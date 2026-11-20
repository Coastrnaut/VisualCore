// LissajousLabyrinthRules — feature 311 (R02-G02-01) T-R02G0201-005 (FR-R02G0201-008). Lissajous Labyrinth expressed as
// an R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is the four dial
// values, a move sets one dial to a new value, and a state is solved when its lap wins the level
// (`LissajousLabyrinthLap.verdict` is `.won`). Moves are listed dial by dial in `LissajousLabyrinthDial.allCases` order
// (frequencyA, frequencyB, phaseA, phaseC), values ascending within the dial's range, skipping the current value and any
// change that would make the two frequencies share a factor. A state offers at most 8 + 8 + 15 + 15 = 46 moves.
import VisualCoreSimulation

/// The pure rules of one Lissajous Labyrinth level as an R02-F23 puzzle contract.
public struct LissajousLabyrinthRules: PuzzleRules {
    /// A position: the four dial values.
    public typealias State = LissajousLabyrinthDials
    /// A player action: one dial set to a new value.
    public typealias Move = LissajousLabyrinthAction

    /// The level whose lap verdict decides `isSolved(_:)`.
    public let level: LissajousLabyrinthLevel

    /// The rules of `level`.
    public init(level: LissajousLabyrinthLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g02-lissajous-labyrinth" }

    /// Every single-dial change, ordered dial (frequencyA, frequencyB, phaseA, phaseC), then value ascending within the
    /// dial's range, skipping the current value and any change whose frequencies are not coprime (at most 46 moves);
    /// empty for an invalid state.
    public func moves(in state: LissajousLabyrinthDials) -> [LissajousLabyrinthAction] {
        guard state.isValid else { return [] }
        var result: [LissajousLabyrinthAction] = []
        result.reserveCapacity(46)
        for dial in LissajousLabyrinthDial.allCases {
            let current: Int = state[dial]
            for value in dial.range where value != current {
                var next: LissajousLabyrinthDials = state
                next[dial] = value
                if next.isValid { result.append(LissajousLabyrinthAction(dial: dial, value: value)) }
            }
        }
        return result
    }

    /// The dials after `move`, or nil for a value outside the dial's range, a value equal to the current one, a change
    /// whose frequencies are not coprime or an invalid state.
    public func apply(_ move: LissajousLabyrinthAction, to state: LissajousLabyrinthDials) -> LissajousLabyrinthDials? {
        guard state.isValid else { return nil }
        guard move.dial.range.contains(move.value), state[move.dial] != move.value else { return nil }
        var next: LissajousLabyrinthDials = state
        next[move.dial] = move.value
        return next.isValid ? next : nil
    }

    /// Whether the lap of `state` wins the level (`LissajousLabyrinthLap.verdict` is `.won`).
    public func isSolved(_ state: LissajousLabyrinthDials) -> Bool {
        LissajousLabyrinthLap.verdict(state, level: level) == .won
    }
}
