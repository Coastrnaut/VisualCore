// AcousticConstellatorReconciliationTests — feature 427 (R02-G13-07) T-R02G1307-002 (FR-R02G1307-001, 003;
// SC-R02G1307-001, 003; clarifications Q1, Q2, Q4; research R6, R7). Every certified level's witness, stored as a trace
// with the witness action count and the stars by rule, verifies (ten parallel groups of 10 levels); an edited star
// count, actions spent below the trace's actions, a changed trace step, an illegal action, an action after the win, an
// unwon trace, an early listen and an overlong trace are dropped and counted; untraced results are kept unverified; the
// frontier is unchanged; the effective actions of record sequences with undo and redo (a failed listen undone included)
// match the play's applied actions; the replacement rules of a traced record; Codable round trips and the decoding of
// schema 1 and 2 JSON; the replay mode's rules and encoding. Test data uses explicit types and plain loops (CI
// type-check rule). Modelled on feature 417's HarmonicBridgesReconciliationTests.
@testable import AcousticConstellatorCore
import Foundation
import Testing

@Suite struct AcousticConstellatorReconciliationTests {
    typealias Progress = AcousticConstellatorProgress
    typealias Result = AcousticConstellatorProgress.Result
    typealias Mode = AcousticConstellatorMode
    typealias Play = AcousticConstellatorPlay
    typealias Action = AcousticConstellatorAction
    typealias Core = AcousticConstellatorExperienceCore
    typealias Reconciliation = AcousticConstellatorReconciliation
    typealias Generated = AcousticConstellatorGenerated

    /// The witness result of certified level `number`: its witness actions as the trace, the witness action count as
    /// the actions spent, and the stars by rule.
    static func witnessResult(_ number: Int) throws -> Result {
        let certified: Generated = try Core.generated(number: number)
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
            #expect(result.trace.last == Action.listen, "level \(number)")
            let certified: Generated = try Core.generated(number: number)
            var play: Play = try Core.freshPlay(of: certified.level)
            for action in result.trace {
                try play.apply(action, expecting: play.fingerprint)
            }
            #expect(play.stage == .won)
            #expect(play.actionsSpent == result.actionsSpent, "level \(number)")
            #expect(result.stars == 3)
            var progress: Progress = Progress()
            progress.record(level: number, actionsSpent: result.actionsSpent, certified: result.actionsSpent,
                            trace: result.trace)
            let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
            #expect(outcome.dropped == 0, "level \(number)")
            #expect(outcome.progress == progress)
        }
    }

    /// A star of `level` that two nudges (+1 then −1) leave as it was: star 0.
    static let nudgedStar: Int = 0

    // MARK: Witnesses

    @Test func witnessesOfLevels1To10Verify() throws { try Self.checkWitnesses(1, 10) }
    @Test func witnessesOfLevels11To20Verify() throws { try Self.checkWitnesses(11, 20) }
    @Test func witnessesOfLevels21To30Verify() throws { try Self.checkWitnesses(21, 30) }
    @Test func witnessesOfLevels31To40Verify() throws { try Self.checkWitnesses(31, 40) }
    @Test func witnessesOfLevels41To50Verify() throws { try Self.checkWitnesses(41, 50) }
    @Test func witnessesOfLevels51To60Verify() throws { try Self.checkWitnesses(51, 60) }
    @Test func witnessesOfLevels61To70Verify() throws { try Self.checkWitnesses(61, 70) }
    @Test func witnessesOfLevels71To80Verify() throws { try Self.checkWitnesses(71, 80) }
    @Test func witnessesOfLevels81To90Verify() throws { try Self.checkWitnesses(81, 90) }
    @Test func witnessesOfLevels91To100Verify() throws { try Self.checkWitnesses(91, 100) }

    @Test func honestHigherActionsVerifyWithTheirStars() throws {
        let witness: Result = try Self.witnessResult(4)
        let count: Int = witness.actionsSpent
        for extra in 0...5 {
            let spent: Int = count + extra
            let stars: Int = Progress.stars(actionsSpent: spent, certified: count)
            let result: Result = Result(actionsSpent: spent, stars: stars, trace: witness.trace, verified: true)
            #expect(Reconciliation.verifies(level: 4, result: result))
        }
    }

    // MARK: Tampering

    @Test func tamperedResultsAreDroppedAndCounted() throws {
        let certified: Generated = try Core.generated(number: 5)
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
        // A changed step: the listen becomes a nudge (no win).
        var changed: [Action] = trace
        changed[changed.count - 1] = Action.nudge(Self.nudgedStar, 1)
        tampered.append(Result(actionsSpent: count, stars: 3, trace: changed, verified: true))
        // A changed step: the first action replaced by a nudge of the opposite or another step.
        var moved: [Action] = trace
        switch trace[0] {
        case .nudge(let star, let step): moved[0] = Action.nudge(star, -step)
        case .link(let u, _), .unlink(let u, _): moved[0] = Action.nudge(u, 1)
        case .listen: moved[0] = Action.nudge(Self.nudgedStar, 1)
        }
        if !AcousticConstellatorSolver.wins(certified.level, actions: moved) {
            tampered.append(Result(actionsSpent: count, stars: 3, trace: moved, verified: true))
        }
        // Illegal actions first: an unknown star, a nudge step outside ±1, a self link.
        let illegal: [Action] = [Action.link(-1, 0), Action.nudge(Self.nudgedStar, 2), Action.link(0, 0),
                                 Action.unlink(0, certified.level.stars.count)]
        for bad in illegal {
            var withBad: [Action] = [bad]
            withBad.append(contentsOf: trace)
            tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: withBad, verified: true))
        }
        // An action after the win (the play is final).
        var after: [Action] = trace
        after.append(Action.listen)
        tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: after, verified: true))
        // An unwon trace (the listen left out).
        var short: [Action] = trace
        short.removeLast()
        tampered.append(Result(actionsSpent: count, stars: 3, trace: short, verified: true))
        // An early listen (the stars do not hold: the play fails and refuses the rest).
        var early: [Action] = [Action.listen]
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
        let other: Generated = try Core.generated(number: 6)
        if !AcousticConstellatorSolver.wins(other.level, actions: trace) {
            #expect(!Reconciliation.verifies(level: 6, result: witness))
        }
    }

    @Test func overlongTracesNeverVerify() throws {
        #expect(Reconciliation.maxTraceLength == 64)
        #expect(AcousticConstellatorLevel.budgets.upperBound <= Reconciliation.maxTraceLength)
        let certified: Generated = try Core.generated(number: 2)
        let witness: Result = try Self.witnessResult(2)
        let star: Int = Self.nudgedStar
        // Pairs of nudges (+1 then −1) before the witness keep it a winning play while the budget lasts: every link,
        // unlink and nudge must leave the budget unspent (≤ budget − 1), the listen may spend the last action.
        let pairs: Int = (certified.level.budget - witness.trace.count) / 2
        var longest: [Action] = []
        for _ in 0..<pairs {
            longest.append(Action.nudge(star, 1))
            longest.append(Action.nudge(star, -1))
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
            overlong.append(Action.nudge(star, 1))
            overlong.append(Action.nudge(star, -1))
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
        #expect(outcome.progress.solved[9]?.verified == false)
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
        let certified: Generated = try Core.generated(number: 6)
        let level: AcousticConstellatorLevel = certified.level
        let witness: [Action] = certified.actions
        let up: Action = Action.nudge(Self.nudgedStar, 1)
        let down: Action = Action.nudge(Self.nudgedStar, -1)
        let other: Action = Action.nudge(1, 1)
        var play: Play = try Core.freshPlay(of: level)
        // A nudge, then its undo: nothing effective.
        try play.apply(up, expecting: play.fingerprint)
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        // Redo brings it back.
        try play.redo()
        var expected: [Action] = [up]
        #expect(Reconciliation.netTrace(play.records) == expected)
        // Nudging back, undone twice and redone twice.
        try play.apply(down, expecting: play.fingerprint)
        try play.undo()
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        try play.redo()
        try play.redo()
        expected.append(down)
        #expect(Reconciliation.netTrace(play.records) == expected)
        // An undo then a new action clears the redo stack.
        try play.undo()
        try play.apply(other, expecting: play.fingerprint)
        expected = [up, other]
        #expect(Reconciliation.netTrace(play.records) == expected)
        #expect(throws: AcousticConstellatorError.self) { try play.redo() }
        // Undo both: back at the starting phases.
        try play.undo()
        try play.undo()
        expected = []
        #expect(Reconciliation.netTrace(play.records) == expected)
        // A listen that fails (the play fails), then its undo: the listen is not effective.
        try play.apply(Action.listen, expecting: play.fingerprint)
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
            let certified: Generated = try Core.generated(number: number)
            let level: AcousticConstellatorLevel = certified.level
            let starCount: Int = level.stars.count
            var play: Play = try Core.freshPlay(of: level)
            var state: UInt64 = UInt64(number) &* 2_654_435_761
            for _ in 0..<40 {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let choice: UInt64 = (state >> 33) % 5
                let star: Int = Int((state >> 40) % UInt64(starCount))
                let partner: Int = Int((state >> 48) % UInt64(starCount))
                if choice == 0 {
                    if play.canUndo { try play.undo() }
                } else if choice == 1 {
                    if play.canRedo { try play.redo() }
                } else if play.stage == .playing && play.actionsLeft > 2 {
                    let candidate: Action
                    if choice == 2 {
                        candidate = Action.nudge(star, (state >> 56) % 2 == 0 ? 1 : -1)
                    } else if choice == 3 {
                        candidate = Action.link(star, partner)
                    } else {
                        candidate = Action.unlink(star, partner)
                    }
                    do {
                        try play.check(candidate)
                        try play.apply(candidate, expecting: play.fingerprint)
                    } catch {
                        // A refused action changes nothing and records nothing.
                    }
                }
                if play.stage == .failed, play.canUndo { try play.undo() }
            }
            let net: [Action] = Reconciliation.netTrace(play.records)
            var fresh: Play = try Core.freshPlay(of: level)
            for action in net {
                try fresh.apply(action, expecting: fresh.fingerprint)
            }
            #expect(fresh.links == play.links, "level \(number)")
            #expect(fresh.phases == play.phases, "level \(number)")
            #expect(fresh.actionsSpent == play.actionsSpent, "level \(number)")
            #expect(fresh.stage == play.stage, "level \(number)")
            #expect(fresh.fingerprint == play.fingerprint, "level \(number)")
        }
    }

    // MARK: Record rules

    @Test func tracedRecordReplacesOnlyWhenBetter() throws {
        let traceA: [Action] = [Action.link(0, 1), Action.listen]
        let traceB: [Action] = [Action.nudge(0, 1), Action.listen]
        let traceC: [Action] = [Action.listen]
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
        #expect(progress.frontier == frontier)
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
            == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,\"trace\":[],"
            + "\"verified\":false}]}")
        var traced: Progress = Progress()
        traced.record(level: 1, actionsSpent: 2, certified: 3, trace: [Action.link(2, 3), Action.listen])
        #expect(String(decoding: try traced.encoded(), as: UTF8.self)
            == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,"
            + "\"trace\":[{\"link\":{\"_0\":2,\"_1\":3}},{\"listen\":{}}],\"verified\":true}]}")
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
                                                            trace: [Action.nudge(1, -1)], verified: true))
        let back: Result = try JSONDecoder().decode(Result.self, from: encoded)
        #expect(back.trace == [Action.nudge(1, -1)])
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
        #expect(Mode.campaign.awardsStars && Mode.daily(level: 9).awardsStars && !Mode.practice.awardsStars)
        #expect(AcousticConstellatorFeedbackPlan.modeName(replay) == "replay")
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
