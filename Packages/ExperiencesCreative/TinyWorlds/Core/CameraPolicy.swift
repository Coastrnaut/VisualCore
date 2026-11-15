// CameraPolicy — feature 090 (A12-P02) T-A12-204 (FR-A12-210; clarification 3; research D3; SC-A12-201). The camera
// policy every world shares: pitch 10°…75° and distance 10…30 m (the limits of `WorldView`), target (0, 0.3, 0) and a
// clearance of 0.5 m. The eye is placed as `OrbitCamera.eye` places it (target + distance × (cos pitch · sin yaw,
// sin pitch, cos pitch · cos yaw)). The clearance holds when the eye's height is at least 0.5 m above the highest of 9
// terrain samples on a 3 × 3 grid of 0.5 m spacing centred on the point below the eye (so every sample lies within 1 m
// of it); samples outside the terrain grid take its edge height (`HeightField.height(atX:z:)` clamps). When the
// clearance fails, the pitch is raised in steps of 1° until it holds or the pitch reaches 75°, where the eye is at
// least 0.3 + 10 · sin 75° ≈ 9.96 m high, far above every terrain (at most 1.6 m). Yaw and distance never change.
//
// `clamp` is pure and idempotent: a view that already keeps the clearance is returned unchanged.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// The comfortable-camera rules shared by every world.
public enum CameraPolicy {
    /// The point the camera orbits and looks at (metres).
    public static let target = Vec3(0, 0.3, 0)
    /// The least height of the eye above the terrain neighbourhood below it (metres).
    public static let clearance = 0.5
    /// The spacing of the 3 × 3 terrain samples around the point below the eye (metres).
    public static let sampleSpacing = 0.5
    /// The pitch step used when raising the camera, in radians (1°).
    public static let pitchStep = WorldView.radiansPerDegree
    /// The allowed pitch in radians (10°…75°).
    public static var pitchRange: ClosedRange<Double> { WorldView.pitchRange }
    /// The allowed distance in metres (10…30).
    public static var distanceRange: ClosedRange<Double> { WorldView.distanceRange }

    /// The orbit camera of `view` around ``target``.
    public static func camera(for view: WorldView) -> OrbitCamera {
        OrbitCamera(target: target, distance: view.distance, yaw: view.yaw, pitch: view.pitch)
    }

    /// The eye position of `view` (as `OrbitCamera.eye`).
    public static func eye(of view: WorldView) -> Vec3 { camera(for: view).eye }

    /// The highest of the 9 terrain samples of `field` on the 0.5 m grid centred on (x, z).
    public static func neighbourhoodMaximum(field: HeightField, x: Double, z: Double) -> Double {
        var highest = -Double.infinity
        for dz in -1...1 {
            for dx in -1...1 {
                highest = max(highest, field.height(atX: x + Double(dx) * sampleSpacing,
                                                    z: z + Double(dz) * sampleSpacing))
            }
        }
        return highest
    }

    /// The eye's height above the neighbourhood maximum below it, in metres.
    public static func headroom(of view: WorldView, field: HeightField) -> Double {
        let eye = eye(of: view)
        return eye.y - neighbourhoodMaximum(field: field, x: eye.x, z: eye.z)
    }

    /// True when `view` is within its limits and its eye is at least ``clearance`` above the terrain below it.
    public static func keepsClearance(_ view: WorldView, field: HeightField) -> Bool {
        view.isValid && headroom(of: view, field: field) >= clearance
    }

    /// `view` with its pitch raised in 1° steps (to at most 75°) until the clearance over `field` holds; yaw and
    /// distance unchanged. The view's own limits already hold (`WorldView` clamps on creation).
    public static func clamp(_ view: WorldView, field: HeightField) -> WorldView {
        var current = WorldView(yaw: view.yaw, pitch: view.pitch, distance: view.distance)
        let top = pitchRange.upperBound
        var step = 0
        while current.pitch < top, headroom(of: current, field: field) < clearance {
            step += 1
            let pitch = min(view.pitch + Double(step) * pitchStep, top)
            current = WorldView(yaw: view.yaw, pitch: pitch, distance: view.distance)
        }
        return current
    }

    /// `view` clamped over the level-0 terrain of `preset` and `seed` (see ``clamp(_:field:)``); when the terrain
    /// cannot be built (never for the bundled presets) the view is checked against the highest possible terrain
    /// (`WorldPreset.heightRange.upperBound`) everywhere.
    public static func clamp(_ view: WorldView, preset: WorldPreset, seed: UInt32) -> WorldView {
        if let field = try? TerrainGenerator.heightField(preset: preset, seed: seed) {
            return clamp(view, field: field)
        }
        let top = WorldPreset.heightRange.upperBound
        guard let flat = try? HeightField(columns: 1, rows: 1, cellSize: WorldPreset.worldSize,
                                          originX: WorldPreset.worldOrigin, originZ: WorldPreset.worldOrigin,
                                          height: { _, _ in top }) else { return view }
        return clamp(view, field: flat)
    }
}
