// FacetedForgeDifficulty — feature 372 (R02-G08-02) T-R02G0802-002 (FR-R02G0802-003; clarification Q3). A level's
// difficulty metrics, taken from the level and the solver's actual result: the smallest cut count, the distinct
// directions and the diagonal directions of the witness, the crystal's face count, the target's piece count and the
// cut evaluations the solver spent.
import VisualCoreSimulation

/// The difficulty metrics of a certified level.
public struct FacetedForgeDifficulty: Sendable, Hashable, Codable {
    /// The smallest cut count (target pieces − 1).
    public let smallest: Int
    /// The distinct directions the witness uses.
    public let directions: Int
    /// The witness's cuts along a face or body diagonal (directions 3 … 12).
    public let diagonals: Int
    /// The crystal's face count.
    public let crystalFaces: Int
    /// The target's piece count.
    public let pieces: Int
    /// The cut evaluations the solver spent.
    public let work: Int

    /// Metrics of the given values.
    public init(smallest: Int, directions: Int, diagonals: Int, crystalFaces: Int, pieces: Int, work: Int) {
        self.smallest = smallest
        self.directions = directions
        self.diagonals = diagonals
        self.crystalFaces = crystalFaces
        self.pieces = pieces
        self.work = work
    }

    /// The metrics of `actions` (the witness, `work` cut evaluations) on `level`.
    public init(level: FacetedForgeLevel, actions: [FacetedForgeAction], work: Int) {
        var used: Set<Int> = []
        var diagonals: Int = 0
        for action in actions {
            guard case let .cut(_, direction, _) = action else { continue }
            used.insert(direction)
            if direction >= 3 { diagonals += 1 }
        }
        self.init(smallest: actions.count, directions: used.count, diagonals: diagonals,
                  crystalFaces: level.crystal.faceCount, pieces: level.target.count, work: work)
    }

    /// The R02-F24 difficulty: shortest = the smallest cut count, explored = the cut evaluations.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: smallest, explored: work) }
}
