// StressTests — feature 086 (A11-P05) T-A11-502 (FR-A11-501; clarification 3; SC-A11-501). The seeded stress scenes,
// host-free and short:
// - Five seeds (1…5): free play filled to the 48-body cap by drops (one every 10 ticks), 16 springs (the starting
//   scene's two and fourteen more between seeded pairs of dynamic bodies, joined at their centres, rest length the
//   current distance clamped to 0.1…10 m), stiffness level 3; then 1,200 ticks in which every 30 ticks a seeded dynamic
//   body is selected and nudged by a seeded (dx, dy) in −1…1 and every 240 ticks seeded gravity, drag and stiffness
//   levels are set. Every tick: every number finite, every body centre inside the stage, speeds within the caps; at
//   the end the world validates.
// - The energy check: the same scene with drag low and no edits after its tick 0; the total energy sampled every second
//   (120 ticks) over 1,200 ticks never rises by more than 1 % of the previous sample.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

/// The stress scene of clarification 3 (shared with WorkBudgetTests).
enum StressScene {
    /// The number of springs of the scene.
    static let springCount = 16

    /// The filled scene of `seed` and the generator after it: free play, drops to 48 bodies, 16 springs, stiffness
    /// level 3 (and drag low unless `dragLevel` says otherwise).
    static func make(seed: UInt64, dragLevel: Int = ForceLevels.defaultDragLevel,
                     catalog: MaterialCatalog = .bundled) -> (PhysicsWorld, SeededRandom) {
        var random = SeededRandom(seed: seed)
        var world = StartingScene.make(random: &random, catalog: catalog)
        var tick = 0
        while world.bodies.count < PhysicsWorld.maxBodies {
            if tick.isMultiple(of: 10) {
                WorldSimulation.drop(&world, kind: (tick / 10).isMultiple(of: 2) ? .circle : .box, random: &random,
                                     catalog: catalog)
            }
            WorldSimulation.tick(&world, catalog: catalog)
            tick += 1
        }
        let dynamic = world.bodies.filter { !$0.isStatic }.map(\.id)
        var joined = Set(world.springs.compactMap { spring -> [Int]? in
            guard let a = spring.a.bodyId, let b = spring.b.bodyId else { return nil }
            return [min(a, b), max(a, b)]
        })
        while world.springs.count < springCount {
            let a = dynamic[random.index(below: dynamic.count)], b = dynamic[random.index(below: dynamic.count)]
            guard a != b, !joined.contains([min(a, b), max(a, b)]) else { continue }
            joined.insert([min(a, b), max(a, b)])
            let distance = (world.anchorPosition(.body(b))! - world.anchorPosition(.body(a))!).length
            let rest = min(max(distance, PhysicsWorld.restLengthRange.lowerBound), PhysicsWorld.restLengthRange.upperBound)
            world.springs.append(WorldSpring(id: world.nextSpringId, a: .body(a), b: .body(b), restLength: rest))
            world.nextSpringId += 1
        }
        WorldSimulation.setStiffnessLevel(&world, 3)
        WorldSimulation.setDragLevel(&world, dragLevel)
        return (world, random)
    }
}

@Suite struct StressTests {
    private let catalog = MaterialCatalog.bundled

    @Test(arguments: [UInt64(1), 2, 3, 4, 5])
    func stressScenesStayFiniteInsideAndCapped(seed: UInt64) {
        var (world, random) = StressScene.make(seed: seed)
        #expect(world.bodies.count == 48 && world.springs.count == 16 && world.stiffnessLevel == 3)
        #expect(world.validate(catalog: catalog).isEmpty)
        let dynamic = world.bodies.filter { !$0.isStatic }.map(\.id)
        var bad = 0, nudges = 0, levelChanges = 0, maxSpeed = 0.0
        for tick in 1...1_200 {
            if tick.isMultiple(of: 30) {
                let id = dynamic[random.index(below: dynamic.count)]
                let dx = random.range(-1...1), dy = random.range(-1...1)
                #expect(WorldEditing.select(&world, id: id) == nil)
                if WorldEditing.nudge(&world, dx: dx, dy: dy) == nil { nudges += 1 }
            }
            if tick.isMultiple(of: 240) {
                #expect(WorldSimulation.setGravityLevel(&world, random.index(below: 3)))
                #expect(WorldSimulation.setDragLevel(&world, random.index(below: 3)))
                #expect(WorldSimulation.setStiffnessLevel(&world, random.index(below: 4)))
                levelChanges += 1
            }
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            for body in world.bodies {
                maxSpeed = max(maxSpeed, body.velocity.length)
                if !body.isFinite || !world.isInsideStage(body.position)
                    || body.velocity.length > PhysicsWorld.speedCap + 1e-9
                    || abs(body.angularVelocity) > PhysicsWorld.angularSpeedCap + 1e-9 { bad += 1 }
            }
            if !world.isFinite { bad += 1 }
        }
        print("stress seed \(seed): nudges \(nudges), level changes \(levelChanges), max speed \(maxSpeed) m/s, "
              + "asleep at end \(world.bodies.filter(\.asleep).count)")
        #expect(bad == 0 && nudges == 40 && levelChanges == 5)
        #expect(world.validate(catalog: catalog).isEmpty && world.bodies.count == 48 && world.springs.count == 16)
    }

    @Test func theUneditedDampedSceneNeverGainsMoreThanOnePercentPerSecond() {
        var (world, _) = StressScene.make(seed: 1, dragLevel: 1)
        #expect(world.dragLevel == 1 && world.stiffnessLevel == 3)
        var samples = [WorldDiagnostics.totalEnergy(world, catalog: catalog)]
        for tick in 1...1_200 {
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            if tick.isMultiple(of: 120) { samples.append(WorldDiagnostics.totalEnergy(world, catalog: catalog)) }
        }
        let rises = zip(samples, samples.dropFirst()).map { ($1 - $0) / abs($0) }
        print("energy samples (J): \(samples.map { (($0 * 100).rounded() / 100) }); "
              + "largest rise per second \((rises.max() ?? 0) * 100) %")
        #expect(samples.count == 11 && samples.allSatisfy { $0.isFinite })
        #expect(rises.allSatisfy { $0 <= 0.01 }, "\(rises)")
    }
}
