// MoleculeState — feature 110 (A15-P01) T-A15-105 (FR-A15-131; clarification Q5) and feature 111 (A15-P02) T-A15-204
// (FR-A15-221; clarification Q4; data-model "MoleculeState (schema 2)"; contracts/renderer.md). The saved state of
// Molecular Explorer at snapshot schema 2: the selected molecule index (0 = water … 4 = caffeine, an index into
// `MoleculeLibrary.molecules`), the display mode and the camera steps, kept apart from the molecule data. The initial
// state selects water in ball-and-stick with the default camera (turn 2, tilt 2, zoom 0).
//
// Written as JSON with sorted keys:
// `{"camera": {"tilt": <t>, "turn": <n>, "zoom": <z>}, "mode": <0|1>, "schema": 2, "selection": <index>}`.
// `decode(_:)` reads the schema first and refuses, in this order:
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, or a missing or non-integer key of that
//   schema (schema 1: `selection`; schema 2: `selection`, `mode` and the camera's `turn`, `tilt`, `zoom`);
// - `newer-version`: a schema above the current one (3 since feature 112, 4 since feature 114; whatever else the
//   payload holds);
// - `out-of-range`: a selection outside 0…4, a mode outside 0…1, or a camera step outside turn 0…23, tilt −8…8,
//   zoom −4…4.
// A schema-1 payload (`{"schema": 1, "selection": <index>}`) migrates to ball-and-stick with the default camera
// (`migrateV1(selection:)`). A refusal changes nothing; the caller opens `MoleculeState.initial`.
//
// `select(_:)` accepts a whole index 0…4; `next()` and `previous()` step by one and refuse a step past an end (next at
// caffeine, previous at water). Each returns false, with nothing changed, when refused; an accepted choice resets the
// camera to the default and keeps the mode (also when the same molecule is chosen again). `setMode(_:)` keeps the
// selection and the camera. `turn(_:)` wraps; `tilt(_:)` and `zoom(_:)` return false, with nothing changed, beyond their
// limits (the adapter maps that to `a15.camera-limit`); `resetCamera()` returns to the default camera.
//
// Feature 112 (A15-P03) T-A15-304 (FR-A15-311, FR-A15-330; clarification Q5; data-model "MoleculeState (schema 3)";
// contracts/selection.md): schema 3 adds the camera's pan and the selected atom (none, or an index 0…atoms − 1 of the
// selected molecule). Written as JSON with sorted keys:
// `{"atom": <index>, "camera": {"panX": <x>, "panY": <y>, "tilt": <t>, "turn": <n>, "zoom": <z>}, "mode": <0|1>,
// "schema": 3, "selection": <index>}`, with the `atom` key omitted when no atom is selected (so the JSON of a state
// is unique). `decode(_:)` now refuses `newer-version` above schema 3; a schema-3 payload is `damaged` when a key above
// (other than `atom`) is missing or not an integer, or `atom` is present and neither an integer nor null (null reads as
// none); it is `out-of-range` for an atom outside 0…atoms − 1 or a pan outside −10…10, besides the schema-2 checks.
// A schema-1 or schema-2 payload migrates with no selected atom and no pan (`migrateV1(selection:)`,
// `migrateV2(selection:mode:camera:)`); for the adapter's `MigrationChain`, `upgradePayload(_:from:)` turns a schema-1
// payload into the schema-2 JSON and a schema-2 payload into the schema-3 JSON, each checked like `decode(_:)`.
//
// `selectAtom(_:)` accepts an index below the selected molecule's atom count; `nextAtom()` selects atom 0 when none is
// selected and refuses at the last atom; `previousAtom()` selects the last atom when none is selected and refuses at
// atom 0; `clearAtom()` refuses when none is selected. Each returns false, with nothing changed, when refused (the
// adapter maps that to `a15.invalid-choice`). Choosing a molecule (`select`, `next`, `previous`) clears the selected
// atom and resets the camera, pan included, keeping the mode; `setMode(_:)` keeps the selected atom and the camera;
// `pan(dx:dy:)` follows `CameraSettings.pan(dx:dy:)`; `resetCamera()` also zeroes the pan and keeps the atom.
//
// Feature 114 (A15-P05) T-A15-502 (FR-A15-504, FR-A15-505; clarification Q1; data-model "MoleculeState schema 4";
// contracts/import.md): schema 4 adds the imported molecule and the import in progress. Written as JSON with sorted
// keys: `{"atom": <index>, "camera": {…}, "imported": {"atoms": [{"symbol": "O", "x": <x>, "y": <y>, "z": <z>}, …]},
// "mode": <0|1>, "pending": {"atoms": [ … ], "count": <n>}, "schema": 4, "selection": <index>}`, with `atom`,
// `imported` and `pending` each omitted when there is none (so the JSON of a state is unique; null reads as none). The
// selection is 0…5, where 5 (``MoleculeState/importedSelection``) is the imported molecule and is valid only with an
// import. `decode(_:)` now refuses `newer-version` above schema 4; a schema-4 payload is `damaged` when a schema-3 key
// is malformed or `imported` or `pending` is present and malformed (not an object, an atom without its symbol or a
// numeric coordinate, a count that is not an integer); it is `out-of-range`, besides the schema-3 checks, for a
// selection outside 0…5, a selection of 5 without an import, an imported atom list `ImportedMolecule.make(atoms:)`
// refuses, a pending count outside 1…500, more pending atoms than the count or a pending atom outside the limits. A
// schema-1, 2 or 3 payload migrates with neither an import nor a pending import; `upgradePayload(_:from:)` gains the
// step 3 → 4 (a schema-2 payload now becomes the schema-3 JSON, a schema-3 payload the schema-4 JSON).
//
// The import arrives as three mutating steps, which the adapter's `import.begin`, `import.atom` and `import.end`
// call:
// - `beginImport(count:)` starts a pending import of `count` atoms (1…500), dropping any earlier pending atoms;
// - `addImportedAtom(_:)` appends one atom to the pending import; refused with no pending import, when the count is
//   reached or for an atom outside the limits (``ImportedMolecule/refusal(for:)``);
// - `endImport()` refuses `bad-count` with no pending import and `count-mismatch` when fewer atoms than the count
//   arrived; otherwise it runs `ImportedMolecule.make(atoms:)` (the minimum distance and the bonds) and, on success,
//   stores the import (replacing an earlier one) and clears the pending import. It never selects the import (the
//   adapter sends `molecule.select [5]` next); when the import was already shown (selection 5) the selected atom is
//   cleared, since the molecule changed.
// Every refusal changes nothing. `molecule` is the imported molecule at selection 5. `moleculeCount` stays 5 (the
// library); `maxSelection` is 5 with an import and 4 without. `next()` and `previous()` stay within the library: both
// are refused at selection 5.
import Foundation

/// Why a saved Molecular Explorer state was refused.
public enum MoleculeStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing or malformed key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``MoleculeState/schemaVersion``).
    case newerVersion = "newer-version"
    /// A selection, mode, camera step, pan, atom or imported atom outside its range.
    case outOfRange = "out-of-range"
}

/// The state of a Molecular Explorer session: the selected molecule (a library molecule or the imported one), the
/// display mode, the camera, the selected atom, the imported molecule and the import in progress.
public struct MoleculeState: Codable, Equatable, Sendable {
    /// An import in progress: the atom count announced by `import.begin` and the atoms received so far (never shown).
    public struct PendingImport: Encodable, Equatable, Sendable {
        /// The number of atoms announced, 1…500.
        public let count: Int
        /// The atoms received so far, in file order (at most ``count``), symbols normalised.
        public fileprivate(set) var atoms: [Atom]

        /// Creates a pending import (no validation; ``MoleculeState/beginImport(count:)`` validates).
        init(count: Int, atoms: [Atom]) {
            self.count = count; self.atoms = atoms
        }
    }

    /// The snapshot schema this code writes (it also reads schemas 1, 2 and 3 and migrates them).
    public static let schemaVersion = 4
    /// The oldest schema this code reads.
    public static let oldestSchemaVersion = 1
    /// The number of library molecules (5).
    public static let moleculeCount = MoleculeLibraryData.records.count
    /// The selection of the imported molecule (5, just after the library).
    public static let importedSelection = moleculeCount
    /// Water selected, ball-and-stick, default camera.
    public static let initial = MoleculeState(selection: 0)

    /// The selected molecule index: 0…4 for the library, 5 (``importedSelection``) for the imported molecule.
    public private(set) var selection: Int
    /// The display mode.
    public private(set) var mode: DisplayMode
    /// The camera steps, pan included.
    public private(set) var camera: CameraSettings
    /// The selected atom's index in the selected molecule, or nil when none is selected.
    public private(set) var selectedAtom: Int?
    /// The imported molecule, or nil when nothing was imported (feature 114).
    public private(set) var imported: ImportedMolecule?
    /// The import in progress, or nil when none is (feature 114).
    public private(set) var pending: PendingImport?

    /// The state with library molecule `selection` (clamped into 0…4) selected, in `mode` with `camera` (made valid
    /// by ``CameraSettings/init(turnSteps:tiltSteps:zoomSteps:panX:panY:)``) and atom `selectedAtom` selected (none
    /// when it is not an atom index of that molecule); no import and no pending import.
    public init(selection: Int, mode: DisplayMode = .ballAndStick, camera: CameraSettings = .default,
                selectedAtom: Int? = nil) {
        self.selection = min(max(selection, 0), Self.moleculeCount - 1)
        self.mode = mode
        self.camera = CameraSettings(turnSteps: camera.turnSteps, tiltSteps: camera.tiltSteps,
                                     zoomSteps: camera.zoomSteps, panX: camera.panX, panY: camera.panY)
        self.selectedAtom = nil
        if let atom = selectedAtom, (0..<atomCount).contains(atom) { self.selectedAtom = atom }
    }

    /// The current state of a schema-1 `selection`: ball-and-stick with the default camera, no pan and no selected
    /// atom; nil outside 0…4.
    public static func migrateV1(selection: Int) -> MoleculeState? {
        guard (0..<moleculeCount).contains(selection) else { return nil }
        return MoleculeState(selection: selection, mode: .ballAndStick, camera: .default)
    }

    /// The current state of a schema-2 state's values: the same molecule, mode and turn, tilt and zoom, with no pan
    /// and no selected atom; nil when a value is outside its range.
    public static func migrateV2(selection: Int, mode: Int, camera: (turn: Int, tilt: Int, zoom: Int))
        -> MoleculeState? {
        guard (0..<moleculeCount).contains(selection), let displayMode = DisplayMode(rawValue: mode),
              CameraSettings.isValid(turn: camera.turn, tilt: camera.tilt, zoom: camera.zoom) else { return nil }
        return MoleculeState(selection: selection, mode: displayMode,
                             camera: CameraSettings(turnSteps: camera.turn, tiltSteps: camera.tilt,
                                                    zoomSteps: camera.zoom))
    }

    /// The number of atoms of the selected molecule (0 when there is no molecule).
    public var atomCount: Int { molecule?.atoms.count ?? 0 }

    /// The highest selection accepted now: 5 with an import, 4 without.
    public var maxSelection: Int { imported == nil ? Self.moleculeCount - 1 : Self.importedSelection }

    /// The selected molecule: the imported one at selection 5, else the library's; nil when the library failed to
    /// load it (never for the bundled data).
    public var molecule: Molecule? {
        if selection == Self.importedSelection { return imported?.molecule }
        return MoleculeLibrary.molecules.indices.contains(selection) ? MoleculeLibrary.molecules[selection] : nil
    }

    /// The scene of the selected molecule in the current mode, or nil when there is no molecule.
    public var scene: MoleculeScene? {
        molecule.map { MoleculeScene(molecule: $0, mode: mode) }
    }

    /// Selects molecule `index`, clears the selected atom and resets the camera and pan (the mode is kept); false,
    /// with nothing changed, for an index outside 0…``maxSelection`` (5 only with an import).
    @discardableResult
    public mutating func select(_ index: Int) -> Bool {
        guard (0...maxSelection).contains(index) else { return false }
        selection = index
        camera = .default
        selectedAtom = nil
        return true
    }

    /// Selects the next library molecule; false, with nothing changed, at the last one (caffeine) and at the
    /// imported molecule.
    @discardableResult
    public mutating func next() -> Bool { selection < Self.moleculeCount - 1 ? select(selection + 1) : false }

    /// Selects the previous library molecule; false, with nothing changed, at the first one (water) and at the
    /// imported molecule.
    @discardableResult
    public mutating func previous() -> Bool {
        selection > 0 && selection < Self.moleculeCount ? select(selection - 1) : false
    }

    /// Starts an import of `count` atoms, dropping any earlier pending atoms; false, with nothing changed, for a count
    /// outside 1…500. The shown molecule and the stored import are kept.
    @discardableResult
    public mutating func beginImport(count: Int) -> Bool {
        guard (1...Molecule.maxAtoms).contains(count) else { return false }
        pending = PendingImport(count: count, atoms: [])
        return true
    }

    /// Appends `atom` (symbol normalised) to the pending import; false, with nothing changed, with no pending import,
    /// when the announced count is reached, or for an atom outside the limits (``ImportedMolecule/refusal(for:)``).
    @discardableResult
    public mutating func addImportedAtom(_ atom: Atom) -> Bool {
        guard var current = pending, current.atoms.count < current.count, ImportedMolecule.refusal(for: atom) == nil,
              let element = Elements.element(symbol: atom.symbol) else { return false }
        current.atoms.append(Atom(symbol: element.symbol, x: atom.x, y: atom.y, z: atom.z))
        pending = current
        return true
    }

    /// Ends the pending import: `bad-count` with no pending import, `count-mismatch` when fewer atoms than announced
    /// arrived, else the result of ``ImportedMolecule/make(atoms:)``. On success the import is stored (replacing an
    /// earlier one) and the pending import cleared, the selection is kept (the selected atom is cleared when the
    /// import was shown); a refusal changes nothing.
    @discardableResult
    public mutating func endImport() -> Result<ImportedMolecule, XYZRefusal.Reason> {
        guard let current = pending else { return .failure(.badCount) }
        guard current.atoms.count == current.count else { return .failure(.countMismatch) }
        let made = ImportedMolecule.make(atoms: current.atoms)
        if case .success(let molecule) = made {
            imported = molecule
            pending = nil
            if selection == Self.importedSelection { selectedAtom = nil }
        }
        return made
    }

    /// Sets the display mode; the selection, the camera and the selected atom are kept.
    public mutating func setMode(_ mode: DisplayMode) {
        self.mode = mode
    }

    /// Turns the camera by `delta` steps, wrapping around; never refused.
    public mutating func turn(_ delta: Int) {
        camera.turn(delta)
    }

    /// Tilts the camera by `delta` steps; false, with nothing changed, beyond −8…8.
    @discardableResult
    public mutating func tilt(_ delta: Int) -> Bool {
        camera.tilt(delta)
    }

    /// Zooms the camera by `delta` steps; false, with nothing changed, beyond −4…4.
    @discardableResult
    public mutating func zoom(_ delta: Int) -> Bool {
        camera.zoom(delta)
    }

    /// Pans the camera by one step on each axis; false, with nothing changed, for values other than −1, 0, 1, for
    /// (0, 0) or beyond −10…10.
    @discardableResult
    public mutating func pan(dx: Int, dy: Int) -> Bool {
        camera.pan(dx: dx, dy: dy)
    }

    /// Returns the camera to the default (turn 2, tilt 2, zoom 0, pan 0, 0); the selected atom is kept.
    public mutating func resetCamera() {
        camera = .default
    }

    /// Selects atom `index` of the selected molecule; false, with nothing changed, for an index outside
    /// 0…atoms − 1.
    @discardableResult
    public mutating func selectAtom(_ index: Int) -> Bool {
        guard (0..<atomCount).contains(index) else { return false }
        selectedAtom = index
        return true
    }

    /// Selects the next atom (atom 0 when none is selected); false, with nothing changed, at the last atom.
    @discardableResult
    public mutating func nextAtom() -> Bool {
        guard let current = selectedAtom else { return selectAtom(0) }
        return current < atomCount - 1 ? selectAtom(current + 1) : false
    }

    /// Selects the previous atom (the last atom when none is selected); false, with nothing changed, at atom 0.
    @discardableResult
    public mutating func previousAtom() -> Bool {
        guard let current = selectedAtom else { return selectAtom(atomCount - 1) }
        return current > 0 ? selectAtom(current - 1) : false
    }

    /// Clears the selected atom; false when none is selected.
    @discardableResult
    public mutating func clearAtom() -> Bool {
        guard selectedAtom != nil else { return false }
        selectedAtom = nil
        return true
    }

    /// The coding keys.
    private enum CodingKeys: String, CodingKey { case schema, selection, mode, camera, atom, imported, pending }

    /// The raw camera steps of a schema-2 payload, checked after decoding.
    private struct RawCamera: Codable {
        /// The turn steps.
        var turn: Int
        /// The tilt steps.
        var tilt: Int
        /// The zoom steps.
        var zoom: Int
    }

    /// The raw camera steps of a schema-3 or schema-4 payload, pan included, checked after decoding.
    private struct RawCamera3: Codable {
        /// The turn steps.
        var turn: Int
        /// The tilt steps.
        var tilt: Int
        /// The zoom steps.
        var zoom: Int
        /// The horizontal pan steps.
        var panX: Int
        /// The vertical pan steps.
        var panY: Int
    }

    /// The whole schema-1 payload.
    private struct PayloadV1: Decodable {
        /// The schema (1).
        var schema: Int
        /// The molecule index.
        var selection: Int
    }

    /// The whole schema-2 payload (also written by ``upgradePayload(_:from:)`` for step 1 → 2).
    private struct PayloadV2: Codable {
        /// The schema (2).
        var schema: Int
        /// The molecule index.
        var selection: Int
        /// The display mode.
        var mode: Int
        /// The camera steps.
        var camera: RawCamera
    }

    /// The whole schema-3 payload (also written by ``upgradePayload(_:from:)`` for step 2 → 3; `atom` is omitted
    /// when nil).
    private struct PayloadV3: Codable {
        /// The schema (3).
        var schema: Int
        /// The molecule index.
        var selection: Int
        /// The display mode.
        var mode: Int
        /// The camera steps and pan.
        var camera: RawCamera3
        /// The selected atom, absent or null for none.
        var atom: Int?
    }

    /// The raw atoms of a schema-4 `imported` object, checked after decoding.
    private struct RawImported: Decodable {
        /// The atoms in file order.
        var atoms: [Atom]
    }

    /// The raw schema-4 `pending` object, checked after decoding.
    private struct RawPending: Decodable {
        /// The announced atom count.
        var count: Int
        /// The atoms so far.
        var atoms: [Atom]
    }

    /// The whole schema-4 payload.
    private struct PayloadV4: Decodable {
        /// The schema (4).
        var schema: Int
        /// The molecule index, 0…5.
        var selection: Int
        /// The display mode.
        var mode: Int
        /// The camera steps and pan.
        var camera: RawCamera3
        /// The selected atom, absent or null for none.
        var atom: Int?
        /// The imported molecule's atoms, absent or null for none.
        var imported: RawImported?
        /// The import in progress, absent or null for none.
        var pending: RawPending?
    }

    /// The state of a schema-2 payload, or `out-of-range`.
    private static func validated(_ payload: PayloadV2) -> Result<MoleculeState, MoleculeStateRefusal> {
        let camera = payload.camera
        guard let state = migrateV2(selection: payload.selection, mode: payload.mode,
                                    camera: (camera.turn, camera.tilt, camera.zoom)) else {
            return .failure(.outOfRange)
        }
        return .success(state)
    }

    /// The state of a schema-3 payload, or `out-of-range` when a value is outside its range.
    private static func validated(_ payload: PayloadV3) -> Result<MoleculeState, MoleculeStateRefusal> {
        let camera = payload.camera
        guard var state = migrateV2(selection: payload.selection, mode: payload.mode,
                                    camera: (camera.turn, camera.tilt, camera.zoom)),
              CameraSettings.panRange.contains(camera.panX), CameraSettings.panRange.contains(camera.panY) else {
            return .failure(.outOfRange)
        }
        state.camera.panX = camera.panX
        state.camera.panY = camera.panY
        if let atom = payload.atom {
            guard state.selectAtom(atom) else { return .failure(.outOfRange) }
        }
        return .success(state)
    }

    /// The pending import of a raw `pending` object, or nil when its count is outside 1…500, it holds more atoms than
    /// the count or an atom outside the limits.
    private static func validated(_ raw: RawPending) -> PendingImport? {
        guard (1...Molecule.maxAtoms).contains(raw.count), raw.atoms.count <= raw.count else { return nil }
        var pending = PendingImport(count: raw.count, atoms: [])
        for atom in raw.atoms {
            guard ImportedMolecule.refusal(for: atom) == nil, let element = Elements.element(symbol: atom.symbol) else {
                return nil
            }
            pending.atoms.append(Atom(symbol: element.symbol, x: atom.x, y: atom.y, z: atom.z))
        }
        return pending
    }

    /// The state of a schema-4 payload, or `out-of-range` when a value is outside its range (see the file header).
    private static func validated(_ payload: PayloadV4) -> Result<MoleculeState, MoleculeStateRefusal> {
        var imported: ImportedMolecule?
        if let raw = payload.imported {
            guard case .success(let molecule) = ImportedMolecule.make(atoms: raw.atoms) else {
                return .failure(.outOfRange)
            }
            imported = molecule
        }
        var pending: PendingImport?
        if let raw = payload.pending {
            guard let value = validated(raw) else { return .failure(.outOfRange) }
            pending = value
        }
        let isImported = payload.selection == importedSelection
        guard !isImported || imported != nil else { return .failure(.outOfRange) }
        let library = PayloadV3(schema: 3, selection: isImported ? 0 : payload.selection, mode: payload.mode,
                                camera: payload.camera, atom: nil)
        guard case .success(var state) = validated(library) else { return .failure(.outOfRange) }
        state.imported = imported
        state.pending = pending
        state.selection = payload.selection
        if let atom = payload.atom {
            guard state.selectAtom(atom) else { return .failure(.outOfRange) }
        }
        return .success(state)
    }

    /// Decodes a schema-4 state, or a schema-1, 2 or 3 state migrated; throws for another schema, a malformed key or
    /// a value outside its range.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        let selection = try c.decode(Int.self, forKey: .selection)
        let result: Result<MoleculeState, MoleculeStateRefusal>
        switch schema {
        case 1:
            result = Self.migrateV1(selection: selection).map { .success($0) } ?? .failure(.outOfRange)
        case 2:
            let payload = PayloadV2(schema: 2, selection: selection, mode: try c.decode(Int.self, forKey: .mode),
                                    camera: try c.decode(RawCamera.self, forKey: .camera))
            result = Self.validated(payload)
        case 3:
            let payload = PayloadV3(schema: 3, selection: selection, mode: try c.decode(Int.self, forKey: .mode),
                                    camera: try c.decode(RawCamera3.self, forKey: .camera),
                                    atom: try c.decodeIfPresent(Int.self, forKey: .atom))
            result = Self.validated(payload)
        case 4:
            let payload = PayloadV4(schema: 4, selection: selection, mode: try c.decode(Int.self, forKey: .mode),
                                    camera: try c.decode(RawCamera3.self, forKey: .camera),
                                    atom: try c.decodeIfPresent(Int.self, forKey: .atom),
                                    imported: try c.decodeIfPresent(RawImported.self, forKey: .imported),
                                    pending: try c.decodeIfPresent(RawPending.self, forKey: .pending))
            result = Self.validated(payload)
        default:
            result = .failure(schema > Self.schemaVersion ? .newerVersion : .damaged)
        }
        switch result {
        case .success(let state): self = state
        case .failure(let reason):
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: reason.rawValue)
        }
    }

    /// Encodes the state at the current schema (the keys of the file header; `atom`, `imported` and `pending` only
    /// when there is one).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(selection, forKey: .selection)
        try c.encode(mode.rawValue, forKey: .mode)
        try c.encode(camera, forKey: .camera)
        try c.encodeIfPresent(selectedAtom, forKey: .atom)
        try c.encodeIfPresent(imported, forKey: .imported)
        try c.encodeIfPresent(pending, forKey: .pending)
    }

    /// The JSON encoder with sorted keys used for every payload.
    private static func sortedEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    /// The state as JSON with sorted keys.
    public func encoded() -> Data {
        (try? Self.sortedEncoder().encode(self)) ?? Data()
    }

    /// The state in `data` (schema 4, or schema 1, 2 or 3 migrated), or the reason it is refused (see the file header
    /// for the order of the checks).
    public static func decode(_ data: Data) -> Result<MoleculeState, MoleculeStateRefusal> {
        /// The schema alone, read first.
        struct Header: Decodable { var schema: Int }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= oldestSchemaVersion else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        switch header.schema {
        case 1:
            guard let payload = try? decoder.decode(PayloadV1.self, from: data) else { return .failure(.damaged) }
            return migrateV1(selection: payload.selection).map { .success($0) } ?? .failure(.outOfRange)
        case 2:
            guard let payload = try? decoder.decode(PayloadV2.self, from: data) else { return .failure(.damaged) }
            return validated(payload)
        case 3:
            guard let payload = try? decoder.decode(PayloadV3.self, from: data) else { return .failure(.damaged) }
            return validated(payload)
        default:
            guard let payload = try? decoder.decode(PayloadV4.self, from: data) else { return .failure(.damaged) }
            return validated(payload)
        }
    }

    /// One migration step for the adapter's `MigrationChain`: a schema-1 payload (`version` 1) becomes the schema-2
    /// JSON `{"camera":{"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":2,"selection":<index>}`; a schema-2 payload
    /// (`version` 2) becomes the schema-3 JSON of the same state with no pan and no atom
    /// (`{"camera":{"panX":0,"panY":0,"tilt":…,"turn":…,"zoom":…},"mode":…,"schema":3,"selection":…}`); a schema-3
    /// payload (`version` 3) becomes the schema-4 JSON of the same state with no import and no pending import. The
    /// payload's own schema must equal `version` (else `damaged`); it is checked like ``decode(_:)`` and refused with
    /// the same reasons; any other `version` is `damaged`.
    public static func upgradePayload(_ data: Data, from version: Int) -> Result<Data, MoleculeStateRefusal> {
        /// The schema alone, read first.
        struct Header: Decodable { var schema: Int }
        guard (1...3).contains(version), let header = try? JSONDecoder().decode(Header.self, from: data),
              header.schema == version else { return .failure(.damaged) }
        switch decode(data) {
        case .failure(let reason):
            return .failure(reason)
        case .success(let state):
            let camera = state.camera
            let written: Data?
            switch version {
            case 1:
                let payload = PayloadV2(schema: 2, selection: state.selection, mode: state.mode.rawValue,
                                        camera: RawCamera(turn: camera.turnSteps, tilt: camera.tiltSteps,
                                                          zoom: camera.zoomSteps))
                written = try? sortedEncoder().encode(payload)
            case 2:
                let payload = PayloadV3(schema: 3, selection: state.selection, mode: state.mode.rawValue,
                                        camera: RawCamera3(turn: camera.turnSteps, tilt: camera.tiltSteps,
                                                           zoom: camera.zoomSteps, panX: camera.panX,
                                                           panY: camera.panY),
                                        atom: state.selectedAtom)
                written = try? sortedEncoder().encode(payload)
            default:
                written = state.encoded()
            }
            guard let result = written else { return .failure(.damaged) }
            return .success(result)
        }
    }
}
