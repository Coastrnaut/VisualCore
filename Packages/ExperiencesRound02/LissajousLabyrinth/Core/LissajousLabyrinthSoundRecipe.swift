// LissajousLabyrinthSoundRecipe — feature 316 (R02-G02-06) T-R02G0206-004 (FR-R02G0206-006; clarification Q4; research
// R4). The optional ambient sound of Lissajous Labyrinth as an `AmbientLoopRecipe`, a pure function of the dials and the
// stage, so equal states sound equal. The figure's own ratio a : b is heard: partials at 110 Hz × a and 110 Hz × b (one
// partial when a = b = 1, the only equal coprime pair), a soft perfect fifth (× 3 / 2) above the lower of the two, and,
// when the play is won, a brighter octave above the higher one. The partial amplitudes are 0.6 … 1.0 of a base
// amplitude, shaped linearly by phase φ (first partial) and phase ψ (second partial) over 0 … 15; the fifth is at half
// the base. A failed play halves every amplitude and the loop's gain. Every frequency is a whole number of hertz, so each
// partial completes whole cycles in the 8-second loop. Bounds: at most 4 partials (limit 6), amplitudes ≤ 0.8 (limit 1),
// gain ≤ 0.14 (limit 0.3), highest frequency 1,980 Hz (well under the 24 kHz Nyquist limit at 48 kHz); dials outside
// their ranges are clamped (frequencies to 1 … 9, phases to 0 … 15), so every recipe is valid.
import VisualCoreAudioDSP

/// The ambient loop recipe of Lissajous Labyrinth (presentation only; the presenter builds it at level open, play end
/// and when the Sound toggle turns on).
public enum LissajousLabyrinthSoundRecipe {
    /// The loop length in seconds.
    public static let seconds = 8
    /// The root frequency in hertz that the frequency dials multiply (A2).
    public static let rootHertz = 110
    /// The base partial amplitude that the phases shape (0.6 … 1.0 of it).
    public static let baseAmplitude = 0.8
    /// The loop gain in every stage but `failed`.
    public static let baseGain = 0.14

    /// The amplitude `baseAmplitude × (0.6 + 0.4 × phase / 15)` for `phase` clamped to 0 … 15.
    public static func shapedAmplitude(phase: Int) -> Double {
        let clamped: Int = min(max(phase, 0), 15)
        return baseAmplitude * (0.6 + 0.4 * Double(clamped) / 15)
    }

    /// The recipe for `dials` and `stage`: 8 s, one swell; partials at 110 × a and 110 × b Hz (one when both are 1)
    /// shaped by φ and ψ, a fifth above the lower at half the base amplitude, an octave above the higher at the base
    /// amplitude when won; a failed play halves every amplitude and the gain (0.07 instead of 0.14). Always valid.
    public static func recipe(dials: LissajousLabyrinthDials, stage: LissajousLabyrinthStage) -> AmbientLoopRecipe {
        let a: Int = min(max(dials.frequencyA, 1), 9)
        let b: Int = min(max(dials.frequencyB, 1), 9)
        let scale: Double = stage == .failed ? 0.5 : 1
        var partials: [AmbientLoopPartial] = []
        let first: Double = shapedAmplitude(phase: dials.phaseA)
        let second: Double = shapedAmplitude(phase: dials.phaseC)
        if a == b {
            partials.append(AmbientLoopPartial(cyclesPerLoop: seconds * rootHertz * a,
                                               amplitude: max(first, second) * scale))
        } else {
            partials.append(AmbientLoopPartial(cyclesPerLoop: seconds * rootHertz * a, amplitude: first * scale))
            partials.append(AmbientLoopPartial(cyclesPerLoop: seconds * rootHertz * b, amplitude: second * scale))
        }
        // The fifth: 165 Hz × the lower multiplier, a whole number of hertz.
        partials.append(AmbientLoopPartial(cyclesPerLoop: seconds * rootHertz * 3 * min(a, b) / 2,
                                           amplitude: baseAmplitude / 2 * scale))
        if stage == .won {
            partials.append(AmbientLoopPartial(cyclesPerLoop: seconds * rootHertz * 2 * max(a, b),
                                               amplitude: baseAmplitude))
        }
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: 1, gain: baseGain * scale)
    }
}
