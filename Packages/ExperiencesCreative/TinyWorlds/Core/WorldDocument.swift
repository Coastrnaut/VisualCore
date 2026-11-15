// WorldDocument — feature 091 (A12-P03) T-A12-302 (FR-A12-320, FR-A12-323; clarification Q4; research D4; data-model
// "WorldDocument"; G-WORLDDOC). A saved world: its slot name ("Island, seed 1") and its `WorldState`, written as JSON
// with sorted keys `{"name", "schema": 2, "state": {…}}` (the state as `WorldState.encoded()` writes it) and at most
// 64 KB (65,536 bytes). Doubles use Swift's shortest round-trip form, so every prop transform reads back bit-identical
// and the reopened world has the same digest.
//
// `encode()` refuses a document above the cap as `too-large`. `decode(_:)` checks, in this order:
// - `too-large`: more than 65,536 bytes (nothing else is read);
// - `damaged`: not JSON, truncated, no integer `schema` or a schema below 2;
// - `newer-version`: a document schema above 2, or a state schema above `WorldState.schemaVersion`;
// - `damaged`: no string `name`, no `state`, or a state `WorldState.decode(_:)` refuses as damaged.
// A state of schema 1 inside a document is read as `WorldState` reads it (no props, the default light). A refusal
// changes nothing; the caller keeps the current world.
import Foundation

/// Why a world document was refused (or could not be written).
public enum WorldDocumentRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing, malformed or out-of-range value.
    case damaged = "damaged"
    /// Written by a newer version.
    case newerVersion = "newer-version"
    /// Larger than ``WorldDocument/maxBytes``.
    case tooLarge = "too-large"
}

/// A saved world: slot name and state.
public struct WorldDocument: Equatable, Sendable {
    /// The document schema this code writes and reads.
    public static let schemaVersion = 2
    /// The largest document in bytes (64 KB).
    public static let maxBytes = 65_536

    /// The slot name shown in the slot list.
    public var name: String
    /// The saved world.
    public var state: WorldState

    /// Creates a document.
    public init(name: String, state: WorldState) {
        self.name = name
        self.state = state
    }

    /// A document named after `state` (``defaultName(for:)``).
    public init(state: WorldState) { self.init(name: Self.defaultName(for: state), state: state) }

    /// The default slot name: the preset's name and the seed, such as "Island, seed 1".
    public static func defaultName(for state: WorldState) -> String { "\(state.preset.name), seed \(state.seed)" }

    /// The JSON layout.
    private struct Layout: Codable {
        var name: String
        var schema: Int
        var state: WorldState
    }

    /// The document as sorted-key JSON, or `too-large` above ``maxBytes`` (or `damaged` if it cannot be encoded).
    public func encode() -> Result<Data, WorldDocumentRefusal> {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(Layout(name: name, schema: Self.schemaVersion, state: state)) else {
            return .failure(.damaged)
        }
        return data.count <= Self.maxBytes ? .success(data) : .failure(.tooLarge)
    }

    /// The document in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data) -> Result<WorldDocument, WorldDocumentRefusal> {
        guard data.count <= maxBytes else { return .failure(.tooLarge) }
        struct Header: Decodable { var schema: Int }
        struct StateHeader: Decodable {
            struct Inner: Decodable { var schema: Int }
            var state: Inner
        }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= schemaVersion else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        if let inner = try? decoder.decode(StateHeader.self, from: data), inner.state.schema > WorldState.schemaVersion {
            return .failure(.newerVersion)
        }
        guard let layout = try? decoder.decode(Layout.self, from: data) else { return .failure(.damaged) }
        return .success(WorldDocument(name: layout.name, state: layout.state))
    }
}
