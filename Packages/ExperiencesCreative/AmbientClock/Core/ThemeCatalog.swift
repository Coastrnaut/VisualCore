// ThemeCatalog — feature 133 T-A18-303 (FR-A18-301, FR-A18-302, FR-A18-304; SC-A18-301; clarification Q2). The four
// ambient themes, their three curated dark palettes of four sRGB colours each, their per-level element budgets and the
// contrast rule: white text reaches at least 4.5 : 1 against every palette colour. Pure Swift; no UIKit, so the WCAG
// contrast math is mirrored here from VisualCoreUI's `AccessibleColors.contrastRatio`.
import Foundation

/// A named palette of four sRGB-encoded colours (components 0…1), in blend order.
public struct ThemePalette: Equatable, Sendable {
    /// The palette's display name.
    public let name: String
    /// The four colours, sRGB-encoded (0…1) as (red, green, blue).
    public let colors: [SIMD3<Double>]

    /// Creates a palette.
    public init(name: String, colors: [SIMD3<Double>]) {
        self.name = name
        self.colors = colors
    }
}

/// One ambient theme: its stable id, display name, palettes and the count of its drawn elements per quality level.
public struct ThemeInfo: Equatable, Sendable {
    /// The stable id (`noise-gradient`, `particle-drift`, `wave-field` or `sdf-shapes`); used in outcomes.
    public let id: String
    /// The display name.
    public let name: String
    /// The three palettes.
    public let palettes: [ThemePalette]
    /// The element count at each quality level: index 0 is level-0 (full), index 1 is level-1 (reduced).
    public let counts: [Int]
    /// What the count counts (`octaves`, `cells`, `waves` or `shapes`).
    public let countName: String

    /// Creates a theme description.
    public init(id: String, name: String, palettes: [ThemePalette], counts: [Int], countName: String) {
        self.id = id
        self.name = name
        self.palettes = palettes
        self.counts = counts
        self.countName = countName
    }
}

/// The catalog of ambient themes and the contrast rule over their palettes.
public enum ThemeCatalog {
    /// The contrast white overlay text must reach against every palette colour (WCAG AA for normal text).
    public static let requiredContrast = 4.5

    /// The overlay text colour, sRGB-encoded: opaque white.
    public static let white = SIMD3<Double>(1, 1, 1)

    /// The four themes, in `ThemePreset.theme` order. Palette 0 of theme 0 is the A18-P02 noise palette exactly.
    public static let themes: [ThemeInfo] = [
        ThemeInfo(id: "noise-gradient", name: "Noise Gradient", palettes: [
            ThemePalette(name: "Dusk", colors: [
                SIMD3(0.04, 0.06, 0.18),   // midnight blue
                SIMD3(0.14, 0.06, 0.18),   // dusk violet
                SIMD3(0.02, 0.14, 0.15),   // deep teal
                SIMD3(0.10, 0.12, 0.15),   // slate
            ]),
            ThemePalette(name: "Forest", colors: [
                SIMD3(0.03, 0.10, 0.06), SIMD3(0.06, 0.14, 0.08), SIMD3(0.10, 0.12, 0.06), SIMD3(0.04, 0.08, 0.10),
            ]),
            ThemePalette(name: "Ember", colors: [
                SIMD3(0.16, 0.05, 0.04), SIMD3(0.18, 0.08, 0.03), SIMD3(0.12, 0.04, 0.08), SIMD3(0.08, 0.05, 0.06),
            ]),
        ], counts: [5, 3], countName: "octaves"),
        ThemeInfo(id: "particle-drift", name: "Particle Drift", palettes: [
            ThemePalette(name: "Night Sky", colors: [
                SIMD3(0.02, 0.03, 0.10), SIMD3(0.06, 0.08, 0.18), SIMD3(0.12, 0.12, 0.20), SIMD3(0.03, 0.05, 0.12),
            ]),
            ThemePalette(name: "Aurora", colors: [
                SIMD3(0.02, 0.12, 0.10), SIMD3(0.04, 0.16, 0.12), SIMD3(0.08, 0.06, 0.16), SIMD3(0.02, 0.06, 0.08),
            ]),
            ThemePalette(name: "Plum", colors: [
                SIMD3(0.10, 0.04, 0.12), SIMD3(0.16, 0.06, 0.16), SIMD3(0.06, 0.03, 0.08), SIMD3(0.12, 0.08, 0.14),
            ]),
        ], counts: [48, 24], countName: "cells"),
        ThemeInfo(id: "wave-field", name: "Wave Field", palettes: [
            ThemePalette(name: "Deep Sea", colors: [
                SIMD3(0.01, 0.06, 0.12), SIMD3(0.02, 0.10, 0.16), SIMD3(0.04, 0.14, 0.18), SIMD3(0.02, 0.04, 0.08),
            ]),
            ThemePalette(name: "Lagoon", colors: [
                SIMD3(0.02, 0.12, 0.12), SIMD3(0.03, 0.16, 0.14), SIMD3(0.06, 0.10, 0.12), SIMD3(0.01, 0.08, 0.08),
            ]),
            ThemePalette(name: "Storm", colors: [
                SIMD3(0.08, 0.09, 0.12), SIMD3(0.12, 0.13, 0.16), SIMD3(0.05, 0.06, 0.09), SIMD3(0.16, 0.16, 0.18),
            ]),
        ], counts: [6, 3], countName: "waves"),
        ThemeInfo(id: "sdf-shapes", name: "SDF Shapes", palettes: [
            ThemePalette(name: "Graphite", colors: [
                SIMD3(0.06, 0.06, 0.07), SIMD3(0.12, 0.12, 0.13), SIMD3(0.18, 0.18, 0.19), SIMD3(0.09, 0.10, 0.12),
            ]),
            ThemePalette(name: "Indigo", colors: [
                SIMD3(0.06, 0.04, 0.16), SIMD3(0.10, 0.08, 0.20), SIMD3(0.04, 0.06, 0.14), SIMD3(0.14, 0.10, 0.18),
            ]),
            ThemePalette(name: "Moss", colors: [
                SIMD3(0.08, 0.10, 0.04), SIMD3(0.12, 0.14, 0.06), SIMD3(0.05, 0.08, 0.05), SIMD3(0.14, 0.12, 0.08),
            ]),
        ], counts: [8, 4], countName: "shapes"),
    ]

    /// The element count of theme `theme` at quality level `tier` (both clamped to the catalog: theme 0–3, tier 0–1).
    public static func budget(theme: Int, tier: Int) -> Int {
        let info = themes[min(max(theme, 0), themes.count - 1)]
        return info.counts[min(max(tier, 0), info.counts.count - 1)]
    }

    /// The palette `palette` of theme `theme` (both clamped to the catalog).
    public static func palette(theme: Int, palette: Int) -> ThemePalette {
        let info = themes[min(max(theme, 0), themes.count - 1)]
        return info.palettes[min(max(palette, 0), info.palettes.count - 1)]
    }

    /// The WCAG 2 relative luminance of an sRGB-encoded colour: each component linearised
    /// (`c ≤ 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)^2.4`), then `0.2126 R + 0.7152 G + 0.0722 B`.
    public static func relativeLuminance(_ color: SIMD3<Double>) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(color.x) + 0.7152 * linear(color.y) + 0.0722 * linear(color.z)
    }

    /// The WCAG contrast ratio (1…21) between two opaque sRGB-encoded colours: `(L1 + 0.05) / (L2 + 0.05)` with L1
    /// the lighter. The same math as VisualCoreUI's `AccessibleColors.contrastRatio(_:_:)`, which the experience tests
    /// cross-check.
    public static func contrastRatio(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let (l1, l2) = (relativeLuminance(a), relativeLuminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// The smallest contrast of `text` against any of the 48 palette colours.
    public static func minimumContrast(text: SIMD3<Double> = white) -> Double {
        themes.flatMap { $0.palettes.flatMap(\.colors) }.map { contrastRatio(text, $0) }.min() ?? 1
    }

    /// One sentence per palette colour against which `text` falls below ``requiredContrast``; empty when every
    /// colour passes.
    public static func contrastProblems(text: SIMD3<Double> = white) -> [String] {
        var problems: [String] = []
        for info in themes {
            for palette in info.palettes {
                for (index, color) in palette.colors.enumerated() {
                    let ratio = contrastRatio(text, color)
                    if ratio < requiredContrast {
                        problems.append("Theme \(info.id) palette \(palette.name) colour \(index) gives text "
                            + "\(String(format: "%.2f", ratio)) : 1, below \(requiredContrast) : 1.")
                    }
                }
            }
        }
        return problems
    }
}
