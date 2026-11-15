// TerrainColoring — feature 090 (A12-P02) T-A12-204 (FR-A12-220; clarification 4; research D4; SC-A12-204). The
// per-vertex colour of a world's terrain, a pure function of the height and the preset's palette (sea or void, low land,
// high land), applied in this order:
//
// - asteroid garden, height below −0.5 m: a linear blend from the low-land colour at −0.5 m to the void colour (the
//   palette's sea slot) at −1.0 m, the bottom of `WorldPreset.heightRange` (so the falling edge of the disc fades into
//   the background);
// - island and miniature city (the presets with a sea), height below sea level 0: the low-land colour darkened by 25 %
//   (red, green and blue × 0.75);
// - otherwise: a linear blend from the low-land colour at 0.1 m to the high-land colour at 1.2 m, clamped outside, so
//   0…0.1 m (and, on the asteroid garden, −0.5…0.1 m) is plain low land and everything above 1.2 m plain high land.
//
// Alpha is always 1, every component is clamped into 0…1 and a non-finite height counts as 0 m, so the result always
// suits `MeshRenderer`'s colour stream. The colours do not enter the terrain digest (geometry only).
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// Colours a world's terrain per vertex by height.
public enum TerrainColoring {
    /// Below this height (metres) the asteroid garden starts to blend to its void colour.
    public static let voidStart = -0.5
    /// At and below this height (metres) the asteroid garden is the void colour.
    public static let voidEnd = -1.0
    /// The height (metres) where the low-to-high-land blend starts.
    public static let lowLandTop = 0.1
    /// The height (metres) where the low-to-high-land blend ends.
    public static let highLandBottom = 1.2
    /// The factor applied to red, green and blue of the low-land colour below sea level.
    public static let underwaterShade = 0.75

    /// The colour (RGBA 0…1, alpha 1) of a terrain point at `height` metres in `preset`'s world with `palette` (see
    /// the file header for the bands).
    public static func color(height: Double, palette: Palette, preset: WorldPreset) -> Vec4 {
        let h = height.isFinite ? height : 0
        let low = palette.lowLand, high = palette.highLand
        if preset.id == .asteroidGarden, h < voidStart {
            let t = clamp01((voidStart - h) / (voidStart - voidEnd))
            return rgba(mix(low, palette.sea, t))
        }
        if preset.hasSea, h < WorldPreset.seaLevel {
            return rgba((low.r * underwaterShade, low.g * underwaterShade, low.b * underwaterShade))
        }
        let t = clamp01((h - lowLandTop) / (highLandBottom - lowLandTop))
        return rgba(mix(low, high, t))
    }

    /// One colour per height, in order (see ``color(height:palette:preset:)``).
    public static func colors(heights: [Double], palette: Palette, preset: WorldPreset) -> [Vec4] {
        heights.map { color(height: $0, palette: palette, preset: preset) }
    }

    /// One colour per vertex of `mesh`, from each position's y (the terrain height).
    public static func colors(mesh: Mesh, palette: Palette, preset: WorldPreset) -> [Vec4] {
        mesh.positions.map { color(height: $0.y, palette: palette, preset: preset) }
    }

    /// The linear blend of the colours' red, green and blue, `t` = 0 giving `a` and 1 giving `b`.
    private static func mix(_ a: RGBA, _ b: RGBA, _ t: Double) -> (Double, Double, Double) {
        (a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t)
    }

    /// Red, green and blue clamped into 0…1 (non-finite → 0) with alpha 1.
    private static func rgba(_ c: (Double, Double, Double)) -> Vec4 {
        Vec4(clamp01(c.0), clamp01(c.1), clamp01(c.2), 1)
    }

    /// `x` clamped into 0…1; non-finite gives 0.
    private static func clamp01(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
}
