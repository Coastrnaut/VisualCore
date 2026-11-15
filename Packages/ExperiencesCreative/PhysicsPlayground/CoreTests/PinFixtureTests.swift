// PinFixtureTests — feature 084 (A11-P03) T-A11-302 (FR-A11-302; research D1; SC-A11-302). The phase's regression
// fixture: a pinned body (and a static body of mass 0) is treated as static and never divided by zero, host-free and
// short:
// - a pinned steel box hit by rubber balls (one thrown at it again every 25 ticks) for 1,000 ticks keeps its position and angle bit-identical, its
//   velocity 0, and every number of the world stays finite; the balls really hit it (contact-cache entries name it);
// - unpinned, the same body regains its material mass and falls at g within 1 %;
// - a spring from a pinned body swings the other end while the pinned end stays put;
// - a static body of mass 0 in a spring and in contacts produces no non-finite value.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct PinFixtureTests {
    private let catalog = MaterialCatalog.bundled

    /// A pinned steel box in mid-air with five rubber balls above and beside it, thrown at it.
    private func impactWorld() -> PhysicsWorld {
        var bodies = [PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(0.8, 0.4)), materialId: "steel",
                                  position: Vec2(5, 3), angle: 0.3, pinned: true)]
        let starts: [(Vec2, Vec2)] = [(Vec2(4.6, 5.5), Vec2(0, -6)), (Vec2(5.4, 6.5), Vec2(0, -3)),
                                      (Vec2(2, 3.2), Vec2(8, 1)), (Vec2(8, 3), Vec2(-9, 2)),
                                      (Vec2(5, 7.5), Vec2(0.3, -10))]
        for (index, start) in starts.enumerated() {
            bodies.append(PhysicsBody(id: index + 1, shape: .circle(radius: 0.25), materialId: "rubber",
                                      position: start.0, velocity: start.1))
        }
        return PhysicsWorld(bodies: bodies)
    }

    @Test func aPinnedBodyHitForOneThousandTicksMovesByExactlyZero() {
        var world = impactWorld()
        #expect(world.validate(catalog: catalog).isEmpty)
        let pinned = world.bodies[0]
        var hits = 0
        for tick in 0..<1_000 {
            // Every 25 ticks one ball is thrown at the box again from above or from a side, in turn.
            if tick % 25 == 0 {
                let ball = 1 + (tick / 25) % 5
                let launches: [(Vec2, Vec2)] = [(Vec2(4.5, 5), Vec2(0.5, -8)), (Vec2(2.5, 3.2), Vec2(9, 0.5)),
                                              (Vec2(7.5, 3.4), Vec2(-9, 0.5)), (Vec2(5.6, 5.5), Vec2(-0.5, -9))]
                let (position, velocity) = launches[(tick / 25) % launches.count]
                world.bodies[ball].position = position
                world.bodies[ball].velocity = velocity
            }
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            let body = world.bodies[0]
            #expect(body.position == pinned.position && body.angle == pinned.angle)
            #expect(body.velocity == .zero && body.angularVelocity == 0)
            #expect(world.isFinite)
            if world.contactCache.contains(where: { $0.bodyA == 0 && $0.bodyB > 0 && $0.normalImpulse > 0 }) {
                hits += 1
            }
        }
        #expect(hits >= 20, "ticks with an impulse on the pinned body: \(hits)")
        #expect(world.validate(catalog: catalog).isEmpty)
        #expect(world.bodies[0].position.x.bitPattern == pinned.position.x.bitPattern)
        #expect(world.bodies[0].position.y.bitPattern == pinned.position.y.bitPattern)
        #expect(world.bodies[0].angle.bitPattern == pinned.angle.bitPattern)
    }

    @Test func unpinnedTheBodyRegainsItsMassAndFallsAtG() throws {
        var world = PhysicsWorld(bodies: [PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(0.3, 0.3)),
                                                      materialId: "wood", position: Vec2(5, 7), pinned: true)])
        #expect(WorldSimulation.setDragLevel(&world, 0))
        for _ in 0..<60 { WorldSimulation.tick(&world, catalog: catalog) }
        #expect(world.bodies[0].position == Vec2(5, 7))
        #expect(WorldEditing.togglePin(&world, id: 0) == nil)
        #expect(try #require(world.bodies[0].mass(in: catalog)) == 0.6 * 0.36)
        for _ in 0..<120 { #expect(WorldSimulation.tick(&world, catalog: catalog)) }
        let t = 1.0, g = 9.81
        let speed = -world.bodies[0].velocity.y
        let fall = 7 - world.bodies[0].position.y
        #expect(abs(speed - g * t) <= 0.01 * g * t, "speed \(speed)")
        #expect(abs(fall - 0.5 * g * t * t) <= 0.01 * 0.5 * g * t * t, "fall \(fall)")
    }

    @Test func aSpringFromAPinnedBodySwingsTheOtherEnd() {
        let anchor = PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(0.3, 0.3)), materialId: "wood",
                                 position: Vec2(5, 6), pinned: true)
        let bob = PhysicsBody(id: 1, shape: .circle(radius: 0.25), materialId: "rubber", position: Vec2(6.5, 6))
        let spring = WorldSpring(id: 0, a: .body(0, local: Vec2(0.3, 0)), b: .body(1), restLength: 1.2)
        var world = PhysicsWorld(bodies: [anchor, bob], springs: [spring], stiffnessLevel: 3)
        #expect(world.validate(catalog: catalog).isEmpty)
        var lowest = 6.0, leftmost = 6.5
        for _ in 0..<240 {
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            #expect(world.bodies[0].position == Vec2(5, 6) && world.bodies[0].angle == 0)
            #expect(world.bodies[0].velocity == .zero && world.isFinite)
            lowest = min(lowest, world.bodies[1].position.y)
            leftmost = min(leftmost, world.bodies[1].position.x)
        }
        // The bob swings down and inward around the pinned end.
        #expect(lowest < 5 && leftmost < 6)
        #expect(WorldDiagnostics.springPotentialEnergy(world, catalog: catalog).isFinite)
    }

    @Test func aStaticBodyOfMassZeroNeverDividesByZero() {
        let ledge = PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(1, 0.15)), materialId: "steel", isStatic: true,
                                position: Vec2(5, 5))
        let ball = PhysicsBody(id: 1, shape: .circle(radius: 0.3), materialId: "rubber", position: Vec2(5, 3.5))
        let spring = WorldSpring(id: 0, a: .body(0), b: .body(1), restLength: 1.0)
        var world = PhysicsWorld(bodies: [ledge, ball], springs: [spring])
        #expect(ledge.mass(in: catalog) == 0)
        var forces = ForceMeasurement()
        for _ in 0..<600 {
            #expect(WorldSimulation.tick(&world, catalog: catalog, forces: &forces))
            #expect(world.isFinite && world.bodies[0].position == Vec2(5, 5))
            #expect(forces.springForces.values.allSatisfy(\.isFinite) && forces.springForces[0] == nil)
        }
        #expect(WorldDiagnostics.totalEnergy(world, catalog: catalog).isFinite)
    }
}
