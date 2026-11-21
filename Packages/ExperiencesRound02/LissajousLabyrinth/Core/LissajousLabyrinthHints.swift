// LissajousLabyrinthHints — feature 315 (R02-G02-05) T-R02G0205-002 (FR-R02G0205-002, 003; clarifications Q1, Q5;
// research R1). Progressive hints taken from the first action of a shortest remaining solution (the certified
// breadth-first search started from the current dials over the level's winning set), and the plain-English explanation
// of a failure from the kernel's lap verdict. Hints never change a play, are unlimited and do not affect stars. Texts
// number obstacles and checkpoints from 1 (index 0 is "obstacle 1"), as the player sees them.

/// One hint of a play: the next action of a shortest remaining solution (clarification Q1).
public struct LissajousLabyrinthHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the dial, 2 adds raise or lower, 3 adds the exact value.
    public let level: Int
    /// The dial the first action of the shortest remaining solution sets.
    public let dial: LissajousLabyrinthDial
    /// Whether that action raises the dial (true) or lowers it (false); nil at level 1.
    public let raise: Bool?
    /// The value that action sets; nil at levels 1 and 2.
    public let value: Int?
    /// The fewest actions that win from the current dials.
    public let remaining: Int
    /// Whether `remaining` fits in the actions left (`allowance − spent`).
    public let withinActions: Bool

    /// A hint of the given values.
    public init(level: Int, dial: LissajousLabyrinthDial, raise: Bool?, value: Int?, remaining: Int,
                withinActions: Bool) {
        self.level = level
        self.dial = dial
        self.raise = raise
        self.value = value
        self.remaining = remaining
        self.withinActions = withinActions
    }

    /// The player-facing name of `dial`: "Frequency A", "Frequency B", "Phase A" or "Phase C".
    public static func title(_ dial: LissajousLabyrinthDial) -> String {
        switch dial {
        case .frequencyA: "Frequency A"
        case .frequencyB: "Frequency B"
        case .phaseA: "Phase A"
        case .phaseC: "Phase C"
        }
    }

    /// The hint in plain English:
    /// - not within the actions left: "No solution fits in the actions left; undo or retry."
    /// - level 1: "Turn Phase A."
    /// - level 2: "Raise Phase A." or "Lower Phase A."
    /// - level 3: "Set Phase A to 7."
    public var text: String {
        guard withinActions else { return "No solution fits in the actions left; undo or retry." }
        let name: String = Self.title(dial)
        switch (raise, value) {
        case (_, let value?): return "Set \(name) to \(value)."
        case (let raise?, nil): return (raise ? "Raise " : "Lower ") + name + "."
        default: return "Turn \(name)."
        }
    }
}

/// The hint engine of Lissajous Labyrinth (clarification Q1; research R1, R2).
public enum LissajousLabyrinthHints {
    /// The hint of `level` (clamped to 1 … 3) for `play`, or nil unless the play is in stage `playing` (no hint while
    /// loading, in the tutorial, paused, won, failed or showing the result), or when no winning setting is reachable.
    ///
    /// `winning` is the level's winning set, `LissajousLabyrinthSolver.winningSettings(play.level).settings`, computed
    /// once when the level opens (research R2). The hint is the first action of
    /// ``LissajousLabyrinthSolver/solve(_:from:winning:)`` from the play's dials: its dial, whether its value is above
    /// the current one, and its value. Applying the level-3 action leaves a shortest remaining solution exactly one
    /// action shorter.
    public static func hint(level: Int, play: LissajousLabyrinthPlay,
                            winning: [LissajousLabyrinthDials]) -> LissajousLabyrinthHint? {
        guard play.stage == .playing else { return nil }
        guard let solution = LissajousLabyrinthSolver.solve(play.level, from: play.dials, winning: winning),
              let first = solution.actions.first else { return nil }
        let clamped: Int = min(3, max(1, level))
        let raise: Bool = first.value > play.dials[first.dial]
        return LissajousLabyrinthHint(level: clamped, dial: first.dial, raise: clamped >= 2 ? raise : nil,
                                      value: clamped >= 3 ? first.value : nil, remaining: solution.shortest,
                                      withinActions: solution.shortest <= play.level.allowance - play.spent)
    }
}

/// The plain-English explanation of a failed play (FR-R02G0205-003; clarification Q5).
public struct LissajousLabyrinthFailureExplanation: Sendable, Equatable {
    /// The kernel's failure: the lap verdict after the last action (``LissajousLabyrinthPlay/failure``), a contact or a
    /// missed checkpoint.
    public let verdict: LissajousLabyrinthVerdict

    /// The explanation of `play`'s failure, or nil unless the play is `failed`, or `result` with a failure.
    public init?(play: LissajousLabyrinthPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure,
              failure != .won else { return nil }
        verdict = failure
    }

    /// The explanation, obstacles and checkpoints numbered from 1:
    /// - contact: "The path touches obstacle 2 at 37 % of the lap. Undo the last change or retry the level." where the
    ///   percentage is ⌊100 · tick / 4,096⌋;
    /// - missed: "Checkpoint 3 is not reached in order. Undo the last change or retry the level."
    public var text: String {
        let advice: String = " Undo the last change or retry the level."
        switch verdict {
        case .contact(let obstacle, let tick):
            let percent: Int = 100 * tick / LissajousLabyrinthLap.ticks
            return "The path touches obstacle \(obstacle + 1) at \(percent) % of the lap." + advice
        case .missed(let checkpoint):
            return "Checkpoint \(checkpoint + 1) is not reached in order." + advice
        case .won:
            return "The lap wins."
        }
    }
}
