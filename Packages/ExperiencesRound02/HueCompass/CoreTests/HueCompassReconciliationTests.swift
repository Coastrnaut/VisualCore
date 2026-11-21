// HueCompassReconciliationTests — feature 337 (R02-G04-07) T-R02G0407-002 (FR-R02G0407-001, 003; clarifications Q1, Q2;
// research R6; SC-R02G0407-003). Host checks of the traced results and of reconciliation: every certified level's
// witness actions (the solution's turns and probes, then the selection) recorded as a trace verify (five bands of 20); a
// traced win is verified, fewer units replace it and ties keep the earlier trace; practice and replay record nothing;
// `drop(level:)`; results encode with their traces, an encoding without them (schema 2) decodes unverified; the replay
// mode round trips and awards nothing; an edited star count, unit count or trace step, an illegal trace, a trace that
// does not win and an over-long trace are dropped and counted; a result without a trace is kept unverified; the frontier
// stays as saved. The certified levels come from the per-process generation cache
// (``HueCompassExperienceCore/generated(number:)``); the level of the record tests is the one seed 2_337 picks. Edited
// saves are made by editing the encoded JSON, as a tampered file would be. Test data uses explicit types and plain loops
// (CI type-check rule).
@testable import HueCompassCore
import Foundation
import Testing

@Suite struct HueCompassReconciliationTests {
    /// The test seed; it picks the level of the record tests (2_337 mod 100 + 1 = 38).
    static let seed: UInt64 = 2_337

    /// The certified witness actions of level `number` (1 … 100): the solution's turns and probes, then the selection.
    static func solution(_ number: Int) throws -> [HueCompassAction] {
        let actions: [HueCompassAction] = HueCompassExperienceCore.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The units a trace spends: its probes and its selection.
    static func units(_ trace: [HueCompassAction]) -> Int {
        var count: Int = 0
        for action in trace {
            switch action {
            case .turn: continue
            case .probe, .select: count += 1
            }
        }
        return count
    }

    /// The certified smallest probe count of level `number`.
    static func smallest(_ number: Int) throws -> Int {
        try HueCompassExperienceCore.generated(number: number).solution.smallest
    }

    /// Progress with honest verified campaign wins of `levels` (each its certified witness actions as the trace).
    static func honest(_ levels: [Int]) throws -> HueCompassProgress {
        var progress: HueCompassProgress = HueCompassProgress()
        for level in levels {
            let trace: [HueCompassAction] = try Self.solution(level)
            progress.record(level: level, units: Self.units(trace), smallest: try Self.smallest(level),
                            mode: .campaign, trace: trace)
        }
        return progress
    }

    /// `trace` as encoded JSON.
    static func object(_ trace: [HueCompassAction]) throws -> Any {
        try JSONSerialization.jsonObject(with: try JSONEncoder().encode(trace))
    }

    /// `progress` encoded, its won entry for `level` edited by `edit`, decoded again.
    static func edited(_ progress: HueCompassProgress, level: Int,
                       _ edit: (inout [String: Any]) throws -> Void) throws -> HueCompassProgress {
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try progress.encoded()) as? [String: Any])
        var entries: [[String: Any]] = try #require(object["solved"] as? [[String: Any]])
        for index in entries.indices where entries[index]["level"] as? Int == level {
            try edit(&entries[index])
        }
        object["solved"] = entries
        return try JSONDecoder().decode(HueCompassProgress.self,
                                        from: try JSONSerialization.data(withJSONObject: object))
    }

    /// `progress` with the trace of `level` replaced by `trace` (and, when given, its best units by `units`).
    static func retraced(_ progress: HueCompassProgress, level: Int, _ trace: [HueCompassAction],
                         units: Int? = nil) throws -> HueCompassProgress {
        let encoded: Any = try Self.object(trace)
        return try Self.edited(progress, level: level) { entry in
            entry["trace"] = encoded
            if let units { entry["bestUnits"] = units }
        }
    }

    /// Every certified level of `band` (1 … 5), recorded with its witness actions as the trace, verifies and is kept.
    func verifyBand(_ band: Int) throws {
        var levels: [Int] = []
        for entry in HueCompassManifest.entries where entry.band == band { levels.append(entry.number) }
        #expect(levels.count == 20)
        HueCompassExperienceCore.prewarm(levels)
        let progress: HueCompassProgress = try Self.honest(levels)
        for level in levels {
            let result: HueCompassProgress.Result = try #require(progress.solved[level])
            #expect(result.verified && result.stars == 3, "level \(level)")
            #expect(result.bestUnits == (try Self.smallest(level)) + 1, "level \(level)")
            #expect(HueCompassReconciliation.verifies(level: level, result: result), "level \(level)")
        }
        let reconciled: (progress: HueCompassProgress, dropped: Int) = HueCompassReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
    }

    @Test func certifiedSolutionsBand1Verify() throws { try verifyBand(1) }
    @Test func certifiedSolutionsBand2Verify() throws { try verifyBand(2) }
    @Test func certifiedSolutionsBand3Verify() throws { try verifyBand(3) }
    @Test func certifiedSolutionsBand4Verify() throws { try verifyBand(4) }
    @Test func certifiedSolutionsBand5Verify() throws { try verifyBand(5) }

    @Test func aTracedWinIsVerifiedAndOnlyFewerUnitsReplaceIt() throws {
        let level: Int = HueCompassExperienceCore.levelNumber(forSeed: Self.seed)
        #expect(level == 38)
        let best: [HueCompassAction] = try Self.solution(level)
        let smallest: Int = try Self.smallest(level)
        let bestUnits: Int = Self.units(best)
        // A longer win: one extra probe before the certified actions (the extra clue changes nothing else).
        let longer: [HueCompassAction] = [.probe] + best
        var progress: HueCompassProgress = HueCompassProgress()
        progress.open(through: level)
        let first: Bool = progress.record(level: level, units: bestUnits + 1, smallest: smallest, trace: longer)
        #expect(first)
        #expect(progress.solved[level]?.verified == true)
        #expect(progress.solved[level]?.trace == longer)
        #expect(progress.solved[level]?.stars == HueCompassProgress.stars(units: bestUnits + 1, smallest: smallest))
        let fewer: Bool = progress.record(level: level, units: bestUnits, smallest: smallest, trace: best)
        #expect(fewer)
        #expect(progress.solved[level]?.trace == best && progress.solved[level]?.stars == 3)
        // A tie keeps the earlier trace; more units never replace.
        let tie: Bool = progress.record(level: level, units: bestUnits, smallest: smallest, trace: [.turn(1)] + best)
        #expect(!tie && progress.solved[level]?.trace == best)
        let more: Bool = progress.record(level: level, units: bestUnits + 1, smallest: smallest, trace: longer)
        #expect(!more && progress.solved[level]?.trace == best)
        #expect(progress.frontier == level + 1)
        // Daily opens nothing; practice and replay record nothing; a level outside 1 … 100 is ignored.
        let daily: Bool = progress.record(level: 60, units: 3, smallest: 2, mode: .daily(level: 60), trace: best)
        #expect(daily && progress.frontier == level + 1 && progress.solved[60]?.verified == true)
        let practice: Bool = progress.record(level: 61, units: 3, smallest: 2, mode: .practice, trace: best)
        let replay: Bool = progress.record(level: 62, units: 3, smallest: 2, mode: .replay(level: 62), trace: best)
        let outside: Bool = progress.record(level: 101, units: 3, smallest: 2, trace: best)
        #expect(!practice && !replay && !outside)
        #expect(progress.solved[61] == nil && progress.solved[62] == nil && progress.solved[101] == nil)
        // A win without a trace is unverified, as before.
        progress.record(level: 2, units: 9, smallest: 1)
        #expect(progress.solved[2] == HueCompassProgress.Result(bestUnits: 9, stars: 1))
        #expect(progress.solved[2]?.verified == false && progress.solved[2]?.trace.isEmpty == true)
        // drop removes the result; the frontier is unchanged.
        progress.drop(level: level)
        #expect(progress.solved[level] == nil && progress.frontier == level + 1)
        progress.drop(level: 77)
        #expect(progress.solved.count == 2)
    }

    @Test func tracesEncodeAndASchemaTwoEncodingDecodesUnverified() throws {
        let progress: HueCompassProgress = try Self.honest([1, 2])
        let data: Data = try progress.encoded()
        let decoded: HueCompassProgress = try JSONDecoder().decode(HueCompassProgress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"trace\":["))
        #expect(text.contains("\"verified\":true"))
        let old: Data = Data("{\"frontier\":3,\"solved\":[{\"bestUnits\":5,\"level\":1,\"stars\":2}]}".utf8)
        let restored: HueCompassProgress = try JSONDecoder().decode(HueCompassProgress.self, from: old)
        #expect(restored.solved[1] == HueCompassProgress.Result(bestUnits: 5, stars: 2))
        #expect(restored.solved[1]?.verified == false)
        #expect(restored.solved[1]?.trace.isEmpty == true)
        #expect(restored.frontier == 3)
        // The old payload re-encodes with an empty trace and verified false.
        let reencoded: String = String(decoding: try restored.encoded(), as: UTF8.self)
        #expect(reencoded == "{\"frontier\":3,\"solved\":[{\"bestUnits\":5,\"level\":1,\"stars\":2,\"trace\":[],"
            + "\"verified\":false}]}")
    }

    @Test func theReplayModeRoundTripsAndAwardsNothing() throws {
        let modes: [HueCompassMode] = [.campaign, .practice, .daily(level: 7), .replay(level: 38)]
        let names: [String] = ["{\"mode\":\"campaign\"}", "{\"mode\":\"practice\"}",
                               "{\"level\":7,\"mode\":\"daily\"}", "{\"level\":38,\"mode\":\"replay\"}"]
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for index in modes.indices {
            let data: Data = try encoder.encode(modes[index])
            #expect(String(decoding: data, as: UTF8.self) == names[index])
            #expect(try JSONDecoder().decode(HueCompassMode.self, from: data) == modes[index])
        }
        let replay: HueCompassMode = .replay(level: 38)
        #expect(!replay.awardsStars && !replay.opensLevels)
        #expect(replay.allowance(base: 5) == 5)
        #expect(HueCompassMode.campaign.awardsStars && HueCompassMode.daily(level: 3).awardsStars)
        #expect(!HueCompassMode.practice.awardsStars)
        for bad in ["{\"mode\":\"replay\",\"level\":0}", "{\"mode\":\"replay\",\"level\":101}", "{\"mode\":\"replay\"}"] {
            #expect(throws: DecodingError.self, "\(bad)") {
                _ = try JSONDecoder().decode(HueCompassMode.self, from: Data(bad.utf8))
            }
        }
        #expect(HueCompassFeedbackPlan.modeName(replay) == "Replay")
    }

    @Test func editedStarsUnitsStepsIllegalAndOverlongTracesAreDropped() throws {
        let levels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8]
        let progress: HueCompassProgress = try Self.honest(levels)
        // Level 1: stars edited.
        var tampered: HueCompassProgress = try Self.edited(progress, level: 1) { entry in entry["stars"] = 2 }
        // Level 2: best units edited.
        tampered = try Self.edited(tampered, level: 2) { entry in
            entry["bestUnits"] = ((entry["bestUnits"] as? Int) ?? 0) + 1
        }
        // Level 3: the selection step changed to a band the level does not accept (the play fails).
        var changed: [HueCompassAction] = try Self.solution(3)
        let level3: HueCompassLevel = try HueCompassExperienceCore.generated(number: 3).level
        guard case .select(let bearing, let band) = changed[changed.count - 1] else {
            Issue.record("the witness ends with a selection")
            return
        }
        let wrong: Int = (band + 12) % HueCompassWheel.bands
        #expect(!level3.accepts(bearing: bearing, band: wrong))
        changed[changed.count - 1] = .select(bearing: bearing, band: wrong)
        tampered = try Self.retraced(tampered, level: 3, changed)
        // Level 4: an illegal trace (a selection bearing out of range, refused by the kernel).
        var illegal: [HueCompassAction] = try Self.solution(4)
        illegal[illegal.count - 1] = .select(bearing: 200, band: 0)
        tampered = try Self.retraced(tampered, level: 4, illegal)
        // Level 5: an illegal trace (a turn of 0).
        tampered = try Self.retraced(tampered, level: 5, [.turn(0)] + (try Self.solution(5)))
        // Level 6: a trace that does not win (the selection removed, best units matching).
        var unfinished: [HueCompassAction] = try Self.solution(6)
        unfinished.removeLast()
        tampered = try Self.retraced(tampered, level: 6, unfinished, units: Self.units(unfinished))
        // Level 7: an over-long trace that would win without the bound (600 turn pairs, then the witness).
        var overlong: [HueCompassAction] = []
        for _ in 0..<600 {
            overlong.append(.turn(1))
            overlong.append(.turn(-1))
        }
        let witness7: [HueCompassAction] = try Self.solution(7)
        overlong += witness7
        #expect(overlong.count > HueCompassProgress.maximumTraceLength)
        #expect(HueCompassProgress.maximumTraceLength == 24 + 24 * 48)
        var unbounded: HueCompassPlay = try HueCompassExperienceCore.freshPlay(
            of: try HueCompassExperienceCore.generated(number: 7).level)
        for action in overlong { try unbounded.apply(action, expecting: unbounded.fingerprint) }
        #expect(unbounded.stage == .won)
        tampered = try Self.retraced(tampered, level: 7, overlong)
        #expect(tampered.solved[7]?.trace.count == overlong.count)
        let reconciled: (progress: HueCompassProgress, dropped: Int) = HueCompassReconciliation.reconcile(tampered)
        #expect(reconciled.dropped == 7)
        #expect(reconciled.progress.solved.keys.sorted() == [8])
        #expect(reconciled.progress.solved[8] == progress.solved[8])
        #expect(reconciled.progress.frontier == progress.frontier)
    }

    @Test func tracelessResultsAreKeptAndTheFrontierStaysAsSaved() throws {
        var progress: HueCompassProgress = try Self.honest([9])
        progress.record(level: 3, units: 12, smallest: 5)
        // A daily traced win beyond the frontier.
        let daily: [HueCompassAction] = try Self.solution(60)
        progress.record(level: 60, units: Self.units(daily), smallest: try Self.smallest(60), mode: .daily(level: 60),
                        trace: daily)
        #expect(progress.frontier == 10)
        let reconciled: (progress: HueCompassProgress, dropped: Int) = HueCompassReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
        #expect(reconciled.progress.solved[3]?.verified == false)
        #expect(reconciled.progress.frontier == 10)
        // Dropping never lowers the frontier.
        let tampered: HueCompassProgress = try Self.edited(progress, level: 9) { entry in entry["stars"] = 1 }
        let after: (progress: HueCompassProgress, dropped: Int) = HueCompassReconciliation.reconcile(tampered)
        #expect(after.dropped == 1 && after.progress.frontier == 10 && after.progress.solved[9] == nil)
        // A verified result without a trace, a trace on another level or an out-of-range level never verifies.
        let empty: HueCompassProgress.Result = HueCompassProgress.Result(bestUnits: 2, stars: 3, trace: [],
                                                                         verified: true)
        #expect(!HueCompassReconciliation.verifies(level: 1, result: empty))
        let claimed: HueCompassProgress = try Self.edited(progress, level: 3) { entry in entry["verified"] = true }
        let claimedAfter: (progress: HueCompassProgress, dropped: Int) = HueCompassReconciliation.reconcile(claimed)
        #expect(claimedAfter.dropped == 1 && claimedAfter.progress.solved[3] == nil)
        let honest9: HueCompassProgress.Result = try #require(progress.solved[9])
        #expect(HueCompassReconciliation.verifies(level: 9, result: honest9))
        #expect(!HueCompassReconciliation.verifies(level: 0, result: honest9))
        #expect(!HueCompassReconciliation.verifies(level: 101, result: honest9))
    }
}
