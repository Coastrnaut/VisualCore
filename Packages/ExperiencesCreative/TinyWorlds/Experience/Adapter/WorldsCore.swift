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
// throws `WorldsRestoreError`). The quality tiers are described below. The digest is the canonical text of the whole
// state and the terrain digest it generates, so a scenario's final digest pins the terrain too. The outcome names the
// world shown (`world-island`, `world-asteroid-garden`, `world-miniature-city`).
//
// Feature 090 (A12-P02) T-A12-205 (FR-A12-210, FR-A12-222; clarifications 3 and 5; research D3; plan "Lifecycle"):
// the camera policy. After every accepted action (the view actions `view.orbit`, `view.zoom` and `view.reset`, and
// also `world.preset` and `world.seed`, whose new terrain may rise under the eye) and whenever a core is built from a
// state (preparation, restore, reset), the view is passed through `CameraPolicy.clamp(_:field:)` over the level-0
// terrain of the current preset and seed: the pitch is raised in 1° steps (to at most 75°) until the eye is 0.5 m above
// the terrain around the point below it. The clamp is idempotent, so a view that already keeps the clearance (every
// bundled preset's default view, and every view of the P01 scenario fixtures) is unchanged and so are their digests; a
// saved view that does not keep it is raised on restore. The level-0 height fields are remembered per preset and seed
// in a small process-wide memo (at most 16 entries), as the terrain digests are. Three quality tiers (`level-0`…
// `level-2`) are declared; the presenter maps them to the terrain detail levels and the state never depends on them.
//
// Feature 091 (A12-P03) T-A12-303 (FR-A12-302, FR-A12-303, FR-A12-310, FR-A12-320; clarifications Q2–Q4; research D2–D4;
// contracts/actions.md). Eight actions are added, each applied through the core's `WorldEditing` or `WorldLight` on a
// copy of the state (a refusal changes nothing); the core's refusals carry the `WorldEditRefusal` codes:
//   prop.place [kind 0…3, x −6…6, z −6…6]  a prop of the kind at (x, z), snapped to the terrain and selected; a kind
//                                          that is not a whole index is `a12.invalid-choice`; then `a12.prop-cap`,
//                                          `a12.outside` (|x| or |z| above 5.5 m), `a12.under-water`, `a12.too-close`;
//   prop.select [index −1…23]              −1 clears the selection; a fractional value or an index that names no prop
//                                          is `a12.invalid-choice`;
//   prop.move [dx −1…1, dz −1…1]           moves the selected prop; `a12.no-selection`, then the placement rules;
//   prop.rotate [degrees −180…180]         turns the selected prop about +y; `a12.no-selection`;
//   prop.delete                            deletes the selected prop; `a12.no-selection`;
//   light.azimuth [degrees 0…360]          the light's azimuth (360 wraps to 0);
//   light.elevation [degrees 10…85]        the light's elevation;
//   light.ambient [0.1…0.6]                the ambient level.
// The declared ranges let the engine refuse a value outside them (`outOfRange`); called directly, the core refuses a
// light value outside its range with `a12.invalid-choice`. The x and z ranges are the world box (−6…6), so a point of
// the box outside the 5.5 m prop limit reaches the core and is refused with `a12.outside`. Choosing a preset or a new
// seed clears the props and the selection (`WorldState`). The placement rules read the level-0 height field of the
// current preset and seed from the memo of feature 090 (`heightField(of:)`), so repeated edits never regenerate it.
//
// Snapshot schema 2 (`WorldState.schemaVersion`): the state with props, selection and light. `MigrationChain(currentVersion:
// 2)` has the step 1 → 2 (``migratedToSchemaTwo(_:)``): a schema-1 payload (its `schema` must be 1) gets no props, no
// selection (−1) and the default light, everything else kept. `schemaOneExample()` is the stored A12-P02 payload the
// registry's migration check restores, with the digest its restore through the step must give. A saved world is opened
// outside the replay: `openingSnapshot(of:experience:stepIndex:)` builds the snapshot the presenter hands to
// `ExperienceShell.restore`. The digest text keeps its `a12.worlds.v1|` prefix; the state's JSON (now with `light`,
// `props` and `selection`) is digested whole, so every prop transform and the light are covered.
//
// Feature 092 (A12-P04) T-A12-403 (FR-A12-402, FR-A12-404, FR-A12-407; clarifications Q1, Q3 and Q5; contracts/
// actions.md). One action is added:
//   world.pack [index 0…2]                 replaces the world with pack i's composition (`WorldPack.pack(index:)` and
//                                          `WorldPack.apply(to:field:)`: preset i, the pack's seed, a fresh generator,
//                                          its props in order, no selection, its light and its default view); also
//                                          "reset to pack" (the controls send it with the current preset's index), so
//                                          opening a pack after any edits gives the same state and digest. A value that
//                                          is not a whole index is `a12.invalid-choice`; a pack whose prop breaks a
//                                          placement rule is refused with that rule's code (`WorldEditRefusal`) and the
//                                          world stays.
// The camera policy now uses the preset's limits (`CameraPolicy.limits(for:)`, the pack's pitch and distance ranges)
// and sees the props: every clamp (after every accepted action, the prop actions included, and whenever a core is
// built from a state) is `CameraPolicy.clamp(_:state:field:)` over the level-0 terrain from the memo.
import Foundation
import Synchronization
import TinyWorldsCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreScenes
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
    /// The migration step 1 → 2 was handed a payload whose `schema` is not 1 (the number found, −1 when missing).
    case notSchemaOne(Int)
}

/// The state of Tiny Worlds. Schema version 2 (feature 091).
public struct WorldsCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a12.tiny-worlds"

    /// The action ids in declaration order.
    public static let actionIDs = ["world.preset", "world.seed", "view.orbit", "view.zoom", "view.reset",
                                   "prop.place", "prop.select", "prop.move", "prop.rotate", "prop.delete",
                                   "light.azimuth", "light.elevation", "light.ambient", "world.pack"]

    /// The number of values each action carries.
    static let valueCounts: [String: Int] = [
        "world.preset": 1, "world.seed": 0, "view.orbit": 2, "view.zoom": 1, "view.reset": 0,
        "prop.place": 3, "prop.select": 1, "prop.move": 2, "prop.rotate": 1, "prop.delete": 0,
        "light.azimuth": 1, "light.elevation": 1, "light.ambient": 1, "world.pack": 1,
    ]

    /// The declared range of a prop's x and z in `prop.place`: the world box, −6…6 m.
    public static let placeCoordinateRange: ClosedRange<Double> = -6...6
    /// The declared range of `light.azimuth` in degrees.
    public static let azimuthRange: ClosedRange<Double> = 0...360
    /// The declared range of `prop.select`: −1 (none) … the last possible prop index.
    public static let selectRange: ClosedRange<Double> = -1...Double(WorldEditing.maxProps - 1)

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
        var clamped = state
        clamped.view = Self.policyView(state.view, of: state)
        self.state = clamped
        terrainDigest = Self.terrainDigest(of: clamped)
    }

    /// The most level-0 height fields ``fieldMemo`` keeps before it starts over.
    static let fieldMemoLimit = 16

    /// Level-0 height fields by preset index and seed (`presetIndex << 32 | seed`); generation is pure.
    private static let fieldMemo = Mutex<[UInt64: HeightField]>([:])

    /// The level-0 height field of `state`'s preset and seed, or nil when it cannot be built (never for the bundled
    /// presets).
    static func heightField(of state: WorldState) -> HeightField? {
        let key = UInt64(state.presetIndex) << 32 | UInt64(state.seed)
        if let known = fieldMemo.withLock({ $0[key] }) { return known }
        guard let field = try? TerrainGenerator.heightField(preset: state.preset, seed: state.seed) else { return nil }
        fieldMemo.withLock { memo in
            if memo.count >= fieldMemoLimit { memo.removeAll() }
            memo[key] = field
        }
        return field
    }

    /// `view` passed through the camera policy for `state` (`CameraPolicy.clamp(_:state:field:)`: the preset's
    /// limits, the level-0 terrain from the memo and the props); when the terrain cannot be built, the policy checks
    /// it against the highest terrain.
    static func policyView(_ view: WorldView, of state: WorldState) -> WorldView {
        CameraPolicy.clamp(view, state: state, field: heightField(of: state))
    }

    /// Applies the camera policy to the current view (see the file header).
    private mutating func applyCameraPolicy() {
        let clamped = Self.policyView(state.view, of: state)
        if clamped != state.view { state.view = clamped }
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
    /// The placed props, in placement order.
    public var props: [PlacedProp] { state.props }
    /// The selected prop's index, or `WorldState.noSelection`.
    public var selection: Int { state.selection }
    /// The world light.
    public var light: WorldLight { state.light }

    // MARK: Contract

    /// Three quality tiers (`level-0`…`level-2`), drawn at the terrain detail levels 0…2 (`TerrainDetail`); the
    /// state and its digest never depend on the tier.
    public static var qualityTiers: Int { 3 }

    /// Schema 2 with the step 1 → 2 (``migratedToSchemaTwo(_:)``).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: WorldState.schemaVersion, steps: [
            1: { payload in try migratedToSchemaTwo(payload) },
        ])
    }

    /// The step 1 → 2: a schema-1 payload (its `schema` must be 1) with no props, no selection (−1) and the default
    /// light added and the schema set to 2; every other key is kept as it was. Not validated here; the restore
    /// validates.
    static func migratedToSchemaTwo(_ payload: [String: Any]) throws -> [String: Any] {
        let schema = (payload["schema"] as? NSNumber)?.intValue ?? -1
        guard schema == 1 else { throw WorldsRestoreError.notSchemaOne(schema) }
        let light = try JSONSerialization.jsonObject(with: JSONEncoder().encode(WorldLight.default))
        var upgraded = payload
        upgraded["schema"] = WorldState.schemaVersion
        upgraded["props"] = [Any]()
        upgraded["selection"] = WorldState.noSelection
        upgraded["light"] = light
        return upgraded
    }

    /// The declared range of `world.pack`: the pack indices 0…2.
    public static var packRange: ClosedRange<Double> { 0...Double(WorldPack.all.count - 1) }

    /// The fourteen controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "world.preset", ranges: [0...Double(WorldState.presetRange.upperBound)]),
         ExperienceControl(id: "world.seed"),
         ExperienceControl(id: "view.orbit", ranges: [WorldView.orbitStepRange, WorldView.orbitStepRange]),
         ExperienceControl(id: "view.zoom", ranges: [WorldView.zoomRange]),
         ExperienceControl(id: "view.reset"),
         ExperienceControl(id: "prop.place", ranges: [0...Double(PropKind.allCases.count - 1),
                                                      placeCoordinateRange, placeCoordinateRange]),
         ExperienceControl(id: "prop.select", ranges: [selectRange]),
         ExperienceControl(id: "prop.move", ranges: [WorldEditing.moveStepRange, WorldEditing.moveStepRange]),
         ExperienceControl(id: "prop.rotate", ranges: [WorldEditing.rotateStepRange]),
         ExperienceControl(id: "prop.delete"),
         ExperienceControl(id: "light.azimuth", ranges: [azimuthRange]),
         ExperienceControl(id: "light.elevation", ranges: [WorldLight.elevationRange]),
         ExperienceControl(id: "light.ambient", ranges: [WorldLight.ambientRange]),
         ExperienceControl(id: "world.pack", ranges: [packRange])]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> WorldsCore {
        try Task.checkCancellation()
        return WorldsCore(seed: seed)
    }

    /// A host step changes nothing: nothing animates in this phase.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header), then applies the camera policy; a refused action
    /// changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        let expected = Self.valueCounts[action.control]
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
        case "view.reset":
            state.view.reset()
        case "world.pack":
            return openPack(v[0])
        default:
            return applyEdit(action.control, v)
        }
        applyCameraPolicy()
        return .accepted
    }

    /// Replaces the world with the pack named by `value` (see the file header); a refusal changes nothing.
    private mutating func openPack(_ value: Double) -> ActionResult {
        guard let index = Self.choice(value, count: WorldPack.all.count), let pack = WorldPack.pack(index: index) else {
            return Self.refused(.invalidChoice)
        }
        var next = state
        let probe = WorldState(presetIndex: pack.presetIndex, seed: pack.seed, view: pack.defaultView,
                               random: state.random)
        if let refusal = pack.apply(to: &next, field: Self.heightField(of: probe)) { return Self.refused(refusal) }
        replace(with: next)
        applyCameraPolicy()
        return .accepted
    }

    /// Carries out a prop or light action (see the file header) on a copy of the state; a refusal changes nothing.
    /// The camera policy then passes over the new props (a prop never rises near the eye at the policy's heights, so
    /// the view almost never changes).
    private mutating func applyEdit(_ control: String, _ v: [Double]) -> ActionResult {
        var next = state
        let field = Self.heightField(of: state)
        let refusal: WorldEditRefusal?
        switch control {
        case "prop.place":
            guard let kind = Self.choice(v[0], count: PropKind.allCases.count) else {
                return Self.refused(.invalidChoice)
            }
            refusal = WorldEditing.place(kind: kind, x: v[1], z: v[2], in: &next, field: field)
        case "prop.select":
            guard v[0].isFinite, v[0] == v[0].rounded(), abs(v[0]) <= Double(Int32.max) else {
                return Self.refused(.invalidChoice)
            }
            refusal = WorldEditing.select(Int(v[0]), in: &next)
        case "prop.move":
            refusal = WorldEditing.move(dx: v[0], dz: v[1], in: &next, field: field)
        case "prop.rotate":
            refusal = WorldEditing.rotate(degrees: v[0], in: &next)
        case "prop.delete":
            refusal = WorldEditing.delete(in: &next)
        case "light.azimuth":
            guard Self.azimuthRange.contains(v[0]) else { return Self.refused(.invalidChoice) }
            refusal = next.light.setAzimuth(v[0]) ? nil : .invalidChoice
        case "light.elevation":
            refusal = next.light.setElevation(v[0]) ? nil : .invalidChoice
        default:   // light.ambient
            refusal = next.light.setAmbient(v[0]) ? nil : .invalidChoice
        }
        if let refusal { return Self.refused(refusal) }
        state = next
        applyCameraPolicy()
        return .accepted
    }

    /// The rule refusal of `refusal` (its spoken code).
    static func refused(_ refusal: WorldEditRefusal) -> ActionResult { .rejected(.rule(code: refusal.rawValue)) }

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

    /// The world state (schema 2) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        state.encoded()
    }

    /// The core of a schema-2 payload (or a schema-1 payload, read with no props and the default light) with the
    /// envelope's `seed` as preparation seed; a payload that
    /// `WorldState.decode(_:)` refuses (damaged or newer) throws ``WorldsRestoreError/refused(_:)``.
    public static func restore(payload: Data, seed: UInt64) throws -> WorldsCore {
        switch WorldState.decode(payload) {
        case .success(let state): return WorldsCore(seed: seed, state: state)
        case .failure(let reason): throw WorldsRestoreError.refused(reason)
        }
    }

    // MARK: Saved worlds and migration (feature 091)

    /// The core that opening `state` from a saved world gives: `state` (passed through the camera policy) with
    /// `core`'s preparation seed, so a reset still returns to the prepared world.
    public static func opening(state: WorldState, from core: WorldsCore) -> WorldsCore {
        WorldsCore(seed: core.preparationSeed, state: state)
    }

    /// The snapshot of `core` at `stepIndex` (schema 2, the digest the engine computes) that the presenter hands to
    /// `ExperienceShell.restore` to open a saved world.
    public static func openingSnapshot(of core: WorldsCore, experience: ExperienceID,
                                       stepIndex: Int) throws -> ExperienceSnapshot {
        var builder = DigestBuilder(domain: experience.rawValue)
        try core.writeDigest(into: &builder)
        return try ExperienceSnapshot(experience: experience, schemaVersion: WorldState.schemaVersion,
                                      seed: core.preparationSeed, stepIndex: stepIndex, digest: builder.finish(),
                                      payload: core.snapshotPayload())
    }

    /// The actions the stored A12-P02 example was saved after, all at step 0 (A12-P01 and A12-P02 actions only): the
    /// asteroid garden, a new seed, a turn with a tilt and a zoom in.
    public static let schemaOneExampleActions: [(control: String, values: [Double])] = [
        ("world.preset", [1]), ("world.seed", []), ("view.orbit", [-30, 15]), ("view.zoom", [1.25]),
    ]

    /// The schema-1 payload of seed `seed` after ``schemaOneExampleActions``: exactly the keys A12-P01 and A12-P02
    /// wrote (`presetIndex`, `random`, `schema` 1, `seed`, `view`). No prop or light action exists before A12-P03, so
    /// this is what A12-P02 saved for that seed and those actions.
    public static func schemaOneExamplePayload(seed: UInt64 = 7) -> [String: Any]? {
        var core = WorldsCore(seed: seed)
        for action in schemaOneExampleActions {
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: 0))
        }
        guard var object = (try? JSONSerialization.jsonObject(with: core.state.encoded())) as? [String: Any] else {
            return nil
        }
        for key in ["light", "props", "selection"] { object[key] = nil }
        object["schema"] = 1
        return object
    }

    /// The stored example of schema 1 for the registry's migration check: ``schemaOneExamplePayload(seed:)`` in an
    /// envelope of schema 1 at step 0, with the digest its restore through the step 1 → 2 must give (the same preset,
    /// seed, view and generator, no props, no selection and the default light). Nil only if the encoding failed.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID), let payload = schemaOneExamplePayload(seed: seed),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let upgraded = try? migrations.migrate(payload, from: 1),
              let migrated = try? JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]),
              let restored = try? restore(payload: migrated, seed: seed) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? restored.writeDigest(into: &builder)) != nil else { return nil }
        let digest = builder.finish()
        guard let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: 1, seed: seed, stepIndex: 0,
                                                     digest: digest, payload: data),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: 1, snapshot: encoded, expectedDigest: digest.hex)
    }
}
