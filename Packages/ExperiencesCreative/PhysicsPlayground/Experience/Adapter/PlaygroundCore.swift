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
    /// A drop asked for while the world already holds the most bodies (48).
    public static let bodyCap = "a11.body-cap"
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

/// Why a stored playground state is refused.
public enum PlaygroundRestoreError: Error, Equatable {
    /// The world does not validate (its problems, from `PhysicsWorld.validate(catalog:)`).
    case invalidWorld([String])
    /// The generator state cannot be restored.
    case invalidGenerator
    /// A payload handed to the step 1 → 2 whose world is not at schema 1 (the schema it names).
    case notSchemaOne(Int)
}

/// The saved state of Physics Playground (snapshot schema 2): the world and the generator state.
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

/// The state of Physics Playground. Schema version 2.
public struct PlaygroundCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a11.physics-playground"

    /// The outcome while the world runs.
    public static let runningOutcome = "world-running"
    /// The outcome while the world is paused.
    public static let pausedOutcome = "world-paused"

    /// The action ids in declaration order.
    public static let actionIDs = ["world.pause", "world.step", "world.timeScale", "world.reset", "world.drop",
                                   "world.gravity", "world.drag", "world.stiffness"]

    /// The snapshot schema this build writes.
    public static let snapshotSchema = 2

    /// The materials the world uses: the bundled catalog (it validates: `MaterialCatalog.decode` of its encoding
    /// refuses nothing, which the tests check).
    public static var catalog: MaterialCatalog { MaterialCatalog.bundled }

    /// The preparation seed; `reset()` and `world.reset` return to the first state built from it.
    public private(set) var preparationSeed: UInt64
    /// The physics world.
    public private(set) var world: PhysicsWorld
    /// The generator of the starting scene and of dropped bodies.
    public private(set) var generator: SeededRandom

    /// The first state prepared with `seed`: a generator seeded by `seed` and the starting scene drawn from it (the
    /// static ledge, three circles and three boxes at rest, the hanging box and the joined circles with their two
    /// springs, the default levels, an empty contact cache, tick 0, running at 1×).
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

    /// The whole state: the world and the generator state.
    public var state: PlaygroundState { PlaygroundState(world: world, random: generator.state) }

    // MARK: Contract

    /// One host step is the world's fixed tick, 1/120 s.
    public static var stepDuration: Double { WorldSettings.fixedTick }

    /// One quality tier (`level-0`): the drawing has nothing to scale down.
    public static var qualityTiers: Int { 1 }

    /// Schema 2 (feature 083). The step 1 → 2 (``migratedToSchemaTwo(_:)``) decodes a Phase 01 payload, migrates its
    /// world with `PhysicsWorld.migrated(fromSchemaOne:)`, keeps the generator state and re-encodes it. A payload that
    /// does not decode is refused by the step (the engine reports the migration as failed).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: snapshotSchema, steps: [
            1: { payload in try migratedToSchemaTwo(payload) },
        ])
    }

    /// The step 1 → 2: `payload` decoded as a ``PlaygroundStateSchemaOne`` (its world must name schema 1), the world
    /// migrated (no springs, Earth, low drag, stiffness level 1, an empty cache; bodies, tick, ids, pause and time
    /// scale kept), the generator state kept, and the state encoded again as a JSON object. Not validated here; the
    /// restore validates.
    static func migratedToSchemaTwo(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let old = try JSONDecoder().decode(PlaygroundStateSchemaOne.self, from: data)
        guard old.world.schema == 1 else { throw PlaygroundRestoreError.notSchemaOne(old.world.schema) }
        let state = PlaygroundState(world: PhysicsWorld.migrated(fromSchemaOne: old.world), random: old.random)
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
        // Dropped through the schema-2 helper on a world without springs: the same five draws as A11-P01's drop.
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

    /// The stored example of schema 1 for the registry's migration check (feature 083, T-A11-204): the A11-P01 payload
    /// ``schemaOneExampleState(seed:)`` — written as A11-P01 wrote it (the world at schema 1 without springs, levels
    /// or contact cache) at step 0 — with the digest its restore through the migration chain must give: the same
    /// bodies, tick, ids, pause, time scale and generator, with no springs, Earth gravity, low drag, stiffness level 1
    /// and an empty cache. Nil only if the encoding failed.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let id = ExperienceID(rawValue: experienceID),
              let payload = try? encoder.encode(schemaOneExampleState(seed: seed)),
              let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
              let upgraded = try? migrations.migrate(object, from: 1),
              let migrated = try? JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]),
              let restored = try? restore(payload: migrated, seed: seed) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? restored.writeDigest(into: &builder)) != nil else { return nil }
        let digest = builder.finish()
        guard let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: 1, seed: seed, stepIndex: 0,
                                                     digest: digest, payload: payload),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: 1, snapshot: encoded, expectedDigest: digest.hex)
    }

    /// The eight controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "world.pause", ranges: [0...1]),
         ExperienceControl(id: "world.step"),
         ExperienceControl(id: "world.timeScale", ranges: [0...3]),
         ExperienceControl(id: "world.reset"),
         ExperienceControl(id: "world.drop", ranges: [0...1]),
         ExperienceControl(id: "world.gravity", ranges: [0...2]),
         ExperienceControl(id: "world.drag", ranges: [0...2]),
         ExperienceControl(id: "world.stiffness", ranges: [0...3])]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> PlaygroundCore {
        try Task.checkCancellation()
        return PlaygroundCore(seed: seed)
    }

    /// One host step: `WorldSimulation.advanceHostStep` (nothing while paused; otherwise the time scale's whole ticks).
    public mutating func update(step: Int) {
        WorldSimulation.advanceHostStep(&world, catalog: Self.catalog)
    }

    /// Carries out a well-formed action (the engine checked the control, the value count, finiteness and ranges);
    /// a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        let expected = ["world.pause": 1, "world.step": 0, "world.timeScale": 1, "world.reset": 0,
                        "world.drop": 1, "world.gravity": 1, "world.drag": 1, "world.stiffness": 1][action.control]
        guard let expected else { return .rejected(.unknownControl(action.control)) }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        switch action.control {
        case "world.pause":
            guard let i = Self.choice(v[0], count: 2) else {
                return .rejected(.rule(code: PlaygroundRule.invalidChoice))
            }
            world.paused = i == 1
        case "world.step":
            guard world.paused else { return .rejected(.rule(code: PlaygroundRule.notPaused)) }
            var next = world
            // A validated world can always be ticked; a world that could not is refused like a running one.
            guard WorldSimulation.step(&next, catalog: Self.catalog) else {
                return .rejected(.rule(code: PlaygroundRule.notPaused))
            }
            world = next
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

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
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

    /// The canonical text of the whole state (`a11.playground.v1|` and the state as JSON with sorted keys); a value
    /// that cannot be written (a non-finite number) is refused as non-finite.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = try? String(data: Self.encode(state), encoding: .utf8) else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a11.playground.v1|" + text)
    }

    /// The playground state (schema 2) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        try Self.encode(state)
    }

    /// The core of a schema-2 payload (an older one has been through ``migrations``) with the envelope's `seed` as
    /// preparation seed. A payload that does not decode as schema 2 (a schema-1 payload included), a world that does
    /// not validate or a malformed generator state is refused (throws).
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
