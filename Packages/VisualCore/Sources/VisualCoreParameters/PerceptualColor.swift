// PerceptualColor — feature 210 (R02-F10) T-R02F10-002 (FR-R02F10-001, FR-R02F10-002, FR-R02F10-003, FR-R02F10-011,
// FR-R02F10-013; research R1, R2). Pure colour arithmetic: the exact sRGB transfer, OKLab and OKLCh (Ottosson 2020,
// M1/M2 for linear sRGB), Rec. 709 relative luminance, the WCAG contrast ratio, the OKLab difference ΔE_OK, a hue
// rotation that keeps lightness, chroma bisection into the sRGB gamut and a black-or-white outline choice.
import Foundation

/// Perceptual colour conversions and measures on `SIMD3<Double>` colours (see the file header).
///
/// sRGB and linear colours are (r, g, b) with components 0…1; OKLab is (L, a, b); OKLCh is (L, C, h) with h in
/// radians, 0 ..< 2π.
public enum PerceptualColor {
    /// Ottosson's M1: linear sRGB → LMS.
    private static let m1: [SIMD3<Double>] = [
        SIMD3(0.4122214708, 0.5363325363, 0.0514459929),
        SIMD3(0.2119034982, 0.6806995451, 0.1073969566),
        SIMD3(0.0883024619, 0.2817188376, 0.6299787005),
    ]
    /// Ottosson's M2: cube-rooted LMS → OKLab.
    private static let m2: [SIMD3<Double>] = [
        SIMD3(0.2104542553, 0.7936177850, -0.0040720468),
        SIMD3(1.9779984951, -2.4285922050, 0.4505937099),
        SIMD3(0.0259040371, 0.7827717662, -0.8086757660),
    ]
    /// The exact inverses, so that a round trip is limited only by floating-point rounding.
    private static let m1Inverse = invert(m1)
    private static let m2Inverse = invert(m2)
    /// Chroma below this is treated as grey (hue undefined).
    private static let greyChroma = 1e-12
    /// Per-channel tolerance of the linear gamut test.
    private static let gamutTolerance = 1e-12

    private static func multiply(_ m: [SIMD3<Double>], _ v: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3((m[0] * v).sum(), (m[1] * v).sum(), (m[2] * v).sum())
    }

    private static func invert(_ m: [SIMD3<Double>]) -> [SIMD3<Double>] {
        let (a, b, c) = (m[0].x, m[0].y, m[0].z), (d, e, f) = (m[1].x, m[1].y, m[1].z), (g, h, i) = (m[2].x, m[2].y, m[2].z)
        let det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
        return [
            SIMD3(e * i - f * h, c * h - b * i, b * f - c * e) / det,
            SIMD3(f * g - d * i, a * i - c * g, c * d - a * f) / det,
            SIMD3(d * h - e * g, b * g - a * h, a * e - b * d) / det,
        ]
    }

    /// Decodes an sRGB colour to linear light with the exact sRGB transfer function, per component.
    public static func linear(fromSRGB c: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(Palette.linear(fromSRGB: c.x), Palette.linear(fromSRGB: c.y), Palette.linear(fromSRGB: c.z))
    }

    /// Encodes a linear-light colour to sRGB with the exact sRGB transfer function, per component.
    public static func sRGB(fromLinear c: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(Palette.sRGB(fromLinear: c.x), Palette.sRGB(fromLinear: c.y), Palette.sRGB(fromLinear: c.z))
    }

    /// Converts a linear sRGB colour to OKLab (M1, sign-preserving cube root, M2).
    public static func oklab(fromLinear c: SIMD3<Double>) -> SIMD3<Double> {
        let lms = multiply(m1, c)
        return multiply(m2, SIMD3(cbrt(lms.x), cbrt(lms.y), cbrt(lms.z)))
    }

    /// Converts an OKLab colour to linear sRGB (inverse M2, cube, inverse M1); the result may leave 0…1.
    public static func linear(fromOklab c: SIMD3<Double>) -> SIMD3<Double> {
        let root = multiply(m2Inverse, c)
        return multiply(m1Inverse, root * root * root)
    }

    /// Converts OKLab to OKLCh: L, chroma C = √(a² + b²) and hue h in radians, 0 ..< 2π (0 when C < 1e-12).
    public static func oklch(fromOklab c: SIMD3<Double>) -> SIMD3<Double> {
        let chroma = (c.y * c.y + c.z * c.z).squareRoot()
        guard chroma >= greyChroma else { return SIMD3(c.x, chroma, 0) }
        var hue = atan2(c.z, c.y)
        if hue < 0 { hue += 2 * Double.pi }
        if hue >= 2 * Double.pi { hue = 0 }
        return SIMD3(c.x, chroma, hue)
    }

    /// Converts OKLCh (L, C, h in radians) to OKLab.
    public static func oklab(fromOklch c: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(c.x, c.y * cos(c.z), c.y * sin(c.z))
    }

    /// The relative luminance Y of an sRGB colour: 0.2126 R + 0.7152 G + 0.0722 B on linear components (Rec. 709).
    public static func relativeLuminance(sRGB c: SIMD3<Double>) -> Double {
        (SIMD3(0.2126, 0.7152, 0.0722) * linear(fromSRGB: c)).sum()
    }

    /// The perceptual lightness of an sRGB colour: its OKLab L.
    public static func lightness(sRGB c: SIMD3<Double>) -> Double {
        oklab(fromLinear: linear(fromSRGB: c)).x
    }

    /// The WCAG contrast ratio (L1 + 0.05) / (L2 + 0.05) of two sRGB colours, the lighter on top; 1 … 21.
    public static func contrastRatio(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let ya = relativeLuminance(sRGB: a), yb = relativeLuminance(sRGB: b)
        return (max(ya, yb) + 0.05) / (min(ya, yb) + 0.05)
    }

    /// The perceptual difference ΔE_OK of two sRGB colours: the Euclidean distance of their OKLab values.
    public static func difference(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = oklab(fromLinear: linear(fromSRGB: a)) - oklab(fromLinear: linear(fromSRGB: b))
        return (d * d).sum().squareRoot()
    }

    /// Rotates the OKLCh hue of an sRGB colour by `radians`, keeping L and C, and brings the result into the sRGB
    /// gamut with `intoGamut(oklch:)` (constant L and h). Greys (r = g = b, or C < 1e-12) are returned unchanged.
    ///
    /// - Throws: `ColorAccessError.nonFinite(index: 0)` for a non-finite component or angle and
    ///   `ColorAccessError.outOfRange(index: 0)` for a component outside 0…1.
    public static func rotateHue(sRGB c: SIMD3<Double>, by radians: Double) throws(ColorAccessError) -> SIMD3<Double> {
        guard c.x.isFinite, c.y.isFinite, c.z.isFinite, radians.isFinite else { throw .nonFinite(index: 0) }
        guard (0...1).contains(c.x), (0...1).contains(c.y), (0...1).contains(c.z) else { throw .outOfRange(index: 0) }
        // Ottosson's published M2 rows do not cancel exactly (white has b ≈ 3.7e-8), so an sRGB grey (r = g = b) has
        // a chroma of up to about 4e-8; it is recognised by its equal channels as well as by C < 1e-12.
        guard !(c.x == c.y && c.y == c.z) else { return c }
        let lch = oklch(fromOklab: oklab(fromLinear: linear(fromSRGB: c)))
        guard lch.y >= greyChroma else { return c }
        var hue = (lch.z + radians).truncatingRemainder(dividingBy: 2 * Double.pi)
        if hue < 0 { hue += 2 * Double.pi }
        let mapped = intoGamut(oklch: SIMD3(lch.x, lch.y, hue))
        let out = sRGB(fromLinear: linear(fromOklab: oklab(fromOklch: mapped)))
        return clamp01(out)
    }

    private static func clamp01(_ v: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(min(max(v.x, 0), 1), min(max(v.y, 0), 1), min(max(v.z, 0), 1))
    }

    private static func inGamut(_ lch: SIMD3<Double>) -> Bool {
        let l = linear(fromOklab: oklab(fromOklch: lch))
        let lo = -gamutTolerance, hi = 1 + gamutTolerance
        return l.x >= lo && l.x <= hi && l.y >= lo && l.y <= hi && l.z >= lo && l.z <= hi
    }

    /// Brings an OKLCh colour into the sRGB gamut at constant L and h.
    ///
    /// A colour whose linear sRGB lies within [−1e-12, 1 + 1e-12] per channel is returned unchanged; otherwise the
    /// chroma is bisected between 0 and C for exactly 24 steps and the largest in-gamut chroma found is kept.
    public static func intoGamut(oklch c: SIMD3<Double>) -> SIMD3<Double> {
        if inGamut(c) { return c }
        var lo = 0.0, hi = c.y
        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            if inGamut(SIMD3(c.x, mid, c.z)) { lo = mid } else { hi = mid }
        }
        return SIMD3(c.x, lo, c.z)
    }

    /// Black (0, 0, 0) or white (1, 1, 1), whichever has the larger minimum WCAG contrast with both `color` and
    /// `background`; a tie gives black.
    public static func outline(for color: SIMD3<Double>, on background: SIMD3<Double>) -> SIMD3<Double> {
        let black = SIMD3<Double>(0, 0, 0), white = SIMD3<Double>(1, 1, 1)
        let onBlack = min(contrastRatio(black, color), contrastRatio(black, background))
        let onWhite = min(contrastRatio(white, color), contrastRatio(white, background))
        return onWhite > onBlack ? white : black
    }

    /// The two-ring outline of a clue (FR-R02F10-013; T-R02F10-017): `inner` is black or white, whichever contrasts
    /// more with `color` (always at least √21 ≈ 4.58:1); `outer` is the opposite of `inner`, drawn around it only when
    /// `inner` is below 3:1 against `background`, so the outermost ring always reaches 3:1 against the background.
    public static func outlineRings(for color: SIMD3<Double>, on background: SIMD3<Double>)
        -> (inner: SIMD3<Double>, outer: SIMD3<Double>?) {
        let black = SIMD3<Double>(0, 0, 0), white = SIMD3<Double>(1, 1, 1)
        let inner = contrastRatio(white, color) > contrastRatio(black, color) ? white : black
        guard contrastRatio(inner, background) < 3 else { return (inner, nil) }
        return (inner, inner == white ? black : white)
    }
}
