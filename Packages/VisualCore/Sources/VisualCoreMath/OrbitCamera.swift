// OrbitCamera.swift — perspective camera orbiting a target (feature 006 T-F515; FR-F509; research R8).
// yaw 0 / pitch 0 puts the eye on +z looking toward −z. Right-handed, y up, GL clip space.
import Foundation

/// Perspective camera orbiting `target` at `distance`, steered by yaw and pitch (right-handed, y up, GL clip space).
public struct OrbitCamera: Sendable, Equatable {
    /// Maximum absolute pitch, 89° in radians, so the view never flips over the pole.
    public static let pitchLimit = 89.0 * .pi / 180
    /// Allowed orbit distances; values outside are clamped.
    public static let distanceRange: ClosedRange<Double> = 0.01...1_000_000

    /// World point the camera looks at and orbits around.
    public var target: Vec3
    /// Eye-to-target distance, clamped to `distanceRange` (non-finite resets to 5).
    public var distance: Double { didSet { distance = Self.clampDistance(distance) } }
    /// Radians around +y.
    public var yaw: Double
    /// Radians, clamped to ±89° so the view never flips.
    public var pitch: Double { didSet { pitch = Self.clampPitch(pitch) } }
    /// Vertical field of view, radians in (0, π).
    public var fovY: Double
    /// Near clipping plane distance (> 0).
    public var near: Double
    /// Far clipping plane distance (> `near`).
    public var far: Double

    /// Creates a camera; invalid values are replaced (fovY → π/3, near → 0.1, far → near · 1000) and distance and pitch are clamped.
    public init(target: Vec3 = .zero, distance: Double = 5, yaw: Double = 0, pitch: Double = 0,
                fovY: Double = .pi / 3, near: Double = 0.1, far: Double = 1000) {
        self.target = target
        self.distance = Self.clampDistance(distance)
        self.yaw = yaw
        self.pitch = Self.clampPitch(pitch)
        self.fovY = fovY > 0 && fovY < .pi ? fovY : .pi / 3
        self.near = near > 0 ? near : 0.1
        self.far = far > self.near ? far : self.near * 1000
    }

    static func clampDistance(_ d: Double) -> Double {
        d.isFinite ? min(max(d, distanceRange.lowerBound), distanceRange.upperBound) : 5
    }
    static func clampPitch(_ p: Double) -> Double { p.isFinite ? min(max(p, -pitchLimit), pitchLimit) : 0 }

    /// World-space eye position derived from target, distance, yaw and pitch.
    public var eye: Vec3 {
        target + Vec3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * distance
    }

    /// Right-handed view matrix looking from `eye` at `target` with +y up.
    public func view() -> Mat4 { Mat4.lookAt(eye: eye, target: target, up: Vec3(0, 1, 0)) }
    /// Perspective projection (GL depth range); a non-positive or non-finite aspect falls back to 1.
    public func projection(aspect: Double) -> Mat4 {
        Mat4.perspective(fovY: fovY, aspect: aspect > 0 && aspect.isFinite ? aspect : 1, near: near, far: far)
    }
    /// Combined `projection · view` matrix.
    public func viewProjection(aspect: Double) -> Mat4 { projection(aspect: aspect) * view() }

    /// World point → NDC (x, y in −1…1 when visible; z is depth).
    public func project(_ p: Vec3, aspect: Double) -> Vec3 { viewProjection(aspect: aspect).applyPoint(p) }

    /// World-space ray through an NDC point (picking).
    public func ray(ndc: Vec2, aspect: Double) -> (origin: Vec3, direction: Vec3) {
        guard let inv = viewProjection(aspect: aspect).inverse else { return (eye, (target - eye).normalized) }
        let a = inv.applyPoint(Vec3(ndc.x, ndc.y, -1)), b = inv.applyPoint(Vec3(ndc.x, ndc.y, 1))
        return (a, (b - a).normalized)
    }

    /// Adds yaw and pitch deltas in radians (pitch stays clamped; non-finite deltas are ignored).
    public mutating func orbit(dYaw: Double, dPitch: Double) {
        if dYaw.isFinite { yaw += dYaw }
        if dPitch.isFinite { pitch += dPitch }
    }

    /// Moves closer (factor > 1) or farther (factor < 1).
    public mutating func zoom(by factor: Double) {
        guard factor.isFinite, factor > 0 else { return }
        distance /= factor
    }
}
