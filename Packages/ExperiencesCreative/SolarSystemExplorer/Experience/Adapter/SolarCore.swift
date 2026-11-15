// SolarCore — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5; contracts/catalog.md). The
// state of Solar System Explorer as an experience: a `SolarState` (the selected body index, 0 = Sun … 8 = Neptune,
// into `BodyCatalog.bundled`) and the preparation seed. Nothing animates: a host step (the default 1/120 s) changes
// nothing, so a suspension never changes the line-up either.
//
// Preparation: every preparation seed opens with the Sun selected (`SolarState.initial`); the seed is kept only as the
// envelope's preparation seed (`reset()` returns to the same first state). The catalog is fixed data, so nothing
// depends on the seed.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange`, a non-finite value with `nonFinite` and a wrong value count with `wrongValueCount` before
// the core sees it):
//   body.select [0…8]   the body by catalog index; a value that is not a whole index 0…8 is refused with
//                       `a14.invalid-choice`.
//   body.next           the next body (refused with `a14.invalid-choice` at Neptune).
//   body.previous       the previous body (refused with `a14.invalid-choice` at the Sun).
// Called directly (not through the engine), the core refuses an unknown control with `unknownControl` and a wrong
// value count with `wrongValueCount`, as the engine does. A refusal changes nothing.
//
// Snapshot schema 1: `SolarState.encoded()` (JSON with sorted keys: schema, selection); the preparation seed and the
// schema version come from the snapshot envelope (`MigrationChain(currentVersion: 1)`, so a newer envelope is refused
// by the engine). A payload `SolarState.decode(_:)` refuses (damaged, newer inside the payload or out of range) is
// refused (the restore throws `SolarRestoreError`). One quality tier (`level-0`). The digest is the canonical text of
// the state ("a14.solar.v1|" and the state's JSON) followed by the selection and the selected body's id.
//
// The outcome is `viewing-<body id>` ("viewing-sun", "viewing-earth") for the selected body: the scenario manifest's
// completion scenario must expect an outcome (`ScenarioManifestValidator`), and selecting a body is what a session of
// this phase completes, as Tiny Worlds' `world-<preset>` outcome is.
//
// The canvas description (clarifications Q4, Q5): "Solar System Explorer: Earth selected; 9 bodies. Sizes and spacing
// not to scale."
import Foundation
import SolarSystemExplorerCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Solar System Explorer's refusals.
public enum SolarRule {
    /// A body index that is not a whole index 0…8, or a step past the first or the last body.
    public static let invalidChoice = "a14.invalid-choice"
}

/// Why a stored Solar System Explorer state is refused.
public enum SolarRestoreError: Error, Equatable {
    /// `SolarState.decode(_:)` refused the payload, for the named reason.
    case refused(SolarStateRefusal)
}

/// The state of Solar System Explorer. Schema version 1.
public struct SolarCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a14.solar-system-explorer"

    /// The action ids in declaration order.
    public static let actionIDs = ["body.select", "body.next", "body.previous"]

    /// The prefix of the outcome code; the selected body's id follows.
    public static let outcomePrefix = "viewing-"

    /// The words the canvas description and the legend end with.
    public static let notToScale = "Sizes and spacing not to scale"

    /// The catalog the selection refers to.
    public static var catalog: BodyCatalog { SolarState.catalog }

    /// The number of bodies of the catalog (9).
    public static var bodyCount: Int { SolarState.bodyCount }

    /// The preparation seed; `reset()` returns to the first state.
    public private(set) var preparationSeed: UInt64
    /// The whole saved state: the selected body.
    public private(set) var state: SolarState

    /// The first state (the Sun selected) with `seed` as preparation seed.
    public init(seed: UInt64) {
        self.init(seed: seed, state: .initial)
    }

    /// A core holding `state`, prepared with `seed`.
    init(seed: UInt64, state: SolarState) {
        preparationSeed = seed
        self.state = state
    }

    /// The selected body's index, 0 (the Sun) … 8 (Neptune).
    public var selection: Int { state.selection }
    /// The selected body; nil only if the catalog lacked the index (never for a decoded state).
    public var body: CelestialBody? { Self.catalog.body(at: state.selection) }
    /// The selected body's fact card.
    public var factCard: FactCard? { Self.catalog.factCard(for: state.selection) }

    // MARK: Contract

    /// One quality tier (`level-0`): the line-up has nothing to scale down in this phase.
    public static var qualityTiers: Int { 1 }

    /// Schema 1, no steps.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: SolarState.schemaVersion)
    }

    /// The three controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "body.select", ranges: [0...Double(bodyCount - 1)]),
         ExperienceControl(id: "body.next"),
         ExperienceControl(id: "body.previous")]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> SolarCore {
        try Task.checkCancellation()
        return SolarCore(seed: seed)
    }

    /// A host step changes nothing: nothing animates in this phase.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        let expected = ["body.select": 1, "body.next": 0, "body.previous": 0][action.control]
        guard let expected else { return .rejected(.unknownControl(action.control)) }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        let refused = ActionResult.rejected(.rule(code: SolarRule.invalidChoice))
        var next = state
        switch action.control {
        case "body.select":
            guard let index = Self.choice(v[0], count: Self.bodyCount), next.select(index) else { return refused }
        case "body.next":
            guard next.next() else { return refused }
        default:   // body.previous
            guard next.previous() else { return refused }
        }
        state = next
        return .accepted
    }

    /// The table index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// `viewing-<id>` of the selected body (see the file header).
    public var outcome: ExperienceOutcome? {
        ExperienceOutcome(code: Self.outcomePrefix + (body?.id ?? "unknown"))
    }

    /// Back to the first state.
    public mutating func reset() {
        self = SolarCore(seed: preparationSeed)
    }

    /// The canonical text of the state, then the selection and the selected body's id.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = String(data: state.encoded(), encoding: .utf8), !text.isEmpty else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a14.solar.v1|" + text)
        builder.add(state.selection)
        builder.add(body?.id ?? "")
    }

    /// The state (schema 1) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        state.encoded()
    }

    /// The core of a schema-1 payload with the envelope's `seed` as preparation seed; a payload that
    /// `SolarState.decode(_:)` refuses (damaged, newer or out of range) throws ``SolarRestoreError/refused(_:)``.
    public static func restore(payload: Data, seed: UInt64) throws -> SolarCore {
        switch SolarState.decode(payload) {
        case .success(let state): return SolarCore(seed: seed, state: state)
        case .failure(let reason): throw SolarRestoreError.refused(reason)
        }
    }

    // MARK: Words

    /// The name of the body at `index` ("Earth"), or "Unknown body" outside the catalog.
    public static func name(index: Int) -> String {
        catalog.body(at: index)?.name ?? "Unknown body"
    }

    /// The status line: "Earth selected, body 4 of 9".
    public static func status(selection: Int) -> String {
        "\(name(index: selection)) selected, body \(selection + 1) of \(bodyCount)"
    }

    /// The canvas description: "Solar System Explorer: Earth selected; 9 bodies. Sizes and spacing not to scale."
    public static func canvasDescription(selection: Int) -> String {
        "Solar System Explorer: \(name(index: selection)) selected; \(bodyCount) bodies. \(notToScale)."
    }

    /// The canvas description of this core.
    public var canvasDescription: String { Self.canvasDescription(selection: state.selection) }
}
