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
// Snapshot schema 2 — feature 076 (A10-P02) T-A10-203 (FR-A10-210, FR-A10-211; clarification 4; research D4):
// `ArcadeState` as JSON with sorted keys, holding the schema-2 run (with its wave state); the preparation seed and the
// schema version come from the snapshot envelope (`MigrationChain(currentVersion: 2)`, so a newer payload is refused
// by the engine). The step 1 → 2 decodes a Phase 01 payload (its run at schema 1, without the wave fields), lifts the
// run with `GameRun.migrated()` — wave 1, wave step 0, pattern `rain`, no free lane, cursor 0, everything else kept,
// the generator state untouched — and re-encodes it. A payload that does not decode, whose run does not validate
// (`GameRun.validate()` names a problem; a schema-1 run that skipped the migration is refused as "schema 1 is not 2")
// or whose generator state is malformed is refused (the restore throws). `schemaOneExample()` is the stored Phase 01
// payload the registry's migration check restores. One quality tier (`level-0`). The digest is the canonical text of
// the whole state — the run with its step, score, lives, flags, steering, player, objects, next id, the kept events,
// the event count and the wave state, and the generator state.
//
// Snapshot schema 3 — feature 077 (A10-P03) T-A10-304 (FR-A10-310, FR-A10-321; clarification 2; research D3):
// `ArcadeState` adds `screen` (title, playing, paused, over), `sound` and `haptics` (both on by default). The step
// 2 → 3 decodes a schema-2 payload, derives the screen from its run (`ArcadeScreen.derived(from:)`: over → over,
// paused → paused, otherwise playing) and turns sound and haptics on; a payload missing these keys decodes the same way.
// A new experience (and `reset()`) opens on the title screen holding a fresh run. Actions since schema 3:
//   run.start          no values: title → playing (the held run), over → playing with a new run;
//   run.pause [0…1]    1 pauses a playing game, 0 resumes a paused one (`run.paused` mirrors the paused screen);
//   run.restart        no values: paused or over → playing with a new run;
//   settings.sound [0…1], settings.haptics [0…1]   0 off, 1 on, on any screen; a fractional value is refused with
//                      `a10.invalid-choice`.
// A flow action on a screen `ArcadeFlow` does not allow is refused with the rule `a10.wrong-screen`. `run.steer` is
// allowed on every screen: it only stores the held value, which takes effect on the next advanced step (a value held
// on the title screen carries into the run that `run.start` plays; a new run starts straight). A host step advances
// the run only on the playing screen; the step that ends the run moves the screen to over. The restore refuses a state
// whose screen contradicts its run (over exactly when the run is over; otherwise paused exactly when the run is
// paused). `schemaTwoExample()` is the stored schema-2 payload (a paused run) the registry's migration check restores.
// The digest covers the screen and both settings; the outcome names the screen (`run-title`, `run-playing`,
// `run-paused`, `run-over`).
import Foundation
import NeonArcadeCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Neon Arcade's refusals.
public enum ArcadeRule {
    /// A choice value that is not a whole number naming an entry of the action's table (`run.pause`,
    /// `settings.sound` or `settings.haptics` other than 0 or 1).
    public static let invalidChoice = "a10.invalid-choice"
    /// A steering value that is not finite or lies outside −1…1 (only reachable when the core is called directly).
    public static let invalidSteering = "a10.invalid-steering"
    /// A flow action (`run.start`, `run.pause`, `run.restart`) on a screen that does not allow it (feature 077).
    public static let wrongScreen = "a10.wrong-screen"
}

/// Why a stored arcade state is refused.
public enum ArcadeRestoreError: Error, Equatable {
    /// The run does not validate (its problems, from `GameRun.validate()`), or the screen contradicts it.
    case invalidRun([String])
    /// The generator state cannot be restored.
    case invalidGenerator
}

/// The saved state of Neon Arcade (snapshot schema 3): the schema-2 run, the generator state, the screen and the
/// sound and haptics settings.
public struct ArcadeState: Codable, Equatable, Sendable {
    /// The Neon Dodge run.
    public var run: GameRun
    /// The state of the generator that draws the spawns.
    public var random: SeededRandom.State
    /// The screen shown (feature 077).
    public var screen: ArcadeScreen
    /// Whether sound effects play (feature 077; on by default).
    public var sound: Bool
    /// Whether haptics play (feature 077; on by default).
    public var haptics: Bool

    /// A state of `run` with the generator state `random` on `screen` (by default the screen the run implies:
    /// ``ArcadeScreen/derived(from:)``) with the settings given (on by default).
    public init(run: GameRun, random: SeededRandom.State, screen: ArcadeScreen? = nil, sound: Bool = true,
                haptics: Bool = true) {
        self.run = run
        self.random = random
        self.screen = screen ?? ArcadeScreen.derived(from: run)
        self.sound = sound
        self.haptics = haptics
    }

    private enum CodingKeys: String, CodingKey {
        case run, random, screen, sound, haptics
    }

    /// Decodes a state; a payload written before schema 3 (without `screen`, `sound` or `haptics`) reads with the
    /// screen derived from its run and both settings on (clarification 2).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        run = try container.decode(GameRun.self, forKey: .run)
        random = try container.decode(SeededRandom.State.self, forKey: .random)
        screen = try container.decodeIfPresent(ArcadeScreen.self, forKey: .screen) ?? ArcadeScreen.derived(from: run)
        sound = try container.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        haptics = try container.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
    }

    /// The problems of the screen against the run, empty when they agree: the screen is over exactly when the run is
    /// over, and otherwise paused exactly when the run is paused.
    public func screenProblems() -> [String] {
        if run.over != (screen == .over) {
            return ["screen \(screen.rawValue) does not match an over run: \(run.over)"]
        }
        if !run.over, run.paused != (screen == .paused) {
            return ["screen \(screen.rawValue) does not match a paused run: \(run.paused)"]
        }
        return []
    }
}

/// The state of Neon Arcade. Schema version 3.
public struct ArcadeCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a10.neon-arcade"

    /// The outcome on the title screen (feature 077).
    public static let titleOutcome = "run-title"
    /// The outcome while the run is being played.
    public static let playingOutcome = "run-playing"
    /// The outcome while the run is paused.
    public static let pausedOutcome = "run-paused"
    /// The outcome once the lives are gone.
    public static let overOutcome = "run-over"

    /// The snapshot schema of this build (feature 077).
    public static let snapshotSchema = 3
    /// The snapshot schema of feature 076 (A10-P02), before the screen and the settings.
    public static let schemaTwo = 2
    /// The keys schema 3 adds to the stored state.
    static let schemaThreeKeys = ["screen", "sound", "haptics"]

    /// The action ids in declaration order.
    public static let actionIDs = ["run.start", "run.steer", "run.pause", "run.restart", "settings.sound",
                                   "settings.haptics"]

    /// The content the run spawns from: the bundled catalog (it validates: `ArcadeCatalog.decode` of its encoding
    /// refuses nothing, which the tests check).
    public static var catalog: ArcadeCatalog { ArcadeCatalog.bundled }

    /// The preparation seed; `reset()` returns to the first state built from it.
    public private(set) var preparationSeed: UInt64
    /// The Neon Dodge run.
    public private(set) var run: GameRun
    /// The generator of the spawns.
    public private(set) var generator: SeededRandom
    /// The screen shown (feature 077); only ``ArcadeScreen/playing`` advances the run.
    public private(set) var screen: ArcadeScreen
    /// Whether sound effects play (feature 077).
    public private(set) var sound: Bool
    /// Whether haptics play (feature 077).
    public private(set) var haptics: Bool

    /// The first state prepared with `seed`: the title screen holding a new run (step 0, score 0, three lives, the
    /// player at rest in the middle, no objects), a generator seeded by `seed`, sound and haptics on.
    public init(seed: UInt64) {
        preparationSeed = seed
        run = GameRun.new()
        generator = SeededRandom(seed: seed)
        screen = ArcadeFlow.initialScreen
        sound = true
        haptics = true
    }

    /// A core holding `state`, prepared with `seed`; throws when the generator state cannot be restored.
    init(seed: UInt64, state: ArcadeState) throws {
        preparationSeed = seed
        run = state.run
        screen = state.screen
        sound = state.sound
        haptics = state.haptics
        do {
            generator = try SeededRandom(restoring: state.random)
        } catch {
            throw ArcadeRestoreError.invalidGenerator
        }
    }

    /// The whole state: the run, the generator state, the screen and the settings.
    public var state: ArcadeState {
        ArcadeState(run: run, random: generator.state, screen: screen, sound: sound, haptics: haptics)
    }

    // MARK: Contract

    /// One fixed simulation step: `GameSimulation.step` (1/60 s).
    public static var stepDuration: Double { GameSimulation.step }

    /// One quality tier (`level-0`): the drawing has nothing to scale down.
    public static var qualityTiers: Int { 1 }

    /// Schema 3 (feature 077). The step 1 → 2 decodes a Phase 01 payload, lifts its run with `GameRun.migrated()`
    /// (the start of wave 1 with `rain`, everything else kept) and re-encodes it without the schema-3 keys; the step
    /// 2 → 3 adds the screen derived from the run and both settings on. A payload that does not decode is refused by
    /// the step (the engine reports the migration as failed).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: snapshotSchema, steps: [
            1: { payload in try migratedToSchemaTwo(payload) },
            2: { payload in try migratedToSchemaThree(payload) },
        ])
    }

    /// The step 1 → 2: `payload` decoded as an `ArcadeState` (a schema-1 run reads with the wave fields at their
    /// defaults), its run migrated and the state encoded again as a JSON object without the schema-3 keys.
    static func migratedToSchemaTwo(_ payload: [String: Any]) throws -> [String: Any] {
        var state = try decodeState(payload)
        state.run = state.run.migrated()
        var object = try jsonObject(state)
        for key in schemaThreeKeys { object[key] = nil }
        return object
    }

    /// The step 2 → 3 (clarification 2): `payload` decoded as an `ArcadeState` — the screen derived from its run
    /// when absent, sound and haptics on when absent — and encoded again as a JSON object.
    static func migratedToSchemaThree(_ payload: [String: Any]) throws -> [String: Any] {
        try jsonObject(decodeState(payload))
    }

    /// `payload` decoded as an `ArcadeState`.
    private static func decodeState(_ payload: [String: Any]) throws -> ArcadeState {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return try JSONDecoder().decode(ArcadeState.self, from: data)
    }

    /// `state` encoded as a JSON object.
    private static func jsonObject(_ state: ArcadeState) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: encode(state)) as? [String: Any] else {
            throw ArcadeRestoreError.invalidRun(["the migrated state is not a JSON object"])
        }
        return object
    }

    /// The core of seed `seed` after `run.start` and the recorded replay's first ``schemaOneExampleSteps`` steps
    /// (steering 0.6 from step 0, −0.3 from step 45): the run the stored examples were saved from.
    static func exampleSource(seed: UInt64) -> ArcadeCore {
        var core = ArcadeCore(seed: seed)
        _ = core.apply(ExperienceAction(control: "run.start", values: [], step: 0))
        for step in 0..<schemaOneExampleSteps {
            for input in schemaOneExampleInputs where input.step == step {
                _ = core.apply(ExperienceAction(control: "run.steer", values: [input.value], step: step))
            }
            core.update(step: step)
        }
        return core
    }

    /// The stored example of schema `version` built from the JSON object `object` (written as that schema wrote it),
    /// with the digest its restore through the migration chain must give; nil only if the encoding failed.
    private static func example(version: Int, object: [String: Any], seed: UInt64) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID),
              let payload = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let upgraded = try? migrations.migrate(object, from: version),
              let migrated = try? JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]),
              let restored = try? restore(payload: migrated, seed: seed) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? restored.writeDigest(into: &builder)) != nil,
              let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: version, seed: seed,
                                                     stepIndex: restored.run.step, digest: builder.finish(),
                                                     payload: payload),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: version, snapshot: encoded, expectedDigest: builder.finish().hex)
    }

    /// The stored example of schema 1 for the registry's migration check (feature 076, T-A10-203): the A10-P01
    /// payload of a run of seed `seed` after the first 120 steps of the recorded replay (steering 0.6 from step 0,
    /// −0.3 from step 45) — written as A10-P01 wrote it (the run at schema 1 without `wave`, `waveStep`, `patternId`,
    /// `freeLane` and `patternCursor`, and no screen or settings) — with the digest its restore must give: the same
    /// step, score, lives, player, objects, events and generator state with the run at schema 2 at the start of wave 1
    /// (`rain`, no free lane, cursor 0), on the playing screen with sound and haptics on. Nil only if the encoding
    /// failed.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? {
        let core = exampleSource(seed: seed)
        // The schema-1 shape: the run without the wave fields, at schema 1, and no schema-3 keys.
        guard var object = (try? JSONSerialization.jsonObject(with: encode(core.state))) as? [String: Any],
              var run = object["run"] as? [String: Any] else { return nil }
        run["schema"] = GameRun.schemaOne
        for key in ["wave", "waveStep", "patternId", "freeLane", "patternCursor"] { run[key] = nil }
        object["run"] = run
        for key in schemaThreeKeys { object[key] = nil }
        return example(version: GameRun.schemaOne, object: object, seed: seed)
    }

    /// The stored example of schema 2 for the registry's migration check (feature 077, T-A10-304): the A10-P02
    /// payload (no screen, sound or haptics) of the run ``schemaOneExample(seed:)`` was saved from, paused after its
    /// 120 steps, with the digest its restore must give: the same run and generator on the paused screen (derived
    /// from the paused run) with sound and haptics on. Nil only if the encoding failed.
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample? {
        var core = exampleSource(seed: seed)
        _ = core.apply(ExperienceAction(control: "run.pause", values: [1], step: schemaOneExampleSteps))
        guard var object = (try? JSONSerialization.jsonObject(with: encode(core.state))) as? [String: Any] else {
            return nil
        }
        for key in schemaThreeKeys { object[key] = nil }
        return example(version: schemaTwo, object: object, seed: seed)
    }

    /// The steps of the recorded replay the stored examples are saved after.
    public static let schemaOneExampleSteps = 120
    /// The steering inputs of the recorded replay within its first ``schemaOneExampleSteps`` steps (the same values as
    /// the manifest's `recordedInputs`, which exists in test builds only).
    public static let schemaOneExampleInputs: [(step: Int, value: Double)] = [(0, 0.6), (45, -0.3)]

    /// The six controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "run.start"),
         ExperienceControl(id: "run.steer", ranges: [-1...1]),
         ExperienceControl(id: "run.pause", ranges: [0...1]),
         ExperienceControl(id: "run.restart"),
         ExperienceControl(id: "settings.sound", ranges: [0...1]),
         ExperienceControl(id: "settings.haptics", ranges: [0...1])]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> ArcadeCore {
        try Task.checkCancellation()
        return ArcadeCore(seed: seed)
    }

    /// One fixed step of Neon Dodge (`GameSimulation.advance`) on the playing screen only; the step that ends the run
    /// moves the screen to over. Every other screen leaves the state unchanged.
    public mutating func update(step: Int) {
        guard screen.advancesRun else { return }
        GameSimulation.advance(&run, catalog: Self.catalog, random: &generator)
        if run.over { screen = .over }
    }

    /// The number of values each action takes.
    private static let valueCounts = ["run.start": 0, "run.steer": 1, "run.pause": 1, "run.restart": 0,
                                      "settings.sound": 1, "settings.haptics": 1]

    /// Carries out a well-formed action (the engine checked the control, the value count, finiteness and ranges).
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard let expected = Self.valueCounts[action.control] else {
            return .rejected(.unknownControl(action.control))
        }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        switch action.control {
        case "run.start":
            return flow(.start)
        case "run.steer":
            guard v[0].isFinite, abs(v[0]) <= 1 else { return .rejected(.rule(code: ArcadeRule.invalidSteering)) }
            GameSimulation.steer(&run, value: v[0])
        case "run.pause":
            guard let i = Self.choice(v[0], count: 2) else { return .rejected(.rule(code: ArcadeRule.invalidChoice)) }
            return flow(.pause(i == 1))
        case "run.restart":
            return flow(.restart)
        case "settings.sound":
            guard let i = Self.choice(v[0], count: 2) else { return .rejected(.rule(code: ArcadeRule.invalidChoice)) }
            sound = i == 1
        default:   // settings.haptics
            guard let i = Self.choice(v[0], count: 2) else { return .rejected(.rule(code: ArcadeRule.invalidChoice)) }
            haptics = i == 1
        }
        return .accepted
    }

    /// Applies a flow move: refused with `a10.wrong-screen` when `ArcadeFlow` does not allow it on this screen;
    /// otherwise a new run when the move asks for one (the generator continues, so the new run draws new objects by
    /// the same rules), the new screen, and `run.paused` set to mirror the paused screen.
    private mutating func flow(_ action: ArcadeFlowAction) -> ActionResult {
        guard let transition = ArcadeFlow.apply(action, to: screen) else {
            return .rejected(.rule(code: ArcadeRule.wrongScreen))
        }
        if transition.newRun { GameSimulation.restart(&run) }
        screen = transition.screen
        run.paused = screen == .paused
        return .accepted
    }

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// The outcome of the screen: `run-title`, `run-playing`, `run-paused` or `run-over`.
    public var outcome: ExperienceOutcome? {
        switch screen {
        case .title: return ExperienceOutcome(code: Self.titleOutcome)
        case .playing: return ExperienceOutcome(code: Self.playingOutcome)
        case .paused: return ExperienceOutcome(code: Self.pausedOutcome)
        case .over: return ExperienceOutcome(code: Self.overOutcome)
        }
    }

    /// Back to the first state built from the preparation seed (the title screen).
    public mutating func reset() {
        self = ArcadeCore(seed: preparationSeed)
    }

    /// The canonical text of the whole state (`a10.arcade.v1|` and the state as JSON with sorted keys: the run, the
    /// generator, the screen and both settings); a value that cannot be written (a non-finite number) is refused as
    /// non-finite.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = try? String(data: Self.encode(state), encoding: .utf8) else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a10.arcade.v1|" + text)
    }

    /// The arcade state (schema 3) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        try Self.encode(state)
    }

    /// The core of a schema-3 payload (an older one has been through ``migrations``) with the envelope's `seed` as
    /// preparation seed. A payload that does not decode, a run that does not validate (a schema-1 run included), a
    /// screen that contradicts the run or a malformed generator state is refused (throws).
    public static func restore(payload: Data, seed: UInt64) throws -> ArcadeCore {
        let state = try JSONDecoder().decode(ArcadeState.self, from: payload)
        let problems = state.run.validate() + state.screenProblems()
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
