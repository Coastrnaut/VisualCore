// ApsidesWorkshopInvariantTests — feature 471 (R02-G18-01) T-R02G1801-006 (FR-R02G1801-012; the source's invariants
// R2-G18-INV-01 … 05 and INV-07 … 10 on Apsides Workshop), modelled on CelestialEclipseLabInvariantTests (feature
// 461). Each named test gives a direct boundary example and a seeded check of neighbouring inputs (seed 2,476: fixtures
// drawn from it, random valid orbits and periods, steps −1 and one past each range, the current orbit, orbits one step
// beyond the star or the sky bound, a budget ± 1, periods T and 2T, share bands moved by one unit, a reversed or
// shortened target list, ids changed, a byte of a stored level changed).
// How each invariant maps onto this kernel (INV-06 content and INV-12 novelty belong to R02-G18-02; INV-11 is
// superseded by the free tier):
// - INV-01 Time: no rule reads a clock; time is the tick 0 … T − 1 of one revolution. The orbiter's positions depend
//   only on the tick and the orbit (never on planets, targets, the level's other values, pauses or reads): tick 2t of
//   a revolution of 2T ticks is tick t of a revolution of T ticks; periapsis is tick 0 and apoapsis tick T/2; the same
//   actions give the same fingerprints however many pauses and reads lie between them; an idle play never spends an
//   action or fails; the kernel sources hold no clock, time interval or floating-point value.
// - INV-02 Input budget: an accepted tuning spends exactly 1 action, the play none; refusals spend nothing and change
//   nothing; a tuning out of range, unchanged or making the orbit invalid (a(20 − k) < 60 or a(20 + k) > 1280) is
//   refused `action`, with no action left `budget` (action before budget) while the play is still accepted.
// - INV-03 Goal: a play wins exactly when the orbit strikes no planet and every target is met in its order (judged
//   against an independent sector, share, contact and order judge); a share exactly on a band bound is inside; the
//   known orbits win; a reversed target list is judged by the same independent judge; a prefix keeps a win.
// - INV-04 Repeatability: the same inputs give the same records, fingerprints, reports and outcome on independent runs
//   and through replay; a trace with a record removed, or the trace of another level, is refused.
// - INV-05 Undo: undo restores the exact prior fingerprint, orbit, actions spent, report and failure; redo the later
//   one; a new action clears redo; a won level is final; a failed play returns to playing with the orbit before it;
//   undo while paused stays paused.
// - INV-07 Failure honesty: a failed play names `contact`, `order`, `share`, `apsis-sector` or `apsis-distance` with
//   the planet or target and the tick (or the sector or distance) equal to an independent judge; the orbit and actions
//   spent stay as they were (no hidden fix); the last record ends at the current fingerprint; the words name the
//   planet and the tick; refusals carry their `r02-g18.*` codes; undo from a failure returns to playing.
// - INV-08 Stability: every position of every valid orbit lies within ±16,384 sky units (the sky bound is reached
//   exactly by the orbits of apoapsis 1280 twentieths), every Kepler residual within 2^−22 (256 in fixed point), every
//   share in 0 … 1000 and their sum in 992 … 1000; at least 500 seeded play states stay bounded.
// - INV-09 Save: stored levels round-trip byte for byte (through `encoded`/`decode` and through Codable); any
//   single-byte edit is refused or decodes to the same level; truncated, newer, older and fingerprint-edited forms are
//   refused; a stored record trace replays to the same play.
// - INV-10 Renderer purity: the report is a pure function of the level's period, planets and targets and the orbit
//   (never of time, call order, presentation, the id, seed, difficulty, budget, tutorial or starting orbit); names and
//   descriptions read for drawing never change the play; the play is a value type; the kernel sources import only
//   Foundation, VisualCoreMath and VisualCoreSimulation.
// Test data uses explicit types and plain loops (CI type-check rule). Forbidden tokens are built by concatenation so
// that this file never holds the token sequence the repository's compliance scan matches.
import Foundation
import Testing
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

@Suite struct ApsidesWorkshopInvariantTests {
    typealias Play = ApsidesWorkshopPlay
    typealias Level = ApsidesWorkshopLevel
    typealias Action = ApsidesWorkshopAction
    typealias Failure = ApsidesWorkshopFailure
    typealias Report = ApsidesWorkshopReport
    typealias Orbit = ApsidesWorkshopOrbit
    typealias Point = ApsidesWorkshopPoint
    typealias Planet = ApsidesWorkshopPlanet
    typealias Target = ApsidesWorkshopTarget
    typealias Fixture = ApsidesWorkshopFixture
    typealias Record = ApsidesWorkshopRecord
    typealias Refusal = ApsidesWorkshopError
    typealias Sky = ApsidesWorkshopSky
    typealias Fixed = ApsidesWorkshopFixed

    /// The helpers, builders and independent computations of this file.
    private enum Inv {
        /// The invariant (neighbouring-input) seed.
        static let seed: UInt64 = 2_476

        /// A fingerprint that is never the current one.
        static let staleFingerprint: String = String(repeating: "0", count: 64)

        /// The sky bound in sky units (64 lattice units of 256).
        static let skyBound: Int = 16_384

        /// The kernel sources the scans read when present (the Core directory next to this test directory).
        static let kernelFiles: [String] = ["ApsidesWorkshopError.swift", "ApsidesWorkshopFixed.swift",
                                            "ApsidesWorkshopOrbit.swift", "ApsidesWorkshopLevel.swift",
                                            "ApsidesWorkshopPlay.swift", "ApsidesWorkshopRules.swift"]

        /// The fixtures of the invariant seed (computed once).
        static let fixtures: [Fixture] = Fixture.all(count: 40, seed: seed)

        /// The hand level's starting orbit: a circle of 24 lattice units (shares 125 in every sector).
        static let circle: Orbit = Orbit(size: 24, eccentricity: 0, direction: 0)

        /// The hand level's winning orbit: size 24, e = 0.75, periapsis towards +x (sector 0 sweeps 3.6 %).
        static let winner: Orbit = Orbit(size: 24, eccentricity: 15, direction: 0)

        /// The hand level's target: sector 0 sweeps 0.0 … 10.0 %.
        static let handTarget: Target = .sweep(sector: 0, low: 0, high: 100)

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

        /// The hand level: period 16, the circle as starting orbit, by default no planets and the target sector 0
        /// sweeps 0.0 … 10.0 %. The circle fails `share` (125) at tick 0; the winner wins (share 36).
        static func hand(targets: [Target] = [handTarget], planets: [Planet] = [], budget: Int = 3,
                         id: String = "inv-hand", seed: UInt64 = 1) throws(Refusal) -> Level {
            try Level(id: id, seed: seed, difficulty: 1, period: 16, planets: planets, targets: targets,
                      orbit: circle, budget: budget)
        }

        /// `level` with some values replaced.
        static func variant(_ level: Level, id: String? = nil, seed: UInt64? = nil, difficulty: Int? = nil,
                            budget: Int? = nil, tutorial: Bool? = nil) throws(Refusal) -> Level {
            try Level(id: id ?? level.id, seed: seed ?? level.seed, difficulty: difficulty ?? level.difficulty,
                      period: level.period, planets: level.planets, targets: level.targets, orbit: level.orbit,
                      budget: budget ?? level.budget, tutorial: tutorial ?? level.tutorial)
        }

        /// The extreme valid level: period 96, six planets of radius 8 at the corners and edges of the sky, six sweep
        /// targets each asking for a share of exactly 100.0 % (never all met), a 64-character id, the largest seed,
        /// difficulty 5, budget 24, a tutorial, and an orbit reaching the sky bound.
        static func extreme() throws(Refusal) -> Level {
            let planets: [Planet] = [Planet(x: 64, y: 64, radius: 8), Planet(x: -64, y: 64, radius: 8),
                                     Planet(x: -64, y: -64, radius: 8), Planet(x: 64, y: -64, radius: 8),
                                     Planet(x: 0, y: 64, radius: 8), Planet(x: 0, y: -64, radius: 8)]
            var targets: [Target] = []
            for sector in 0..<6 { targets.append(.sweep(sector: sector, low: 1000, high: 1000)) }
            return try Level(id: String(repeating: "z", count: 64), seed: UInt64.max, difficulty: 5, period: 96,
                             planets: planets, targets: targets, orbit: Orbit(size: 40, eccentricity: 12,
                                                                                direction: 23),
                             budget: 24, tutorial: true)
        }

        /// Whether `orbit` is valid, by an independent reading of the rule (clarification Q1).
        static func invValid(_ orbit: Orbit) -> Bool {
            if orbit.size < 8 || orbit.size > 48 { return false }
            if orbit.eccentricity < 0 || orbit.eccentricity > 15 { return false }
            if orbit.direction < 0 || orbit.direction > 23 { return false }
            let near: Int = orbit.size * (20 - orbit.eccentricity)
            let far: Int = orbit.size * (20 + orbit.eccentricity)
            return near >= 60 && far <= 1280
        }

        /// The orbit a tuning asks for from `orbit` (nil for the play).
        static func tuned(_ orbit: Orbit, _ action: Action) -> Orbit? {
            switch action {
            case .periapsis(let k, let d): return Orbit(size: orbit.size, eccentricity: k, direction: d)
            case .size(let a): return Orbit(size: a, eccentricity: orbit.eccentricity, direction: orbit.direction)
            case .play: return nil
            }
        }

        /// Whether a tuning from `orbit` passes the action checks (in range, changed, valid), independently.
        static func invAccepts(_ orbit: Orbit, _ action: Action) -> Bool {
            guard let next = tuned(orbit, action) else { return true }
            return next != orbit && invValid(next)
        }

        /// A random valid orbit.
        static func randomOrbit(_ random: inout SeededRandom) -> Orbit {
            while true {
                let orbit: Orbit = Orbit(size: random.int(8...48), eccentricity: random.int(0...15),
                                         direction: random.int(0...23))
                if invValid(orbit) { return orbit }
            }
        }

        /// The tunings that take `from` to `to` through valid orbits only: the size first when the eccentricity does
        /// not fall (the orbit (a₁, k₀) is then valid), otherwise the periapsis knob first ((a₀, k₁) is then valid).
        static func route(from: Orbit, to: Orbit) -> [Action] {
            var actions: [Action] = []
            let knob: Bool = from.eccentricity != to.eccentricity || from.direction != to.direction
            let size: Bool = from.size != to.size
            if to.eccentricity >= from.eccentricity {
                if size { actions.append(.size(to.size)) }
                if knob { actions.append(.periapsis(to.eccentricity, to.direction)) }
            } else {
                if knob { actions.append(.periapsis(to.eccentricity, to.direction)) }
                if size { actions.append(.size(to.size)) }
            }
            return actions
        }

        /// A seeded action for `play`: mostly a tuning in range, sometimes a step out of range (−1 or one past), the
        /// current value, or the play.
        static func invAction(_ play: Play, random: inout SeededRandom) -> Action {
            let roll: Int = random.int(0...19)
            let orbit: Orbit = play.orbit
            if roll == 0 { return .size(random.int(0...1) == 0 ? 7 : 49) }
            if roll == 1 {
                let k: Int = random.int(0...1) == 0 ? -1 : 16
                let d: Int = random.int(0...1) == 0 ? -1 : 24
                return random.int(0...1) == 0 ? .periapsis(k, orbit.direction) : .periapsis(orbit.eccentricity, d)
            }
            if roll == 2 {
                return random.int(0...1) == 0 ? .size(orbit.size) : .periapsis(orbit.eccentricity, orbit.direction)
            }
            if roll == 3 { return .play }
            if roll < 12 { return .periapsis(random.int(0...15), random.int(0...23)) }
            return .size(random.int(8...48))
        }

        /// A seeded walk of up to `steps` actions, undos, redos, pauses and resumes on `level` (refusals skipped).
        static func invWalk(_ level: Level, steps: Int, random: inout SeededRandom) throws -> Play {
            var play: Play = try playing(level)
            for _ in 0..<steps {
                let roll: Int = random.int(0...19)
                if roll < 2 {
                    _ = refusal { () throws(Refusal) in try play.undo() }
                } else if roll == 2 {
                    _ = refusal { () throws(Refusal) in try play.redo() }
                } else if roll == 3 {
                    _ = refusal { () throws(Refusal) in try play.handle(.pause) }
                } else if roll == 4 {
                    _ = refusal { () throws(Refusal) in try play.handle(.resume) }
                } else {
                    if play.stage == .paused { try play.handle(.resume) }
                    if play.stage != .playing { continue }
                    let action: Action = invAction(play, random: &random)
                    _ = refusal { () throws(Refusal) in try play.apply(action, expecting: play.fingerprint) }
                }
            }
            return play
        }

        /// The play of `level` with its orbit set to `orbit` (a budget-24 variant so every tuning fits), then played.
        static func runOf(_ level: Level, orbit: Orbit) throws -> Play {
            let roomy: Level = try variant(level, budget: Level.budgets.upperBound)
            var actions: [Action] = route(from: roomy.orbit, to: orbit)
            actions.append(.play)
            return try played(roomy, actions)
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

        /// The sector of a point by an independent method: the half-open quadrant [90q°, 90(q + 1)°), the point
        /// turned back by 90q° exactly, then the half of the quadrant (45° belongs to the upper half).
        static func invSector(_ p: Point) -> Int {
            var x: Int = p.x
            var y: Int = p.y
            var quadrant: Int = 0
            while !(x > 0 && y >= 0) && quadrant < 4 {
                let turnedX: Int = y
                let turnedY: Int = -x
                x = turnedX
                y = turnedY
                quadrant += 1
            }
            return 2 * quadrant + (y >= x ? 1 : 0)
        }

        /// The shares of `points` by an independent quadrature: the doubled triangle star → P(t) → P(t + 1) counted
        /// for the sector of P(t), in tenths of a percent rounded down (negative sector areas count as 0).
        static func invShares(_ points: [Point]) -> [Int] {
            var areas: [Int64] = [0, 0, 0, 0, 0, 0, 0, 0]
            var total: Int64 = 0
            for tick in 0..<points.count {
                let p: Point = points[tick]
                let q: Point = points[(tick + 1) % points.count]
                let doubled: Int64 = Int64(p.x) * Int64(q.y) - Int64(q.x) * Int64(p.y)
                areas[invSector(p)] += doubled
                total += doubled
            }
            var shares: [Int] = []
            for area in areas {
                if total <= 0 || area <= 0 {
                    shares.append(0)
                } else {
                    shares.append(Int(area * 1000 / total))
                }
            }
            return shares
        }

        /// Whether `planet` is struck by the segment a → b, independently: the squared distance from the centre to
        /// the closest point of the segment below the squared radius, the interior case by Lagrange's identity.
        static func invTouches(_ planet: Planet, _ a: Point, _ b: Point) -> Bool {
            let cx: Int64 = Int64(planet.x) * 256
            let cy: Int64 = Int64(planet.y) * 256
            let r: Int64 = Int64(planet.radius) * 256
            let dx: Int64 = Int64(b.x) - Int64(a.x)
            let dy: Int64 = Int64(b.y) - Int64(a.y)
            let wx: Int64 = cx - Int64(a.x)
            let wy: Int64 = cy - Int64(a.y)
            let length2: Int64 = dx * dx + dy * dy
            let dot: Int64 = wx * dx + wy * dy
            let toA: Int64 = wx * wx + wy * wy
            if length2 == 0 || dot <= 0 { return toA < r * r }
            if dot >= length2 {
                let ux: Int64 = cx - Int64(b.x)
                let uy: Int64 = cy - Int64(b.y)
                return ux * ux + uy * uy < r * r
            }
            return toA * length2 - dot * dot < r * r * length2
        }

        /// The event tick of `target` on `points`, independently.
        static func invEventTick(_ target: Target, _ points: [Point]) -> Int {
            switch target.kind {
            case .periapsis: return 0
            case .apoapsis: return points.count / 2
            case .sweep:
                for tick in 0..<points.count where invSector(points[tick]) == target.sector { return tick }
                return points.count
            }
        }

        /// The failure of a play of `orbit` against `period`, `planets` and `targets` by an independent judge
        /// (clarification Q3) on the kernel's integer positions; nil when it wins.
        static func invJudge(period: Int, planets: [Planet], targets: [Target], orbit: Orbit) -> Failure? {
            let points: [Point] = Sky.positions(orbit, period: period).points
            for tick in 0..<period {
                for index in 0..<planets.count
                where invTouches(planets[index], points[tick], points[(tick + 1) % period]) {
                    return .contact(planet: index, tick: tick)
                }
            }
            let shares: [Int] = invShares(points)
            var previous: Int = -1
            for index in 0..<targets.count {
                let target: Target = targets[index]
                let tick: Int = invEventTick(target, points)
                if index > 0 && tick < previous { return .order(target: index, tick: tick) }
                previous = tick
                switch target.kind {
                case .sweep:
                    let share: Int = shares[target.sector]
                    if share < target.low || share > target.high {
                        return .share(target: index, tick: tick, share: share)
                    }
                case .periapsis, .apoapsis:
                    let periapsis: Bool = target.kind == .periapsis
                    let sector: Int = periapsis ? orbit.direction / 3 : ((orbit.direction + 12) / 3) % 8
                    let k: Int = orbit.eccentricity
                    let distance: Int = periapsis ? orbit.size * (20 - k) : orbit.size * (20 + k)
                    if sector != target.sector { return .apsisSector(target: index, sector: sector) }
                    if distance < target.low || distance > target.high {
                        return .apsisDistance(target: index, distance: distance)
                    }
                }
            }
            return nil
        }

        /// The independent judge of `orbit` in `level`.
        static func invJudge(_ level: Level, orbit: Orbit) -> Failure? {
            invJudge(period: level.period, planets: level.planets, targets: level.targets, orbit: orbit)
        }
    }

    // MARK: INV-01 Time

    @Test func testApsidesWorkshopTimeBoundary() throws {
        // Direct boundary: the circle starts at (6144, 0) at tick 0 and is at (−6144, 0) at tick T/2 = 8; the winner's
        // periapsis (tick 0) lies 6 lattice units out, its apoapsis (tick 8) 42 lattice units out.
        let level: Level = try Inv.hand()
        var play: Play = try Inv.playing(level)
        #expect(play.report.positions.count == level.period)
        #expect(play.report.positions[0] == Point(x: 6_144, y: 0))
        #expect(play.report.positions[8] == Point(x: -6_144, y: 0))
        try play.apply(.periapsis(15, 0), expecting: play.fingerprint)
        #expect(play.report.positions[0] == Point(x: 1_536, y: 0))
        #expect(play.report.positions[8] == Point(x: -10_752, y: 0))
        #expect(play.report.largestResidual <= Fixed.residualBound)
        // Positions depend only on the tick and the orbit: tick 2t of 2T ticks is tick t of T ticks, and planets,
        // targets and the level's other values never move them.
        let single: [Point] = Sky.positions(Inv.winner, period: 16).points
        let double: [Point] = Sky.positions(Inv.winner, period: 32).points
        #expect(single == play.report.positions)
        for tick in 0..<16 { #expect(double[2 * tick] == single[tick]) }
        let crowded: Report = Sky.report(period: 16, planets: [Planet(x: 6, y: 0, radius: 1)],
                                         targets: [.sweep(sector: 5, low: 0, high: 1000)], orbit: Inv.winner)
        #expect(crowded.positions == single)
        // Pauses and reads between the same actions change nothing; an idle play spends nothing and never fails.
        let actions: [Action] = [.size(30), .periapsis(15, 0)]
        let direct: Play = try Inv.played(level, actions)
        var slow: Play = try Inv.playing(level)
        for action in actions {
            for _ in 0..<3 {
                try slow.handle(.pause)
                _ = level.progressDescription(report: slow.report, orbit: slow.orbit, actionsLeft: slow.actionsLeft)
                try slow.handle(.resume)
            }
            try slow.apply(action, expecting: slow.fingerprint)
        }
        #expect(slow.fingerprint == direct.fingerprint)
        #expect(slow.report == direct.report && slow.orbit == direct.orbit)
        #expect(slow.actionsSpent == direct.actionsSpent)
        var idle: Play = try Inv.playing(level)
        for _ in 0..<10 {
            try idle.handle(.pause)
            try idle.handle(.resume)
        }
        #expect(idle.actionsSpent == 0 && idle.failure == nil && idle.stage == .playing)
        #expect(idle.report == level.startReport && idle.orbit == level.orbit)

        // Seeded neighbours: random valid orbits on the fixtures' periods T agree with the same orbit at 2T on every
        // even tick, every residual stays within the bound, and the fixtures' planets and targets never move them.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var compared: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            let period: Int = fixture.level.period
            let orbit: Orbit = Inv.randomOrbit(&random)
            let solved: (points: [Point], largestResidual: Int64) = Sky.positions(orbit, period: period)
            #expect(solved.points.count == period)
            #expect(solved.largestResidual >= 0 && solved.largestResidual <= Fixed.residualBound)
            let doubled: [Point] = Sky.positions(orbit, period: 2 * period).points
            for tick in 0..<period { #expect(doubled[2 * tick] == solved.points[tick]) }
            #expect(Sky.report(fixture.level, orbit: orbit).positions == solved.points)
            #expect(Sky.report(period: period, planets: [], targets: [Inv.handTarget], orbit: orbit).positions
                == solved.points)
            #expect(Sky.positions(orbit, period: period).points == solved.points)
            compared += 1
        }
        #expect(compared == 24)
        // No clock, time interval or floating-point value in the kernel sources.
        let tokens: [String] = ["Da" + "te(", "Continuous" + "Clock", "Suspending" + "Clock", "Time" + "Interval",
                                "CFAbsolute" + "Time", "Dispatch" + "Time", "Dou" + "ble", "Flo" + "at"]
        for source in try Inv.kernelSources() {
            for line in Inv.codeLines(source.text) {
                for token in tokens { #expect(!line.contains(token), "\(source.name): \(token)") }
            }
        }
    }

    // MARK: INV-02 Input budget

    @Test func testApsidesWorkshopInputbudgetBoundary() throws {
        // Direct boundary: budget 1. The tuning spends the only action; the next valid tuning is refused `budget`, an
        // unchanged, out-of-range or orbit-breaking one `action` (action before budget), a stale fingerprint `stale`;
        // the play is free.
        let level: Level = try Inv.hand(budget: 1)
        var loading: Play = Play(level: level)
        #expect(Inv.refusal { () throws(Refusal) in try loading.apply(.size(99), expecting: Inv.staleFingerprint) }
            == .stage)
        var play: Play = try Inv.playing(level)
        #expect(play.actionsLeft == 1)
        try play.apply(.periapsis(15, 0), expecting: play.fingerprint)
        #expect(play.actionsSpent == 1 && play.actionsLeft == 0 && play.orbit == Inv.winner)
        let spent: Play = play
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.size(36), expecting: play.fingerprint) }
            == .budget)
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.size(37), expecting: play.fingerprint) }
            == .action("invalid orbit"))
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.size(11), expecting: play.fingerprint) }
            == .action("invalid orbit"))
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.periapsis(15, 0), expecting: play.fingerprint)
        }))
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.size(7), expecting: play.fingerprint)
        }))
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.periapsis(16, 0), expecting: play.fingerprint)
        }))
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in
            try play.apply(.periapsis(15, 24), expecting: play.fingerprint)
        }))
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.size(30), expecting: Inv.staleFingerprint) }
            == .stale)
        #expect(play == spent)
        try play.apply(.play, expecting: play.fingerprint)
        #expect(play.actionsSpent == 1 && play.stage == .won)
        #expect(Inv.refusal { () throws(Refusal) in try play.apply(.play, expecting: play.fingerprint) } == .stage)
        // With actions left, the orbits on the star and sky bounds are accepted and one step beyond refused.
        var bounds: Play = try Inv.played(try Inv.hand(budget: 4), [.periapsis(15, 0)])
        let atWinner: Play = bounds
        #expect(Inv.refusal { () throws(Refusal) in try bounds.apply(.size(11), expecting: bounds.fingerprint) }
            == .action("invalid orbit"))
        #expect(Inv.refusal { () throws(Refusal) in try bounds.apply(.size(37), expecting: bounds.fingerprint) }
            == .action("invalid orbit"))
        #expect(bounds == atWinner)
        try bounds.apply(.size(12), expecting: bounds.fingerprint)
        #expect(bounds.orbit.periapsisDistance == 60 && bounds.actionsSpent == 2)
        try bounds.apply(.size(36), expecting: bounds.fingerprint)
        #expect(bounds.orbit.apoapsisDistance == 1_260 && bounds.actionsSpent == 3)

        // Seeded neighbours: a budget of exactly the needed tunings wins, one less is refused on the last tuning, one
        // more leaves an action; random actions are accepted exactly when the independent checks allow them, spend 1
        // per accepted tuning and nothing otherwise.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var tight: Int = 0
        var refusedAction: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            let changes: [Action] = Inv.route(from: fixture.level.orbit, to: fixture.winning)
            let needed: Int = changes.count
            #expect(needed >= 1)
            let exact: Level = try Inv.variant(fixture.level, budget: needed)
            var won: Play = try Inv.played(exact, changes)
            #expect(won.actionsLeft == 0)
            try won.apply(.play, expecting: won.fingerprint)
            #expect(won.stage == .won && won.actionsSpent == needed)
            if needed + 1 <= Level.budgets.upperBound {
                let roomy: Level = try Inv.variant(fixture.level, budget: needed + 1)
                let left: Play = try Inv.played(roomy, changes)
                #expect(left.actionsLeft == 1)
            }
            if needed - 1 >= Level.budgets.lowerBound {
                let short: Level = try Inv.variant(fixture.level, budget: needed - 1)
                var cut: Play = try Inv.played(short, Array(changes.dropLast()))
                let before: Play = cut
                let last: Action = changes[changes.count - 1]
                #expect(Inv.refusal { () throws(Refusal) in try cut.apply(last, expecting: cut.fingerprint) }
                    == .budget)
                #expect(cut == before)
                try cut.apply(.play, expecting: cut.fingerprint)
                #expect(cut.actionsSpent == needed - 1)
                #expect(cut.failure == Inv.invJudge(short, orbit: cut.orbit))
                tight += 1
            }
            var walker: Play = try Inv.playing(fixture.level)
            for _ in 0..<12 {
                if walker.stage != .playing { break }
                let action: Action = Inv.invAction(walker, random: &random)
                let spentBefore: Int = walker.actionsSpent
                let checks: Bool = Inv.invAccepts(walker.orbit, action)
                let expected: Bool = action == .play || (checks && walker.actionsLeft > 0)
                let copy: Play = walker
                let refused: Refusal? = Inv.refusal { () throws(Refusal) in
                    try walker.apply(action, expecting: walker.fingerprint)
                }
                #expect((refused == nil) == expected)
                if refused != nil {
                    #expect(walker == copy)
                    if checks {
                        #expect(refused == .budget)
                    } else {
                        #expect(Inv.isAction(refused))
                        refusedAction += 1
                    }
                } else if action == .play {
                    #expect(walker.actionsSpent == spentBefore)
                } else {
                    #expect(walker.actionsSpent == spentBefore + 1)
                    #expect(walker.orbit == Inv.tuned(copy.orbit, action))
                }
                #expect(walker.actionsLeft >= 0 && walker.actionsLeft <= fixture.level.budget)
            }
        }
        #expect(tight > 0)
        #expect(refusedAction > 0)
    }

    // MARK: INV-03 Goal

    @Test func testApsidesWorkshopGoalBoundary() throws {
        // Direct boundary: the winner sweeps 3.6 % of sector 0 (inside 0.0 … 10.0 %, a win); the circle sweeps
        // 12.5 % (a failure). A share exactly on a band bound is inside; one unit beyond is outside.
        let level: Level = try Inv.hand()
        let won: Play = try Inv.played(level, [.periapsis(15, 0), .play])
        #expect(won.stage == .won && won.failure == nil && won.report.met == 1 && won.report.wins)
        let failed: Play = try Inv.played(level, [.play])
        #expect(failed.stage == .failed && failed.report.met == 0)
        #expect(failed.failure == .share(target: 0, tick: 0, share: 125))
        #expect(Inv.invJudge(level, orbit: Inv.winner) == nil)
        let share: Int = won.report.shares[0]
        #expect(share == 36)
        let bands: [(low: Int, high: Int, wins: Bool)] = [(share, 100, true), (share + 1, 100, false),
                                                           (0, share, true), (0, share - 1, false)]
        for band in bands {
            let targets: [Target] = [.sweep(sector: 0, low: band.low, high: band.high)]
            let report: Report = Sky.report(period: 16, planets: [], targets: targets, orbit: Inv.winner)
            #expect(report.wins == band.wins)
            #expect(report.failure == Inv.invJudge(period: 16, planets: [], targets: targets, orbit: Inv.winner))
        }
        // Every target met but a planet struck: no win. Every target met but out of order: no win.
        let struck: Level = try Inv.hand(planets: [Planet(x: 6, y: 0, radius: 1)])
        #expect(Sky.report(struck, orbit: Inv.winner).failure == .contact(planet: 0, tick: 0))
        let inOrder: [Target] = [Inv.handTarget, .sweep(sector: 4, low: 0, high: 1000)]
        let reversed: [Target] = [.sweep(sector: 4, low: 0, high: 1000), Inv.handTarget]
        let ordered: Report = Sky.report(period: 16, planets: [], targets: inOrder, orbit: Inv.winner)
        #expect(ordered.wins && ordered.met == 2)
        let unordered: Report = Sky.report(period: 16, planets: [], targets: reversed, orbit: Inv.winner)
        #expect(unordered.failure == .order(target: 1, tick: 0) && unordered.met == 1)
        for direction in 0..<24 {
            let orbit: Orbit = Orbit(size: 24, eccentricity: 15, direction: direction)
            #expect(Sky.report(level, orbit: orbit).failure == Inv.invJudge(level, orbit: orbit))
        }

        // Seeded neighbours: the known orbits win; random orbits win exactly when the independent judge says so; a
        // reversed target list is judged the same way; a target list cut to a prefix keeps the known orbit winning.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var reversedLosses: Int = 0
        var reversedTried: Int = 0
        for fixture in Inv.fixtures {
            let level: Level = fixture.level
            var actions: [Action] = Inv.route(from: level.orbit, to: fixture.winning)
            actions.append(.play)
            let known: Play = try Inv.runOf(level, orbit: fixture.winning)
            #expect(known.stage == .won && known.report.met == level.targets.count)
            #expect(Inv.invJudge(level, orbit: fixture.winning) == nil)
            #expect(actions.count <= level.budget + 1)
            let orbit: Orbit = Inv.randomOrbit(&random)
            let run: Play = try Inv.runOf(level, orbit: orbit)
            let judged: Failure? = Inv.invJudge(level, orbit: orbit)
            #expect(run.failure == judged)
            #expect((run.stage == .won) == (judged == nil))
            if level.targets.count >= 2 {
                var flipped: [Target] = []
                var index: Int = level.targets.count - 1
                while index >= 0 {
                    flipped.append(level.targets[index])
                    index -= 1
                }
                let report: Report = Sky.report(period: level.period, planets: level.planets, targets: flipped,
                                                orbit: fixture.winning)
                let flippedJudge: Failure? = Inv.invJudge(period: level.period, planets: level.planets,
                                                          targets: flipped, orbit: fixture.winning)
                #expect(report.failure == flippedJudge)
                reversedTried += 1
                if flippedJudge != nil { reversedLosses += 1 }
                let prefix: [Target] = Array(level.targets.prefix(level.targets.count - 1))
                #expect(Sky.report(period: level.period, planets: level.planets, targets: prefix,
                                   orbit: fixture.winning).wins)
            }
        }
        #expect(reversedTried > 0)
        #expect(reversedLosses > 0)
    }

    // MARK: INV-04 Repeatability

    @Test func testApsidesWorkshopRepeatabilityBoundary() throws {
        // Direct boundary: the same inputs on two plays and through replay give the same records and fingerprints.
        let level: Level = try Inv.hand()
        let actions: [Action] = [.size(30), .size(24), .periapsis(15, 0), .play]
        let first: Play = try Inv.played(level, actions)
        let second: Play = try Inv.played(level, actions)
        #expect(first == second)
        #expect(first.records == second.records && first.fingerprint == second.fingerprint)
        #expect(first.report == second.report && first.stage == .won)
        let replayed: Play = try Play.replay(level: level, records: first.records)
        #expect(replayed.records == first.records && replayed.fingerprint == first.fingerprint)
        #expect(replayed.stage == first.stage && replayed.orbit == first.orbit)
        // The trace of another level (another seed) and a trace with a record removed are refused.
        let other: Level = try Inv.hand(id: "inv-other", seed: 7)
        #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in
            _ = try Play.replay(level: other, records: first.records)
        }))
        var gapped: [Record] = first.records
        var removable: Int = -1
        for index in gapped.indices where gapped[index].action == .size(30) { removable = index }
        #expect(removable >= 0 && removable < gapped.count - 1)
        if removable >= 0 {
            gapped.remove(at: removable)
            #expect(Inv.refusal { () throws(Refusal) in _ = try Play.replay(level: level, records: gapped) } != nil)
        }

        // Seeded neighbours: seeded walks repeated from the same generator state are equal and replay exactly; every
        // prefix of a trace replays to the fingerprint its last record names.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures.prefix(20) {
            let saved: SeededRandom = random
            let a: Play = try Inv.invWalk(fixture.level, steps: 24, random: &random)
            var again: SeededRandom = saved
            let b: Play = try Inv.invWalk(fixture.level, steps: 24, random: &again)
            #expect(a == b)
            #expect(again == random)
            let back: Play = try Play.replay(level: fixture.level, records: a.records)
            #expect(back.fingerprint == a.fingerprint && back.records == a.records && back.report == a.report)
            if a.records.count >= 2 {
                let cut: Int = random.int(1...(a.records.count - 1))
                let prefix: [Record] = Array(a.records.prefix(cut))
                let partial: Play = try Play.replay(level: fixture.level, records: prefix)
                #expect(partial.fingerprint == prefix[prefix.count - 1].next)
            }
        }
    }

    // MARK: INV-05 Undo

    @Test func testApsidesWorkshopUndoBoundary() throws {
        // Direct boundary: undo restores the exact earlier fingerprint, redo the later one; a new action clears redo.
        let level: Level = try Inv.hand()
        var play: Play = try Inv.playing(level)
        #expect(!play.canUndo)
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in try play.undo() }))
        let start: String = play.fingerprint
        let startReport: Report = play.report
        try play.apply(.periapsis(15, 0), expecting: play.fingerprint)
        let after: String = play.fingerprint
        try play.undo()
        #expect(play.fingerprint == start && play.orbit == Inv.circle && play.actionsSpent == 0)
        #expect(play.report == startReport && play.canRedo)
        try play.redo()
        #expect(play.fingerprint == after && play.orbit == Inv.winner && play.actionsSpent == 1)
        try play.undo()
        try play.apply(.size(30), expecting: play.fingerprint)
        #expect(!play.canRedo)
        #expect(Inv.isAction(Inv.refusal { () throws(Refusal) in try play.redo() }))
        // A failed play returns to playing with the orbit before it.
        var failing: Play = try Inv.playing(level)
        let beforePlay: String = failing.fingerprint
        try failing.apply(.play, expecting: failing.fingerprint)
        #expect(failing.stage == .failed && failing.canUndo)
        try failing.undo()
        #expect(failing.stage == .playing && failing.failure == nil && failing.orbit == Inv.circle)
        #expect(failing.fingerprint == beforePlay)
        // A won level is final.
        var won: Play = try Inv.played(level, [.periapsis(15, 0), .play])
        #expect(won.stage == .won && !won.canUndo)
        #expect(Inv.refusal { () throws(Refusal) in try won.undo() } == .stage)
        // Undo while paused stays paused.
        var paused: Play = try Inv.played(level, [.periapsis(15, 0)])
        try paused.handle(.pause)
        try paused.undo()
        #expect(paused.stage == .paused && paused.orbit == Inv.circle && paused.actionsSpent == 0)

        // Seeded neighbours: every accepted action of a seeded walk undoes to the exact earlier state and redoes to the
        // exact later one.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var checked: Int = 0
        for fixture in Inv.fixtures.prefix(24) {
            var walker: Play = try Inv.playing(fixture.level)
            for _ in 0..<10 {
                if walker.stage != .playing { break }
                let action: Action = Inv.invAction(walker, random: &random)
                let earlier: Play = walker
                let refused: Refusal? = Inv.refusal { () throws(Refusal) in
                    try walker.apply(action, expecting: walker.fingerprint)
                }
                if refused != nil { continue }
                let later: Play = walker
                if walker.stage == .won {
                    #expect(!walker.canUndo)
                    break
                }
                try walker.undo()
                #expect(walker.fingerprint == earlier.fingerprint && walker.orbit == earlier.orbit)
                #expect(walker.actionsSpent == earlier.actionsSpent && walker.report == earlier.report)
                #expect(walker.failure == earlier.failure && walker.stage == .playing)
                try walker.redo()
                #expect(walker.fingerprint == later.fingerprint && walker.orbit == later.orbit)
                #expect(walker.actionsSpent == later.actionsSpent && walker.stage == later.stage)
                checked += 1
                if walker.stage == .failed { try walker.undo() }
            }
        }
        #expect(checked > 24)
    }

    // MARK: INV-07 Failure honesty

    @Test func testApsidesWorkshopFailurehonestyBoundary() throws {
        // Direct boundary: one level per failure code, each named with its real planet or target and tick (or sector
        // or distance), equal to the independent judge, the orbit and actions spent unchanged by the play.
        let cases: [(level: Level, failure: Failure, code: String)] = [
            (try Inv.hand(), .share(target: 0, tick: 0, share: 125), "share"),
            (try Inv.hand(planets: [Planet(x: 24, y: 0, radius: 2), Planet(x: -24, y: 0, radius: 2)]),
             .contact(planet: 0, tick: 0), "contact"),
            (try Inv.hand(targets: [.sweep(sector: 4, low: 0, high: 1000), .sweep(sector: 0, low: 0, high: 1000)]),
             .order(target: 1, tick: 0), "order"),
            (try Inv.hand(targets: [Target(kind: .periapsis, sector: 3, low: 0, high: 1280)]),
             .apsisSector(target: 0, sector: 0), "apsis-sector"),
            (try Inv.hand(targets: [Target(kind: .periapsis, sector: 0, low: 0, high: 100)]),
             .apsisDistance(target: 0, distance: 480), "apsis-distance"),
        ]
        for item in cases {
            var play: Play = try Inv.playing(item.level)
            let orbitBefore: Orbit = play.orbit
            let reportBefore: Report = play.report
            try play.apply(.play, expecting: play.fingerprint)
            #expect(play.stage == .failed)
            #expect(play.failure == item.failure)
            #expect(play.failure?.code == item.code)
            #expect(Inv.invJudge(item.level, orbit: orbitBefore) == item.failure)
            #expect(play.orbit == orbitBefore && play.actionsSpent == 0 && play.report == reportBefore)
            #expect(play.report.failure == play.failure)
            #expect(play.records.last?.next == play.fingerprint)
            #expect(play.records.last?.action == .play)
            try play.undo()
            #expect(play.stage == .playing && play.failure == nil && play.orbit == orbitBefore)
        }
        // The words name the planet and the tick of a contact, and the share and band of a missed sweep.
        let contactLevel: Level = cases[1].level
        let contactWords: String = contactLevel.progressDescription(report: contactLevel.startReport,
                                                                    orbit: contactLevel.orbit, actionsLeft: 3)
        #expect(contactWords.contains("planet 0") && contactWords.contains("tick 0"))
        let shareLevel: Level = cases[0].level
        let shareWords: String = shareLevel.targetDescription(0, report: shareLevel.startReport,
                                                              orbit: shareLevel.orbit)
        #expect(shareWords == "sector 0 swept 12.5 %, needs 0.0 % to 10.0 %")
        // Refusals name their reasons.
        var refusing: Play = try Inv.playing(try Inv.hand(budget: 1))
        let unknown: Refusal? = Inv.refusal { () throws(Refusal) in
            try refusing.apply(.size(64), expecting: refusing.fingerprint)
        }
        #expect(unknown?.reasonCode == "r02-g18.action")
        try refusing.apply(.size(30), expecting: refusing.fingerprint)
        let broke: Refusal? = Inv.refusal { () throws(Refusal) in
            try refusing.apply(.size(31), expecting: refusing.fingerprint)
        }
        #expect(broke?.reasonCode == "r02-g18.budget")
        let stale: Refusal? = Inv.refusal { () throws(Refusal) in
            try refusing.apply(.play, expecting: Inv.staleFingerprint)
        }
        #expect(stale?.reasonCode == "r02-g18.stale")
        var loading: Play = Play(level: shareLevel)
        let early: Refusal? = Inv.refusal { () throws(Refusal) in try loading.apply(.play, expecting: "") }
        #expect(early?.reasonCode == "r02-g18.stage")

        // Seeded neighbours: random orbits on the fixtures fail with exactly the independent judge's failure, naming a
        // real planet or target and a tick inside the revolution, the orbit unchanged by the play.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var codes: Set<String> = []
        for fixture in Inv.fixtures {
            let level: Level = fixture.level
            for _ in 0..<3 {
                let orbit: Orbit = Inv.randomOrbit(&random)
                let run: Play = try Inv.runOf(level, orbit: orbit)
                let judged: Failure? = Inv.invJudge(level, orbit: orbit)
                #expect(run.failure == judged)
                #expect(run.orbit == orbit)
                #expect(run.stage == (judged == nil ? .won : .failed))
                switch judged {
                case .contact(let planet, let tick):
                    #expect(planet >= 0 && planet < level.planets.count && tick >= 0 && tick < level.period)
                case .order(let target, let tick), .share(let target, let tick, _):
                    #expect(target >= 0 && target < level.targets.count && tick >= 0 && tick <= level.period)
                case .apsisSector(let target, let sector):
                    #expect(target >= 0 && target < level.targets.count && sector >= 0 && sector < 8)
                case .apsisDistance(let target, let distance):
                    #expect(target >= 0 && target < level.targets.count && distance >= 60 && distance <= 1280)
                case nil:
                    break
                }
                if let judged { codes.insert(judged.code) }
            }
        }
        #expect(!codes.isEmpty)
        #expect(codes.isSubset(of: ["contact", "order", "share", "apsis-sector", "apsis-distance"]))
    }

    // MARK: INV-08 Stability

    @Test func testApsidesWorkshopStabilityBoundary() throws {
        // Direct boundary: the extreme orbits in every direction at the longest period stay within the sky bound
        // (reached exactly by an apoapsis of 1280 twentieths), every residual within 2^−22, every share in 0 … 1000
        // summing to 992 … 1000; one step beyond is invalid; the extreme level builds and does not win.
        let extremes: [Orbit] = [Orbit(size: 40, eccentricity: 12, direction: 0),
                                 Orbit(size: 36, eccentricity: 15, direction: 0),
                                 Orbit(size: 48, eccentricity: 6, direction: 0),
                                 Orbit(size: 12, eccentricity: 15, direction: 0),
                                 Orbit(size: 8, eccentricity: 0, direction: 0)]
        let beyond: [Orbit] = [Orbit(size: 41, eccentricity: 12, direction: 0),
                               Orbit(size: 37, eccentricity: 15, direction: 0),
                               Orbit(size: 48, eccentricity: 7, direction: 0),
                               Orbit(size: 11, eccentricity: 15, direction: 0),
                               Orbit(size: 7, eccentricity: 0, direction: 0)]
        for orbit in extremes { #expect(orbit.isValid && Inv.invValid(orbit)) }
        for orbit in beyond { #expect(!orbit.isValid && !Inv.invValid(orbit)) }
        var largest: Int = 0
        for base in extremes {
            for direction in 0..<24 {
                let orbit: Orbit = Orbit(size: base.size, eccentricity: base.eccentricity, direction: direction)
                let solved: (points: [Point], largestResidual: Int64) = Sky.positions(orbit, period: 96)
                #expect(solved.largestResidual >= 0 && solved.largestResidual <= Fixed.residualBound)
                for p in solved.points {
                    #expect(abs(p.x) <= Inv.skyBound && abs(p.y) <= Inv.skyBound)
                    largest = max(largest, max(abs(p.x), abs(p.y)))
                }
                let shares: [Int] = Sky.shares(solved.points)
                var sum: Int = 0
                for share in shares {
                    #expect(share >= 0 && share <= 1000)
                    sum += share
                }
                #expect(sum >= 1000 - 8 && sum <= 1000)
            }
        }
        #expect(largest == Inv.skyBound)
        let extreme: Level = try Inv.extreme()
        #expect(extreme.planets.count == 6 && extreme.targets.count == 6 && extreme.period == 96)
        #expect(extreme.budget == 24 && extreme.id.count == 64 && !extreme.startReport.wins)

        // Seeded neighbours: 500 random valid orbits at random even periods 16 … 96 stay bounded with shares equal to
        // the independent quadrature; at least 500 seeded play states on the extreme level and the fixtures stay
        // bounded.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for _ in 0..<500 {
            let orbit: Orbit = Inv.randomOrbit(&random)
            let period: Int = 2 * random.int(8...48)
            let solved: (points: [Point], largestResidual: Int64) = Sky.positions(orbit, period: period)
            #expect(solved.points.count == period)
            #expect(solved.largestResidual >= 0 && solved.largestResidual <= Fixed.residualBound)
            for p in solved.points { #expect(abs(p.x) <= Inv.skyBound && abs(p.y) <= Inv.skyBound) }
            let shares: [Int] = Sky.shares(solved.points)
            #expect(shares == Inv.invShares(solved.points))
            var sum: Int = 0
            for share in shares {
                #expect(share >= 0 && share <= 1000)
                sum += share
            }
            #expect(sum >= 1000 - 8 && sum <= 1000)
        }
        var levels: [Level] = [extreme]
        for fixture in Inv.fixtures.prefix(10) { levels.append(fixture.level) }
        var states: Int = 0
        var round: Int = 0
        while states < 500 {
            let level: Level = levels[round % levels.count]
            round += 1
            var play: Play = try Inv.playing(level)
            for _ in 0..<40 {
                let roll: Int = random.int(0...9)
                if roll == 0 {
                    _ = Inv.refusal { () throws(Refusal) in try play.undo() }
                } else if roll == 1 {
                    _ = Inv.refusal { () throws(Refusal) in try play.redo() }
                } else {
                    if play.stage != .playing { break }
                    let action: Action = Inv.invAction(play, random: &random)
                    _ = Inv.refusal { () throws(Refusal) in try play.apply(action, expecting: play.fingerprint) }
                }
                states += 1
                #expect(play.actionsSpent >= 0 && play.actionsSpent <= level.budget)
                #expect(play.actionsLeft >= 0 && play.actionsLeft <= level.budget)
                #expect(Inv.invValid(play.orbit))
                #expect(play.report.positions.count == level.period && play.report.shares.count == 8)
                #expect(play.report.largestResidual <= Fixed.residualBound)
                #expect(play.report.met >= 0 && play.report.met <= level.targets.count)
                #expect(play.report.eventTicks.count == level.targets.count)
                #expect(play.report.deviations.count == level.targets.count)
                for tick in play.report.eventTicks { #expect(tick >= 0 && tick <= level.period) }
                #expect(play.fingerprint.count == 64)
            }
        }
        #expect(states >= 500)
    }

    // MARK: INV-09 Save

    @Test func testApsidesWorkshopSaveBoundary() throws {
        // Direct boundary: the stored form round-trips byte for byte; newer, older, truncated and fingerprint-edited
        // forms are refused.
        let level: Level = try Inv.hand()
        let data: Data = level.encoded()
        let decoded: Level = try Level.decode(data)
        #expect(decoded == level && decoded.encoded() == data)
        let viaCodable: Level = try JSONDecoder().decode(Level.self, from: data)
        #expect(viaCodable == level)
        let text: String = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"schema\":1"))
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(Inv.refusal { () throws(Refusal) in _ = try Level.decode(newer) } == .newerSchema(2))
        let older: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0").utf8)
        #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in _ = try Level.decode(older) }))
        let truncated: Data = data.prefix(data.count / 2)
        #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in _ = try Level.decode(truncated) }))
        let marker: String = "\"fingerprint\":\""
        if let range = text.range(of: marker) {
            let digit: Character = text[range.upperBound]
            let replacement: String = digit == "0" ? "1" : "0"
            var edited: String = text
            edited.replaceSubrange(range.upperBound...range.upperBound, with: replacement)
            #expect(Inv.isMalformed(Inv.refusal { () throws(Refusal) in _ = try Level.decode(Data(edited.utf8)) }))
        } else {
            Issue.record("the stored form holds no fingerprint")
        }
        // A stored record trace replays to the same play.
        let played: Play = try Inv.played(level, [.size(30), .periapsis(15, 0)])
        let trace: Data = try JSONEncoder().encode(played.records)
        let restored: [Record] = try JSONDecoder().decode([Record].self, from: trace)
        let back: Play = try Play.replay(level: level, records: restored)
        #expect(back.fingerprint == played.fingerprint && back.records == played.records)
        let extreme: Level = try Inv.extreme()
        #expect(try Level.decode(extreme.encoded()) == extreme)

        // Seeded neighbours: any single-byte edit of a stored fixture level is refused or decodes to the same level.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        var refused: Int = 0
        for fixture in Inv.fixtures.prefix(10) {
            let stored: Data = fixture.level.encoded()
            #expect(try Level.decode(stored) == fixture.level)
            for _ in 0..<24 {
                var bytes: [UInt8] = Array(stored)
                let position: Int = random.int(0...(bytes.count - 1))
                let value: UInt8 = UInt8(random.int(32...126))
                if bytes[position] == value { continue }
                bytes[position] = value
                do {
                    let edited: Level = try Level.decode(Data(bytes))
                    #expect(edited == fixture.level)
                } catch {
                    refused += 1
                }
            }
        }
        #expect(refused > 0)
    }

    // MARK: INV-10 Renderer purity

    @Test func testApsidesWorkshopRendererpurityBoundary() throws {
        // Direct boundary: the report equals the sky's pure function of the level and the orbit; reading names and
        // descriptions leaves the play unchanged; the play is a value type.
        let level: Level = try Inv.hand()
        var play: Play = try Inv.playing(level)
        try play.apply(.size(30), expecting: play.fingerprint)
        #expect(play.report == Sky.report(level, orbit: play.orbit))
        #expect(Sky.report(level, orbit: play.orbit) == Sky.report(level, orbit: play.orbit))
        #expect(play.report == Sky.report(period: level.period, planets: level.planets, targets: level.targets,
                                          orbit: play.orbit))
        let copy: Play = play
        let words: String = level.progressDescription(report: play.report, orbit: play.orbit,
                                                      actionsLeft: play.actionsLeft)
        #expect(words == level.progressDescription(report: play.report, orbit: play.orbit,
                                                   actionsLeft: play.actionsLeft))
        #expect(level.sectorName(3) == "sector 3")
        #expect(level.planetName(2) == "planet 2")
        for index in level.targets.indices {
            _ = level.targetDescription(index, report: play.report, orbit: play.orbit)
        }
        #expect(play == copy)
        var changed: Play = copy
        try changed.apply(.periapsis(15, 0), expecting: changed.fingerprint)
        #expect(play == copy && changed != copy)
        // The report never depends on the id, seed, difficulty, budget or tutorial.
        let others: [Level] = [try Inv.variant(level, id: "inv-renamed"), try Inv.variant(level, seed: 99),
                               try Inv.variant(level, difficulty: 5), try Inv.variant(level, budget: 24),
                               try Inv.variant(level, tutorial: true)]
        for other in others {
            #expect(Sky.report(other, orbit: Inv.winner) == Sky.report(level, orbit: Inv.winner))
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

        // Seeded neighbours: along seeded walks the report is the pure function of the level and the orbit, and a
        // level that differs only in its id gives the same reports and outcomes for the same actions.
        var random: SeededRandom = SeededRandom(seed: Inv.seed)
        for fixture in Inv.fixtures.prefix(20) {
            let renamed: Level = try Inv.variant(fixture.level, id: fixture.level.id + "-renamed")
            var a: Play = try Inv.playing(fixture.level)
            var b: Play = try Inv.playing(renamed)
            for _ in 0..<10 {
                if a.stage != .playing { break }
                let action: Action = Inv.invAction(a, random: &random)
                let refusedA: Refusal? = Inv.refusal { () throws(Refusal) in
                    try a.apply(action, expecting: a.fingerprint)
                }
                let refusedB: Refusal? = Inv.refusal { () throws(Refusal) in
                    try b.apply(action, expecting: b.fingerprint)
                }
                #expect(refusedA == refusedB)
                #expect(a.report == Sky.report(fixture.level, orbit: a.orbit))
                #expect(a.report.shares == Inv.invShares(a.report.positions))
                #expect(a.report == b.report && a.orbit == b.orbit && a.stage == b.stage)
                #expect(a.failure == b.failure && a.actionsSpent == b.actionsSpent)
                let before: Play = a
                _ = fixture.level.progressDescription(report: a.report, orbit: a.orbit, actionsLeft: a.actionsLeft)
                for index in fixture.level.targets.indices {
                    _ = fixture.level.targetDescription(index, report: a.report, orbit: a.orbit)
                }
                for index in fixture.level.planets.indices { _ = fixture.level.planetName(index) }
                #expect(a == before)
            }
        }
    }
}
