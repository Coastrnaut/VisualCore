// SpringWorldTests — feature 083 (A11-P02) T-A11-203 (FR-A11-210–212; clarifications 1, 4 and 5; research D1, D4,
// D5; SC-A11-201, 205). The world's springs and force levels, host-free and short:
// - Spring equilibrium (fixture 12): a wood box (half-size 0.3 m) hanging from a world anchor comes to rest within 2 %
//   of the analytic stretch m·g/k' after 10 s (1,200 ticks) at every stiffness level (k' the level's stiffness clamped
//   to the stable bound 0.1·m/dt²), and so does the starting scene's hanging box.
// - A stiffer level oscillates faster: the first half period of the hanging box shortens from level 0 to level 3 and
//   matches π·√(m/k') within 5 %.
// - Gravity levels (fixture 17): free fall for 1 s without drag gives 0, 1.62 and 9.81 m/s² within 1 %.
// - Drag levels (fixture 17): without gravity a speed decays as e^(−k·t) within 1 % over 1 s for k = 0, 0.05 and 1.0.
// - The level actions refuse out-of-range levels; the starting scene's springs and levels; the spring energy
//   ½·k'·(L − L₀)² and the total energy; validation refuses a spring to a missing body, a spring with both ends on one
//   body, more than 16 springs, non-finite numbers, a bad rest length, levels that do not match the settings and a
//   malformed contact cache; a world with an unsound spring is not simulated.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct SpringWorldTests {
    private let catalog = MaterialCatalog.bundled
    private let dt = 1.0 / 120.0

    /// The mass of a wood box of half-size 0.3 m (0.6 kg/m² × 0.36 m²).
    private let boxMass = 0.6 * 0.36

    /// A wood box (half-size 0.3 m) hanging from the world point (5, 7.5) by its top centre at rest length 1.5 m.
    private func hanging(stiffnessLevel: Int) -> PhysicsWorld {
        let box = PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(0.3, 0.3)), materialId: "wood",
                              position: Vec2(5, 7.5 - 1.5 - 0.3))
        let spring = WorldSpring(id: 0, a: .world(Vec2(5, 7.5)), b: .body(0, local: Vec2(0, 0.3)), restLength: 1.5)
        return PhysicsWorld(bodies: [box], springs: [spring], stiffnessLevel: stiffnessLevel)
    }

    /// The current stretch L − L₀ of `spring` in `world`.
    private func stretch(_ world: PhysicsWorld, _ spring: WorldSpring) -> Double {
        let a = world.anchorPosition(spring.a)!, b = world.anchorPosition(spring.b)!
        return (b - a).length - spring.restLength
    }

    /// The clamped stiffness k' of the hanging box at `level`.
    private func clamped(_ level: Int) -> Double {
        min(ForceLevels.stiffness[level], Springs2D.stableStiffness(effectiveMass: boxMass, dt: dt))
    }

    @Test(arguments: [0, 1, 2, 3])
    func aHangingBoxSettlesAtTheAnalyticStretch(level: Int) {
        var world = hanging(stiffnessLevel: level)
        #expect(world.validate(catalog: catalog).isEmpty)
        for _ in 0..<1_200 { #expect(WorldSimulation.tick(&world, catalog: catalog)) }
        let expected = boxMass * 9.81 / clamped(level)
        let measured = stretch(world, world.springs[0])
        #expect(abs(measured - expected) <= 0.02 * expected, "level \(level): \(measured) vs \(expected)")
        #expect(world.bodies[0].velocity.length < 0.01)
    }

    @Test func theStartingScenesHangingBoxSettlesAtTheAnalyticStretch() {
        var random = SeededRandom(seed: 1)
        var world = StartingScene.make(random: &random, catalog: catalog)
        for _ in 0..<1_200 { #expect(WorldSimulation.tick(&world, catalog: catalog)) }
        let expected = boxMass * 9.81 / clamped(ForceLevels.defaultStiffnessLevel)
        let measured = stretch(world, world.springs[0])
        #expect(abs(measured - expected) <= 0.02 * expected, "\(measured) vs \(expected)")
        #expect(world.validate(catalog: catalog).isEmpty)
    }

    @Test func aStifferLevelOscillatesFaster() {
        var halves: [Double] = []
        for level in 0...3 {
            var world = hanging(stiffnessLevel: level)
            var ticks = 0, moving = false
            // From rest at the rest length the box falls, then turns back up at the bottom: half a period.
            while ticks < 600 {
                WorldSimulation.tick(&world, catalog: catalog)
                ticks += 1
                let vy = world.bodies[0].velocity.y
                if vy < -1e-6 { moving = true }
                if moving && vy >= 0 { break }
            }
            let half = Double(ticks) * dt
            let analytic = Double.pi * (boxMass / clamped(level)).squareRoot()
            #expect(abs(half - analytic) <= 0.05 * analytic, "level \(level): \(half) vs \(analytic)")
            halves.append(half)
        }
        #expect(zip(halves, halves.dropFirst()).allSatisfy { $0 > $1 })
    }

    @Test func gravityLevelsGiveTheStatedAcceleration() {
        for level in 0...2 {
            var world = PhysicsWorld(bodies: [PhysicsBody(id: 0, shape: .circle(radius: 0.2), materialId: "wood",
                                                          position: Vec2(5, 7.5))])
            #expect(WorldSimulation.setGravityLevel(&world, level))
            #expect(WorldSimulation.setDragLevel(&world, 0))
            #expect(world.validate(catalog: catalog).isEmpty)
            for _ in 0..<120 { #expect(WorldSimulation.tick(&world, catalog: catalog)) }
            let g = ForceLevels.gravity[level], v = -world.bodies[0].velocity.y
            if g == 0 { #expect(v == 0 && world.bodies[0].position.y == 7.5) }
            else { #expect(abs(v - g) <= 0.01 * g) }
        }
        #expect(ForceLevels.gravity == [0, 1.62, 9.81] && ForceLevels.defaultGravityLevel == 2)
    }

    @Test func dragLevelsGiveTheStatedDecay() {
        for level in 0...2 {
            var world = PhysicsWorld(bodies: [PhysicsBody(id: 0, shape: .circle(radius: 0.2), materialId: "wood",
                                                          position: Vec2(2, 4), velocity: Vec2(2, 0),
                                                          angularVelocity: 3)])
            #expect(WorldSimulation.setGravityLevel(&world, 0))
            #expect(WorldSimulation.setDragLevel(&world, level))
            for _ in 0..<120 { #expect(WorldSimulation.tick(&world, catalog: catalog)) }
            let k = ForceLevels.drag[level], decay = exp(-k * 1.0)
            #expect(abs(world.bodies[0].velocity.x - 2 * decay) <= 0.01 * 2 * decay)
            #expect(abs(world.bodies[0].angularVelocity - 3 * decay) <= 0.01 * 3 * decay)
        }
        #expect(ForceLevels.drag == [0, 0.05, 1.0] && ForceLevels.defaultDragLevel == 1)
    }

    @Test func levelActionsRefuseOutOfRangeLevels() {
        var world = PhysicsWorld()
        let before = world
        #expect(!WorldSimulation.setGravityLevel(&world, 3) && !WorldSimulation.setGravityLevel(&world, -1))
        #expect(!WorldSimulation.setDragLevel(&world, 3) && !WorldSimulation.setStiffnessLevel(&world, 4))
        #expect(!WorldSimulation.setStiffnessLevel(&world, -1))
        #expect(world == before)
        #expect(WorldSimulation.setGravityLevel(&world, 1) && world.settings.gravity == Vec2(0, -1.62))
        #expect(WorldSimulation.setDragLevel(&world, 2))
        #expect(world.settings.linearDrag == 1.0 && world.settings.angularDrag == 1.0)
        #expect(WorldSimulation.setStiffnessLevel(&world, 3) && world.stiffnessLevel == 3)
        #expect(WorldSimulation.springStiffness(world) == 400)
        #expect(world.validate().isEmpty)
        #expect(ForceLevels.stiffness == [20, 60, 150, 400] && ForceLevels.defaultStiffnessLevel == 1)
        #expect(ForceLevels.springDampingRatio == 0.1 && ForceLevels.maxSprings == 16)
    }

    @Test func theStartingSceneHasTheTwoSpringsAndTheDefaultLevels() throws {
        var random = SeededRandom(seed: 42)
        let world = StartingScene.make(random: &random, catalog: catalog)
        #expect(world.gravityLevel == 2 && world.dragLevel == 1 && world.stiffnessLevel == 1)
        #expect(world.contactCache.isEmpty && world.springs.count == 2 && world.nextSpringId == 2)
        let hangingSpring = world.springs[0], pair = world.springs[1]
        #expect(hangingSpring.a == .world(Vec2(7.5, 8.0)) && hangingSpring.restLength == 1.5)
        let box = try #require(world.bodies.first { $0.id == hangingSpring.b.bodyId })
        #expect(box.materialId == "wood" && box.shape == .box(halfExtents: Vec2(0.3, 0.3)))
        #expect(abs(stretch(world, hangingSpring)) < 1e-12)
        #expect(pair.restLength == 1.0)
        for end in [pair.a, pair.b] {
            let ball = try #require(world.bodies.first { $0.id == end.bodyId })
            #expect(ball.materialId == "rubber" && ball.shape == .circle(radius: 0.3))
        }
        #expect(abs(stretch(world, pair)) < 1e-12)
        #expect(world.validate(catalog: catalog).isEmpty)
    }

    @Test func springEnergyIsHalfKPrimeTimesTheStretchSquared() {
        var world = hanging(stiffnessLevel: 3)
        world.bodies[0].position.y -= 0.2
        let k = clamped(3)
        #expect(k < 400)
        #expect(abs(WorldDiagnostics.springPotentialEnergy(world, catalog: catalog) - 0.5 * k * 0.04) < 1e-12)
        let total = WorldDiagnostics.kineticEnergy(world, catalog: catalog)
            + WorldDiagnostics.potentialEnergy(world, catalog: catalog)
            + WorldDiagnostics.springPotentialEnergy(world, catalog: catalog)
        #expect(WorldDiagnostics.totalEnergy(world, catalog: catalog) == total)
        // Two static ends store nothing.
        var pinned = world
        pinned.bodies[0].isStatic = true
        #expect(WorldDiagnostics.springPotentialEnergy(pinned, catalog: catalog) == 0)
    }

    @Test func validationRefusesBadSpringsLevelsAndCaches() {
        var random = SeededRandom(seed: 7)
        let good = StartingScene.make(random: &random, catalog: catalog)
        #expect(good.validate().isEmpty)
        func problems(_ change: (inout PhysicsWorld) -> Void) -> [String] {
            var world = good
            change(&world)
            return world.validate()
        }
        #expect(problems { $0.springs[1].b = .body(42) } == ["spring 1: end b body 42 does not exist"])
        #expect(problems { $0.springs[1].b = .body(8) } == ["spring 1: both ends on body 8"])
        #expect(problems { $0.springs[1].b = .world(Vec2(5, 5)) } == ["spring 1: end b is not a body"])
        #expect(problems { $0.springs[0].a = .world(Vec2(5, 9)) } == ["spring 0: end a world point outside the stage"])
        #expect(problems { $0.springs[1].restLength = .nan } == ["spring 1: non-finite value"])
        #expect(problems { $0.springs[0].a.point.x = .infinity } == ["spring 0: non-finite value"])
        #expect(problems { $0.springs[1].restLength = 0.05 } == ["spring 1: rest length 0.05 is outside 0.1…10 m"])
        #expect(problems { $0.springs[1].restLength = 10.5 } == ["spring 1: rest length 10.5 is outside 0.1…10 m"])
        #expect(problems { $0.springs[1].id = 0 } == ["spring 0: id is not above the previous id 0"])
        #expect(problems { $0.nextSpringId = 1 } == ["spring 1: id is not below nextSpringId 1"])
        let crowded = problems { world in
            for id in 2..<17 {
                world.springs.append(WorldSpring(id: id, a: .body(1), b: .body(2), restLength: 1))
            }
            world.nextSpringId = 17
        }
        #expect(crowded == ["spring count 17 exceeds 16"])
        #expect(problems { $0.gravityLevel = 3 } == ["gravityLevel 3 is outside 0…2"])
        #expect(problems { $0.gravityLevel = 1 } == ["settings.gravity does not match gravityLevel 1"])
        #expect(problems { $0.dragLevel = 2 } == ["settings.linearDrag does not match dragLevel 2",
                                                  "settings.angularDrag does not match dragLevel 2"])
        #expect(problems { $0.stiffnessLevel = 4 } == ["stiffnessLevel 4 is outside 0…3"])
        let entry = ContactCacheEntry(bodyA: 1, bodyB: 2, pointIndex: 0, normalImpulse: 0.1, tangentImpulse: 0)
        #expect(problems { $0.contactCache = [entry] }.isEmpty)
        #expect(problems { $0.contactCache = [entry, entry] } == ["contact cache 1: key is not above the previous key"])
        var bad = entry
        bad.normalImpulse = .nan
        #expect(problems { $0.contactCache = [bad] } == ["contact cache 0: non-finite value"])
        bad = entry
        bad.normalImpulse = -1
        #expect(problems { $0.contactCache = [bad] } == ["contact cache 0: normal impulse is negative"])
        bad = entry
        bad.bodyB = -5
        #expect(problems { $0.contactCache = [bad] }
                == ["contact cache 0: bodyB -5 is neither above bodyA nor a wall marker"])
        bad = entry
        bad.pointIndex = 2
        #expect(problems { $0.contactCache = [bad] } == ["contact cache 0: point index outside 0…1"])

        // A world with an unsound spring or mismatched levels is refused and unchanged.
        for change in [{ (w: inout PhysicsWorld) in w.springs[1].b = .body(42) },
                       { (w: inout PhysicsWorld) in w.gravityLevel = 0 },
                       { (w: inout PhysicsWorld) in w.springs[1].restLength = .infinity }] {
            var world = good
            change(&world)
            let before = world
            #expect(!WorldSimulation.tick(&world, catalog: catalog))
            #expect(world == before)
        }
    }
}
