// MicroscopicAuroraSoundRecipe — feature 486 (R02-G19-06) T-R02G1906-004 (FR-R02G1906-004, 006; SC-R02G1906-003,
// 004; clarifications Q3, Q4). The optional sound of Microscopic Aurora: the audition of the panel's selected well and
// the ambient loop, both pure, so equal inputs sound equal.
//
// The selected well's strength step is n = 3 × (s − 1) for its strength s (1 … 4), so n is 0, 3, 6 or 9: a stronger
// well sounds higher, a minor third per strength (`step(strength:)` clamps s to 1 … 4, so it only guards strengths
// outside the kernel's range). Its tone is 220 Hz × 2^(n / 12) (`tone(strength:)`): A3 (220 Hz) for strength 1, up to
// nine semitones above (369.994 Hz) for strength 4. The audition (`MicroscopicAuroraAudition.of(_:placeable:)`) is a
// pure function of n, the well's sense and whether it can be placed (its site a level site no other well holds, which
// the presenter decides): a well that can be placed sounds its tone and a second partial at the tone × 3/2 (the fifth,
// clockwise) or × 4/3 (the fourth, counterclockwise), each at gain 0.04, a clean interval; one that cannot be placed
// sounds its tone and a second partial 3 Hz above it, each at gain 0.04, so it beats audibly three times a second —
// never silence, and whatever its sense. It lasts ``MicroscopicAuroraAudition/duration`` (0.6 s) with a linear decay to
// silence, played once per change of the panel's selection (slot, site, strength or sense), a new one replacing the
// last; never for drag previews.
//
// The ambient loop (`MicroscopicAuroraSoundRecipe.recipe(play:)`) is an `AmbientLoopRecipe`, a pure function of the
// actions left against the level's action budget, the stencil cells lit, the cells the coverage needs and the stage.
// The root step is 0 for more than three quarters of the budget left, 1 for more than half, 2 for more than a quarter
// and 3 otherwise (`rootStep(actionsLeft:budget:)`, decided in integers: 4·left > 3·budget, 2·left > budget, 4·left >
// budget, exactly as Apsides Workshop, feature 476), and the root is 110 Hz × (1, 9/8, 5/4, 4/3)[step] (110, 123.75,
// 137.5 and 146.67 Hz), so the key rises as the actions drain. The lit quarters are ⌊4 × l / N⌋ clamped to 0 … 4
// (`litQuarters(_:)`), with l the stencil cells the swim report lights (`play.report.litStencil.count`) and N the cells
// the coverage needs (`MicroscopicAuroraDish.neededCells(stencil:required:)` of the stencil's size and the level's
// required coverage). Each lit quarter adds a partial, the q-th at the root × (5/4, 3/2, 2, 5/2)[q − 1], every partial
// at the base amplitude, so the chord opens as the stencil lights; with less than a quarter lit the root sounds alone.
// A won play adds the octave (the root × 2) at the base amplitude as its own partial and swells twice per loop (so
// every (step, quarters, stage) triple stays distinct among playing, won and failed although the won octave coincides
// with the third quarter's partial); at most 1 + 4 + 1 = 6 partials sound, within the limit. A failed play halves
// every amplitude and the loop gain (the synthesiser normalises the summed partials to the loop gain, so the gain is
// what makes it quieter). Every other stage (loading, tutorial, paused, result) sounds as playing.
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
public struct MicroscopicAuroraPartial: Sendable, Equatable {
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

/// The audition of the panel's selected well: its strength's tone with a fifth (clockwise) or a fourth
/// (counterclockwise) when the well can be placed, or with a partial 3 Hz above when it cannot, decaying linearly to
/// silence over ``duration`` (presentation only).
public struct MicroscopicAuroraAudition: Sendable, Equatable {
    /// The audition's length, in seconds, with a linear decay to silence.
    public static let duration = 0.6
    /// The tone of strength step 0 (strength 1), in hertz (A3).
    public static let baseHertz = 220.0
    /// The semitones per strength above 1 (a minor third).
    public static let semitonesPerStrength = 3
    /// The gain of each partial.
    public static let toneGain = 0.04
    /// The ratio of the second partial of a placeable clockwise well to its tone: the fifth.
    public static let fifthRatio = 1.5
    /// The ratio of the second partial of a placeable counterclockwise well to its tone: the fourth.
    public static let fourthRatio = 4.0 / 3.0
    /// The upward offset of the second partial of a well that cannot be placed, in hertz (the beat rate).
    public static let beatHertz = 3.0

    /// The partials, in order: the strength's tone, then its interval partner or its beating partner.
    public let partials: [MicroscopicAuroraPartial]

    /// An audition of `partials`.
    public init(partials: [MicroscopicAuroraPartial]) {
        self.partials = partials
    }

    /// The strength step of `strength`: 3 × (s − 1) with s clamped to `MicroscopicAuroraWell.strengths` (1 … 4), so
    /// 0, 3, 6 or 9.
    public static func step(strength: Int) -> Int {
        let range: ClosedRange<Int> = MicroscopicAuroraWell.strengths
        let clamped: Int = min(max(strength, range.lowerBound), range.upperBound)
        return semitonesPerStrength * (clamped - range.lowerBound)
    }

    /// The tone of `strength`, in hertz: 220 × 2^(n / 12) with n = ``step(strength:)``.
    public static func tone(strength: Int) -> Double {
        baseHertz * pow(2, Double(step(strength: strength)) / 12)
    }

    /// The ratio of the second partial of a placeable well turning by `sense` to its tone: ``fifthRatio`` clockwise,
    /// ``fourthRatio`` counterclockwise.
    public static func intervalRatio(sense: MicroscopicAuroraSense) -> Double {
        sense == .clockwise ? fifthRatio : fourthRatio
    }

    /// The audition of `well`: its tone (``tone(strength:)``) and, when it can be placed (`placeable`), the tone ×
    /// ``intervalRatio(sense:)``; when it cannot, a partial ``beatHertz`` above the tone; each at ``toneGain``. A pure
    /// function of (``step(strength:)``, the sense, `placeable`); the well's cell does not change it.
    public static func of(_ well: MicroscopicAuroraWell, placeable: Bool) -> MicroscopicAuroraAudition {
        let hertz: Double = tone(strength: well.strength)
        let own: MicroscopicAuroraPartial = MicroscopicAuroraPartial(frequency: hertz, gain: toneGain)
        let second: Double = placeable ? hertz * intervalRatio(sense: well.sense) : hertz + beatHertz
        let partner: MicroscopicAuroraPartial = MicroscopicAuroraPartial(frequency: second, gain: toneGain)
        return MicroscopicAuroraAudition(partials: [own, partner])
    }
}

/// The ambient loop recipe of Microscopic Aurora (presentation only; the presenter builds it when a level opens, when a
/// placement, removal, undo, redo or the play changes the lit quarters, the root step or the stage, and when the Sound
/// toggle turns on — never per frame).
public enum MicroscopicAuroraSoundRecipe {
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
    /// The most lit-quarter partials that sound (one per quarter of the needed stencil cells lit).
    public static let maxQuarterPartials = 4

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the q-th lit-quarter partial, q = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let quarterFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                               Fraction(numerator: 3, denominator: 2),
                                               Fraction(numerator: 2, denominator: 1),
                                               Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the q-th lit-quarter partial, q = 1 … 4: 5/4, 3/2, 2 and 5/2.
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

    /// The lit quarters of `lit` stencil cells against `needed` cells: ⌊4 × lit / needed⌋ clamped to 0 … 4 (0 when
    /// nothing is needed; a negative count counts as 0).
    public static func quarters(lit: Int, needed: Int) -> Int {
        guard needed > 0 else { return 0 }
        return quarterPartials(quarters: 4 * max(lit, 0) / needed)
    }

    /// The stencil cells the coverage of `play`'s level needs: `MicroscopicAuroraDish.neededCells(stencil:required:)`
    /// of the stencil's size and the required coverage.
    public static func neededCells(_ play: MicroscopicAuroraPlay) -> Int {
        MicroscopicAuroraDish.neededCells(stencil: play.level.stencil.count, required: play.level.coverage)
    }

    /// The lit quarters of `play`: ``quarters(lit:needed:)`` of the stencil cells its swim report lights
    /// (`play.report.litStencil.count`) and the cells the coverage needs (``neededCells(_:)``),
    /// min(4, ⌊4 × lit / needed⌋).
    public static func litQuarters(_ play: MicroscopicAuroraPlay) -> Int {
        quarters(lit: play.report.litStencil.count, needed: neededCells(play))
    }

    /// The exact frequencies, in hertz, of the partials of the recipe for `rootStep`, `quarters` and `stage`, in
    /// order: the root, one per lit-quarter partial, and the octave when won.
    static func fractions(rootStep: Int, quarters: Int, stage: MicroscopicAuroraStage) -> [Fraction] {
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
    /// root (110 Hz × ``stepRatios``[step]), one per lit-quarter partial (the root × ``quarterRatios``[q − 1]), and
    /// the octave (the root × 2) when won.
    public static func frequencies(rootStep: Int, quarters: Int, stage: MicroscopicAuroraStage) -> [Double] {
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
    public static func loopSeconds(rootStep: Int, quarters: Int, stage: MicroscopicAuroraStage) -> Int {
        longestWholeSeconds(fractions(rootStep: rootStep, quarters: quarters, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for root step `rootStep` with `quarters` lit quarters in `stage`: the root and a partial per lit
    /// quarter up to four (``frequencies(rootStep:quarters:stage:)``), the octave as its own partial when won, over
    /// ``loopSeconds(rootStep:quarters:stage:)`` with whole cycles; every partial at ``baseAmplitude`` and the gain
    /// ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(rootStep: Int, quarters: Int, stage: MicroscopicAuroraStage) -> AmbientLoopRecipe {
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
    /// level's action budget (``rootStep(actionsLeft:budget:)``), the quarters of the needed stencil cells lit
    /// (``litQuarters(_:)``) and the play's stage.
    public static func recipe(play: MicroscopicAuroraPlay) -> AmbientLoopRecipe {
        recipe(rootStep: rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
               quarters: litQuarters(play), stage: play.stage)
    }
}
