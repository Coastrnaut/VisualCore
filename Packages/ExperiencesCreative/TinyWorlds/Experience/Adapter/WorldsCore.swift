// WorldsCore — feature 089 (A12-P01) T-A12-104 (FR-A12-120, FR-A12-121, FR-A12-122; clarifications 4 and 5; research
// D4; plan "Lifecycle"). The state of Tiny Worlds as an experience: a `WorldState` (preset, seed, view and the state of
// the generator that draws new seeds), the preparation seed and, as a cache of the state, the terrain digest of the
// current preset and seed (`TerrainGenerator.digest(preset:seed:)`, recomputed only when the preset or the seed
// changes, and remembered per preset and seed in a small process-wide memo, at most 64 entries, because generation is
// pure). Nothing animates: a host step (the default 1/120 s) changes nothing, so a suspension never changes the
// world either.
//
// Preparation: the preparation seed names the world's seed when it lies in 1…4,294,967,295 (so a scenario prepared
// with seed 2 opens seed 2 of the island); any other preparation seed (0, or a value above 32 bits such as the one
// app's per-experience seed) opens the default world, seed 1 (`WorldState.defaultSeed`). The island, the default view
// and a fresh generator seeded with `WorldState.generatorSeed` complete the first state, so the one app opens exactly
// `WorldState.initial`.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange`, a non-finite value with `nonFinite` and a wrong value count with `wrongValueCount` before
// the core sees it):
//   world.preset [0…2]               island, asteroid garden, miniature city by index; a value that is not a whole
//                                    index 0…2 (fractional, out of range or non-finite) is refused with
//                                    `a12.invalid-choice`.
//   world.seed                       no values: the next seed from the session's generator (`WorldState.newSeed()`).
//   view.orbit [Δyaw°, Δpitch°]      each −180…180: turns the view (yaw wraps) and tilts it (pitch clamped to
//                                    10°…75°); a step outside −180…180 or non-finite is refused with
//                                    `a12.invalid-choice`.
//   view.zoom [factor 0.5…2]         divides the distance by the factor (clamped to 10…30 m); a factor outside 0.5…2
//                                    or non-finite is refused with `a12.invalid-choice`.
//   view.reset                       no values: the default view (yaw 45°, pitch 35°, 18 m).
// Called directly (not through the engine), the core refuses an unknown control with `unknownControl` and a wrong
// value count with `wrongValueCount`, as the engine does. A refusal changes nothing.
//
// Snapshot schema 1: `WorldState.encoded()` (JSON with sorted keys); the preparation seed and the schema version come
// from the snapshot envelope (`MigrationChain(currentVersion: 1)`, so a newer envelope is refused by the engine). A
// payload `WorldState.decode(_:)` refuses (damaged, or a newer schema inside the payload) is refused (the restore
// throws `WorldsRestoreError`). One quality tier (`level-0`). The digest is the canonical text of the whole state and
// the terrain digest it generates, so a scenario's final digest pins the terrain too. The outcome names the world
// shown (`world-island`, `world-asteroid-garden`, `world-miniature-city`).
import Foundation
import Synchronization
import TinyWorldsCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Tiny Worlds' refusals.
public enum WorldsRule {
    /// A preset index, orbit step or zoom factor that is not a valid choice.
    public static let invalidChoice = "a12.invalid-choice"
}

/// Why a stored world state is refused.
public enum WorldsRestoreError: Error, Equatable {
    /// `WorldState.decode(_:)` refused the payload, for the named reason.
    case refused(WorldStateRefusal)
}

/// The state of Tiny Worlds. Schema version 1.
public struct WorldsCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a12.tiny-worlds"

    /// The action ids in declaration order.
    public static let actionIDs = ["world.preset", "world.seed", "view.orbit", "view.zoom", "view.reset"]

    /// The outcome code of the world showing `preset` (`world-<preset content id>`).
    public static func outcomeCode(_ preset: WorldPreset) -> String { "world-" + preset.id.contentId }

    /// The preparation seed; `reset()` returns to the first state built from it.
    public private(set) var preparationSeed: UInt64
    /// The whole saved state: preset, seed, view and generator.
    public private(set) var state: WorldState
    /// The terrain digest of the current preset and seed (a cache of the state, never saved); empty only if the
    /// terrain could not be generated (never for the bundled presets).
    public private(set) var terrainDigest: String

    /// The world's seed for the preparation seed `seed`: `seed` itself when it lies in 1…UInt32.max, otherwise
    /// `WorldState.defaultSeed` (1).
    public static func worldSeed(forPreparationSeed seed: UInt64) -> UInt32 {
        (1...UInt64(UInt32.max)).contains(seed) ? UInt32(seed) : WorldState.defaultSeed
    }

    /// The first state prepared with `seed`: the island with the world seed of ``worldSeed(forPreparationSeed:)``, the
    /// default view and a fresh generator seeded with `WorldState.generatorSeed`.
    public init(seed: UInt64) {
        let first = WorldState(presetIndex: WorldPresetID.island.rawValue, seed: Self.worldSeed(forPreparationSeed: seed),
                               view: .default, random: SeededRandom(seed: WorldState.generatorSeed).state)
        self.init(seed: seed, state: first)
    }

    /// A core holding `state`, prepared with `seed`.
    init(seed: UInt64, state: WorldState) {
        preparationSeed = seed
        self.state = state
        terrainDigest = Self.terrainDigest(of: state)
    }

    /// The most terrain digests ``terrainMemo`` keeps before it starts over.
    static let terrainMemoLimit = 64

    /// Terrain digests by preset index and seed (`presetIndex << 32 | seed`). Generation is pure, so a remembered
    /// digest equals a regenerated one; the memo only spares repeated generation (preparations, resets, replays).
    private static let terrainMemo = Mutex<[UInt64: String]>([:])

    /// The terrain digest of `state`'s preset and seed, or "" when the terrain cannot be generated.
    static func terrainDigest(of state: WorldState) -> String {
        let key = UInt64(state.presetIndex) << 32 | UInt64(state.seed)
        if let known = terrainMemo.withLock({ $0[key] }) { return known }
        let digest = (try? TerrainGenerator.digest(preset: state.preset, seed: state.seed)) ?? ""
        terrainMemo.withLock { memo in
            if memo.count >= terrainMemoLimit { memo.removeAll() }
            memo[key] = digest
        }
        return digest
    }

    /// The current preset.
    public var preset: WorldPreset { state.preset }
    /// The current world seed.
    public var seed: UInt32 { state.seed }
    /// The current view.
    public var view: WorldView { state.view }

    // MARK: Contract

    /// One quality tier (`level-0`): the drawing has nothing to scale down in this phase.
    public static var qualityTiers: Int { 1 }

    /// Schema 1, the first; nothing to migrate.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: WorldState.schemaVersion) }

    /// The five controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "world.preset", ranges: [0...Double(WorldState.presetRange.upperBound)]),
         ExperienceControl(id: "world.seed"),
         ExperienceControl(id: "view.orbit", ranges: [WorldView.orbitStepRange, WorldView.orbitStepRange]),
         ExperienceControl(id: "view.zoom", ranges: [WorldView.zoomRange]),
         ExperienceControl(id: "view.reset")]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> WorldsCore {
        try Task.checkCancellation()
        return WorldsCore(seed: seed)
    }

    /// A host step changes nothing: nothing animates in this phase.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        let expected = ["world.preset": 1, "world.seed": 0, "view.orbit": 2, "view.zoom": 1,
                        "view.reset": 0][action.control]
        guard let expected else { return .rejected(.unknownControl(action.control)) }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        let refused = ActionResult.rejected(.rule(code: WorldsRule.invalidChoice))
        switch action.control {
        case "world.preset":
            guard let index = Self.choice(v[0], count: WorldPreset.all.count) else { return refused }
            var next = state
            guard next.choosePreset(index) else { return refused }
            replace(with: next)
        case "world.seed":
            var next = state
            next.newSeed()
            replace(with: next)
        case "view.orbit":
            var view = state.view
            guard view.orbit(yawDegrees: v[0], pitchDegrees: v[1]) else { return refused }
            state.view = view
        case "view.zoom":
            var view = state.view
            guard view.zoom(v[0]) else { return refused }
            state.view = view
        default:   // view.reset
            state.view.reset()
        }
        return .accepted
    }

    /// Takes `next` as the state, regenerating the terrain digest only when the preset or the seed changed.
    private mutating func replace(with next: WorldState) {
        let regenerate = next.presetIndex != state.presetIndex || next.seed != state.seed
        state = next
        if regenerate { terrainDigest = Self.terrainDigest(of: next) }
    }

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// The world shown: `world-island`, `world-asteroid-garden` or `world-miniature-city`.
    public var outcome: ExperienceOutcome? { ExperienceOutcome(code: Self.outcomeCode(preset)) }

    /// Back to the first state built from the preparation seed.
    public mutating func reset() {
        self = WorldsCore(seed: preparationSeed)
    }

    /// The canonical text of the whole state and its terrain: `a12.worlds.v1|`, the state as JSON with sorted keys,
    /// `|terrain:` and the terrain digest. A state that cannot be written (never: every number of a valid state is
    /// finite) is refused as non-finite.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = String(data: state.encoded(), encoding: .utf8), !text.isEmpty else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a12.worlds.v1|" + text + "|terrain:" + terrainDigest)
    }

    /// The world state (schema 1) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        state.encoded()
    }

    /// The core of a schema-1 payload with the envelope's `seed` as preparation seed; a payload that
    /// `WorldState.decode(_:)` refuses (damaged or newer) throws ``WorldsRestoreError/refused(_:)``.
    public static func restore(payload: Data, seed: UInt64) throws -> WorldsCore {
        switch WorldState.decode(payload) {
        case .success(let state): return WorldsCore(seed: seed, state: state)
        case .failure(let reason): throw WorldsRestoreError.refused(reason)
        }
    }
}
