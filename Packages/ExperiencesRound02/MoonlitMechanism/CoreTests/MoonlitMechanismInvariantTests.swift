// MoonlitMechanismInvariantTests — feature 431 (R02-G14-01) T-R02G1401-006 (FR-R02G1401-012; the source's invariants
// R2-G14-INV-01 … 05 and INV-07 … 10 on Moonlit Mechanism). Each named test gives a direct boundary example and a
// seeded check of neighbouring inputs (seed 2,436: fixtures drawn from it, an unknown gear, re-seating the driver, a
// step of 0 or ±2, a lamp step out of range, an action budget ± 1, one tooth or one lamp step away from a fixture
// solution, a stray allowance one either side of the stray count, a byte of a stored level changed). How each invariant
// maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G14-02; INV-11 is superseded by the free tier):
// - INV-01 Time: no rule reads a clock; phases are whole teeth and the handle turns one tooth per action. The same
//   actions give the same fingerprints, reports and records however many pauses, reads and 0.008333 s presentation
//   frames lie between them; an idle play never spends an action or fails; the kernel sources hold no clock, time
//   interval or floating-point value.
// - INV-02 Input budget: a turn, a re-seat, a lamp step and a run each spend exactly 1 action; refusals (an unknown
//   gear, the driver re-seated, a step other than ±1, a lamp step out of range, a stale fingerprint, the wrong stage)
//   spend nothing; the action that spends the last of the budget is applied and judged (a run on it wins or fails by
//   its own cause, any other action on it fails `budget`) and every later action is refused by stage.
// - INV-03 Goal: a run wins exactly when every meshing pair is aligned, every required key frame has no uncovered
//   target cell and at most the allowance of stray cells, and no key frame shadows a forbidden cell; one tooth of
//   re-seat away from a solution jams at that gear, one handle turn away keeps every pair aligned, and every neighbour's
//   outcome is the one its run report gives; the stray allowance at the stray count wins and one below does not.
// - INV-04 Repeatability: the same actions give the same records, fingerprints and outcome on independent runs and
//   through replay; an edited or forged record is refused.
// - INV-05 Undo: undo restores the exact prior phases, lamp height, actions spent, report, failure and fingerprint;
//   redo the later one; a new action clears redo; a won level is final; a failed play returns to playing.
// - INV-07 Failure honesty: a failing run names its real cause — the first misaligned pair, the key frame and
//   lowest-numbered forbidden cell, the key frame and count of uncovered target cells or of stray cells — equal to an
//   independent computation; a budget failure names the action that spent the last of the budget; the run report always
//   lists every pair and every key frame, whatever decides.
// - INV-08 Stability: extreme valid levels (5 gears of 20 teeth, a 24 × 16 wall, offsets ±8, depth 3, 5 lamp heights,
//   400 handle turns, 12 forbidden cells, budget 40) run without a crash or overflow; every phase stays below its
//   teeth, every cell below W · H, every count within its target or cast, every error within ⌊g / 2⌋, the actions spent
//   within the budget.
// - INV-09 Save: stored levels round-trip byte for byte; any single-byte edit of the stored JSON is refused or decodes
//   to the same level; truncated and newer forms are refused; a stored record trace replays to the same play.
// - INV-10 Renderer purity: names and descriptions never change the state or the run report; a level differing only in
//   its id gives identical run reports; the play is a value type; the kernel sources import only Foundation,
//   VisualCoreMath and VisualCoreSimulation.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden tokens are built by concatenation so
// that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MoonlitMechanismCore

@Suite struct MoonlitMechanismInvariantTests {
    typealias Play = MoonlitMechanismPlay
    typealias Level = MoonlitMechanismLevel
    typealias Action = MoonlitMechanismAction
    typealias Failure = MoonlitMechanismFailure
    typealias Outcome = MoonlitMechanismOutcome
    typealias Report = MoonlitMechanismRunReport
    typealias Gear = MoonlitMechanismGear
    typealias Cell = MoonlitMechanismCell
    typealias Frame = MoonlitMechanismKeyFrame

    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = 2_436

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// The kernel sources the scans read when present (the Core directory next to this test directory).
    static let kernelFiles: [String] = ["MoonlitMechanismError.swift", "MoonlitMechanismMechanics.swift",
                                        "MoonlitMechanismLevel.swift", "MoonlitMechanismPlay.swift",
                                        "MoonlitMechanismRules.swift"]

    /// The fixtures of the invariant seed (computed once).
    static let fixtures: [MoonlitMechanismFixture] = MoonlitMechanismFixture.all(count: 60, seed: seed)

    // MARK: Helpers

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: Level) throws(MoonlitMechanismError) -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A playing play of `level` with `actions` applied in order.
    static func played(_ level: Level, _ actions: [Action]) throws(MoonlitMechanismError) -> Play {
        var play: Play = try playing(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(MoonlitMechanismError) -> Void) -> MoonlitMechanismError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// Whether `error` is an `.action` refusal (any payload).
    static func isAction(_ error: MoonlitMechanismError?) -> Bool {
        if case .action = error { return true }
        return false
    }

    /// `level` with some values replaced.
    static func variant(_ level: Level, id: String? = nil, startingHeight: Int? = nil, allowance: Int? = nil,
                        budget: Int? = nil, tutorial: Bool? = nil) throws(MoonlitMechanismError) -> Level {
        try Level(id: id ?? level.id, seed: level.seed, difficulty: level.difficulty, gears: level.gears,
                  width: level.width, rows: level.rows, lampHeights: level.lampHeights,
                  startingHeight: startingHeight ?? level.startingHeight, keyFrames: level.keyFrames,
                  forbidden: level.forbidden, allowance: allowance ?? level.allowance, budget: budget ?? level.budget,
                  tutorial: tutorial ?? level.tutorial)
    }

    /// The known actions of `fixture` without the final run (they lead to the solution set-up).
    static func toSolution(_ fixture: MoonlitMechanismFixture) -> [Action] {
        Array(fixture.actions.dropLast())
    }

    /// A seeded action on `level`: mostly ±1 turns, re-seats and lamp steps, sometimes a run, an unknown gear, the
    /// driver re-seated or a step of 0 or ±2.
    static func invAction(_ level: Level, random: inout SeededRandom) -> Action {
        let roll: Int = random.int(0...19)
        let count: Int = level.gears.count
        let step: Int = random.int(0...1) == 0 ? -1 : 1
        if roll == 0 { return .run }
        if roll == 1 { return .turn([0, 2, -2][random.int(0...2)]) }
        if roll == 2 { return .reseat(0, step) }
        if roll == 3 { return .reseat(count, step) }
        if roll == 4 { return .lamp([0, 2, -2][random.int(0...2)]) }
        if roll < 10 { return .turn(step) }
        if roll < 16 { return .reseat(random.int(1...(count - 1)), step) }
        return .lamp(step)
    }

    /// A seeded walk of up to `steps` actions, undos, redos, pauses and resumes on `level` (refusals skipped).
    static func invWalk(_ level: Level, steps: Int, random: inout SeededRandom) throws -> Play {
        var play: Play = try playing(level)
        for _ in 0..<steps {
            let roll: Int = random.int(0...19)
            if roll == 0 {
                _ = refusal { () throws(MoonlitMechanismError) in try play.undo() }
            } else if roll == 1 {
                _ = refusal { () throws(MoonlitMechanismError) in try play.redo() }
            } else if roll == 2 {
                _ = refusal { () throws(MoonlitMechanismError) in try play.handle(.pause) }
            } else if roll == 3 {
                _ = refusal { () throws(MoonlitMechanismError) in try play.handle(.resume) }
            } else {
                if play.stage == .paused { try play.handle(.resume) }
                if play.stage != .playing { break }
                let action: Action = invAction(level, random: &random)
                _ = refusal { () throws(MoonlitMechanismError) in try play.apply(action, expecting: play.fingerprint) }
            }
        }
        return play
    }

    /// The kernel sources present in the Core directory next to this test directory.
    static func kernelSources() throws -> [(name: String, text: String)] {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
        var sources: [(name: String, text: String)] = []
        for name in kernelFiles {
            let url: URL = core.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            sources.append((name, try String(contentsOf: url, encoding: .utf8)))
        }
        return sources
    }

    /// The failure a run outcome gives, or nil for a win.
    static func failure(of outcome: Outcome) -> Failure? {
        switch outcome {
        case .won: nil
        case .jammed(let child): .jammed(child)
        case .forbidden(let frame, let cell): .forbidden(frame: frame, cell: cell)
        case .missing(let frame, let count): .missing(frame: frame, count: count)
        case .stray(let frame, let count): .stray(frame: frame, count: count)
        }
    }

    // MARK: Independent computations

    /// The greatest common divisor, without the kernel.
    static func invGcd(_ a: Int, _ b: Int) -> Int {
        var x: Int = a
        var y: Int = b
        while y != 0 { (x, y) = (y, x % y) }
        return x
    }

    /// `v` modulo `m` in 0 ..< m, without the kernel.
    static func invMod(_ v: Int, _ m: Int) -> Int { ((v % m) + m) % m }

    /// The phases after `turns` handle turns, without the kernel.
    static func invTurned(_ gears: [Gear], _ phases: [Int], _ turns: Int) -> [Int] {
        var result: [Int] = []
        for index in gears.indices {
            var depth: Int = 0
            var current: Int = index
            while let parent = gears[current].parent {
                depth += 1
                current = parent
            }
            let direction: Int = depth % 2 == 0 ? 1 : -1
            result.append(invMod(phases[index] + direction * turns, gears[index].teeth))
        }
        return result
    }

    /// The cast cells (sorted), without the kernel.
    static func invCast(_ level: Level, _ phases: [Int], _ height: Int) -> [Int] {
        var cells: Set<Int> = []
        for (index, gear) in level.gears.enumerated() {
            for bit in 0..<gear.teeth where gear.blades[bit] {
                for offset in gear.slots[invMod(bit + phases[index], gear.teeth)] {
                    let column: Int = gear.centre.column + offset.column
                    let row: Int = gear.centre.row + offset.row + height * gear.depth
                    if column >= 0, column < level.width, row >= 0, row < level.rows {
                        cells.insert(row * level.width + column)
                    }
                }
            }
        }
        return cells.sorted()
    }

    /// The outcome of a run, without the kernel.
    static func invOutcome(_ level: Level, _ phases: [Int], _ height: Int) -> Outcome {
        for (index, gear) in level.gears.enumerated() {
            guard let parent = gear.parent else { continue }
            let g: Int = invGcd(level.gears[parent].teeth, gear.teeth)
            if invMod(phases[parent] + phases[index], g) != gear.alignment { return .jammed(child: index) }
        }
        for (index, frame) in level.keyFrames.enumerated() {
            let cast: [Int] = invCast(level, invTurned(level.gears, phases, frame.turns), height)
            let castSet: Set<Int> = Set(cast)
            if let cell = cast.first(where: { level.forbidden.contains($0) }) {
                return .forbidden(frame: index, cell: cell)
            }
            guard frame.required else { continue }
            var missing: Int = 0
            for cell in frame.target where !castSet.contains(cell) { missing += 1 }
            if missing > 0 { return .missing(frame: index, count: missing) }
            var stray: Int = 0
            for cell in cast where !frame.target.contains(cell) { stray += 1 }
            if stray > level.allowance { return .stray(frame: index, count: stray) }
        }
        return .won
    }

    /// Whether `report` meets the win condition: aligned, every required key frame matched within the allowance and
    /// no forbidden cell at any key frame.
    static func meetsGoal(_ level: Level, _ report: Report) -> Bool {
        guard report.errors.allSatisfy({ $0 == 0 }) else { return false }
        for (index, frame) in report.frames.enumerated() {
            if !frame.forbidden.isEmpty { return false }
            if level.keyFrames[index].required, frame.missing > 0 || frame.stray > level.allowance { return false }
        }
        return true
    }

    // MARK: INV-01 Time

    @Test func testMoonlitMechanismTimeBoundary() throws {
        // Direct boundary: known actions with pauses, reads and 0.008333 s presentation frames in between give the same
        // fingerprints, reports and records as without them.
        let step: Double = 0.008333
        let fixture: MoonlitMechanismFixture = Self.fixtures[0]
        let plain: Play = try Self.played(fixture.level, fixture.actions)
        var busy: Play = try Self.playing(fixture.level)
        var elapsed: Double = 0
        for action in fixture.actions {
            for _ in 0..<120 {
                elapsed += step
                _ = busy.fingerprint
                _ = busy.report
                _ = busy.actionsLeft
            }
            try busy.handle(.pause)
            try busy.handle(.resume)
            try busy.apply(action, expecting: busy.fingerprint)
        }
        #expect(elapsed > 0.9, "presentation frames elapsed")
        #expect(busy == plain, "pauses, reads and presentation frames never change the play")
        #expect(busy.records == plain.records, "records are independent of when actions came")
        #expect(plain.stage == .won, "the known actions win regardless of when")
        // An idle play never spends an action or fails.
        var idle: Play = try Self.playing(fixture.level)
        let before: String = idle.fingerprint
        for _ in 0..<1_000 {
            _ = idle.report
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.fingerprint == before, "an idle play keeps its fingerprint")
        #expect(idle.actionsSpent == 0 && idle.failure == nil, "an idle play spends nothing and never fails")
        // The kernel sources hold no clock, time interval or floating-point value.
        let tokens: [String] = ["Da" + "te(", "Dou" + "ble", "Flo" + "at", "Time" + "Interval", "Dispatch" + "Time",
                                "Continuous" + "Clock", "CFAbsolute" + "Time", "random" + "Element", ".ran" + "dom("]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count >= 4, "the kernel sources are present")
        for source in sources {
            for token in tokens {
                #expect(!source.text.contains(token), "a kernel source holds a clock or floating-point token")
            }
        }
        // Neighbouring inputs: the same seeded walk twice gives equal plays.
        for index in 0..<30 {
            let level: Level = Self.fixtures[index].level
            var first: SeededRandom = SeededRandom(seed: Self.seed &+ UInt64(index))
            var second: SeededRandom = SeededRandom(seed: Self.seed &+ UInt64(index))
            let a: Play = try Self.invWalk(level, steps: 40, random: &first)
            let b: Play = try Self.invWalk(level, steps: 40, random: &second)
            #expect(a == b, "equal inputs give equal plays")
            #expect(a.fingerprint == b.fingerprint, "equal inputs give equal fingerprints")
        }
    }

    // MARK: INV-02 Input budget

    @Test func testMoonlitMechanismInputbudgetBoundary() throws {
        // Direct boundary: the budget fails on exactly the action that spends its last unit.
        let fixture: MoonlitMechanismFixture = Self.fixtures[1]
        let level: Level = try Self.variant(fixture.level, budget: 4)
        var play: Play = try Self.playing(level)
        let steps: [Action] = [.turn(1), .turn(-1), .turn(1), .turn(-1)]
        for (index, action) in steps.enumerated() {
            try play.apply(action, expecting: play.fingerprint)
            #expect(play.actionsSpent == index + 1, "each turn spends exactly one action")
            if index < 3 {
                #expect(play.stage == .playing, "the budget is not spent yet")
            }
        }
        #expect(play.stage == .failed, "the action spending the last of the budget fails")
        if case .budget(let n) = play.failure {
            #expect(n == 3 || n == 4, "the budget failure names the last action")
        } else {
            Issue.record("the budget failure is named budget")
        }
        let after: String = play.fingerprint
        let late: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
            try play.apply(.turn(1), expecting: play.fingerprint)
        }
        #expect(late == .stage, "an action beyond the budget is refused by stage")
        #expect(play.fingerprint == after, "a refused action changes nothing")
        // Neighbouring inputs: budgets of the known count and one less; refusals spend nothing.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            let exact: Level = try Self.variant(fixture.level, budget: fixture.actions.count)
            let won: Play = try Self.played(exact, fixture.actions)
            #expect(won.stage == .won, "a run on the last action of the budget still wins")
            #expect(won.actionsLeft == 0, "the budget is fully spent")
            if fixture.actions.count >= 2 {
                let short: Level = try Self.variant(fixture.level, budget: fixture.actions.count - 1)
                let failed: Play = try Self.played(short, Self.toSolution(fixture))
                #expect(failed.stage == .failed, "one action short fails on the exact action")
                #expect(failed.failure?.code == "budget", "the failure is the budget")
                #expect(failed.actionsSpent == short.budget, "the budget fails after exactly its count")
            }
            var walk: Play = try Self.playing(fixture.level)
            for _ in 0..<20 {
                guard walk.stage == .playing else { break }
                let action: Action = Self.invAction(fixture.level, random: &random)
                let spent: Int = walk.actionsSpent
                let print: String = walk.fingerprint
                let error: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
                    try walk.apply(action, expecting: walk.fingerprint)
                }
                if error == nil {
                    #expect(walk.actionsSpent == spent + 1, "an accepted action spends exactly one")
                } else {
                    #expect(Self.isAction(error), "an invalid action is refused as an action")
                    #expect(walk.actionsSpent == spent && walk.fingerprint == print, "a refusal spends nothing")
                }
            }
            if walk.stage == .playing {
                let print: String = walk.fingerprint
                let stale: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
                    try walk.apply(.turn(1), expecting: Self.staleFingerprint)
                }
                #expect(stale == .stale, "a stale fingerprint is refused")
                #expect(walk.fingerprint == print, "a stale refusal changes nothing")
            }
        }
        // Wrong stage: loading refuses actions.
        var loading: Play = Play(level: fixture.level)
        let early: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
            try loading.apply(.turn(1), expecting: loading.fingerprint)
        }
        #expect(early == .stage, "an action before begin is refused by stage")
    }

    // MARK: INV-03 Goal

    @Test func testMoonlitMechanismGoalBoundary() throws {
        // Direct boundary: the known actions reach a set-up meeting the goal, and the run wins there.
        let first: MoonlitMechanismFixture = Self.fixtures[2]
        let won: Play = try Self.played(first.level, first.actions)
        #expect(won.stage == .won, "the known actions win")
        #expect(Self.meetsGoal(first.level, won.report), "a won run meets every goal condition")
        // Neighbouring inputs: one tooth or one lamp step away from each fixture solution.
        for fixture in Self.fixtures {
            let level: Level = try Self.variant(fixture.level, budget: 40)
            let solution: [Int] = fixture.solution
            let height: Int = fixture.solutionHeight
            let base: Report = level.run(phases: solution, height: height)
            #expect(base.outcome == .won, "the fixture solution wins")
            var neighbours: [Action] = [.turn(1), .turn(-1), .lamp(1), .lamp(-1)]
            for gear in 1..<level.gears.count {
                neighbours.append(.reseat(gear, 1))
                neighbours.append(.reseat(gear, -1))
            }
            for neighbour in neighbours {
                guard let next = MoonlitMechanismFixture.apply(neighbour, gears: level.gears, phases: solution,
                                                               height: height, lampHeights: level.lampHeights)
                else { continue }
                let report: Report = level.run(phases: next.phases, height: next.height)
                #expect((report.outcome == .won) == Self.meetsGoal(level, report), "won exactly when the goal is met")
                #expect(report.outcome == Self.invOutcome(level, next.phases, next.height),
                        "the outcome equals an independent run")
                if case .reseat(let gear, _) = neighbour {
                    #expect(report.outcome == .jammed(child: gear), "one tooth of re-seat jams at that gear")
                }
                if case .turn = neighbour {
                    #expect(report.aligned, "a handle turn never misaligns a pair")
                }
                var play: Play = try Self.played(level, Self.toSolution(fixture))
                try play.apply(neighbour, expecting: play.fingerprint)
                try play.apply(.run, expecting: play.fingerprint)
                #expect((play.stage == .won) == (report.outcome == .won), "the play wins exactly as the report says")
                #expect(play.failure == Self.failure(of: report.outcome), "the play fails exactly as the report says")
            }
            // One either side of the stray allowance at the lowest-stray required key frame of a lamp neighbour.
            for lamp in [1, -1] {
                guard let next = MoonlitMechanismFixture.apply(.lamp(lamp), gears: level.gears, phases: solution,
                                                               height: height, lampHeights: level.lampHeights)
                else { continue }
                let report: Report = level.run(phases: next.phases, height: next.height)
                var clean: Bool = true
                var largest: Int = 0
                for (index, frame) in report.frames.enumerated() {
                    if !frame.forbidden.isEmpty { clean = false }
                    if level.keyFrames[index].required {
                        if frame.missing > 0 { clean = false }
                        largest = max(largest, frame.stray)
                    }
                }
                guard clean, largest >= 1, largest <= 4 else { continue }
                let at: Level = try Self.variant(level, allowance: largest)
                let below: Level = try Self.variant(level, allowance: largest - 1)
                #expect(at.run(phases: next.phases, height: next.height).outcome == .won,
                        "strays exactly at the allowance still match")
                if case .stray = below.run(phases: next.phases, height: next.height).outcome {
                } else {
                    Issue.record("one stray above the allowance fails stray")
                }
            }
        }
    }

    // MARK: INV-04 Repeatability

    @Test func testMoonlitMechanismRepeatabilityBoundary() throws {
        // Direct boundary: the known actions replay to the same play.
        let fixture: MoonlitMechanismFixture = Self.fixtures[3]
        let won: Play = try Self.played(fixture.level, fixture.actions)
        let replayed: Play = try Play.replay(level: fixture.level, records: won.records)
        #expect(replayed == won, "a known trace replays to the same play")
        #expect(replayed.fingerprint == won.fingerprint, "a known trace replays to the same fingerprint")
        // Neighbouring inputs: seeded walks replay; edited and forged records are refused.
        for index in 0..<Self.fixtures.count {
            let level: Level = Self.fixtures[index].level
            var random: SeededRandom = SeededRandom(seed: Self.seed &+ UInt64(index))
            let walk: Play = try Self.invWalk(level, steps: 30, random: &random)
            let again: Play = try Play.replay(level: level, records: walk.records)
            #expect(again.records == walk.records, "a replay reproduces every record")
            #expect(again.phases == walk.phases && again.height == walk.height, "a replay reproduces the set-up")
            #expect(again.failure == walk.failure && again.report == walk.report, "a replay reproduces the outcome")
            if let last = walk.records.last {
                #expect(again.records.last?.next == last.next, "a replay reproduces the last fingerprint")
                var edited: [MoonlitMechanismRecord] = walk.records
                edited[edited.count - 1] = MoonlitMechanismRecord(schema: last.schema, seed: last.seed,
                                                                  index: last.index, kind: last.kind,
                                                                  action: last.action, previous: last.previous,
                                                                  next: Self.staleFingerprint)
                let editedError: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
                    _ = try Play.replay(level: level, records: edited)
                }
                #expect(editedError != nil, "an edited record is refused")
                var forged: [MoonlitMechanismRecord] = walk.records
                forged[0] = MoonlitMechanismRecord(schema: forged[0].schema, seed: forged[0].seed &+ 1,
                                                   index: forged[0].index, kind: forged[0].kind,
                                                   action: forged[0].action, previous: forged[0].previous,
                                                   next: forged[0].next)
                let forgedError: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
                    _ = try Play.replay(level: level, records: forged)
                }
                #expect(forgedError != nil, "a record of another level seed is refused")
            }
        }
    }

    // MARK: INV-05 Undo

    @Test func testMoonlitMechanismUndoBoundary() throws {
        // Direct boundary: a won level is final; a failed play undone returns to playing.
        let fixture: MoonlitMechanismFixture = Self.fixtures[4]
        var won: Play = try Self.played(fixture.level, fixture.actions)
        let wonError: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in try won.undo() }
        #expect(wonError == .stage, "a won level refuses undo")
        var failed: Play = try Self.played(fixture.level, [.run])
        #expect(failed.stage == .failed, "the unsolved start fails its run")
        try failed.undo()
        #expect(failed.stage == .playing && failed.failure == nil, "undo from failed returns to playing")
        #expect(failed.fingerprint == (try Self.playing(fixture.level)).fingerprint, "undo restores the start")
        // Neighbouring inputs: every accepted action of seeded walks undoes and redoes exactly.
        for index in 0..<Self.fixtures.count {
            let level: Level = Self.fixtures[index].level
            var random: SeededRandom = SeededRandom(seed: Self.seed &+ UInt64(index))
            var play: Play = try Self.playing(level)
            for _ in 0..<25 {
                guard play.stage == .playing else { break }
                let earlier: Play = play
                let action: Action = Self.invAction(level, random: &random)
                let error: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
                    try play.apply(action, expecting: play.fingerprint)
                }
                guard error == nil else { continue }
                let later: Play = play
                #expect(!play.canRedo, "a new action clears redo")
                if later.stage == .won {
                    #expect(!play.canUndo, "a won play is final")
                    break
                }
                try play.undo()
                #expect(play.fingerprint == earlier.fingerprint, "undo restores the exact earlier fingerprint")
                #expect(play.phases == earlier.phases && play.height == earlier.height, "undo restores the set-up")
                #expect(play.actionsSpent == earlier.actionsSpent, "undo restores the actions spent")
                #expect(play.report == earlier.report && play.failure == earlier.failure, "undo restores the report")
                try play.redo()
                #expect(play.fingerprint == later.fingerprint, "redo restores the exact later fingerprint")
                #expect(play.report == later.report && play.failure == later.failure, "redo restores the report")
                if play.stage == .failed {
                    try play.undo()
                    #expect(play.stage == .playing, "a failed play undone returns to playing")
                }
            }
        }
    }

    // MARK: INV-07 Failure honesty

    @Test func testMoonlitMechanismFailurehonestyBoundary() throws {
        // Direct boundary: a run at the unsolved start names its real cause, and its report lists every key frame.
        let fixture: MoonlitMechanismFixture = Self.fixtures[5]
        let failed: Play = try Self.played(fixture.level, [.run])
        let start: Outcome = Self.invOutcome(fixture.level, fixture.level.startingPhases, fixture.level.startingHeight)
        #expect(failed.failure == Self.failure(of: start), "the failure equals an independent run")
        #expect(failed.report.frames.count == fixture.level.keyFrames.count, "the report lists every key frame")
        // Neighbouring inputs: seeded walks ending in a run name the real cause.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            let level: Level = try Self.variant(fixture.level, budget: 40)
            for _ in 0..<4 {
                var play: Play = try Self.playing(level)
                for _ in 0..<random.int(0...8) {
                    let action: Action = Self.invAction(level, random: &random)
                    if action == .run { continue }
                    _ = Self.refusal { () throws(MoonlitMechanismError) in
                        try play.apply(action, expecting: play.fingerprint)
                    }
                }
                #expect(play.report.frames.count == level.keyFrames.count, "every key frame is always reported")
                #expect(play.report.errors.count == level.gears.count, "every pair is always reported")
                try play.apply(.run, expecting: play.fingerprint)
                let truth: Outcome = Self.invOutcome(level, play.phases, play.height)
                #expect(play.report.outcome == truth, "the run outcome equals an independent computation")
                #expect(play.failure == Self.failure(of: truth), "the failure names its real cause")
                #expect(play.report.frames.count == level.keyFrames.count, "a decided run still lists every key frame")
                switch play.failure {
                case .jammed(let child):
                    #expect(play.report.errors[child] != 0, "the named pair is misaligned")
                    for earlier in 0..<child {
                        #expect(play.report.errors[earlier] == 0, "no earlier pair is misaligned")
                    }
                case .forbidden(let frame, let cell):
                    #expect(play.report.frames[frame].forbidden.first == cell, "the lowest forbidden cell is named")
                    #expect(level.forbidden.contains(cell), "the named cell is forbidden")
                case .missing(let frame, let count):
                    let target: [Int] = level.keyFrames[frame].target
                    let cast: Set<Int> = Set(Self.invCast(level, Self.invTurned(level.gears, play.phases,
                                                                                level.keyFrames[frame].turns),
                                                          play.height))
                    var uncovered: Int = 0
                    for cell in target where !cast.contains(cell) { uncovered += 1 }
                    #expect(count == uncovered, "the missing count is the real number of uncovered cells")
                    #expect(level.keyFrames[frame].required, "missing is judged only at a required key frame")
                case .stray(let frame, let count):
                    #expect(count > level.allowance, "a stray failure exceeds the allowance")
                    #expect(count == play.report.frames[frame].stray, "the stray count is reported")
                    #expect(level.keyFrames[frame].required, "stray is judged only at a required key frame")
                case .budget:
                    Issue.record("a budget of 40 is not spent in nine actions")
                case nil:
                    #expect(play.stage == .won, "no failure only when won")
                }
            }
        }
        // A budget failure names the action that spent the last of the budget.
        for budget in 1...3 {
            let level: Level = try Self.variant(fixture.level, budget: budget)
            var play: Play = try Self.playing(level)
            for index in 0..<budget {
                try play.apply(index % 2 == 0 ? .turn(1) : .turn(-1), expecting: play.fingerprint)
            }
            if case .budget(let n) = play.failure {
                #expect(n == budget - 1 || n == budget, "the budget failure names the last action")
            } else {
                Issue.record("a spent budget fails budget")
            }
            #expect(play.failure?.code == "budget", "the budget failure code is budget")
        }
    }

    // MARK: INV-08 Stability

    @Test func testMoonlitMechanismStabilityBoundary() throws {
        // Direct boundary: an extreme valid level runs without a crash or overflow.
        var gears: [Gear] = []
        for index in 0..<5 {
            var blades: [Bool] = []
            var slots: [[Cell]] = []
            for k in 0..<20 {
                blades.append(k % 2 == 0)
                slots.append([Cell(column: 8, row: 8), Cell(column: -8, row: -8), Cell(column: k % 9 - 4, row: 0)])
            }
            gears.append(Gear(teeth: 20, phase: 19, blades: blades, depth: 3,
                              centre: Cell(column: 23 - index, row: 15 - index), parent: index == 0 ? nil : index - 1,
                              alignment: index == 0 ? 0 : 18, slots: slots))
        }
        var frames: [Frame] = []
        for index in 0..<6 { frames.append(Frame(turns: 395 + index, target: [100 + index], required: index < 3)) }
        var forbidden: [Int] = []
        for index in 0..<12 { forbidden.append(200 + index) }
        let extreme: Level = try Level(id: "extreme-five", seed: Self.seed, difficulty: 5, gears: gears, width: 24,
                                       rows: 16, lampHeights: 5, startingHeight: 4, keyFrames: frames,
                                       forbidden: forbidden, allowance: 4, budget: 40)
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        var levels: [Level] = [extreme]
        for fixture in Self.fixtures { levels.append(fixture.level) }
        // Neighbouring inputs: seeded walks on the extreme level and the fixtures stay within their bounds.
        for level in levels {
            var play: Play = try Self.playing(level)
            for _ in 0..<40 {
                if play.stage == .paused { try play.handle(.resume) }
                guard play.stage == .playing else { break }
                let action: Action = Self.invAction(level, random: &random)
                _ = Self.refusal { () throws(MoonlitMechanismError) in
                    try play.apply(action, expecting: play.fingerprint)
                }
                let cells: Int = level.width * level.rows
                #expect(play.actionsSpent >= 0 && play.actionsSpent <= level.budget, "actions spent within budget")
                #expect(play.height >= 0 && play.height < level.lampHeights, "lamp height within range")
                for (index, phase) in play.phases.enumerated() {
                    #expect(phase >= 0 && phase < level.gears[index].teeth, "a phase stays below its teeth")
                }
                for (index, error) in play.report.errors.enumerated() {
                    var bound: Int = 0
                    if let parent = level.gears[index].parent {
                        bound = Self.invGcd(level.gears[parent].teeth, level.gears[index].teeth) / 2
                    }
                    #expect(error >= 0 && error <= bound, "an alignment error stays within half the divisor")
                }
                for (index, frame) in play.report.frames.enumerated() {
                    let target: Int = level.keyFrames[index].target.count
                    #expect(frame.covered >= 0 && frame.missing >= 0, "counts are not negative")
                    #expect(frame.covered + frame.missing == target, "covered and missing make the target size")
                    #expect(frame.stray >= 0 && frame.stray <= frame.cast.count, "stray within the cast")
                    #expect(frame.forbidden.count <= level.forbidden.count, "forbidden hits within the forbidden cells")
                    var previous: Int = -1
                    for cell in frame.cast {
                        #expect(cell > previous && cell < cells, "cast cells are sorted, distinct and on the wall")
                        previous = cell
                    }
                    for (gear, phase) in frame.phases.enumerated() {
                        #expect(phase >= 0 && phase < level.gears[gear].teeth, "a key-frame phase stays below teeth")
                    }
                }
            }
        }
    }

    // MARK: INV-09 Save

    @Test func testMoonlitMechanismSaveBoundary() throws {
        // Direct boundary: a stored level round-trips byte for byte; truncated and newer forms are refused.
        let level: Level = Self.fixtures[6].level
        let data: Data = level.encoded()
        let decoded: Level = try Level.decode(data)
        #expect(decoded == level, "a stored level round-trips")
        #expect(decoded.encoded() == data, "a stored level round-trips byte for byte")
        let truncated: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
            _ = try Level.decode(data.prefix(data.count / 2))
        }
        #expect(truncated != nil, "a truncated stored level is refused")
        let text: String = String(decoding: data, as: UTF8.self)
        let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        let newerError: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
            _ = try Level.decode(Data(newer.utf8))
        }
        #expect(newerError == .newerSchema(2), "a newer stored level is refused")
        // Neighbouring inputs: seeded single-byte edits are refused or decode to the same level.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        let replacements: [UInt8] = Array("0123456789-\",:[]{}aeftnrsluxyz ".utf8)
        for fixture in Self.fixtures.prefix(8) {
            let stored: [UInt8] = Array(fixture.level.encoded())
            #expect((try Level.decode(Data(stored))) == fixture.level, "every fixture round-trips")
            for _ in 0..<250 {
                var edited: [UInt8] = stored
                let position: Int = random.int(0...(stored.count - 1))
                let byte: UInt8 = replacements[random.int(0...(replacements.count - 1))]
                guard byte != edited[position] else { continue }
                edited[position] = byte
                do {
                    let back: Level = try Level.decode(Data(edited))
                    #expect(back == fixture.level, "a decoded single-byte edit is the same level")
                } catch {
                    #expect(!error.reasonCode.isEmpty, "a single-byte edit is refused with a reason")
                }
            }
        }
        // A stored record trace replays to the same play.
        var trace: SeededRandom = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures.prefix(10) {
            let walk: Play = try Self.invWalk(fixture.level, steps: 20, random: &trace)
            let recordData: Data = try JSONEncoder().encode(walk.records)
            let records: [MoonlitMechanismRecord] = try JSONDecoder().decode([MoonlitMechanismRecord].self,
                                                                             from: recordData)
            #expect(records == walk.records, "records round-trip")
            let back: Play = try Play.replay(level: try Level.decode(fixture.level.encoded()), records: records)
            #expect(back.records == walk.records, "a stored trace replays to the same records")
        }
    }

    // MARK: INV-10 Renderer purity

    @Test func testMoonlitMechanismRendererpurityBoundary() throws {
        // Direct boundary: naming and describing a play never changes it.
        let fixture: MoonlitMechanismFixture = Self.fixtures[7]
        let play: Play = try Self.played(fixture.level, Self.toSolution(fixture))
        let print: String = play.fingerprint
        let report: Report = play.report
        for index in fixture.level.gears.indices {
            let name: String = fixture.level.gearName(index, phase: play.phases[index])
            #expect(name.hasPrefix("gear \(index), \(fixture.level.gears[index].teeth) teeth"), "gears named in words")
        }
        #expect(fixture.level.lampName(play.height) == "lamp height \(play.height) of \(fixture.level.lampHeights)",
                "the lamp is named in words")
        _ = fixture.level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        #expect(play.fingerprint == print && play.report == report, "names and descriptions change nothing")
        // The play is a value type: a changed copy leaves the original alone.
        var copy: Play = play
        try copy.apply(.turn(1), expecting: copy.fingerprint)
        #expect(play.fingerprint == print, "a copy's action never changes the original")
        // The kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation.
        let allowed: Set<String> = ["Foundation", "VisualCoreMath", "VisualCoreSimulation"]
        for source in try Self.kernelSources() {
            for line in source.text.split(separator: "\n") where line.hasPrefix("import ") {
                let module: String = String(line.dropFirst("import ".count)).trimmingCharacters(in: .whitespaces)
                #expect(allowed.contains(module), "a kernel source imports only the allowed modules")
            }
        }
        // Neighbouring inputs: a level differing only in its id gives identical reports; descriptions are a function of
        // the report and never feed back.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for fixture in Self.fixtures {
            let renamed: Level = try Self.variant(fixture.level, id: "renamed-" + fixture.level.id)
            var a: Play = try Self.playing(fixture.level)
            var b: Play = try Self.playing(renamed)
            for _ in 0..<15 {
                guard a.stage == .playing else { break }
                let action: Action = Self.invAction(fixture.level, random: &random)
                let first: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                let describedBefore: String = a.fingerprint
                _ = fixture.level.progressDescription(report: a.report, actionsLeft: a.actionsLeft)
                _ = fixture.level.lampName(a.height)
                for index in fixture.level.gears.indices { _ = fixture.level.gearName(index, phase: a.phases[index]) }
                #expect(a.fingerprint == describedBefore, "describing never changes the fingerprint")
                let second: MoonlitMechanismError? = Self.refusal { () throws(MoonlitMechanismError) in
                    try b.apply(action, expecting: b.fingerprint)
                }
                #expect(first == second, "a renamed level accepts and refuses alike")
                #expect(a.report == b.report && a.failure == b.failure && a.stage == b.stage,
                        "a renamed level gives identical reports")
                #expect(fixture.level.progressDescription(report: a.report, actionsLeft: a.actionsLeft)
                        == renamed.progressDescription(report: b.report, actionsLeft: b.actionsLeft),
                        "descriptions depend only on the report")
            }
        }
    }
}
