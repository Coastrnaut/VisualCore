// WorldSimulationTests — feature 082 (A11-P01) T-A11-103 (FR-A11-111, FR-A11-112, FR-A11-113; clarifications 1 and 4;
// research D3, D4; SC-A11-102, 104). The tick rules, host-free and short: free fall for 1 s without drag matches g·t
// and g·t²/2 within 1 %; drag is the factor 1/(1 + k·dt); speeds are capped at 40 m/s and 40 rad/s; a world with a
// non-finite number or an unknown material is refused and unchanged; the walls lie just outside the stage; the time
// scales ¼, ½, 1 and 2 give the identical world after the same number of ticks; a paused world does not advance and a
// single step runs exactly one tick (refused while running); drops are seeded, at y = 7 m and refused at 48 bodies
// without touching the generator; the diagnostics measure energy and momentum without changing the world.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct WorldSimulationTests {
    private let catalog = MaterialCatalog.bundled

    private func scene(_ seed: UInt64) -> PhysicsWorld {
        var random = SeededRandom(seed: seed)
        return StartingScene.make(random: &random, catalog: catalog)
    }

    /// A world with one wood circle (radius 0.2 m) at `position` moving at `velocity`.
    private func single(at position: Vec2, velocity: Vec2 = .zero, settings: WorldSettings) -> PhysicsWorld {
        PhysicsWorld(settings: settings, bodies: [PhysicsBody(id: 0, shape: .circle(radius: 0.2), materialId: "wood",
                                                              position: position, velocity: velocity)])
    }

    @Test func freeFallForOneSecondMatchesTheTextbookWithinOnePercent() {
        let settings = WorldSettings(linearDrag: 0, angularDrag: 0)
        var world = single(at: Vec2(5, 7.5), settings: settings)
        for _ in 0..<120 { #expect(WorldSimulation.tick(&world, catalog: catalog)) }
        let body = world.bodies[0]
        let g = 9.81, t = 1.0
        #expect(world.tick == 120)
        #expect(abs(-body.velocity.y - g * t) <= 0.01 * g * t)
        #expect(abs((7.5 - body.position.y) - g * t * t / 2) <= 0.01 * g * t * t / 2)
        #expect(body.velocity.x == 0 && body.position.x == 5 && body.angle == 0)
    }

    @Test func dragIsTheFactorOneOverOnePlusKdt() {
        let settings = WorldSettings(gravity: .zero, linearDrag: 0.05, angularDrag: 0.05)
        var world = single(at: Vec2(5, 4), velocity: Vec2(2, 0), settings: settings)
        world.bodies[0].angularVelocity = 3
        WorldSimulation.tick(&world, catalog: catalog)
        let factor = 1 / (1 + 0.05 / 120)
        #expect(abs(world.bodies[0].velocity.x - 2 * factor) < 1e-12)
        #expect(abs(world.bodies[0].angularVelocity - 3 * factor) < 1e-12)
        #expect(abs(world.bodies[0].position.x - (5 + 2 * factor / 120)) < 1e-12)
    }

    @Test func speedsAreCapped() {
        let settings = WorldSettings(gravity: .zero, linearDrag: 0, angularDrag: 0)
        var world = single(at: Vec2(5, 4), velocity: Vec2(30, 40), settings: settings)
        world.bodies[0].angularVelocity = -55
        WorldSimulation.tick(&world, catalog: catalog)
        #expect(abs(world.bodies[0].velocity.length - 40) < 1e-9)
        #expect(world.bodies[0].angularVelocity == -40)
        #expect(world.validate().isEmpty)
    }

    @Test func unsoundWorldsAreRefusedAndUnchanged() {
        var world = scene(5)
        world.bodies[3].velocity = Vec2(.nan, 0)
        let before = world
        #expect(!WorldSimulation.tick(&world, catalog: catalog))
        #expect(WorldSimulation.advanceHostStep(&world, catalog: catalog) == 0)
        #expect(world == before)
        var unknown = scene(5)
        unknown.bodies[2].materialId = "lead"
        let kept = unknown
        #expect(!WorldSimulation.tick(&unknown, catalog: catalog))
        #expect(unknown == kept)
        var badScale = scene(5)
        badScale.timeScaleIndex = 9
        #expect(WorldSimulation.advanceHostStep(&badScale, catalog: catalog) == 0 && badScale.tick == 0)
        var badSettings = scene(5)
        badSettings.settings.iterations = 0
        #expect(!WorldSimulation.tick(&badSettings, catalog: catalog))
    }

    @Test func theWallsLieJustOutsideTheStage() {
        let walls = WorldSimulation.walls(for: WorldSettings())
        #expect(walls.count == 4)
        #expect(walls[0].pose.position == Vec2(5, -0.5) && walls[0].shape == .box(halfExtents: Vec2(6, 0.5)))
        #expect(walls[1].pose.position == Vec2(5, 8.5) && walls[1].shape == .box(halfExtents: Vec2(6, 0.5)))
        #expect(walls[2].pose.position == Vec2(-0.5, 4) && walls[2].shape == .box(halfExtents: Vec2(0.5, 5)))
        #expect(walls[3].pose.position == Vec2(10.5, 4) && walls[3].shape == .box(halfExtents: Vec2(0.5, 5)))
        #expect(WorldSimulation.wallRestitution == 0 && WorldSimulation.wallFriction == 0.5)
    }

    @Test func everyTimeScaleGivesTheSameWorldAfterTheSameTicks() {
        let ticks = 96
        var reference = scene(11)
        for _ in 0..<ticks { WorldSimulation.advanceHostStep(&reference, catalog: catalog) }
        #expect(reference.tick == ticks && reference.remainder == 0)
        for (index, hostSteps) in [(0, ticks * 4), (1, ticks * 2), (3, ticks / 2)] {
            var world = scene(11)
            world.timeScaleIndex = index
            var ran = 0
            for _ in 0..<hostSteps { ran += WorldSimulation.advanceHostStep(&world, catalog: catalog) }
            #expect(ran == ticks && world.tick == ticks && world.remainder == 0)
            #expect(world.bodies == reference.bodies)
        }
        var quarter = scene(11)
        quarter.timeScaleIndex = 0
        let counts = (0..<8).map { _ in WorldSimulation.advanceHostStep(&quarter, catalog: catalog) }
        #expect(counts == [0, 0, 0, 1, 0, 0, 0, 1])
        var double = scene(11)
        double.timeScaleIndex = 3
        #expect(WorldSimulation.advanceHostStep(&double, catalog: catalog) == 2 && double.tick == 2)
    }

    @Test func pauseBlocksAdvanceAndSingleStepRunsExactlyOneTick() {
        var world = scene(3)
        world.paused = true
        world.timeScaleIndex = 0
        world.remainder = 3
        let paused = world
        for _ in 0..<50 { #expect(WorldSimulation.advanceHostStep(&world, catalog: catalog) == 0) }
        #expect(world == paused)
        #expect(WorldSimulation.step(&world, catalog: catalog))
        #expect(world.tick == 1 && world.remainder == 3 && world.paused && world.timeScaleIndex == 0)
        var oneTick = paused
        WorldSimulation.tick(&oneTick, catalog: catalog)
        #expect(world == oneTick)
        world.paused = false
        let running = world
        #expect(!WorldSimulation.step(&world, catalog: catalog))
        #expect(world == running)
    }

    @Test func dropsAreSeededAndRefusedAtTheCap() throws {
        var world = scene(8)
        var random = SeededRandom(seed: 8_008)
        var drops = 0
        while WorldSimulation.drop(&world, kind: drops.isMultiple(of: 2) ? .circle : .box, random: &random,
                                   catalog: catalog) {
            drops += 1
        }
        #expect(drops == 38 && world.bodies.count == 48 && world.nextId == 48)
        let generator = random, full = world
        #expect(!WorldSimulation.drop(&world, kind: .circle, random: &random, catalog: catalog))
        #expect(world == full && random == generator)
        for body in world.bodies.dropFirst(10) {
            #expect(body.position.y == 7 && (1...9).contains(body.position.x))
            #expect(body.sizes.allSatisfy { (0.25...0.6).contains($0) })
            #expect(!body.isStatic && body.velocity == .zero && body.angularVelocity == 0)
        }
        let dropped = world.bodies[10]
        guard case .circle = dropped.shape else { Issue.record("first drop is not a circle"); return }
        guard case .box = world.bodies[11].shape else { Issue.record("second drop is not a box"); return }
        #expect(world.validate().isEmpty)
        var empty = scene(8)
        var other = SeededRandom(seed: 1)
        #expect(!WorldSimulation.drop(&empty, kind: .box, random: &other,
                                      catalog: MaterialCatalog(materials: [])))
        var a = scene(8), b = scene(8)
        var randomA = SeededRandom(seed: 5), randomB = SeededRandom(seed: 5)
        WorldSimulation.drop(&a, kind: .box, random: &randomA, catalog: catalog)
        WorldSimulation.drop(&b, kind: .box, random: &randomB, catalog: catalog)
        #expect(a == b && randomA == randomB)
    }

    @Test func diagnosticsMeasureEnergyAndMomentumWithoutChangingTheWorld() throws {
        var world = PhysicsWorld(settings: WorldSettings(gravity: Vec2(0, -10)), bodies: [
            PhysicsBody(id: 0, shape: .box(halfExtents: Vec2(1, 0.15)), materialId: "steel", isStatic: true,
                        position: Vec2(2, 2.5)),
            PhysicsBody(id: 1, shape: .box(halfExtents: Vec2(0.5, 0.5)), materialId: "wood", position: Vec2(5, 2),
                        velocity: Vec2(3, 4), angularVelocity: 2),
        ])
        let before = world
        let mass = 0.6 * 1.0, inertia = mass * 2.0 / 12
        #expect(abs(WorldDiagnostics.kineticEnergy(world, catalog: catalog)
                    - (0.5 * mass * 25 + 0.5 * inertia * 4)) < 1e-12)
        #expect(abs(WorldDiagnostics.potentialEnergy(world, catalog: catalog) - mass * 10 * 2) < 1e-12)
        let momentum = WorldDiagnostics.momentum(world, catalog: catalog)
        #expect(abs(momentum.x - mass * 3) < 1e-12 && abs(momentum.y - mass * 4) < 1e-12)
        #expect(world == before)
        world.bodies[1].velocity = .zero
        world.bodies[1].angularVelocity = 0
        #expect(WorldDiagnostics.kineticEnergy(world, catalog: catalog) == 0)
        #expect(WorldDiagnostics.momentum(world, catalog: catalog) == .zero)
    }
}
