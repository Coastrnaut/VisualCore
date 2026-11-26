// MicroscopicAuroraInvariantTests — feature 481 (R02-G19-01) T-R02G1901-006 (FR-R02G1901-012; the source's invariants
// R2-G19-INV-01 … 05 and INV-07 … 10 on Microscopic Aurora), modelled on ApsidesWorkshopInvariantTests (feature 471).
// Each named test gives a direct boundary example and a seeded check of neighbouring inputs (seed 2,486: fixtures drawn
// from it, random wells and traces, swim lengths T − 1, T and T + 1 at the range bounds, budgets ± 1, a coverage
// requirement one cell either side, a stencil cut in two, a byte of a stored level changed or the form truncated).
// How each invariant maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G19-02; INV-11 is
// superseded by the free tier):
// - INV-01 Time: no rule reads a clock; time is the whole tick 1 … T of one swim. A swim that does not fail keeps T + 1
//   positions (tick 0 first) and T ticks; a longer swim of the same level repeats the shorter one's positions; lengths
//   119 and 481 are refused, 120, 121, 479 and 480 accepted; pauses and reads between actions change nothing; the
//   kernel sources hold no clock, time interval or floating-point value.
// - INV-02 Input budget: a placement or removal spends exactly 1 action, the play none; the action that spends the
//   last one is accepted and the next refused `budget` while the play is still accepted; action before budget; stale
//   before action; refusals change nothing; budgets 0 and 13 are refused, b − 1, b and b + 1 give exactly that many.
// - INV-03 Goal: a swim wins exactly when no swimmer leaves, the swarm stays coherent, the coverage reaches the
//   requirement and the lit stencil is one group (judged by an independent judge); a requirement one cell above the
//   lit count fails `coverage`; a stencil cut in two fails `connectedness`; the known fixture actions win.
// - INV-04 Repeatability: the same trace twice gives identical fingerprints and outcome; replay reproduces them; a
//   trace with a record removed, or the trace of another level, is refused `malformed`.
// - INV-05 Undo: undo restores the exact prior fingerprint (including from failed, which returns to playing with the
//   wells before the play); redo the later one; a new action clears redo; a won play is final; undo while paused
//   stays paused.
// - INV-07 Failure honesty: a failed play names the swimmer or cell and the tick equal to the independent judge; the
//   wells and actions spent stay as they were; the words of `failureDescription` say it.
// - INV-08 Stability: every velocity stays within ±v_max per axis every tick, every position within one step of the
//   enclosure, the densities sum to swimmers × ticks swum (the exit tick adds none), every measure in range.
// - INV-09 Save: stored levels round-trip byte for byte (through `encoded`/`decode` and through Codable); every
//   one-byte edit and every truncation is refused; a stored record trace replays to the same play.
// - INV-10 Renderer purity: the report is a pure function of the level and the wells (never of call order, reads of
//   words, the id, seed, difficulty, budget or tutorial, nor the order of the wells); the report type holds only the
//   truth metric; the play is a value type; the kernel sources import only Foundation, VisualCoreMath and
//   VisualCoreSimulation.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden tokens are built by concatenation so
// that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

@Suite struct MicroscopicAuroraInvariantTests {
    typealias Play = MicroscopicAuroraPlay
    typealias Level = MicroscopicAuroraLevel
    typealias Action = MicroscopicAuroraAction
    typealias Failure = MicroscopicAuroraFailure
    typealias Report = MicroscopicAuroraReport
    typealias Point = MicroscopicAuroraPoint
    typealias Swimmer = MicroscopicAuroraSwimmer
    typealias Cell = MicroscopicAuroraCell
    typealias Well = MicroscopicAuroraWell
    typealias Rules = MicroscopicAuroraSwarmRules
    typealias Fixture = MicroscopicAuroraFixture
    typealias Record = MicroscopicAuroraRecord
    typealias Refusal = MicroscopicAuroraError
    typealias Dish = MicroscopicAuroraDish

    /// One step of a seeded trace.
    private enum Step {
        case act(Action)
        case undo
        case redo
        case pause
        case resume
    }

    /// The helpers, builders and independent computations of this file.
    private enum Inv {
        /// The invariant (neighbouring-input) seed.
        static let seed: UInt64 = 2_486

        /// A fingerprint that is never the current one.
        static let staleFingerprint: String = String(repeating: "0", count: 64)

        /// The fixtures of the invariant seed (computed once).
        static let fixtures: [Fixture] = Fixture.all(count: 40, seed: seed)

        /// Ballistic rules: no separation, alignment or cohesion, so every swimmer keeps its velocity (v_max 8).
        static let ballistic: Rules = Rules(neighbourRadius: 2, separationRadius: 1, coherenceRadius: 2,
                                            separationWeight: 0, alignmentWeight: 0, cohesionWeight: 0,
                                            maxAcceleration: 2, maxSpeed: 8)

        /// Four swimmers about the centre, at x = 3040 (0, 1) and 3104 (2, 3), y = 3040 and 3104: all moving +x at 8
        /// per tick, or (`split`) 0 and 1 moving −x and 2 and 3 moving +x.
        static func quartet(split: Bool) -> [Swimmer] {
            let left: Int = split ? -8 : 8
            return [Swimmer(position: Point(x: 3_040, y: 3_040), velocity: Point(x: left, y: 0)),
                    Swimmer(position: Point(x: 3_040, y: 3_104), velocity: Point(x: left, y: 0)),
                    Swimmer(position: Point(x: 3_104, y: 3_040), velocity: Point(x: 8, y: 0)),
                    Swimmer(position: Point(x: 3_104, y: 3_104), velocity: Point(x: 8, y: 0))]
        }

        /// The cells of rows 11 and 12 in `columns`.
        static func band(_ columns: ClosedRange<Int>) -> [Cell] {
            var cells: [Cell] = []
            for row in 11...12 {
                for column in columns { cells.append(Cell(row: row, column: column)) }
            }
            return cells
        }

        /// A hand level of the quartet under ballistic rules (`refusingAWin` false lets a probe read any report).
        static func hand(split: Bool = false, radius: Int = 11, length: Int = 120, stencil: [Cell]? = nil,
                         coverage: Int = 500, coherence: Int = 2, wells: [Well?] = [nil, nil, nil], budget: Int = 3,
                         refusingAWin: Bool = false) throws(Refusal) -> Level {
            try Level(id: "inv-hand", seed: 7, difficulty: 1, radius: radius, length: length, rules: ballistic,
                      swimmers: quartet(split: split), stencil: stencil ?? band(12...15), threshold: 1,
                      coverage: coverage, coherence: coherence, wells: wells, budget: budget, tutorial: false,
                      refusingAWin: refusingAWin)
        }

        /// `level` with some values replaced.
        static func copy(_ level: Level, id: String? = nil, seed: UInt64? = nil, difficulty: Int? = nil,
                         radius: Int? = nil, length: Int? = nil, rules: Rules? = nil, stencil: [Cell]? = nil,
                         coverage: Int? = nil, wells: [Well?]? = nil, budget: Int? = nil, tutorial: Bool? = nil,
                         refusingAWin: Bool) throws(Refusal) -> Level {
            try Level(id: id ?? level.id, seed: seed ?? level.seed, difficulty: difficulty ?? level.difficulty,
                      radius: radius ?? level.radius, length: length ?? level.length, rules: rules ?? level.rules,
                      swimmers: level.swimmers, stencil: stencil ?? level.stencil, threshold: level.threshold,
                      coverage: coverage ?? level.coverage, coherence: level.coherence, wells: wells ?? level.wells,
                      budget: budget ?? level.budget, tutorial: tutorial ?? level.tutorial,
                      refusingAWin: refusingAWin)
        }

        /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
        static func playing(_ level: Level) throws(Refusal) -> Play {
            var play: Play = Play(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            return play
        }

        /// A playing play of `level` with `actions` applied in order.
        static func played(_ level: Level, _ actions: [Action]) throws(Refusal) -> Play {
            var play: Play = try playing(level)
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
            return play
        }

        /// The refusal of `body`, or nil when it was accepted.
        static func refusal(_ body: () throws(Refusal) -> Void) -> Refusal? {
            do {
                try body()
                return nil
            } catch {
                return error
            }
        }

        /// Whether `error` is an `.action` refusal (any payload).
        static func isAction(_ error: Refusal?) -> Bool {
            if case .action = error { return true }
            return false
        }

        /// Whether `error` is a `.malformed` refusal (any payload).
        static func isMalformed(_ error: Refusal?) -> Bool {
            if case .malformed = error { return true }
            return false
        }

        /// A random well on a usable cell of `level` not in `avoiding`.
        static func randomWell(_ random: inout SeededRandom, _ level: Level, avoiding: Set<Cell> = []) -> Well {
            var cell: Cell = Fixture.cell(&random, radius: level.radius)
            while avoiding.contains(cell) { cell = Fixture.cell(&random, radius: level.radius) }
            let sense: MicroscopicAuroraSense = random.int(0...1) == 0 ? .clockwise : .counterclockwise
            return Well(cell: cell, strength: random.int(1...4), sense: sense)
        }

        /// 0 … 3 random wells on distinct usable cells of `level`.
        static func randomWells(_ random: inout SeededRandom, _ level: Level) -> [Well] {
            var wells: [Well] = []
            var used: Set<Cell> = []
            let count: Int = random.int(0...3)
            for _ in 0..<count {
                let well: Well = randomWell(&random, level, avoiding: used)
                used.insert(well.cell)
                wells.append(well)
            }
            return wells
        }

        /// A seeded trace of `count` steps on `level`: placements, removals, undo, redo, pause, resume and play.
        static func randomSteps(_ level: Level, count: Int, random: inout SeededRandom) -> [Step] {
            var steps: [Step] = []
            for _ in 0..<count {
                let r: Int = random.int(0...9)
                if r <= 3 {
                    steps.append(.act(.place(slot: random.int(0...2), well: randomWell(&random, level))))
                } else if r == 4 {
                    steps.append(.act(.remove(slot: random.int(0...2))))
                } else if r == 5 {
                    steps.append(.undo)
                } else if r == 6 {
                    steps.append(.redo)
                } else if r == 7 {
                    steps.append(.pause)
                } else if r == 8 {
                    steps.append(.resume)
                } else {
                    steps.append(.act(.play))
                }
            }
            return steps
        }

        /// Runs `steps` on a playing play of `level` (refusals ignored); the fingerprint after every step.
        static func run(_ level: Level, _ steps: [Step]) throws(Refusal) -> (play: Play, fingerprints: [String]) {
            var play: Play = try playing(level)
            var fingerprints: [String] = [play.fingerprint]
            for step in steps {
                switch step {
                case .act(let action): try? play.apply(action, expecting: play.fingerprint)
                case .undo: try? play.undo()
                case .redo: try? play.redo()
                case .pause: try? play.handle(.pause)
                case .resume: try? play.handle(.resume)
                }
                fingerprints.append(play.fingerprint)
            }
            return (play, fingerprints)
        }

        /// The kernel sources present in the Core directory next to this test directory.
        static func kernelSources() throws -> [(name: String, text: String)] {
            let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
            var sources: [(name: String, text: String)] = []
            let names: [String] = (try? FileManager.default.contentsOfDirectory(atPath: core.path)) ?? []
            for name in names.sorted() where name.hasSuffix(".swift") {
                let url: URL = core.appendingPathComponent(name)
                sources.append((name, try String(contentsOf: url, encoding: .utf8)))
            }
            return sources
        }

        /// The lines of `text` that are not comments.
        static func codeLines(_ text: String) -> [String] {
            var lines: [String] = []
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed: String = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                lines.append(String(line))
            }
            return lines
        }

        // MARK: Independent computations

        /// Whether `p` lies inside an enclosure of `radius` cells about (3072, 3072), the rim inside.
        static func invInside(_ p: Point, radius: Int) -> Bool {
            let dx: Int = p.x - 3_072
            let dy: Int = p.y - 3_072
            let r: Int = radius * 256
            return dx * dx + dy * dy <= r * r
        }

        /// The row-major index of the cell holding `p` (a point inside the enclosure, so both coordinates positive).
        static func invIndex(_ p: Point) -> Int { (p.y / 256) * 24 + p.x / 256 }

        /// The largest group of `points` linked within `radius` cells, by union-find.
        static func invCoherence(_ points: [Point], radius: Int) -> Int {
            var parent: [Int] = Array(0..<points.count)
            func root(_ a: Int) -> Int {
                var x: Int = a
                while parent[x] != x { x = parent[x] }
                return x
            }
            let r: Int = radius * 256
            for a in points.indices {
                for b in points.indices where b > a {
                    let dx: Int = points[a].x - points[b].x
                    let dy: Int = points[a].y - points[b].y
                    if dx * dx + dy * dy <= r * r {
                        let ra: Int = root(a)
                        let rb: Int = root(b)
                        if ra != rb { parent[rb] = ra }
                    }
                }
            }
            var sizes: [Int: Int] = [:]
            for a in points.indices { sizes[root(a), default: 0] += 1 }
            var largest: Int = 0
            for (_, size) in sizes { largest = max(largest, size) }
            return largest
        }

        /// The group of `start` within `cells` under four-neighbour adjacency, by breadth-first search.
        static func invGroup(of start: Cell, in cells: Set<Cell>) -> Set<Cell> {
            var group: Set<Cell> = [start]
            var queue: [Cell] = [start]
            var head: Int = 0
            while head < queue.count {
                let c: Cell = queue[head]
                head += 1
                let around: [Cell] = [Cell(row: c.row + 1, column: c.column), Cell(row: c.row - 1, column: c.column),
                                      Cell(row: c.row, column: c.column + 1), Cell(row: c.row, column: c.column - 1)]
                for n in around where cells.contains(n) && !group.contains(n) {
                    group.insert(n)
                    queue.append(n)
                }
            }
            return group
        }

        /// The judge of a swim from its positions (tick 0 first), independently: per tick exit then coherence, after
        /// the swim coverage then connectedness.
        static func invJudge(_ level: Level, positions: [[Point]]) -> Failure? {
            var density: [Int] = Array(repeating: 0, count: 576)
            for tick in 1..<positions.count {
                for k in positions[tick].indices where !invInside(positions[tick][k], radius: level.radius) {
                    return .exit(swimmer: k, tick: tick)
                }
                for p in positions[tick] { density[invIndex(p)] += 1 }
                let group: Int = invCoherence(positions[tick], radius: level.rules.coherenceRadius)
                if group < level.coherence { return .coherence(tick: tick, group: group) }
            }
            var lit: [Cell] = []
            for cell in level.stencil.sorted() where density[cell.row * 24 + cell.column] >= level.threshold {
                lit.append(cell)
            }
            let size: Int = level.stencil.count
            if lit.count * 1000 < level.coverage * size {
                var needed: Int = 0
                while needed * 1000 < level.coverage * size { needed += 1 }
                return .coverage(lit: lit.count, needed: needed)
            }
            guard let first = lit.first else { return nil }
            let joined: Set<Cell> = invGroup(of: first, in: Set(lit))
            for cell in lit where !joined.contains(cell) { return .connectedness(cell: cell) }
            return nil
        }

        /// The swim of `level` with `wells` judged independently, with the kernel's report.
        static func judged(_ level: Level, _ wells: [Well]) -> (report: Report, judge: Failure?, ticks: Int) {
            let swum: (report: Report, positions: [[Point]]) = Dish.swim(level, wells: wells, keepPositions: true)
            return (swum.report, invJudge(level, positions: swum.positions), swum.positions.count - 1)
        }

        /// Whether the words of `failure` name its swimmer or cell and its tick (or counts).
        static func wordsSay(_ level: Level, _ failure: Failure) -> Bool {
            let words: String = level.failureDescription(failure)
            switch failure {
            case .exit(let swimmer, let tick):
                return words.contains("swimmer \(swimmer + 1) ") && words.hasSuffix(" tick \(tick)")
            case .coherence(let tick, let group):
                return words.contains(" tick \(tick) (") && words.contains("largest group \(group),")
            case .coverage(let lit, let needed):
                return words.contains("\(lit) of \(level.stencil.count) ") && words.hasSuffix("needs \(needed)")
            case .connectedness(let cell):
                return words.hasPrefix("row \(cell.row), column \(cell.column) ")
            }
        }
    }

    // MARK: INV-01 Time

    @Test func testMicroscopicAuroraTimeBoundary() throws {
        // Direct boundary: the ballistic quartet moves exactly 8 dish units per whole tick; a swim that does not fail
        // keeps T + 1 positions and T ticks, and its trails add 4 per tick.
        let level: Level = try Inv.hand()
        let swum: (report: Report, positions: [[Point]]) = Dish.swim(level, wells: [], keepPositions: true)
        #expect(swum.report.wins)
        #expect(swum.report.ticks == 120 && swum.positions.count == 121)
        for tick in 0...120 {
            #expect(swum.positions[tick][0] == Point(x: 3_040 + 8 * tick, y: 3_040))
            #expect(swum.positions[tick][3] == Point(x: 3_104 + 8 * tick, y: 3_104))
        }
        var trail: Int = 0
        for value in swum.report.density { trail += value }
        #expect(trail == 4 * 120)
        // Lengths T − 1, T and T + 1 at both range bounds.
        for length in [119, 120, 121, 479, 480, 481] {
            let refused: Refusal? = Inv.refusal { () throws(Refusal) in _ = try Inv.hand(radius: 11, length: length) }
            let inRange: Bool = length >= 120 && length <= 480
            #expect(refused == (inRange ? nil : .level("length")), "length \(length)")
        }
        // A longer swim of the same level repeats the shorter one's positions tick for tick.
        let long: Level = try Inv.hand(split: true, length: 121, coherence: 2)
        let short: Level = try Inv.hand(split: true, length: 120, coherence: 2)
        let longSwim: [[Point]] = Dish.swim(long, wells: [], keepPositions: true).positions
        let shortSwim: [[Point]] = Dish.swim(short, wells: [], keepPositions: true).positions
        #expect(longSwim.count == 122 && shortSwim.count == 121)
        for tick in shortSwim.indices { #expect(longSwim[tick] == shortSwim[tick]) }
        // Pauses and reads between the same actions change nothing; an idle play spends nothing and never fails.
        let fixture: Fixture = Inv.fixtures[0]
        let direct: Play = try Inv.played(fixture.level, Array(fixture.actions.dropLast()))
        var slow: Play = try Inv.playing(fixture.level)
        for action in fixture.actions.dropLast() {
            for _ in 0..<3 {
                try slow.handle(.pause)
                _ = fixture.level.progressDescription(report: slow.report, wells: slow.wells,
                                                      actionsLeft: slow.actionsLeft)
                try slow.handle(.resume)
            }
            try slow.apply(action, expecting: slow.fingerprint)
        }
        #expect(slow.fingerprint == direct.fingerprint && slow.report == direct.report)
        var idle: Play = try Inv.playing(fixture.level)
        let start: String = idle.fingerprint
        for _ in 0..<10 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.fingerprint == start && idle.actionsLeft == fixture.level.budget && idle.failure == nil)
        #expect(idle.stage == .playing && idle.report == fixture.level.startReport)

        // Seeded neighbours: random lengths in range and their neighbours on fixture levels; every swim counts whole
        // ticks 1 … T (failures name a tick in range, swims that do not fail keep T + 1 positions).
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var checked: Int = 0
        for fixture in Inv.fixtures.prefix(20) {
            let length: Int = random.int(120...480)
            for candidate in [length - 1, length, length + 1] {
                let refused: Refusal? = Inv.refusal { () throws(Refusal) in
                    _ = try Inv.copy(fixture.level, length: candidate, refusingAWin: false)
                }
                #expect(refused == (Level.lengths.contains(candidate) ? nil : .level("length")))
            }
            let level: Level = try Inv.copy(fixture.level, length: length, refusingAWin: false)
            let wells: [Well] = Inv.randomWells(&random, level)
            let swim: (report: Report, positions: [[Point]]) = Dish.swim(level, wells: wells, keepPositions: true)
            #expect(swim.positions.count == swim.report.ticks + 1)
            #expect(swim.report.ticks >= 1 && swim.report.ticks <= length)
            switch swim.report.failure {
            case .exit(_, let tick), .coherence(let tick, _): #expect(tick == swim.report.ticks)
            default: #expect(swim.report.ticks == length)
            }
            checked += 1
        }
        #expect(checked == 20)
        // No clock, time interval or floating-point value in the kernel sources.
        let tokens: [String] = ["Da" + "te(", "Continuous" + "Clock", "Suspending" + "Clock", "Time" + "Interval",
                                "CFAbsolute" + "Time", "Dispatch" + "Time", "Dou" + "ble", "Flo" + "at"]
        let sources: [(name: String, text: String)] = try Inv.kernelSources()
        #expect(!sources.isEmpty)
        for source in sources {
            for line in Inv.codeLines(source.text) {
                for token in tokens { #expect(!line.contains(token), "\(source.name): \(token)") }
            }
        }
    }

    // MARK: INV-02 Input budget

    @Test func testMicroscopicAuroraInputbudgetBoundary() throws {
        // Direct boundary: a budget of 2 on the split hand level; two placements are accepted, the third is refused
        // `budget` without any change, the play is still accepted.
        let level: Level = try Inv.hand(split: true, coherence: 3, budget: 2, refusingAWin: true)
        let a: Well = Well(cell: Cell(row: 5, column: 12), strength: 1, sense: .clockwise)
        let b: Well = Well(cell: Cell(row: 18, column: 12), strength: 2, sense: .counterclockwise)
        var loading: Play = Play(level: level)
        #expect(Inv.refusal { () throws(Refusal) in try loading.apply(.play, expecting: loading.fingerprint) }
            == .stage)
        var play: Play = try Inv.playing(level)
        #expect(play.actionsLeft == 2)
        try play.apply(.place(slot: 0, well: a), expecting: play.fingerprint)
        #expect(play.actionsLeft == 1 && play.actionsSpent == 1)
        try play.apply(.place(slot: 1, well: b), expecting: play.fingerprint)
        #expect(play.actionsLeft == 0 && play.actionsSpent == 2)
        let spent: Play = play
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.remove(slot: 0), expecting: play.fingerprint) }
            == .budget)
        #expect(Inv.refusal { () throws(Refusal) in
            try play.apply(.place(slot: 2, well: Well(cell: Cell(row: 12, column: 5), strength: 1, sense: .clockwise)),
                           expecting: play.fingerprint)
        } == .budget)
        // Action before budget, stale before action; refusals spend nothing and change nothing.
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.remove(slot: 2), expecting: play.fingerprint)
        }))
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.place(slot: 3, well: a), expecting: play.fingerprint)
        }))
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.place(slot: 3, well: a),
                                                                  expecting: Inv.staleFingerprint) } == .stale)
        #expect(play == spent && play.records.count == spent.records.count)
        try play.apply(.play, expecting: play.fingerprint)
        #expect(play.actionsSpent == 2 && (play.stage == .won || play.stage == .failed))
        // Budgets outside 1 … 12 are refused.
        for budget in [0, 13] {
            #expect(Inv.refusal { () throws(Refusal) in _ = try Inv.hand(budget: budget) } == .level("budget"))
        }

        // Seeded neighbours: budgets b − 1, b and b + 1 of each fixture accept exactly that many placements (slot 0
        // toggled between two free cells), then refuse `budget` and still accept the play.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var levels: Int = 0
        for fixture in Inv.fixtures.prefix(16) {
            var taken: Set<Cell> = []
            for slot in 1..<Level.slots { if let well = fixture.level.wells[slot] { taken.insert(well.cell) } }
            let first: Well = Inv.randomWell(&random, fixture.level, avoiding: taken)
            taken.insert(first.cell)
            let second: Well = Inv.randomWell(&random, fixture.level, avoiding: taken)
            for budget in [fixture.level.budget - 1, fixture.level.budget, fixture.level.budget + 1] {
                guard Level.budgets.contains(budget) else { continue }
                let level: Level = try Inv.copy(fixture.level, budget: budget, refusingAWin: true)
                var walk: Play = try Inv.playing(level)
                var accepted: Int = 0
                var refusal: Refusal? = nil
                for index in 0..<(budget + 2) {
                    let action: Action = .place(slot: 0, well: index % 2 == 0 ? first : second)
                    let before: Play = walk
                    refusal = Inv.refusal { () throws(Refusal) in try walk.apply(action, expecting: walk.fingerprint) }
                    if refusal == nil {
                        accepted += 1
                        #expect(walk.actionsSpent == before.actionsSpent + 1)
                    } else {
                        #expect(walk == before)
                        break
                    }
                }
                #expect(accepted == budget && refusal == .budget && walk.actionsLeft == 0)
                try walk.apply(.play, expecting: walk.fingerprint)
                #expect(walk.actionsSpent == budget)
                levels += 1
            }
        }
        #expect(levels >= 32)
    }

    // MARK: INV-03 Goal

    @Test func testMicroscopicAuroraGoalBoundary() throws {
        // Direct boundary: the ballistic quartet lights rows 11 and 12, columns 12 … 15 (8 cells) as one group. With
        // the unlit cell (11, 16) added the coverage is 8000 / 9 = 888: a requirement of 888 wins, 889 (one cell
        // above the lit count) fails `coverage` with 8 lit of 9 needed.
        var stencil: [Cell] = Inv.band(12...15)
        stencil.append(Cell(row: 11, column: 16))
        let atBound: Report = Dish.report(try Inv.hand(stencil: stencil, coverage: 888), wells: [])
        #expect(atBound.wins && atBound.coverage == 888 && atBound.litStencil.count == 8 && atBound.groups == 1)
        let above: Report = Dish.report(try Inv.hand(stencil: stencil, coverage: 889), wells: [])
        #expect(above.failure == .coverage(lit: 8, needed: 9))
        // One group: the stencil cut into columns 12 and 15 fails `connectedness` at (11, 15) with full coverage.
        let cut: [Cell] = [Cell(row: 11, column: 12), Cell(row: 12, column: 12), Cell(row: 11, column: 15),
                           Cell(row: 12, column: 15)]
        let parted: Report = Dish.report(try Inv.hand(stencil: cut), wells: [])
        #expect(parted.coverage == 1000 && parted.groups == 2)
        #expect(parted.failure == .connectedness(cell: Cell(row: 11, column: 15)))
        // No exit: in an enclosure of 6 cells the leading pair (2, 3) reaches x = 3104 + 8 · 188 at tick 188.
        let small: Report = Dish.report(try Inv.hand(radius: 6, length: 240, stencil: Inv.band(11...13)), wells: [])
        #expect(small.failure == .exit(swimmer: 2, tick: 188))
        // Coherence: the split pairs part beyond 2 cells (64 + 16t > 512) at tick 29; a requirement of 3 fails.
        let split: Report = Dish.report(try Inv.hand(split: true, coherence: 3), wells: [])
        #expect(split.failure == .coherence(tick: 29, group: 2))
        let pairs: Report = Dish.report(try Inv.hand(split: true, coherence: 2), wells: [])
        #expect(pairs.smallestCoherence == 2 && pairs.failure?.code != "coherence")
        // The known fixture actions win.
        for fixture in Inv.fixtures.prefix(10) {
            let won: Play = try Inv.played(fixture.level, fixture.actions)
            #expect(won.stage == .won && won.failure == nil)
        }

        // Seeded neighbours: on each fixture the winning wells win; a stencil with one unlit cell added wins at the
        // floor coverage and fails one tenth above; a stencil with a cut cell removed fails `connectedness`; random
        // wells are judged exactly as the independent judge, and wins only with every condition met.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var coverageCases: Int = 0
        var cutCases: Int = 0
        var outcomes: [String: Int] = [:]
        for fixture in Inv.fixtures.prefix(24) {
            let winning: [Well] = fixture.winning.compactMap { $0 }
            let report: Report = Dish.report(fixture.level, wells: winning)
            #expect(report.wins)
            let lit: Int = report.litStencil.count
            let members: Set<Cell> = Set(fixture.level.stencil)
            var unlit: Cell? = nil
            for index in 0..<576 where report.density[index] < fixture.level.threshold {
                let cell: Cell = Cell(row: index / 24, column: index % 24)
                if !members.contains(cell) && Level.isUsable(cell, radius: fixture.level.radius) {
                    unlit = cell
                    break
                }
            }
            if let unlit, fixture.level.stencil.count < Level.stencilSizes.upperBound {
                let wider: [Cell] = fixture.level.stencil + [unlit]
                let floor: Int = lit * 1000 / (lit + 1)
                if floor >= Level.coverages.lowerBound {
                    let bound: Level = try Inv.copy(fixture.level, stencil: wider, coverage: floor, refusingAWin: false)
                    #expect(Dish.report(bound, wells: winning).wins)
                    let over: Level = try Inv.copy(fixture.level, stencil: wider, coverage: floor + 1,
                                                   refusingAWin: false)
                    #expect(Dish.report(over, wells: winning).failure == .coverage(lit: lit, needed: lit + 1))
                    coverageCases += 1
                }
            }
            for removed in fixture.level.stencil {
                let rest: [Cell] = fixture.level.stencil.filter { $0 != removed }
                guard rest.count >= Level.stencilSizes.lowerBound, Dish.groups(rest) >= 2 else { continue }
                let level: Level = try Inv.copy(fixture.level, stencil: rest, coverage: 500, refusingAWin: false)
                let judged: (report: Report, judge: Failure?, ticks: Int) = Inv.judged(level, winning)
                #expect(judged.report.failure?.code == "connectedness" && judged.report.failure == judged.judge)
                cutCases += 1
                break
            }
            for _ in 0..<4 {
                let wells: [Well] = Inv.randomWells(&random, fixture.level)
                let judged: (report: Report, judge: Failure?, ticks: Int) = Inv.judged(fixture.level, wells)
                #expect(judged.report.failure == judged.judge)
                let r: Report = judged.report
                let allMet: Bool = judged.judge?.code != "exit" && r.smallestCoherence >= fixture.level.coherence
                    && r.coverage >= fixture.level.coverage && r.groups == 1
                #expect(r.wins == allMet)
                outcomes[r.failure?.code ?? "win", default: 0] += 1
            }
        }
        #expect(coverageCases >= 12 && cutCases >= 6)
        #expect(outcomes.values.reduce(0, +) == 96)
    }

    // MARK: INV-04 Repeatability

    @Test func testMicroscopicAuroraRepeatabilityBoundary() throws {
        // Direct boundary: the known fixture trace twice gives identical fingerprints and outcome; replay repeats it.
        let fixture: Fixture = Inv.fixtures[0]
        var steps: [Step] = []
        for action in fixture.actions { steps.append(.act(action)) }
        let first: (play: Play, fingerprints: [String]) = try Inv.run(fixture.level, steps)
        let second: (play: Play, fingerprints: [String]) = try Inv.run(fixture.level, steps)
        #expect(first.fingerprints == second.fingerprints)
        #expect(first.play.stage == .won && second.play.stage == .won && first.play == second.play)
        let replayed: Play = try Play.replay(level: fixture.level, records: first.play.records)
        #expect(replayed.fingerprint == first.play.fingerprint && replayed.records == first.play.records)
        // A trace with a record removed, and the trace of another level, are refused `malformed`.
        for index in 0..<(first.play.records.count - 1) {
            var gapped: [Record] = first.play.records
            gapped.remove(at: index)
            #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in
                _ = try Play.replay(level: fixture.level, records: gapped)
            }), "record \(index) removed")
        }
        let other: Level = Inv.fixtures[1].level
        #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in
            _ = try Play.replay(level: other, records: first.play.records)
        }))

        // Seeded neighbours: seeded traces on the fixtures run twice give identical fingerprints, records, reports
        // and outcomes, and replay reproduces the final play.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var traces: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            let trace: [Step] = Inv.randomSteps(fixture.level, count: 16, random: &random)
            let a: (play: Play, fingerprints: [String]) = try Inv.run(fixture.level, trace)
            let b: (play: Play, fingerprints: [String]) = try Inv.run(fixture.level, trace)
            #expect(a.fingerprints == b.fingerprints)
            #expect(a.play.records == b.play.records && a.play.report == b.play.report)
            #expect(a.play.stage == b.play.stage && a.play.failure == b.play.failure)
            let again: Play = try Play.replay(level: fixture.level, records: a.play.records)
            #expect(again.fingerprint == a.play.fingerprint && again.stage == a.play.stage)
            #expect(again.wells == a.play.wells && again.report == a.play.report)
            traces += 1
        }
        #expect(traces == 24)
    }

    // MARK: INV-05 Undo

    @Test func testMicroscopicAuroraUndoBoundary() throws {
        // Direct boundary: on the split hand level a placement and a failed play are undone to the exact prior
        // fingerprints (the failed play returns to playing with the wells before it); redo restores the later ones.
        let level: Level = try Inv.hand(split: true, coherence: 3, refusingAWin: true)
        var play: Play = try Inv.playing(level)
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in try play.undo() }))
        let start: String = play.fingerprint
        // The first strength-1 well along column 12 whose swim still fails (most leave the split unhealed).
        var well: Well = Well(cell: Cell(row: 2, column: 12), strength: 1, sense: .clockwise)
        for row in 2...21 {
            let candidate: Well = Well(cell: Cell(row: row, column: 12), strength: 1, sense: .clockwise)
            if Dish.report(level, wells: [candidate]).failure != nil {
                well = candidate
                break
            }
        }
        try play.apply(.place(slot: 0, well: well), expecting: play.fingerprint)
        #expect(play.report.failure != nil)
        let placed: String = play.fingerprint
        try play.apply(.play, expecting: play.fingerprint)
        #expect(play.stage == .failed && play.failure != nil)
        let failed: String = play.fingerprint
        try play.undo()
        #expect(play.fingerprint == placed && play.stage == .playing && play.failure == nil)
        #expect(play.wells[0] == well && play.actionsSpent == 1)
        try play.undo()
        #expect(play.fingerprint == start && play.actionsSpent == 0 && play.wells == level.wells)
        try play.redo()
        #expect(play.fingerprint == placed)
        try play.redo()
        #expect(play.fingerprint == failed && play.stage == .failed)
        try play.undo()
        // Undo while paused stays paused; a new action clears redo.
        try play.handle(.pause)
        try play.undo()
        #expect(play.stage == .paused && play.actionsSpent == 0)
        try play.handle(.resume)
        #expect(play.fingerprint == start && play.canRedo)
        try play.apply(.place(slot: 1, well: well), expecting: play.fingerprint)
        #expect(!play.canRedo && Inv.isAction(Inv.refusal { () throws(Refusal) in try play.redo() }))
        // A won play is final.
        let fixture: Fixture = Inv.fixtures[0]
        var won: Play = try Inv.played(fixture.level, fixture.actions)
        #expect(won.stage == .won)
        #expect(Inv.refusal { () throws(Refusal) in try won.undo() } == .stage)

        // Seeded neighbours: seeded walks of accepted placements, removals and a play are undone step by step to the
        // exact earlier fingerprints, then redone to the exact later ones.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var walks: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            var walk: Play = try Inv.playing(fixture.level)
            var history: [String] = [walk.fingerprint]
            for _ in 0..<12 {
                let r: Int = random.int(0...5)
                let action: Action
                if r == 0 {
                    action = .remove(slot: random.int(0...2))
                } else if r == 5 {
                    action = .play
                } else {
                    action = .place(slot: random.int(0...2), well: Inv.randomWell(&random, fixture.level))
                }
                if (try? walk.apply(action, expecting: walk.fingerprint)) != nil { history.append(walk.fingerprint) }
                if walk.stage != .playing { break }
            }
            if walk.stage == .won {
                #expect(Inv.refusal { () throws(Refusal) in try walk.undo() } == .stage)
                continue
            }
            for index in stride(from: history.count - 2, through: 0, by: -1) {
                try walk.undo()
                #expect(walk.fingerprint == history[index])
            }
            #expect(!walk.canUndo && Inv.isAction(Inv.refusal { () throws(Refusal) in try walk.undo() }))
            for index in 1..<history.count {
                try walk.redo()
                #expect(walk.fingerprint == history[index])
            }
            walks += 1
        }
        #expect(walks >= 12)
    }

    // MARK: INV-07 Failure honesty

    @Test func testMicroscopicAuroraFailurehonestyBoundary() throws {
        // Direct boundary: the exit and coherence hand levels fail on the play naming the swimmer or the group and
        // the tick; the words say it; the wells and actions spent stay as they were.
        let exitLevel: Level = try Inv.hand(radius: 6, length: 240, stencil: Inv.band(11...13), refusingAWin: true)
        var exitPlay: Play = try Inv.playing(exitLevel)
        try exitPlay.apply(.play, expecting: exitPlay.fingerprint)
        #expect(exitPlay.stage == .failed && exitPlay.failure == .exit(swimmer: 2, tick: 188))
        #expect(exitLevel.failureDescription(.exit(swimmer: 2, tick: 188)) == "swimmer 3 leaves the dish at tick 188")
        #expect(exitPlay.wells == exitLevel.wells && exitPlay.actionsSpent == 0)
        let splitLevel: Level = try Inv.hand(split: true, coherence: 3, refusingAWin: true)
        var splitPlay: Play = try Inv.playing(splitLevel)
        try splitPlay.apply(.play, expecting: splitPlay.fingerprint)
        #expect(splitPlay.failure == .coherence(tick: 29, group: 2))
        #expect(Inv.wordsSay(splitLevel, .coherence(tick: 29, group: 2)))
        var stencil: [Cell] = Inv.band(12...15)
        stencil.append(Cell(row: 11, column: 16))
        let coverageLevel: Level = try Inv.hand(stencil: stencil, coverage: 889, refusingAWin: true)
        var coveragePlay: Play = try Inv.playing(coverageLevel)
        try coveragePlay.apply(.play, expecting: coveragePlay.fingerprint)
        #expect(coveragePlay.failure == .coverage(lit: 8, needed: 9))
        #expect(coverageLevel.failureDescription(.coverage(lit: 8, needed: 9)) == "stencil 8 of 9 cells lit, needs 9")
        let cut: [Cell] = [Cell(row: 11, column: 12), Cell(row: 12, column: 12), Cell(row: 11, column: 15),
                           Cell(row: 12, column: 15)]
        let cutLevel: Level = try Inv.hand(stencil: cut, refusingAWin: true)
        var cutPlay: Play = try Inv.playing(cutLevel)
        try cutPlay.apply(.play, expecting: cutPlay.fingerprint)
        #expect(cutPlay.failure == .connectedness(cell: Cell(row: 11, column: 15)))
        #expect(cutLevel.failureDescription(.connectedness(cell: Cell(row: 11, column: 15)))
            == "row 11, column 15 is not joined to the pattern")
        for failed in [exitPlay, splitPlay, coveragePlay, cutPlay] {
            if let failure = failed.failure { #expect(Inv.wordsSay(failed.level, failure)) }
            #expect(failed.failure == failed.report.failure)
        }
        // Refusals carry their codes.
        let codes: [Refusal] = [.level("x"), .action("x"), .budget, .stage, .stale, .newerSchema(2), .malformed("x")]
        for code in codes { #expect(code.reasonCode.hasPrefix("r02-g19.")) }

        // Seeded neighbours: each fixture played from its start (never a win), and after one random placement, fails
        // with the independent judge's failure; the failing tick lies in 1 … T; the words name it; nothing is fixed.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var failures: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            var direct: Play = try Inv.playing(fixture.level)
            try direct.apply(.play, expecting: direct.fingerprint)
            #expect(direct.stage == .failed)
            let start: (report: Report, judge: Failure?, ticks: Int) = Inv.judged(fixture.level,
                                                                                    fixture.level.placedWells)
            #expect(direct.failure == start.judge && direct.failure != nil)
            #expect(direct.wells == fixture.level.wells && direct.actionsSpent == 0)
            var moved: Play = try Inv.playing(fixture.level)
            let well: Well = Inv.randomWell(&random, fixture.level)
            try? moved.apply(.place(slot: random.int(0...2), well: well), expecting: moved.fingerprint)
            let wellsBefore: [Well?] = moved.wells
            let spentBefore: Int = moved.actionsSpent
            try moved.apply(.play, expecting: moved.fingerprint)
            let judged: (report: Report, judge: Failure?, ticks: Int) = Inv.judged(fixture.level,
                                                                                     wellsBefore.compactMap { $0 })
            #expect(moved.failure == judged.judge && moved.wells == wellsBefore && moved.actionsSpent == spentBefore)
            for play in [direct, moved] {
                guard let failure = play.failure else { continue }
                #expect(Inv.wordsSay(fixture.level, failure))
                switch failure {
                case .exit(let swimmer, let tick):
                    #expect(swimmer >= 0 && swimmer < fixture.level.swimmers.count)
                    #expect(tick >= 1 && tick <= fixture.level.length)
                case .coherence(let tick, let group):
                    #expect(tick >= 1 && tick <= fixture.level.length && group < fixture.level.coherence)
                case .coverage(let lit, let needed):
                    #expect(lit < needed && needed <= fixture.level.stencil.count)
                case .connectedness(let cell):
                    #expect(play.report.litStencil.contains(cell))
                }
                failures += 1
            }
        }
        #expect(failures >= 24)
    }

    // MARK: INV-08 Stability

    @Test func testMicroscopicAuroraStabilityBoundary() throws {
        // Direct boundary: the strongest rules (all weights 8, a_max 16, v_max 48) with three strength-4 wells over
        // 480 ticks keep every velocity within ±48 per axis, every position within one step of the enclosure, and the
        // densities sum to swimmers × ticks swum.
        let fixture: Fixture = Inv.fixtures[0]
        let strong: Rules = Rules(neighbourRadius: 6, separationRadius: 6, coherenceRadius: fixture.level.rules
                                    .coherenceRadius, separationWeight: 8, alignmentWeight: 8, cohesionWeight: 8,
                                  maxAcceleration: 16, maxSpeed: 48)
        let extreme: Level = try Inv.copy(fixture.level, length: 480, rules: strong, refusingAWin: false)
        let wells: [Well] = [Well(cell: Cell(row: 6, column: 12), strength: 4, sense: .clockwise),
                             Well(cell: Cell(row: 18, column: 12), strength: 4, sense: .counterclockwise),
                             Well(cell: Cell(row: 12, column: 6), strength: 4, sense: .clockwise)]
        var swims: Int = 0
        swims += check(extreme, wells: wells)
        swims += check(try Inv.hand(), wells: [])

        // Seeded neighbours: fixtures with random wells, and with their v_max and a_max at the range bounds.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures.prefix(30) {
            for _ in 0..<3 {
                swims += check(fixture.level, wells: Inv.randomWells(&random, fixture.level))
            }
            let r: Rules = fixture.level.rules
            let bounds: Rules = Rules(neighbourRadius: r.neighbourRadius, separationRadius: r.separationRadius,
                                      coherenceRadius: r.coherenceRadius, separationWeight: r.separationWeight,
                                      alignmentWeight: r.alignmentWeight, cohesionWeight: r.cohesionWeight,
                                      maxAcceleration: random.int(0...1) == 0 ? 2 : 16, maxSpeed: 48)
            let level: Level = try Inv.copy(fixture.level, rules: bounds, refusingAWin: false)
            swims += check(level, wells: Inv.randomWells(&random, level))
        }
        #expect(swims == 122)
    }

    /// Checks one swim tick by tick against an independent stepping of the same swarm; returns 1 (one swim checked).
    private func check(_ level: Level, wells: [Well]) -> Int {
        let swim: (report: Report, positions: [[Point]]) = Dish.swim(level, wells: wells, keepPositions: true)
        let report: Report = swim.report
        let vmax: Int = level.rules.maxSpeed
        let reach: Int = level.radius * 256 + vmax
        var swimmers: [Swimmer] = level.swimmers
        var density: [Int] = Array(repeating: 0, count: 576)
        var exited: Bool = false
        for tick in 1..<swim.positions.count {
            swimmers = Dish.step(swimmers, wells: wells, rules: level.rules)
            for k in swimmers.indices {
                let v: Point = swimmers[k].velocity
                let p: Point = swimmers[k].position
                let previous: Point = swim.positions[tick - 1][k]
                #expect(abs(v.x) <= vmax && abs(v.y) <= vmax)
                #expect(p == swim.positions[tick][k])
                #expect(p.x == previous.x + v.x && p.y == previous.y + v.y)
                #expect(abs(p.x - 3_072) <= reach && abs(p.y - 3_072) <= reach)
            }
            var inside: Bool = true
            for s in swimmers where !Inv.invInside(s.position, radius: level.radius) { inside = false }
            if !inside {
                exited = true
                break
            }
            for s in swimmers { density[Inv.invIndex(s.position)] += 1 }
        }
        #expect(report.density == density && report.density.count == 576)
        var sum: Int = 0
        for value in report.density {
            #expect(value >= 0)
            sum += value
        }
        let swum: Int = exited ? report.ticks - 1 : report.ticks
        #expect(sum == level.swimmers.count * swum)
        #expect(report.finalSwimmers == swimmers && report.finalSwimmers.count == level.swimmers.count)
        #expect(report.coverage >= 0 && report.coverage <= 1000)
        #expect(report.smallestCoherence >= 1 && report.smallestCoherence <= level.swimmers.count)
        #expect(report.smallestCoherenceTick >= 0 && report.smallestCoherenceTick <= report.ticks)
        #expect(report.groups >= 0 && report.groups <= report.litStencil.count)
        #expect(report.litStencil == report.litStencil.sorted())
        for cell in report.litStencil { #expect(level.stencil.contains(cell)) }
        return 1
    }

    // MARK: INV-09 Save

    @Test func testMicroscopicAuroraSaveBoundary() throws {
        // Direct boundary: the hand level round-trips byte for byte; every one-byte edit and every truncation of its
        // stored form is refused; a newer schema and an edited fingerprint are refused with their reasons.
        let level: Level = try Inv.hand(split: true, coherence: 3, refusingAWin: true)
        let stored: Data = level.encoded()
        let decoded: Level = try Level.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored)
        let viaCodable: Level = try JSONDecoder().decode(Level.self, from: JSONEncoder().encode(level))
        #expect(viaCodable == level)
        let bytes: [UInt8] = Array(stored)
        for index in bytes.indices {
            var edited: [UInt8] = bytes
            edited[index] ^= 0x01
            let refused: Refusal? = Inv.refusal { () throws(Refusal) in _ = try Level.decode(Data(edited)) }
            #expect(refused != nil, "byte \(index) edited")
            #expect((try? JSONDecoder().decode(Level.self, from: Data(edited))) == nil, "Codable byte \(index)")
        }
        for length in 0..<bytes.count {
            let cut: Data = Data(bytes.prefix(length))
            #expect(Inv.refusal { () throws(Refusal) in _ = try Level.decode(cut) } != nil, "truncated to \(length)")
        }
        let text: String = String(decoding: stored, as: UTF8.self)
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(Inv.refusal { () throws(Refusal) in _ = try Level.decode(newer) } == .newerSchema(2))
        let head: String = String(level.fingerprint.prefix(1))
        let swapped: String = (head == "0" ? "1" : "0") + String(level.fingerprint.dropFirst())
        let forged: Data = Data(text.replacingOccurrences(of: level.fingerprint, with: swapped).utf8)
        #expect(Inv.refusal { () throws(Refusal) in _ = try Level.decode(forged) } == .malformed("fingerprint"))
        // A stored record trace replays to the same play.
        let fixture: Fixture = Inv.fixtures[0]
        let played: Play = try Inv.played(fixture.level, fixture.actions)
        let trace: Data = try JSONEncoder().encode(played.records)
        let records: [Record] = try JSONDecoder().decode([Record].self, from: trace)
        #expect(try Play.replay(level: fixture.level, records: records).fingerprint == played.fingerprint)

        // Seeded neighbours: every fixture round-trips; seeded one-byte edits (a random different byte) and seeded
        // truncations are refused, never partially accepted.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var edits: Int = 0
        for fixture in Inv.fixtures.prefix(20) {
            let data: Data = fixture.level.encoded()
            #expect(try Level.decode(data) == fixture.level && (try Level.decode(data)).encoded() == data)
            let original: [UInt8] = Array(data)
            for _ in 0..<24 {
                var edited: [UInt8] = original
                let index: Int = random.int(0...(original.count - 1))
                edited[index] = UInt8((Int(original[index]) + random.int(1...255)) % 256)
                #expect(Inv.refusal { () throws(Refusal) in _ = try Level.decode(Data(edited)) } != nil)
                let length: Int = random.int(0...(original.count - 1))
                #expect(Inv.refusal { () throws(Refusal) in _ = try Level.decode(Data(original.prefix(length))) }
                    != nil)
                edits += 1
            }
        }
        #expect(edits == 480)
    }

    // MARK: INV-10 Renderer purity

    @Test func testMicroscopicAuroraRendererpurityBoundary() throws {
        // Direct boundary: the report is the dish's pure function of the level and the wells; computing it twice, or
        // after reading words, gives equal reports; the play is a value type; the report holds only the truth metric.
        let fixture: Fixture = Inv.fixtures[0]
        let level: Level = fixture.level
        var play: Play = try Inv.playing(level)
        try play.apply(fixture.actions[0], expecting: play.fingerprint)
        let wells: [Well] = play.wells.compactMap { $0 }
        #expect(play.report == Dish.report(level, wells: wells))
        #expect(Dish.report(level, wells: wells) == Dish.report(level, wells: wells))
        #expect(Dish.report(level, wells: wells) == Dish.report(level, wells: wells.reversed()))
        let copy: Play = play
        let words: String = level.progressDescription(report: play.report, wells: play.wells,
                                                      actionsLeft: play.actionsLeft)
        #expect(words == level.progressDescription(report: play.report, wells: play.wells,
                                                   actionsLeft: play.actionsLeft))
        for slot in play.wells.indices { _ = level.wellDescription(slot, well: play.wells[slot]) }
        _ = level.coverageDescription(report: play.report)
        if let failure = play.report.failure { _ = level.failureDescription(failure) }
        #expect(play == copy && play.report == Dish.report(level, wells: wells))
        var changed: Play = copy
        try changed.handle(.pause)
        #expect(play == copy && changed != copy)
        let labels: [String] = Mirror(reflecting: play.report).children.compactMap { $0.label }
        #expect(Set(labels) == ["ticks", "finalSwimmers", "density", "litStencil", "coverage", "groups",
                                "smallestCoherence", "smallestCoherenceTick", "failure"])
        // The report never depends on the id, seed, difficulty, budget or tutorial.
        let others: [Level] = [try Inv.copy(level, id: "inv-renamed", refusingAWin: false),
                               try Inv.copy(level, seed: 99, refusingAWin: false),
                               try Inv.copy(level, difficulty: 5, refusingAWin: false),
                               try Inv.copy(level, budget: 12, refusingAWin: false),
                               try Inv.copy(level, tutorial: true, refusingAWin: false)]
        for other in others {
            #expect(Dish.report(other, wells: wells) == Dish.report(level, wells: wells))
            #expect(other.startReport == level.startReport)
        }
        // The kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation.
        let allowed: Set<String> = ["Foundation", "VisualCoreMath", "VisualCoreSimulation"]
        for source in try Inv.kernelSources() {
            for line in Inv.codeLines(source.text) where line.hasPrefix("import ") {
                let module: String = String(line.dropFirst("import ".count)).trimmingCharacters(in: .whitespaces)
                #expect(allowed.contains(module), "\(source.name) imports \(module)")
            }
        }

        // Seeded neighbours: along seeded traces the play's report is the pure function of the level and its wells,
        // reads of words change nothing, and a renamed level gives the same reports and outcomes.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures.prefix(16) {
            let renamed: Level = try Inv.copy(fixture.level, id: fixture.level.id + "-renamed", refusingAWin: true)
            let trace: [Step] = Inv.randomSteps(fixture.level, count: 10, random: &random)
            var a: Play = try Inv.playing(fixture.level)
            var b: Play = try Inv.playing(renamed)
            for step in trace {
                guard case .act(let action) = step else { continue }
                let refusedA: Refusal? = Inv.refusal { () throws(Refusal) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                let refusedB: Refusal? = Inv.refusal { () throws(Refusal) in
                    try b.apply(action, expecting: b.fingerprint)
                }
                #expect(refusedA == refusedB)
                #expect(a.report == Dish.report(fixture.level, wells: a.wells.compactMap { $0 }))
                #expect(a.report == b.report && a.wells == b.wells && a.stage == b.stage)
                #expect(a.failure == b.failure && a.actionsLeft == b.actionsLeft)
                let before: Play = a
                _ = fixture.level.progressDescription(report: a.report, wells: a.wells, actionsLeft: a.actionsLeft)
                for slot in a.wells.indices { _ = fixture.level.wellDescription(slot, well: a.wells[slot]) }
                _ = fixture.level.coverageDescription(report: a.report)
                #expect(a == before)
            }
        }
    }
}
