// VoxelOrigamiRules — feature 441 (R02-G15-01) T-R02G1501-005 (FR-R02G1501-010). Voxel Origami expressed as an R02-F23
// puzzle contract so later features can certify levels with `PuzzleValidator`: a state is a `Position` (the quarter
// turn of every hinge, the actions spent and the outcome), a move is a `VoxelOrigamiAction`, and a state is solved when
// its outcome is `won`. While playing (and while actions are left) the legal moves are, in exactly this order: for each
// hinge 1 … n − 1 that `level.canTurn` at the position's turns (a hinge that would swing at least one cube), turn
// (hinge, −1) then (hinge, +1). A won or failed position offers nothing. Applying a move mirrors the play's
// `apply(_:expecting:)`: a turn spends 1 action; when `VoxelOrigamiLattice.check` refuses it (collision or sweep) the
// level fails with the turns unchanged; otherwise the turns change, the level is won when the shape matches the target
// (even on the last action of the budget), else a turn that spends the last of the budget fails the level. A move the
// play would refuse (an unknown hinge, a step other than ±1, an idle hinge) is refused (nil). The rules carry no stage,
// fingerprints, failure details, pose, report, records, undo or redo: those belong to the play. Integers only; no
// clock, no random source. Modelled on `MoonlitMechanismRules` (feature 431).
import VisualCoreSimulation

/// The pure rules of one Voxel Origami level as an R02-F23 puzzle contract.
public struct VoxelOrigamiRules: PuzzleRules {
    /// A position of a Voxel Origami play as the rules see it: quarter turns, actions spent and outcome.
    public struct Position: Hashable, Codable, Sendable {
        /// Whether play continues or how it ended.
        public enum Outcome: String, Hashable, Codable, Sendable {
            /// Turns are still possible.
            case playing
            /// A clear turn left a shape that matches the target.
            case won
            /// A turn collided or swept through a still cube, or a turn spent the last of the budget without a match.
            case failed
        }

        /// The quarter turn of every hinge, in cube order (0 … 3; the root's entry is always 0).
        public let turns: [Int]
        /// The actions spent, 0 … the level's budget.
        public let actionsSpent: Int
        /// Whether play continues or how it ended.
        public let outcome: Outcome

        /// A position of the given values (not checked).
        public init(turns: [Int], actionsSpent: Int, outcome: Outcome) {
            self.turns = turns
            self.actionsSpent = actionsSpent
            self.outcome = outcome
        }
    }

    /// A position: quarter turns, actions spent and outcome.
    public typealias State = Position
    /// A player action: a quarter turn of one hinge.
    public typealias Move = VoxelOrigamiAction

    /// The level whose cubes, target, orientations and budget decide the results.
    public let level: VoxelOrigamiLevel

    /// The rules of `level`.
    public init(level: VoxelOrigamiLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g15-voxel-origami" }

    /// The start position: the level's start turns, no action spent, still playing.
    public var initialState: Position {
        Position(turns: level.startTurns, actionsSpent: 0, outcome: .playing)
    }

    /// The legal moves: none once won or failed or with the budget spent; otherwise for each hinge 1 … n − 1 that
    /// would swing at least one cube at the position's turns, turn −1 then turn +1.
    public func moves(in state: Position) -> [VoxelOrigamiAction] {
        guard state.outcome == .playing, state.actionsSpent < level.budget,
              state.turns.count == level.cubes.count else { return [] }
        var result: [VoxelOrigamiAction] = []
        for hinge in 1..<level.cubes.count where level.canTurn(hinge, turns: state.turns) {
            result.append(.turn(hinge, -1))
            result.append(.turn(hinge, 1))
        }
        return result
    }

    /// The position after `move`, or nil when the play would refuse it. A turn spends 1 action; a turn the lattice
    /// check refuses fails the level with the turns unchanged; a clear turn changes the turns and wins when the shape
    /// matches the target, else fails the level when the budget is fully spent — exactly as the play judges it.
    public func apply(_ move: VoxelOrigamiAction, to state: Position) -> Position? {
        guard state.outcome == .playing, state.actionsSpent < level.budget,
              state.turns.count == level.cubes.count else { return nil }
        let spent: Int = state.actionsSpent + 1
        switch move {
        case .turn(let hinge, let step):
            guard hinge >= 1, hinge < level.cubes.count, step == 1 || step == -1,
                  level.canTurn(hinge, turns: state.turns) else { return nil }
            if VoxelOrigamiLattice.check(level.cubes, turns: state.turns, hinge: hinge, step: step) != nil {
                return Position(turns: state.turns, actionsSpent: spent, outcome: .failed)
            }
            let turns: [Int] = VoxelOrigamiLattice.turned(state.turns, hinge: hinge, step: step)
            if level.report(turns: turns).matched {
                return Position(turns: turns, actionsSpent: spent, outcome: .won)
            }
            return Position(turns: turns, actionsSpent: spent, outcome: spent >= level.budget ? .failed : .playing)
        }
    }

    /// Whether `state`'s outcome is `won`.
    public func isSolved(_ state: Position) -> Bool {
        state.outcome == .won
    }
}
