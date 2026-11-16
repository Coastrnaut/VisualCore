// AnatomyContentPack — feature 127 (A17-P04) T-A17-404 (FR-A17-407; SC-A17-404; clarification Q4; data-model
// "AnatomyContentPack"; contracts/accessibility-pack.md). The versioned content pack the bundled region is shipped in,
// `Content/knee-right.pack.json`: one `DocumentEnvelope` (`kind` "a17.content-pack", `schemaVersion` 2, `savedAt` as
// ISO 8601, `payload` the region's JSON object), written as JSON with sorted keys.
//
// Pack schema 1 is the bare region file of A17-P01 (a JSON object with `schema` and `structures` and no `kind`); it
// migrates to schema 2 by wrapping, so it decodes to the same region.
//
// `decode(_:)` refuses, in this order: `too-large` (more than 262,144 bytes, not parsed), `damaged` (not a JSON
// object), then a bare region is decoded by `AnatomyContent.decode(_:)`; otherwise `damaged` (not an envelope: no
// `kind`, whole-number `schemaVersion`, ISO 8601 `savedAt` or object `payload`), `damaged` (a kind other than
// "a17.content-pack"), `newer-version` (an envelope schema above 2), `damaged` (an envelope schema below 1), and then
// whatever `AnatomyContent.decode(_:)` refuses for the payload, which it validates.
//
// `digest(_:)` is the SHA-256 (`StableHash.sha256Hex`) of `AnatomyContent.encoded(region)`, the region with sorted
// keys, so it is equal for equal regions however they were stored.
import Foundation
import VisualCoreMath
import VisualCorePersistence

/// The versioned content pack (see the file header).
public enum AnatomyContentPack {
    /// The envelope kind.
    public static let kind = "a17.content-pack"
    /// The pack schema this code reads and writes; schema 1 is the bare region.
    public static let schemaVersion = 2
    /// The largest pack that is read, in bytes.
    public static let maxBytes = 262_144
    /// The save time written into the bundled pack, so encoding is deterministic: 2026-11-16T00:00:00Z.
    public static let bundledSavedAt = Date(timeIntervalSince1970: 1_794_787_200)

    /// The pack of `region`, saved at `savedAt`, as JSON with sorted keys, pretty printed, slashes unescaped.
    public static func encode(_ region: AnatomyRegion, savedAt: Date = bundledSavedAt) -> Data {
        let file = PackFile(kind: kind, payload: region, savedAt: ISO8601DateFormatter().string(from: savedAt),
                            schemaVersion: schemaVersion)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return (try? encoder.encode(file)) ?? Data()
    }

    /// Decodes a pack (schema 2) or a bare region (schema 1): the validated region or the first refusal (see the
    /// file header).
    public static func decode(_ data: Data) -> Result<AnatomyRegion, ContentRefusal> {
        guard data.count <= maxBytes else {
            return .failure(ContentRefusal(.tooLarge, "The content pack is \(data.count) bytes, more than the limit of \(maxBytes)."))
        }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .failure(ContentRefusal(.damaged, "The content pack is not a JSON object."))
        }
        if object["kind"] == nil, object["structures"] != nil, object["schema"] != nil {
            return AnatomyContent.decode(data)
        }
        guard let envelope = envelope(object), let payload = object["payload"] as? [String: Any] else {
            return .failure(ContentRefusal(.damaged, "The content pack is not a document envelope."))
        }
        guard envelope.kind == kind else {
            return .failure(ContentRefusal(.damaged, "The content pack holds a \(envelope.kind) document, not \(kind)."))
        }
        if envelope.schemaVersion > schemaVersion {
            return .failure(ContentRefusal(.newerVersion,
                "The content pack uses schema \(envelope.schemaVersion), newer than schema \(schemaVersion)."))
        }
        guard envelope.schemaVersion >= 1, let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return .failure(ContentRefusal(.damaged,
                "The content pack uses schema \(envelope.schemaVersion), which does not exist."))
        }
        return AnatomyContent.decode(body)
    }

    /// The SHA-256 hex digest of the region encoded with sorted keys.
    public static func digest(_ region: AnatomyRegion) -> String {
        StableHash.sha256Hex([UInt8](AnatomyContent.encoded(region)))
    }

    /// The envelope metadata of a JSON object, or nil.
    static func envelope(_ object: [String: Any]) -> DocumentEnvelope? {
        guard let kind = object["kind"] as? String,
              let number = object["schemaVersion"] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              let version = Int(exactly: number.doubleValue),
              let savedText = object["savedAt"] as? String,
              let savedAt = ISO8601DateFormatter().date(from: savedText) else { return nil }
        return DocumentEnvelope(kind: kind, schemaVersion: version, savedAt: savedAt)
    }
}

/// The written form of a pack; property names are the JSON keys.
private struct PackFile: Encodable {
    let kind: String
    let payload: AnatomyRegion
    let savedAt: String
    let schemaVersion: Int
}
