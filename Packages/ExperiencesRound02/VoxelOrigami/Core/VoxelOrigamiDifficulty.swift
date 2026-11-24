// VoxelOrigamiDifficulty — feature 442 (R02-G15-02) T-R02G1502-002 (FR-R02G1502-003; SC-R02G1502-004; clarification Q3).
// The difficulty metrics of a certified Voxel Origami level, from the level and the solver's actual result: the witness
// turn count, the cubes, the hinges that can turn at the start, the orientations, the states searched at smaller depths
// and the solver work. Modelled on `MoonlitMechanismDifficulty` (feature 432).
import VisualCoreSimulation

/// The difficulty metrics of a certified level.
public struct VoxelOrigamiDifficulty: Sendable, Hashable, Codable {
    /// The witness turn count (the plan's size).
    public let turns: Int
    /// The cubes.
    public let cubes: Int
    /// The hinges that would swing a cube at the start.
    public let turnableHinges: Int
    /// The orientations the match allows.
    public let orientations: VoxelOrigamiOrientations
    /// The states reached at every depth below the plan's.
    public let statesSearched: Int
    /// The turns the solver tried.
    public let work: Int

    /// The metrics of the given values.
    public init(turns: Int, cubes: Int, turnableHinges: Int, orientations: VoxelOrigamiOrientations,
                statesSearched: Int, work: Int) {
        self.turns = turns
        self.cubes = cubes
        self.turnableHinges = turnableHinges
        self.orientations = orientations
        self.statesSearched = statesSearched
        self.work = work
    }

    /// The metrics of `level` certified by `plan`.
    public init(level: VoxelOrigamiLevel, plan: VoxelOrigamiPlan) {
        var turnable: Int = 0
        for hinge in 1..<level.cubes.count where level.canTurn(hinge, turns: level.startTurns) { turnable += 1 }
        self.init(turns: plan.size, cubes: level.cubes.count, turnableHinges: turnable,
                  orientations: level.orientations, statesSearched: plan.statesSearched, work: plan.work)
    }

    /// The shared difficulty of R02-F24: the shortest plan and the work explored.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: turns, explored: work) }
}
