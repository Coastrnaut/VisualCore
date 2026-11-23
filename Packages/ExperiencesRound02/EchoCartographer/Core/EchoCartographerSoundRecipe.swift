// EchoCartographerSoundRecipe — feature 406 (R02-G11-06) T-R02G1106-004 (FR-R02G1106-006; SC-R02G1106-004;
// clarification Q4). The optional ambient sound of Echo Cartographer as an `AmbientLoopRecipe`, a pure function of the
// energy left against the level's energy budget, the beacons located and the stage, so equal plays sound equal. The
// root step is 0 for more than three quarters of the budget left, 1 for more than half, 2 for more than a quarter and 3
// otherwise (`rootStep(energy:budget:)`, decided in integers: 4·energy > 3·budget, 2·energy > budget, 4·energy >
// budget), and the root is 110 Hz × (1, 9/8, 5/4, 4/3)[step] (110, 123.75, 137.5 and 146.67 Hz), so the key rises as
// the energy drains; each located beacon adds its partial at the root × (5/4, 3/2, 2, 5/2)[k − 1], up to four, every
// partial at the base amplitude, so the chord opens as beacons are located; with none located the root sounds alone. A
// won play adds the octave (the root × 2) at the base amplitude as its own partial; at most 1 + 4 + 1 = 6 partials
// sound, within the limit. The won octave coincides with the third beacon partial (ratio 2), so a won chord of k
// located has the same partials as the playing chord of k + 1; a won loop therefore also swells twice per loop instead
// of once (as in Backwards Aurora, feature 396), which keeps the recipe of every (step, located, stage) triple distinct
// among playing, won and failed. A failed play halves every amplitude and the loop gain (the synthesiser normalises the
// summed partials to the loop gain, so the gain is what makes it quieter). Every other stage (loading, tutorial,
// paused, result) sounds as playing.
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

/// The ambient loop recipe of Echo Cartographer (presentation only; the presenter builds it when a level opens, when an
/// action, undo or redo changes the located count, the root step or the stage, and when the Sound toggle turns on —
/// never per frame).
public enum EchoCartographerSoundRecipe {
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
    /// The amplitude of the root, of every beacon partial and of the won octave.
    public static let baseAmplitude = 0.6
    /// The loop gain in every stage but `failed`.
    public static let baseGain = 0.2
    /// The swell cycles per loop in every stage but `won`.
    public static let baseSwellCycles = 1
    /// The swell cycles per loop when won.
    public static let wonSwellCycles = 2
    /// The root steps the recipe distinguishes (0: more than three quarters of the energy left … 3: a quarter or
    /// less); others are clamped into it.
    public static let rootSteps: ClosedRange<Int> = 0...3
    /// The most beacon partials that sound (one per located beacon).
    public static let maxBeaconPartials = 4

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the partial of the k-th located beacon, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let beaconFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                              Fraction(numerator: 3, denominator: 2),
                                              Fraction(numerator: 2, denominator: 1),
                                              Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the partial of the k-th located beacon, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    public static var beaconRatios: [Double] { beaconFractions.map(\.value) }

    /// The root step of `energy` left of a budget `budget` (a budget below 1 counts as 1; integer comparisons only):
    /// 0 when more than three quarters is left (4·energy > 3·budget), 1 when more than half (2·energy > budget), 2 when
    /// more than a quarter (4·energy > budget), else 3.
    public static func rootStep(energy: Int, budget: Int) -> Int {
        let whole: Int = max(budget, 1)
        if 4 * energy > 3 * whole { return 0 }
        if 2 * energy > whole { return 1 }
        if 4 * energy > whole { return 2 }
        return 3
    }

    /// `step` clamped to ``rootSteps``.
    public static func clampedStep(_ step: Int) -> Int { min(max(step, rootSteps.lowerBound), rootSteps.upperBound) }

    /// The number of beacon partials: `located` clamped to 0 … ``maxBeaconPartials``.
    public static func beaconPartials(located: Int) -> Int { min(max(located, 0), maxBeaconPartials) }

    /// The exact frequencies, in hertz, of the partials of the recipe for `rootStep`, `located` and `stage`, in order:
    /// the root, one per beacon partial, and the octave when won.
    static func fractions(rootStep: Int, located: Int, stage: EchoCartographerStage) -> [Fraction] {
        let root: Fraction = Fraction(numerator: rootHertz, denominator: 1)
            .times(stepFractions[clampedStep(rootStep) - rootSteps.lowerBound])
        var result: [Fraction] = [root]
        for index in 0..<beaconPartials(located: located) {
            result.append(root.times(beaconFractions[index]))
        }
        if stage == .won { result.append(root.times(octaveFraction)) }
        return result
    }

    /// The frequencies, in hertz, of the partials of the recipe for `rootStep`, `located` and `stage`, in order: the
    /// root (110 Hz × ``stepRatios``[step]), one per beacon partial (the root × ``beaconRatios``[k − 1]), and the
    /// octave (the root × 2) when won.
    public static func frequencies(rootStep: Int, located: Int, stage: EchoCartographerStage) -> [Double] {
        fractions(rootStep: rootStep, located: located, stage: stage).map(\.value)
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

    /// The loop length of the recipe for `rootStep`, `located` and `stage`: the longest the shared player accepts
    /// (16 s at most) at which every partial has a whole number of cycles — 16 s for steps 0 … 2 and 15 s for step 3.
    public static func loopSeconds(rootStep: Int, located: Int, stage: EchoCartographerStage) -> Int {
        longestWholeSeconds(fractions(rootStep: rootStep, located: located, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for root step `rootStep` with `located` beacons located in `stage`: the root and a partial per
    /// located beacon up to four (``frequencies(rootStep:located:stage:)``), the octave as its own partial when won,
    /// over ``loopSeconds(rootStep:located:stage:)`` with whole cycles; every partial at ``baseAmplitude`` and the
    /// gain ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(rootStep: Int, located: Int, stage: EchoCartographerStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let exact: [Fraction] = fractions(rootStep: rootStep, located: located, stage: stage)
        let seconds: Int = longestWholeSeconds(exact) ?? AmbientLoopRecipe.secondsRange.upperBound
        var partials: [AmbientLoopPartial] = []
        for fraction in exact {
            partials.append(AmbientLoopPartial(cyclesPerLoop: fraction.cycles(seconds: seconds), amplitude: amplitude))
        }
        let swell: Int = stage == .won ? wonSwellCycles : baseSwellCycles
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: swell, gain: baseGain * scale)
    }

    /// The recipe of `play`: ``recipe(rootStep:located:stage:)`` with the root step of the energy left against the
    /// level's energy budget (``rootStep(energy:budget:)``), the number of located beacons and the play's stage.
    public static func recipe(play: EchoCartographerPlay) -> AmbientLoopRecipe {
        recipe(rootStep: rootStep(energy: play.energy, budget: play.level.energy),
               located: play.located.count, stage: play.stage)
    }
}
