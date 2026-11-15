// PresetTests — feature 085 (A11-P04) T-A11-402 (FR-A11-401, FR-A11-431; clarification 1; research D1; SC-A11-401).
// The four presets, host-free and short: each validates with its stated bodies, springs and levels; free play is the
// seeded starting scene with its exact draws, while the other presets are fixed and leave the generator untouched; the
// pendulum swings through the vertical within 2 s; the spring chain hangs straight down at rest lengths; the stack
// stands for 600 ticks (top box drift under 2 cm); the preset names, authors and licenses.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct PresetTests {
    private let catalog = MaterialCatalog.bundled

    private func make(_ id: PresetID, seed: UInt64 = 7) -> PhysicsWorld {
        var random = SeededRandom(seed: seed)
        return Presets.make(id, random: &random, catalog: catalog)
    }

    /// The common opening state: tick 0, running at normal speed, no selection, no grab, overlays off.
    private func expectFreshlyOpened(_ world: PhysicsWorld) {
        #expect(world.validate(catalog: catalog).isEmpty, "\(world.validate(catalog: catalog))")
        #expect(world.tick == 0 && !world.paused && world.timeScaleIndex == PhysicsWorld.normalTimeScaleIndex)
        #expect(world.remainder == 0 && world.selectedId == nil && world.grab == nil)
        #expect(!world.showVelocity && !world.showForces && world.contactCache.isEmpty)
        #expect(world.bodies.allSatisfy { $0.velocity == .zero && $0.angularVelocity == 0 })
    }

    @Test func freePlayIsTheSeededStartingSceneWithTheSameDraws() {
        var presetRandom = SeededRandom(seed: 11), sceneRandom = SeededRandom(seed: 11)
        let world = Presets.make(.freePlay, random: &presetRandom, catalog: catalog)
        #expect(world == StartingScene.make(random: &sceneRandom, catalog: catalog))
        #expect(presetRandom == sceneRandom)
        expectFreshlyOpened(world)
    }

    @Test(arguments: [PresetID.pendulum, .springChain, .stackedObjects])
    func fixedPresetsDoNotDrawAndAreDeterministic(id: PresetID) {
        var random = SeededRandom(seed: 3)
        let before = random
        let world = Presets.make(id, random: &random, catalog: catalog)
        #expect(random == before)
        #expect(world == make(id, seed: 99))
        #expect(world.encoded() == make(id, seed: 1).encoded())
        expectFreshlyOpened(world)
    }

    @Test func thePendulumHasAPinnedPivotAndABobAtThirtyDegrees() {
        let world = make(.pendulum)
        #expect(world.bodies.count == 2 && world.springs.count == 1)
        let pivot = world.bodies[0], bob = world.bodies[1]
        #expect(pivot.shape == .circle(radius: 0.15) && pivot.materialId == "steel" && pivot.pinned)
        #expect(pivot.position == Vec2(5, 7))
        #expect(bob.shape == .circle(radius: 0.3) && bob.materialId == "steel" && !bob.pinned && !bob.isStatic)
        let offset = bob.position - pivot.position
        #expect(abs(offset.length - 2.5) < 1e-12)
        #expect(abs(atan2(offset.x, -offset.y) - Double.pi / 6) < 1e-12)
        #expect(world.springs[0] == WorldSpring(id: 0, a: .body(0), b: .body(1), restLength: 2.5))
        #expect(world.gravityLevel == 2 && world.dragLevel == 0 && world.stiffnessLevel == 3)
        #expect(world.settings.linearDrag == 0 && world.settings.angularDrag == 0)
    }

    @Test func thePendulumSwingsThroughTheVerticalWithinTwoSeconds() {
        var world = make(.pendulum)
        var crossedAt: Int?
        for tick in 1...240 {
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            let offset = world.bodies[1].position - world.bodies[0].position
            if offset.x < 0 { crossedAt = tick; break }
        }
        // A quarter period of a 2.5 m pendulum is about (π/2)·√(2.5/9.81) ≈ 0.79 s ≈ 95 ticks.
        #expect(crossedAt != nil && crossedAt! > 60 && crossedAt! < 130, "crossed at \(String(describing: crossedAt))")
        #expect(world.bodies[0].position == Vec2(5, 7) && world.bodies[0].velocity == .zero)
    }

    @Test func theSpringChainHangsStraightDownAtRestLengths() {
        let world = make(.springChain)
        #expect(world.bodies.count == 5 && world.springs.count == 5)
        for (index, body) in world.bodies.enumerated() {
            #expect(body.id == index && body.shape == .circle(radius: 0.2) && body.materialId == "rubber")
            #expect(body.position.x == 5 && abs(body.position.y - (8 - 0.8 * Double(index + 1))) < 1e-12)
        }
        #expect(world.springs[0].a == .world(Vec2(5, 8)) && world.springs[0].b == .body(0))
        for index in 1..<5 {
            #expect(world.springs[index] == WorldSpring(id: index, a: .body(index - 1), b: .body(index),
                                                        restLength: 0.8))
        }
        for spring in world.springs {
            let length = (world.anchorPosition(spring.b)! - world.anchorPosition(spring.a)!).length
            #expect(abs(length - spring.restLength) < 1e-12 && spring.restLength == 0.8)
        }
        #expect(world.gravityLevel == 2 && world.dragLevel == 1 && world.stiffnessLevel == 2)
        #expect(WorldDiagnostics.springPotentialEnergy(world, catalog: catalog) < 1e-20)
    }

    @Test func theStackedObjectsRestOnEachOtherAndStandForFiveSeconds() {
        var world = make(.stackedObjects)
        #expect(world.bodies.count == 5 && world.springs.isEmpty)
        for (index, body) in world.bodies.enumerated() {
            #expect(body.shape == .box(halfExtents: Vec2(0.25, 0.25)) && body.materialId == "wood")
            #expect(body.position == Vec2(5, 0.25 + 0.5 * Double(index)))
        }
        #expect(world.gravityLevel == ForceLevels.defaultGravityLevel && world.dragLevel == ForceLevels.defaultDragLevel)
        #expect(world.stiffnessLevel == ForceLevels.defaultStiffnessLevel)
        let top = world.bodies[4].position
        var drift = 0.0
        for _ in 1...600 {
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            drift = max(drift, abs(world.bodies[4].position.x - top.x))
        }
        #expect(drift < 0.02 && abs(world.bodies[4].position.y - top.y) < 0.01)
        #expect(world.bodies.allSatisfy { abs($0.angle) < 0.1 })
    }

    @Test func presetsHaveNamesAuthorsAndLicenses() {
        #expect(PresetID.allCases.map(\.rawValue) == [0, 1, 2, 3])
        #expect(PresetID.allCases.map(\.name) == ["Free play", "Pendulum", "Spring chain", "Stacked objects"])
        #expect(PresetID.allCases.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        var random = SeededRandom(seed: 1)
        #expect(Presets.make(number: 4, random: &random, catalog: catalog) == nil)
        #expect(Presets.make(number: 2, random: &random, catalog: catalog) == make(.springChain))
    }
}
