// ImpulseSolver2D.swift — a sequential-impulse contact solver for 2D rigid bodies: the body state, a contact between
// two bodies and `ImpulseSolver2D.solve` with restitution, Coulomb friction and a positional correction (feature 082
// (A11-P01) T-A11-102 (FR-A11-102); contract specs/082-pp-p01-model/contracts/api.md; research D2). The solver is pure
// and deterministic (fixed order), never divides by zero, never writes a non-finite value and never moves a body whose
// inverse mass and inverse inertia are both 0. Warm starting (feature 083 (A11-P02) T-A11-202 (FR-A11-203); contract
// specs/083-pp-p02-springs/contracts/api.md; research D3): a contact may carry the accumulated impulses of the previous
// step, which the `inout` solve applies first and writes back; without stored impulses it is the Phase 01 cold start.
import Foundation
import VisualCoreMath

/// The state of one 2D rigid body as the contact solver sees it.
public struct RigidBodyState2D: Sendable, Equatable {
    /// Position of the centre of mass in world units.
    public var position: Vec2
    /// Rotation in radians, counter-clockwise.
    public var angle: Double
    /// Linear velocity in world units per second.
    public var velocity: Vec2
    /// Angular velocity in radians per second, counter-clockwise.
    public var angularVelocity: Double
    /// 1 / mass; 0 makes the body immovable by impulses (static).
    public var inverseMass: Double
    /// 1 / moment of inertia; 0 makes the body unable to rotate from impulses.
    public var inverseInertia: Double
    /// Coefficient of restitution 0…1; a contact uses the larger of the two bodies' values.
    public var restitution: Double
    /// Coefficient of friction ≥ 0; a contact uses the geometric mean of the two bodies' values.
    public var friction: Double

    /// Creates a body state from all of its fields.
    public init(position: Vec2, angle: Double, velocity: Vec2, angularVelocity: Double, inverseMass: Double,
                inverseInertia: Double, restitution: Double, friction: Double) {
        self.position = position
        self.angle = angle
        self.velocity = velocity
        self.angularVelocity = angularVelocity
        self.inverseMass = inverseMass
        self.inverseInertia = inverseInertia
        self.restitution = restitution
        self.friction = friction
    }

    /// True when every field is finite and the inverse mass and inverse inertia are not negative.
    var isUsable: Bool {
        position.isFinite && angle.isFinite && velocity.isFinite && angularVelocity.isFinite
            && inverseMass.isFinite && inverseMass >= 0 && inverseInertia.isFinite && inverseInertia >= 0
            && restitution.isFinite && friction.isFinite
    }
}

/// A contact between two bodies: indices into the body array and the manifold whose normal points from body `a` to
/// body `b`.
public struct Contact2D: Sendable, Equatable {
    /// Index of the first body.
    public var a: Int
    /// Index of the second body.
    public var b: Int
    /// The contact manifold; its normal points from body `a` to body `b`.
    public var manifold: ContactManifold2D
    /// Accumulated normal impulse per manifold point from a previous solve (warm start); empty means a cold start.
    /// Used only when its count equals the manifold's point count.
    public var normalImpulses: [Double] = []
    /// Accumulated friction impulse per manifold point from a previous solve (warm start); empty means a cold start.
    /// Used only when its count equals the manifold's point count.
    public var tangentImpulses: [Double] = []

    /// Creates a contact between body `a` and body `b` without stored impulses (cold start).
    public init(a: Int, b: Int, manifold: ContactManifold2D) {
        self.a = a
        self.b = b
        self.manifold = manifold
    }

    /// Creates a contact between body `a` and body `b` carrying the accumulated normal and tangent impulses per
    /// manifold point of a previous solve, for warm starting.
    public init(a: Int, b: Int, manifold: ContactManifold2D, normalImpulses: [Double], tangentImpulses: [Double]) {
        self.a = a
        self.b = b
        self.manifold = manifold
        self.normalImpulses = normalImpulses
        self.tangentImpulses = tangentImpulses
    }
}

/// A deterministic sequential-impulse solver for 2D rigid-body contacts.
public enum ImpulseSolver2D {
    /// Solver settings.
    public struct Settings: Sendable, Equatable {
        /// Number of velocity iterations over all contact points (default 10).
        public var iterations: Int
        /// Closing speed in world units per second above which restitution is applied (default 0.5).
        public var restitutionThreshold: Double
        /// Penetration in world units that the positional correction leaves alone (default 0.005).
        public var slop: Double
        /// Fraction of the penetration beyond the slop removed by the positional correction (default 0.8).
        public var correction: Double

        /// Creates settings; every argument has the documented default.
        public init(iterations: Int = 10, restitutionThreshold: Double = 0.5, slop: Double = 0.005,
                    correction: Double = 0.8) {
            self.iterations = iterations
            self.restitutionThreshold = restitutionThreshold
            self.slop = slop
            self.correction = correction
        }
    }

    /// Per-point solver data captured before the iterations.
    private struct Point {
        var contact: Int
        var index: Int
        var a: Int
        var b: Int
        var rA: Vec2
        var rB: Vec2
        var normal: Vec2
        var tangent: Vec2
        var normalMass: Double
        var tangentMass: Double
        var bias: Double
        var friction: Double
        var normalImpulse = 0.0
        var tangentImpulse = 0.0
    }

    /// ω × r for a scalar angular velocity ω: (−ω·r.y, ω·r.x).
    private static func cross(_ w: Double, _ r: Vec2) -> Vec2 { Vec2(-w * r.y, w * r.x) }

    /// Velocity of body `b` relative to body `a` at the contact point.
    private static func relativeVelocity(_ bodyA: RigidBodyState2D, _ bodyB: RigidBodyState2D, _ rA: Vec2,
                                         _ rB: Vec2) -> Vec2 {
        bodyB.velocity + cross(bodyB.angularVelocity, rB) - bodyA.velocity - cross(bodyA.angularVelocity, rA)
    }

    /// The unit normal of a usable contact, or nil when the contact refers to missing or unusable bodies or carries a
    /// non-finite or zero normal.
    private static func usableNormal(_ contact: Contact2D, _ bodies: [RigidBodyState2D]) -> Vec2? {
        let range = bodies.indices
        guard contact.a != contact.b, range.contains(contact.a), range.contains(contact.b),
              bodies[contact.a].isUsable, bodies[contact.b].isUsable,
              contact.manifold.normal.isFinite, contact.manifold.depth.isFinite else { return nil }
        let length = contact.manifold.normal.length
        guard length.isFinite, length > 0 else { return nil }
        return contact.manifold.normal / length
    }

    /// Applies impulse `p` at offsets `rA`, `rB`: −p to body a and +p to body b. Nothing changes if any result would
    /// not be finite; the result says whether the impulse was applied.
    @discardableResult
    private static func apply(_ p: Vec2, _ point: Point, _ bodies: inout [RigidBodyState2D]) -> Bool {
        let bodyA = bodies[point.a], bodyB = bodies[point.b]
        let va = bodyA.velocity - p * bodyA.inverseMass
        let wa = bodyA.angularVelocity - bodyA.inverseInertia * point.rA.cross(p)
        let vb = bodyB.velocity + p * bodyB.inverseMass
        let wb = bodyB.angularVelocity + bodyB.inverseInertia * point.rB.cross(p)
        guard va.isFinite, wa.isFinite, vb.isFinite, wb.isFinite else { return false }
        bodies[point.a].velocity = va
        bodies[point.a].angularVelocity = wa
        bodies[point.b].velocity = vb
        bodies[point.b].angularVelocity = wb
        return true
    }

    /// Resolves `contacts` on `bodies`: `settings.iterations` sequential passes over every contact point accumulating a
    /// non-negative normal impulse (with the restitution bias −e·vₙ captured once when the closing speed exceeds
    /// `restitutionThreshold`, e = max(eA, eB)) and a friction impulse clamped to ±μ·Pₙ (μ = √(μA·μB)); then one
    /// positional pass that moves each body by its inverse-mass share of `correction`·max(depth − `slop`, 0) along the
    /// normal. Contacts with out-of-range or equal indices, unusable bodies or a degenerate normal are ignored. Stored
    /// impulses in the contacts are used as a warm start (see `solve(_:contacts:settings:)` with `inout` contacts);
    /// without them the result is the Phase 01 cold start.
    public static func solve(_ bodies: inout [RigidBodyState2D], contacts: [Contact2D],
                             settings: Settings = Settings()) {
        var copy = contacts
        solve(&bodies, contacts: &copy, settings: settings)
    }

    /// Resolves `contacts` on `bodies` like `solve(_:contacts:settings:)` with warm starting: for each contact whose
    /// stored `normalImpulses` and `tangentImpulses` both have one value per manifold point, the stored impulses
    /// (normal clamped ≥ 0, friction to ±μ·Pₙ, non-finite values read as 0) are applied first and the iterations start
    /// from them; the restitution bias is still taken from the velocities before the warm start. Afterwards every
    /// contact holds the accumulated normal and tangent impulse per manifold point (0 for a skipped point; empty for
    /// an ignored contact).
    public static func solve(_ bodies: inout [RigidBodyState2D], contacts: inout [Contact2D],
                             settings: Settings = Settings()) {
        var points: [Point] = []
        var used = Array(repeating: false, count: contacts.count)
        for (contactIndex, contact) in contacts.enumerated() {
            guard let normal = usableNormal(contact, bodies) else { continue }
            used[contactIndex] = true
            let bodyA = bodies[contact.a], bodyB = bodies[contact.b]
            let tangent = Vec2(-normal.y, normal.x)
            let e = max(bodyA.restitution, bodyB.restitution)
            let mu = (max(bodyA.friction, 0) * max(bodyB.friction, 0)).squareRoot()
            for (pointIndex, p) in contact.manifold.points.enumerated() where p.isFinite {
                let rA = p - bodyA.position, rB = p - bodyB.position
                let rnA = rA.cross(normal), rnB = rB.cross(normal)
                let kN = bodyA.inverseMass + bodyB.inverseMass
                    + bodyA.inverseInertia * rnA * rnA + bodyB.inverseInertia * rnB * rnB
                guard kN.isFinite, kN > 0 else { continue }
                let rtA = rA.cross(tangent), rtB = rB.cross(tangent)
                let kT = bodyA.inverseMass + bodyB.inverseMass
                    + bodyA.inverseInertia * rtA * rtA + bodyB.inverseInertia * rtB * rtB
                let vn = relativeVelocity(bodyA, bodyB, rA, rB).dot(normal)
                var bias = -vn > settings.restitutionThreshold ? -e * vn : 0
                if !bias.isFinite { bias = 0 }
                points.append(Point(contact: contactIndex, index: pointIndex, a: contact.a, b: contact.b, rA: rA, rB: rB, normal: normal, tangent: tangent,
                                    normalMass: kN, tangentMass: kT.isFinite ? kT : 0, bias: bias,
                                    friction: mu.isFinite ? mu : 0))
            }
        }

        // Warm start: apply the stored impulses after every bias has been captured from the cold velocities.
        for i in points.indices {
            let contact = contacts[points[i].contact]
            let count = contact.manifold.points.count
            guard contact.normalImpulses.count == count, contact.tangentImpulses.count == count else { continue }
            let storedN = contact.normalImpulses[points[i].index], storedT = contact.tangentImpulses[points[i].index]
            let normalImpulse = storedN.isFinite ? max(storedN, 0) : 0
            let limit = points[i].friction * normalImpulse
            let tangentImpulse = storedT.isFinite && points[i].tangentMass > 0 ? min(max(storedT, -limit), limit) : 0
            guard normalImpulse != 0 || tangentImpulse != 0 else { continue }
            let p = points[i].normal * normalImpulse + points[i].tangent * tangentImpulse
            guard p.isFinite else { continue }
            // `apply` leaves the bodies unchanged when a result would not be finite; then nothing is accumulated.
            if apply(p, points[i], &bodies) {
                points[i].normalImpulse = normalImpulse
                points[i].tangentImpulse = tangentImpulse
            }
        }

        for _ in 0..<max(settings.iterations, 0) {
            for i in points.indices {
                var point = points[i]
                // Normal impulse, accumulated and clamped ≥ 0.
                let vn = relativeVelocity(bodies[point.a], bodies[point.b], point.rA, point.rB).dot(point.normal)
                let lambdaN = (-vn + point.bias) / point.normalMass
                if lambdaN.isFinite {
                    let newImpulse = max(point.normalImpulse + lambdaN, 0)
                    let delta = newImpulse - point.normalImpulse
                    point.normalImpulse = newImpulse
                    apply(point.normal * delta, point, &bodies)
                }
                // Friction impulse, accumulated and clamped to ±μ·Pn.
                if point.tangentMass > 0 {
                    let vt = relativeVelocity(bodies[point.a], bodies[point.b], point.rA, point.rB).dot(point.tangent)
                    let lambdaT = -vt / point.tangentMass
                    if lambdaT.isFinite {
                        let limit = point.friction * point.normalImpulse
                        let newImpulse = min(max(point.tangentImpulse + lambdaT, -limit), limit)
                        let delta = newImpulse - point.tangentImpulse
                        point.tangentImpulse = newImpulse
                        apply(point.tangent * delta, point, &bodies)
                    }
                }
                points[i] = point
            }
        }

        // Write the accumulated impulses back, one per manifold point.
        for c in contacts.indices {
            let count = used[c] ? contacts[c].manifold.points.count : 0
            contacts[c].normalImpulses = Array(repeating: 0, count: count)
            contacts[c].tangentImpulses = Array(repeating: 0, count: count)
        }
        for point in points {
            contacts[point.contact].normalImpulses[point.index] = point.normalImpulse
            contacts[point.contact].tangentImpulses[point.index] = point.tangentImpulse
        }

        for contact in contacts {
            guard let normal = usableNormal(contact, bodies) else { continue }
            let invA = bodies[contact.a].inverseMass, invB = bodies[contact.b].inverseMass
            let sum = invA + invB
            guard sum > 0 else { continue }
            let amount = settings.correction * max(contact.manifold.depth - settings.slop, 0) / sum
            guard amount.isFinite, amount > 0 else { continue }
            let xa = bodies[contact.a].position - normal * (amount * invA)
            let xb = bodies[contact.b].position + normal * (amount * invB)
            guard xa.isFinite, xb.isFinite else { continue }
            bodies[contact.a].position = xa
            bodies[contact.b].position = xb
        }
    }
}
