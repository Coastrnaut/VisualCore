// CelestialEclipseLabFixtures — feature 461 (R02-G17-01) T-R02G1701-002 (SC-R02G1701-001 … 004). Seeded Celestial
// Eclipse Lab levels with known winning phases. A fixture draws 2 … 5 bodies, body i in its own depth band (z between
// 20 − 10 i and 26 − 10 i, so body i is in front of every body j > i), each with an orbit of 4 … 12 positions whose x
// and y lie in −6 … 6 (so discs of radius 1 … 4 meet often) and a radius 1 … 4; body 0 is fixed in half the fixtures.
// It then draws the winning phases, reads the eclipse intervals they produce over a horizon of 12 … 40 ticks, and makes
// the first 1 … 3 events the target, each with a window from its tick minus 0 … 2 to its tick plus 0 … 2 (clipped to
// the horizon), so the winning phases match the target exactly with nothing before it. The starting phases are the
// winning ones with one … all movable bodies moved to other phases, kept only when they do not win; the budget is the
// number of moved bodies plus 0 … 2. A fixture without enough events or without a non-winning start is skipped. The
// known actions set each moved body back to its winning phase, then run.
import Foundation
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

/// A seeded level with its known winning actions.
struct CelestialEclipseLabFixture: Sendable {
    /// The level.
    let level: CelestialEclipseLabLevel
    /// The winning phases.
    let winning: [Int]
    /// The known actions: a phase change for each body whose starting phase differs from its winning one, then `run`.
    let actions: [CelestialEclipseLabAction]

    /// The fixture seed of the feature.
    static let seed: UInt64 = 2_461

    /// `count` fixtures from `seed`, in order.
    static func all(count: Int, seed: UInt64 = seed) -> [CelestialEclipseLabFixture] {
        var random = SeededRandom(seed: seed)
        var fixtures: [CelestialEclipseLabFixture] = []
        var index: Int = 0
        while fixtures.count < count {
            if let fixture = make(&random, index: index) { fixtures.append(fixture) }
            index += 1
        }
        return fixtures
    }

    /// Random bodies in their depth bands (see the file header).
    static func bodies(_ random: inout SeededRandom, count: Int, fixFirst: Bool) -> [CelestialEclipseLabBody] {
        var result: [CelestialEclipseLabBody] = []
        for i in 0..<count {
            let period: Int = random.int(4...12)
            var orbit: [CelestialEclipseLabVector] = []
            for _ in 0..<period {
                orbit.append(CelestialEclipseLabVector(random.int(-6...6), random.int(-6...6),
                                                       random.int((20 - 10 * i)...(26 - 10 * i))))
            }
            result.append(CelestialEclipseLabBody(orbit: orbit, radius: random.int(1...4), fixed: fixFirst && i == 0))
        }
        return result
    }

    /// One fixture from `random`, or nil when its draw yields too few events or no non-winning start.
    static func make(_ random: inout SeededRandom, index: Int) -> CelestialEclipseLabFixture? {
        let count: Int = random.int(2...5)
        let fixFirst: Bool = random.int(0...1) == 1
        let drawn: [CelestialEclipseLabBody] = bodies(&random, count: count, fixFirst: fixFirst)
        let horizon: Int = random.int(12...40)
        var winning: [Int] = []
        for body in drawn { winning.append(random.int(0...(body.period - 1))) }
        // The events of the winning phases, read with a provisional one-eclipse target (the target does not change the
        // intervals).
        guard let probe = try? CelestialEclipseLabLevel.unchecked(bodies: drawn, horizon: horizon) else { return nil }
        let events: [CelestialEclipseLabInterval] = CelestialEclipseLabSky.intervals(probe, phases: winning)
        let wanted: Int = random.int(1...3)
        guard events.count >= wanted else { return nil }
        var target: [CelestialEclipseLabTarget] = []
        for event in events.prefix(wanted) {
            let open: Int = max(event.first - random.int(0...2), 0)
            let close: Int = min(event.first + random.int(0...2), horizon - 1)
            target.append(CelestialEclipseLabTarget(front: event.front, back: event.back, open: open, close: close))
        }
        let movable: [Int] = (0..<count).filter { !drawn[$0].fixed }
        guard !movable.isEmpty else { return nil }
        for _ in 0..<8 {
            var start: [Int] = winning
            var moved: [Int] = []
            let moves: Int = random.int(1...movable.count)
            for body in movable.shuffledPrefix(moves, using: &random) {
                let period: Int = drawn[body].period
                start[body] = (winning[body] + random.int(1...(period - 1))) % period
                moved.append(body)
            }
            moved.sort()
            let budget: Int = min(moved.count + random.int(0...2), CelestialEclipseLabLevel.budgets.upperBound)
            guard let level = try? CelestialEclipseLabLevel(
                id: "fixture-\(index)", seed: UInt64(index), difficulty: 1, bodies: drawn, horizon: horizon,
                target: target, phases: start, budget: budget, tutorial: false) else { continue }
            var actions: [CelestialEclipseLabAction] = []
            for body in moved { actions.append(.phase(body, winning[body])) }
            actions.append(.run)
            return CelestialEclipseLabFixture(level: level, winning: winning, actions: actions)
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

extension CelestialEclipseLabLevel {
    /// A probe level of `bodies` and `horizon` with a placeholder target and the start phases all 0, built without the
    /// "already won" rule, for reading intervals only (fixtures).
    static func unchecked(bodies: [CelestialEclipseLabBody], horizon: Int) throws -> CelestialEclipseLabLevel {
        // The placeholder target is a pair that cannot be met first unless no other event occurs; the intervals do not
        // depend on the target.
        let pair: (front: Int, back: Int) = bodies[0].nearestBack > bodies[1].farthestFront ? (0, 1) : (1, 0)
        let target: [CelestialEclipseLabTarget] = [CelestialEclipseLabTarget(front: pair.front, back: pair.back,
                                                                             open: horizon - 1, close: horizon - 1)]
        var phases: [Int] = []
        for _ in bodies { phases.append(0) }
        var movable: [CelestialEclipseLabBody] = bodies
        if !movable.contains(where: { !$0.fixed }) {
            movable[movable.count - 1] = CelestialEclipseLabBody(orbit: bodies[bodies.count - 1].orbit,
                                                                 radius: bodies[bodies.count - 1].radius)
        }
        return try CelestialEclipseLabLevel.probe(bodies: movable, horizon: horizon, target: target, phases: phases)
    }
}
