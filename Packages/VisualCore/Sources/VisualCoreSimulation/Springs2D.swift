// Springs2D.swift — damped springs between 2D rigid bodies (or a body and a fixed world point) applied as velocity
// impulses before the contact solver (feature 083 (A11-P02) T-A11-202 (FR-A11-201); contract specs/083-pp-p02-springs/
// contracts/api.md; research D1). Stiffness is clamped to 0.1·m/dt² (ω·dt ≤ 0.32) and damping to m/dt, where m is the
// effective mass of the two ends, so semi-implicit Euler stays stable. Pure and deterministic (spring order), never
// writes a non-finite value and never moves a static end.
import Foundation
import VisualCoreMath

/// One end of a spring: a point fixed to a body (in the body's local frame) or a fixed point in the world.
public enum SpringAnchor2D: Sendable, Equatable {
    /// A point at `local` in the frame of the body at `index` in the body array.
    case body(index: Int, local: Vec2)
    /// A fixed world point; it acts as an end with inverse mass 0 that never moves.
    case world(Vec2)
}

/// A damped spring between two anchors.
public struct Spring2D: Sendable, Equatable {
    /// The first end.
    public var a: SpringAnchor2D
    /// The second end.
    public var b: SpringAnchor2D
    /// Length in world units at which the spring exerts no force (≥ 0).
    public var restLength: Double
    /// Stiffness k in newtons per metre (≥ 0); clamped per tick to `Springs2D.stableStiffness(effectiveMass:dt:)`.
    public var stiffness: Double
    /// Damping ratio ζ (≥ 0); the damping coefficient is 2ζ·√(k·m), clamped to `Springs2D.stableDamping(effectiveMass:dt:)`.
    public var dampingRatio: Double

    /// Creates a spring from its anchors, rest length, stiffness and damping ratio (default 0, undamped).
    public init(a: SpringAnchor2D, b: SpringAnchor2D, restLength: Double, stiffness: Double,
                dampingRatio: Double = 0) {
        self.a = a
        self.b = b
        self.restLength = restLength
        self.stiffness = stiffness
        self.dampingRatio = dampingRatio
    }
}

/// Applies damped springs to 2D rigid bodies as impulses.
public enum Springs2D {
    /// Lengths below this (world units) apply nothing, because the spring direction is undefined.
    public static let minimumLength: Double = 1e-9

    /// The largest stiffness kept stable for effective mass `m` and step `dt`: 0.1·m/dt², i.e. ω·dt ≤ √0.1 ≈ 0.32.
    /// Returns 0 when the result is not finite and positive.
    public static func stableStiffness(effectiveMass m: Double, dt: Double) -> Double {
        let k = 0.1 * m / (dt * dt)
        return k.isFinite && k > 0 ? k : 0
    }

    /// The largest damping coefficient kept stable for effective mass `m` and step `dt`: m/dt, which removes the whole
    /// closing speed in one step. Returns 0 when the result is not finite and positive.
    public static func stableDamping(effectiveMass m: Double, dt: Double) -> Double {
        let c = m / dt
        return c.isFinite && c > 0 ? c : 0
    }

    /// The resolved state of one anchor: its world point, its offset from the body's centre, its velocity, and the
    /// body index (nil for a world anchor).
    private struct End {
        var index: Int?
        var point: Vec2
        var r: Vec2
        var velocity: Vec2
        var inverseMass: Double
        var inverseInertia: Double
    }

    /// Resolves an anchor, or nil when its index is out of range, its body is unusable or a value is not finite.
    private static func resolve(_ anchor: SpringAnchor2D, _ bodies: [RigidBodyState2D]) -> End? {
        switch anchor {
        case .world(let p):
            guard p.isFinite else { return nil }
            return End(index: nil, point: p, r: .zero, velocity: .zero, inverseMass: 0, inverseInertia: 0)
        case let .body(index, local):
            guard bodies.indices.contains(index), local.isFinite else { return nil }
            let body = bodies[index]
            guard body.isUsable else { return nil }
            let point = Pose2D(position: body.position, angle: body.angle).toWorld(local)
            let r = point - body.position
            let velocity = body.velocity + Vec2(-body.angularVelocity * r.y, body.angularVelocity * r.x)
            guard point.isFinite, r.isFinite, velocity.isFinite else { return nil }
            return End(index: index, point: point, r: r, velocity: velocity, inverseMass: body.inverseMass,
                       inverseInertia: body.inverseInertia)
        }
    }

    /// Applies every spring, in order, to `bodies` for a step of `dt` seconds. Per spring: the world anchors pA, pB,
    /// d = pB − pA, L = |d|, n = d/L, the stretch speed vₙ = (vB − vA)·n at the anchors, the effective mass
    /// m = 1/(Σ linear inverse masses of the ends), k' = min(k, 0.1·m/dt²), c = min(2ζ·√(k'·m), m/dt) and the impulse
    /// J = (k'·(L − L₀) + c·vₙ)·dt; end A receives +J·n at pA and end B −J·n at pB (linear and angular), so a stretched
    /// spring pulls the ends together. A spring is skipped when L < `minimumLength`, both ends are static, an index is
    /// invalid, both ends are the same body, a parameter is negative or not finite, `dt` is not finite and positive,
    /// or a result would not be finite.
    public static func apply(_ bodies: inout [RigidBodyState2D], springs: [Spring2D], dt: Double) {
        guard dt.isFinite, dt > 0 else { return }
        for spring in springs {
            guard spring.restLength.isFinite, spring.restLength >= 0, spring.stiffness.isFinite, spring.stiffness >= 0,
                  spring.dampingRatio.isFinite, spring.dampingRatio >= 0,
                  let endA = resolve(spring.a, bodies), let endB = resolve(spring.b, bodies) else { continue }
            if let ia = endA.index, let ib = endB.index, ia == ib { continue }
            let inverseMassSum = endA.inverseMass + endB.inverseMass
            guard inverseMassSum.isFinite, inverseMassSum > 0 else { continue }
            let d = endB.point - endA.point
            let length = d.length
            guard length.isFinite, length >= minimumLength else { continue }
            let n = d / length
            let vn = (endB.velocity - endA.velocity).dot(n)
            let m = 1 / inverseMassSum
            let k = min(spring.stiffness, stableStiffness(effectiveMass: m, dt: dt))
            let c = min(2 * spring.dampingRatio * (k * m).squareRoot(), stableDamping(effectiveMass: m, dt: dt))
            let j = (k * (length - spring.restLength) + c * vn) * dt
            guard j.isFinite else { continue }
            let impulse = n * j
            guard impulse.isFinite else { continue }

            var updated: [(Int, Vec2, Double)] = []
            if let ia = endA.index {
                let body = bodies[ia]
                let v = body.velocity + impulse * body.inverseMass
                let w = body.angularVelocity + body.inverseInertia * endA.r.cross(impulse)
                guard v.isFinite, w.isFinite else { continue }
                updated.append((ia, v, w))
            }
            if let ib = endB.index {
                let body = bodies[ib]
                let v = body.velocity - impulse * body.inverseMass
                let w = body.angularVelocity - body.inverseInertia * endB.r.cross(impulse)
                guard v.isFinite, w.isFinite else { continue }
                updated.append((ib, v, w))
            }
            for (index, v, w) in updated {
                bodies[index].velocity = v
                bodies[index].angularVelocity = w
            }
        }
    }
}
