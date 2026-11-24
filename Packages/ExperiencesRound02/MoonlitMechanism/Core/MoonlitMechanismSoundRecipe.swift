// MoonlitMechanismSoundRecipe — feature 436 (R02-G14-06) T-R02G1406-004 (FR-R02G1406-006; SC-R02G1406-004;
// clarification Q4). The optional sound of Moonlit Mechanism: the audition of a chosen gear and the ambient loop, both
// pure, so equal inputs sound equal.
//
// A gear's tone is 220 Hz × 2^((T − 12) / 12) for its tooth count T: a 12-tooth gear sounds A3 (220 Hz), fewer teeth
// lower, more teeth higher, one semitone per tooth, clamped to two octaves either side (55 … 880 Hz; the kernel's 6 … 20
// teeth give 155.56 … 349.23 Hz, so the clamp only guards counts outside the kernel's range). The audition
// (`MoonlitMechanismAudition.of(_:gear:)`) of a chosen gear g ≥ 1 is a pure function of its tooth count, its parent's
// tooth count and the mesh error e of gear g with that parent: two partials, the tone of gear g and the tone of its
// parent detuned upward by e × 1.5 Hz, each at gain 0.04, so a misaligned mesh beats audibly and an aligned one (e = 0)
// is a clean chord. The error is `play.report.errors[g]`: the kernel's run report lists one error per gear, indexed by
// the child gear of each mesh (entry g is the mesh of gear g with its parent, entry 0 — the driver, which has no parent —
// is always 0); it is the cyclic distance of the mesh from alignment, 0 … ⌊gcd / 2⌋ teeth (at most 10 for 20-tooth
// gears, so at most 15 Hz of detune). The driver (gear 0) sounds its tone alone (one partial). A gear the level lacks
// (or a negative index) gives no partials (silence). It lasts ``MoonlitMechanismAudition/duration`` (0.6 s) with a
// linear decay to silence, played once per choice, a new one replacing the last.
//
// The ambient loop (`MoonlitMechanismSoundRecipe.recipe(play:)`) is an `AmbientLoopRecipe`, a pure function of the
// actions left against the level's action budget, the covered quarters of the required target cells in the run report
// and the stage. The root step is 0 for more than three quarters of the budget left, 1 for more than half, 2 for more
// than a quarter and 3 otherwise (`rootStep(actionsLeft:budget:)`, decided in integers: 4·left > 3·budget, 2·left >
// budget, 4·left > budget), and the root is 110 Hz × (1, 9/8, 5/4, 4/3)[step] (110, 123.75, 137.5 and 146.67 Hz), so
// the key rises as the actions drain. The covered quarters are ⌊4 × c / t⌋ (0 … 4; `coveredQuarters(_:)`), with c the
// target cells covered and t the target cells, both summed over the required key frames of the play's run report (the
// truth metric of the current set-up); a level whose required targets are empty counts 0. Each covered quarter adds a
// partial, the k-th at the root × (5/4, 3/2, 2, 5/2)[k − 1], every partial at the base amplitude, so the chord opens as
// the shadows match; with none covered the root sounds alone. A won play adds the octave (the root × 2) at the base
// amplitude as its own partial and swells twice per loop (as Acoustic Constellator, feature 426, so every (step,
// quarters, stage) triple stays distinct among playing, won and failed although the won octave coincides with the
// third quarter's partial); at most 1 + 4 + 1 = 6 partials sound, within the limit. A failed play halves every
// amplitude and the loop gain (the synthesiser normalises the summed partials to the loop gain, so the gain is what
// makes it quieter). Every other stage (loading, tutorial, paused, result) sounds as playing.
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
public struct MoonlitMechanismPartial: Sendable, Equatable {
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

/// The audition of a chosen gear: its tone and its parent's, the second detuned by their mesh error, decaying linearly
/// to silence over ``duration`` (presentation only).
public struct MoonlitMechanismAudition: Sendable, Equatable {
    /// The audition's length, in seconds, with a linear decay to silence.
    public static let duration = 0.6
    /// The tone of a 12-tooth gear, in hertz (A3).
    public static let baseHertz = 220.0
    /// The tooth count that sounds ``baseHertz``.
    public static let baseTeeth = 12
    /// The lowest tone, in hertz: two octaves below ``baseHertz``.
    public static let lowestHertz = 55.0
    /// The highest tone, in hertz: two octaves above ``baseHertz``.
    public static let highestHertz = 880.0
    /// The gain of each tone.
    public static let toneGain = 0.04
    /// The upward detune of the parent's tone per tooth of mesh error, in hertz.
    public static let detunePerError = 1.5

    /// The partials, in order: the tone of the chosen gear, then the detuned tone of its parent (none for the driver);
    /// empty for silence.
    public let partials: [MoonlitMechanismPartial]

    /// An audition of `partials`.
    public init(partials: [MoonlitMechanismPartial]) {
        self.partials = partials
    }

    /// The tone of a gear of `teeth` teeth, in hertz: 220 × 2^((teeth − 12) / 12), clamped to ``lowestHertz`` …
    /// ``highestHertz`` (two octaves either side).
    public static func tone(teeth: Int) -> Double {
        let raw: Double = baseHertz * pow(2, Double(teeth - baseTeeth) / 12)
        return min(max(raw, lowestHertz), highestHertz)
    }

    /// The audition of gear `gear` of `play`: for the driver (gear 0) its tone (``tone(teeth:)``) alone; for a gear
    /// g ≥ 1 its tone and the tone of its parent (`level.gears[g].parent`) raised by e × ``detunePerError`` hertz, with
    /// e = `play.report.errors[g]` the mesh error of gear g with its parent (the report's errors are indexed by the
    /// child gear of each mesh), each at ``toneGain``; no partials for a gear the level lacks.
    public static func of(_ play: MoonlitMechanismPlay, gear: Int) -> MoonlitMechanismAudition {
        let gears: [MoonlitMechanismGear] = play.level.gears
        guard gear >= 0, gear < gears.count else { return MoonlitMechanismAudition(partials: []) }
        let own: MoonlitMechanismPartial = MoonlitMechanismPartial(frequency: tone(teeth: gears[gear].teeth),
                                                                   gain: toneGain)
        guard let parent = gears[gear].parent, parent >= 0, parent < gears.count else {
            return MoonlitMechanismAudition(partials: [own])
        }
        let errors: [Int] = play.report.errors
        let error: Int = gear < errors.count ? max(errors[gear], 0) : 0
        let second: MoonlitMechanismPartial = MoonlitMechanismPartial(
            frequency: tone(teeth: gears[parent].teeth) + Double(error) * detunePerError, gain: toneGain)
        return MoonlitMechanismAudition(partials: [own, second])
    }
}

/// The ambient loop recipe of Moonlit Mechanism (presentation only; the presenter builds it when a level opens, when an
/// action, undo or redo changes the covered quarters, the root step or the stage, and when the Sound toggle turns on —
/// never per frame).
public enum MoonlitMechanismSoundRecipe {
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
    /// The amplitude of the root, of every covered-quarter partial and of the won octave.
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
    /// The most covered-quarter partials that sound (one per covered quarter of the required target cells).
    public static let maxQuarterPartials = 4

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the k-th covered-quarter partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let quarterFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                               Fraction(numerator: 3, denominator: 2),
                                               Fraction(numerator: 2, denominator: 1),
                                               Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the k-th covered-quarter partial, k = 1 … 4: 5/4, 3/2, 2 and 5/2.
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

    /// The number of covered-quarter partials: `quarters` clamped to 0 … ``maxQuarterPartials``.
    public static func quarterPartials(quarters: Int) -> Int { min(max(quarters, 0), maxQuarterPartials) }

    /// The covered quarters of `covered` of `targets` target cells: ⌊4 × covered / targets⌋ clamped to 0 … 4 (0 when
    /// there are no target cells).
    public static func quarters(covered: Int, targets: Int) -> Int {
        guard targets > 0 else { return 0 }
        return quarterPartials(quarters: 4 * max(covered, 0) / targets)
    }

    /// The covered quarters of `play`: ``quarters(covered:targets:)`` of the target cells covered and the target cells
    /// (covered plus missing), both summed over the required key frames of its run report.
    public static func coveredQuarters(_ play: MoonlitMechanismPlay) -> Int {
        let frames: [MoonlitMechanismKeyFrame] = play.level.keyFrames
        let reports: [MoonlitMechanismFrameReport] = play.report.frames
        var covered: Int = 0
        var targets: Int = 0
        for index in frames.indices where frames[index].required && index < reports.count {
            covered += reports[index].covered
            targets += reports[index].covered + reports[index].missing
        }
        return quarters(covered: covered, targets: targets)
    }

    /// The exact frequencies, in hertz, of the partials of the recipe for `rootStep`, `quarters` and `stage`, in
    /// order: the root, one per covered-quarter partial, and the octave when won.
    static func fractions(rootStep: Int, quarters: Int, stage: MoonlitMechanismStage) -> [Fraction] {
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
    /// root (110 Hz × ``stepRatios``[step]), one per covered-quarter partial (the root × ``quarterRatios``[k − 1]),
    /// and the octave (the root × 2) when won.
    public static func frequencies(rootStep: Int, quarters: Int, stage: MoonlitMechanismStage) -> [Double] {
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
    public static func loopSeconds(rootStep: Int, quarters: Int, stage: MoonlitMechanismStage) -> Int {
        longestWholeSeconds(fractions(rootStep: rootStep, quarters: quarters, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for root step `rootStep` with `quarters` covered quarters in `stage`: the root and a partial per
    /// covered quarter up to four (``frequencies(rootStep:quarters:stage:)``), the octave as its own partial when won,
    /// over ``loopSeconds(rootStep:quarters:stage:)`` with whole cycles; every partial at ``baseAmplitude`` and the
    /// gain ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(rootStep: Int, quarters: Int, stage: MoonlitMechanismStage) -> AmbientLoopRecipe {
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
    /// level's action budget (``rootStep(actionsLeft:budget:)``), the covered quarters of the required target cells in
    /// its run report (``coveredQuarters(_:)``) and the play's stage.
    public static func recipe(play: MoonlitMechanismPlay) -> AmbientLoopRecipe {
        recipe(rootStep: rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
               quarters: coveredQuarters(play), stage: play.stage)
    }
}
