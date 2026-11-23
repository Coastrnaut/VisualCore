// EchoCartographerInvariantTests — feature 401 (R02-G11-01) T-R02G1101-006 (FR-R02G1101-012; the source's invariants
// R2-G11-INV-01 … 05 and INV-07 … 10 on Echo Cartographer). Each named test gives a direct boundary example and a seeded
// check of neighbouring inputs (seed 2,406: a claim at a beacon ± tolerance + 1, a pulse from a cell one step outside
// what is known, a cell just outside the chamber, a ninth marker, an energy budget ± 1), as the source asks. How each
// invariant maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G11-02; INV-11 is superseded by the
// free tier):
// - INV-01 Time: no rule reads a clock. Every delay is whole ticks, 24 × distance (12 ticks of 0.008333 s per cell each
//   way); the same actions give the same fingerprints and records however many pauses and reads lie between them; an
//   idle play never spends energy or fails; the kernel sources hold no clock, time interval or floating-point value.
// - INV-02 Input budget: a pulse spends exactly 1 energy, a hit nothing, a miss min(miss cost, energy left), a marker
//   nothing; refusals spend nothing; undo gives the energy of the moment it restores back and redo spends it again; the
//   energy never leaves 0 … budget; the action that spends the last energy is applied and judged, and every action after
//   the end is refused by stage.
// - INV-03 Goal: the level is won exactly on the action after which every beacon is located; a claim at the tolerance
//   locates, one cell further misses; a located beacon is the nearest unlocated one (then lowest row, then column).
// - INV-04 Repeatability: the same actions give the same records, fingerprints and outcome on independent runs and
//   through replay; an edited or forged record is refused.
// - INV-05 Undo: undo restores the exact prior knowledge, markers, located beacons, energy, stage, failure and
//   fingerprint; redo the later one; a new action clears redo; a won level is final; a paused play stays paused; a
//   failed play returns to playing.
// - INV-07 Failure honesty: energy failure names the 0-based index of the action that spent the last energy (its
//   record's index); the win is judged before the energy; a miss never costs more than the energy left; a failed play
//   undone still wins with its known claims (no hidden solution).
// - INV-08 Stability: over seeded traces every ray distance is 1 … max(W, H), every path length 0 … W·H − 1, every delay
//   within 24·W·H, every index inside the grid, the energy within the budget, at most 8 markers, each localization error
//   within the tolerance; reported rays, revealed cells and echoes equal an independent computation; nothing traps.
// - INV-09 Save: the stored level round-trips byte for byte; truncated, edited and newer stored forms are refused as a
//   whole; a stored record trace up to a save point replays to the state at that point; a damaged trace is refused.
// - INV-10 Renderer purity: the kernel types are value types; reading, naming, copying and decoding change no
//   fingerprint; the kernel sources import only Foundation, VisualCoreMath and VisualCoreSimulation (no rendering, UI,
//   GL or Metal framework) and use no clock, random source, Double or Float.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden import names are built by concatenation
// so that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import EchoCartographerCore

@Suite struct EchoCartographerInvariantTests {
    typealias Play = EchoCartographerPlay
    typealias Action = EchoCartographerAction
    typealias Cell = EchoCartographerCell

    /// The invariant (neighbouring-input) seed.
    static let seed: UInt64 = 2_406

    /// A fingerprint that is never the current one.
    static let staleFingerprint: String = String(repeating: "0", count: 64)

    /// The cell at column `x`, row `y`.
    static func cell(_ x: Int, _ y: Int) -> Cell { Cell(x: x, y: y) }

    /// The hand chamber's entry, (0, 0).
    static let entryPulse: Action = .pulse(0, 0)

    /// The winning claims on the hand level: each beacon's own cell, (2, 2) then (6, 0).
    static let winning: [Action] = [.claim(2, 2), .claim(6, 0)]

    /// A claim two cells from (2, 2) and three from (6, 0): a miss at tolerance 1.
    static let missing: Action = .claim(2, 0)

    /// Actions that neither win nor fail at energy 6: a pulse from the entry, a marker, a pulse from (0, 4) (known open
    /// after the first pulse's south ray).
    static let wandering: [Action] = [.pulse(0, 0), .mark(3, 3), .pulse(0, 4)]

    /// The hand level (Fixtures.handLevel's chamber, entry (0, 0), beacons (2, 2) and (6, 0)) with overrides.
    static func sample(tolerance: Int = 1, energy: Int = 6, missCost: Int = 2,
                       tutorial: Bool = false) throws(EchoCartographerError) -> EchoCartographerLevel {
        let hand: EchoCartographerLevel = EchoCartographerFixtures.handLevel()
        return try EchoCartographerLevel(id: "invariant", seed: seed, difficulty: 2, chamber: hand.chamber,
                                         entry: cell(0, 0), beacons: [cell(2, 2), cell(6, 0)], tolerance: tolerance,
                                         energy: energy, missCost: missCost, tutorial: tutorial)
    }

    /// A play of `level` begun (and its tutorial dismissed) so that it is in stage `playing`.
    static func playing(_ level: EchoCartographerLevel) throws(EchoCartographerError) -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A playing play of `level` with `actions` applied in order.
    static func played(_ level: EchoCartographerLevel, _ actions: [Action]) throws(EchoCartographerError) -> Play {
        var play: Play = try playing(level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play
    }

    /// The refusal of `body`, or nil when it was accepted.
    static func refusal(_ body: () throws(EchoCartographerError) -> Void) -> EchoCartographerError? {
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }

    /// Whether `error` is an `.action` refusal (any payload).
    static func isAction(_ error: EchoCartographerError?) -> Bool {
        if case .action = error { return true }
        return false
    }

    /// The cell an action names.
    static func target(_ action: Action) -> Cell {
        switch action {
        case let .pulse(x, y), let .claim(x, y), let .mark(x, y): return cell(x, y)
        }
    }

    // MARK: Independent computations

    /// Whether `c` is an open cell of `chamber`, decided from the raw walls.
    static func invOpen(_ chamber: EchoCartographerChamber, _ c: Cell) -> Bool {
        if c.x < 0 || c.y < 0 || c.x >= chamber.width || c.y >= chamber.height { return false }
        return !chamber.walls.contains(c.y * chamber.width + c.x)
    }

    /// A ray computed independently: the open cells crossed, the struck wall cell (nil at the border) and the steps.
    static func invRay(_ chamber: EchoCartographerChamber, from: Cell, dx: Int,
                       dy: Int) -> (open: [Cell], wall: Cell?, distance: Int) {
        var open: [Cell] = []
        var x: Int = from.x
        var y: Int = from.y
        var steps: Int = 0
        while true {
            x += dx
            y += dy
            steps += 1
            if x < 0 || y < 0 || x >= chamber.width || y >= chamber.height { return (open, nil, steps) }
            if chamber.walls.contains(y * chamber.width + x) { return (open, cell(x, y), steps) }
            open.append(cell(x, y))
        }
    }

    /// The four directions' steps in the fixed order north, east, south, west.
    static let invSteps: [(dx: Int, dy: Int)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]

    /// Path lengths from `from` by an independent breadth-first search; −1 for walls and unreachable cells.
    static func invPaths(_ chamber: EchoCartographerChamber, from: Cell) -> [Int] {
        let count: Int = chamber.width * chamber.height
        var lengths: [Int] = Array(repeating: -1, count: count)
        if !invOpen(chamber, from) { return lengths }
        var queue: [Cell] = [from]
        lengths[from.y * chamber.width + from.x] = 0
        var head: Int = 0
        while head < queue.count {
            let here: Cell = queue[head]
            head += 1
            let length: Int = lengths[here.y * chamber.width + here.x]
            for step in invSteps {
                let next: Cell = cell(here.x + step.dx, here.y + step.dy)
                if !invOpen(chamber, next) { continue }
                let n: Int = next.y * chamber.width + next.x
                if lengths[n] < 0 {
                    lengths[n] = length + 1
                    queue.append(next)
                }
            }
        }
        return lengths
    }

    /// Checks `echo` (a pulse from its emitter on `level`) against the independent rays and path lengths.
    static func invCheckEcho(_ echo: EchoCartographerEcho, _ level: EchoCartographerLevel) {
        let chamber: EchoCartographerChamber = level.chamber
        #expect(echo.rays.count == 4)
        for (k, ray) in echo.rays.enumerated() where k < 4 {
            let step: (dx: Int, dy: Int) = invSteps[k]
            let expected: (open: [Cell], wall: Cell?, distance: Int) = invRay(chamber, from: echo.emitter,
                                                                               dx: step.dx, dy: step.dy)
            #expect(ray.direction == EchoCartographerDirection.allCases[k])
            #expect(ray.open == expected.open && ray.wall == expected.wall && ray.distance == expected.distance)
            #expect(ray.delay == 24 * ray.distance)
        }
        let lengths: [Int] = invPaths(chamber, from: echo.emitter)
        var distances: [Int] = []
        for beacon in level.beacons {
            let length: Int = lengths[beacon.y * chamber.width + beacon.x]
            if length >= 0 { distances.append(length) }
        }
        distances.sort()
        #expect(echo.beaconDistances == distances)
        var delays: [Int] = []
        for distance in distances { delays.append(24 * distance) }
        #expect(echo.beaconDelays == delays)
    }

    /// The claim rule decided independently: the nearest unlocated beacon within the tolerance (then lowest row, then
    /// lowest column), and whether a located beacon is within the tolerance.
    static func invClaim(_ level: EchoCartographerLevel, _ c: Cell,
                         located: Set<Int>) -> (hit: Int?, nearLocated: Bool) {
        var best: Int? = nil
        var near: Bool = false
        for (index, beacon) in level.beacons.enumerated() {
            let d: Int = max(abs(c.x - beacon.x), abs(c.y - beacon.y))
            if d > level.tolerance { continue }
            if located.contains(index) {
                near = true
                continue
            }
            if let b = best {
                let other: Cell = level.beacons[b]
                let bd: Int = max(abs(c.x - other.x), abs(c.y - other.y))
                let lower: Bool = beacon.y < other.y || (beacon.y == other.y && beacon.x < other.x)
                let closer: Bool = d < bd || (d == bd && lower)
                if closer { best = index }
            } else {
                best = index
            }
        }
        return (best, near)
    }

    /// What an action on `play` must do, decided independently.
    struct Expected {
        /// "action" or "noop" when the action must be refused; nil when it must be accepted.
        let refusal: String?
        /// The energy after it.
        let energy: Int
        /// The number of located beacons after it.
        let located: Int
        /// The beacon a claim locates, if any.
        let hit: Int?
    }

    /// The independent judgement of `action` on a playing `play` (stage and fingerprint already valid).
    static func invExpect(_ play: Play, _ action: Action) -> Expected {
        let level: EchoCartographerLevel = play.level
        let c: Cell = target(action)
        let inside: Bool = c.x >= 0 && c.y >= 0 && c.x < level.chamber.width && c.y < level.chamber.height
        let same: Expected = Expected(refusal: "action", energy: play.energy, located: play.located.count, hit: nil)
        if !inside { return same }
        let known: EchoCartographerKnown = play.knowledge[c.y * level.chamber.width + c.x]
        switch action {
        case .pulse:
            if known != .open { return same }
            return Expected(refusal: nil, energy: play.energy - 1, located: play.located.count, hit: nil)
        case .claim:
            if known == .wall { return same }
            let result: (hit: Int?, nearLocated: Bool) = invClaim(level, c, located: Set(play.located.keys))
            if let hit = result.hit {
                return Expected(refusal: nil, energy: play.energy, located: play.located.count + 1, hit: hit)
            }
            if result.nearLocated {
                return Expected(refusal: "noop", energy: play.energy, located: play.located.count, hit: nil)
            }
            let cost: Int = min(level.missCost, play.energy)
            return Expected(refusal: nil, energy: play.energy - cost, located: play.located.count, hit: nil)
        case .mark:
            if !play.markers.contains(c) && play.markers.count >= 8 { return same }
            return Expected(refusal: nil, energy: play.energy, located: play.located.count, hit: nil)
        }
    }

    /// Checks an accepted action's result against `expected`: energy, located beacons, then the judgement (win first,
    /// then energy zero: failed naming the action's record index).
    static func invCheckJudged(_ after: Play, _ expected: Expected) {
        #expect(after.energy == expected.energy && after.located.count == expected.located)
        let index: Int = after.records.last?.index ?? -1
        if expected.located == after.level.beacons.count {
            #expect(after.stage == .won && after.failure == nil)
        } else if expected.energy == 0 {
            #expect(after.stage == .failed && after.failure == .energy(index))
        } else {
            #expect(after.stage == .playing && after.failure == nil)
        }
    }

    // MARK: Seeded walks

    /// A seeded action for `play`: a cell just outside the chamber, a pulse from a known-open cell or from any cell, a
    /// claim at a beacon ± (tolerance + 1), a claim on a known beacon cell or anywhere, a marker among ten cells (so the
    /// ninth marker and toggles occur).
    static func invAction(_ play: Play, _ fixture: EchoCartographerFixture, random: inout SeededRandom) -> Action {
        let level: EchoCartographerLevel = play.level
        let width: Int = level.chamber.width
        let height: Int = level.chamber.height
        let roll: Int = random.int(0...19)
        if roll == 0 {
            let x: Int = random.int(0...1) == 0 ? -1 : width
            let y: Int = random.int(0...(height - 1))
            let kind: Int = random.int(0...2)
            if kind == 0 { return .pulse(x, y) }
            if kind == 1 { return .claim(x, y) }
            return .mark(x, y)
        }
        if roll <= 5 {
            var open: [Int] = []
            for index in 0..<(width * height) where play.knowledge[index] == .open { open.append(index) }
            let pick: Int = open[random.int(0...(open.count - 1))]
            return .pulse(pick % width, pick / width)
        }
        if roll == 6 { return .pulse(random.int(0...(width - 1)), random.int(0...(height - 1))) }
        if roll <= 11 {
            let beacon: Cell = level.beacons[random.int(0...(level.beacons.count - 1))]
            let reach: Int = level.tolerance + 1
            let x: Int = min(width - 1, max(0, beacon.x + random.int(-reach...reach)))
            let y: Int = min(height - 1, max(0, beacon.y + random.int(-reach...reach)))
            return .claim(x, y)
        }
        if roll <= 13 { return .claim(random.int(0...(width - 1)), random.int(0...(height - 1))) }
        if roll <= 16 {
            let pick: Int = random.int(0...9)
            return .mark(pick % width, pick / width)
        }
        let known: Cell = fixture.claims[random.int(0...(fixture.claims.count - 1))]
        return .claim(known.x, known.y)
    }

    /// What one seeded step did.
    enum StepKind: Equatable { case undo, redo, pause, resume, action }

    /// One seeded step: its kind, its action (if any), the play before it and its refusal (if any).
    typealias Step = (kind: StepKind, action: Action?, before: Play, error: EchoCartographerError?)

    /// One seeded step on `play`: an undo or redo when possible (always an undo from a failed play), a pause or resume,
    /// or an action checked against the independent judgement. A refused step must leave the play unchanged.
    static func invStep(_ play: inout Play, _ fixture: EchoCartographerFixture, random: inout SeededRandom) -> Step {
        let before: Play = play
        let roll: Int = random.int(0...19)
        if play.stage == .failed && play.canUndo {
            let error: EchoCartographerError? = refusal { () throws(EchoCartographerError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 0 && play.canUndo {
            let error: EchoCartographerError? = refusal { () throws(EchoCartographerError) in try play.undo() }
            return (.undo, nil, before, error)
        }
        if roll == 1 && play.canRedo {
            let error: EchoCartographerError? = refusal { () throws(EchoCartographerError) in try play.redo() }
            return (.redo, nil, before, error)
        }
        if roll == 2 && play.stage == .playing {
            let error: EchoCartographerError? = refusal { () throws(EchoCartographerError) in try play.handle(.pause) }
            return (.pause, nil, before, error)
        }
        if play.stage == .paused {
            let error: EchoCartographerError? = refusal { () throws(EchoCartographerError) in try play.handle(.resume) }
            return (.resume, nil, before, error)
        }
        let action: Action = invAction(play, fixture, random: &random)
        let error: EchoCartographerError? = refusal { () throws(EchoCartographerError) in
            try play.apply(action, expecting: play.fingerprint)
        }
        if error != nil && play != before { Issue.record("a refused \(action) changed the play") }
        if before.stage == .playing {
            let expected: Expected = invExpect(before, action)
            if let reason = expected.refusal {
                let matches: Bool = reason == "noop" ? error == .noop : isAction(error)
                #expect(matches, "\(action) should be refused as \(reason), got \(String(describing: error))")
            } else {
                #expect(error == nil, "\(action) should be accepted, got \(String(describing: error))")
                if error == nil { invCheckJudged(play, expected) }
            }
        }
        return (.action, action, before, error)
    }

    /// A seeded walk of at most `steps` steps on a playing play of the fixture's level; a won play ends the walk.
    static func invWalk(_ fixture: EchoCartographerFixture, steps: Int,
                        random: inout SeededRandom) throws(EchoCartographerError) -> Play {
        var play: Play = try playing(fixture.level)
        for _ in 0..<steps {
            if play.stage == .won { break }
            _ = invStep(&play, fixture, random: &random)
        }
        return play
    }

    /// Whether two plays hold the same kernel state.
    static func sameState(_ a: Play, _ b: Play) -> Bool {
        a.fingerprint == b.fingerprint && a.knowledge == b.knowledge && a.markers == b.markers
            && a.located == b.located && a.energy == b.energy && a.stage == b.stage && a.failure == b.failure
    }

    /// `play` resumed if it is paused. A trace records no pause, so a replay ends paused only when its last record was
    /// made while paused; plays are compared resumed.
    static func unpaused(_ play: Play) throws(EchoCartographerError) -> Play {
        var copy: Play = play
        if copy.stage == .paused { try copy.handle(.resume) }
        return copy
    }

    /// The fixture of the neighbouring checks: the fixtures from seed 2,406 on.
    static func neighbour(_ index: Int) -> EchoCartographerFixture {
        EchoCartographerFixtures.fixture(seed &+ UInt64(index))
    }

    /// The presentation sources of feature 403 (R02-G11-03), which use Doubles for drawing and import the experience
    /// packages; the purity scan covers the kernel files only.
    static let presentationSources: Set<String> = ["EchoCartographerSceneSnapshot.swift",
                                                   "EchoCartographerSceneGeometry.swift",
                                                   "EchoCartographerShaders.swift",
                                                   "EchoCartographerScenarios.swift",
                                                   "EchoCartographerExperienceCore.swift"]

    /// The Swift sources of the kernel (the Core directory next to this test directory, without the presentation
    /// sources).
    static func kernelSources() throws -> [(name: String, text: String)] {
        let tests: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let core: URL = tests.deletingLastPathComponent().appendingPathComponent("Core")
        let names: [String] = try FileManager.default.contentsOfDirectory(atPath: core.path).sorted()
        var sources: [(name: String, text: String)] = []
        for name in names where name.hasSuffix(".swift") && !presentationSources.contains(name) {
            let text: String = try String(contentsOf: core.appendingPathComponent(name), encoding: .utf8)
            sources.append((name, text))
        }
        return sources
    }

    // MARK: INV-01 Time

    /// INV-01 Time: delays are whole ticks (24 × distance); no rule reads a clock; pauses and reads between actions
    /// change no fingerprint.
    @Test func testEchoCartographerTimeBoundary() throws {
        let level: EchoCartographerLevel = try Self.sample()
        // Direct example: the pulse from the entry: rays 1, 3, 5, 1 cells (24, 72, 120, 24 ticks), echoes 4 and 10
        // cells (96 and 240 ticks); one cell is 24 ticks, the round trip at 12 each way.
        #expect(EchoCartographerChamber.ticksPerCell == 24)
        let pulsed: Play = try Self.played(level, [Self.entryPulse])
        let echo: EchoCartographerEcho = try #require(pulsed.lastEcho)
        var distances: [Int] = []
        var delays: [Int] = []
        for ray in echo.rays {
            distances.append(ray.distance)
            delays.append(ray.delay)
        }
        #expect(distances == [1, 3, 5, 1] && delays == [24, 72, 120, 24])
        #expect(echo.beaconDistances == [4, 10] && echo.beaconDelays == [96, 240])
        Self.invCheckEcho(echo, level)
        // A ray striking the neighbouring wall is 1 cell, 24 ticks; an echo from the emitter's own cell is 0 ticks.
        let adjacent: EchoCartographerRay = level.chamber.ray(from: Self.cell(0, 1), .east)
        #expect(adjacent.distance == 1 && adjacent.delay == 24 && adjacent.wall == Self.cell(1, 1))
        let onBeacon: EchoCartographerEcho = level.chamber.echo(from: Self.cell(2, 2), beacons: level.beacons)
        #expect(onBeacon.beaconDistances.first == 0 && onBeacon.beaconDelays.first == 0)
        // The same actions applied straight and after many pauses and reads.
        let actions: [Action] = [Self.wandering[0], Self.wandering[1], Self.wandering[2], Self.winning[0],
                                 Self.winning[1]]
        var straight: Play = try Self.playing(level)
        var framed: Play = try Self.playing(level)
        for action in actions {
            try straight.apply(action, expecting: straight.fingerprint)
            for _ in 0..<120 {
                _ = framed.fingerprint
                _ = framed.lastEcho
                _ = framed.totalLocalizationError
                try framed.handle(.pause)
                try framed.handle(.resume)
            }
            _ = level.levelDescription()
            try framed.apply(action, expecting: framed.fingerprint)
            #expect(framed.fingerprint == straight.fingerprint && framed.energy == straight.energy)
        }
        #expect(straight.stage == .won && framed.stage == .won)
        #expect(straight.records == framed.records)
        // An idle play neither spends energy nor fails, however long it waits or how often it is paused.
        var idle: Play = try Self.playing(level)
        let opening: String = idle.fingerprint
        for _ in 0..<1_000 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.stage == .playing && idle.energy == level.energy && idle.failure == nil)
        #expect(idle.fingerprint == opening && idle.records.isEmpty)
        // The kernel holds no clock, time interval or floating-point value.
        let tokens: [String] = ["Double", "Float", "TimeInterval", "Date", "Clock", "CFAbsoluteTime", "DispatchTime",
                                "Timer"]
        let sources: [(name: String, text: String)] = try Self.kernelSources()
        #expect(sources.count >= 4)
        for source in sources {
            for token in tokens { #expect(!source.text.contains(token), "\(source.name) uses \(token)") }
        }
        // Seeded neighbours: every pulse's delays are 24 × its distances; accepted actions repeated after seeded numbers
        // of pauses and reads reach the same fingerprint after every action and the same records.
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        for index in 0..<30 {
            let fixture: EchoCartographerFixture = Self.neighbour(index)
            var a: Play = try Self.playing(fixture.level)
            var b: Play = try Self.playing(fixture.level)
            for _ in 0..<20 {
                if a.stage != .playing { break }
                let action: Action = Self.invAction(a, fixture, random: &random)
                let error: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                if error != nil { continue }
                if case .pulse = action, let last = a.lastEcho {
                    for ray in last.rays { #expect(ray.delay == ray.distance * 24) }
                    for (k, distance) in last.beaconDistances.enumerated() {
                        #expect(last.beaconDelays[k] == distance * 24)
                    }
                }
                let frames: Int = random.int(0...6)
                for _ in 0..<frames {
                    try b.handle(.pause)
                    _ = b.fingerprint
                    _ = b.localizationErrors
                    try b.handle(.resume)
                }
                try b.apply(action, expecting: b.fingerprint)
                #expect(a.fingerprint == b.fingerprint && a.energy == b.energy && a.stage == b.stage)
            }
            #expect(a.records == b.records)
        }
    }

    // MARK: INV-02 Input budget

    /// INV-02 Input budget: a pulse spends 1, a miss its capped cost, hits and markers nothing, refusals nothing; the
    /// action that spends the last energy is judged and later actions are refused by stage.
    @Test func testEchoCartographerInputbudgetBoundary() throws {
        // Direct: 3 pulses from the entry fail an energy-3 level on the third; any further action is refused by stage.
        let three: [Action] = [Self.entryPulse, Self.entryPulse, Self.entryPulse]
        var spent: Play = try Self.played(try Self.sample(energy: 3), three)
        #expect(spent.energy == 0 && spent.stage == .failed && spent.failure == .energy(2))
        let held: Play = spent
        let lateClaim: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try spent.apply(Self.winning[0], expecting: spent.fingerprint)
        }
        let lateMark: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try spent.apply(.mark(1, 0), expecting: spent.fingerprint)
        }
        #expect(lateClaim == .stage && lateMark == .stage && spent == held)
        // With one energy more, the same three leave one; the winning claims are free and win with that one left.
        let spare: Play = try Self.played(try Self.sample(energy: 4), three)
        #expect(spare.stage == .playing && spare.energy == 1 && spare.failure == nil)
        let exact: Play = try Self.played(try Self.sample(energy: 1), Self.winning)
        #expect(exact.stage == .won && exact.energy == 1 && exact.failure == nil)
        // A miss costs the miss cost but never more than the energy left.
        let miss: Play = try Self.played(try Self.sample(energy: 6, missCost: 2), [Self.missing])
        #expect(miss.energy == 4 && miss.stage == .playing && miss.located.isEmpty)
        let capped: Play = try Self.played(try Self.sample(energy: 3, missCost: 3), [Self.entryPulse, Self.missing])
        #expect(capped.energy == 0 && capped.stage == .failed)
        // Refused actions spend nothing: stage, stale, outside, pulse from an unknown cell, claim on a known wall,
        // a ninth marker, a no-op claim.
        var loading: Play = Play(level: try Self.sample())
        let early: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try loading.apply(Self.entryPulse, expecting: Self.staleFingerprint)
        }
        #expect(early == .stage && loading.energy == 6)
        var play: Play = try Self.playing(try Self.sample())
        let opening: Play = play
        let stale: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try play.apply(.pulse(-1, 0), expecting: Self.staleFingerprint)
        }
        let west: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try play.apply(.pulse(-1, 0), expecting: play.fingerprint)
        }
        let south: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try play.apply(.claim(0, 5), expecting: play.fingerprint)
        }
        let east: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try play.apply(.mark(7, 0), expecting: play.fingerprint)
        }
        let unknown: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try play.apply(.pulse(1, 0), expecting: play.fingerprint)
        }
        #expect(stale == .stale)
        #expect(Self.isAction(west) && Self.isAction(south) && Self.isAction(east) && Self.isAction(unknown))
        #expect(play == opening && play.energy == 6 && play.records.isEmpty)
        // The pulse from the entry spends exactly one; (3, 0) is then a known wall and a claim on it is refused.
        try play.apply(Self.entryPulse, expecting: play.fingerprint)
        #expect(play.energy == 5 && play.records.count == 1 && play.knowledge[3] == .wall)
        let afterPulse: Play = play
        let onWall: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try play.apply(.claim(3, 0), expecting: play.fingerprint)
        }
        #expect(Self.isAction(onWall) && play == afterPulse)
        // Markers are free: eight are accepted, the ninth refused, a toggle removes one.
        for k in 0..<8 { try play.apply(.mark(k % 7, 4 - k / 7), expecting: play.fingerprint) }
        #expect(play.markers.count == 8 && play.energy == 5)
        let full: Play = play
        let ninth: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try play.apply(.mark(6, 2), expecting: play.fingerprint)
        }
        #expect(Self.isAction(ninth) && play == full)
        try play.apply(.mark(0, 4), expecting: play.fingerprint)
        #expect(play.markers.count == 7 && play.energy == 5)
        // A hit is free; a second claim within the tolerance only of the located beacon is a refused no-op.
        try play.apply(Self.winning[0], expecting: play.fingerprint)
        #expect(play.energy == 5 && play.located.count == 1)
        let located: Play = play
        let noop: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
            try play.apply(.claim(2, 1), expecting: play.fingerprint)
        }
        #expect(noop == .noop && play == located)
        // Undo gives the energy back, redo spends it again.
        var undoing: Play = try Self.played(try Self.sample(), [Self.entryPulse])
        try undoing.undo()
        #expect(undoing.energy == 6)
        try undoing.redo()
        #expect(undoing.energy == 5 && undoing.records.count == 3)
        // Seeded neighbours: over seeded walks the energy stays within 0 … budget; an accepted pulse spends one, a
        // claim nothing or its capped miss cost, a marker nothing; refusals and pauses spend nothing; undo never spends
        // and redo never gives back; a play at zero energy is decided.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 1)
        for index in 0..<40 {
            let fixture: EchoCartographerFixture = Self.neighbour(index)
            let budget: Int = fixture.level.energy
            var walk: Play = try Self.playing(fixture.level)
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, fixture, random: &random)
                #expect(walk.energy >= 0 && walk.energy <= budget)
                if walk.energy == 0 { #expect(walk.stage == .won || walk.stage == .failed) }
                if step.error != nil {
                    #expect(walk == step.before)
                    continue
                }
                switch step.kind {
                case .action:
                    #expect(walk.records.count == step.before.records.count + 1)
                    guard let action = step.action else { continue }
                    switch action {
                    case .pulse: #expect(walk.energy == step.before.energy - 1)
                    case .claim:
                        if walk.located.count > step.before.located.count {
                            #expect(walk.energy == step.before.energy)
                        } else {
                            let cost: Int = min(fixture.level.missCost, step.before.energy)
                            #expect(walk.energy == step.before.energy - cost)
                        }
                    case .mark: #expect(walk.energy == step.before.energy)
                    }
                case .undo:
                    #expect(walk.energy >= step.before.energy)
                case .redo:
                    #expect(walk.energy <= step.before.energy)
                case .pause, .resume:
                    #expect(walk.energy == step.before.energy && walk.records == step.before.records)
                }
            }
        }
    }

    // MARK: INV-03 Goal

    /// INV-03 Goal: won exactly when every beacon is located; a claim at the tolerance locates, one further misses.
    @Test func testEchoCartographerGoalBoundary() throws {
        let level: EchoCartographerLevel = try Self.sample()
        // Direct example: a fresh play is not won; the first claim locates one beacon, the second wins.
        let fresh: Play = try Self.playing(level)
        #expect(fresh.stage == .playing && fresh.located.isEmpty && fresh.totalLocalizationError == 0)
        let half: Play = try Self.played(level, [Self.winning[0]])
        #expect(half.stage == .playing && half.located == [1: Self.cell(2, 2)])
        #expect(half.knowledge[16] == .open)
        let won: Play = try Self.played(level, Self.winning)
        #expect(won.stage == .won && won.located.count == 2 && won.failure == nil && won.totalLocalizationError == 0)
        // The tolerance is inclusive: (2, 1) is one cell from (2, 2) and locates it at tolerance 1 (error 1); (2, 0) is
        // two cells away and misses; at tolerance 2 it locates.
        let atTolerance: Play = try Self.played(level, [.claim(2, 1)])
        #expect(atTolerance.located == [1: Self.cell(2, 1)] && atTolerance.localizationErrors.reduce(0, +) == 1)
        #expect(atTolerance.totalLocalizationError == 1 && atTolerance.energy == level.energy)
        let beyond: Play = try Self.played(level, [Self.missing])
        #expect(beyond.located.isEmpty && beyond.energy == level.energy - level.missCost)
        let wider: Play = try Self.played(try Self.sample(tolerance: 2), [Self.missing])
        #expect(wider.located == [1: Self.cell(2, 0)] && wider.totalLocalizationError == 2)
        // Nearest first: at tolerance 2, (4, 1) is two cells from both beacons; the tie goes to the lower row, (6, 0),
        // beacon 0; then (3, 2) locates (2, 2) and wins with total error 3.
        var tie: Play = try Self.played(try Self.sample(tolerance: 2), [.claim(4, 1)])
        #expect(tie.located == [0: Self.cell(4, 1)])
        try tie.apply(.claim(3, 2), expecting: tie.fingerprint)
        #expect(tie.stage == .won && tie.totalLocalizationError == 3)
        // Pulses and markers alone never win.
        let looking: Play = try Self.played(level, Self.wandering)
        #expect(looking.stage == .playing && looking.located.isEmpty)
        // Seeded neighbours: after every accepted action the play is won exactly when every beacon is located; each
        // fixture's known actions win only on the last claim, and a claim one cell beyond the tolerance of the last
        // beacon in its place wins only when the independent rule says it locates.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 2)
        for index in 0..<40 {
            let fixture: EchoCartographerFixture = Self.neighbour(index)
            let other: EchoCartographerLevel = fixture.level
            var walk: Play = try Self.playing(other)
            for _ in 0..<30 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, fixture, random: &random)
                guard step.kind == .action, step.error == nil else { continue }
                #expect((walk.stage == .won) == (walk.located.count == other.beacons.count))
                if walk.stage == .won { #expect(walk.failure == nil) }
            }
            // The known pulses are applied only when the energy outlasts them (a pulse that spends the last energy
            // fails the level); the known claims are on the beacons' own cells and need no pulse.
            var known: Play = try Self.playing(other)
            for pulse in fixture.pulses where other.energy > fixture.pulses.count {
                try known.apply(.pulse(pulse.x, pulse.y), expecting: known.fingerprint)
                #expect(known.stage == .playing)
            }
            for (offset, claim) in fixture.claims.enumerated() {
                let last: Bool = offset == fixture.claims.count - 1
                if last {
                    let dx: Int = random.int(0...1) == 0 ? -(other.tolerance + 1) : other.tolerance + 1
                    let near: Cell = Self.cell(claim.x + dx, claim.y)
                    var probe: Play = known
                    let expected: Expected = Self.invExpect(probe, .claim(near.x, near.y))
                    let error: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
                        try probe.apply(.claim(near.x, near.y), expecting: probe.fingerprint)
                    }
                    if expected.refusal == nil {
                        #expect(error == nil)
                        #expect((probe.stage == .won) == (expected.located == other.beacons.count))
                    } else {
                        #expect(error != nil && probe == known)
                    }
                }
                try known.apply(.claim(claim.x, claim.y), expecting: known.fingerprint)
                #expect((known.stage == .won) == last)
            }
        }
    }

    // MARK: INV-04 Repeatability

    /// INV-04 Repeatability: the same actions give the same records and fingerprints; replay reproduces them.
    @Test func testEchoCartographerRepeatabilityBoundary() throws {
        let level: EchoCartographerLevel = try Self.sample()
        // Direct example: two independent runs with an undo and a redo agree record for record and replay agrees.
        var first: Play = try Self.played(level, Self.wandering)
        var second: Play = try Self.played(level, Self.wandering)
        try first.undo()
        try second.undo()
        try first.redo()
        try second.redo()
        for action in Self.winning {
            try first.apply(action, expecting: first.fingerprint)
            try second.apply(action, expecting: second.fingerprint)
        }
        #expect(first.records == second.records && first.fingerprint == second.fingerprint)
        #expect(first.records.count == 7 && first.stage == .won && second.stage == .won)
        let replayed: Play = try Play.replay(level: level, records: first.records)
        #expect(Self.sameState(replayed, first) && replayed.records == first.records)
        // An edited or forged record is refused: a changed next fingerprint, a changed action, a missing action.
        var forged: [EchoCartographerRecord] = first.records
        let one: EchoCartographerRecord = forged[0]
        forged[0] = EchoCartographerRecord(schema: one.schema, seed: one.seed, index: one.index, kind: one.kind,
                                           action: one.action, previous: one.previous, next: Self.staleFingerprint)
        #expect(Self.refusal { () throws(EchoCartographerError) in
            _ = try Play.replay(level: level, records: forged)
        } != nil)
        var swapped: [EchoCartographerRecord] = first.records
        let two: EchoCartographerRecord = first.records[1]
        swapped[1] = EchoCartographerRecord(schema: two.schema, seed: two.seed, index: two.index, kind: .mark,
                                            action: .mark(4, 4), previous: two.previous, next: two.next)
        #expect(Self.refusal { () throws(EchoCartographerError) in
            _ = try Play.replay(level: level, records: swapped)
        } != nil)
        var bare: [EchoCartographerRecord] = first.records
        bare[0] = EchoCartographerRecord(schema: one.schema, seed: one.seed, index: one.index, kind: .pulse,
                                         action: nil, previous: one.previous, next: one.next)
        #expect(Self.refusal { () throws(EchoCartographerError) in
            _ = try Play.replay(level: level, records: bare)
        } != nil)
        // The same records on a neighbouring level (energy + 1) are refused: every fingerprint names the level.
        let otherLevel: EchoCartographerLevel = try Self.sample(energy: 7)
        #expect(Self.refusal { () throws(EchoCartographerError) in
            _ = try Play.replay(level: otherLevel, records: first.records)
        } != nil)
        // Seeded neighbours: two walks drawn from equal seeds agree; replay reproduces every walk.
        for index in 0..<30 {
            let fixture: EchoCartographerFixture = Self.neighbour(index)
            var randomA: SeededRandom = SeededRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            var randomB: SeededRandom = SeededRandom(seed: Self.seed &+ 3 &+ UInt64(index))
            let a: Play = try Self.invWalk(fixture, steps: 30, random: &randomA)
            let b: Play = try Self.invWalk(fixture, steps: 30, random: &randomB)
            #expect(a == b && a.records == b.records && a.fingerprint == b.fingerprint)
            let again: Play = try Play.replay(level: fixture.level, records: a.records)
            #expect(again.records == a.records && again.knowledge == a.knowledge && again.energy == a.energy)
            #expect(again.located == a.located && again.markers == a.markers)
            #expect((try Self.unpaused(again)).fingerprint == (try Self.unpaused(a)).fingerprint)
        }
    }

    // MARK: INV-05 Undo

    /// INV-05 Undo: exact restore; redo the later state; a won level is final; failed returns to playing.
    @Test func testEchoCartographerUndoBoundary() throws {
        let level: EchoCartographerLevel = try Self.sample()
        // Direct example: each undo restores the exact earlier state, each redo the later one.
        var play: Play = try Self.playing(level)
        var states: [Play] = [play]
        let actions: [Action] = [Self.wandering[0], Self.wandering[1], Self.wandering[2], Self.missing,
                                 Self.winning[0]]
        for action in actions {
            try play.apply(action, expecting: play.fingerprint)
            states.append(play)
        }
        for back in stride(from: states.count - 2, through: 0, by: -1) {
            try play.undo()
            #expect(Self.sameState(play, states[back]))
        }
        #expect(!play.canUndo && play.canRedo && play.knowledge == level.openingKnowledge)
        let nothing: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in try play.undo() }
        #expect(Self.isAction(nothing))
        for forward in 1..<states.count {
            try play.redo()
            #expect(Self.sameState(play, states[forward]))
        }
        // A new action clears redo.
        try play.undo()
        #expect(play.canRedo)
        try play.apply(.mark(5, 4), expecting: play.fingerprint)
        #expect(!play.canRedo)
        let noRedo: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in try play.redo() }
        #expect(Self.isAction(noRedo))
        // A paused play stays paused through undo and redo.
        try play.handle(.pause)
        let paused: Play = play
        try play.undo()
        #expect(play.stage == .paused)
        try play.redo()
        #expect(play.stage == .paused && play.markers == paused.markers && play.energy == paused.energy)
        // A won level is final: undo and redo are refused.
        var won: Play = try Self.played(level, Self.winning)
        let wonHeld: Play = won
        let finalUndo: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in try won.undo() }
        let finalRedo: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in try won.redo() }
        #expect(finalUndo == .stage && finalRedo == .stage && won == wonHeld && !won.canUndo)
        // A failed play returns to playing with the exact earlier state (energy and knowledge), and then still wins.
        let poor: EchoCartographerLevel = try Self.sample(energy: 3, missCost: 2)
        let beforeMiss: Play = try Self.played(poor, [Self.entryPulse])
        var failed: Play = try Self.played(poor, [Self.entryPulse, Self.missing])
        #expect(failed.stage == .failed && failed.canUndo && !failed.canRedo)
        try failed.undo()
        #expect(Self.sameState(failed, beforeMiss) && failed.failure == nil && failed.energy == 2)
        for action in Self.winning { try failed.apply(action, expecting: failed.fingerprint) }
        #expect(failed.stage == .won)
        // Seeded neighbours: along seeded walks of accepted actions (undoing every failure at once), the states are
        // kept; undoing back to the start restores each one exactly, in reverse.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 4)
        for index in 0..<30 {
            let fixture: EchoCartographerFixture = Self.neighbour(index)
            var walk: Play = try Self.playing(fixture.level)
            var kept: [Play] = [walk]
            for _ in 0..<12 {
                if walk.stage != .playing { break }
                let action: Action = Self.invAction(walk, fixture, random: &random)
                let error: EchoCartographerError? = Self.refusal { () throws(EchoCartographerError) in
                    try walk.apply(action, expecting: walk.fingerprint)
                }
                if error != nil { continue }
                if walk.stage == .failed {
                    let before: Play = kept[kept.count - 1]
                    try walk.undo()
                    #expect(Self.sameState(walk, before) && walk.stage == .playing)
                    try walk.redo()
                    #expect(walk.stage == .failed)
                    try walk.undo()
                    continue
                }
                kept.append(walk)
            }
            if walk.stage == .won { continue }
            for back in stride(from: kept.count - 1, through: 0, by: -1) {
                #expect(Self.sameState(walk, kept[back]))
                if back > 0 { try walk.undo() }
            }
        }
    }

    // MARK: INV-07 Failure honesty

    /// INV-07 Failure honesty: energy failure names the action that spent the last energy; the win is judged first.
    @Test func testEchoCartographerFailurehonestyBoundary() throws {
        // Direct example: energy 3, miss cost 2: the pulse leaves 2, the miss spends them; failed on action 1.
        let poor: EchoCartographerLevel = try Self.sample(energy: 3, missCost: 2)
        let failed: Play = try Self.played(poor, [Self.entryPulse, Self.missing])
        #expect(failed.stage == .failed && failed.failure == .energy(1) && failed.failure?.code == "energy")
        #expect(failed.energy == 0 && failed.records.last?.index == 1 && failed.located.isEmpty)
        // A miss cost above the energy left spends only what is left; one energy more survives the same miss.
        let capped: Play = try Self.played(try Self.sample(energy: 3, missCost: 3), [Self.entryPulse, Self.missing])
        #expect(capped.energy == 0 && capped.failure == .energy(1))
        let survives: Play = try Self.played(try Self.sample(energy: 4, missCost: 2), [Self.entryPulse, Self.missing])
        #expect(survives.stage == .playing && survives.energy == 1 && survives.failure == nil)
        // A pulse that spends the last energy fails at once (a pulse never locates a beacon); after a marker it names
        // action 1.
        let lastPulse: Play = try Self.played(try Self.sample(energy: 1), [Self.entryPulse])
        #expect(lastPulse.failure == .energy(0) && lastPulse.records.last?.index == 0)
        let marked: Play = try Self.played(try Self.sample(energy: 1), [.mark(1, 0), Self.entryPulse])
        #expect(marked.failure == .energy(1) && marked.records.last?.index == 1)
        // The budget boundary: E pulses fail an energy-E level on action E − 1; E − 1 pulses do not.
        for budget in 1...6 {
            var pulses: [Action] = []
            for _ in 0..<budget { pulses.append(Self.entryPulse) }
            let atBudget: Play = try Self.played(try Self.sample(energy: budget), pulses)
            #expect(atBudget.stage == .failed && atBudget.failure == .energy(budget - 1))
            if budget > 1 {
                let under: Play = try Self.played(try Self.sample(energy: budget), Array(pulses.dropLast()))
                #expect(under.stage == .playing && under.failure == nil && under.energy == 1)
            }
        }
        // The win is judged before the energy: with one energy left after a miss, the free claims still win.
        let edge: Play = try Self.played(try Self.sample(energy: 3, missCost: 2), [Self.missing] + Self.winning)
        #expect(edge.stage == .won && edge.energy == 1 && edge.failure == nil)
        // No hidden solution: the failed play undone still wins with the known claims.
        var retry: Play = failed
        try retry.undo()
        for action in Self.winning { try retry.apply(action, expecting: retry.fingerprint) }
        #expect(retry.stage == .won && retry.failure == nil)
        // Seeded neighbours: every failure met on a seeded walk is honest: it names the record index of the action just
        // applied, the energy is zero and a beacon is still hidden; with no failure the energy is positive or the level
        // is won.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 5)
        var failures: Int = 0
        var wins: Int = 0
        for index in 0..<40 {
            let fixture: EchoCartographerFixture = Self.neighbour(index)
            let other: EchoCartographerLevel = fixture.level
            var walk: Play = try Self.playing(other)
            for _ in 0..<40 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, fixture, random: &random)
                guard step.kind == .action, step.error == nil else { continue }
                switch walk.failure {
                case let .energy(action):
                    failures += 1
                    #expect(walk.stage == .failed && walk.energy == 0)
                    #expect(walk.records.last?.index == action)
                    #expect(walk.located.count < other.beacons.count)
                case nil:
                    if walk.stage == .won { wins += 1 }
                    #expect(walk.energy > 0 || walk.stage == .won)
                }
            }
        }
        #expect(failures > 0 && wins > 0)
    }

    // MARK: INV-08 Stability

    /// The serpentine 16 × 16 chamber: the odd rows are walls except one gap, at column 15 for rows 1, 5, 9, 13 and at
    /// column 0 for rows 3, 7, 11, 15, so the open floor is one corridor.
    static func serpentine() throws(EchoCartographerError) -> EchoCartographerChamber {
        var walls: Set<Int> = []
        for y in stride(from: 1, to: 16, by: 2) {
            let gap: Int = y % 4 == 1 ? 15 : 0
            for x in 0..<16 where x != gap { walls.insert(y * 16 + x) }
        }
        return try EchoCartographerChamber(width: 16, height: 16, walls: walls)
    }

    /// INV-08 Stability: bounded values and no trap over seeded traces.
    @Test func testEchoCartographerStabilityBoundary() throws {
        // Direct example: the longest corridor of a 16 × 16 chamber: from (0, 0) to (0, 15) is 7 × (15 + 2) + 15 + 1 =
        // 135 steps, 3,240 ticks, within W·H = 256 cells and 24·W·H = 6,144 ticks.
        let snake: EchoCartographerChamber = try Self.serpentine()
        let far: EchoCartographerLevel = try EchoCartographerLevel(
            id: "serpentine", seed: Self.seed, difficulty: 5, chamber: snake, entry: Self.cell(0, 0),
            beacons: [Self.cell(0, 15)], tolerance: 0, energy: 60, missCost: 3)
        let echo: EchoCartographerEcho = far.echo(from: Self.cell(0, 0))
        #expect(echo.beaconDistances == [135] && echo.beaconDelays == [3_240])
        #expect(Self.invPaths(snake, from: Self.cell(0, 0))[15 * 16] == 135)
        #expect(echo.beaconDistances[0] <= 256 && echo.beaconDelays[0] <= 24 * 256)
        Self.invCheckEcho(echo, far)
        // The longest ray of an empty 16 × 16 chamber leaves it after 16 steps (384 ticks).
        let empty: EchoCartographerChamber = try EchoCartographerChamber(width: 16, height: 16, walls: [])
        let long: EchoCartographerRay = empty.ray(from: Self.cell(0, 0), .east)
        #expect(long.distance == 16 && long.delay == 384 && long.wall == nil && long.open.count == 15)
        // Through a play: the far beacon is located with its own cell and the play wins with every value in bounds.
        var play: Play = try Self.playing(far)
        try play.apply(.pulse(0, 0), expecting: play.fingerprint)
        try play.apply(.claim(0, 15), expecting: play.fingerprint)
        #expect(play.stage == .won && play.energy == 59 && play.totalLocalizationError == 0)
        // Seeded neighbours: long seeded traces on the fixtures (and on the serpentine level) never trap; every
        // distance, delay and index stays in bounds; reported rays, revealed cells and echoes agree with the independent
        // computation; the counts stay consistent.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 6)
        var fixtures: [EchoCartographerFixture] = []
        for index in 0..<40 { fixtures.append(Self.neighbour(index)) }
        fixtures.append(EchoCartographerFixture(level: far, pulses: [Self.cell(0, 0)], claims: [Self.cell(0, 15)]))
        for fixture in fixtures {
            let other: EchoCartographerLevel = fixture.level
            let width: Int = other.chamber.width
            let height: Int = other.chamber.height
            let cells: Int = width * height
            var walk: Play = try Self.playing(other)
            var accepted: Int = 0
            for _ in 0..<60 {
                if walk.stage == .won { break }
                let step: Step = Self.invStep(&walk, fixture, random: &random)
                if step.error == nil && step.kind != .pause && step.kind != .resume { accepted += 1 }
                #expect(walk.records.count == accepted)
                #expect(walk.energy >= 0 && walk.energy <= other.energy)
                #expect(walk.markers.count <= 8 && Set(walk.markers).count == walk.markers.count)
                for marker in walk.markers { #expect(other.chamber.isInside(marker)) }
                #expect(walk.located.count <= other.beacons.count)
                var total: Int = 0
                for (beacon, claim) in walk.located {
                    #expect(beacon >= 0 && beacon < other.beacons.count && other.chamber.isInside(claim))
                    if beacon >= 0 && beacon < other.beacons.count {
                        let error: Int = claim.distance(to: other.beacons[beacon])
                        #expect(error <= other.tolerance)
                        total += error
                        #expect(walk.knowledge[other.chamber.index(other.beacons[beacon])] == .open)
                    }
                }
                #expect(walk.totalLocalizationError == total && walk.localizationErrors.reduce(0, +) == total)
                // Knowledge never contradicts the chamber.
                for index in 0..<cells {
                    let known: EchoCartographerKnown = walk.knowledge[index]
                    let isWall: Bool = other.chamber.walls.contains(index)
                    if known == .open { #expect(!isWall) }
                    if known == .wall { #expect(isWall) }
                }
                guard step.kind == .action, step.error == nil, let action = step.action,
                      case .pulse = action, let last = walk.lastEcho else { continue }
                #expect(last.emitter == Self.target(action))
                Self.invCheckEcho(last, other)
                for ray in last.rays {
                    #expect(ray.distance >= 1 && ray.distance <= max(width, height) && ray.distance <= cells)
                    #expect(ray.delay >= 24 && ray.delay <= 24 * cells)
                    for crossed in ray.open { #expect(walk.knowledge[other.chamber.index(crossed)] == .open) }
                    if let wall = ray.wall { #expect(walk.knowledge[other.chamber.index(wall)] == .wall) }
                }
                for (k, distance) in last.beaconDistances.enumerated() {
                    #expect(distance >= 0 && distance <= cells - 1)
                    #expect(last.beaconDelays[k] >= 0 && last.beaconDelays[k] <= 24 * cells)
                }
            }
        }
    }

    // MARK: INV-09 Save

    /// The stored form of `level` with key `key` set to `value` (fingerprint kept), sorted keys.
    static func invEditing(_ level: EchoCartographerLevel, key: String, value: Any) throws -> Data {
        let object: Any = try JSONSerialization.jsonObject(with: level.encoded())
        guard var dictionary = object as? [String: Any] else { throw EchoCartographerError.malformed("not an object") }
        dictionary[key] = value
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    /// The refusal of decoding `data`, or nil when it decoded.
    static func invDecodeRefusal(_ data: Data) -> EchoCartographerError? {
        do {
            _ = try EchoCartographerLevel.decode(data)
            return nil
        } catch {
            return error
        }
    }

    /// INV-09 Save: the stored level round-trips; damaged forms are refused whole; stored traces replay to save points.
    @Test func testEchoCartographerSaveBoundary() throws {
        let level: EchoCartographerLevel = try Self.sample(tutorial: true)
        // Direct example: byte-for-byte round trip.
        let stored: Data = level.encoded()
        let decoded: EchoCartographerLevel = try EchoCartographerLevel.decode(stored)
        #expect(decoded == level && decoded.encoded() == stored && decoded.fingerprint == level.fingerprint)
        let viaCodable: EchoCartographerLevel = try JSONDecoder().decode(EchoCartographerLevel.self, from: stored)
        #expect(viaCodable == level)
        // Truncated, edited and newer forms are refused as a whole. The hand chamber's walls are cells 3, 8, 10, 12,
        // 15, 19, 22, 23, 24, 26; its beacons are cells 6 and 16; the entry is cell 0.
        let levelCode: EchoCartographerError = .malformed("r02-g11.level")
        #expect(Self.invDecodeRefusal(stored.prefix(stored.count / 2)) == .malformed("unreadable"))
        #expect(Self.invDecodeRefusal(Data()) == .malformed("unreadable"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "energy", value: 5)) == .malformed("fingerprint"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "energy", value: 0)) == levelCode)
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "energy", value: 61)) == levelCode)
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "tolerance", value: 3)) == levelCode)
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "tolerance", value: 2))
                    == .malformed("fingerprint"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "missCost", value: 0)) == levelCode)
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "beacons", value: [3, 16] as [Int])) == levelCode)
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "beacons", value: [0, 16] as [Int])) == levelCode)
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "beacons", value: [16, 16] as [Int]))
                    == levelCode)
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "beacons", value: [] as [Int])) == levelCode)
        let doubledWalls: [Int] = [3, 3, 8, 10, 12, 15, 19, 22, 23, 24, 26]
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "walls", value: doubledWalls)) == levelCode)
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "width", value: 4)) == levelCode)
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "schema", value: 2)) == .newerSchema(2))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "schema", value: 0)) == .malformed("schema 0"))
        #expect(Self.invDecodeRefusal(try Self.invEditing(level, key: "fingerprint", value: Self.staleFingerprint))
                    == .malformed("fingerprint"))
        // A stored record trace up to a save point replays to the state at that point.
        var play: Play = try Self.playing(level)
        var saves: [Play] = []
        let actions: [Action] = [Self.wandering[0], Self.wandering[1], Self.missing, Self.wandering[2],
                                 Self.winning[0], Self.winning[1]]
        for action in actions {
            try play.apply(action, expecting: play.fingerprint)
            saves.append(play)
        }
        #expect(play.stage == .won)
        let trace: Data = try JSONEncoder().encode(play.records)
        let loaded: [EchoCartographerRecord] = try JSONDecoder().decode([EchoCartographerRecord].self, from: trace)
        #expect(loaded == play.records)
        for point in 1...loaded.count {
            let resumed: Play = try Play.replay(level: decoded, records: Array(loaded.prefix(point)))
            #expect(Self.sameState(resumed, saves[point - 1]))
        }
        // A damaged trace is refused: unreadable bytes, and a record whose previous fingerprint was edited.
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode([EchoCartographerRecord].self, from: trace.prefix(trace.count / 2))
        }
        var damaged: [EchoCartographerRecord] = loaded
        let r: EchoCartographerRecord = damaged[2]
        damaged[2] = EchoCartographerRecord(schema: r.schema, seed: r.seed, index: r.index, kind: r.kind,
                                            action: r.action, previous: Self.staleFingerprint, next: r.next)
        #expect(Self.refusal { () throws(EchoCartographerError) in
            _ = try Play.replay(level: decoded, records: damaged)
        } != nil)
        // Seeded neighbours: every seeded level round-trips; a seeded truncation, an energy ± 1 and a tolerance ± 1
        // are refused; the stored trace of a seeded walk replays to the walk's state.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 7)
        for index in 0..<40 {
            let fixture: EchoCartographerFixture = Self.neighbour(index)
            let other: EchoCartographerLevel = fixture.level
            let bytes: Data = other.encoded()
            let back: EchoCartographerLevel = try EchoCartographerLevel.decode(bytes)
            #expect(back == other && back.encoded() == bytes)
            let cut: Int = random.int(0...(bytes.count - 1))
            #expect(Self.invDecodeRefusal(bytes.prefix(cut)) != nil)
            for energy in [other.energy - 1, other.energy + 1] {
                #expect(Self.invDecodeRefusal(try Self.invEditing(other, key: "energy", value: energy)) != nil)
            }
            for tolerance in [other.tolerance - 1, other.tolerance + 1] {
                let edited: Data = try Self.invEditing(other, key: "tolerance", value: tolerance)
                #expect(Self.invDecodeRefusal(edited) != nil)
            }
            let walk: Play = try Self.invWalk(fixture, steps: 30, random: &random)
            let saved: Data = try JSONEncoder().encode(walk.records)
            let records: [EchoCartographerRecord] = try JSONDecoder().decode([EchoCartographerRecord].self, from: saved)
            let restored: Play = try Play.replay(level: back, records: records)
            #expect(restored.records == walk.records && restored.knowledge == walk.knowledge)
            #expect(restored.energy == walk.energy && restored.located == walk.located)
            #expect(restored.fingerprint == (walk.records.last?.next ?? restored.fingerprint))
            #expect((try Self.unpaused(restored)).fingerprint == (try Self.unpaused(walk)).fingerprint)
        }
    }

    // MARK: INV-10 Renderer purity

    /// INV-10 Renderer purity: value types only; reading changes nothing; the kernel imports no rendering framework.
    @Test func testEchoCartographerRendererpurityBoundary() throws {
        let level: EchoCartographerLevel = try Self.sample()
        // Direct example: the kernel types are value types.
        let play: Play = try Self.played(level, [Self.entryPulse, .mark(2, 1)])
        let echo: EchoCartographerEcho = try #require(play.lastEcho)
        #expect(Mirror(reflecting: level).displayStyle == .struct)
        #expect(Mirror(reflecting: level.chamber).displayStyle == .struct)
        #expect(Mirror(reflecting: play).displayStyle == .struct)
        #expect(Mirror(reflecting: play.knowledge).displayStyle == .struct)
        #expect(Mirror(reflecting: echo).displayStyle == .struct)
        #expect(Mirror(reflecting: echo.rays[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: play.records[0]).displayStyle == .struct)
        #expect(Mirror(reflecting: Self.entryPulse).displayStyle == .enum)
        #expect(Mirror(reflecting: EchoCartographerFailure.energy(0)).displayStyle == .enum)
        #expect(Mirror(reflecting: EchoCartographerStage.playing).displayStyle == .enum)
        // The play holds no visual state: no field names a colour, vertex, texture, shader, frame, time or layer.
        let visual: [String] = ["colo", "vertex", "texture", "shader", "frame", "time", "layer", "pixel", "mesh"]
        for child in Mirror(reflecting: play).children {
            let label: String = (child.label ?? "").lowercased()
            for word in visual { #expect(!label.contains(word), "the play holds \(label)") }
        }
        // A copy is independent: changing it leaves the original as it was.
        let original: Play = play
        var copy: Play = play
        try copy.apply(.pulse(0, 4), expecting: copy.fingerprint)
        #expect(play == original && copy.energy == play.energy - 1 && copy.knowledge != play.knowledge)
        // Reading names and descriptions and decoding the level change nothing.
        let fingerprint: String = play.fingerprint
        var words: [String] = [level.levelDescription(), level.echoDescription(echo),
                               level.progressDescription(located: play.located.count, energy: play.energy)]
        for index in 0..<level.chamber.cellCount {
            words.append(level.cellName(level.chamber.cell(index), knowledge: play.knowledge))
        }
        _ = play.localizationErrors
        _ = play.totalLocalizationError
        _ = play.canUndo
        _ = play.canRedo
        #expect(words.count == 3 + level.chamber.cellCount)
        #expect(play.fingerprint == fingerprint && play == original)
        let decoded: EchoCartographerLevel = try EchoCartographerLevel.decode(level.encoded())
        let rebuilt: Play = try Play.replay(level: decoded, records: play.records)
        #expect(rebuilt.fingerprint == fingerprint)
        // The same state reached by another path (a pulse and its undo) has the same fingerprint.
        var detour: Play = try Self.playing(level)
        try detour.apply(Self.entryPulse, expecting: detour.fingerprint)
        try detour.undo()
        #expect(detour.fingerprint == (try Self.playing(level)).fingerprint)
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
        #expect(sources.count >= 4)
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
        // Seeded neighbours: for seeded walks, reading every cell name, the echo and progress descriptions and
        // recomputing a neighbouring pulse (one step beside the last emitter) on the level change no fingerprint;
        // replaying the records on the decoded level gives the same fingerprint.
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 8)
        for index in 0..<30 {
            let fixture: EchoCartographerFixture = Self.neighbour(index)
            let other: EchoCartographerLevel = fixture.level
            let p: Play = try Self.invWalk(fixture, steps: 20, random: &random)
            let held: String = p.fingerprint
            let heldKnowledge: EchoCartographerKnowledge = p.knowledge
            for cellIndex in 0..<other.chamber.cellCount {
                _ = other.cellName(other.chamber.cell(cellIndex), knowledge: p.knowledge)
            }
            _ = other.progressDescription(located: p.located.count, energy: p.energy)
            if let last = p.lastEcho {
                _ = other.echoDescription(last)
                let step: (dx: Int, dy: Int) = Self.invSteps[random.int(0...3)]
                let beside: Cell = Self.cell(last.emitter.x + step.dx, last.emitter.y + step.dy)
                if other.chamber.isInside(beside) && other.chamber.isOpen(beside) {
                    _ = other.echo(from: beside)
                }
            }
            #expect(p.fingerprint == held && p.knowledge == heldKnowledge)
            if !p.records.isEmpty {
                let otherDecoded: EchoCartographerLevel = try EchoCartographerLevel.decode(other.encoded())
                let again: Play = try Play.replay(level: otherDecoded, records: p.records)
                #expect(again.records == p.records && again.knowledge == heldKnowledge)
                #expect((try Self.unpaused(again)).fingerprint == (try Self.unpaused(p)).fingerprint)
            }
        }
    }
}
