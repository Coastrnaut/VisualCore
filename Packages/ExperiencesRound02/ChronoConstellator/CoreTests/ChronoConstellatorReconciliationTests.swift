// ChronoConstellatorReconciliationTests — feature 357 (R02-G06-07) T-R02G0607-002 (clarifications Q1 … Q3;
// contracts/api.md). Host checks of the traced results and of reconciliation: every certified level's witness actions
// (``ChronoConstellatorWitness/actions(for:level:)``: the solution's phase changes, then one step of the tick limit)
// recorded as a trace verify with three stars (five bands of 20, each prewarmed concurrently); a traced win is
// verified, a better one replaces it and ties keep the earlier trace; practice and replay record nothing;
// `drop(level:)`; an edited star count, edit count or trace step, an illegal trace and an over-long trace are dropped
// and counted; a result without a trace is kept unverified; the frontier stays as saved; the net trace of records with
// undo and redo equals the hand-computed list and replays to the same fingerprint. Edited saves are made by editing the
// encoded JSON, as a tampered file would be. Explicit types and plain loops (CI type-check rule); each test < 3 s.
import Foundation
import Testing
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorReconciliationTests {
    typealias Core = ChronoConstellatorExperienceCore
    typealias Progress = ChronoConstellatorProgress
    typealias Reconciliation = ChronoConstellatorReconciliation
    typealias Action = ChronoConstellatorAction

    /// The certified witness actions of level `number` (1 … 100).
    static func witness(_ number: Int) throws -> [Action] {
        let generated: ChronoConstellatorGenerated = try Core.generated(number: number)
        let actions: [Action] = ChronoConstellatorWitness.actions(for: generated.solution, level: generated.level)
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The certified smallest edit count of level `number`.
    static func smallest(_ number: Int) throws -> Int {
        try Core.generated(number: number).difficulty.smallest
    }

    /// The edits in use after replaying `trace` on a fresh play of level `number`.
    static func spent(_ number: Int, _ trace: [Action]) throws -> Int {
        let generated: ChronoConstellatorGenerated = try Core.generated(number: number)
        var play: ChronoConstellatorPlay = try Core.freshPlay(of: generated.level)
        for action in trace { try play.apply(action, expecting: play.fingerprint) }
        return play.spent
    }

    /// Progress with honest verified campaign wins of `levels` (each its witness actions as the trace).
    static func honest(_ levels: [Int]) throws -> Progress {
        var progress: Progress = Progress()
        for level in levels {
            let trace: [Action] = try Self.witness(level)
            let edits: Int = try Self.spent(level, trace)
            progress.record(level: level, edits: edits, smallest: try Self.smallest(level), mode: .campaign,
                            trace: trace)
        }
        return progress
    }

    /// `progress` encoded, its won entry for `level` edited by `edit`, decoded again.
    static func edited(_ progress: Progress, level: Int,
                       _ edit: (inout [String: Any]) throws -> Void) throws -> Progress {
        let data: Data = try progress.encoded()
        var object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        var entries: [[String: Any]] = try #require(object["solved"] as? [[String: Any]])
        for index in entries.indices where entries[index]["level"] as? Int == level {
            try edit(&entries[index])
        }
        object["solved"] = entries
        return try JSONDecoder().decode(Progress.self, from: try JSONSerialization.data(withJSONObject: object))
    }

    /// `progress` with the trace of `level` replaced by `trace`.
    static func retraced(_ progress: Progress, level: Int, _ trace: [Action]) throws -> Progress {
        let encoded: Any = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(trace))
        return try Self.edited(progress, level: level) { (entry: inout [String: Any]) in entry["trace"] = encoded }
    }

    /// Every certified level of `band` (1 … 5), recorded with its witness actions as the trace, verifies with its
    /// certified smallest edit count and three stars and is kept.
    func verifyBand(_ band: Int) throws {
        var levels: [Int] = []
        for number in Core.levelNumbers where Progress.band(of: number) == band { levels.append(number) }
        #expect(levels.count == 20)
        Core.prewarm(levels)
        let progress: Progress = try Self.honest(levels)
        for level in levels {
            let result: Progress.Result = try #require(progress.solved[level])
            #expect(result.verified && result.stars == 3, "level \(level)")
            #expect(result.bestEdits == (try Self.smallest(level)), "level \(level)")
            #expect(result.trace.count <= Reconciliation.maxTraceLength, "level \(level)")
            #expect(Reconciliation.verifies(level: level, result: result), "level \(level)")
        }
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
    }

    @Test func certifiedWitnessesBand1Verify() throws { try verifyBand(1) }
    @Test func certifiedWitnessesBand2Verify() throws { try verifyBand(2) }
    @Test func certifiedWitnessesBand3Verify() throws { try verifyBand(3) }
    @Test func certifiedWitnessesBand4Verify() throws { try verifyBand(4) }
    @Test func certifiedWitnessesBand5Verify() throws { try verifyBand(5) }

    @Test func aTracedWinIsVerifiedAndOnlyABetterOneReplacesIt() throws {
        let level: Int = 48
        let best: [Action] = try Self.witness(level)
        let smallest: Int = try Self.smallest(level)
        // A longer trace of the same win: two rewinds first (legal at tick 0, no edit), so the edits are equal.
        let longer: [Action] = [Action.rewind, Action.rewind] + best
        var progress: Progress = Progress()
        let first: Bool = progress.record(level: level, edits: smallest + 2, smallest: smallest, trace: longer)
        #expect(first)
        #expect(progress.solved[level]?.verified == true)
        #expect(progress.solved[level]?.trace == longer)
        #expect(progress.solved[level]?.stars == 2)
        let fewer: Bool = progress.record(level: level, edits: smallest, smallest: smallest, trace: best)
        #expect(fewer)
        #expect(progress.solved[level]?.trace == best && progress.solved[level]?.stars == 3)
        // A tie keeps the earlier trace; more edits never replace.
        let tie: Bool = progress.record(level: level, edits: smallest, smallest: smallest, trace: longer)
        #expect(!tie && progress.solved[level]?.trace == best)
        let more: Bool = progress.record(level: level, edits: smallest + 2, smallest: smallest, trace: longer)
        #expect(!more && progress.solved[level]?.trace == best)
        #expect(progress.frontier == level + 1)
        // Daily opens nothing; practice and replay record nothing; a level outside 1 … 100 is ignored.
        let daily: Bool = progress.record(level: 60, edits: 3, smallest: 2, mode: .daily(level: 60), trace: best)
        #expect(daily && progress.frontier == level + 1 && progress.solved[60]?.verified == true)
        let practice: Bool = progress.record(level: 61, edits: 3, smallest: 2, mode: .practice, trace: best)
        let replay: Bool = progress.record(level: 62, edits: 3, smallest: 2, mode: .replay(level: 62), trace: best)
        let outside: Bool = progress.record(level: 101, edits: 3, smallest: 2, trace: best)
        let below: Bool = progress.record(level: 0, edits: 3, smallest: 2, trace: best)
        #expect(!practice && !replay && !outside && !below)
        #expect(progress.solved[61] == nil && progress.solved[62] == nil && progress.solved[101] == nil)
        // A win without a trace is unverified, as before.
        progress.record(level: 2, edits: 9, smallest: 1)
        #expect(progress.solved[2] == Progress.Result(bestEdits: 9, stars: 1))
        #expect(progress.solved[2]?.verified == false && progress.solved[2]?.trace.isEmpty == true)
        // drop removes the result; the frontier is unchanged; dropping an absent level changes nothing.
        progress.drop(level: level)
        #expect(progress.solved[level] == nil && progress.frontier == level + 1)
        progress.drop(level: 77)
        #expect(progress.solved.count == 2)
    }

    @Test func tracesEncodeAndTheReplayModeAwardsNothing() throws {
        let progress: Progress = try Self.honest([1, 2])
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"trace\":["))
        #expect(text.contains("\"verified\":true"))
        let old: Data = Data("{\"frontier\":3,\"solved\":[{\"bestEdits\":5,\"level\":1,\"stars\":2}]}".utf8)
        let restored: Progress = try JSONDecoder().decode(Progress.self, from: old)
        #expect(restored.solved[1] == Progress.Result(bestEdits: 5, stars: 2))
        #expect(restored.solved[1]?.verified == false && restored.solved[1]?.trace.isEmpty == true)
        let reencoded: String = String(decoding: try restored.encoded(), as: UTF8.self)
        #expect(reencoded == "{\"frontier\":3,\"solved\":[{\"bestEdits\":5,\"level\":1,\"stars\":2,\"trace\":[],"
            + "\"verified\":false}]}")
        // The result alone decodes without trace and verified too.
        let bare: Data = Data("{\"bestEdits\":4,\"stars\":3}".utf8)
        #expect(try JSONDecoder().decode(Progress.Result.self, from: bare) == Progress.Result(bestEdits: 4, stars: 3))
        // Every action kind round trips in a trace.
        let actions: [Action] = [.phase(1, 3), .hold(0, 2, 4), .release(0, 2), .step(7), .rewind]
        let encodedActions: Data = try JSONEncoder().encode(actions)
        #expect(try JSONDecoder().decode([Action].self, from: encodedActions) == actions)
        // The replay mode.
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let replay: ChronoConstellatorMode = .replay(level: 48)
        let replayData: Data = try encoder.encode(replay)
        #expect(String(decoding: replayData, as: UTF8.self) == "{\"level\":48,\"mode\":\"replay\"}")
        #expect(try JSONDecoder().decode(ChronoConstellatorMode.self, from: replayData) == replay)
        #expect(!replay.awardsStars && !replay.opensLevels)
        #expect(replay.budget(base: 5) == 5)
        #expect(ChronoConstellatorMode.campaign.awardsStars && ChronoConstellatorMode.daily(level: 3).awardsStars)
        #expect(ChronoConstellatorFeedbackPlan.modeName(replay) == "replay")
    }

    @Test func editedStarsEditsStepsIllegalAndOverlongTracesAreDropped() throws {
        let levels: [Int] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        Core.prewarm(levels)
        let progress: Progress = try Self.honest(levels)
        // Level 4: stars edited.
        var tampered: Progress = try Self.edited(progress, level: 4) { (entry: inout [String: Any]) in
            entry["stars"] = 2
        }
        // Level 5: edits edited up.
        tampered = try Self.edited(tampered, level: 5) { (entry: inout [String: Any]) in
            entry["bestEdits"] = ((entry["bestEdits"] as? Int) ?? 0) + 1
        }
        // Level 6: edits edited down (still three stars: only the replay's edit count sees it).
        try #require(try Self.smallest(6) >= 1)
        tampered = try Self.edited(tampered, level: 6) { (entry: inout [String: Any]) in
            entry["bestEdits"] = ((entry["bestEdits"] as? Int) ?? 0) - 1
        }
        #expect(tampered.solved[6]?.stars == 3)
        // Level 7: one trace step changed: the last phase change removed (the play cannot win).
        var changed: [Action] = try Self.witness(7)
        try #require(changed.count >= 2)
        changed.remove(at: changed.count - 2)
        tampered = try Self.retraced(tampered, level: 7, changed)
        // Level 3: the final step shortened to one tick (level 3 first wins on tick 6, so the play does not win).
        var shortened: [Action] = try Self.witness(3)
        shortened[shortened.count - 1] = .step(1)
        let generated3: ChronoConstellatorGenerated = try Core.generated(number: 3)
        var check: ChronoConstellatorPlay = try Core.freshPlay(of: generated3.level)
        for action in shortened { try check.apply(action, expecting: check.fingerprint) }
        try #require(check.stage != .won)
        tampered = try Self.retraced(tampered, level: 3, shortened)
        // Level 9: an illegal trace (a star index out of range).
        tampered = try Self.retraced(tampered, level: 9, [Action.phase(99, 0)] + (try Self.witness(9)))
        // Level 10: an illegal trace (a step of 0 ticks).
        tampered = try Self.retraced(tampered, level: 10, [Action.step(0)] + (try Self.witness(10)))
        // Level 11: an illegal trace (a phase change after the step: not at tick 0).
        tampered = try Self.retraced(tampered, level: 11, (try Self.witness(11)) + [Action.phase(0, 0)])
        // Level 12: an over-long trace (rewinds at tick 0 before the witness, 65 actions, otherwise a legal win).
        let witness12: [Action] = try Self.witness(12)
        var overlong: [Action] = []
        for _ in 0..<(Reconciliation.maxTraceLength + 1 - witness12.count) { overlong.append(.rewind) }
        overlong += witness12
        #expect(overlong.count == 65 && Reconciliation.maxTraceLength == 64)
        tampered = try Self.retraced(tampered, level: 12, overlong)
        // The edge: the same padding to exactly 64 actions verifies.
        let edge: [Action] = Array(overlong.dropFirst())
        let honest12: Progress.Result = try #require(progress.solved[12])
        let edgeResult: Progress.Result = Progress.Result(bestEdits: honest12.bestEdits, stars: honest12.stars,
                                                          trace: edge, verified: true)
        #expect(Reconciliation.verifies(level: 12, result: edgeResult))
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(tampered)
        #expect(reconciled.dropped == 9)
        let expectedKept: [Int] = [8, 13, 14, 15]
        #expect(reconciled.progress.solved.keys.sorted() == expectedKept)
        for level in expectedKept { #expect(reconciled.progress.solved[level] == progress.solved[level]) }
        #expect(reconciled.progress.frontier == progress.frontier)
    }

    @Test func untracedResultsAreKeptAndTheFrontierStaysAsSaved() throws {
        var progress: Progress = try Self.honest([9])
        progress.record(level: 3, edits: 12, smallest: 5)
        // A daily traced win beyond the frontier.
        let daily: [Action] = try Self.witness(60)
        progress.record(level: 60, edits: try Self.spent(60, daily), smallest: try Self.smallest(60),
                        mode: .daily(level: 60), trace: daily)
        #expect(progress.frontier == 10)
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
        #expect(reconciled.progress.solved[3]?.verified == false)
        #expect(reconciled.progress.frontier == 10)
        // Dropping never lowers the frontier.
        let tampered: Progress = try Self.edited(progress, level: 9) { (entry: inout [String: Any]) in
            entry["stars"] = 1
        }
        let after: (progress: Progress, dropped: Int) = Reconciliation.reconcile(tampered)
        #expect(after.dropped == 1 && after.progress.frontier == 10 && after.progress.solved[9] == nil)
        // A result claimed verified without a trace, or at a level outside 1 … 100, never verifies.
        let empty: Progress.Result = Progress.Result(bestEdits: 2, stars: 3, trace: [], verified: true)
        #expect(!Reconciliation.verifies(level: 1, result: empty))
        let claimed: Progress = try Self.edited(progress, level: 3) { (entry: inout [String: Any]) in
            entry["verified"] = true
        }
        let claimedAfter: (progress: Progress, dropped: Int) = Reconciliation.reconcile(claimed)
        #expect(claimedAfter.dropped == 1 && claimedAfter.progress.solved[3] == nil)
        let honest9: Progress.Result = try #require(progress.solved[9])
        #expect(Reconciliation.verifies(level: 9, result: honest9))
        #expect(!Reconciliation.verifies(level: 0, result: honest9))
        #expect(!Reconciliation.verifies(level: 101, result: honest9))
    }

    @Test func netTraceCancelsUndoneActionsAndRestoresRedoneOnes() throws {
        // Hand-made records: phase, hold, undo, undo, redo, step 5, redo (nothing to redo), rewind
        // → phase, step, rewind.
        let kinds: [ChronoConstellatorRecordKind] = [.phase, .hold, .undo, .undo, .redo, .step, .redo, .rewind]
        let actions: [Action?] = [.phase(0, 1), .hold(1, 2, 3), nil, nil, nil, .step(5), nil, .rewind]
        var records: [ChronoConstellatorRecord] = []
        for index in kinds.indices {
            records.append(ChronoConstellatorRecord(schema: 1, seed: 1, tick: 0, kind: kinds[index],
                                                    action: actions[index], previous: "a", next: "b"))
        }
        let expected: [Action] = [.phase(0, 1), .step(5), .rewind]
        #expect(Reconciliation.netTrace(records) == expected)
        #expect(Reconciliation.netTrace([]).isEmpty)
        // A redo after a new action restores nothing (the new action cleared the redo stack).
        let clearedKinds: [ChronoConstellatorRecordKind] = [.release, .undo, .phase, .redo]
        let clearedActions: [Action?] = [.release(0, 4), nil, .phase(2, 0), nil]
        var cleared: [ChronoConstellatorRecord] = []
        for index in clearedKinds.indices {
            cleared.append(ChronoConstellatorRecord(schema: 1, seed: 1, tick: 0, kind: clearedKinds[index],
                                                    action: clearedActions[index], previous: "a", next: "b"))
        }
        #expect(Reconciliation.netTrace(cleared) == [Action.phase(2, 0)])

        // A real play of level 48 with detours undone and redone: its net trace is the hand-computed list, replays to
        // the same fingerprint and verifies.
        let level: Int = 48
        let generated: ChronoConstellatorGenerated = try Core.generated(number: level)
        let best: [Action] = try Self.witness(level)
        // At least two phase changes, so one-tick and two-tick steps after the first cannot win.
        try #require(try Self.smallest(level) >= 2 && best.count >= 3)
        guard case .phase(let star, let offset) = best[0] else {
            Issue.record("the witness starts with a phase change")
            return
        }
        let length: Int = generated.level.stars[star].length
        let detour: Action = .phase(star, (offset + 1) % length)
        var play: ChronoConstellatorPlay = try Core.freshPlay(of: generated.level)
        try play.apply(best[0], expecting: play.fingerprint)
        try play.apply(detour, expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        try play.undo()
        try play.apply(.step(1), expecting: play.fingerprint)
        try play.apply(.rewind, expecting: play.fingerprint)
        try play.apply(.step(2), expecting: play.fingerprint)
        try play.undo()
        for index in 1..<best.count { try play.apply(best[index], expecting: play.fingerprint) }
        #expect(play.stage == .won)
        var handNet: [Action] = [best[0], Action.step(1), Action.rewind]
        for index in 1..<best.count { handNet.append(best[index]) }
        let net: [Action] = Reconciliation.netTrace(play.records)
        #expect(net == handNet)
        var again: ChronoConstellatorPlay = try Core.freshPlay(of: generated.level)
        for action in net { try again.apply(action, expecting: again.fingerprint) }
        #expect(again.fingerprint == play.fingerprint)
        let stars: Int = Progress.stars(edits: play.spent, smallest: generated.difficulty.smallest)
        let result: Progress.Result = Progress.Result(bestEdits: play.spent, stars: stars, trace: net, verified: true)
        #expect(Reconciliation.verifies(level: level, result: result))
    }
}
