// VoxelOrigamiSolver — feature 442 (R02-G15-02) T-R02G1502-003 (FR-R02G1502-002; SC-R02G1502-001, 002, 005;
// clarification Q2). The certifying solver of Voxel Origami: a breadth-first search over quarter-turn states from a
// level's start, the exact case of the catalog's "A-star over hinge-angle lattice states with swept AABB collision
// filter" (a zero heuristic). At each depth the states are expanded in the order they were reached; each state's moves
// in the order hinges ascending, step −1 then +1; a move is tried only on a hinge that would swing a cube, and reaches a
// state only when the kernel's collision and exact sweep rule clear it (the swept collision filter); states are merged
// by their quarter turns. The first reached state whose pose matches the target ends the search and its path is the
// plan. Work = turns tried, counted and bounded; over the bound, or past the most turns asked for, there is no plan. The
// minimality proof is that every state reachable in fewer turns was reached and none matched (the states reached at
// each smaller depth are counted). Nothing here reads a clock.

/// A minimal plan of a level: its turns in order, the states reached at each smaller depth and the work.
public struct VoxelOrigamiPlan: Sendable, Equatable, Codable {
    /// The turns of the plan, in order.
    public let turns: [VoxelOrigamiAction]
    /// The states reached at depths 0 … size − 1 (depth 0 is the start alone: 1); none matched.
    public let statesByDepth: [Int]
    /// The turns tried before the plan was found.
    public let work: Int

    /// A plan of the given values.
    public init(turns: [VoxelOrigamiAction], statesByDepth: [Int], work: Int) {
        self.turns = turns
        self.statesByDepth = statesByDepth
        self.work = work
    }

    /// The number of turns.
    public var size: Int { turns.count }

    /// The states reached at every smaller depth together.
    public var statesSearched: Int { statesByDepth.reduce(0, +) }
}

/// The breadth-first solver of Voxel Origami (see the file header).
public enum VoxelOrigamiSolver {
    /// The most turns tried for one level.
    public static let workBound: Int = 300_000
    /// The most turns a plan may have.
    public static let maxTurns: Int = 6

    /// The minimal plan of `level` from its start within `maxTurns` turns and `workBound` turns tried, or nil.
    public static func plan(_ level: VoxelOrigamiLevel, maxTurns: Int = maxTurns,
                            workBound: Int = workBound) -> VoxelOrigamiPlan? {
        let cubes: [VoxelOrigamiCube] = level.cubes
        let group: [VoxelOrigamiRotation] = level.orientations.group
        let start: [Int] = level.startTurns
        guard VoxelOrigamiLattice.canonical(level.pose(turns: start).cells, group: group) != level.targetCanonical
        else { return nil }
        var parent: [[Int]: ([Int], VoxelOrigamiAction)] = [:]
        var seen: Set<[Int]> = [start]
        var frontier: [[Int]] = [start]
        var statesByDepth: [Int] = []
        var work: Int = 0
        var depth: Int = 0
        while !frontier.isEmpty, depth < maxTurns {
            statesByDepth.append(frontier.count)
            depth += 1
            var next: [[Int]] = []
            for state in frontier {
                let pose: VoxelOrigamiPose = level.pose(turns: state)
                for hinge in 1..<cubes.count
                where !VoxelOrigamiLattice.swinging(cubes, pose: pose, hinge: hinge).isEmpty {
                    for step in [-1, 1] {
                        work += 1
                        if work > workBound { return nil }
                        guard VoxelOrigamiLattice.check(cubes, turns: state, hinge: hinge, step: step) == nil
                        else { continue }
                        let reached: [Int] = VoxelOrigamiLattice.turned(state, hinge: hinge, step: step)
                        guard seen.insert(reached).inserted else { continue }
                        parent[reached] = (state, .turn(hinge, step))
                        let cells: [VoxelOrigamiVector] = level.pose(turns: reached).cells
                        if VoxelOrigamiLattice.canonical(cells, group: group) == level.targetCanonical {
                            return VoxelOrigamiPlan(turns: path(to: reached, from: start, parent: parent),
                                                    statesByDepth: statesByDepth, work: work)
                        }
                        next.append(reached)
                    }
                }
            }
            frontier = next
        }
        return nil
    }

    /// The turns from `start` to `state` along the recorded parents.
    static func path(to state: [Int], from start: [Int],
                     parent: [[Int]: ([Int], VoxelOrigamiAction)]) -> [VoxelOrigamiAction] {
        var turns: [VoxelOrigamiAction] = []
        var current: [Int] = state
        while current != start, let (previous, action) = parent[current] {
            turns.append(action)
            current = previous
        }
        return turns.reversed()
    }

    /// Whether `actions`, applied through the kernel's play from `level`'s start, end with the level won on the last
    /// one.
    public static func matches(_ level: VoxelOrigamiLevel, actions: [VoxelOrigamiAction]) -> Bool {
        var play = VoxelOrigamiPlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for (index, action) in actions.enumerated() {
                try play.apply(action, expecting: play.fingerprint)
                if play.stage == .won { return index == actions.count - 1 }
                guard play.stage == .playing else { return false }
            }
        } catch {
            return false
        }
        return false
    }
}
