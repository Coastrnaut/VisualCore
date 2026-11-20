// WaveKnotKeeperRules — feature 321 (R02-G03-01) T-R02G0301-005 (FR-R02G0301-008). Wave Knot Keeper expressed as an
// R02-F23 puzzle contract so later features can certify levels with `PuzzleValidator`: a state is the rope's control
// points, a move steps one control point one lattice unit, and a state is solved when it wins the level
// (`WaveKnotKeeperLevel.wins`: a non-degenerate xy-projection with the target's crossing count and writhe). A move is legal
// exactly when `WaveKnotKeeperPlay.refusal(of:points:level:)` finds nothing (range, bounds, coincidence, the sweep outside
// a gate, the tension bound). Moves are listed point index ascending, then direction in `WaveKnotKeeperDirection.allCases`
// order (plusX, minusX, plusY, minusY, plusZ, minusZ), keeping the legal ones, so a rope of at most 16 points offers at
// most 16 · 6 = 96 moves. The rules do not count moves: the allowance, the stage, undo and redo belong to the play, and a
// certification bounds solution length with its own fairness budget.
import VisualCoreSimulation

/// The pure rules of one Wave Knot Keeper level as an R02-F23 puzzle contract.
public struct WaveKnotKeeperRules: PuzzleRules {
    /// A position: the rope's control points, in rope order.
    public typealias State = [WaveKnotKeeperPoint]
    /// A player action: one control point stepped one unit along one direction.
    public typealias Move = WaveKnotKeeperMove

    /// The level whose gates and tension bound decide legality and whose target decides `isSolved(_:)`.
    public let level: WaveKnotKeeperLevel

    /// The rules of `level`.
    public init(level: WaveKnotKeeperLevel) {
        self.level = level
    }

    /// The family's id, stored in every certified level.
    public var rulesID: String { "r02-g03-wave-knot-keeper" }

    /// The start rope of the level (`level.points`).
    public var initialState: [WaveKnotKeeperPoint] { level.points }

    /// Every legal single-point step, ordered point index ascending, then direction in
    /// `WaveKnotKeeperDirection.allCases` order, keeping the moves `WaveKnotKeeperPlay.refusal(of:points:level:)` accepts
    /// (at most 6 per point, 96 for a rope of 16 points).
    public func moves(in state: [WaveKnotKeeperPoint]) -> [WaveKnotKeeperMove] {
        var result: [WaveKnotKeeperMove] = []
        result.reserveCapacity(state.count * WaveKnotKeeperDirection.allCases.count)
        for point in state.indices {
            for direction in WaveKnotKeeperDirection.allCases {
                let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                if WaveKnotKeeperPlay.refusal(of: move, points: state, level: level) == nil { result.append(move) }
            }
        }
        return result
    }

    /// The rope after `move` (its point stepped one unit), or nil when
    /// `WaveKnotKeeperPlay.refusal(of:points:level:)` refuses it.
    public func apply(_ move: WaveKnotKeeperMove, to state: [WaveKnotKeeperPoint]) -> [WaveKnotKeeperPoint]? {
        guard WaveKnotKeeperPlay.refusal(of: move, points: state, level: level) == nil else { return nil }
        var next: [WaveKnotKeeperPoint] = state
        next[move.point] = state[move.point].moved(move.direction)
        return next
    }

    /// Whether `state` wins the level (`WaveKnotKeeperLevel.wins`).
    public func isSolved(_ state: [WaveKnotKeeperPoint]) -> Bool {
        level.wins(state)
    }
}
