// ColorDomain — feature 184 (A25-P05) T-A25-502 (clarification Q1; research R1, R4, R5; contracts/color.md). Which
// values each effect works on, the CPU sRGB transfer functions and the storage precision of the CPU reference.
//
//   linear     grade, blur, vignette: the input is decoded to linear light, the effect is computed, the output is
//              encoded again (exposure, averaging and darkening are light operations)
//   stored     distort (a resampling) and posterize (levels even to the eye) work on the stored sRGB-encoded values
//
// Every picture between effects holds sRGB-encoded values (research R3). The transfer functions are the exact
// piecewise formula of VisualCore's `vc/color.glsl` (`vc_srgbDecode`, `vc_srgbEncode`), written here because
// VisualCore has none for the CPU (research R5). Pure Swift; no UI, GPU or clock.
import Foundation

/// The values an effect works on (clarification Q1).
public enum ColorDomain: Sendable, Equatable {
    /// Linear light: the input is decoded with `SRGB.decode`, the output encoded with `SRGB.encode`.
    case linear
    /// The stored sRGB-encoded values, unchanged.
    case stored
}

extension EffectID {
    /// The values this effect works on: `.linear` for grade, blur and vignette, `.stored` for distort and posterize.
    public var colorDomain: ColorDomain {
        switch self {
        case .grade, .blur, .vignette: .linear
        case .distort, .posterize: .stored
        }
    }
}

/// The sRGB transfer functions, the exact piecewise formula of `vc/color.glsl`.
public enum SRGB {
    /// Linear light of one encoded channel: c = clamp(x, 0, 1); c/12.92 below 0.04045, else ((c + 0.055)/1.055)^2.4.
    public static func decode(_ x: Float) -> Float {
        let c = min(max(x, 0), 1)
        return c < 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4)
    }

    /// The encoded value of one linear channel: c = clamp(x, 0, 1); c·12.92 below 0.0031308, else
    /// 1.055·c^(1/2.4) − 0.055.
    public static func encode(_ x: Float) -> Float {
        let c = min(max(x, 0), 1)
        return c < 0.0031308 ? c * 12.92 : 1.055 * powf(c, 1 / 2.4) - 0.055
    }

    /// `decode` of each component.
    public static func decode(_ v: SIMD3<Float>) -> SIMD3<Float> { SIMD3(decode(v.x), decode(v.y), decode(v.z)) }

    /// `encode` of each component.
    public static func encode(_ v: SIMD3<Float>) -> SIMD3<Float> { SIMD3(encode(v.x), encode(v.y), encode(v.z)) }
}

/// How the CPU reference stores the picture between the nodes of a chain (research R4).
public enum ReferenceStorage: Sendable, Equatable {
    /// 8 bits per channel, round(x·255)/255, as the GPU's `.rgba8` intermediates.
    case byte
    /// Half-float per channel (`Float16`), as the GPU's `.rgba16f` intermediates.
    case half
}
