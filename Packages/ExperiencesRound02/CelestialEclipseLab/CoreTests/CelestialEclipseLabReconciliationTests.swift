// CelestialEclipseLabReconciliationTests — feature 467 (R02-G17-07) T-R02G1707-002 (contracts/api.md; research R2, R3,
// R6, R7; clarifications Q1, Q2). Every certified level's stored witness (docs/games/celestial-eclipse-lab/levels/
// NNN.witness.json: its phase changes, then the run), stored as a trace with the certified change count and the stars
// by rule, verifies (ten groups of 10 levels); an edited star count, actions spent below the trace's changes, a changed
// trace step, a removed change, an illegal (refused) action, a phase change over the budget, an action after the run, a
// run-less trace, a failing trace and an overlong trace are dropped and counted; untraced results are kept unverified;
// the frontier is unchanged; the effective actions of record sequences with undo and redo (a failed run undone and
// redone included, and 4 levels of seeded mixed walks, SeededRandom seed 2_467) match the play; the replacement rules
// of a traced record; Codable round trips and the decoding of JSON without trace and verified; the replay mode's rules
// and encoding. Test data uses explicit types and plain loops (CI type-check rule); no `try` inside `#expect`; no
// wall-clock asserts; each test well under 10 s. Modelled on feature 457's StarlitCartoucheReconciliationTests.
import Foundation
import Testing
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

/// The repository's witness directory, found from this file (five levels up: CoreTests, CelestialEclipseLab, the
/// package, Packages).
private let reconciliationWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/celestial-eclipse-lab/levels", isDirectory: true)

@Suite struct CelestialEclipseLabReconciliationTests {
    typealias Progress = CelestialEclipseLabProgress
    typealias Result = CelestialEclipseLabProgress.Result
    typealias Mode = CelestialEclipseLabMode
    typealias Play = CelestialEclipseLabPlay
    typealias Action = CelestialEclipseLabAction
    typealias Record = CelestialEclipseLabRecord
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Reconciliation = CelestialEclipseLabReconciliation
    typealias Generated = CelestialEclipseLabGenerated
    typealias Level = CelestialEclipseLabLevel

    /// The seed of the mixed walks.
    static let seed: UInt64 = 2_467

    /// The first level of each witness group of ten levels: 1, 11, … 91.
    static let witnessGroups: [Int] = [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]

    /// The stored witness of level `number`, read with the plain decoder.
    static func storedWitness(_ number: Int) throws -> CelestialEclipseLabWitness {
        let name: String = String(CelestialEclipseLabGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: reconciliationWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(CelestialEclipseLabWitness.self, from: data)
    }

    /// The phase changes of `actions` (every action but the run).
    static func changes(_ actions: [Action]) -> [Action] {
        var result: [Action] = []
        for action in actions where action != .run { result.append(action) }
        return result
    }

    /// The witness result of certified level `number`: its plan's phase changes then the run as the trace, the plan's
    /// change count as the actions spent, and the stars by rule.
    static func witnessResult(_ number: Int) throws -> Result {
        let certified: Generated = try Core.generated(number: number)
        var trace: [Action] = certified.plan.actions
        trace.append(.run)
        let count: Int = certified.plan.size
        return Result(actionsSpent: count, stars: Progress.stars(actionsSpent: count, certified: count),
                      trace: trace, verified: true)
    }

    /// The stage a fresh play of `level` ends in after `actions`, or nil when the play refuses one of them.
    static func outcome(_ level: Level, _ actions: [Action]) -> CelestialEclipseLabStage? {
        do {
            var play: Play = try Core.freshPlay(of: level)
            for action in actions {
                try play.apply(action, expecting: play.fingerprint)
            }
            return play.stage
        } catch {
            return nil
        }
    }

    /// The first certified level (from `from`) whose plan has at least `minimum` phase changes.
    static func level(withPlanOf minimum: Int, from: Int) throws -> Int {
        for number in from...100 {
            if try Core.generated(number: number).plan.size >= minimum { return number }
        }
        Issue.record("no level with a plan of \(minimum) phase changes")
        return from
    }

    /// The first movable body of `level` with a period of at least 2, or nil.
    static func movableBody(_ level: Level) -> Int? {
        for (index, body) in level.bodies.enumerated() where !body.fixed && body.period >= 2 { return index }
        return nil
    }

    /// `count` accepted-looking phase changes of `body` that alternate between another offset and the start offset.
    static func toggles(_ level: Level, body: Int, count: Int) -> [Action] {
        let start: Int = level.phases[body]
        let other: Int = (start + 1) % level.bodies[body].period
        var result: [Action] = []
        for index in 0..<count {
            result.append(Action.phase(body, index % 2 == 0 ? other : start))
        }
        return result
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
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(loaded)
        #expect(reconciled.dropped == 1, sourceLocation: sourceLocation)
        #expect(reconciled.progress.solved[level] == nil, sourceLocation: sourceLocation)
        #expect(reconciled.progress.frontier == frontier, sourceLocation: sourceLocation)
    }

    /// Whether `text` decodes as a mode.
    static func decodesMode(_ text: String) -> Bool {
        do {
            _ = try JSONDecoder().decode(Mode.self, from: Data(text.utf8))
            return true
        } catch {
            return false
        }
    }

    // MARK: Witnesses

    @Test(arguments: witnessGroups)
    func storedWitnessesOfTenLevelsVerify(first: Int) throws {
        for number in first...(first + 9) {
            let witness: CelestialEclipseLabWitness = try Self.storedWitness(number)
            let certified: Generated = try Core.generated(number: number)
            #expect(witness.level == certified.level, "level \(number)")
            #expect(witness.actions.last == .run, "level \(number)")
            let changes: [Action] = Self.changes(witness.actions)
            #expect(changes.count + 1 == witness.actions.count, "level \(number): one run, last")
            #expect(changes.count == certified.plan.size, "level \(number)")
            #expect(witness.actions.count <= Reconciliation.maxTraceLength)
            let count: Int = changes.count
            let stars: Int = Progress.stars(actionsSpent: count, certified: certified.plan.size)
            #expect(stars == 3)
            let result: Result = Result(actionsSpent: count, stars: stars, trace: witness.actions, verified: true)
            #expect(Reconciliation.verifies(level: number, result: result), "level \(number)")
            #expect(Self.outcome(certified.level, witness.actions) == .won, "level \(number)")
            var progress: Progress = Progress()
            progress.record(level: number, actionsSpent: count, certified: certified.plan.size,
                            trace: witness.actions)
            #expect(progress.solved[number] == result)
            let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
            #expect(reconciled.dropped == 0, "level \(number)")
            #expect(reconciled.progress == progress)
        }
    }

    @Test func honestHigherActionsVerifyWithTheirStars() throws {
        let number: Int = try Self.level(withPlanOf: 2, from: 4)
        let witness: Result = try Self.witnessResult(number)
        let count: Int = witness.actionsSpent
        for extra in 0...5 {
            let spent: Int = count + extra
            let stars: Int = Progress.stars(actionsSpent: spent, certified: count)
            let result: Result = Result(actionsSpent: spent, stars: stars, trace: witness.trace, verified: true)
            #expect(Reconciliation.verifies(level: number, result: result), "extra \(extra)")
        }
    }

    // MARK: Tampering

    @Test func tamperedResultsAreDroppedAndCounted() throws {
        let number: Int = try Self.level(withPlanOf: 2, from: 5)
        let certified: Generated = try Core.generated(number: number)
        let level: Level = certified.level
        let witness: Result = try Self.witnessResult(number)
        let trace: [Action] = witness.trace
        let count: Int = witness.actionsSpent
        #expect(count >= 2)
        var tampered: [Result] = []
        // Edited stars.
        tampered.append(Result(actionsSpent: count, stars: 2, trace: trace, verified: true))
        tampered.append(Result(actionsSpent: count + 5, stars: 3, trace: trace, verified: true))
        // Actions spent below the phase changes the trace spends (stars still by rule).
        tampered.append(Result(actionsSpent: count - 1,
                               stars: Progress.stars(actionsSpent: count - 1, certified: count),
                               trace: trace, verified: true))
        // A changed step: the first change's offset moved (kept only when the changed trace does not win anyway).
        guard case .phase(let firstBody, let firstOffset) = trace[0] else {
            Issue.record("the witness does not start with a phase change")
            return
        }
        let period: Int = level.bodies[firstBody].period
        for shift in 1..<period {
            var moved: [Action] = trace
            moved[0] = Action.phase(firstBody, (firstOffset + shift) % period)
            if Self.outcome(level, moved) != .won {
                tampered.append(Result(actionsSpent: count, stars: 3, trace: moved, verified: true))
            }
        }
        // A removed change: the first change left out (fewer changes than the certified plan never win).
        let removed: [Action] = Array(trace.dropFirst())
        #expect(Self.outcome(level, removed) != .won)
        tampered.append(Result(actionsSpent: count, stars: 3, trace: removed, verified: true))
        // Illegal actions first: an unknown body, a negative body, offsets −1 and the period, the start offset itself.
        var illegal: [Action] = [Action.phase(level.bodies.count, 0), Action.phase(-1, 0),
                                 Action.phase(firstBody, -1), Action.phase(firstBody, period),
                                 Action.phase(firstBody, level.phases[firstBody])]
        // A fixed body, when the level has one.
        for (index, body) in level.bodies.enumerated() where body.fixed {
            illegal.append(Action.phase(index, (level.phases[index] + 1) % max(body.period, 1)))
        }
        for bad in illegal {
            #expect(Self.outcome(level, [bad]) == nil, "\(bad) is refused")
            var withBad: [Action] = [bad]
            withBad.append(contentsOf: trace)
            tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: withBad, verified: true))
        }
        // Phase changes over the budget: the change after the last allowed one is refused.
        let body: Int = try #require(Self.movableBody(level))
        var overBudget: [Action] = Self.toggles(level, body: body, count: level.budget + 1)
        overBudget.append(.run)
        #expect(Self.outcome(level, overBudget) == nil)
        tampered.append(Result(actionsSpent: level.budget + 1, stars: 1, trace: overBudget, verified: true))
        // An action after the run (the play is final): a phase change, a second run.
        var afterChange: [Action] = trace
        afterChange.append(trace[0])
        tampered.append(Result(actionsSpent: count + 1, stars: 3, trace: afterChange, verified: true))
        var afterRun: [Action] = trace
        afterRun.append(.run)
        tampered.append(Result(actionsSpent: count, stars: 3, trace: afterRun, verified: true))
        // A run-less trace (the winning phases set, the run left out).
        let runless: [Action] = Self.changes(trace)
        #expect(Self.outcome(level, runless) == .playing)
        tampered.append(Result(actionsSpent: count, stars: 3, trace: runless, verified: true))
        // Verified but without a trace.
        tampered.append(Result(actionsSpent: count, stars: 3, trace: [], verified: true))
        // Unverified but with a trace that does not replay (a trace is checked whatever the flag says).
        tampered.append(Result(actionsSpent: count, stars: 3, trace: runless, verified: false))
        #expect(tampered.count >= 16)

        for result in tampered {
            try Self.expectDropped(level: number, result: result, frontier: 12)
        }
        // A level outside 1 … 100 never verifies.
        #expect(!Reconciliation.verifies(level: 0, result: witness))
        #expect(!Reconciliation.verifies(level: 101, result: witness))
        // The witness of this level is not a solution of the next one.
        let other: Generated = try Core.generated(number: number + 1)
        if Self.outcome(other.level, trace) != .won {
            #expect(!Reconciliation.verifies(level: number + 1, result: witness))
        }
    }

    @Test func failingTracesNeverVerify() throws {
        for number in 1...10 {
            let certified: Generated = try Core.generated(number: number)
            let level: Level = certified.level
            let witness: Result = try Self.witnessResult(number)
            // The run alone: a certified level never wins at its start, so the play ends failed.
            let alone: [Action] = [.run]
            #expect(Self.outcome(level, alone) == .failed, "level \(number)")
            try Self.expectDropped(level: number, result: Result(actionsSpent: 0, stars: 3, trace: alone,
                                                                 verified: true), frontier: 30)
            // The witness without its last change: fewer changes than the certified plan, so the run fails.
            var short: [Action] = Self.changes(witness.trace)
            short.removeLast()
            short.append(.run)
            #expect(Self.outcome(level, short) == .failed, "level \(number)")
            let spent: Int = short.count - 1
            let failing: Result = Result(actionsSpent: spent,
                                         stars: Progress.stars(actionsSpent: spent, certified: certified.plan.size),
                                         trace: short, verified: true)
            try Self.expectDropped(level: number, result: failing, frontier: 30)
            // A failing run followed by the winning trace: the play is final after the failed run.
            var retried: [Action] = [.run]
            retried.append(contentsOf: witness.trace)
            let retry: Result = Result(actionsSpent: witness.actionsSpent, stars: 3, trace: retried, verified: true)
            try Self.expectDropped(level: number, result: retry, frontier: 30)
        }
    }

    @Test func overlongTracesNeverVerify() throws {
        #expect(Reconciliation.maxTraceLength == 64)
        #expect(Level.budgets.upperBound + 1 <= Reconciliation.maxTraceLength)
        let number: Int = try Self.level(withPlanOf: 2, from: 2)
        let level: Level = try Core.generated(number: number).level
        let body: Int = try #require(Self.movableBody(level))
        // 64 changes and the run: 65 actions, one over the bound (refused before any replay).
        var sixtyFive: [Action] = Self.toggles(level, body: body, count: Reconciliation.maxTraceLength)
        sixtyFive.append(.run)
        #expect(sixtyFive.count == Reconciliation.maxTraceLength + 1)
        let over: Result = Result(actionsSpent: 64, stars: 1, trace: sixtyFive, verified: true)
        try Self.expectDropped(level: number, result: over, frontier: 3)
        // The witness repeated past 64 actions.
        let witness: Result = try Self.witnessResult(number)
        var overlong: [Action] = []
        while overlong.count <= Reconciliation.maxTraceLength {
            overlong.append(contentsOf: Self.changes(witness.trace))
        }
        overlong.append(.run)
        let tooLong: Result = Result(actionsSpent: overlong.count - 1, stars: 1, trace: overlong, verified: true)
        try Self.expectDropped(level: number, result: tooLong, frontier: 3)
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
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == progress)
        #expect(reconciled.progress.frontier == 40)
        #expect(reconciled.progress.solved[7]?.verified == false)
        #expect(reconciled.progress.solved[7]?.trace.isEmpty == true)
        #expect(reconciled.progress.solved[9]?.verified == false)
        #expect(reconciled.progress.solved[1]?.verified == true)
        #expect(reconciled.progress.solved[8]?.verified == true)

        // A tampered level among honest ones: only it is dropped; the frontier stays.
        let tampered: Result = Result(actionsSpent: witness.actionsSpent, stars: 1, trace: witness.trace,
                                      verified: true)
        var honest: Progress = progress
        honest.drop(level: 8)
        let honestText: String = String(decoding: try honest.encoded(), as: UTF8.self)
        let tamperedData: Data = try Self.progressData(frontier: 40, level: 8, result: tampered)
        let tamperedText: String = String(decoding: tamperedData, as: UTF8.self)
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
        let level: Level = certified.level
        let plan: [Action] = certified.plan.actions
        let first: Action = plan[0]
        var play: Play = try Core.freshPlay(of: level)
        // A change, then its undo: nothing effective.
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
        // An undo then a new change clears the redo stack.
        try play.undo()
        try play.apply(first, expecting: play.fingerprint)
        #expect(Reconciliation.netTrace(play.records) == expected)
        #expect(!play.canRedo)
        // Undo it: back at the start.
        try play.undo()
        expected = []
        #expect(Reconciliation.netTrace(play.records) == expected)
        // A failing run, then its undo: the run is not effective.
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.stage == .failed)
        #expect(Reconciliation.netTrace(play.records) == [Action.run])
        try play.undo()
        #expect(play.stage == .playing)
        #expect(Reconciliation.netTrace(play.records) == expected)
        // Redo restores the failed run; undo removes it again.
        try play.redo()
        #expect(play.stage == .failed)
        #expect(Reconciliation.netTrace(play.records) == [Action.run])
        try play.undo()
        #expect(Reconciliation.netTrace(play.records) == expected)
        // A pause and a resume are not actions.
        try play.handle(.pause)
        try play.handle(.resume)
        #expect(Reconciliation.netTrace(play.records) == expected)
        // The plan and the run win.
        for action in plan {
            try play.apply(action, expecting: play.fingerprint)
            expected.append(action)
        }
        try play.apply(.run, expecting: play.fingerprint)
        expected.append(.run)
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
        #expect(spent > Self.changes(net).count)
        let result: Result = Result(actionsSpent: spent,
                                    stars: Progress.stars(actionsSpent: spent, certified: plan.count),
                                    trace: net, verified: true)
        #expect(Reconciliation.verifies(level: number, result: result))
        // The same trace claimed with the trace's own change count (fewer than spent) also verifies: the rule is an
        // upper bound on the trace, not an equality.
        let lean: Int = Self.changes(net).count
        let leanResult: Result = Result(actionsSpent: lean,
                                        stars: Progress.stars(actionsSpent: lean, certified: plan.count),
                                        trace: net, verified: true)
        #expect(Reconciliation.verifies(level: number, result: leanResult))
    }

    @Test func netTraceMatchesThePlayOverMixedSequences() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for number in [10, 33, 57, 88] {
            let certified: Generated = try Core.generated(number: number)
            let level: Level = certified.level
            var movable: [Int] = []
            for (index, body) in level.bodies.enumerated() where !body.fixed && body.period >= 2 {
                movable.append(index)
            }
            #expect(!movable.isEmpty, "level \(number)")
            var play: Play = try Core.freshPlay(of: level)
            for _ in 0..<40 {
                let choice: UInt64 = random.next() % 6
                if choice == 0 {
                    if play.canUndo { try play.undo() }
                } else if choice == 1 {
                    if play.canRedo { try play.redo() }
                } else if choice == 2 {
                    if play.stage == .playing { try play.apply(.run, expecting: play.fingerprint) }
                } else if play.stage == .playing && play.actionsLeft > 0 && !movable.isEmpty {
                    let body: Int = movable[Int(random.next() % UInt64(movable.count))]
                    let period: Int = level.bodies[body].period
                    let step: Int = 1 + Int(random.next() % UInt64(period - 1))
                    let offset: Int = (play.phases[body] + step) % period
                    try play.apply(Action.phase(body, offset), expecting: play.fingerprint)
                }
                if play.stage == .won { break }
            }
            let net: [Action] = Reconciliation.netTrace(play.records)
            var fresh: Play = try Core.freshPlay(of: level)
            for action in net {
                try fresh.apply(action, expecting: fresh.fingerprint)
            }
            #expect(fresh.phases == play.phases, "level \(number)")
            #expect(fresh.actionsSpent == play.actionsSpent, "level \(number)")
            #expect(fresh.timeline == play.timeline, "level \(number)")
            #expect(fresh.failure == play.failure, "level \(number)")
            #expect(fresh.stage == play.stage, "level \(number)")
            #expect(fresh.fingerprint == play.fingerprint, "level \(number)")
            #expect(Self.changes(net).count <= Progress.actionsSpent(play), "level \(number)")
            var runs: Int = 0
            for action in net where action == .run { runs += 1 }
            #expect(runs <= 1, "level \(number)")
            if runs == 1 { #expect(net.last == .run, "level \(number)") }
        }
    }

    @Test func netTraceIgnoresRecordsWithoutAnActionAndEvents() {
        var records: [Record] = []
        let kinds: [CelestialEclipseLabRecordKind] = [.phase, .run, .undo, .redo, .begin, .dismissTutorial, .pause,
                                                      .resume]
        for kind in kinds {
            records.append(Record(schema: 1, seed: 1, index: records.count, kind: kind, action: nil, previous: "",
                                  next: ""))
        }
        #expect(Reconciliation.netTrace(records).isEmpty)
        #expect(Reconciliation.netTrace([]).isEmpty)
        // An undo with nothing effective and a redo with nothing undone change nothing.
        let change: Record = Record(schema: 1, seed: 1, index: 0, kind: .phase, action: Action.phase(1, 2),
                                    previous: "", next: "")
        let undo: Record = Record(schema: 1, seed: 1, index: 1, kind: .undo, action: nil, previous: "", next: "")
        let redo: Record = Record(schema: 1, seed: 1, index: 2, kind: .redo, action: nil, previous: "", next: "")
        #expect(Reconciliation.netTrace([undo, redo, change]) == [Action.phase(1, 2)])
        #expect(Reconciliation.netTrace([change, undo, undo, redo, redo]) == [Action.phase(1, 2)])
    }

    // MARK: Record rules

    @Test func tracedRecordReplacesOnlyWhenBetter() {
        let traceA: [Action] = [Action.phase(1, 0), Action.phase(2, 3), Action.run]
        let traceB: [Action] = [Action.phase(3, 1), Action.phase(2, 1), Action.run]
        let traceC: [Action] = [Action.phase(1, 4), Action.run]
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
        let again: Data = try decoded.encoded()
        #expect(decoded == progress)
        #expect(again == data)
        #expect(decoded.solved[1]?.verified == true)
        #expect(decoded.solved[1]?.trace == progress.solved[1]?.trace)
        #expect(decoded.solved[1]?.trace.last == .run)
        #expect(decoded.solved[12]?.verified == false)
        // A result encodes its trace and verified flag, also when untraced.
        var single: Progress = Progress()
        single.record(level: 1, actionsSpent: 2, certified: 3)
        let singleText: String = String(decoding: try single.encoded(), as: UTF8.self)
        #expect(singleText == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,\"trace\":[],"
            + "\"verified\":false}]}")
        var traced: Progress = Progress()
        traced.record(level: 1, actionsSpent: 2, certified: 3,
                      trace: [Action.phase(2, 5), Action.phase(1, 0), Action.run])
        let tracedText: String = String(decoding: try traced.encoded(), as: UTF8.self)
        #expect(tracedText == "{\"frontier\":2,\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,"
            + "\"trace\":[{\"phase\":{\"_0\":2,\"_1\":5}},{\"phase\":{\"_0\":1,\"_1\":0}},{\"run\":{}}],"
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
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(decoded)
        #expect(reconciled.dropped == 0)
        #expect(reconciled.progress == decoded)
        // A result alone also decodes without trace and verified.
        let single: Result = try JSONDecoder().decode(Result.self, from: Data("{\"actionsSpent\":3,\"stars\":2}".utf8))
        #expect(single == Result(actionsSpent: 3, stars: 2))
        let encoded: Data = try JSONEncoder().encode(Result(actionsSpent: 3, stars: 2,
                                                            trace: [Action.phase(3, 7), Action.run], verified: true))
        let back: Result = try JSONDecoder().decode(Result.self, from: encoded)
        #expect(back.trace == [Action.phase(3, 7), Action.run])
        #expect(back.verified)
    }

    @Test func replayModeRulesAndEncoding() throws {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder: JSONDecoder = JSONDecoder()
        let replayText: String = String(decoding: try encoder.encode(Mode.replay(level: 5)), as: UTF8.self)
        #expect(replayText == "{\"level\":5,\"mode\":\"replay\"}")
        let modes: [Mode] = [.replay(level: 1), .replay(level: 100), .campaign, .practice, .daily(level: 3)]
        for mode in modes {
            let back: Mode = try decoder.decode(Mode.self, from: try encoder.encode(mode))
            #expect(back == mode)
        }
        let bad: [String] = ["{\"mode\":\"replay\",\"level\":0}", "{\"mode\":\"replay\",\"level\":101}",
                             "{\"mode\":\"replay\"}"]
        for text in bad {
            #expect(!Self.decodesMode(text), "\(text)")
        }
        #expect(Self.decodesMode("{\"mode\":\"replay\",\"level\":7}"))
        let replay: Mode = .replay(level: 9)
        #expect(!replay.awardsStars)
        #expect(!replay.opensLevels)
        #expect(replay.budget(base: 17) == 17)
        #expect(replay != .daily(level: 9))
        #expect(Mode.campaign.awardsStars && Mode.daily(level: 9).awardsStars && !Mode.practice.awardsStars)
    }
}
