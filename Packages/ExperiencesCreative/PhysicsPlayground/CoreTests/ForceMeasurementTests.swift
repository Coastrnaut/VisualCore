// ForceMeasurementTests — feature 084 (A11-P03) T-A11-302 (FR-A11-310 inputs; clarification 4; research D3). The
// measured forces the arrows draw, host-free and short:
// - for a static stretch (body at rest, no gravity) the measured spring force equals k'·(L − L₀) along the spring,
//   toward the other end, and equals what `Springs2D` applied (m·Δv/dt);
// - the two ends of a body–body spring get equal and opposite forces; a pinned end gets the reaction and stays put;
// - the grab pull is never measured; the weight is m·g (a pinned body keeps its mass, a static body has none);
// - measuring never changes the world (identical bytes with and without), a refused tick leaves the measurement
//   unchanged, a measurement names its tick, and the settled hanging box's spring force balances its weight within 2 %.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct ForceMeasurementTests {
    private let catalog = MaterialCatalog.bundled
    private let dt = 1.0 / 120.0

    /// A wood box (half-size 0.3 m, mass 0.216 kg) at rest at (5, 4) hanging by its centre from the world point
    /// (5, 6.5) with rest length 1.5 m (stretch 1 m), gravity off and no drag.
    private func stretched(level: Int = 1) -> PhysicsWorld {
        let box = PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(0.3, 0.3)), materialId: "wood", position: Vec2(5, 4))
        let spring = WorldSpring(id: 0, a: .world(Vec2(5, 6.5)), b: .body(0), restLength: 1.5)
        var world = PhysicsWorld(bodies: [box], springs: [spring], stiffnessLevel: level)
        WorldSimulation.setGravityLevel(&world, 0)
        WorldSimulation.setDragLevel(&world, 0)
        return world
    }

    @Test(arguments: [0, 1, 2, 3])
    func aStaticStretchMeasuresKPrimeTimesTheStretch(level: Int) {
        var world = stretched(level: level)
        let mass = 0.6 * 0.36
        let k = min(ForceLevels.stiffness[level], Springs2D.stableStiffness(effectiveMass: mass, dt: dt))
        var forces = ForceMeasurement()
        #expect(WorldSimulation.tick(&world, catalog: catalog, forces: &forces))
        let force = forces.springForce(on: 0)
        // Toward the anchor (up), magnitude k'·(L − L₀) = k'·1 m.
        #expect(abs(force.x) < 1e-12 && abs(force.y - k * 1.0) <= 1e-9 * k, "level \(level): \(force) vs \(k)")
        // What Springs2D applied: m·Δv/dt (no gravity, drag or contact).
        let applied = world.bodies[0].velocity * (mass / dt)
        #expect((applied - force).length <= 1e-9 * k)
        #expect(forces.tick == 1 && forces.isCurrent(for: world))
    }

    @Test func aBodyToBodySpringGivesEqualAndOppositeForcesAndAPinnedEndTheReaction() {
        let a = PhysicsBody(id: 0, shape: .circle(radius: 0.3), materialId: "wood", position: Vec2(3, 4))
        let b = PhysicsBody(id: 1, shape: .circle(radius: 0.3), materialId: "rubber", position: Vec2(6, 4))
        let spring = WorldSpring(id: 0, a: .body(0), b: .body(1), restLength: 2)
        var world = PhysicsWorld(bodies: [a, b], springs: [spring])
        WorldSimulation.setGravityLevel(&world, 0)
        var forces = ForceMeasurement()
        #expect(WorldSimulation.tick(&world, catalog: catalog, forces: &forces))
        let fa = forces.springForce(on: 0), fb = forces.springForce(on: 1)
        #expect(fa.x > 0 && fb.x < 0 && (fa + fb).length < 1e-12)
        // Pin body 0: it gets the reaction and stays put; the stretch is the same, so the force on body 1 is k'·1 m.
        var pinned = PhysicsWorld(bodies: [a, b], springs: [spring])
        WorldSimulation.setGravityLevel(&pinned, 0)
        #expect(WorldEditing.togglePin(&pinned, id: 0) == nil)
        #expect(WorldSimulation.tick(&pinned, catalog: catalog, forces: &forces))
        let massB = 1.2 * Double.pi * 0.09
        let k = min(ForceLevels.stiffness[1], Springs2D.stableStiffness(effectiveMass: massB, dt: dt))
        #expect(abs(forces.springForce(on: 1).x + k) <= 1e-9 * k)
        #expect((forces.springForce(on: 0) + forces.springForce(on: 1)).length < 1e-12)
        #expect(pinned.bodies[0].position == Vec2(3, 4) && pinned.bodies[0].velocity == .zero)
    }

    @Test func theGrabPullIsNotMeasuredAndWeightIsMassTimesG() throws {
        var world = PhysicsWorld(bodies: [
            PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(1, 0.15)), materialId: "steel", isStatic: true,
                        position: Vec2(2, 2.5)),
            PhysicsBody(id: 1, shape: .circle(radius: 0.4), materialId: "steel", position: Vec2(6, 5)),
            PhysicsBody(id: 2, shape: .box(halfExtents: Vec2(0.3, 0.2)), materialId: "wood", position: Vec2(8, 5),
                        pinned: true),
        ])
        #expect(WorldEditing.grab(&world, id: 1, at: Vec2(6, 5)) == nil)
        #expect(WorldEditing.move(&world, to: Vec2(3, 7)) == nil)
        var forces = ForceMeasurement()
        #expect(WorldSimulation.tick(&world, catalog: catalog, forces: &forces))
        #expect(forces.springForces == [1: .zero, 2: .zero])
        #expect(world.bodies[1].velocity.length > 0.1)
        let steel = try #require(world.bodies[1].mass(in: catalog))
        #expect(ForceMeasurement.weight(of: world.bodies[1], in: world, catalog: catalog) == Vec2(0, -9.81) * steel)
        let wood = try #require(world.bodies[2].mass(in: catalog))
        #expect(wood > 0 && ForceMeasurement.weight(of: world.bodies[2], in: world, catalog: catalog)
            == Vec2(0, -9.81) * wood)
        #expect(ForceMeasurement.weight(of: world.bodies[0], in: world, catalog: catalog) == .zero)
    }

    @Test func measuringNeverChangesTheWorldAndARefusedTickKeepsTheMeasurement() {
        var random = SeededRandom(seed: 4)
        let start = StartingScene.make(random: &random, catalog: catalog)
        var plain = start, measured = start
        var forces = ForceMeasurement()
        for _ in 0..<120 {
            WorldSimulation.tick(&plain, catalog: catalog)
            WorldSimulation.tick(&measured, catalog: catalog, forces: &forces)
        }
        #expect(plain.encoded() == measured.encoded())
        #expect(forces.tick == 120 && forces.isCurrent(for: measured))
        // Host steps and the single step measure the same way.
        var hostPlain = start, hostMeasured = start
        for _ in 0..<30 {
            WorldSimulation.advanceHostStep(&hostPlain, catalog: catalog)
            WorldSimulation.advanceHostStep(&hostMeasured, catalog: catalog, forces: &forces)
        }
        #expect(hostPlain.encoded() == hostMeasured.encoded() && forces.tick == hostMeasured.tick)
        hostMeasured.paused = true
        #expect(WorldSimulation.step(&hostMeasured, catalog: catalog, forces: &forces) && forces.tick == hostMeasured.tick)
        // A refused tick changes neither the world nor the measurement.
        var broken = measured
        broken.bodies[1].velocity = Vec2(.nan, 0)
        let kept = forces
        #expect(!WorldSimulation.tick(&broken, catalog: catalog, forces: &forces))
        #expect(forces == kept)
        // A restored world has no current measurement until it ticks.
        #expect(!ForceMeasurement().isCurrent(for: measured))
    }

    @Test func theSettledHangingBoxsSpringForceBalancesItsWeight() throws {
        var random = SeededRandom(seed: 1)
        var world = StartingScene.make(random: &random, catalog: catalog)
        var forces = ForceMeasurement()
        for _ in 0..<1_200 { WorldSimulation.tick(&world, catalog: catalog, forces: &forces) }
        let box = try #require(world.bodies.first { $0.id == 7 })
        let weight = ForceMeasurement.weight(of: box, in: world, catalog: catalog)
        let spring = forces.springForce(on: 7)
        #expect((spring + weight).length <= 0.02 * weight.length, "\(spring) vs \(weight)")
        // The joined circles pull on each other equally and oppositely.
        #expect((forces.springForce(on: 8) + forces.springForce(on: 9)).length < 1e-9)
    }
}
