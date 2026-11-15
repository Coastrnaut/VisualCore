// MigrationTests — feature 083 (A11-P02) T-A11-203 (FR-A11-210; clarification 4; research D4, D5; SC-A11-206). The
// world record's schema 2 and the migration from schema 1 (fixture 18), host-free and short:
// - A schema-1 world JSON exactly as feature 082 wrote it decodes through `PhysicsWorld.decode(_:)` into a sound
//   schema-2 world with the same bodies, tick, ids, pause flag and time scale, no springs (next spring id 0), Earth
//   gravity, low drag, stiffness level 1 and an empty contact cache; the strict schema-2 decoder refuses it (the
//   migration is explicit, never a silent default).
// - `PhysicsWorld.migrated(fromSchemaOne:)` writes the default levels' gravity and drags into the settings and keeps
//   the stage, tick and iterations; every A11-P01 starting scene (re-expressed as schema 1) migrates to a sound world.
// - Another schema number is refused; a schema-2 world with springs, levels and a contact cache round-trips exactly.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct MigrationTests {
    private let catalog = MaterialCatalog.bundled

    /// A world saved by feature 082 (schema 1): the steel ledge and a moving rubber ball, paused at half speed.
    private static let schemaOneJSON = """
    {"bodies":[{"angle":0,"angularVelocity":0,"id":0,"isStatic":true,"materialId":"steel",\
    "position":{"x":2,"y":2.5},"shape":{"box":{"halfExtents":{"x":1,"y":0.15}}},"velocity":{"x":0,"y":0}},\
    {"angle":0.5,"angularVelocity":-1.25,"id":3,"isStatic":false,"materialId":"rubber",\
    "position":{"x":6,"y":3},"shape":{"circle":{"radius":0.3}},"velocity":{"x":1.5,"y":-2}}],\
    "nextId":4,"paused":true,"remainder":2,"schema":1,"settings":{"angularDrag":0.05,\
    "gravity":{"x":0,"y":-9.81},"iterations":10,"linearDrag":0.05,"stageSize":{"x":10,"y":8},\
    "tick":0.008333333333333333},"tick":314,"timeScaleIndex":1}
    """

    @Test func aSchemaOneWorldJSONMigratesWithDefaults() throws {
        let data = Data(Self.schemaOneJSON.utf8)
        let world = try PhysicsWorld.decode(data)
        #expect(world.schema == 2 && world.validate(catalog: catalog).isEmpty)
        #expect(world.bodies.map(\.id) == [0, 3] && world.nextId == 4)
        #expect(world.bodies[1].shape == .circle(radius: 0.3) && world.bodies[1].materialId == "rubber")
        #expect(world.bodies[1].velocity == Vec2(1.5, -2) && world.bodies[1].angularVelocity == -1.25)
        #expect(world.bodies[0].isStatic && world.bodies[0].position == Vec2(2, 2.5))
        #expect(world.tick == 314 && world.paused && world.timeScaleIndex == 1 && world.remainder == 2)
        #expect(world.springs.isEmpty && world.nextSpringId == 0 && world.contactCache.isEmpty)
        #expect(world.gravityLevel == 2 && world.dragLevel == 1 && world.stiffnessLevel == 1)
        #expect(world.settings == WorldSettings())
        // The strict schema-2 decoder does not guess the missing fields.
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(PhysicsWorld.self, from: data) }
        // The migrated world simulates.
        var running = world
        running.paused = false
        #expect(WorldSimulation.advanceHostStep(&running, catalog: catalog) >= 0)
        #expect(WorldSimulation.tick(&running, catalog: catalog))
    }

    @Test func migrationWritesTheDefaultLevelsIntoTheSettings() {
        let old = PhysicsWorld.SchemaOne(settings: WorldSettings(gravity: Vec2(0, -3), linearDrag: 0.4,
                                                                 angularDrag: 0.2, iterations: 7),
                                         bodies: [], tick: 9, nextId: 5)
        let world = PhysicsWorld.migrated(fromSchemaOne: old)
        #expect(world.settings.gravity == Vec2(0, -9.81))
        #expect(world.settings.linearDrag == 0.05 && world.settings.angularDrag == 0.05)
        #expect(world.settings.iterations == 7 && world.settings.stageSize == Vec2(10, 8))
        #expect(world.tick == 9 && world.nextId == 5 && world.validate().isEmpty)
    }

    @Test func everyPhaseOneShapedWorldMigrates() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for seed: UInt64 in [1, 2, 3, 42, 2026] {
            var random = SeededRandom(seed: seed)
            let modern = StartingScene.make(random: &random, catalog: catalog)
            let old = PhysicsWorld.SchemaOne(settings: modern.settings, bodies: modern.bodies, tick: modern.tick,
                                             nextId: modern.nextId, paused: modern.paused,
                                             timeScaleIndex: modern.timeScaleIndex, remainder: modern.remainder)
            let world = try PhysicsWorld.decode(try encoder.encode(old))
            #expect(world == PhysicsWorld.migrated(fromSchemaOne: old))
            #expect(world.bodies == modern.bodies && world.springs.isEmpty)
            #expect(world.validate(catalog: catalog).isEmpty)
        }
    }

    @Test func anotherSchemaIsRefused() {
        let three = Self.schemaOneJSON.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":3")
        #expect(throws: PhysicsWorld.DecodeError.unsupportedSchema(3)) {
            try PhysicsWorld.decode(Data(three.utf8))
        }
        #expect(throws: DecodingError.self) { try PhysicsWorld.decode(Data("{}".utf8)) }
    }

    @Test func aSchemaTwoWorldRoundTripsExactly() throws {
        var random = SeededRandom(seed: 11)
        var world = StartingScene.make(random: &random, catalog: catalog)
        WorldSimulation.setGravityLevel(&world, 1)
        WorldSimulation.setDragLevel(&world, 2)
        WorldSimulation.setStiffnessLevel(&world, 3)
        for _ in 0..<600 { WorldSimulation.tick(&world, catalog: catalog) }
        #expect(!world.contactCache.isEmpty)
        #expect(world.validate(catalog: catalog) == [])
        let data = world.encoded()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"schema\":2") && text.contains("\"springs\":[") && text.contains("\"contactCache\":["))
        let back = try PhysicsWorld.decode(data)
        #expect(back == world && back.encoded() == data)
        #expect(try JSONDecoder().decode(PhysicsWorld.self, from: data) == world)
    }
}
