// MyceliumArchitectPuzzle — feature 511 (R02-G22-01) T-R02G2201-005 (FR-R02G2201-011; research R14). Mycelium
// Architect expressed as an R02-F23 puzzle contract so R02-G22-02 can certify levels with `PuzzleValidator`: a state is
// a `Position` (the arrangement — placed nutrients, placed blockers and seeds — and the actions spent), a move is a
// `MyceliumArchitectAction` arrangement action (nutrient, blocker, clear, seed, unseed; never the run), and a state is
// solved when the predicted run wins (`MyceliumArchitectGrowth.report(level, arrangement:).wins`). While actions are
// left the legal moves are, in exactly this order: `nutrient(cell)` for the empty cells in ascending (row, column),
// then `blocker(cell)` for the empty cells likewise, then `clear(cell)` for the placed nutrients and blockers merged in
// ascending (row, column), then `seed(direction)` in ascending direction, then `unseed(direction)` in ascending
// direction — each skipping the moves the play would refuse (a placement limit reached, a direction already seeded, the
// seed limit reached, a starting seed). With the budget spent nothing is legal. A move list holds at most
// 2 · W · H + 6 + 8 + 8 moves, so R02-G22-02's fairness budget passes a maxBranching of at least 2 · W · H + 20.
// Applying a move uses the same check as the play's `apply(_:expecting:)` (`MyceliumArchitectPlay.changed`), so a move
// is legal here exactly when the play accepts it in `playing` with actions left, and both produce the same
// arrangement; a move the play would refuse, or the run, is refused (nil). The rules carry no stage, fingerprints,
// report, failure, records, undo or redo: those belong to the play. Integers only; no clock, no random source.
// Modelled on `BinaryGardensPuzzle` (feature 501).
import VisualCoreSimulation

/// The pure rules of one Mycelium Architect level as an R02-F23 puzzle contract.
public struct MyceliumArchitectPuzzle: PuzzleRules {
    /// A position of a Mycelium Architect play as the rules see it: the arrangement and the actions spent.
    public struct Position: Hashable, Codable, Sendable {
        /// The arrangement: placed nutrients, placed blockers and seeds.
        public let arrangement: MyceliumArchitectArrangement
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int

        /// A position of the given values (not checked).
        public init(arrangement: MyceliumArchitectArrangement, actionsSpent: Int) {
            self.arrangement = arrangement
            self.actionsSpent = actionsSpent
        }
    }

    /// A position: the arrangement and the actions spent.
    public typealias State = Position
    /// A player action: a nutrient, blocker, clear, seed or unseed (the run is never a legal move).
    public typealias Move = MyceliumArchitectAction

    /// The level whose board, limits, growth and budget decide the results.
    public let level: MyceliumArchitectLevel

    /// The rules of `level`.
    public init(level: MyceliumArchitectLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g22-mycelium-architect" }

    /// The start position: the level's starting arrangement, no action spent.
    public var initialState: Position {
        Position(arrangement: level.start, actionsSpent: 0)
    }

    /// Whether `state` can take an arrangement action: an action left.
    func isOpen(_ state: Position) -> Bool {
        state.actionsSpent >= 0 && state.actionsSpent < level.budget
    }

    /// Every arrangement action of `arrangement` in the order of research R14, legal or not: nutrients on every board
    /// cell in ascending (row, column), blockers likewise, clears of the placed items merged in ascending (row, column),
    /// seeds in ascending direction, unseeds in ascending direction.
    func candidates(_ arrangement: MyceliumArchitectArrangement) -> [MyceliumArchitectAction] {
        var result: [MyceliumArchitectAction] = []
        for row in 0..<level.height {
            for column in 0..<level.width {
                result.append(.nutrient(MyceliumArchitectCell(column: column, row: row)))
            }
        }
        for row in 0..<level.height {
            for column in 0..<level.width {
                result.append(.blocker(MyceliumArchitectCell(column: column, row: row)))
            }
        }
        let placed: [MyceliumArchitectCell] = (arrangement.nutrients + arrangement.blockers).sorted()
        for cell in placed { result.append(.clear(cell)) }
        for direction in MyceliumArchitectDirection.allCases.sorted() { result.append(.seed(direction)) }
        for direction in MyceliumArchitectDirection.allCases.sorted() { result.append(.unseed(direction)) }
        return result
    }

    /// The legal moves: none with the budget spent; otherwise every arrangement action the play would accept, in the
    /// order of research R14 (nutrients on empty cells ascending, blockers on empty cells ascending, clears ascending,
    /// seeds ascending, unseeds ascending), at most 2 · W · H + 20.
    public func moves(in state: Position) -> [MyceliumArchitectAction] {
        guard isOpen(state) else { return [] }
        var result: [MyceliumArchitectAction] = []
        for move in candidates(state.arrangement) {
            if (try? MyceliumArchitectPlay.changed(level, state.arrangement, by: move)) != nil { result.append(move) }
        }
        return result
    }

    /// The position after `move`, or nil when the play would refuse it: the item is placed, cleared, seeded or
    /// unseeded and 1 action is spent. Refused: the run, a cell off the board or not empty, a placement or seed limit
    /// reached, a clear without a placed item, a direction already seeded or not seeded, a starting seed, no action
    /// left.
    public func apply(_ move: MyceliumArchitectAction, to state: Position) -> Position? {
        guard isOpen(state) else { return nil }
        if case .run = move { return nil }
        guard let next = try? MyceliumArchitectPlay.changed(level, state.arrangement, by: move) else { return nil }
        return Position(arrangement: next, actionsSpent: state.actionsSpent + 1)
    }

    /// Whether a run from `state` would win: the predicted growth report of its arrangement has no failure.
    public func isSolved(_ state: Position) -> Bool {
        MyceliumArchitectGrowth.report(level, arrangement: state.arrangement).wins
    }
}
