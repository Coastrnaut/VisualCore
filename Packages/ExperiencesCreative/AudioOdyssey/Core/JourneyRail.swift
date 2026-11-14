// JourneyRail — feature 054 (A07-P01) T-A07-103 (FR-A07-101, FR-A07-110; clarifications 1, 2). The seeded closed rail
// of Audio Odyssey: 12 control points on a perturbed horizontal ellipse (semi-axes 120 along x and 80 along z), radial
// jitter up to ±10 % and heights up to ±4 (gentle slopes over spans of about 50 units).
//
// The rail must keep its radius of curvature at or above `requiredTurnRadius`: the comfort radius (fast speed ÷ the
// standard turn rate, 7 ÷ 45°/s ≈ 8.92) and the landscape's half-width plus a margin (14), so the terrain strip never
// folds over itself. A seed whose points break that (or that `CameraRail` refuses) is retried with the same random draws
// scaled by 1/2, then 1/4, then 0 (the plain level ellipse, whose smallest radius is 80² ÷ 120 ≈ 53).
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// Makes the seeded camera rail of Audio Odyssey.
public enum JourneyRail {
    /// The number of control points.
    public static let controlPointCount = 12
    /// The semi-axis along x, in units.
    public static let semiAxisX = 120.0
    /// The semi-axis along z, in units.
    public static let semiAxisZ = 80.0
    /// The largest relative radial jitter of a control point (±10 %).
    public static let radialJitter = 0.10
    /// The largest height of a control point above or below y = 0, in units.
    public static let heightJitter = 4.0
    /// The smallest radius that keeps the fastest speed within the standard turn rate: 7 ÷ (π/4) ≈ 8.92 units.
    public static let comfortTurnRadius = SpeedChoice.fast.unitsPerSecond / ComfortLimits.standard.maxTurnRate
    /// The smallest radius the generator accepts: the comfort radius, and at least the landscape half-width plus 2.
    public static let requiredTurnRadius = max(comfortTurnRadius, 14)
    /// The jitter scales tried in order; the last (0) is the plain level ellipse.
    public static let jitterScales: [Double] = [1, 0.5, 0.25, 0]

    /// The 12 control points for `seed` with the jitter scaled by `scale` (0…1), counter-clockwise seen from +y.
    public static func controlPoints(seed: UInt64, scale: Double = 1) -> [Vec3] {
        let s = scale.isFinite ? min(max(scale, 0), 1) : 0
        var rng = SeededRandom(seed: seed)
        return (0..<controlPointCount).map { k in
            let radial = rng.range(-1...1), height = rng.range(-1...1)
            let angle = 2 * Double.pi * Double(k) / Double(controlPointCount)
            let f = 1 + radialJitter * s * radial
            return Vec3(semiAxisX * f * cos(angle), heightJitter * s * height, semiAxisZ * f * sin(angle))
        }
    }

    /// The rail for `seed`: the first jitter scale whose rail is valid with a radius ≥ `requiredTurnRadius`.
    public static func make(seed: UInt64) -> CameraRail {
        for scale in jitterScales {
            if let rail = CameraRail(controlPoints: controlPoints(seed: seed, scale: scale)),
               rail.minimumTurnRadius() >= requiredTurnRadius {
                return rail
            }
        }
        // The plain level ellipse (scale 0) is well spaced, horizontal and has a smallest radius of about 53.
        guard let ellipse = CameraRail(controlPoints: controlPoints(seed: seed, scale: 0)) else {
            preconditionFailure("the level ellipse rail must be valid")
        }
        return ellipse
    }
}
