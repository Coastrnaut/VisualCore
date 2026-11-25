// StarlitCartoucheSoundRecipe — feature 456 (R02-G16-06) T-R02G1606-004 (FR-R02G1606-006; SC-R02G1606-004;
// clarification Q4). The optional sound of Starlit Cartouche: the audition of a chosen destination and the ambient
// loop, both pure, so equal inputs sound equal.
//
// Star j's tone is 220 Hz × 2^(j / 12): star 0 sounds A3 (220 Hz), each further star one semitone higher, at most
// eleven above (a level has at most twelve stars, 0 … 11, 220 … 415.305 Hz); `tone(star:)` clamps j to 0 … 11, so it
// only guards indices outside the kernel's range. The audition (`StarlitCartoucheAudition.of(_:star:)`) of a chosen
// destination is a pure function of its index and whether a corridor joins it to the ship's star
// (`StarlitCartoucheChart.corridor(play.level, joining: play.star, j)` is not nil): a reachable star sounds its tone
// and its fifth (the tone × 3/2), each at gain 0.04, a clean chord; an unreachable one sounds its tone and a second
// partial 3 Hz above it, each at gain 0.04, so it beats audibly three times a second. A star the level lacks (a
// negative index or one at or past the star count) and the ship's own star (which cannot be chosen as a destination:
// the adapter refuses it) give no partials (silence). It lasts ``StarlitCartoucheAudition/duration`` (0.6 s) with a
// linear decay to silence, played once per choice, a new one replacing the last.
//
// The ambient loop (`StarlitCartoucheSoundRecipe.recipe(play:)`) is an `AmbientLoopRecipe`, a pure function of the
// actions left against the level's action budget, the symbol strokes drawn and the stage. The root step is 0 for more
// than three quarters of the budget left, 1 for more than half, 2 for more than a quarter and 3 otherwise
// (`rootStep(actionsLeft:budget:)`, decided in integers: 4·left > 3·budget, 2·left > budget, 4·left > budget, exactly
// as Voxel Origami, feature 446), and the root is 110 Hz × (1, 9/8, 5/4, 4/3)[step] (110, 123.75, 137.5 and
// 146.67 Hz), so the key rises as the actions drain. The drawn quarters are ⌊4 × d / n⌋ clamped to 0 … 4
// (`drawnQuarters(_:)`), with d the symbol strokes drawn (the play's drawn corridors that are strokes of the symbol)
// and n the symbol's stroke count. Each drawn quarter adds a partial, the k-th at the root × (5/4, 3/2, 2,
// 5/2)[k − 1], every partial at the base amplitude, so the chord opens as the cartouche is drawn; with less than a
// quarter drawn the root sounds alone. A won play adds the octave (the root × 2) at the base amplitude as its own
// partial and swells twice per loop (so every (step, quarters, stage) triple stays distinct among playing, won and
// failed although the won octave coincides with the third quarter's partial); at most 1 + 4 + 1 = 6 partials sound,
// within the limit. A failed play halves every amplitude and the loop gain (the synthesiser normalises the summed
// partials to the loop gain, so the gain is what makes it quieter). Every other stage (loading, tutorial, paused,
// result) sounds as playing.
//
// The loop length is the longest the shared player accepts (`AmbientLoopRecipe.secondsRange`, 4 … 16 s) at which every
// partial of this recipe has a whole number of cycles: each frequency is an exact fraction n / d of hertz (110 × the
// step's ratio × the partial's ratio, in integers), so a length of L seconds gives n × L / d cycles, whole exactly when
// d divides n × L; trying 16, 15, … 4 s in integer arithmetic gives 16 s for steps 0 … 2 and 15 s for step 3 (the 4/3
// root). Bounds: at most 6 partials (limit 6), amplitudes ≤ 0.6 (limit 1), gain ≤ 0.2 (limit 0.3), 15 or 16 s (limit
// 4 … 16), swell 1 or 2 cycles, so every recipe is valid. Integers decide the step, the quarters and the length; the
// Doubles are the recipe's amplitudes and gain only.
import Foundation
import VisualCoreAudioDSP

/// One sine partial of an audition: a frequency in hertz and a gain.
public struct StarlitCartouchePartial: Sendable, Equatable {
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

/// The audition of a chosen destination: its tone with its fifth when a corridor joins it to the ship's star, or with
/// a partial 3 Hz above when none does, decaying linearly to silence over ``duration`` (presentation only).
public struct StarlitCartoucheAudition: Sendable, Equatable {
    /// The audition's length, in seconds, with a linear decay to silence.
    public static let duration = 0.6
    /// The tone of star 0, in hertz (A3).
    public static let baseHertz = 220.0
    /// The stars that have their own tone: 0 … 11 (a level has at most twelve stars); others are clamped into it.
    public static let toneStars: ClosedRange<Int> = 0...11
    /// The gain of each partial.
    public static let toneGain = 0.04
    /// The ratio of the second partial of a reachable star to its tone: the fifth.
    public static let fifthRatio = 1.5
    /// The upward offset of the second partial of an unreachable star, in hertz (the beat rate).
    public static let beatHertz = 3.0

    /// The partials, in order: the star's tone, then its fifth or its beating partner; empty for silence.
    public let partials: [StarlitCartouchePartial]

    /// An audition of `partials`.
    public init(partials: [StarlitCartouchePartial]) {
        self.partials = partials
    }

    /// The tone of star `star`, in hertz: 220 × 2^(j / 12), with j clamped to ``toneStars`` (0 … 11).
    public static func tone(star: Int) -> Double {
        let index: Int = min(max(star, toneStars.lowerBound), toneStars.upperBound)
        return baseHertz * pow(2, Double(index) / 12)
    }

    /// Whether a corridor joins star `star` to the ship's star of `play`
    /// (`StarlitCartoucheChart.corridor(play.level, joining: play.star, star)` is not nil).
    public static func isReachable(_ play: StarlitCartouchePlay, star: Int) -> Bool {
        StarlitCartoucheChart.corridor(play.level, joining: play.star, star) != nil
    }

    /// The audition of destination `star` of `play`: when a corridor joins it to the ship's star
    /// (``isReachable(_:star:)``) its tone (``tone(star:)``) and its fifth (× ``fifthRatio``); when none does its tone
    /// and a partial ``beatHertz`` above; each at ``toneGain``. No partials for a star the level lacks (below 0, or
    /// at or past the star count) or the ship's own star.
    public static func of(_ play: StarlitCartouchePlay, star: Int) -> StarlitCartoucheAudition {
        guard star >= 0, star < play.level.stars.count, star != play.star else {
            return StarlitCartoucheAudition(partials: [])
        }
        let hertz: Double = tone(star: star)
        let own: StarlitCartouchePartial = StarlitCartouchePartial(frequency: hertz, gain: toneGain)
        let second: Double = isReachable(play, star: star) ? hertz * fifthRatio : hertz + beatHertz
        return StarlitCartoucheAudition(partials: [own, StarlitCartouchePartial(frequency: second, gain: toneGain)])
    }
}

/// The ambient loop recipe of Starlit Cartouche (presentation only; the presenter builds it when a level opens, when an
/// action, undo or redo changes the drawn quarters, the root step or the stage, and when the Sound toggle turns on —
/// never per frame).
public enum StarlitCartoucheSoundRecipe {
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
    /// The amplitude of the root, of every drawn-quarter partial and of the won octave.
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
    /// The most drawn-quarter partials that sound (one per quarter of the symbol drawn).
    public static let maxQuarterPartials = 4

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the k-th drawn-quarter partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let quarterFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                               Fraction(numerator: 3, denominator: 2),
                                               Fraction(numerator: 2, denominator: 1),
                                               Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the k-th drawn-quarter partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    public static var quarterRatios: [Double] { quarterFractions.map(\.value) }

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

    /// The number of drawn-quarter partials: `quarters` clamped to 0 … ``maxQuarterPartials``.
    public static func quarterPartials(quarters: Int) -> Int { min(max(quarters, 0), maxQuarterPartials) }

    /// The drawn quarters of `drawn` of `strokes` symbol strokes: ⌊4 × drawn / strokes⌋ clamped to 0 … 4 (0 when the
    /// symbol has no strokes; a negative count counts as 0).
    public static func quarters(drawn: Int, strokes: Int) -> Int {
        guard strokes > 0 else { return 0 }
        return quarterPartials(quarters: 4 * max(drawn, 0) / strokes)
    }

    /// The symbol strokes `play` has drawn: its drawn corridors that are strokes of the level's symbol.
    public static func symbolStrokesDrawn(_ play: StarlitCartouchePlay) -> Int {
        var count: Int = 0
        for stroke in Set(play.level.symbol) where play.drawn.contains(stroke) { count += 1 }
        return count
    }

    /// The drawn quarters of `play`: ``quarters(drawn:strokes:)`` of the symbol strokes drawn
    /// (``symbolStrokesDrawn(_:)``) and the symbol's stroke count, min(4, ⌊4 × drawn / strokes⌋).
    public static func drawnQuarters(_ play: StarlitCartouchePlay) -> Int {
        quarters(drawn: symbolStrokesDrawn(play), strokes: Set(play.level.symbol).count)
    }

    /// The exact frequencies, in hertz, of the partials of the recipe for `rootStep`, `quarters` and `stage`, in
    /// order: the root, one per drawn-quarter partial, and the octave when won.
    static func fractions(rootStep: Int, quarters: Int, stage: StarlitCartoucheStage) -> [Fraction] {
        let root: Fraction = Fraction(numerator: rootHertz, denominator: 1)
            .times(stepFractions[clampedStep(rootStep) - rootSteps.lowerBound])
        var result: [Fraction] = [root]
        for index in 0..<quarterPartials(quarters: quarters) {
            result.append(root.times(quarterFractions[index]))
        }
        if stage == .won { result.append(root.times(octaveFraction)) }
        return result
    }

    /// The frequencies, in hertz, of the partials of the recipe for `rootStep`, `quarters` and `stage`, in order: the
    /// root (110 Hz × ``stepRatios``[step]), one per drawn-quarter partial (the root × ``quarterRatios``[k − 1]),
    /// and the octave (the root × 2) when won.
    public static func frequencies(rootStep: Int, quarters: Int, stage: StarlitCartoucheStage) -> [Double] {
        fractions(rootStep: rootStep, quarters: quarters, stage: stage).map(\.value)
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

    /// The loop length of the recipe for `rootStep`, `quarters` and `stage`: the longest the shared player accepts
    /// (16 s at most) at which every partial has a whole number of cycles — 16 s for steps 0 … 2 and 15 s for step 3.
    public static func loopSeconds(rootStep: Int, quarters: Int, stage: StarlitCartoucheStage) -> Int {
        longestWholeSeconds(fractions(rootStep: rootStep, quarters: quarters, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for root step `rootStep` with `quarters` drawn quarters in `stage`: the root and a partial per
    /// drawn quarter up to four (``frequencies(rootStep:quarters:stage:)``), the octave as its own partial when won,
    /// over ``loopSeconds(rootStep:quarters:stage:)`` with whole cycles; every partial at ``baseAmplitude`` and the
    /// gain ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(rootStep: Int, quarters: Int, stage: StarlitCartoucheStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let exact: [Fraction] = fractions(rootStep: rootStep, quarters: quarters, stage: stage)
        let seconds: Int = longestWholeSeconds(exact) ?? AmbientLoopRecipe.secondsRange.upperBound
        var partials: [AmbientLoopPartial] = []
        for fraction in exact {
            partials.append(AmbientLoopPartial(cyclesPerLoop: fraction.cycles(seconds: seconds), amplitude: amplitude))
        }
        let swell: Int = stage == .won ? wonSwellCycles : baseSwellCycles
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: swell, gain: baseGain * scale)
    }

    /// The recipe of `play`: ``recipe(rootStep:quarters:stage:)`` with the root step of the actions left against the
    /// level's action budget (``rootStep(actionsLeft:budget:)``), the quarters of the symbol drawn
    /// (``drawnQuarters(_:)``) and the play's stage.
    public static func recipe(play: StarlitCartouchePlay) -> AmbientLoopRecipe {
        recipe(rootStep: rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
               quarters: drawnQuarters(play), stage: play.stage)
    }
}
