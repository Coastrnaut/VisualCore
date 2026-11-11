// SceneFamily.swift — the four scene families of Generative Art Studio (feature 012 T-A01-107; FR-A01-101).
import VisualCoreParameters

/// Stable ids of the scene families (also persisted in documents).
public enum SceneFamilyID: String, Codable, Sendable, CaseIterable {
    /// Domain-warped fractal gradient noise.
    case gradientNoise = "gradient-noise"
    /// Raymarched signed-distance shapes.
    case raymarchedShapes = "raymarched-shapes"
    /// Kaleidoscopic geometric tiling.
    case geometricTiling = "geometric-tiling"
    /// A seeded particle fountain over a gradient.
    case particles
}

/// How a family draws: one full-screen fragment shader, or a background shader plus particles.
public enum SceneKind: Sendable, Equatable {
    /// A single fragment shader file.
    case shader(fragment: String)
    /// A background fragment shader plus a particle system.
    case particles(background: String)
}

/// One scene family: content, accessible description, parameter schema, default palette and curated presets.
public struct SceneFamily: Sendable, Identifiable {
    /// Stable id.
    public let id: SceneFamilyID
    /// Gallery title.
    public let title: String
    /// One-line gallery description (also the VoiceOver hint).
    public let summary: String
    /// What the canvas shows, spoken by VoiceOver.
    public let accessibilityDescription: String
    /// SF Symbol shown in the gallery.
    public let symbol: String
    /// How the family draws.
    public let kind: SceneKind
    /// User-adjustable parameters.
    public let schema: ParameterSchema
    /// Palette used when a document names none or an unknown one.
    public let defaultPaletteID: String
    /// Curated starting points (at least one).
    public let presets: [Preset]

    /// The first preset.
    public var defaultPreset: Preset { presets[0] }
}
