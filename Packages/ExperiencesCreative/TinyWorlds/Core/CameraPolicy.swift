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
//
// Feature 092 (A12-P04) T-A12-402 (FR-A12-403, FR-A12-405; clarification Q3; research D2): the limits become per preset
// and the clearance sees the props.
// - `limits(for:)` is the preset's pack's `CameraLimits` (pack i ↔ preset i; inside the global limits). Every clamp
//   that knows the preset (`clamp(_:preset:seed:props:)`, `clamp(_:state:field:)`) first clamps the view's pitch and
//   distance into them and then raises the pitch in 1° steps up to the preset's upper pitch (not 75°). The overload
//   over a bare field keeps the global limits unless it is given others.
// - The obstacle height below the eye is the highest of the 9 terrain samples and of the top (y + scale · model height)
//   of every prop whose centre lies within 1 m plus its picking radius (in x–z) of the point below the eye; the picking
//   radius is the distance from the prop's base centre to the farthest corner of its picking box in x–z (the
//   half-diagonal of the box, rotation-independent), times its scale. The clearance holds when the eye is at least
//   0.5 m above it. At every preset's upper pitch (at least 70°) and least distance (at least 10 m) the eye is at least
//   9.7 m high, far above every terrain and prop top (at most 1.6 + 1.2 m).
// - Yaw never changes; a clamp never changes a prop.
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

    /// The distance the props' clearance reaches beyond a prop's picking radius (metres).
    public static let propReach = 1.0

    /// The camera limits of `preset`: its pack's pitch and distance ranges (inside the global limits).
    public static func limits(for preset: WorldPreset) -> CameraLimits { WorldPack.pack(for: preset.id).limits }

    /// The picking radius of `prop`: the x–z distance from its base centre to the farthest corner of its picking box,
    /// times its scale.
    public static func pickingRadius(of prop: PlacedProp) -> Double {
        let model = PropCatalog.model(prop.kind)
        let dx = max(abs(model.boxMin.x), abs(model.boxMax.x)), dz = max(abs(model.boxMin.z), abs(model.boxMax.z))
        return (dx * dx + dz * dz).squareRoot() * prop.scale
    }

    /// The highest top (y + scale · model height) of the `props` whose centre lies within ``propReach`` plus its
    /// picking radius of (x, z) in x–z; −∞ when there is none.
    public static func propMaximum(props: [PlacedProp], x: Double, z: Double) -> Double {
        var highest = -Double.infinity
        for prop in props {
            let reach = propReach + pickingRadius(of: prop)
            let dx = prop.x - x, dz = prop.z - z
            guard dx * dx + dz * dz <= reach * reach else { continue }
            highest = max(highest, prop.y + prop.scale * PropCatalog.model(prop.kind).height)
        }
        return highest
    }

    /// The obstacle height below (x, z): the highest of the 9 terrain samples of `field` and the nearby props' tops.
    public static func obstacleHeight(field: HeightField, props: [PlacedProp], x: Double, z: Double) -> Double {
        max(neighbourhoodMaximum(field: field, x: x, z: z), propMaximum(props: props, x: x, z: z))
    }

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

    /// The eye's height above the obstacle height below it (terrain of `field` and `props`), in metres.
    public static func headroom(of view: WorldView, field: HeightField, props: [PlacedProp] = []) -> Double {
        let eye = eye(of: view)
        return eye.y - obstacleHeight(field: field, props: props, x: eye.x, z: eye.z)
    }

    /// True when `view` is within `limits` (the global ones by default) and its eye is at least ``clearance`` above
    /// the terrain of `field` and the `props` below it.
    public static func keepsClearance(_ view: WorldView, field: HeightField, limits: CameraLimits = .global,
                                      props: [PlacedProp] = []) -> Bool {
        limits.contains(view) && headroom(of: view, field: field, props: props) >= clearance
    }

    /// `view` with its pitch and distance clamped into `limits` (the global ones by default) and then its pitch raised
    /// in 1° steps (to at most the upper pitch of `limits`) until the clearance over `field` and `props` holds; yaw
    /// unchanged.
    public static func clamp(_ view: WorldView, field: HeightField, limits: CameraLimits = .global,
                             props: [PlacedProp] = []) -> WorldView {
        let base = view.clamped(to: limits)
        var current = base
        let top = limits.pitch.upperBound
        var step = 0
        while current.pitch < top, headroom(of: current, field: field, props: props) < clearance {
            step += 1
            let pitch = min(base.pitch + Double(step) * pitchStep, top)
            current = WorldView(yaw: base.yaw, pitch: pitch, distance: base.distance)
        }
        return current
    }

    /// `view` clamped with `preset`'s limits (``limits(for:)``) over the level-0 terrain of `preset` and `seed` and
    /// `props` (see ``clamp(_:field:limits:props:)``); when the terrain cannot be built (never for the bundled
    /// presets) the view is checked against the highest possible terrain (`WorldPreset.heightRange.upperBound`)
    /// everywhere.
    public static func clamp(_ view: WorldView, preset: WorldPreset, seed: UInt32,
                             props: [PlacedProp] = []) -> WorldView {
        let limits = limits(for: preset)
        if let field = try? TerrainGenerator.heightField(preset: preset, seed: seed) {
            return clamp(view, field: field, limits: limits, props: props)
        }
        let top = WorldPreset.heightRange.upperBound
        guard let flat = try? HeightField(columns: 1, rows: 1, cellSize: WorldPreset.worldSize,
                                          originX: WorldPreset.worldOrigin, originZ: WorldPreset.worldOrigin,
                                          height: { _, _ in top }) else { return view.clamped(to: limits) }
        return clamp(view, field: flat, limits: limits, props: props)
    }

    /// `view` clamped for `state`: its preset's limits, over its level-0 terrain (`field` when given, which must be
    /// `WorldEditing.groundField(of: state)`) and its props. Used after every action and on restore.
    public static func clamp(_ view: WorldView, state: WorldState, field: HeightField? = nil) -> WorldView {
        if let field = field ?? WorldEditing.groundField(of: state) {
            return clamp(view, field: field, limits: limits(for: state.preset), props: state.props)
        }
        return clamp(view, preset: state.preset, seed: state.seed, props: state.props)
    }

    /// True when `state`'s view is within its preset's limits and keeps the clearance over its terrain and props.
    public static func keepsClearance(_ state: WorldState, field: HeightField? = nil) -> Bool {
        guard let field = field ?? WorldEditing.groundField(of: state) else { return false }
        return keepsClearance(state.view, field: field, limits: limits(for: state.preset), props: state.props)
    }
}
