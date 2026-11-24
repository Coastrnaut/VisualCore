// VoxelOrigamiReconciliationTests — feature 447 (R02-G15-07) T-R02G1507-002 (FR-R02G1507-001, 003; SC-R02G1507-001,
// 003; clarifications Q1, Q2, Q3). Every certified level's witness, stored as a trace with the witness turn count and
// the stars by rule, verifies (ten groups of 10 levels); an edited star count, actions spent below the trace's turns, a
// changed trace step, an illegal (refused) turn, a failing turn (collision and sweep), a turn after the win, an unwon
// trace and an overlong trace are dropped and counted; untraced results are kept unverified; the frontier is
// unchanged; the effective turns of record sequences with undo and redo (a failed turn undone included, and 4 levels
// of seeded mixed walks, SeededRandom seed 2_447) match the play; the replacement rules of a traced record; Codable
// round trips and the decoding of schema 1 and 2 JSON; the replay mode's rules and encoding. Test data uses explicit
// types and plain loops (CI type-check rule); each test well under 10 s. Modelled on feature 437's
// MoonlitMechanismReconciliationTests.
import Foundation
import Testing
import VisualCoreSimulation
@testable import VoxelOrigamiCore

@Suite struct VoxelOrigamiReconciliationTests {
    typealias Progress = VoxelOrigamiProgress
    typealias Result = VoxelOrigamiProgress.Result
    typealias Mode = VoxelOrigamiMode
    typealias Play = VoxelOrigamiPlay
    typealias Action = VoxelOrigamiAction
    typealias Core = VoxelOrigamiExperienceCore
    typealias Reconciliation = VoxelOrigamiReconciliation
    typealias Generated = VoxelOrigamiGenerated

    /// The seed of the mixed walks.
    static let seed: UInt64 = 2_447

    /// The witness result of certified level `number`: its plan's turns as the trace, the plan's turn count as the
    /// actions spent, and the stars by rule.
    static func witnessResult(_ number: Int) throws -> Result {
        let certified: Generated = try Core.generated(number: number)
        let trace: [Action] = certified.plan.turns
        let count: Int = trace.count
        return Result(actionsSpent: count, stars: Progress.stars(actionsSpent: count, certified: count),
                      trace: trace, verified: true)
    }

    /// Checks that every witness of levels `first` … `last` verifies and spends exactly its turn count.
    static func checkWitnesses(_ first: Int, _ last: Int) throws {
        for number in first...last {
            let result: Result = try Self.witnessResult(number)
            #expect(Reconciliation.verifies(level: number, result: result), "level \(number)")
            #expect(result.trace.count <= Reconciliation.maxTraceLength)
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

    /// The first group of ten levels of each witness test, 1, 11, … 91.
    static let witnessGroups: [Int] = [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]

    /// The first certified level (from `from`) whose plan has at least `minimum` turns.
    static func level(withPlanOf minimum: Int, from: Int) throws -> Int {
        for number in from...100 {
            if try Core.generated(number: number).plan.size >= minimum { return number }
        }
        Issue.record("no level with a plan of \(minimum) turns")
        return from
    }

    /// A turn the kernel accepts on a fresh play of certified level `number` that fails it with `collision` (when
    /// `collision`) or `sweep`, or nil when the start pose has none.
    static func failingTurn(level number: Int, collision: Bool) throws -> Action? {
        let certified: Generated = try Core.generated(number: number)
        let play: Play = try Core.freshPlay(of: certified.level)
        for hinge in 1..<certified.level.cubes.count {
            for step in [1, -1] {
                let action: Action = Action.turn(hinge, step)
                do {
                    try play.check(action)
                } catch {
                    continue
                }
                let refused: VoxelOrigamiFailure? = VoxelOrigamiLattice.check(certified.level.cubes,
                                                                              turns: play.turns, hinge: hinge,
                                                                              step: step)
                switch refused {
                case .collision?: if collision { return action }
                case .sweep?: if !collision { return action }
                default: break
                }
            }
        }
        return nil
    }

    // MARK: Witnesses

    @Test(arguments: witnessGroups)
    func witnessesOfTenLevelsVerify(first: Int) throws {
        try Self.checkWitnesses(first, first + 9)
    }

    @Test func honestHigherActionsVerifyWithTheirStars() throws {
        let number: Int = try Self.level(withPlanOf: 2, from: 4)
        let witness: Result = try Self.witnessResult(number)
        let count: Int = witness.actionsSpent
        for extra in 0...5 {
            let spent: Int = count + extra
            let stars: Int = Progress.stars(actionsSpent: spent, certified: count)
            let result: Result = Result(actionsSpent: spent, stars: stars, trace: witness.trace, verified: true)
            #expect(Reconciliation.verifies(level: number, result: result))
        }
    }

    // MARK: Tampering

    @Test func tamperedResultsAreDroppedAndCounted() throws {
        let number: Int = try Self.level(withPlanOf: 2, from: 5)
        let certified: Generated = try Core.generated(number: number)
        let witness: Result = try Self.witnessResult(number)
        let trace: [Action] = witness.trace
        let count: Int = witness.actionsSpent
        #expect(count >= 2)
        var tampered: [Result] = []
        // Edited stars.
        tampered.append(Result(actionsSpent: count, stars: 2, trace: trace, verified: true))
        tampered.append(Result(actionsSpent: count + 5, stars: 3, trace: trace, verified: true))
        // Actions spent below the turns the trace spends (stars still by rule).
        tampered.append(Result(actionsSpent: count - 1,
                               stars: Progress.stars(actionsSpent: count - 1, certified: count),
                               trace: trace, verified: true))
        // A changed step: the first turn reversed (kept only when the changed trace does not win anyway).
        var moved: [Action] = trace
        if case .turn(let hinge, let step) = trace[0] { moved[0] = Action.turn(hinge, -step) }
        if !VoxelOrigamiSolver.matches(certified.level, actions: moved) {
            tampered.append(Result(actionsSpent: count, stars: 3, trace: moved, verified: true))
        }
        // Illegal turns first: the root, an unknown hinge, a negative hinge, steps 0 and 2.
        let cubeCount: Int = certified.level.cubes.count
        let illegal: [Action] = [Action.turn(0, 1), Action.turn(cubeCount, 1), Action.turn(-1, 1),
                                 Action.turn(1, 0), Action.turn(1, 2)]
        for bad in illegal {
            var withBad: [Action] = [bad]
            withBad.append(contentsOf: trace)
            tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: withBad, verified: true))
        }
        // A turn after the win (the play is final).
        var after: [Action] = trace
        after.append(trace[0])
        tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: after, verified: true))
        // An unwon trace (the last turn left out).
        var short: [Action] = trace
        short.removeLast()
        tampered.append(Result(actionsSpent: count, stars: 3, trace: short, verified: true))
        // Verified but without a trace.
        tampered.append(Result(actionsSpent: count, stars: 3, trace: [], verified: true))

        for result in tampered {
            #expect(!Reconciliation.verifies(level: number, result: result))
            let entries: Data = try Self.progressData(frontier: 12, level: number, result: result)
            let loaded: Progress = try JSONDecoder().decode(Progress.self, from: entries)
            let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(loaded)
            #expect(outcome.dropped == 1)
            #expect(outcome.progress.solved[number] == nil)
            #expect(outcome.progress.frontier == 12)
        }
        // A level outside 1 … 100 never verifies.
        #expect(!Reconciliation.verifies(level: 0, result: witness))
        #expect(!Reconciliation.verifies(level: 101, result: witness))
        // The witness of this level is not a solution of the next one.
        let other: Generated = try Core.generated(number: number + 1)
        if !VoxelOrigamiSolver.matches(other.level, actions: trace) {
            #expect(!Reconciliation.verifies(level: number + 1, result: witness))
        }
    }

    @Test func failingTurnsNeverVerify() throws {
        var found: [Bool] = [false, false]
        for collision in [true, false] {
            for number in 1...100 {
                guard let bad = try Self.failingTurn(level: number, collision: collision) else { continue }
                let witness: Result = try Self.witnessResult(number)
                // The failing turn first: the play fails and refuses the rest.
                var first: [Action] = [bad]
                first.append(contentsOf: witness.trace)
                let spent: Int = first.count
                let early: Result = Result(actionsSpent: spent,
                                           stars: Progress.stars(actionsSpent: spent, certified: witness.trace.count),
                                           trace: first, verified: true)
                #expect(!Reconciliation.verifies(level: number, result: early), "level \(number)")
                // The failing turn alone: the play ends failed.
                let alone: Result = Result(actionsSpent: 1, stars: 3, trace: [bad], verified: true)
                #expect(!Reconciliation.verifies(level: number, result: alone), "level \(number)")
                let data: Data = try Self.progressData(frontier: 30, level: number, result: early)
                let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(
                    try JSONDecoder().decode(Progress.self, from: data))
                #expect(outcome.dropped == 1)
                #expect(outcome.progress.frontier == 30)
                found[collision ? 0 : 1] = true
                break
            }
        }
        #expect(found == [true, true], "a level with a colliding and a sweeping first turn")
    }

    @Test func overlongTracesNeverVerify() throws {
        #expect(Reconciliation.maxTraceLength == 64)
        #expect(VoxelOrigamiLevel.budgets.upperBound <= Reconciliation.maxTraceLength)
        let number: Int = try Self.level(withPlanOf: 2, from: 2)
        let certified: Generated = try Core.generated(number: number)
        let witness: Result = try Self.witnessResult(number)
        // Pairs of the first witness turn and its inverse before the witness keep it a winning play while the budget
        // lasts (the first turn alone never matches: the plan is minimal and has at least 2 turns).
        guard case .turn(let hinge, let step) = witness.trace[0] else { return }
        let pairs: Int = (certified.level.budget - witness.trace.count) / 2
        var longest: [Action] = []
        for _ in 0..<pairs {
            longest.append(Action.turn(hinge, step))
            longest.append(Action.turn(hinge, -step))
        }
        longest.append(contentsOf: witness.trace)
        #expect(longest.count <= Reconciliation.maxTraceLength)
        let spent: Int = longest.count
        let fits: Result = Result(actionsSpent: spent,
                                  stars: Progress.stars(actionsSpent: spent, certified: witness.trace.count),
                                  trace: longest, verified: true)
        #expect(Reconciliation.verifies(level: number, result: fits))
        // A trace over 64 turns is refused before any replay.
        var overlong: [Action] = []
        while overlong.count + witness.trace.count <= Reconciliation.maxTraceLength {
            overlong.append(Action.turn(hinge, step))
            overlong.append(Action.turn(hinge, -step))
        }
        overlong.append(contentsOf: witness.trace)
        #expect(overlong.count > Reconciliation.maxTraceLength)
        let tooLong: Result = Result(actionsSpent: overlong.count, stars: 1, trace: overlong, verified: true)
        #expect(!Reconciliation.verifies(level: number, result: tooLong))
        let data: Data = try Self.progressData(frontier: 3, level: number, result: tooLong)
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
        let number: Int = try Self.level(withPlanOf: 2, from: 6)
        let certified: Generated = try Core.generated(number: number)
        let level: VoxelOrigamiLevel = certified.level
        let witness: [Action] = certified.plan.turns
        guard case .turn(let hinge, let step) = witness[0] else { return }
        let up: Action = Action.turn(hinge, step)
        let down: Action = Action.turn(hinge, -step)
        var play: Play = try Core.freshPlay(of: level)
        // A turn, then its undo: nothing effective.
        try play.apply(up, expecting: play.fingerprint)
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        // Redo brings it back.
        try play.redo()
        var expected: [Action] = [up]
        #expect(Reconciliation.netTrace(play.records) == expected)
        // Turning back, undone twice and redone twice.
        try play.apply(down, expecting: play.fingerprint)
        try play.undo()
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        try play.redo()
        try play.redo()
        expected.append(down)
        #expect(Reconciliation.netTrace(play.records) == expected)
        // An undo then a new turn clears the redo stack.
        try play.undo()
        try play.apply(up, expecting: play.fingerprint)
        expected = [up, up]
        #expect(Reconciliation.netTrace(play.records) == expected)
        #expect(throws: VoxelOrigamiError.self) { try play.redo() }
        // Undo both: back at the start pose.
        try play.undo()
        try play.undo()
        expected = []
        #expect(Reconciliation.netTrace(play.records) == expected)
        // A failing turn (when the start pose has one), then its undo: the turn is not effective.
        var failing: Action? = try Self.failingTurn(level: number, collision: true)
        if failing == nil { failing = try Self.failingTurn(level: number, collision: false) }
        if let bad = failing {
            try play.apply(bad, expecting: play.fingerprint)
            #expect(play.stage == .failed)
            try play.undo()
            #expect(Reconciliation.netTrace(play.records) == expected)
        }
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
        #expect(Reconciliation.verifies(level: number, result: result))
        // The same trace claimed with the trace's own count (fewer than spent) also verifies: the rule is an upper
        // bound on the trace, not an equality.
        let lean: Result = Result(actionsSpent: net.count,
                                  stars: Progress.stars(actionsSpent: net.count, certified: witness.count),
                                  trace: net, verified: true)
        #expect(Reconciliation.verifies(level: number, result: lean))
    }

    @Test func netTraceMatchesThePlayOverMixedSequences() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for number in [10, 33, 57, 88] {
            let certified: Generated = try Core.generated(number: number)
            let level: VoxelOrigamiLevel = certified.level
            let cubeCount: Int = level.cubes.count
            var play: Play = try Core.freshPlay(of: level)
            for _ in 0..<40 {
                let choice: UInt64 = random.next() % 4
                let hinge: Int = 1 + Int(random.next() % UInt64(cubeCount - 1))
                let step: Int = random.next() % 2 == 0 ? 1 : -1
                if choice == 0 {
                    if play.canUndo { try play.undo() }
                } else if choice == 1 {
                    if play.canRedo { try play.redo() }
                } else if play.stage == .playing && play.actionsLeft > 2 {
                    let candidate: Action = Action.turn(hinge, step)
                    do {
                        try play.check(candidate)
                        try play.apply(candidate, expecting: play.fingerprint)
                    } catch {
                        // A refused turn changes nothing and records nothing.
                    }
                }
                if play.stage == .failed, play.canUndo { try play.undo() }
            }
            let net: [Action] = Reconciliation.netTrace(play.records)
            var fresh: Play = try Core.freshPlay(of: level)
            for action in net {
                try fresh.apply(action, expecting: fresh.fingerprint)
            }
            #expect(fresh.turns == play.turns, "level \(number)")
            #expect(fresh.pose == play.pose, "level \(number)")
            #expect(fresh.actionsSpent == play.actionsSpent, "level \(number)")
            #expect(fresh.stage == play.stage, "level \(number)")
            #expect(fresh.fingerprint == play.fingerprint, "level \(number)")
            #expect(net.count <= Progress.actionsSpent(play), "level \(number)")
        }
    }

    @Test func netTraceIgnoresRecordsWithoutAnAction() {
        let stray: VoxelOrigamiRecord = VoxelOrigamiRecord(schema: 1, seed: 1, index: 0, kind: .turn, action: nil,
                                                           previous: "", next: "")
        let undo: VoxelOrigamiRecord = VoxelOrigamiRecord(schema: 1, seed: 1, index: 0, kind: .undo, action: nil,
                                                          previous: "", next: "")
        let redo: VoxelOrigamiRecord = VoxelOrigamiRecord(schema: 1, seed: 1, index: 0, kind: .redo, action: nil,
                                                          previous: "", next: "")
        #expect(Reconciliation.netTrace([stray, undo, redo]).isEmpty)
        #expect(Reconciliation.netTrace([]).isEmpty)
    }

    // MARK: Record rules

    @Test func tracedRecordReplacesOnlyWhenBetter() throws {
        let traceA: [Action] = [Action.turn(1, 1), Action.turn(2, -1)]
        let traceB: [Action] = [Action.turn(3, 1), Action.turn(2, 1)]
        let traceC: [Action] = [Action.turn(1, -1)]
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
        traced.record(level: 1, actionsSpent: 2, certified: 3, trace: [Action.turn(2, -1), Action.turn(1, 1)])
        #expect(String(decoding: try traced.encoded(), as: UTF8.self)
            == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,"
            + "\"trace\":[{\"turn\":{\"_0\":2,\"_1\":-1}},{\"turn\":{\"_0\":1,\"_1\":1}}],"
            + "\"verified\":true}]}")
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
                                                            trace: [Action.turn(3, -1)], verified: true))
        let back: Result = try JSONDecoder().decode(Result.self, from: encoded)
        #expect(back.trace == [Action.turn(3, -1)])
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
        #expect(VoxelOrigamiFeedbackPlan.modeName(replay) == "replay")
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
