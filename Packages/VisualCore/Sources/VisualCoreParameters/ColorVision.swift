// ColorVision — feature 210 (R02-F10) T-R02F10-003 (FR-R02F10-004, FR-R02F10-005, FR-R02F10-006; research R3, R4).
// Colour-vision simulation with the Machado, Oliveira and Fernandes (2009) severity-1.0 matrices in linear sRGB
// (achromatopsia = relative luminance on every channel), a pairwise palette separation check in ΔE_OK and three
// original colour-vision-friendly presets.
import Foundation

/// A colour-vision condition that can be simulated on an sRGB colour.
public enum ColorVisionCondition: String, CaseIterable, Sendable, Codable {
    /// Typical trichromatic vision (identity).
    case normal
    /// No long-wavelength (red) cones.
    case protanopia
    /// No medium-wavelength (green) cones.
    case deuteranopia
    /// No short-wavelength (blue) cones.
    case tritanopia
    /// No colour vision: every channel becomes the Rec. 709 relative luminance.
    case achromatopsia

    /// The three rows of the 3×3 linear-sRGB simulation matrix (Machado 2009, severity 1.0).
    public var matrix: [SIMD3<Double>] {
        switch self {
        case .normal:
            [SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1)]
        case .protanopia:
            [SIMD3(0.152286, 1.052583, -0.204868), SIMD3(0.114503, 0.786281, 0.099216),
             SIMD3(-0.003882, -0.048116, 1.051998)]
        case .deuteranopia:
            [SIMD3(0.367322, 0.860646, -0.227968), SIMD3(0.280085, 0.672501, 0.047413),
             SIMD3(-0.011820, 0.042940, 0.968881)]
        case .tritanopia:
            [SIMD3(1.255528, -0.076749, -0.178779), SIMD3(-0.078411, 0.930809, 0.147602),
             SIMD3(0.004733, 0.691367, 0.303900)]
        case .achromatopsia:
            [SIMD3(0.2126, 0.7152, 0.0722), SIMD3(0.2126, 0.7152, 0.0722), SIMD3(0.2126, 0.7152, 0.0722)]
        }
    }

    /// Simulates this condition on an sRGB colour: decode to linear, multiply by `matrix`, clamp each channel to
    /// 0…1 and encode back to sRGB.
    public func simulate(sRGB c: SIMD3<Double>) -> SIMD3<Double> {
        let l = PerceptualColor.linear(fromSRGB: c), m = matrix
        let r = SIMD3((m[0] * l).sum(), (m[1] * l).sum(), (m[2] * l).sum())
        return PerceptualColor.sRGB(fromLinear: SIMD3(min(max(r.x, 0), 1), min(max(r.y, 0), 1), min(max(r.z, 0), 1)))
    }
}

/// Two colours of a palette that are too close under one condition.
public struct PaletteSeparationIssue: Sendable, Equatable {
    /// Index of the first colour (the smaller index).
    public let first: Int
    /// Index of the second colour.
    public let second: Int
    /// The condition under which they are too close.
    public let condition: ColorVisionCondition
    /// Their ΔE_OK after simulation.
    public let distance: Double

    /// Creates an issue record.
    public init(first: Int, second: Int, condition: ColorVisionCondition, distance: Double) {
        self.first = first
        self.second = second
        self.condition = condition
        self.distance = distance
    }
}

/// The pairwise separation check of a palette under every colour-vision condition.
public enum PaletteSeparation {
    /// The smallest acceptable ΔE_OK between two simulated colours.
    public static let threshold = 0.08

    /// Every pair i < j and every condition (in `allCases` order) whose simulated colours differ by less than
    /// `threshold`, ordered by (i, j, condition).
    public static func issues(_ colors: [SIMD3<Double>]) -> [PaletteSeparationIssue] {
        var result: [PaletteSeparationIssue] = []
        for i in colors.indices {
            for j in colors.indices where j > i {
                for condition in ColorVisionCondition.allCases {
                    let d = PerceptualColor.difference(condition.simulate(sRGB: colors[i]), condition.simulate(sRGB: colors[j]))
                    if d < threshold { result.append(PaletteSeparationIssue(first: i, second: j, condition: condition, distance: d)) }
                }
            }
        }
        return result
    }
}

/// Three original palettes that stay separable under every `ColorVisionCondition`.
///
/// The stops were built from OKLCh ladders (luminance-lightness ∛Y at 0.36, 0.48, 0.60, 0.72, 0.84, 0.95, so that they
/// survive achromatopsia; chroma reduced into gamut), rounded to four decimals and verified by
/// `PaletteSeparation.issues(stops) == []` under all five conditions.
public enum ColorVisionPresets {
    /// Blue (h 255°) on the dark half, orange (h 60°) on the light half.
    public static let warmCool: Palette = try! Palette(id: "cvd-warm-cool", name: "Warm and cool", stops: [
        SIMD3(0.0027, 0.2363, 0.4780), SIMD3(0.1324, 0.3685, 0.6480), SIMD3(0.2752, 0.5092, 0.8007),
        SIMD3(0.8876, 0.5730, 0.2939), SIMD3(0.9968, 0.7411, 0.5327), SIMD3(1.0000, 0.9211, 0.8604),
    ])
    /// Red (h 25°) on the dark half, cyan (h 200°) on the light half.
    public static let redCyan: Palette = try! Palette(id: "cvd-red-cyan", name: "Red and cyan", stops: [
        SIMD3(0.4682, 0.0929, 0.1024), SIMD3(0.6220, 0.2422, 0.2289), SIMD3(0.7798, 0.3837, 0.3606),
        SIMD3(0.0524, 0.7145, 0.7433), SIMD3(0.2175, 0.8738, 0.9058), SIMD3(0.7032, 0.9839, 0.9981),
    ])
    /// A low-chroma (C 0.02, h 250°) lightness ramp.
    public static let lightness: Palette = try! Palette(id: "cvd-lightness", name: "Lightness", stops: [
        SIMD3(0.2087, 0.2431, 0.2797), SIMD3(0.3340, 0.3709, 0.4102), SIMD3(0.4680, 0.5068, 0.5485),
        SIMD3(0.6091, 0.6497, 0.6934), SIMD3(0.7565, 0.7987, 0.8440), SIMD3(0.8965, 0.9400, 0.9868),
    ])
    /// All presets in display order.
    public static let all: [Palette] = [warmCool, redCyan, lightness]
}
