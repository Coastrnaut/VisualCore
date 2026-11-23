// BackwardsAuroraRules — feature 391 (R02-G10-01) T-R02G1001-005 (FR-R02G1001-010). Backwards Aurora expressed as an
// R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the
// wave, the reversals spent and the outcome), a move is a `BackwardsAuroraAction`, and a state is solved when its
// outcome is `won`. While playing the legal moves are every reversal `reverse(start, end)` whose section length
// end − start + 1 is within the level's shortest … longest and whose section does not read the same both ways, in
// order of start, then end. A won or failed position offers nothing. Applying a move mirrors the play's
// `apply(_:expecting:)`: the section is reversed, one reversal is spent and the outcome is judged — the tear first (a
// seam bend of the reversal with |b| > B fails), then the win (every checkpoint matched and the wave smooth), then the
// budget (reversals spent equal to the budget fail). A move the play would refuse (out of range, a length outside the
// level's sections, a palindrome) is refused (nil). The rules carry no stage, fingerprints, undo, redo or records:
// those belong to the play. Integers only; no clock, no random source.
import VisualCoreSimulation

/// The pure rules of one Backwards Aurora level as an R02-F23 puzzle contract.
public struct BackwardsAuroraRules: PuzzleRules {
    /// A position of a Backwards Aurora play as the rules see it: the wave, the reversals spent and the outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Actions are still possible.
            case playing
            /// Every checkpoint is matched and the wave is smooth.
            case won
            /// A reversal tore the aurora or the budget ran out.
            case failed
        }

        /// The wave.
        public let wave: BackwardsAuroraWave
        /// The reversals spent, 0 … the level's budget.
        public let spent: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(wave: BackwardsAuroraWave, spent: Int, outcome: Outcome) {
            self.wave = wave
            self.spent = spent
            self.outcome = outcome
        }
    }

    /// A position: wave, reversals spent and outcome.
    public typealias State = Position
    /// A player action: a reversal of a section.
    public typealias Move = BackwardsAuroraAction

    /// The level whose opening wave, checkpoints, limits, sections and budget decide the results.
    public let level: BackwardsAuroraLevel

    /// The rules of `level`.
    public init(level: BackwardsAuroraLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g10-backwards-aurora" }

    /// The start position: the opening wave, no reversal spent, still playing.
    public var initialState: Position {
        Position(wave: level.opening, spent: 0, outcome: .playing)
    }

    /// The legal moves: none once won or failed; otherwise every reversal of a section of length shortest … longest
    /// that is not a palindrome, in order of start, then end.
    public func moves(in state: Position) -> [BackwardsAuroraAction] {
        guard state.outcome == .playing else { return [] }
        let count: Int = state.wave.count
        var result: [BackwardsAuroraAction] = []
        for start in 0..<count {
            let first: Int = start + level.shortest - 1
            let last: Int = min(start + level.longest - 1, count - 1)
            if first > last { continue }
            for end in first...last where !state.wave.isPalindrome(start: start, end: end) {
                result.append(.reverse(start, end))
            }
        }
        return result
    }

    /// The lowest seam position of the section [start, end] whose bend in `wave` exceeds the breaking limit, or nil.
    public func tearSeam(_ wave: BackwardsAuroraWave, start: Int, end: Int) -> Int? {
        for k in BackwardsAuroraWave.seams(start: start, end: end, count: wave.count)
        where abs(wave.bend(at: k)) > level.breakingLimit {
            return k
        }
        return nil
    }

    /// The position after `move`, or nil when `move` is not among ``moves(in:)``. The section is reversed, one
    /// reversal is spent and the outcome is judged: tear, then win, then budget, exactly as ``BackwardsAuroraPlay``
    /// judges it.
    public func apply(_ move: BackwardsAuroraAction, to state: Position) -> Position? {
        guard state.outcome == .playing else { return nil }
        guard case let .reverse(start, end) = move else { return nil }
        let count: Int = state.wave.count
        guard start >= 0, end < count, start < end, level.sectionLengths.contains(end - start + 1) else { return nil }
        guard !state.wave.isPalindrome(start: start, end: end) else { return nil }
        let wave: BackwardsAuroraWave = state.wave.reversed(start: start, end: end)
        let spent: Int = state.spent + 1
        var outcome: Position.Outcome = .playing
        if tearSeam(wave, start: start, end: end) != nil {
            outcome = .failed
        } else if level.wins(wave) {
            outcome = .won
        } else if spent >= level.budget {
            outcome = .failed
        }
        return Position(wave: wave, spent: spent, outcome: outcome)
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
