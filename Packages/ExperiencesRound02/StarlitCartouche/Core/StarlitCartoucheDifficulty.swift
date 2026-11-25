// StarlitCartoucheDifficulty — feature 452 (R02-G16-02) T-R02G1602-002 (FR-R02G1602-003; SC-R02G1602-004;
// clarification Q3). The difficulty metrics of a certified Starlit Cartouche level, from the level and the solver's
// actual result: the witness leg count, the stars, the corridors, the hazards, the symbol strokes, the states searched
// at smaller depths and the solver work. Modelled on `VoxelOrigamiDifficulty` (feature 442).
import VisualCoreSimulation

/// The difficulty metrics of a certified level.
public struct StarlitCartoucheDifficulty: Sendable, Hashable, Codable {
    /// The witness leg count (the plan's size).
    public let legs: Int
    /// The stars.
    public let stars: Int
    /// The corridors.
    public let corridors: Int
    /// The hazard tubes.
    public let hazards: Int
    /// The symbol's strokes.
    public let strokes: Int
    /// The states reached at every depth below the plan's.
    public let statesSearched: Int
    /// The legs the solver tried.
    public let work: Int

    /// The metrics of the given values.
    public init(legs: Int, stars: Int, corridors: Int, hazards: Int, strokes: Int, statesSearched: Int, work: Int) {
        self.legs = legs
        self.stars = stars
        self.corridors = corridors
        self.hazards = hazards
        self.strokes = strokes
        self.statesSearched = statesSearched
        self.work = work
    }

    /// The metrics of `level` certified by `plan`.
    public init(level: StarlitCartoucheLevel, plan: StarlitCartouchePlan) {
        self.init(legs: plan.size, stars: level.stars.count, corridors: level.corridors.count,
                  hazards: level.hazards.count, strokes: level.symbol.count, statesSearched: plan.statesSearched,
                  work: plan.work)
    }

    /// The shared difficulty of R02-F24: the shortest plan and the work explored.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: legs, explored: work) }
}
