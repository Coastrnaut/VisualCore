// ApsidesWorkshopRules — feature 471 (R02-G18-01) T-R02G1801-005 (FR-R02G1801-010; clarifications Q4, Q5).
// Apsides Workshop expressed as an R02-F23 puzzle contract so later features can certify levels with
// `PuzzleValidator`: a state is a `Position` (the orbit and the actions spent), a move is an `ApsidesWorkshopAction`
// tuning, and a state is solved when the predicted play wins (`ApsidesWorkshopSky.report(level, orbit:).wins`). While
// actions are left the legal moves are, in exactly this order: `periapsis(k, d)` for each eccentricity step k 0 … 15
// and, within it, each direction step d 0 … 23, other than the current pair and keeping the orbit valid; then `size(a)`
// for each size a 8 … 48 other than the current one and keeping the orbit valid. With the budget spent nothing is
// legal. Applying a move mirrors the play's `apply(_:expecting:)`: the orbit takes the tuning and 1 action is spent; a
// move the play would refuse (a step out of range, unchanged or making the orbit invalid, no action left, or the
// play) is refused (nil). The play is not a move: it spends nothing and only reveals the outcome that `isSolved`
// already predicts. The rules carry no stage, fingerprints, report, failure, records, undo or redo: those belong to
// the play. Integers only; no clock, no random source. Modelled on `CelestialEclipseLabRules` (feature 461).
import VisualCoreSimulation

/// The pure rules of one Apsides Workshop level as an R02-F23 puzzle contract.
public struct ApsidesWorkshopRules: PuzzleRules {
    /// A position of an Apsides Workshop play as the rules see it: the orbit and the actions spent.
    public struct Position: Hashable, Codable, Sendable {
        /// The current orbit.
        public let orbit: ApsidesWorkshopOrbit
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int

        /// A position of the given values (not checked).
        public init(orbit: ApsidesWorkshopOrbit, actionsSpent: Int) {
            self.orbit = orbit
            self.actionsSpent = actionsSpent
        }
    }

    /// A position: the orbit and the actions spent.
    public typealias State = Position
    /// A player action: a tuning (the play is never a legal move).
    public typealias Move = ApsidesWorkshopAction

    /// The level whose period, planets, targets and budget decide the results.
    public let level: ApsidesWorkshopLevel

    /// The rules of `level`.
    public init(level: ApsidesWorkshopLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g18-apsides-workshop" }

    /// The start position: the level's starting orbit, no action spent.
    public var initialState: Position {
        Position(orbit: level.orbit, actionsSpent: 0)
    }

    /// Whether `state` can take a tuning: a valid orbit and an action left.
    func isOpen(_ state: Position) -> Bool {
        state.orbit.isValid && state.actionsSpent >= 0 && state.actionsSpent < level.budget
    }

    /// The legal moves: none with the budget spent; otherwise each periapsis tuning (eccentricity steps ascending,
    /// direction steps ascending within each) other than the current pair whose orbit is valid, then each size
    /// tuning (ascending) other than the current size whose orbit is valid.
    public func moves(in state: Position) -> [ApsidesWorkshopAction] {
        guard isOpen(state) else { return [] }
        let orbit: ApsidesWorkshopOrbit = state.orbit
        var result: [ApsidesWorkshopAction] = []
        for k in ApsidesWorkshopOrbit.eccentricities {
            for d in ApsidesWorkshopOrbit.directions {
                if k == orbit.eccentricity && d == orbit.direction { continue }
                if ApsidesWorkshopOrbit(size: orbit.size, eccentricity: k, direction: d).isValid {
                    result.append(.periapsis(k, d))
                }
            }
        }
        for a in ApsidesWorkshopOrbit.sizes where a != orbit.size {
            if ApsidesWorkshopOrbit(size: a, eccentricity: orbit.eccentricity, direction: orbit.direction).isValid {
                result.append(.size(a))
            }
        }
        return result
    }

    /// The position after `move`, or nil when the play would refuse it: the orbit takes the tuning and 1 action is
    /// spent. Refused: the play, a step out of range, a tuning equal to the current orbit or making it invalid, no
    /// action left.
    public func apply(_ move: ApsidesWorkshopAction, to state: Position) -> Position? {
        guard isOpen(state) else { return nil }
        let orbit: ApsidesWorkshopOrbit = state.orbit
        let next: ApsidesWorkshopOrbit
        switch move {
        case .play:
            return nil
        case .periapsis(let k, let d):
            guard k != orbit.eccentricity || d != orbit.direction else { return nil }
            next = ApsidesWorkshopOrbit(size: orbit.size, eccentricity: k, direction: d)
        case .size(let a):
            guard a != orbit.size else { return nil }
            next = ApsidesWorkshopOrbit(size: a, eccentricity: orbit.eccentricity, direction: orbit.direction)
        }
        guard next.isValid else { return nil }
        return Position(orbit: next, actionsSpent: state.actionsSpent + 1)
    }

    /// Whether a play from `state` would win: the predicted report of its orbit meets every target without contact
    /// (false for an invalid orbit).
    public func isSolved(_ state: Position) -> Bool {
        guard state.orbit.isValid else { return false }
        return ApsidesWorkshopSky.report(level, orbit: state.orbit).wins
    }
}
