// OrbitViewBounds.swift — feature 042 (A05-P03) T-A05-302 (FR-A05-321; G-ORBITBOUNDS remainder).
// Bounds for the full orbit view: the pitch and distance bounds of ``OrbitBounds`` plus a target radius (pan limit),
// a field-of-view range and a clearance radius that keeps the eye outside the composition's bounding sphere
// (minimum distance = max(lower distance bound, |target| + clearance + 2 · near); research D3). Every step returns a
// camera inside the bounds, so state built only from these steps never holds an out-of-bounds camera.
import Foundation

/// Bounds for an ``OrbitCamera`` viewing a 3D composition: orbit bounds (pitch limit, distance range), a pan limit
/// for the target, a field-of-view range and a clearance radius about the origin.
public struct OrbitViewBounds: Sendable, Equatable, Codable {
    /// Pitch limit and distance range, applied exactly as ``OrbitBounds/clamp(_:)`` applies them; yaw is wrapped
    /// into −π…π.
    public var orbit: OrbitBounds
    /// Maximum distance of the target from the origin; a negative or non-finite radius acts as 0.
    public var targetRadius: Double
    /// Allowed vertical fields of view in radians; intersected with the open interval (0, π) when applied (an empty
    /// or non-finite intersection falls back to the single default angle π/3 of ``OrbitCamera``).
    public var fovRange: ClosedRange<Double>
    /// Radius about the origin that the eye stays outside of (the composition's bounding radius); a negative or
    /// non-finite clearance acts as 0.
    public var clearance: Double

    /// Creates bounds from orbit bounds, a target radius, a field-of-view range (radians) and a clearance radius.
    public init(orbit: OrbitBounds, targetRadius: Double, fovRange: ClosedRange<Double>, clearance: Double = 0) {
        self.orbit = orbit
        self.targetRadius = targetRadius
        self.fovRange = fovRange
        self.clearance = clearance
    }

    /// Smallest admissible field of view: keeps the applied range strictly inside (0, π).
    static let fovMargin = 1e-6
    /// Default field of view of ``OrbitCamera`` (π/3), the fallback for an unusable range or angle.
    static let defaultFov = Double.pi / 3

    /// The target radius actually applied (finite, ≥ 0).
    var effectiveTargetRadius: Double { targetRadius.isFinite && targetRadius > 0 ? targetRadius : 0 }

    /// The clearance actually applied (finite, ≥ 0).
    var effectiveClearance: Double { clearance.isFinite && clearance > 0 ? clearance : 0 }

    /// The field-of-view range actually applied: `fovRange` ∩ [margin, π − margin].
    var effectiveFovRange: ClosedRange<Double> {
        let lower = max(fovRange.lowerBound, Self.fovMargin)
        let upper = min(fovRange.upperBound, .pi - Self.fovMargin)
        guard lower.isFinite, upper.isFinite, lower <= upper else { return Self.defaultFov...Self.defaultFov }
        return lower...upper
    }

    /// The minimum eye-to-target distance for `camera`: max(lower distance bound, |target| + clearance + 2 · near),
    /// never above the upper distance bound (a larger or non-finite value returns the upper bound). A non-finite or
    /// negative near distance counts as 0.
    public func minimumDistance(for camera: OrbitCamera) -> Double {
        let range = orbit.effectiveDistanceRange
        let near = camera.near.isFinite && camera.near > 0 ? camera.near : 0
        let rule = camera.target.length + effectiveClearance + 2 * near
        guard rule.isFinite, rule <= range.upperBound else { return range.upperBound }
        return max(range.lowerBound, rule)
    }

    /// Clamps a target into the ball of radius ``effectiveTargetRadius``: a NaN component becomes 0, an infinite one
    /// saturates at ±radius, and a longer vector is scaled back toward the origin (a vector within 1e-12 relative of
    /// the radius is kept, which makes the clamp idempotent).
    func clampTarget(_ t: Vec3) -> Vec3 {
        let r = effectiveTargetRadius
        func c(_ v: Double) -> Double { v.isNaN ? 0 : (v.isInfinite ? (v > 0 ? r : -r) : v) }
        var finite = Vec3(c(t.x), c(t.y), c(t.z))
        var len = finite.length
        if !len.isFinite {
            // The squared length overflowed: rescale by the largest component first (keeps the direction).
            let m = max(abs(finite.x), abs(finite.y), abs(finite.z))
            finite = finite * (1 / m)
            len = finite.length
            return r > 0 ? finite * (r / len) : .zero
        }
        guard len > r * (1 + 1e-12) else { return finite }
        return r > 0 ? finite * (r / len) : .zero
    }

    /// Clamps a vertical field of view into ``effectiveFovRange``; a non-finite angle becomes π/3 clamped.
    func clampFov(_ fovY: Double) -> Double {
        let range = effectiveFovRange
        let f = fovY.isFinite ? fovY : Self.defaultFov
        return min(max(f, range.lowerBound), range.upperBound)
    }

    /// Returns `camera` with its target pulled back to |target| ≤ target radius, its field of view clamped into the
    /// field-of-view range, its pitch and yaw clamped as ``OrbitBounds/clamp(_:)`` does, and its distance clamped into
    /// ``minimumDistance(for:)``…upper distance bound. Clip planes are kept. Idempotent.
    public func clamp(_ camera: OrbitCamera) -> OrbitCamera {
        var out = orbit.clamp(camera)
        out.target = clampTarget(camera.target)
        out.fovY = clampFov(camera.fovY)
        let upper = orbit.effectiveDistanceRange.upperBound
        let lower = minimumDistance(for: out)
        out.distance = min(max(out.distance, lower), upper)
        return out
    }
}

extension OrbitCamera {
    /// Unit view direction from the eye toward the target.
    public var forward: Vec3 { (target - eye).normalized }

    /// Unit view-space right vector: normalize(forward × world up), world up = +y (matches ``view()``).
    public var right: Vec3 { forward.cross(Vec3(0, 1, 0)).normalized }

    /// Unit view-space up vector: right × forward.
    public var up: Vec3 { right.cross(forward) }

    /// Moves the target by `delta.x · right + delta.y · up` (world units in the view plane) and clamps the result
    /// into `bounds`. A non-finite delta returns `self` unchanged.
    public func panned(by delta: Vec2, within bounds: OrbitViewBounds) -> OrbitCamera {
        guard delta.x.isFinite, delta.y.isFinite else { return self }
        var next = self
        next.target = target + right * delta.x + up * delta.y
        return bounds.clamp(next)
    }

    /// Sets the vertical field of view (radians, absolute) and clamps the result into `bounds`. A non-finite angle
    /// returns `self` unchanged.
    public func withFieldOfView(_ fovY: Double, within bounds: OrbitViewBounds) -> OrbitCamera {
        guard fovY.isFinite else { return self }
        var next = self
        next.fovY = fovY
        return bounds.clamp(next)
    }

    /// Adds the yaw and pitch deltas (radians) as the ``OrbitBounds`` variant of `orbited(yaw:pitch:within:)` does and clamps
    /// the result into `bounds`. A non-finite delta returns `self` unchanged.
    public func orbited(yaw: Double, pitch: Double, within bounds: OrbitViewBounds) -> OrbitCamera {
        guard yaw.isFinite, pitch.isFinite else { return self }
        return bounds.clamp(orbited(yaw: yaw, pitch: pitch, within: bounds.orbit))
    }

    /// Divides the distance by `factor` (a zoom-in pinch, factor > 1, moves closer) and clamps the result into
    /// `bounds`, so the eye never comes closer than ``OrbitViewBounds/minimumDistance(for:)``. A non-finite or
    /// non-positive factor returns `self` unchanged.
    public func zoomed(by factor: Double, within bounds: OrbitViewBounds) -> OrbitCamera {
        guard factor.isFinite, factor > 0 else { return self }
        return bounds.clamp(zoomed(by: factor, within: bounds.orbit))
    }
}
