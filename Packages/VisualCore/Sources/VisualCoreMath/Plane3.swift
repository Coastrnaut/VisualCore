// Plane3 — feature 222 (R02-F22) T-R02F22-002 (FR-R02F22-001; SC-R02F22-001; clarification Q1; research R2). A plane
// through a point with a unit normal, and the ray-plane hit t = (p₀ − o) · n / (d · n): no hit when |d · n| < 1e-12 (the
// `Ray3` tolerance) or t < 0; the hit normal faces the ray.

/// A plane through `point` with unit normal `normal`.
public struct Plane3: Sendable, Equatable, Codable {
    /// A point on the plane.
    public let point: Vec3
    /// The unit normal.
    public let normal: Vec3

    /// A plane through `point` with the normalised `normal`; nil for a non-finite point or a zero or non-finite normal.
    public init?(point: Vec3, normal: Vec3) {
        guard point.isFinite, normal.isFinite else { return nil }
        let length = normal.length
        guard length > 0, length.isFinite else { return nil }
        let unit = normal / length
        guard unit.isFinite, unit.length > 0 else { return nil }
        self.point = point
        self.normal = unit
    }

    /// The signed distance of `p` from the plane, positive on the normal's side.
    public func signedDistance(_ p: Vec3) -> Double { (p - point).dot(normal) }
}

extension Ray3 {
    /// Intersects `plane`: nil when the ray is parallel to it (|d · n| below the ray tolerance) or the plane lies
    /// behind the origin; a start on the plane hits at distance 0. The hit normal is the plane normal turned to face
    /// the ray.
    public func intersect(plane: Plane3) -> RayHit3? {
        let denominator = direction.dot(plane.normal)
        guard abs(denominator) >= Self.tolerance else { return nil }
        let t = (plane.point - origin).dot(plane.normal) / denominator
        guard t.isFinite, t >= 0 else { return nil }
        let facing = denominator < 0 ? plane.normal : -plane.normal
        return RayHit3(distance: t, point: origin + direction * t, normal: facing)
    }
}
