// TrailDecay.swift — the fade model for decaying trail images (feature 035 A04-P03 T-A04-302; gap G-BLENDTRAIL;
// FR-A04-302; research R1). Pure math shared by the GPU trail layer (VisualCoreRendering's TrailLayer) and its tests:
// the layer keeps `max(previous × factor − subtraction/255, 0)` of the last image each frame.
import Foundation

/// Frame-rate-independent fading of trail images stored with 8 bits per channel.
public enum TrailDecay {
    /// Allowed strengths: the fraction of brightness kept per 1/60 s (0 = no trail).
    public static let strengthRange: ClosedRange<Double> = 0...0.98

    /// `strength` clamped to `strengthRange` (non-finite becomes 0).
    public static func clampedStrength(_ strength: Double) -> Double {
        strength.isFinite ? min(max(strength, strengthRange.lowerBound), strengthRange.upperBound) : 0
    }

    /// The multiplier for a frame of `delta` seconds: `strength^(delta × 60)`, so equal elapsed time fades equally at
    /// any frame rate. A non-positive or non-finite `delta` gives 1 (no time passed).
    public static func factor(strength: Double, delta: Double) -> Double {
        guard delta.isFinite, delta > 0 else { return 1 }
        let s = clampedStrength(strength)
        return s == 0 ? 0 : pow(s, delta * 60)
    }

    /// The extra fade per frame, in 8-bit levels: `max(1, delta × 60)` (one level per 1/60 s, at least one per frame).
    /// Scaling it with time keeps equal elapsed time fading alike at 30 and 60 frames per second (a fixed level per
    /// frame differed by up to 20/255 after 1 s; this differs by at most 5/255, research R1); the minimum of one level
    /// guarantees every trail ends even at high frame rates.
    public static func subtraction(delta: Double) -> Double {
        guard delta.isFinite, delta > 0 else { return 1 }
        return max(1, delta * 60)
    }

    /// The 8-bit value after one frame: `max(0, round(value × factor − subtract))`, the GPU's result for an 8-bit
    /// channel of the trail layer.
    public static func step8(_ value: UInt8, factor: Double, subtract: Double = 1) -> UInt8 {
        let f = factor.isFinite ? min(max(factor, 0), 1) : 0
        let d = subtract.isFinite ? max(subtract, 1) : 1
        return UInt8(max(0, (Double(value) * f - d).rounded()))
    }
}
