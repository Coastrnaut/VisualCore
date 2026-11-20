// AuroraLoomSoundRecipe — feature 306 (R02-G01-06) T-R02G0106-005 (FR-R02G0106-006; clarification Q4; research R4). The
// optional ambient sound of Aurora Loom as an `AmbientLoopRecipe`, a pure function of the three ribbons' wave steps and
// the stage. Each ribbon gives one partial whose frequency is its wave step's entry in a major pentatonic scale from
// 110 Hz (just ratios 1, 9/8, 5/4, 3/2, 5/3 per octave, rounded to whole hertz so every partial completes a whole number
// of cycles in the 8-second loop). A won play adds a perfect fifth above the lowest partial and plays louder; a failed
// play is quieter. Phase steps are not sonified: they shift where the ribbons meet, not their pitch, and a recipe that
// changed with every phase step would rebuild the loop on almost every move.
import VisualCoreAudioDSP

/// The ambient loop recipe of Aurora Loom (presentation only; the presenter builds it at level open, play end and when
/// the Sound toggle turns on).
public enum AuroraLoomSoundRecipe {
    /// The loop length in seconds.
    public static let seconds = 8

    /// The frequency in whole hertz of each wave step 0 … 15: the major pentatonic scale from 110 Hz (A2) over three
    /// octaves and one note, just ratios rounded — 110, 124, 138, 165, 183, 220, 248, 275, 330, 367, 440, 495, 550, 660,
    /// 733, 880.
    public static let pentatonicHertz: [Int] = [110, 124, 138, 165, 183, 220, 248, 275, 330, 367, 440, 495, 550, 660,
                                                733, 880]

    /// The amplitudes of the partials of ribbons 0, 1 and 2.
    public static let ribbonAmplitudes: [Double] = [0.5, 0.35, 0.25]
    /// The amplitude of the won chord's fifth.
    public static let fifthAmplitude = 0.3
    /// The gain while the play is won.
    public static let wonGain = 0.2
    /// The gain while the play is failed.
    public static let failedGain = 0.08
    /// The gain in every other stage (loading, tutorial, playing, paused, result).
    public static let defaultGain = 0.14

    /// The frequency in hertz of `waveStep`, clamped to 0 … 15.
    public static func hertz(waveStep: Int) -> Int {
        pentatonicHertz[min(max(waveStep, 0), pentatonicHertz.count - 1)]
    }

    /// The recipe for `steps` and `stage`: 8 s, one swell; partial r at `8 × hertz(wave[r])` cycles with amplitude
    /// 0.5 / 0.35 / 0.25; when won, a fourth partial at the lowest frequency × 3 / 2 (rounded to whole hertz) with
    /// amplitude 0.3 and gain 0.2; gain 0.08 when failed, otherwise 0.14. A missing wave step counts as 0. Always valid.
    public static func recipe(steps: AuroraLoomSteps, stage: AuroraLoomStage) -> AmbientLoopRecipe {
        var partials: [AmbientLoopPartial] = []
        var lowest: Int = Int.max
        for ribbon in 0..<3 {
            let wave: Int = ribbon < steps.wave.count ? steps.wave[ribbon] : 0
            let frequency: Int = hertz(waveStep: wave)
            lowest = min(lowest, frequency)
            partials.append(AmbientLoopPartial(cyclesPerLoop: seconds * frequency, amplitude: ribbonAmplitudes[ribbon]))
        }
        let gain: Double
        switch stage {
        case .won:
            let fifth: Int = Int((Double(lowest) * 1.5).rounded())
            partials.append(AmbientLoopPartial(cyclesPerLoop: seconds * fifth, amplitude: fifthAmplitude))
            gain = wonGain
        case .failed:
            gain = failedGain
        case .loading, .tutorial, .playing, .paused, .result:
            gain = defaultGain
        }
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: 1, gain: gain)
    }
}
