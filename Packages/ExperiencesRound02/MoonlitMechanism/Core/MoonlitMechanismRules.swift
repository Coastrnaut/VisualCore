// MoonlitMechanismRules — feature 431 (R02-G14-01) T-R02G1401-005 (FR-R02G1401-010). Moonlit Mechanism expressed as
// an R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the
// phase of every gear, the lamp height, the actions spent and the outcome), a move is a `MoonlitMechanismAction`, and a
// state is solved when its outcome is `won`. While playing (and while actions are left) the legal moves are, in exactly
// this order: turn −1, turn +1; for each gear 1 … n − 1 re-seat (gear, −1) then (gear, +1); lamp −1 then lamp +1, each
// only when the new height stays in 0 … L − 1; then the run. A won or failed position offers nothing. Applying a move
// mirrors the play's `apply(_:expecting:)`: a turn, a re-seat or a lamp step changes the set-up, spends 1 action and
// fails the level when it spends the last of the budget; a run spends 1 action and wins when the level's run of the
// position wins (even on the last action of the budget), else fails. A move the play would refuse (an unknown gear,
// re-seating the driver, a step other than ±1, a lamp step out of range) is refused (nil). The rules carry no stage,
// fingerprints, failure details, records, undo or redo: those belong to the play. Integers only; no clock, no random
// source.
import VisualCoreSimulation

/// The pure rules of one Moonlit Mechanism level as an R02-F23 puzzle contract.
public struct MoonlitMechanismRules: PuzzleRules {
    /// A position of a Moonlit Mechanism play as the rules see it: phases, lamp height, actions spent and outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Actions are still possible.
            case playing
            /// A run won: every mesh aligned, every required key frame matched, no forbidden cell shadowed.
            case won
            /// A run failed (jammed, forbidden, missing or stray), or another action spent the last of the budget.
            case failed
        }

        /// The phase of every gear, in gear order (whole teeth, 0 … teeth − 1).
        public let phases: [Int]
        /// The lamp height, 0 … the level's lamp heights − 1.
        public let height: Int
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(phases: [Int], height: Int, actionsSpent: Int, outcome: Outcome) {
            self.phases = phases
            self.height = height
            self.actionsSpent = actionsSpent
            self.outcome = outcome
        }
    }

    /// A position: phases, lamp height, actions spent and outcome.
    public typealias State = Position
    /// A player action: a handle turn, a re-seat, a lamp step or the run.
    public typealias Move = MoonlitMechanismAction

    /// The level whose gears, wall, lamp, key frames, forbidden cells, allowance and budget decide the results.
    public let level: MoonlitMechanismLevel

    /// The rules of `level`.
    public init(level: MoonlitMechanismLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g14-moonlit-mechanism" }

    /// The start position: the level's starting phases and lamp height, no action spent, still playing.
    public var initialState: Position {
        Position(phases: level.startingPhases, height: level.startingHeight, actionsSpent: 0, outcome: .playing)
    }

    /// Whether `step` is a single step (−1 or +1).
    private static func isStep(_ step: Int) -> Bool { step == 1 || step == -1 }

    /// Whether `height` is a lamp height of the level.
    private func isHeight(_ height: Int) -> Bool { height >= 0 && height < level.lampHeights }

    /// The legal moves: none once won or failed or with the budget spent; otherwise turn −1, turn +1, then for each
    /// gear 1 … n − 1 re-seat −1, +1, then lamp −1 and lamp +1 when the new height is in range, then the run.
    public func moves(in state: Position) -> [MoonlitMechanismAction] {
        guard state.outcome == .playing, state.actionsSpent < level.budget else { return [] }
        var result: [MoonlitMechanismAction] = [.turn(-1), .turn(1)]
        for gear in 1..<level.gears.count {
            result.append(.reseat(gear, -1))
            result.append(.reseat(gear, 1))
        }
        if isHeight(state.height - 1) { result.append(.lamp(-1)) }
        if isHeight(state.height + 1) { result.append(.lamp(1)) }
        result.append(.run)
        return result
    }

    /// The position after `move`, or nil when the play would refuse it. A turn moves every gear in its direction, a
    /// re-seat moves one non-driver gear, a lamp step moves the lamp within range; each spends 1 action and fails the
    /// level when the budget is fully spent. A run spends 1 action and wins when the level's run of the position wins,
    /// else fails — exactly as the play judges them.
    public func apply(_ move: MoonlitMechanismAction, to state: Position) -> Position? {
        guard state.outcome == .playing, state.actionsSpent < level.budget else { return nil }
        var phases: [Int] = state.phases
        var height: Int = state.height
        let spent: Int = state.actionsSpent + 1
        var outcome: Position.Outcome = .playing
        switch move {
        case .turn(let step):
            guard Self.isStep(step) else { return nil }
            phases = MoonlitMechanismTrain.turned(level.gears, phases: phases, by: step)
        case .reseat(let gear, let step):
            guard gear >= 1, gear < level.gears.count, gear < phases.count, Self.isStep(step) else { return nil }
            phases[gear] = MoonlitMechanismTrain.mod(phases[gear] + step, level.gears[gear].teeth)
        case .lamp(let step):
            guard Self.isStep(step), isHeight(height + step) else { return nil }
            height += step
        case .run:
            let won: Bool = level.run(phases: phases, height: height).outcome == .won
            return Position(phases: phases, height: height, actionsSpent: spent, outcome: won ? .won : .failed)
        }
        if spent >= level.budget { outcome = .failed }
        return Position(phases: phases, height: height, actionsSpent: spent, outcome: outcome)
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
