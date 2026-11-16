// MoleculeState — feature 110 (A15-P01) T-A15-105 (FR-A15-131; clarification Q5; data-model "MoleculeState";
// contracts/domain.md). The saved state of Molecular Explorer at snapshot schema 1: the selected molecule index
// (0 = water … 4 = caffeine, an index into `MoleculeLibrary.molecules`). The initial state selects water.
//
// Written as JSON with sorted keys: `{"schema": 1, "selection": <index>}`. `decode(_:)` reads the schema first and
// refuses, in this order:
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, or a missing or non-integer `selection`;
// - `newer-version`: a schema above 1 (whatever else the payload holds);
// - `out-of-range`: a selection outside 0…4.
// A refusal changes nothing; the caller opens `MoleculeState.initial`.
//
// `select(_:)` accepts a whole index 0…4; `next()` and `previous()` step by one and refuse a step past an end (next at
// caffeine, previous at water). Each returns false, with nothing changed, when refused; the adapter maps that to the
// refusal `a15.invalid-choice`.
import Foundation

/// Why a saved Molecular Explorer state was refused.
public enum MoleculeStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing or malformed key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``MoleculeState/schemaVersion``).
    case newerVersion = "newer-version"
    /// A selection outside the library.
    case outOfRange = "out-of-range"
}

/// The state of a Molecular Explorer session: the selected library molecule.
public struct MoleculeState: Codable, Equatable, Sendable {
    /// The snapshot schema this code writes and reads.
    public static let schemaVersion = 1
    /// The number of selectable molecules (5).
    public static let moleculeCount = MoleculeLibraryData.records.count
    /// Water selected.
    public static let initial = MoleculeState(selection: 0)

    /// The selected molecule index, 0…4.
    public private(set) var selection: Int

    /// The state with molecule `selection` (clamped into 0…4) selected.
    public init(selection: Int) {
        self.selection = min(max(selection, 0), Self.moleculeCount - 1)
    }

    /// The selected molecule, or nil when the library failed to load it (never for the bundled data).
    public var molecule: Molecule? {
        MoleculeLibrary.molecules.indices.contains(selection) ? MoleculeLibrary.molecules[selection] : nil
    }

    /// Selects molecule `index`; false, with nothing changed, for an index outside 0…4.
    @discardableResult
    public mutating func select(_ index: Int) -> Bool {
        guard (0..<Self.moleculeCount).contains(index) else { return false }
        selection = index
        return true
    }

    /// Selects the next molecule; false, with nothing changed, at the last molecule (caffeine).
    @discardableResult
    public mutating func next() -> Bool { select(selection + 1) }

    /// Selects the previous molecule; false, with nothing changed, at the first molecule (water).
    @discardableResult
    public mutating func previous() -> Bool { select(selection - 1) }

    /// The coding keys.
    private enum CodingKeys: String, CodingKey { case schema, selection }

    /// Decodes a schema-1 state; throws for another schema, a malformed key or a selection outside 0…4.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        let selection = try c.decode(Int.self, forKey: .selection)
        guard schema == Self.schemaVersion, (0..<Self.moleculeCount).contains(selection) else {
            throw DecodingError.dataCorruptedError(forKey: .selection, in: c, debugDescription: "not a valid state")
        }
        self.selection = selection
    }

    /// Encodes the state at the current schema (the keys of the file header).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(selection, forKey: .selection)
    }

    /// The state as JSON with sorted keys.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// The state in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data) -> Result<MoleculeState, MoleculeStateRefusal> {
        /// The schema alone, read first.
        struct Header: Decodable { var schema: Int }
        /// The whole schema-1 payload.
        struct Payload: Decodable { var schema: Int; var selection: Int }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= 1 else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let payload = try? decoder.decode(Payload.self, from: data) else { return .failure(.damaged) }
        guard (0..<moleculeCount).contains(payload.selection) else { return .failure(.outOfRange) }
        return .success(MoleculeState(selection: payload.selection))
    }
}
