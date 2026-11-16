// AnatomyViewDocument — feature 126 (A17-P03) T-A17-305 (FR-A17-307; SC-A17-305; clarification Q4; data-model
// "AnatomyViewDocument"; contracts/layers-search.md). The saved view file of Interactive Anatomy, `view.json` in the
// experience's storage: one `DocumentEnvelope` (`kind` "a17.view", `schemaVersion`, `savedAt` as ISO 8601, `payload`
// the view state's JSON object), written as JSON with sorted keys, the same shape `DocumentStore` writes.
//
// `decode(_:parts:)` refuses, in this order: `too-large` (more than 65,536 bytes, not parsed), `damaged` (not an
// envelope: no `kind`, whole-number `schemaVersion`, ISO 8601 `savedAt` or object `payload`), `damaged` (a kind other
// than "a17.view"), `newer-version` (an envelope schema above `AnatomyViewState.schemaVersion`), `damaged` (an
// envelope schema below 1, or a payload whose `schema` differs from the envelope's); then the payload is decoded by
// `AnatomyViewState.decode(_:parts:)`, which migrates schema 1 and drops unknown ids with reasons.
import Foundation
import VisualCorePersistence

/// The saved view file (see the file header).
public enum AnatomyViewDocument {
    /// The file name in the experience's storage.
    public static let fileName = "view.json"
    /// The envelope kind.
    public static let kind = "a17.view"
    /// The largest file that is read.
    public static let maxBytes = 65_536

    /// The envelope of `view`, saved at `savedAt`, as JSON with sorted keys.
    public static func encode(_ view: AnatomyViewState, savedAt: Date = Date(),
                              partIDs: [String] = AnatomyIsolate.bundledPartIDs) -> Data {
        let envelope = DocumentEnvelope(kind: kind, schemaVersion: AnatomyViewState.schemaVersion, savedAt: savedAt)
        guard let payload = try? JSONSerialization.jsonObject(with: view.encoded(partIDs: partIDs)) else { return Data() }
        let object: [String: Any] = ["kind": envelope.kind, "schemaVersion": envelope.schemaVersion,
                                     "savedAt": ISO8601DateFormatter().string(from: envelope.savedAt),
                                     "payload": payload]
        return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }

    /// The envelope metadata of `data`, or nil when it is not an envelope.
    public static func envelope(_ data: Data) -> DocumentEnvelope? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return envelope(object)
    }

    /// Decodes a saved view file whose ids should be among `parts`: the view or the first refusal, and one reason
    /// sentence for each dropped id (see the file header).
    public static func decode(_ data: Data, parts: [String])
        -> (Result<AnatomyViewState, ContentRefusal>, dropped: [String]) {
        guard data.count <= maxBytes else {
            return (.failure(ContentRefusal(.tooLarge,
                "The saved view file has \(data.count) bytes, more than \(maxBytes).")), [])
        }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let envelope = envelope(object), let payload = object["payload"] as? [String: Any] else {
            return (.failure(ContentRefusal(.damaged, "The saved view file is not a document envelope.")), [])
        }
        guard envelope.kind == kind else {
            return (.failure(ContentRefusal(.damaged,
                "The saved view file holds a \(envelope.kind) document, not \(kind).")), [])
        }
        if envelope.schemaVersion > AnatomyViewState.schemaVersion {
            return (.failure(ContentRefusal(.newerVersion,
                "The saved view file uses schema \(envelope.schemaVersion), newer than schema \(AnatomyViewState.schemaVersion).")), [])
        }
        let payloadSchema = (payload["schema"] as? NSNumber).flatMap { Int(exactly: $0.doubleValue) }
        guard envelope.schemaVersion >= 1, payloadSchema == envelope.schemaVersion,
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return (.failure(ContentRefusal(.damaged,
                "The saved view file's schema \(envelope.schemaVersion) does not match its payload.")), [])
        }
        let decoded: (Result<AnatomyViewState, ContentRefusal>, dropped: [String]) =
            AnatomyViewState.decode(body, parts: parts)
        return decoded
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
