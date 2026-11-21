// ColorfallCanyonsDifficulty — feature 342 (R02-G05-02) T-R02G0502-002 (FR-R02G0502-003, 005; clarification Q3). The
// difficulty metrics of a generated level, from the level and the solver's actual result. The smallest edit count comes
// from `ColorfallCanyonsSolver`; harder bands need more edits (the band ranges of `ColorfallCanyonsBandProfile`).
import VisualCoreSimulation

/// The difficulty of one level, from the level and the solver's actual result.
public struct ColorfallCanyonsDifficulty: Sendable, Equatable, Hashable, Codable {
    /// The smallest number of edits (carves and valve toggles before the first tick) that wins.
    public let smallest: Int
    /// The solver's work: distinct routings simulated.
    public let work: Int
    /// The tick at which the witness wins.
    public let winTick: Int
    /// The level's springs.
    public let springs: Int
    /// The level's basins.
    public let basins: Int
    /// The level's protected basins.
    public let protectedBasins: Int
    /// The level's carvable cells at the start.
    public let carvableCells: Int

    /// A difficulty of the given values.
    public init(smallest: Int, work: Int, winTick: Int, springs: Int, basins: Int, protectedBasins: Int,
                carvableCells: Int) {
        self.smallest = smallest
        self.work = work
        self.winTick = winTick
        self.springs = springs
        self.basins = basins
        self.protectedBasins = protectedBasins
        self.carvableCells = carvableCells
    }

    /// The R02-F24 difficulty the progression rule reads: the smallest edit count, with the solver's work as explored.
    public var puzzleDifficulty: PuzzleDifficulty {
        PuzzleDifficulty(shortest: smallest, explored: work)
    }
}
