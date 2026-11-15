// ExperimentDocument — feature 085 (A11-P04) T-A11-402 (FR-A11-402, FR-A11-403; clarifications 2 and 3; research D2,
// D3; data-model "Origin", "ExperimentDocument"). The origin of an opened experiment and the saved experiment file.
//
// `ExperimentOrigin` is a preset (0…3, `PresetID`) or a saved slot (0…3). It is written as
// `{"kind": "preset" | "slot", "index": n}`; any other kind or an index outside 0…3 fails to decode.
//
// `ExperimentDocument` is file schema 1: `{"name", "origin", "schema": 1, "world"}` with sorted keys at every level
// (`encoded()`), the world written by its own Codable form (the schema-3 record exactly as `PhysicsWorld.encoded()`
// writes it). A document never holds a grab or a selection: they are removed when a document is made and when one is
// read. A name is 1–24 characters: it is trimmed of surrounding white space and cut to 24 characters, and an empty
// name becomes "Experiment N" with N the slot number + 1 given by the caller.
//
// `decode(_:)` reads the schema first and refuses, in this order:
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, a missing or malformed `name`, `origin` or
//   `world` key, or a stored name that breaks the name rule (empty, longer than 24 characters, or with surrounding white
//   space);
// - `newer-version`: a schema above 1 (whatever else the file holds);
// - `invalid-world`: the world record does not decode through `PhysicsWorld.decode(from:)` (malformed fields or an
//   unsupported world schema), or the decoded world (any supported world schema, migrated to schema 3) has validation
//   problems against the catalog.
// The refusal never changes anything; the caller leaves the file in place.
import Foundation

/// Where the opened experiment came from: a preset or a saved slot.
public enum ExperimentOrigin: Codable, Equatable, Hashable, Sendable {
    /// Preset 0…3 (``PresetID``).
    case preset(Int)
    /// Saved slot 0…3.
    case slot(Int)

    /// The allowed preset numbers and slot numbers.
    public static let validRange: ClosedRange<Int> = 0...3
    /// The origin of free play.
    public static let freePlay = ExperimentOrigin.preset(PresetID.freePlay.rawValue)

    /// The preset or slot number.
    public var index: Int {
        switch self {
        case .preset(let index), .slot(let index): index
        }
    }

    /// True when the number is in 0…3.
    public var isValid: Bool { Self.validRange.contains(index) }

    private enum CodingKeys: String, CodingKey { case kind, index }

    /// Decodes `{"kind": "preset" | "slot", "index": 0…3}`; anything else throws.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        let index = try c.decode(Int.self, forKey: .index)
        guard Self.validRange.contains(index) else {
            throw DecodingError.dataCorruptedError(forKey: .index, in: c, debugDescription: "index outside 0…3")
        }
        switch kind {
        case "preset": self = .preset(index)
        case "slot": self = .slot(index)
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "unknown kind \(kind)")
        }
    }

    /// Encodes `{"index": n, "kind": "preset" | "slot"}`.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .preset(let index): try c.encode("preset", forKey: .kind); try c.encode(index, forKey: .index)
        case .slot(let index): try c.encode("slot", forKey: .kind); try c.encode(index, forKey: .index)
        }
    }
}

/// Why a saved experiment file was refused.
public enum DocumentRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing or malformed key.
    case damaged = "damaged"
    /// Written by a newer version (file schema above 1).
    case newerVersion = "newer-version"
    /// The world does not decode or does not validate.
    case invalidWorld = "invalid-world"
}

/// A saved experiment: file schema 1, a name, an origin and a world without grab and selection.
public struct ExperimentDocument: Codable, Equatable, Sendable {
    /// The file schema this code writes and reads.
    public static let schemaVersion = 1
    /// The longest name in characters.
    public static let maxNameLength = 24

    /// The file schema (1).
    public var schema: Int
    /// The name, 1–24 characters.
    public var name: String
    /// Where the experiment came from.
    public var origin: ExperimentOrigin
    /// The world (current world schema), without grab and selection.
    public var world: PhysicsWorld

    /// A document of `world` with the name `name` normalised by ``normalizedName(_:slot:)`` (`slot` is the slot the
    /// document is saved to, 0…3, used only for the default name), the origin `origin`, and the world's grab and
    /// selection removed.
    public init(name: String, origin: ExperimentOrigin, world: PhysicsWorld, slot: Int) {
        self.schema = Self.schemaVersion
        self.name = Self.normalizedName(name, slot: slot)
        self.origin = origin
        self.world = Self.withoutEditing(world)
    }

    /// `raw` trimmed of surrounding white space and cut to 24 characters; "Experiment N" (N = `slot` + 1) when that
    /// is empty.
    public static func normalizedName(_ raw: String, slot: Int) -> String {
        let trimmed = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNameLength))
        let cut = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        return cut.isEmpty ? "Experiment \(slot + 1)" : cut
    }

    /// True when `name` keeps the name rule: 1–24 characters with no surrounding white space (a name
    /// ``normalizedName(_:slot:)`` leaves unchanged).
    public static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && name.count <= maxNameLength && name == name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `world` without grab and selection.
    public static func withoutEditing(_ world: PhysicsWorld) -> PhysicsWorld {
        var world = world
        world.grab = nil
        world.selectedId = nil
        return world
    }

    /// The document as JSON with sorted keys (deterministic bytes for equal documents); empty data for a world with a
    /// non-finite number. The grab and the selection are removed before encoding.
    public func encoded() -> Data {
        var copy = self
        copy.world = Self.withoutEditing(world)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(copy)) ?? Data()
    }

    /// The document in `data`, or the reason it is refused (see the file header for the order of the checks). The
    /// world is decoded through ``PhysicsWorld/decode(from:)`` (any supported world schema), validated against
    /// `catalog`, and has its grab and selection removed.
    public static func decode(_ data: Data, catalog: MaterialCatalog = .bundled)
        -> Result<ExperimentDocument, DocumentRefusal> {
        struct Header: Decodable { var schema: Int }
        struct Body: Decodable {
            var name: String
            var origin: ExperimentOrigin
            var world: WorldPayload
        }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= 1 else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let body = try? decoder.decode(Body.self, from: data), isValidName(body.name) else {
            return .failure(.damaged)
        }
        guard case .success(let world) = body.world.result, world.validate(catalog: catalog).isEmpty else {
            return .failure(.invalidWorld)
        }
        var document = ExperimentDocument(name: body.name, origin: body.origin, world: world, slot: 0)
        document.name = body.name
        return .success(document)
    }

    /// The world key of a file: present (otherwise the file is damaged), its record decoded or not.
    private struct WorldPayload: Decodable {
        var result: Result<PhysicsWorld, Error>
        init(from decoder: Decoder) throws { result = Result { try PhysicsWorld.decode(from: decoder) } }
    }
}
