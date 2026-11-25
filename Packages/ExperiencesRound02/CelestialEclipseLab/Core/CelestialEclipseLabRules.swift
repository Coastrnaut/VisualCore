// CelestialEclipseLabRules — feature 461 (R02-G17-01) T-R02G1701-005 (FR-R02G1701-010; clarifications Q2, Q5).
// Celestial Eclipse Lab expressed as an R02-F23 puzzle contract so later features can certify levels with
// `PuzzleValidator`: a state is a `Position` (the phase of every body and the actions spent), a move is a
// `CelestialEclipseLabAction` phase change, and a state is solved when the predicted run wins
// (`CelestialEclipseLabSky.timeline(level, phases:).wins`). While actions are left the legal moves are, in exactly this
// order: for each movable body in index order, `phase(body, offset)` for each offset 0 … period − 1 other than the
// body's current phase. With the budget spent nothing is legal. Applying a move mirrors the play's
// `apply(_:expecting:)`: the body takes the offset and 1 action is spent; a move the play would refuse (an unknown or
// fixed body, an offset outside the period or equal to the current one, no action left, or the run) is refused (nil).
// The run is not a move: it spends nothing and only reveals the outcome that `isSolved` already predicts. The rules
// carry no stage, fingerprints, timeline, failure, records, undo or redo: those belong to the play. Integers only; no
// clock, no random source. Modelled on `StarlitCartoucheRules` (feature 451).
import VisualCoreSimulation

/// The pure rules of one Celestial Eclipse Lab level as an R02-F23 puzzle contract.
public struct CelestialEclipseLabRules: PuzzleRules {
    /// A position of a Celestial Eclipse Lab play as the rules see it: the phases and the actions spent.
    public struct Position: Hashable, Codable, Sendable {
        /// The phase of every body, by body index.
        public let phases: [Int]
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int

        /// A position of the given values (not checked).
        public init(phases: [Int], actionsSpent: Int) {
            self.phases = phases
            self.actionsSpent = actionsSpent
        }
    }

    /// A position: the phases and the actions spent.
    public typealias State = Position
    /// A player action: a phase change (the run is never a legal move).
    public typealias Move = CelestialEclipseLabAction

    /// The level whose bodies, horizon, target and budget decide the results.
    public let level: CelestialEclipseLabLevel

    /// The rules of `level`.
    public init(level: CelestialEclipseLabLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g17-celestial-eclipse-lab" }

    /// The start position: the level's starting phases, no action spent.
    public var initialState: Position {
        Position(phases: level.phases, actionsSpent: 0)
    }

    /// Whether `state` can take a phase change: one phase per body and an action left.
    func isOpen(_ state: Position) -> Bool {
        state.phases.count == level.bodies.count && state.actionsSpent >= 0 && state.actionsSpent < level.budget
    }

    /// The legal moves: none with the budget spent; otherwise for each movable body in index order, the phase change
    /// to each offset 0 … period − 1 other than its current phase.
    public func moves(in state: Position) -> [CelestialEclipseLabAction] {
        guard isOpen(state) else { return [] }
        var result: [CelestialEclipseLabAction] = []
        for body in level.bodies.indices {
            let orbit: CelestialEclipseLabBody = level.bodies[body]
            if orbit.fixed { continue }
            for offset in 0..<orbit.period where offset != state.phases[body] {
                result.append(.phase(body, offset))
            }
        }
        return result
    }

    /// The position after `move`, or nil when the play would refuse it: the body takes the offset and 1 action is
    /// spent. Refused: the run, an unknown or fixed body, an offset outside the period or equal to the current phase,
    /// no action left.
    public func apply(_ move: CelestialEclipseLabAction, to state: Position) -> Position? {
        guard isOpen(state) else { return nil }
        switch move {
        case .run:
            return nil
        case .phase(let body, let offset):
            guard body >= 0, body < level.bodies.count else { return nil }
            let orbit: CelestialEclipseLabBody = level.bodies[body]
            guard !orbit.fixed, offset >= 0, offset < orbit.period, offset != state.phases[body] else { return nil }
            var phases: [Int] = state.phases
            phases[body] = offset
            return Position(phases: phases, actionsSpent: state.actionsSpent + 1)
        }
    }

    /// Whether a run from `state` would win: the predicted timeline of its phases matches the whole target (false for
    /// a position whose phases do not fit the level's bodies).
    public func isSolved(_ state: Position) -> Bool {
        guard state.phases.count == level.bodies.count else { return false }
        for body in level.bodies.indices {
            guard state.phases[body] >= 0, state.phases[body] < level.bodies[body].period else { return false }
        }
        return CelestialEclipseLabSky.timeline(level, phases: state.phases).wins
    }
}
