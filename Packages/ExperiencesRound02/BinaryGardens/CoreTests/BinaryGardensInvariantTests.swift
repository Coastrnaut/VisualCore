// BinaryGardensInvariantTests — feature 501 (R02-G21-01) T-R02G2101-006 (FR-R02G2101-012; the source's invariants
// R2-G21-INV-01 … 05 and INV-07 … 10 on Binary Gardens), modelled on MushroomWeatherInvariantTests (feature 491).
// Each named test gives a direct boundary example and a seeded check of neighbouring inputs (seed 2,506: fixtures drawn
// from it, random arrangements and traces, tolerances E − 1, E and E + 1, budgets ± 1, a flux bound and a bloom bound
// one milliflux either side, a window one tick either side, a byte of a stored level changed or the form truncated).
// How each invariant maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G21-02; INV-11 is
// superseded by the free tier):
// - INV-01 Time: no rule reads a clock; time is the 48 ticks of one cycle, and the judge's walk never passes tick
//   48 + E (at most 60); a report holds exactly 48 positions per body and 48 fluxes per world; tolerances −1 and 13 are
//   refused, 0 and 12 accepted; pauses and reads between actions change nothing; the kernel sources hold no clock, time
//   interval, floating-point value or run-time trigonometry.
// - INV-02 Input budget: an arrangement action spends exactly 1 action, the run none; the action that spends the last
//   one is accepted and the next refused `budget` while the run is still accepted; action before budget; stale before
//   action; refusals change nothing; budgets 0 and 25 are refused, b − 1, b and b + 1 give exactly that many actions.
// - INV-03 Goal: a run wins exactly when no lethal run exceeds the tolerance, every world's cyclic comfortable window
//   reaches W and every integral lies in its bloom band (judged by the independent reference); a comfortable bound one
//   milliflux inside the extreme flux of the window, or W one tick above the window, fails `unstable`; the known fixture
//   actions win.
// - INV-04 Repeatability: the same trace twice gives identical fingerprints and outcome; replay reproduces them; a
//   trace with a record removed, or the trace of another level, is refused `malformed`.
// - INV-05 Undo: undo restores the exact prior fingerprint (including from failed, which returns to playing with the
//   arrangement before the run); redo the later one; a new action clears redo; a won run is final; nothing is undone
//   while paused.
// - INV-07 Failure honesty: a failed run names the reason, the world and the walk tick or measure of the first failure
//   equal to the independent judge; a tolerance one tick either side moves or removes the lethal failure exactly; the
//   arrangement and actions spent stay as they were; the words of `failureDescription` say it.
// - INV-08 Stability: an independent computation reproduces every position, share, flux and band; every body is back at
//   its start after 48 ticks; every share lies in 0 … 64 000, every flux is the sum of its shares and every integral at
//   most 6 144 000, over seeded and extreme arrangements (largest luminosity, every clamp radius, a world through a star).
// - INV-09 Save: stored levels round-trip byte for byte (through `encoded`/`decode` and through Codable); every
//   one-byte edit and every truncation is refused; a stored record trace replays to the same play.
// - INV-10 Renderer purity: the report is a value derived only from the level and the arrangement (never of call order,
//   reads of words, the id, seed, difficulty, budget or tutorial; swapping the two stars only swaps their shares and
//   positions); the report type holds only the truth metric; the play is a value type; the kernel sources import only
//   Foundation, VisualCoreMath and VisualCoreSimulation.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden tokens are built by concatenation so
// that this file never holds the token sequence the repository's compliance scan matches.
// Feature 503 (R02-G21-03) T-R02G2103-002 (FR-R02G2103-009): the kernel scans read a fixed list of the kernel's ten
// files (feature 501's five and feature 502's five in `Core/Content`, read relative to `Core/`), so the presentation
// sources (snapshot, shaders with run-time trigonometry, geometry, adapter, scenarios) stay outside them.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BinaryGardensCore

@Suite struct BinaryGardensInvariantTests {
    typealias Play = BinaryGardensPlay
    typealias Level = BinaryGardensLevel
    typealias Action = BinaryGardensAction
    typealias Failure = BinaryGardensFailure
    typealias Report = BinaryGardensReport
    typealias Star = BinaryGardensStar
    typealias World = BinaryGardensWorld
    typealias Arrangement = BinaryGardensArrangement
    typealias Fixture = BinaryGardensFixture
    typealias Record = BinaryGardensRecord
    typealias Refusal = BinaryGardensError
    typealias Sky = BinaryGardensSky
    typealias Ref = BinaryGardensReference

    /// One step of a seeded trace.
    private enum Step {
        case act(Action)
        case undo
        case redo
        case pause
        case resume
    }

    /// The helpers, builders and checks of this file.
    private enum Inv {
        /// The invariant (neighbouring-input) seed.
        static let seed: UInt64 = 2_506

        /// A fingerprint that is never the current one.
        static let staleFingerprint: String = String(repeating: "0", count: 64)

        /// The fixtures of the invariant seed (computed once).
        static let fixtures: [Fixture] = Fixture.all(count: 40, seed: seed)

        /// A copy of `level` with some values changed (`refusingAWin` false lets a copy read any report).
        static func copy(_ level: Level, id: String? = nil, seed: UInt64? = nil, difficulty: Int? = nil,
                         stars: [Star]? = nil, worlds: [World]? = nil, lethalTolerance: Int? = nil,
                         budget: Int? = nil, tutorial: Bool? = nil,
                         refusingAWin: Bool) throws(Refusal) -> Level {
            try Level(id: id ?? level.id, seed: seed ?? level.seed, difficulty: difficulty ?? level.difficulty,
                      ringRadii: level.ringRadii, starSpeed: level.starSpeed,
                      luminosityLevels: level.luminosityLevels, stars: stars ?? level.stars, maxTilt: level.maxTilt,
                      startTilt: level.startTilt, minimumSeparation: level.minimumSeparation,
                      clampRadius: level.clampRadius, worlds: worlds ?? level.worlds,
                      lethalTolerance: lethalTolerance ?? level.lethalTolerance, budget: budget ?? level.budget,
                      tutorial: tutorial ?? level.tutorial, refusingAWin: refusingAWin)
        }

        /// The play's hand level (budget `budget`): every run fails `wilted`; the tilt toggles freely.
        static func budgetLevel(budget: Int) throws(Refusal) -> Level {
            try BinaryGardensPlayTests.hand(budget: budget)
        }

        /// A play of `level` after `begin` (and `dismissTutorial`).
        static func playing(_ level: Level) throws(Refusal) -> Play {
            var play = Play(level: level)
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            return play
        }

        /// A play of `level` after `actions`.
        static func played(_ level: Level, _ actions: [Action]) throws(Refusal) -> Play {
            var play: Play = try playing(level)
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
            return play
        }

        /// The refusal `body` throws, or nil.
        static func refusal(_ body: () throws(Refusal) -> Void) -> Refusal? {
            do {
                try body()
                return nil
            } catch {
                return error
            }
        }

        /// Whether `error` is a `.malformed` refusal.
        static func isMalformed(_ error: Refusal?) -> Bool {
            if case .malformed = error { return true }
            return false
        }

        /// A random well-formed arrangement of `level`.
        static func randomArrangement(_ random: inout SeededRandom, _ level: Level) -> Arrangement {
            BinaryGardensSkyTests.randomArrangement(&random, level)
        }

        /// A random seeded trace of `count` steps.
        static func randomSteps(_ level: Level, count: Int, random: inout SeededRandom) -> [Step] {
            var steps: [Step] = []
            for _ in 0..<count {
                switch random.int(0...9) {
                case 0: steps.append(.undo)
                case 1: steps.append(.redo)
                case 2: steps.append(.pause)
                case 3: steps.append(.resume)
                default: steps.append(.act(BinaryGardensPlayTests.randomAction(&random, level: level)))
                }
            }
            return steps
        }

        /// Plays `steps` on `level`, ignoring refusals; the fingerprint after every step.
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

        /// The kernel's source files, relative to `Core/`: feature 501's five and feature 502's five in `Content/`
        /// (the presentation files of feature 503 — the scene snapshot, shaders, geometry, adapter and scenarios — draw
        /// with floating point and run-time trigonometry and are not part of the kernel).
        static let kernelFiles: [String] = ["BinaryGardensError.swift", "BinaryGardensLevel.swift",
                                            "BinaryGardensPlay.swift", "BinaryGardensPuzzle.swift",
                                            "BinaryGardensSky.swift", "Content/BinaryGardensManifest.swift",
                                            "Content/BinaryGardensDifficulty.swift",
                                            "Content/BinaryGardensSolver.swift",
                                            "Content/BinaryGardensGenerator.swift",
                                            "Content/BinaryGardensWitness.swift"]

        /// The kernel sources in the Core directory next to this test directory.
        static func kernelSources() throws -> [(name: String, text: String)] {
            let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
            var sources: [(name: String, text: String)] = []
            for name in kernelFiles {
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

        /// Whether the independent reference judges `arrangement` in `level` exactly as the kernel.
        static func agrees(_ level: Level, _ arrangement: Arrangement) -> Bool {
            Sky.report(level, arrangement: arrangement).failure == Ref.run(level, arrangement).failure
        }
    }

    // MARK: INV-01 Time

    @Test func testBinaryGardensTimeBoundary() throws {
        // Direct boundary: a world lethal at every tick fails at walk tick E + 1 for every tolerance, and a world lethal
        // only at ticks 45 … 48 and 1 … 8 (a cyclic run of 12) fails with tolerance 11 at walk tick 56, the last ticks
        // of the walk; tolerance 12 survives the whole walk of 60 ticks.
        let w = World(radius: 10, phase: 0, speed: 0, lethalLow: 100, comfortLow: 200, comfortHigh: 300,
                      lethalHigh: 400, window: 1, bloomLow: 0, bloomHigh: 9_600_000)
        var always: [Int] = Array(repeating: 50, count: 48)
        for tolerance in 0...12 {
            let light: BinaryGardensWorldLight = BinaryGardensSkyTests.light(always, w)
            #expect(Sky.judge(worlds: [w], tolerance: tolerance, lights: [light])
                == .frozen(world: 0, tick: tolerance + 1))
        }
        always = Array(repeating: 250, count: 48)
        for tick in [45, 46, 47, 48, 1, 2, 3, 4, 5, 6, 7, 8] { always[tick - 1] = 450 }
        let wrap: BinaryGardensWorldLight = BinaryGardensSkyTests.light(always, w)
        #expect(wrap.longestLethalRun == 12)
        #expect(Sky.judge(worlds: [w], tolerance: 11, lights: [wrap]) == .scorched(world: 0, tick: 56))
        #expect(Sky.judge(worlds: [w], tolerance: 12, lights: [wrap]) == nil)
        // Tolerances −1 and 13 are refused, 0 and 12 accepted.
        let level: Level = Inv.fixtures[0].level
        #expect(Inv.refusal { () throws(Refusal) in _ = try Inv.copy(level, lethalTolerance: -1, refusingAWin: false) }
            == .level("lethal tolerance"))
        #expect(Inv.refusal { () throws(Refusal) in _ = try Inv.copy(level, lethalTolerance: 13, refusingAWin: false) }
            == .level("lethal tolerance"))
        #expect(Inv.refusal { () throws(Refusal) in _ = try Inv.copy(level, lethalTolerance: 0, refusingAWin: false) }
            == nil)
        #expect(Inv.refusal { () throws(Refusal) in _ = try Inv.copy(level, lethalTolerance: 12, refusingAWin: false) }
            == nil)
        // A report holds 48 ticks of every body and world; pauses and reads change nothing.
        let report: Report = level.startReport
        #expect(report.starPositions.count == 48 && report.worldPositions.count == 48)
        for light in report.worlds {
            #expect(light.flux.count == 48 && light.shares.count == 48 && light.bands.count == 48)
        }
        var play: Play = try Inv.playing(level)
        let before: Report = play.report
        try play.handle(.pause)
        _ = level.progressDescription(report: play.report, arrangement: play.arrangement, actionsLeft: play.actionsLeft)
        try play.handle(.resume)
        #expect(play.report == before)
        // The kernel sources hold no clock, time interval, floating point or run-time trigonometry.
        let forbidden: [String] = ["Da" + "te(", "Dispatch" + "Time", "CFAbsolute" + "Time", "Time" + "Interval",
                                   "Dou" + "ble", "Flo" + "at", "clo" + "ck", "si" + "n(", "co" + "s(", "sq" + "rt(",
                                   "Continuous" + "Clock", "process" + "Info"]
        let sources: [(name: String, text: String)] = try Inv.kernelSources()
        #expect(sources.count == 10)
        for source in sources {
            for line in Inv.codeLines(source.text) {
                for token in forbidden { #expect(!line.contains(token), "\(source.name): \(token)") }
            }
        }

        // Seeded neighbours: tolerances E − 1, E and E + 1 on seeded arrangements; a lethal failure always names a walk
        // tick of 1 … 48 + E, and raising the tolerance never brings a lethal failure earlier.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures.prefix(25) {
            let arrangement: Arrangement = Inv.randomArrangement(&random, fixture.level)
            var previous: Int = 0
            for delta in -1...1 {
                let tolerance: Int = fixture.level.lethalTolerance + delta
                guard (0...12).contains(tolerance) else { continue }
                let copy: Level = try Inv.copy(fixture.level, lethalTolerance: tolerance, refusingAWin: false)
                let failure: Failure? = Sky.report(copy, arrangement: arrangement).failure
                switch failure {
                case .frozen(_, let tick), .scorched(_, let tick):
                    #expect(tick >= 1 && tick <= 48 + tolerance && tick >= previous)
                    previous = tick
                default:
                    previous = Int.max
                }
                #expect(Inv.agrees(copy, arrangement))
            }
        }
    }

    // MARK: INV-02 Input budget

    @Test func testBinaryGardensInputbudgetBoundary() throws {
        // Direct boundary: budget 2; two tilts accepted, the third refused `budget`, the run still accepted.
        var play: Play = try Inv.playing(try Inv.budgetLevel(budget: 2))
        try play.apply(.tilt(step: 1), expecting: play.fingerprint)
        #expect(play.actionsSpent == 1)
        try play.apply(.tilt(step: 2), expecting: play.fingerprint)
        #expect(play.actionsSpent == 2 && play.actionsLeft == 0)
        let spent: Play = play
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.tilt(step: 1), expecting: play.fingerprint) }
            == .budget)
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.tilt(step: 2), expecting: play.fingerprint) }
            == .action("unchanged"))
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.tilt(step: 9), expecting: Inv.staleFingerprint) }
            == .stale)
        #expect(play == spent)
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.actionsSpent == 2 && play.stage == .failed)
        #expect(Inv.refusal { () throws(Refusal) in _ = try Inv.budgetLevel(budget: 0) } == .level("budget"))
        #expect(Inv.refusal { () throws(Refusal) in _ = try Inv.budgetLevel(budget: 25) } == .level("budget"))
        #expect(Inv.refusal { () throws(Refusal) in _ = try Inv.budgetLevel(budget: 24) } == nil)

        // Seeded neighbours: budgets b − 1, b and b + 1 give exactly that many accepted actions.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for _ in 0..<12 {
            let b: Int = random.int(2...23)
            for budget in [b - 1, b, b + 1] {
                var p: Play = try Inv.playing(try Inv.budgetLevel(budget: budget))
                var accepted: Int = 0
                for step in 0..<30 {
                    let target: Int = step % 2 == 0 ? 1 + random.int(0...1) : 3
                    let action: Action = p.arrangement.tilt == target ? .tilt(step: 0) : .tilt(step: target)
                    if Inv.refusal({ () throws(Refusal) in try p.apply(action, expecting: p.fingerprint) }) == nil {
                        accepted += 1
                    }
                }
                #expect(accepted == budget && p.actionsLeft == 0)
                try p.apply(.run, expecting: p.fingerprint)
                #expect(p.actionsSpent == budget)
            }
        }
    }

    // MARK: INV-03 Goal

    @Test func testBinaryGardensGoalBoundary() throws {
        // Direct boundary: every fixture's known actions win; the winning arrangement's comfortable bound one milliflux
        // inside the window's extreme flux, or W one tick above its window, fails `unstable`.
        for fixture in Inv.fixtures.prefix(10) {
            let won: Play = try Inv.played(fixture.level, fixture.actions)
            #expect(won.stage == .won && won.report.wins)
            let report: Report = Sky.report(fixture.level, arrangement: fixture.winning)
            let world: World = fixture.level.worlds[0]
            let light: BinaryGardensWorldLight = report.worlds[0]
            var worlds: [World] = fixture.level.worlds
            worlds[0] = BinaryGardensLevelTests.world(world, window: light.window + 1)
            if light.window < 48 {
                let higher: Level = try Inv.copy(fixture.level, worlds: worlds, refusingAWin: false)
                #expect(Sky.report(higher, arrangement: fixture.winning).failure
                    == .unstable(world: 0, window: light.window, required: light.window + 1))
            }
            #expect(Inv.agrees(fixture.level, fixture.winning) && Inv.agrees(fixture.level, fixture.level.start))
        }

        // Seeded neighbours: on seeded arrangements the kernel and the independent judge agree, and a bloom bound one
        // milliflux beyond the integral flips the outcome to `wilted` or `bleached`.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var flips: Int = 0
        for fixture in Inv.fixtures {
            let arrangement: Arrangement = Inv.randomArrangement(&random, fixture.level)
            #expect(Inv.agrees(fixture.level, arrangement))
            let winning: Report = Sky.report(fixture.level, arrangement: fixture.winning)
            let integral: Int = winning.worlds[0].integral
            let world: World = fixture.level.worlds[0]
            var low: [World] = fixture.level.worlds
            low[0] = BinaryGardensLevelTests.world(world, bloomLow: integral + 1,
                                                   bloomHigh: max(world.bloomHigh, integral + 1))
            var high: [World] = fixture.level.worlds
            high[0] = BinaryGardensLevelTests.world(world, bloomLow: min(world.bloomLow, integral - 1),
                                                    bloomHigh: integral - 1)
            let exact: [World] = [BinaryGardensLevelTests.world(world, bloomLow: integral, bloomHigh: integral)]
                + fixture.level.worlds.dropFirst()
            let lowLevel: Level = try Inv.copy(fixture.level, worlds: low, refusingAWin: false)
            let highLevel: Level = try Inv.copy(fixture.level, worlds: high, refusingAWin: false)
            let exactLevel: Level = try Inv.copy(fixture.level, worlds: exact, refusingAWin: false)
            #expect(Sky.report(lowLevel, arrangement: fixture.winning).failure?.code == "wilted")
            #expect(Sky.report(highLevel, arrangement: fixture.winning).failure?.code == "bleached")
            #expect(Sky.report(exactLevel, arrangement: fixture.winning).wins)
            flips += 2
        }
        #expect(flips == 80)
    }

    // MARK: INV-04 Repeatability

    @Test func testBinaryGardensRepeatabilityBoundary() throws {
        // Direct boundary: the known actions twice give identical records; replay reproduces them; a trace with a record
        // removed or replayed on another level is refused.
        let fixture: Fixture = Inv.fixtures[0]
        let first: Play = try Inv.played(fixture.level, fixture.actions)
        let second: Play = try Inv.played(fixture.level, fixture.actions)
        #expect(first == second && first.records == second.records)
        #expect(try Play.replay(level: fixture.level, records: first.records) == first)
        var removed: [Record] = first.records
        removed.remove(at: 1)
        #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in
            _ = try Play.replay(level: fixture.level, records: removed)
        }))
        #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in
            _ = try Play.replay(level: Inv.fixtures[1].level, records: first.records)
        }))

        // Seeded neighbours: seeded traces run twice give the same fingerprint sequence and replay to the same play.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures {
            let steps: [Step] = Inv.randomSteps(fixture.level, count: 14, random: &random)
            let a: (play: Play, fingerprints: [String]) = try Inv.run(fixture.level, steps)
            let b: (play: Play, fingerprints: [String]) = try Inv.run(fixture.level, steps)
            #expect(a.fingerprints == b.fingerprints && a.play == b.play)
            #expect(try Play.replay(level: fixture.level, records: a.play.records) == a.play)
        }
    }

    // MARK: INV-05 Undo

    @Test func testBinaryGardensUndoBoundary() throws {
        // Direct boundary: undo from failed returns to playing with the arrangement before the run; a won run is final;
        // nothing is undone while paused.
        var play: Play = try Inv.playing(try Inv.budgetLevel(budget: 3))
        try play.apply(.tilt(step: 2), expecting: play.fingerprint)
        let beforeRun: String = play.fingerprint
        try play.apply(.run, expecting: play.fingerprint)
        try play.undo()
        #expect(play.fingerprint == beforeRun && play.stage == .playing && play.arrangement.tilt == 2)
        try play.handle(.pause)
        #expect(Inv.refusal { () throws(Refusal) in try play.undo() } == .stage)
        try play.handle(.resume)
        let fixture: Fixture = Inv.fixtures[0]
        var won: Play = try Inv.played(fixture.level, fixture.actions)
        #expect(Inv.refusal { () throws(Refusal) in try won.undo() } == .stage)

        // Seeded neighbours: after every accepted arrangement action, undo restores the exact prior fingerprint and redo
        // the later one.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var checked: Int = 0
        for fixture in Inv.fixtures {
            var p: Play = try Inv.playing(fixture.level)
            for _ in 0..<8 {
                let action: Action = BinaryGardensPlayTests.randomAction(&random, level: fixture.level)
                if case .run = action { continue }
                let before: String = p.fingerprint
                guard Inv.refusal({ () throws(Refusal) in try p.apply(action, expecting: before) }) == nil else {
                    continue
                }
                let after: String = p.fingerprint
                try p.undo()
                #expect(p.fingerprint == before)
                try p.redo()
                #expect(p.fingerprint == after && !p.canRedo)
                checked += 1
            }
        }
        #expect(checked > 40)
    }

    // MARK: INV-07 Failure honesty

    @Test func testBinaryGardensFailurehonestyBoundary() throws {
        // Direct boundary: a run lethal for exactly E + 1 ticks fails at its last tick; with tolerance E + 1 it does not
        // fail for that reason; the words name the world and the tick of the next cycle.
        let w = World(radius: 10, phase: 0, speed: 0, lethalLow: 100, comfortLow: 200, comfortHigh: 300,
                      lethalHigh: 400, window: 1, bloomLow: 0, bloomHigh: 9_600_000)
        var flux: [Int] = Array(repeating: 250, count: 48)
        for tick in [46, 47, 48, 1] { flux[tick - 1] = 50 }
        let light: BinaryGardensWorldLight = BinaryGardensSkyTests.light(flux, w)
        #expect(Sky.judge(worlds: [w, w], tolerance: 3, lights: [BinaryGardensSkyTests.light(Array(repeating: 250,
                                                                                                    count: 48), w),
                                                                light]) == .frozen(world: 1, tick: 49))
        #expect(Sky.judge(worlds: [w], tolerance: 4, lights: [light]) == nil)
        let level: Level = Inv.fixtures[0].level
        #expect(level.failureDescription(.frozen(world: 1, tick: 49)) == "world 2 froze at tick 49 (tick 1 of the next cycle)")
        // The play keeps its arrangement and actions spent on a failed run.
        var play: Play = try Inv.playing(level)
        let arrangement: Arrangement = play.arrangement
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.stage == .failed && play.arrangement == arrangement && play.actionsSpent == 0)
        #expect(play.failure == Ref.run(level, arrangement).failure)

        // Seeded neighbours: on seeded arrangements the failure equals the independent judge, its words name its world,
        // and a tolerance one tick higher never turns a lethal failure into an earlier one.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures {
            let arrangement: Arrangement = Inv.randomArrangement(&random, fixture.level)
            let failure: Failure? = Sky.report(fixture.level, arrangement: arrangement).failure
            #expect(failure == Ref.run(fixture.level, arrangement).failure)
            if let failure {
                let words: String = fixture.level.failureDescription(failure)
                #expect(words.hasPrefix("world \(failure.world + 1) "))
                if case .frozen(_, let tick) = failure, fixture.level.lethalTolerance < 12 {
                    let looser: Level = try Inv.copy(fixture.level, lethalTolerance: fixture.level.lethalTolerance + 1,
                                                     refusingAWin: false)
                    switch Sky.report(looser, arrangement: arrangement).failure {
                    case .frozen(_, let later), .scorched(_, let later): #expect(later > tick)
                    default: break
                    }
                }
            }
        }
    }

    // MARK: INV-08 Stability

    @Test func testBinaryGardensStabilityBoundary() throws {
        // Direct boundary: extreme arrangements (largest luminosity at the smallest ring, every clamp radius, a world
        // passing through a star) stay bounded: shares 0 … 64 000, flux the sum of the shares, integral ≤ 6 144 000.
        for clamp in 1...8 {
            let world = World(radius: 1, phase: 0, speed: 1, lethalLow: 0, comfortLow: 1, comfortHigh: 199_999,
                              lethalHigh: 200_000, window: 1, bloomLow: 0, bloomHigh: 9_600_000)
            let level: Level = try BinaryGardensLevelTests.hand(ringRadii: [1, 40], luminosities: [64],
                                                                clampRadius: clamp, worlds: [world])
            let report: Report = level.startReport
            #expect(report.worlds[0].shares.allSatisfy { $0[0] == 64_000 / (clamp * clamp) })
            #expect(check(report) == 0)
            #expect(BinaryGardensSkyTests.compare(level, level.start) == 0)
        }

        // Seeded neighbours: seeded arrangements reproduce the independent computation, keep every bound and return
        // every body to its start after 48 ticks.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures {
            for _ in 0..<3 {
                let arrangement: Arrangement = Inv.randomArrangement(&random, fixture.level)
                let report: Report = Sky.report(fixture.level, arrangement: arrangement)
                #expect(check(report) == 0)
                #expect(BinaryGardensSkyTests.compare(fixture.level, arrangement) == 0)
                #expect(report.starPositions[47] == Sky.starPositions(fixture.level, arrangement, tick: 0))
            }
        }
    }

    /// The number of broken bounds in `report`.
    private func check(_ report: Report) -> Int {
        var broken: Int = 0
        for light in report.worlds {
            var integral: Int = 0
            for tick in 0..<48 {
                let shares: [Int] = light.shares[tick]
                for share in shares where share < 0 || share > 64_000 { broken += 1 }
                if light.flux[tick] != shares[0] + shares[1] { broken += 1 }
                integral += light.flux[tick]
            }
            if integral != light.integral || integral > 6_144_000 { broken += 1 }
            if light.window > 48 || light.longestLethalRun > 48 { broken += 1 }
        }
        if report.minimumSeparationSquared < 0 || !(0..<48).contains(report.minimumSeparationTick) { broken += 1 }
        return broken
    }

    // MARK: INV-09 Save

    @Test func testBinaryGardensSaveBoundary() throws {
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

    @Test func testBinaryGardensRendererpurityBoundary() throws {
        // Direct boundary: the report is the sky's pure function of the level and the arrangement; computing it twice or
        // after reading words gives equal reports; the play is a value type; the report holds only the truth metric.
        let fixture: Fixture = Inv.fixtures[0]
        let level: Level = fixture.level
        var play: Play = try Inv.playing(level)
        try play.apply(fixture.actions[0], expecting: play.fingerprint)
        let arrangement: Arrangement = play.arrangement
        #expect(play.report == Sky.report(level, arrangement: arrangement))
        #expect(Sky.report(level, arrangement: arrangement) == Sky.report(level, arrangement: arrangement))
        let copy: Play = play
        _ = level.progressDescription(report: play.report, arrangement: play.arrangement, actionsLeft: play.actionsLeft)
        for star in 0..<2 { _ = level.starDescription(star, arrangement: play.arrangement) }
        for world in level.worlds.indices {
            _ = level.worldDescription(world, report: play.report)
            for tick in 1...48 { _ = level.worldTickDescription(world, tick: tick, report: play.report) }
        }
        if let failure = play.report.failure { _ = level.failureDescription(failure) }
        #expect(play == copy && play.report == Sky.report(level, arrangement: arrangement))
        var changed: Play = copy
        try changed.handle(.pause)
        #expect(play == copy && changed != copy)
        let labels: [String] = Mirror(reflecting: play.report).children.compactMap { $0.label }
        #expect(Set(labels) == ["starPositions", "worldPositions", "worlds", "minimumSeparationSquared",
                                "minimumSeparationTick", "failure"])
        // Swapping the two stars only swaps their positions and shares.
        let swappedStars: [Star] = [level.stars[1], level.stars[0]]
        let swappedLevel: Level = try Inv.copy(level, stars: swappedStars, refusingAWin: false)
        let swapped = Arrangement(rings: Array(fixture.winning.rings.reversed()),
                                  phases: Array(fixture.winning.phases.reversed()),
                                  luminosities: Array(fixture.winning.luminosities.reversed()),
                                  tilt: fixture.winning.tilt)
        let straight: Report = Sky.report(level, arrangement: fixture.winning)
        let reversed: Report = Sky.report(swappedLevel, arrangement: swapped)
        #expect(straight.worldPositions == reversed.worldPositions && straight.failure == reversed.failure)
        #expect(straight.minimumSeparationSquared == reversed.minimumSeparationSquared)
        for tick in 0..<48 {
            #expect(straight.starPositions[tick] == Array(reversed.starPositions[tick].reversed()))
        }
        for world in level.worlds.indices {
            #expect(straight.worlds[world].flux == reversed.worlds[world].flux)
            #expect(straight.worlds[world].shares == reversed.worlds[world].shares.map { Array($0.reversed()) })
        }
        // The report never depends on the id, seed, difficulty, budget or tutorial.
        let others: [Level] = [try Inv.copy(level, id: "inv-renamed", refusingAWin: false),
                               try Inv.copy(level, seed: 99, refusingAWin: false),
                               try Inv.copy(level, difficulty: 5, refusingAWin: false),
                               try Inv.copy(level, budget: 24, refusingAWin: false),
                               try Inv.copy(level, tutorial: true, refusingAWin: false)]
        for other in others {
            #expect(Sky.report(other, arrangement: arrangement) == Sky.report(level, arrangement: arrangement))
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
        // arrangement, reads of words change nothing, and a renamed level gives the same reports and outcomes.
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
                #expect(a.report == Sky.report(fixture.level, arrangement: a.arrangement))
                #expect(a.report == b.report && a.arrangement == b.arrangement && a.stage == b.stage)
                #expect(a.failure == b.failure && a.actionsLeft == b.actionsLeft)
                let before: Play = a
                _ = fixture.level.progressDescription(report: a.report, arrangement: a.arrangement,
                                                      actionsLeft: a.actionsLeft)
                #expect(a == before)
            }
        }
    }
}
