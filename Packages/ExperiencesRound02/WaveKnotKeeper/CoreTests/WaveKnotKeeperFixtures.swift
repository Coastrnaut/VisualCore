// WaveKnotKeeperFixtures — feature 321 (R02-G03-01) T-R02G0301-002 (SC-R02G0301-001 … 005). Seeded test levels with a
// known solution, shared by the Wave Knot Keeper kernel tests. A fixture is built backwards: a random simple rope W with a
// non-degenerate projection is the goal (the target is W's crossing count and writhe); a random walk of legal moves
// from W gives the start S (rejected and retried until S does not already win); the known solution is the walk reversed
// with each direction flipped, which is legal step by step because each reversed step sweeps the same triangles back
// through a state the walk already held. The tension bound is the largest tension on the walk plus a margin, so no
// step of the solution exceeds it. Optionally one gate is placed around a random point. Deterministic: a SplitMix64
// generator, no clock. Fixture seed 2_321.
import Foundation
@testable import WaveKnotKeeperCore

/// A small deterministic generator (SplitMix64).
struct WaveKnotKeeperRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// The next 64 random bits.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform integer in `range`.
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }

    /// A random direction.
    mutating func direction() -> WaveKnotKeeperDirection {
        WaveKnotKeeperDirection.allCases[int(0...5)]
    }
}

/// A fixture level with its known solution and the rope it reaches.
struct WaveKnotKeeperFixture {
    let level: WaveKnotKeeperLevel
    /// Moves that win from the start (the play may win before the last one; stop at the win).
    let solution: [WaveKnotKeeperMove]
    /// The goal rope W.
    let goal: [WaveKnotKeeperPoint]
}

enum WaveKnotKeeperFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_321

    /// A random simple rope of `count` points in −`spread` … `spread` with a non-degenerate projection.
    static func rope(_ random: inout WaveKnotKeeperRandom, count: Int, spread: Int) -> [WaveKnotKeeperPoint] {
        while true {
            var points: [WaveKnotKeeperPoint] = []
            var seen: Set<WaveKnotKeeperPoint> = []
            while points.count < count {
                let p = WaveKnotKeeperPoint(x: random.int(-spread...spread), y: random.int(-spread...spread),
                                            z: random.int(-spread...spread))
                if seen.insert(p).inserted { points.append(p) }
            }
            if WaveKnotKeeperGeometry.isSimple(points) && !WaveKnotKeeperGeometry.summary(points).degenerate {
                return points
            }
        }
    }

    /// The fixture of `index` (deterministic from ``seed`` and `index`).
    static func fixture(_ index: Int, gates: Bool = false) -> WaveKnotKeeperFixture {
        var random = WaveKnotKeeperRandom(seed: seed &+ UInt64(index) &* 7_919)
        while true {
            let count = random.int(6...10)
            let goal = rope(&random, count: count, spread: random.int(4...10))
            var gateList: [WaveKnotKeeperGate] = []
            if gates {
                let c = goal[random.int(0...(count - 1))]
                let lo = WaveKnotKeeperPoint(x: max(c.x - 2, -16), y: max(c.y - 2, -16), z: max(c.z - 2, -16))
                let hi = WaveKnotKeeperPoint(x: min(c.x + 2, 16), y: min(c.y + 2, 16), z: min(c.z + 2, 16))
                if let gate = try? WaveKnotKeeperGate(min: lo, max: hi) { gateList.append(gate) }
            }
            let summary = WaveKnotKeeperGeometry.summary(goal)
            guard let target = try? WaveKnotKeeperTarget(crossings: summary.crossings, writhe: summary.writhe) else {
                continue
            }
            // Walk away from the goal with legal moves.
            var points = goal
            var walk: [WaveKnotKeeperMove] = []
            var maxTension = WaveKnotKeeperGeometry.tension(points)
            let steps = random.int(3...10)
            var attempts = 0
            while walk.count < steps && attempts < 400 {
                attempts += 1
                let move = WaveKnotKeeperMove(point: random.int(0...(count - 1)), direction: random.direction())
                if let last = walk.last, last.point == move.point, last.direction == move.direction.opposite { continue }
                let rules = ProbeLevel(gates: gateList)
                guard rules.legal(move, points) else { continue }
                points[move.point] = points[move.point].moved(move.direction)
                walk.append(move)
                maxTension = max(maxTension, WaveKnotKeeperGeometry.tension(points))
            }
            guard walk.count == steps else { continue }
            var solution: [WaveKnotKeeperMove] = []
            for move in walk.reversed() {
                solution.append(WaveKnotKeeperMove(point: move.point, direction: move.direction.opposite))
            }
            let bound = min(maxTension + random.int(0...40), 49_152)
            guard let level = try? WaveKnotKeeperLevel(id: "fixture-\(index)", seed: seed &+ UInt64(index),
                                                       band: 1 + index % 5, points: points, gates: gateList,
                                                       target: target, tensionBound: bound,
                                                       allowance: min(64, steps + random.int(0...6))) else { continue }
            return WaveKnotKeeperFixture(level: level, solution: solution, goal: goal)
        }
    }

    /// The legality rules of a move without a level (bounds, coincidence, sweep outside the gates), as the play
    /// checks them before the tension bound.
    struct ProbeLevel {
        let gates: [WaveKnotKeeperGate]

        func legal(_ move: WaveKnotKeeperMove, _ points: [WaveKnotKeeperPoint]) -> Bool {
            let from = points[move.point]
            let to = from.moved(move.direction)
            guard to.isInBounds, !points.contains(to) else { return false }
            if gates.contains(where: { $0.contains(from) && $0.contains(to) }) { return true }
            return WaveKnotKeeperGeometry.sweepIsClear(points, moving: move.point, to: to)
        }
    }

    /// A fresh play of `level` in stage `playing`.
    static func playing(_ level: WaveKnotKeeperLevel) throws -> WaveKnotKeeperPlay {
        try WaveKnotKeeperPlay.replay(level: level, records: [])
    }
}
