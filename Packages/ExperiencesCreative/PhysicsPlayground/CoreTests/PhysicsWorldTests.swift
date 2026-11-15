// PhysicsWorldTests — feature 082 (A11-P01) T-A11-103 (FR-A11-110, FR-A11-112; clarifications 1 and 4; data-model
// "PhysicsWorld"). The world record and the starting scene, host-free and short: defaults and units; mass = density ×
// area and inertia from `Shape2D`, static ⇔ mass 0; the JSON round trip with sorted keys is exact; `validate` names
// each problem (schema, settings, count, ids, non-finite values, sizes, unknown material, speeds, a moving static body,
// a centre outside the stage, tick, time-scale index and remainder); the seeded starting scene has the ledge and three
// circles and three boxes at rest in the upper half without overlap, and is the same for the same seed.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct PhysicsWorldTests {
    private let catalog = MaterialCatalog.bundled

    private func scene(_ seed: UInt64) -> PhysicsWorld {
        var random = SeededRandom(seed: seed)
        return StartingScene.make(random: &random, catalog: catalog)
    }

    @Test func defaultsUseTheStatedUnits() {
        let settings = WorldSettings()
        #expect(settings.gravity == Vec2(0, -9.81))
        #expect(settings.linearDrag == 0.05 && settings.angularDrag == 0.05)
        #expect(settings.tick == 1.0 / 120.0 && settings.iterations == 10)
        #expect(settings.stageSize == Vec2(10, 8))
        let world = PhysicsWorld()
        #expect(world.schema == 1 && world.tick == 0 && world.nextId == 0 && !world.paused)
        #expect(world.timeScaleIndex == 2 && world.remainder == 0)
        #expect(PhysicsWorld.timeScales == [0.25, 0.5, 1, 2] && PhysicsWorld.maxBodies == 48)
        #expect(world.validate().isEmpty)
    }

    @Test func massComesFromDensityAndAreaAndStaticBodiesHaveNone() throws {
        let circle = PhysicsBody(id: 0, shape: .circle(radius: 0.5), materialId: "rubber", position: Vec2(5, 4))
        let mass = try #require(circle.mass(in: catalog))
        #expect(abs(mass - 1.2 * Double.pi * 0.25) < 1e-12)
        #expect(abs(try #require(circle.inertia(in: catalog)) - mass * 0.25 / 2) < 1e-12)
        let box = PhysicsBody(id: 1, shape: .box(halfExtents: Vec2(0.5, 0.25)), materialId: "steel",
                              position: Vec2(5, 4))
        let boxMass = try #require(box.mass(in: catalog))
        #expect(abs(boxMass - 7.8 * 4 * 0.5 * 0.25) < 1e-12)
        #expect(abs(try #require(box.inertia(in: catalog)) - boxMass * (1.0 + 0.25) / 12) < 1e-12)
        var ledge = box
        ledge.isStatic = true
        #expect(ledge.mass(in: catalog) == 0 && ledge.inertia(in: catalog) == 0)
        var unknown = circle
        unknown.materialId = "lead"
        #expect(unknown.mass(in: catalog) == nil)
    }

    @Test func theJSONRoundTripIsExact() throws {
        var world = scene(42)
        world.tick = 17
        world.bodies[3].velocity = Vec2(1.0 / 3.0, -2.5)
        world.bodies[3].angularVelocity = 0.1
        let data = world.encoded()
        let back = try JSONDecoder().decode(PhysicsWorld.self, from: data)
        #expect(back == world)
        #expect(back.encoded() == data)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"bodies\":[{\"angle\":"))
        #expect(text.contains("\"schema\":1"))
    }

    @Test func validateNamesEachProblem() {
        let good = scene(7)
        #expect(good.validate().isEmpty)
        func problems(_ change: (inout PhysicsWorld) -> Void) -> [String] {
            var world = good
            change(&world)
            return world.validate()
        }
        #expect(problems { $0.schema = 2 } == ["schema 2 is not 1"])
        #expect(problems { $0.settings.gravity = Vec2(0, .nan) } == ["settings.gravity is not finite"])
        #expect(problems { $0.settings.gravity = Vec2(0, -25) } == ["settings.gravity exceeds 20.0 m/s²"])
        #expect(problems { $0.settings.linearDrag = 6 } == ["settings.linearDrag 6.0 is outside 0…5"])
        #expect(problems { $0.settings.angularDrag = -1 } == ["settings.angularDrag -1.0 is outside 0…5"])
        #expect(problems { $0.settings.tick = 1.0 / 60.0 }.first?.hasPrefix("settings.tick") == true)
        #expect(problems { $0.settings.iterations = 0 } == ["settings.iterations 0 is outside 1…20"])
        #expect(problems { $0.settings.iterations = 21 } == ["settings.iterations 21 is outside 1…20"])
        #expect(problems { $0.bodies[2].position.x = .infinity } == ["body 2: non-finite value"])
        #expect(problems { $0.bodies[2].angularVelocity = .nan } == ["body 2: non-finite value"])
        #expect(problems { $0.bodies[2].shape = .circle(radius: 0.1) } == ["body 2: size outside 0.15…1.0 m"])
        #expect(problems { $0.bodies[2].shape = .box(halfExtents: Vec2(0.5, 1.2)) }
                == ["body 2: size outside 0.15…1.0 m"])
        #expect(problems { $0.bodies[2].materialId = "lead" } == ["body 2: unknown material 'lead'"])
        #expect(problems { $0.bodies[2].velocity = Vec2(30, 30) } == ["body 2: speed exceeds 40 m/s"])
        #expect(problems { $0.bodies[2].angularVelocity = -41 } == ["body 2: angular speed exceeds 40 rad/s"])
        #expect(problems { $0.bodies[0].velocity = Vec2(0, 1) } == ["body 0: static body is moving"])
        #expect(problems { $0.bodies[2].position = Vec2(11, 4) } == ["body 2: centre outside the stage"])
        #expect(problems { $0.bodies[2].position = Vec2(5, -0.1) } == ["body 2: centre outside the stage"])
        #expect(problems { $0.bodies[2].id = 1 } == ["body 1: id is not above the previous id 1"])
        #expect(problems { $0.bodies.swapAt(1, 2) } == ["body 1: id is not above the previous id 2"])
        #expect(problems { $0.bodies[0].id = -1 } == ["body -1: id is negative"])
        #expect(problems { $0.nextId = 6 } == ["body 6: id is not below nextId 6"])
        #expect(problems { $0.tick = -1 } == ["tick -1 is negative"])
        #expect(problems { $0.timeScaleIndex = 4 } == ["timeScaleIndex 4 is outside 0…3"])
        #expect(problems { $0.remainder = 8 } == ["remainder 8 is outside 0…7"])
        #expect(problems { $0.remainder = 7 }.isEmpty)
        let crowded = problems { world in
            for id in 7..<50 {
                world.bodies.append(PhysicsBody(id: id, shape: .circle(radius: 0.2), materialId: "wood",
                                                position: Vec2(5, 4)))
            }
            world.nextId = 50
        }
        #expect(crowded == ["body count 50 exceeds 48"])
        let several = problems { $0.schema = 0; $0.bodies[1].materialId = "x"; $0.remainder = -1 }
        #expect(several.count == 3)
    }

    @Test func theStartingSceneHasTheLedgeAndSixBodiesAtRestWithoutOverlap() throws {
        for seed: UInt64 in [1, 2, 3, 42, 2026, 31_337, 99_999] {
            let world = scene(seed)
            #expect(world.validate().isEmpty)
            #expect(world.bodies.count == 7 && world.nextId == 7)
            #expect(world.bodies.map(\.id) == Array(0...6))
            let ledge = world.bodies[0]
            #expect(ledge.isStatic && ledge.materialId == "steel" && ledge.position == Vec2(2.0, 2.5))
            #expect(ledge.shape == .box(halfExtents: Vec2(1.0, 0.15)))
            let dynamic = Array(world.bodies.dropFirst())
            #expect(dynamic.allSatisfy { !$0.isStatic && $0.velocity == .zero && $0.angularVelocity == 0 })
            var circles = 0, boxes = 0
            for body in dynamic {
                switch body.shape {
                case .circle: circles += 1
                case .box: boxes += 1
                }
                #expect(body.sizes.allSatisfy { (0.25...0.6).contains($0) })
                #expect(body.position.y - body.boundingRadius >= 4)
                #expect(body.position.y + body.boundingRadius <= 8)
                #expect(body.position.x - body.boundingRadius >= 0 && body.position.x + body.boundingRadius <= 10)
                #expect(abs(body.angle) <= Double.pi)
                #expect(catalog.material(id: body.materialId) != nil)
            }
            #expect(circles == 3 && boxes == 3)
            for i in world.bodies.indices {
                for j in world.bodies.indices where j > i {
                    let a = world.bodies[i], b = world.bodies[j]
                    #expect(Contacts2D.collide(a.shape, a.pose, b.shape, b.pose) == nil)
                }
            }
        }
        #expect(scene(42) == scene(42))
        #expect(scene(42) != scene(43))
    }
}
