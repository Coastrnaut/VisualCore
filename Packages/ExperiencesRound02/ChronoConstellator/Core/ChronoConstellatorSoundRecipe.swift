// ChronoConstellatorSoundRecipe — feature 356 (R02-G06-06) T-R02G0606-005 (FR-R02G0606-006; SC-R02G0606-004;
// clarification Q4). The optional ambient sound of Chrono Constellator as an `AmbientLoopRecipe`, a pure function of
// which stars stand on their targets and the stage, so equal skies sound equal. A root at 110 Hz (A2) always sounds;
// each star on its target adds its partial at 110 Hz × (3/2, 5/4, 2, 5/3, 9/8)[star] — 165, 137.5, 220, 183.3 and
// 123.75 Hz — at the base amplitude, so the chord fills as the constellation forms; with no star on target the root
// sounds alone. A won play adds a brighter octave (220 Hz) at the base amplitude as its own partial while fewer than 6
// partials sound; with 6 (the root and 5 stars on target, the recipe's limit) the root itself is raised to the octave
// instead, so the won sound always differs from the playing one and never exceeds 6 partials. A failed play halves
// every amplitude and the loop gain (the synthesiser normalises the summed partials to the loop gain, so the gain is
// what makes it quieter). The loop lasts 12 s, so every partial has a whole number of cycles in it: 1,320 (root),
// 1,980, 1,650, 2,640, 2,200 and 1,485 (stars 0 … 4) and 2,640 (the won octave). Entries of `onTarget` beyond the fifth
// are ignored (a level has at most 5 stars). Bounds: at most 6 partials (limit 6), amplitudes ≤ 0.6 (limit 1), gain ≤
// 0.2 (limit 0.3), 12 s (limit 4 … 16), so every recipe is valid.
import VisualCoreAudioDSP

/// The ambient loop recipe of Chrono Constellator (presentation only; the presenter builds it when a level opens, when
/// a step, edit, rewind, undo or redo changes the stars on target or the stage, and when the Sound toggle turns on).
public enum ChronoConstellatorSoundRecipe {
    /// The loop length in seconds.
    public static let seconds = 12
    /// The root frequency in hertz (A2).
    public static let rootHertz = 110.0
    /// The amplitude of the root, of every star partial and of the won octave.
    public static let baseAmplitude = 0.6
    /// The loop gain in every stage but `failed`.
    public static let baseGain = 0.2
    /// The frequency ratio of each star's partial to the root, star 0 … 4.
    public static let starRatios: [Double] = [3.0 / 2, 5.0 / 4, 2, 5.0 / 3, 9.0 / 8]

    /// The root's cycles per loop (1,320).
    public static var rootCycles: Int { Int((rootHertz * Double(seconds)).rounded()) }

    /// The cycles per loop of each star's partial, star 0 … 4 (1,980, 1,650, 2,640, 2,200 and 1,485).
    public static var starCycles: [Int] {
        var cycles: [Int] = []
        for ratio in starRatios { cycles.append(Int((Double(rootCycles) * ratio).rounded())) }
        return cycles
    }

    /// The cycles per loop of the won octave (2,640, 220 Hz).
    public static var octaveCycles: Int { rootCycles * 2 }

    /// The recipe for the stars on target `onTarget` (star order; entries beyond the fifth ignored) and `stage`: 12 s,
    /// one swell; the root (1,320 cycles); a partial (``starCycles``) for each star on its target; when won the octave
    /// (2,640 cycles) as its own partial while fewer than 6 partials sound, else the root raised to the octave; every
    /// partial at ``baseAmplitude`` and the gain ``baseGain``, both halved when failed. Always valid.
    public static func recipe(onTarget: [Bool], stage: ChronoConstellatorStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let cycles: [Int] = starCycles
        var partials: [AmbientLoopPartial] = [AmbientLoopPartial(cyclesPerLoop: rootCycles, amplitude: amplitude)]
        for star in 0..<min(onTarget.count, cycles.count) where onTarget[star] {
            partials.append(AmbientLoopPartial(cyclesPerLoop: cycles[star], amplitude: amplitude))
        }
        if stage == .won {
            if partials.count < AmbientLoopRecipe.partialCountRange.upperBound {
                partials.append(AmbientLoopPartial(cyclesPerLoop: octaveCycles, amplitude: amplitude))
            } else {
                partials[0] = AmbientLoopPartial(cyclesPerLoop: octaveCycles, amplitude: amplitude)
            }
        }
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: 1, gain: baseGain * scale)
    }

    /// Whether each star of `snapshot` stands on its target, in star order.
    public static func onTarget(_ snapshot: ChronoConstellatorSceneSnapshot) -> [Bool] {
        snapshot.stars.map(\.onTarget)
    }
}
