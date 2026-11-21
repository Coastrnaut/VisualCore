// HueCompassSoundRecipe — feature 336 (R02-G04-06) T-R02G0406-005 (FR-R02G0406-006; clarification Q4; research R6).
// The optional ambient sound of Hue Compass as an `AmbientLoopRecipe`, a pure function of the last clue and the stage,
// so equal clues sound equal. The clue is heard as a chord that resolves: a root at 110 Hz, a clue partial at 110 Hz ×
// (1 + g / 12) for the last clue's hue gap g (clamped to 0 … 12, so it rises from the root to its octave as the probe's
// band drifts away from the target's; merged into the root, a unison, when g = 0 or there is no clue yet) and a soft
// perfect fifth (165 Hz) above the root; a won play always adds a brighter octave (220 Hz) above the root (kept as its
// own partial even when the clue partial sits at the octave at gap 12, so the won sound always differs). The fog depth
// d of the last clue (0 with no clue; clamped to 0 … 90) shapes the loudness: the loop's gain is the base gain × (1 −
// 0.4 · min(d, 90) / 90), 1.0 at d = 0 falling to 0.6 at d ≥ 90, so a probe deep in the fog sounds farther away. The
// factor is applied to the loop gain, the one gain that sets the loudness: the synthesiser normalises the summed
// partials to that peak gain, so scaling every amplitude by the same factor would change nothing. A failed play halves
// every amplitude and the gain. The loop lasts 8 s and every partial has a whole number of cycles in it: 110 × (12 + g)
// / 12 Hz is a whole number of cycles per loop only when g is a multiple of 3, so the clue partial's cycles per loop
// are 880 × (12 + g) / 12 rounded to the nearest whole cycle (at most 1/6 Hz off). Bounds: at most 4 partials (limit
// 6), amplitudes ≤ 0.8 (limit 1), gain ≤ 0.14 (limit 0.3), 8 s (limit 4 … 16); the highest frequency is 220 Hz, so
// every recipe is valid.
import VisualCoreAudioDSP

/// The ambient loop recipe of Hue Compass (presentation only; the presenter builds it at level open, when a clue is
/// recorded, at play end and when the Sound toggle turns on).
public enum HueCompassSoundRecipe {
    /// The loop length in seconds.
    public static let seconds = 8
    /// The root frequency in hertz (A2).
    public static let rootHertz = 110
    /// The amplitude of the root, the clue partial and the won octave.
    public static let baseAmplitude = 0.8
    /// The loop gain with no fog depth in every stage but `failed`.
    public static let baseGain = 0.14
    /// The largest hue gap heard (half the 24 bands).
    static let maxHueGap = 12
    /// The largest fog depth heard; deeper clues sound as this one.
    static let maxDepth = 90

    /// The fog-depth factor `1 − 0.4 · min(d, 90) / 90` for depth `d` (a negative depth counts as 0): 1.0 at 0,
    /// falling linearly to 0.6 at 90 and staying there.
    public static func depthFactor(depth: Int) -> Double {
        let clamped: Int = min(max(depth, 0), maxDepth)
        return 1 - 0.4 * Double(clamped) / Double(maxDepth)
    }

    /// The cycles per loop of the clue partial `110 × (1 + g / 12)` Hz for hue gap `g` clamped to 0 … 12: the exact
    /// `880 × (12 + g) / 12` rounded to the nearest whole cycle (880 at g = 0, 1,760 at g = 12).
    static func clueCycles(hueGap: Int) -> Int {
        let gap: Int = min(max(hueGap, 0), maxHueGap)
        let numerator: Int = seconds * rootHertz * (maxHueGap + gap)
        return (numerator + maxHueGap / 2) / maxHueGap
    }

    /// The root's cycles per loop (880).
    static var rootCycles: Int { seconds * rootHertz }

    /// The recipe for the last clue `clue` (nil before the first probe) and `stage`: 8 s, one swell; the root (110 Hz,
    /// the base amplitude), the clue partial (``clueCycles(hueGap:)``, the base amplitude; merged into the root when its
    /// frequency equals the root's, that is at gap 0 or with no clue), the fifth (165 Hz) at half the base amplitude, and
    /// when won the octave (220 Hz) at the base amplitude (always its own partial); gain `baseGain` ×
    /// ``depthFactor(depth:)`` of the clue's depth (0 with no clue). A failed play halves every amplitude and the gain.
    /// Always valid.
    public static func recipe(clue: HueCompassClue?, stage: HueCompassStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let factor: Double = depthFactor(depth: clue?.depth ?? 0)
        let root: Int = rootCycles
        let current: Int = clue.map { clueCycles(hueGap: $0.hueGap) } ?? root
        let octave: Int = root * 2
        var partials: [AmbientLoopPartial] = [AmbientLoopPartial(cyclesPerLoop: root, amplitude: baseAmplitude * scale)]
        if current != root {
            partials.append(AmbientLoopPartial(cyclesPerLoop: current, amplitude: baseAmplitude * scale))
        }
        partials.append(AmbientLoopPartial(cyclesPerLoop: root * 3 / 2, amplitude: baseAmplitude / 2 * scale))
        if stage == .won {
            partials.append(AmbientLoopPartial(cyclesPerLoop: octave, amplitude: baseAmplitude * scale))
        }
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: 1, gain: baseGain * factor * scale)
    }
}
