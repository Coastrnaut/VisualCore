// FluidPalette.swift — Ink, Smoke and Glowing dye (feature 022 T-A02-402; FR-A02-401; spec 022 clarification 1).
// The dye field stores per-channel amounts; a palette decides how they look. `displayColor` is the CPU reference of
// the display shader (FluidShaders.display). Palettes are artistic presets, not color-science claims.
import Foundation

/// How dye amounts become display color.
public enum FluidDisplayMode: Int, Sendable, Codable {
    /// `paper × exp(−2·dye)`: subtractive ink on paper.
    case ink = 0
    /// Background mixed toward near-white by `1 − exp(−1.5·luma(dye))`: gray smoke, no hue.
    case smoke = 1
    /// Clamped dye on black, with glow added by the effect graph.
    case glow = 2
}

/// A playground look: background, splat colors and display mode.
public struct FluidPalette: Sendable, Equatable, Identifiable {
    /// Stable id: `ink`, `smoke` or `glow`.
    public let id: String
    /// Display name.
    public let name: String
    /// Display mode (shader `uMode`).
    public let mode: FluidDisplayMode
    /// Background color (display values 0…1).
    public let background: SIMD3<Float>
    /// The six splat colors (dye amounts 0…1), cycled by finger order and splash number.
    public let splatColors: [SIMD3<Float>]
    /// Whether the glow effect is on.
    public var glow: Bool { mode == .glow }

    /// The three palettes, in picker order.
    public static let all: [FluidPalette] = [
        FluidPalette(id: "ink", name: "Ink", mode: .ink, background: SIMD3(0.96, 0.94, 0.88), splatColors: [
            SIMD3(0.90, 0.75, 0.25), SIMD3(0.35, 0.55, 0.75), SIMD3(0.30, 0.90, 0.75),
            SIMD3(0.80, 0.80, 0.80), SIMD3(0.85, 0.40, 0.45), SIMD3(0.50, 0.85, 0.35)]),
        FluidPalette(id: "smoke", name: "Smoke", mode: .smoke, background: SIMD3(0.04, 0.04, 0.05), splatColors: [
            SIMD3(repeating: 0.55), SIMD3(repeating: 0.65), SIMD3(repeating: 0.75),
            SIMD3(repeating: 0.85), SIMD3(repeating: 0.90), SIMD3(repeating: 0.70)]),
        FluidPalette(id: "glow", name: "Glowing dye", mode: .glow, background: SIMD3(0, 0, 0), splatColors: DyeSeed.palette),
    ]

    /// The palette with `id`, or Glowing dye for an unknown id.
    public static func named(_ id: String) -> FluidPalette { all.first { $0.id == id } ?? all[2] }

    /// Near-white that dense smoke approaches.
    public static let smokeWhite: Float = 0.92

    /// The display color of a dye amount (CPU reference of the display shader).
    public func displayColor(dye: SIMD3<Float>) -> SIMD3<Float> {
        let d = SIMD3(max(dye.x, 0), max(dye.y, 0), max(dye.z, 0))
        switch mode {
        case .ink:
            return background * SIMD3(Float(exp(Double(-2 * d.x))), Float(exp(Double(-2 * d.y))), Float(exp(Double(-2 * d.z))))
        case .smoke:
            let luma = 0.2126 * d.x + 0.7152 * d.y + 0.0722 * d.z
            let t = 1 - Float(exp(Double(-1.5 * luma)))
            return background + (SIMD3(repeating: Self.smokeWhite) - background) * t
        case .glow:
            return SIMD3(min(d.x, 1), min(d.y, 1), min(d.z, 1))
        }
    }
}
