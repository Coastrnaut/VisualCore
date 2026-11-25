// StarlitCartoucheReconciliationTests — feature 457 (R02-G16-07) T-R02G1607-002 (contracts/api.md; research R2, R3, R5,
// R6, R7). Every certified level's witness, stored as a trace with the witness leg count and the stars by rule,
// verifies (ten groups of 10 levels); an edited star count, actions spent below the trace's legs, a changed trace
// step, a removed trace step, an illegal (refused) leg, a failing leg (the chart's check), a leg after the win, an
// unwon trace and an overlong trace are dropped and counted; untraced results are kept unverified; the frontier is
// unchanged; the effective legs of record sequences with undo and redo (a failed leg undone included, and 4 levels of
// seeded mixed walks, SeededRandom seed 2_457) match the play; the replacement rules of a traced record; Codable round
// trips and the decoding of JSON without trace and verified; the replay mode's rules and encoding. Test data uses
// explicit types and plain loops (CI type-check rule); each test well under 10 s. Modelled on feature 447's
// VoxelOrigamiReconciliationTests.
import Foundation
import Testing
import VisualCoreSimulation
@testable import StarlitCartoucheCore

@Suite struct StarlitCartoucheReconciliationTests {
    typealias Progress = StarlitCartoucheProgress
    typealias Result = StarlitCartoucheProgress.Result
    typealias Mode = StarlitCartoucheMode
    typealias Play = StarlitCartouchePlay
    typealias Action = StarlitCartoucheAction
    typealias Core = StarlitCartoucheExperienceCore
    typealias Reconciliation = StarlitCartoucheReconciliation
    typealias Generated = StarlitCartoucheGenerated
    typealias Rules = StarlitCartoucheRules

    /// The seed of the mixed walks.
    static let seed: UInt64 = 2_457

    /// The witness result of certified level `number`: its plan's legs as the trace, the plan's leg count as the
    /// actions spent, and the stars by rule.
    static func witnessResult(_ number: Int) throws -> Result {
        let certified: Generated = try Core.generated(number: number)
        let trace: [Action] = certified.plan.legs
        let count: Int = trace.count
        return Result(actionsSpent: count, stars: Progress.stars(actionsSpent: count, certified: count),
                      trace: trace, verified: true)
    }

    /// Checks that every witness of levels `first` … `last` verifies and spends exactly its leg count.
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

    /// The first level of each witness group of ten levels: 1, 11, … 91.
    static let witnessGroups: [Int] = [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]

    /// The first certified level (from `from`) whose plan has at least `minimum` legs.
    static func level(withPlanOf minimum: Int, from: Int) throws -> Int {
        for number in from...100 {
            if try Core.generated(number: number).plan.size >= minimum { return number }
        }
        Issue.record("no level with a plan of \(minimum) legs")
        return from
    }

    /// A leg the kernel accepts on a fresh play of certified level `number` that fails it by the chart's check (not the
    /// budget), or nil when the start has none.
    static func failingLeg(level number: Int) throws -> Action? {
        let certified: Generated = try Core.generated(number: number)
        let rules: Rules = Rules(level: certified.level)
        let start: Rules.Position = rules.initialState
        for move in rules.moves(in: start) {
            guard let after = rules.apply(move, to: start) else { continue }
            if after.outcome == .failed && after.actionsSpent < certified.level.budget { return move }
        }
        return nil
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

    /// Checks that `result` of `level` does not verify and that reconciling it alone drops and counts it, keeping the
    /// frontier `frontier`.
    static func expectDropped(level: Int, result: Result, frontier: Int,
                              sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(!Reconciliation.verifies(level: level, result: result), sourceLocation: sourceLocation)
        let data: Data = try Self.progressData(frontier: frontier, level: level, result: result)
        let loaded: Progress = try JSONDecoder().decode(Progress.self, from: data)
        let outcome: (progress: Progress, dropped: Int) = Reconciliation.reconcile(loaded)
        #expect(outcome.dropped == 1, sourceLocation: sourceLocation)
        #expect(outcome.progress.solved[level] == nil, sourceLocation: sourceLocation)
        #expect(outcome.progress.frontier == frontier, sourceLocation: sourceLocation)
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
        let level: StarlitCartoucheLevel = certified.level
        let witness: Result = try Self.witnessResult(number)
        let trace: [Action] = witness.trace
        let count: Int = witness.actionsSpent
        #expect(count >= 2)
        var tampered: [Result] = []
        // Edited stars.
        tampered.append(Result(actionsSpent: count, stars: 2, trace: trace, verified: true))
        tampered.append(Result(actionsSpent: count + 5, stars: 3, trace: trace, verified: true))
        // Actions spent below the legs the trace spends (stars still by rule).
        tampered.append(Result(actionsSpent: count - 1,
                               stars: Progress.stars(actionsSpent: count - 1, certified: count),
                               trace: trace, verified: true))
        // A changed step: the first leg's wait changed (kept only when the changed trace does not win anyway).
        for shift in 1...8 {
            var moved: [Action] = trace
            if case .leg(let star, let wait) = trace[0] { moved[0] = Action.leg(star, (wait + shift) % 9) }
            if !StarlitCartoucheSolver.wins(level, actions: moved) {
                tampered.append(Result(actionsSpent: count, stars: 3, trace: moved, verified: true))
            }
        }
        // A removed step: the first leg left out.
        let removed: [Action] = Array(trace.dropFirst())
        if !StarlitCartoucheSolver.wins(level, actions: removed) {
            tampered.append(Result(actionsSpent: count, stars: 3, trace: removed, verified: true))
        }
        // Illegal legs first: an unknown star, a negative star, the start star itself, waits −1 and 9.
        guard case .leg(let firstStar, _) = trace[0] else { return }
        let illegal: [Action] = [Action.leg(level.stars.count, 0), Action.leg(-1, 0), Action.leg(level.start, 0),
                                 Action.leg(firstStar, -1), Action.leg(firstStar, 9)]
        for bad in illegal {
            var withBad: [Action] = [bad]
            withBad.append(contentsOf: trace)
            tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: withBad, verified: true))
        }
        // A leg after the win (the play is final).
        var after: [Action] = trace
        after.append(trace[0])
        tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: after, verified: true))
        // An unwon trace (the last leg left out).
        var short: [Action] = trace
        short.removeLast()
        tampered.append(Result(actionsSpent: count, stars: 3, trace: short, verified: true))
        // Verified but without a trace.
        tampered.append(Result(actionsSpent: count, stars: 3, trace: [], verified: true))
        #expect(tampered.count >= 12)

        for result in tampered {
            try Self.expectDropped(level: number, result: result, frontier: 12)
        }
        // A level outside 1 … 100 never verifies.
        #expect(!Reconciliation.verifies(level: 0, result: witness))
        #expect(!Reconciliation.verifies(level: 101, result: witness))
        // The witness of this level is not a solution of the next one.
        let other: Generated = try Core.generated(number: number + 1)
        if !StarlitCartoucheSolver.wins(other.level, actions: trace) {
            #expect(!Reconciliation.verifies(level: number + 1, result: witness))
        }
    }

    @Test func failingLegsNeverVerify() throws {
        var found: Int = 0
        for number in 1...100 {
            guard let bad = try Self.failingLeg(level: number) else { continue }
            let witness: Result = try Self.witnessResult(number)
            // The failing leg first: the play fails and refuses the rest.
            var first: [Action] = [bad]
            first.append(contentsOf: witness.trace)
            let spent: Int = first.count
            let early: Result = Result(actionsSpent: spent,
                                       stars: Progress.stars(actionsSpent: spent, certified: witness.trace.count),
                                       trace: first, verified: true)
            try Self.expectDropped(level: number, result: early, frontier: 30)
            // The failing leg alone: the play ends failed.
            let alone: Result = Result(actionsSpent: 1, stars: 3, trace: [bad], verified: true)
            try Self.expectDropped(level: number, result: alone, frontier: 30)
            found += 1
            if found == 3 { break }
        }
        #expect(found == 3, "three levels with a failing first leg")
    }

    @Test func overlongTracesNeverVerify() throws {
        #expect(Reconciliation.maxTraceLength == 64)
        #expect(StarlitCartoucheLevel.budgets.upperBound <= Reconciliation.maxTraceLength)
        let number: Int = try Self.level(withPlanOf: 2, from: 2)
        let witness: Result = try Self.witnessResult(number)
        // The witness repeated past 64 legs is refused (before any replay).
        var overlong: [Action] = []
        while overlong.count <= Reconciliation.maxTraceLength {
            overlong.append(contentsOf: witness.trace)
        }
        #expect(overlong.count > Reconciliation.maxTraceLength)
        let tooLong: Result = Result(actionsSpent: overlong.count, stars: 1, trace: overlong, verified: true)
        try Self.expectDropped(level: number, result: tooLong, frontier: 3)
        // Exactly 65 legs: one over the bound.
        let sixtyFive: [Action] = Array(overlong.prefix(Reconciliation.maxTraceLength + 1))
        let over: Result = Result(actionsSpent: 65, stars: 1, trace: sixtyFive, verified: true)
        try Self.expectDropped(level: number, result: over, frontier: 3)
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
        let level: StarlitCartoucheLevel = certified.level
        let witness: [Action] = certified.plan.legs
        let first: Action = witness[0]
        var play: Play = try Core.freshPlay(of: level)
        // A leg, then its undo: nothing effective.
        try play.apply(first, expecting: play.fingerprint)
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        // Redo brings it back.
        try play.redo()
        var expected: [Action] = [first]
        #expect(Reconciliation.netTrace(play.records) == expected)
        // Undone and redone twice over.
        try play.undo()
        #expect(Reconciliation.netTrace(play.records).isEmpty)
        try play.redo()
        try play.undo()
        try play.redo()
        #expect(Reconciliation.netTrace(play.records) == expected)
        // An undo then a new leg clears the redo stack.
        try play.undo()
        try play.apply(first, expecting: play.fingerprint)
        #expect(Reconciliation.netTrace(play.records) == expected)
        #expect(throws: StarlitCartoucheError.self) { try play.redo() }
        // Undo it: back at the start.
        try play.undo()
        expected = []
        #expect(Reconciliation.netTrace(play.records) == expected)
        // A failing leg (when the start has one), then its undo: the leg is not effective.
        if let bad = try Self.failingLeg(level: number) {
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
            let level: StarlitCartoucheLevel = certified.level
            let rules: Rules = Rules(level: level)
            var play: Play = try Core.freshPlay(of: level)
            for _ in 0..<40 {
                let choice: UInt64 = random.next() % 4
                if choice == 0 {
                    if play.canUndo { try play.undo() }
                } else if choice == 1 {
                    if play.canRedo { try play.redo() }
                } else if play.stage == .playing && play.actionsLeft > 2 {
                    let position: Rules.Position = Rules.Position(star: play.star, beat: play.beat,
                                                                  drawn: play.drawn,
                                                                  actionsSpent: play.actionsSpent,
                                                                  outcome: .playing)
                    let moves: [Action] = rules.moves(in: position)
                    if !moves.isEmpty {
                        let move: Action = moves[Int(random.next() % UInt64(moves.count))]
                        try play.apply(move, expecting: play.fingerprint)
                    }
                }
                if play.stage == .failed, play.canUndo { try play.undo() }
            }
            let net: [Action] = Reconciliation.netTrace(play.records)
            var fresh: Play = try Core.freshPlay(of: level)
            for action in net {
                try fresh.apply(action, expecting: fresh.fingerprint)
            }
            #expect(fresh.legs == play.legs, "level \(number)")
            #expect(fresh.star == play.star, "level \(number)")
            #expect(fresh.beat == play.beat, "level \(number)")
            #expect(fresh.drawn == play.drawn, "level \(number)")
            #expect(fresh.actionsSpent == play.actionsSpent, "level \(number)")
            #expect(fresh.stage == play.stage, "level \(number)")
            #expect(fresh.fingerprint == play.fingerprint, "level \(number)")
            #expect(net.count <= Progress.actionsSpent(play), "level \(number)")
        }
    }

    @Test func netTraceIgnoresRecordsWithoutAnAction() {
        let stray: StarlitCartoucheRecord = StarlitCartoucheRecord(schema: 1, seed: 1, index: 0, kind: .leg,
                                                                   action: nil, previous: "", next: "")
        let undo: StarlitCartoucheRecord = StarlitCartoucheRecord(schema: 1, seed: 1, index: 0, kind: .undo,
                                                                  action: nil, previous: "", next: "")
        let redo: StarlitCartoucheRecord = StarlitCartoucheRecord(schema: 1, seed: 1, index: 0, kind: .redo,
                                                                  action: nil, previous: "", next: "")
        #expect(Reconciliation.netTrace([stray, undo, redo]).isEmpty)
        #expect(Reconciliation.netTrace([]).isEmpty)
    }

    // MARK: Record rules

    @Test func tracedRecordReplacesOnlyWhenBetter() throws {
        let traceA: [Action] = [Action.leg(1, 0), Action.leg(2, 3)]
        let traceB: [Action] = [Action.leg(3, 1), Action.leg(2, 1)]
        let traceC: [Action] = [Action.leg(1, 4)]
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
        #expect(decoded.solved[1]?.trace == progress.solved[1]?.trace)
        #expect(decoded.solved[12]?.verified == false)
        // A result encodes its trace and verified flag, also when untraced.
        var single: Progress = Progress()
        single.record(level: 1, actionsSpent: 2, certified: 3)
        #expect(String(decoding: try single.encoded(), as: UTF8.self)
            == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,\"trace\":[],"
            + "\"verified\":false}]}")
        var traced: Progress = Progress()
        traced.record(level: 1, actionsSpent: 2, certified: 3, trace: [Action.leg(2, 5), Action.leg(1, 0)])
        #expect(String(decoding: try traced.encoded(), as: UTF8.self)
            == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,"
            + "\"trace\":[{\"leg\":{\"_0\":2,\"_1\":5}},{\"leg\":{\"_0\":1,\"_1\":0}}],"
            + "\"verified\":true}]}")
    }

    @Test func oldJSONDecodesUnverified() throws {
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
                                                            trace: [Action.leg(3, 7)], verified: true))
        let back: Result = try JSONDecoder().decode(Result.self, from: encoded)
        #expect(back.trace == [Action.leg(3, 7)])
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
        #expect(StarlitCartoucheFeedbackPlan.modeName(replay) == "replay")
    }
}
