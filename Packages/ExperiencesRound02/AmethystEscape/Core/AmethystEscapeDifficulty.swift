// AmethystEscapeDifficulty — feature 362 (R02-G07-02) T-R02G0702-002 (FR-R02G0702-003; clarification Q3). A level's
// difficulty metrics, taken from the level and the solver's actual result: the smallest move count, the witness's turns
// and advances, the shell and sector counts and the states the proof explored.
import VisualCoreSimulation

/// The difficulty metrics of a certified level.
public struct AmethystEscapeDifficulty: Sendable, Hashable, Codable {
    /// The smallest move count.
    public let smallest: Int
    /// The witness's shell turns.
    public let turns: Int
    /// The witness's advances.
    public let advances: Int
    /// The number of shells.
    public let shells: Int
    /// The number of sectors.
    public let sectors: Int
    /// The states the search expanded.
    public let explored: Int

    /// Metrics of the given values.
    public init(smallest: Int, turns: Int, advances: Int, shells: Int, sectors: Int, explored: Int) {
        self.smallest = smallest
        self.turns = turns
        self.advances = advances
        self.shells = shells
        self.sectors = sectors
        self.explored = explored
    }

    /// The metrics of `solution` on `level`.
    public init(level: AmethystEscapeLevel, solution: AmethystEscapeSolution) {
        var turns = 0
        for action in solution.actions {
            if case .rotate = action { turns += 1 }
        }
        self.init(smallest: solution.smallest, turns: turns, advances: solution.smallest - turns,
                  shells: level.shells.count, sectors: level.sectors, explored: solution.work)
    }

    /// The R02-F24 difficulty: shortest = the smallest move count, explored = the states expanded.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: smallest, explored: explored) }
}
