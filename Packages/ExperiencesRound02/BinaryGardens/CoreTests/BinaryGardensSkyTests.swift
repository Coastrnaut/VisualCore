// BinaryGardensSkyTests — feature 501 (R02-G21-01) T-R02G2101-003 (FR-R02G2101-003, 004, 005, 014; SC-R02G2101-003,
// 004). An independent reimplementation of the sky, written from the specification's clarifications only (the cosine
// table rebuilt from its quarter wave and symmetry rules, the positions, the milliflux law with its clamp, the five
// bands, the lethal walk over ticks 1 … 48 + E computed per world as the trailing lethal run at every walk tick, the
// cyclic comfortable window and lethal run by brute force over every start, the integrals, the bloom, the minimum
// separation and the judge order frozen/scorched → unstable → wilted/bleached), compared with the kernel on 500 seeded
// runs (125 fixtures of seed 2,501 × the start, the known winning arrangement and two random arrangements): every
// position, star share, flux, band, lethal run, window and start, integral, bloom, minimum separation and its tick and
// the outcome equal. Hand cases: a flux one milliflux either side of each of the four bounds (directly and on a run), a
// distance one unit either side of the clamp radius, a lethal run one tick either side of the tolerance (also across
// the cycle boundary, and tolerance 0), a mixed lethal-low-then-high run, a window one tick short of the requirement,
// the whole cycle comfortable and ties of equal windows, an integral one milliflux either side of each bloom bound, a
// separation one unit either side of the minimum, and the judge order. Explicit types, plain loops; each test well
// under 10 s.
import Foundation
import Testing
import VisualCoreSimulation
@testable import BinaryGardensCore

/// The independent reference of the sky.
enum BinaryGardensReference {
    /// The cosine table rebuilt from the quarter wave and the symmetry rules of the clarification.
    static let cosine: [Int] = {
        let quarter: [Int] = [1024, 1015, 989, 946, 887, 812, 724, 623, 512, 392, 265, 134, 0]
        var table: [Int] = []
        for k in 0..<48 {
            if k <= 12 {
                table.append(quarter[k])
            } else if k <= 24 {
                table.append(-quarter[24 - k])
            } else if k <= 36 {
                table.append(-quarter[k - 24])
            } else {
                table.append(quarter[48 - k])
            }
        }
        return table
    }()

    /// The non-negative residue of `x` modulo 48.
    static func mod48(_ x: Int) -> Int {
        var r: Int = x % 48
        if r < 0 { r += 48 }
        return r
    }

    /// C[k].
    static func c(_ k: Int) -> Int { cosine[mod48(k)] }

    /// S[k] = C[(k + 36) mod 48].
    static func s(_ k: Int) -> Int { cosine[mod48(k + 36)] }

    /// A star's coordinates.
    static func star(radius: Int, phase: Int, tilt: Int) -> [Int] {
        [radius * c(phase) * 1024, radius * s(phase) * c(tilt), radius * s(phase) * s(tilt)]
    }

    /// A world's coordinates.
    static func world(radius: Int, phase: Int) -> [Int] {
        [radius * c(phase) * 1024, radius * s(phase) * 1024, 0]
    }

    /// The squared distance at scale 2^40.
    static func d2(_ a: [Int], _ b: [Int]) -> Int {
        var sum: Int = 0
        for i in 0..<3 { sum += (a[i] - b[i]) * (a[i] - b[i]) }
        return sum
    }

    /// One star's milliflux.
    static func share(_ luminosity: Int, _ d2: Int, _ clamp: Int) -> Int {
        let floor: Int = clamp * clamp * 1_099_511_627_776
        let denominator: Int = d2 > floor ? d2 : floor
        return (1000 * luminosity * 1_099_511_627_776) / denominator
    }

    /// The band of `f` for `w`.
    static func band(_ f: Int, _ w: BinaryGardensWorld) -> BinaryGardensBand {
        if f > w.lethalHigh { return .lethalHigh }
        if f > w.comfortHigh { return .bright }
        if f >= w.comfortLow { return .comfortable }
        if f >= w.lethalLow { return .dim }
        return .lethalLow
    }

    /// The longest cyclic run of `flags` by brute force over every start, with the smallest start (1-based; 0 when
    /// the length is 0).
    static func longest(_ flags: [Bool]) -> (length: Int, start: Int) {
        var best: Int = 0
        var bestStart: Int = 0
        for s in 0..<48 {
            var n: Int = 0
            while n < 48 && flags[(s + n) % 48] { n += 1 }
            if n > best {
                best = n
                bestStart = s + 1
            }
        }
        return (best, bestStart)
    }

    /// The whole reference result of one arrangement.
    struct Result {
        var stars: [[[Int]]] = []
        var worlds: [[[Int]]] = []
        var shares: [[[Int]]] = []
        var flux: [[Int]] = []
        var bands: [[BinaryGardensBand]] = []
        var lethal: [Int] = []
        var window: [(Int, Int)] = []
        var integral: [Int] = []
        var bloom: [BinaryGardensBloom] = []
        var separation: Int = 0
        var separationTick: Int = 0
        var failure: BinaryGardensFailure?
    }

    /// The reference result of `arrangement` in `level`.
    static func run(_ level: BinaryGardensLevel, _ arrangement: BinaryGardensArrangement) -> Result {
        var r = Result()
        let n: Int = level.worlds.count
        r.shares = Array(repeating: [], count: n)
        r.flux = Array(repeating: [], count: n)
        r.bands = Array(repeating: [], count: n)
        for tick in 1...48 {
            var stars: [[Int]] = []
            for i in 0..<2 {
                let p: Int = mod48(arrangement.phases[i] + level.starSpeed * tick)
                stars.append(star(radius: level.ringRadii[arrangement.rings[i]], phase: p, tilt: arrangement.tilt))
            }
            r.stars.append(stars)
            var worlds: [[Int]] = []
            for j in 0..<n {
                let w: BinaryGardensWorld = level.worlds[j]
                let point: [Int] = world(radius: w.radius, phase: mod48(w.phase + w.speed * tick))
                worlds.append(point)
                let a: Int = share(level.luminosityLevels[arrangement.luminosities[0]], d2(stars[0], point),
                                   level.clampRadius)
                let b: Int = share(level.luminosityLevels[arrangement.luminosities[1]], d2(stars[1], point),
                                   level.clampRadius)
                r.shares[j].append([a, b])
                r.flux[j].append(a + b)
                r.bands[j].append(band(a + b, w))
            }
            r.worlds.append(worlds)
        }
        for j in 0..<n {
            r.lethal.append(longest(r.bands[j].map { $0 == .lethalLow || $0 == .lethalHigh }).length)
            r.window.append(longest(r.bands[j].map { $0 == .comfortable }))
            var sum: Int = 0
            for f in r.flux[j] { sum += f }
            r.integral.append(sum)
            let w: BinaryGardensWorld = level.worlds[j]
            r.bloom.append(sum < w.bloomLow ? .below : sum > w.bloomHigh ? .above : .inside)
        }
        r.separation = Int.max
        for tick in 0..<48 {
            var stars: [[Int]] = []
            for i in 0..<2 {
                let p: Int = mod48(arrangement.phases[i] + level.starSpeed * tick)
                stars.append(star(radius: level.ringRadii[arrangement.rings[i]], phase: p, tilt: arrangement.tilt))
            }
            let d: Int = d2(stars[0], stars[1])
            if d < r.separation {
                r.separation = d
                r.separationTick = tick
            }
        }
        r.failure = judge(level.worlds, tolerance: level.lethalTolerance, bands: r.bands, window: r.window.map { $0.0 },
                          integral: r.integral)
        return r
    }

    /// The reference judge: per world the first walk tick whose trailing lethal run (counted from walk tick 1)
    /// exceeds E; the smallest such tick wins, the lowest world among equals; then worlds ascending, unstable before
    /// wilted or bleached.
    static func judge(_ worlds: [BinaryGardensWorld], tolerance: Int, bands: [[BinaryGardensBand]], window: [Int],
                      integral: [Int]) -> BinaryGardensFailure? {
        var best: (tick: Int, world: Int, band: BinaryGardensBand)?
        for j in 0..<worlds.count {
            for t in 1...(48 + tolerance) {
                var run: Int = 0
                var u: Int = t
                while u >= 1 {
                    let b: BinaryGardensBand = bands[j][(u - 1) % 48]
                    if b == .lethalLow || b == .lethalHigh { run += 1 } else { break }
                    u -= 1
                }
                if run > tolerance {
                    if best == nil || t < best!.tick { best = (t, j, bands[j][(t - 1) % 48]) }
                    break
                }
            }
        }
        if let best {
            return best.band == .lethalLow ? .frozen(world: best.world, tick: best.tick)
                : .scorched(world: best.world, tick: best.tick)
        }
        for j in 0..<worlds.count {
            let w: BinaryGardensWorld = worlds[j]
            if window[j] < w.window { return .unstable(world: j, window: window[j], required: w.window) }
            if integral[j] < w.bloomLow {
                return .wilted(world: j, integral: integral[j], low: w.bloomLow, high: w.bloomHigh)
            }
            if integral[j] > w.bloomHigh {
                return .bleached(world: j, integral: integral[j], low: w.bloomLow, high: w.bloomHigh)
            }
        }
        return nil
    }
}

@Suite struct BinaryGardensSkyTests {
    typealias Sky = BinaryGardensSky
    typealias Level = BinaryGardensLevel
    typealias World = BinaryGardensWorld
    typealias Star = BinaryGardensStar
    typealias Arrangement = BinaryGardensArrangement
    typealias Ref = BinaryGardensReference

    /// Compares the kernel's report with the reference; returns the number of mismatching fields.
    static func compare(_ level: Level, _ arrangement: Arrangement) -> Int {
        let report: BinaryGardensReport = Sky.report(level, arrangement: arrangement)
        let ref: Ref.Result = Ref.run(level, arrangement)
        var misses: Int = 0
        for tick in 0..<48 {
            for i in 0..<2 {
                let p: BinaryGardensPoint = report.starPositions[tick][i]
                if [p.x, p.y, p.z] != ref.stars[tick][i] { misses += 1 }
            }
            for j in level.worlds.indices {
                let p: BinaryGardensPoint = report.worldPositions[tick][j]
                if [p.x, p.y, p.z] != ref.worlds[tick][j] { misses += 1 }
            }
        }
        for j in level.worlds.indices {
            let light: BinaryGardensWorldLight = report.worlds[j]
            if light.shares != ref.shares[j] { misses += 1 }
            if light.flux != ref.flux[j] { misses += 1 }
            if light.bands != ref.bands[j] { misses += 1 }
            if light.longestLethalRun != ref.lethal[j] { misses += 1 }
            if light.window != ref.window[j].0 || light.windowStart != ref.window[j].1 { misses += 1 }
            if light.integral != ref.integral[j] { misses += 1 }
            if light.bloom != ref.bloom[j] { misses += 1 }
        }
        if report.minimumSeparationSquared != ref.separation { misses += 1 }
        if report.minimumSeparationTick != ref.separationTick { misses += 1 }
        if report.failure != ref.failure { misses += 1 }
        return misses
    }

    /// A random well-formed arrangement of `level`.
    static func randomArrangement(_ random: inout SeededRandom, _ level: Level) -> Arrangement {
        let rings: Int = level.ringRadii.count - 1
        let levels: Int = level.luminosityLevels.count - 1
        return Arrangement(rings: [random.int(0...rings), random.int(0...rings)],
                           phases: [random.int(0...47), random.int(0...47)],
                           luminosities: [random.int(0...levels), random.int(0...levels)],
                           tilt: random.int(0...level.maxTilt))
    }

    @Test func theTableAndTheReferenceAgree() {
        #expect(Ref.cosine == Sky.cosine)
        for k in -96...96 { #expect(Ref.s(k) == Sky.sine(k)) }
    }

    @Test func kernelMatchesTheReferenceOn500SeededRuns() {
        var random = SeededRandom(seed: BinaryGardensFixture.seed)
        var runs: Int = 0
        var outcomes: Set<String> = []
        for fixture in BinaryGardensFixture.all(count: 125) {
            let level: Level = fixture.level
            let arrangements: [Arrangement] = [level.start, fixture.winning, Self.randomArrangement(&random, level),
                                               Self.randomArrangement(&random, level)]
            for arrangement in arrangements {
                #expect(Self.compare(level, arrangement) == 0, "\(level.id)")
                let report: BinaryGardensReport = Sky.report(level, arrangement: arrangement)
                outcomes.insert(report.failure?.code ?? "won")
                runs += 1
            }
        }
        #expect(runs == 500)
        #expect(outcomes.contains("won") && outcomes.count >= 3, "\(outcomes)")
    }

    /// Synthetic flux codes against the hand world's bounds 100 / 200 / 300 / 400.
    static let lethalLowFlux: Int = 50
    static let dimFlux: Int = 150
    static let comfortFlux: Int = 250
    static let brightFlux: Int = 350
    static let lethalHighFlux: Int = 450

    /// A hand world with bounds 100 / 200 / 300 / 400, window `window` and bloom band `low` … `high`.
    static func handWorld(window: Int = 1, low: Int = 0, high: Int = 9_600_000) -> World {
        World(radius: 10, phase: 0, speed: 0, lethalLow: 100, comfortLow: 200, comfortHigh: 300, lethalHigh: 400,
              window: window, bloomLow: low, bloomHigh: high)
    }

    /// The light of `world` for the 48 fluxes `flux` (all from star 1).
    static func light(_ flux: [Int], _ world: World) -> BinaryGardensWorldLight {
        Sky.light(shares: flux.map { [$0, 0] }, world: world)
    }

    /// 48 fluxes of `fill` with `overrides` at the given ticks (1 … 48).
    static func profile(_ fill: Int, _ overrides: [Int: Int] = [:]) -> [Int] {
        var flux: [Int] = Array(repeating: fill, count: 48)
        for (tick, value) in overrides { flux[tick - 1] = value }
        return flux
    }

    @Test func aFluxOneMillifluxEitherSideOfEachBound() throws {
        let w: World = Self.handWorld()
        let cases: [(Int, BinaryGardensBand)] = [
            (99, .lethalLow), (100, .dim), (101, .dim), (199, .dim), (200, .comfortable), (201, .comfortable),
            (299, .comfortable), (300, .comfortable), (301, .bright), (399, .bright), (400, .bright),
            (401, .lethalHigh), (0, .lethalLow),
        ]
        for (flux, band) in cases { #expect(Sky.band(flux, of: w) == band, "flux \(flux)") }
        // On a run: the lowest flux of a real level exactly at λ_lo is not lethal; one milliflux higher, it freezes
        // with tolerance 0 at its first tick; likewise the highest flux at λ_hi and one below it.
        let probe: Level = try BinaryGardensLevelTests.hand(worlds: [BinaryGardensLevelTests.wide(radius: 7, speed: 2)])
        let flux: [Int] = probe.startReport.worlds[0].flux
        let low: Int = flux.min() ?? 0
        let high: Int = flux.max() ?? 0
        #expect(low + 4 < high)
        let firstLow: Int = (flux.firstIndex(of: low) ?? 0) + 1
        let firstHigh: Int = (flux.firstIndex(of: high) ?? 0) + 1
        func failure(lethalLow: Int, lethalHigh: Int) throws -> BinaryGardensFailure? {
            let world = World(radius: 7, phase: 0, speed: 2, lethalLow: lethalLow, comfortLow: lethalLow + 1,
                              comfortHigh: lethalHigh - 1, lethalHigh: lethalHigh, window: 1, bloomLow: 0,
                              bloomHigh: 9_600_000)
            return try BinaryGardensLevelTests.hand(worlds: [world]).startReport.failure
        }
        #expect(try failure(lethalLow: low, lethalHigh: high) == nil)
        #expect(try failure(lethalLow: low + 1, lethalHigh: high) == .frozen(world: 0, tick: firstLow))
        #expect(try failure(lethalLow: low, lethalHigh: high - 1) == .scorched(world: 0, tick: firstHigh))
        // The comfortable bounds: a window of 48 needs c_lo ≤ min and c_hi ≥ max.
        func window(comfortLow: Int, comfortHigh: Int) throws -> Int {
            let world = World(radius: 7, phase: 0, speed: 2, lethalLow: 0, comfortLow: comfortLow,
                              comfortHigh: comfortHigh, lethalHigh: 200_000, window: 1, bloomLow: 0,
                              bloomHigh: 9_600_000)
            return try BinaryGardensLevelTests.hand(worlds: [world]).startReport.worlds[0].window
        }
        #expect(try window(comfortLow: low, comfortHigh: high) == 48)
        #expect(try window(comfortLow: low + 1, comfortHigh: high) < 48)
        #expect(try window(comfortLow: low, comfortHigh: high - 1) < 48)
    }

    @Test func aDistanceOneUnitEitherSideOfTheClampRadius() throws {
        // Star 1 on ring ρ = 4 at phase 0; a world co-rotating at the star speed at radius 4 + d, phase 0, untilted:
        // the distance is d units on the axes and the table's C² + S² makes it slightly different off them.
        func shares(distance: Int, clamp: Int) throws -> [Int] {
            let world = World(radius: 4 + distance, phase: 0, speed: 1, lethalLow: 0, comfortLow: 1,
                              comfortHigh: 199_999, lethalHigh: 200_000, window: 1, bloomLow: 0, bloomHigh: 9_600_000)
            let level: Level = try BinaryGardensLevelTests.hand(ringRadii: [4, 40], phases: [0, 24],
                                                                luminosities: [64], clampRadius: clamp,
                                                                worlds: [world])
            return level.startReport.worlds[0].shares.map { $0[0] }
        }
        for clamp in 2...7 {
            let clamped: Int = 64_000 / (clamp * clamp)
            let inside: [Int] = try shares(distance: clamp - 1, clamp: clamp)
            let at: [Int] = try shares(distance: clamp, clamp: clamp)
            let outside: [Int] = try shares(distance: clamp + 1, clamp: clamp)
            #expect(inside.allSatisfy { $0 == clamped }, "clamp \(clamp) inside")
            #expect(at.allSatisfy { $0 <= clamped } && at[11] == clamped && at[47] == clamped, "clamp \(clamp) at")
            #expect(outside.allSatisfy { $0 < clamped }, "clamp \(clamp) outside")
        }
        // A world passing through a star receives the clamped maximum, never a division by zero.
        #expect(Sky.flux(luminosity: 64, squaredDistance: 0, clampRadius: 1) == 64_000)
        let through: [Int] = try shares(distance: 0, clamp: 1)
        #expect(through.allSatisfy { $0 == 64_000 })
    }

    @Test func aLethalRunOneTickEitherSideOfTheTolerance() {
        let w: World = Self.handWorld()
        // Three lethal-low ticks 10 … 12: tolerance 3 survives, 2 freezes at tick 12.
        let three: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux, [10: 50, 11: 50, 12: 50]), w)
        #expect(three.longestLethalRun == 3)
        #expect(Sky.judge(worlds: [w], tolerance: 3, lights: [three]) == nil)
        #expect(Sky.judge(worlds: [w], tolerance: 2, lights: [three]) == .frozen(world: 0, tick: 12))
        #expect(Sky.judge(worlds: [w], tolerance: 4, lights: [three]) == nil)
        // Tolerance 0: a single lethal tick fails.
        let one: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux, [5: 450]), w)
        #expect(Sky.judge(worlds: [w], tolerance: 0, lights: [one]) == .scorched(world: 0, tick: 5))
        #expect(Sky.judge(worlds: [w], tolerance: 1, lights: [one]) == nil)
        // Across the cycle boundary: ticks 47, 48, 1, 2 lethal (a cyclic run of 4); tolerance 3 freezes at walk tick 50
        // (tick 2 of the next cycle), tolerance 4 survives.
        let wrap: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux, [47: 50, 48: 50, 1: 50, 2: 50]), w)
        #expect(wrap.longestLethalRun == 4)
        #expect(Sky.judge(worlds: [w], tolerance: 3, lights: [wrap]) == .frozen(world: 0, tick: 50))
        #expect(Sky.judge(worlds: [w], tolerance: 4, lights: [wrap]) == nil)
        // A lethal run at the start only is judged at its own ticks: ticks 1 … 4, tolerance 3, fails at tick 4.
        let head: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux, [1: 50, 2: 50, 3: 50, 4: 50]), w)
        #expect(Sky.judge(worlds: [w], tolerance: 3, lights: [head]) == .frozen(world: 0, tick: 4))
        // Every tick lethal: the longest run is 48 and the walk fails at tick E + 1.
        let all: BinaryGardensWorldLight = Self.light(Self.profile(Self.lethalLowFlux), w)
        #expect(all.longestLethalRun == 48)
        #expect(Sky.judge(worlds: [w], tolerance: 12, lights: [all]) == .frozen(world: 0, tick: 13))
        // The lower world fails first at an equal tick; an earlier tick of a higher world fails first.
        let late: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux, [9: 450]), w)
        let early: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux, [6: 50]), w)
        #expect(Sky.judge(worlds: [w, w], tolerance: 0, lights: [late, early]) == .frozen(world: 1, tick: 6))
        #expect(Sky.judge(worlds: [w, w], tolerance: 0, lights: [early, early]) == .frozen(world: 0, tick: 6))
    }

    @Test func aMixedLethalRunIsOneRunNamedByItsExceedingTick() {
        let w: World = Self.handWorld()
        let lowThenHigh: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux, [10: 50, 11: 450]), w)
        #expect(lowThenHigh.longestLethalRun == 2)
        #expect(Sky.judge(worlds: [w], tolerance: 1, lights: [lowThenHigh]) == .scorched(world: 0, tick: 11))
        #expect(Sky.judge(worlds: [w], tolerance: 0, lights: [lowThenHigh]) == .frozen(world: 0, tick: 10))
        let highThenLow: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux, [10: 450, 11: 50]), w)
        #expect(Sky.judge(worlds: [w], tolerance: 1, lights: [highThenLow]) == .frozen(world: 0, tick: 11))
        // A dim or bright tick between ends the run.
        let broken: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux,
                                                                      [10: 50, 11: 150, 12: 450]), w)
        #expect(broken.longestLethalRun == 1)
        #expect(Sky.judge(worlds: [w], tolerance: 1, lights: [broken]) == nil)
    }

    @Test func aWindowOneTickShortOfTheRequirementAndTheWholeCycle() {
        // Comfortable ticks 5 … 28 (24 ticks), dim elsewhere.
        var overrides: [Int: Int] = [:]
        for tick in 5...28 { overrides[tick] = Self.comfortFlux }
        let flux: [Int] = Self.profile(Self.dimFlux, overrides)
        let holds: BinaryGardensWorldLight = Self.light(flux, Self.handWorld(window: 24))
        #expect(holds.window == 24 && holds.windowStart == 5)
        #expect(Sky.judge(worlds: [Self.handWorld(window: 24)], tolerance: 0, lights: [holds]) == nil)
        #expect(Sky.judge(worlds: [Self.handWorld(window: 25)], tolerance: 0, lights: [holds])
            == .unstable(world: 0, window: 24, required: 25))
        // The whole cycle comfortable: a window of 48 from tick 1 holds any requirement.
        let whole: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux), Self.handWorld(window: 48))
        #expect(whole.window == 48 && whole.windowStart == 1)
        #expect(Sky.judge(worlds: [Self.handWorld(window: 48)], tolerance: 0, lights: [whole]) == nil)
        // 47 comfortable ticks with tick 20 dim: the window wraps from tick 21 through tick 19 (47 ticks).
        let gap: BinaryGardensWorldLight = Self.light(Self.profile(Self.comfortFlux, [20: Self.dimFlux]),
                                                      Self.handWorld(window: 48))
        #expect(gap.window == 47 && gap.windowStart == 21)
        #expect(Sky.judge(worlds: [Self.handWorld(window: 48)], tolerance: 0, lights: [gap])
            == .unstable(world: 0, window: 47, required: 48))
        // Equal longest runs: the smallest start wins, also against a run that wraps (ticks 45 … 3 and 10 … 16).
        var ties: [Int: Int] = [:]
        for tick in [45, 46, 47, 48, 1, 2, 3, 10, 11, 12, 13, 14, 15, 16] { ties[tick] = Self.comfortFlux }
        let tied: BinaryGardensWorldLight = Self.light(Self.profile(Self.brightFlux, ties), Self.handWorld())
        #expect(tied.window == 7 && tied.windowStart == 10)
        // No comfortable tick: window 0, start 0.
        let none: BinaryGardensWorldLight = Self.light(Self.profile(Self.brightFlux), Self.handWorld())
        #expect(none.window == 0 && none.windowStart == 0)
        #expect(Sky.judge(worlds: [Self.handWorld()], tolerance: 0, lights: [none])
            == .unstable(world: 0, window: 0, required: 1))
    }

    @Test func anIntegralOneMillifluxEitherSideOfEachBloomBound() throws {
        let flux: [Int] = Self.profile(Self.comfortFlux, [7: 260])
        let integral: Int = 47 * 250 + 260
        func judged(low: Int, high: Int) -> BinaryGardensFailure? {
            let w: World = Self.handWorld(low: low, high: high)
            return Sky.judge(worlds: [w], tolerance: 0, lights: [Self.light(flux, w)])
        }
        #expect(Self.light(flux, Self.handWorld()).integral == integral)
        #expect(judged(low: integral, high: integral) == nil)
        #expect(judged(low: integral + 1, high: integral + 5)
            == .wilted(world: 0, integral: integral, low: integral + 1, high: integral + 5))
        #expect(judged(low: integral - 5, high: integral - 1)
            == .bleached(world: 0, integral: integral, low: integral - 5, high: integral - 1))
        #expect(judged(low: integral - 1, high: integral + 1) == nil)
        #expect(Self.light(flux, Self.handWorld(low: integral + 1, high: integral + 5)).bloom == .below)
        #expect(Self.light(flux, Self.handWorld(low: integral - 5, high: integral - 1)).bloom == .above)
        // On a real level: the integral exactly at either bound blooms, one milliflux inside the band refuses it.
        let probe: Level = try BinaryGardensLevelTests.hand(worlds: [BinaryGardensLevelTests.wide(radius: 9, speed: -3)])
        let real: Int = probe.startReport.worlds[0].integral
        func outcome(low: Int, high: Int) throws -> BinaryGardensFailure? {
            let world = World(radius: 9, phase: 0, speed: -3, lethalLow: 0, comfortLow: 1, comfortHigh: 199_999,
                              lethalHigh: 200_000, window: 1, bloomLow: low, bloomHigh: high)
            return try BinaryGardensLevelTests.hand(worlds: [world]).startReport.failure
        }
        #expect(try outcome(low: real, high: real) == nil)
        #expect(try outcome(low: real + 1, high: real + 1)?.code == "wilted")
        #expect(try outcome(low: real - 1, high: real - 1)?.code == "bleached")
    }

    @Test func aSeparationOneUnitEitherSideOfTheMinimum() throws {
        for fixture in BinaryGardensFixture.all(count: 40) {
            let level: Level = fixture.level
            let closest: Int = Sky.integerSquareRoot(level.startReport.minimumSeparationSquared) >> 20
            let allowed: Int = min(16, closest)
            func probe(_ separation: Int) -> Level? {
                try? Level.probe(ringRadii: level.ringRadii, starSpeed: level.starSpeed,
                                 luminosityLevels: level.luminosityLevels, stars: level.stars, maxTilt: level.maxTilt,
                                 startTilt: level.startTilt, minimumSeparation: separation,
                                 clampRadius: level.clampRadius, worlds: level.worlds,
                                 lethalTolerance: level.lethalTolerance)
            }
            #expect(probe(allowed) != nil)
            if allowed > 0 { #expect(probe(allowed - 1) != nil) }
            if closest + 1 <= 16 { #expect(probe(closest + 1) == nil) }
            #expect(level.startReport.minimumSeparationSquared >= allowed * allowed << 40)
            #expect(level.startReport.minimumSeparationSquared < (closest + 1) * (closest + 1) << 40)
        }
        #expect(Sky.integerSquareRoot(0) == 0 && Sky.integerSquareRoot(15) == 3 && Sky.integerSquareRoot(16) == 4)
        #expect(Sky.integerSquareRoot(144 << 40) == 12 << 20 && Sky.integerSquareRoot((144 << 40) - 1) == (12 << 20) - 1)
    }

    @Test func theJudgeOrder() {
        let w: World = Self.handWorld(window: 10, low: 0, high: 100)
        let dim: [Int] = Self.profile(Self.dimFlux)
        let comfortable: [Int] = Self.profile(Self.comfortFlux)
        // World 1 is unstable and above its bloom band, world 2 freezes: the lethal walk comes first.
        let lethal: [Int] = Self.profile(Self.comfortFlux, [30: 50])
        #expect(Sky.judge(worlds: [w, w], tolerance: 0, lights: [Self.light(dim, w), Self.light(lethal, w)])
            == .frozen(world: 1, tick: 30))
        // A world failing both its window and its bloom band fails unstable.
        #expect(Sky.judge(worlds: [w], tolerance: 0, lights: [Self.light(dim, w)])
            == .unstable(world: 0, window: 0, required: 10))
        // World 1 bleaches, world 2 is unstable: the lowest-numbered world names the failure.
        let blooming: World = Self.handWorld(window: 10, low: 0, high: 9_600_000)
        #expect(Sky.judge(worlds: [w, blooming], tolerance: 0,
                          lights: [Self.light(comfortable, w), Self.light(dim, blooming)])
            == .bleached(world: 0, integral: 48 * 250, low: 0, high: 100))
        #expect(Sky.judge(worlds: [blooming, w], tolerance: 0,
                          lights: [Self.light(dim, blooming), Self.light(comfortable, w)])
            == .unstable(world: 0, window: 0, required: 10))
        let starving: World = Self.handWorld(window: 1, low: 9_000_000, high: 9_600_000)
        #expect(Sky.judge(worlds: [starving, w], tolerance: 0,
                          lights: [Self.light(comfortable, starving), Self.light(dim, w)])
            == .wilted(world: 0, integral: 48 * 250, low: 9_000_000, high: 9_600_000))
        #expect(Sky.judge(worlds: [blooming], tolerance: 0, lights: [Self.light(comfortable, blooming)]) == nil)
    }
}
