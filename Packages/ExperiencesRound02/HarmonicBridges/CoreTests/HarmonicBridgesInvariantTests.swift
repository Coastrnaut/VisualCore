// HarmonicBridgesInvariantTests — feature 411 (R02-G12-01) T-R02G1201-006 (FR-R02G1201-012; the source's invariants
// R2-G12-INV-01 … 05 and INV-07 … 10 on Harmonic Bridges). Each named test gives a direct boundary example and a seeded
// check of neighbouring inputs (seed 2,416: a peg just outside 1 … 12, an action budget ± 1, a threshold one quarter
// above the critical one, a digit of a stored level changed, islands moved), as the source asks. How each invariant
// maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G12-02; INV-11 is superseded by the free tier):
// - INV-01 Time: no rule reads a clock and no presentation timestep decides anything. The same actions give the same
//   fingerprints, reports and records however many pauses and reads lie between them; an idle play never spends an
//   action or fails; the kernel sources hold no clock, time interval or floating-point value.
// - INV-02 Input budget: a tuning and a test each spend exactly 1 action; refusals (peg 0 and 13, an unknown or locked
//   string, a no-op, a stale fingerprint) spend nothing; the action that spends the last of the budget is applied and
//   judged (a test on it wins or breaks, a tuning on it fails the budget) and every later action is refused by stage.
// - INV-03 Goal: the level is won exactly when the goal is reached in every step of the crossing window; a swing that
//   equals the threshold is a bridge, one quarter below is not, so raising the threshold one quarter above the critical
//   value breaks the crossing.
// - INV-04 Repeatability: the same actions give the same records, fingerprints and outcome on independent runs and
//   through replay; an edited or forged record is refused.
// - INV-05 Undo: undo restores the exact prior pegs, actions spent, report, stage, failure and fingerprint; redo the
//   later one; a new action clears redo; a won level is final; a paused play stays paused; a failed play returns to
//   playing.
// - INV-07 Failure honesty: a failing test names the first step whose goal is missed and the lowest-index string across
//   the start's reach in that step, and that string really is a non-bridge there (an independent computation of its
//   swing); a budget failure names the index of the action that spent the last of the budget; a failed play undone
//   still wins with its known actions (no hidden solution).
// - INV-08 Stability: every reported swing is 0 … 36 quarters (3 tones × strength 3 × 4), every peg 1 … 12, the actions
//   spent 0 … budget; the report equals an independent computation (a swing table derived from n·k mod 6, resonance by
//   enumeration, reachability by relaxation to a fixed point).
// - INV-09 Save: the stored level round-trips byte for byte; truncated, edited, out-of-range and newer stored forms are
//   refused as a whole (no level is returned); a stored record trace up to a save point replays to the state at that
//   point; a damaged trace is refused.
// - INV-10 Renderer purity: the kernel types are value types; the drawing positions of the islands never change a rule
//   outcome (moved islands give identical reports, breaks and outcomes); reading, naming and copying change no
//   fingerprint; the kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation and use no clock,
//   random source, Double or Float. The scanned kernel list is Error, Resonance, Level, Play and Rules.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden import names are built by concatenation
// so that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import HarmonicBridgesCore

@Suite struct HarmonicBridgesInvariantTests {
    typealias Play = HarmonicBridgesPlay
    typealias Level = HarmonicBridgesLevel
    typealias Action = HarmonicBridgesAction
    typealias Failure = HarmonicBridgesFailure
    typealias Island = HarmonicBridgesIsland
    typealias Tone = HarmonicBridgesTone
    typealias Bridges = HarmonicBridgesString

    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = 2_416

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// The known winning actions on the hand level: string 3 to peg 1, then a test.
    static let winning: [Action] = [.tune(3, 1), .test]

    /// Actions on the hand level that wander (string 0 away and back) and then win.
    static let wanderThenWin: [Action] = [.tune(0, 4), .tune(0, 2), .tune(3, 1), .test]

    /// The kernel sources the scans read (the Core directory next to this test directory).
    static let kernelFiles: [String] = ["HarmonicBridgesError.swift", "HarmonicBridgesResonance.swift",
                                        "HarmonicBridgesLevel.swift", "HarmonicBridgesPlay.swift",
                                        "HarmonicBridgesRules.swift"]

    // MARK: Helpers

    /// The fixture of neighbouring index `index` (seed 2,416 onwards).
    static func neighbour(_ index: Int) -> HarmonicBridgesFixture {
        HarmonicBridgesFixtures.fixture(seed &+ UInt64(index))
    }

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: Level) throws(HarmonicBridgesError) -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A playing play of `level` with `actions` applied in order.
    static func played(_ level: Level, _ actions: [Action]) throws(HarmonicBridgesError) -> Play {
        var play: Play = try playing(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(HarmonicBridgesError) -> Void) -> HarmonicBridgesError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// The refusal of decoding `data`, or nil when it decoded.
    static func decodeRefusal(_ data: Data) -> HarmonicBridgesError? {
        do {
            _ = try Level.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// Whether `error` is a `.malformed` refusal (any payload).
    static func isMalformed(_ error: HarmonicBridgesError?) -> Bool {
        if case .malformed = error { return true }
        return false
    }

    /// `level` with some values replaced (the id, seed, strings, start, goal and tutorial kept).
    static func variant(_ level: Level, islands: [Island]? = nil, threshold: Int? = nil,
                        budget: Int? = nil) throws(HarmonicBridgesError) -> Level {
        try Level(id: level.id, seed: level.seed, difficulty: level.difficulty, islands: islands ?? level.islands,
                  strings: level.strings, start: level.start, goal: level.goal, steps: level.steps,
                  threshold: threshold ?? level.threshold, budget: budget ?? level.budget, tutorial: level.tutorial)
    }

    /// The known winning actions of `fixture`: its tunings, then a test.
    static func winningActions(_ fixture: HarmonicBridgesFixture) -> [Action] {
        var actions: [Action] = []
        for tuning in fixture.winningActions { actions.append(.tune(tuning.string, tuning.peg)) }
        actions.append(.test)
        return actions
    }

    /// A seeded action on `level`: mostly tunings in range, sometimes a test, a peg 0 or 13 or an unknown string.
    static func invAction(_ level: Level, random: inout SeededRandom) -> Action {
        let roll: Int = random.int(0...19)
        let count: Int = level.strings.count
        if roll < 3 { return .test }
        if roll == 3 { return .tune(random.int(0...(count - 1)), random.int(0...1) == 0 ? 0 : 13) }
        if roll == 4 { return .tune(count, random.int(1...12)) }
        return .tune(random.int(0...(count - 1)), random.int(1...12))
    }

    /// A seeded walk of up to `steps` actions on `level` (refusals skipped), from stage `playing`.
    static func invWalk(_ level: Level, steps: Int, random: inout SeededRandom) throws -> Play {
        var play: Play = try playing(level)
        for _ in 0..<steps {
            if play.stage != .playing { break }
            let action: Action = invAction(level, random: &random)
            _ = refusal { () throws(HarmonicBridgesError) in try play.apply(action, expecting: play.fingerprint) }
        }
        return play
    }

    /// The kernel sources (the listed files of the Core directory next to this test directory).
    static func kernelSources() throws -> [(name: String, text: String)] {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
        var sources: [(name: String, text: String)] = []
        for name in kernelFiles {
            let text: String = try String(contentsOf: core.appendingPathComponent(name), encoding: .utf8)
            sources.append((name, text))
        }
        return sources
    }

    // MARK: Independent computations

    /// q(n, k) = 4 sin²(nπk/6) derived from n·k mod 6 (0 → 0, 1 or 5 → 1, 2 or 4 → 3, 3 → 4), not from the kernel table.
    static func invQuarter(_ n: Int, _ k: Int) -> Int {
        switch (n * k) % 6 {
        case 0: return 0
        case 1, 5: return 1
        case 2, 4: return 3
        default: return 4
        }
    }

    /// The swing of `string` at `peg` under `tones`: every mode n in 1 … 5 with n·peg = F·length, by enumeration.
    static func invSwing(_ string: Bridges, peg: Int, tones: [Tone]) -> [Int] {
        var swing: [Int] = [0, 0, 0, 0, 0]
        for tone in tones {
            for n in 1...5 where n * peg == tone.frequency * string.length {
                for k in 1...5 { swing[k - 1] += tone.strength * invQuarter(n, k) }
            }
        }
        return swing
    }

    /// Whether `swing` reaches `threshold` at every sample.
    static func invBridge(_ swing: [Int], threshold: Int) -> Bool {
        for value in swing where value < threshold { return false }
        return true
    }

    /// The islands the start reaches over `bridges`, by relaxation to a fixed point (no queue).
    static func invReached(_ level: Level, bridges: [Bool]) -> [Bool] {
        var reached: [Bool] = Array(repeating: false, count: level.islands.count)
        reached[level.start] = true
        var changed: Bool = true
        while changed {
            changed = false
            for (index, string) in level.strings.enumerated() where bridges[index] {
                if reached[string.a] != reached[string.b] {
                    reached[string.a] = true
                    reached[string.b] = true
                    changed = true
                }
            }
        }
        return reached
    }

    /// The truth metric at `pegs`, computed independently.
    static func invReport(_ level: Level, pegs: [Int]) -> (swings: [[[Int]]], bridges: [[Bool]], reached: [[Bool]]) {
        var swings: [[[Int]]] = []
        var bridges: [[Bool]] = []
        var reached: [[Bool]] = []
        for tones in level.steps {
            var stepSwings: [[Int]] = []
            var stepBridges: [Bool] = []
            for (index, string) in level.strings.enumerated() {
                let swing: [Int] = invSwing(string, peg: pegs[index], tones: tones)
                stepSwings.append(swing)
                stepBridges.append(invBridge(swing, threshold: level.threshold))
            }
            swings.append(stepSwings)
            bridges.append(stepBridges)
            reached.append(invReached(level, bridges: stepBridges))
        }
        return (swings, bridges, reached)
    }

    /// The break at `pegs`, computed independently: the first step whose goal is missed and the lowest-index non-bridge
    /// string across the cut (nil when none crosses); nil when the goal is reached in every step.
    static func invBreak(_ level: Level, pegs: [Int]) -> (step: Int, string: Int?)? {
        let report: (swings: [[[Int]]], bridges: [[Bool]], reached: [[Bool]]) = invReport(level, pegs: pegs)
        for step in 0..<level.steps.count where !report.reached[step][level.goal] {
            for (index, string) in level.strings.enumerated() {
                let crosses: Bool = report.reached[step][string.a] != report.reached[step][string.b]
                if crosses && !report.bridges[step][index] { return (step, index) }
            }
            return (step, nil)
        }
        return nil
    }

    /// Checks `report` (of `level` at `pegs`) against the independent computation.
    static func invCheckReport(_ report: HarmonicBridgesReport, _ level: Level, pegs: [Int]) {
        let expected: (swings: [[[Int]]], bridges: [[Bool]], reached: [[Bool]]) = invReport(level, pegs: pegs)
        #expect(report.swings == expected.swings)
        #expect(report.bridges == expected.bridges)
        #expect(report.reached == expected.reached)
    }

    // MARK: INV-01 Time

    /// INV-01 Time: no rule reads a clock; pauses, reads and plucks between actions change no fingerprint, report or
    /// outcome; an idle play never spends or fails.
    @Test func testHarmonicBridgesTimeBoundary() throws {
        let level: Level = HarmonicBridgesFixtures.handLevel()
        // Direct example: the same actions applied straight and after many pauses, reads and plucks.
        var straight: Play = try Self.playing(level)
        var framed: Play = try Self.playing(level)
        for action in Self.wanderThenWin {
            try straight.apply(action, expecting: straight.fingerprint)
            for _ in 0..<120 {
                _ = framed.fingerprint
                _ = framed.progressDescription
                for string in 0..<level.strings.count { _ = try framed.pluck(string) }
                try framed.handle(.pause)
                try framed.handle(.resume)
            }
            try framed.apply(action, expecting: framed.fingerprint)
            #expect(framed.fingerprint == straight.fingerprint && framed.report == straight.report)
            #expect(framed.actionsSpent == straight.actionsSpent)
        }
        #expect(straight.stage == .won && framed.stage == .won)
        #expect(straight.records == framed.records)
        // An idle play neither spends an action nor fails, however long it waits or how often it is paused.
        var idle: Play = try Self.playing(level)
        let opening: String = idle.fingerprint
        for _ in 0..<1_000 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.stage == .playing && idle.actionsSpent == 0 && idle.failure == nil)
        #expect(idle.fingerprint == opening && idle.records.isEmpty)
        #expect(idle.report == level.report(pegs: level.startingPegs))
        // The kernel holds no clock, time interval or floating-point value.
        let tokens: [String] = ["Double", "Float", "TimeInterval", "Date", "Clock", "CFAbsoluteTime", "DispatchTime",
                                "Timer", "deltaTime", "timestep"]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count == Self.kernelFiles.count)
        for source in sources {
            for token in tokens { #expect(!source.text.contains(token), "\(source.name) uses \(token)") }
        }
        // Seeded neighbours: accepted actions repeated after seeded numbers of pauses and reads reach the same
        // fingerprint and report after every action and the same records.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for index in 0..<30 {
            let fixture: HarmonicBridgesFixture = Self.neighbour(index)
            var a: Play = try Self.playing(fixture.level)
            var b: Play = try Self.playing(fixture.level)
            for _ in 0..<20 {
                if a.stage != .playing { break }
                let action: Action = Self.invAction(fixture.level, random: &random)
                let error: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                if error != nil { continue }
                let frames: Int = random.int(0...6)
                for _ in 0..<frames {
                    try b.handle(.pause)
                    _ = b.fingerprint
                    _ = b.progressDescription
                    try b.handle(.resume)
                }
                try b.apply(action, expecting: b.fingerprint)
                #expect(a.fingerprint == b.fingerprint && a.report == b.report && a.stage == b.stage)
            }
            #expect(a.records == b.records)
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: each tuning and test spends 1; refusals spend nothing; the last action of the budget is
    /// judged and later actions are refused by stage.
    @Test func testHarmonicBridgesInputbudgetBoundary() throws {
        // Direct example: refusals on a fresh play of the hand level spend nothing.
        let level: Level = HarmonicBridgesFixtures.handLevel()
        var fresh: Play = try Self.playing(level)
        let opening: String = fresh.fingerprint
        let refused: [(Action, HarmonicBridgesError)] = [(.tune(0, 0), .action("peg")), (.tune(0, 13), .action("peg")),
                                                         (.tune(4, 1), .action("string")),
                                                         (.tune(-1, 1), .action("string")), (.tune(0, 2), .noop)]
        for entry in refused {
            let error: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
                try fresh.apply(entry.0, expecting: fresh.fingerprint)
            }
            #expect(error == entry.1)
        }
        let stale: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
            try fresh.apply(.tune(0, 3), expecting: Self.staleFingerprint)
        }
        #expect(stale == .stale)
        var locked: Play = try Self.playing(HarmonicBridgesFixtures.handLevel(lockedLast: true))
        let lockedError: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
            try locked.apply(.tune(3, 1), expecting: locked.fingerprint)
        }
        #expect(lockedError == .action("locked") && locked.actionsSpent == 0 && locked.records.isEmpty)
        #expect(fresh.fingerprint == opening && fresh.actionsSpent == 0 && fresh.records.isEmpty)
        // Pegs 1 and 12 are inside the range; each accepted tuning spends exactly 1 action.
        try fresh.apply(.tune(0, 1), expecting: fresh.fingerprint)
        #expect(fresh.actionsSpent == 1 && fresh.actionsLeft == level.budget - 1)
        try fresh.apply(.tune(0, 12), expecting: fresh.fingerprint)
        #expect(fresh.actionsSpent == 2 && fresh.pegs[0] == 12)
        try fresh.undo()
        #expect(fresh.actionsSpent == 1)
        try fresh.redo()
        #expect(fresh.actionsSpent == 2)
        // Budget 3: the third tuning spends the last action and fails the budget at index 2; then every action is
        // refused by stage and spends nothing.
        var spent: Play = try Self.played(HarmonicBridgesFixtures.handLevel(budget: 3), [.tune(0, 4), .tune(0, 2)])
        #expect(spent.stage == .playing && spent.actionsLeft == 1)
        try spent.apply(.tune(0, 4), expecting: spent.fingerprint)
        #expect(spent.stage == .failed && spent.failure == .budget(2) && spent.actionsLeft == 0)
        let after: [Action] = [.test, .tune(3, 1)]
        for action in after {
            let error: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
                try spent.apply(action, expecting: spent.fingerprint)
            }
            #expect(error == .stage && spent.actionsSpent == 3 && spent.records.count == 3)
        }
        // A winning test on the last action wins; a failing test on the last action breaks (not the budget).
        let lastWin: Play = try Self.played(HarmonicBridgesFixtures.handLevel(budget: 2), Self.winning)
        #expect(lastWin.stage == .won && lastWin.failure == nil && lastWin.actionsLeft == 0)
        let lastBreak: Play = try Self.played(HarmonicBridgesFixtures.handLevel(budget: 1), [.test])
        #expect(lastBreak.stage == .failed && lastBreak.failure == .broken(step: 1, string: 0))
        // Seeded neighbours: budgets of the known actions' count and one either side; peg 0 and 13 and an unknown
        // string refused on a seeded string.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 1)
        for index in 0..<30 {
            let fixture: HarmonicBridgesFixture = Self.neighbour(index)
            let actions: [Action] = Self.winningActions(fixture)
            let needed: Int = actions.count
            let exact: Play = try Self.played(try Self.variant(fixture.level, budget: needed), actions)
            #expect(exact.stage == .won && exact.actionsSpent == needed && exact.actionsLeft == 0)
            let roomy: Play = try Self.played(try Self.variant(fixture.level, budget: needed + 1), actions)
            #expect(roomy.stage == .won && roomy.actionsLeft == 1)
            var short: Play = try Self.playing(try Self.variant(fixture.level, budget: needed - 1))
            for action in actions.dropLast() { try short.apply(action, expecting: short.fingerprint) }
            #expect(short.stage == .failed && short.failure == .budget(needed - 2))
            #expect(short.records.last?.index == needed - 2)
            let late: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
                try short.apply(.test, expecting: short.fingerprint)
            }
            #expect(late == .stage && short.actionsSpent == needed - 1)
            var probe: Play = try Self.playing(fixture.level)
            let string: Int = random.int(0...(fixture.level.strings.count - 1))
            let outside: [Action] = [.tune(string, 0), .tune(string, 13), .tune(fixture.level.strings.count, 1)]
            for action in outside {
                let error: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
                    try probe.apply(action, expecting: probe.fingerprint)
                }
                #expect(error == .action("peg") || error == .action("string"))
            }
            #expect(probe.actionsSpent == 0 && probe.records.isEmpty)
        }
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: won only when the goal is reached in every step; a swing equal to the threshold is a bridge and one
    /// quarter below is not.
    @Test func testHarmonicBridgesGoalBoundary() throws {
        // Direct example: on the hand level the winning pegs reach the goal in both steps; string 0's swing in step 0
        // is 2 6 8 6 2, a bridge at threshold 2 and not at 3.
        let level: Level = HarmonicBridgesFixtures.handLevel()
        let winningPegs: [Int] = [2, 4, 3, 1]
        #expect(level.report(pegs: winningPegs).goalReachedInEveryStep)
        #expect(level.resonance(0, step: 0, peg: 2).swing == [2, 6, 8, 6, 2])
        #expect(level.resonance(0, step: 0, peg: 2).bridge)
        let won: Play = try Self.played(level, Self.winning)
        #expect(won.stage == .won && won.failure == nil)
        // One quarter more threshold: the minimum swing of strings 0 and 1 (2) falls one quarter short in step 0.
        let higher: Level = try Self.variant(level, threshold: 3)
        #expect(!higher.resonance(0, step: 0, peg: 2).bridge)
        let broken: Play = try Self.played(higher, Self.winning)
        #expect(broken.stage == .failed && broken.failure == .broken(step: 0, string: 0))
        // The goal reached in step 0 only is not a win: the starting pegs miss it in step 1.
        let start: HarmonicBridgesReport = level.report(pegs: level.startingPegs)
        #expect(start.reached[0][level.goal] && !start.reached[1][level.goal] && !start.goalReachedInEveryStep)
        let early: Play = try Self.played(level, [.test])
        #expect(early.stage == .failed && early.failure == .broken(step: 1, string: 0))
        // Seeded neighbours: at the winning pegs the critical threshold wins and one quarter above breaks; the starting
        // pegs never win.
        for index in 0..<30 {
            let fixture: HarmonicBridgesFixture = Self.neighbour(index)
            var critical: Int = 0
            for threshold in 1...12 {
                let candidate: Level = try Self.variant(fixture.level, threshold: threshold)
                let wins: Bool = candidate.report(pegs: fixture.winningPegs).goalReachedInEveryStep
                if threshold <= fixture.level.threshold { #expect(wins, "threshold \(threshold) below the fixture's") }
                if wins {
                    #expect(critical == threshold - 1, "wins are monotone in the threshold")
                    critical = threshold
                }
            }
            #expect(critical >= fixture.level.threshold)
            let actions: [Action] = Self.winningActions(fixture)
            let atCritical: Play = try Self.played(try Self.variant(fixture.level, threshold: critical), actions)
            #expect(atCritical.stage == .won)
            if critical < 12 {
                let above: Level = try Self.variant(fixture.level, threshold: critical + 1)
                let missed: Play = try Self.played(above, actions)
                let expected: (step: Int, string: Int?)? = Self.invBreak(above, pegs: fixture.winningPegs)
                let unwrapped: (step: Int, string: Int?) = try #require(expected)
                #expect(missed.stage == .failed)
                #expect(missed.failure == .broken(step: unwrapped.step, string: unwrapped.string))
            }
            let opening: Play = try Self.played(fixture.level, [.test])
            #expect(opening.stage == .failed)
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same actions give the same records, fingerprints and outcome; replay reproduces them;
    /// an edited or forged record is refused.
    @Test func testHarmonicBridgesRepeatabilityBoundary() throws {
        // Direct example: two independent runs and a replay of the hand level's wandering win.
        let level: Level = HarmonicBridgesFixtures.handLevel()
        let first: Play = try Self.played(level, Self.wanderThenWin)
        let second: Play = try Self.played(level, Self.wanderThenWin)
        #expect(first.records == second.records && first.fingerprint == second.fingerprint)
        #expect(first.stage == .won && second.stage == .won)
        let replayed: Play = try Play.replay(level: level, records: first.records)
        #expect(replayed.records == first.records && replayed.fingerprint == first.fingerprint)
        // An edited next fingerprint, an edited previous fingerprint and a forged seed are refused.
        let original: HarmonicBridgesRecord = first.records[1]
        var editedNext: [HarmonicBridgesRecord] = first.records
        editedNext[1] = HarmonicBridgesRecord(schema: original.schema, seed: original.seed, index: original.index,
                                              kind: original.kind, action: original.action,
                                              previous: original.previous, next: Self.staleFingerprint)
        let nextError: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
            _ = try Play.replay(level: level, records: editedNext)
        }
        #expect(nextError == .malformed("record 1"))
        var editedPrevious: [HarmonicBridgesRecord] = first.records
        editedPrevious[1] = HarmonicBridgesRecord(schema: original.schema, seed: original.seed, index: original.index,
                                                  kind: original.kind, action: original.action,
                                                  previous: Self.staleFingerprint, next: original.next)
        let previousError: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
            _ = try Play.replay(level: level, records: editedPrevious)
        }
        #expect(previousError == .malformed("replay"))
        var forged: [HarmonicBridgesRecord] = first.records
        let head: HarmonicBridgesRecord = first.records[0]
        forged[0] = HarmonicBridgesRecord(schema: head.schema, seed: head.seed &+ 1, index: head.index,
                                          kind: head.kind, action: head.action, previous: head.previous,
                                          next: head.next)
        let seedError: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
            _ = try Play.replay(level: level, records: forged)
        }
        #expect(seedError == .malformed("seed 0"))
        // Seeded neighbours: two walks from the same seed agree; the replay agrees; a record whose next fingerprint is
        // edited at a seeded index is refused.
        var pick: SeededRandom = SeededRandom(seed: Self.seed &+ 3)
        for index in 0..<30 {
            let fixture: HarmonicBridgesFixture = Self.neighbour(index)
            var randomA: SeededRandom = SeededRandom(seed: Self.seed &+ 100 &+ UInt64(index))
            var randomB: SeededRandom = SeededRandom(seed: Self.seed &+ 100 &+ UInt64(index))
            let a: Play = try Self.invWalk(fixture.level, steps: 20, random: &randomA)
            let b: Play = try Self.invWalk(fixture.level, steps: 20, random: &randomB)
            #expect(a.records == b.records && a.fingerprint == b.fingerprint && a.stage == b.stage)
            #expect(a.failure == b.failure)
            if a.records.isEmpty { continue }
            let again: Play = try Play.replay(level: fixture.level, records: a.records)
            #expect(again.records == a.records && again.fingerprint == a.fingerprint)
            let at: Int = pick.int(0...(a.records.count - 1))
            let record: HarmonicBridgesRecord = a.records[at]
            var edited: [HarmonicBridgesRecord] = a.records
            edited[at] = HarmonicBridgesRecord(schema: record.schema, seed: record.seed, index: record.index,
                                               kind: record.kind, action: record.action, previous: record.previous,
                                               next: Self.staleFingerprint)
            let error: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
                _ = try Play.replay(level: fixture.level, records: edited)
            }
            #expect(error == .malformed("record \(at)"))
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: undo and redo restore exact moments; a new action clears redo; a won play is final; a paused play
    /// stays paused; a failed play returns to playing.
    @Test func testHarmonicBridgesUndoBoundary() throws {
        let level: Level = HarmonicBridgesFixtures.handLevel()
        // Direct example: a tuning undone and redone.
        var play: Play = try Self.playing(level)
        let nothing: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in try play.undo() }
        #expect(nothing == .action("undo"))
        let before: String = play.fingerprint
        try play.apply(.tune(3, 1), expecting: play.fingerprint)
        let after: String = play.fingerprint
        try play.undo()
        #expect(play.fingerprint == before && play.pegs == level.startingPegs && play.actionsSpent == 0)
        #expect(play.report == level.report(pegs: level.startingPegs) && play.stage == .playing)
        try play.redo()
        #expect(play.fingerprint == after && play.pegs == [2, 4, 3, 1] && play.actionsSpent == 1)
        // A new action clears redo.
        try play.undo()
        try play.apply(.tune(0, 4), expecting: play.fingerprint)
        let cleared: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in try play.redo() }
        #expect(cleared == .action("redo") && !play.canRedo)
        // A paused play stays paused through undo.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused && play.actionsSpent == 0)
        try play.handle(.resume)
        // A failed test undone returns to playing at the exact prior moment.
        let ready: String = play.fingerprint
        try play.apply(.test, expecting: play.fingerprint)
        #expect(play.stage == .failed)
        try play.undo()
        #expect(play.stage == .playing && play.fingerprint == ready && play.failure == nil)
        // A won play is final.
        for action in Self.winning { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        let final: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in try play.undo() }
        #expect(final == .stage && play.stage == .won)
        // Seeded neighbours: after every accepted action of seeded walks, undo restores the moment before (fingerprint,
        // pegs, actions spent, report, failure) and redo the moment after.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 4)
        for index in 0..<30 {
            let fixture: HarmonicBridgesFixture = Self.neighbour(index)
            var walk: Play = try Self.playing(fixture.level)
            for _ in 0..<20 {
                if walk.stage != .playing { break }
                let action: Action = Self.invAction(fixture.level, random: &random)
                let held: Play = walk
                let error: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
                    try walk.apply(action, expecting: walk.fingerprint)
                }
                if error != nil {
                    #expect(walk == held)
                    continue
                }
                if walk.stage == .won {
                    #expect(!walk.canUndo)
                    break
                }
                let later: String = walk.fingerprint
                try walk.undo()
                #expect(walk.fingerprint == held.fingerprint && walk.pegs == held.pegs)
                #expect(walk.actionsSpent == held.actionsSpent && walk.report == held.report)
                #expect(walk.failure == held.failure && walk.stage == .playing)
                try walk.redo()
                #expect(walk.fingerprint == later)
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: a failing test names its step and a string that really is a non-bridge across the cut; a
    /// budget failure names its action; a failed play undone still wins with its known actions.
    @Test func testHarmonicBridgesFailurehonestyBoundary() throws {
        // Direct example: the hand level's opening test breaks in step 1 at string 0, which joins the reached island 0
        // to the unreached island 1 and is silent in step 1.
        let level: Level = HarmonicBridgesFixtures.handLevel()
        var play: Play = try Self.played(level, [.test])
        #expect(play.failure == .broken(step: 1, string: 0))
        #expect(play.report.reached[1] == [true, false, true, false])
        #expect(!play.report.bridges[1][0])
        #expect(Self.invSwing(level.strings[0], peg: 2, tones: level.steps[1]) == [0, 0, 0, 0, 0])
        let words: String = try play.pluck(0)
        let expectedWords: String = "string 0, island 0 to island 1, peg 2: step 0: mode 1, swing 2 6 8 6 2, a bridge; "
            + "step 1: no modes, swing 0 0 0 0 0, not a bridge"
        #expect(words == expectedWords)
        // No hidden solution: undone, the known actions win.
        try play.undo()
        for action in Self.winning { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        // No string across the cut: a bridge from 0 to 1 and no string to the goal 2 names no string.
        let isolated: Level = try Level(id: "isolated", seed: Self.seed, difficulty: 1,
                                        islands: [Island(x: 0, y: 0), Island(x: 4, y: 0), Island(x: 8, y: 0)],
                                        strings: [Bridges(a: 0, b: 1, length: 1, peg: 2)], start: 0, goal: 2,
                                        steps: [[Tone(frequency: 2, strength: 2)]], threshold: 2, budget: 3)
        let none: Play = try Self.played(isolated, [.test])
        #expect(none.failure == .broken(step: 0, string: nil))
        // A budget failure names the index of the action that spent the last of the budget (its record's index).
        let spent: Play = try Self.played(HarmonicBridgesFixtures.handLevel(budget: 2), [.tune(0, 4), .tune(0, 2)])
        #expect(spent.failure == .budget(1) && spent.records.last?.index == 1)
        // Seeded neighbours: at seeded pegs, every named break equals the independent one; the named string crosses
        // the cut and its independently computed swing falls below the threshold somewhere in that step; a nil string
        // means no string crosses. The opening test of every fixture names the independent break.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 5)
        for index in 0..<30 {
            let fixture: HarmonicBridgesFixture = Self.neighbour(index)
            let other: Level = fixture.level
            for _ in 0..<10 {
                var pegs: [Int] = []
                for _ in 0..<other.strings.count { pegs.append(random.int(1...12)) }
                let named: HarmonicBridgesBreak? = other.firstBreak(other.report(pegs: pegs))
                let expected: (step: Int, string: Int?)? = Self.invBreak(other, pegs: pegs)
                #expect(named?.step == expected?.step && named?.string == expected?.string)
                guard let named else { continue }
                let reached: [Bool] = Self.invReport(other, pegs: pegs).reached[named.step]
                #expect(!reached[other.goal])
                if let string = named.string {
                    let joined: Bridges = other.strings[string]
                    #expect(reached[joined.a] != reached[joined.b], "string \(string) crosses the cut")
                    let swing: [Int] = Self.invSwing(joined, peg: pegs[string], tones: other.steps[named.step])
                    #expect(!Self.invBridge(swing, threshold: other.threshold), "string \(string) is no bridge")
                } else {
                    for joined in other.strings { #expect(reached[joined.a] == reached[joined.b]) }
                }
            }
            let opening: Play = try Self.played(other, [.test])
            let expected: (step: Int, string: Int?)? = Self.invBreak(other, pegs: other.startingPegs)
            let unwrapped: (step: Int, string: Int?) = try #require(expected)
            #expect(opening.failure == .broken(step: unwrapped.step, string: unwrapped.string))
            var retry: Play = opening
            try retry.undo()
            for action in Self.winningActions(fixture) { try retry.apply(action, expecting: retry.fingerprint) }
            #expect(retry.stage == .won && retry.failure == nil)
        }
    }

    // MARK: INV-08 Stability

    /// INV-08 Stability: every reported number is bounded (swings 0 … 36, pegs 1 … 12, actions 0 … budget) and the report
    /// equals an independent computation.
    @Test func testHarmonicBridgesStabilityBoundary() throws {
        // Direct example: three strength-3 tones resonating modes 1, 3 and 5 give the largest swing, 36 at the middle.
        let loudest: Level = try Level(id: "loudest", seed: Self.seed, difficulty: 1,
                                       islands: [Island(x: 0, y: 0), Island(x: 15, y: 9)],
                                       strings: [Bridges(a: 0, b: 1, length: 1, peg: 1)], start: 0, goal: 1,
                                       steps: [[Tone(frequency: 1, strength: 3), Tone(frequency: 3, strength: 3),
                                                Tone(frequency: 5, strength: 3)]], threshold: 12, budget: 60)
        #expect(loudest.resonance(0, step: 0, peg: 1).swing == [18, 18, 36, 18, 18])
        #expect(loudest.resonance(0, step: 0, peg: 1).resonatingModes == [1, 3, 5])
        var bounds: Play = try Self.playing(loudest)
        try bounds.apply(.tune(0, 12), expecting: bounds.fingerprint)
        let outside: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
            try bounds.apply(.tune(0, 13), expecting: bounds.fingerprint)
        }
        #expect(outside == .action("peg") && bounds.pegs == [12])
        try bounds.apply(.tune(0, 1), expecting: bounds.fingerprint)
        try bounds.apply(.test, expecting: bounds.fingerprint)
        #expect(bounds.stage == .won)
        // Seeded neighbours: after every accepted action of seeded walks every number stays in range and the report
        // equals the independent computation.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 6)
        for index in 0..<30 {
            let fixture: HarmonicBridgesFixture = Self.neighbour(index)
            let other: Level = fixture.level
            var walk: Play = try Self.playing(other)
            for _ in 0..<20 {
                if walk.stage != .playing { break }
                let action: Action = Self.invAction(other, random: &random)
                _ = Self.refusal { () throws(HarmonicBridgesError) in try walk.apply(action, expecting: walk.fingerprint) }
                #expect(walk.actionsSpent >= 0 && walk.actionsSpent <= other.budget)
                #expect(walk.actionsLeft >= 0 && walk.actionsLeft <= other.budget)
                #expect(walk.pegs.count == other.strings.count)
                for peg in walk.pegs { #expect(peg >= 1 && peg <= 12) }
                #expect(walk.report.swings.count == other.steps.count)
                for stepSwings in walk.report.swings {
                    #expect(stepSwings.count == other.strings.count)
                    for swing in stepSwings {
                        #expect(swing.count == 5)
                        for value in swing { #expect(value >= 0 && value <= 36) }
                    }
                }
                for count in walk.report.bridgeCounts { #expect(count >= 0 && count <= other.strings.count) }
                for stepReached in walk.report.reached { #expect(stepReached[other.start]) }
                Self.invCheckReport(walk.report, other, pegs: walk.pegs)
            }
        }
    }

    // MARK: INV-09 Save

    /// INV-09 Save: the stored level round-trips byte for byte; damaged stored forms are refused whole; a stored record
    /// trace replays to the state at its save point and a damaged trace is refused.
    @Test func testHarmonicBridgesSaveBoundary() throws {
        // Direct example: the hand level round-trips, and each damage is refused with its reason.
        let level: Level = HarmonicBridgesFixtures.handLevel()
        let stored: Data = level.encoded()
        let decoded: Level = try Level.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored)
        let text: String = try #require(String(data: stored, encoding: .utf8))
        #expect(text.contains("\"threshold\":2") && text.contains("\"schema\":1") && text.contains("\"budget\":6"))
        let edited: Data = Data(text.replacingOccurrences(of: "\"threshold\":2", with: "\"threshold\":3").utf8)
        #expect(Self.decodeRefusal(edited) == .malformed("fingerprint"))
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(Self.decodeRefusal(newer) == .newerSchema(2))
        let outOfRange: Data = Data(text.replacingOccurrences(of: "\"budget\":6", with: "\"budget\":61").utf8)
        #expect(Self.decodeRefusal(outOfRange) == .malformed("r02-g12.level"))
        let truncated: Data = stored.prefix(stored.count - 1)
        #expect(Self.decodeRefusal(truncated) == .malformed("unreadable"))
        let damaged: [Data] = [edited, newer, outOfRange, truncated]
        for data in damaged {
            let viaCodable: Level? = try? JSONDecoder().decode(Level.self, from: data)
            #expect(viaCodable == nil)
        }
        // A stored record trace replays to the state at each save point; a damaged trace is refused.
        let play: Play = try Self.played(level, Self.wanderThenWin)
        for cut in 1...play.records.count {
            let prefix: [HarmonicBridgesRecord] = Array(play.records.prefix(cut))
            let trace: Data = try JSONEncoder().encode(prefix)
            let loaded: [HarmonicBridgesRecord] = try JSONDecoder().decode([HarmonicBridgesRecord].self, from: trace)
            let restored: Play = try Play.replay(level: decoded, records: loaded)
            #expect(restored.fingerprint == prefix[cut - 1].next && restored.records == prefix)
        }
        let trace: Data = try JSONEncoder().encode(play.records)
        let traceText: String = try #require(String(data: trace, encoding: .utf8))
        let brokenTrace: Data = Data(traceText.replacingOccurrences(of: play.records[2].next,
                                                                    with: Self.staleFingerprint).utf8)
        let loadedBroken: [HarmonicBridgesRecord] = try JSONDecoder().decode([HarmonicBridgesRecord].self,
                                                                            from: brokenTrace)
        let traceError: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
            _ = try Play.replay(level: decoded, records: loadedBroken)
        }
        #expect(Self.isMalformed(traceError))
        // Seeded neighbours: every fixture round-trips byte for byte; a digit changed to another digit at three seeded
        // positions, and a seeded truncation, are each refused whole.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 7)
        let zero: UInt8 = 48
        let nine: UInt8 = 57
        for index in 0..<30 {
            let other: Level = Self.neighbour(index).level
            let bytes: Data = other.encoded()
            let again: Level = try Level.decode(bytes)
            #expect(again == other && again.encoded() == bytes)
            var digits: [Int] = []
            for (position, byte) in bytes.enumerated() where byte >= zero && byte <= nine { digits.append(position) }
            for _ in 0..<3 {
                let position: Int = digits[random.int(0...(digits.count - 1))]
                var changed: [UInt8] = Array(bytes)
                let old: Int = Int(changed[position] - zero)
                changed[position] = zero + UInt8((old + random.int(1...9)) % 10)
                let error: HarmonicBridgesError? = Self.decodeRefusal(Data(changed))
                #expect(error != nil, "digit at \(position) changed was accepted")
            }
            let length: Int = random.int(0...(bytes.count - 1))
            #expect(Self.decodeRefusal(bytes.prefix(length)) != nil, "truncation to \(length) was accepted")
        }
    }

    // MARK: INV-10 Renderer purity

    /// INV-10 Renderer purity: value types only; island positions decide nothing; reading changes nothing; the kernel
    /// imports no rendering framework.
    @Test func testHarmonicBridgesRendererpurityBoundary() throws {
        let level: Level = HarmonicBridgesFixtures.handLevel()
        // Direct example: the kernel types are value types.
        let play: Play = try Self.played(level, [.tune(0, 4)])
        #expect(Mirror(reflecting: level).displayStyle == .struct)
        #expect(Mirror(reflecting: play).displayStyle == .struct)
        #expect(Mirror(reflecting: play.report).displayStyle == .struct)
        #expect(Mirror(reflecting: play.records[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: level.strings[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: level.islands[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: level.resonance(0, step: 0, peg: 2)).displayStyle == .struct)
        #expect(Mirror(reflecting: Action.test).displayStyle == .enum)
        #expect(Mirror(reflecting: Failure.budget(0)).displayStyle == .enum)
        #expect(Mirror(reflecting: HarmonicBridgesStage.playing).displayStyle == .enum)
        // The play holds no visual state: no field names a colour, vertex, texture, shader, frame, time or layer.
        let visual: [String] = ["colo", "vertex", "texture", "shader", "frame", "time", "layer", "pixel", "mesh"]
        for child in Mirror(reflecting: play).children {
            let label: String = (child.label ?? "").lowercased()
            for word in visual { #expect(!label.contains(word), "the play holds \(label)") }
        }
        // Moved islands: the same actions give identical reports, breaks, pegs, stages and failures.
        let moved: [Island] = [Island(x: 15, y: 9), Island(x: 0, y: 0), Island(x: 7, y: 3), Island(x: 2, y: 8)]
        let elsewhere: Level = try Self.variant(level, islands: moved)
        #expect(elsewhere.fingerprint != level.fingerprint)
        let pegSets: [[Int]] = [level.startingPegs, [2, 4, 3, 1], [12, 1, 6, 1], [1, 1, 1, 1]]
        for pegs in pegSets {
            #expect(elsewhere.report(pegs: pegs) == level.report(pegs: pegs))
            #expect(elsewhere.firstBreak(elsewhere.report(pegs: pegs)) == level.firstBreak(level.report(pegs: pegs)))
        }
        let sequences: [[Action]] = [[.test], Self.wanderThenWin]
        for actions in sequences {
            let here: Play = try Self.played(level, actions)
            let there: Play = try Self.played(elsewhere, actions)
            #expect(here.report == there.report && here.pegs == there.pegs && here.stage == there.stage)
            #expect(here.failure == there.failure && here.actionsSpent == there.actionsSpent)
        }
        // A copy is independent, and reading names, descriptions and plucks changes nothing.
        let original: Play = play
        var copy: Play = play
        try copy.apply(.tune(0, 2), expecting: copy.fingerprint)
        #expect(play == original && copy.pegs[0] == 2 && play.pegs[0] == 4)
        let fingerprint: String = play.fingerprint
        var words: [String] = [play.progressDescription]
        for string in 0..<level.strings.count {
            words.append(try play.pluck(string))
            words.append(level.stringName(string, peg: play.pegs[string]))
            words.append(level.resonanceDescription(string, pegs: play.pegs))
        }
        _ = play.canUndo
        _ = play.canRedo
        #expect(words.count == 1 + 3 * level.strings.count)
        #expect(play.fingerprint == fingerprint && play == original)
        // The kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation, read no clock or random
        // source, use no Double or Float and declare no class. Forbidden import lines are built by concatenation.
        let prefix: String = "import" + " "
        let frameworks: [String] = ["UIKit", "SwiftUI", "AppKit", "Metal", "MetalKit", "QuartzCore", "OpenGLES",
                                    "GLKit", "CoreGraphics", "SpriteKit", "SceneKit", "GameKit", "CoreMotion",
                                    "Combine", "VisualCoreRendering", "CoreImage", "AVFoundation"]
        var forbidden: [String] = []
        for name in frameworks { forbidden.append(prefix + name) }
        let calls: [String] = ["Date()", "Date.now", "CFAbsoluteTimeGetCurrent", "CACurrentMediaTime",
                               "DispatchTime.now", "ContinuousClock", "SuspendingClock", "systemUptime",
                               "SystemRandomNumberGenerator", ".random(", "arc4random", "UUID()", "Double", "Float",
                               "CGFloat"]
        forbidden.append(contentsOf: calls)
        let allowedImports: Set<String> = [prefix + "Foundation", prefix + "VisualCoreMath",
                                           prefix + "VisualCoreSimulation"]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count == Self.kernelFiles.count)
        for source in sources {
            for token in forbidden {
                #expect(!source.text.contains(token), "\(source.name) uses \(token)")
            }
            for line in source.text.split(separator: "\n") {
                let trimmed: String = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(prefix) {
                    #expect(allowedImports.contains(trimmed), "\(source.name) imports \(trimmed)")
                }
                let isClass: Bool = trimmed.hasPrefix("class ") || trimmed.hasPrefix("final class ")
                    || trimmed.hasPrefix("public class ") || trimmed.hasPrefix("public final class ")
                    || trimmed.hasPrefix("open class ")
                #expect(!isClass, "\(source.name) declares a reference type: \(trimmed)")
            }
        }
        // Seeded neighbours: islands moved to seeded distinct positions give the same outcome after every action of
        // the same seeded walk; reading the words on the moved level changes no fingerprint.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 8)
        for index in 0..<30 {
            let other: Level = Self.neighbour(index).level
            var positions: [Island] = []
            var used: Set<Int> = []
            while positions.count < other.islands.count {
                let x: Int = random.int(0...15)
                let y: Int = random.int(0...9)
                if used.insert(y * 16 + x).inserted { positions.append(Island(x: x, y: y)) }
            }
            let shifted: Level = try Self.variant(other, islands: positions)
            var a: Play = try Self.playing(other)
            var b: Play = try Self.playing(shifted)
            for _ in 0..<20 {
                if a.stage != .playing { break }
                let action: Action = Self.invAction(other, random: &random)
                let errorA: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                let errorB: HarmonicBridgesError? = Self.refusal { () throws(HarmonicBridgesError) in
                    try b.apply(action, expecting: b.fingerprint)
                }
                #expect(errorA == errorB)
                #expect(a.report == b.report && a.pegs == b.pegs && a.stage == b.stage && a.failure == b.failure)
                #expect(a.actionsSpent == b.actionsSpent)
                let held: String = b.fingerprint
                _ = b.progressDescription
                for string in 0..<shifted.strings.count { _ = try b.pluck(string) }
                #expect(b.fingerprint == held)
            }
        }
    }
}
