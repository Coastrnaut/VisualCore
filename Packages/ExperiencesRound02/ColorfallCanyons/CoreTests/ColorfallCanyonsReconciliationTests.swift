// ColorfallCanyonsReconciliationTests — feature 347 (R02-G05-07) T-R02G0507-002 (FR-R02G0507-001, 003; SC-R02G0507-003;
// clarifications Q1, Q2; research R2, R6). Host checks of the traced results and of reconciliation: every certified
// level's witness actions (the solution's carves and valve toggles, then the step) recorded as a trace verify with three
// stars (five bands of 20); a traced win is verified, a better one replaces it and ties keep the earlier trace; practice
// and replay record nothing; `drop(level:)`; results encode with their traces, an encoding without them (schema 1 or 2)
// decodes unverified; the replay mode round trips and awards nothing; an edited star count, action count or trace step,
// an illegal trace, a trace that does not win and an over-long trace are dropped and counted; a result without a trace is
// kept unverified; the frontier stays as saved; the net actions of records with undo and redo. The certified levels come
// from the per-process generation cache (``ColorfallCanyonsExperienceCore/generated(number:)``); the level of the record
// tests is the one seed 2_347 picks. Edited saves are made by editing the encoded JSON, as a tampered file would be.
// Test data uses explicit types and plain loops (CI type-check rule).
#if DEBUG || VISUALCORE_AUTOMATION
@testable import ColorfallCanyonsCore
import Foundation
import Testing

@Suite struct ColorfallCanyonsReconciliationTests {
    /// The test seed; it picks the level of the record tests (2_347 mod 100 + 1 = 48).
    static let seed: UInt64 = 2_347

    /// The certified witness actions of level `number` (1 … 100): the solution's edits, then the step.
    static func solution(_ number: Int) throws -> [ColorfallCanyonsAction] {
        let actions: [ColorfallCanyonsAction] = ColorfallCanyonsExperienceCore.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The actions a trace spends: its carves and valve toggles.
    static func spent(_ trace: [ColorfallCanyonsAction]) -> Int {
        var count: Int = 0
        for action in trace {
            switch action {
            case .carve, .valve: count += 1
            case .step: continue
            }
        }
        return count
    }

    /// The certified smallest edit count of level `number`.
    static func smallest(_ number: Int) throws -> Int {
        try ColorfallCanyonsExperienceCore.generated(number: number).solution.smallest
    }

    /// Progress with honest verified campaign wins of `levels` (each its certified witness actions as the trace).
    static func honest(_ levels: [Int]) throws -> ColorfallCanyonsProgress {
        var progress: ColorfallCanyonsProgress = ColorfallCanyonsProgress()
        for level in levels {
            let trace: [ColorfallCanyonsAction] = try Self.solution(level)
            progress.record(level: level, actions: Self.spent(trace), smallest: try Self.smallest(level),
                            mode: .campaign, trace: trace)
        }
        return progress
    }

    /// `trace` as encoded JSON.
    static func object(_ trace: [ColorfallCanyonsAction]) throws -> Any {
        try JSONSerialization.jsonObject(with: try JSONEncoder().encode(trace))
    }

    /// `progress` encoded, its won entry for `level` edited by `edit`, decoded again.
    static func edited(_ progress: ColorfallCanyonsProgress, level: Int,
                       _ edit: (inout [String: Any]) throws -> Void) throws -> ColorfallCanyonsProgress {
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try progress.encoded()) as? [String: Any])
        var entries: [[String: Any]] = try #require(object["solved"] as? [[String: Any]])
        for index in entries.indices where entries[index]["level"] as? Int == level {
            try edit(&entries[index])
        }
        object["solved"] = entries
        return try JSONDecoder().decode(ColorfallCanyonsProgress.self,
                                        from: try JSONSerialization.data(withJSONObject: object))
    }

    /// `progress` with the trace of `level` replaced by `trace` (and, when given, its best actions by `actions`).
    static func retraced(_ progress: ColorfallCanyonsProgress, level: Int, _ trace: [ColorfallCanyonsAction],
                         actions: Int? = nil) throws -> ColorfallCanyonsProgress {
        let encoded: Any = try Self.object(trace)
        return try Self.edited(progress, level: level) { entry in
            entry["trace"] = encoded
            if let actions { entry["bestActions"] = actions }
        }
    }

    /// Every certified level of `band` (1 … 5), recorded with its witness actions as the trace, verifies with its
    /// certified smallest edit count and three stars and is kept.
    func verifyBand(_ band: Int) throws {
        var levels: [Int] = []
        for entry in ColorfallCanyonsManifest.entries where entry.band == band { levels.append(entry.number) }
        #expect(levels.count == 20)
        ColorfallCanyonsExperienceCore.prewarm(levels)
        let progress: ColorfallCanyonsProgress = try Self.honest(levels)
        for level in levels {
            let result: ColorfallCanyonsProgress.Result = try #require(progress.solved[level])
            #expect(result.verified && result.stars == 3, "level \(level)")
            #expect(result.bestActions == (try Self.smallest(level)), "level \(level)")
            #expect(ColorfallCanyonsReconciliation.verifies(level: level, result: result), "level \(level)")
        }
        let reconciled: (progress: ColorfallCanyonsProgress, dropped: Int) =
            ColorfallCanyonsReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
    }

    @Test func certifiedSolutionsBand1Verify() throws { try verifyBand(1) }
    @Test func certifiedSolutionsBand2Verify() throws { try verifyBand(2) }
    @Test func certifiedSolutionsBand3Verify() throws { try verifyBand(3) }
    @Test func certifiedSolutionsBand4Verify() throws { try verifyBand(4) }
    @Test func certifiedSolutionsBand5Verify() throws { try verifyBand(5) }

    @Test func aTracedWinIsVerifiedAndOnlyABetterOneReplacesIt() throws {
        let level: Int = ColorfallCanyonsExperienceCore.levelNumber(forSeed: Self.seed)
        #expect(level == 48)
        let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsExperienceCore.generated(number: level)
        let best: [ColorfallCanyonsAction] = try Self.solution(level)
        let smallest: Int = try Self.smallest(level)
        try #require(generated.level.budget >= smallest + 2 && !generated.level.springs.isEmpty)
        // A longer win: spring 0 toggled twice before the certified actions (the valves end as they began).
        let longer: [ColorfallCanyonsAction] = [.valve(0), .valve(0)] + best
        var check: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: generated.level)
        for action in longer { try check.apply(action, expecting: check.fingerprint) }
        #expect(check.stage == .won && check.spent == smallest + 2)
        var progress: ColorfallCanyonsProgress = ColorfallCanyonsProgress()
        progress.open(through: level)
        let first: Bool = progress.record(level: level, actions: smallest + 2, smallest: smallest, trace: longer)
        #expect(first)
        #expect(progress.solved[level]?.verified == true)
        #expect(progress.solved[level]?.trace == longer)
        #expect(progress.solved[level]?.stars == 2)
        let longerResult: ColorfallCanyonsProgress.Result = try #require(progress.solved[level])
        #expect(ColorfallCanyonsReconciliation.verifies(level: level, result: longerResult))
        let fewer: Bool = progress.record(level: level, actions: smallest, smallest: smallest, trace: best)
        #expect(fewer)
        #expect(progress.solved[level]?.trace == best && progress.solved[level]?.stars == 3)
        // A tie keeps the earlier trace; more actions never replace.
        let tie: Bool = progress.record(level: level, actions: smallest, smallest: smallest, trace: [.step(1)] + best)
        #expect(!tie && progress.solved[level]?.trace == best)
        let more: Bool = progress.record(level: level, actions: smallest + 2, smallest: smallest, trace: longer)
        #expect(!more && progress.solved[level]?.trace == best)
        #expect(progress.frontier == level + 1)
        // Daily opens nothing; practice and replay record nothing; a level outside 1 … 100 is ignored.
        let daily: Bool = progress.record(level: 60, actions: 3, smallest: 2, mode: .daily(level: 60), trace: best)
        #expect(daily && progress.frontier == level + 1 && progress.solved[60]?.verified == true)
        let practice: Bool = progress.record(level: 61, actions: 3, smallest: 2, mode: .practice, trace: best)
        let replay: Bool = progress.record(level: 62, actions: 3, smallest: 2, mode: .replay(level: 62), trace: best)
        let outside: Bool = progress.record(level: 101, actions: 3, smallest: 2, trace: best)
        let below: Bool = progress.record(level: 0, actions: 3, smallest: 2, trace: best)
        #expect(!practice && !replay && !outside && !below)
        #expect(progress.solved[61] == nil && progress.solved[62] == nil && progress.solved[101] == nil)
        // A win without a trace is unverified, as before.
        progress.record(level: 2, actions: 9, smallest: 1)
        #expect(progress.solved[2] == ColorfallCanyonsProgress.Result(bestActions: 9, stars: 1))
        #expect(progress.solved[2]?.verified == false && progress.solved[2]?.trace.isEmpty == true)
        // drop removes the result; the frontier is unchanged.
        progress.drop(level: level)
        #expect(progress.solved[level] == nil && progress.frontier == level + 1)
        progress.drop(level: 77)
        #expect(progress.solved.count == 2)
    }

    @Test func tracesEncodeAndAnOldEncodingDecodesUnverified() throws {
        let progress: ColorfallCanyonsProgress = try Self.honest([1, 2])
        let data: Data = try progress.encoded()
        let decoded: ColorfallCanyonsProgress = try JSONDecoder().decode(ColorfallCanyonsProgress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"trace\":["))
        #expect(text.contains("\"verified\":true"))
        let old: Data = Data("{\"frontier\":3,\"solved\":[{\"bestActions\":5,\"level\":1,\"stars\":2}]}".utf8)
        let restored: ColorfallCanyonsProgress = try JSONDecoder().decode(ColorfallCanyonsProgress.self, from: old)
        #expect(restored.solved[1] == ColorfallCanyonsProgress.Result(bestActions: 5, stars: 2))
        #expect(restored.solved[1]?.verified == false)
        #expect(restored.solved[1]?.trace.isEmpty == true)
        #expect(restored.frontier == 3)
        // The old payload re-encodes with an empty trace and verified false.
        let reencoded: String = String(decoding: try restored.encoded(), as: UTF8.self)
        #expect(reencoded == "{\"frontier\":3,\"solved\":[{\"bestActions\":5,\"level\":1,\"stars\":2,\"trace\":[],"
            + "\"verified\":false}]}")
        // Every action kind round trips in a trace.
        let actions: [ColorfallCanyonsAction] = [.carve(7), .valve(1), .step(600)]
        let encodedActions: Data = try JSONEncoder().encode(actions)
        #expect(try JSONDecoder().decode([ColorfallCanyonsAction].self, from: encodedActions) == actions)
    }

    @Test func theReplayModeRoundTripsAndAwardsNothing() throws {
        let modes: [ColorfallCanyonsMode] = [.campaign, .practice, .daily(level: 7), .replay(level: 48)]
        let names: [String] = ["{\"mode\":\"campaign\"}", "{\"mode\":\"practice\"}",
                               "{\"level\":7,\"mode\":\"daily\"}", "{\"level\":48,\"mode\":\"replay\"}"]
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for index in modes.indices {
            let data: Data = try encoder.encode(modes[index])
            #expect(String(decoding: data, as: UTF8.self) == names[index])
            #expect(try JSONDecoder().decode(ColorfallCanyonsMode.self, from: data) == modes[index])
        }
        let replay: ColorfallCanyonsMode = .replay(level: 48)
        #expect(!replay.awardsStars && !replay.opensLevels)
        #expect(replay.budget(base: 5) == 5)
        #expect(ColorfallCanyonsMode.campaign.awardsStars && ColorfallCanyonsMode.daily(level: 3).awardsStars)
        #expect(!ColorfallCanyonsMode.practice.awardsStars)
        let bad: [String] = ["{\"mode\":\"replay\",\"level\":0}", "{\"mode\":\"replay\",\"level\":101}",
                             "{\"mode\":\"replay\"}"]
        for text in bad {
            #expect(throws: DecodingError.self, "\(text)") {
                _ = try JSONDecoder().decode(ColorfallCanyonsMode.self, from: Data(text.utf8))
            }
        }
        #expect(ColorfallCanyonsFeedbackPlan.modeName(replay) == "replay")
    }

    @Test func editedStarsActionsStepsIllegalAndOverlongTracesAreDropped() throws {
        let levels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        ColorfallCanyonsExperienceCore.prewarm(levels)
        let progress: ColorfallCanyonsProgress = try Self.honest(levels)
        // Level 1: stars edited.
        var tampered: ColorfallCanyonsProgress = try Self.edited(progress, level: 1) { entry in entry["stars"] = 2 }
        // Level 2: best actions edited.
        tampered = try Self.edited(tampered, level: 2) { entry in
            entry["bestActions"] = ((entry["bestActions"] as? Int) ?? 0) + 1
        }
        // Level 10: best actions one below the actions spent (the star count still matches: only the spent check sees it).
        try #require(try Self.smallest(10) >= 1)
        tampered = try Self.edited(tampered, level: 10) { entry in
            entry["bestActions"] = ((entry["bestActions"] as? Int) ?? 0) - 1
        }
        #expect(tampered.solved[10]?.stars == ColorfallCanyonsProgress.stars(
            actions: (tampered.solved[10]?.bestActions ?? 0), smallest: try Self.smallest(10)))
        // Level 3: the final step edited to one tick (the play does not win).
        var shortened: [ColorfallCanyonsAction] = try Self.solution(3)
        guard case .step = shortened[shortened.count - 1] else {
            Issue.record("the witness ends with a step")
            return
        }
        shortened[shortened.count - 1] = .step(1)
        tampered = try Self.retraced(tampered, level: 3, shortened)
        // Level 4: an illegal trace (a carve of a cell out of range, refused by the kernel).
        tampered = try Self.retraced(tampered, level: 4, [.carve(-1)] + (try Self.solution(4)))
        // Level 5: an illegal trace (a step of 0 ticks).
        tampered = try Self.retraced(tampered, level: 5, [.step(0)] + (try Self.solution(5)))
        // Level 6: a trace that does not win (the step removed, best actions matching).
        var unfinished: [ColorfallCanyonsAction] = try Self.solution(6)
        unfinished.removeLast()
        tampered = try Self.retraced(tampered, level: 6, unfinished, actions: Self.spent(unfinished))
        // Level 7: more than 30 carves and valve toggles (31 toggles of spring 0, then the witness).
        var tooManyEdits: [ColorfallCanyonsAction] = []
        for _ in 0..<31 { tooManyEdits.append(.valve(0)) }
        tooManyEdits += try Self.solution(7)
        #expect(!ColorfallCanyonsProgress.withinTraceBound(tooManyEdits))
        tampered = try Self.retraced(tampered, level: 7, tooManyEdits)
        // Level 8: more than 3,600 steps (3,601 one-tick steps after the edits).
        let witness8: [ColorfallCanyonsAction] = try Self.solution(8)
        var tooManySteps: [ColorfallCanyonsAction] = Array(witness8.dropLast())
        for _ in 0..<3_601 { tooManySteps.append(.step(1)) }
        #expect(!ColorfallCanyonsProgress.withinTraceBound(tooManySteps))
        #expect(ColorfallCanyonsProgress.maximumTraceEdits == 30 && ColorfallCanyonsProgress.maximumTraceSteps == 3_600)
        // The bound's edges: 30 edits and 3,600 steps are within it; one more of either is not.
        var edge: [ColorfallCanyonsAction] = []
        for _ in 0..<30 { edge.append(.carve(0)) }
        for _ in 0..<3_600 { edge.append(.step(1)) }
        #expect(ColorfallCanyonsProgress.withinTraceBound(edge))
        #expect(!ColorfallCanyonsProgress.withinTraceBound(edge + [.valve(0)]))
        #expect(!ColorfallCanyonsProgress.withinTraceBound(edge + [.step(1)]))
        tampered = try Self.retraced(tampered, level: 8, tooManySteps)
        #expect(tampered.solved[8]?.trace.count == tooManySteps.count)
        let reconciled: (progress: ColorfallCanyonsProgress, dropped: Int) =
            ColorfallCanyonsReconciliation.reconcile(tampered)
        #expect(reconciled.dropped == 9)
        #expect(reconciled.progress.solved.keys.sorted() == [9])
        #expect(reconciled.progress.solved[9] == progress.solved[9])
        #expect(reconciled.progress.frontier == progress.frontier)
    }

    @Test func tracelessResultsAreKeptAndTheFrontierStaysAsSaved() throws {
        var progress: ColorfallCanyonsProgress = try Self.honest([9])
        progress.record(level: 3, actions: 12, smallest: 5)
        // A daily traced win beyond the frontier.
        let daily: [ColorfallCanyonsAction] = try Self.solution(60)
        progress.record(level: 60, actions: Self.spent(daily), smallest: try Self.smallest(60),
                        mode: .daily(level: 60), trace: daily)
        #expect(progress.frontier == 10)
        let reconciled: (progress: ColorfallCanyonsProgress, dropped: Int) =
            ColorfallCanyonsReconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
        #expect(reconciled.progress.solved[3]?.verified == false)
        #expect(reconciled.progress.frontier == 10)
        // Dropping never lowers the frontier.
        let tampered: ColorfallCanyonsProgress = try Self.edited(progress, level: 9) { entry in entry["stars"] = 1 }
        let after: (progress: ColorfallCanyonsProgress, dropped: Int) =
            ColorfallCanyonsReconciliation.reconcile(tampered)
        #expect(after.dropped == 1 && after.progress.frontier == 10 && after.progress.solved[9] == nil)
        // A verified result without a trace or an out-of-range level never verifies.
        let empty: ColorfallCanyonsProgress.Result = ColorfallCanyonsProgress.Result(bestActions: 2, stars: 3, trace: [],
                                                                                     verified: true)
        #expect(!ColorfallCanyonsReconciliation.verifies(level: 1, result: empty))
        let claimed: ColorfallCanyonsProgress = try Self.edited(progress, level: 3) { entry in entry["verified"] = true }
        let claimedAfter: (progress: ColorfallCanyonsProgress, dropped: Int) =
            ColorfallCanyonsReconciliation.reconcile(claimed)
        #expect(claimedAfter.dropped == 1 && claimedAfter.progress.solved[3] == nil)
        let honest9: ColorfallCanyonsProgress.Result = try #require(progress.solved[9])
        #expect(ColorfallCanyonsReconciliation.verifies(level: 9, result: honest9))
        #expect(!ColorfallCanyonsReconciliation.verifies(level: 0, result: honest9))
        #expect(!ColorfallCanyonsReconciliation.verifies(level: 101, result: honest9))
    }

    @Test func netActionsCancelUndoneActionsAndRestoreRedoneOnes() throws {
        // Hand-made records: carve 1, carve 2, undo, undo, redo, step 5, redo (nothing to redo) → carve 1, step 5.
        let kinds: [ColorfallCanyonsRecordKind] = [.carve, .carve, .undo, .undo, .redo, .step, .redo]
        let actions: [ColorfallCanyonsAction?] = [.carve(1), .carve(2), nil, nil, nil, .step(5), nil]
        var records: [ColorfallCanyonsRecord] = []
        for index in kinds.indices {
            records.append(ColorfallCanyonsRecord(schema: 1, seed: 1, tick: 0, kind: kinds[index],
                                                  action: actions[index], previous: "a", next: "b"))
        }
        #expect(ColorfallCanyonsReconciliation.netActions(records) == [.carve(1), .step(5)])
        #expect(ColorfallCanyonsReconciliation.netActions([]).isEmpty)
        // A redo after a new action restores nothing (the new action cleared the redo stack).
        let cleared: [ColorfallCanyonsRecord] = [
            ColorfallCanyonsRecord(schema: 1, seed: 1, tick: 0, kind: .valve, action: .valve(0), previous: "a", next: "b"),
            ColorfallCanyonsRecord(schema: 1, seed: 1, tick: 0, kind: .undo, action: nil, previous: "b", next: "a"),
            ColorfallCanyonsRecord(schema: 1, seed: 1, tick: 0, kind: .carve, action: .carve(3), previous: "a", next: "c"),
            ColorfallCanyonsRecord(schema: 1, seed: 1, tick: 0, kind: .redo, action: nil, previous: "c", next: "c"),
        ]
        #expect(ColorfallCanyonsReconciliation.netActions(cleared) == [.carve(3)])

        // A real play of level 48 with detours undone and redone: its net actions are the certified actions, replay to
        // the same fingerprint and verify.
        let level: Int = 48
        let generated: ColorfallCanyonsGenerated = try ColorfallCanyonsExperienceCore.generated(number: level)
        let best: [ColorfallCanyonsAction] = try Self.solution(level)
        var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: generated.level)
        try play.apply(best[0], expecting: play.fingerprint)
        try play.apply(.valve(0), expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        try play.undo()
        try play.apply(.step(1), expecting: play.fingerprint)
        try play.undo()
        for index in 1..<best.count { try play.apply(best[index], expecting: play.fingerprint) }
        #expect(play.stage == .won)
        let net: [ColorfallCanyonsAction] = ColorfallCanyonsReconciliation.netActions(play.records)
        #expect(net == best)
        var again: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: generated.level)
        for action in net { try again.apply(action, expecting: again.fingerprint) }
        #expect(again.fingerprint == play.fingerprint)
        let result: ColorfallCanyonsProgress.Result = ColorfallCanyonsProgress.Result(
            bestActions: play.spent, stars: ColorfallCanyonsProgress.stars(actions: play.spent,
                                                                           smallest: generated.solution.smallest),
            trace: net, verified: true)
        #expect(ColorfallCanyonsReconciliation.verifies(level: level, result: result))
    }
}
#endif
