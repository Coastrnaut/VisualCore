// ChronoConstellatorRules — feature 351 (R02-G06-01) T-R02G0601-005 (FR-R02G0601-010). Chrono Constellator expressed as
// an R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the
// timeline, the replay tick and the outcome), a move is a `ChronoConstellatorAction`, and a state is solved when its
// outcome is `won`. At tick 0 while playing the moves are, in this exact order: phase(i, o) for every star i and every
// offset o other than its current phase; hold(i, s, k) for every star i, start s 1 … 32 and length k 1 … 32 (s outer,
// k inner); then release(i, s) for every hold in the timeline's order; then step(tick limit). An edit the play would
// refuse (past the tick limit, overlapping or touching another hold, or over the budget) is not listed. A step of the
// tick limit always decides the play (win, collision or time), so after tick 0 the only move is rewind (from a failed
// position, an honest retry with the timeline kept); a won position offers nothing. Every edit goes through the
// timeline's own checked operations and every tick through `ChronoConstellatorEvaluation`, exactly as
// `ChronoConstellatorPlay.apply(_:expecting:)` does. A move not listed in `moves(in:)` is refused (nil). The rules carry
// no stage, undo, redo or records: those belong to the play.
import VisualCoreSimulation

/// The pure rules of one Chrono Constellator level as an R02-F23 puzzle contract.
public struct ChronoConstellatorRules: PuzzleRules {
    /// A position of a Chrono Constellator play as the rules see it: the timeline, the replay tick and the outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Edits (at tick 0), steps and rewinds are still possible.
            case playing
            /// Every star stood on its own target.
            case won
            /// The play failed (collision or time).
            case failed
        }

        /// The start phases and holds.
        public let timeline: ChronoConstellatorTimeline
        /// The replay tick, 0 at the start of the timeline.
        public let tick: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(timeline: ChronoConstellatorTimeline, tick: Int, outcome: Outcome) {
            self.timeline = timeline
            self.tick = tick
            self.outcome = outcome
        }
    }

    /// A position: timeline, tick and outcome.
    public typealias State = Position
    /// A player action: a phase, a hold, a release, a step or a rewind.
    public typealias Move = ChronoConstellatorAction

    /// The hold starts the rules list, 1 … 32.
    public static let holdStarts: ClosedRange<Int> = 1...32
    /// The hold lengths the rules list, 1 … 32.
    public static let holdLengths: ClosedRange<Int> = 1...32

    /// The level whose stars, budget and tick limit decide the results.
    public let level: ChronoConstellatorLevel

    /// The rules of `level`.
    public init(level: ChronoConstellatorLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g06-chrono-constellator" }

    /// The start position: the level's default timeline, tick 0, still playing.
    public var initialState: Position {
        Position(timeline: ChronoConstellatorTimeline(level: level), tick: 0, outcome: .playing)
    }

    /// The legal moves: none once won; only rewind after tick 0 or once failed; otherwise, at tick 0 while playing,
    /// phase(i, o) for every star and every offset other than its current phase, hold(i, s, k) for every star, start 1 … 32
    /// and length 1 … 32, release(i, s) for every hold and step(tick limit), each edit only when the timeline accepts it.
    public func moves(in state: Position) -> [ChronoConstellatorAction] {
        if state.outcome == .won { return [] }
        if state.outcome == .failed || state.tick != 0 { return [.rewind] }
        let timeline: ChronoConstellatorTimeline = state.timeline
        var result: [ChronoConstellatorAction] = []
        for star in level.stars.indices {
            for offset in 0..<level.stars[star].length where offset != timeline.phases[star] {
                if (try? timeline.settingPhase(star: star, to: offset, level: level)) != nil {
                    result.append(.phase(star, offset))
                }
            }
        }
        for star in level.stars.indices {
            for start in Self.holdStarts {
                for length in Self.holdLengths {
                    let hold = ChronoConstellatorHold(star: star, start: start, length: length)
                    if (try? timeline.adding(hold, level: level)) != nil {
                        result.append(.hold(star, start, length))
                    }
                }
            }
        }
        for hold in timeline.holds {
            result.append(.release(hold.star, hold.start))
        }
        result.append(.step(level.tickLimit))
        return result
    }

    /// The position after `move`, or nil when `move` is not among ``moves(in:)``. A phase, hold or release edits the
    /// timeline through its checked operations; step(tick limit) replays tick by tick and stops at the first tick whose
    /// ``ChronoConstellatorEvaluation`` verdict decides the play; a rewind returns to tick 0 with the timeline kept.
    public func apply(_ move: ChronoConstellatorAction, to state: Position) -> Position? {
        if state.outcome == .won { return nil }
        if state.outcome == .failed || state.tick != 0 {
            guard case .rewind = move else { return nil }
            return Position(timeline: state.timeline, tick: 0, outcome: .playing)
        }
        switch move {
        case .phase(let star, let offset):
            guard let timeline = try? state.timeline.settingPhase(star: star, to: offset, level: level) else {
                return nil
            }
            return Position(timeline: timeline, tick: 0, outcome: .playing)
        case .hold(let star, let start, let length):
            guard Self.holdStarts.contains(start), Self.holdLengths.contains(length),
                  let timeline = try? state.timeline.adding(ChronoConstellatorHold(star: star, start: start,
                                                                                    length: length), level: level)
            else { return nil }
            return Position(timeline: timeline, tick: 0, outcome: .playing)
        case .release(let star, let start):
            guard let timeline = try? state.timeline.releasing(star: star, start: start, level: level) else {
                return nil
            }
            return Position(timeline: timeline, tick: 0, outcome: .playing)
        case .step(let ticks):
            guard ticks == level.tickLimit else { return nil }
            var tick: Int = 0
            var outcome: Position.Outcome = .playing
            while tick < ticks && outcome == .playing {
                tick += 1
                let positions: [Int] = state.timeline.positions(at: tick, level: level)
                switch ChronoConstellatorEvaluation.verdict(positions: positions, tick: tick, level: level) {
                case .running: outcome = .playing
                case .won: outcome = .won
                case .failed: outcome = .failed
                }
            }
            return Position(timeline: state.timeline, tick: tick, outcome: outcome)
        case .rewind:
            return nil
        }
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
