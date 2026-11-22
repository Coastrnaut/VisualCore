// AmethystEscapeSoundRecipe — feature 366 (R02-G07-06) T-R02G0706-004 (FR-R02G0706-006; SC-R02G0706-004;
// clarification Q4). The optional ambient sound of Amethyst Escape as an `AmbientLoopRecipe`, a pure function of the
// pearl's shell, the number of shells and the stage, so equal crystals sound equal. A root at 98 Hz (G2) always sounds;
// each shell the pearl has passed adds its partial at 98 Hz × (5/4, 3/2, 2, 5/2)[shell − 1] — 122.5, 147, 196 and
// 245 Hz — at the base amplitude, so the chord opens as the pearl climbs outward; in the innermost shell the root
// sounds alone. The pearl's shell is clamped to 0 … min(shells − 1, 4) (a level has 2 … 5 shells, so at most 4
// shells are passed; the shell count matters only through that clamp). A won play adds a brighter octave (196 Hz) at
// the base amplitude as its own partial while fewer than 6 partials sound; with 6 already (never with 5 shells or
// fewer, kept for safety) the root itself is raised to the octave instead, so the won sound always differs from the
// playing one and never exceeds 6 partials. The won octave (2,352 cycles) coincides with the third shell's partial
// (98 × 2), so a won chord of k passed shells has the same partials as the playing chord of k + 1 passed shells on a
// deeper level; a won loop therefore also swells twice per loop (every 6 s) instead of once, which keeps the recipe of
// every (shells passed, stage) pair distinct among playing, won and failed. A failed play halves every amplitude and
// the loop gain (the synthesiser normalises the summed partials to the loop gain, so the gain is what makes it
// quieter). The loop lasts 12 s, so every partial has a whole number of cycles in it: 1,176 (root), 1,470, 1,764,
// 2,352 and 2,940 (shells 1 … 4) and 2,352 (the won octave). Bounds: at most 6 partials (limit 6), amplitudes ≤ 0.6
// (limit 1), gain ≤ 0.2 (limit 0.3), 12 s (limit 4 … 16), swell 1 or 2 cycles, so every recipe is valid.
import VisualCoreAudioDSP

/// The ambient loop recipe of Amethyst Escape (presentation only; the presenter builds it when a level opens, when an
/// advance, undo or redo changes the pearl's shell or the stage, and when the Sound toggle turns on — never per frame).
public enum AmethystEscapeSoundRecipe {
    /// The loop length in seconds.
    public static let seconds = 12
    /// The root frequency in hertz (G2).
    public static let rootHertz = 98.0
    /// The amplitude of the root, of every shell partial and of the won octave.
    public static let baseAmplitude = 0.6
    /// The loop gain in every stage but `failed`.
    public static let baseGain = 0.2
    /// The swell cycles per loop in every stage but `won`.
    public static let baseSwellCycles = 1
    /// The swell cycles per loop when won (one swell every 6 s).
    public static let wonSwellCycles = 2
    /// The frequency ratio to the root of the partial of each passed shell, shells 1 … 4.
    public static let shellRatios: [Double] = [5.0 / 4, 3.0 / 2, 2, 5.0 / 2]

    /// The root's cycles per loop (1,176).
    public static var rootCycles: Int { Int((rootHertz * Double(seconds)).rounded()) }

    /// The cycles per loop of each passed shell's partial, shells 1 … 4 (1,470, 1,764, 2,352 and 2,940).
    public static var shellCycles: [Int] {
        var cycles: [Int] = []
        for ratio in shellRatios { cycles.append(Int((Double(rootCycles) * ratio).rounded())) }
        return cycles
    }

    /// The cycles per loop of the won octave (2,352, 196 Hz).
    public static var octaveCycles: Int { rootCycles * 2 }

    /// The number of shells the pearl has passed: `pearlShell` clamped to 0 … min(`shells` − 1, 4).
    public static func passedShells(pearlShell: Int, shells: Int) -> Int {
        let top: Int = min(max(shells - 1, 0), shellRatios.count)
        return min(max(pearlShell, 0), top)
    }

    /// The recipe for the pearl in shell `pearlShell` (0: innermost) of a level of `shells` shells in `stage`: 12 s,
    /// one swell (``wonSwellCycles`` when won); the root (1,176 cycles); a partial (``shellCycles``) for each shell
    /// passed (``passedShells(pearlShell:shells:)``); when won the octave (2,352 cycles) as its own partial while fewer
    /// than 6 partials sound, else the root raised to the octave; every partial at ``baseAmplitude`` and the gain
    /// ``baseGain``, both halved when failed. Always valid.
    public static func recipe(pearlShell: Int, shells: Int, stage: AmethystEscapeStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let cycles: [Int] = shellCycles
        var partials: [AmbientLoopPartial] = [AmbientLoopPartial(cyclesPerLoop: rootCycles, amplitude: amplitude)]
        let passed: Int = passedShells(pearlShell: pearlShell, shells: shells)
        for shell in 0..<passed {
            partials.append(AmbientLoopPartial(cyclesPerLoop: cycles[shell], amplitude: amplitude))
        }
        if stage == .won {
            if partials.count < AmbientLoopRecipe.partialCountRange.upperBound {
                partials.append(AmbientLoopPartial(cyclesPerLoop: octaveCycles, amplitude: amplitude))
            } else {
                partials[0] = AmbientLoopPartial(cyclesPerLoop: octaveCycles, amplitude: amplitude)
            }
        }
        let swell: Int = stage == .won ? wonSwellCycles : baseSwellCycles
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: swell, gain: baseGain * scale)
    }

    /// The recipe for `snapshot`: its pearl's shell, its shell count and its stage.
    public static func recipe(_ snapshot: AmethystEscapeSceneSnapshot) -> AmbientLoopRecipe {
        recipe(pearlShell: snapshot.pearl.shell, shells: snapshot.shells.count, stage: snapshot.stage)
    }
}
