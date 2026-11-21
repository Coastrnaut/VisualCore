// HueCompassRules — feature 331 (R02-G04-01) T-R02G0401-005 (FR-R02G0401-009). Hue Compass expressed as an R02-F23
// puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the bearing, the
// units spent and the outcome), a move is a `HueCompassAction`, and a state is solved when its outcome is `won`. While the
// outcome is `playing` the moves are, in this exact order, turn(+1), turn(−1), probe, then select(current bearing, band b)
// for b = 0 … 23 — 27 moves; an ended position offers none. Single-step turns keep the branching small: any turn of the
// play (−48 … 48) is a sequence of them, and selecting another bearing than the current one is the same as turning there
// first. A turn moves the bearing mod 96 and spends nothing; a probe spends one unit and fails when it spends the last; a
// selection spends one unit and wins exactly when `HueCompassLevel.accepts(bearing:band:)` does, else fails — as
// `HueCompassPlay.apply(_:expecting:)` decides. A move not listed in `moves(in:)` is refused (nil). The rules carry no
// clues, undo or redo: those belong to the play, and a probe's only effect on the position is the unit it spends.
import VisualCoreSimulation

/// The pure rules of one Hue Compass level as an R02-F23 puzzle contract.
public struct HueCompassRules: PuzzleRules {
    /// A position of a Hue Compass play as the rules see it: the bearing, the units spent and the outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Turns, probes and selections are still possible.
            case playing
            /// A selection was accepted.
            case won
            /// A selection missed or a probe spent the last unit.
            case failed
        }

        /// The bearing the compass points at, 0 … 95.
        public let bearing: Int
        /// The units spent by probes and the selection.
        public let spent: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(bearing: Int, spent: Int, outcome: Outcome) {
            self.bearing = bearing
            self.spent = spent
            self.outcome = outcome
        }
    }

    /// A position: bearing, units spent and outcome.
    public typealias State = Position
    /// A player action: a turn, a probe or a selection.
    public typealias Move = HueCompassAction

    /// The level whose target, tolerances and allowance decide the results.
    public let level: HueCompassLevel

    /// The rules of `level`.
    public init(level: HueCompassLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g04-hue-compass" }

    /// The start position: the level's start bearing, nothing spent, still playing.
    public var initialState: Position { Position(bearing: level.start, spent: 0, outcome: .playing) }

    /// The legal moves: none once the outcome is not `playing`; otherwise turn(+1), turn(−1), probe, then
    /// select(bearing: the current bearing, band: b) for b = 0 … 23, in that order (27 moves).
    public func moves(in state: Position) -> [HueCompassAction] {
        guard state.outcome == .playing else { return [] }
        var result: [HueCompassAction] = [.turn(1), .turn(-1), .probe]
        result.reserveCapacity(3 + HueCompassWheel.bands)
        for band in 0..<HueCompassWheel.bands {
            result.append(.select(bearing: state.bearing, band: band))
        }
        return result
    }

    /// The position after `move`, or nil when `move` is not among ``moves(in:)``. A turn moves the bearing modulo 96 and
    /// spends nothing; a probe spends one unit and fails when it spends the last; a selection spends one unit and wins
    /// when the level accepts the bearing and band, else fails.
    public func apply(_ move: HueCompassAction, to state: Position) -> Position? {
        guard state.outcome == .playing else { return nil }
        switch move {
        case .turn(let steps):
            guard steps == 1 || steps == -1 else { return nil }
            return Position(bearing: HueCompassWheel.mod(state.bearing + steps, HueCompassWheel.bearings),
                            spent: state.spent, outcome: .playing)
        case .probe:
            guard state.spent < level.allowance else { return nil }
            let spent: Int = state.spent + 1
            return Position(bearing: state.bearing, spent: spent,
                            outcome: spent == level.allowance ? .failed : .playing)
        case .select(let bearing, let band):
            guard bearing == state.bearing, (0..<HueCompassWheel.bands).contains(band),
                  state.spent < level.allowance else { return nil }
            let won: Bool = level.accepts(bearing: bearing, band: band)
            return Position(bearing: state.bearing, spent: state.spent + 1, outcome: won ? .won : .failed)
        }
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
