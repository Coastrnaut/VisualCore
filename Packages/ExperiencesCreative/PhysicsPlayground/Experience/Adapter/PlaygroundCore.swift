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
//
// Feature 085 (A11-P04) T-A11-403 (FR-A11-402, FR-A11-403, FR-A11-410, FR-A11-430; clarifications 2, 4, 5; research
// D2–D4; data-model "PlaygroundState (schema 4)"; contract contracts/experiments.md). The state remembers the
// experiment it was opened from: `origin` (`ExperimentOrigin`: preset 0…3 or slot 0…3), `startingWorld` (the world as
// it opened) and the tutorial progress (`TutorialProgress?`). Three actions are added:
//   experiment.preset [0…3]  opens free play, the pendulum, the spring chain or the stacked objects
//                            (`Presets.make` with the core's generator; only free play draws from it); the preset
//                            becomes the starting world and the origin `.preset(i)`; no grab, no selection, no measured
//                            forces;
//   tutorial.start [0…1]     starts "Controlling time" or "Springs and energy" at step 0 (`Tutorials.start`) at the
//                            world's tick;
//   tutorial.stop            ends the tutorial (the world is unchanged); refused with `a11.no-tutorial` when none runs;
// a fractional value is refused with `a11.invalid-choice`. `world.reset` now restores the starting world at normal
// speed, running, with no grab, no selection and no measured forces; the generator keeps going (later drops stay
// seeded and replayable). The core's `reset()` is still a fresh preparation from the seed (free play, no tutorial).
// After every applied action and every host step the tutorial is advanced (`Tutorials.advance`, with `justReset` true
// for `world.reset`); a reset, a preset or an opened slot replaces the world, so a running tutorial stays on its step
// and the step begins again at the new world's tick (edge case "Opening a preset or a slot during a tutorial": it
// continues if its next step expects the new experiment, which the advance after the action checks).
//
// Snapshot schema 4: `PlaygroundState` holds the world, the generator state, the origin, the starting world and the
// tutorial progress (omitted when none runs). `MigrationChain(currentVersion: 4)` has the steps 1 → 2, 2 → 3 and
// 3 → 4 (`migratedToSchemaFour`: a schema-3 payload gets origin free play, the current world without grab and
// selection as the starting world, and no tutorial). The restore also validates the starting world and refuses a
// tutorial progress that names no tutorial or step. `schemaThreeExample()` is the stored Phase 03 payload the
// registry's migration check restores. A saved slot is opened outside the replay: `opening(document:slot:from:)`
// builds the state and `openingSnapshot(of:experience:stepIndex:)` the snapshot the presenter hands to
// `ExperienceShell.restore`. The digest covers the whole state (world, generator, origin, starting world, tutorial).
//
// Feature 086 (A11-P05) T-A11-504 (FR-A11-502, FR-A11-520; clarifications 1, 4; research D1, D3; data-model
// "PlaygroundState (schema 5)"; contract contracts/stability.md). The world is at world schema 4 (every body's `asleep`
// and `restTicks`, covered by the digest), so the state is snapshot schema 5: the schema-4 state with a schema-4 world
// and starting world. `MigrationChain(currentVersion: 5)` keeps the steps 1 → 2, 2 → 3 and 3 → 4, each writing the
// faithful payload of its schema (bodies without the keys their schema lacked: `pinned`, `asleep` and `restTicks` for
// schemas 1 and 2, `asleep` and `restTicks` for schemas 3 and 4; the world of a schema-3 or schema-4 state at world
// schema 3), and adds 4 → 5 (``migratedToSchemaFive(_:)``): the world and the starting world of a schema-4 state (both
// at world schema 3) migrated with `PhysicsWorld.migrated(fromSchemaThree:)` — every body awake with 0 rest ticks,
// everything else kept. `schemaFourExample()` is the stored A11-P04 payload the registry's migration check restores.
// Three quality tiers (`level-0`, `level-1`, `level-2`, as the registration): the presenter draws the host's tier with
// `DrawingBudget` (spring coils, circle points, hatch spacing); the core stores no tier (`setQualityTier` keeps the
// protocol's default, which does nothing), so the state, the replay and the digest are the same at every tier.
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
    /// `tutorial.stop` while no tutorial runs (feature 085).
    public static let noTutorial = "a11.no-tutorial"
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
    /// A payload handed to the step 3 → 4 whose world is not at schema 3 (the schema it names; feature 085).
    case notSchemaThree(Int)
    /// A payload handed to the step 4 → 5 whose world or starting world is not at world schema 3 (the schema it
    /// names; feature 086).
    case notSchemaFour(Int)
    /// The starting world does not validate (its problems; feature 085).
    case invalidStartingWorld([String])
    /// The tutorial progress names no tutorial or step, or a negative start tick (feature 085).
    case invalidTutorial
}

/// The saved state of Physics Playground at snapshot schema 3 (feature 084): the schema-3 world and the generator
/// state, exactly the keys A11-P03 wrote.
public struct PlaygroundStateSchemaThree: Codable, Equatable, Sendable {
    /// The schema-3 world.
    public var world: PhysicsWorld
    /// The state of the generator that draws dropped bodies.
    public var random: SeededRandom.State

    /// A schema-3 state of `world` with the generator state `random`.
    public init(world: PhysicsWorld, random: SeededRandom.State) {
        self.world = world
        self.random = random
    }
}

/// The saved state of Physics Playground (snapshot schema 5, feature 086; the shape of schema 4, feature 085, with the
/// world and the starting world at world schema 4): the world, the generator state, the origin of the opened
/// experiment, its starting world and the tutorial progress (nil, and not written, when none runs). A schema-4 payload
/// decodes into the same shape with both worlds at world schema 3 (the step 4 → 5 migrates them).
public struct PlaygroundState: Codable, Equatable, Sendable {
    /// The physics world.
    public var world: PhysicsWorld
    /// The state of the generator that draws dropped bodies.
    public var random: SeededRandom.State
    /// Where the opened experiment came from.
    public var origin: ExperimentOrigin
    /// The world as the experiment opened (what `world.reset` restores).
    public var startingWorld: PhysicsWorld
    /// The running tutorial's progress, nil when none runs.
    public var tutorial: TutorialProgress?

    /// A state of every field.
    public init(world: PhysicsWorld, random: SeededRandom.State, origin: ExperimentOrigin,
                startingWorld: PhysicsWorld, tutorial: TutorialProgress?) {
        self.world = world
        self.random = random
        self.origin = origin
        self.startingWorld = startingWorld
        self.tutorial = tutorial
    }

    /// A free-play state of `world` with the generator state `random`: `world` without grab and selection is the
    /// starting world, and no tutorial runs (the form the migration 3 → 4 gives).
    public init(world: PhysicsWorld, random: SeededRandom.State) {
        self.init(world: world, random: random, origin: .freePlay,
                  startingWorld: ExperimentDocument.withoutEditing(world), tutorial: nil)
    }
}

/// The state of Physics Playground. Schema version 5 (feature 086).
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
                                   "edit.delete", "edit.nudge", "overlay.velocity", "overlay.forces",
                                   "experiment.preset", "tutorial.start", "tutorial.stop"]

    /// The edit actions a canvas gesture sends (feature 084; each also reachable through a native control).
    public static let gestureActionIDs: Set<String> = ["edit.add", "edit.select", "edit.grab", "edit.move",
                                                       "edit.release", "edit.pin", "edit.delete"]

    /// The snapshot schema this build writes (5 since feature 086: the world at world schema 4).
    public static let snapshotSchema = 5

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
    /// Where the opened experiment came from (feature 085): free play after preparation.
    public private(set) var origin: ExperimentOrigin
    /// The world as the opened experiment began (feature 085): what `world.reset` restores.
    public private(set) var startingWorld: PhysicsWorld
    /// The running tutorial's progress (feature 085), nil when none runs.
    public private(set) var tutorial: TutorialProgress?

    /// The first state prepared with `seed`: a generator seeded by `seed` and the starting scene drawn from it (the
    /// static ledge, three circles and three boxes at rest, the hanging box and the joined circles with their two
    /// springs, the default levels, an empty contact cache, no pins, no selection, no grab, both overlays off, tick 0,
    /// running at 1×); free play, that scene as the starting world, no tutorial.
    public init(seed: UInt64) {
        preparationSeed = seed
        var random = SeededRandom(seed: seed)
        world = StartingScene.make(random: &random, catalog: Self.catalog)
        generator = random
        origin = .freePlay
        startingWorld = world
        tutorial = nil
    }

    /// A core holding `state`, prepared with `seed`; throws when the generator state cannot be restored.
    init(seed: UInt64, state: PlaygroundState) throws {
        preparationSeed = seed
        world = state.world
        origin = state.origin
        startingWorld = state.startingWorld
        tutorial = state.tutorial
        do {
            generator = try SeededRandom(restoring: state.random)
        } catch {
            throw PlaygroundRestoreError.invalidGenerator
        }
    }

    /// Two cores are equal when their preparation seeds, worlds, generators, origins, starting worlds and tutorial
    /// progress are; the measured ``forces`` are derived data and are not compared.
    public static func == (lhs: PlaygroundCore, rhs: PlaygroundCore) -> Bool {
        lhs.preparationSeed == rhs.preparationSeed && lhs.world == rhs.world && lhs.generator == rhs.generator
            && lhs.origin == rhs.origin && lhs.startingWorld == rhs.startingWorld && lhs.tutorial == rhs.tutorial
    }

    /// The whole state: the world, the generator state, the origin, the starting world and the tutorial progress.
    public var state: PlaygroundState {
        PlaygroundState(world: world, random: generator.state, origin: origin, startingWorld: startingWorld,
                        tutorial: tutorial)
    }

    // MARK: Contract

    /// One host step is the world's fixed tick, 1/120 s.
    public static var stepDuration: Double { WorldSettings.fixedTick }

    /// Three quality tiers (`level-0`, `level-1`, `level-2`, feature 086 A11-P05; the default uniform profile names
    /// them as the registration does): `DrawingBudget.count`. The tier is presentation only — the presenter draws
    /// the springs, circles and hatches with the `DrawingBudget` of the host's tier (level 2 under Low Power Mode);
    /// the core keeps nothing (`setQualityTier` is the protocol's default, which does nothing), so the state and its
    /// digest are the same at every tier.
    public static var qualityTiers: Int { DrawingBudget.count }

    /// Schema 5 (feature 086). The step 1 → 2 (``migratedToSchemaTwo(_:)``) turns a Phase 01 payload into a Phase 02
    /// payload; the step 2 → 3 (``migratedToSchemaThree(_:)``) turns a Phase 02 payload into a Phase 03 payload; the
    /// step 3 → 4 (``migratedToSchemaFour(_:)``) turns a Phase 03 payload into a Phase 04 payload; the step 4 → 5
    /// (``migratedToSchemaFive(_:)``) turns a Phase 04 payload into a schema-5 payload. A payload that does not decode
    /// is refused by its step (the engine reports the migration as failed).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: snapshotSchema, steps: [
            1: { payload in try migratedToSchemaTwo(payload) },
            2: { payload in try migratedToSchemaThree(payload) },
            3: { payload in try migratedToSchemaFour(payload) },
            4: { payload in try migratedToSchemaFive(payload) },
        ])
    }

    /// The body keys world schema 4 added (feature 086): absent from the bodies of every older world record.
    static let sleepKeys = ["asleep", "restTicks"]

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

    /// `value` encoded with sorted keys as a JSON object, every body of its world written without the `pinned`,
    /// `asleep` and `restTicks` keys (as schemas 1 and 2 wrote bodies).
    static func objectWithoutPins<Value: Encodable>(_ value: Value) throws -> [String: Any] {
        try withoutBodyKeys(jsonObject(value), keys: ["pinned"] + sleepKeys, worlds: ["world"])
    }

    /// `object` with the keys `keys` removed from every body of each of its worlds named by `worlds` (feature 086: the
    /// faithful payload of an older schema). Throws when a named world is not a JSON object with bodies.
    static func withoutBodyKeys(_ object: [String: Any], keys: [String], worlds: [String]) throws -> [String: Any] {
        var object = object
        for name in worlds {
            guard var world = object[name] as? [String: Any], var bodies = world["bodies"] as? [[String: Any]] else {
                throw PlaygroundRestoreError.invalidWorld(["the state has no \(name) with bodies"])
            }
            for index in bodies.indices {
                for key in keys { bodies[index][key] = nil }
            }
            world["bodies"] = bodies
            object[name] = world
        }
        return object
    }

    /// `world` as a world-schema-3 record (feature 086): the schema number set to 3; its bodies are written without
    /// `asleep` and `restTicks` by the callers (``withoutBodyKeys(_:keys:worlds:)``).
    static func schemaThreeWorld(_ world: PhysicsWorld) -> PhysicsWorld {
        var world = world
        world.schema = 3
        return world
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
    /// else kept), the generator state kept, and the Phase 03 state (``PlaygroundStateSchemaThree``) encoded again as
    /// a JSON object — its world at schema 3 with bodies without `asleep` and `restTicks` (feature 086), exactly as
    /// A11-P03 wrote it. Not validated here; the restore validates.
    static func migratedToSchemaThree(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let old = try JSONDecoder().decode(PlaygroundStateSchemaTwo.self, from: data)
        guard old.world.schema == 2 else { throw PlaygroundRestoreError.notSchemaTwo(old.world.schema) }
        let world = schemaThreeWorld(PhysicsWorld.migrated(fromSchemaTwo: old.world))
        let state = PlaygroundStateSchemaThree(world: world, random: old.random)
        return try withoutBodyKeys(jsonObject(state), keys: sleepKeys, worlds: ["world"])
    }

    /// The step 3 → 4 (feature 085): `payload` decoded as a ``PlaygroundStateSchemaThree`` (its world must name schema
    /// 3), kept as it is, with origin free play, the world without grab and selection as the starting world and no
    /// tutorial; the generator state kept; encoded again as a JSON object with both worlds at schema 3 and their bodies
    /// without `asleep` and `restTicks` (feature 086), exactly as A11-P04 wrote it. Not validated here; the restore
    /// validates.
    static func migratedToSchemaFour(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let old = try JSONDecoder().decode(PlaygroundStateSchemaThree.self, from: data)
        guard old.world.schema == 3 else { throw PlaygroundRestoreError.notSchemaThree(old.world.schema) }
        return try withoutBodyKeys(jsonObject(PlaygroundState(world: old.world, random: old.random)), keys: sleepKeys,
                                   worlds: ["world", "startingWorld"])
    }

    /// The step 4 → 5 (feature 086): `payload` decoded as a schema-4 state (the shape of ``PlaygroundState``; its
    /// world and starting world must name world schema 3), both worlds migrated with
    /// `PhysicsWorld.migrated(fromSchemaThree:)` (world schema 4, every body awake with 0 rest ticks, everything else
    /// kept), the generator, origin and tutorial progress kept; encoded again as a JSON object. Not validated here; the
    /// restore validates.
    static func migratedToSchemaFive(_ payload: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        var state = try JSONDecoder().decode(PlaygroundState.self, from: data)
        for schema in [state.world.schema, state.startingWorld.schema] where schema != 3 {
            throw PlaygroundRestoreError.notSchemaFour(schema)
        }
        state.world = PhysicsWorld.migrated(fromSchemaThree: state.world)
        state.startingWorld = PhysicsWorld.migrated(fromSchemaThree: state.startingWorld)
        return try jsonObject(state)
    }

    /// `value` encoded with sorted keys as a JSON object.
    static func jsonObject<Value: Encodable>(_ value: Value) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let object = try JSONSerialization.jsonObject(with: encoder.encode(value)) as? [String: Any] else {
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

    /// The actions the stored Phase 03 example was saved after, all at step 0 (A11-P01 … A11-P03 actions only): drop a
    /// circle, drop a box, pin circle 8, select circle 9, grab the hanging box 7 at its centre, velocity arrows on,
    /// half speed, pause (feature 085).
    public static let schemaThreeExampleActions: [(control: String, values: [Double])] = [
        ("world.drop", [0]), ("world.drop", [1]), ("edit.pin", [8]), ("edit.select", [9]),
        ("edit.grab", [7, 7.5, 6.2]), ("overlay.velocity", [1]), ("world.timeScale", [1]), ("world.pause", [1]),
    ]

    /// The A11-P03 state of seed `seed` after ``schemaThreeExampleActions`` at step 0: the ten-body starting scene, a
    /// dropped circle and a dropped box (ids 10 and 11), circle 8 pinned, circle 9 selected, the hanging box held,
    /// velocity arrows on, half speed, paused, tick 0, and the generator after those draws. No tick has run and the
    /// actions are A11-P03's, so this is exactly what A11-P03 saved for that seed and those actions (feature 085).
    /// The world is written at world schema 3 (feature 086): every body is awake with 0 rest ticks at step 0, so the
    /// schema number is the only difference from the current world.
    public static func schemaThreeExampleState(seed: UInt64 = 7) -> PlaygroundStateSchemaThree {
        var core = PlaygroundCore(seed: seed)
        for action in schemaThreeExampleActions {
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: 0))
        }
        return PlaygroundStateSchemaThree(world: schemaThreeWorld(core.world), random: core.generator.state)
    }

    /// The stored example of schema 3 for the registry's migration check (feature 085, T-A11-403): the A11-P03 payload
    /// ``schemaThreeExampleState(seed:)`` — exactly the keys `random` and `world` (the schema-3 world, bodies without
    /// `asleep` and `restTicks`) at step 0 — with the digest its restore through the steps 3 → 4 → 5 must give: the
    /// same world (at world schema 4) and generator, origin free play, the world without its grab and selection as the
    /// starting world, and no tutorial. Nil only if the encoding failed.
    public static func schemaThreeExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let object = try? jsonObject(schemaThreeExampleState(seed: seed)),
              let payload = try? withoutBodyKeys(object, keys: sleepKeys, worlds: ["world"]) else { return nil }
        return migrationExample(version: 3, payload: payload, seed: seed)
    }

    /// The actions the stored Phase 04 example was saved after, all at step 0 (A11-P01 … A11-P04 actions only; feature
    /// 086): start the tutorial "Springs and energy", open the spring chain, force arrows on (the tutorial's first two
    /// steps), drop a box, Moon gravity, half speed, pause.
    public static let schemaFourExampleActions: [(control: String, values: [Double])] = [
        ("tutorial.start", [1]), ("experiment.preset", [Double(PresetID.springChain.rawValue)]),
        ("overlay.forces", [1]), ("world.drop", [1]), ("world.gravity", [1]), ("world.timeScale", [1]),
        ("world.pause", [1]),
    ]

    /// The A11-P04 state of seed `seed` after ``schemaFourExampleActions`` at step 0: the spring chain as the starting
    /// world, the chain with a dropped box, force arrows on, Moon gravity, half speed and paused as the world, origin
    /// the spring-chain preset, the tutorial "Springs and energy" on its last step, and the generator after those
    /// draws; both worlds at world schema 3. No tick has run and the actions are A11-P04's, so this is exactly what
    /// A11-P04 saved for that seed and those actions (feature 086).
    public static func schemaFourExampleState(seed: UInt64 = 7) -> PlaygroundState {
        var core = PlaygroundCore(seed: seed)
        for action in schemaFourExampleActions {
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: 0))
        }
        return PlaygroundState(world: schemaThreeWorld(core.world), random: core.generator.state, origin: core.origin,
                               startingWorld: schemaThreeWorld(core.startingWorld), tutorial: core.tutorial)
    }

    /// The stored example of schema 4 for the registry's migration check (feature 086, T-A11-504): the A11-P04 payload
    /// ``schemaFourExampleState(seed:)`` — the keys `origin`, `random`, `startingWorld`, `tutorial` and `world`, both
    /// worlds at world schema 3 with bodies without `asleep` and `restTicks` — at step 0, with the digest its restore
    /// through the step 4 → 5 must give: the same worlds at world schema 4 (every body awake with 0 rest ticks), the
    /// same generator, origin and tutorial progress. Nil only if the encoding failed.
    public static func schemaFourExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let object = try? jsonObject(schemaFourExampleState(seed: seed)),
              let payload = try? withoutBodyKeys(object, keys: sleepKeys, worlds: ["world", "startingWorld"])
        else { return nil }
        return migrationExample(version: 4, payload: payload, seed: seed)
    }

    /// The twenty-one controls with their declared ranges.
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
                ExperienceControl(id: "overlay.forces", ranges: [0...1]),
                ExperienceControl(id: "experiment.preset", ranges: [0...Double(PresetID.allCases.count - 1)]),
                ExperienceControl(id: "tutorial.start", ranges: [0...Double(Tutorials.all.count - 1)]),
                ExperienceControl(id: "tutorial.stop")]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> PlaygroundCore {
        try Task.checkCancellation()
        return PlaygroundCore(seed: seed)
    }

    /// One host step: the measured `WorldSimulation.advanceHostStep` (nothing while paused; otherwise the time
    /// scale's whole ticks), keeping the spring forces of the last tick it ran in ``forces``; then a running tutorial
    /// is advanced (feature 085).
    public mutating func update(step: Int) {
        WorldSimulation.advanceHostStep(&world, catalog: Self.catalog, forces: &forces)
        if tutorial != nil { advanceTutorial(justReset: false) }
    }

    /// The number of values each action carries.
    static let valueCounts: [String: Int] = [
        "world.pause": 1, "world.step": 0, "world.timeScale": 1, "world.reset": 0, "world.drop": 1,
        "world.gravity": 1, "world.drag": 1, "world.stiffness": 1, "edit.add": 3, "edit.select": 1, "edit.grab": 3,
        "edit.move": 2, "edit.release": 0, "edit.pin": 1, "edit.delete": 1, "edit.nudge": 2, "overlay.velocity": 1,
        "overlay.forces": 1, "experiment.preset": 1, "tutorial.start": 1, "tutorial.stop": 0,
    ]

    /// Carries out a well-formed action (the engine checked the control, the value count, finiteness and ranges);
    /// a refused action changes nothing. After an applied action a running tutorial is advanced (feature 085), with
    /// `justReset` true for `world.reset`.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let result = applyAction(action)
        if result.isAccepted, tutorial != nil { advanceTutorial(justReset: action.control == "world.reset") }
        return result
    }

    /// The action itself, without the tutorial check (see ``apply(_:)``).
    mutating func applyAction(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard let expected = Self.valueCounts[action.control] else {
            return .rejected(.unknownControl(action.control))
        }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        if action.control.hasPrefix("edit.") || action.control.hasPrefix("overlay.") { return applyEdit(action) }
        if action.control.hasPrefix("experiment.") || action.control.hasPrefix("tutorial.") {
            return applyExperiment(action)
        }
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
            restartExperiment()
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

    /// The experiment and tutorial actions (feature 085; see the file header).
    mutating func applyExperiment(_ action: ExperienceAction) -> ActionResult {
        let invalid = ActionResult.rejected(.rule(code: PlaygroundRule.invalidChoice))
        switch action.control {
        case "experiment.preset":
            guard let i = Self.choice(action.values[0], count: PresetID.allCases.count),
                  let id = PresetID(rawValue: i) else { return invalid }
            var random = generator
            let opened = Presets.make(id, random: &random, catalog: Self.catalog)
            generator = random
            open(ExperimentDocument.withoutEditing(opened), origin: .preset(i))
        case "tutorial.start":
            guard let i = Self.choice(action.values[0], count: Tutorials.all.count),
                  let progress = Tutorials.start(i, tick: world.tick) else { return invalid }
            tutorial = progress
        case "tutorial.stop":
            guard tutorial != nil else { return .rejected(.rule(code: PlaygroundRule.noTutorial)) }
            tutorial = nil
        default:
            return .rejected(.unknownControl(action.control))
        }
        return .accepted
    }

    /// Opens `opened` as the experiment of `origin`: it becomes the world and the starting world, the measured forces
    /// are cleared and a running tutorial's current step begins again at the new world's tick.
    mutating func open(_ opened: PhysicsWorld, origin: ExperimentOrigin) {
        world = opened
        startingWorld = opened
        self.origin = origin
        forces = ForceMeasurement()
        restartTutorialStep()
    }

    /// `world.reset` (feature 085): the starting world at normal speed, running, with no grab, no selection and no
    /// measured forces; the generator, the origin and the starting world are kept; a running tutorial's current step
    /// begins again at the restored tick.
    mutating func restartExperiment() {
        world = startingWorld
        world.timeScaleIndex = PhysicsWorld.normalTimeScaleIndex
        world.paused = false
        world.grab = nil
        world.selectedId = nil
        forces = ForceMeasurement()
        restartTutorialStep()
    }

    /// Sets the start tick of a running tutorial's current step to the world's tick (after the world was replaced).
    mutating func restartTutorialStep() {
        guard var progress = tutorial else { return }
        progress.startTick = world.tick
        tutorial = progress
    }

    /// Completes as many steps of the running tutorial as hold now (`Tutorials.advance`).
    mutating func advanceTutorial(justReset: Bool) {
        Tutorials.advance(&tutorial, context: TutorialContext(world: world, startingWorld: startingWorld,
                                                              origin: origin,
                                                              justReset: justReset))
    }

    /// The core `current` with the saved experiment `document` opened from slot `slot` (0…3; feature 085, research
    /// D3): the same seed and generator, the document's world (without grab and selection) as the world and the
    /// starting world, origin `.slot(slot)`, no measured forces; a running tutorial stays on its step, which begins
    /// again at the opened world's tick, and is then advanced. A slot outside 0…3 changes nothing (returns `current`).
    public static func opening(document: ExperimentDocument, slot: Int,
                               from current: PlaygroundCore) -> PlaygroundCore {
        guard ExperimentOrigin.validRange.contains(slot) else { return current }
        var core = current
        core.open(ExperimentDocument.withoutEditing(document.world), origin: .slot(slot))
        if core.tutorial != nil { core.advanceTutorial(justReset: false) }
        return core
    }

    /// The snapshot of `core` for `ExperienceShell.restore` (feature 085): the current schema (5), the core's
    /// preparation seed, the step index `stepIndex`, the core's digest with `experience` as domain and its payload.
    /// Throws when the payload or the digest cannot be written or the envelope is refused.
    public static func openingSnapshot(of core: PlaygroundCore, experience: ExperienceID,
                                       stepIndex: Int) throws -> ExperienceSnapshot {
        var builder = DigestBuilder(domain: experience.rawValue)
        try core.writeDigest(into: &builder)
        return try ExperienceSnapshot(experience: experience, schemaVersion: snapshotSchema,
                                      seed: core.preparationSeed, stepIndex: stepIndex, digest: builder.finish(),
                                      payload: core.snapshotPayload())
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

    /// Back to the first state built from the preparation seed (free play, no tutorial).
    public mutating func reset() {
        self = PlaygroundCore(seed: preparationSeed)
    }

    /// The canonical text of the whole state (`a11.playground.v1|` and the state as JSON with sorted keys: the world
    /// with its pins, selection, grab and overlay flags, the generator state, the origin, the starting world and the
    /// tutorial progress; never the measured forces); a value that cannot be written (a non-finite number) is refused
    /// as non-finite.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = try? String(data: Self.encode(state), encoding: .utf8) else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a11.playground.v1|" + text)
    }

    /// The playground state (schema 5) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        try Self.encode(state)
    }

    /// The core of a schema-5 payload (an older one has been through ``migrations``) with the envelope's `seed` as
    /// preparation seed. A payload that does not decode as schema 5 (a schema-1, 2 or 3 payload included), a world or
    /// a starting world that does not validate (a schema-4 payload's worlds at world schema 3 included), a tutorial
    /// progress that names no tutorial or step, or a malformed generator state is refused (throws). The restored core
    /// has no measured forces until its next tick.
    public static func restore(payload: Data, seed: UInt64) throws -> PlaygroundCore {
        let state = try JSONDecoder().decode(PlaygroundState.self, from: payload)
        let problems = state.world.validate(catalog: catalog)
        guard problems.isEmpty else { throw PlaygroundRestoreError.invalidWorld(problems) }
        let starting = state.startingWorld.validate(catalog: catalog)
        guard starting.isEmpty else { throw PlaygroundRestoreError.invalidStartingWorld(starting) }
        if let progress = state.tutorial, !progress.isValid { throw PlaygroundRestoreError.invalidTutorial }
        return try PlaygroundCore(seed: seed, state: state)
    }

    /// `value` as JSON with sorted keys.
    static func encode(_ value: PlaygroundState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
