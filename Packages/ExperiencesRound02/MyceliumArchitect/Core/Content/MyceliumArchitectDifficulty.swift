// MyceliumArchitectDifficulty — feature 512 (R02-G22-02) T-R02G2202-003 (FR-R02G2202-002, 003; clarifications Q3,
// Q4). The solver's result and the difficulty metrics stored with every catalog level, shared by the solver, the
// generator and the witness without a cycle.

/// What the solver found: the minimal plan and its proof.
public struct MyceliumArchitectSolution: Sendable, Equatable {
    /// The plan's arrangement actions, then `run`.
    public let actions: [MyceliumArchitectAction]
    /// The arrangements judged, the start included.
    public let work: Int
    /// The arrangements at each depth below the plan's length, every one judged and none winning.
    public let countsByDepth: [Int]
    /// The smallest loss among the arrangements judged at smaller depths, the start included.
    public let nearestMissLoss: Int
    /// The arrangement of that nearest miss.
    public let nearestMiss: MyceliumArchitectArrangement
    /// The nearest miss's first failure.
    public let nearestMissFailure: MyceliumArchitectFailure?

    /// A solution of these values.
    public init(actions: [MyceliumArchitectAction], work: Int, countsByDepth: [Int], nearestMissLoss: Int,
                nearestMiss: MyceliumArchitectArrangement, nearestMissFailure: MyceliumArchitectFailure?) {
        self.actions = actions
        self.work = work
        self.countsByDepth = countsByDepth
        self.nearestMissLoss = nearestMissLoss
        self.nearestMiss = nearestMiss
        self.nearestMissFailure = nearestMissFailure
    }

    /// The plan's length in arrangement actions (the run excluded).
    public var length: Int { actions.count - 1 }
}

/// The difficulty metrics of a catalog level, from the level and the solver's actual work.
public struct MyceliumArchitectDifficulty: Sendable, Hashable, Codable {
    /// The witness length in arrangement actions.
    public let witnessLength: Int
    /// The number of terminals.
    public let terminals: Int
    /// The board's cells, width × height.
    public let boardCells: Int
    /// The toxic cells.
    public let toxins: Int
    /// The placement sites.
    public let sites: Int
    /// The legal moves from the start.
    public let moveSpace: Int
    /// The arrangements judged at depths below the witness length.
    public let searchedBelow: Int
    /// The arrangements the solver judged in all.
    public let work: Int
    /// The nearest miss's loss.
    public let nearestMiss: Int

    /// Difficulty metrics of these values.
    public init(witnessLength: Int, terminals: Int, boardCells: Int, toxins: Int, sites: Int, moveSpace: Int,
                searchedBelow: Int, work: Int, nearestMiss: Int) {
        self.witnessLength = witnessLength
        self.terminals = terminals
        self.boardCells = boardCells
        self.toxins = toxins
        self.sites = sites
        self.moveSpace = moveSpace
        self.searchedBelow = searchedBelow
        self.work = work
        self.nearestMiss = nearestMiss
    }

    /// The metrics of `level` and its `solution`.
    public init(level: MyceliumArchitectLevel, solution: MyceliumArchitectSolution) {
        let puzzle = MyceliumArchitectPuzzle(level: level)
        self.init(witnessLength: solution.length, terminals: level.terminals.count,
                  boardCells: level.width * level.height, toxins: level.toxins.count,
                  sites: level.sites?.count ?? 0, moveSpace: puzzle.moves(in: puzzle.initialState).count,
                  searchedBelow: solution.countsByDepth.reduce(0, +), work: solution.work,
                  nearestMiss: solution.nearestMissLoss)
    }
}
