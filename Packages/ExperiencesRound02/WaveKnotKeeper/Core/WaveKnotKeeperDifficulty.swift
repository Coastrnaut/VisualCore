// WaveKnotKeeperDifficulty — feature 322 (R02-G03-02) T-R02G0302-002 (FR-R02G0302-003; clarification Q3). The difficulty
// metrics of a generated level, taken from the level and the solver's actual result: the shortest solution, the rope's
// point count, the number of crossing gates, the target crossing count and the solver's work (ropes expanded).
import VisualCoreSimulation

/// The difficulty metrics of one generated level.
public struct WaveKnotKeeperDifficulty: Sendable, Equatable, Hashable, Codable {
    /// The fewest moves that win the level (the solver's shortest solution).
    public let shortest: Int
    /// The rope's control-point count.
    public let points: Int
    /// The number of crossing gates.
    public let gates: Int
    /// The target crossing count.
    public let crossings: Int
    /// The ropes the solver expanded.
    public let work: Int

    /// Metrics of the given values (not checked).
    public init(shortest: Int, points: Int, gates: Int, crossings: Int, work: Int) {
        self.shortest = shortest
        self.points = points
        self.gates = gates
        self.crossings = crossings
        self.work = work
    }

    /// The metrics of `level` solved by `solution`.
    public init(level: WaveKnotKeeperLevel, solution: WaveKnotKeeperSolution) {
        self.init(shortest: solution.shortest, points: level.points.count, gates: level.gates.count,
                  crossings: level.target.crossings, work: solution.work)
    }

    /// The R02-F24 measure: shortest solution, then work as the ropes explored.
    public var puzzleDifficulty: PuzzleDifficulty {
        PuzzleDifficulty(shortest: shortest, explored: work)
    }
}
