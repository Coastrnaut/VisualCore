// SkyPresets — feature 152 (A21-P01) T-A21-103 (FR-A21-103; clarification Q1). The three procedural sky presets of
// Aurora: `polar-night` (deep blue sky, green ribbons, many stars), `violet-veil` (violet and rose ribbons, light
// clouds) and `dawn-haze` (warm haze, fewer stars, more clouds); each version 1 and written for VisualCore. Pure
// Foundation; the presets are data, nothing here draws.
import Foundation

/// One sky preset: a stable id, a display name, its version, its attribution and the scene it starts.
public struct SkyPreset: Equatable, Sendable {
    /// The stable id (for example `polar-night`).
    public let id: String
    /// The display name.
    public let name: String
    /// The preset's version (1 in this phase).
    public let version: Int
    /// Who wrote the preset (`written for VisualCore`).
    public let attribution: String
    /// The scene the preset starts; its ``SkyScene/preset`` is ``id``.
    public let scene: SkyScene
}

/// The catalog of sky presets, with a lookup by id.
public enum SkyPresets {
    /// The attribution of every preset in this phase.
    public static let attribution = "written for VisualCore"

    /// `polar-night`: a deep blue sky with green ribbons and many stars.
    public static let polarNight = SkyPreset(
        id: "polar-night", name: "Polar night", version: 1, attribution: attribution,
        scene: SkyScene(preset: "polar-night",
                        palette: [SkyColor(red: 0.02, green: 0.04, blue: 0.14),
                                  SkyColor(red: 0.20, green: 0.85, blue: 0.45),
                                  SkyColor(red: 0.10, green: 0.60, blue: 0.50)],
                        ribbons: 3, turbulence: 0.45, cloudiness: 0.10, stars: 320, speed: 1.0))

    /// `violet-veil`: violet and rose ribbons with light clouds.
    public static let violetVeil = SkyPreset(
        id: "violet-veil", name: "Violet veil", version: 1, attribution: attribution,
        scene: SkyScene(preset: "violet-veil",
                        palette: [SkyColor(red: 0.05, green: 0.03, blue: 0.12),
                                  SkyColor(red: 0.55, green: 0.30, blue: 0.85),
                                  SkyColor(red: 0.90, green: 0.40, blue: 0.60),
                                  SkyColor(red: 0.40, green: 0.20, blue: 0.70)],
                        ribbons: 2, turbulence: 0.60, cloudiness: 0.30, stars: 200, speed: 0.8))

    /// `dawn-haze`: a warm haze with fewer stars and more clouds.
    public static let dawnHaze = SkyPreset(
        id: "dawn-haze", name: "Dawn haze", version: 1, attribution: attribution,
        scene: SkyScene(preset: "dawn-haze",
                        palette: [SkyColor(red: 0.16, green: 0.10, blue: 0.14),
                                  SkyColor(red: 0.95, green: 0.60, blue: 0.40),
                                  SkyColor(red: 0.85, green: 0.45, blue: 0.50)],
                        ribbons: 2, turbulence: 0.30, cloudiness: 0.65, stars: 60, speed: 0.6))

    /// Every preset, in catalog order: `polar-night`, `violet-veil`, `dawn-haze`.
    public static let all: [SkyPreset] = [polarNight, violetVeil, dawnHaze]

    /// The id of the default preset (`polar-night`).
    public static let defaultID = "polar-night"

    /// The default preset (`polar-night`).
    public static var defaultPreset: SkyPreset { polarNight }

    /// The preset with `id`, or nil when it is unknown.
    public static func preset(id: String) -> SkyPreset? { all.first { $0.id == id } }

    /// The scene of the preset with `id`, or nil when it is unknown.
    public static func scene(id: String) -> SkyScene? { preset(id: id)?.scene }
}
