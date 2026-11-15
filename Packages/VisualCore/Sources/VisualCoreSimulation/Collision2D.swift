// Collision2D.swift — generic 2D collision tests for games: circle–circle and circle–capsule overlap, the closest point
// on a capsule's segment and a swept circle–circle test that catches tunnelling at any speed (feature 075 (A10-P01)
// T-A10-102 (FR-A10-101, 102); contract specs/075-na-p01-engine/contracts/api.md; research D1, D3). Every function is
// pure and deterministic; non-finite input or a negative radius never reports a contact.
import Foundation
import VisualCoreMath

/// A circle used for collision: a centre and a radius in world units.
public struct CollisionCircle: Sendable, Equatable {
    /// Centre in world units.
    public var center: Vec2
    /// Radius in world units; a negative or non-finite radius makes every test with this circle report no contact.
    public var radius: Double
    /// Creates a circle from its centre and radius.
    public init(center: Vec2, radius: Double) {
        self.center = center
        self.radius = radius
    }

    /// True when the centre and radius are finite and the radius is not negative.
    var isValid: Bool { center.isFinite && radius.isFinite && radius >= 0 }
}

/// A capsule used for collision: the segment from `a` to `b` swept by a circle of `radius` (a bar with rounded ends).
public struct CollisionCapsule: Sendable, Equatable {
    /// First end of the segment in world units.
    public var a: Vec2
    /// Second end of the segment in world units; equal to `a` makes the capsule a circle.
    public var b: Vec2
    /// Radius around the segment in world units; a negative or non-finite radius makes every test report no contact.
    public var radius: Double
    /// Creates a capsule from its segment ends and radius.
    public init(a: Vec2, b: Vec2, radius: Double) {
        self.a = a
        self.b = b
        self.radius = radius
    }

    /// True when both ends and the radius are finite and the radius is not negative.
    var isValid: Bool { a.isFinite && b.isFinite && radius.isFinite && radius >= 0 }
}

/// Pure, deterministic 2D collision tests between circles and capsules.
public enum Collision2D {
    /// Slack added to every contact comparison so that exactly touching shapes count as touching despite rounding.
    public static let tolerance: Double = 1e-9

    /// True when the two circles touch or overlap: centre distance² ≤ (ra + rb)² + `tolerance`. False for non-finite
    /// input or a negative radius.
    public static func overlaps(_ a: CollisionCircle, _ b: CollisionCircle) -> Bool {
        guard a.isValid, b.isValid else { return false }
        let delta = a.center - b.center
        let reach = a.radius + b.radius
        return delta.dot(delta) <= reach * reach + tolerance
    }

    /// True when the circle touches or overlaps the capsule: the distance from the circle's centre to the closest point
    /// of the capsule's segment is ≤ r1 + r2 + `tolerance`. A degenerate segment (a = b) behaves as a circle. False for
    /// non-finite input or a negative radius.
    public static func overlaps(_ circle: CollisionCircle, _ capsule: CollisionCapsule) -> Bool {
        guard circle.isValid, capsule.isValid else { return false }
        let closest = closestPoint(on: capsule, to: circle.center)
        return circle.center.distance(to: closest) <= circle.radius + capsule.radius + tolerance
    }

    /// The point of the capsule's segment `a`…`b` nearest to `point` (the radius is not involved). A degenerate
    /// segment returns `a`. When the point or either end is non-finite, `point` is returned unchanged.
    public static func closestPoint(on capsule: CollisionCapsule, to point: Vec2) -> Vec2 {
        guard point.isFinite, capsule.a.isFinite, capsule.b.isFinite else { return point }
        let segment = capsule.b - capsule.a
        let lengthSquared = segment.dot(segment)
        guard lengthSquared > 0 else { return capsule.a }
        let t = min(max((point - capsule.a).dot(segment) / lengthSquared, 0), 1)
        return capsule.a + segment * t
    }

    /// The earliest fraction t in 0…1 of a step at which circle `a` moving by `da` first touches circle `b` moving by
    /// `db`, both moving linearly over the step. Works on the relative motion d = da − db from p = a.center − b.center
    /// with R = ra + rb: returns 0 when the circles already touch at the start (|p|² ≤ R² + `tolerance`), otherwise
    /// the smallest root of |p + t d|² = R². Returns nil when there is no relative motion, the circles move apart, the
    /// path passes wide (negative discriminant), contact would come after the step (t > 1), or any input is non-finite
    /// or has a negative radius. Because the whole path is solved, no travel per step is too fast to be caught.
    public static func sweep(_ a: CollisionCircle, moving da: Vec2, _ b: CollisionCircle, moving db: Vec2) -> Double? {
        guard a.isValid, b.isValid, da.isFinite, db.isFinite else { return nil }
        let p = a.center - b.center
        let d = da - db
        let reach = a.radius + b.radius
        let c = p.dot(p) - reach * reach
        if c <= tolerance { return 0 }
        let quadratic = d.dot(d)
        let linear = 2 * p.dot(d)
        guard quadratic > 0, linear < 0 else { return nil }
        let discriminant = linear * linear - 4 * quadratic * c
        guard discriminant >= 0, discriminant.isFinite else { return nil }
        let t = (-linear - discriminant.squareRoot()) / (2 * quadratic)
        guard t.isFinite, t >= 0, t <= 1 else { return nil }
        return t
    }
}
