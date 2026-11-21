// WaveKnotKeeperSoundRecipe — feature 326 (R02-G03-06) T-R02G0306-005 (FR-R02G0306-006; clarification Q4; research R5).
// The optional ambient sound of Wave Knot Keeper as an `AmbientLoopRecipe`, a pure function of the rope's summary, the
// level's target and the stage, so equal states sound equal. The knot is heard as a chord that resolves: a root at
// 110 Hz × (1 + target crossings), a partial at 110 Hz × (1 + current crossings) (one partial, in unison with the root,
// when the counts match; the root's frequency for a degenerate summary) and a soft perfect fifth (× 3 / 2) above the
// root; a won play adds a brighter octave above the root. The writhe distance d = |summary writhe − target writhe| shapes
// the loudness: the factor 0.6 + 0.4 / (1 + d) (1.0 at d = 0, 0.8 at 1, 0.73 at 2, 0.7 at 3, falling toward 0.6) scales
// both the current partial's amplitude and the loop's gain, so a rope whose writhe is off sounds quieter and its own
// voice recedes behind the root. A failed play halves every amplitude and the gain. Every frequency is a whole number
// of hertz, so each partial completes whole cycles in the 8-second loop. Bounds: at most 4 partials (limit 6),
// amplitudes ≤ 0.8 (limit 1), gain ≤ 0.14 (limit 0.3); crossings are clamped to 0 … 32 (the target's own range), so the
// highest frequency is the won octave 7,260 Hz (well under the 24 kHz Nyquist limit at 48 kHz) and every recipe is
// valid.
import VisualCoreAudioDSP

/// The ambient loop recipe of Wave Knot Keeper (presentation only; the presenter builds it at level open, summary
/// changes, play end and when the Sound toggle turns on).
public enum WaveKnotKeeperSoundRecipe {
    /// The loop length in seconds.
    public static let seconds = 8
    /// The frequency in hertz that 1 + a crossing count multiplies (A2).
    public static let rootHertz = 110
    /// The amplitude of the root, the current partial at writhe distance 0 and the won octave.
    public static let baseAmplitude = 0.8
    /// The loop gain at writhe distance 0 in every stage but `failed`.
    public static let baseGain = 0.14
    /// The largest crossing count heard (the target's range is 0 … 32).
    static let maxCrossings = 32

    /// The writhe-distance factor `0.6 + 0.4 / (1 + d)` for `d = |writhe − targetWrithe|`: 1.0 at 0, strictly falling
    /// toward 0.6 (never below it). A distance too large for `Int` counts as the largest.
    public static func writheFactor(writhe: Int, targetWrithe: Int) -> Double {
        let (difference, overflow) = writhe.subtractingReportingOverflow(targetWrithe)
        let distance: Double = overflow || difference == Int.min ? Double(Int.max) : Double(abs(difference))
        return 0.6 + 0.4 / (1 + distance)
    }

    /// The cycles per loop of `rootHertz × (1 + crossings) × numerator / denominator` with crossings clamped to 0 … 32.
    static func cycles(crossings: Int, numerator: Int = 1, denominator: Int = 1) -> Int {
        let clamped: Int = min(max(crossings, 0), maxCrossings)
        return seconds * rootHertz * (1 + clamped) * numerator / denominator
    }

    /// The recipe for `summary`, `target` and `stage`: 8 s, one swell; the root (110 × (1 + target crossings) Hz, the
    /// base amplitude), the current partial (110 × (1 + summary crossings) Hz, or the root's frequency when the summary
    /// is degenerate; merged into the root when the frequencies are equal) at the base amplitude × the writhe factor, the
    /// fifth above the root at half the base amplitude, and when won the octave above the root at the base amplitude;
    /// gain `baseGain` × the writhe factor. A failed play halves every amplitude and the gain. Always valid.
    public static func recipe(summary: WaveKnotKeeperSummary, target: WaveKnotKeeperTarget,
                              stage: WaveKnotKeeperStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let factor: Double = writheFactor(writhe: summary.writhe, targetWrithe: target.writhe)
        let root: Int = cycles(crossings: target.crossings)
        let current: Int = summary.degenerate ? root : cycles(crossings: summary.crossings)
        var partials: [AmbientLoopPartial] = []
        if current == root {
            partials.append(AmbientLoopPartial(cyclesPerLoop: root, amplitude: baseAmplitude * scale))
        } else {
            partials.append(AmbientLoopPartial(cyclesPerLoop: root, amplitude: baseAmplitude * scale))
            partials.append(AmbientLoopPartial(cyclesPerLoop: current, amplitude: baseAmplitude * factor * scale))
        }
        partials.append(AmbientLoopPartial(cyclesPerLoop: cycles(crossings: target.crossings, numerator: 3,
                                                                 denominator: 2),
                                           amplitude: baseAmplitude / 2 * scale))
        if stage == .won {
            partials.append(AmbientLoopPartial(cyclesPerLoop: cycles(crossings: target.crossings, numerator: 2),
                                               amplitude: baseAmplitude * scale))
        }
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: 1, gain: baseGain * factor * scale)
    }
}
