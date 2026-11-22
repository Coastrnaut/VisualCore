// FacetedForgeSoundRecipe — feature 376 (R02-G08-06) T-R02G0806-004 (FR-R02G0806-006; SC-R02G0806-004;
// clarification Q4). The optional ambient sound of Faceted Forge as an `AmbientLoopRecipe`, a pure function of the
// piece count, the target's piece count and the stage, so equal crystals sound equal. A root at 110 Hz (A2) always
// sounds; each piece beyond the first adds its partial at 110 Hz × (5/4, 3/2, 2, 5/2)[k − 1] — 137.5, 165, 220 and
// 275 Hz — at the base amplitude, so the chord opens as the crystal is cut; while the crystal is whole the root sounds
// alone. The target's piece count is used only to clamp: the partials k = 1 … min(pieces, target) − 1, at most 4 (a
// play with more pieces than its target can no longer win, so the chord holds at the target's), and nothing else
// depends on it. A won play adds the octave (220 Hz) at the base amplitude as its own partial; at most 1 + 4 + 1 = 6
// partials sound, within the limit. The won octave (2,640 cycles) coincides with the third partial (110 × 2), so a
// won chord of k added partials has the same partials as the playing chord of k + 1 on another level; a won loop
// therefore also swells twice per loop (every 6 s) instead of once, which keeps the recipe of every (partials, stage)
// pair distinct among playing, won and failed. A failed play halves every amplitude and the loop gain (the synthesiser
// normalises the summed partials to the loop gain, so the gain is what makes it quieter). Every other stage (loading,
// tutorial, paused, result) sounds as playing. The loop lasts 12 s, so every partial has a whole number of cycles in
// it: 1,320 (root), 1,650, 1,980, 2,640 and 3,300 (k = 1 … 4) and 2,640 (the won octave). Bounds: at most 6 partials
// (limit 6), amplitudes ≤ 0.6 (limit 1), gain ≤ 0.2 (limit 0.3), 12 s (limit 4 … 16), swell 1 or 2 cycles, so every
// recipe is valid.
import VisualCoreAudioDSP

/// The ambient loop recipe of Faceted Forge (presentation only; the presenter builds it when a level opens, when a cut,
/// undo or redo changes the piece count or the stage, and when the Sound toggle turns on — never per frame).
public enum FacetedForgeSoundRecipe {
    /// The loop length in seconds.
    public static let seconds = 12
    /// The root frequency in hertz (A2).
    public static let rootHertz = 110.0
    /// The amplitude of the root, of every piece partial and of the won octave.
    public static let baseAmplitude = 0.6
    /// The loop gain in every stage but `failed`.
    public static let baseGain = 0.2
    /// The swell cycles per loop in every stage but `won`.
    public static let baseSwellCycles = 1
    /// The swell cycles per loop when won (one swell every 6 s).
    public static let wonSwellCycles = 2
    /// The frequency ratio to the root of the partial of each piece beyond the first, k = 1 … 4.
    public static let pieceRatios: [Double] = [5.0 / 4, 3.0 / 2, 2, 5.0 / 2]

    /// The root's cycles per loop (1,320).
    public static var rootCycles: Int { Int((rootHertz * Double(seconds)).rounded()) }

    /// The cycles per loop of each added partial, k = 1 … 4 (1,650, 1,980, 2,640 and 3,300).
    public static var pieceCycles: [Int] {
        var cycles: [Int] = []
        for ratio in pieceRatios { cycles.append(Int((Double(rootCycles) * ratio).rounded())) }
        return cycles
    }

    /// The cycles per loop of the won octave (2,640, 220 Hz).
    public static var octaveCycles: Int { rootCycles * 2 }

    /// The number of added partials: min(`pieces`, `target`) − 1, clamped to 0 … 4 (the target only clamps).
    public static func addedPartials(pieces: Int, target: Int) -> Int {
        let counted: Int = min(pieces, target) - 1
        return min(max(counted, 0), pieceRatios.count)
    }

    /// The recipe for `pieces` pieces against a target of `target` pieces in `stage`: 12 s, one swell
    /// (``wonSwellCycles`` when won); the root (1,320 cycles); a partial (``pieceCycles``) for each added partial
    /// (``addedPartials(pieces:target:)``); when won the octave (2,640 cycles) as its own partial; every partial at
    /// ``baseAmplitude`` and the gain ``baseGain``, both halved when failed. Always valid.
    public static func recipe(pieces: Int, target: Int, stage: FacetedForgeStage) -> AmbientLoopRecipe {
        let scale: Double = stage == .failed ? 0.5 : 1
        let amplitude: Double = baseAmplitude * scale
        let cycles: [Int] = pieceCycles
        var partials: [AmbientLoopPartial] = [AmbientLoopPartial(cyclesPerLoop: rootCycles, amplitude: amplitude)]
        let added: Int = addedPartials(pieces: pieces, target: target)
        for index in 0..<added {
            partials.append(AmbientLoopPartial(cyclesPerLoop: cycles[index], amplitude: amplitude))
        }
        if stage == .won {
            partials.append(AmbientLoopPartial(cyclesPerLoop: octaveCycles, amplitude: amplitude))
        }
        let swell: Int = stage == .won ? wonSwellCycles : baseSwellCycles
        return AmbientLoopRecipe(seconds: seconds, partials: partials, swellCycles: swell, gain: baseGain * scale)
    }
}
