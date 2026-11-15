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

// Warm starting — feature 083 (A11-P02) T-A11-202 (FR-A11-203, 204; SC-A11-204; contract specs/083-pp-p02-springs/
// contracts/api.md; research D3). Without stored impulses the inout solve equals the Phase 01 solve bit for bit (a
// verbatim reference copy of the Phase 01 algorithm below); the accumulated impulses are written back; stored impulses
// of the wrong count are ignored; five boxes stacked on a static floor stay standing for 1,200 ticks.

/// The Phase 01 (feature 082) solve, copied verbatim apart from names, as the reference for the cold start.
private func phaseOneSolve(_ bodies: inout [RigidBodyState2D], contacts: [Contact2D],
                           settings: ImpulseSolver2D.Settings = .init()) {
    struct Point {
        var a: Int, b: Int, rA: Vec2, rB: Vec2, normal: Vec2, tangent: Vec2, normalMass: Double, tangentMass: Double
        var bias: Double, friction: Double, normalImpulse = 0.0, tangentImpulse = 0.0
    }
    func cross(_ w: Double, _ r: Vec2) -> Vec2 { Vec2(-w * r.y, w * r.x) }
    func relative(_ bA: RigidBodyState2D, _ bB: RigidBodyState2D, _ rA: Vec2, _ rB: Vec2) -> Vec2 {
        bB.velocity + cross(bB.angularVelocity, rB) - bA.velocity - cross(bA.angularVelocity, rA)
    }
    func usableNormal(_ c: Contact2D) -> Vec2? {
        let range = bodies.indices
        guard c.a != c.b, range.contains(c.a), range.contains(c.b), bodies[c.a].isUsable, bodies[c.b].isUsable,
              c.manifold.normal.isFinite, c.manifold.depth.isFinite else { return nil }
        let length = c.manifold.normal.length
        guard length.isFinite, length > 0 else { return nil }
        return c.manifold.normal / length
    }
    func apply(_ p: Vec2, _ point: Point) {
        let bA = bodies[point.a], bB = bodies[point.b]
        let va = bA.velocity - p * bA.inverseMass
        let wa = bA.angularVelocity - bA.inverseInertia * point.rA.cross(p)
        let vb = bB.velocity + p * bB.inverseMass
        let wb = bB.angularVelocity + bB.inverseInertia * point.rB.cross(p)
        guard va.isFinite, wa.isFinite, vb.isFinite, wb.isFinite else { return }
        bodies[point.a].velocity = va
        bodies[point.a].angularVelocity = wa
        bodies[point.b].velocity = vb
        bodies[point.b].angularVelocity = wb
    }
    var points: [Point] = []
    for contact in contacts {
        guard let normal = usableNormal(contact) else { continue }
        let bA = bodies[contact.a], bB = bodies[contact.b]
        let tangent = Vec2(-normal.y, normal.x)
        let e = max(bA.restitution, bB.restitution)
        let mu = (max(bA.friction, 0) * max(bB.friction, 0)).squareRoot()
        for p in contact.manifold.points where p.isFinite {
            let rA = p - bA.position, rB = p - bB.position
            let rnA = rA.cross(normal), rnB = rB.cross(normal)
            let kN = bA.inverseMass + bB.inverseMass + bA.inverseInertia * rnA * rnA + bB.inverseInertia * rnB * rnB
            guard kN.isFinite, kN > 0 else { continue }
            let rtA = rA.cross(tangent), rtB = rB.cross(tangent)
            let kT = bA.inverseMass + bB.inverseMass + bA.inverseInertia * rtA * rtA + bB.inverseInertia * rtB * rtB
            let vn = relative(bA, bB, rA, rB).dot(normal)
            var bias = -vn > settings.restitutionThreshold ? -e * vn : 0
            if !bias.isFinite { bias = 0 }
            points.append(Point(a: contact.a, b: contact.b, rA: rA, rB: rB, normal: normal, tangent: tangent,
                                normalMass: kN, tangentMass: kT.isFinite ? kT : 0, bias: bias,
                                friction: mu.isFinite ? mu : 0))
        }
    }
    for _ in 0..<max(settings.iterations, 0) {
        for i in points.indices {
            var point = points[i]
            let vn = relative(bodies[point.a], bodies[point.b], point.rA, point.rB).dot(point.normal)
            let lambdaN = (-vn + point.bias) / point.normalMass
            if lambdaN.isFinite {
                let newImpulse = max(point.normalImpulse + lambdaN, 0)
                let delta = newImpulse - point.normalImpulse
                point.normalImpulse = newImpulse
                apply(point.normal * delta, point)
            }
            if point.tangentMass > 0 {
                let vt = relative(bodies[point.a], bodies[point.b], point.rA, point.rB).dot(point.tangent)
                let lambdaT = -vt / point.tangentMass
                if lambdaT.isFinite {
                    let limit = point.friction * point.normalImpulse
                    let newImpulse = min(max(point.tangentImpulse + lambdaT, -limit), limit)
                    let delta = newImpulse - point.tangentImpulse
                    point.tangentImpulse = newImpulse
                    apply(point.tangent * delta, point)
                }
            }
            points[i] = point
        }
    }
    for contact in contacts {
        guard let normal = usableNormal(contact) else { continue }
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

/// A seeded scene of overlapping circles and boxes with every pairwise contact.
private func seededScene(_ seed: UInt64) -> (bodies: [RigidBodyState2D], shapes: [Shape2D], contacts: [Contact2D]) {
    var random = SeededRandom(seed: seed)
    var bodies: [RigidBodyState2D] = [], shapes: [Shape2D] = []
    for i in 0..<10 {
        let shape: Shape2D = i % 2 == 0 ? .circle(radius: random.range(0.2...0.6))
            : .box(halfExtents: Vec2(random.range(0.2...0.6), random.range(0.2...0.6)))
        shapes.append(shape)
        let isStatic = i == 0
        bodies.append(RigidBodyState2D(position: Vec2(random.range(0...3), random.range(0...3)),
                                       angle: random.range(-1...1),
                                       velocity: Vec2(random.range(-3...3), random.range(-3...3)),
                                       angularVelocity: random.range(-2...2), inverseMass: isStatic ? 0 : random.range(0.2...3),
                                       inverseInertia: isStatic ? 0 : random.range(0.5...6),
                                       restitution: random.range(0...1), friction: random.range(0...1)))
    }
    var contacts: [Contact2D] = []
    for a in bodies.indices {
        for b in bodies.indices where b > a {
            if let m = Contacts2D.collide(shapes[a], Pose2D(position: bodies[a].position, angle: bodies[a].angle),
                                          shapes[b], Pose2D(position: bodies[b].position, angle: bodies[b].angle)) {
                contacts.append(Contact2D(a: a, b: b, manifold: m))
            }
        }
    }
    return (bodies, shapes, contacts)
}

struct ImpulseSolver2DTests {
    @Test func coldStartEqualsPhaseOneExactly() {
        for seed in UInt64(1)...20 {
            let scene = seededScene(seed)
            var reference = scene.bodies, plain = scene.bodies, warm = scene.bodies
            phaseOneSolve(&reference, contacts: scene.contacts)
            ImpulseSolver2D.solve(&plain, contacts: scene.contacts)
            var contacts = scene.contacts
            ImpulseSolver2D.solve(&warm, contacts: &contacts)
            #expect(plain == reference)
            #expect(warm == reference)
            // The manifolds are untouched and the impulses are written back, one per point.
            #expect(contacts.map(\.manifold) == scene.contacts.map(\.manifold))
            for c in contacts {
                #expect(c.normalImpulses.count == c.manifold.points.count)
                #expect(c.tangentImpulses.count == c.manifold.points.count)
                #expect(c.normalImpulses.allSatisfy { $0 >= 0 && $0.isFinite })
            }
        }
    }

    @Test func storedImpulsesWithTheWrongCountAreIgnored() throws {
        let scene = seededScene(7)
        let first = try #require(scene.contacts.first)
        var reference = scene.bodies
        phaseOneSolve(&reference, contacts: scene.contacts)
        var contacts = scene.contacts
        contacts[0] = Contact2D(a: first.a, b: first.b, manifold: first.manifold,
                                normalImpulses: Array(repeating: 5, count: first.manifold.points.count + 1),
                                tangentImpulses: [])
        var bodies = scene.bodies
        ImpulseSolver2D.solve(&bodies, contacts: &contacts)
        #expect(bodies == reference)
    }

    @Test func restingContactKeepsItsImpulse() throws {
        // A crate resting on the floor: the second solve, warm-started, ends with the same supporting impulse and the
        // crate at rest; ignored contacts get empty arrays.
        let floorShape = Shape2D.box(halfExtents: Vec2(5, 0.5)), crateShape = Shape2D.box(halfExtents: Vec2(0.5, 0.5))
        let g = 9.81, dt = 1.0 / 120
        var bodies = [RigidBodyState2D(position: Vec2(0, -0.5), angle: 0, velocity: .zero, angularVelocity: 0,
                                       inverseMass: 0, inverseInertia: 0, restitution: 0, friction: 0.5),
                      RigidBodyState2D(position: Vec2(0, 0.5), angle: 0, velocity: .zero, angularVelocity: 0,
                                       inverseMass: 0.5, inverseInertia: 3, restitution: 0, friction: 0.5)]
        let m = try #require(Contacts2D.collide(floorShape, Pose2D(position: bodies[0].position), crateShape,
                                                Pose2D(position: bodies[1].position)))
        var contacts = [Contact2D(a: 0, b: 1, manifold: m), Contact2D(a: 0, b: 0, manifold: m)]
        var residuals: [Double] = []
        var totals: [Double] = []
        for _ in 0..<3 {
            bodies[1].velocity.y -= g * dt
            ImpulseSolver2D.solve(&bodies, contacts: &contacts)
            residuals.append(abs(bodies[1].velocity.y))
            totals.append(contacts[0].normalImpulses.reduce(0, +))
        }
        // The cold first solve leaves a small residual; warm-started solves converge further.
        #expect(residuals[0] <= 1e-5)
        #expect(residuals[1] < residuals[0] && residuals[2] <= 1e-8)
        // The accumulated normal impulse supports the weight impulse m·g·dt (mass 2).
        for total in totals { #expect(abs(total - 2 * g * dt) <= 1e-5) }
        #expect(contacts[1].normalImpulses.isEmpty && contacts[1].tangentImpulses.isEmpty)
    }

    @Test func fiveBoxStackStandsWithWarmStarting() {
        // Five 0.5 m boxes of 0.15 kg (density 0.6 kg/m²), friction 0.5, restitution 0, on a static floor whose top is
        // at y = 0; gravity −9.81 m/s², dt = 1/120 s, 1,200 ticks: gravity → contacts (broad phase over all pairs) →
        // warm-started solve (previous impulses matched by pair and point index) → integrate.
        let dt = 1.0 / 120, g = -9.81
        let half = 0.25, mass = 0.6 * 0.25
        let crate = Shape2D.box(halfExtents: Vec2(half, half))
        var shapes: [Shape2D] = [.box(halfExtents: Vec2(5, 0.5))]
        var bodies = [RigidBodyState2D(position: Vec2(0, -0.5), angle: 0, velocity: .zero, angularVelocity: 0,
                                       inverseMass: 0, inverseInertia: 0, restitution: 0, friction: 0.5)]
        for i in 0..<5 {
            shapes.append(crate)
            bodies.append(RigidBodyState2D(position: Vec2(0, half + 0.5 * Double(i)), angle: 0, velocity: .zero,
                                           angularVelocity: 0, inverseMass: 1 / mass,
                                           inverseInertia: 1 / crate.inertia(mass: mass), restitution: 0,
                                           friction: 0.5))
        }
        let resting = bodies.map(\.position.y)
        var previous: [BroadPhasePair2D: Contact2D] = [:]
        var worstSink = 0.0, worstDrift = 0.0
        for _ in 0..<1_200 {
            for i in bodies.indices where bodies[i].inverseMass > 0 { bodies[i].velocity.y += g * dt }
            let poses = bodies.map { Pose2D(position: $0.position, angle: $0.angle) }
            let boxes = shapes.indices.map { shapes[$0].bounds(at: poses[$0]) }
            var contacts: [Contact2D] = []
            for pair in BroadPhase2D.pairs(boxes) {
                guard let m = Contacts2D.collide(shapes[pair.a], poses[pair.a], shapes[pair.b], poses[pair.b])
                else { continue }
                var contact = Contact2D(a: pair.a, b: pair.b, manifold: m)
                if let old = previous[pair], old.normalImpulses.count == m.points.count {
                    contact.normalImpulses = old.normalImpulses
                    contact.tangentImpulses = old.tangentImpulses
                }
                contacts.append(contact)
            }
            ImpulseSolver2D.solve(&bodies, contacts: &contacts)
            previous = Dictionary(uniqueKeysWithValues: contacts.map { (BroadPhasePair2D(a: $0.a, b: $0.b), $0) })
            for i in bodies.indices where bodies[i].inverseMass > 0 {
                bodies[i].position += bodies[i].velocity * dt
                bodies[i].angle += bodies[i].angularVelocity * dt
            }
            for i in 1..<bodies.count { worstSink = max(worstSink, abs(bodies[i].position.y - resting[i])) }
            worstDrift = max(worstDrift, abs(bodies[5].position.x))
        }
        #expect(worstDrift < 0.02, "top box horizontal drift \(worstDrift) m")
        #expect(worstSink < 0.01, "largest height deviation \(worstSink) m")
        for b in bodies { #expect(b.position.isFinite && b.velocity.isFinite) }
    }
}
