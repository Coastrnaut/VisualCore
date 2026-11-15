// ArcadeCore — feature 075 (A10-P01) T-A10-104 (FR-A10-112, FR-A10-120, FR-A10-121; clarifications 1, 3 and 4;
// research D2 and D4; contract "Experience actions"). The state of Neon Arcade as an experience: an `ArcadeState` (the
// Neon Dodge `GameRun` and the seeded generator's state) and the preparation seed. A host step advances the run by one
// fixed step of `GameSimulation` (1/60 s); `GameSimulation.advance` itself leaves a paused or over run unchanged. The
// session steps the core only while it runs, so a suspension never fast-forwards the game.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange` and a non-finite value with `nonFinite` before the core sees it):
//   run.steer [−1…1]   the held steering value (target velocity = value × 9 units/s); it holds until the next steer and
//                      also applies while paused (it takes effect on the next advanced step). Called directly, a
//                      non-finite value or one outside −1…1 is refused with the rule `a10.invalid-steering`.
//   run.pause [0…1]    0 playing, 1 paused; a value that is not exactly 0 or 1 is refused with `a10.invalid-choice`.
//   run.restart        no values: a new run (score 0, three lives, steering 0); the generator continues, so the new
//                      run draws new objects by the same rules.
// A refusal changes nothing. The applied `run.steer` actions with their steps and the seed are the replay (research
// D4).
//
// Snapshot schema 1: `ArcadeState` as JSON with sorted keys; the preparation seed and the schema version come from the
// snapshot envelope (`MigrationChain(currentVersion: 1)`, so a newer payload is refused by the engine). A payload that
// does not decode, whose run does not validate (`GameRun.validate()` names a problem) or whose generator state is
// malformed is refused (the restore throws). One quality tier (`level-0`). The digest is the canonical text of the
// whole state — the run with its step, score, lives, flags, steering, player, objects, next id, the kept events and
// the event count, and the generator state.
import Foundation
import NeonArcadeCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Neon Arcade's refusals.
public enum ArcadeRule {
    /// A choice value that is not a whole number naming an entry of the action's table (`run.pause` other than 0 or 1).
    public static let invalidChoice = "a10.invalid-choice"
    /// A steering value that is not finite or lies outside −1…1 (only reachable when the core is called directly).
    public static let invalidSteering = "a10.invalid-steering"
}

/// Why a stored arcade state is refused.
public enum ArcadeRestoreError: Error, Equatable {
    /// The run does not validate (its problems, from `GameRun.validate()`).
    case invalidRun([String])
    /// The generator state cannot be restored.
    case invalidGenerator
}

/// The saved state of Neon Arcade (snapshot schema 1): the run and the generator state.
public struct ArcadeState: Codable, Equatable, Sendable {
    /// The Neon Dodge run.
    public var run: GameRun
    /// The state of the generator that draws the spawns.
    public var random: SeededRandom.State

    /// A state of `run` with the generator state `random`.
    public init(run: GameRun, random: SeededRandom.State) {
        self.run = run
        self.random = random
    }
}

/// The state of Neon Arcade. Schema version 1.
public struct ArcadeCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a10.neon-arcade"

    /// The outcome while the run is being played.
    public static let playingOutcome = "run-playing"
    /// The outcome while the run is paused.
    public static let pausedOutcome = "run-paused"
    /// The outcome once the lives are gone.
    public static let overOutcome = "run-over"

    /// The action ids in declaration order.
    public static let actionIDs = ["run.steer", "run.pause", "run.restart"]

    /// The content the run spawns from: the bundled catalog (it validates: `ArcadeCatalog.decode` of its encoding
    /// refuses nothing, which the tests check).
    public static var catalog: ArcadeCatalog { ArcadeCatalog.bundled }

    /// The preparation seed; `reset()` returns to the first state built from it.
    public private(set) var preparationSeed: UInt64
    /// The Neon Dodge run.
    public private(set) var run: GameRun
    /// The generator of the spawns.
    public private(set) var generator: SeededRandom

    /// The first state prepared with `seed`: a new run (step 0, score 0, three lives, the player at rest in the
    /// middle, no objects) and a generator seeded by `seed`.
    public init(seed: UInt64) {
        preparationSeed = seed
        run = GameRun.new()
        generator = SeededRandom(seed: seed)
    }

    /// A core holding `state`, prepared with `seed`; throws when the generator state cannot be restored.
    init(seed: UInt64, state: ArcadeState) throws {
        preparationSeed = seed
        run = state.run
        do {
            generator = try SeededRandom(restoring: state.random)
        } catch {
            throw ArcadeRestoreError.invalidGenerator
        }
    }

    /// The whole state: the run and the generator state.
    public var state: ArcadeState { ArcadeState(run: run, random: generator.state) }

    // MARK: Contract

    /// One fixed simulation step: `GameSimulation.step` (1/60 s).
    public static var stepDuration: Double { GameSimulation.step }

    /// One quality tier (`level-0`): the drawing has nothing to scale down.
    public static var qualityTiers: Int { 1 }

    /// Schema 1, the first; nothing to migrate.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }

    /// The three controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "run.steer", ranges: [-1...1]),
         ExperienceControl(id: "run.pause", ranges: [0...1]),
         ExperienceControl(id: "run.restart")]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> ArcadeCore {
        try Task.checkCancellation()
        return ArcadeCore(seed: seed)
    }

    /// One fixed step of Neon Dodge (`GameSimulation.advance`); a paused or over run is left unchanged by it.
    public mutating func update(step: Int) {
        GameSimulation.advance(&run, catalog: Self.catalog, random: &generator)
    }

    /// Carries out a well-formed action (the engine checked the control, the value count, finiteness and ranges).
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        let expected = ["run.steer": 1, "run.pause": 1, "run.restart": 0][action.control]
        guard let expected else { return .rejected(.unknownControl(action.control)) }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        switch action.control {
        case "run.steer":
            guard v[0].isFinite, abs(v[0]) <= 1 else { return .rejected(.rule(code: ArcadeRule.invalidSteering)) }
            GameSimulation.steer(&run, value: v[0])
        case "run.pause":
            guard let i = Self.choice(v[0], count: 2) else { return .rejected(.rule(code: ArcadeRule.invalidChoice)) }
            run.paused = i == 1
        default:   // run.restart
            GameSimulation.restart(&run)
        }
        return .accepted
    }

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// `run-over` once the lives are gone, `run-paused` while paused, `run-playing` otherwise.
    public var outcome: ExperienceOutcome? {
        ExperienceOutcome(code: run.over ? Self.overOutcome : run.paused ? Self.pausedOutcome : Self.playingOutcome)
    }

    /// Back to the first state built from the preparation seed.
    public mutating func reset() {
        self = ArcadeCore(seed: preparationSeed)
    }

    /// The canonical text of the whole state (`a10.arcade.v1|` and the state as JSON with sorted keys); a value that
    /// cannot be written (a non-finite number) is refused as non-finite.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = try? String(data: Self.encode(state), encoding: .utf8) else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a10.arcade.v1|" + text)
    }

    /// The arcade state (schema 1) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        try Self.encode(state)
    }

    /// The core of a schema-1 payload with the envelope's `seed` as preparation seed. A payload that does not decode,
    /// a run that does not validate or a malformed generator state is refused (throws).
    public static func restore(payload: Data, seed: UInt64) throws -> ArcadeCore {
        let state = try JSONDecoder().decode(ArcadeState.self, from: payload)
        let problems = state.run.validate()
        guard problems.isEmpty else { throw ArcadeRestoreError.invalidRun(problems) }
        return try ArcadeCore(seed: seed, state: state)
    }

    /// `value` as JSON with sorted keys.
    static func encode(_ value: ArcadeState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
