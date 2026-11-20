// HandleDrag — feature 222 (R02-F22) T-R02F22-004 (FR-R02F22-003; SC-R02F22-003; clarification Q3; research R4). A
// constrained handle drag that keeps the grab offset: position = p₀ + (h − h₀), where h is the constraint hit of the
// current ray and h₀ that of the start ray, so the start ray returns p₀ exactly. A plane hit is the ray-plane hit of the
// plane through p₀; an axis hit is the point of the axis line through p₀ closest to the ray. The drag holds its last
// position when the constraint is grazing (plane |d · n| < 0.1, axis |d · a| > 0.995) or missed; an optional box clamps
// each axis.
import Foundation
import VisualCoreMath

/// The constraint of a handle drag; the vector is normalised by ``HandleDrag``.
public enum DragConstraint: Sendable, Equatable {
    /// Movement along the line through the start with this direction.
    case axis(Vec3)
    /// Movement across the plane through the start with this normal.
    case plane(Vec3)
}

/// A drag of a handle under a ``DragConstraint`` that keeps the grab offset and holds at grazing angles.
public struct HandleDrag: Sendable, Equatable {
    /// A plane drag is grazing — and holds — when |d · n| is below this.
    public static let planeGrazing = 0.1
    /// An axis drag is grazing — and holds — when |d · a| is above this.
    public static let axisGrazing = 0.995

    /// The handle position when the drag began, p₀.
    public let start: Vec3
    /// The constraint with its vector normalised.
    public let constraint: DragConstraint
    /// The current handle position, p₀ + (h − h₀) clamped to the bounds.
    public private(set) var position: Vec3
    /// Whether the latest update was grazing or missed, so the position was held.
    public private(set) var isHeld: Bool

    /// The unit axis direction or plane normal.
    private let unit: Vec3
    /// The constraint hit of the start ray, h₀.
    private let startHit: Vec3
    /// The latest constraint hit that was followed.
    private var lastHit: Vec3
    /// The lower corner of the clamping box, if any.
    private let boundsMin: Vec3?
    /// The upper corner of the clamping box, if any.
    private let boundsMax: Vec3?

    /// Begins a drag of the handle at `start` grabbed by `ray` under `constraint`, optionally clamped to `bounds`.
    ///
    /// Nil for a non-finite start, a zero or non-finite constraint vector, non-finite bounds or bounds with `min`
    /// above `max` on any axis, and for a start ray that is grazing or misses the constraint (a plane behind the ray,
    /// or an axis whose closest point lies behind the ray origin). The initial position is `start` clamped to the
    /// bounds.
    public init?(start: Vec3, ray: Ray3, constraint: DragConstraint, bounds: (min: Vec3, max: Vec3)? = nil) {
        guard start.isFinite else { return nil }
        let raw: Vec3
        switch constraint {
        case .axis(let v): raw = v
        case .plane(let v): raw = v
        }
        guard raw.isFinite else { return nil }
        let length = raw.length
        guard length > 0, length.isFinite else { return nil }
        let unit = raw / length
        guard unit.isFinite, unit.length > 0 else { return nil }
        if let bounds {
            guard bounds.min.isFinite, bounds.max.isFinite,
                  bounds.min.x <= bounds.max.x, bounds.min.y <= bounds.max.y, bounds.min.z <= bounds.max.z
            else { return nil }
            boundsMin = bounds.min
            boundsMax = bounds.max
        } else {
            boundsMin = nil
            boundsMax = nil
        }
        let normalised: DragConstraint
        switch constraint {
        case .axis: normalised = .axis(unit)
        case .plane: normalised = .plane(unit)
        }
        guard let h0 = Self.hit(start: start, unit: unit, constraint: normalised, ray: ray) else { return nil }
        self.start = start
        self.constraint = normalised
        self.unit = unit
        self.startHit = h0
        self.lastHit = h0
        self.isHeld = false
        self.position = start
        self.position = clamped(start)
    }

    /// Follows `ray`: the new position p₀ + (h − h₀) clamped to the bounds, or the last position (with ``isHeld``
    /// true) when the ray is grazing or misses the constraint. Returns the position.
    @discardableResult
    public mutating func update(ray: Ray3) -> Vec3 {
        guard let h = Self.hit(start: start, unit: unit, constraint: constraint, ray: ray) else {
            isHeld = true
            return position
        }
        lastHit = h
        position = clamped(start + (h - startHit))
        isHeld = false
        return position
    }

    /// The signed angle in radians about the plane normal from h₀ − `center` to the latest hit − `center`, both
    /// projected onto the plane (right-hand rule, in −π … π); 0 when either projection is (near) zero, for a
    /// non-finite center and for an axis constraint.
    public func angle(around center: Vec3) -> Double {
        guard case .plane = constraint, center.isFinite else { return 0 }
        let a = startHit - center, b = lastHit - center
        let u = a - unit * unit.dot(a)
        let v = b - unit * unit.dot(b)
        let scale = max(1, max(a.length, b.length))
        let tiny = 1e-12 * scale
        guard u.length > tiny, v.length > tiny else { return 0 }
        return atan2(unit.dot(u.cross(v)), u.dot(v))
    }

    /// The constraint hit of `ray`, or nil when it is grazing or missed.
    private static func hit(start: Vec3, unit: Vec3, constraint: DragConstraint, ray: Ray3) -> Vec3? {
        let d = ray.direction
        switch constraint {
        case .plane:
            guard abs(d.dot(unit)) >= planeGrazing,
                  let plane = Plane3(point: start, normal: unit),
                  let hit = ray.intersect(plane: plane) else { return nil }
            return hit.point
        case .axis:
            // Closest points of the line start + s·a and the ray o + t·d (both unit): with w = start − o and
            // b = a · d, s = (b (d · w) − a · w) / (1 − b²) and t = d · w + s b.
            let b = unit.dot(d)
            guard abs(b) <= axisGrazing else { return nil }
            let w = start - ray.origin
            let dw = d.dot(w)
            let s = (b * dw - unit.dot(w)) / (1 - b * b)
            let t = dw + s * b
            guard s.isFinite, t >= 0 else { return nil }
            let point = start + unit * s
            return point.isFinite ? point : nil
        }
    }

    /// `p` clamped to the bounds on each axis, or `p` when there are none.
    private func clamped(_ p: Vec3) -> Vec3 {
        guard let lo = boundsMin, let hi = boundsMax else { return p }
        return Vec3(min(max(p.x, lo.x), hi.x), min(max(p.y, lo.y), hi.y), min(max(p.z, lo.z), hi.z))
    }
}
