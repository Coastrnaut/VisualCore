// NocturneGardenDifficulty — feature 382 (R02-G09-02) T-R02G0902-002 (FR-R02G0902-003; clarification Q3). A level's
// difficulty metrics, taken from the level and the solver's actual result: the smallest move count, the distinct kinds
// and sizes the witness plants, whether it changes the sun, the target's and the forbidden regions' cell counts, the
// required match and the plant evaluations the solver spent.
import VisualCoreSimulation

/// The difficulty metrics of a certified level.
public struct NocturneGardenDifficulty: Sendable, Hashable, Codable {
    /// The smallest move count (the solver's lower bound, met by the witness).
    public let smallest: Int
    /// The distinct bloom kinds the witness plants.
    public let kinds: Int
    /// The distinct sizes the witness plants.
    public let sizes: Int
    /// Whether the witness changes the sun.
    public let sunChange: Bool
    /// The target's cell count.
    public let targetCells: Int
    /// The forbidden regions' cell count.
    public let forbiddenCells: Int
    /// The required match.
    public let required: NocturneGardenRatio
    /// The plant evaluations the solver spent.
    public let work: Int

    /// Metrics of the given values.
    public init(smallest: Int, kinds: Int, sizes: Int, sunChange: Bool, targetCells: Int, forbiddenCells: Int,
                required: NocturneGardenRatio, work: Int) {
        self.smallest = smallest
        self.kinds = kinds
        self.sizes = sizes
        self.sunChange = sunChange
        self.targetCells = targetCells
        self.forbiddenCells = forbiddenCells
        self.required = required
        self.work = work
    }

    /// The metrics of `actions` (the witness, `work` plant evaluations) on `level`.
    public init(level: NocturneGardenLevel, actions: [NocturneGardenAction], work: Int) {
        var kinds: Set<NocturneGardenKind> = []
        var sizes: Set<Int> = []
        var sunChange: Bool = false
        for action in actions {
            switch action {
            case let .plant(kind, _, _, size):
                kinds.insert(kind)
                sizes.insert(size)
            case .sun:
                sunChange = true
            case .move, .resize, .remove:
                break
            }
        }
        self.init(smallest: actions.count, kinds: kinds.count, sizes: sizes.count, sunChange: sunChange,
                  targetCells: level.target.count, forbiddenCells: level.forbidden.count, required: level.required,
                  work: work)
    }

    /// The R02-F24 difficulty: shortest = the smallest move count, explored = the plant evaluations.
    public var puzzleDifficulty: PuzzleDifficulty { PuzzleDifficulty(shortest: smallest, explored: work) }
}
