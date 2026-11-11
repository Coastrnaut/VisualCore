// PrecisionAdvisor.swift — how close a view's pixel step is to the floating-point resolution of its coordinates
// (feature 027 T-A03-201; gap G-PRECISION; FR-A03-205; research R2). Pure; the GPU's mantissa bits come from
// VisualCoreRendering's RenderCapabilities.fragmentHighp (or are assumed by the caller).
import Foundation

/// Compares a per-pixel plane step with one unit in the last place (ulp) of the coordinates, for `mantissaBits` of
/// precision. Below 1 ulp per pixel, neighboring pixels collapse onto the same value (blocky garbage); below
/// `nearLimitMargin` ulps, iteration error starts to show as banding.
public enum PrecisionAdvisor {
    /// The precision state of a view.
    public enum Level: String, Sendable, Equatable {
        case reliable, nearLimit, beyondLimit
    }

    /// The assessment of one view.
    public struct Status: Sendable, Equatable {
        /// The level.
        public let level: Level
        /// The pixel step in ulps of the coordinate magnitude (0 for invalid input).
        public let margin: Double
        /// The smallest pixel step that stays at or above 1 ulp at this magnitude.
        public let minimumPixelStep: Double
    }

    /// Margins below this many ulps per pixel are `nearLimit`.
    public static let nearLimitMargin = 16.0

    /// The smallest per-pixel step representable at `magnitude` with `mantissaBits` (clamped to 1…64):
    /// max(|magnitude|, tiny) · 2^−bits.
    public static func minimumPixelStep(mantissaBits: Int, magnitude: Double) -> Double {
        let bits = Double(min(max(mantissaBits, 1), 64))
        let m = magnitude.isFinite ? abs(magnitude) : 0
        return max(m, Double.leastNormalMagnitude) * pow(2, -bits)
    }

    /// Assesses a view: ulp = max(|magnitude|, pixelStep) · 2^−bits and margin = pixelStep / ulp. Reliable at ≥ 16,
    /// near the limit at 1…16, beyond below 1. Non-finite or non-positive input and fewer than 1 bit are beyond the
    /// limit with margin 0.
    public static func assess(mantissaBits: Int, magnitude: Double, pixelStep: Double) -> Status {
        guard mantissaBits >= 1, magnitude.isFinite, pixelStep.isFinite, pixelStep > 0 else {
            return Status(level: .beyondLimit, margin: 0, minimumPixelStep: minimumPixelStep(mantissaBits: max(mantissaBits, 1), magnitude: magnitude))
        }
        let bits = Double(min(mantissaBits, 64))
        let ulp = max(abs(magnitude), pixelStep) * pow(2, -bits)
        let margin = pixelStep / ulp
        let level: Level = margin >= nearLimitMargin ? .reliable : (margin >= 1 ? .nearLimit : .beyondLimit)
        return Status(level: level, margin: margin, minimumPixelStep: minimumPixelStep(mantissaBits: mantissaBits, magnitude: magnitude))
    }
}
