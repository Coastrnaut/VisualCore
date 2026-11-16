// MoleculeCore — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; contracts/domain.md) and feature 111
// (A15-P02) T-A15-205 (FR-A15-210, FR-A15-220, FR-A15-221; clarifications Q3, Q4; contracts/renderer.md). The state of
// Molecular Explorer as an experience: a `MoleculeState` at schema 2 (the selected molecule index, 0 = water … 4 =
// caffeine, into `MoleculeLibrary.molecules`; the display mode; the camera steps) and the preparation seed. Nothing
// animates: a host step (the default 1/120 s) changes nothing, so a suspension never changes the molecule or the view.
//
// Preparation: every preparation seed opens with water selected in ball-and-stick with the default camera
// (`MoleculeState.initial`); the seed is kept only as the envelope's preparation seed (`reset()` returns to the same
// first state). The library is fixed data, so nothing depends on the seed.
//
// Actions (all carried as numbers, as every experience action is; the engine refuses a value outside the declared
// range with `outOfRange`, a non-finite value with `nonFinite` and a wrong value count with `wrongValueCount` before
// the core sees it):
//   molecule.select [0…4]   the molecule by library index; a value that is not a whole index 0…4 is refused with
//                           `a15.invalid-choice`. The camera returns to the default; the mode stays.
//   molecule.next           the next molecule (refused with `a15.invalid-choice` at caffeine); camera as select.
//   molecule.previous       the previous molecule (refused with `a15.invalid-choice` at water); camera as select.
//   display.mode [0…1]      0 ball-and-stick, 1 space-filling; another value is refused with `a15.invalid-choice`.
//                           The molecule and the camera stay.
//   camera.orbit [−1…1]     turns by one 15° step (+1 right, −1 left), wrapping around; never refused at a limit; a
//                           value other than ±1 is refused with `a15.invalid-choice`.
//   camera.tilt [−1…1]      tilts by one 10° step within −80°…+80°; beyond is refused with `a15.camera-limit`, a value
//                           other than ±1 with `a15.invalid-choice`.
//   camera.zoom [−1…1]      +1 closer, −1 farther, steps −4…4; beyond is refused with `a15.camera-limit`, a value other
//                           than ±1 with `a15.invalid-choice`.
//   view.reset              the default camera (turn 30°, tilt 20°, zoom 0); the molecule and the mode stay.
// Called directly (not through the engine), the core refuses an unknown control with `unknownControl` and a wrong
// value count with `wrongValueCount`, as the engine does. A refusal changes nothing.
//
// Snapshot schema 2: `MoleculeState.encoded()` (JSON with sorted keys: camera {tilt, turn, zoom}, mode, schema,
// selection); the preparation seed and the schema version come from the snapshot envelope
// (`MigrationChain(currentVersion: 2)` with the step 1 → 2, which reads the schema-1 payload through
// `MoleculeState.decode(_:)` — ball-and-stick with the default camera, `MoleculeState.migrateV1(selection:)` — and
// writes it back as a schema-2 object; a newer envelope is refused by the engine). `restore` reads schema-2 payloads
// and schema-1 payloads alike; a payload `MoleculeState.decode(_:)` refuses (damaged, newer inside the payload or out
// of range) is refused (the restore, or the migration step, throws `MoleculeRestoreError`). One quality tier
// (`level-0`). The digest is the canonical text of the whole schema-2 state ("a15.molecule.v2|" and the state's JSON)
// followed by the selection, the selected molecule's id and the mode's name.
//
// The outcome is `viewing-<molecule id>` ("viewing-water", "viewing-caffeine") for the selected molecule: the scenario
// manifest's completion scenario must expect an outcome (`ScenarioManifestValidator`), and choosing a molecule is what
// a session completes, as Solar System Explorer's `viewing-<body>` outcome is. The mode and the camera do not change
// it.
//
// The canvas description (FR-A15-131; clarifications Q5 of feature 110 and Q4 of feature 111) names the molecule, its
// formula, its atom and bond counts, its elements by name in Hill order and the display mode, so no information
// depends on colour alone: "Molecular Explorer: Caffeine, C8H10N4O2; 24 atoms, 25 bonds; elements carbon, hydrogen,
// nitrogen, oxygen; ball-and-stick."
import Foundation
import MolecularExplorerCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Molecular Explorer's refusals.
public enum MoleculeRule {
    /// A molecule index that is not a whole index 0…4, or a step past the first or the last molecule.
    public static let invalidChoice = "a15.invalid-choice"
    /// A camera tilt beyond −80°…+80° or a zoom beyond −4…4 steps (feature 111, clarification Q3).
    public static let cameraLimit = "a15.camera-limit"
}

/// Why a stored Molecular Explorer state is refused.
public enum MoleculeRestoreError: Error, Equatable {
    /// `MoleculeState.decode(_:)` refused the payload, for the named reason.
    case refused(MoleculeStateRefusal)
}

/// The state of Molecular Explorer. Schema version 2.
public struct MoleculeCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a15.molecular-explorer"

    /// The action ids in declaration order.
    public static let actionIDs = ["molecule.select", "molecule.next", "molecule.previous", "display.mode",
                                   "camera.orbit", "camera.tilt", "camera.zoom", "view.reset"]

    /// The number of values each action carries, by action id.
    static let valueCounts: [String: Int] = ["molecule.select": 1, "molecule.next": 0, "molecule.previous": 0,
                                             "display.mode": 1, "camera.orbit": 1, "camera.tilt": 1,
                                             "camera.zoom": 1, "view.reset": 0]

    /// The prefix of the outcome code; the selected molecule's id follows.
    public static let outcomePrefix = "viewing-"

    /// The library the selection refers to, in order: water, methane, ethanol, benzene, caffeine.
    public static var library: [Molecule] { MoleculeLibrary.molecules }

    /// The number of selectable molecules (5).
    public static var moleculeCount: Int { MoleculeState.moleculeCount }

    /// The preparation seed; `reset()` returns to the first state.
    public private(set) var preparationSeed: UInt64
    /// The whole saved state: the selected molecule, the display mode and the camera.
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
    /// The display mode.
    public var mode: DisplayMode { state.mode }
    /// The camera steps.
    public var camera: CameraSettings { state.camera }

    // MARK: Contract

    /// One quality tier (`level-0`): 74 items at most (caffeine in ball-and-stick) have nothing to scale
    /// down.
    public static var qualityTiers: Int { 1 }

    /// Schema 2 with the step 1 → 2 (``migrateSchemaOne(_:)``: ball-and-stick and the default camera).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: MoleculeState.schemaVersion, steps: [1: { payload in
            try migrateSchemaOne(payload)
        }])
    }

    /// The schema-2 object of a schema-1 payload object: read through `MoleculeState.decode(_:)` (which migrates a
    /// schema-1 state with `MoleculeState.migrateV1(selection:)`) and written back as the schema-2 JSON object.
    /// Throws ``MoleculeRestoreError/refused(_:)`` for a payload whose schema is not 1 (`damaged`) or that the decode
    /// refuses.
    static func migrateSchemaOne(_ payload: [String: Any]) throws -> [String: Any] {
        guard (payload["schema"] as? Int) == 1,
              JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            throw MoleculeRestoreError.refused(.damaged)
        }
        switch MoleculeState.decode(data) {
        case .success(let state):
            guard let object = try? JSONSerialization.jsonObject(with: state.encoded()) as? [String: Any] else {
                throw MoleculeRestoreError.refused(.damaged)
            }
            return object
        case .failure(let reason):
            throw MoleculeRestoreError.refused(reason)
        }
    }

    /// The eight controls with their declared ranges.
    public static var controls: [ExperienceControl] {
        [ExperienceControl(id: "molecule.select", ranges: [0...Double(moleculeCount - 1)]),
         ExperienceControl(id: "molecule.next"),
         ExperienceControl(id: "molecule.previous"),
         ExperienceControl(id: "display.mode", ranges: [0...1]),
         ExperienceControl(id: "camera.orbit", ranges: [-1...1]),
         ExperienceControl(id: "camera.tilt", ranges: [-1...1]),
         ExperienceControl(id: "camera.zoom", ranges: [-1...1]),
         ExperienceControl(id: "view.reset")]
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
        guard let expected = Self.valueCounts[action.control] else {
            return .rejected(.unknownControl(action.control))
        }
        guard v.count == expected else { return .rejected(.wrongValueCount(expected: expected, found: v.count)) }
        let refused = ActionResult.rejected(.rule(code: MoleculeRule.invalidChoice))
        let limit = ActionResult.rejected(.rule(code: MoleculeRule.cameraLimit))
        var next = state
        switch action.control {
        case "molecule.select":
            guard let index = Self.choice(v[0], count: Self.moleculeCount), next.select(index) else { return refused }
        case "molecule.next":
            guard next.next() else { return refused }
        case "molecule.previous":
            guard next.previous() else { return refused }
        case "display.mode":
            guard let raw = Self.choice(v[0], count: DisplayMode.allCases.count),
                  let mode = DisplayMode(rawValue: raw) else { return refused }
            next.setMode(mode)
        case "view.reset":
            next.resetCamera()
        default:   // camera.orbit, camera.tilt, camera.zoom
            guard let step = Self.unitStep(v[0]) else { return refused }
            switch action.control {
            case "camera.orbit": next.turn(step)
            case "camera.tilt": guard next.tilt(step) else { return limit }
            default: guard next.zoom(step) else { return limit }
            }
        }
        state = next
        return .accepted
    }

    /// The camera step named by `value`: exactly −1 or +1; nil otherwise.
    static func unitStep(_ value: Double) -> Int? {
        value == 1 ? 1 : value == -1 ? -1 : nil
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

    /// The canonical text of the whole schema-2 state (selection, mode, camera), then the selection, the selected
    /// molecule's id and the mode's name.
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = String(data: state.encoded(), encoding: .utf8), !text.isEmpty else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a15.molecule.v2|" + text)
        builder.add(state.selection)
        builder.add(molecule?.id ?? "")
        builder.add(state.mode.name)
    }

    /// The state (schema 2) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        state.encoded()
    }

    /// The core of a schema-2 (or schema-1, migrated) payload with the envelope's `seed` as preparation seed; a payload
    /// that
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
    /// hydrogen, nitrogen, oxygen; ball-and-stick." ("Molecular Explorer: no molecule." outside the library).
    public static func canvasDescription(selection: Int, mode: DisplayMode = .ballAndStick) -> String {
        guard let molecule = molecule(index: selection) else { return "Molecular Explorer: no molecule." }
        let elements = elementNames(molecule).joined(separator: ", ")
        return "Molecular Explorer: \(molecule.title), \(molecule.formula); \(countsLine(index: selection)); "
            + "elements \(elements); \(mode.name)."
    }

    /// The canvas description of this core (its molecule and its mode).
    public var canvasDescription: String { Self.canvasDescription(selection: state.selection, mode: state.mode) }
}
