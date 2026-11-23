// HarmonicBridgesRules — feature 411 (R02-G12-01) T-R02G1201-005 (FR-R02G1201-010). Harmonic Bridges expressed as an
// R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the peg
// of every string, the actions spent and the outcome), a move is a `HarmonicBridgesAction`, and a state is solved when
// its outcome is `won`. While playing the legal moves are every valid tuning — in string order, then peg 1 … 12 order,
// skipping locked strings and each string's current peg — then the test. A won or failed position offers nothing.
// Applying a move mirrors the play's `apply(_:expecting:)`: a tuning sets one peg and spends 1 action, and fails the
// level when it spends the last of the budget; a test spends 1 action and wins when the goal is reached in every step of
// the crossing window (`HarmonicBridgesLevel.firstBreak` finds no break, even on the last action of the budget), else
// fails. A move the play would refuse is refused (nil). The rules carry no stage, fingerprints, failure details, undo,
// redo or records: those belong to the play. Integers only; no clock, no random source.
import VisualCoreSimulation

/// The pure rules of one Harmonic Bridges level as an R02-F23 puzzle contract.
public struct HarmonicBridgesRules: PuzzleRules {
    /// A position of a Harmonic Bridges play as the rules see it: pegs, actions spent and outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Actions are still possible.
            case playing
            /// A test found the goal reached in every step of the crossing window.
            case won
            /// A test broke, or a tuning spent the last of the budget.
            case failed
        }

        /// The peg of every string, in string order.
        public let pegs: [Int]
        /// The tunings and tests spent, 0 … the level's budget.
        public let actionsSpent: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(pegs: [Int], actionsSpent: Int, outcome: Outcome) {
            self.pegs = pegs
            self.actionsSpent = actionsSpent
            self.outcome = outcome
        }
    }

    /// A position: pegs, actions spent and outcome.
    public typealias State = Position
    /// A player action: a tuning or the test.
    public typealias Move = HarmonicBridgesAction

    /// The level whose strings, tones, threshold, crossing window and budget decide the results.
    public let level: HarmonicBridgesLevel

    /// The rules of `level`.
    public init(level: HarmonicBridgesLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g12-harmonic-bridges" }

    /// The start position: the level's starting pegs, no action spent, still playing.
    public var initialState: Position {
        Position(pegs: level.startingPegs, actionsSpent: 0, outcome: .playing)
    }

    /// Whether tuning string `string` to `peg` is valid in `state`: a known string, a peg in 1 … 12, not locked and not
    /// the string's current peg.
    public func canTune(_ string: Int, to peg: Int, in state: Position) -> Bool {
        guard string >= 0, string < level.strings.count, string < state.pegs.count else { return false }
        guard HarmonicBridgesLevel.pegs.contains(peg), !level.strings[string].locked else { return false }
        return state.pegs[string] != peg
    }

    /// The legal moves: none once won or failed; otherwise every valid tuning in string order, then peg order, then
    /// the test.
    public func moves(in state: Position) -> [HarmonicBridgesAction] {
        guard state.outcome == .playing else { return [] }
        var result: [HarmonicBridgesAction] = []
        for string in 0..<level.strings.count {
            for peg in HarmonicBridgesLevel.pegs where canTune(string, to: peg, in: state) {
                result.append(.tune(string, peg))
            }
        }
        result.append(.test)
        return result
    }

    /// The position after `move`, or nil when `move` is not among ``moves(in:)``. A tuning sets the peg, spends 1
    /// action and fails the level when the budget is fully spent; a test spends 1 action and wins when no step of the
    /// crossing window breaks, else fails — exactly as the play judges them.
    public func apply(_ move: HarmonicBridgesAction, to state: Position) -> Position? {
        guard state.outcome == .playing else { return nil }
        var pegs: [Int] = state.pegs
        let spent: Int = state.actionsSpent + 1
        var outcome: Position.Outcome = .playing
        switch move {
        case .tune(let string, let peg):
            guard canTune(string, to: peg, in: state) else { return nil }
            pegs[string] = peg
            if spent >= level.budget { outcome = .failed }
        case .test:
            let report: HarmonicBridgesReport = level.report(pegs: pegs)
            outcome = level.firstBreak(report) == nil ? .won : .failed
        }
        return Position(pegs: pegs, actionsSpent: spent, outcome: outcome)
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
