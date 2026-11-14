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
// A choice value that is not a whole number naming an entry is refused with the rule `a09.invalid-choice`; a refusal
// changes nothing.
//
// Snapshot schema 1: `AquariumState` as JSON with sorted keys; the preparation seed comes from the snapshot envelope. A
// payload whose document does not validate, whose habitat index or lighting level names no entry, whose step count is
// negative or whose generator state is malformed is refused (the restore throws). One quality tier (`level-0`).
import Foundation
import DigitalAquariumCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Digital Aquarium's refusals.
public enum AquariumRule {
    /// A choice value that is not a whole number naming an entry of the action's table.
    public static let invalidChoice = "a09.invalid-choice"
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
}

/// The saved state of Digital Aquarium (snapshot schema 1).
public struct AquariumState: Codable, Equatable, Sendable {
    /// The habitat document: water colour, bounds, plants, fish, decor and lighting.
    public var document: HabitatDocument
    /// The number of simulation steps taken (paused steps are not counted).
    public var step: Int
    /// Whether the motion is paused.
    public var paused: Bool
    /// The state of the generator that drives the wander and builds the starter habitats.
    public var random: SeededRandom.State

    /// A state of `document` after `step` steps, paused or not, with the generator state `random`.
    public init(document: HabitatDocument, step: Int, paused: Bool, random: SeededRandom.State) {
        self.document = document
        self.step = step
        self.paused = paused
        self.random = random
    }
}

/// The state of Digital Aquarium. Schema version 1.
public struct AquariumCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a09.digital-aquarium"

    /// The outcome code: every state shows a configured aquarium (a starter habitat is always chosen); the completion
    /// scenario checks it after a change of settings.
    public static let outcomeCode = "aquarium-configured"

    /// The action ids in declaration order.
    public static let actionIDs = ["habitat.select", "lighting.level", "motion.pause"]

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
    /// The generator of the wander and of the starter habitats.
    public private(set) var generator: SeededRandom

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
        do {
            generator = try SeededRandom(restoring: state.random)
        } catch {
            throw AquariumRestoreError.invalidGenerator
        }
    }

    /// The whole state: document, step count, pause flag and generator state.
    public var state: AquariumState {
        AquariumState(document: document, step: step, paused: paused, random: generator.state)
    }

    // MARK: Contract

    /// One fixed simulation step: `AquariumSimulation.step` (1/60 s).
    public static var stepDuration: Double { AquariumSimulation.step }

    /// One quality tier (`level-0`): the aquarium draws at most 36 shapes plus the water and the gravel.
    public static var qualityTiers: Int { 1 }

    /// Schema 1; no older schema exists.
    public static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }

    /// The three controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "habitat.select", ranges: [0...Double(max(catalog.habitats.count - 1, 0))]),
         ExperienceControl(id: "lighting.level", ranges: [0...Double(lightingLevels - 1)]),
         ExperienceControl(id: "motion.pause", ranges: [0...1])]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> AquariumCore {
        try Task.checkCancellation()
        return AquariumCore(seed: seed)
    }

    /// One fixed step of the bounded wander, unless the motion is paused.
    public mutating func update(step: Int) {
        guard !paused else { return }
        AquariumSimulation.advance(&document, catalog: Self.catalog, random: &generator)
        self.step += 1
    }

    /// Carries out a well-formed action (the engine checked the control, the value count, finiteness and ranges).
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        guard v.count == 1 else { return .rejected(.wrongValueCount(expected: 1, found: v.count)) }
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
            document = next
            generator = random
        case "lighting.level":
            guard let i = Self.choice(x, count: Self.lightingLevels) else {
                return .rejected(.rule(code: AquariumRule.invalidChoice))
            }
            document.lighting = i
        case "motion.pause":
            guard let i = Self.choice(x, count: 2) else { return .rejected(.rule(code: AquariumRule.invalidChoice)) }
            paused = i == 1
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

    /// The aquarium state (schema 1) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        try Self.encode(state)
    }

    /// The core of a schema-1 payload with the envelope's `seed` as preparation seed; a payload that does not decode, a
    /// document that does not validate, an unknown habitat, a lighting level outside 0…2, a negative step count or a
    /// malformed generator state is refused (throws).
    public static func restore(payload: Data, seed: UInt64) throws -> AquariumCore {
        let state = try JSONDecoder().decode(AquariumState.self, from: payload)
        let problems = state.document.validate(catalog: catalog)
        guard problems.isEmpty else { throw AquariumRestoreError.invalidDocument(problems) }
        guard catalog.habitats.indices.contains(state.document.habitatIndex) else {
            throw AquariumRestoreError.unknownHabitat(state.document.habitatIndex)
        }
        guard (0..<lightingLevels).contains(state.document.lighting) else {
            throw AquariumRestoreError.invalidLighting(state.document.lighting)
        }
        guard state.step >= 0 else { throw AquariumRestoreError.negativeStep(state.step) }
        return try AquariumCore(seed: seed, state: state)
    }

    /// `value` as JSON with sorted keys.
    static func encode(_ value: AquariumState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
