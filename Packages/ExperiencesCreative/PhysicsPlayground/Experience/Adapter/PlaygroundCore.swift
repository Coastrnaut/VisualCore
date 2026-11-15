// PlaygroundCore — feature 082 (A11-P01) T-A11-104 (FR-A11-120, FR-A11-121; clarifications 4 and 5; research D4;
// contract "Experience actions"). The state of Physics Playground as an experience: a `PlaygroundState` (the
// `PhysicsWorld` and the seeded generator's state) and the preparation seed. Preparing builds the seeded starting scene
// (`StartingScene.make`); a host step (1/120 s) is `WorldSimulation.advanceHostStep`, which does nothing while the
// world is paused and otherwise runs the time scale's whole ticks (¼ one tick every fourth host step, 2 two ticks per
// host step). The session steps the core only while it runs, so a suspension never fast-forwards the world.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange` and a non-finite value with `nonFinite` before the core sees it):
//   world.pause [0…1]      0 running, 1 paused; a value that is not exactly 0 or 1 is refused with
//                          `a11.invalid-choice`.
//   world.step             no values: exactly one tick while paused; refused with `a11.not-paused` while running.
//   world.timeScale [0…3]  ¼, ½, 1 or 2 by index; a fractional value is refused with `a11.invalid-choice`.
//   world.reset            no values: the starting scene of the preparation seed, time scale 1×, running; the
//                          generator restarts from the seed (the same as the core's `reset()`).
//   world.drop [0…1]       0 circle, 1 box: a seeded body at rest at y = 7 m (`WorldSimulation.drop`); refused with
//                          `a11.body-cap` at 48 bodies; a fractional value is refused with `a11.invalid-choice`.
// A refusal changes nothing (neither the world nor the generator). The replay is the seed plus the applied actions with
// their steps (research D4).
//
// Feature 083 (A11-P02) T-A11-204 (FR-A11-210, FR-A11-221; clarification 4; research D4; data-model "Snapshot";
// contract "Experience actions") adds three level actions, applied through the core's `WorldSimulation` helpers (which
// keep the settings' gravity and drags equal to the levels):
//   world.gravity [0…2]    off, Moon (1.62 m/s²) or Earth (9.81 m/s²) (`WorldSimulation.setGravityLevel`);
//   world.drag [0…2]       none (0), low (0.05 s⁻¹) or high (1.0 s⁻¹) (`WorldSimulation.setDragLevel`);
//   world.stiffness [0…3]  20, 60, 150 or 400 N/m for every spring (`WorldSimulation.setStiffnessLevel`);
// a fractional value is refused with `a11.invalid-choice`. `world.reset` and `reset()` give the starting scene with its
// two springs, the default levels (Earth, low drag, stiffness level 1) and an empty contact cache.
//
// Snapshot schema 2: `PlaygroundState` as JSON with sorted keys, holding the schema-2 world (springs, levels and the
// contact cache); the preparation seed and the schema version come from the snapshot envelope
// (`MigrationChain(currentVersion: 2)`, so a newer payload is refused by the engine). The step 1 → 2 decodes a Phase 01
// payload (its world at schema 1, `PhysicsWorld.SchemaOne`), migrates the world with
// `PhysicsWorld.migrated(fromSchemaOne:)` — no springs, Earth gravity, low drag, stiffness level 1, an empty cache,
// everything else kept — keeps the generator state untouched and re-encodes it. A payload that does not decode as
// schema 2 (a schema-1 payload that skipped the migration lacks the schema-2 keys), whose world does not validate
// (`PhysicsWorld.validate(catalog:)` names a problem) or whose generator state is malformed is refused (the restore
// throws). `schemaOneExample()` is the stored Phase 01 payload the registry's migration check restores. One quality
// tier (`level-0`). The digest is the canonical text of the whole state: the world (settings, bodies, tick, next id,
// paused, time-scale index, remainder, springs, next spring id, levels and contact cache) and the generator state.
//
// Feature 084 (A11-P03) T-A11-303 (FR-A11-301, FR-A11-303, FR-A11-320; clarifications 1, 4, 5; research D1, D3;
// data-model "Snapshot"; contract contracts/actions.md) adds the ten edit and overlay actions, each applied through
// the core's `WorldEditing` on a copy (a refusal changes nothing) with the refusal codes of `EditRefusal.code`:
//   edit.add [x 0…10, y 0…8, kind 0…1]   a seeded body of the kind centred at the point (`WorldEditing.add`, drawing
//                                        from the generator); `a11.body-cap`, `a11.no-room`;
//   edit.select [id −1…10000]            −1 clears; `a11.unknown-body`;
//   edit.grab [id 0…10000, x 0…10, y 0…8] the grab of a dynamic, unpinned body at the point; `a11.unknown-body`,
//                                        `a11.not-grabbable`;
//   edit.move [x −1…11, y −1…9]           the grab's target (any point of the drawn view, clamped into the stage by the
//                                        core); `a11.no-grab`;
//   edit.release                         ends the grab; `a11.no-grab`;
//   edit.pin [id 0…10000]                pins or unpins; `a11.unknown-body`, `a11.static-body`;
//   edit.delete [id 0…10000]             the body with its springs, cache entries, grab and selection;
//                                        `a11.unknown-body`;
//   edit.nudge [dx −1…1, dy −1…1]        1 m/s × value added to the selected body; `a11.no-selection`,
//                                        `a11.not-grabbable`;
//   overlay.velocity [0…1], overlay.forces [0…1]  the world's overlay flags (drawing only).
// A fractional kind, id or overlay value is refused with `a11.invalid-choice`.
//
// Snapshot schema 3: the schema-3 world (pins, selection, grab, overlay flags). `MigrationChain(currentVersion: 3)`
// has the steps 1 → 2 (a Phase 01 payload to a faithful Phase 02 payload: the world as `PhysicsWorld.SchemaTwo`,
// written without the `pinned` key) and 2 → 3 (`PhysicsWorld.migrated(fromSchemaTwo:)`: no pins, no selection, no
// grab, overlays off; the generator kept). `schemaTwoExample()` is the stored Phase 02 payload the registry's
// migration check restores. A host step runs the measured advance
// (`WorldSimulation.advanceHostStep(_:catalog:forces:)`) and keeps the measured spring forces of the last tick in
// `PlaygroundCore.forces`: derived data for the force arrows, never encoded, never digested and not part of the core's
// equality (a restored or reset core has none until its next tick). Reset gives the starting scene with no pins, no
// selection, no grab and both overlays off.
import Foundation
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreMath
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Physics Playground's refusals.
public enum PlaygroundRule {
    /// A choice value that is not a whole number naming an entry of the action's table.
    public static let invalidChoice = "a11.invalid-choice"
    /// A single step asked for while the world is running.
    public static let notPaused = "a11.not-paused"
    /// A drop or an add asked for while the world already holds the most bodies (48).
    public static let bodyCap = "a11.body-cap"
    /// An added body would leave the stage or overlap another body too much (feature 084).
    public static let noRoom = EditRefusal.noRoom.code
    /// No body has the id (feature 084).
    public static let unknownBody = EditRefusal.unknownBody.code
    /// The body is static or pinned and cannot be grabbed or nudged (feature 084).
    public static let notGrabbable = EditRefusal.notGrabbable.code
    /// There is no grab to move or release (feature 084).
    public static let noGrab = EditRefusal.noGrab.code
    /// A static body cannot be pinned or unpinned (feature 084).
    public static let staticBody = EditRefusal.staticBody.code
    /// There is no selected body to nudge (feature 084).
    public static let noSelection = EditRefusal.noSelection.code
}

/// The saved state of Physics Playground at snapshot schema 1 (feature 082): the schema-1 world and the generator
/// state, exactly the keys A11-P01 wrote.
public struct PlaygroundStateSchemaOne: Codable, Equatable, Sendable {
    /// The schema-1 world.
    public var world: PhysicsWorld.SchemaOne
    /// The state of the generator that draws dropped bodies.
    public var random: SeededRandom.State

    /// A schema-1 state of `world` with the generator state `random`.
    public init(world: PhysicsWorld.SchemaOne, random: SeededRandom.State) {
        self.world = world
        self.random = random
    }
}

/// The saved state of Physics Playground at snapshot schema 2 (feature 083): the schema-2 world and the generator
/// state, exactly the keys A11-P02 wrote.
public struct PlaygroundStateSchemaTwo: Codable, Equatable, Sendable {
    /// The schema-2 world.
    public var world: PhysicsWorld.SchemaTwo
    /// The state of the generator that draws dropped bodies.
    public var random: SeededRandom.State

    /// A schema-2 state of `world` with the generator state `random`.
    public init(world: PhysicsWorld.SchemaTwo, random: SeededRandom.State) {
        self.world = world
        self.random = random
    }
}

/// Why a stored playground state is refused.
public enum PlaygroundRestoreError: Error, Equatable {
    /// The world does not validate (its problems, from `PhysicsWorld.validate(catalog:)`).
    case invalidWorld([String])
    /// The generator state cannot be restored.
    case invalidGenerator
    /// A payload handed to the step 1 → 2 whose world is not at schema 1 (the schema it names).
    case notSchemaOne(Int)
    /// A payload handed to the step 2 → 3 whose world is not at schema 2 (the schema it names; feature 084).
    case notSchemaTwo(Int)
}

/// The saved state of Physics Playground (snapshot schema 3): the world and the generator state.
public struct PlaygroundState: Codable, Equatable, Sendable {
    /// The physics world.
    public var world: PhysicsWorld
    /// The state of the generator that draws dropped bodies.
    public var random: SeededRandom.State

    /// A state of `world` with the generator state `random`.
    public init(world: PhysicsWorld, random: SeededRandom.State) {
        self.world = world
        self.random = random
    }
}

/// The state of Physics Playground. Schema version 3.
public struct PlaygroundCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a11.physics-playground"

    /// The outcome while the world runs.
    public static let runningOutcome = "world-running"
    /// The outcome while the world is paused.
    public static let pausedOutcome = "world-paused"

    /// The action ids in declaration order.
    public static let actionIDs = ["world.pause", "world.step", "world.timeScale", "world.reset", "world.drop",
                                   "world.gravity", "world.drag", "world.stiffness",
                                   "edit.add", "edit.select", "edit.grab", "edit.move", "edit.release", "edit.pin",
                                   "edit.delete", "edit.nudge", "overlay.velocity", "overlay.forces"]

    /// The edit actions a canvas gesture sends (feature 084; each also reachable through a native control).
    public static let gestureActionIDs: Set<String> = ["edit.add", "edit.select", "edit.grab", "edit.move",
                                                       "edit.release", "edit.pin", "edit.delete"]

    /// The snapshot schema this build writes.
    public static let snapshotSchema = 3

    /// The largest body id an edit action names.
    public static let maxBodyId = 10_000

    /// The materials the world uses: the bundled catalog (it validates: `MaterialCatalog.decode` of its encoding
    /// refuses nothing, which the tests check).
    public static var catalog: MaterialCatalog { MaterialCatalog.bundled }

    /// The preparation seed; `reset()` and `world.reset` return to the first state built from it.
    public private(set) var preparationSeed: UInt64
    /// The physics world.
    public private(set) var world: PhysicsWorld
    /// The generator of the starting scene and of dropped bodies.
    public private(set) var generator: SeededRandom
    /// The spring forces measured by the last tick a host step or a single step ran (feature 084): derived data for
    /// the force arrows, never encoded, never digested and not compared by `==`; empty after preparation, restore and
    /// reset until the next tick.
    public private(set) var forces = ForceMeasurement()

    /// The first state prepared with `seed`: a generator seeded by `seed` and the starting scene drawn from it (the
    /// static ledge, three circles and three boxes at rest, the hanging box and the joined circles with their two
    /// springs, the default levels, an empty contact cache, no pins, no selection, no grab, both overlays off, tick 0,
    /// running at 1×).
    public init(seed: UInt64) {
        preparationSeed = seed
        var random = SeededRandom(seed: seed)
        world = StartingScene.make(random: &random, catalog: Self.catalog)
        generator = random
    }

    /// A core holding `state`, prepared with `seed`; throws when the generator state cannot be restored.
    init(seed: UInt64, state: PlaygroundState) throws {
        preparationSeed = seed
        world = state.world
        do {
            generator = try SeededRandom(restoring: state.random)
        } catch {
            throw PlaygroundRestoreError.invalidGenerator
        }
    }

    /// Two cores are equal when their preparation seeds, worlds and generators are; the measured ``forces`` are
    /// derived data and are not compared.
    public static func == (lhs: PlaygroundCore, rhs: PlaygroundCore) -> Bool {
        lhs.preparationSeed == rhs.preparationSeed && lhs.world == rhs.world && lhs.generator == rhs.generator
    }

    /// The whole state: the world and the generator state.
    public var state: PlaygroundState { PlaygroundState(world: world, random: generator.state) }

    // MARK: Contract

    /// One host step is the world's fixed tick, 1/120 s.
    public static var stepDuration: Double { WorldSettings.fixedTick }

    /// One quality tier (`level-0`): the drawing has nothing to scale down.
    public static var qualityTiers: Int { 1 }

    /// Schema 3 (feature 084). The step 1 → 2 (``migratedToSchemaTwo(_:)``) turns a Phase 01 payload into a Phase 02
    /// payload; the step 2 → 3 (``migratedToSchemaThree(_:)``) turns a Phase 02 payload into a schema-3 payload. A
    /// payload that does not decode is refused by its step (the engine reports the migration as failed).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: snapshotSchema, steps: [
            1: { payload in try migratedToSchemaTwo(payload) },
            2: { payload in try migratedToSchemaThree(payload) },
        ])
    }

    /// The schema-2 record of a world: every schema-2 field of `world` (its pins, selection, grab and overlay flags
    /// dropped).
    static func schemaTwo(of world: PhysicsWorld) -> PhysicsWorld.SchemaTwo {
        var bodies = world.bodies
        for index in bodies.indices { bodies[index].pinned = false }
        return PhysicsWorld.SchemaTwo(settings: world.settings, bodies: bodies, tick: world.tick, nextId: world.nextId,
                                      paused: world.paused, timeScaleIndex: world.timeScaleIndex,
                                      remainder: world.remainder, springs: world.springs,
                                      nextSpringId: world.nextSpringId, gravityLevel: world.gravityLevel,
                                      dragLevel: world.dragLevel, stiffnessLevel: world.stiffnessLevel,
                                      contactCache: world.contactCache)
    }

    /// `value` encoded with sorted keys as a JSON object, every body of its world written without the `pinned` key
    /// (as schemas 1 and 2 wrote bodies).
    static func objectWithoutPins<Value: Encodable>(_ value: Value) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard var object = try JSONSerialization.jsonObject(with: encoder.encode(value)) as? [String: Any],
              var world = object["world"] as? [String: Any],
              var bodies = world["bodies"] as? [[String: Any]] else {
            throw PlaygroundRestoreError.invalidWorld(["the state is not a JSON object with a world and bodies"])
        }
        for index in bodies.indices { bodies[index]["pinned"] = nil }
        world["bodies"] = bodies
        object["world"] = world
        return object
    }

    /// The step 1 → 2: `payload` decoded as a ``PlaygroundStateSchemaOne`` (its world must name schema 1), the world
    /// migrated (no springs, Earth, low drag, stiffness level 1, an empty cache; bodies, tick, ids, pause and time
    /// scale kept) and written as a Phase 02 payload (``PlaygroundStateSchemaTwo``, bodies without `pinned`), the
    /// generator state kept. Not validated here; the restore validates.
    static func migratedToSchemaTwo(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let old = try JSONDecoder().decode(PlaygroundStateSchemaOne.self, from: data)
        guard old.world.schema == 1 else { throw PlaygroundRestoreError.notSchemaOne(old.world.schema) }
        let world = schemaTwo(of: PhysicsWorld.migrated(fromSchemaOne: old.world))
        return try objectWithoutPins(PlaygroundStateSchemaTwo(world: world, random: old.random))
    }

    /// The step 2 → 3: `payload` decoded as a ``PlaygroundStateSchemaTwo`` (its world must name schema 2), the world
    /// migrated with `PhysicsWorld.migrated(fromSchemaTwo:)` (no pins, no selection, no grab, overlays off; everything
    /// else kept), the generator state kept, and the state encoded again as a JSON object. Not validated here; the
    /// restore validates.
    static func migratedToSchemaThree(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let old = try JSONDecoder().decode(PlaygroundStateSchemaTwo.self, from: data)
        guard old.world.schema == 2 else { throw PlaygroundRestoreError.notSchemaTwo(old.world.schema) }
        let state = PlaygroundState(world: PhysicsWorld.migrated(fromSchemaTwo: old.world), random: old.random)
        guard let object = try JSONSerialization.jsonObject(with: encode(state)) as? [String: Any] else {
            throw PlaygroundRestoreError.invalidWorld(["the migrated state is not a JSON object"])
        }
        return object
    }

    /// The A11-P01 starting scene of `random`: the static ledge and three circles and three boxes in six slots across
    /// the whole upper half of the stage (each 10/3 m wide; the draws exactly as `StartingScene.make` makes them), no
    /// springs, as feature 082 built it. Used only to write the stored Phase 01 example.
    static func phaseOneScene(random: inout SeededRandom) -> PhysicsWorld.SchemaOne {
        let stage = WorldSettings.defaultStage
        var bodies = [PhysicsBody(id: 0, shape: .box(halfExtents: StartingScene.ledgeHalfExtents),
                                  materialId: StartingScene.ledgeMaterialId, isStatic: true,
                                  position: StartingScene.ledgeCenter)]
        var kinds: [BodyKind] = [.circle, .circle, .circle, .box, .box, .box]
        random.shuffle(&kinds)
        let slotWidth = stage.x / 3, slotHeight = stage.y / 4, margin = 0.05
        for (slot, kind) in kinds.enumerated() {
            let column = Double(slot % 3), row = Double(slot / 3)
            let center = Vec2(slotWidth * (column + 0.5), stage.y / 2 + slotHeight * (row + 0.5))
            let first = random.range(StartingScene.sizeRange), second = random.range(StartingScene.sizeRange)
            let materialIndex = random.index(below: max(catalog.materials.count, 1))
            let angle = random.range(-Double.pi...Double.pi)
            let shape: Shape2D = kind == .circle ? .circle(radius: first) : .box(halfExtents: Vec2(first, second))
            let bound = kind == .circle ? first : Vec2(first, second).length
            let spanX = slotWidth / 2 - bound - margin, spanY = slotHeight / 2 - bound - margin
            let offset = Vec2(random.range(-spanX...spanX), random.range(-spanY...spanY))
            bodies.append(PhysicsBody(id: slot + 1, shape: shape, materialId: catalog.materials[materialIndex].id,
                                      position: center + offset, angle: angle))
        }
        return PhysicsWorld.SchemaOne(bodies: bodies, nextId: bodies.count)
    }

    /// The actions the stored Phase 01 example was saved after, all at step 0 (A11-P01 actions only): drop a circle,
    /// drop a box, half speed, pause.
    public static let schemaOneExampleActions: [(control: String, values: [Double])] = [
        ("world.drop", [0]), ("world.drop", [1]), ("world.timeScale", [1]), ("world.pause", [1]),
    ]

    /// The A11-P01 state of seed `seed` after ``schemaOneExampleActions`` at step 0: the Phase 01 starting scene, a
    /// dropped circle and a dropped box (ids 7 and 8, drawn by `WorldSimulation.drop`'s five draws each, as A11-P01
    /// drew them), half speed, paused, tick 0, and the generator after those draws. No tick has run, so this is
    /// exactly what A11-P01 saved for that seed and those actions.
    public static func schemaOneExampleState(seed: UInt64 = 7) -> PlaygroundStateSchemaOne {
        var random = SeededRandom(seed: seed)
        var old = phaseOneScene(random: &random)
        // Dropped through the current helper on a world without springs: the same five draws as A11-P01's drop.
        var world = PhysicsWorld(bodies: old.bodies, nextId: old.nextId)
        for kind in [BodyKind.circle, .box] {
            _ = WorldSimulation.drop(&world, kind: kind, random: &random, catalog: catalog)
        }
        old.bodies = world.bodies
        old.nextId = world.nextId
        old.timeScaleIndex = 1
        old.paused = true
        return PlaygroundStateSchemaOne(world: old, random: random.state)
    }

    /// The stored example of `version` for the registry's migration check: `payload` in an envelope of that schema
    /// version at step 0, with the digest its restore through the migration chain gives. Nil only if a step failed.
    static func migrationExample(version: Int, payload: [String: Any], seed: UInt64) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let upgraded = try? migrations.migrate(payload, from: version),
              let migrated = try? JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]),
              let restored = try? restore(payload: migrated, seed: seed) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? restored.writeDigest(into: &builder)) != nil else { return nil }
        let digest = builder.finish()
        guard let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: version, seed: seed, stepIndex: 0,
                                                     digest: digest, payload: data),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: version, snapshot: encoded, expectedDigest: digest.hex)
    }

    /// The stored example of schema 1 for the registry's migration check (feature 083, T-A11-204): the A11-P01 payload
    /// ``schemaOneExampleState(seed:)`` — written as A11-P01 wrote it (the world at schema 1 without springs, levels
    /// or contact cache, bodies without `pinned`) at step 0 — with the digest its restore through the migration chain
    /// (1 → 2 → 3) must give: the same bodies, tick, ids, pause, time scale and generator, with no springs, Earth
    /// gravity, low drag, stiffness level 1, an empty cache, no pins, no selection, no grab and overlays off. Nil only
    /// if the encoding failed.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let payload = try? objectWithoutPins(schemaOneExampleState(seed: seed)) else { return nil }
        return migrationExample(version: 1, payload: payload, seed: seed)
    }

    /// The actions the stored Phase 02 example was saved after, all at step 0 (A11-P02 actions only): drop a circle,
    /// drop a box, stiff springs, Moon gravity, high drag, half speed, pause.
    public static let schemaTwoExampleActions: [(control: String, values: [Double])] = [
        ("world.drop", [0]), ("world.drop", [1]), ("world.stiffness", [2]), ("world.gravity", [1]),
        ("world.drag", [2]), ("world.timeScale", [1]), ("world.pause", [1]),
    ]

    /// The A11-P02 state of seed `seed` after ``schemaTwoExampleActions`` at step 0: the starting scene of ten bodies
    /// and two springs, a dropped circle and a dropped box (ids 10 and 11), stiffness level 2, Moon gravity, high drag,
    /// half speed, paused, tick 0, an empty contact cache, and the generator after those draws. No tick has run and
    /// the actions are A11-P02's, so this is exactly what A11-P02 saved for that seed and those actions.
    public static func schemaTwoExampleState(seed: UInt64 = 7) -> PlaygroundStateSchemaTwo {
        var core = PlaygroundCore(seed: seed)
        for action in schemaTwoExampleActions {
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: 0))
        }
        return PlaygroundStateSchemaTwo(world: schemaTwo(of: core.world), random: core.generator.state)
    }

    /// The stored example of schema 2 for the registry's migration check (feature 084, T-A11-303): the A11-P02 payload
    /// ``schemaTwoExampleState(seed:)`` — the world at schema 2 (springs, levels and contact cache; bodies without
    /// `pinned`; no selection, grab or overlay keys) at step 0 — with the digest its restore through the step 2 → 3
    /// must give: everything kept, no pins, no selection, no grab and overlays off. Nil only if the encoding failed.
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let payload = try? objectWithoutPins(schemaTwoExampleState(seed: seed)) else { return nil }
        return migrationExample(version: 2, payload: payload, seed: seed)
    }

    /// The eighteen controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        let id = -1...Double(maxBodyId), body = 0...Double(maxBodyId)
        let stage = WorldSettings.defaultStage, wall = WorldSimulation.wallThickness
        return [ExperienceControl(id: "world.pause", ranges: [0...1]),
                ExperienceControl(id: "world.step"),
                ExperienceControl(id: "world.timeScale", ranges: [0...3]),
                ExperienceControl(id: "world.reset"),
                ExperienceControl(id: "world.drop", ranges: [0...1]),
                ExperienceControl(id: "world.gravity", ranges: [0...2]),
                ExperienceControl(id: "world.drag", ranges: [0...2]),
                ExperienceControl(id: "world.stiffness", ranges: [0...3]),
                ExperienceControl(id: "edit.add", ranges: [0...stage.x, 0...stage.y, 0...1]),
                ExperienceControl(id: "edit.select", ranges: [id]),
                ExperienceControl(id: "edit.grab", ranges: [body, 0...stage.x, 0...stage.y]),
                ExperienceControl(id: "edit.move", ranges: [-wall...(stage.x + wall), -wall...(stage.y + wall)]),
                ExperienceControl(id: "edit.release"),
                ExperienceControl(id: "edit.pin", ranges: [body]),
                ExperienceControl(id: "edit.delete", ranges: [body]),
                ExperienceControl(id: "edit.nudge", ranges: [-1...1, -1...1]),
                ExperienceControl(id: "overlay.velocity", ranges: [0...1]),
                ExperienceControl(id: "overlay.forces", ranges: [0...1])]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> PlaygroundCore {
        try Task.checkCancellation()
        return PlaygroundCore(seed: seed)
    }

    /// One host step: the measured `WorldSimulation.advanceHostStep` (nothing while paused; otherwise the time
    /// scale's whole ticks), keeping the spring forces of the last tick it ran in ``forces``.
    public mutating func update(step: Int) {
        WorldSimulation.advanceHostStep(&world, catalog: Self.catalog, forces: &forces)
    }

    /// The number of values each action carries.
    static let valueCounts: [String: Int] = [
        "world.pause": 1, "world.step": 0, "world.timeScale": 1, "world.reset": 0, "world.drop": 1,
        "world.gravity": 1, "world.drag": 1, "world.stiffness": 1, "edit.add": 3, "edit.select": 1, "edit.grab": 3,
        "edit.move": 2, "edit.release": 0, "edit.pin": 1, "edit.delete": 1, "edit.nudge": 2, "overlay.velocity": 1,
        "overlay.forces": 1,
    ]

    /// Carries out a well-formed action (the engine checked the control, the value count, finiteness and ranges);
    /// a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard let expected = Self.valueCounts[action.control] else {
            return .rejected(.unknownControl(action.control))
        }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        if action.control.hasPrefix("edit.") || action.control.hasPrefix("overlay.") { return applyEdit(action) }
        switch action.control {
        case "world.pause":
            guard let i = Self.choice(v[0], count: 2) else {
                return .rejected(.rule(code: PlaygroundRule.invalidChoice))
            }
            world.paused = i == 1
        case "world.step":
            guard world.paused else { return .rejected(.rule(code: PlaygroundRule.notPaused)) }
            var next = world, measured = forces
            // A validated world can always be ticked; a world that could not is refused like a running one.
            guard WorldSimulation.step(&next, catalog: Self.catalog, forces: &measured) else {
                return .rejected(.rule(code: PlaygroundRule.notPaused))
            }
            world = next
            forces = measured
        case "world.timeScale":
            guard let i = Self.choice(v[0], count: PhysicsWorld.timeScales.count) else {
                return .rejected(.rule(code: PlaygroundRule.invalidChoice))
            }
            world.timeScaleIndex = i
        case "world.reset":
            self = PlaygroundCore(seed: preparationSeed)
        case "world.gravity":
            var next = world
            guard let i = Self.choice(v[0], count: ForceLevels.gravity.count),
                  WorldSimulation.setGravityLevel(&next, i) else {
                return .rejected(.rule(code: PlaygroundRule.invalidChoice))
            }
            world = next
        case "world.drag":
            var next = world
            guard let i = Self.choice(v[0], count: ForceLevels.drag.count),
                  WorldSimulation.setDragLevel(&next, i) else {
                return .rejected(.rule(code: PlaygroundRule.invalidChoice))
            }
            world = next
        case "world.stiffness":
            var next = world
            guard let i = Self.choice(v[0], count: ForceLevels.stiffness.count),
                  WorldSimulation.setStiffnessLevel(&next, i) else {
                return .rejected(.rule(code: PlaygroundRule.invalidChoice))
            }
            world = next
        default:   // world.drop
            guard let i = Self.choice(v[0], count: 2), let kind = BodyKind(rawValue: i) else {
                return .rejected(.rule(code: PlaygroundRule.invalidChoice))
            }
            guard world.bodies.count < PhysicsWorld.maxBodies else {
                return .rejected(.rule(code: PlaygroundRule.bodyCap))
            }
            var next = world
            var random = generator
            guard WorldSimulation.drop(&next, kind: kind, random: &random, catalog: Self.catalog) else {
                return .rejected(.rule(code: PlaygroundRule.bodyCap))
            }
            world = next
            generator = random
        }
        return .accepted
    }

    /// The edit and overlay actions (feature 084): each edit runs on a copy of the world (and of the generator for
    /// `edit.add`) and is kept only when `WorldEditing` accepts it; a refusal is reported with its `EditRefusal.code`.
    mutating func applyEdit(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        let invalid = ActionResult.rejected(.rule(code: PlaygroundRule.invalidChoice))
        var next = world
        var random = generator
        let refusal: EditRefusal?
        switch action.control {
        case "edit.add":
            guard let i = Self.choice(v[2], count: 2), let kind = BodyKind(rawValue: i) else { return invalid }
            refusal = WorldEditing.add(&next, kind: kind, at: Vec2(v[0], v[1]), random: &random, catalog: Self.catalog)
        case "edit.select":
            guard let id = Self.wholeNumber(v[0]) else { return invalid }
            refusal = WorldEditing.select(&next, id: id)
        case "edit.grab":
            guard let id = Self.wholeNumber(v[0]) else { return invalid }
            refusal = WorldEditing.grab(&next, id: id, at: Vec2(v[1], v[2]))
        case "edit.move":
            refusal = WorldEditing.move(&next, to: Vec2(v[0], v[1]))
        case "edit.release":
            refusal = WorldEditing.release(&next)
        case "edit.pin":
            guard let id = Self.wholeNumber(v[0]) else { return invalid }
            refusal = WorldEditing.togglePin(&next, id: id)
        case "edit.delete":
            guard let id = Self.wholeNumber(v[0]) else { return invalid }
            refusal = WorldEditing.delete(&next, id: id)
        case "edit.nudge":
            refusal = WorldEditing.nudge(&next, dx: v[0], dy: v[1])
        case "overlay.velocity", "overlay.forces":
            guard let i = Self.choice(v[0], count: 2) else { return invalid }
            if action.control == "overlay.velocity" { next.showVelocity = i == 1 } else { next.showForces = i == 1 }
            refusal = nil
        default:
            return .rejected(.unknownControl(action.control))
        }
        if let refusal { return .rejected(.rule(code: refusal.code)) }
        world = next
        generator = random
        return .accepted
    }

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// `value` as a whole number in −1…``maxBodyId`` (a body id, or −1 to clear a selection); nil otherwise.
    static func wholeNumber(_ value: Double) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= -1, value <= Double(maxBodyId) else { return nil }
        return Int(value)
    }

    /// `world-paused` while paused, `world-running` otherwise.
    public var outcome: ExperienceOutcome? {
        ExperienceOutcome(code: world.paused ? Self.pausedOutcome : Self.runningOutcome)
    }

    /// Back to the first state built from the preparation seed.
    public mutating func reset() {
        self = PlaygroundCore(seed: preparationSeed)
    }

    /// The canonical text of the whole state (`a11.playground.v1|` and the state as JSON with sorted keys: the world
    /// with its pins, selection, grab and overlay flags, and the generator state; never the measured forces); a value
    /// that cannot be written (a non-finite number) is refused as non-finite.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = try? String(data: Self.encode(state), encoding: .utf8) else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a11.playground.v1|" + text)
    }

    /// The playground state (schema 3) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        try Self.encode(state)
    }

    /// The core of a schema-3 payload (an older one has been through ``migrations``) with the envelope's `seed` as
    /// preparation seed. A payload that does not decode as schema 3 (a schema-1 or schema-2 payload included), a world
    /// that does not validate or a malformed generator state is refused (throws). The restored core has no measured
    /// forces until its next tick.
    public static func restore(payload: Data, seed: UInt64) throws -> PlaygroundCore {
        let state = try JSONDecoder().decode(PlaygroundState.self, from: payload)
        let problems = state.world.validate(catalog: catalog)
        guard problems.isEmpty else { throw PlaygroundRestoreError.invalidWorld(problems) }
        return try PlaygroundCore(seed: seed, state: state)
    }

    /// `value` as JSON with sorted keys.
    static func encode(_ value: PlaygroundState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
