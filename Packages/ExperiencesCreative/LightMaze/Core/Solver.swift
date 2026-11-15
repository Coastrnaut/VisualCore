// Solver — feature 100 (A13-P05) T-A13-502 (FR-A13-501, FR-A13-502; SC-A13-501, SC-A13-502; clarifications Q1–Q3;
// research D1–D3; contract contracts/solver.md; gap G-SOLVER). A bounded, deterministic search proving a board solvable
// by the rules of play. Tiles never move, so the search space is the orientations of the turnable tiles; a turn
// toggles one tile, so the turns of an orientation set are the tiles whose orientation differs from the board's own.
//
// Order: k = 0, 1, … n turns; within k the combinations of turnable-tile indices in lexicographic order. Each set is
// traced with `BeamTracer.trace`; the first solved set is reported with its turns (the fewest possible) and the number
// of sets examined; when none of the 2ⁿ sets solves the board it is reported unsolvable with 2ⁿ examined. An invalid
// board (`invalid-board`, with its own refusal) or one with more than ``Solver/maxTurnable`` turnable tiles
// (`too-many-tiles`) is refused before anything is traced. The search runs in tests and release QA only; nothing in
// the experience calls it while a person plays.
import Foundation

/// Why the solver refused a board without searching.
public enum SolverRefusal: Equatable, Sendable {
    /// The board is invalid for the given reason.
    case invalidBoard(BoardRefusal)
    /// The board has this many turnable tiles, more than ``Solver/maxTurnable``.
    case tooManyTiles(Int)

    /// The refusal's code: `invalid-board` or `too-many-tiles`.
    public var code: String {
        switch self {
        case .invalidBoard: return "invalid-board"
        case .tooManyTiles: return "too-many-tiles"
        }
    }
}

/// The outcome of a search.
public enum SolverResult: Equatable, Sendable {
    /// The first solved set in search order: the turnable tiles' orientations (in tile order), the turns from the
    /// board's own orientations (the fewest possible) and the sets examined.
    case solved(orientations: [Orientation], turns: Int, examined: Int)
    /// No set solves the board; all 2ⁿ sets were examined.
    case unsolvable(examined: Int)
    /// The board was refused without searching.
    case refused(SolverRefusal)

    /// The number of sets examined (0 when refused).
    public var examined: Int {
        switch self {
        case .solved(_, _, let examined), .unsolvable(let examined): return examined
        case .refused: return 0
        }
    }
}

/// The bounded search over the turnable tiles' orientations.
public enum Solver {
    /// The most turnable tiles a board may have to be searched (at most 2¹⁶ = 65,536 sets).
    public static let maxTurnable = 16

    /// Searches `board` from its own orientations (see the file header).
    public static func solve(_ board: Board) -> SolverResult {
        if let problem = board.problem { return .refused(.invalidBoard(problem)) }
        let start = board.orientations
        let n = start.count
        guard n <= maxTurnable else { return .refused(.tooManyTiles(n)) }
        var examined = 0
        for k in 0...n {
            var combination = Array(0..<k)
            while true {
                var orientations = start
                for index in combination { orientations[index] = orientations[index].toggled }
                examined += 1
                if let candidate = board.applying(orientations), BeamTracer.trace(candidate).isSolved {
                    return .solved(orientations: orientations, turns: k, examined: examined)
                }
                guard let next = nextCombination(combination, n: n) else { break }
                combination = next
            }
        }
        return .unsolvable(examined: examined)
    }

    /// The turns from `start` to `orientations`: the number of positions that differ (both of the same length).
    public static func turns(from start: [Orientation], to orientations: [Orientation]) -> Int {
        var count = 0
        for index in 0..<min(start.count, orientations.count) where start[index] != orientations[index] { count += 1 }
        return count + abs(start.count - orientations.count)
    }

    /// The combination after `combination` (sorted indices into `0..<n`) in lexicographic order, or nil after the last
    /// (the empty combination has no successor).
    static func nextCombination(_ combination: [Int], n: Int) -> [Int]? {
        let k = combination.count
        guard k > 0 else { return nil }
        var next = combination
        var position = k - 1
        while position >= 0 && next[position] == n - k + position { position -= 1 }
        guard position >= 0 else { return nil }
        next[position] += 1
        var fill = position + 1
        while fill < k {
            next[fill] = next[fill - 1] + 1
            fill += 1
        }
        return next
    }
}
