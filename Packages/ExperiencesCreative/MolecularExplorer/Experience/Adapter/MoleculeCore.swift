// MoleculeCore — feature 110 (A15-P01) T-A15-106 (FR-A15-131; clarification Q5; contracts/domain.md) and feature 111
// (A15-P02) T-A15-205 (FR-A15-210, FR-A15-220, FR-A15-221; clarifications Q3, Q4; contracts/renderer.md). The state of
// Molecular Explorer as an experience: a `MoleculeState` (schema 3 since feature 112, below; the selected molecule
// index, 0 = water … 4 = caffeine, into `MoleculeLibrary.molecules`; the display mode; the camera steps) and the
// preparation seed. Nothing
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
// Snapshot schema 2 (feature 111; schema 3 and its chain since feature 112, below): `MoleculeState.encoded()` (JSON
// with sorted keys: camera {tilt, turn, zoom}, mode, schema, selection); the preparation seed and the schema version
// come from the snapshot envelope
// (`MigrationChain(currentVersion: 2)` with the step 1 → 2, which reads the schema-1 payload through
// `MoleculeState.decode(_:)` — ball-and-stick with the default camera, `MoleculeState.migrateV1(selection:)` — and
// writes it back as a schema-2 object; a newer envelope is refused by the engine). `restore` reads schema-2 payloads
// and schema-1 payloads alike; a payload `MoleculeState.decode(_:)` refuses (damaged, newer inside the payload or out
// of range) is refused (the restore, or the migration step, throws `MoleculeRestoreError`). One quality tier
// (`level-0`). The digest (until feature 112) was the canonical text of the whole schema-2 state ("a15.molecule.v2|"
// and the state's JSON) followed by the selection, the selected molecule's id and the mode's name.
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
//
// Feature 112 (A15-P03) T-A15-305 and T-A15-306 (FR-A15-301, FR-A15-302, FR-A15-310, FR-A15-311, FR-A15-322,
// FR-A15-330; clarifications Q1–Q3, Q5; contracts/selection.md). The state is a `MoleculeState` at schema 3: the pan
// steps and the selected atom join it. Five actions are added:
//   camera.pan [−1…1, −1…1]   one pan step on each axis (dx, dy); each value must be exactly −1, 0 or 1 and not both
//                           0, else `a15.invalid-choice`; a step beyond −10…10 on either axis is refused with
//                           `a15.camera-limit`. Positive dx moves the camera's target to the view's right (the
//                           molecule appears to move left), positive dy moves it up (the molecule appears to move
//                           down).
//   atom.select [0…499]     the atom by index in the selected molecule; a value that is not a whole index below the
//                           molecule's atom count is refused with `a15.invalid-choice`.
//   atom.next               the next atom (atom 1 when none is selected); refused with `a15.invalid-choice` at the
//                           last.
//   atom.previous           the previous atom (the last atom when none is selected); refused with `a15.invalid-choice`
//                           at atom 1.
//   atom.clear              clears the selected atom; refused with `a15.invalid-choice` when none is selected.
// Choosing a molecule clears the selected atom and resets the camera, pan included; changing the mode keeps both; Reset
// view zeroes the pan and keeps the atom. Snapshot schema 3 (`MigrationChain(currentVersion: 3)`, steps 1 → 2 and
// 2 → 3, each through `MoleculeState.upgradePayload(_:from:)`; a refusal throws `MoleculeRestoreError`). The digest
// is the canonical text of the whole schema-3 state ("a15.molecule.v3|" and the state's JSON, which carries the pan and
// the atom) followed by the selection, the selected molecule's id, the mode's name and the selected atom (−1 for none).
// When an atom is selected the canvas description ends, after the mode, with "; selected <element name in lower case>,
// atom <1-based index>": "…; ball-and-stick; selected nitrogen, atom 3."
//
// Feature 114 (A15-P05) T-A15-505 (FR-A15-504, FR-A15-505; clarification Q1; contracts/import.md). The state is a
// `MoleculeState` at schema 4: the imported molecule (and the atoms of an import in progress) join it. Three actions
// are added and `molecule.select` ranges 0…5:
//   import.begin [1…500]    starts an import of that many atoms, dropping the atoms of an earlier unfinished import (a
//                           begin while an import is pending restarts it); a value that is not a whole count 1…500 is
//                           refused with `a15.invalid-import`. The shown molecule and the stored import stay.
//   import.atom [Z, x, y, z] one atom of the pending import: Z one of the atomic numbers 1, 6, 7, 8, 9, 15, 16, 17, 35,
//                           53 (declared 1…53; another whole or fractional value is refused), x, y, z in ångström
//                           within −1,000…1,000 (declared so; the engine refuses beyond). Refused with
//                           `a15.invalid-import` without a pending import, once the announced count is reached, or for
//                           an atom outside the limits.
//   import.end []           re-checks the count and every limit (`ImportedMolecule.make(atoms:)`: elements, finite,
//                           magnitude, 0.4 Å minimum distance), infers the bonds and stores the imported molecule,
//                           replacing an earlier one; refused with `a15.invalid-import` without a pending import, with
//                           fewer atoms than announced or for atoms the rule refuses. It does not select: the file's
//                           actions end with `molecule.select [5]`.
//   molecule.select [5]     the imported molecule, refused with `a15.invalid-choice` while there is none;
//                           `molecule.next` and `molecule.previous` stay within the five library molecules (both are
//                           refused at the imported molecule).
// A refusal changes nothing, so an interrupted import never changes the shown molecule. Snapshot schema 4
// (`MigrationChain(currentVersion: 4)`, steps 1 → 2, 2 → 3 and 3 → 4, each through `MoleculeState.upgradePayload`;
// schemas 1–3 migrate with no import). The digest keeps its layout and its "a15.molecule.v3|" prefix: the state's JSON
// (now schema 4, with the import when there is one) followed by the selection, the selected molecule's id, the mode's
// name and the selected atom, so the digests of the standard scenarios change only through the schema number. The
// outcome of the imported molecule is `viewing-imported`. The words of the imported molecule come from the state:
// the name line "Imported molecule — C2H6O", the counts of its atoms and inferred bonds and the source line "imported
// file — your own data" (the presenter puts the file's title in place of "Imported molecule"); the status reads
// "Imported molecule selected, molecule 6 of 6".
//
// Feature 115 (A15-P06) T-A15-606 (FR-A15-612; clarification Q5): `schemaOneExample()`, `schemaTwoExample()` and
// `schemaThreeExample()` are stored payloads of schemas 1, 2 and 3 (caffeine; then space-filling with a moved camera;
// then a pan and atom 3) in envelopes of their schema, each with the digest its migration to schema 4 and restore
// give, for the registry's `SnapshotMigrationCheck`.
import Foundation
import MolecularExplorerCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The rule codes of Molecular Explorer's refusals.
public enum MoleculeRule {
    /// A molecule index that is not a whole index 0…4, a step past the first or the last molecule, a pan value other
    /// than −1, 0, 1 (or both 0), an atom index outside the molecule, a step past the first or the last atom, or a
    /// clear with no atom selected (feature 112).
    public static let invalidChoice = "a15.invalid-choice"
    /// A camera tilt beyond −80°…+80°, a zoom beyond −4…4 steps (feature 111, clarification Q3) or a pan beyond −10…10
    /// steps (feature 112, clarification Q2).
    public static let cameraLimit = "a15.camera-limit"
    /// An import action the engine state refuses: an atom or an end without a begin, a count outside 1…500, an atomic
    /// number outside the ten supported elements, an atom beyond the limits, a wrong count at the end or atoms closer
    /// than 0.4 Å (feature 114, clarification Q1).
    public static let invalidImport = "a15.invalid-import"
}

/// Why a stored Molecular Explorer state is refused.
public enum MoleculeRestoreError: Error, Equatable {
    /// `MoleculeState.decode(_:)` refused the payload, for the named reason.
    case refused(MoleculeStateRefusal)
}

/// The state of Molecular Explorer. Schema version 4 (feature 114: the imported molecule joins the state).
public struct MoleculeCore: ExperienceCore, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a15.molecular-explorer"

    /// The action ids in declaration order.
    public static let actionIDs = ["molecule.select", "molecule.next", "molecule.previous", "display.mode",
                                   "camera.orbit", "camera.tilt", "camera.zoom", "view.reset", "camera.pan",
                                   "atom.select", "atom.next", "atom.previous", "atom.clear", "import.begin",
                                   "import.atom", "import.end"]

    /// The number of values each action carries, by action id.
    static let valueCounts: [String: Int] = ["molecule.select": 1, "molecule.next": 0, "molecule.previous": 0,
                                             "display.mode": 1, "camera.orbit": 1, "camera.tilt": 1,
                                             "camera.zoom": 1, "view.reset": 0, "camera.pan": 2,
                                             "atom.select": 1, "atom.next": 0, "atom.previous": 0, "atom.clear": 0,
                                             "import.begin": 1, "import.atom": 4, "import.end": 0]

    /// The prefix of the outcome code; the selected molecule's id follows.
    public static let outcomePrefix = "viewing-"

    /// The library the selection refers to, in order: water, methane, ethanol, benzene, caffeine.
    public static var library: [Molecule] { MoleculeLibrary.molecules }

    /// The number of library molecules (5).
    public static var moleculeCount: Int { MoleculeState.moleculeCount }

    /// The selection of the imported molecule (5, after the five library molecules; feature 114).
    public static var importedSelection: Int { MoleculeState.importedSelection }

    /// The highest atomic number `import.atom` declares (iodine, 53); only ``ImportedMolecule/atomicNumbers`` are
    /// accepted (feature 114).
    public static let maxAtomicNumber = 53

    /// The coordinate magnitude `import.atom` declares, ångström (feature 114).
    public static let maxImportCoordinate = Molecule.maxCoordinate

    /// The preparation seed; `reset()` returns to the first state.
    public private(set) var preparationSeed: UInt64
    /// The whole saved state: the selected molecule, the display mode, the camera (pan included) and the selected
    /// atom.
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
    /// The selected atom's index in the selected molecule, or nil when none is selected (feature 112).
    public var selectedAtom: Int? { state.selectedAtom }
    /// The imported molecule, or nil when there is none (feature 114).
    public var imported: ImportedMolecule? { state.imported }

    // MARK: Contract

    /// One quality tier (`level-0`): 82 items at most (caffeine in ball-and-stick: 24 atoms and 58 sticks) have
    /// nothing to scale down.
    public static var qualityTiers: Int { 1 }

    /// Schema 4 with the steps 1 → 2, 2 → 3 and 3 → 4 (``migrateSchema(_:from:)``: each through
    /// `MoleculeState.upgradePayload(_:from:)`; a schema-1 state opens in ball-and-stick with the default camera, a
    /// schema-2 state keeps its molecule, mode and camera; neither has a pan or a selected atom; a schema-3 state keeps
    /// everything and has no import).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: MoleculeState.schemaVersion, steps: [
            1: { payload in try migrateSchema(payload, from: 1) },
            2: { payload in try migrateSchema(payload, from: 2) },
            3: { payload in try migrateSchema(payload, from: 3) },
        ])
    }

    /// The next schema's object of a payload object of schema `version` (1, 2 or 3): serialised with sorted keys,
    /// upgraded by `MoleculeState.upgradePayload(_:from:)` and read back as a JSON object. Throws
    /// ``MoleculeRestoreError/refused(_:)`` with the upgrade's reason (`damaged` for a payload whose schema is not
    /// `version` or that is not a JSON object).
    static func migrateSchema(_ payload: [String: Any], from version: Int) throws -> [String: Any] {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            throw MoleculeRestoreError.refused(.damaged)
        }
        switch MoleculeState.upgradePayload(data, from: version) {
        case .success(let upgraded):
            guard let object = try? JSONSerialization.jsonObject(with: upgraded) as? [String: Any] else {
                throw MoleculeRestoreError.refused(.damaged)
            }
            return object
        case .failure(let reason):
            throw MoleculeRestoreError.refused(reason)
        }
    }

    /// The schema-2 object of a schema-1 payload object (``migrateSchema(_:from:)`` from 1).
    static func migrateSchemaOne(_ payload: [String: Any]) throws -> [String: Any] {
        try migrateSchema(payload, from: 1)
    }

    /// The highest atom index `atom.select` declares (a molecule holds at most 500 atoms).
    public static let maxAtomIndex = Molecule.maxAtoms - 1

    /// The sixteen controls with their declared ranges (`molecule.select` 0…5 and the three import actions since
    /// feature 114).
    public static var controls: [ExperienceControl] {
        let coordinate = -maxImportCoordinate...maxImportCoordinate
        return [ExperienceControl(id: "molecule.select", ranges: [0...Double(importedSelection)]),
                ExperienceControl(id: "molecule.next"),
                ExperienceControl(id: "molecule.previous"),
                ExperienceControl(id: "display.mode", ranges: [0...1]),
                ExperienceControl(id: "camera.orbit", ranges: [-1...1]),
                ExperienceControl(id: "camera.tilt", ranges: [-1...1]),
                ExperienceControl(id: "camera.zoom", ranges: [-1...1]),
                ExperienceControl(id: "view.reset"),
                ExperienceControl(id: "camera.pan", ranges: [-1...1, -1...1]),
                ExperienceControl(id: "atom.select", ranges: [0...Double(maxAtomIndex)]),
                ExperienceControl(id: "atom.next"),
                ExperienceControl(id: "atom.previous"),
                ExperienceControl(id: "atom.clear"),
                ExperienceControl(id: "import.begin", ranges: [1...Double(Molecule.maxAtoms)]),
                ExperienceControl(id: "import.atom",
                                  ranges: [1...Double(maxAtomicNumber), coordinate, coordinate, coordinate]),
                ExperienceControl(id: "import.end")]
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
        let importRefused = ActionResult.rejected(.rule(code: MoleculeRule.invalidImport))
        var next = state
        switch action.control {
        case "molecule.select":
            guard let index = Self.choice(v[0], count: Self.importedSelection + 1), next.select(index) else {
                return refused
            }
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
        case "camera.pan":
            guard let dx = Self.panStep(v[0]), let dy = Self.panStep(v[1]), dx != 0 || dy != 0 else { return refused }
            guard next.pan(dx: dx, dy: dy) else { return limit }
        case "atom.select":
            guard let index = Self.choice(v[0], count: next.atomCount), next.selectAtom(index) else { return refused }
        case "atom.next":
            guard next.nextAtom() else { return refused }
        case "atom.previous":
            guard next.previousAtom() else { return refused }
        case "atom.clear":
            guard next.clearAtom() else { return refused }
        case "import.begin":
            guard let count = Self.choice(v[0], count: Molecule.maxAtoms + 1), next.beginImport(count: count) else {
                return importRefused
            }
        case "import.atom":
            guard let atom = Self.importedAtom(v), next.addImportedAtom(atom) else { return importRefused }
        case "import.end":
            guard case .success = next.endImport() else { return importRefused }
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

    /// The pan step named by `value`: exactly −1, 0 or +1; nil otherwise (feature 112).
    static func panStep(_ value: Double) -> Int? {
        value == 1 ? 1 : value == -1 ? -1 : value == 0 ? 0 : nil
    }

    /// The atom of the values of `import.atom` (Z, x, y, z): Z a whole atomic number of
    /// ``ImportedMolecule/atomicNumbers`` and x, y, z finite within ±1,000 Å; nil otherwise (feature 114).
    static func importedAtom(_ values: [Double]) -> Atom? {
        guard values.count == 4, let number = choice(values[0], count: maxAtomicNumber + 1),
              ImportedMolecule.atomicNumbers.contains(number) else { return nil }
        for value in values[1...] where !value.isFinite || abs(value) > maxImportCoordinate { return nil }
        return ImportedMolecule.atom(atomicNumber: number, x: values[1], y: values[2], z: values[3])
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

    /// The canonical text of the whole state (schema 4: selection, mode, camera with the pan, selected atom, the import
    /// and the pending import; the "a15.molecule.v3|" prefix is kept, see the file header), then the selection, the
    /// selected molecule's id, the mode's name and the selected atom (−1 for none).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        guard let text = String(data: state.encoded(), encoding: .utf8), !text.isEmpty else {
            throw .nonFinite(field: builder.fieldCount)
        }
        builder.add("a15.molecule.v3|" + text)
        builder.add(state.selection)
        builder.add(molecule?.id ?? "")
        builder.add(state.mode.name)
        builder.add(state.selectedAtom ?? -1)
    }

    /// The state (schema 4) as JSON with sorted keys.
    public func snapshotPayload() throws -> Data {
        state.encoded()
    }

    /// The core of a schema-4 (or schema-1, 2 or 3, migrated) payload with the envelope's `seed` as preparation
    /// seed; a payload that `MoleculeState.decode(_:)` refuses (damaged, newer or out of range) throws
    /// ``MoleculeRestoreError/refused(_:)``.
    public static func restore(payload: Data, seed: UInt64) throws -> MoleculeCore {
        switch MoleculeState.decode(payload) {
        case .success(let state): return MoleculeCore(seed: seed, state: state)
        case .failure(let reason): throw MoleculeRestoreError.refused(reason)
        }
    }

    // MARK: Stored migration examples (A15-P06)

    /// The stored payload of schema `version` (1, 2 or 3) for the registry's migration check (feature 115,
    /// T-A15-606): schema 1 selects caffeine; schema 2 also chooses space-filling and moves the camera (turn 5, tilt 3,
    /// zoom 1); schema 3 also pans the camera (2, −1) and selects atom 3. Nil for another version.
    public static func schemaExamplePayload(version: Int) -> [String: Any]? {
        guard (1...3).contains(version) else { return nil }
        var payload: [String: Any] = ["schema": version, "selection": 4]
        if version == 2 {
            payload["mode"] = DisplayMode.spaceFilling.rawValue
            payload["camera"] = ["turn": 5, "tilt": 3, "zoom": 1]
        }
        if version == 3 {
            payload["mode"] = DisplayMode.spaceFilling.rawValue
            payload["camera"] = ["turn": 5, "tilt": 3, "zoom": 1, "panX": 2, "panY": -1]
            payload["atom"] = 3
        }
        return payload
    }

    /// The stored example of schema `version` for the registry's migration check: ``schemaExamplePayload(version:)``
    /// in an envelope of that schema at step 0 with seed `seed`, with the digest its restore through the migration
    /// chain to schema 4 gives (computed here by running ``migrations`` and ``restore(payload:seed:)``, as Solar System
    /// Explorer does). Nil for another version or if the encoding, the migration or the restore failed.
    public static func schemaExample(version: Int, seed: UInt64 = 7) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID), let payload = schemaExamplePayload(version: version),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let upgraded = try? migrations.migrate(payload, from: version),
              let migrated = try? JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]),
              let restored = try? restore(payload: migrated, seed: seed) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? restored.writeDigest(into: &builder)) != nil else { return nil }
        let digest = builder.finish()
        guard let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: version, seed: seed, stepIndex: 0,
                                                     digest: digest, payload: data),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: version, snapshot: encoded, expectedDigest: digest.hex)
    }

    /// The stored schema-1 example (A15-P01 state: the selection only).
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? { schemaExample(version: 1, seed: seed) }
    /// The stored schema-2 example (A15-P02 state: the display mode and the camera).
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample? { schemaExample(version: 2, seed: seed) }
    /// The stored schema-3 example (A15-P03 state: the pan and the selected atom).
    public static func schemaThreeExample(seed: UInt64 = 7) -> MigrationExample? {
        schemaExample(version: 3, seed: seed)
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
        return nameLine(molecule)
    }

    /// The name line of `molecule` with `title` in place of its own title when given: "Caffeine — C8H10N4O2",
    /// "water-copy — H2O" (feature 114).
    public static func nameLine(_ molecule: Molecule, title: String? = nil) -> String {
        "\(title ?? molecule.title) — \(molecule.formula)"
    }

    /// The counts line: "24 atoms, 25 bonds" (empty outside the library).
    public static func countsLine(index: Int) -> String {
        guard let molecule = molecule(index: index) else { return "" }
        return countsLine(molecule)
    }

    /// The counts line of `molecule`: "24 atoms, 25 bonds" (feature 114).
    public static func countsLine(_ molecule: Molecule) -> String {
        "\(counted(molecule.atoms.count, "atom")), \(counted(molecule.bonds.count, "bond"))"
    }

    /// The license in words: "public domain" for `public-domain`, "CC0 1.0" for `CC0-1.0`, "factual data" for
    /// `factual-data`, "your own data" for `own-data` (feature 114), otherwise the license as stored.
    public static func licenseWords(_ license: String) -> String {
        switch license {
        case "public-domain": return "public domain"
        case "CC0-1.0": return "CC0 1.0"
        case "factual-data": return "factual data"
        case SourceRecord.ownDataLicense: return "your own data"
        default: return license
        }
    }

    /// The source line: "PubChem Compound CID 2519, 3D conformer — public domain" (empty outside the library).
    public static func sourceLine(index: Int) -> String {
        guard let molecule = molecule(index: index) else { return "" }
        return sourceLine(molecule)
    }

    /// The source line of `molecule`: "PubChem Compound CID 2519, 3D conformer — public domain", "imported file — your
    /// own data" (feature 114).
    public static func sourceLine(_ molecule: Molecule) -> String {
        "\(molecule.source.title) — \(licenseWords(molecule.source.license))"
    }

    /// The status line: "Caffeine selected, molecule 5 of 5".
    public static func status(selection: Int) -> String {
        status(title: title(index: selection), selection: selection)
    }

    /// The status line of the molecule `title` at `selection`: "Caffeine selected, molecule 5 of 5" in the library,
    /// "water-copy selected, molecule 6 of 6" for the imported molecule (feature 114).
    public static func status(title: String, selection: Int) -> String {
        let count = selection == importedSelection ? importedSelection + 1 : moleculeCount
        return "\(title) selected, molecule \(selection + 1) of \(count)"
    }

    /// The title of the selected molecule: the library title, "Imported molecule" for the import, "Unknown molecule"
    /// without a molecule (feature 114).
    public var title: String { molecule?.title ?? "Unknown molecule" }

    /// The name line of the selected molecule, with `title` in place of its own when given ("Unknown molecule"
    /// without a molecule; feature 114).
    public func nameLine(title: String? = nil) -> String {
        guard let molecule else { return "Unknown molecule" }
        return Self.nameLine(molecule, title: title)
    }

    /// The counts line of the selected molecule (empty without a molecule; feature 114).
    public var countsLine: String { molecule.map { Self.countsLine($0) } ?? "" }

    /// The source line of the selected molecule (empty without a molecule; feature 114).
    public var sourceLine: String { molecule.map { Self.sourceLine($0) } ?? "" }

    /// The status line of the selected molecule, with `title` in place of its own when given (feature 114).
    public func status(title: String? = nil) -> String {
        Self.status(title: title ?? self.title, selection: selection)
    }

    /// The lower-case element name of atom `atom` of `molecule` ("nitrogen"; the symbol outside the catalog), or nil
    /// when `atom` is not an atom index of it (feature 112).
    public static func atomElementName(_ molecule: Molecule, atom: Int) -> String? {
        guard molecule.atoms.indices.contains(atom) else { return nil }
        let symbol = molecule.atoms[atom].symbol
        return Elements.element(symbol: symbol)?.name.lowercased() ?? symbol
    }

    /// The canvas description: "Molecular Explorer: Caffeine, C8H10N4O2; 24 atoms, 25 bonds; elements carbon,
    /// hydrogen, nitrogen, oxygen; ball-and-stick." ("Molecular Explorer: no molecule." outside the library); with
    /// atom `atom` selected (feature 112) it ends "…; ball-and-stick; selected nitrogen, atom 3." (an index outside
    /// the molecule adds nothing).
    public static func canvasDescription(selection: Int, mode: DisplayMode = .ballAndStick, atom: Int? = nil)
        -> String {
        canvasDescription(molecule: molecule(index: selection), mode: mode, atom: atom)
    }

    /// The canvas description of `molecule` (any molecule, the imported one included; feature 114) in `mode` with
    /// atom `atom` selected, named `title` when given (else by its own title); "Molecular Explorer: no molecule." for
    /// nil.
    public static func canvasDescription(molecule: Molecule?, mode: DisplayMode = .ballAndStick, atom: Int? = nil,
                                         title: String? = nil) -> String {
        guard let molecule else { return "Molecular Explorer: no molecule." }
        let elements = elementNames(molecule).joined(separator: ", ")
        var selected = ""
        if let atom, let name = atomElementName(molecule, atom: atom) {
            selected = "; selected \(name), atom \(atom + 1)"
        }
        return "Molecular Explorer: \(title ?? molecule.title), \(molecule.formula); \(countsLine(molecule)); "
            + "elements \(elements); \(mode.name)\(selected)."
    }

    /// The canvas description of this core (its molecule, the imported one included, its mode and its selected atom).
    public var canvasDescription: String {
        titledCanvasDescription(nil)
    }

    /// The canvas description of this core with `title` in place of the molecule's own title when given (the
    /// presenter passes the imported file's title; feature 114).
    public func titledCanvasDescription(_ title: String?) -> String {
        Self.canvasDescription(molecule: state.molecule, mode: state.mode, atom: state.selectedAtom, title: title)
    }
}
