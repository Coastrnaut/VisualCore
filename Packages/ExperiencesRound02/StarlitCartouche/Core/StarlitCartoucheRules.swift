// StarlitCartoucheRules — feature 451 (R02-G16-01) T-R02G1601-005 (FR-R02G1601-010). Starlit Cartouche expressed as an
// R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the
// ship's star and beat, the drawn strokes, the actions spent and the outcome), a move is a `StarlitCartoucheAction`,
// and a state is solved when its outcome is `won`. While playing (and while actions are left) the legal moves are, in
// exactly this order: for each corridor (in corridor index order) that joins the ship's star, the leg to its other end
// after each wait 0 … 8 for which `StarlitCartoucheChart.leg` succeeds (the stars are in range at the departure beat).
// A won or failed position offers nothing. Applying a move mirrors the play's `apply(_:expecting:)`: a leg spends 1
// action; when `StarlitCartoucheChart.check` fails it (departure, hazard, arrival, deadline or stroke) the level fails
// with the star, beat and strokes unchanged; otherwise the ship moves, the beat becomes the arrival beat and the
// corridor is drawn, the level is won when the drawn set equals the symbol with the ship at the beacon (even on the
// last action of the budget), else a leg that spends the last of the budget fails the level. A move the play would
// refuse (an unknown star, the ship's own star, no corridor, a wait outside 0 … 8, stars out of range) is refused
// (nil). The rules carry no stage, fingerprints, failure details, legs, report, records, undo or redo: those belong to
// the play. Integers only; no clock, no random source. Modelled on `VoxelOrigamiRules` (feature 441).
import VisualCoreSimulation

/// The pure rules of one Starlit Cartouche level as an R02-F23 puzzle contract.
public struct StarlitCartoucheRules: PuzzleRules {
    /// A position of a Starlit Cartouche play as the rules see it: star, beat, drawn strokes, actions spent, outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Legs are still possible.
            case playing
            /// A clear leg left the drawn strokes equal to the symbol with the ship at the beacon.
            case won
            /// A leg failed the chart's check, or a leg spent the last of the budget without a match.
            case failed
        }

        /// The ship's star.
        public let star: Int
        /// The ship's beat.
        public let beat: Int
        /// The drawn strokes (corridor indices).
        public let drawn: Set<Int>
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(star: Int, beat: Int, drawn: Set<Int>, actionsSpent: Int, outcome: Outcome) {
            self.star = star
            self.beat = beat
            self.drawn = drawn
            self.actionsSpent = actionsSpent
            self.outcome = outcome
        }
    }

    /// A position: star, beat, drawn strokes, actions spent and outcome.
    public typealias State = Position
    /// A player action: a leg to a star after a wait.
    public typealias Move = StarlitCartoucheAction

    /// The level whose stars, corridors, hazards, symbol and budget decide the results.
    public let level: StarlitCartoucheLevel

    /// The rules of `level`.
    public init(level: StarlitCartoucheLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g16-starlit-cartouche" }

    /// The start position: the level's start star, beat 0, nothing drawn, no action spent, still playing.
    public var initialState: Position {
        Position(star: level.start, beat: 0, drawn: [], actionsSpent: 0, outcome: .playing)
    }

    /// Whether `state` can take a leg: playing, actions left and a star of the level.
    func isOpen(_ state: Position) -> Bool {
        state.outcome == .playing && state.actionsSpent < level.budget && state.star >= 0
            && state.star < level.stars.count
    }

    /// The legal moves: none once won or failed or with the budget spent; otherwise for each corridor joining the
    /// ship's star, in corridor index order, the leg to its other end after each wait 0 … 8 that the chart accepts.
    public func moves(in state: Position) -> [StarlitCartoucheAction] {
        guard isOpen(state) else { return [] }
        var result: [StarlitCartoucheAction] = []
        for index in level.corridors.indices {
            let corridor: StarlitCartoucheCorridor = level.corridors[index]
            let destination: Int
            if corridor.a == state.star {
                destination = corridor.b
            } else if corridor.b == state.star {
                destination = corridor.a
            } else {
                continue
            }
            for wait in StarlitCartoucheChart.waits {
                let flown: StarlitCartoucheLeg? = try? StarlitCartoucheChart.leg(level, from: state.star,
                                                                                 at: state.beat, to: destination,
                                                                                 wait: wait)
                if flown != nil { result.append(.leg(destination, wait)) }
            }
        }
        return result
    }

    /// The position after `move`, or nil when the play would refuse it. A leg spends 1 action; a leg the chart's
    /// check fails fails the level with the star, beat and strokes unchanged; a clear leg moves the ship, draws the
    /// corridor and wins when the drawn set equals the symbol with the ship at the beacon, else fails the level when
    /// the budget is fully spent — exactly as the play judges it.
    public func apply(_ move: StarlitCartoucheAction, to state: Position) -> Position? {
        guard isOpen(state) else { return nil }
        let spent: Int = state.actionsSpent + 1
        switch move {
        case .leg(let destination, let wait):
            let flown: StarlitCartoucheLeg
            do {
                flown = try StarlitCartoucheChart.leg(level, from: state.star, at: state.beat, to: destination,
                                                      wait: wait)
            } catch {
                return nil
            }
            if StarlitCartoucheChart.check(level, leg: flown) != nil {
                return Position(star: state.star, beat: state.beat, drawn: state.drawn, actionsSpent: spent,
                                outcome: .failed)
            }
            var drawn: Set<Int> = state.drawn
            drawn.insert(flown.corridor)
            let report: StarlitCartoucheRouteReport = StarlitCartoucheChart.report(level, star: flown.to,
                                                                                   beat: flown.arrive,
                                                                                   drawn: drawn, legs: [])
            if report.matched {
                return Position(star: flown.to, beat: flown.arrive, drawn: drawn, actionsSpent: spent,
                                outcome: .won)
            }
            return Position(star: flown.to, beat: flown.arrive, drawn: drawn, actionsSpent: spent,
                            outcome: spent >= level.budget ? .failed : .playing)
        }
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
