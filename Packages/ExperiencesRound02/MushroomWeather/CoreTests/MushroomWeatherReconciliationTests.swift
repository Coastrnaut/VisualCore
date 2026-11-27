// MushroomWeatherReconciliationTests — feature 497 (R02-G20-07) T-R02G2007-002 (FR-R02G2007-001, 002, 003;
// SC-R02G2007-003; clarifications Q1, Q2, Q3; research R2–R4, R6, R7). Every certified level's witness (its certified
// plan's pod, vent and moonlight actions, then the run) verifies as a trace (ten levels per test, five in band 5);
// recorded traces with undone actions (actions spent above the trace's) and an effective detour trace are kept; edited
// stars, actions spent below the trace's actions, an edited or missing trace step, and an illegal, failing, run-less,
// after-the-run or overlong (over 64 actions) trace are dropped and counted, while untraced results are kept
// unverified, a claimed-verified empty trace is dropped and the frontier is unchanged; `netTrace` over undo and redo
// sequences of a real play (a failed run undone included) equals the witness and replays to the same arrangement,
// fingerprint and stage, and 200 seeded (SeededRandom seed 2_497) random place, remove, vent, moonlight, undo, redo and
// run walks agree with an independent net list and replay to the same fingerprint. Modelled on feature 487's
// MicroscopicAuroraReconciliationTests. Test data uses explicit types and plain loops (CI type-check rule); each test
// under 10 s. No clock, no random source but the seeded generator.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherReconciliationTests {
    typealias Reconciliation = MushroomWeatherReconciliation
    typealias Progress = MushroomWeatherProgress
    typealias Result = MushroomWeatherProgress.Result
    typealias Play = MushroomWeatherPlay
    typealias Action = MushroomWeatherAction
    typealias Cell = MushroomWeatherCell
    typealias Level = MushroomWeatherLevel
    typealias Core = MushroomWeatherExperienceCore
    typealias Generated = MushroomWeatherGenerated

    /// The seed of the seeded walks.
    static let seed: UInt64 = 2_497

    /// The witness trace of certified level `number`: its certified plan's actions, then the run.
    static func witnessTrace(_ number: Int) throws -> [Action] {
        let generated: Generated = try Core.generated(number: number)
        var trace: [Action] = generated.plan.actions
        trace.append(.run)
        return trace
    }

    /// The certified plan's action count of level `number` (the stars' reference).
    static func certified(_ number: Int) throws -> Int {
        try Core.generated(number: number).plan.size
    }

    /// The pod, vent and moonlight actions of `trace` (every action but the run).
    static func spends(_ trace: [Action]) -> Int {
        var count: Int = 0
        for action in trace where action != .run { count += 1 }
        return count
    }

    /// The honest verified result of level `number` for `trace` with `actionsSpent` actions spent.
    static func result(_ number: Int, trace: [Action], actionsSpent: Int) throws -> Result {
        let stars: Int = Progress.stars(actionsSpent: actionsSpent, certified: try certified(number))
        return Result(actionsSpent: actionsSpent, stars: stars, trace: trace, verified: true)
    }

    /// The honest result of level `number`'s witness trace.
    static func honest(_ number: Int) throws -> Result {
        let trace: [Action] = try witnessTrace(number)
        return try result(number, trace: trace, actionsSpent: spends(trace))
    }

    /// The certified level `number` played fresh (campaign budget, begun, tutorial dismissed).
    static func fresh(_ number: Int) throws -> Play {
        try Core.freshPlay(of: try Core.generated(number: number).level)
    }

    /// `trace` applied to a fresh play of level `number`; nil when the kernel refuses an action.
    static func replayed(_ number: Int, _ trace: [Action]) throws -> Play? {
        var play: Play = try fresh(number)
        for action in trace {
            do { try play.apply(action, expecting: play.fingerprint) } catch { return nil }
        }
        return play
    }

    /// The action that undoes the effect of `action` on `arrangement` (the arrangement before it): a placement on an
    /// empty slot is undone by its removal, a move by the move back, a vent by the other state, the moonlight by the
    /// earlier level; the run by itself (never used).
    static func inverse(_ action: Action, before arrangement: MushroomWeatherArrangement) -> Action {
        switch action {
        case let .place(slot, _):
            if slot < arrangement.pods.count, let cell = arrangement.pods[slot] { return .place(slot: slot, cell: cell) }
            return .remove(slot: slot)
        case let .remove(slot):
            let cell: Cell = slot < arrangement.pods.count ? (arrangement.pods[slot] ?? Cell(row: 0, column: 0))
                : Cell(row: 0, column: 0)
            return .place(slot: slot, cell: cell)
        case let .vent(index, open):
            return .vent(index: index, open: !open)
        case .moonlight:
            return .moonlight(level: arrangement.moonlight)
        case .run:
            return .run
        }
    }

    /// Progress holding `results` by level, built by decoding a snapshot-schema-3 encoding so that edited (dishonest)
    /// results are stored exactly; the frontier is `frontier`.
    static func progress(_ results: [Int: Result], frontier: Int) throws -> Progress {
        var entries: [String] = []
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for level in results.keys.sorted() {
            guard let result = results[level] else { continue }
            let trace: String = String(decoding: try encoder.encode(result.trace), as: UTF8.self)
            entries.append("{\"actionsSpent\":\(result.actionsSpent),\"level\":\(level),\"stars\":\(result.stars),"
                + "\"trace\":\(trace),\"verified\":\(result.verified)}")
        }
        let text: String = "{\"frontier\":\(frontier),\"solved\":[" + entries.joined(separator: ",") + "]}"
        return try JSONDecoder().decode(Progress.self, from: Data(text.utf8))
    }

    /// A placement on the certified level `number` the kernel refuses: a floor cell that is not one of the level's
    /// sites (or a cell outside the forest when every floor cell is a site).
    static func illegalPlacement(_ number: Int) throws -> Action {
        let level: Level = try Core.generated(number: number).level
        for row in 0..<level.rows {
            for column in 0..<level.columns {
                let cell: Cell = Cell(row: row, column: column)
                guard level.isFloor(cell), !level.allowsPod(cell) else { continue }
                return .place(slot: 0, cell: cell)
            }
        }
        return .place(slot: 0, cell: Cell(row: -1, column: -1))
    }

    // MARK: Witness traces verify

    /// Checks that every certified level of `numbers` verifies its witness trace and reconciles with nothing dropped.
    static func check(_ numbers: ClosedRange<Int>) throws {
        let first: Int = numbers.lowerBound
        var results: [Int: Result] = [:]
        for number in numbers {
            let result: Result = try honest(number)
            #expect(result.trace.count <= Reconciliation.maxTraceLength)
            #expect(result.trace.last == .run && result.stars == 3)
            #expect(Reconciliation.verifies(level: number, result: result), "level \(number)")
            results[number] = result
        }
        let saved: Progress = try progress(results, frontier: first)
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(saved)
        #expect(reconciled.dropped == 0 && reconciled.progress == saved && reconciled.progress.frontier == first)
    }

    @Test func levels1To10WitnessTracesVerify() throws { try Self.check(1...10) }
    @Test func levels11To20WitnessTracesVerify() throws { try Self.check(11...20) }
    @Test func levels21To30WitnessTracesVerify() throws { try Self.check(21...30) }
    @Test func levels31To40WitnessTracesVerify() throws { try Self.check(31...40) }
    @Test func levels41To50WitnessTracesVerify() throws { try Self.check(41...50) }
    @Test func levels51To60WitnessTracesVerify() throws { try Self.check(51...60) }
    @Test func levels61To70WitnessTracesVerify() throws { try Self.check(61...70) }
    @Test func levels71To80WitnessTracesVerify() throws { try Self.check(71...80) }
    @Test func levels81To85WitnessTracesVerify() throws { try Self.check(81...85) }
    @Test func levels86To90WitnessTracesVerify() throws { try Self.check(86...90) }
    @Test func levels91To95WitnessTracesVerify() throws { try Self.check(91...95) }
    @Test func levels96To100WitnessTracesVerify() throws { try Self.check(96...100) }

    @Test func recordedTracesRoundTripAndVerify() throws {
        var progress: Progress = Progress()
        let numbers: [Int] = [1, 2, 3, 37, 64, 100]
        for number in numbers {
            let trace: [Action] = try Self.witnessTrace(number)
            // Two undone actions on top of the trace: two more actions spent, two stars.
            let spent: Int = Self.spends(trace) + 2
            progress.record(level: number, actionsSpent: spent, certified: try Self.certified(number), trace: trace)
        }
        let decoded: Progress = try JSONDecoder().decode(Progress.self, from: try progress.encoded())
        #expect(decoded == progress)
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(decoded)
        #expect(reconciled.dropped == 0 && reconciled.progress == progress)
        for number in numbers {
            #expect(reconciled.progress.solved[number]?.verified == true)
            #expect(reconciled.progress.stars(of: number) == 2)
        }
    }

    @Test func honestDetourTraceVerifies() throws {
        // A detour that stays effective: the first witness action and the action undoing it, then the witness; the
        // trace spends two more actions than the witness and verifies with that many spent.
        let number: Int = 30
        let witness: [Action] = try Self.witnessTrace(number)
        let start: Play = try Self.fresh(number)
        var trace: [Action] = [witness[0], Self.inverse(witness[0], before: start.arrangement)]
        for action in witness { trace.append(action) }
        let budget: Int = try Core.generated(number: number).level.budget
        try #require(Self.spends(trace) <= budget)
        let replay: Play? = try Self.replayed(number, trace)
        #expect(replay?.stage == .won)
        let spent: Int = Self.spends(trace)
        let kept: Result = try Self.result(number, trace: trace, actionsSpent: spent)
        #expect(Reconciliation.verifies(level: number, result: kept))
        #expect(!Reconciliation.verifies(level: number,
                                         result: try Self.result(number, trace: trace, actionsSpent: spent - 1)))
    }

    // MARK: Edited results are dropped

    @Test func editedResultsAreDroppedAndCounted() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var results: [Int: Result] = [:]
        var expectedDropped: [Int] = []
        // Three honest results, three of each kind of edit, on levels chosen by the seeded generator.
        var levels: [Int] = []
        while levels.count < 27 {
            let number: Int = random.int(1...100)
            if !levels.contains(number) { levels.append(number) }
        }
        for index in 0..<levels.count {
            let number: Int = levels[index]
            let honest: Result = try Self.honest(number)
            let trace: [Action] = honest.trace
            let spent: Int = honest.actionsSpent
            let certified: Int = try Self.certified(number)
            var edited: Result = honest
            switch index / 3 {
            case 0:
                edited = honest
            case 1:
                // Stars raised or lowered against the stars rule.
                let stars: Int = honest.stars == 3 ? 2 : 3
                edited = Result(actionsSpent: spent, stars: stars, trace: trace, verified: true)
            case 2:
                // Actions spent below the trace's pod, vent and moonlight actions (stars claimed by the rule for them).
                let lowered: Int = spent - 1
                let claimed: Int = Progress.stars(actionsSpent: lowered, certified: certified)
                edited = Result(actionsSpent: lowered, stars: claimed, trace: trace, verified: true)
            case 3:
                // A trace step removed: an action left out (the certified plan is minimal, so this cannot win).
                var shorter: [Action] = trace
                shorter.remove(at: random.int(0...(trace.count - 2)))
                edited = Result(actionsSpent: spent, stars: honest.stars, trace: shorter, verified: true)
            case 4:
                // An illegal step: a placement on a cell the level refuses, before the run.
                var illegal: [Action] = trace
                illegal.insert(try Self.illegalPlacement(number), at: trace.count - 1)
                edited = Result(actionsSpent: spent + 1, stars: honest.stars, trace: illegal, verified: true)
            case 5:
                // A failing trace: the run alone fails (a certified start never wins).
                edited = Result(actionsSpent: spent, stars: honest.stars, trace: [.run], verified: true)
            case 6:
                // A run-less trace: the arrangement actions without the closing run.
                var runless: [Action] = trace
                runless.removeLast()
                edited = Result(actionsSpent: spent, stars: honest.stars, trace: runless, verified: true)
            case 7:
                // An action after the run.
                var after: [Action] = trace
                after.append(.run)
                edited = Result(actionsSpent: spent, stars: honest.stars, trace: after, verified: true)
            default:
                // An overlong trace: over 64 actions (the witness padded with pairs that undo and redo its last
                // action, before its run).
                var long: [Action] = trace
                long.removeLast()
                guard let beforeLast = try Self.replayed(number, Array(trace.prefix(trace.count - 2))) else {
                    Issue.record("the witness of level \(number) does not replay")
                    continue
                }
                let redoLast: Action = trace[trace.count - 2]
                let undoLast: Action = Self.inverse(redoLast, before: beforeLast.arrangement)
                while long.count < Reconciliation.maxTraceLength {
                    long.append(undoLast)
                    long.append(redoLast)
                }
                long.append(.run)
                edited = Result(actionsSpent: Self.spends(long), stars: 1, trace: long, verified: true)
                #expect(edited.trace.count > Reconciliation.maxTraceLength)
            }
            results[number] = edited
            if index >= 3 { expectedDropped.append(number) }
        }
        // A failing run is really a failure, not a refusal.
        let failing: Play? = try Self.replayed(levels[15], [.run])
        #expect(failing?.stage == .failed)
        let saved: Progress = try Self.progress(results, frontier: 37)
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(saved)
        #expect(reconciled.dropped == expectedDropped.count)
        #expect(reconciled.progress.frontier == 37)
        for number in levels {
            let kept: Bool = !expectedDropped.contains(number)
            #expect((reconciled.progress.solved[number] != nil) == kept, "level \(number)")
            if kept { #expect(reconciled.progress.solved[number] == saved.solved[number]) }
        }
    }

    /// The edits of one trace step: a placement moved to each other site, a vent set to the other state, the
    /// moonlight set to each other level.
    static func stepEdits(_ action: Action, level: Level) -> [Action] {
        var edits: [Action] = []
        switch action {
        case let .place(slot, cell):
            for site in level.sites ?? [] where site != cell { edits.append(.place(slot: slot, cell: site)) }
        case let .vent(index, open):
            edits.append(.vent(index: index, open: !open))
        case let .moonlight(moon):
            for other in Level.moonlightLevels where other != moon { edits.append(.moonlight(level: other)) }
        case .remove, .run:
            break
        }
        return edits
    }

    @Test func editedTraceStepIsDropped() throws {
        // A witness step changed to another site, vent state or moonlight level: it verifies exactly when the kernel
        // still wins with it (checked through the kernel).
        var dropped: Int = 0
        for number in [5, 25, 45, 65, 85] {
            let honest: Result = try Self.honest(number)
            let level: Level = try Core.generated(number: number).level
            for index in 0..<(honest.trace.count - 1) {
                for changed in Self.stepEdits(honest.trace[index], level: level) {
                    var trace: [Action] = honest.trace
                    trace[index] = changed
                    let replay: Play? = try Self.replayed(number, trace)
                    let wins: Bool = replay?.stage == .won
                    let edited: Result = Result(actionsSpent: honest.actionsSpent, stars: honest.stars, trace: trace,
                                                verified: true)
                    #expect(Reconciliation.verifies(level: number, result: edited) == wins, "level \(number)")
                    if !wins { dropped += 1 }
                }
            }
        }
        #expect(dropped > 0)
    }

    @Test func untracedResultsAreKeptAndClaimedVerifiedEmptyTracesDropped() throws {
        var progress: Progress = Progress()
        for level in 1...20 {
            progress.record(level: level, actionsSpent: 30, certified: 1, opensNext: true)
        }
        let reconciled: (progress: Progress, dropped: Int) = Reconciliation.reconcile(progress)
        #expect(reconciled.dropped == 0 && reconciled.progress == progress && reconciled.progress.frontier == 21)
        for level in 1...20 { #expect(reconciled.progress.solved[level]?.verified == false) }
        // A result that claims to be verified without a trace is dropped; the frontier stays.
        var claimed: [Int: Result] = [:]
        claimed[4] = Result(actionsSpent: 1, stars: 3, trace: [], verified: true)
        claimed[5] = Result(actionsSpent: 1, stars: 3, trace: [], verified: false)
        let saved: Progress = try Self.progress(claimed, frontier: 90)
        let checked: (progress: Progress, dropped: Int) = Reconciliation.reconcile(saved)
        #expect(checked.dropped == 1 && checked.progress.solved[4] == nil && checked.progress.solved[5] != nil)
        #expect(checked.progress.frontier == 90)
        #expect(!Reconciliation.verifies(level: 0, result: try Self.honest(1)))
        #expect(!Reconciliation.verifies(level: 101, result: try Self.honest(1)))
        #expect(Reconciliation.maxTraceLength == 64)
    }

    // MARK: Net trace

    @Test func netTraceDropsUndoneActionsAndRestoresRedoneOnes() throws {
        let number: Int = 42
        let witness: [Action] = try Self.witnessTrace(number)
        var play: Play = try Self.fresh(number)
        // The detour is the witness's first action itself, so the kernel accepts it on the fresh play.
        let detour: Action = witness[0]
        // A detour action undone, redone and undone again, then the witness with an undo and redo of its first step.
        try play.apply(detour, expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        try play.undo()
        try play.apply(witness[0], expecting: play.fingerprint)
        try play.undo()
        try play.redo()
        for index in 1..<(witness.count - 1) { try play.apply(witness[index], expecting: play.fingerprint) }
        // A failed run undone is left out: undo the last action (a minimal plan without it fails), run (fails), undo
        // the run, then apply the last action again and run.
        let last: Action = witness[witness.count - 2]
        try play.undo()
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.stage == .failed)
        try play.undo()
        try play.apply(last, expecting: play.fingerprint)
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.stage == .won)
        let net: [Action] = Reconciliation.netTrace(play.records)
        #expect(net == witness)
        // Two actions spent on top of the witness: the undone detour and the last action applied twice.
        #expect(Progress.actionsSpent(play) == Self.spends(witness) + 2)
        let replay: Play? = try Self.replayed(number, net)
        #expect(replay?.stage == .won && replay?.arrangement == play.arrangement)
        #expect(replay?.fingerprint == play.fingerprint)
        #expect(Reconciliation.verifies(level: number,
                                        result: try Self.result(number, trace: net,
                                                                actionsSpent: Progress.actionsSpent(play))))
        #expect(Reconciliation.netTrace([]) == [])
    }

    /// One random arrangement action for the seeded walks: a placement on a site (3 in 7), a removal (1 in 7), a vent
    /// (2 in 7; the moonlight on a level without vents) or the moonlight (1 in 7).
    static func randomAction(_ level: Level, _ random: inout SeededRandom) -> Action {
        let sites: [Cell] = level.sites ?? [Cell(row: 0, column: 0)]
        let slot: Int = random.int(0...(level.podRules.slots - 1))
        let roll: Int = random.int(0...6)
        switch roll {
        case 0, 1, 2:
            return .place(slot: slot, cell: sites[random.int(0...(sites.count - 1))])
        case 3:
            return .remove(slot: slot)
        case 4, 5:
            if level.vents.isEmpty { return .moonlight(level: random.int(Level.moonlightLevels)) }
            return .vent(index: random.int(0...(level.vents.count - 1)), open: random.int(0...1) == 1)
        default:
            return .moonlight(level: random.int(Level.moonlightLevels))
        }
    }

    @Test func seededWalksAgreeWithAnIndependentNetList() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        let numbers: [Int] = [1, 12, 33, 58, 77, 99]
        for walk in 0..<200 {
            let number: Int = numbers[walk % numbers.count]
            let level: Level = try Core.generated(number: number).level
            var play: Play = try Self.fresh(number)
            // The independent net list: the effective moments as plain arrays.
            var net: [Action] = []
            var redo: [Action] = []
            for _ in 0..<12 {
                let choice: Int = random.int(0...9)
                if choice <= 4 {
                    let action: Action = Self.randomAction(level, &random)
                    do {
                        try play.apply(action, expecting: play.fingerprint)
                        net.append(action)
                        redo.removeAll()
                    } catch {
                        continue
                    }
                } else if choice <= 6 {
                    do {
                        try play.undo()
                        if let last = net.popLast() { redo.append(last) }
                    } catch {
                        continue
                    }
                } else if choice <= 8 {
                    do {
                        try play.redo()
                        if let again = redo.popLast() { net.append(again) }
                    } catch {
                        continue
                    }
                } else {
                    do {
                        try play.apply(.run, expecting: play.fingerprint)
                        net.append(.run)
                        redo.removeAll()
                    } catch {
                        continue
                    }
                }
            }
            let computed: [Action] = Reconciliation.netTrace(play.records)
            #expect(computed == net, "walk \(walk)")
            let replay: Play? = try Self.replayed(number, computed)
            #expect(replay?.fingerprint == play.fingerprint, "walk \(walk)")
            #expect(replay?.stage == play.stage && replay?.actionsSpent == play.actionsSpent)
            #expect(Self.spends(computed) <= Progress.actionsSpent(play))
        }
    }
}
