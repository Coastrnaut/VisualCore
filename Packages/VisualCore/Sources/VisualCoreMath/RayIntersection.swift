// RayIntersection — feature 090 (A12-P02) T-A12-202 (FR-A12-202; gap G-PICKING; research D2).
// Ray casts against axis-aligned boxes (slab method), spheres (quadratic) and triangles (two-sided Möller–Trumbore).
// A start inside a box or sphere hits at distance 0 with the normal −direction; tolerance 1e-12.
import Foundation

/// The nearest intersection of a ray with a shape.
public struct RayHit3: Sendable, Equatable {
    /// Distance from the ray origin along the unit direction, never negative.
    public let distance: Double
    /// World-space hit point, `origin + direction · distance`.
    public let point: Vec3
    /// Unit surface normal facing against the ray (`normal · direction ≤ 0`).
    public let normal: Vec3
}

/// A half-line from `origin` along a unit `direction`, used for picking.
public struct Ray3: Sendable, Equatable {
    /// Numerical tolerance used by every intersection test.
    static let tolerance = 1e-12

    /// Start point of the ray.
    public let origin: Vec3
    /// Unit-length direction of travel.
    public let direction: Vec3

    /// Creates a ray, normalising `direction`; nil for non-finite values or a zero (or unnormalisable) direction.
    public init?(origin: Vec3, direction: Vec3) {
        guard origin.isFinite, direction.isFinite else { return nil }
        let length = direction.length
        guard length > 0, length.isFinite else { return nil }
        let unit = direction / length
        guard unit.isFinite, unit.length > 0 else { return nil }
        self.origin = origin
        self.direction = unit
    }

    private func at(_ t: Double) -> Vec3 { origin + direction * t }

    private var insideHit: RayHit3 { RayHit3(distance: 0, point: origin, normal: -direction) }

    /// Intersects the axis-aligned box `[boxMin, boxMax]` with the slab method.
    ///
    /// A ray parallel to a slab hits only if its origin lies within that slab (boundaries included). A start inside
    /// the box hits at distance 0 with the normal −direction. Nil for a miss, a box behind the ray, non-finite bounds
    /// or `boxMin` above `boxMax` on any axis.
    public func intersect(boxMin: Vec3, boxMax: Vec3) -> RayHit3? {
        guard boxMin.isFinite, boxMax.isFinite,
              boxMin.x <= boxMax.x, boxMin.y <= boxMax.y, boxMin.z <= boxMax.z else { return nil }
        let o = [origin.x, origin.y, origin.z], d = [direction.x, direction.y, direction.z]
        let lo = [boxMin.x, boxMin.y, boxMin.z], hi = [boxMax.x, boxMax.y, boxMax.z]
        let tol = Self.tolerance
        var tNear = -Double.infinity, tFar = Double.infinity
        var axis = -1, sign = 0.0
        for i in 0..<3 {
            if abs(d[i]) <= tol {
                if o[i] < lo[i] - tol || o[i] > hi[i] + tol { return nil }
                continue
            }
            var t1 = (lo[i] - o[i]) / d[i], t2 = (hi[i] - o[i]) / d[i]
            if t1 > t2 { swap(&t1, &t2) }
            if t1 > tNear { tNear = t1; axis = i; sign = d[i] > 0 ? -1 : 1 }
            if t2 < tFar { tFar = t2 }
            if tNear > tFar + tol { return nil }
        }
        if tFar < -tol { return nil }
        if axis < 0 || tNear <= 0 { return insideHit }
        var n = [0.0, 0.0, 0.0]
        n[axis] = sign
        return RayHit3(distance: tNear, point: at(tNear), normal: Vec3(n[0], n[1], n[2]))
    }

    /// Intersects the sphere at `sphereCenter` with `radius` (> 0, finite), taking the nearer non-negative root.
    ///
    /// A tangent ray hits once; a start inside hits at distance 0 with the normal −direction. Nil for a miss, a sphere
    /// behind the ray or an invalid sphere.
    public func intersect(sphereCenter: Vec3, radius: Double) -> RayHit3? {
        guard sphereCenter.isFinite, radius.isFinite, radius > 0 else { return nil }
        let oc = origin - sphereCenter
        let b = oc.dot(direction)
        let c = oc.dot(oc) - radius * radius
        var disc = b * b - c
        if disc < -Self.tolerance * max(1, radius * radius) { return nil }
        disc = max(0, disc)
        let s = disc.squareRoot()
        let t0 = -b - s, t1 = -b + s
        if t1 < -Self.tolerance { return nil }
        if t0 <= 0 { return c < 0 ? insideHit : RayHit3(distance: 0, point: origin, normal: facing(oc / radius)) }
        let p = at(t0)
        return RayHit3(distance: t0, point: p, normal: facing((p - sphereCenter) / radius))
    }

    /// Intersects the triangle `a`, `b`, `c` from either side (Möller–Trumbore), with the normal facing the ray.
    ///
    /// Nil for a miss, a triangle behind the ray, a ray parallel to the triangle's plane, a degenerate triangle or
    /// non-finite vertices.
    public func intersect(triangle a: Vec3, _ b: Vec3, _ c: Vec3) -> RayHit3? {
        guard a.isFinite, b.isFinite, c.isFinite else { return nil }
        let tol = Self.tolerance
        let e1 = b - a, e2 = c - a
        let cross = e1.cross(e2)
        let scale = e1.length * e2.length
        guard scale > 0, cross.length > tol * scale else { return nil }
        let p = direction.cross(e2)
        let det = e1.dot(p)
        guard abs(det) > tol * scale else { return nil }
        let inv = 1 / det
        let s = origin - a
        let u = s.dot(p) * inv
        if u < -tol || u > 1 + tol { return nil }
        let q = s.cross(e1)
        let v = direction.dot(q) * inv
        if v < -tol || u + v > 1 + tol { return nil }
        let t = e2.dot(q) * inv
        if t < -tol { return nil }
        let distance = max(0, t)
        return RayHit3(distance: distance, point: at(distance), normal: facing(cross.normalized))
    }

    /// The hit with the smallest distance among `hits` (the first one on a tie), or nil when none is present.
    public static func nearest(_ hits: [RayHit3?]) -> RayHit3? {
        var best: RayHit3?
        for case let hit? in hits where best == nil || hit.distance < best!.distance { best = hit }
        return best
    }

    private func facing(_ n: Vec3) -> Vec3 {
        let unit = n.normalized
        return unit.dot(direction) > 0 ? -unit : unit
    }
}
