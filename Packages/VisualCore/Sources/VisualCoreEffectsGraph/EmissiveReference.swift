// EmissiveReference.swift — CPU reference of the emissive pass's formulas: sRGB transfer, Rec. 709 luminance,
// soft-knee prefilter, tone maps, composite and premultiplied over (feature 207 R02-F07 T-R02F07-002;
// FR-R02F07-006; research R2, R3, R4). Pure Swift; the GPU programs in VisualCoreEffects mirror each step.
import Foundation

/// Tone-mapping operator of the emissive pass's `tonemap` parameter (rounded to the nearest raw value).
public enum ToneMapOperator: Int, Sendable, CaseIterable {
    /// Clamp to 0…1 only (the default, so dim parts stay untouched).
    case none = 0
    /// Reinhard `x / (1 + x)` per channel.
    case reinhard = 1
    /// Narkowicz ACES fit `(x(2.51x + 0.03)) / (x(2.43x + 0.59) + 0.14)` per channel, clamped to 0…1.
    case filmic = 2
}

/// Double-precision reference of every formula the emissive pass evaluates on the GPU.
public enum EmissiveReference {
    /// Exact piecewise sRGB decode to linear light: `x / 12.92` up to 0.04045, `((x + 0.055) / 1.055)^2.4` above.
    ///
    /// Inputs below 0 give 0. Inputs above 1 are not clamped: they continue the power curve, so intermediates above
    /// 1 survive (research R4).
    public static func srgbDecode(_ x: Double) -> Double {
        let v = max(0, x)
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    /// Exact piecewise sRGB encode of linear light: `12.92 x` up to 0.0031308, `1.055 x^(1/2.4) − 0.055` above;
    /// the input is clamped to 0…1 first and the output to 0…1 (1 encodes to 1 within 1e-15).
    public static func srgbEncode(_ x: Double) -> Double {
        let v = min(max(x, 0), 1)
        return min(max(v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055, 0), 1)
    }

    /// Rec. 709 luminance of linear light: `0.2126 r + 0.7152 g + 0.0722 b`.
    public static func luminance(_ rgb: SIMD3<Double>) -> Double {
        0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z
    }

    /// Bright extraction with a quadratic soft knee (research R2) on linear light.
    ///
    /// With `k = knee · threshold` and `L = luminance(rgb)`: `soft = clamp(L − threshold + k, 0, 2k)`,
    /// `soft = soft² / (4k + 1e-5)`, `contribution = max(soft, L − threshold) / max(L, 1e-5)`, result
    /// `rgb · contribution`. Zero for `L ≤ threshold − k`; with `knee` 0 it is a hard threshold.
    public static func prefilter(_ rgb: SIMD3<Double>, threshold: Double, knee: Double) -> SIMD3<Double> {
        let k = knee * threshold
        let l = luminance(rgb)
        var soft = min(max(l - threshold + k, 0), 2 * k)
        soft = soft * soft / (4 * k + 1e-5)
        let contribution = max(soft, l - threshold) / max(l, 1e-5)
        return rgb * contribution
    }

    /// Tone-maps one linear channel with `op`; negative inputs give 0 and the result lies in 0…1.
    public static func toneMap(_ x: Double, _ op: ToneMapOperator) -> Double {
        let v = max(0, x)
        switch op {
        case .none:
            return min(v, 1)
        case .reinhard:
            return v / (1 + v)
        case .filmic:
            return min(max((v * (2.51 * v + 0.03)) / (v * (2.43 * v + 0.59) + 0.14), 0), 1)
        }
    }

    /// Composite step on linear light: `(base + glow · intensity) · 2^exposure`, tone-mapped per channel with `op`.
    ///
    /// Returns the LINEAR tone-mapped value; the GPU program then applies `srgbEncode` and keeps the input's alpha.
    public static func composite(base: SIMD3<Double>, glow: SIMD3<Double>, intensity: Double, exposure: Double,
                                 op: ToneMapOperator) -> SIMD3<Double> {
        let c = (base + glow * intensity) * pow(2, exposure)
        return SIMD3(toneMap(c.x, op), toneMap(c.y, op), toneMap(c.z, op))
    }

    /// Premultiplied over (composite mode 2): `overlay · opacity + base · (1 − overlay.a · opacity)`, all four
    /// channels; both colours are premultiplied by their alpha.
    public static func premultipliedOver(overlay: SIMD4<Double>, base: SIMD4<Double>, opacity: Double) -> SIMD4<Double> {
        overlay * opacity + base * (1 - overlay.w * opacity)
    }
}
