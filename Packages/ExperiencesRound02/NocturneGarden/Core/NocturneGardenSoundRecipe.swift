// NocturneGardenSoundRecipe — feature 386 (R02-G09-06) T-R02G0906-004 (FR-R02G0906-006; SC-R02G0906-004;
// clarification Q4). The optional ambient sound of Nocturne Garden as an `AmbientLoopRecipe`, a pure function of the
// planted blooms, the sun and the stage, so equal gardens sound equal. The root is 110 Hz × (1, 9/8, 5/4, 4/3)[sun − 1]
// (the sun clamped to 1 … 4: 110, 123.75, 137.5 and 146.67 Hz), so the garden's key follows the sun; each planted bloom
// adds its partial at the root × (5/4, 3/2, 2, 5/2)[k − 1], up to four, every partial at the base amplitude, so the
// chord opens as the bed fills; on an empty bed the root sounds alone. A won play adds the octave (the root × 2) at the
// base amplitude as its own partial; at most 1 + 4 + 1 = 6 partials sound, within the limit. The won octave coincides
// with the third bloom partial (ratio 2), so a won chord of k blooms has the same partials as the playing chord of
// k + 1; a won loop therefore also swells twice per loop instead of once (as in Faceted Forge, feature 376), which
// keeps the recipe of every (blooms, sun, stage) triple distinct among playing, won and failed. A failed play halves
// every amplitude and the loop gain (the synthesiser normalises the summed partials to the loop gain, so the gain is
// what makes it quieter). Every other stage (loading, tutorial, paused, result) sounds as playing.
//
// The loop length is the longest the shared player accepts (`AmbientLoopRecipe.secondsRange`, 4 … 16 s) at which
// every partial of this recipe has a whole number of cycles. Each frequency is an exact fraction n / d of hertz
// (110 × the sun's ratio × the partial's ratio, in integers), so a length of L seconds gives n × L / d cycles, whole
// exactly when d divides n × L; the length is found by trying 16, 15, … 4 s in integer arithmetic and taking the first
// that fits every partial. The denominators reduce to 1, 2, 4, 8 or 16 for suns 1 … 3 (so 16 s fits) and to 3 for
// sun 4 (the 4/3 root: 15 s), so every recipe has a length: sun 1 gives 1,760 root cycles in 16 s, sun 2 1,980, sun 3
// 2,200 and sun 4 2,200 in 15 s. Bounds: at most 6 partials (limit 6), amplitudes ≤ 0.6 (limit 1), gain ≤ 0.2 (limit
// 0.3), 15 or 16 s (limit 4 … 16), swell 1 or 2 cycles, so every recipe is valid.
import VisualCoreAudioDSP

/// The ambient loop recipe of Nocturne Garden (presentation only; the presenter builds it when a level opens, when a
/// move, undo or redo changes the bloom count, the sun or the stage, and when the Sound toggle turns on — never per
/// frame).
public enum NocturneGardenSoundRecipe {
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

    /// The root frequency at sun 1, in hertz (A2).
    public static let rootHertz = 110
    /// The amplitude of the root, of every bloom partial and of the won octave.
    public static let baseAmplitude = 0.6
    /// The loop gain in every stage but `failed`.
    public static let baseGain = 0.2
    /// The swell cycles per loop in every stage but `won`.
    public static let baseSwellCycles = 1
    /// The swell cycles per loop when won.
    public static let wonSwellCycles = 2
    /// The sun elevations the recipe distinguishes (1 high … 4 low); others are clamped into it.
    public static let suns: ClosedRange<Int> = 1...4
    /// The most bloom partials that sound (one per planted bloom).
    public static let maxBloomPartials = 4

    /// The exact ratio of the root to ``rootHertz`` for sun 1 … 4: 1, 9/8, 5/4 and 4/3.
    static let sunFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                           Fraction(numerator: 9, denominator: 8),
                                           Fraction(numerator: 5, denominator: 4),
                                           Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the partial of the k-th planted bloom, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let bloomFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                             Fraction(numerator: 3, denominator: 2),
                                             Fraction(numerator: 2, denominator: 1),
                                             Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for sun 1 … 4: 1, 9/8, 5/4 and 4/3.
    public static var sunRatios: [Double] { sunFractions.map(\.value) }
    /// The ratio to the root of the partial of the k-th planted bloom, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    public static var bloomRatios: [Double] { bloomFractions.map(\.value) }

    /// `sun` clamped to ``suns``.
    public static func clampedSun(_ sun: Int) -> Int { min(max(sun, suns.lowerBound), suns.upperBound) }

    /// The number of bloom partials: `blooms` clamped to 0 … ``maxBloomPartials``.
    public static func bloomPartials(blooms: Int) -> Int { min(max(blooms, 0), maxBloomPartials) }

    /// The exact frequencies, in hertz, of the partials of the recipe for `blooms`, `sun` and `stage`, in order: the
    /// root, one per bloom partial, and the octave when won.
    static func fractions(blooms: Int, sun: Int, stage: NocturneGardenStage) -> [Fraction] {
        let root: Fraction = Fraction(numerator: rootHertz, denominator: 1)
            .times(sunFractions[clampedSun(sun) - suns.lowerBound])
        var result: [Fraction] = [root]
        for index in 0..<bloomPartials(blooms: blooms) { result.append(root.times(bloomFractions[index])) }
        if stage == .won { result.append(root.times(octaveFraction)) }
        return result
    }

    /// The frequencies, in hertz, of the partials of the recipe for `blooms`, `sun` and `stage`, in order: the root
    /// (110 Hz × ``sunRatios``[sun − 1]), one per bloom partial (the root × ``bloomRatios``[k − 1]), and the octave
    /// (the root × 2) when won.
    public static func frequencies(blooms: Int, sun: Int, stage: NocturneGardenStage) -> [Double] {
        fractions(blooms: blooms, sun: sun, stage: stage).map(\.value)
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

    /// The loop length of the recipe for `blooms`, `sun` and `stage`: the longest the shared player accepts (16 s at
    /// most) at which every partial has a whole number of cycles — 16 s for sun 1 … 3 and 15 s for sun 4.
    public static func loopSeconds(blooms: Int, sun: Int, stage: NocturneGardenStage) -> Int {
        longestWholeSeconds(fractions(blooms: blooms, sun: sun, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for `blooms` planted blooms at sun elevation `sun` in `stage`: the root and a partial per planted
    /// bloom up to four (``frequencies(blooms:sun:stage:)``), the octave as its own partial when won, over
    /// ``loopSeconds(blooms:sun:stage:)`` with whole cycles; every partial at ``baseAmplitude`` and the gain
    /// ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(blooms: Int, sun: Int, stage: NocturneGardenStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let exact: [Fraction] = fractions(blooms: blooms, sun: sun, stage: stage)
        let seconds: Int = longestWholeSeconds(exact) ?? AmbientLoopRecipe.secondsRange.upperBound
        var partials: [AmbientLoopPartial] = []
        for fraction in exact {
            partials.append(AmbientLoopPartial(cyclesPerLoop: fraction.cycles(seconds: seconds), amplitude: amplitude))
        }
        let swell: Int = stage == .won ? wonSwellCycles : baseSwellCycles
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: swell, gain: baseGain * scale)
    }
}
