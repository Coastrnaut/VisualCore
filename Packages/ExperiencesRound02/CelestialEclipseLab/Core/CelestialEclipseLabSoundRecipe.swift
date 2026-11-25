// CelestialEclipseLabSoundRecipe — feature 466 (R02-G17-06) T-R02G1706-004 (FR-R02G1706-006; SC-R02G1706-004;
// clarification Q4). The optional sound of Celestial Eclipse Lab: the audition of a chosen body and the ambient loop,
// both pure, so equal inputs sound equal.
//
// Body j's tone is 220 Hz × 2^(2j / 12): body 0 sounds A3 (220 Hz), each further body a whole tone higher, at most ten
// semitones above (a level has at most six bodies, 0 … 5, 220 … 391.995 Hz); `tone(body:)` clamps j to 0 … 5, so it
// only guards indices outside the kernel's range. The audition (`CelestialEclipseLabAudition.of(_:body:)`) of a chosen
// body is a pure function of its index and whether it takes part — as the front or the back body — in an eclipse
// interval of the play's predicted timeline (`play.timeline.intervals`): an involved body sounds its tone and its fifth
// (the tone × 3/2), each at gain 0.04, a clean chord; an uninvolved one sounds its tone and a second partial 3 Hz above
// it, each at gain 0.04, so it beats audibly three times a second. A body the level lacks (a negative index or one at
// or past the body count) gives no partials (silence); a fixed body can be chosen and sounds like any other. It lasts
// ``CelestialEclipseLabAudition/duration`` (0.6 s) with a linear decay to silence, played once per body choice, a new
// one replacing the last.
//
// The ambient loop (`CelestialEclipseLabSoundRecipe.recipe(play:)`) is an `AmbientLoopRecipe`, a pure function of the
// actions left against the level's action budget, the target eclipses matched in order and the stage. The root step is
// 0 for more than three quarters of the budget left, 1 for more than half, 2 for more than a quarter and 3 otherwise
// (`rootStep(actionsLeft:budget:)`, decided in integers: 4·left > 3·budget, 2·left > budget, 4·left > budget, exactly
// as Starlit Cartouche, feature 456), and the root is 110 Hz × (1, 9/8, 5/4, 4/3)[step] (110, 123.75, 137.5 and
// 146.67 Hz), so the key rises as the actions drain. The matched quarters are ⌊4 × m / n⌋ clamped to 0 … 4
// (`matchedQuarters(_:)`), with m the target eclipses the predicted timeline matches in order (`play.timeline.matched`)
// and n the target's length. Each matched quarter adds a partial, the k-th at the root × (5/4, 3/2, 2, 5/2)[k − 1],
// every partial at the base amplitude, so the chord opens as the target order is matched; with less than a quarter
// matched the root sounds alone. A won play adds the octave (the root × 2) at the base amplitude as its own partial and
// swells twice per loop (so every (step, quarters, stage) triple stays distinct among playing, won and failed although
// the won octave coincides with the third quarter's partial); at most 1 + 4 + 1 = 6 partials sound, within the limit.
// A failed play halves every amplitude and the loop gain (the synthesiser normalises the summed partials to the loop
// gain, so the gain is what makes it quieter). Every other stage (loading, tutorial, paused, result) sounds as playing.
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
public struct CelestialEclipseLabPartial: Sendable, Equatable {
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

/// The audition of a chosen body: its tone with its fifth when it takes part in an eclipse of the predicted timeline,
/// or with a partial 3 Hz above when it takes part in none, decaying linearly to silence over ``duration``
/// (presentation only).
public struct CelestialEclipseLabAudition: Sendable, Equatable {
    /// The audition's length, in seconds, with a linear decay to silence.
    public static let duration = 0.6
    /// The tone of body 0, in hertz (A3).
    public static let baseHertz = 220.0
    /// The bodies that have their own tone: 0 … 5 (a level has at most six bodies); others are clamped into it.
    public static let toneBodies: ClosedRange<Int> = 0...5
    /// The semitones between the tones of neighbouring bodies (a whole tone).
    public static let semitonesPerBody = 2
    /// The gain of each partial.
    public static let toneGain = 0.04
    /// The ratio of the second partial of an involved body to its tone: the fifth.
    public static let fifthRatio = 1.5
    /// The upward offset of the second partial of an uninvolved body, in hertz (the beat rate).
    public static let beatHertz = 3.0

    /// The partials, in order: the body's tone, then its fifth or its beating partner; empty for silence.
    public let partials: [CelestialEclipseLabPartial]

    /// An audition of `partials`.
    public init(partials: [CelestialEclipseLabPartial]) {
        self.partials = partials
    }

    /// The tone of body `body`, in hertz: 220 × 2^(2j / 12), with j clamped to ``toneBodies`` (0 … 5).
    public static func tone(body: Int) -> Double {
        let index: Int = min(max(body, toneBodies.lowerBound), toneBodies.upperBound)
        return baseHertz * pow(2, Double(semitonesPerBody * index) / 12)
    }

    /// Whether body `body` takes part, as the front or the back body, in an eclipse interval of the predicted timeline
    /// of `play` (`play.timeline.intervals`).
    public static func isInvolved(_ play: CelestialEclipseLabPlay, body: Int) -> Bool {
        for interval in play.timeline.intervals where interval.front == body || interval.back == body { return true }
        return false
    }

    /// The audition of body `body` of `play`: when it takes part in an eclipse of the predicted timeline
    /// (``isInvolved(_:body:)``) its tone (``tone(body:)``) and its fifth (× ``fifthRatio``); when it takes part in
    /// none its tone and a partial ``beatHertz`` above; each at ``toneGain``. No partials for a body the level lacks
    /// (below 0, or at or past the body count).
    public static func of(_ play: CelestialEclipseLabPlay, body: Int) -> CelestialEclipseLabAudition {
        guard body >= 0, body < play.level.bodies.count else {
            return CelestialEclipseLabAudition(partials: [])
        }
        let hertz: Double = tone(body: body)
        let own: CelestialEclipseLabPartial = CelestialEclipseLabPartial(frequency: hertz, gain: toneGain)
        let second: Double = isInvolved(play, body: body) ? hertz * fifthRatio : hertz + beatHertz
        let partner: CelestialEclipseLabPartial = CelestialEclipseLabPartial(frequency: second, gain: toneGain)
        return CelestialEclipseLabAudition(partials: [own, partner])
    }
}

/// The ambient loop recipe of Celestial Eclipse Lab (presentation only; the presenter builds it when a level opens,
/// when an action, undo, redo or the run changes the matched quarters, the root step or the stage, and when the Sound
/// toggle turns on — never per frame).
public enum CelestialEclipseLabSoundRecipe {
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
    /// The amplitude of the root, of every matched-quarter partial and of the won octave.
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
    /// The most matched-quarter partials that sound (one per quarter of the target matched).
    public static let maxQuarterPartials = 4

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the k-th matched-quarter partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let quarterFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                               Fraction(numerator: 3, denominator: 2),
                                               Fraction(numerator: 2, denominator: 1),
                                               Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the k-th matched-quarter partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
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

    /// The number of matched-quarter partials: `quarters` clamped to 0 … ``maxQuarterPartials``.
    public static func quarterPartials(quarters: Int) -> Int { min(max(quarters, 0), maxQuarterPartials) }

    /// The matched quarters of `matched` of `targets` target eclipses: ⌊4 × matched / targets⌋ clamped to 0 … 4 (0
    /// when the target is empty; a negative count counts as 0).
    public static func quarters(matched: Int, targets: Int) -> Int {
        guard targets > 0 else { return 0 }
        return quarterPartials(quarters: 4 * max(matched, 0) / targets)
    }

    /// The matched quarters of `play`: ``quarters(matched:targets:)`` of the target eclipses its predicted timeline
    /// matches in order (`play.timeline.matched`) and the target's length, min(4, ⌊4 × matched / targets⌋).
    public static func matchedQuarters(_ play: CelestialEclipseLabPlay) -> Int {
        quarters(matched: play.timeline.matched, targets: play.level.target.count)
    }

    /// The exact frequencies, in hertz, of the partials of the recipe for `rootStep`, `quarters` and `stage`, in
    /// order: the root, one per matched-quarter partial, and the octave when won.
    static func fractions(rootStep: Int, quarters: Int, stage: CelestialEclipseLabStage) -> [Fraction] {
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
    /// root (110 Hz × ``stepRatios``[step]), one per matched-quarter partial (the root × ``quarterRatios``[k − 1]),
    /// and the octave (the root × 2) when won.
    public static func frequencies(rootStep: Int, quarters: Int, stage: CelestialEclipseLabStage) -> [Double] {
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
    public static func loopSeconds(rootStep: Int, quarters: Int, stage: CelestialEclipseLabStage) -> Int {
        longestWholeSeconds(fractions(rootStep: rootStep, quarters: quarters, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for root step `rootStep` with `quarters` matched quarters in `stage`: the root and a partial per
    /// matched quarter up to four (``frequencies(rootStep:quarters:stage:)``), the octave as its own partial when won,
    /// over ``loopSeconds(rootStep:quarters:stage:)`` with whole cycles; every partial at ``baseAmplitude`` and the
    /// gain ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(rootStep: Int, quarters: Int, stage: CelestialEclipseLabStage) -> AmbientLoopRecipe {
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
    /// level's action budget (``rootStep(actionsLeft:budget:)``), the quarters of the target matched in order
    /// (``matchedQuarters(_:)``) and the play's stage.
    public static func recipe(play: CelestialEclipseLabPlay) -> AmbientLoopRecipe {
        recipe(rootStep: rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
               quarters: matchedQuarters(play), stage: play.stage)
    }
}
