// MushroomWeatherSoundRecipe — feature 496 (R02-G20-06) T-R02G2006-004 (FR-R02G2006-004, 006; SC-R02G2006-003,
// 004; clarifications Q3, Q4). The optional sound of Mushroom Weather: the audition of the panel's selected site and
// the ambient loop, both pure, so equal inputs sound equal.
//
// The selected site's step is n = 2 × its index (`step(site:)`, the index clamped to 0 … 7, the most sites a level
// lists, so n is 0, 2, 4 … 14): a later site sounds higher, a whole tone per site. Its tone is 220 Hz × 2^(n / 12)
// (`tone(site:)`): A3 (220 Hz) for the first site, up to fourteen semitones above (493.883 Hz) for the eighth. The
// audition (`MushroomWeatherAudition.of(site:placeable:)`) is a pure function of n and whether the site can take a pod
// (no pod holds it and a slot is free, which the presenter decides): a site that can take a pod sounds its tone and a
// second partial at the tone × 3/2 (a clean fifth), each at gain 0.04; one that cannot sounds its tone and a second
// partial 3 Hz above it, each at gain 0.04, so it beats audibly three times a second — never silence. It lasts
// ``MushroomWeatherAudition/duration`` (0.6 s) with a linear decay to silence, played once per change of the panel's
// selection (slot or site), a new one replacing the last; never for drag previews.
//
// The ambient loop (`MushroomWeatherSoundRecipe.recipe(play:)`) is an `AmbientLoopRecipe`, a pure function of the
// actions left against the level's action budget, the colonies staying in band, the colonies, the moonlight and the
// stage. The root step is 0 for more than three quarters of the budget left, 1 for more than half, 2 for more than a
// quarter and 3 otherwise (`rootStep(actionsLeft:budget:)`, decided in integers: 4·left > 3·budget, 2·left > budget,
// 4·left > budget, exactly as Microscopic Aurora, feature 486), and the root is 110 Hz × (1, 9/8, 5/4, 4/3)[step]
// (110, 123.75, 137.5 and 146.67 Hz), so the key rises as the actions drain. The band quarters are ⌊4 × c / n⌋ clamped
// to 0 … 4 (`bandQuarters(_:)`), with c the colonies staying in band — those whose final in-band run of the predicted
// run of the current arrangement (`play.report.colonies[i].finalRun`, the kernel's
// `MushroomWeatherForest.report(level, arrangement:)`) reaches the level's required cycles (`play.level.required`) —
// and n the level's colonies. Each band quarter adds a partial, the q-th at the root × (5/4, 3/2, 2, 5/2)[q − 1], every
// partial at the base amplitude, so the chord opens as the colonies settle; with fewer than a quarter in band the root
// sounds alone (with the moonlight partial when the moonlight is above 0). The moonlight l (0 … 3,
// `play.arrangement.moonlight`) adds a partial at the root × 3 with the base amplitude × l / 3 when l > 0. A won play
// adds the octave (the root × 2) at the base amplitude and swells twice per loop. A failed play halves every amplitude
// and the loop gain (the synthesiser normalises the summed partials to the loop gain, so the gain is what makes it
// quieter). Every other stage (loading, tutorial, paused, result) sounds as playing.
//
// Partials at the same exact frequency are merged into one, their amplitudes summed and capped at 1: the won octave
// coincides with the third band quarter's partial (the root × 2), and a won play always has every colony in band (a won
// run has no failure, so every final run reaches the required cycles), so without merging a won play with moonlight
// would need 1 + 4 + 1 + 1 = 7 partials, above the shared player's limit of 6. Merged, the octave raises that partial
// to amplitude 1 (0.5 when failed, which a won play never is), so at most 1 + 4 + 1 = 6 partials sound; the won swell
// (2 cycles) and the merged amplitude keep won recipes distinct from playing ones.
//
// The loop length is the longest the shared player accepts (`AmbientLoopRecipe.secondsRange`, 4 … 16 s) at which every
// partial of this recipe has a whole number of cycles: each frequency is an exact fraction n / d of hertz (110 × the
// step's ratio × the partial's ratio, in integers), so a length of L seconds gives n × L / d cycles, whole exactly when
// d divides n × L; trying 16, 15, … 4 s in integer arithmetic gives 16 s for steps 0 … 2 and 15 s for step 3 (the 4/3
// root). Bounds: at most 6 partials (limit 6), amplitudes ≤ 1 (limit 1), gain ≤ 0.2 (limit 0.3), 15 or 16 s (limit
// 4 … 16), swell 1 or 2 cycles, so every recipe is valid. Integers decide the step, the quarters, the moonlight and the
// length; the Doubles are the recipe's amplitudes and gain only.
import Foundation
import VisualCoreAudioDSP

/// One sine partial of an audition: a frequency in hertz and a gain.
public struct MushroomWeatherPartial: Sendable, Equatable {
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

/// The audition of the panel's selected site: its tone with a fifth when the site can take a pod, or with a partial
/// 3 Hz above when it cannot, decaying linearly to silence over ``duration`` (presentation only).
public struct MushroomWeatherAudition: Sendable, Equatable {
    /// The audition's length, in seconds, with a linear decay to silence.
    public static let duration = 0.6
    /// The tone of site index 0, in hertz (A3).
    public static let baseHertz = 220.0
    /// The semitones per site index (a whole tone).
    public static let semitonesPerSite = 2
    /// The highest site index (a level lists at most `MushroomWeatherLevel.siteCounts.upperBound` sites).
    public static let maxSiteIndex: Int = MushroomWeatherLevel.siteCounts.upperBound - 1
    /// The gain of each partial.
    public static let toneGain = 0.04
    /// The ratio of the second partial of a site that can take a pod to its tone: the fifth.
    public static let fifthRatio = 1.5
    /// The upward offset of the second partial of a site that cannot take a pod, in hertz (the beat rate).
    public static let beatHertz = 3.0

    /// The partials, in order: the site's tone, then its fifth or its beating partner.
    public let partials: [MushroomWeatherPartial]

    /// An audition of `partials`.
    public init(partials: [MushroomWeatherPartial]) {
        self.partials = partials
    }

    /// The step of site index `site`: 2 × the index clamped to 0 … ``maxSiteIndex``, so 0, 2, 4 … 14.
    public static func step(site: Int) -> Int {
        let clamped: Int = min(max(site, 0), maxSiteIndex)
        return semitonesPerSite * clamped
    }

    /// The tone of site index `site`, in hertz: 220 × 2^(n / 12) with n = ``step(site:)``.
    public static func tone(site: Int) -> Double {
        baseHertz * pow(2, Double(step(site: site)) / 12)
    }

    /// The audition of site index `site`: its tone (``tone(site:)``) and, when it can take a pod (`placeable`), the
    /// tone × ``fifthRatio``; when it cannot, a partial ``beatHertz`` above the tone; each at ``toneGain``. A pure
    /// function of (``step(site:)``, `placeable`).
    public static func of(site: Int, placeable: Bool) -> MushroomWeatherAudition {
        let hertz: Double = tone(site: site)
        let own: MushroomWeatherPartial = MushroomWeatherPartial(frequency: hertz, gain: toneGain)
        let second: Double = placeable ? hertz * fifthRatio : hertz + beatHertz
        let partner: MushroomWeatherPartial = MushroomWeatherPartial(frequency: second, gain: toneGain)
        return MushroomWeatherAudition(partials: [own, partner])
    }
}

/// The ambient loop recipe of Mushroom Weather (presentation only; the presenter builds it when a level opens, when a
/// pod, vent or moonlight action, undo, redo or the run changes the band quarters, the root step, the moonlight or the
/// stage, and when the Sound toggle turns on — never per frame).
public enum MushroomWeatherSoundRecipe {
    /// An exact frequency ratio or frequency, `numerator / denominator` (denominator ≥ 1).
    struct Fraction: Sendable, Equatable {
        /// The numerator.
        let numerator: Int
        /// The denominator (≥ 1).
        let denominator: Int

        /// The product of this fraction and `other` (not reduced; only divisibility and equality are asked of it).
        func times(_ other: Fraction) -> Fraction {
            Fraction(numerator: numerator * other.numerator, denominator: denominator * other.denominator)
        }

        /// The value as a `Double`.
        var value: Double { Double(numerator) / Double(denominator) }

        /// Whether `seconds` × this frequency is a whole number of cycles.
        func isWhole(seconds: Int) -> Bool { (numerator * seconds) % denominator == 0 }

        /// The cycles in `seconds` seconds, rounded down (exact when ``isWhole(seconds:)``).
        func cycles(seconds: Int) -> Int { numerator * seconds / denominator }

        /// Whether this fraction and `other` are the same number (cross-multiplied in integers).
        func sameValue(as other: Fraction) -> Bool { numerator * other.denominator == other.numerator * denominator }
    }

    /// One partial of the recipe before the loop length is chosen: an exact frequency and an amplitude.
    struct Voice: Sendable, Equatable {
        /// The exact frequency, in hertz.
        var frequency: Fraction
        /// The amplitude, 0 … 1.
        var amplitude: Double
    }

    /// The root frequency at root step 0, in hertz (A2).
    public static let rootHertz = 110
    /// The amplitude of the root, of every band-quarter partial and of the won octave; the moonlight partial's at
    /// moonlight 3.
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
    /// The most band-quarter partials that sound (one per quarter of the colonies staying in band).
    public static let maxQuarterPartials = 4
    /// The moonlight levels the recipe distinguishes (`MushroomWeatherLevel.moonlightLevels`, 0 … 3); others are
    /// clamped into it.
    public static let moonlightLevels: ClosedRange<Int> = MushroomWeatherLevel.moonlightLevels

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the q-th band-quarter partial, q = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let quarterFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                               Fraction(numerator: 3, denominator: 2),
                                               Fraction(numerator: 2, denominator: 1),
                                               Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the moonlight partial to the root.
    static let moonlightFraction: Fraction = Fraction(numerator: 3, denominator: 1)
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the q-th band-quarter partial, q = 1 … 4: 5/4, 3/2, 2 and 5/2.
    public static var quarterRatios: [Double] { quarterFractions.map(\.value) }
    /// The ratio of the moonlight partial to the root: 3.
    public static var moonlightRatio: Double { moonlightFraction.value }

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

    /// `moonlight` clamped to ``moonlightLevels``.
    public static func clampedMoonlight(_ moonlight: Int) -> Int {
        min(max(moonlight, moonlightLevels.lowerBound), moonlightLevels.upperBound)
    }

    /// The number of band-quarter partials: `quarters` clamped to 0 … ``maxQuarterPartials``.
    public static func quarterPartials(quarters: Int) -> Int { min(max(quarters, 0), maxQuarterPartials) }

    /// The band quarters of `inBand` colonies staying in band out of `colonies`: ⌊4 × inBand / colonies⌋ clamped to
    /// 0 … 4 (0 when there are no colonies; a negative count counts as 0).
    public static func quarters(inBand: Int, colonies: Int) -> Int {
        guard colonies > 0 else { return 0 }
        return quarterPartials(quarters: 4 * max(inBand, 0) / colonies)
    }

    /// The colonies of `play` staying in band: those whose final in-band run of the predicted run of the current
    /// arrangement (`play.report.colonies[i].finalRun`) reaches the level's required cycles (`play.level.required`).
    public static func coloniesInBand(_ play: MushroomWeatherPlay) -> Int {
        var count: Int = 0
        for runs in play.report.colonies where runs.finalRun >= play.level.required { count += 1 }
        return count
    }

    /// The band quarters of `play`: ``quarters(inBand:colonies:)`` of the colonies staying in band
    /// (``coloniesInBand(_:)``) and the level's colonies, min(4, ⌊4 × c / n⌋).
    public static func bandQuarters(_ play: MushroomWeatherPlay) -> Int {
        quarters(inBand: coloniesInBand(play), colonies: play.level.colonies.count)
    }

    /// The voices of the recipe for `rootStep`, `quarters`, `moonlight` and `stage`, in order: the root, one per
    /// band-quarter partial, the moonlight partial when the moonlight is above 0, and the octave when won; every
    /// amplitude ``baseAmplitude`` (the moonlight's × l / 3), halved when failed; voices at the same exact frequency
    /// merged into the first of them, their amplitudes summed and capped at 1.
    static func voices(rootStep: Int, quarters: Int, moonlight: Int, stage: MushroomWeatherStage) -> [Voice] {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let root: Fraction = Fraction(numerator: rootHertz, denominator: 1)
            .times(stepFractions[clampedStep(rootStep) - rootSteps.lowerBound])
        var wanted: [Voice] = [Voice(frequency: root, amplitude: amplitude)]
        for index in 0..<quarterPartials(quarters: quarters) {
            wanted.append(Voice(frequency: root.times(quarterFractions[index]), amplitude: amplitude))
        }
        let light: Int = clampedMoonlight(moonlight)
        if light > 0 {
            let share: Double = Double(light) / Double(moonlightLevels.upperBound)
            wanted.append(Voice(frequency: root.times(moonlightFraction), amplitude: amplitude * share))
        }
        if stage == .won { wanted.append(Voice(frequency: root.times(octaveFraction), amplitude: amplitude)) }
        var merged: [Voice] = []
        for voice in wanted {
            var found: Bool = false
            for index in merged.indices where merged[index].frequency.sameValue(as: voice.frequency) {
                merged[index].amplitude = min(merged[index].amplitude + voice.amplitude, 1)
                found = true
            }
            if !found { merged.append(voice) }
        }
        return merged
    }

    /// The frequencies, in hertz, of the partials of the recipe for `rootStep`, `quarters`, `moonlight` and `stage`,
    /// in order: the root (110 Hz × ``stepRatios``[step]), one per band-quarter partial (the root ×
    /// ``quarterRatios``[q − 1]), the moonlight partial (the root × 3) when the moonlight is above 0, and the octave
    /// (the root × 2) when won and not already sounding as the third quarter's partial.
    public static func frequencies(rootStep: Int, quarters: Int, moonlight: Int,
                                   stage: MushroomWeatherStage) -> [Double] {
        var result: [Double] = []
        for voice in voices(rootStep: rootStep, quarters: quarters, moonlight: moonlight, stage: stage) {
            result.append(voice.frequency.value)
        }
        return result
    }

    /// The longest loop length in `AmbientLoopRecipe.secondsRange` at which every frequency of `voices` has a whole
    /// number of cycles; nil when none does.
    static func longestWholeSeconds(_ voices: [Voice]) -> Int? {
        let range: ClosedRange<Int> = AmbientLoopRecipe.secondsRange
        for seconds in stride(from: range.upperBound, through: range.lowerBound, by: -1) {
            var whole: Bool = true
            for voice in voices where !voice.frequency.isWhole(seconds: seconds) { whole = false }
            if whole { return seconds }
        }
        return nil
    }

    /// The loop length of the recipe for `rootStep`, `quarters`, `moonlight` and `stage`: the longest the shared player
    /// accepts (16 s at most) at which every partial has a whole number of cycles — 16 s for steps 0 … 2 and 15 s for
    /// step 3.
    public static func loopSeconds(rootStep: Int, quarters: Int, moonlight: Int, stage: MushroomWeatherStage) -> Int {
        longestWholeSeconds(voices(rootStep: rootStep, quarters: quarters, moonlight: moonlight, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The recipe for root step `rootStep` with `quarters` band quarters, moonlight `moonlight` and `stage`: the
    /// partials of ``frequencies(rootStep:quarters:moonlight:stage:)`` over
    /// ``loopSeconds(rootStep:quarters:moonlight:stage:)`` with whole cycles; every partial at ``baseAmplitude`` (the
    /// moonlight partial at ``baseAmplitude`` × moonlight / 3, the won octave merged into the root × 2 partial) and the
    /// gain ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    public static func recipe(rootStep: Int, quarters: Int, moonlight: Int,
                              stage: MushroomWeatherStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let exact: [Voice] = voices(rootStep: rootStep, quarters: quarters, moonlight: moonlight, stage: stage)
        let seconds: Int = longestWholeSeconds(exact) ?? AmbientLoopRecipe.secondsRange.upperBound
        var partials: [AmbientLoopPartial] = []
        for voice in exact {
            partials.append(AmbientLoopPartial(cyclesPerLoop: voice.frequency.cycles(seconds: seconds),
                                               amplitude: voice.amplitude))
        }
        let swell: Int = stage == .won ? wonSwellCycles : baseSwellCycles
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: swell, gain: baseGain * scale)
    }

    /// The recipe of `play`: ``recipe(rootStep:quarters:moonlight:stage:)`` with the root step of the actions left
    /// against the level's action budget (``rootStep(actionsLeft:budget:)``), the quarters of the colonies staying in
    /// band (``bandQuarters(_:)``), the arrangement's moonlight and the play's stage.
    public static func recipe(play: MushroomWeatherPlay) -> AmbientLoopRecipe {
        recipe(rootStep: rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
               quarters: bandQuarters(play), moonlight: play.arrangement.moonlight, stage: play.stage)
    }
}
