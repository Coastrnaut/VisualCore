// MushroomWeatherInvariantTests — feature 491 (R02-G20-01) T-R02G2001-006 (FR-R02G2001-012; the source's invariants
// R2-G20-INV-01 … 05 and INV-07 … 10 on Mushroom Weather), modelled on MicroscopicAuroraInvariantTests (feature 481).
// Each named test gives a direct boundary example and a seeded check of neighbouring inputs (seed 2,496: fixtures drawn
// from it, random arrangements and traces, run lengths T − 1, T and T + 1 at the range bounds, budgets ± 1, a band edge
// one unit either side, a required count one cycle either side, a survival floor and a mold bound ± 1, a byte of a
// stored level changed or the form truncated).
// How each invariant maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G20-02; INV-11 is
// superseded by the free tier):
// - INV-01 Time: no rule reads a clock; time is the whole cycle 1 … T of one run. A run that does not fail keeps T + 1
//   fields (cycle 0 first) and T ledger entries; a longer run of the same level repeats the shorter one's fields;
//   lengths 19 and 201 are refused, 20, 21, 199 and 200 accepted; pauses and reads between actions change nothing; the
//   kernel sources hold no clock, time interval or floating-point value.
// - INV-02 Input budget: an arrangement action spends exactly 1 action, the run none; the action that spends the last
//   one is accepted and the next refused `budget` while the run is still accepted; action before budget; stale before
//   action; refusals change nothing; budgets 0 and 25 are refused, b − 1, b and b + 1 give exactly that many.
// - INV-03 Goal: a run wins exactly when no colony dries out, no cell turns to mold and every colony is in band for
//   each of the last K cycles (judged by an independent judge); a band one unit off an edge, or K one cycle above the
//   final run, fails `unstable` naming the colony and its run; the known fixture actions win.
// - INV-04 Repeatability: the same trace twice gives identical fingerprints and outcome; replay reproduces them; a
//   trace with a record removed, or the trace of another level, is refused `malformed`.
// - INV-05 Undo: undo restores the exact prior fingerprint (including from failed, which returns to playing with the
//   arrangement before the run); redo the later one; a new action clears redo; a won run is final; undo while paused
//   stays paused.
// - INV-07 Failure honesty: a failed run names the colony or cell and the cycle of the first failure (dried before
//   mold, the lowest-numbered colony, the first cell in row-major order) equal to the independent judge; a survival
//   floor or a mold bound one unit either side moves the cycle exactly; the arrangement and actions spent stay as they
//   were; the words of `failureDescription` say it.
// - INV-08 Stability: an independent stepping of the weather reproduces every field, ledger, growth and colony run;
//   every ledger balances, humidity is never negative and blocked cells stay 0, over seeded and extreme runs.
// - INV-09 Save: stored levels round-trip byte for byte (through `encoded`/`decode` and through Codable); every
//   one-byte edit and every truncation is refused; a stored record trace replays to the same play.
// - INV-10 Renderer purity: the report and the fields are values derived only from the level and the arrangement
//   (never of call order, reads of fields or words, the id, seed, difficulty, budget or tutorial; swapping the slots of
//   two pods only permutes their growth); the report type holds only the truth metric; the play is a value type; the
//   kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden tokens are built by concatenation so
// that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherInvariantTests {
    typealias Play = MushroomWeatherPlay
    typealias Level = MushroomWeatherLevel
    typealias Action = MushroomWeatherAction
    typealias Failure = MushroomWeatherFailure
    typealias Report = MushroomWeatherReport
    typealias Cell = MushroomWeatherCell
    typealias Colony = MushroomWeatherColony
    typealias Vent = MushroomWeatherVent
    typealias Rules = MushroomWeatherPodRules
    typealias Arrangement = MushroomWeatherArrangement
    typealias Ledger = MushroomWeatherLedger
    typealias Runs = MushroomWeatherColonyRuns
    typealias Fixture = MushroomWeatherFixture
    typealias Record = MushroomWeatherRecord
    typealias Refusal = MushroomWeatherError
    typealias Forest = MushroomWeatherForest

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
        static let seed: UInt64 = 2_496

        /// A fingerprint that is never the current one.
        static let staleFingerprint: String = String(repeating: "0", count: 64)

        /// The fixtures of the invariant seed (computed once).
        static let fixtures: [Fixture] = Fixture.all(count: 40, seed: seed)

        static let a: Cell = Cell(row: 0, column: 0)
        static let b: Cell = Cell(row: 0, column: 1)
        static let c: Cell = Cell(row: 0, column: 2)
        static let d: Cell = Cell(row: 2, column: 2)
        static let far: Cell = Cell(row: 5, column: 5)

        /// A hand-made 6 × 6 level whose floor is `floor` (every other cell blocked), with the given humidity and rates
        /// by cell (0 elsewhere), no vents, the given colonies and pods (`refusingAWin` false lets a probe read any
        /// report).
        static func hand(floor: [Cell], humidity: [Cell: Int], rates: [Cell: Int] = [:], diffusion: Int = 8,
                         colonies: [Colony], podRules: Rules? = nil, pods: [Cell?] = [nil], moonlight: Int = 0,
                         moldBound: Int = 10_000, length: Int = 20, required: Int = 5, budget: Int = 3,
                         refusingAWin: Bool = false) throws(Refusal) -> Level {
            let floorSet: Set<Cell> = Set(floor)
            var blocked: [Cell] = []
            var h: [Int] = []
            var r: [Int] = []
            for row in 0..<6 {
                for column in 0..<6 {
                    let cell: Cell = Cell(row: row, column: column)
                    if !floorSet.contains(cell) { blocked.append(cell) }
                    h.append(humidity[cell] ?? 0)
                    r.append(rates[cell] ?? 0)
                }
            }
            let rules: Rules = podRules ?? Rules(slots: pods.count, release: 10, grownRelease: 80, growthThreshold: 100)
            return try Level(id: "inv-hand", seed: 7, difficulty: 1, rows: 6, columns: 6, blocked: blocked,
                             humidity: h, diffusion: diffusion, rates: r, vents: [], podRules: rules,
                             colonies: colonies, moldBound: moldBound, length: length, required: required,
                             start: Arrangement(pods: pods, ventsOpen: [], moonlight: moonlight), budget: budget,
                             tutorial: false, refusingAWin: refusingAWin)
        }

        /// A steady colony on `far` (500 units, rate 0, no neighbours) with band `low` … `high`.
        static func steady(low: Int = 0, high: Int = 1_000) -> Colony { Colony(cell: far, low: low, high: high) }

        /// The two-slot budget level: pods may go on `a` and `b`; the steady colony wants 600 or more, so every run
        /// fails `unstable`.
        static func budgetLevel(budget: Int) throws(Refusal) -> Level {
            try hand(floor: [a, b, far], humidity: [far: 500], colonies: [steady(low: 600, high: 10_000)],
                     pods: [nil, nil], budget: budget, refusingAWin: true)
        }

        /// `level` with some values replaced.
        static func copy(_ level: Level, id: String? = nil, seed: UInt64? = nil, difficulty: Int? = nil,
                         humidity: [Int]? = nil, diffusion: Int? = nil, rates: [Int]? = nil, vents: [Vent]? = nil,
                         podRules: Rules? = nil, colonies: [Colony]? = nil, moldBound: Int? = nil,
                         length: Int? = nil, required: Int? = nil, start: Arrangement? = nil, budget: Int? = nil,
                         tutorial: Bool? = nil, refusingAWin: Bool) throws(Refusal) -> Level {
            try Level(id: id ?? level.id, seed: seed ?? level.seed, difficulty: difficulty ?? level.difficulty,
                      rows: level.rows, columns: level.columns, blocked: level.blocked,
                      humidity: humidity ?? level.humidity, diffusion: diffusion ?? level.diffusion,
                      rates: rates ?? level.rates, vents: vents ?? level.vents, podRules: podRules ?? level.podRules,
                      colonies: colonies ?? level.colonies, moldBound: moldBound ?? level.moldBound,
                      length: length ?? level.length, required: required ?? level.required,
                      start: start ?? level.start, budget: budget ?? level.budget,
                      tutorial: tutorial ?? level.tutorial, refusingAWin: refusingAWin)
        }

        /// `colonies` with colony 0's band and floor replaced.
        static func replacingFirst(_ colonies: [Colony], low: Int, high: Int, floor: Int?) -> [Colony] {
            var result: [Colony] = colonies
            result[0] = Colony(cell: colonies[0].cell, low: low, high: high, survivalFloor: floor)
            return result
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

        /// The floor cells of `level`, row-major.
        static func floorCells(_ level: Level) -> [Cell] {
            var cells: [Cell] = []
            for index in 0..<(level.rows * level.columns) where level.floorMask[index] {
                cells.append(level.cell(at: index))
            }
            return cells
        }

        /// A random cell of the grid of `level` (floor or blocked).
        static func randomCell(_ random: inout SeededRandom, _ level: Level) -> Cell {
            Cell(row: random.int(0...(level.rows - 1)), column: random.int(0...(level.columns - 1)))
        }

        /// A random arrangement of `level`: each slot empty or on a free floor cell, random vents and moonlight.
        static func randomArrangement(_ random: inout SeededRandom, _ level: Level) -> Arrangement {
            var used: Set<Cell> = level.colonyCells
            let floor: [Cell] = floorCells(level)
            var pods: [Cell?] = []
            for _ in 0..<level.podRules.slots {
                if random.int(0...2) == 0 {
                    pods.append(nil)
                    continue
                }
                let free: [Cell] = floor.filter { !used.contains($0) }
                if free.isEmpty {
                    pods.append(nil)
                    continue
                }
                let cell: Cell = free[random.int(0...(free.count - 1))]
                used.insert(cell)
                pods.append(cell)
            }
            var vents: [Bool] = []
            for _ in level.vents { vents.append(random.int(0...1) == 1) }
            return Arrangement(pods: pods, ventsOpen: vents, moonlight: random.int(0...3))
        }

        /// A random arrangement action on `level` (possibly one the play refuses).
        static func randomAction(_ random: inout SeededRandom, _ level: Level) -> Action {
            let slots: Int = level.podRules.slots
            let r: Int = random.int(0...6)
            if r <= 2 {
                return .place(slot: random.int(0...(slots - 1)), cell: randomCell(&random, level))
            } else if r == 3 {
                return .remove(slot: random.int(0...(slots - 1)))
            } else if r == 4 {
                return .vent(index: random.int(0...max(0, level.vents.count - 1)), open: random.int(0...1) == 1)
            }
            return .moonlight(level: random.int(0...3))
        }

        /// A seeded trace of `count` steps on `level`: arrangement actions, undo, redo, pause, resume and run.
        static func randomSteps(_ level: Level, count: Int, random: inout SeededRandom) -> [Step] {
            var steps: [Step] = []
            for _ in 0..<count {
                let r: Int = random.int(0...9)
                if r <= 4 {
                    steps.append(.act(randomAction(&random, level)))
                } else if r == 5 {
                    steps.append(.undo)
                } else if r == 6 {
                    steps.append(.redo)
                } else if r == 7 {
                    steps.append(.pause)
                } else if r == 8 {
                    steps.append(.resume)
                } else {
                    steps.append(.act(.run))
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

        /// The humidity of an isolated cell with no pod, cycle 0 … `cycles`: hₙ₊₁ = hₙ − ⌊hₙ·rate·(4 + L)/4096⌋.
        static func invDecay(_ start: Int, rate: Int, moonlight: Int, cycles: Int) -> [Int] {
            var h: [Int] = [start]
            for _ in 0..<cycles {
                let last: Int = h[h.count - 1]
                h.append(last - min(last, last * rate * (4 + moonlight) / 4096))
            }
            return h
        }

        /// One cycle of the weather, independently: diffusion, evaporation and release, each from the state at the
        /// start of its step; with the released and evaporated totals.
        static func invCycle(_ h: [Int], _ level: Level, _ arrangement: Arrangement,
                             grown: [Bool]) -> (h: [Int], released: Int, evaporated: Int) {
            var rates: [Int] = level.rates
            for index in level.vents.indices {
                let vent: Vent = level.vents[index]
                rates[vent.cell.row * level.columns + vent.cell.column] =
                    arrangement.ventsOpen[index] ? vent.openRate : vent.closedRate
            }
            var next: [Int] = h
            for row in 0..<level.rows {
                for column in 0..<level.columns {
                    let i: Int = row * level.columns + column
                    if !level.floorMask[i] { continue }
                    var neighbours: [Int] = []
                    if column + 1 < level.columns { neighbours.append(i + 1) }
                    if row + 1 < level.rows { neighbours.append(i + level.columns) }
                    for j in neighbours where level.floorMask[j] {
                        let flow: Int = (h[i] - h[j]) * level.diffusion / 64
                        next[i] -= flow
                        next[j] += flow
                    }
                }
            }
            var evaporated: Int = 0
            for i in next.indices where level.floorMask[i] {
                let e: Int = min(next[i], next[i] * rates[i] * (4 + arrangement.moonlight) / 4096)
                next[i] -= e
                evaporated += e
            }
            var released: Int = 0
            for slot in arrangement.pods.indices {
                guard let pod = arrangement.pods[slot] else { continue }
                let amount: Int = grown[slot] ? level.podRules.grownRelease : level.podRules.release
                next[pod.row * level.columns + pod.column] += amount
                released += amount
            }
            return (next, released, evaporated)
        }

        /// The judge of a run from its fields (cycle 0 first), independently: per cycle `dried` (lowest-numbered
        /// sensitive colony below its floor) then `mold` (first floor cell in row-major order above M); after the run
        /// `unstable` (the colony with the shortest final in-band run, lowest index on a tie) when it is below K.
        static func invJudge(_ level: Level, fields: [[Int]]) -> Failure? {
            for cycle in 1..<fields.count {
                let field: [Int] = fields[cycle]
                for k in level.colonies.indices {
                    let colony: Colony = level.colonies[k]
                    if let floor = colony.survivalFloor,
                       field[colony.cell.row * level.columns + colony.cell.column] < floor {
                        return .dried(colony: k, cycle: cycle)
                    }
                }
                for i in field.indices where level.floorMask[i] && field[i] > level.moldBound {
                    return .mold(cell: Cell(row: i / level.columns, column: i % level.columns), cycle: cycle)
                }
            }
            var shortest: Int = 0
            var shortestRun: Int = Int.max
            for k in level.colonies.indices {
                let run: Int = invFinalRun(level, colony: level.colonies[k], fields: fields)
                if run < shortestRun {
                    shortest = k
                    shortestRun = run
                }
            }
            if shortestRun < level.required { return .unstable(colony: shortest, run: shortestRun) }
            return nil
        }

        /// The consecutive cycles ending at the last field at which `colony` is in band.
        static func invFinalRun(_ level: Level, colony: Colony, fields: [[Int]]) -> Int {
            let i: Int = colony.cell.row * level.columns + colony.cell.column
            var run: Int = 0
            var cycle: Int = fields.count - 1
            while cycle >= 1 && colony.low <= fields[cycle][i] && fields[cycle][i] <= colony.high {
                run += 1
                cycle -= 1
            }
            return run
        }

        /// The run of `level` with `arrangement` judged independently, with the kernel's report and fields.
        static func judged(_ level: Level,
                           _ arrangement: Arrangement) -> (report: Report, judge: Failure?, fields: [[Int]]) {
            let run: (report: Report, fields: [[Int]]) = Forest.run(level, arrangement: arrangement, keepFields: true)
            return (run.report, invJudge(level, fields: run.fields), run.fields)
        }

        /// Whether the words of `failure` name its colony or cell and its cycle (or run).
        static func wordsSay(_ level: Level, _ failure: Failure) -> Bool {
            let words: String = level.failureDescription(failure)
            switch failure {
            case .dried(let colony, let cycle):
                return words == "colony \(colony + 1) dries out at cycle \(cycle)"
            case .mold(let cell, let cycle):
                return words.hasPrefix("row \(cell.row), column \(cell.column) ") && words.hasSuffix(" cycle \(cycle)")
            case .unstable(let colony, let run):
                let cycles: String = run == 1 ? "1 cycle" : "\(run) cycles"
                return words.hasPrefix("colony \(colony + 1) ") && words.contains("only the last \(cycles),")
                    && words.hasSuffix("needs \(level.required)")
            }
        }
    }

    // MARK: INV-01 Time

    @Test func testMushroomWeatherTimeBoundary() throws {
        // Direct boundary: an isolated pod releasing 10 per whole cycle holds exactly 10·n after cycle n; a run that
        // does not fail keeps T + 1 fields and T ledger entries, each releasing 10.
        let rules: Rules = Rules(slots: 1, release: 10, grownRelease: 10, growthThreshold: 200_000)
        let level: Level = try Inv.hand(floor: [Inv.a, Inv.far], humidity: [Inv.far: 500],
                                        colonies: [Inv.steady(low: 500, high: 500)], podRules: rules, pods: [Inv.a])
        let run: (report: Report, fields: [[Int]]) = Forest.run(level, arrangement: level.start, keepFields: true)
        #expect(run.report.wins && run.report.cycles == 20)
        #expect(run.fields.count == 21 && run.report.ledger.count == 20)
        for cycle in 0...20 {
            #expect(run.fields[cycle][level.index(of: Inv.a)] == 10 * cycle)
            #expect(run.fields[cycle][level.index(of: Inv.far)] == 500)
        }
        for (i, entry) in run.report.ledger.enumerated() {
            #expect(entry == Ledger(cycle: i + 1, before: 500 + 10 * i, released: 10, evaporated: 0,
                                    after: 510 + 10 * i))
        }
        // Lengths T − 1, T and T + 1 at both range bounds.
        for length in [19, 20, 21, 199, 200, 201] {
            let refused: Refusal? = Inv.refusal { () throws(Refusal) in
                _ = try Inv.hand(floor: [Inv.a, Inv.far], humidity: [Inv.far: 500], colonies: [Inv.steady()],
                                 podRules: rules, pods: [Inv.a], length: length)
            }
            let inRange: Bool = length >= 20 && length <= 200
            #expect(refused == (inRange ? nil : .level("length")), "length \(length)")
        }
        // A longer run of the same level repeats the shorter one's fields cycle for cycle.
        let long: Level = try Inv.hand(floor: [Inv.a, Inv.b, Inv.far], humidity: [Inv.a: 640, Inv.far: 500],
                                       rates: [Inv.a: 30], colonies: [Inv.steady()], pods: [Inv.b], length: 21)
        let short: Level = try Inv.copy(long, length: 20, refusingAWin: false)
        let longFields: [[Int]] = Forest.run(long, arrangement: long.start, keepFields: true).fields
        let shortFields: [[Int]] = Forest.run(short, arrangement: short.start, keepFields: true).fields
        #expect(longFields.count == 22 && shortFields.count == 21)
        for cycle in shortFields.indices { #expect(longFields[cycle] == shortFields[cycle]) }
        // Pauses and reads between the same actions change nothing; an idle play spends nothing and never fails.
        let fixture: Fixture = Inv.fixtures[0]
        let direct: Play = try Inv.played(fixture.level, Array(fixture.actions.dropLast()))
        var slow: Play = try Inv.playing(fixture.level)
        for action in fixture.actions.dropLast() {
            for _ in 0..<3 {
                try slow.handle(.pause)
                _ = fixture.level.progressDescription(report: slow.report, arrangement: slow.arrangement,
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

        // Seeded neighbours: random lengths in range and their neighbours on fixture levels; every run counts whole
        // cycles 1 … T (failures during the run name the last cycle run, runs that complete keep T + 1 fields).
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var checked: Int = 0
        for fixture in Inv.fixtures.prefix(20) {
            let length: Int = random.int(20...200)
            for candidate in [length - 1, length, length + 1] {
                let refused: Refusal? = Inv.refusal { () throws(Refusal) in
                    _ = try Inv.copy(fixture.level, length: candidate, refusingAWin: false)
                }
                #expect(refused == (Level.lengths.contains(candidate) ? nil : .level("length")))
            }
            let level: Level = try Inv.copy(fixture.level, length: length, refusingAWin: false)
            let arrangement: Arrangement = Inv.randomArrangement(&random, level)
            let run: (report: Report, fields: [[Int]]) = Forest.run(level, arrangement: arrangement,
                                                                    keepFields: true)
            #expect(run.fields.count == run.report.cycles + 1 && run.report.ledger.count == run.report.cycles)
            #expect(run.report.cycles >= 1 && run.report.cycles <= length)
            switch run.report.failure {
            case .dried(_, let cycle), .mold(_, let cycle): #expect(cycle == run.report.cycles)
            default: #expect(run.report.cycles == length)
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

    @Test func testMushroomWeatherInputbudgetBoundary() throws {
        // Direct boundary: a budget of 2 on the two-slot hand level; two placements are accepted, the third action is
        // refused `budget` without any change, the run is still accepted.
        let level: Level = try Inv.budgetLevel(budget: 2)
        var loading: Play = Play(level: level)
        #expect(Inv.refusal { () throws(Refusal) in try loading.apply(.run, expecting: loading.fingerprint) }
            == .stage)
        var play: Play = try Inv.playing(level)
        #expect(play.actionsLeft == 2)
        try play.apply(.place(slot: 0, cell: Inv.a), expecting: play.fingerprint)
        #expect(play.actionsLeft == 1 && play.actionsSpent == 1)
        try play.apply(.place(slot: 1, cell: Inv.b), expecting: play.fingerprint)
        #expect(play.actionsLeft == 0 && play.actionsSpent == 2)
        let spent: Play = play
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.remove(slot: 0), expecting: play.fingerprint) }
            == .budget)
        #expect(Inv.refusal { () throws(Refusal) in
            try play.apply(.moonlight(level: 1), expecting: play.fingerprint)
        } == .budget)
        // Action before budget, stale before action; refusals spend nothing and change nothing.
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.remove(slot: 2), expecting: play.fingerprint)
        }))
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.vent(index: 0, open: true), expecting: play.fingerprint)
        }))
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.moonlight(level: 0), expecting: play.fingerprint)
        }))
        #expect(Inv.refusal { () throws(Refusal) in
            try play.apply(.remove(slot: 2), expecting: Inv.staleFingerprint)
        } == .stale)
        #expect(play == spent && play.records.count == spent.records.count)
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.actionsSpent == 2 && play.stage == .failed)
        // Budgets outside 1 … 12 are refused.
        for budget in [0, 25] {
            #expect(Inv.refusal { () throws(Refusal) in _ = try Inv.budgetLevel(budget: budget) } == .level("budget"))
        }

        // Seeded neighbours: budgets b − 1, b and b + 1 of each fixture accept exactly that many moonlight changes
        // (to a seeded other level and back), then refuse `budget` and still accept the run.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var levels: Int = 0
        for fixture in Inv.fixtures.prefix(16) {
            let home: Int = fixture.level.start.moonlight
            let away: Int = (home + random.int(1...3)) % 4
            for budget in [fixture.level.budget - 1, fixture.level.budget, fixture.level.budget + 1] {
                guard Level.budgets.contains(budget) else { continue }
                let level: Level = try Inv.copy(fixture.level, budget: budget, refusingAWin: true)
                var walk: Play = try Inv.playing(level)
                var accepted: Int = 0
                var refusal: Refusal? = nil
                for index in 0..<(budget + 2) {
                    let action: Action = .moonlight(level: index % 2 == 0 ? away : home)
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
                try walk.apply(.run, expecting: walk.fingerprint)
                #expect(walk.actionsSpent == budget && (walk.stage == .won || walk.stage == .failed))
                levels += 1
            }
        }
        #expect(levels >= 32)
    }

    // MARK: INV-03 Goal

    @Test func testMushroomWeatherGoalBoundary() throws {
        // Direct boundary: an isolated colony drying from 5000 at rate 200 (moonlight 0) enters a band 0 … h₁₆ at
        // cycle 16, so its final run is 5: K = 5 wins, K = 6 fails `unstable` with run 5; a band one unit lower
        // (0 … h₁₆ − 1) enters at cycle 17 and fails with run 4.
        let h: [Int] = Inv.invDecay(5_000, rate: 200, moonlight: 0, cycles: 20)
        #expect(h[15] > h[16] && h[16] - 1 >= h[17])
        func decaying(high: Int, required: Int, second: Colony? = nil) throws(Refusal) -> Report {
            var colonies: [Colony] = [Colony(cell: Inv.a, low: 0, high: high)]
            if let second { colonies.append(second) }
            let level: Level = try Inv.hand(floor: [Inv.a, Inv.far], humidity: [Inv.a: 5_000, Inv.far: 500],
                                            rates: [Inv.a: 200], colonies: colonies, length: 20, required: required)
            return level.startReport
        }
        let atK: Report = try decaying(high: h[16], required: 5)
        #expect(atK.wins && atK.colonies[0].finalRun == 5)
        #expect(try decaying(high: h[16], required: 6).failure == .unstable(colony: 0, run: 5))
        #expect(try decaying(high: h[16] - 1, required: 5).failure == .unstable(colony: 0, run: 4))
        // Band edges are inside: a steady colony at 500 wins with band 500 … 500, fails `unstable` with run 0 one
        // unit off either edge; every colony counts (the second one off by one names colony 2).
        #expect(try decaying(high: h[16], required: 5, second: Inv.steady(low: 500, high: 500)).wins)
        #expect(try decaying(high: h[16], required: 5, second: Inv.steady(low: 501, high: 600)).failure
            == .unstable(colony: 1, run: 0))
        #expect(try decaying(high: h[16], required: 5, second: Inv.steady(low: 400, high: 499)).failure
            == .unstable(colony: 1, run: 0))
        // The known fixture actions win.
        for fixture in Inv.fixtures.prefix(10) {
            let won: Play = try Inv.played(fixture.level, fixture.actions)
            #expect(won.stage == .won && won.failure == nil)
        }

        // Seeded neighbours: on each fixture the winning arrangement wins; colony 0's band set exactly to its range
        // over the last K cycles still wins, one unit inside either edge fails `unstable` for colony 0 with its
        // shorter run; K one above the shortest final run fails; random arrangements are judged exactly as the
        // independent judge, and win only with every condition met.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var edgeWins: Int = 0
        var edgeFails: Int = 0
        var requiredCases: Int = 0
        var outcomes: [String: Int] = [:]
        for fixture in Inv.fixtures.prefix(24) {
            let level: Level = fixture.level
            let winning: (report: Report, judge: Failure?, fields: [[Int]]) = Inv.judged(level, fixture.winning)
            #expect(winning.report.wins && winning.judge == nil)
            let first: Colony = level.colonies[0]
            let i: Int = level.index(of: first.cell)
            var lowest: Int = Int.max
            var highest: Int = Int.min
            for cycle in (level.length - level.required + 1)...level.length {
                lowest = min(lowest, winning.fields[cycle][i])
                highest = max(highest, winning.fields[cycle][i])
            }
            let tight: [Colony] = Inv.replacingFirst(level.colonies, low: lowest, high: highest,
                                                     floor: first.survivalFloor)
            let exact: Level = try Inv.copy(level, colonies: tight, refusingAWin: false)
            #expect(Forest.report(exact, arrangement: fixture.winning).wins)
            edgeWins += 1
            var narrowed: [[Colony]] = []
            if lowest + 1 <= highest {
                narrowed.append(Inv.replacingFirst(level.colonies, low: lowest + 1, high: highest,
                                                   floor: first.survivalFloor))
                narrowed.append(Inv.replacingFirst(level.colonies, low: lowest, high: highest - 1,
                                                   floor: first.survivalFloor))
            }
            for colonies in narrowed {
                let off: Level = try Inv.copy(level, colonies: colonies, refusingAWin: false)
                let run: Int = Inv.invFinalRun(off, colony: off.colonies[0], fields: winning.fields)
                #expect(run < level.required)
                #expect(Forest.report(off, arrangement: fixture.winning).failure == .unstable(colony: 0, run: run))
                edgeFails += 1
            }
            var shortest: Int = Int.max
            for runs in winning.report.colonies { shortest = min(shortest, runs.finalRun) }
            if shortest + 1 <= level.length {
                let longer: Level = try Inv.copy(level, required: shortest + 1, refusingAWin: false)
                #expect(Forest.report(longer, arrangement: fixture.winning).failure?.code == "unstable")
                if shortest >= Level.minimumRequired {
                    let atRun: Level = try Inv.copy(level, required: shortest, refusingAWin: false)
                    #expect(Forest.report(atRun, arrangement: fixture.winning).wins)
                }
                requiredCases += 1
            }
            for _ in 0..<4 {
                let arrangement: Arrangement = Inv.randomArrangement(&random, level)
                let judged: (report: Report, judge: Failure?, fields: [[Int]]) = Inv.judged(level, arrangement)
                #expect(judged.report.failure == judged.judge)
                var allMet: Bool = judged.fields.count == level.length + 1
                for colony in level.colonies {
                    if Inv.invFinalRun(level, colony: colony, fields: judged.fields) < level.required { allMet = false }
                    if let floor = colony.survivalFloor {
                        for field in judged.fields.dropFirst() where field[level.index(of: colony.cell)] < floor {
                            allMet = false
                        }
                    }
                }
                for field in judged.fields.dropFirst() {
                    for index in field.indices where level.floorMask[index] && field[index] > level.moldBound {
                        allMet = false
                    }
                }
                #expect(judged.report.wins == allMet)
                outcomes[judged.report.failure?.code ?? "win", default: 0] += 1
            }
        }
        #expect(edgeWins == 24 && edgeFails >= 24 && requiredCases == 24)
        #expect(outcomes.values.reduce(0, +) == 96)
    }

    // MARK: INV-04 Repeatability

    @Test func testMushroomWeatherRepeatabilityBoundary() throws {
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
            #expect(again.arrangement == a.play.arrangement && again.report == a.play.report)
            traces += 1
        }
        #expect(traces == 24)
    }

    // MARK: INV-05 Undo

    @Test func testMushroomWeatherUndoBoundary() throws {
        // Direct boundary: on the two-slot hand level a placement and a failed run are undone to the exact prior
        // fingerprints (the failed run returns to playing with the arrangement before it); redo restores the later
        // ones.
        let level: Level = try Inv.budgetLevel(budget: 3)
        var play: Play = try Inv.playing(level)
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in try play.undo() }))
        let start: String = play.fingerprint
        try play.apply(.place(slot: 0, cell: Inv.a), expecting: play.fingerprint)
        #expect(play.report.failure == .unstable(colony: 0, run: 0))
        let placed: String = play.fingerprint
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.stage == .failed && play.failure == .unstable(colony: 0, run: 0))
        let failed: String = play.fingerprint
        try play.undo()
        #expect(play.fingerprint == placed && play.stage == .playing && play.failure == nil)
        #expect(play.arrangement.pods == [Inv.a, nil] && play.actionsSpent == 1)
        try play.undo()
        #expect(play.fingerprint == start && play.actionsSpent == 0 && play.arrangement == level.start)
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
        try play.apply(.place(slot: 1, cell: Inv.b), expecting: play.fingerprint)
        #expect(!play.canRedo && Inv.isAction(Inv.refusal { () throws(Refusal) in try play.redo() }))
        // A won run is final.
        let fixture: Fixture = Inv.fixtures[0]
        var won: Play = try Inv.played(fixture.level, fixture.actions)
        #expect(won.stage == .won)
        #expect(Inv.refusal { () throws(Refusal) in try won.undo() } == .stage)

        // Seeded neighbours: seeded walks of accepted placements, removals, vents, moonlight and a run are undone step
        // by step to the exact earlier fingerprints, then redone to the exact later ones.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var walks: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            var walk: Play = try Inv.playing(fixture.level)
            var history: [String] = [walk.fingerprint]
            for _ in 0..<12 {
                let action: Action = random.int(0...6) == 0 ? .run : Inv.randomAction(&random, fixture.level)
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

    @Test func testMushroomWeatherFailurehonestyBoundary() throws {
        // Direct boundary: a sensitive colony at 1000 under rate 200 and moonlight 3 holds 659 after cycle 1 and 434
        // after cycle 2: a floor of 660 dries at cycle 1, one unit lower (659) at cycle 2; the words say it; the
        // arrangement and actions spent stay as they were.
        let h: [Int] = Inv.invDecay(1_000, rate: 200, moonlight: 3, cycles: 2)
        #expect(h == [1_000, 659, 434])
        func dry(floor: Int) throws(Refusal) -> Level {
            try Inv.hand(floor: [Inv.a, Inv.far], humidity: [Inv.a: 1_000, Inv.far: 500], rates: [Inv.a: 200],
                         colonies: [Colony(cell: Inv.a, low: floor, high: 1_000, survivalFloor: floor), Inv.steady()],
                         moonlight: 3, refusingAWin: true)
        }
        var dryPlay: Play = try Inv.playing(try dry(floor: 660))
        try dryPlay.apply(.run, expecting: dryPlay.fingerprint)
        #expect(dryPlay.stage == .failed && dryPlay.failure == .dried(colony: 0, cycle: 1))
        #expect(dryPlay.level.failureDescription(.dried(colony: 0, cycle: 1)) == "colony 1 dries out at cycle 1")
        #expect(dryPlay.arrangement == dryPlay.level.start && dryPlay.actionsSpent == 0)
        #expect(try dry(floor: 659).startReport.failure == .dried(colony: 0, cycle: 2))
        // Mold: two isolated pods at 991 releasing 10 exceed M = 1000 at cycle 1, named by the first cell in row-major
        // order (slot 1's cell a, before slot 0's cell c); one unit more (M = 1001) moves it to cycle 2.
        func moldy(_ bound: Int) throws(Refusal) -> Level {
            try Inv.hand(floor: [Inv.a, Inv.c, Inv.far], humidity: [Inv.a: 991, Inv.c: 991, Inv.far: 500],
                         colonies: [Inv.steady()],
                         podRules: Rules(slots: 2, release: 10, grownRelease: 10, growthThreshold: 200_000),
                         pods: [Inv.c, Inv.a], moldBound: bound, refusingAWin: true)
        }
        var moldPlay: Play = try Inv.playing(try moldy(1_000))
        try moldPlay.apply(.run, expecting: moldPlay.fingerprint)
        #expect(moldPlay.failure == .mold(cell: Inv.a, cycle: 1))
        #expect(moldPlay.level.failureDescription(.mold(cell: Inv.a, cycle: 1))
            == "row 0, column 0 turns to mold at cycle 1")
        #expect(try moldy(1_001).startReport.failure == .mold(cell: Inv.a, cycle: 2))
        // Dried is judged before mold in the same cycle, and the lowest-numbered sensitive colony is named.
        let both: Level = try Inv.hand(
            floor: [Inv.a, Inv.c, Inv.d, Inv.far], humidity: [Inv.a: 1_000, Inv.c: 991, Inv.d: 1_000, Inv.far: 500],
            rates: [Inv.a: 200, Inv.d: 200],
            colonies: [Inv.steady(), Colony(cell: Inv.d, low: 660, high: 1_000, survivalFloor: 660),
                       Colony(cell: Inv.a, low: 660, high: 1_000, survivalFloor: 660)],
            podRules: Rules(slots: 1, release: 10, grownRelease: 10, growthThreshold: 200_000), pods: [Inv.c],
            moonlight: 3, moldBound: 1_000, refusingAWin: true)
        #expect(both.startReport.failure == .dried(colony: 1, cycle: 1))
        // Unstable names the colony and its run.
        let unstable: Level = try Inv.budgetLevel(budget: 3)
        var unstablePlay: Play = try Inv.playing(unstable)
        try unstablePlay.apply(.run, expecting: unstablePlay.fingerprint)
        #expect(unstablePlay.failure == .unstable(colony: 0, run: 0))
        #expect(unstable.failureDescription(.unstable(colony: 0, run: 0))
            == "colony 1 is in band for only the last 0 cycles, needs 5")
        for failed in [dryPlay, moldPlay, unstablePlay] {
            if let failure = failed.failure { #expect(Inv.wordsSay(failed.level, failure)) }
            #expect(failed.failure == failed.report.failure)
            #expect(failed.failure == Inv.judged(failed.level, failed.arrangement).judge)
        }
        // Refusals carry their codes.
        let codes: [Refusal] = [.level("x"), .action("x"), .budget, .stage, .stale, .newerSchema(2), .malformed("x")]
        for code in codes { #expect(code.reasonCode.hasPrefix("r02-g20.")) }

        // Seeded neighbours: each fixture run from its start (never a win), and after one random action, fails with
        // the independent judge's failure; the failing cycle lies in 1 … T; the words name it; nothing is fixed.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var failures: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            let level: Level = fixture.level
            var direct: Play = try Inv.playing(level)
            try direct.apply(.run, expecting: direct.fingerprint)
            #expect(direct.stage == .failed)
            #expect(direct.failure == Inv.judged(level, level.start).judge && direct.failure != nil)
            #expect(direct.arrangement == level.start && direct.actionsSpent == 0)
            var moved: Play = try Inv.playing(level)
            try? moved.apply(Inv.randomAction(&random, level), expecting: moved.fingerprint)
            let before: Arrangement = moved.arrangement
            let spentBefore: Int = moved.actionsSpent
            try moved.apply(.run, expecting: moved.fingerprint)
            let judge: Failure? = Inv.judged(level, before).judge
            #expect(moved.failure == judge && moved.arrangement == before && moved.actionsSpent == spentBefore)
            for play in [direct, moved] {
                guard let failure = play.failure else { continue }
                #expect(Inv.wordsSay(level, failure))
                switch failure {
                case .dried(let colony, let cycle):
                    #expect(level.colonies[colony].survivalFloor != nil && cycle >= 1 && cycle <= level.length)
                case .mold(let cell, let cycle):
                    #expect(level.isFloor(cell) && cycle >= 1 && cycle <= level.length)
                case .unstable(let colony, let run):
                    #expect(colony >= 0 && colony < level.colonies.count && run < level.required)
                }
                failures += 1
            }
        }
        #expect(failures >= 24)
        // Seeded survival floors ± 1: a decaying sensitive colony dries at the first cycle below its floor.
        var floorCases: Int = 0
        for _ in 0..<16 {
            let start: Int = random.int(1_000...5_000)
            let rate: Int = random.int(50...200)
            let moonlight: Int = random.int(0...3)
            let decay: [Int] = Inv.invDecay(start, rate: rate, moonlight: moonlight, cycles: 20)
            let pivot: Int = decay[random.int(1...10)]
            for floor in [pivot - 1, pivot, pivot + 1] where floor <= start {
                let level: Level = try Inv.hand(
                    floor: [Inv.a, Inv.far], humidity: [Inv.a: start, Inv.far: 500], rates: [Inv.a: rate],
                    colonies: [Colony(cell: Inv.a, low: floor, high: 10_000, survivalFloor: floor), Inv.steady()],
                    moonlight: moonlight)
                var expected: Failure? = nil
                for cycle in 1...20 where expected == nil && decay[cycle] < floor {
                    expected = .dried(colony: 0, cycle: cycle)
                }
                #expect(level.startReport.failure == expected, "start \(start) rate \(rate) floor \(floor)")
                floorCases += 1
            }
        }
        // Seeded mold bounds ± 1: an isolated pod from h₀ releasing r turns to mold at the first n with h₀ + n·r > M.
        var moldCases: Int = 0
        for _ in 0..<16 {
            let start: Int = random.int(500...990)
            let release: Int = random.int(10...40)
            let bound: Int = random.int(1_000...1_500)
            for candidate in [bound - 1, bound, bound + 1] where Level.moldBounds.contains(candidate) {
                let level: Level = try Inv.hand(
                    floor: [Inv.a, Inv.far], humidity: [Inv.a: start, Inv.far: 500], colonies: [Inv.steady()],
                    podRules: Rules(slots: 1, release: release, grownRelease: release, growthThreshold: 200_000),
                    pods: [Inv.a], moldBound: candidate, length: 120)
                var cycle: Int = 1
                while start + cycle * release <= candidate { cycle += 1 }
                #expect(level.startReport.failure == .mold(cell: Inv.a, cycle: cycle))
                moldCases += 1
            }
        }
        #expect(floorCases == 48 && moldCases >= 46)
    }

    // MARK: INV-08 Stability

    @Test func testMushroomWeatherStabilityBoundary() throws {
        // Direct boundary: the extreme weather (diffusion 12, every rate 200, moonlight 3, release 40 and grown
        // release 80 from a threshold of 100) and a uniform floor at M = 10000 with nothing moving: every field,
        // ledger, growth and colony run equals the independent stepping; no humidity is negative.
        let fixture: Fixture = Inv.fixtures[0]
        var allRates: [Int] = []
        for index in 0..<(fixture.level.rows * fixture.level.columns) {
            allRates.append(fixture.level.floorMask[index] ? 200 : 0)
        }
        var openVents: [Vent] = []
        for vent in fixture.level.vents { openVents.append(Vent(cell: vent.cell, openRate: 200, closedRate: 200)) }
        let extreme: Level = try Inv.copy(fixture.level, diffusion: 12, rates: allRates, vents: openVents,
                                          podRules: Rules(slots: fixture.level.podRules.slots, release: 40,
                                                          grownRelease: 80, growthThreshold: 100),
                                          moldBound: 10_000, refusingAWin: false)
        var full: [Cell?] = []
        var used: Set<Cell> = extreme.colonyCells
        for cell in Inv.floorCells(extreme) where full.count < extreme.podRules.slots && !used.contains(cell) {
            full.append(cell)
            used.insert(cell)
        }
        let strong: Arrangement = Arrangement(pods: full, ventsOpen: extreme.start.ventsOpen, moonlight: 3)
        var uniform: [Int] = []
        for index in 0..<(fixture.level.rows * fixture.level.columns) {
            uniform.append(fixture.level.floorMask[index] ? 10_000 : 0)
        }
        let noRates: [Int] = Array(repeating: 0, count: uniform.count)
        let still: Level = try Inv.copy(fixture.level, humidity: uniform, rates: noRates, vents: [], moldBound: 10_000,
                                        start: Arrangement(pods: Array(repeating: nil,
                                                                       count: fixture.level.podRules.slots),
                                                           ventsOpen: [], moonlight: 0),
                                        refusingAWin: false)
        var runs: Int = 0
        runs += check(extreme, strong)
        let stillRun: (report: Report, fields: [[Int]]) = Forest.run(still, arrangement: still.start, keepFields: true)
        #expect(stillRun.report.cycles == still.length && stillRun.report.humidity == uniform)
        runs += check(still, still.start)

        // Seeded neighbours: fixtures with random arrangements, and with their diffusion, rates and releases at the
        // range bounds.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures.prefix(30) {
            for _ in 0..<3 {
                runs += check(fixture.level, Inv.randomArrangement(&random, fixture.level))
            }
            var rates: [Int] = []
            for index in 0..<(fixture.level.rows * fixture.level.columns) {
                rates.append(fixture.level.floorMask[index] ? (random.int(0...1) == 0 ? 0 : 200) : 0)
            }
            let release: Int = random.int(0...1) == 0 ? 1 : 40
            let bounds: Level = try Inv.copy(fixture.level, diffusion: random.int(0...1) == 0 ? 1 : 12, rates: rates,
                                             podRules: Rules(slots: fixture.level.podRules.slots, release: release,
                                                             grownRelease: 80, growthThreshold: 100),
                                             moldBound: 10_000, refusingAWin: false)
            runs += check(bounds, Inv.randomArrangement(&random, bounds))
        }
        #expect(runs == 122)
    }

    /// Checks one run cycle by cycle against an independent stepping of the same weather; returns 1 (one run checked).
    private func check(_ level: Level, _ arrangement: Arrangement) -> Int {
        let run: (report: Report, fields: [[Int]]) = Forest.run(level, arrangement: arrangement, keepFields: true)
        let report: Report = run.report
        let slots: Int = arrangement.pods.count
        var h: [Int] = level.humidity
        var grown: [Bool] = Array(repeating: false, count: slots)
        var integrals: [Int] = Array(repeating: 0, count: slots)
        var grownAt: [Int?] = Array(repeating: nil, count: slots)
        var current: [Int] = Array(repeating: 0, count: level.colonies.count)
        var longest: [Int] = Array(repeating: 0, count: level.colonies.count)
        var firstOut: [Int?] = Array(repeating: nil, count: level.colonies.count)
        #expect(run.fields.count == report.cycles + 1 && report.ledger.count == report.cycles)
        #expect(run.fields.first == level.humidity)
        for cycle in 1..<run.fields.count {
            var before: Int = 0
            for value in h { before += value }
            let step: (h: [Int], released: Int, evaporated: Int) = Inv.invCycle(h, level, arrangement, grown: grown)
            h = step.h
            var after: Int = 0
            for (i, value) in h.enumerated() {
                #expect(value >= 0)
                if !level.floorMask[i] { #expect(value == 0) }
                after += value
            }
            #expect(h == run.fields[cycle], "cycle \(cycle)")
            let entry: Ledger = report.ledger[cycle - 1]
            #expect(entry == Ledger(cycle: cycle, before: before, released: step.released,
                                    evaporated: step.evaporated, after: after))
            #expect(entry.balances && after == before + step.released - step.evaporated)
            for slot in 0..<slots {
                guard let pod = arrangement.pods[slot] else { continue }
                integrals[slot] += h[level.index(of: pod)]
                if !grown[slot] && integrals[slot] >= level.podRules.growthThreshold {
                    grown[slot] = true
                    grownAt[slot] = cycle
                }
            }
            for k in level.colonies.indices {
                if level.colonies[k].isInBand(h[level.index(of: level.colonies[k].cell)]) {
                    current[k] += 1
                    longest[k] = max(longest[k], current[k])
                } else {
                    current[k] = 0
                    if firstOut[k] == nil { firstOut[k] = cycle }
                }
            }
        }
        #expect(report.humidity == h && report.grownAt == grownAt)
        var expectedRuns: [Runs] = []
        for k in level.colonies.indices {
            expectedRuns.append(Runs(finalRun: current[k], longestRun: longest[k], firstOutOfBand: firstOut[k]))
        }
        #expect(report.colonies == expectedRuns)
        #expect(report.failure == Inv.invJudge(level, fields: run.fields))
        return 1
    }

    // MARK: INV-09 Save

    @Test func testMushroomWeatherSaveBoundary() throws {
        // Direct boundary: the hand level round-trips byte for byte; every one-byte edit and every truncation of its
        // stored form is refused; a newer schema and an edited fingerprint are refused with their reasons.
        let level: Level = try Inv.budgetLevel(budget: 3)
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

    @Test func testMushroomWeatherRendererpurityBoundary() throws {
        // Direct boundary: the report is the forest's pure function of the level and the arrangement; computing it
        // twice, with the fields kept, or after reading words, gives equal reports; the play is a value type; the
        // report holds only the truth metric.
        let fixture: Fixture = Inv.fixtures[0]
        let level: Level = fixture.level
        var play: Play = try Inv.playing(level)
        try play.apply(fixture.actions[0], expecting: play.fingerprint)
        let arrangement: Arrangement = play.arrangement
        #expect(play.report == Forest.report(level, arrangement: arrangement))
        #expect(Forest.report(level, arrangement: arrangement) == Forest.report(level, arrangement: arrangement))
        let kept: (report: Report, fields: [[Int]]) = Forest.run(level, arrangement: arrangement, keepFields: true)
        let again: (report: Report, fields: [[Int]]) = Forest.run(level, arrangement: arrangement, keepFields: true)
        #expect(kept.report == play.report && kept.fields == again.fields && kept.fields.last == kept.report.humidity)
        let copy: Play = play
        let words: String = level.progressDescription(report: play.report, arrangement: play.arrangement,
                                                      actionsLeft: play.actionsLeft)
        #expect(words == level.progressDescription(report: play.report, arrangement: play.arrangement,
                                                   actionsLeft: play.actionsLeft))
        for slot in play.arrangement.pods.indices {
            _ = level.podDescription(slot, cell: play.arrangement.pods[slot], grownAt: play.report.grownAt[slot])
        }
        for index in level.vents.indices { _ = level.ventDescription(index, open: play.arrangement.ventsOpen[index]) }
        for index in level.colonies.indices { _ = level.colonyDescription(index, report: play.report) }
        for entry in play.report.ledger { _ = Level.ledgerDescription(entry) }
        if let failure = play.report.failure { _ = level.failureDescription(failure) }
        #expect(play == copy && play.report == Forest.report(level, arrangement: arrangement))
        var changed: Play = copy
        try changed.handle(.pause)
        #expect(play == copy && changed != copy)
        let labels: [String] = Mirror(reflecting: play.report).children.compactMap { $0.label }
        #expect(Set(labels) == ["cycles", "humidity", "ledger", "grownAt", "colonies", "failure"])
        // Swapping two pods' slots only permutes their growth.
        let swapped: Arrangement = Arrangement(pods: Array(fixture.winning.pods.reversed()),
                                               ventsOpen: fixture.winning.ventsOpen,
                                               moonlight: fixture.winning.moonlight)
        let straight: Report = Forest.report(level, arrangement: fixture.winning)
        let reversed: Report = Forest.report(level, arrangement: swapped)
        #expect(straight.humidity == reversed.humidity && straight.ledger == reversed.ledger)
        #expect(straight.colonies == reversed.colonies && straight.failure == reversed.failure)
        #expect(straight.grownAt == Array(reversed.grownAt.reversed()))
        // The report never depends on the id, seed, difficulty, budget or tutorial.
        let others: [Level] = [try Inv.copy(level, id: "inv-renamed", refusingAWin: false),
                               try Inv.copy(level, seed: 99, refusingAWin: false),
                               try Inv.copy(level, difficulty: 5, refusingAWin: false),
                               try Inv.copy(level, budget: 12, refusingAWin: false),
                               try Inv.copy(level, tutorial: true, refusingAWin: false)]
        for other in others {
            #expect(Forest.report(other, arrangement: arrangement) == Forest.report(level, arrangement: arrangement))
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

        // Seeded neighbours: along seeded traces the play's report is the pure function of the level and its
        // arrangement, reads of fields and words change nothing, and a renamed level gives the same reports and
        // outcomes.
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
                #expect(a.report == Forest.report(fixture.level, arrangement: a.arrangement))
                #expect(a.report == b.report && a.arrangement == b.arrangement && a.stage == b.stage)
                #expect(a.failure == b.failure && a.actionsLeft == b.actionsLeft)
                let before: Play = a
                _ = Forest.run(fixture.level, arrangement: a.arrangement, keepFields: true)
                _ = fixture.level.progressDescription(report: a.report, arrangement: a.arrangement,
                                                      actionsLeft: a.actionsLeft)
                for index in fixture.level.colonies.indices {
                    _ = fixture.level.colonyDescription(index, report: a.report)
                }
                #expect(a == before)
            }
        }
    }
}
