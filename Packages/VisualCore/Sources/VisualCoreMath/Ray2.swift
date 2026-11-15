// Ray2 — feature 096 (A13-P01) T-A13-102 (FR-A13-101–103; gap G-RAYCAST2D; research D1–D2).
// A 2D ray cast against line segments and the reflection of a direction about a normal. The cast uses the parametric
// ray–segment intersection with the 2D cross product: for a segment a→b with s = b − a, q = a − origin and
// denom = direction × s, a ray parallel or collinear to the segment (|denom| ≤ 1e-12) misses; otherwise
// t = (q × s) / denom along the ray and u = (q × direction) / denom along the segment, and the segment is hit when
// t > minimumDistance and 0 ≤ u ≤ 1 (end points count). The nearest hit wins; on equal distances the lower index wins,
// so the result is deterministic. Segments with non-finite or coincident end points are skipped. Excluding the
// segment just left and the minimum distance keep a reflected ray from hitting its own surface at distance zero.
import Foundation

/// A line segment between two points in the plane.
public struct Segment2: Sendable, Equatable, Hashable, Codable {
    /// The first end point.
    public var a: Vec2
    /// The second end point.
    public var b: Vec2
    /// Creates the segment from `a` to `b`.
    public init(_ a: Vec2, _ b: Vec2) { self.a = a; self.b = b }
}

/// The nearest intersection of a 2D ray with a list of segments.
public struct RayHit2: Sendable, Equatable {
    /// Distance from the ray origin along the unit direction; greater than the cast's minimum distance.
    public let distance: Double
    /// The hit point, `origin + direction · distance`.
    public let point: Vec2
    /// The index of the hit segment in the array passed to the cast.
    public let segmentIndex: Int
    /// The segment's unit normal facing against the ray (`normal · direction < 0`).
    public let normal: Vec2
}

/// A half-line in the plane from `origin` along a unit `direction`.
public struct Ray2: Sendable, Equatable {
    /// Numerical tolerance below which a ray counts as parallel to a segment.
    static let parallelTolerance = 1e-12

    /// Start point of the ray.
    public let origin: Vec2
    /// Unit-length direction of travel.
    public let direction: Vec2

    /// Creates a ray, normalising `direction`; nil for a non-finite origin or a zero or non-finite direction.
    public init?(origin: Vec2, direction: Vec2) {
        guard origin.isFinite, direction.isFinite else { return nil }
        let length = direction.length
        guard length > 0, length.isFinite else { return nil }
        let unit = Vec2(direction.x / length, direction.y / length)
        guard unit.isFinite, unit.length > 0 else { return nil }
        self.origin = origin
        self.direction = unit
    }

    /// The point at distance `t` along the ray.
    public func point(at t: Double) -> Vec2 { origin + direction * t }

    /// The nearest segment hit at a distance greater than `minimumDistance`.
    ///
    /// Parallel and collinear segments miss; end points count as hits; segments with non-finite or coincident end
    /// points are skipped; the segment at index `excluding` is ignored. Equal distances resolve to the lower index.
    /// - Parameters:
    ///   - segments: The segments to test.
    ///   - excluding: An index to ignore (for example the segment the ray just left), or nil.
    ///   - minimumDistance: Hits at or below this distance are ignored (default 1e-9); a non-finite value ignores
    ///     nothing beyond distance 0.
    /// - Returns: The nearest hit, or nil when no segment is hit.
    public func cast(against segments: [Segment2], excluding: Int? = nil,
                     minimumDistance: Double = 1e-9) -> RayHit2? {
        let floor = minimumDistance.isFinite ? max(0, minimumDistance) : 0
        var best: (t: Double, index: Int, s: Vec2)?
        for (index, segment) in segments.enumerated() where index != excluding {
            guard segment.a.isFinite, segment.b.isFinite, segment.a != segment.b else { continue }
            let s = segment.b - segment.a
            let denominator = direction.cross(s)
            guard abs(denominator) > Self.parallelTolerance else { continue }
            let q = segment.a - origin
            let t = q.cross(s) / denominator
            let u = q.cross(direction) / denominator
            guard t.isFinite, u.isFinite, t > floor, u >= 0, u <= 1 else { continue }
            if let current = best, current.t <= t { continue }
            best = (t, index, s)
        }
        guard let best else { return nil }
        let length = best.s.length
        var normal = Vec2(-best.s.y / length, best.s.x / length)
        if normal.dot(direction) > 0 { normal = Vec2(-normal.x, -normal.y) }
        return RayHit2(distance: best.t, point: point(at: best.t), segmentIndex: best.index, normal: normal)
    }
}

extension Vec2 {
    /// This direction reflected about the unit `normal`: `self − 2 (self · normal) normal`, which keeps the length and
    /// makes the angle of incidence equal the angle of reflection. A zero or non-finite normal returns `self`
    /// unchanged; a non-unit normal is normalised first.
    public func reflected(about normal: Vec2) -> Vec2 {
        guard normal.isFinite else { return self }
        let length = normal.length
        guard length > 0, length.isFinite else { return self }
        let n = Vec2(normal.x / length, normal.y / length)
        return self - n * (2 * self.dot(n))
    }
}
