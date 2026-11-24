// VoxelOrigamiFixtures — feature 441 (R02-G15-01) T-R02G1501-002 (SC-R02G1501-001 … 004). Seeded Voxel Origami levels
// with known winning turns. A fixture draws a tree of 4 … 9 cubes (each non-root cube attached to a random lower-index
// parent along a random rest direction, redrawn until the rest pose is collision-free), a solution pose (random quarter
// turns, redrawn until collision-free), the target (the solution's cells under a random rotation of the level's allowed
// group and a random shift, sorted) and the orientations (`fixed`, `upright` or `any`). The solution is scrambled by
// 1 … 5 random clear turns (non-idle hinges whose turn passes the lattice check); the start is the scrambled pose and
// the known turns are the inverse turns in reverse order, cut at the first pose that matches the target. A start that
// already matches is redrawn, so every fixture needs at least one turn. `apply` is the fixtures' own step of a turn,
// independent of the play.
import Foundation
import VisualCoreSimulation
@testable import VoxelOrigamiCore

/// A seeded level with its known winning turns.
struct VoxelOrigamiFixture: Sendable {
    /// The level.
    let level: VoxelOrigamiLevel
    /// The known turns, each `.turn(hinge, step)`; the last one wins.
    let actions: [VoxelOrigamiAction]
    /// The solution's quarter turns.
    let solution: [Int]

    /// The fixture seed of the feature.
    static let seed: UInt64 = 2_441

    /// `count` fixtures from `seed`, in order.
    static func all(count: Int, seed: UInt64 = seed) -> [VoxelOrigamiFixture] {
        var random = SeededRandom(seed: seed)
        var fixtures: [VoxelOrigamiFixture] = []
        var index: Int = 0
        while fixtures.count < count {
            if let fixture = make(&random, index: index) { fixtures.append(fixture) }
            index += 1
        }
        return fixtures
    }

    /// The quarter turns after `action`, or nil when the turn is refused or fails (an unknown hinge, a wrong step, an
    /// idle hinge, a collision or a sweep).
    static func apply(_ action: VoxelOrigamiAction, cubes: [VoxelOrigamiCube], turns: [Int]) -> [Int]? {
        guard case .turn(let hinge, let step) = action, hinge >= 1, hinge < cubes.count, step == 1 || step == -1
        else { return nil }
        let pose: VoxelOrigamiPose = VoxelOrigamiLattice.pose(cubes, turns: turns)
        guard !VoxelOrigamiLattice.swinging(cubes, pose: pose, hinge: hinge).isEmpty else { return nil }
        guard VoxelOrigamiLattice.check(cubes, turns: turns, hinge: hinge, step: step) == nil else { return nil }
        return VoxelOrigamiLattice.turned(turns, hinge: hinge, step: step)
    }

    /// A random tree of `count` cubes whose rest pose is collision-free (redrawn up to 50 times), or nil.
    static func tree(_ random: inout SeededRandom, count: Int) -> [VoxelOrigamiCube]? {
        for _ in 0..<50 {
            var cubes: [VoxelOrigamiCube] = [.root]
            for index in 1..<count {
                let parent: Int = random.int(0...(index - 1))
                let direction: VoxelOrigamiVector = VoxelOrigamiVector.units[random.int(0...5)]
                cubes.append(VoxelOrigamiCube(parent: parent, direction: direction, startTurn: 0))
            }
            if VoxelOrigamiLattice.pose(cubes, turns: Array(repeating: 0, count: count)).isCollisionFree {
                return cubes
            }
        }
        return nil
    }

    /// One fixture, or nil when the draw does not qualify.
    static func make(_ random: inout SeededRandom, index: Int) -> VoxelOrigamiFixture? {
        let count: Int = random.int(4...9)
        guard let rest = tree(&random, count: count) else { return nil }
        var solution: [Int] = [0]
        for _ in 1..<count { solution.append(random.int(0...3)) }
        let solved: VoxelOrigamiPose = VoxelOrigamiLattice.pose(rest, turns: solution)
        guard solved.isCollisionFree else { return nil }
        let orientations: VoxelOrigamiOrientations = VoxelOrigamiOrientations.allCases[random.int(0...2)]
        let group: [VoxelOrigamiRotation] = orientations.group
        let rotation: VoxelOrigamiRotation = group[random.int(0...(group.count - 1))]
        let shift = VoxelOrigamiVector(random.int(-3...3), random.int(-3...3), random.int(-3...3))
        let target: [VoxelOrigamiVector] = solved.cells.map { rotation.applied(to: $0) + shift }.sorted()
        // Scramble with 1 … 5 clear turns.
        var turns: [Int] = solution
        var forward: [VoxelOrigamiAction] = []
        let scrambles: Int = random.int(1...5)
        var attempts: Int = 0
        while forward.count < scrambles, attempts < 60 {
            attempts += 1
            let hinge: Int = random.int(1...(count - 1))
            let step: Int = random.int(0...1) == 0 ? -1 : 1
            let action: VoxelOrigamiAction = .turn(hinge, step)
            guard let next = apply(action, cubes: rest, turns: turns) else { continue }
            turns = next
            forward.append(action)
        }
        guard !forward.isEmpty else { return nil }
        let canonicalTarget: [VoxelOrigamiVector] = VoxelOrigamiLattice.canonical(target, group: group)
        func matches(_ t: [Int]) -> Bool {
            VoxelOrigamiLattice.canonical(VoxelOrigamiLattice.pose(rest, turns: t).cells, group: group)
                == canonicalTarget
        }
        guard !matches(turns) else { return nil }
        // The inverse turns in reverse order, cut at the first match.
        var known: [VoxelOrigamiAction] = []
        var replay: [Int] = turns
        for action in forward.reversed() {
            guard case .turn(let hinge, let step) = action,
                  let next = apply(.turn(hinge, -step), cubes: rest, turns: replay) else { return nil }
            replay = next
            known.append(.turn(hinge, -step))
            if matches(replay) { break }
        }
        guard matches(replay) else { return nil }
        var cubes: [VoxelOrigamiCube] = []
        for (position, cube) in rest.enumerated() {
            cubes.append(VoxelOrigamiCube(parent: cube.parent, direction: cube.direction,
                                          startTurn: position == 0 ? 0 : turns[position]))
        }
        let budget: Int = min(40, known.count + random.int(0...4))
        guard let level = try? VoxelOrigamiLevel(id: "fixture-\(index)", seed: Self.seed &+ UInt64(index),
                                                 difficulty: min(5, max(1, known.count)), cubes: cubes,
                                                 target: target, orientations: orientations, budget: budget,
                                                 tutorial: index % 7 == 0) else { return nil }
        return VoxelOrigamiFixture(level: level, actions: known, solution: solution)
    }
}
