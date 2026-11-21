// ColorfallCanyonsRules — feature 341 (R02-G05-01) T-R02G0501-005 (FR-R02G0501-010). Colorfall Canyons expressed as an
// R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the exact
// fluid, the actions spent and the outcome), a move is a `ColorfallCanyonsAction`, and a state is solved when its outcome
// is `won`. While the outcome is `playing` the moves are, in this exact order, carve(c) for every cell c that can be
// carved at the current heights (index order) and valve(s) for every spring s — both only while actions are left — then
// step(1). Single-tick steps keep the moves finite: a step of n ticks is n single steps, because the play's step stops
// at the first tick whose verdict decides it. A carve or valve spends one action; a step runs one tick and sets the
// outcome from the verdict — as `ColorfallCanyonsPlay.apply(_:expecting:)` decides. A move not listed in `moves(in:)` is
// refused (nil). The rules carry no stage, undo, redo or records: those belong to the play.
import VisualCoreSimulation

/// The pure rules of one Colorfall Canyons level as an R02-F23 puzzle contract.
public struct ColorfallCanyonsRules: PuzzleRules {
    /// A position of a Colorfall Canyons play as the rules see it: the fluid, the actions spent and the outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Carves, valves and steps are still possible.
            case playing
            /// Every target basin was met.
            case won
            /// The play failed (contamination, overflow or time).
            case failed
        }

        /// The exact fluid state: heights, valves, supplies, masses, spilled and released units, tick.
        public let fluid: ColorfallCanyonsFluid
        /// The carves and valve toggles spent.
        public let spent: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(fluid: ColorfallCanyonsFluid, spent: Int, outcome: Outcome) {
            self.fluid = fluid
            self.spent = spent
            self.outcome = outcome
        }
    }

    /// A position: fluid, actions spent and outcome.
    public typealias State = Position
    /// A player action: a carve, a valve toggle or a step.
    public typealias Move = ColorfallCanyonsAction

    /// The level whose grid, springs, basins, budget and tick limit decide the results.
    public let level: ColorfallCanyonsLevel

    /// The rules of `level`.
    public init(level: ColorfallCanyonsLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g05-colorfall-canyons" }

    /// The start position: the level's starting fluid, nothing spent, still playing.
    public var initialState: Position {
        Position(fluid: ColorfallCanyonsFluid(level: level), spent: 0, outcome: .playing)
    }

    /// The legal moves: none once the outcome is not `playing`; otherwise, while actions are left, carve(c) for every
    /// carvable cell in index order and valve(s) for every spring in index order; then step(1).
    public func moves(in state: Position) -> [ColorfallCanyonsAction] {
        guard state.outcome == .playing else { return [] }
        var result: [ColorfallCanyonsAction] = []
        if state.spent < level.budget {
            for cell in 0..<level.cellCount where level.isCarvable(cell, heights: state.fluid.heights) {
                result.append(.carve(cell))
            }
            for spring in level.springs.indices {
                result.append(.valve(spring))
            }
        }
        result.append(.step(1))
        return result
    }

    /// The position after `move`, or nil when `move` is not among ``moves(in:)``. A carve lowers the cell by one step and
    /// a valve toggles the spring, each spending one action; step(1) runs one tick and sets the outcome from the verdict.
    public func apply(_ move: ColorfallCanyonsAction, to state: Position) -> Position? {
        guard state.outcome == .playing else { return nil }
        var fluid: ColorfallCanyonsFluid = state.fluid
        switch move {
        case .carve(let cell):
            guard state.spent < level.budget, level.isCarvable(cell, heights: fluid.heights) else { return nil }
            fluid.carve(cell)
            return Position(fluid: fluid, spent: state.spent + 1, outcome: .playing)
        case .valve(let spring):
            guard state.spent < level.budget, level.springs.indices.contains(spring) else { return nil }
            fluid.toggle(spring)
            return Position(fluid: fluid, spent: state.spent + 1, outcome: .playing)
        case .step(let ticks):
            guard ticks == 1 else { return nil }
            fluid.tick(level: level)
            let outcome: Position.Outcome
            switch fluid.verdict(level: level) {
            case .running: outcome = .playing
            case .won: outcome = .won
            case .failed: outcome = .failed
            }
            return Position(fluid: fluid, spent: state.spent, outcome: outcome)
        }
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
