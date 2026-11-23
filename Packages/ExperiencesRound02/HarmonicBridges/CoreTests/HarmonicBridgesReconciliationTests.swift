// HarmonicBridgesReconciliationTests — feature 417 (R02-G12-07) T-R02G1207-002 (FR-R02G1207-001, 003; SC-R02G1207-001,
// 003; clarifications Q1, Q2, Q4; research R6, R7). Every certified level's witness, stored as a trace with the witness
// action count and the stars by rule, verifies (five groups of 20 levels); an edited star count, actions spent below the
// trace's actions, a changed trace step, an illegal action, an action after the win, an unwon trace and an overlong
// trace are dropped and counted; untraced results are kept unverified; the frontier is unchanged; the effective actions
// of record sequences with undo and redo (a failed test undone included) match the play's applied actions; the
// replacement rules of a traced record; Codable round trips and the decoding of schema 1 and 2 JSON; the replay mode's
// rules and encoding. Test data uses explicit types and plain loops (CI type-check rule).
@testable import HarmonicBridgesCore
import Foundation
import Testing

@Suite struct HarmonicBridgesReconciliationTests {
    typealias Progress = HarmonicBridgesProgress
    typealias Result = HarmonicBridgesProgress.Result
    typealias Mode = HarmonicBridgesMode
    typealias Play = HarmonicBridgesPlay
    typealias Action = HarmonicBridgesAction
    typealias Core = HarmonicBridgesExperienceCore
    typealias Reconciliation = HarmonicBridgesReconciliation

    /// The witness result of certified level `number`: its witness actions as the trace, the witness action count as
    /// the actions spent, and the stars by rule.
    static func witnessResult(_ number: Int) throws -> Result {
        let certified: HarmonicBridgesGenerated = try Core.generated(number: number)
        let trace: [Action] = certified.actions
        let count: Int = trace.count
        return Result(actionsSpent: count, stars: Progress.stars(actionsSpent: count, certified: count),
                      trace: trace, verified: true)
    }

    /// Checks that every witness of levels `first` … `last` verifies and spends exactly its action count.
    static func checkWitnesses(_ first: Int, _ last: Int) throws {
        for number in first...last {
            let result: Result = try Self.witnessResult(number)
            #expect(Reconciliation.verifies(level: number, result: result), "level \(number)")
            #expect(result.trace.count <= Reconciliation.maxTraceLength)
            #expect(result.trace.last == Action.test, "level \(number)")
            let certified: HarmonicBridgesGenerated = try Core.generated(number: number)
            var play: Play = try Core.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            #expect(play.stage == .won)
            #expect(play.actionsSpent == result.actionsSpent, "level \(number)")
            #expect(result.stars == 3)
        }
    }

    /// The index of the first string of `level` that is not locked.
    static func unlockedString(_ level: HarmonicBridgesLevel) throws -> Int {
        var found: Int? = nil
        for index in level.strings.indices where !level.strings[index].locked {
            found = index
            break
        }
        return try #require(found)
    }

    /// A peg other than `peg` (1 … 12).
    static func otherPeg(_ peg: Int) -> Int { peg == 1 ? 2 : 1 }

    // MARK: Witnesses

    @Test func witnessesOfBand1Verify() throws { try Self.checkWitnesses(1, 20) }
    @Test func witnessesOfBand2Verify() throws { try Self.checkWitnesses(21, 40) }
    @Test func witnessesOfBand3Verify() throws { try Self.checkWitnesses(41, 60) }
    @Test func witnessesOfBand4Verify() throws { try Self.checkWitnesses(61, 80) }
    @Test func witnessesOfBand5Verify() throws { try Self.checkWitnesses(81, 100) }

    @Test func honestHigherActionsVerifyWithTheirStars() throws {
        let witness: Result = try Self.witnessResult(4)
        let count: Int = witness.actionsSpent
        for extra in 0...5 {
            let spent: Int = count + extra
            let result: Result = Result(actionsSpent: spent, stars: Progress.stars(actionsSpent: spent, certified: count),
                                        trace: witness.trace, verified: true)
            #expect(Reconciliation.verifies(level: 4, result: result))
        }
    }

    // MARK: Tampering

    @Test func tamperedResultsAreDroppedAndCounted() throws {
        let certified: HarmonicBridgesGenerated = try Core.generated(number: 5)
        let witness: Result = try Self.witnessResult(5)
        let trace: [Action] = witness.trace
        let count: Int = witness.actionsSpent
        #expect(count >= 2)
        var tampered: [Result] = []
        // Edited stars.
        tampered.append(Result(actionsSpent: count, stars: 2, trace: trace, verified: true))
        tampered.append(Result(actionsSpent: count + 5, stars: 3, trace: trace, verified: true))
        // Actions spent below the actions the trace spends (stars still by rule).
        tampered.append(Result(actionsSpent: count - 1,
                               stars: Progress.stars(actionsSpent: count - 1, certified: count),
                               trace: trace, verified: true))
        // A changed step: the test becomes a tuning of the first tuned string back to its starting peg (no win).
        var changed: [Action] = trace
        guard case .tune(let firstString, _) = trace[0] else {
            Issue.record("the witness does not start with a tuning")
            return
        }
        let startPeg: Int = certified.level.startingPegs[firstString]
        changed[changed.count - 1] = Action.tune(firstString, startPeg)
        tampered.append(Result(actionsSpent: count, stars: 3, trace: changed, verified: true))
        // A changed step: the first tuning moved to another peg of the same string.
        var moved: [Action] = trace
        if case .tune(let string, let peg) = trace[0] {
            var other: Int = Self.otherPeg(peg)
            if other == certified.level.startingPegs[string] { other = peg == 3 ? 4 : 3 }
            moved[0] = Action.tune(string, other)
        }
        if !HarmonicBridgesSolver.wins(certified.level, actions: moved) {
            tampered.append(Result(actionsSpent: count, stars: 3, trace: moved, verified: true))
        }
        // Illegal actions first: an unknown string, a peg outside 1 … 12.
        var unknown: [Action] = [Action.tune(-1, 1)]
        unknown.append(contentsOf: trace)
        tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: unknown, verified: true))
        var badPeg: [Action] = [Action.tune(firstString, 13)]
        badPeg.append(contentsOf: trace)
        tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: badPeg, verified: true))
        // An action after the win (the play is final).
        var after: [Action] = trace
        after.append(Action.test)
        tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: after, verified: true))
        // An unwon trace (the test left out).
        var short: [Action] = trace
        short.removeLast()
        tampered.append(Result(actionsSpent: count, stars: 3, trace: short, verified: true))
        // An early test (the crossing breaks: the play fails).
        var early: [Action] = [Action.test]
        early.append(contentsOf: trace)
        tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: early, verified: true))
        // Verified but without a trace.
        tampered.append(Result(actionsSpent: count, stars: 3, trace: [], verified: true))

        for result in tampered {
            #expect(!Reconciliation.verifies(level: 5, result: result))
            let entries: Data = try Self.progressData(frontier: 12, level: 5, result: result)
            let loaded: Progress = try JSONDecoder().decode(Progress.self, from: entries)
            let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(loaded)
            #expect(outcome.dropped == 1)
            #expect(outcome.progress.solved[5] == nil)
            #expect(outcome.progress.frontier == 12)
        }
        // A level outside 1 … 100 never verifies.
        #expect(!Reconciliation.verifies(level: 0, result: witness))
        #expect(!Reconciliation.verifies(level: 101, result: witness))
        // The witness of level 5 is not a solution of level 6.
        let other: HarmonicBridgesGenerated = try Core.generated(number: 6)
        if !HarmonicBridgesSolver.wins(other.level, actions: trace) {
            #expect(!Reconciliation.verifies(level: 6, result: witness))
        }
    }

    @Test func overlongTracesNeverVerify() throws {
        #expect(Reconciliation.maxTraceLength == 64)
        #expect(HarmonicBridgesLevel.budgets.upperBound <= Reconciliation.maxTraceLength)
        let certified: HarmonicBridgesGenerated = try Core.generated(number: 2)
        let witness: Result = try Self.witnessResult(2)
        let string: Int = try Self.unlockedString(certified.level)
        let start: Int = certified.level.startingPegs[string]
        let away: Int = Self.otherPeg(start)
        // Pairs of tunings away and back before the witness keep it a winning play while the budget lasts: every
        // tuning must leave the budget unspent (tunings ≤ budget − 1), the test may spend the last action.
        let pairs: Int = (certified.level.budget - witness.trace.count) / 2
        var longest: [Action] = []
        for _ in 0..<pairs {
            longest.append(Action.tune(string, away))
            longest.append(Action.tune(string, start))
        }
        longest.append(contentsOf: witness.trace)
        #expect(longest.count <= Reconciliation.maxTraceLength)
        let spent: Int = longest.count
        let fits: Result = Result(actionsSpent: spent,
                                  stars: Progress.stars(actionsSpent: spent, certified: witness.trace.count),
                                  trace: longest, verified: true)
        #expect(Reconciliation.verifies(level: 2, result: fits))
        // A trace over 64 actions is refused before any replay.
        var overlong: [Action] = []
        while overlong.count + witness.trace.count <= Reconciliation.maxTraceLength {
            overlong.append(Action.tune(string, away))
            overlong.append(Action.tune(string, start))
        }
        overlong.append(contentsOf: witness.trace)
        #expect(overlong.count > Reconciliation.maxTraceLength)
        let tooLong: Result = Result(actionsSpent: overlong.count, stars: 1, trace: overlong, verified: true)
        #expect(!Reconciliation.verifies(level: 2, result: tooLong))
        let data: Data = try Self.progressData(frontier: 3, level: 2, result: tooLong)
        let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(
            try JSONDecoder().decode(Progress.self, from: data))
        #expect(outcome.dropped == 1)
        #expect(outcome.progress.frontier == 3)
    }

    @Test func reconcileKeepsHonestAndUntracedResults() throws {
        var progress: Progress = Progress()
        var changed: Bool = false
        progress.open(through: 40)
        for number in 1...3 {
            let witness: Result = try Self.witnessResult(number)
            changed = progress.record(level: number, actionsSpent: witness.actionsSpent,
                                      certified: witness.actionsSpent, trace: witness.trace)
            #expect(changed)
        }
        progress.record(level: 7, actionsSpent: 9, certified: 3)                                  // untraced
        progress.record(level: 9, actionsSpent: 2, certified: 3, mode: .daily(level: 9))          // untraced
        let witness: Result = try Self.witnessResult(8)
        progress.record(level: 8, actionsSpent: witness.actionsSpent, certified: witness.actionsSpent,
                        mode: .daily(level: 8), trace: witness.trace)
        let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(outcome.dropped == 0)
        #expect(outcome.progress == progress)
        #expect(outcome.progress.frontier == 40)
        #expect(outcome.progress.solved[7]?.verified == false)
        #expect(outcome.progress.solved[7]?.trace.isEmpty == true)
        #expect(outcome.progress.solved[1]?.verified == true)
        #expect(outcome.progress.solved[8]?.verified == true)

        // A tampered level among honest ones: only it is dropped; the frontier stays.
        let tampered: Result = Result(actionsSpent: witness.actionsSpent, stars: 1, trace: witness.trace,
                                      verified: true)
        var honest: Progress = progress
        honest.drop(level: 8)
        let honestText: String = String(decoding: try honest.encoded(), as: UTF8.self)
        let tamperedText: String = String(decoding: try Self.progressData(frontier: 40, level: 8, result: tampered),
                                          as: UTF8.self)
        let entryStart: String.Index = try #require(tamperedText.range(of: "[")).upperBound
        let entryText: String = String(tamperedText[entryStart...].dropLast(2))
        let mixedText: String = String(honestText.dropLast(2)) + "," + entryText + "]}"
        let loaded: Progress = try JSONDecoder().decode(Progress.self, from: Data(mixedText.utf8))
        #expect(loaded.solved.count == honest.solved.count + 1)
        let mixed: (progress: Progress, dropped: Int) = Reconciliation.reconcile(loaded)
        #expect(mixed.dropped == 1)
        #expect(mixed.progress == honest)
        #expect(mixed.progress.frontier == 40)
    }

    // MARK: Net trace

    @Test func netTraceFollowsUndoAndRedo() throws {
        let certified: HarmonicBridgesGenerated = try Core.generated(number: 6)
        let level: HarmonicBridgesLevel = certified.level
        let witness: [Action] = certified.actions
        let string: Int = try Self.unlockedString(level)
        let start: Int = level.startingPegs[string]
        let away: Action = Action.tune(string, Self.otherPeg(start))
        let back: Action = Action.tune(string, start)
        var thirdPeg: Int = 3
        while thirdPeg == start || thirdPeg == Self.otherPeg(start) { thirdPeg += 1 }
        let third: Action = Action.tune(string, thirdPeg)
        var play: Play = try Core.freshPlay(of: level)
        // A tuning, then its undo: nothing effective.
        try play.apply(away, expecting: play.fingerprint)
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        // Redo brings it back.
        try play.redo()
        var expected: [Action] = [away]
        #expect(Reconciliation.netTrace(play.records) == expected)
        // Tuning back, undone twice and redone twice.
        try play.apply(back, expecting: play.fingerprint)
        try play.undo()
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        try play.redo()
        try play.redo()
        expected.append(back)
        #expect(Reconciliation.netTrace(play.records) == expected)
        // An undo then a new action clears the redo stack.
        try play.undo()
        try play.apply(third, expecting: play.fingerprint)
        expected = [away, third]
        #expect(Reconciliation.netTrace(play.records) == expected)
        #expect(throws: HarmonicBridgesError.self) { try play.redo() }
        // Undo both: back at the start pegs.
        try play.undo()
        try play.undo()
        expected = []
        #expect(Reconciliation.netTrace(play.records) == expected)
        // A test that breaks (the play fails), then its undo: the test is not effective.
        try play.apply(Action.test, expecting: play.fingerprint)
        #expect(play.stage == .failed)
        try play.undo()
        #expect(Reconciliation.netTrace(play.records) == expected)
        // The witness wins.
        for action in witness {
            try play.apply(action, expecting: play.fingerprint)
            expected.append(action)
        }
        #expect(play.stage == .won)
        let net: [Action] = Reconciliation.netTrace(play.records)
        #expect(net == expected)
        // The net trace replays to the same fingerprint; the actions spent for the stars count the undone ones too.
        var fresh: Play = try Core.freshPlay(of: level)
        for action in net {
            try fresh.apply(action, expecting: fresh.fingerprint)
        }
        #expect(fresh.fingerprint == play.fingerprint)
        let spent: Int = Progress.actionsSpent(play)
        #expect(spent > net.count)
        let result: Result = Result(actionsSpent: spent,
                                    stars: Progress.stars(actionsSpent: spent, certified: witness.count),
                                    trace: net, verified: true)
        #expect(Reconciliation.verifies(level: 6, result: result))
    }

    @Test func netTraceMatchesThePlayOverMixedSequences() throws {
        for number in [10, 33, 57, 88] {
            let certified: HarmonicBridgesGenerated = try Core.generated(number: number)
            let level: HarmonicBridgesLevel = certified.level
            let string: Int = try Self.unlockedString(level)
            var play: Play = try Core.freshPlay(of: level)
            var state: UInt64 = UInt64(number) &* 2_654_435_761
            for _ in 0..<40 {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let choice: UInt64 = (state >> 33) % 4
                if choice == 0 {
                    if play.canUndo { try play.undo() }
                } else if choice == 1 {
                    if play.canRedo { try play.redo() }
                } else if play.stage == .playing && play.actionsLeft > 2 {
                    let peg: Int = Int((state >> 40) % 12) + 1
                    if peg != play.pegs[string] {
                        try play.apply(Action.tune(string, peg), expecting: play.fingerprint)
                    }
                }
                if play.stage == .failed, play.canUndo { try play.undo() }
            }
            let net: [Action] = Reconciliation.netTrace(play.records)
            var fresh: Play = try Core.freshPlay(of: level)
            for action in net {
                try fresh.apply(action, expecting: fresh.fingerprint)
            }
            #expect(fresh.pegs == play.pegs, "level \(number)")
            #expect(fresh.actionsSpent == play.actionsSpent, "level \(number)")
            #expect(fresh.stage == play.stage, "level \(number)")
            #expect(fresh.fingerprint == play.fingerprint, "level \(number)")
        }
    }

    // MARK: Record rules

    @Test func tracedRecordReplacesOnlyWhenBetter() throws {
        let traceA: [Action] = [Action.tune(0, 1), Action.test]
        let traceB: [Action] = [Action.tune(0, 2), Action.test]
        let traceC: [Action] = [Action.test]
        var progress: Progress = Progress()
        var changed: Bool = false
        changed = progress.record(level: 4, actionsSpent: 6, certified: 3, trace: traceA)
        #expect(changed)
        #expect(progress.solved[4] == Result(actionsSpent: 6, stars: 1, trace: traceA, verified: true))
        #expect(progress.frontier == 5)
        // A tie keeps the earlier trace; a worse result keeps it too.
        changed = progress.record(level: 4, actionsSpent: 6, certified: 3, trace: traceB)
        #expect(!changed)
        changed = progress.record(level: 4, actionsSpent: 7, certified: 3, trace: traceB)
        #expect(!changed)
        #expect(progress.solved[4]?.trace == traceA)
        // Equal actions, more stars (a larger certified count) replaces.
        changed = progress.record(level: 4, actionsSpent: 6, certified: 4, trace: traceB)
        #expect(changed)
        #expect(progress.solved[4] == Result(actionsSpent: 6, stars: 2, trace: traceB, verified: true))
        // Fewer actions replace.
        changed = progress.record(level: 4, actionsSpent: 3, certified: 3, trace: traceC)
        #expect(changed)
        #expect(progress.solved[4] == Result(actionsSpent: 3, stars: 3, trace: traceC, verified: true))
        // A traced result replaces an untraced worse one.
        progress.record(level: 9, actionsSpent: 8, certified: 3)
        #expect(progress.solved[9]?.verified == false)
        changed = progress.record(level: 9, actionsSpent: 5, certified: 3, trace: traceA)
        #expect(changed)
        #expect(progress.solved[9]?.verified == true)
        // Practice and replay record nothing and open nothing; daily records and opens nothing.
        let frontier: Int = progress.frontier
        changed = progress.record(level: 30, actionsSpent: 1, certified: 3, mode: .practice, trace: traceA)
        #expect(!changed)
        changed = progress.record(level: 30, actionsSpent: 1, certified: 3, mode: .replay(level: 30), trace: traceA)
        #expect(!changed)
        changed = progress.record(level: 30, actionsSpent: 1, certified: 3, mode: .replay(level: 30))
        #expect(!changed)
        #expect(progress.solved[30] == nil)
        changed = progress.record(level: 30, actionsSpent: 1, certified: 3, mode: .daily(level: 30), trace: traceA)
        #expect(changed)
        #expect(progress.solved[30]?.verified == true)
        #expect(progress.frontier == frontier)
        // Outside 1 … 100 is ignored.
        changed = progress.record(level: 0, actionsSpent: 1, certified: 3, trace: traceA)
        #expect(!changed)
        changed = progress.record(level: 101, actionsSpent: 1, certified: 3, trace: traceA)
        #expect(!changed)
        // Drop removes a result and keeps the frontier; dropping nothing changes nothing.
        progress.drop(level: 4)
        #expect(progress.solved[4] == nil)
        #expect(progress.frontier == frontier)
        let before: Progress = progress
        progress.drop(level: 50)
        #expect(progress == before)
    }

    // MARK: Codable

    @Test func tracedProgressRoundTrips() throws {
        var progress: Progress = Progress()
        for number in 1...4 {
            let witness: Result = try Self.witnessResult(number)
            progress.record(level: number, actionsSpent: witness.actionsSpent, certified: witness.actionsSpent,
                            trace: witness.trace)
        }
        progress.record(level: 12, actionsSpent: 5, certified: 3, opensNext: false)
        let data: Data = try progress.encoded()
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        #expect(decoded == progress)
        #expect(try decoded.encoded() == data)
        #expect(decoded.solved[1]?.verified == true)
        #expect(decoded.solved[12]?.verified == false)
        // A result encodes its trace and verified flag, also when untraced.
        var single: Progress = Progress()
        single.record(level: 1, actionsSpent: 2, certified: 3)
        #expect(String(decoding: try single.encoded(), as: UTF8.self)
            == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,\"trace\":[],\"verified\":false}]}")
        var traced: Progress = Progress()
        traced.record(level: 1, actionsSpent: 2, certified: 3, trace: [Action.tune(2, 3), Action.test])
        #expect(String(decoding: try traced.encoded(), as: UTF8.self)
            == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,"
            + "\"trace\":[{\"tune\":{\"_0\":2,\"_1\":3}},{\"test\":{}}],\"verified\":true}]}")
    }

    @Test func schemaTwoJSONDecodesUnverified() throws {
        let old: String = "{\"frontier\":5,\"solved\":[{\"level\":1,\"actionsSpent\":2,\"stars\":3},"
            + "{\"level\":4,\"actionsSpent\":9,\"stars\":1}]}"
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: Data(old.utf8))
        #expect(decoded.frontier == 5)
        #expect(decoded.solved[1] == Result(actionsSpent: 2, stars: 3))
        #expect(decoded.solved[1]?.trace.isEmpty == true)
        #expect(decoded.solved[1]?.verified == false)
        #expect(decoded.solved[4] == Result(actionsSpent: 9, stars: 1, trace: [], verified: false))
        let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(decoded)
        #expect(outcome.dropped == 0)
        #expect(outcome.progress == decoded)
        // A result alone also decodes without trace and verified.
        let single: Result = try JSONDecoder().decode(Result.self, from: Data("{\"actionsSpent\":3,\"stars\":2}".utf8))
        #expect(single == Result(actionsSpent: 3, stars: 2))
        let encoded: Data = try JSONEncoder().encode(Result(actionsSpent: 3, stars: 2,
                                                            trace: [Action.tune(1, 2)], verified: true))
        let back: Result = try JSONDecoder().decode(Result.self, from: encoded)
        #expect(back.trace == [Action.tune(1, 2)])
        #expect(back.verified)
    }

    @Test func replayModeRulesAndEncoding() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder: JSONDecoder = JSONDecoder()
        #expect(String(decoding: try encoder.encode(Mode.replay(level: 5)), as: UTF8.self)
            == "{\"level\":5,\"mode\":\"replay\"}")
        let modes: [Mode] = [.replay(level: 1), .replay(level: 100), .campaign, .practice, .daily(level: 3)]
        for mode in modes {
            #expect(try decoder.decode(Mode.self, from: try encoder.encode(mode)) == mode)
        }
        let bad: [String] = ["{\"mode\":\"replay\",\"level\":0}", "{\"mode\":\"replay\",\"level\":101}",
                             "{\"mode\":\"replay\"}"]
        for text in bad {
            #expect(throws: DecodingError.self) { try decoder.decode(Mode.self, from: Data(text.utf8)) }
        }
        let replay: Mode = .replay(level: 9)
        #expect(!replay.awardsStars)
        #expect(!replay.opensLevels)
        #expect(replay.budget(base: 17) == 17)
        #expect(replay != .daily(level: 9))
        #expect(HarmonicBridgesFeedbackPlan.modeName(replay) == "replay")
    }

    /// The JSON of progress with frontier `frontier` and the single won level `level` with `result`.
    static func progressData(frontier: Int, level: Int, result: Result) throws -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let resultData: Data = try encoder.encode(result)
        let resultText: String = String(decoding: resultData, as: UTF8.self)
        let entry: String = "{\"level\":\(level)," + resultText.dropFirst()
        let text: String = "{\"frontier\":\(frontier),\"solved\":[" + entry + "]}"
        return Data(text.utf8)
    }
}
