// LissajousLabyrinthDifficulty — feature 312 (R02-G02-02) T-R02G0202-002 (FR-R02G0202-003; clarification Q3; research
// R5). A level's difficulty taken from the solver's result: the shortest action count, the winning settings among the
// 14,080 legal ones, the minimum clearance of the winning path and the exact verdicts the solver spent.
import VisualCoreSimulation

/// The difficulty of a Lissajous Labyrinth level, measured by its solution.
public struct LissajousLabyrinthDifficulty: Sendable, Equatable, Hashable, Codable {
    /// The fewest actions that win.
    public let shortest: Int
    /// The legal settings that win.
    public let winningSettings: Int
    /// The minimum over samples and obstacles of squared distance minus squared radius for the solution's setting
    /// (``clearance(_:level:)``); `Int.max` for a level without obstacles.
    public let clearance: Int
    /// The exact verdicts the solver spent.
    public let work: Int

    /// A difficulty of the given values.
    public init(shortest: Int, winningSettings: Int, clearance: Int, work: Int) {
        self.shortest = shortest
        self.winningSettings = winningSettings
        self.clearance = clearance
        self.work = work
    }

    /// The difficulty of `level` as solved by `solution`.
    public init(level: LissajousLabyrinthLevel, solution: LissajousLabyrinthSolution) {
        self.init(shortest: solution.shortest, winningSettings: solution.winningSettings,
                  clearance: Self.clearance(solution.setting, level: level), work: solution.work)
    }

    /// The smallest squared distance minus squared radius between any of the 4,096 samples of `dials` and any obstacle
    /// of `level` (exact integers; positive means every sample is outside every obstacle); `Int.max` without obstacles.
    public static func clearance(_ dials: LissajousLabyrinthDials, level: LissajousLabyrinthLevel) -> Int {
        guard !level.obstacles.isEmpty else { return Int.max }
        let points = LissajousLabyrinthLap.samples(dials, level: level)
        var best = Int.max
        for point in points {
            for ball in level.obstacles {
                let dx = point.x - ball.x, dy = point.y - ball.y, dz = point.z - ball.z
                best = min(best, dx * dx + dy * dy + dz * dz - ball.radius * ball.radius)
            }
        }
        return best
    }

    /// The R02-F24 measure: shortest solution, then work as the states explored.
    public var puzzleDifficulty: PuzzleDifficulty {
        PuzzleDifficulty(shortest: shortest, explored: work)
    }
}
