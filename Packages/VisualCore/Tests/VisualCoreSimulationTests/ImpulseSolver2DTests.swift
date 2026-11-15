// ImpulseSolver2DTests — feature 082 (A11-P01) T-A11-102 (FR-A11-102; SC-A11-102, 105; contract specs/082-pp-p01-model/
// contracts/api.md; research D2). Elastic exchange and momentum, perfectly inelastic contact, static bodies, the
// restitution threshold, Coulomb friction, positional correction, ignored contacts, determinism and finite output.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private func body(_ x: Double, _ y: Double, vx: Double = 0, vy: Double = 0, invMass: Double = 1,
                  invInertia: Double = 2, restitution: Double = 0, friction: Double = 0) -> RigidBodyState2D {
    RigidBodyState2D(position: Vec2(x, y), angle: 0, velocity: Vec2(vx, vy), angularVelocity: 0,
                     inverseMass: invMass, inverseInertia: invInertia, restitution: restitution, friction: friction)
}

private func circleContact(_ bodies: [RigidBodyState2D], _ a: Int, _ b: Int, radius: Double = 0.5) -> Contact2D? {
    guard let m = Contacts2D.collide(.circle(radius: radius), Pose2D(position: bodies[a].position),
                                     .circle(radius: radius), Pose2D(position: bodies[b].position)) else { return nil }
    return Contact2D(a: a, b: b, manifold: m)
}

private func momentum(_ bodies: [RigidBodyState2D]) -> Vec2 {
    bodies.reduce(Vec2.zero) { $0 + $1.velocity / $1.inverseMass }
}

struct ImpulseSolverTests {
    @Test func elasticHeadOnExchangesVelocities() throws {
        var bodies = [body(0, 0, vx: 2, restitution: 1), body(0.98, 0, vx: -1, restitution: 1)]
        let contact = try #require(circleContact(bodies, 0, 1))
        let before = momentum(bodies)
        ImpulseSolver2D.solve(&bodies, contacts: [contact])
        #expect(abs(bodies[0].velocity.x - -1) <= 1e-9)
        #expect(abs(bodies[1].velocity.x - 2) <= 1e-9)
        let after = momentum(bodies)
        #expect((after - before).length <= 1e-9 * before.length)
        #expect(bodies[0].angularVelocity == 0 && bodies[1].angularVelocity == 0)
    }

    @Test func inelasticContactMovesTogether() throws {
        var bodies = [body(0, 0, vx: 2), body(0.98, 0, vx: -1)]
        let contact = try #require(circleContact(bodies, 0, 1))
        ImpulseSolver2D.solve(&bodies, contacts: [contact])
        #expect(abs(bodies[0].velocity.x - bodies[1].velocity.x) <= 1e-9)
        #expect(abs(bodies[0].velocity.x - 0.5) <= 1e-9)
    }

    @Test func staticBodyNeverChanges() throws {
        let ledge = body(0, 0, invMass: 0, invInertia: 0, restitution: 0.4, friction: 0.5)
        var bodies = [ledge, body(0.3, 0.95, vx: 3, vy: -6, restitution: 0.9, friction: 0.8)]
        for step in 0..<1_000 {
            bodies[1].position = Vec2(0.3 + 0.0001 * Double(step % 7), 0.95)
            bodies[1].velocity = Vec2(3, -6 - Double(step % 5))
            let contact = try #require(circleContact(bodies, 0, 1))
            ImpulseSolver2D.solve(&bodies, contacts: [contact])
            #expect(bodies[0] == ledge)
        }
    }

    @Test func noRestitutionBelowThreshold() throws {
        var bodies = [body(0, 0, vx: 0.2, restitution: 1), body(0.98, 0, vx: -0.2, restitution: 1)]
        let contact = try #require(circleContact(bodies, 0, 1))
        ImpulseSolver2D.solve(&bodies, contacts: [contact])
        #expect(abs(bodies[0].velocity.x) <= 1e-12)
        #expect(abs(bodies[1].velocity.x) <= 1e-12)
        // Just above the threshold the bodies bounce.
        var fast = [body(0, 0, vx: 0.3, restitution: 1), body(0.98, 0, vx: -0.3, restitution: 1)]
        ImpulseSolver2D.solve(&fast, contacts: [try #require(circleContact(fast, 0, 1))])
        #expect(abs(fast[0].velocity.x - -0.3) <= 1e-9)
    }

    @Test func frictionSlowsWithinTheCoulombBound() throws {
        let floorShape = Shape2D.box(halfExtents: Vec2(5, 0.5))
        let crateShape = Shape2D.box(halfExtents: Vec2(0.5, 0.5))
        for vx in [3.0, 0.1, -0.05] {
            let floor = body(0, 0, invMass: 0, invInertia: 0, friction: 0.5)
            let crate = body(0, 0.995, vx: vx, vy: -1, invMass: 0.5, invInertia: 3, friction: 0.5)
            var bodies = [floor, crate]
            let m = try #require(Contacts2D.collide(floorShape, Pose2D(position: floor.position), crateShape,
                                                    Pose2D(position: crate.position)))
            #expect(m.points.count == 2)
            ImpulseSolver2D.solve(&bodies, contacts: [Contact2D(a: 0, b: 1, manifold: m)])
            let after = bodies[1].velocity
            // Tangential speed at the contact points (r = (±0.5, −0.5), so ω × r adds 0.5·ω along x) drops and never
            // reverses; the centre may keep a tiny opposite velocity while the crate tips.
            let slip = after.x + 0.5 * bodies[1].angularVelocity
            #expect(abs(slip) < abs(vx))
            #expect(slip * vx >= -1e-9)
            // |ΔPt| ≤ μ·ΔPn on the crate's linear momentum (mass 2).
            let dpx = abs(after.x - vx) * 2, dpy = (after.y - -1) * 2
            #expect(dpy > 0)
            #expect(dpx <= 0.5 * dpy + 1e-9)
            #expect(bodies[0] == floor)
        }
    }

    @Test func positionalCorrectionReducesOverlap() throws {
        var bodies = [body(0, 0), body(0.8, 0)]
        let contact = try #require(circleContact(bodies, 0, 1))
        ImpulseSolver2D.solve(&bodies, contacts: [contact])
        let gap = bodies[1].position.x - bodies[0].position.x
        // Depth 0.2: 80 % of (0.2 − 0.005) is removed, shared equally.
        #expect(abs(gap - (0.8 + 0.8 * 0.195)) <= 1e-12)
        #expect(abs(bodies[0].position.x + bodies[1].position.x - 0.8) <= 1e-12)
        // Within the slop nothing moves.
        var shallow = [body(0, 0), body(0.997, 0)]
        ImpulseSolver2D.solve(&shallow, contacts: [try #require(circleContact(shallow, 0, 1))])
        #expect(shallow[0].position == Vec2(0, 0) && shallow[1].position == Vec2(0.997, 0))
    }

    @Test func invalidContactsAreIgnored() throws {
        let original = [body(0, 0, vx: 1), body(0.9, 0, vx: -1)]
        let m = try #require(circleContact(original, 0, 1)).manifold
        var bodies = original
        ImpulseSolver2D.solve(&bodies, contacts: [Contact2D(a: 0, b: 0, manifold: m), Contact2D(a: 0, b: 5, manifold: m),
                                                  Contact2D(a: -1, b: 1, manifold: m)])
        #expect(bodies == original)
    }

    @Test func identicalInputGivesIdenticalOutput() throws {
        func run() throws -> [RigidBodyState2D] {
            var bodies = [body(0, 0, vx: 1.3, vy: 0.2, restitution: 0.6, friction: 0.4),
                          body(0.9, 0.3, vx: -0.7, restitution: 0.2, friction: 0.9),
                          body(0.4, 0.9, vy: -2, invMass: 0.5, restitution: 0.8, friction: 0.3)]
            var contacts: [Contact2D] = []
            for (a, b) in [(0, 1), (0, 2), (1, 2)] {
                if let c = circleContact(bodies, a, b) { contacts.append(c) }
            }
            for _ in 0..<50 { ImpulseSolver2D.solve(&bodies, contacts: contacts) }
            return bodies
        }
        #expect(try run() == run())
    }

    @Test func extremeFiniteInputStaysFinite() throws {
        let huge = 1e300
        var bodies = [body(0, 0, vx: huge, vy: -huge, invMass: 1e-300, invInertia: 1e300, restitution: 1, friction: 1),
                      body(0.5, 0.1, vx: -huge, vy: huge, invMass: 1e300, invInertia: 1e-300, restitution: 1,
                           friction: 1e300)]
        let m = ContactManifold2D(normal: Vec2(1, 0), depth: 1e300, points: [Vec2(1e200, -1e200), Vec2(0.25, 0)])
        for _ in 0..<5 {
            ImpulseSolver2D.solve(&bodies, contacts: [Contact2D(a: 0, b: 1, manifold: m)],
                                  settings: .init(iterations: 20, restitutionThreshold: 0, slop: 0, correction: 1))
        }
        for b in bodies {
            #expect(b.position.isFinite && b.velocity.isFinite && b.angle.isFinite && b.angularVelocity.isFinite)
        }
    }

    @Test func defaultSettings() {
        let s = ImpulseSolver2D.Settings()
        #expect(s.iterations == 10 && s.restitutionThreshold == 0.5 && s.slop == 0.005 && s.correction == 0.8)
    }
}
