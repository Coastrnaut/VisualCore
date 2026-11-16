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
// - `newer-version`: a schema above 2 (whatever else the payload holds);
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
import Foundation

/// Why a saved Molecular Explorer state was refused.
public enum MoleculeStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing or malformed key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``MoleculeState/schemaVersion``).
    case newerVersion = "newer-version"
    /// A selection, mode or camera step outside its range.
    case outOfRange = "out-of-range"
}

/// The state of a Molecular Explorer session: the selected library molecule, the display mode and the camera.
public struct MoleculeState: Codable, Equatable, Sendable {
    /// The snapshot schema this code writes (it also reads schema 1 and migrates it).
    public static let schemaVersion = 2
    /// The oldest schema this code reads.
    public static let oldestSchemaVersion = 1
    /// The number of selectable molecules (5).
    public static let moleculeCount = MoleculeLibraryData.records.count
    /// Water selected, ball-and-stick, default camera.
    public static let initial = MoleculeState(selection: 0)

    /// The selected molecule index, 0…4.
    public private(set) var selection: Int
    /// The display mode.
    public private(set) var mode: DisplayMode
    /// The camera steps.
    public private(set) var camera: CameraSettings

    /// The state with molecule `selection` (clamped into 0…4) selected, in `mode` with `camera` (made valid by
    /// ``CameraSettings/init(turnSteps:tiltSteps:zoomSteps:)``).
    public init(selection: Int, mode: DisplayMode = .ballAndStick, camera: CameraSettings = .default) {
        self.selection = min(max(selection, 0), Self.moleculeCount - 1)
        self.mode = mode
        self.camera = CameraSettings(turnSteps: camera.turnSteps, tiltSteps: camera.tiltSteps,
                                     zoomSteps: camera.zoomSteps)
    }

    /// The schema-2 state of a schema-1 `selection`: ball-and-stick with the default camera; nil outside 0…4.
    public static func migrateV1(selection: Int) -> MoleculeState? {
        guard (0..<moleculeCount).contains(selection) else { return nil }
        return MoleculeState(selection: selection, mode: .ballAndStick, camera: .default)
    }

    /// The selected molecule, or nil when the library failed to load it (never for the bundled data).
    public var molecule: Molecule? {
        MoleculeLibrary.molecules.indices.contains(selection) ? MoleculeLibrary.molecules[selection] : nil
    }

    /// The scene of the selected molecule in the current mode, or nil when there is no molecule.
    public var scene: MoleculeScene? {
        molecule.map { MoleculeScene(molecule: $0, mode: mode) }
    }

    /// Selects molecule `index` and resets the camera (the mode is kept); false, with nothing changed, for an index
    /// outside 0…4.
    @discardableResult
    public mutating func select(_ index: Int) -> Bool {
        guard (0..<Self.moleculeCount).contains(index) else { return false }
        selection = index
        camera = .default
        return true
    }

    /// Selects the next molecule; false, with nothing changed, at the last molecule (caffeine).
    @discardableResult
    public mutating func next() -> Bool { selection < Self.moleculeCount - 1 ? select(selection + 1) : false }

    /// Selects the previous molecule; false, with nothing changed, at the first molecule (water).
    @discardableResult
    public mutating func previous() -> Bool { selection > 0 ? select(selection - 1) : false }

    /// Sets the display mode; the selection and the camera are kept.
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

    /// Returns the camera to the default (turn 2, tilt 2, zoom 0).
    public mutating func resetCamera() {
        camera = .default
    }

    /// The coding keys.
    private enum CodingKeys: String, CodingKey { case schema, selection, mode, camera }

    /// The raw camera steps of a payload, checked after decoding.
    private struct RawCamera: Decodable {
        /// The turn steps.
        var turn: Int
        /// The tilt steps.
        var tilt: Int
        /// The zoom steps.
        var zoom: Int
    }

    /// The state from raw values, or `out-of-range` when one is outside its range.
    private static func validated(selection: Int, mode: Int, camera: RawCamera)
        -> Result<MoleculeState, MoleculeStateRefusal> {
        guard (0..<moleculeCount).contains(selection), let displayMode = DisplayMode(rawValue: mode),
              CameraSettings.isValid(turn: camera.turn, tilt: camera.tilt, zoom: camera.zoom) else {
            return .failure(.outOfRange)
        }
        return .success(MoleculeState(selection: selection, mode: displayMode,
                                      camera: CameraSettings(turnSteps: camera.turn, tiltSteps: camera.tilt,
                                                             zoomSteps: camera.zoom)))
    }

    /// Decodes a schema-2 state, or a schema-1 state migrated; throws for another schema, a malformed key or a value
    /// outside its range.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        let selection = try c.decode(Int.self, forKey: .selection)
        let result: Result<MoleculeState, MoleculeStateRefusal>
        switch schema {
        case 1:
            result = Self.migrateV1(selection: selection).map { .success($0) } ?? .failure(.outOfRange)
        case 2:
            let mode = try c.decode(Int.self, forKey: .mode)
            let camera = try c.decode(RawCamera.self, forKey: .camera)
            result = Self.validated(selection: selection, mode: mode, camera: camera)
        default:
            result = .failure(schema > Self.schemaVersion ? .newerVersion : .damaged)
        }
        switch result {
        case .success(let state): self = state
        case .failure(let reason):
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: reason.rawValue)
        }
    }

    /// Encodes the state at the current schema (the keys of the file header).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(selection, forKey: .selection)
        try c.encode(mode.rawValue, forKey: .mode)
        try c.encode(camera, forKey: .camera)
    }

    /// The state as JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// The state in `data` (schema 2, or schema 1 migrated), or the reason it is refused (see the file header for the
    /// order of the checks).
    public static func decode(_ data: Data) -> Result<MoleculeState, MoleculeStateRefusal> {
        /// The schema alone, read first.
        struct Header: Decodable { var schema: Int }
        /// The whole schema-1 payload.
        struct PayloadV1: Decodable { var schema: Int; var selection: Int }
        /// The whole schema-2 payload.
        struct PayloadV2: Decodable { var schema: Int; var selection: Int; var mode: Int; var camera: RawCamera }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= oldestSchemaVersion else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        if header.schema == 1 {
            guard let payload = try? decoder.decode(PayloadV1.self, from: data) else { return .failure(.damaged) }
            return migrateV1(selection: payload.selection).map { .success($0) } ?? .failure(.outOfRange)
        }
        guard let payload = try? decoder.decode(PayloadV2.self, from: data) else { return .failure(.damaged) }
        return validated(selection: payload.selection, mode: payload.mode, camera: payload.camera)
    }
}
