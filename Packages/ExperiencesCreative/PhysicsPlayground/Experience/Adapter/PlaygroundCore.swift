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
// Snapshot schema 1: `PlaygroundState` as JSON with sorted keys; the preparation seed and the schema version come from
// the snapshot envelope (`MigrationChain(currentVersion: 1)`, so a newer payload is refused by the engine). A payload
// that does not decode, whose world does not validate (`PhysicsWorld.validate(catalog:)` names a problem) or whose
// generator state is malformed is refused (the restore throws). One quality tier (`level-0`). The digest is the
// canonical text of the whole state: the world (settings, bodies, tick, next id, paused, time-scale index and
// remainder) and the generator state.
import Foundation
import PhysicsPlaygroundCore
import VisualCoreExperience
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

/// Why a stored playground state is refused.
public enum PlaygroundRestoreError: Error, Equatable {
    /// The world does not validate (its problems, from `PhysicsWorld.validate(catalog:)`).
    case invalidWorld([String])
    /// The generator state cannot be restored.
    case invalidGenerator
}

/// The saved state of Physics Playground (snapshot schema 1): the world and the generator state.
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

/// The state of Physics Playground. Schema version 1.
public struct PlaygroundCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a11.physics-playground"

    /// The outcome while the world runs.
    public static let runningOutcome = "world-running"
    /// The outcome while the world is paused.
    public static let pausedOutcome = "world-paused"

    /// The action ids in declaration order.
    public static let actionIDs = ["world.pause", "world.step", "world.timeScale", "world.reset", "world.drop"]

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
    /// static ledge and three circles and three boxes at rest, tick 0, running at 1×).
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

    /// Schema 1, the first; nothing to migrate.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }

    /// The five controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "world.pause", ranges: [0...1]),
         ExperienceControl(id: "world.step"),
         ExperienceControl(id: "world.timeScale", ranges: [0...3]),
         ExperienceControl(id: "world.reset"),
         ExperienceControl(id: "world.drop", ranges: [0...1])]
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
                        "world.drop": 1][action.control]
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

    /// The playground state (schema 1) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        try Self.encode(state)
    }

    /// The core of a schema-1 payload with the envelope's `seed` as preparation seed. A payload that does not decode,
    /// a world that does not validate or a malformed generator state is refused (throws).
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
