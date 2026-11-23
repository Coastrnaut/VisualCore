// BackwardsAuroraSoundRecipe — feature 396 (R02-G10-06) T-R02G1006-004 (FR-R02G1006-006; SC-R02G1006-004;
// clarification Q4). The optional ambient sound of Backwards Aurora as an `AmbientLoopRecipe`, a pure function of the
// worst bend against the bend limit, the checkpoints matched and the stage, so equal plays sound equal. The root step is
// 0 for a worst bend at most the limit L, 1 for at most 2L, 2 for at most 4L and 3 above (`rootStep(worstBend:limit:)`),
// and the root is 110 Hz × (1, 9/8, 5/4, 4/3)[step] (110, 123.75, 137.5 and 146.67 Hz), so the key rises as the aurora
// bends harder; each matched checkpoint adds its partial at the root × (5/4, 3/2, 2, 5/2)[k − 1], up to four, every
// partial at the base amplitude, so the chord opens as checkpoints match; with none matched the root sounds alone. A won
// play adds the octave (the root × 2) at the base amplitude as its own partial; at most 1 + 4 + 1 = 6 partials sound,
// within the limit. The won octave coincides with the third checkpoint partial (ratio 2), so a won chord of k matched
// has the same partials as the playing chord of k + 1; a won loop therefore also swells twice per loop instead of once
// (as in Faceted Forge, feature 376, and Nocturne Garden, feature 386), which keeps the recipe of every (step, matched,
// stage) triple distinct among playing, won and failed. A failed play halves every amplitude and the loop gain (the
// synthesiser normalises the summed partials to the loop gain, so the gain is what makes it quieter). Every other stage
// (loading, tutorial, paused, result) sounds as playing.
//
// The loop length is the longest the shared player accepts (`AmbientLoopRecipe.secondsRange`, 4 … 16 s) at which
// every partial of this recipe has a whole number of cycles. Each frequency is an exact fraction n / d of hertz
// (110 × the step's ratio × the partial's ratio, in integers), so a length of L seconds gives n × L / d cycles, whole
// exactly when d divides n × L; the length is found by trying 16, 15, … 4 s in integer arithmetic and taking the first
// that fits every partial. The denominators reduce to 1, 2, 4, 8 or 16 for steps 0 … 2 (so 16 s fits) and to 3 for
// step 3 (the 4/3 root: 15 s), so every recipe has a length: step 0 gives 1,760 root cycles in 16 s, step 1 1,980,
// step 2 2,200 and step 3 2,200 in 15 s. Bounds: at most 6 partials (limit 6), amplitudes ≤ 0.6 (limit 1), gain ≤ 0.2
// (limit 0.3), 15 or 16 s (limit 4 … 16), swell 1 or 2 cycles, so every recipe is valid. Integers decide the step and
// the length; the Doubles are the recipe's amplitudes and gain only.
import VisualCoreAudioDSP

/// The ambient loop recipe of Backwards Aurora (presentation only; the presenter builds it when a level opens, when a
/// reversal, undo or redo changes the matched count, the root step or the stage, and when the Sound toggle turns on —
/// never per frame).
public enum BackwardsAuroraSoundRecipe {
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
    /// The amplitude of the root, of every checkpoint partial and of the won octave.
    public static let baseAmplitude = 0.6
    /// The loop gain in every stage but `failed`.
    public static let baseGain = 0.2
    /// The swell cycles per loop in every stage but `won`.
    public static let baseSwellCycles = 1
    /// The swell cycles per loop when won.
    public static let wonSwellCycles = 2
    /// The root steps the recipe distinguishes (0: worst bend within the limit … 3: above four times it); others are
    /// clamped into it.
    public static let rootSteps: ClosedRange<Int> = 0...3
    /// The most checkpoint partials that sound (one per matched checkpoint).
    public static let maxCheckpointPartials = 4

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the partial of the k-th matched checkpoint, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let checkpointFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                                  Fraction(numerator: 3, denominator: 2),
                                                  Fraction(numerator: 2, denominator: 1),
                                                  Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the partial of the k-th matched checkpoint, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    public static var checkpointRatios: [Double] { checkpointFractions.map(\.value) }

    /// The root step of a worst bend `worstBend` against the bend limit `limit` (a limit below 1 counts as 1): 0 when
    /// the worst bend is at most the limit, 1 when at most twice it, 2 when at most four times it, else 3.
    public static func rootStep(worstBend: Int, limit: Int) -> Int {
        let unit: Int = max(limit, 1)
        if worstBend <= unit { return 0 }
        if worstBend <= 2 * unit { return 1 }
        if worstBend <= 4 * unit { return 2 }
        return 3
    }

    /// `step` clamped to ``rootSteps``.
    public static func clampedStep(_ step: Int) -> Int { min(max(step, rootSteps.lowerBound), rootSteps.upperBound) }

    /// The number of checkpoint partials: `matched` clamped to 0 … ``maxCheckpointPartials``.
    public static func checkpointPartials(matched: Int) -> Int { min(max(matched, 0), maxCheckpointPartials) }

    /// The exact frequencies, in hertz, of the partials of the recipe for `rootStep`, `matched` and `stage`, in order:
    /// the root, one per checkpoint partial, and the octave when won.
    static func fractions(rootStep: Int, matched: Int, stage: BackwardsAuroraStage) -> [Fraction] {
        let root: Fraction = Fraction(numerator: rootHertz, denominator: 1)
            .times(stepFractions[clampedStep(rootStep) - rootSteps.lowerBound])
        var result: [Fraction] = [root]
        for index in 0..<checkpointPartials(matched: matched) {
            result.append(root.times(checkpointFractions[index]))
        }
        if stage == .won { result.append(root.times(octaveFraction)) }
        return result
    }

    /// The frequencies, in hertz, of the partials of the recipe for `rootStep`, `matched` and `stage`, in order: the
    /// root (110 Hz × ``stepRatios``[step]), one per checkpoint partial (the root × ``checkpointRatios``[k − 1]), and
    /// the octave (the root × 2) when won.
    public static func frequencies(rootStep: Int, matched: Int, stage: BackwardsAuroraStage) -> [Double] {
        fractions(rootStep: rootStep, matched: matched, stage: stage).map(\.value)
    }

    /// The longest loop length in `AmbientLoopRecipe.secondsRange` at which every frequency of `fractions` has a
    /// whole number of cycles; nil when none does.
    static func longestWholeSeconds(_ fractions: [Fraction]) -> Int? {
        let range: ClosedRange<Int> = AmbientLoopRecipe.secondsRange
        for seconds in stride(from: range.upperBound, through: range.lowerBound, by: -1)
        where fractions.allSatisfy({ $0.isWhole(seconds: seconds) }) {
            return seconds
        }
        return nil
    }

    /// The loop length of the recipe for `rootStep`, `matched` and `stage`: the longest the shared player accepts
    /// (16 s at most) at which every partial has a whole number of cycles — 16 s for steps 0 … 2 and 15 s for step 3.
    public static func loopSeconds(rootStep: Int, matched: Int, stage: BackwardsAuroraStage) -> Int {
        longestWholeSeconds(fractions(rootStep: rootStep, matched: matched, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for root step `rootStep` with `matched` checkpoints matched in `stage`: the root and a partial per
    /// matched checkpoint up to four (``frequencies(rootStep:matched:stage:)``), the octave as its own partial when won,
    /// over ``loopSeconds(rootStep:matched:stage:)`` with whole cycles; every partial at ``baseAmplitude`` and the gain
    /// ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(rootStep: Int, matched: Int, stage: BackwardsAuroraStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let exact: [Fraction] = fractions(rootStep: rootStep, matched: matched, stage: stage)
        let seconds: Int = longestWholeSeconds(exact) ?? AmbientLoopRecipe.secondsRange.upperBound
        var partials: [AmbientLoopPartial] = []
        for fraction in exact {
            partials.append(AmbientLoopPartial(cyclesPerLoop: fraction.cycles(seconds: seconds), amplitude: amplitude))
        }
        let swell: Int = stage == .won ? wonSwellCycles : baseSwellCycles
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: swell, gain: baseGain * scale)
    }

    /// The recipe of `play`: ``recipe(rootStep:matched:stage:)`` with the root step of the wave's worst bend against
    /// the level's bend limit (``rootStep(worstBend:limit:)``), the number of matched checkpoints and the play's stage.
    public static func recipe(play: BackwardsAuroraPlay) -> AmbientLoopRecipe {
        var matched: Int = 0
        for flag in play.matched where flag { matched += 1 }
        return recipe(rootStep: rootStep(worstBend: play.wave.worstBend, limit: play.level.bendLimit),
                      matched: matched, stage: play.stage)
    }
}
