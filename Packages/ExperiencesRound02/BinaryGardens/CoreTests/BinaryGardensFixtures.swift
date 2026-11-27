// BinaryGardensFixtures — feature 501 (R02-G21-01) T-R02G2101-002 (SC-R02G2101-001 … 004). Seeded Binary Gardens
// levels with known winning arrangements. A fixture draws 2 … 5 strictly increasing ring radii of 1 … 40, a star speed
// 1 … 3, 1 … 4 strictly increasing luminosity levels of 1 … 64, a largest tilt 0 … 6, a clamp radius 1 … 8, 1 … 3 worlds
// (radius 1 … 60, phase 0 … 47, speed −4 … 4), a lethal tolerance 0 … 12 and a winning arrangement (random rings,
// phases, luminosities and tilt). It runs that arrangement on a probe level with wide bounds and takes, per world, a
// window W of 1 … 48 ticks at a random start: the comfortable band c_lo … c_hi around the window's fluxes (widened by
// 0 … 50 milliflux), the lethal bounds outside every flux of the cycle (so no tick is lethal) or, in one draw of three,
// the lethal low bound just above one flux outside the window when the kernel still judges the arrangement a win, and the
// bloom band around the world's integral (widened by 0 … 5 000); the minimum separation is 0 … the winning arrangement's
// whole closest approach in units (at most 16). The start changes 1 … 3 controls of the winning arrangement (each
// adjustable; the other controls adjustable or locked at random), keeps the separation and does not win; the known
// actions reach the winning arrangement (star 1 then star 2: ring, phase, luminosity; then the tilt, or the reverse when
// an intermediate arrangement would break the separation) and then run; the budget is their number plus 0 … 2. Draws
// that fail are skipped, so the generator stays deterministic. Explicit types, plain loops.
import Foundation
import VisualCoreSimulation
@testable import BinaryGardensCore

/// A seeded level with its known winning arrangement and actions.
struct BinaryGardensFixture: Sendable {
    /// The level.
    let level: BinaryGardensLevel
    /// The winning arrangement.
    let winning: BinaryGardensArrangement
    /// The known actions: the arrangement actions that reach the winning arrangement, then `run`.
    let actions: [BinaryGardensAction]

    /// The fixture seed of the feature.
    static let seed: UInt64 = 2_501

    /// `count` fixtures from `seed`, in order.
    static func all(count: Int, seed: UInt64 = seed) -> [BinaryGardensFixture] {
        var random = SeededRandom(seed: seed)
        var fixtures: [BinaryGardensFixture] = []
        var index: Int = 0
        while fixtures.count < count {
            if let fixture = make(&random, index: index) { fixtures.append(fixture) }
            index += 1
        }
        return fixtures
    }

    /// `count` distinct values of `range`, ascending.
    static func distinctSorted(_ random: inout SeededRandom, count: Int, in range: ClosedRange<Int>) -> [Int] {
        var values: Set<Int> = []
        while values.count < count { values.insert(random.int(range)) }
        return values.sorted()
    }

    /// A value of `range` other than `current`.
    static func other(_ random: inout SeededRandom, than current: Int, in range: ClosedRange<Int>) -> Int {
        let value: Int = random.int(range.lowerBound...(range.upperBound - 1))
        return value >= current ? value + 1 : value
    }

    /// The arrangement actions from `start` to `goal`: star 1 then star 2 (ring, phase, luminosity), then the tilt.
    static func actions(from start: BinaryGardensArrangement,
                        to goal: BinaryGardensArrangement) -> [BinaryGardensAction] {
        var actions: [BinaryGardensAction] = []
        for star in 0..<2 {
            if start.rings[star] != goal.rings[star] { actions.append(.ring(star: star, index: goal.rings[star])) }
            if start.phases[star] != goal.phases[star] { actions.append(.phase(star: star, step: goal.phases[star])) }
            if start.luminosities[star] != goal.luminosities[star] {
                actions.append(.luminosity(star: star, index: goal.luminosities[star]))
            }
        }
        if start.tilt != goal.tilt { actions.append(.tilt(step: goal.tilt)) }
        return actions
    }

    /// Whether `actions` take `level` from its start to `goal`, every one accepted by the kernel's check.
    static func reaches(_ level: BinaryGardensLevel, _ actions: [BinaryGardensAction],
                        _ goal: BinaryGardensArrangement) -> Bool {
        var arrangement: BinaryGardensArrangement = level.start
        for action in actions {
            guard let next = try? BinaryGardensSky.changed(level, arrangement, by: action) else { return false }
            arrangement = next
        }
        return arrangement == goal
    }

    /// The flux bounds of a world around `flux` (ticks 1 … 48) with a window of `window` ticks from index `from`, or
    /// nil when the window holds a zero flux or the bounds leave their range.
    static func bounds(_ random: inout SeededRandom, flux: [Int], window: Int,
                       from: Int) -> (lethalLow: Int, comfortLow: Int, comfortHigh: Int, lethalHigh: Int,
                                      outside: [Int])? {
        var inside: [Int] = []
        var outside: [Int] = []
        var member: [Bool] = Array(repeating: false, count: 48)
        for offset in 0..<window { member[(from + offset) % 48] = true }
        for tick in 0..<48 {
            if member[tick] { inside.append(flux[tick]) } else { outside.append(flux[tick]) }
        }
        let low: Int = inside.min() ?? 0
        let high: Int = inside.max() ?? 0
        guard low >= 1 else { return nil }
        let allLow: Int = flux.min() ?? 0
        let allHigh: Int = flux.max() ?? 0
        let comfortLow: Int = max(1, low - random.int(0...50))
        let comfortHigh: Int = high + random.int(0...50)
        let lethalLow: Int = max(0, min(comfortLow - 1, allLow - random.int(0...20)))
        let lethalHigh: Int = max(comfortHigh + 1, allHigh + random.int(0...20))
        guard lethalHigh <= BinaryGardensLevel.maximumFlux else { return nil }
        return (lethalLow, comfortLow, comfortHigh, lethalHigh, outside)
    }

    /// One fixture from `random`, or nil when the draw does not make a level.
    static func make(_ random: inout SeededRandom, index: Int) -> BinaryGardensFixture? {
        let ringRadii: [Int] = distinctSorted(&random, count: random.int(2...5), in: 1...40)
        let starSpeed: Int = random.int(1...3)
        let luminosityLevels: [Int] = distinctSorted(&random, count: random.int(1...4), in: 1...64)
        let maxTilt: Int = random.int(0...6)
        let clampRadius: Int = random.int(1...8)
        let tolerance: Int = random.int(0...12)
        let winning = BinaryGardensArrangement(
            rings: [random.int(0...(ringRadii.count - 1)), random.int(0...(ringRadii.count - 1))],
            phases: [random.int(0...47), random.int(0...47)],
            luminosities: [random.int(0...(luminosityLevels.count - 1)), random.int(0...(luminosityLevels.count - 1))],
            tilt: random.int(0...maxTilt))
        var orbits: [(radius: Int, phase: Int, speed: Int)] = []
        for _ in 0..<random.int(1...3) {
            orbits.append((random.int(1...60), random.int(0...47), random.int(-4...4)))
        }
        var wide: [BinaryGardensWorld] = []
        for orbit in orbits {
            wide.append(BinaryGardensWorld(radius: orbit.radius, phase: orbit.phase, speed: orbit.speed, lethalLow: 0,
                                           comfortLow: 1, comfortHigh: 199_999, lethalHigh: 200_000, window: 1,
                                           bloomLow: 0, bloomHigh: BinaryGardensLevel.maximumBloom))
        }
        var probeStars: [BinaryGardensStar] = []
        for star in 0..<2 {
            probeStars.append(BinaryGardensStar(ring: winning.rings[star], phase: winning.phases[star],
                                                luminosity: winning.luminosities[star], ringAdjustable: true,
                                                phaseAdjustable: true, luminosityAdjustable: false))
        }
        guard let probe = try? BinaryGardensLevel.probe(
            ringRadii: ringRadii, starSpeed: starSpeed, luminosityLevels: luminosityLevels, stars: probeStars,
            maxTilt: maxTilt, startTilt: winning.tilt, minimumSeparation: 0, clampRadius: clampRadius, worlds: wide,
            lethalTolerance: tolerance) else { return nil }
        let report: BinaryGardensReport = probe.startReport
        var safe: [BinaryGardensWorld] = []
        var daring: [BinaryGardensWorld] = []
        for (world, orbit) in orbits.enumerated() {
            let light: BinaryGardensWorldLight = report.worlds[world]
            let window: Int = random.int(1...48)
            let from: Int = random.int(0...47)
            guard let b = bounds(&random, flux: light.flux, window: window, from: from) else { return nil }
            let bloomLow: Int = max(0, light.integral - random.int(0...5_000))
            let bloomHigh: Int = min(BinaryGardensLevel.maximumBloom, light.integral + random.int(0...5_000))
            let world = BinaryGardensWorld(radius: orbit.radius, phase: orbit.phase, speed: orbit.speed,
                                           lethalLow: b.lethalLow, comfortLow: b.comfortLow,
                                           comfortHigh: b.comfortHigh, lethalHigh: b.lethalHigh, window: window,
                                           bloomLow: bloomLow, bloomHigh: bloomHigh)
            safe.append(world)
            var raised: Int = b.lethalLow
            if random.int(0...2) == 0, !b.outside.isEmpty {
                let pick: Int = b.outside[random.int(0...(b.outside.count - 1))]
                if pick + 1 < b.comfortLow && pick + 1 > b.lethalLow { raised = pick + 1 }
            }
            daring.append(BinaryGardensWorld(radius: orbit.radius, phase: orbit.phase, speed: orbit.speed,
                                             lethalLow: raised, comfortLow: b.comfortLow, comfortHigh: b.comfortHigh,
                                             lethalHigh: b.lethalHigh, window: window, bloomLow: bloomLow,
                                             bloomHigh: bloomHigh))
        }
        var worlds: [BinaryGardensWorld] = safe
        if daring != safe, let test = try? BinaryGardensLevel.probe(
            ringRadii: ringRadii, starSpeed: starSpeed, luminosityLevels: luminosityLevels, stars: probeStars,
            maxTilt: maxTilt, startTilt: winning.tilt, minimumSeparation: 0, clampRadius: clampRadius,
            worlds: daring, lethalTolerance: tolerance), test.startReport.wins {
            worlds = daring
        }
        let closest: Int = BinaryGardensSky.integerSquareRoot(report.minimumSeparationSquared) >> 20
        let separation: Int = random.int(0...min(16, closest))
        for _ in 0..<8 {
            var controls: [Int] = [0, 1, 3, 4]
            if luminosityLevels.count > 1 { controls += [2, 5] }
            if maxTilt > 0 { controls.append(6) }
            random.shuffle(&controls)
            let changed: Set<Int> = Set(controls.prefix(random.int(1...min(3, controls.count))))
            var rings: [Int] = winning.rings
            var phases: [Int] = winning.phases
            var luminosities: [Int] = winning.luminosities
            var tilt: Int = winning.tilt
            var stars: [BinaryGardensStar] = []
            for star in 0..<2 {
                let base: Int = star * 3
                if changed.contains(base) {
                    rings[star] = other(&random, than: rings[star], in: 0...(ringRadii.count - 1))
                }
                if changed.contains(base + 1) { phases[star] = other(&random, than: phases[star], in: 0...47) }
                if changed.contains(base + 2) {
                    luminosities[star] = other(&random, than: luminosities[star],
                                               in: 0...(luminosityLevels.count - 1))
                }
                let ringFlag: Bool = changed.contains(base) || random.int(0...1) == 1
                let phaseFlag: Bool = changed.contains(base + 1) || random.int(0...1) == 1
                let luminosityFlag: Bool = luminosityLevels.count > 1
                    && (changed.contains(base + 2) || random.int(0...1) == 1)
                stars.append(BinaryGardensStar(ring: rings[star], phase: phases[star],
                                               luminosity: luminosities[star], ringAdjustable: ringFlag,
                                               phaseAdjustable: phaseFlag, luminosityAdjustable: luminosityFlag))
            }
            if changed.contains(6) { tilt = other(&random, than: tilt, in: 0...maxTilt) }
            let start = BinaryGardensArrangement(rings: rings, phases: phases, luminosities: luminosities, tilt: tilt)
            let forward: [BinaryGardensAction] = actions(from: start, to: winning)
            let budget: Int = min(BinaryGardensLevel.budgets.upperBound, forward.count + random.int(0...2))
            guard let level = try? BinaryGardensLevel(
                id: "fixture-\(index)", seed: UInt64(index), difficulty: random.int(1...5), ringRadii: ringRadii,
                starSpeed: starSpeed, luminosityLevels: luminosityLevels, stars: stars, maxTilt: maxTilt,
                startTilt: tilt, minimumSeparation: separation, clampRadius: clampRadius, worlds: worlds,
                lethalTolerance: tolerance, budget: budget, tutorial: false) else { continue }
            var known: [BinaryGardensAction] = forward
            if !reaches(level, known, winning) {
                known = Array(forward.reversed())
                guard reaches(level, known, winning) else { continue }
            }
            guard BinaryGardensSky.report(level, arrangement: winning).wins else { continue }
            known.append(.run)
            return BinaryGardensFixture(level: level, winning: winning, actions: known)
        }
        return nil
    }
}
