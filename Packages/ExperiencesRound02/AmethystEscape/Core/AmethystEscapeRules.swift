// AmethystEscapeRules — feature 361 (R02-G07-01) T-R02G0701-005 (FR-R02G0701-010). Amethyst Escape expressed as an
// R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the
// crystal, the moves spent and the outcome), a move is an `AmethystEscapeAction`, and a state is solved when its outcome
// is `won`. While playing the moves are, in this exact order: rotate(r, +1) then rotate(r, −1) for every shell r from the
// innermost outward, then advance unless the advance's transition is stuck. A won or failed position offers nothing.
// Applying a rotation turns the crystal through `AmethystEscapeCrystal.rotating(shell:step:level:)`; an advance takes the
// crystal's one transition: exited wins, a wedge fails with the pearl placed in the blocked pocket, and a plain move
// places the pearl. Every move spends one of the level's budget; a move that does not end the play and spends the last
// of the budget fails it. A move not listed in `moves(in:)` is refused (nil). The rules carry no stage, undo, redo or
// records: those belong to the play.
import VisualCoreSimulation

/// The pure rules of one Amethyst Escape level as an R02-F23 puzzle contract.
public struct AmethystEscapeRules: PuzzleRules {
    /// A position of an Amethyst Escape play as the rules see it: the crystal, the moves spent and the outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Rotations and advances are still possible.
            case playing
            /// The pearl left the outermost shell through the exit gap.
            case won
            /// The pearl was wedged or the budget ran out.
            case failed
        }

        /// The shell offsets and the pearl's pocket.
        public let crystal: AmethystEscapeCrystal
        /// The moves spent, 0 … the level's budget.
        public let moves: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(crystal: AmethystEscapeCrystal, moves: Int, outcome: Outcome) {
            self.crystal = crystal
            self.moves = moves
            self.outcome = outcome
        }
    }

    /// A position: crystal, moves spent and outcome.
    public typealias State = Position
    /// A player action: a rotation of one shell by one sector or an advance of the pearl.
    public typealias Move = AmethystEscapeAction

    /// The level whose shells, start and budget decide the results.
    public let level: AmethystEscapeLevel

    /// The rules of `level`.
    public init(level: AmethystEscapeLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g07-amethyst-escape" }

    /// The start position: the level's opening crystal, no moves spent, still playing.
    public var initialState: Position {
        Position(crystal: AmethystEscapeCrystal(level: level), moves: 0, outcome: .playing)
    }

    /// The legal moves: none once won or failed; otherwise rotate(r, +1) and rotate(r, −1) for every shell r, innermost
    /// first, then advance unless the crystal's transition is stuck.
    public func moves(in state: Position) -> [AmethystEscapeAction] {
        guard state.outcome == .playing else { return [] }
        var result: [AmethystEscapeAction] = []
        result.reserveCapacity(level.shells.count * 2 + 1)
        for shell in level.shells.indices {
            result.append(.rotate(shell, 1))
            result.append(.rotate(shell, -1))
        }
        if state.crystal.transition(level: level) != .stuck {
            result.append(.advance)
        }
        return result
    }

    /// The position after `move`, or nil when `move` is not among ``moves(in:)``. A rotation turns the crystal; an
    /// advance takes the crystal's one transition (exited wins, a wedge fails with the pearl placed, a move places the
    /// pearl). The move count grows by one; a move that leaves the play going with the budget spent fails it.
    public func apply(_ move: AmethystEscapeAction, to state: Position) -> Position? {
        guard state.outcome == .playing else { return nil }
        let moves: Int = state.moves + 1
        var crystal: AmethystEscapeCrystal = state.crystal
        var outcome: Position.Outcome = .playing
        switch move {
        case let .rotate(shell, step):
            guard level.shells.indices.contains(shell), step == 1 || step == -1 else { return nil }
            crystal = crystal.rotating(shell: shell, step: step, level: level)
        case .advance:
            switch crystal.transition(level: level) {
            case .stuck:
                return nil
            case .exited:
                outcome = .won
            case let .wedge(pocket):
                crystal = crystal.placing(pearl: pocket)
                outcome = .failed
            case let .moved(pocket):
                crystal = crystal.placing(pearl: pocket)
            }
        }
        if outcome == .playing && moves >= level.budget {
            outcome = .failed
        }
        return Position(crystal: crystal, moves: moves, outcome: outcome)
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
