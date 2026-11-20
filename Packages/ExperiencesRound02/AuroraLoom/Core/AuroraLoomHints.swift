// AuroraLoomHints — feature 305 (R02-G01-05) T-R02G0105-002 (FR-R02G0105-002, 003; SC-R02G0105-002, 003; clarifications
// Q1, Q5; research R1). Progressive hints computed by the solver from the current steps, and the plain-English explanation
// of a failure from the kernel's worst mismatch. Hints never change a play, are unlimited and do not affect stars.
// Texts number ribbons and gates from 1 (ribbon index 0 is "Ribbon 1"), as the player sees them.

/// One hint of a play: what to change next on a shortest remaining solution (clarification Q1).
public struct AuroraLoomHint: Sendable, Equatable {
    /// The hint level, 1 … 3: 1 names the ribbon, 2 adds the control, 3 adds the exact step.
    public let level: Int
    /// The ribbon to change (0 … 2): the one whose optimal winning setting needs the most changes from the current steps.
    public let ribbon: Int
    /// The control to change (wave before phase when both change); nil at level 1.
    public let control: AuroraLoomControl?
    /// The step to set the control to (0 … 15); nil at levels 1 and 2.
    public let step: Int?
    /// The shortest number of moves that win from the current steps.
    public let remaining: Int
    /// Whether `remaining` fits in the moves left (`allowance − spent`).
    public let withinMoves: Bool

    /// A hint of the given values.
    public init(level: Int, ribbon: Int, control: AuroraLoomControl?, step: Int?, remaining: Int, withinMoves: Bool) {
        self.level = level
        self.ribbon = ribbon
        self.control = control
        self.step = step
        self.remaining = remaining
        self.withinMoves = withinMoves
    }

    /// The hint in plain English, ribbons numbered from 1:
    /// - not within the moves left: "No solution fits in the moves left; undo a move."
    /// - level 1: "Ribbon 2 is furthest from harmony."
    /// - level 2: "Change ribbon 2's wave." (or "phase")
    /// - level 3: "Set ribbon 2's wave to 7."
    public var text: String {
        guard withinMoves else { return "No solution fits in the moves left; undo a move." }
        let name: Int = ribbon + 1
        switch (control, step) {
        case (let control?, let step?): return "Set ribbon \(name)'s \(control.rawValue) to \(step)."
        case (let control?, nil): return "Change ribbon \(name)'s \(control.rawValue)."
        default: return "Ribbon \(name) is furthest from harmony."
        }
    }
}

/// The hint engine of Aurora Loom (clarification Q1; research R1).
public enum AuroraLoomHints {
    /// The hint of `level` (clamped to 1 … 3) for `play`, or nil unless the play is in stage `playing` (no hint while
    /// loading, in the tutorial, paused, won, failed or showing the result) or when the level has no solution.
    ///
    /// The solver runs from the play's current steps (``AuroraLoomSolver/solve(_:from:)``). The ribbon is the one whose
    /// chosen winning setting needs the most changes; ties go to the larger worst |residual| of that ribbon at the current
    /// steps, then the lower ribbon. The control is wave when that ribbon's wave changes, otherwise phase; the step is the
    /// chosen setting's value. Applying the level-3 move leaves a shortest remaining solution exactly one move shorter.
    public static func hint(level: Int, play: AuroraLoomPlay) -> AuroraLoomHint? {
        guard play.stage == .playing else { return nil }
        guard let solution = AuroraLoomSolver.solve(play.level, from: play.steps) else { return nil }
        let steps: AuroraLoomSteps = play.steps
        let target: AuroraLoomSteps = solution.setting
        var chosen: Int = 0
        var chosenChanges: Int = -1
        var chosenScore: Int = -1
        for ribbon in 0..<3 {
            let changes: Int = (target.wave[ribbon] != steps.wave[ribbon] ? 1 : 0)
                + (target.phase[ribbon] != steps.phase[ribbon] ? 1 : 0)
            let score: Int = AuroraLoomSolver.Scorer(level: play.level, ribbon: ribbon)
                .score(wave: steps.wave[ribbon], phase: steps.phase[ribbon])
            if changes > chosenChanges || (changes == chosenChanges && score > chosenScore) {
                chosen = ribbon
                chosenChanges = changes
                chosenScore = score
            }
        }
        let control: AuroraLoomControl = target.wave[chosen] != steps.wave[chosen] ? .wave : .phase
        let step: Int = control == .wave ? target.wave[chosen] : target.phase[chosen]
        let clamped: Int = min(3, max(1, level))
        return AuroraLoomHint(level: clamped, ribbon: chosen, control: clamped >= 2 ? control : nil,
                              step: clamped >= 3 ? step : nil, remaining: solution.shortest,
                              withinMoves: solution.shortest <= play.level.allowance - play.spent)
    }
}

/// The plain-English explanation of a failed play (FR-R02G0105-003; clarification Q5).
public struct AuroraLoomFailureExplanation: Sendable, Equatable {
    /// The kernel's failure: the worst mismatch after the last move (``AuroraLoomPlay/failure``).
    public let mismatch: AuroraLoomMismatch
    /// The level's tolerance in 1/4,096 turn.
    public let tolerance: Int

    /// The explanation of `play`'s failure, or nil unless the play is `failed`, or `result` with a failure.
    public init?(play: AuroraLoomPlay) {
        guard play.stage == .failed || play.stage == .result, let failure = play.failure else { return nil }
        mismatch = failure
        tolerance = play.level.tolerance
    }

    /// How far the worst residual lies outside the tolerance, in hundredths of a turn rounded up (at least 1), so a
    /// failure never reads as "0.00": ⌈(|residual| − tolerance) · 100 / 4,096⌉.
    public var hundredthsOutside: Int {
        let excess: Int = max(0, abs(mismatch.residual) - tolerance)
        return max(1, (excess * 100 + AuroraLoomHarmony.unitsPerTurn - 1) / AuroraLoomHarmony.unitsPerTurn)
    }

    /// The explanation, ribbons and gates numbered from 1, the distance as ``hundredthsOutside`` written "0.xx":
    /// "Ribbon 2 is furthest off at gate 3: 0.21 of a turn outside the tolerance after the last move. Undo or retry."
    public var text: String {
        let value: Int = hundredthsOutside
        let cents: Int = value % 100
        let amount: String = "\(value / 100)." + (cents < 10 ? "0\(cents)" : "\(cents)")
        return "Ribbon \(mismatch.ribbon + 1) is furthest off at gate \(mismatch.gate + 1): \(amount) of a turn outside "
            + "the tolerance after the last move. Undo or retry."
    }
}
