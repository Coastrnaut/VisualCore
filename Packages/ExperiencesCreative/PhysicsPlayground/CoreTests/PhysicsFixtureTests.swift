// PhysicsFixtureTests — feature 082 (A11-P01) T-A11-103 (FR-A11-111, FR-A11-112; research D3, D5; SC-A11-101–103).
// The Phase 01 regression fixtures, host-free and short:
// - Two-body elastic momentum: two equal circles of a test material (restitution 1, inside the catalog's 0…1 range)
//   meet head-on in zero gravity without drag; the total momentum after the contact equals the total before within
//   1e-9 relative error and the velocities are exchanged within 2 %.
// - Static zero mass: a static steel ledge hit by falling and dropped bodies for 1,000 ticks moves by exactly 0.
// - Floor: a rubber ball dropped onto the floor bounces (restitution through max(eA, eB)) and never passes through it
//   (it sinks less than one tick of travel, 0.1 m, before the contact pushes it back).
// - Containment (SC-A11-101): five seeded starting scenes filled to the 48-body cap by drops (one every 10 ticks) run
//   2,400 ticks (20 s); no body centre ever leaves the stage and no number is ever non-finite.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct PhysicsFixtureTests {
    private let catalog = MaterialCatalog.bundled

    @Test func twoEqualCirclesHeadOnKeepMomentumAndExchangeVelocities() throws {
        let elastic = Material(id: "test-elastic", name: "Test elastic", fill: RGB(1, 1, 1), edge: RGB(0, 0, 0),
                               density: 1, restitution: 1, friction: 0, author: "VisualCore project", license: "MIT")
        #expect(MaterialCatalog.check(elastic) == nil)
        let testCatalog = MaterialCatalog(materials: catalog.materials + [elastic])
        let settings = WorldSettings(gravity: .zero, linearDrag: 0, angularDrag: 0)
        var world = PhysicsWorld(settings: settings, bodies: [
            PhysicsBody(id: 0, shape: .circle(radius: 0.5), materialId: "test-elastic", position: Vec2(3, 4),
                        velocity: Vec2(3, 0)),
            PhysicsBody(id: 1, shape: .circle(radius: 0.5), materialId: "test-elastic", position: Vec2(7, 4),
                        velocity: Vec2(-1, 0)),
        ])
        #expect(world.validate(catalog: testCatalog).isEmpty)
        let before = WorldDiagnostics.momentum(world, catalog: testCatalog)
        var touched = false
        for _ in 0..<180 {
            #expect(WorldSimulation.tick(&world, catalog: testCatalog))
            let a = world.bodies[0], b = world.bodies[1]
            if Contacts2D.collide(a.shape, a.pose, b.shape, b.pose) != nil { touched = true }
        }
        let after = WorldDiagnostics.momentum(world, catalog: testCatalog)
        #expect((after - before).length <= 1e-9 * before.length)
        let a = world.bodies[0], b = world.bodies[1]
        #expect(touched || b.position.x - a.position.x < 4)
        #expect(abs(a.velocity.x - (-1)) <= 0.02 * 1)
        #expect(abs(b.velocity.x - 3) <= 0.02 * 3)
        #expect(abs(a.velocity.y) < 1e-12 && abs(b.velocity.y) < 1e-12)
        #expect(a.position.x < b.position.x && b.position.x + 0.5 < 10)
    }

    @Test func aStaticLedgeMovesByExactlyZeroUnderOneThousandTicksOfImpacts() {
        var world = PhysicsWorld(bodies: [
            PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(1.0, 0.15)), materialId: "steel", isStatic: true,
                        position: Vec2(2.0, 2.5)),
            PhysicsBody(id: 1, shape: .circle(radius: 0.3), materialId: "rubber", position: Vec2(1.5, 3.5)),
            PhysicsBody(id: 2, shape: .box(halfExtents: Vec2(0.4, 0.3)), materialId: "steel", position: Vec2(2.4, 4.0),
                        angle: 0.4),
            PhysicsBody(id: 3, shape: .circle(radius: 0.5), materialId: "steel", position: Vec2(2.0, 5.5)),
            PhysicsBody(id: 4, shape: .box(halfExtents: Vec2(0.3, 0.3)), materialId: "wood", position: Vec2(1.2, 6.5),
                        velocity: Vec2(0, -10)),
        ])
        let ledge = world.bodies[0]
        var random = SeededRandom(seed: 404)
        var contactTicks = 0
        for tick in 0..<1_000 {
            if tick.isMultiple(of: 100) {
                WorldSimulation.drop(&world, kind: tick.isMultiple(of: 200) ? .circle : .box, random: &random,
                                     catalog: catalog)
                world.bodies[world.bodies.count - 1].position.x = 1.2 + Double(tick / 100) * 0.16
            }
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            #expect(world.bodies[0] == ledge)
            if world.bodies.dropFirst().contains(where: {
                Contacts2D.collide(ledge.shape, ledge.pose, $0.shape, $0.pose) != nil
            }) { contactTicks += 1 }
        }
        #expect(world.bodies[0].position == Vec2(2.0, 2.5) && world.bodies[0].angle == 0)
        #expect(world.bodies[0].velocity == .zero && world.bodies[0].angularVelocity == 0)
        #expect(contactTicks >= 100)
        #expect(world.bodies.allSatisfy { $0.isFinite })
    }

    @Test func aRubberBallBouncesOnTheFloorAndNeverPassesThrough() {
        var world = PhysicsWorld(bodies: [
            PhysicsBody(id: 0, shape: .circle(radius: 0.3), materialId: "rubber", position: Vec2(5, 6)),
        ])
        var lowest = 6.0, bounced = false, peakAfterBounce = 0.0
        for _ in 0..<360 {
            WorldSimulation.tick(&world, catalog: catalog)
            let body = world.bodies[0]
            lowest = min(lowest, body.position.y)
            if body.velocity.y > 1 { bounced = true }
            if bounced { peakAfterBounce = max(peakAfterBounce, body.position.y) }
        }
        #expect(bounced)
        #expect(lowest > 0.3 - 0.1)
        #expect(peakAfterBounce > 2 && peakAfterBounce < 6)
    }

    @Test(arguments: [UInt64(1), 2, 3, 4, 5])
    func bodiesNeverLeaveTheStageWhenFilledToTheCap(seed: UInt64) {
        var random = SeededRandom(seed: seed)
        var world = StartingScene.make(random: &random, catalog: catalog)
        var outside = 0, nonFinite = 0
        for tick in 0..<2_400 {
            if tick.isMultiple(of: 10), world.bodies.count < PhysicsWorld.maxBodies {
                #expect(WorldSimulation.drop(&world, kind: (tick / 10).isMultiple(of: 2) ? .circle : .box,
                                             random: &random, catalog: catalog))
            }
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            for body in world.bodies {
                let p = body.position, v = body.velocity
                if !(p.x.isFinite && p.y.isFinite && v.x.isFinite && v.y.isFinite && body.angle.isFinite
                     && body.angularVelocity.isFinite) { nonFinite += 1 }
                if p.x < 0 || p.x > 10 || p.y < 0 || p.y > 8 { outside += 1 }
            }
        }
        #expect(world.bodies.count == 48 && world.tick == 2_400)
        #expect(outside == 0 && nonFinite == 0)
        #expect(world.validate().isEmpty)
    }
}
