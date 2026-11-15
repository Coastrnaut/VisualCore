// AquariumCore — feature 068 (A09-P01) T-A09-103 (FR-A09-101, FR-A09-110, FR-A09-111, FR-A09-121; clarifications 1,
// 2 and 4; contract "Experience actions"). The state of Digital Aquarium as an experience: an `AquariumState` (the
// habitat document, the simulation step count, the pause flag and the generator state) and the preparation seed. A
// host step advances the fish by one fixed step of `AquariumSimulation` (1/60 s) unless the motion is paused; the
// session steps the core only while it runs, so a suspension never fast-forwards the fish.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange` before the core sees it):
//   habitat.select [0…1]   the starter habitat (Reef, Kelp) of `SpeciesCatalog.bundled`, built with the core's
//                          generator; the lighting level stays, the step count and the pause flag stay.
//   lighting.level [0…2]   dim, soft, bright (the presenter scales the colours by 0.6, 0.8, 1.0).
//   motion.pause [0…1]     swimming, paused.
// Feature 070 (A09-P03) T-A09-306 (FR-A09-301, 310, 320; clarification 2): feeding and decor editing. Positions are
// fractions of the tank (x left→right, y bottom→top), mapped by `DecorEditing.tankPoint`.
//   food.drop [0…1, 0…1]           three pellets around the point (clamped into the swim bounds); refused whole with
//                                  `a09.food-full` when the water would hold more than 12.
//   decor.kind [0…2]               the decoration kind the next placement uses (catalog decor order).
//   decor.place [0…1, 0…1]         a piece of the chosen kind at the point (clamped into the tank), rotation 0, scale
//                                  1; refused with `a09.decor-full` at 12 pieces.
//   decor.move [0…11, 0…1, 0…1]    piece `index` to the point; `a09.no-such-decor` for a missing piece.
//   decor.remove [0…11]            piece `index`; `a09.no-such-decor` for a missing piece.
// A habitat change clears the pellets and brings the new habitat's starter decor; the chosen kind stays.
// Feature 072 (A09-P05) T-A09-504 (FR-A09-501, 510, 520; clarifications 1, 2 and 4):
//   ambient.mode [0…1]                    off, on: the fish cruise at 0.6 of their speed (the drawing also halves the
//                                         particles and dims after idle; Low Power Mode and Reduce Motion do that
//                                         without touching the state).
//   decor.turn [0…11, −π…π, 0.5…2.0]      piece `index` gets the rotation and the scale (used when a saved
//                                         configuration is rebuilt); `a09.no-such-decor` for a missing piece.
// Snapshot schema 4 adds `ambient` (missing → off). Three quality tiers (`level-0`…`level-2`) choose the drawing
// budget (`AquariumBudget`); the state never depends on them.
// A choice value that is not a whole number naming an entry is refused with the rule `a09.invalid-choice`; a refusal
// changes nothing.
//
// Snapshot schema 3 (features 069 and 070; FR-A09-212, FR-A09-320): `AquariumState` as JSON with sorted keys; the
// preparation seed and the schema version come from the snapshot envelope. Schema 2 added the fish `turn` and the decor
// rotation and scale, schema 3 the pellets (habitat document schema 3, `food`) and the chosen decoration kind
// (`decorKind`). The chain carries a schema-1 payload unchanged and gives a schema-2 payload `decorKind` 0; the
// document is migrated to schema 3 by `HabitatDocument.migrated(catalog:)` on restore (missing fields take their
// defaults; a schema-1 document without decor gets the habitat's starter decor). `schemaOneExample()` and
// `schemaTwoExample()` are the stored payloads the registry's migration check restores. A payload whose (migrated)
// document does not validate, whose habitat index, lighting level or decoration kind names no entry, whose step count
// is negative or whose generator state is malformed is refused (the restore throws). Three quality tiers (feature 072).
import Foundation
import DigitalAquariumCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Digital Aquarium's refusals.
public enum AquariumRule {
    /// A choice value that is not a whole number naming an entry of the action's table.
    public static let invalidChoice = "a09.invalid-choice"
    /// A feed that would put more than 12 pellets in the water (feature 070).
    public static let foodFull = "a09.food-full"
    /// A placement when the habitat already holds 12 decor pieces (feature 070).
    public static let decorFull = "a09.decor-full"
    /// A move or removal of a decor piece that does not exist (feature 070).
    public static let noSuchDecor = "a09.no-such-decor"
}

/// Why a stored aquarium state is refused.
public enum AquariumRestoreError: Error, Equatable {
    /// The habitat document does not validate (its problems).
    case invalidDocument([String])
    /// The habitat index names no starter habitat of the bundled catalog.
    case unknownHabitat(Int)
    /// The lighting level is not 0, 1 or 2.
    case invalidLighting(Int)
    /// The step count is negative.
    case negativeStep(Int)
    /// The generator state cannot be restored.
    case invalidGenerator
    /// The chosen decoration kind names no decor kind of the bundled catalog (feature 070).
    case invalidDecorKind(Int)
}

/// The saved state of Digital Aquarium (snapshot schema 4).
public struct AquariumState: Codable, Equatable, Sendable {
    /// The habitat document: water colour, bounds, plants, fish, decor and lighting.
    public var document: HabitatDocument
    /// The number of simulation steps taken (paused steps are not counted).
    public var step: Int
    /// Whether the motion is paused.
    public var paused: Bool
    /// The state of the generator that drives the reduced wander turn and builds the starter habitats.
    public var random: SeededRandom.State
    /// The decoration kind the next placement uses: an index into the catalog's decor kinds (schema 3; 0 when missing).
    public var decorKind: Int
    /// Whether ambient mode is on (schema 4; off when missing): the fish cruise at 0.6 of their speed.
    public var ambient: Bool

    /// A state of `document` after `step` steps, paused or not, with the generator state `random`, the chosen
    /// decoration kind `decorKind` and the ambient choice `ambient`.
    public init(document: HabitatDocument, step: Int, paused: Bool, random: SeededRandom.State, decorKind: Int = 0,
                ambient: Bool = false) {
        self.ambient = ambient
        self.document = document
        self.step = step
        self.paused = paused
        self.random = random
        self.decorKind = decorKind
    }

    private enum CodingKeys: String, CodingKey { case document, step, paused, random, decorKind, ambient }

    /// Decodes a state; a missing `decorKind` (snapshot schemas 1 and 2) decodes as 0.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        document = try c.decode(HabitatDocument.self, forKey: .document)
        step = try c.decode(Int.self, forKey: .step)
        paused = try c.decode(Bool.self, forKey: .paused)
        random = try c.decode(SeededRandom.State.self, forKey: .random)
        decorKind = try c.decodeIfPresent(Int.self, forKey: .decorKind) ?? 0
        ambient = try c.decodeIfPresent(Bool.self, forKey: .ambient) ?? false
    }
}

/// The state of Digital Aquarium. Schema version 4.
public struct AquariumCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a09.digital-aquarium"

    /// The outcome code: every state shows a configured aquarium (a starter habitat is always chosen); the completion
    /// scenario checks it after a change of settings.
    public static let outcomeCode = "aquarium-configured"

    /// The action ids in declaration order.
    public static let actionIDs = ["habitat.select", "lighting.level", "motion.pause", "food.drop", "decor.kind",
                                   "decor.place", "decor.move", "decor.remove", "ambient.mode", "decor.turn"]

    /// The number of lighting levels (dim, soft, bright).
    public static let lightingLevels = 3

    /// The catalog the core reads its species, plants and starter habitats from.
    public static var catalog: SpeciesCatalog { SpeciesCatalog.bundled }

    /// The preparation seed; `reset()` returns to the first state built from it.
    public private(set) var preparationSeed: UInt64
    /// The habitat document.
    public private(set) var document: HabitatDocument
    /// The number of simulation steps taken.
    public private(set) var step: Int
    /// Whether the motion is paused.
    public private(set) var paused: Bool
    /// The generator of the reduced wander turn and of the starter habitats.
    public private(set) var generator: SeededRandom
    /// The decoration kind the next placement uses (an index into the catalog's decor kinds).
    public private(set) var decorKind: Int = 0
    /// Whether ambient mode is on.
    public private(set) var ambient: Bool = false

    /// The first state prepared with `seed`: the first starter habitat (Reef) built with a generator seeded by `seed`,
    /// step 0, swimming.
    public init(seed: UInt64) {
        preparationSeed = seed
        var random = SeededRandom(seed: seed)
        document = HabitatDocument.starter(0, catalog: Self.catalog, random: &random)
        generator = random
        step = 0
        paused = false
    }

    /// A core holding `state`, prepared with `seed`; throws when the generator state cannot be restored.
    init(seed: UInt64, state: AquariumState) throws {
        preparationSeed = seed
        document = state.document
        step = state.step
        paused = state.paused
        decorKind = state.decorKind
        ambient = state.ambient
        do {
            generator = try SeededRandom(restoring: state.random)
        } catch {
            throw AquariumRestoreError.invalidGenerator
        }
    }

    /// The whole state: document, step count, pause flag and generator state.
    public var state: AquariumState {
        AquariumState(document: document, step: step, paused: paused, random: generator.state, decorKind: decorKind,
                      ambient: ambient)
    }

    // MARK: Contract

    /// One fixed simulation step: `AquariumSimulation.step` (1/60 s).
    public static var stepDuration: Double { AquariumSimulation.step }

    /// Three quality tiers (`level-0`…`level-2`, feature 072): level 0 draws everything, level 1 halves the bubbles
    /// and motes and draws one-octave caustics, level 2 quarters them and draws no caustics (`AquariumBudget`).
    public static var qualityTiers: Int { AquariumBudget.levels }

    /// Schema 3; a schema-1 payload is carried over unchanged, a schema-2 payload gains `decorKind` 0 (feature 070),
    /// and the habitat document is migrated on restore (`HabitatDocument.migrated(catalog:)` needs the catalog, which a
    /// payload step does not have).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: 4, steps: [
            1: { payload in payload },
            2: { payload in
                var upgraded = payload
                upgraded["decorKind"] = 0
                return upgraded
            },
            3: { payload in
                var upgraded = payload
                upgraded["ambient"] = false
                return upgraded
            },
        ])
    }

    /// The stored example of schema 1 for the registry's migration check (feature 069, T-A09-206): the A09-P01 payload
    /// of the Kelp habitat at bright lighting after 120 steps — written as A09-P01 wrote it (habitat document schema 1,
    /// no `turn`, `rotation` or `scale`, no decor) — with the digest its restore must give: the same aquarium with its
    /// document migrated (schema 3, the Kelp starter decor, no pellets). Nil only if the encoding failed.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID) else { return nil }
        var core = AquariumCore(seed: seed)
        _ = core.apply(ExperienceAction(control: "habitat.select", values: [1], step: 0))
        _ = core.apply(ExperienceAction(control: "lighting.level", values: [2], step: 0))
        for s in 0..<120 { core.update(step: s) }
        // The schema-1 shape: the document without the decor and the schema-2 fields.
        guard var object = (try? JSONSerialization.jsonObject(with: encode(core.state))) as? [String: Any],
              var document = object["document"] as? [String: Any],
              let fish = document["fish"] as? [[String: Any]] else { return nil }
        document["schema"] = 1
        document["decor"] = [Any]()
        document["food"] = nil
        document["fish"] = fish.map { var f = $0; f["turn"] = nil; return f }
        object["document"] = document
        object["decorKind"] = nil
        object["ambient"] = nil
        // The expected state: the schema-1 document as decoded (turn 0), then migrated.
        guard let payload = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let restored = try? restore(payload: payload, seed: seed) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? restored.writeDigest(into: &builder)) != nil,
              let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: 1, seed: seed,
                                                     stepIndex: restored.step, digest: builder.finish(),
                                                     payload: payload),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: 1, snapshot: encoded, expectedDigest: builder.finish().hex)
    }

    /// The stored example of schema 2 for the registry's migration check (feature 070, T-A09-306): the A09-P02 payload
    /// of the Reef habitat at dim lighting after 90 steps with its starter decor — written as A09-P02 wrote it (habitat
    /// document schema 2, no `food`, no `decorKind`) — with the digest its restore must give: the same aquarium with
    /// its document at schema 3, no pellets and the first decoration kind. Nil only if the encoding failed.
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID) else { return nil }
        var core = AquariumCore(seed: seed)
        _ = core.apply(ExperienceAction(control: "lighting.level", values: [0], step: 0))
        for s in 0..<90 { core.update(step: s) }
        guard var object = (try? JSONSerialization.jsonObject(with: encode(core.state))) as? [String: Any],
              var document = object["document"] as? [String: Any] else { return nil }
        document["schema"] = 2
        document["food"] = nil
        object["document"] = document
        object["decorKind"] = nil
        object["ambient"] = nil
        guard let payload = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let restored = try? restore(payload: payload, seed: seed) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? restored.writeDigest(into: &builder)) != nil,
              let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: 2, seed: seed,
                                                     stepIndex: restored.step, digest: builder.finish(),
                                                     payload: payload),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: 2, snapshot: encoded, expectedDigest: builder.finish().hex)
    }

    /// The stored example of schema 3 for the registry's migration check (feature 072, T-A09-504): an A09-P04 payload
    /// (no `ambient`) of the Kelp habitat at soft lighting after 60 steps with decoration kind 2 chosen and food in the
    /// water, with the digest its restore must give: the same aquarium with ambient mode off. Nil only if the encoding
    /// failed.
    public static func schemaThreeExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID) else { return nil }
        var core = AquariumCore(seed: seed)
        _ = core.apply(ExperienceAction(control: "habitat.select", values: [1], step: 0))
        _ = core.apply(ExperienceAction(control: "decor.kind", values: [2], step: 0))
        _ = core.apply(ExperienceAction(control: "food.drop", values: [0.5, 0.8], step: 0))
        for s in 0..<60 { core.update(step: s) }
        guard var object = (try? JSONSerialization.jsonObject(with: encode(core.state))) as? [String: Any] else {
            return nil
        }
        object["ambient"] = nil
        guard let payload = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let restored = try? restore(payload: payload, seed: seed) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? restored.writeDigest(into: &builder)) != nil,
              let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: 3, seed: seed,
                                                     stepIndex: restored.step, digest: builder.finish(),
                                                     payload: payload),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: 3, snapshot: encoded, expectedDigest: builder.finish().hex)
    }

    /// The ten controls with their declared ranges (positions as fractions of the tank; decor indices below the
    /// 12-piece limit; kinds of the catalog's decor).
    public static var controls: [ExperienceControl] {
        let pieces = Double(HabitatDocument.maxDecor - 1)
        return [ExperienceControl(id: "habitat.select", ranges: [0...Double(max(catalog.habitats.count - 1, 0))]),
                ExperienceControl(id: "lighting.level", ranges: [0...Double(lightingLevels - 1)]),
                ExperienceControl(id: "motion.pause", ranges: [0...1]),
                ExperienceControl(id: "food.drop", ranges: [0...1, 0...1]),
                ExperienceControl(id: "decor.kind", ranges: [0...Double(max(catalog.decor.count - 1, 0))]),
                ExperienceControl(id: "decor.place", ranges: [0...1, 0...1]),
                ExperienceControl(id: "decor.move", ranges: [0...pieces, 0...1, 0...1]),
                ExperienceControl(id: "decor.remove", ranges: [0...pieces]),
                ExperienceControl(id: "ambient.mode", ranges: [0...1]),
                ExperienceControl(id: "decor.turn", ranges: [0...pieces, -Double.pi...Double.pi, 0.5...2.0])]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> AquariumCore {
        try Task.checkCancellation()
        return AquariumCore(seed: seed)
    }

    /// One fixed step of schooling (`AquariumSimulation.advance`), unless the motion is paused.
    public mutating func update(step: Int) {
        guard !paused else { return }
        AquariumSimulation.advance(&document, catalog: Self.catalog, random: &generator, ambient: ambient)
        self.step += 1
    }

    /// Carries out a well-formed action (the engine checked the control, the value count, finiteness and ranges).
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        let expected = ["food.drop": 2, "decor.place": 2, "decor.move": 3, "decor.turn": 3][action.control] ?? 1
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        let x = v[0]
        switch action.control {
        case "habitat.select":
            guard let i = Self.choice(x, count: Self.catalog.habitats.count) else {
                return .rejected(.rule(code: AquariumRule.invalidChoice))
            }
            let lighting = document.lighting
            var random = generator
            var next = HabitatDocument.starter(i, catalog: Self.catalog, random: &random)
            next.lighting = lighting
            document = next          // a starter document: no pellets, the habitat's starter decor
            generator = random
        case "lighting.level":
            guard let i = Self.choice(x, count: Self.lightingLevels) else {
                return .rejected(.rule(code: AquariumRule.invalidChoice))
            }
            document.lighting = i
        case "motion.pause":
            guard let i = Self.choice(x, count: 2) else { return .rejected(.rule(code: AquariumRule.invalidChoice)) }
            paused = i == 1
        case "food.drop":
            let point = DecorEditing.tankPoint(fractionX: v[0], fractionY: v[1])
            guard Feeding.drop(at: point, into: &document) else { return .rejected(.rule(code: AquariumRule.foodFull)) }
        case "decor.kind":
            guard let i = Self.choice(x, count: Self.catalog.decor.count) else {
                return .rejected(.rule(code: AquariumRule.invalidChoice))
            }
            decorKind = i
        case "decor.place":
            guard Self.catalog.decor.indices.contains(decorKind) else {
                return .rejected(.rule(code: AquariumRule.invalidChoice))
            }
            let point = DecorEditing.tankPoint(fractionX: v[0], fractionY: v[1])
            guard DecorEditing.place(kindId: Self.catalog.decor[decorKind].id, at: point, into: &document) else {
                return .rejected(.rule(code: AquariumRule.decorFull))
            }
        case "decor.move":
            guard let i = Self.choice(x, count: HabitatDocument.maxDecor) else {
                return .rejected(.rule(code: AquariumRule.invalidChoice))
            }
            let point = DecorEditing.tankPoint(fractionX: v[1], fractionY: v[2])
            guard DecorEditing.move(index: i, to: point, in: &document) else {
                return .rejected(.rule(code: AquariumRule.noSuchDecor))
            }
        case "ambient.mode":
            guard let i = Self.choice(x, count: 2) else { return .rejected(.rule(code: AquariumRule.invalidChoice)) }
            ambient = i == 1
        case "decor.turn":
            guard let i = Self.choice(x, count: HabitatDocument.maxDecor) else {
                return .rejected(.rule(code: AquariumRule.invalidChoice))
            }
            guard document.decor.indices.contains(i) else { return .rejected(.rule(code: AquariumRule.noSuchDecor)) }
            document.decor[i].rotation = v[1]
            document.decor[i].scale = v[2]
        case "decor.remove":
            guard let i = Self.choice(x, count: HabitatDocument.maxDecor) else {
                return .rejected(.rule(code: AquariumRule.invalidChoice))
            }
            guard DecorEditing.remove(index: i, from: &document) else {
                return .rejected(.rule(code: AquariumRule.noSuchDecor))
            }
        default:
            return .rejected(.unknownControl(action.control))
        }
        return .accepted
    }

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// `aquarium-configured`, always (see ``outcomeCode``).
    public var outcome: ExperienceOutcome? { ExperienceOutcome(code: Self.outcomeCode) }

    /// Back to the first state built from the preparation seed.
    public mutating func reset() {
        self = AquariumCore(seed: preparationSeed)
    }

    /// The canonical text of the whole state (`a09.aquarium.v1|` and the state as JSON with sorted keys); a value that
    /// cannot be written (a non-finite number) is refused as non-finite.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = try? String(data: Self.encode(state), encoding: .utf8) else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a09.aquarium.v1|" + text)
    }

    /// The aquarium state (schema 3) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        try Self.encode(state)
    }

    /// The core of a payload (schema 3, or schema 1 or 2 carried over by ``migrations``) with the envelope's `seed` as
    /// preparation seed; its document is migrated to schema 3 first. A payload that does not decode, a migrated
    /// document that does not validate, an unknown habitat, a lighting level outside 0…2, a negative step count, a
    /// decoration kind outside the catalog or a malformed generator state is refused (throws).
    public static func restore(payload: Data, seed: UInt64) throws -> AquariumCore {
        var state = try JSONDecoder().decode(AquariumState.self, from: payload)
        state.document = state.document.migrated(catalog: catalog)
        let problems = state.document.validate(catalog: catalog)
        guard problems.isEmpty else { throw AquariumRestoreError.invalidDocument(problems) }
        guard catalog.habitats.indices.contains(state.document.habitatIndex) else {
            throw AquariumRestoreError.unknownHabitat(state.document.habitatIndex)
        }
        guard (0..<lightingLevels).contains(state.document.lighting) else {
            throw AquariumRestoreError.invalidLighting(state.document.lighting)
        }
        guard state.step >= 0 else { throw AquariumRestoreError.negativeStep(state.step) }
        guard catalog.decor.indices.contains(state.decorKind) else {
            throw AquariumRestoreError.invalidDecorKind(state.decorKind)
        }
        return try AquariumCore(seed: seed, state: state)
    }

    /// `value` as JSON with sorted keys.
    static func encode(_ value: AquariumState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
