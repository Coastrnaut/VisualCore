// Springs2DTests — feature 083 (A11-P02) T-A11-202 (FR-A11-201; SC-A11-201, 202; contract specs/083-pp-p02-springs/
// contracts/api.md; research D1). A stretched spring pulls both ends together, world anchors and static ends never move,
// zero length applies nothing, the stiffness and damping clamps, undamped energy within 2 % over 1,200 ticks, damped
// energy decay at ζ = 0.5, equilibrium stretch m·g/k under gravity, invalid springs and determinism. The oscillator
// tests integrate one body with semi-implicit Euler (spring impulse, then x += v·dt).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private func body(_ x: Double, _ y: Double, vx: Double = 0, vy: Double = 0, invMass: Double = 1,
                  invInertia: Double = 2) -> RigidBodyState2D {
    RigidBodyState2D(position: Vec2(x, y), angle: 0, velocity: Vec2(vx, vy), angularVelocity: 0,
                     inverseMass: invMass, inverseInertia: invInertia, restitution: 0, friction: 0)
}

private let dt = 1.0 / 120

/// One body of mass `mass` hanging from (or attached to) the world origin by `spring`, integrated for `ticks` steps;
/// `observe` sees the body after every step.
private func simulate(_ start: RigidBodyState2D, _ spring: Spring2D, gravity: Vec2 = .zero, ticks: Int,
                      observe: (Int, RigidBodyState2D) -> Void = { _, _ in }) -> RigidBodyState2D {
    var bodies = [start]
    for tick in 0..<ticks {
        bodies[0].velocity += gravity * dt
        Springs2D.apply(&bodies, springs: [spring], dt: dt)
        bodies[0].position += bodies[0].velocity * dt
        bodies[0].angle += bodies[0].angularVelocity * dt
        observe(tick, bodies[0])
    }
    return bodies[0]
}

/// Spring plus kinetic energy of a body on a spring from the world origin.
private func energy(_ b: RigidBodyState2D, k: Double, rest: Double) -> Double {
    let stretch = b.position.length - rest
    let speed = b.velocity.length
    return 0.5 * k * stretch * stretch + 0.5 * speed * speed / b.inverseMass
}

struct Springs2DTests {
    @Test func stretchedSpringPullsBothEndsTogether() {
        var bodies = [body(0, 0), body(3, 0, invMass: 0.5)]
        let spring = Spring2D(a: .body(index: 0, local: .zero), b: .body(index: 1, local: .zero), restLength: 1,
                              stiffness: 10)
        Springs2D.apply(&bodies, springs: [spring], dt: dt)
        #expect(bodies[0].velocity.x > 0 && bodies[1].velocity.x < 0)
        // Equal and opposite impulse: J = k·(L − L₀)·dt = 20·dt on body 0 (mass 1) and body 1 (mass 2).
        #expect(abs(bodies[0].velocity.x - 20 * dt) <= 1e-12)
        #expect(abs(bodies[1].velocity.x - -10 * dt) <= 1e-12)
        #expect(bodies[0].velocity.y == 0 && bodies[1].velocity.y == 0)
        // A compressed spring pushes them apart.
        var close = [body(0, 0), body(0.5, 0)]
        Springs2D.apply(&close, springs: [spring], dt: dt)
        #expect(close[0].velocity.x < 0 && close[1].velocity.x > 0)
    }

    @Test func offCentreAnchorSpinsTheBody() {
        var bodies = [body(0, 0)]
        let spring = Spring2D(a: .world(Vec2(0, 2)), b: .body(index: 0, local: Vec2(0.5, 0)), restLength: 1,
                              stiffness: 10)
        Springs2D.apply(&bodies, springs: [spring], dt: dt)
        // The pull at (0.5, 0) points to (0, 2): upward and left, so the body turns counter-clockwise.
        #expect(bodies[0].velocity.y > 0 && bodies[0].velocity.x < 0)
        #expect(bodies[0].angularVelocity > 0)
    }

    @Test func worldAnchorAndStaticEndsNeverMove() {
        let wall = body(5, 5, invMass: 0, invInertia: 0)
        var bodies = [wall, body(0, 0)]
        let springs = [Spring2D(a: .body(index: 0, local: Vec2(0.2, 0.1)), b: .body(index: 1, local: .zero),
                                restLength: 0.5, stiffness: 50, dampingRatio: 0.3),
                       Spring2D(a: .world(Vec2(-3, 0)), b: .body(index: 1, local: Vec2(0.1, 0)), restLength: 1,
                                stiffness: 40, dampingRatio: 0.1)]
        for _ in 0..<600 {
            Springs2D.apply(&bodies, springs: springs, dt: dt)
            bodies[1].position += bodies[1].velocity * dt
            bodies[1].angle += bodies[1].angularVelocity * dt
            #expect(bodies[0] == wall)
        }
        #expect(bodies[1].position.isFinite && bodies[1].position != Vec2(0, 0))
        // Two static ends: nothing at all.
        let pair = [wall, body(-5, 5, invMass: 0, invInertia: 0)]
        var still = pair
        Springs2D.apply(&still, springs: [Spring2D(a: .body(index: 0, local: .zero), b: .body(index: 1, local: .zero),
                                                   restLength: 1, stiffness: 100, dampingRatio: 1)], dt: dt)
        #expect(still == pair)
    }

    @Test func zeroLengthAppliesNothing() {
        let original = [body(1, 1, vx: 0.3), body(1, 1, vx: -0.2)]
        var bodies = original
        Springs2D.apply(&bodies, springs: [Spring2D(a: .body(index: 0, local: .zero), b: .body(index: 1, local: .zero),
                                                    restLength: 2, stiffness: 100, dampingRatio: 1)], dt: dt)
        #expect(bodies == original)
        var anchored = [body(2, 3)]
        Springs2D.apply(&anchored, springs: [Spring2D(a: .world(Vec2(2, 3)), b: .body(index: 0, local: .zero),
                                                      restLength: 1, stiffness: 100)], dt: dt)
        #expect(anchored == [body(2, 3)])
    }

    @Test func stiffnessAndDampingAreClamped() {
        // m = 1/(1 + 1) = 0.5; k' = 0.1·0.5/dt² and the impulse is k'·(L − L₀)·dt.
        let m = 0.5
        #expect(abs(Springs2D.stableStiffness(effectiveMass: m, dt: dt) - 0.1 * m * 14_400) <= 1e-9)
        #expect(abs(Springs2D.stableDamping(effectiveMass: m, dt: dt) - m * 120) <= 1e-9)
        var bodies = [body(0, 0), body(2, 0)]
        Springs2D.apply(&bodies, springs: [Spring2D(a: .body(index: 0, local: .zero), b: .body(index: 1, local: .zero),
                                                    restLength: 1, stiffness: 1e9)], dt: dt)
        let expected = 0.1 * m / (dt * dt) * 1 * dt
        #expect(abs(bodies[0].velocity.x - expected) <= 1e-9)
        #expect(abs(bodies[1].velocity.x + expected) <= 1e-9)
        // Huge damping at rest length: c = m/dt removes the stretch speed in one step and no more.
        var moving = [body(1, 0, vx: 3, vy: 0.5)]
        Springs2D.apply(&moving, springs: [Spring2D(a: .world(.zero), b: .body(index: 0, local: .zero), restLength: 1,
                                                    stiffness: 10, dampingRatio: 1e9)], dt: dt)
        #expect(abs(moving[0].velocity.x) <= 1e-12)
        #expect(moving[0].velocity.y == 0.5)
        // Degenerate inputs give 0.
        #expect(Springs2D.stableStiffness(effectiveMass: 1, dt: 0) == 0)
        #expect(Springs2D.stableDamping(effectiveMass: .nan, dt: dt) == 0)
    }

    @Test func undampedEnergyStaysWithinTwoPercent() {
        // m = 1, k = 6 N/m: ω = √6 ≈ 2.45 rad/s, ω·dt ≈ 0.020 ≤ 0.1.
        let k = 6.0, rest = 1.0
        #expect(k.squareRoot() * dt <= 0.1)
        let spring = Spring2D(a: .world(.zero), b: .body(index: 0, local: .zero), restLength: rest, stiffness: k)
        let start = body(1.5, 0)
        let e0 = energy(start, k: k, rest: rest)
        var worst = 0.0
        _ = simulate(start, spring, ticks: 1_200) { _, b in
            worst = max(worst, abs(energy(b, k: k, rest: rest) - e0) / e0)
        }
        #expect(worst <= 0.02, "worst relative energy error \(worst)")
    }

    @Test func dampedEnergyDecays() {
        let k = 6.0, rest = 1.0
        let spring = Spring2D(a: .world(.zero), b: .body(index: 0, local: .zero), restLength: rest, stiffness: k,
                              dampingRatio: 0.5)
        let start = body(1.5, 0)
        let e0 = energy(start, k: k, rest: rest)
        var history = [e0]
        let end = simulate(start, spring, ticks: 1_200) { _, b in history.append(energy(b, k: k, rest: rest)) }
        // Over every one-second window the energy never rises by more than 0.1 % (plus a floor for round-off near 0).
        for i in 120..<history.count {
            #expect(history[i] <= history[i - 120] * 1.001 + 1e-12 * e0)
        }
        #expect(energy(end, k: k, rest: rest) < 0.1 * e0)
    }

    @Test func equilibriumStretchUnderGravity() {
        // m = 0.5 kg, k = 60 N/m (below the clamp 0.1·0.5·14,400 = 720), ζ = 0.5: stretch m·g/k after 10 s when the
        // spring impulse is applied before gravity within a tick (spring, gravity, then x += v·dt).
        let mass = 0.5, k = 60.0, rest = 1.5, g = 9.81
        let spring = Spring2D(a: .world(Vec2(0, 8)), b: .body(index: 0, local: .zero), restLength: rest, stiffness: k,
                              dampingRatio: 0.5)
        var bodies = [body(0, 8 - rest, invMass: 1 / mass)]
        for _ in 0..<1_200 {
            Springs2D.apply(&bodies, springs: [spring], dt: dt)
            bodies[0].velocity.y -= g * dt
            bodies[0].position += bodies[0].velocity * dt
        }
        let stretch = (8 - bodies[0].position.y) - rest
        let expected = mass * g / k
        #expect(abs(stretch - expected) <= 0.02 * expected, "stretch \(stretch) expected \(expected)")
        #expect(abs(bodies[0].position.x) <= 1e-12)
        // With gravity added before the spring, the damper also sees the in-tick gravity speed g·dt, so the rest stretch
        // is (m·g − c·g·dt)/k with c = 2ζ·√(k·m): a relative shortfall of 2ζ·ω·dt (here 9 %).
        let end = simulate(body(0, 8 - rest, invMass: 1 / mass), spring, gravity: Vec2(0, -g), ticks: 1_200)
        let c = 2 * 0.5 * (k * mass).squareRoot()
        let biased = (mass * g - c * g * dt) / k
        #expect(abs((8 - end.position.y) - rest - biased) <= 1e-9 * expected)
    }

    @Test func invalidSpringsAreSkipped() {
        let original = [body(0, 0), body(2, 0)]
        let a = SpringAnchor2D.body(index: 0, local: .zero), b = SpringAnchor2D.body(index: 1, local: .zero)
        let invalid = [Spring2D(a: a, b: .body(index: 5, local: .zero), restLength: 1, stiffness: 10),
                       Spring2D(a: .body(index: -1, local: .zero), b: b, restLength: 1, stiffness: 10),
                       Spring2D(a: a, b: .body(index: 0, local: Vec2(1, 0)), restLength: 0.5, stiffness: 10),
                       Spring2D(a: a, b: b, restLength: .nan, stiffness: 10),
                       Spring2D(a: a, b: b, restLength: 1, stiffness: -10),
                       Spring2D(a: a, b: b, restLength: 1, stiffness: .infinity),
                       Spring2D(a: a, b: b, restLength: 1, stiffness: 10, dampingRatio: .nan),
                       Spring2D(a: .world(Vec2(.nan, 0)), b: b, restLength: 1, stiffness: 10)]
        var bodies = original
        Springs2D.apply(&bodies, springs: invalid, dt: dt)
        #expect(bodies == original)
        let valid = Spring2D(a: a, b: b, restLength: 1, stiffness: 10)
        for badDt in [0, -dt, .nan, .infinity] {
            Springs2D.apply(&bodies, springs: [valid], dt: badDt)
            #expect(bodies == original)
        }
        // Extreme finite values never write a non-finite result.
        var extreme = [body(0, 0, vx: 1e300, invMass: 1e300, invInertia: 1e300), body(1e300, 1e300, invMass: 1e-300)]
        Springs2D.apply(&extreme, springs: [Spring2D(a: .body(index: 0, local: Vec2(1e300, 0)), b: b, restLength: 0,
                                                     stiffness: 1e300, dampingRatio: 1e300)], dt: dt)
        for e in extreme { #expect(e.velocity.isFinite && e.angularVelocity.isFinite && e.position.isFinite) }
    }

    @Test func identicalInputGivesIdenticalOutput() {
        func run() -> [RigidBodyState2D] {
            var bodies = [body(0, 0, vx: 0.4), body(1.7, 0.3, invMass: 0.5), body(0.8, 1.9, vy: -1, invMass: 2)]
            let springs = [Spring2D(a: .body(index: 0, local: Vec2(0.1, 0.2)), b: .body(index: 1, local: Vec2(-0.2, 0)),
                                    restLength: 1, stiffness: 80, dampingRatio: 0.1),
                           Spring2D(a: .world(Vec2(1, 4)), b: .body(index: 2, local: Vec2(0, 0.3)), restLength: 1.5,
                                    stiffness: 150, dampingRatio: 0.1),
                           Spring2D(a: .body(index: 1, local: .zero), b: .body(index: 2, local: .zero), restLength: 1.2,
                                    stiffness: 400, dampingRatio: 0.1)]
            for _ in 0..<600 {
                Springs2D.apply(&bodies, springs: springs, dt: dt)
                for i in bodies.indices {
                    bodies[i].position += bodies[i].velocity * dt
                    bodies[i].angle += bodies[i].angularVelocity * dt
                }
            }
            return bodies
        }
        #expect(run() == run())
    }
}
