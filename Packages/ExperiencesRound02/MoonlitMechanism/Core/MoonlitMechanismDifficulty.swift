// MoonlitMechanismDifficulty — feature 432 (R02-G14-02) T-R02G1402-002 (FR-R02G1402-003; clarification Q3). The
// difficulty metrics of a certified level, all from the level and the solver's actual plan: the witness action count
// (before the run), the gears, the meshes, the total teeth, the key frames and the required ones, the target cells of
// all key frames, the forbidden cells, the lamp heights, the vectors of smaller norms tried (the minimality proof) and
// the solver's work (runs).
import Foundation
import VisualCoreSimulation

/// The difficulty metrics of a certified Moonlit Mechanism level.
public struct MoonlitMechanismDifficulty: Sendable, Hashable, Codable {
    /// The actions of the witness plan before the run (turns, re-seats and lamp steps).
    public let actions: Int
    /// The gears.
    public let gears: Int
    /// The meshes (gears − 1).
    public let meshes: Int
    /// The teeth of all gears.
    public let teeth: Int
    /// The key frames.
    public let keyFrames: Int
    /// The required key frames.
    public let requiredKeyFrames: Int
    /// The target cells of all key frames.
    public let targetCells: Int
    /// The forbidden cells.
    public let forbiddenCells: Int
    /// The lamp heights.
    public let lampHeights: Int
    /// The plan vectors of smaller norms the solver tried, none of which wins.
    public let smallerVectors: Int
    /// The runs the solver judged in all.
    public let work: Int

    /// Metrics of the given values.
    public init(actions: Int, gears: Int, meshes: Int, teeth: Int, keyFrames: Int, requiredKeyFrames: Int,
                targetCells: Int, forbiddenCells: Int, lampHeights: Int, smallerVectors: Int, work: Int) {
        self.actions = actions
        self.gears = gears
        self.meshes = meshes
        self.teeth = teeth
        self.keyFrames = keyFrames
        self.requiredKeyFrames = requiredKeyFrames
        self.targetCells = targetCells
        self.forbiddenCells = forbiddenCells
        self.lampHeights = lampHeights
        self.smallerVectors = smallerVectors
        self.work = work
    }

    /// The metrics of `plan` on `level`.
    public init(level: MoonlitMechanismLevel, plan: MoonlitMechanismPlan) {
        var targets: Int = 0
        for frame in level.keyFrames { targets += frame.target.count }
        self.init(actions: plan.size, gears: level.gears.count, meshes: level.gears.count - 1,
                  teeth: level.gears.reduce(0) { $0 + $1.teeth }, keyFrames: level.keyFrames.count,
                  requiredKeyFrames: level.keyFrames.filter(\.required).count, targetCells: targets,
                  forbiddenCells: level.forbidden.count, lampHeights: level.lampHeights,
                  smallerVectors: plan.smallerVectors, work: plan.work)
    }

    /// The R02-F24 difficulty: shortest = the witness action count, explored = the runs the solver judged.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: actions, explored: work) }
}
