// StarlitCartoucheFixtures — feature 451 (R02-G16-01) T-R02G1601-002 (SC-R02G1601-001 … 004). Seeded Starlit Cartouche
// levels with known winning legs. A fixture draws 4 … 9 stars (orbits of 1 … 4 positions with coordinates −3 … 3, so
// every pair is at most 108 apart squared, and distinct glyph points), a range of 11 (121 ≥ 108: every corridor is
// flyable at every beat), then flies a random route of 1 … 6 legs from a random start star (a random next star other
// than the current one, a wait 0 … 2, a travel 1 … 3), adding each leg's corridor if it is new. The symbol is the set of
// corridors the route flew; the beacon is the route's last star; 0 … 3 extra corridors join other star pairs (never in
// the symbol) and carry the hazards (0 … 2), so no hazard touches the route. Every window is [0, deadline], the deadline
// is the last arrival plus 0 … 4 (at most 64) and the budget is the route's leg count plus 0 … 3. `step` is the
// fixtures' own computation of a leg, independent of the chart.
import Foundation
import VisualCoreSimulation
@testable import StarlitCartoucheCore

/// A seeded level with its known winning legs.
struct StarlitCartoucheFixture: Sendable {
    /// The level.
    let level: StarlitCartoucheLevel
    /// The known legs, each `.leg(star, wait)`; flown in order they win, at the latest on the last one (a route that
    /// revisits its stars can complete the symbol at the beacon earlier).
    let actions: [StarlitCartoucheAction]

    /// The fixture seed of the feature.
    static let seed: UInt64 = 2_451

    /// `count` fixtures from `seed`, in order.
    static func all(count: Int, seed: UInt64 = seed) -> [StarlitCartoucheFixture] {
        var random = SeededRandom(seed: seed)
        var fixtures: [StarlitCartoucheFixture] = []
        var index: Int = 0
        while fixtures.count < count {
            if let fixture = make(&random, index: index) { fixtures.append(fixture) }
            index += 1
        }
        return fixtures
    }

    /// The fixtures' own step: the arrival star and beat of a leg from `star` at `beat` to `destination` after `wait`,
    /// with its corridor, or nil when the leg is refused (unknown star, same star, no corridor, wait out of range, out of
    /// range at departure). Failures are not judged here.
    static func step(_ level: StarlitCartoucheLevel, star: Int, beat: Int, destination: Int,
                     wait: Int) -> (star: Int, beat: Int, corridor: Int)? {
        guard destination >= 0, destination < level.stars.count, destination != star, (0...8).contains(wait) else {
            return nil
        }
        var found: Int? = nil
        for index in level.corridors.indices {
            let c: StarlitCartoucheCorridor = level.corridors[index]
            if (c.a == star && c.b == destination) || (c.b == star && c.a == destination) { found = index }
        }
        guard let corridor = found else { return nil }
        let depart: Int = beat + wait
        let pa: StarlitCartoucheVector = level.stars[star].orbit[depart % level.stars[star].orbit.count]
        let pb: StarlitCartoucheVector = level.stars[destination].orbit[depart % level.stars[destination].orbit.count]
        let dx: Int = pa.x - pb.x
        let dy: Int = pa.y - pb.y
        let dz: Int = pa.z - pb.z
        guard dx * dx + dy * dy + dz * dz <= level.range * level.range else { return nil }
        return (destination, depart + level.corridors[corridor].travel, corridor)
    }

    /// One fixture, or nil when the draw does not make a valid level.
    static func make(_ random: inout SeededRandom, index: Int) -> StarlitCartoucheFixture? {
        let count: Int = random.int(4...9)
        var glyphs: [StarlitCartoucheGlyphPoint] = []
        var orbits: [[StarlitCartoucheVector]] = []
        while glyphs.count < count {
            let g = StarlitCartoucheGlyphPoint(random.int(0...4), random.int(0...4))
            if glyphs.contains(g) { continue }
            glyphs.append(g)
            var orbit: [StarlitCartoucheVector] = []
            let length: Int = random.int(1...4)
            for _ in 0..<length {
                orbit.append(StarlitCartoucheVector(random.int(-3...3), random.int(-3...3), random.int(-3...3)))
            }
            orbits.append(orbit)
        }
        let start: Int = random.int(0...(count - 1))
        var corridors: [StarlitCartoucheCorridor] = []
        var actions: [StarlitCartoucheAction] = []
        var symbol: Set<Int> = []
        var star: Int = start
        var beat: Int = 0
        let legs: Int = random.int(1...6)
        for _ in 0..<legs {
            var next: Int = random.int(0...(count - 1))
            if next == star { next = (next + 1) % count }
            let wait: Int = random.int(0...2)
            var corridorIndex: Int? = nil
            for i in corridors.indices where corridors[i].joins(star, next) { corridorIndex = i }
            if corridorIndex == nil {
                corridors.append(StarlitCartoucheCorridor(star, next, travel: random.int(1...3)))
                corridorIndex = corridors.count - 1
            }
            let travel: Int = corridors[corridorIndex!].travel
            symbol.insert(corridorIndex!)
            actions.append(.leg(next, wait))
            beat += wait + travel
            star = next
        }
        let extras: Int = random.int(0...3)
        var extraIndices: [Int] = []
        for _ in 0..<extras {
            let a: Int = random.int(0...(count - 1))
            let b: Int = random.int(0...(count - 1))
            guard a != b, !corridors.contains(where: { $0.joins(a, b) }) else { continue }
            corridors.append(StarlitCartoucheCorridor(a, b, travel: random.int(1...3)))
            extraIndices.append(corridors.count - 1)
        }
        var hazards: [StarlitCartoucheHazard] = []
        if !extraIndices.isEmpty {
            let hazardCount: Int = random.int(0...2)
            for _ in 0..<hazardCount {
                let from: Int = random.int(0...20)
                hazards.append(StarlitCartoucheHazard(corridor: extraIndices[random.int(0...(extraIndices.count - 1))],
                                                      from: from, to: from + random.int(0...4)))
            }
        }
        let deadline: Int = min(beat + random.int(0...4), 64)
        var stars: [StarlitCartoucheStar] = []
        for i in 0..<count {
            stars.append(StarlitCartoucheStar(orbit: orbits[i], glyph: glyphs[i], open: 0, close: deadline))
        }
        let budget: Int = min(legs + random.int(0...3), 16)
        guard let level = try? StarlitCartoucheLevel(id: "fixture-\(index)", seed: UInt64(index),
                                                     difficulty: random.int(1...5), stars: stars, range: 11,
                                                     corridors: corridors, hazards: hazards, start: start,
                                                     beacon: star, deadline: deadline, symbol: symbol.sorted(),
                                                     budget: budget, tutorial: random.int(0...1) == 1)
        else { return nil }
        return StarlitCartoucheFixture(level: level, actions: actions)
    }
}
