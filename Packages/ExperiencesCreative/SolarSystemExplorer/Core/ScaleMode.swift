// ScaleMode — feature 105 (A14-P03) T-A14-304 (FR-A14-310, FR-A14-311; SC-A14-302; clarification Q3; data-model
// "ScaleMode"; research D3). The two ways Solar System Explorer maps the model's double-precision heliocentric
// positions (AU, ecliptic: x toward the J2000.0 equinox, z toward ecliptic north) and the catalog's radii to the scene
// (y up, so the ecliptic is the scene's x–z plane):
//   - `enhanced` (raw value 0, the default; A14-P02's orbit view): a point at r AU lies 4·√r scene units out in its
//     direction, scene = (x, z, −y) · 4√r / r; display radii are A14-P01's (0.25 + 0.15 · log₂(radius / 2,439.7 km),
//     at least 0.05; the Sun 1.6) × 0.6 for a planet and × 0.5 for the Sun. Label: "Distances and sizes not to scale".
//   - `trueRelative` (raw value 1): one linear scale, 2 scene units per AU, for positions (scene = (x, z, −y) · 2) and
//     radii (radius km ÷ 149,597,870.7 × 2): Neptune lies about 60 units out and the Sun's radius is about 0.0093, so
//     drawn radii and distances keep the catalog's ratios. Label: "Distances and sizes to one scale; small bodies
//     marked" (a body drawn under 2 px gets a marker, which the presenter draws).
// Camera: the overview distance is 60 (enhanced) or 120 (true-relative) times 1.25^−zoomSteps; near and far are
// 0.5 and 200 (enhanced) or max(1e-4, 0.05 · d) and d + 140 (true-relative) for camera distance d, so the scene (at
// most 22 or about 61 units from the Sun) and the focused body stay inside the depth range, and the starfield drawn at
// 0.9 × far (180, or 0.9 · d + 126) lies beyond every body (97 at most, or d + 61) for every camera distance used.
import Foundation
import VisualCoreMath

/// How positions and radii are mapped to the scene.
public enum ScaleMode: Int, CaseIterable, Codable, Sendable {
    /// Bodies enlarged and distances compressed (4·√r), labelled not to scale.
    case enhanced = 0
    /// One linear scale (2 scene units per AU) for positions and radii.
    case trueRelative = 1

    /// The enhanced mode's scene units per √AU (4).
    public static let enhancedScale = 4.0
    /// The true-relative mode's scene units per AU (2).
    public static let trueScale = 2.0
    /// A14-P01's display radius of the star (1.6).
    public static let sunBaseRadius = 1.6
    /// A14-P01's display radius of a planet the size of Mercury (0.25).
    public static let basePlanetRadius = 0.25
    /// A14-P01's display radius added per doubling of the true radius (0.15).
    public static let radiusPerDoubling = 0.15
    /// The reference radius of A14-P01's display radii (Mercury's, 2,439.7 km).
    public static let referenceRadiusKm = 2_439.7
    /// The enhanced mode's factor on a planet's A14-P01 display radius (0.6).
    public static let planetRadiusFactor = 0.6
    /// The enhanced mode's factor on the Sun's A14-P01 display radius (0.5).
    public static let sunRadiusFactor = 0.5
    /// The drawn radius in pixels below which the true-relative mode marks a body (2).
    public static let markerThresholdPixels = 2.0
    /// The marker's radius in pixels (6).
    public static let markerRadiusPixels = 6.0

    /// The words shown and spoken for the mode.
    public var label: String {
        switch self {
        case .enhanced: return "Distances and sizes not to scale"
        case .trueRelative: return "Distances and sizes to one scale; small bodies marked"
        }
    }

    /// The short name of the mode: "Enhanced" or "True relative".
    public var name: String {
        switch self {
        case .enhanced: return "Enhanced"
        case .trueRelative: return "True relative"
        }
    }

    /// The scene point of the heliocentric ecliptic point `p` (AU); the origin for the Sun or a non-finite point.
    public func scenePosition(_ p: Vec3) -> Vec3 {
        let r = p.length
        guard r.isFinite, r > 0 else { return .zero }
        let factor: Double
        switch self {
        case .enhanced: factor = Self.enhancedScale * r.squareRoot() / r
        case .trueRelative: factor = Self.trueScale
        }
        return Vec3(p.x * factor, p.z * factor, -p.y * factor)
    }

    /// The drawn radius of a body of `radiusKm` and `kind`, scene units (see the file header); 0 for a non-finite or
    /// non-positive radius in the true-relative mode.
    public func drawnRadius(radiusKm: Double, kind: BodyKind) -> Double {
        switch self {
        case .enhanced:
            if kind == .star { return Self.sunBaseRadius * Self.sunRadiusFactor }
            guard radiusKm.isFinite, radiusKm > 0 else { return Self.basePlanetRadius * Self.planetRadiusFactor }
            let doublings = log2(radiusKm / Self.referenceRadiusKm)
            let base = max(0.05, Self.basePlanetRadius + Self.radiusPerDoubling * doublings)
            return base * Self.planetRadiusFactor
        case .trueRelative:
            guard radiusKm.isFinite, radiusKm > 0 else { return 0 }
            return radiusKm / Units.kmPerAU * Self.trueScale
        }
    }

    /// The drawn radius of the catalog body at `index` (0 outside the catalog).
    public func drawnRadius(index: Int) -> Double {
        guard let body = BodyCatalog.bundled.body(at: index) else { return 0 }
        return drawnRadius(radiusKm: body.meanRadiusKm, kind: body.kind)
    }

    /// The camera distance at zoom step `zoomSteps`: 60 (enhanced) or 120 (true-relative) × 1.25^−zoomSteps.
    public func cameraDistance(zoomSteps: Int) -> Double {
        let overview = self == .enhanced ? SolarState.overviewDistance : 2 * SolarState.overviewDistance
        return overview * pow(SolarState.zoomFactor, -Double(zoomSteps))
    }

    /// The near and far planes for camera distance `distance` (see the file header).
    public func clipRange(distance: Double) -> (near: Double, far: Double) {
        switch self {
        case .enhanced: return (0.5, 200)
        case .trueRelative: return (max(1e-4, 0.05 * distance), distance + 140)
        }
    }
}
