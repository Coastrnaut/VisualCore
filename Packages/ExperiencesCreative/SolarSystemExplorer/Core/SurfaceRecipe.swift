// SurfaceRecipe — feature 105 (A14-P03) T-A14-302 (FR-A14-301; SC-A14-301; clarification Q1; research D1; data-model
// "SurfaceRecipe"). One procedural surface per catalog body: a style, a few base colours and thresholds, and a
// ``SphereNoise`` seeded 0xA14_0000 + the body's catalog index. `colors(for:)` gives one ``SurfaceColor`` per vertex
// position, so the experience can colour a `Mesh.uvSphere(segments: 48, rings: 24)` without this core depending on
// VisualCoreScenes: it takes the mesh's positions (`[Vec3]`, any radius) and evaluates every colour at the position's
// unit direction (rounded as ``SphereNoise/unitDirection(_:)`` rounds it). The duplicated seam vertices and the vertices
// of a pole row share a direction and so get identical colours.
//
// Latitude is asin of the unit direction's y component: `Mesh.uvSphere` puts its poles on ±y (MeshGenerators.swift,
// theta 0 at the north pole, y = cos theta). Styles (clarification Q1):
// - `emissive` (the Sun): yellow-orange, brightness 1 ± 8 % from granulation noise.
// - `terrain` (Mercury grey, Venus pale yellow haze, Mars rust with dark patches): the primary colour blends into the
//   secondary as the noise rises from `threshold` over `softness`.
// - `oceanWorld` (Earth): ocean blue below noise 0.52, green to brown land above, white caps where |sin latitude| > 0.88.
// - `banded` (Jupiter 9 bands, Saturn 7 paler bands, Uranus and Neptune faint bands): sin(latitude · k) perturbed by
//   noise blends primary and secondary with the recipe's contrast.
// Every channel is clamped to 0…1; alpha is 1.
//
// The digest is the SHA-256 (``StableHash/sha256Hex(_:)``) of the colours, each channel quantised to a 16-bit integer
// (round(channel × 65,535)) written big-endian in r, g, b, a order. The quantisation keeps the digest stable against
// last-bit differences of the math library between platforms.
import Foundation
import VisualCoreMath

/// A linear RGBA colour with every channel in 0…1.
public struct SurfaceColor: Equatable, Sendable {
    /// Red, 0…1.
    public let r: Double
    /// Green, 0…1.
    public let g: Double
    /// Blue, 0…1.
    public let b: Double
    /// Alpha, 0…1.
    public let a: Double

    /// Creates a colour; every channel is clamped to 0…1 (a non-finite channel becomes 0).
    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = SurfaceColor.clamp(r); self.g = SurfaceColor.clamp(g)
        self.b = SurfaceColor.clamp(b); self.a = SurfaceColor.clamp(a)
    }

    /// Rec. 709 relative luminance of the colour channels (0.2126 r + 0.7152 g + 0.0722 b).
    public var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    /// The linear blend from `self` (t = 0) to `other` (t = 1); t is clamped to 0…1.
    public func mixed(with other: SurfaceColor, _ t: Double) -> SurfaceColor {
        let s = SurfaceColor.clamp(t)
        return SurfaceColor(r: r + (other.r - r) * s, g: g + (other.g - g) * s, b: b + (other.b - b) * s,
                            a: a + (other.a - a) * s)
    }

    /// The colour with r, g and b multiplied by `factor` (clamped to 0…1 again); alpha unchanged.
    public func scaled(_ factor: Double) -> SurfaceColor {
        SurfaceColor(r: r * factor, g: g * factor, b: b * factor, a: a)
    }

    /// The largest absolute channel difference between `self` and `other`.
    public func distance(to other: SurfaceColor) -> Double {
        max(max(abs(r - other.r), abs(g - other.g)), max(abs(b - other.b), abs(a - other.a)))
    }

    static func clamp(_ v: Double) -> Double { v.isFinite ? min(max(v, 0), 1) : 0 }
}

/// How a ``SurfaceRecipe`` turns noise and latitude into colour.
public enum SurfaceStyle: String, CaseIterable, Sendable {
    /// Self-lit (the Sun): primary colour with ± `variation` granulation.
    case emissive
    /// Rocky or hazy: primary blends into secondary as the noise rises over `threshold`.
    case terrain
    /// Latitude bands of sin(latitude · bands) perturbed by noise.
    case banded
    /// Ocean below `threshold`, land (secondary → tertiary) above, white polar caps beyond `capLimit`.
    case oceanWorld
}

/// The procedural surface of one catalog body (clarification Q1).
public struct SurfaceRecipe: Equatable, Sendable {
    /// The seed of body index 0; body i uses `seedBase + i`.
    public static let seedBase: UInt64 = 0xA14_0000

    /// The body's catalog id.
    public let bodyID: String
    /// The noise seed (``seedBase`` + catalog index).
    public let seed: UInt64
    /// The colouring style.
    public let style: SurfaceStyle
    /// The main colour (Sun base, terrain low, ocean, band light).
    public let primary: SurfaceColor
    /// The second colour (terrain high, land green, band dark).
    public let secondary: SurfaceColor
    /// The third colour (land brown for `oceanWorld`; polar caps use white).
    public let tertiary: SurfaceColor
    /// Noise threshold (terrain blend start, ocean/land boundary).
    public let threshold: Double
    /// Noise span of the terrain blend and the land green → brown blend.
    public let softness: Double
    /// Granulation amplitude of `emissive` (0.08 = ± 8 %).
    public let variation: Double
    /// Number of latitude bands k of `banded` (sin(latitude · k)).
    public let bands: Int
    /// Band contrast of `banded`, 0…1 (1 full primary ↔ secondary swing).
    public let contrast: Double
    /// Noise perturbation of the band phase, radians per unit of (noise − 0.5).
    public let perturbation: Double
    /// |sin latitude| above which `oceanWorld` draws white caps.
    public let capLimit: Double
    /// The seeded noise (frequency per recipe).
    public let noise: SphereNoise

    /// Creates a recipe from all of its fields; `seed` also seeds ``noise``.
    public init(bodyID: String, seed: UInt64, style: SurfaceStyle, primary: SurfaceColor, secondary: SurfaceColor,
                tertiary: SurfaceColor, threshold: Double = 0.5, softness: Double = 0.1, variation: Double = 0,
                bands: Int = 0, contrast: Double = 0, perturbation: Double = 0, capLimit: Double = 1,
                frequency: Double = 3) {
        self.bodyID = bodyID; self.seed = seed; self.style = style
        self.primary = primary; self.secondary = secondary; self.tertiary = tertiary
        self.threshold = threshold; self.softness = softness > 0 ? softness : 0.1; self.variation = variation
        self.bands = bands; self.contrast = contrast; self.perturbation = perturbation; self.capLimit = capLimit
        self.noise = SphereNoise(seed: seed, frequency: frequency)
    }

    /// The nine recipes in catalog order (sun, mercury, venus, earth, mars, jupiter, saturn, uranus, neptune).
    public static let bundled: [SurfaceRecipe] = [
        SurfaceRecipe(bodyID: "sun", seed: seedBase + 0, style: .emissive,
                      primary: SurfaceColor(r: 1.0, g: 0.78, b: 0.32), secondary: SurfaceColor(r: 1.0, g: 0.62, b: 0.18),
                      tertiary: SurfaceColor(r: 1.0, g: 0.9, b: 0.6), variation: 0.08, frequency: 8),
        SurfaceRecipe(bodyID: "mercury", seed: seedBase + 1, style: .terrain,
                      primary: SurfaceColor(r: 0.66, g: 0.64, b: 0.62), secondary: SurfaceColor(r: 0.36, g: 0.35, b: 0.34),
                      tertiary: SurfaceColor(r: 0.5, g: 0.5, b: 0.5), threshold: 0.35, softness: 0.3, frequency: 5),
        SurfaceRecipe(bodyID: "venus", seed: seedBase + 2, style: .terrain,
                      primary: SurfaceColor(r: 0.95, g: 0.89, b: 0.66), secondary: SurfaceColor(r: 0.86, g: 0.77, b: 0.52),
                      tertiary: SurfaceColor(r: 0.9, g: 0.84, b: 0.6), threshold: 0.3, softness: 0.4, frequency: 2),
        SurfaceRecipe(bodyID: "earth", seed: seedBase + 3, style: .oceanWorld,
                      primary: SurfaceColor(r: 0.07, g: 0.24, b: 0.58), secondary: SurfaceColor(r: 0.2, g: 0.46, b: 0.18),
                      tertiary: SurfaceColor(r: 0.52, g: 0.4, b: 0.24), threshold: 0.52, softness: 0.12,
                      capLimit: 0.88, frequency: 2.5),
        SurfaceRecipe(bodyID: "mars", seed: seedBase + 4, style: .terrain,
                      primary: SurfaceColor(r: 0.76, g: 0.37, b: 0.19), secondary: SurfaceColor(r: 0.38, g: 0.2, b: 0.12),
                      tertiary: SurfaceColor(r: 0.6, g: 0.3, b: 0.16), threshold: 0.55, softness: 0.08, frequency: 3),
        SurfaceRecipe(bodyID: "jupiter", seed: seedBase + 5, style: .banded,
                      primary: SurfaceColor(r: 0.93, g: 0.86, b: 0.73), secondary: SurfaceColor(r: 0.66, g: 0.48, b: 0.34),
                      tertiary: SurfaceColor(r: 0.8, g: 0.6, b: 0.45), bands: 9, contrast: 1, perturbation: 2.5,
                      frequency: 3),
        SurfaceRecipe(bodyID: "saturn", seed: seedBase + 6, style: .banded,
                      primary: SurfaceColor(r: 0.96, g: 0.91, b: 0.76), secondary: SurfaceColor(r: 0.84, g: 0.76, b: 0.57),
                      tertiary: SurfaceColor(r: 0.9, g: 0.84, b: 0.66), bands: 7, contrast: 0.7, perturbation: 1.5,
                      frequency: 3),
        SurfaceRecipe(bodyID: "uranus", seed: seedBase + 7, style: .banded,
                      primary: SurfaceColor(r: 0.62, g: 0.87, b: 0.91), secondary: SurfaceColor(r: 0.52, g: 0.78, b: 0.84),
                      tertiary: SurfaceColor(r: 0.6, g: 0.85, b: 0.9), bands: 5, contrast: 0.25, perturbation: 1,
                      frequency: 2),
        SurfaceRecipe(bodyID: "neptune", seed: seedBase + 8, style: .banded,
                      primary: SurfaceColor(r: 0.22, g: 0.38, b: 0.82), secondary: SurfaceColor(r: 0.14, g: 0.26, b: 0.66),
                      tertiary: SurfaceColor(r: 0.2, g: 0.34, b: 0.76), bands: 6, contrast: 0.35, perturbation: 1.2,
                      frequency: 2),
    ]

    /// The recipe of the body with `bodyID`, or nil for an unknown id.
    public static func recipe(bodyID: String) -> SurfaceRecipe? { bundled.first { $0.bodyID == bodyID } }

    /// The colour at the direction of `position` (any length). A non-finite or zero position is coloured as the
    /// north pole (+y).
    public func color(at position: Vec3) -> SurfaceColor {
        let d = SphereNoise.unitDirection(position) ?? Vec3(0, 1, 0)
        let n = noise.value(at: d)
        let sinLatitude = min(max(d.y, -1), 1)
        switch style {
        case .emissive:
            return primary.scaled(1 + 2 * variation * (n - 0.5))
        case .terrain:
            return primary.mixed(with: secondary, (n - threshold) / softness)
        case .oceanWorld:
            if abs(sinLatitude) > capLimit { return SurfaceColor(r: 0.94, g: 0.95, b: 0.97) }
            if n < threshold {
                let depth = (threshold - n) / threshold
                return primary.scaled(1 - 0.35 * depth)
            }
            return secondary.mixed(with: tertiary, (n - threshold) / softness)
        case .banded:
            let latitude = asin(sinLatitude)
            let wave = sin(latitude * Double(bands) + perturbation * (n - 0.5))
            return primary.mixed(with: secondary, 0.5 + 0.5 * contrast * wave)
        }
    }

    /// One colour per vertex position, in the order given (each channel 0…1).
    public func colors(for positions: [Vec3]) -> [SurfaceColor] {
        var result: [SurfaceColor] = []
        result.reserveCapacity(positions.count)
        for position in positions { result.append(color(at: position)) }
        return result
    }

    /// The colours of `positions` as 64 lower-case hexadecimal digits (see the file header for the byte layout).
    public func digest(for positions: [Vec3]) -> String {
        SurfaceRecipe.digest(of: colors(for: positions))
    }

    /// The SHA-256 hex of `colors`, each channel as round(channel × 65,535) in two big-endian bytes, r, g, b, a order.
    public static func digest(of colors: [SurfaceColor]) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(colors.count * 8)
        for color in colors {
            for channel in [color.r, color.g, color.b, color.a] {
                let q = UInt16((SurfaceColor.clamp(channel) * 65_535).rounded())
                bytes.append(UInt8(q >> 8)); bytes.append(UInt8(q & 0xFF))
            }
        }
        return StableHash.sha256Hex(bytes)
    }
}
