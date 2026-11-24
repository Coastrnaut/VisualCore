// AcousticConstellatorSoundRecipe — feature 426 (R02-G13-06) T-R02G1306-004 (FR-R02G1306-006; SC-R02G1306-004;
// clarification Q4). The optional sound of Acoustic Constellator: the audition of an inspected link and the ambient
// loop, both pure, so equal inputs sound equal.
//
// A star's tone is 220 Hz × 2^(rate / 12): its natural rate 0 … 11 as semitones above A3 (rate 0 at exactly 220 Hz,
// rate 11 at 220 × 2^(11/12) ≈ 415.30 Hz). The audition (`AcousticConstellatorAudition.of(_:link:tick:)`) is a pure
// function of the link's two stars' rates and their phase gap g (0 … 6, the unsigned clock gap of their phases) at the
// given tick of the snapshot's listen report: two partials, the tone of star `a` and the tone of star `b` detuned upward
// by g × 1.5 Hz, each at gain 0.04, so a wide gap beats audibly (up to 9 Hz) and a gap of 0 is a clean chord. It lasts
// ``AcousticConstellatorAudition/duration`` (0.6 s) with a linear decay to silence, played once per inspection, a new
// one replacing the last. A link naming a star the snapshot does not have gives no partials (silence); a tick outside
// the report is clamped to it, as the snapshot's `phases(at:)` does.
//
// The ambient loop (`AcousticConstellatorSoundRecipe.recipe(play:)`) is an `AmbientLoopRecipe`, a pure function of the
// actions left against the level's action budget, the lit quarters of the coherence gauge and the stage. The root step
// is 0 for more than three quarters of the budget left, 1 for more than half, 2 for more than a quarter and 3
// otherwise (`rootStep(actionsLeft:budget:)`, decided in integers: 4·left > 3·budget, 2·left > budget, 4·left >
// budget), and the root is 110 Hz × (1, 9/8, 5/4, 4/3)[step] (110, 123.75, 137.5 and 146.67 Hz), so the key rises as
// the actions drain. The lit quarters are the coherence bars lit (0 … 12) at the last tick of the play's current listen
// report, divided by 3 and rounded down (0 … 4; `litQuarters(_:)`); each lit quarter adds a partial, the k-th at the
// root × (5/4, 3/2, 2, 5/2)[k − 1], every partial at the base amplitude, so the chord opens as the stars cohere; with
// none lit the root sounds alone. A won play adds the octave (the root × 2) at the base amplitude as its own partial
// and swells twice per loop (as Harmonic Bridges, feature 416, so every (step, quarters, stage) triple stays distinct
// among playing, won and failed although the won octave coincides with the third quarter's partial); at most
// 1 + 4 + 1 = 6 partials sound, within the limit. A failed play halves every amplitude and the loop gain (the
// synthesiser normalises the summed partials to the loop gain, so the gain is what makes it quieter). Every other stage
// (loading, tutorial, paused, result) sounds as playing.
//
// The loop length is the longest the shared player accepts (`AmbientLoopRecipe.secondsRange`, 4 … 16 s) at which every
// partial of this recipe has a whole number of cycles. Each frequency is an exact fraction n / d of hertz (110 × the
// step's ratio × the partial's ratio, in integers), so a length of L seconds gives n × L / d cycles, whole exactly when
// d divides n × L; the length is found by trying 16, 15, … 4 s in integer arithmetic and taking the first that fits
// every partial: 16 s for steps 0 … 2 and 15 s for step 3 (the 4/3 root). Bounds: at most 6 partials (limit 6),
// amplitudes ≤ 0.6 (limit 1), gain ≤ 0.2 (limit 0.3), 15 or 16 s (limit 4 … 16), swell 1 or 2 cycles, so every recipe
// is valid. Integers decide the step, the quarters and the length; the Doubles are the recipe's amplitudes and gain
// only.
import Foundation
import VisualCoreAudioDSP

/// One sine partial of an audition: a frequency in hertz and a gain.
public struct AcousticConstellatorPartial: Sendable, Equatable {
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

/// The audition of an inspected link: the tones of its two stars, the second detuned by their phase gap, decaying
/// linearly to silence over ``duration`` (presentation only).
public struct AcousticConstellatorAudition: Sendable, Equatable {
    /// The audition's length, in seconds, with a linear decay to silence.
    public static let duration = 0.6
    /// The tone of a star of rate 0, in hertz (A3).
    public static let baseHertz = 220.0
    /// The gain of each of the two tones.
    public static let toneGain = 0.04
    /// The upward detune of the second tone per step of phase gap, in hertz.
    public static let detunePerGap = 1.5

    /// The partials, in order: the tone of the link's star `a`, then the detuned tone of its star `b`; empty for
    /// silence.
    public let partials: [AcousticConstellatorPartial]

    /// An audition of `partials`.
    public init(partials: [AcousticConstellatorPartial]) {
        self.partials = partials
    }

    /// The tone of a star of natural rate `rate`, in hertz: 220 × 2^(rate / 12).
    public static func tone(rate: Int) -> Double {
        baseHertz * pow(2, Double(rate) / 12)
    }

    /// The audition of `link` at `tick` of `snapshot`: the tone of star `a` (``tone(rate:)``) and the tone of star `b`
    /// raised by g × ``detunePerGap`` hertz, with g the unsigned phase gap of the two stars at `tick` (0 … 6; the tick
    /// clamped to the report as `phases(at:)` does), each at ``toneGain``; no partials when the link names a star the
    /// snapshot does not have.
    public static func of(_ snapshot: AcousticConstellatorSceneSnapshot, link: AcousticConstellatorLink,
                          tick: Int) -> AcousticConstellatorAudition {
        let stars: [AcousticConstellatorStar] = snapshot.stars
        guard link.a >= 0, link.a < stars.count, link.b >= 0, link.b < stars.count else {
            return AcousticConstellatorAudition(partials: [])
        }
        let now: [Int] = snapshot.phases(at: tick)
        var gap: Int = 0
        if link.a < now.count, link.b < now.count { gap = abs(AcousticConstellatorClock.gap(now[link.a], now[link.b])) }
        let first: AcousticConstellatorPartial = AcousticConstellatorPartial(frequency: tone(rate: stars[link.a].rate),
                                                                             gain: toneGain)
        let second: AcousticConstellatorPartial = AcousticConstellatorPartial(
            frequency: tone(rate: stars[link.b].rate) + Double(gap) * detunePerGap, gain: toneGain)
        return AcousticConstellatorAudition(partials: [first, second])
    }
}

/// The ambient loop recipe of Acoustic Constellator (presentation only; the presenter builds it when a level opens,
/// when an action, undo or redo changes the lit quarters, the root step or the stage, and when the Sound toggle turns
/// on — never per frame).
public enum AcousticConstellatorSoundRecipe {
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
    /// The amplitude of the root, of every lit-quarter partial and of the won octave.
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
    /// The most lit-quarter partials that sound (one per lit quarter of the 12-bar coherence gauge).
    public static let maxQuarterPartials = 4
    /// The coherence bars per quarter of the gauge.
    public static let barsPerQuarter = 3

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the k-th lit-quarter partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let quarterFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                               Fraction(numerator: 3, denominator: 2),
                                               Fraction(numerator: 2, denominator: 1),
                                               Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the k-th lit-quarter partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
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

    /// The number of lit-quarter partials: `quarters` clamped to 0 … ``maxQuarterPartials``.
    public static func quarterPartials(quarters: Int) -> Int { min(max(quarters, 0), maxQuarterPartials) }

    /// The lit quarters of `bars` coherence bars: ⌊bars / 3⌋ clamped to 0 … 4.
    public static func quarters(bars: Int) -> Int { quarterPartials(quarters: max(bars, 0) / barsPerQuarter) }

    /// The lit quarters of the coherence gauge of `play`: ``quarters(bars:)`` of the coherence bars lit at the last
    /// tick of its current listen report (the scene snapshot's `coherenceBars(at:)`).
    public static func litQuarters(_ play: AcousticConstellatorPlay) -> Int {
        let snapshot: AcousticConstellatorSceneSnapshot = AcousticConstellatorSceneSnapshot(play: play, levelNumber: 1,
                                                                                           time: 0)
        return quarters(bars: snapshot.coherenceBars(at: snapshot.ticks - 1))
    }

    /// The exact frequencies, in hertz, of the partials of the recipe for `rootStep`, `quarters` and `stage`, in
    /// order: the root, one per lit-quarter partial, and the octave when won.
    static func fractions(rootStep: Int, quarters: Int, stage: AcousticConstellatorStage) -> [Fraction] {
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
    /// root (110 Hz × ``stepRatios``[step]), one per lit-quarter partial (the root × ``quarterRatios``[k − 1]), and
    /// the octave (the root × 2) when won.
    public static func frequencies(rootStep: Int, quarters: Int, stage: AcousticConstellatorStage) -> [Double] {
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
    public static func loopSeconds(rootStep: Int, quarters: Int, stage: AcousticConstellatorStage) -> Int {
        longestWholeSeconds(fractions(rootStep: rootStep, quarters: quarters, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for root step `rootStep` with `quarters` lit quarters in `stage`: the root and a partial per lit
    /// quarter up to four (``frequencies(rootStep:quarters:stage:)``), the octave as its own partial when won, over
    /// ``loopSeconds(rootStep:quarters:stage:)`` with whole cycles; every partial at ``baseAmplitude`` and the gain
    /// ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(rootStep: Int, quarters: Int, stage: AcousticConstellatorStage) -> AmbientLoopRecipe {
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
    /// level's action budget (``rootStep(actionsLeft:budget:)``), the lit quarters of its coherence gauge at the last
    /// tick of its current listen report (``litQuarters(_:)``) and the play's stage.
    public static func recipe(play: AcousticConstellatorPlay) -> AmbientLoopRecipe {
        recipe(rootStep: rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
               quarters: litQuarters(play), stage: play.stage)
    }
}
