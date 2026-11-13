// FamilyCatalog.swift — the app's content: four families with schemas and presets, and the palettes offered
// (feature 012 T-A01-107; FR-A01-101). Shaders: Apps/GenerativeArtStudio/Shaders/*.frag.
import VisualCoreParameters

/// The Generative Art Studio catalog.
public enum FamilyCatalog {
    // The definitions below are constants checked by tests; a bad literal is a programming error.
    private static func p(_ name: String, _ title: String, _ unit: String, _ range: ClosedRange<Double>, _ d: Double,
                          _ t: ParameterTransform = .linear) -> ParameterDefinition {
        try! ParameterDefinition(name: name, title: title, unit: unit, range: range, defaultValue: d, transform: t)
    }
    private static func schema(_ defs: [ParameterDefinition]) -> ParameterSchema { try! ParameterSchema(defs) }

    /// Palettes the app offers (the VisualCore built-ins).
    public static let palettes: [Palette] = Palette.builtIns

    /// The palette with `id`, if offered.
    public static func palette(_ id: String) -> Palette? { palettes.first { $0.id == id } }

    /// The four families in gallery order.
    public static let all: [SceneFamily] = [
        SceneFamily(
            id: .gradientNoise, title: "Gradient Noise", summary: "Flowing, domain-warped fractal noise mapped through a palette.",
            accessibilityDescription: "Soft clouds of color that swirl and fold into each other.", symbol: "cloud.fill",
            kind: .shader(fragment: "gradient-noise.frag"),
            schema: schema([p("scale", "Scale", "×", 0.5...16, 3, .logarithmic), p("octaves", "Detail", "octaves", 1...8, 5),
                            p("warp", "Warp", "", 0...2, 0.8), p("speed", "Speed", "×", 0...2, 0.15), p("contrast", "Contrast", "×", 0.5...2, 1)]),
            defaultPaletteID: "sunset",
            presets: [Preset(id: "noise-dusk", title: "Dusk", seed: 7, paletteID: "sunset", values: ["scale": 3, "warp": 0.8]),
                      Preset(id: "noise-tide", title: "Tide", seed: 2024, paletteID: "ocean", values: ["scale": 6, "warp": 1.4, "octaves": 6])]),
        SceneFamily(
            id: .raymarchedShapes, title: "Raymarched Shapes", summary: "Soft-blended 3D forms lit and shaded in real time.",
            accessibilityDescription: "Smooth glossy blobs merge and separate as they slowly rotate.", symbol: "circle.hexagongrid.fill",
            kind: .shader(fragment: "raymarched-shapes.frag"),
            schema: schema([p("blend", "Blend", "", 0.05...1, 0.35), p("rotation", "Rotation", "rad/s", 0...2, 0.3),
                            p("zoom", "Zoom", "×", 0.5...2, 1), p("glow", "Glow", "", 0...1, 0.4)]),
            defaultPaletteID: "ocean",
            presets: [Preset(id: "shapes-pearl", title: "Pearl", seed: 11, paletteID: "ocean", values: [:]),
                      Preset(id: "shapes-magma", title: "Magma", seed: 99, paletteID: "ember", values: ["blend": 0.7, "glow": 0.8])]),
        SceneFamily(
            id: .geometricTiling, title: "Geometric Tiling", summary: "Kaleidoscopic tiles with crisp lines and rotational symmetry.",
            accessibilityDescription: "A grid of sharp-edged star tiles in bright colors, slowly twisting.", symbol: "square.grid.3x3.fill",
            kind: .shader(fragment: "geometric-tiling.frag"),
            schema: schema([p("cells", "Cells", "per side", 2...24, 6), p("symmetry", "Symmetry", "fold", 3...12, 6),
                            p("lineWidth", "Line width", "", 0.01...0.2, 0.05), p("twist", "Twist", "rad", 0...3.14159, 0.5),
                            p("speed", "Speed", "×", 0...2, 0.1)]),
            defaultPaletteID: "neon",
            presets: [Preset(id: "tiles-neon", title: "Neon Grid", seed: 3, paletteID: "neon", values: [:]),
                      Preset(id: "tiles-ink", title: "Ink", seed: 42, paletteID: "mono", values: ["cells": 10, "symmetry": 8, "lineWidth": 0.02])]),
        SceneFamily(
            id: .particles, title: "Particles", summary: "A seeded fountain of glowing particles under gravity.",
            accessibilityDescription: "Glowing sparks rise from the bottom center, arc over and fall back down over a dark gradient.",
            symbol: "sparkles", kind: .particles(background: "particles-background.frag"),
            schema: schema([p("count", "Particles per second", "/s", 50...2000, 600, .logarithmic), p("gravity", "Gravity", "pt/s²", -400...400, -160),
                            p("spread", "Spread", "rad", 0.05...3.14159, 0.6), p("speed", "Launch speed", "pt/s", 20...500, 260),
                            p("size", "Size", "pt", 1...24, 7), p("drag", "Drag", "/s", 0...2, 0.3)]),
            defaultPaletteID: "ember",
            presets: [Preset(id: "particles-fountain", title: "Fountain", seed: 5, paletteID: "ember", values: [:]),
                      Preset(id: "particles-burst", title: "Burst", seed: 77, paletteID: "neon", values: ["spread": 2.5, "speed": 180, "gravity": -60])]),
    ]

    /// The family with `id`.
    public static func family(_ id: SceneFamilyID) -> SceneFamily { all.first { $0.id == id }! }
}
