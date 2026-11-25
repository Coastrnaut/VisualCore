// ApsidesWorkshopFixtures — feature 471 (R02-G18-01) T-R02G1801-002 (SC-R02G1801-001 … 004). Seeded Apsides Workshop
// levels with known winning orbits. A fixture draws a period of 16, 24, 32 or 48 ticks and a valid winning orbit,
// reads the report it produces, and makes 1 … 3 sweep targets from the sectors it visits (each with a band from its
// share minus 5 … 60 to its share plus 5 … 60, clipped to 0 … 1000) and, in half the fixtures, an apsis target
// (periapsis or apoapsis, its sector, a range of its distance minus and plus 0 … 40 twentieths), all ordered by event
// tick; it adds 0 … 2 exclusion planets that the winning orbit does not strike. The starting orbit is the winning one
// with one … three steps moved, kept only when it is valid and does not win; the budget is the number of tunings
// needed plus 0 … 2. A fixture without a non-winning start is skipped. The known actions set the size and the periapsis
// knob back to the winning orbit (in an order whose orbit in between is valid), then play.
import Foundation
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

/// A seeded level with its known winning actions.
struct ApsidesWorkshopFixture: Sendable {
    /// The level.
    let level: ApsidesWorkshopLevel
    /// The winning orbit.
    let winning: ApsidesWorkshopOrbit
    /// The known actions: the periapsis knob and the size where they differ from the start, then `play`.
    let actions: [ApsidesWorkshopAction]

    /// The fixture seed of the feature.
    static let seed: UInt64 = 2_471

    /// `count` fixtures from `seed`, in order.
    static func all(count: Int, seed: UInt64 = seed) -> [ApsidesWorkshopFixture] {
        var random = SeededRandom(seed: seed)
        var fixtures: [ApsidesWorkshopFixture] = []
        var index: Int = 0
        while fixtures.count < count {
            if let fixture = make(&random, index: index) { fixtures.append(fixture) }
            index += 1
        }
        return fixtures
    }

    /// A random valid orbit.
    static func orbit(_ random: inout SeededRandom) -> ApsidesWorkshopOrbit {
        while true {
            let orbit = ApsidesWorkshopOrbit(size: random.int(ApsidesWorkshopOrbit.sizes),
                                             eccentricity: random.int(ApsidesWorkshopOrbit.eccentricities),
                                             direction: random.int(ApsidesWorkshopOrbit.directions))
            if orbit.isValid { return orbit }
        }
    }

    /// One fixture from `random`, or nil when no non-winning start was found.
    static func make(_ random: inout SeededRandom, index: Int) -> ApsidesWorkshopFixture? {
        let periods: [Int] = [16, 24, 32, 48]
        let period: Int = periods[random.int(0...3)]
        let winning: ApsidesWorkshopOrbit = orbit(&random)
        let (points, _) = ApsidesWorkshopSky.positions(winning, period: period)
        let shares: [Int] = ApsidesWorkshopSky.shares(points)
        let visited: [Int] = (0..<ApsidesWorkshopSky.sectorCount).filter { sector in
            points.contains { ApsidesWorkshopSky.sector(of: $0) == sector }
        }
        var targets: [ApsidesWorkshopTarget] = []
        for sector in visited.shuffledPrefix(random.int(1...min(3, visited.count)), using: &random) {
            let low: Int = max(0, shares[sector] - random.int(5...60))
            let high: Int = min(ApsidesWorkshopSky.wholeShare, shares[sector] + random.int(5...60))
            targets.append(.sweep(sector: sector, low: low, high: high))
        }
        if random.int(0...1) == 1 {
            let periapsis: Bool = random.int(0...1) == 1
            let distance: Int = periapsis ? winning.periapsisDistance : winning.apoapsisDistance
            targets.append(ApsidesWorkshopTarget(kind: periapsis ? .periapsis : .apoapsis,
                                                 sector: periapsis ? winning.periapsisSector : winning.apoapsisSector,
                                                 low: max(0, distance - random.int(0...40)),
                                                 high: min(1280, distance + random.int(0...40))))
        }
        // Ordered by event tick; ties keep their drawing order.
        let ticks: [Int] = targets.map { ApsidesWorkshopSky.eventTick($0, points: points, period: period) }
        targets = targets.indices.sorted { (ticks[$0], $0) < (ticks[$1], $1) }.map { targets[$0] }
        var planets: [ApsidesWorkshopPlanet] = []
        let wanted: Int = random.int(0...2)
        var attempts: Int = 0
        while planets.count < wanted && attempts < 40 {
            attempts += 1
            let planet = ApsidesWorkshopPlanet(x: random.int(-48...48), y: random.int(-48...48),
                                               radius: random.int(1...4))
            let reach: Int = planet.radius + ApsidesWorkshopSky.starRadius
            guard planet.x * planet.x + planet.y * planet.y > reach * reach else { continue }
            let struck: Bool = points.indices.contains { tick in
                ApsidesWorkshopSky.touches(planet, from: points[tick], to: points[(tick + 1) % period])
            }
            if !struck { planets.append(planet) }
        }
        for _ in 0..<8 {
            var size: Int = winning.size
            var eccentricity: Int = winning.eccentricity
            var direction: Int = winning.direction
            for part in [0, 1, 2].shuffledPrefix(random.int(1...3), using: &random) {
                switch part {
                case 0: size = min(max(size + (random.int(0...1) == 0 ? -1 : 1) * random.int(1...6), 8), 48)
                case 1: eccentricity = min(max(eccentricity + (random.int(0...1) == 0 ? -1 : 1) * random.int(1...4),
                                               0), 15)
                default: direction = (direction + random.int(1...23)) % 24
                }
            }
            let start = ApsidesWorkshopOrbit(size: size, eccentricity: eccentricity, direction: direction)
            guard start != winning, start.isValid else { continue }
            // Size first when the winning eccentricity is not lower than the start's, the knob first otherwise: the
            // orbit in between then keeps the lower eccentricity with either size, so it is always valid.
            var tunings: [ApsidesWorkshopAction] = []
            if start.eccentricity != winning.eccentricity || start.direction != winning.direction {
                tunings.append(.periapsis(winning.eccentricity, winning.direction))
            }
            if start.size != winning.size {
                if winning.eccentricity >= start.eccentricity {
                    tunings.insert(.size(winning.size), at: 0)
                } else {
                    tunings.append(.size(winning.size))
                }
            }
            var actions: [ApsidesWorkshopAction] = tunings
            let budget: Int = actions.count + random.int(0...2)
            actions.append(.play)
            guard let level = try? ApsidesWorkshopLevel(
                id: "fixture-\(index)", seed: UInt64(index), difficulty: 1, period: period, planets: planets,
                targets: targets, orbit: start, budget: budget, tutorial: false) else { continue }
            return ApsidesWorkshopFixture(level: level, winning: winning, actions: actions)
        }
        return nil
    }
}

extension Array where Element == Int {
    /// The first `count` elements of a seeded shuffle (Fisher–Yates with `random`).
    func shuffledPrefix(_ count: Int, using random: inout SeededRandom) -> [Int] {
        var items: [Int] = self
        var i: Int = items.count - 1
        while i > 0 {
            let j: Int = random.int(0...i)
            items.swapAt(i, j)
            i -= 1
        }
        return Array(items.prefix(count))
    }
}
