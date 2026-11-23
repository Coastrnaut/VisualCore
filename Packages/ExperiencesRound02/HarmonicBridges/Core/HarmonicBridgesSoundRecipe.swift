// HarmonicBridgesSoundRecipe — feature 416 (R02-G12-06) T-R02G1206-004 (FR-R02G1206-006; SC-R02G1206-004;
// clarification Q4). The optional sound of Harmonic Bridges: the audition of a plucked string and the ambient loop,
// both pure, so equal inputs sound equal.
//
// The audition (`HarmonicBridgesAudition.of(_:string:step:)`) is a pure function of the string's peg and its resonant
// modes and tone strengths in the given step of the snapshot: a fundamental of 110 Hz × 2^((peg − 1) / 12) (peg 1 is
// A2, each peg a semitone higher, peg 12 at 110 × 2^(11/12) ≈ 207.65 Hz); one partial per resonant mode n with tone
// strength w, in tone order, at the fundamental × n with gain 0.04 × w (modes 1 … 5 and strengths 1 … 3, so at most
// 1,038.3 Hz and gain 0.12 per partial); a string that sings no mode in that step gets the fundamental alone at gain 0.02
// (the muted pluck). It lasts ``HarmonicBridgesAudition/duration`` (0.6 s) with a linear decay to silence, played once
// per pluck, a new pluck replacing the last. An unknown string gives no partials (silence); an unknown step sings no
// mode, so it gives the muted pluck.
//
// The ambient loop (`HarmonicBridgesSoundRecipe.recipe(play:)`) is an `AmbientLoopRecipe`, a pure function of the actions
// left against the level's action budget, the steps in which the start reaches the goal and the stage. The root step is
// 0 for more than three quarters of the budget left, 1 for more than half, 2 for more than a quarter and 3 otherwise
// (`rootStep(actionsLeft:budget:)`, decided in integers: 4·left > 3·budget, 2·left > budget, 4·left > budget), and the
// root is 110 Hz × (1, 9/8, 5/4, 4/3)[step] (110, 123.75, 137.5 and 146.67 Hz), so the key rises as the actions drain;
// each step in which the start reaches the goal adds a partial, the k-th at the root × (5/4, 3/2, 2, 5/2)[k − 1], up to
// four, every partial at the base amplitude, so the chord opens as the crossing holds in more steps; with none reached
// the root sounds alone. A won play adds the octave (the root × 2) at the base amplitude as its own partial and swells
// twice per loop (as Echo Cartographer, feature 406, so every (step, reached, stage) triple stays distinct among
// playing, won and failed although the won octave coincides with the third reached partial); at most 1 + 4 + 1 = 6
// partials sound, within the limit. A failed play halves every amplitude and the loop gain (the synthesiser normalises
// the summed partials to the loop gain, so the gain is what makes it quieter). Every other stage (loading, tutorial,
// paused, result) sounds as playing.
//
// The loop length is the longest the shared player accepts (`AmbientLoopRecipe.secondsRange`, 4 … 16 s) at which every
// partial of this recipe has a whole number of cycles. Each frequency is an exact fraction n / d of hertz (110 × the
// step's ratio × the partial's ratio, in integers), so a length of L seconds gives n × L / d cycles, whole exactly when
// d divides n × L; the length is found by trying 16, 15, … 4 s in integer arithmetic and taking the first that fits
// every partial: 16 s for steps 0 … 2 and 15 s for step 3 (the 4/3 root). Bounds: at most 6 partials (limit 6),
// amplitudes ≤ 0.6 (limit 1), gain ≤ 0.2 (limit 0.3), 15 or 16 s (limit 4 … 16), swell 1 or 2 cycles, so every recipe
// is valid. Integers decide the step and the length; the Doubles are the recipe's amplitudes and gain only.
import Foundation
import VisualCoreAudioDSP

/// One sine partial of an audition: a frequency in hertz and a gain.
public struct HarmonicBridgesPartial: Sendable, Equatable {
    /// The frequency, in hertz.
    public let frequency: Double
    /// The gain, 0 … 1.
    public let gain: Double

    /// A partial at `frequency` hertz with `gain`.
    public init(frequency: Double, gain: Double) {
        self.frequency = frequency
        self.gain = gain
    }
}

/// The audition of a plucked string: its partials, decaying linearly to silence over ``duration`` (presentation only).
public struct HarmonicBridgesAudition: Sendable, Equatable {
    /// The audition's length, in seconds, with a linear decay to silence.
    public static let duration = 0.6
    /// The fundamental of peg 1, in hertz (A2).
    public static let baseHertz = 110.0
    /// The gain per unit of tone strength of a resonant mode's partial.
    public static let modeGain = 0.04
    /// The gain of the muted pluck (the fundamental alone, for a string that sings no mode).
    public static let mutedGain = 0.02

    /// The partials, in order: one per resonant mode in tone order, or the fundamental alone; empty for silence.
    public let partials: [HarmonicBridgesPartial]

    /// An audition of `partials`.
    public init(partials: [HarmonicBridgesPartial]) {
        self.partials = partials
    }

    /// The fundamental of `peg`, in hertz: 110 × 2^((peg − 1) / 12).
    public static func fundamental(peg: Int) -> Double {
        baseHertz * pow(2, Double(peg - 1) / 12)
    }

    /// The audition of string `string` in step `step` of `snapshot`: at the string's peg, one partial per resonant mode
    /// n with tone strength w at ``fundamental(peg:)`` × n and gain ``modeGain`` × w, or the fundamental alone at
    /// ``mutedGain`` when the string sings no mode in that step (an unknown step included); no partials for an unknown
    /// string.
    public static func of(_ snapshot: HarmonicBridgesSceneSnapshot, string: Int, step: Int) -> HarmonicBridgesAudition {
        guard string >= 0, string < snapshot.pegs.count else { return HarmonicBridgesAudition(partials: []) }
        let root: Double = fundamental(peg: snapshot.pegs[string])
        var modes: [Int] = []
        var strengths: [Int] = []
        if step >= 0, step < snapshot.modes.count, step < snapshot.strengths.count,
           string < snapshot.modes[step].count, string < snapshot.strengths[step].count {
            modes = snapshot.modes[step][string]
            strengths = snapshot.strengths[step][string]
        }
        var partials: [HarmonicBridgesPartial] = []
        for index in 0..<min(modes.count, strengths.count) {
            partials.append(HarmonicBridgesPartial(frequency: root * Double(modes[index]),
                                                   gain: modeGain * Double(strengths[index])))
        }
        if partials.isEmpty { partials.append(HarmonicBridgesPartial(frequency: root, gain: mutedGain)) }
        return HarmonicBridgesAudition(partials: partials)
    }
}

/// The ambient loop recipe of Harmonic Bridges (presentation only; the presenter builds it when a level opens, when an
/// action, undo or redo changes the steps reached, the root step or the stage, and when the Sound toggle turns on —
/// never per frame).
public enum HarmonicBridgesSoundRecipe {
    /// An exact frequency ratio or frequency, `numerator / denominator` (denominator ≥ 1).
    struct Fraction: Sendable, Equatable {
        /// The numerator.
        let numerator: Int
        /// The denominator (≥ 1).
        let denominator: Int

        /// The product of this fraction and `other` (not reduced; only divisibility is asked of it).
        func times(_ other: Fraction) -> Fraction {
            Fraction(numerator: numerator * other.numerator, denominator: denominator * other.denominator)
        }

        /// The value as a `Double`.
        var value: Double { Double(numerator) / Double(denominator) }

        /// Whether `seconds` × this frequency is a whole number of cycles.
        func isWhole(seconds: Int) -> Bool { (numerator * seconds) % denominator == 0 }

        /// The cycles in `seconds` seconds, rounded down (exact when ``isWhole(seconds:)``).
        func cycles(seconds: Int) -> Int { numerator * seconds / denominator }
    }

    /// The root frequency at root step 0, in hertz (A2).
    public static let rootHertz = 110
    /// The amplitude of the root, of every reached-step partial and of the won octave.
    public static let baseAmplitude = 0.6
    /// The loop gain in every stage but `failed`.
    public static let baseGain = 0.2
    /// The swell cycles per loop in every stage but `won`.
    public static let baseSwellCycles = 1
    /// The swell cycles per loop when won.
    public static let wonSwellCycles = 2
    /// The root steps the recipe distinguishes (0: more than three quarters of the actions left … 3: a quarter or
    /// less); others are clamped into it.
    public static let rootSteps: ClosedRange<Int> = 0...3
    /// The most reached-step partials that sound (one per step in which the start reaches the goal).
    public static let maxReachedPartials = 4

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the k-th reached-step partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let reachedFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                               Fraction(numerator: 3, denominator: 2),
                                               Fraction(numerator: 2, denominator: 1),
                                               Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the k-th reached-step partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    public static var reachedRatios: [Double] { reachedFractions.map(\.value) }

    /// The root step of `actionsLeft` of a budget `budget` (a budget below 1 counts as 1; integer comparisons only):
    /// 0 when more than three quarters is left (4·left > 3·budget), 1 when more than half (2·left > budget), 2 when
    /// more than a quarter (4·left > budget), else 3.
    public static func rootStep(actionsLeft: Int, budget: Int) -> Int {
        let whole: Int = max(budget, 1)
        if 4 * actionsLeft > 3 * whole { return 0 }
        if 2 * actionsLeft > whole { return 1 }
        if 4 * actionsLeft > whole { return 2 }
        return 3
    }

    /// `step` clamped to ``rootSteps``.
    public static func clampedStep(_ step: Int) -> Int { min(max(step, rootSteps.lowerBound), rootSteps.upperBound) }

    /// The number of reached-step partials: `reached` clamped to 0 … ``maxReachedPartials``.
    public static func reachedPartials(reached: Int) -> Int { min(max(reached, 0), maxReachedPartials) }

    /// The number of steps of `play` in which the start reaches the goal (`report.reached[step][goal]`).
    public static func stepsReached(_ play: HarmonicBridgesPlay) -> Int {
        let goal: Int = play.level.goal
        var count: Int = 0
        for row in play.report.reached where goal >= 0 && goal < row.count && row[goal] { count += 1 }
        return count
    }

    /// The exact frequencies, in hertz, of the partials of the recipe for `rootStep`, `reached` and `stage`, in order:
    /// the root, one per reached-step partial, and the octave when won.
    static func fractions(rootStep: Int, reached: Int, stage: HarmonicBridgesStage) -> [Fraction] {
        let root: Fraction = Fraction(numerator: rootHertz, denominator: 1)
            .times(stepFractions[clampedStep(rootStep) - rootSteps.lowerBound])
        var result: [Fraction] = [root]
        for index in 0..<reachedPartials(reached: reached) {
            result.append(root.times(reachedFractions[index]))
        }
        if stage == .won { result.append(root.times(octaveFraction)) }
        return result
    }

    /// The frequencies, in hertz, of the partials of the recipe for `rootStep`, `reached` and `stage`, in order: the
    /// root (110 Hz × ``stepRatios``[step]), one per reached-step partial (the root × ``reachedRatios``[k − 1]), and
    /// the octave (the root × 2) when won.
    public static func frequencies(rootStep: Int, reached: Int, stage: HarmonicBridgesStage) -> [Double] {
        fractions(rootStep: rootStep, reached: reached, stage: stage).map(\.value)
    }

    /// The longest loop length in `AmbientLoopRecipe.secondsRange` at which every frequency of `fractions` has a
    /// whole number of cycles; nil when none does.
    static func longestWholeSeconds(_ fractions: [Fraction]) -> Int? {
        let range: ClosedRange<Int> = AmbientLoopRecipe.secondsRange
        for seconds in stride(from: range.upperBound, through: range.lowerBound, by: -1) {
            var whole: Bool = true
            for fraction in fractions where !fraction.isWhole(seconds: seconds) { whole = false }
            if whole { return seconds }
        }
        return nil
    }

    /// The loop length of the recipe for `rootStep`, `reached` and `stage`: the longest the shared player accepts
    /// (16 s at most) at which every partial has a whole number of cycles — 16 s for steps 0 … 2 and 15 s for step 3.
    public static func loopSeconds(rootStep: Int, reached: Int, stage: HarmonicBridgesStage) -> Int {
        longestWholeSeconds(fractions(rootStep: rootStep, reached: reached, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for root step `rootStep` with the goal reached in `reached` steps in `stage`: the root and a partial
    /// per reached step up to four (``frequencies(rootStep:reached:stage:)``), the octave as its own partial when won,
    /// over ``loopSeconds(rootStep:reached:stage:)`` with whole cycles; every partial at ``baseAmplitude`` and the gain
    /// ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(rootStep: Int, reached: Int, stage: HarmonicBridgesStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let exact: [Fraction] = fractions(rootStep: rootStep, reached: reached, stage: stage)
        let seconds: Int = longestWholeSeconds(exact) ?? AmbientLoopRecipe.secondsRange.upperBound
        var partials: [AmbientLoopPartial] = []
        for fraction in exact {
            partials.append(AmbientLoopPartial(cyclesPerLoop: fraction.cycles(seconds: seconds), amplitude: amplitude))
        }
        let swell: Int = stage == .won ? wonSwellCycles : baseSwellCycles
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: swell, gain: baseGain * scale)
    }

    /// The recipe of `play`: ``recipe(rootStep:reached:stage:)`` with the root step of the actions left against the
    /// level's action budget (``rootStep(actionsLeft:budget:)``), the steps in which the start reaches the goal
    /// (``stepsReached(_:)``) and the play's stage.
    public static func recipe(play: HarmonicBridgesPlay) -> AmbientLoopRecipe {
        recipe(rootStep: rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
               reached: stepsReached(play), stage: play.stage)
    }
}
