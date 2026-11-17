// SceneCatalog — feature 138 (A19-P01) T-A19-103 (FR-A19-101; clarification Q2). The fixed, curated catalog of four
// procedural scenes: each has a stable id, a name, two or three bounded parameters and three presets of four opaque
// sRGB colours. Every scene and colour is written in this repository; nothing here draws (A19-P02 adds the shaders).
import Foundation

/// An opaque sRGB colour with components in 0…1. There is no alpha component, so every colour is opaque by
/// construction.
public struct RGBColor: Codable, Equatable, Hashable, Sendable {
    /// The red component, in 0…1.
    public let r: Double
    /// The green component, in 0…1.
    public let g: Double
    /// The blue component, in 0…1.
    public let b: Double

    /// Creates a colour; each component is clamped to 0…1 (a non-finite component becomes 0).
    public init(r: Double, g: Double, b: Double) {
        self.r = Self.clamp(r)
        self.g = Self.clamp(g)
        self.b = Self.clamp(b)
    }

    /// Creates a colour from a 24-bit `0xRRGGBB` value.
    public init(hex: UInt32) {
        self.init(r: Double((hex >> 16) & 0xFF) / 255, g: Double((hex >> 8) & 0xFF) / 255, b: Double(hex & 0xFF) / 255)
    }

    private static func clamp(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }
}

/// One bounded numeric parameter of a scene, with `minimum < maximum` and `minimum ≤ defaultValue ≤ maximum`.
public struct SceneParameter: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// The stable id within its scene (for example `bandCount`).
    public let id: String
    /// The display name.
    public let name: String
    /// The smallest allowed value.
    public let minimum: Double
    /// The largest allowed value.
    public let maximum: Double
    /// The value a new project uses.
    public let defaultValue: Double

    /// Creates a parameter. The catalog's tests check the documented range invariants.
    public init(id: String, name: String, minimum: Double, maximum: Double, defaultValue: Double) {
        self.id = id
        self.name = name
        self.minimum = minimum
        self.maximum = maximum
        self.defaultValue = defaultValue
    }

    /// True when `value` is finite and in `minimum…maximum`.
    public func accepts(_ value: Double) -> Bool {
        value.isFinite && value >= minimum && value <= maximum
    }
}

/// A named palette of exactly four opaque colours, ordered from the deepest to the lightest tone.
public struct ColorPreset: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// The stable id within its scene (for example `polar-night`).
    public let id: String
    /// The display name.
    public let name: String
    /// The four colours.
    public let colors: [RGBColor]

    /// Creates a preset from four colours.
    public init(id: String, name: String, colors: [RGBColor]) {
        self.id = id
        self.name = name
        self.colors = colors
    }
}

/// A curated procedural scene: its id, name, parameters and colour presets.
public struct SceneDefinition: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// The stable id: `aurora-bands`, `ink-flow`, `soft-cells` or `ripple-dunes`.
    public let id: String
    /// The display name.
    public let name: String
    /// Two or three parameters, in display order.
    public let parameters: [SceneParameter]
    /// Three colour presets; a project refers to one by its index.
    public let presets: [ColorPreset]

    /// Creates a scene definition.
    public init(id: String, name: String, parameters: [SceneParameter], presets: [ColorPreset]) {
        self.id = id
        self.name = name
        self.parameters = parameters
        self.presets = presets
    }

    /// The parameter with `id`, or nil.
    public func parameter(_ id: String) -> SceneParameter? {
        parameters.first { $0.id == id }
    }

    /// Every parameter id mapped to its default value.
    public var defaultParameters: [String: Double] {
        Dictionary(uniqueKeysWithValues: parameters.map { ($0.id, $0.defaultValue) })
    }
}

/// The fixed catalog of curated scenes, in catalog order.
public enum SceneCatalog {
    /// The four scenes in catalog order: aurora-bands, ink-flow, soft-cells, ripple-dunes.
    public static let scenes: [SceneDefinition] = [auroraBands, inkFlow, softCells, rippleDunes]

    /// The scene with `id`, or nil when the catalog has none.
    public static func scene(id: String) -> SceneDefinition? {
        scenes.first { $0.id == id }
    }

    private static func preset(_ id: String, _ name: String, _ hex: [UInt32]) -> ColorPreset {
        ColorPreset(id: id, name: name, colors: hex.map { RGBColor(hex: $0) })
    }

    private static func parameter(_ id: String, _ name: String, _ minimum: Double, _ maximum: Double,
                                  _ defaultValue: Double) -> SceneParameter {
        SceneParameter(id: id, name: name, minimum: minimum, maximum: maximum, defaultValue: defaultValue)
    }

    /// Soft vertical light bands.
    private static let auroraBands = SceneDefinition(
        id: "aurora-bands", name: "Aurora Bands",
        parameters: [
            parameter("bandCount", "Bands", 2, 8, 4),
            parameter("drift", "Drift", 0, 1, 0.35),
            parameter("softness", "Softness", 0.1, 1, 0.6),
        ],
        presets: [
            preset("polar-night", "Polar Night", [0x0B1D33, 0x1F6F78, 0x3FC1A5, 0xB8F2D0]),
            preset("borealis-rose", "Borealis Rose", [0x1A1030, 0x5B2A6E, 0xC75C8C, 0xF4B6C2]),
            preset("glacier-dawn", "Glacier Dawn", [0x14233C, 0x3E6A9A, 0x8FC1E3, 0xF2E8CF]),
        ])

    /// Domain-warped noise, like ink spreading in water.
    private static let inkFlow = SceneDefinition(
        id: "ink-flow", name: "Ink Flow",
        parameters: [
            parameter("warp", "Warp", 0, 2, 0.8),
            parameter("scale", "Scale", 0.5, 4, 1.5),
            parameter("flowSpeed", "Flow", 0, 1, 0.25),
        ],
        presets: [
            preset("sumi", "Sumi", [0x101418, 0x2E3A46, 0x6B7B8A, 0xE8E4DA]),
            preset("indigo-wash", "Indigo Wash", [0x0E1A40, 0x23408E, 0x5C7FCF, 0xD7E1F5]),
            preset("saffron-ink", "Saffron Ink", [0x2B1408, 0x8C3B12, 0xD9822B, 0xF6D8A8]),
        ])

    /// Voronoi cells with soft edges.
    private static let softCells = SceneDefinition(
        id: "soft-cells", name: "Soft Cells",
        parameters: [
            parameter("cellCount", "Cells", 4, 40, 14),
            parameter("edgeSoftness", "Edge softness", 0, 1, 0.5),
        ],
        presets: [
            preset("sea-glass", "Sea Glass", [0x0F2E2E, 0x3E8077, 0x9CCFB8, 0xE6F4EA]),
            preset("terracotta", "Terracotta", [0x3A1F17, 0xA0522D, 0xD99A6C, 0xF3E0CC]),
            preset("lavender-field", "Lavender Field", [0x2A2240, 0x6A5A9E, 0xB3A6DA, 0xEEE8F7]),
        ])

    /// Layered sine dunes.
    private static let rippleDunes = SceneDefinition(
        id: "ripple-dunes", name: "Ripple Dunes",
        parameters: [
            parameter("layerCount", "Layers", 2, 7, 4),
            parameter("amplitude", "Amplitude", 0.05, 0.5, 0.2),
            parameter("wavelength", "Wavelength", 0.2, 2, 0.8),
        ],
        presets: [
            preset("desert-noon", "Desert Noon", [0x5E3A1E, 0xB9783F, 0xE3B36F, 0xF8E6C4]),
            preset("dusk-dunes", "Dusk Dunes", [0x231942, 0x5E3C6E, 0xC0677A, 0xF2A97E]),
            preset("moon-sand", "Moon Sand", [0x1C1F26, 0x4A505C, 0x9AA1AB, 0xDCDFE3]),
        ])
}
