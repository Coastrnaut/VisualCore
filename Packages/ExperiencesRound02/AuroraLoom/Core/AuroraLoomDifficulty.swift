// AuroraLoomDifficulty — feature 302 (R02-G01-02) T-R02G0102-002 (FR-R02G0102-003; clarification Q3; research R8). A
// level's difficulty taken from the solver's actual work: the shortest solution, the setting evaluations spent, the
// winning settings available, the tolerance and the harmony's speed.
import VisualCoreSimulation

/// The difficulty of an Aurora Loom level, measured by its solution.
public struct AuroraLoomDifficulty: Sendable, Equatable, Hashable, Codable {
    /// The fewest moves that win.
    public let shortest: Int
    /// The setting evaluations the solver spent.
    public let work: Int
    /// The winning settings over the three ribbons (the sum of each ribbon's count).
    public let winningSettings: Int
    /// The level's tolerance in phase units.
    public let tolerance: Int
    /// The level's harmony speed Ω.
    public let omega: Int

    /// The difficulty of `level` as solved by `solution`.
    public init(level: AuroraLoomLevel, solution: AuroraLoomSolution) {
        shortest = solution.shortest
        work = solution.work
        winningSettings = solution.winningSettings.reduce(0, +)
        tolerance = level.tolerance
        omega = level.omega
    }

    /// The R02-F24 measure: shortest solution, then work as the states explored.
    public var puzzleDifficulty: PuzzleDifficulty {
        PuzzleDifficulty(shortest: shortest, explored: work)
    }
}
