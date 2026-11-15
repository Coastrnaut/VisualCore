// SolarState — feature 103 (A14-P01) T-A14-102 (FR-A14-121; clarification Q5; data-model "SolarState";
// contracts/catalog.md). The saved state of Solar System Explorer at snapshot schema 1: the selected body index
// (0 = Sun … 8 = Neptune, an index into `BodyCatalog.bundled`). The initial state selects the Sun.
//
// Written as JSON with sorted keys: `{"schema": 1, "selection": <index>}`. `decode(_:)` reads the schema first and
// refuses, in this order:
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, or a missing or non-integer `selection`;
// - `newer-version`: a schema above 1 (whatever else the payload holds);
// - `out-of-range`: a selection outside 0…8.
// A refusal changes nothing; the caller opens `SolarState.initial`.
//
// `select(_:)` accepts a whole index 0…8; `next()` and `previous()` step by one and refuse a step past an end (next at
// Neptune, previous at the Sun). Each returns false, with nothing changed, when refused; the adapter maps that to the
// refusal `a14.invalid-choice`.
import Foundation

/// Why a saved Solar System Explorer state was refused.
public enum SolarStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing or malformed key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``SolarState/schemaVersion``).
    case newerVersion = "newer-version"
    /// A selection outside the catalog.
    case outOfRange = "out-of-range"
}

/// The state of a Solar System Explorer session: the selected body.
public struct SolarState: Codable, Equatable, Sendable {
    /// The snapshot schema this code writes and reads.
    public static let schemaVersion = 1
    /// The catalog the selection refers to.
    public static let catalog = BodyCatalog.bundled
    /// The number of selectable bodies (9).
    public static let bodyCount = BodyCatalog.bundled.bodies.count
    /// The Sun selected.
    public static let initial = SolarState(selection: 0)

    /// The selected body index, 0…8.
    public private(set) var selection: Int

    /// The state with body `selection` (clamped into 0…8) selected.
    public init(selection: Int) {
        self.selection = min(max(selection, 0), Self.bodyCount - 1)
    }

    /// The selected body.
    public var body: CelestialBody { Self.catalog.bodies[selection] }

    /// The selected body's fact card.
    public var factCard: FactCard {
        Self.catalog.factCard(for: selection) ?? FactCard(bodyID: body.id, name: body.name, kind: body.kind, facts: [])
    }

    /// Selects body `index`; false, with nothing changed, for an index outside 0…8.
    @discardableResult
    public mutating func select(_ index: Int) -> Bool {
        guard (0..<Self.bodyCount).contains(index) else { return false }
        selection = index
        return true
    }

    /// Selects the next body; false, with nothing changed, at the last body (Neptune).
    @discardableResult
    public mutating func next() -> Bool { select(selection + 1) }

    /// Selects the previous body; false, with nothing changed, at the first body (the Sun).
    @discardableResult
    public mutating func previous() -> Bool { select(selection - 1) }

    private enum CodingKeys: String, CodingKey { case schema, selection }

    /// Decodes a schema-1 state; throws for another schema, a malformed key or a selection outside 0…8.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        let selection = try c.decode(Int.self, forKey: .selection)
        guard schema == Self.schemaVersion, (0..<Self.bodyCount).contains(selection) else {
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
    public static func decode(_ data: Data) -> Result<SolarState, SolarStateRefusal> {
        struct Header: Decodable { var schema: Int }
        struct Payload: Decodable { var schema: Int; var selection: Int }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= 1 else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let payload = try? decoder.decode(Payload.self, from: data) else { return .failure(.damaged) }
        guard (0..<bodyCount).contains(payload.selection) else { return .failure(.outOfRange) }
        return .success(SolarState(selection: payload.selection))
    }
}
