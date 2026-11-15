// MigrationTests — feature 083 (A11-P02) T-A11-203 (FR-A11-210; clarification 4; research D4, D5; SC-A11-206). The
// world record's schema 2 and the migration from schema 1 (fixture 18), host-free and short:
// - A schema-1 world JSON exactly as feature 082 wrote it decodes through `PhysicsWorld.decode(_:)` into a sound
//   schema-2 world with the same bodies, tick, ids, pause flag and time scale, no springs (next spring id 0), Earth
//   gravity, low drag, stiffness level 1 and an empty contact cache; the strict schema-2 decoder refuses it (the
//   migration is explicit, never a silent default).
// - `PhysicsWorld.migrated(fromSchemaOne:)` writes the default levels' gravity and drags into the settings and keeps
//   the stage, tick and iterations; every A11-P01 starting scene (re-expressed as schema 1) migrates to a sound world.
// - Another schema number is refused; a schema-2 world with springs, levels and a contact cache round-trips exactly.
// Updated by feature 084 (A11-P03) T-A11-302 (FR-A11-320; clarification 5; SC-A11-305) for schema 3: schema-1 records
// migrate 1 → 2 → 3 (nothing pinned, no selection, no grab, overlays off); a schema-2 record (as feature 083 wrote it,
// without `pinned`) migrates 2 → 3 keeping every field; the strict schema-3 decoder refuses both; schema 4 is refused;
// a schema-3 world with pins, a selection, a grab and overlays round-trips exactly.
// Updated by feature 086 (A11-P05) T-A11-502 (FR-A11-502; clarification 1) for schema 4: every migration ends with every
// body awake and 0 rest ticks; a schema-3 record (without `asleep` and `restTicks`) migrates 3 → 4 keeping every other
// field; schema 5 is refused; a schema-4 world with sleeping bodies, pins, a selection, a grab and overlays round-trips
// exactly.
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
        #expect(world.schema == 4 && world.validate(catalog: catalog).isEmpty)
        #expect(world.bodies.allSatisfy { !$0.asleep && $0.restTicks == 0 })
        #expect(world.bodies.allSatisfy { !$0.pinned } && world.selectedId == nil && world.grab == nil)
        #expect(!world.showVelocity && !world.showForces)
        #expect(world.bodies.map(\.id) == [0, 3] && world.nextId == 4)
        #expect(world.bodies[1].shape == .circle(radius: 0.3) && world.bodies[1].materialId == "rubber")
        #expect(world.bodies[1].velocity == Vec2(1.5, -2) && world.bodies[1].angularVelocity == -1.25)
        #expect(world.bodies[0].isStatic && world.bodies[0].position == Vec2(2, 2.5))
        #expect(world.tick == 314 && world.paused && world.timeScaleIndex == 1 && world.remainder == 2)
        #expect(world.springs.isEmpty && world.nextSpringId == 0 && world.contactCache.isEmpty)
        #expect(world.gravityLevel == 2 && world.dragLevel == 1 && world.stiffnessLevel == 1)
        #expect(world.settings == WorldSettings())
        // The strict schema-3 decoder does not guess the missing fields.
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
        let five = Self.schemaOneJSON.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":5")
        #expect(throws: PhysicsWorld.DecodeError.unsupportedSchema(5)) {
            try PhysicsWorld.decode(Data(five.utf8))
        }
        #expect(throws: DecodingError.self) { try PhysicsWorld.decode(Data("{}".utf8)) }
    }

    /// A schema-2 record of `world` exactly as feature 083 wrote it: no `pinned` keys, none of the schema-3 fields.
    private func schemaTwoData(_ world: PhysicsWorld) throws -> Data {
        var object = try #require(try JSONSerialization.jsonObject(with: world.encoded()) as? [String: Any])
        object["schema"] = 2
        for key in ["selectedId", "grab", "showVelocity", "showForces"] { object.removeValue(forKey: key) }
        let bodies = try #require(object["bodies"] as? [[String: Any]])
        object["bodies"] = bodies.map { body -> [String: Any] in
            var body = body
            body.removeValue(forKey: "pinned")
            body.removeValue(forKey: "asleep")
            body.removeValue(forKey: "restTicks")
            return body
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    @Test func aSchemaTwoWorldMigratesToSchemaThreeKeepingEveryField() throws {
        var random = SeededRandom(seed: 11)
        var world = StartingScene.make(random: &random, catalog: catalog)
        WorldSimulation.setGravityLevel(&world, 1)
        WorldSimulation.setDragLevel(&world, 2)
        WorldSimulation.setStiffnessLevel(&world, 3)
        for _ in 0..<600 { WorldSimulation.tick(&world, catalog: catalog) }
        #expect(!world.contactCache.isEmpty)
        let data = try schemaTwoData(world)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"schema\":2") && !text.contains("pinned") && !text.contains("showForces"))
        // The strict schema-3 decoder refuses it; the migrating decoder keeps every schema-2 field.
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(PhysicsWorld.self, from: data) }
        let migrated = try PhysicsWorld.decode(data)
        // Schema 4 (feature 086): the migrated bodies are awake with 0 rest ticks; the run may have put some to sleep.
        Sleep.wakeAll(&world)
        #expect(migrated == world)
        #expect(migrated.schema == 4 && migrated.validate(catalog: catalog).isEmpty)
        #expect(migrated.bodies.allSatisfy { !$0.pinned } && migrated.selectedId == nil && migrated.grab == nil)
        #expect(!migrated.showVelocity && !migrated.showForces)
        let old = try JSONDecoder().decode(PhysicsWorld.SchemaTwo.self, from: data)
        #expect(PhysicsWorld.migrated(fromSchemaTwo: old) == world)
        // The migrated world continues exactly like the original.
        var a = world, b = migrated
        for _ in 0..<60 { WorldSimulation.tick(&a, catalog: catalog); WorldSimulation.tick(&b, catalog: catalog) }
        #expect(a.encoded() == b.encoded())
    }

    /// A schema-3 record of `world` exactly as feature 084 wrote it: no `asleep` or `restTicks` keys.
    private func schemaThreeData(_ world: PhysicsWorld) throws -> Data {
        var object = try #require(try JSONSerialization.jsonObject(with: world.encoded()) as? [String: Any])
        object["schema"] = 3
        let bodies = try #require(object["bodies"] as? [[String: Any]])
        object["bodies"] = bodies.map { body -> [String: Any] in
            var body = body
            body.removeValue(forKey: "asleep")
            body.removeValue(forKey: "restTicks")
            return body
        }
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    @Test func aSchemaThreeWorldMigratesToSchemaFourAwake() throws {
        var random = SeededRandom(seed: 12)
        var world = StartingScene.make(random: &random, catalog: catalog)
        for _ in 0..<480 { WorldSimulation.tick(&world, catalog: catalog) }
        #expect(WorldEditing.togglePin(&world, id: 2) == nil)
        #expect(WorldEditing.select(&world, id: 3) == nil)
        world.showForces = true
        let data = try schemaThreeData(world)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"schema\":3") && !text.contains("asleep") && !text.contains("restTicks"))
        let migrated = try PhysicsWorld.decode(data)
        #expect(migrated.schema == 4 && migrated.validate(catalog: catalog).isEmpty)
        #expect(migrated.bodies.allSatisfy { !$0.asleep && $0.restTicks == 0 })
        var awake = world
        Sleep.wakeAll(&awake)
        #expect(migrated == awake)
        let three = try JSONDecoder().decode(PhysicsWorld.self, from: data)
        #expect(three.schema == 3 && PhysicsWorld.migrated(fromSchemaThree: three) == awake)
    }

    @Test func aSchemaFourWorldRoundTripsExactly() throws {
        var random = SeededRandom(seed: 11)
        var world = Presets.make(.stackedObjects, random: &random, catalog: catalog)
        for _ in 0..<360 { WorldSimulation.tick(&world, catalog: catalog) }
        #expect(world.bodies.allSatisfy { $0.asleep })
        let data = world.encoded()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"schema\":4") && text.contains("\"asleep\":true") && text.contains("\"restTicks\":60"))
        let back = try PhysicsWorld.decode(data)
        #expect(back == world && back.encoded() == data)
    }

    @Test func aSchemaThreeWorldRoundTripsExactly() throws {
        var random = SeededRandom(seed: 11)
        var world = StartingScene.make(random: &random, catalog: catalog)
        WorldSimulation.setStiffnessLevel(&world, 3)
        for _ in 0..<240 { WorldSimulation.tick(&world, catalog: catalog) }
        #expect(WorldEditing.togglePin(&world, id: 1) == nil)
        #expect(WorldEditing.select(&world, id: 2) == nil)
        #expect(WorldEditing.grab(&world, id: 3, at: world.bodies[3].position + Vec2(0.05, 0)) == nil)
        world.showVelocity = true
        world.showForces = true
        #expect(world.validate(catalog: catalog) == [])
        let data = world.encoded()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"schema\":4") && text.contains("\"pinned\":true") && text.contains("\"grab\":{"))
        #expect(text.contains("\"selectedId\":2") && text.contains("\"showForces\":true"))
        let back = try PhysicsWorld.decode(data)
        #expect(back == world && back.encoded() == data)
        #expect(try JSONDecoder().decode(PhysicsWorld.self, from: data) == world)
    }
}
