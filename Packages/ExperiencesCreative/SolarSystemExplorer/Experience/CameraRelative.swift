// CameraRelative — feature 105 (A14-P03) T-A14-307 (FR-A14-322; SC-A14-304; clarification Q5; research D5). Positions
// stay in double precision; for drawing, a scene point is taken relative to the camera target in Double and only
// then converted to single precision, so the Float error scales with the distance from the target (where the camera
// looks) and not with the distance from the Sun. `pixelSize` is the scene size of one pixel at a distance:
// 2 · d · tan(fovY / 2) / height.
import Foundation
import VisualCoreMath

/// Camera-relative single-precision conversion and the scene size of a pixel.
enum CameraRelative {
    /// `p − target` computed in Double, then converted to Float (round to nearest).
    static func relative(_ p: Vec3, to target: Vec3) -> SIMD3<Float> {
        let d = p - target
        return SIMD3<Float>(Float(d.x), Float(d.y), Float(d.z))
    }

    /// The scene size of one pixel at `distance` through a vertical field of view `fovY` (radians) on a canvas
    /// `heightPixels` high: 2 · distance · tan(fovY / 2) / heightPixels (0 for a non-positive height).
    static func pixelSize(distance: Double, fovY: Double, heightPixels: Double) -> Double {
        guard heightPixels > 0 else { return 0 }
        return 2 * distance * tan(fovY / 2) / heightPixels
    }
}
