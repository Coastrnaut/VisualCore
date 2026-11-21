// WaveKnotKeeperHints — feature 325 (R02-G03-05) T-R02G0305-002 (FR-R02G0305-002, 003; clarifications Q1, Q5; research
// R1, R4). Progressive hints taken from the first move of the shortest remaining solution (the certified breadth-first
// search started from the play's current rope, depth at most 3), and the plain-English explanation of a failure from the
// kernel's projection summary against the target. Hints never change a play, are unlimited and do not affect stars.
// Point numbering: ``WaveKnotKeeperHint/point`` is the 0-based index into the rope's control points; texts show it
// from 1 ("Move point 4" for index 3), as the panel shows "Point n" to the player.

/// One hint of a play: the next move of the shortest remaining solution (clarification Q1).
public struct WaveKnotKeeperHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the point, 2 adds the axis, 3 adds the exact direction.
    public let level: Int
    /// The 0-based index of the control point the first move of the shortest remaining solution steps; −1 when no
    /// winning rope is within ``WaveKnotKeeperSolver/maximumDepth`` moves (then `withinMoves` is false).
    public let point: Int
    /// The axis of that move, 0 = x, 1 = y, 2 = z; nil at level 1 and when there is no move.
    public let axis: Int?
    /// The exact direction of that move; nil at levels 1 and 2 and when there is no move.
    public let direction: WaveKnotKeeperDirection?
    /// The fewest moves that win from the current rope; ``WaveKnotKeeperSolver/maximumDepth`` + 1 when no winning rope
    /// is within that depth.
    public let remaining: Int
    /// Whether a winning rope is within ``WaveKnotKeeperSolver/maximumDepth`` moves and `remaining` fits in the moves
    /// left (`allowance − spent`).
    public let withinMoves: Bool

    /// A hint of the given values (not checked).
    public init(level: Int, point: Int, axis: Int?, direction: WaveKnotKeeperDirection?, remaining: Int,
                withinMoves: Bool) {
        self.level = level
        self.point = point
        self.axis = axis
        self.direction = direction
        self.remaining = remaining
        self.withinMoves = withinMoves
    }

    /// The axis of `direction`: 0 = x, 1 = y, 2 = z.
    public static func axis(of direction: WaveKnotKeeperDirection) -> Int {
        switch direction {
        case .plusX, .minusX: 0
        case .plusY, .minusY: 1
        case .plusZ, .minusZ: 2
        }
    }

    /// The player-facing name of `axis` (0 … 2): "x", "y" or "z".
    public static func axisName(_ axis: Int) -> String {
        switch axis {
        case 0: "x"
        case 1: "y"
        default: "z"
        }
    }

    /// The player-facing name of `direction` with its signed axis: "right (+x)", "left (−x)", "up (+y)", "down (−y)",
    /// "over (+z)" or "under (−z)" (the minus sign is U+2212).
    public static func directionName(_ direction: WaveKnotKeeperDirection) -> String {
        switch direction {
        case .plusX: "right (+x)"
        case .minusX: "left (\u{2212}x)"
        case .plusY: "up (+y)"
        case .minusY: "down (\u{2212}y)"
        case .plusZ: "over (+z)"
        case .minusZ: "under (\u{2212}z)"
        }
    }

    /// The hint in plain English, the point numbered from 1 (clarification Q1):
    /// - not within the moves: "No short solution from here; undo or retry"
    /// - level 1: "Move point 4"
    /// - level 2: "Move point 4 along y"
    /// - level 3: "Move point 4 down (−y)" ("over (+z)" / "under (−z)" for ±z)
    public var text: String {
        guard withinMoves, point >= 0 else { return "No short solution from here; undo or retry" }
        let name: String = "Move point \(point + 1)"
        if let direction { return name + " " + Self.directionName(direction) }
        if let axis { return name + " along " + Self.axisName(axis) }
        return name
    }
}

/// The hint engine of Wave Knot Keeper (clarification Q1; research R1).
public enum WaveKnotKeeperHints {
    /// The hint of `level` (clamped to 1 … 3) for `play`, or nil unless the play is in stage `playing` (no hint while
    /// loading, in the tutorial, paused, won, failed or showing the result).
    ///
    /// The hint is the first move of ``WaveKnotKeeperSolver/solve(_:from:depth:)`` on `play.level` (so a practice copy
    /// of the level with a raised allowance is honoured) from the play's rope, depth
    /// ``WaveKnotKeeperSolver/maximumDepth``. `withinMoves` is false — and the text "No short solution from here; undo or
    /// retry" — when no winning rope is within that depth or the shortest remaining solution is longer than the moves
    /// left; otherwise applying the level-3 move leaves a shortest remaining solution exactly one move shorter (or wins).
    public static func hint(level: Int, play: WaveKnotKeeperPlay) -> WaveKnotKeeperHint? {
        guard play.stage == .playing else { return nil }
        return hint(level: level, play: play, solution: WaveKnotKeeperSolver.solve(play.level, from: play.points))
    }

    /// The hint of `level` (clamped to 1 … 3) for `play` from `solution`, the result of
    /// ``WaveKnotKeeperSolver/solve(_:from:depth:)`` on `play.level` from `play.points` at the maximum depth (one search
    /// serves all three levels); nil unless the play is `playing`.
    static func hint(level: Int, play: WaveKnotKeeperPlay, solution: WaveKnotKeeperSolution?) -> WaveKnotKeeperHint? {
        guard play.stage == .playing else { return nil }
        let clamped: Int = min(3, max(1, level))
        let left: Int = play.level.allowance - play.spent
        guard let solution, let first = solution.moves.first else {
            return WaveKnotKeeperHint(level: clamped, point: -1, axis: nil, direction: nil,
                                      remaining: WaveKnotKeeperSolver.maximumDepth + 1, withinMoves: false)
        }
        return WaveKnotKeeperHint(level: clamped, point: first.point,
                                  axis: clamped >= 2 ? WaveKnotKeeperHint.axis(of: first.direction) : nil,
                                  direction: clamped >= 3 ? first.direction : nil, remaining: solution.shortest,
                                  withinMoves: solution.shortest <= left)
    }
}

/// The plain-English explanation of a failed play (FR-R02G0305-003; clarification Q5; research R4).
public struct WaveKnotKeeperFailureExplanation: Sendable, Equatable {
    /// The kernel's projection summary of the final rope (``WaveKnotKeeperPlay/failure``).
    public let summary: WaveKnotKeeperSummary
    /// The level's target signature.
    public let target: WaveKnotKeeperTarget

    /// The explanation of `play`'s failure, or nil unless the play is `failed`, or `result` after a failure.
    public init?(play: WaveKnotKeeperPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        summary = failure
        target = play.level.target
    }

    /// The explanation (clarification Q5):
    /// - "The rope has c crossings and writhe w; the target is C and W. Undo the last move or retry the level."
    /// - degenerate projection: "Two strands overlap in the view, so the crossings cannot be counted. Undo the last move
    ///   or retry the level."
    public var text: String {
        let advice: String = " Undo the last move or retry the level."
        if summary.degenerate {
            return "Two strands overlap in the view, so the crossings cannot be counted." + advice
        }
        return "The rope has \(summary.crossings) crossings and writhe \(summary.writhe); the target is "
            + "\(target.crossings) and \(target.writhe)." + advice
    }
}
