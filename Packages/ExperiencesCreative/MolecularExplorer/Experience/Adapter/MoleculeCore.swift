// MoleculeCore — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; contracts/domain.md). The state of
// Molecular Explorer as an experience: a `MoleculeState` (the selected molecule index, 0 = water … 4 = caffeine, into
// `MoleculeLibrary.molecules`) and the preparation seed. Nothing animates: a host step (the default 1/120 s) changes
// nothing, so a suspension never changes the molecule either.
//
// Preparation: every preparation seed opens with water selected (`MoleculeState.initial`); the seed is kept only as the
// envelope's preparation seed (`reset()` returns to the same first state). The library is fixed data, so nothing
// depends on the seed.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange`, a non-finite value with `nonFinite` and a wrong value count with `wrongValueCount` before
// the core sees it):
//   molecule.select [0…4]   the molecule by library index; a value that is not a whole index 0…4 is refused with
//                           `a15.invalid-choice`.
//   molecule.next           the next molecule (refused with `a15.invalid-choice` at caffeine).
//   molecule.previous       the previous molecule (refused with `a15.invalid-choice` at water).
// Called directly (not through the engine), the core refuses an unknown control with `unknownControl` and a wrong
// value count with `wrongValueCount`, as the engine does. A refusal changes nothing.
//
// Snapshot schema 1: `MoleculeState.encoded()` (JSON with sorted keys: schema, selection); the preparation seed and the
// schema version come from the snapshot envelope (`MigrationChain(currentVersion: 1)`, so a newer envelope is refused
// by the engine). A payload `MoleculeState.decode(_:)` refuses (damaged, newer inside the payload or out of range) is
// refused (the restore throws `MoleculeRestoreError`). One quality tier (`level-0`). The digest is the canonical text
// of the state ("a15.molecule.v1|" and the state's JSON) followed by the selection and the selected molecule's id.
//
// The outcome is `viewing-<molecule id>` ("viewing-water", "viewing-caffeine") for the selected molecule: the scenario
// manifest's completion scenario must expect an outcome (`ScenarioManifestValidator`), and choosing a molecule is what
// a session of this phase completes, as Solar System Explorer's `viewing-<body>` outcome is.
//
// The canvas description (FR-A15-131; clarification Q5) names the molecule, its formula, its atom and bond counts and
// its elements by name in Hill order, so no information depends on colour alone: "Molecular Explorer: Caffeine,
// C8H10N4O2; 24 atoms, 25 bonds; elements carbon, hydrogen, nitrogen, oxygen."
import Foundation
import MolecularExplorerCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Molecular Explorer's refusals.
public enum MoleculeRule {
    /// A molecule index that is not a whole index 0…4, or a step past the first or the last molecule.
    public static let invalidChoice = "a15.invalid-choice"
}

/// Why a stored Molecular Explorer state is refused.
public enum MoleculeRestoreError: Error, Equatable {
    /// `MoleculeState.decode(_:)` refused the payload, for the named reason.
    case refused(MoleculeStateRefusal)
}

/// The state of Molecular Explorer. Schema version 1.
public struct MoleculeCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a15.molecular-explorer"

    /// The action ids in declaration order.
    public static let actionIDs = ["molecule.select", "molecule.next", "molecule.previous"]

    /// The prefix of the outcome code; the selected molecule's id follows.
    public static let outcomePrefix = "viewing-"

    /// The library the selection refers to, in order: water, methane, ethanol, benzene, caffeine.
    public static var library: [Molecule] { MoleculeLibrary.molecules }

    /// The number of selectable molecules (5).
    public static var moleculeCount: Int { MoleculeState.moleculeCount }

    /// The preparation seed; `reset()` returns to the first state.
    public private(set) var preparationSeed: UInt64
    /// The whole saved state: the selected molecule.
    public private(set) var state: MoleculeState

    /// The first state (water selected) with `seed` as preparation seed.
    public init(seed: UInt64) {
        self.init(seed: seed, state: .initial)
    }

    /// A core holding `state`, prepared with `seed`.
    init(seed: UInt64, state: MoleculeState) {
        preparationSeed = seed
        self.state = state
    }

    /// The selected molecule's index, 0 (water) … 4 (caffeine).
    public var selection: Int { state.selection }
    /// The selected molecule; nil only if the library lacked the index (never for the bundled data).
    public var molecule: Molecule? { state.molecule }

    // MARK: Contract

    /// One quality tier (`level-0`): a handful of spheres has nothing to scale down in this phase.
    public static var qualityTiers: Int { 1 }

    /// Schema 1, no steps.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: MoleculeState.schemaVersion)
    }

    /// The three controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "molecule.select", ranges: [0...Double(moleculeCount - 1)]),
         ExperienceControl(id: "molecule.next"),
         ExperienceControl(id: "molecule.previous")]
    }

    /// The first state with `seed` as the preparation seed.
    public static func prepare(seed: UInt64) async throws -> MoleculeCore {
        try Task.checkCancellation()
        return MoleculeCore(seed: seed)
    }

    /// A host step changes nothing: nothing animates in this phase.
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action (see the file header); a refused action changes nothing.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        let expected = ["molecule.select": 1, "molecule.next": 0, "molecule.previous": 0][action.control]
        guard let expected else { return .rejected(.unknownControl(action.control)) }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        let refused = ActionResult.rejected(.rule(code: MoleculeRule.invalidChoice))
        var next = state
        switch action.control {
        case "molecule.select":
            guard let index = Self.choice(v[0], count: Self.moleculeCount), next.select(index) else { return refused }
        case "molecule.next":
            guard next.next() else { return refused }
        default:   // molecule.previous
            guard next.previous() else { return refused }
        }
        state = next
        return .accepted
    }

    /// The library index named by `value`: a finite whole number in `0..<count`; nil otherwise.
    static func choice(_ value: Double, count: Int) -> Int? {
        guard value.isFinite, value == value.rounded(), value >= 0, value < Double(count) else { return nil }
        return Int(value)
    }

    /// `viewing-<id>` of the selected molecule (see the file header).
    public var outcome: ExperienceOutcome? {
        ExperienceOutcome(code: Self.outcomePrefix + (molecule?.id ?? "unknown"))
    }

    /// Back to the first state.
    public mutating func reset() {
        self = MoleculeCore(seed: preparationSeed)
    }

    /// The canonical text of the state, then the selection and the selected molecule's id.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = String(data: state.encoded(), encoding: .utf8), !text.isEmpty else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a15.molecule.v1|" + text)
        builder.add(state.selection)
        builder.add(molecule?.id ?? "")
    }

    /// The state (schema 1) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        state.encoded()
    }

    /// The core of a schema-1 payload with the envelope's `seed` as preparation seed; a payload that
    /// `MoleculeState.decode(_:)` refuses (damaged, newer or out of range) throws ``MoleculeRestoreError/refused(_:)``.
    public static func restore(payload: Data, seed: UInt64) throws -> MoleculeCore {
        switch MoleculeState.decode(payload) {
        case .success(let state): return MoleculeCore(seed: seed, state: state)
        case .failure(let reason): throw MoleculeRestoreError.refused(reason)
        }
    }

    // MARK: Words

    /// The library molecule at `index`, or nil outside the library.
    public static func molecule(index: Int) -> Molecule? {
        library.indices.contains(index) ? library[index] : nil
    }

    /// The title of the molecule at `index` ("Caffeine"), or "Unknown molecule" outside the library.
    public static func title(index: Int) -> String {
        molecule(index: index)?.title ?? "Unknown molecule"
    }

    /// The element symbols of `molecule` in Hill order (carbon, hydrogen, then the others alphabetically; every
    /// symbol alphabetically without carbon), each once: the order of the formula.
    public static func hillSymbols(_ molecule: Molecule) -> [String] {
        let symbols = Set(molecule.atoms.map(\.symbol))
        guard symbols.contains("C") else { return symbols.sorted() }
        var order = ["C"]
        if symbols.contains("H") { order.append("H") }
        return order + symbols.filter { $0 != "C" && $0 != "H" }.sorted()
    }

    /// The lower-case element names of `molecule` in Hill order ("carbon, hydrogen, nitrogen, oxygen").
    public static func elementNames(_ molecule: Molecule) -> [String] {
        hillSymbols(molecule).map { Elements.element(symbol: $0)?.name.lowercased() ?? $0 }
    }

    /// `count` and the noun, singular for one ("1 atom", "24 atoms").
    static func counted(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    /// The name line: "Caffeine — C8H10N4O2" ("Unknown molecule" outside the library).
    public static func nameLine(index: Int) -> String {
        guard let molecule = molecule(index: index) else { return "Unknown molecule" }
        return "\(molecule.title) — \(molecule.formula)"
    }

    /// The counts line: "24 atoms, 25 bonds" (empty outside the library).
    public static func countsLine(index: Int) -> String {
        guard let molecule = molecule(index: index) else { return "" }
        return "\(counted(molecule.atoms.count, "atom")), \(counted(molecule.bonds.count, "bond"))"
    }

    /// The license in words: "public domain" for `public-domain`, "CC0 1.0" for `CC0-1.0`, "factual data" for
    /// `factual-data`, otherwise the license as stored.
    public static func licenseWords(_ license: String) -> String {
        switch license {
        case "public-domain": return "public domain"
        case "CC0-1.0": return "CC0 1.0"
        case "factual-data": return "factual data"
        default: return license
        }
    }

    /// The source line: "PubChem Compound CID 2519, 3D conformer — public domain" (empty outside the library).
    public static func sourceLine(index: Int) -> String {
        guard let molecule = molecule(index: index) else { return "" }
        return "\(molecule.source.title) — \(licenseWords(molecule.source.license))"
    }

    /// The status line: "Caffeine selected, molecule 5 of 5".
    public static func status(selection: Int) -> String {
        "\(title(index: selection)) selected, molecule \(selection + 1) of \(moleculeCount)"
    }

    /// The canvas description: "Molecular Explorer: Caffeine, C8H10N4O2; 24 atoms, 25 bonds; elements carbon,
    /// hydrogen, nitrogen, oxygen." ("Molecular Explorer: no molecule." outside the library).
    public static func canvasDescription(selection: Int) -> String {
        guard let molecule = molecule(index: selection) else { return "Molecular Explorer: no molecule." }
        let elements = elementNames(molecule).joined(separator: ", ")
        return "Molecular Explorer: \(molecule.title), \(molecule.formula); \(countsLine(index: selection)); "
            + "elements \(elements)."
    }

    /// The canvas description of this core.
    public var canvasDescription: String { Self.canvasDescription(selection: state.selection) }
}
