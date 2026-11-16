// RecentMolecules — feature 113 (A15-P04) T-A15-402 (contracts/library.md; data-model "RecentMolecules"; research D1,
// D2; clarification Q1). The recently opened library molecules, newest first, unique, at most 8, kept apart from the
// engine state so digests and replays do not change. `record(_:)` moves an id to the front and drops the oldest beyond
// 8. The document `recent.json` is schema 1, sorted keys, at most 2,048 bytes: `{"ids":["water"],"schemaVersion":1}`.
// `decode(_:known:)` refuses, in this order:
// - `oversized`: more than 2,048 bytes (checked before parsing);
// - `damaged`: not JSON, or a missing key or a value of the wrong type;
// - `newer-version`: a schema version above 1;
// - `out-of-range`: a schema version below 1, more than 8 ids, a duplicate id, or a malformed id (empty, longer than
//   32 characters, or not only lowercase letters a–z, digits and hyphens).
// On success the ids not in `known` (the library) are dropped, keeping the order of the rest.
import Foundation

/// The recently opened molecules (`recent.json`, schema 1), newest first.
public struct RecentMolecules: Equatable, Sendable {
    /// The schema version this build writes and reads.
    public static let schemaVersion = 1
    /// The most ids kept.
    public static let cap = 8
    /// The largest accepted document, bytes.
    public static let maxBytes = 2_048
    /// The document's file name.
    public static let fileName = "recent.json"
    /// The longest accepted id, characters.
    static let maxIdLength = 32

    /// The ids, newest first, unique, at most ``cap``.
    public private(set) var ids: [String]

    /// Creates a list from `ids` (newest first), keeping the first of each duplicate and at most ``cap`` ids.
    public init(ids: [String] = []) {
        var unique: [String] = []
        for id in ids where !unique.contains(id) && unique.count < Self.cap { unique.append(id) }
        self.ids = unique
    }

    /// Records `id` as the newest: moved to the front, unique, the oldest dropped beyond ``cap``.
    public mutating func record(_ id: String) {
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
        if ids.count > Self.cap { ids.removeLast(ids.count - Self.cap) }
    }

    /// The stored shape.
    private struct Payload: Codable {
        var ids: [String]
        var schemaVersion: Int
    }

    /// The list as JSON with sorted keys (`{"ids":[…],"schemaVersion":1}`).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(Payload(ids: ids, schemaVersion: Self.schemaVersion))) ?? Data()
    }

    /// True when `id` is 1…32 characters of lowercase letters a–z, digits and hyphens.
    static func isWellFormed(_ id: String) -> Bool {
        guard !id.isEmpty, id.unicodeScalars.count <= maxIdLength else { return false }
        for scalar in id.unicodeScalars {
            let value = scalar.value
            let ok = (0x61...0x7A).contains(value) || (0x30...0x39).contains(value) || value == 0x2D
            if !ok { return false }
        }
        return true
    }

    /// The list in `data` with the ids outside `known` dropped, or the first refusal in the order of the file header.
    public static func decode(_ data: Data, known: Set<String>) -> Result<RecentMolecules, DocumentRefusal> {
        guard data.count <= maxBytes else { return .failure(.oversized) }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return .failure(.damaged) }
        guard payload.schemaVersion <= schemaVersion else { return .failure(.newerVersion) }
        guard payload.schemaVersion >= 1, payload.ids.count <= cap,
              Set(payload.ids).count == payload.ids.count else { return .failure(.outOfRange) }
        for id in payload.ids where !isWellFormed(id) { return .failure(.outOfRange) }
        return .success(RecentMolecules(ids: payload.ids.filter { known.contains($0) }))
    }
}
