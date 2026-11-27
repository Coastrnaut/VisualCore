// BinaryGardensSoundRecipe — feature 506 (R02-G21-06) T-R02G2106-004 (FR-R02G2106-006; SC-R02G2106-004;
// clarification Q4; research R6, R7). The optional sound of Binary Gardens: the audition of the panel's selected star
// and the ambient loop, both pure, so equal inputs sound equal.
//
// The selected star's step is n = 2 × (7 − its ring index), the index clamped to 0 … 7 (`step(ring:)`, the most rings
// a level lists is 8, so n is 14, 12 … 0): an outer ring sounds lower, a whole tone per ring. Its tone is
// 220 Hz × 2^(n / 12) (`tone(ring:)`): 493.883 Hz on the innermost ring down to A3 (220 Hz) on the eighth. The audition
// (`BinaryGardensAudition.of(ring:canChange:)`) is a pure function of n and whether the star can change now
// (`canChange(star:play:)`: the play is playing and the puzzle's legal moves from the current arrangement and actions
// spent include a ring, phase or luminosity move of that star): a star that can change sounds its tone and a second
// partial at the tone × 3/2 (a clean fifth), each at gain 0.04; one that cannot sounds its tone and a second partial
// 3 Hz above it, each at gain 0.04, so it beats audibly three times a second — never silence. It lasts
// ``BinaryGardensAudition/duration`` (0.6 s) with a linear decay to silence; the presenter plays it once per change of
// the panel's selected star and once after an accepted ring change of it, a new one replacing the last; never for
// previews.
//
// The ambient loop (`BinaryGardensSoundRecipe.recipe(play:)`) is an `AmbientLoopRecipe`, a pure function of the worlds
// keeping their light, the worlds, the stars' luminosities, the actions left against the level's action budget and the
// stage. The root step is 0 for more than three quarters of the budget left, 1 for more than half, 2 for more than a
// quarter and 3 otherwise (`rootStep(actionsLeft:budget:)`, decided in integers: 4·left > 3·budget, 2·left > budget,
// 4·left > budget, as features 486 and 496), and the root is 110 Hz × (1, 9/8, 5/4, 4/3)[step], so the key rises as
// the actions drain. The light quarters are ⌊4 × w / n⌋ clamped to 0 … 4 (`lightQuarters(_:)`), with w the worlds
// keeping their light — those whose predicted report of the current arrangement (`play.report.worlds[i]`) has a longest
// lethal run of at most the level's lethal tolerance, a comfortable window of at least the world's required window and
// its bloom `inside` (`BinaryGardensFeedbackPlan.keepsLight` / `worldsKeepingLight`, the one rule, research R1) —
// and n the level's worlds. Each light quarter adds a partial, the q-th at the root × (5/4, 3/2, 2, 5/2)[q − 1], every
// partial at the base amplitude, so the chord opens as the worlds settle; with fewer than a quarter keeping their light
// the root sounds alone (with the brightness partial when there is one). The brightness b = (i₁ + i₂) / (2 × (m − 1))
// (`brightness(_:)`, the stars' luminosity indices i₁ and i₂ of the level's m luminosity levels; 0 when m = 1) adds a
// partial at the root × 3 with the base amplitude × b when b > 0. A won play adds the octave (the root × 2) at the base
// amplitude and swells twice per loop. A failed play halves every amplitude and the loop gain. Every other stage
// (loading, tutorial, paused, result) sounds as playing.
//
// Partials at the same exact frequency are merged into one, their amplitudes summed and capped at 1: the won octave
// coincides with the third light quarter's partial (the root × 2), and a won play always has every world keeping its
// light (a won run has no failure, so no world freezes, scorches, is unstable, wilts or bleaches), so without merging a
// won play with brightness would need 1 + 4 + 1 + 1 = 7 partials, above the shared player's limit of 6. Merged, at
// most 1 + 4 + 1 = 6 partials sound; the won swell and the merged amplitude keep won recipes distinct from playing ones.
//
// The loop length is the longest the shared player accepts (`AmbientLoopRecipe.secondsRange`, 4 … 16 s) at which every
// partial of this recipe has a whole number of cycles: each frequency is an exact fraction n / d of hertz, so a length
// of L seconds gives n × L / d cycles, whole exactly when d divides n × L; trying 16, 15, … 4 s in integer arithmetic
// gives 16 s for steps 0 … 2 and 15 s for step 3 (the 4/3 root). Bounds: at most 6 partials (limit 6), amplitudes ≤ 1
// (limit 1), gain ≤ 0.2 (limit 0.3), 15 or 16 s (limit 4 … 16), swell 1 or 2 cycles, so every recipe is valid.
// Integers decide the step, the quarters and the length; the Doubles are the recipe's amplitudes and gain only.
// Modelled on `MushroomWeatherSoundRecipe` (feature 496).
import Foundation
import VisualCoreAudioDSP

/// One sine partial of an audition: a frequency in hertz and a gain.
public struct BinaryGardensPartial: Sendable, Equatable {
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

/// The audition of the panel's selected star: its tone with a fifth when the star can change now, or with a partial
/// 3 Hz above when it cannot, decaying linearly to silence over ``duration`` (presentation only).
public struct BinaryGardensAudition: Sendable, Equatable {
    /// The audition's length, in seconds, with a linear decay to silence.
    public static let duration = 0.6
    /// The tone of step 0 (the outermost ring index 7), in hertz (A3).
    public static let baseHertz = 220.0
    /// The semitones per ring index (a whole tone).
    public static let semitonesPerRing = 2
    /// The highest ring index (a level lists at most `BinaryGardensLevel.ringCounts.upperBound` rings).
    public static let maxRingIndex: Int = BinaryGardensLevel.ringCounts.upperBound - 1
    /// The gain of each partial.
    public static let toneGain = 0.04
    /// The ratio of the second partial of a star that can change to its tone: the fifth.
    public static let fifthRatio = 1.5
    /// The upward offset of the second partial of a star that cannot change, in hertz (the beat rate).
    public static let beatHertz = 3.0

    /// The partials, in order: the star's tone, then its fifth or its beating partner.
    public let partials: [BinaryGardensPartial]

    /// An audition of `partials`.
    public init(partials: [BinaryGardensPartial]) {
        self.partials = partials
    }

    /// The step of ring index `ring`: 2 × (7 − the index clamped to 0 … ``maxRingIndex``), so 14, 12 … 0.
    public static func step(ring: Int) -> Int {
        let clamped: Int = min(max(ring, 0), maxRingIndex)
        return semitonesPerRing * (maxRingIndex - clamped)
    }

    /// The tone of ring index `ring`, in hertz: 220 × 2^(n / 12) with n = ``step(ring:)``.
    public static func tone(ring: Int) -> Double {
        baseHertz * pow(2, Double(step(ring: ring)) / 12)
    }

    /// Whether star `star` of `play` can change now: the play is playing and the puzzle's legal moves from its
    /// arrangement and actions spent (`BinaryGardensPuzzle(level:).moves(in:)`) include a ring, phase or luminosity
    /// move of that star (a tilt moves both stars and does not count). False for a star outside 0 … 1.
    public static func canChange(star: Int, play: BinaryGardensPlay) -> Bool {
        guard play.stage == .playing, (0...1).contains(star) else { return false }
        let puzzle: BinaryGardensPuzzle = BinaryGardensPuzzle(level: play.level)
        let position: BinaryGardensPuzzle.Position = BinaryGardensPuzzle.Position(arrangement: play.arrangement,
                                                                                   actionsSpent: play.actionsSpent)
        for move in puzzle.moves(in: position) {
            switch move {
            case .ring(let mover, _), .phase(let mover, _), .luminosity(let mover, _):
                if mover == star { return true }
            case .tilt, .run:
                continue
            }
        }
        return false
    }

    /// The audition of ring index `ring`: its tone (``tone(ring:)``) and, when the star can change (`canChange`), the
    /// tone × ``fifthRatio``; when it cannot, a partial ``beatHertz`` above the tone; each at ``toneGain``. A pure
    /// function of (``step(ring:)``, `canChange`).
    public static func of(ring: Int, canChange: Bool) -> BinaryGardensAudition {
        let hertz: Double = tone(ring: ring)
        let own: BinaryGardensPartial = BinaryGardensPartial(frequency: hertz, gain: toneGain)
        let second: Double = canChange ? hertz * fifthRatio : hertz + beatHertz
        let partner: BinaryGardensPartial = BinaryGardensPartial(frequency: second, gain: toneGain)
        return BinaryGardensAudition(partials: [own, partner])
    }
}

/// The ambient loop recipe of Binary Gardens (presentation only; the presenter builds it when a level opens, when an
/// action, undo, redo or the run changes the light quarters, the root step, the brightness partial or the stage, and
/// when the Sound toggle turns on — never per frame).
public enum BinaryGardensSoundRecipe {
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
    /// The amplitude of the root, of every light-quarter partial and of the won octave; the brightness partial's at
    /// brightness 1.
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
    /// The most light-quarter partials that sound (one per quarter of the worlds keeping their light).
    public static let maxQuarterPartials = 4

    /// The exact ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    static let stepFractions: [Fraction] = [Fraction(numerator: 1, denominator: 1),
                                            Fraction(numerator: 9, denominator: 8),
                                            Fraction(numerator: 5, denominator: 4),
                                            Fraction(numerator: 4, denominator: 3)]
    /// The exact ratio to the root of the q-th light-quarter partial, q = 1 … 4: 5/4, 3/2, 2 and 5/2.
    static let quarterFractions: [Fraction] = [Fraction(numerator: 5, denominator: 4),
                                               Fraction(numerator: 3, denominator: 2),
                                               Fraction(numerator: 2, denominator: 1),
                                               Fraction(numerator: 5, denominator: 2)]
    /// The exact ratio of the brightness partial to the root.
    static let brightnessFraction: Fraction = Fraction(numerator: 3, denominator: 1)
    /// The exact ratio of the won octave to the root.
    static let octaveFraction: Fraction = Fraction(numerator: 2, denominator: 1)

    /// The ratio of the root to ``rootHertz`` for root step 0 … 3: 1, 9/8, 5/4 and 4/3.
    public static var stepRatios: [Double] { stepFractions.map(\.value) }
    /// The ratio to the root of the q-th light-quarter partial, q = 1 … 4: 5/4, 3/2, 2 and 5/2.
    public static var quarterRatios: [Double] { quarterFractions.map(\.value) }
    /// The ratio of the brightness partial to the root: 3.
    public static var brightnessRatio: Double { brightnessFraction.value }

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
    static func clampedStep(_ step: Int) -> Int { min(max(step, rootSteps.lowerBound), rootSteps.upperBound) }

    /// The number of light-quarter partials: `quarters` clamped to 0 … ``maxQuarterPartials``.
    static func quarterPartials(quarters: Int) -> Int { min(max(quarters, 0), maxQuarterPartials) }

    /// `brightness` clamped to 0 … 1 (a non-finite value counts as 0).
    static func clampedBrightness(_ brightness: Double) -> Double {
        brightness.isFinite ? min(max(brightness, 0), 1) : 0
    }

    /// The light quarters of `keeping` worlds keeping their light out of `worlds`: ⌊4 × keeping / worlds⌋ clamped to
    /// 0 … 4 (0 when there are no worlds; a negative count counts as 0).
    static func quarters(keeping: Int, worlds: Int) -> Int {
        guard worlds > 0 else { return 0 }
        return quarterPartials(quarters: 4 * max(keeping, 0) / worlds)
    }

    /// The light quarters of `play`: ⌊4 × w / n⌋ clamped to 0 … 4, w the worlds keeping their light
    /// (`BinaryGardensFeedbackPlan.worldsKeepingLight(_:)`) and n the level's worlds.
    public static func lightQuarters(_ play: BinaryGardensPlay) -> Int {
        quarters(keeping: BinaryGardensFeedbackPlan.worldsKeepingLight(play), worlds: play.level.worlds.count)
    }

    /// The stars' brightness of `play`: (i₁ + i₂) / (2 × (m − 1)) for the stars' luminosity indices i₁, i₂ (each
    /// clamped to 0 … m − 1) of the level's m luminosity levels; 0 when m ≤ 1. 0 … 1.
    public static func brightness(_ play: BinaryGardensPlay) -> Double {
        let levels: Int = play.level.luminosityLevels.count
        guard levels > 1 else { return 0 }
        var sum: Int = 0
        for index in play.arrangement.luminosities { sum += min(max(index, 0), levels - 1) }
        return clampedBrightness(Double(sum) / Double(2 * (levels - 1)))
    }

    /// The voices of the recipe for `rootStep`, `quarters`, `brightness` and `stage`, in order: the root, one per
    /// light-quarter partial, the brightness partial when the brightness is above 0, and the octave when won; every
    /// amplitude ``baseAmplitude`` (the brightness partial's × the brightness), halved when failed; voices at the same
    /// exact frequency merged into the first of them, their amplitudes summed and capped at 1.
    static func voices(rootStep: Int, quarters: Int, brightness: Double, stage: BinaryGardensStage) -> [Voice] {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let root: Fraction = Fraction(numerator: rootHertz, denominator: 1)
            .times(stepFractions[clampedStep(rootStep) - rootSteps.lowerBound])
        var wanted: [Voice] = [Voice(frequency: root, amplitude: amplitude)]
        for index in 0..<quarterPartials(quarters: quarters) {
            wanted.append(Voice(frequency: root.times(quarterFractions[index]), amplitude: amplitude))
        }
        let share: Double = clampedBrightness(brightness)
        if share > 0 {
            wanted.append(Voice(frequency: root.times(brightnessFraction), amplitude: amplitude * share))
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

    /// The frequencies, in hertz, of the recipe for `rootStep`, `quarters`, `brightness` and `stage`, in order (see
    /// ``voices(rootStep:quarters:brightness:stage:)``).
    static func frequencies(rootStep: Int, quarters: Int, brightness: Double, stage: BinaryGardensStage) -> [Double] {
        voices(rootStep: rootStep, quarters: quarters, brightness: brightness, stage: stage).map(\.frequency.value)
    }

    /// The loop length for `rootStep`, `quarters`, `brightness` and `stage`: the longest the shared player accepts at
    /// which every partial has a whole number of cycles.
    static func loopSeconds(rootStep: Int, quarters: Int, brightness: Double, stage: BinaryGardensStage) -> Int {
        longestWholeSeconds(voices(rootStep: rootStep, quarters: quarters, brightness: brightness, stage: stage))
            ?? AmbientLoopRecipe.secondsRange.upperBound
    }

    /// The loop length of `play`'s recipe, in seconds: the longest the shared player accepts (16 s at most) at which
    /// every partial has a whole number of cycles — 16 s for root steps 0 … 2 and 15 s for step 3.
    public static func loopSeconds(play: BinaryGardensPlay) -> Int {
        loopSeconds(rootStep: rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
                    quarters: lightQuarters(play), brightness: brightness(play), stage: play.stage)
    }

    /// The recipe for root step `rootStep` with `quarters` light quarters, `brightness` and `stage`: the partials of
    /// ``voices(rootStep:quarters:brightness:stage:)`` over the longest whole-cycle loop length; every partial at
    /// ``baseAmplitude`` (the brightness partial × the brightness, the won octave merged into the root × 2 partial) and
    /// the gain ``baseGain``, both halved when failed; one swell (``wonSwellCycles`` when won). Always valid.
    static func recipe(rootStep: Int, quarters: Int, brightness: Double,
                       stage: BinaryGardensStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let exact: [Voice] = voices(rootStep: rootStep, quarters: quarters, brightness: brightness, stage: stage)
        let seconds: Int = longestWholeSeconds(exact) ?? AmbientLoopRecipe.secondsRange.upperBound
        var partials: [AmbientLoopPartial] = []
        for voice in exact {
            partials.append(AmbientLoopPartial(cyclesPerLoop: voice.frequency.cycles(seconds: seconds),
                                               amplitude: voice.amplitude))
        }
        let swell: Int = stage == .won ? wonSwellCycles : baseSwellCycles
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: swell, gain: baseGain * scale)
    }

    /// The recipe of `play`: the root step of the actions left against the level's action budget
    /// (``rootStep(actionsLeft:budget:)``), the light quarters (``lightQuarters(_:)``), the stars' brightness
    /// (``brightness(_:)``) and the play's stage (see the header). Always a valid recipe of the shared player.
    public static func recipe(play: BinaryGardensPlay) -> AmbientLoopRecipe {
        recipe(rootStep: rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
               quarters: lightQuarters(play), brightness: brightness(play), stage: play.stage)
    }
}
