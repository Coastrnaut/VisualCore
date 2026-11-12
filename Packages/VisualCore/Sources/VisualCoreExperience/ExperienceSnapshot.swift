// ExperienceSnapshot — feature 188 T-U02-020 (FR-U02-040, FR-U02-043, FR-U02-046, FR-U02-047; research R4;
// data-model section 4; contract specs/188-ua-f02-experience-sdk/contracts/experience-core-api.md). The envelope of
// a captured experience state: who wrote it, with which schema, seed and step, the digest of the state, the payload
// as exact text and a checksum of that text. Reading never stops the process: every input gives a snapshot or a
// typed `SnapshotError`.
import Foundation
import VisualCoreMath

/// A captured state of one experience in a form that can be stored and restored.
///
/// The encoded form is UTF-8 JSON with the eight keys `checksum`, `digest`, `experience`, `format`, `payload`,
/// `schema`, `seed` and `step` in this order and no insignificant white space. The payload is held as text, so its
/// bytes and its checksum never drift.
public struct ExperienceSnapshot: Sendable, Equatable, Codable {
    /// The envelope format this build writes and reads.
    public static let format = 1
    /// The largest encoded snapshot, in bytes.
    public static let maxBytes = 1_048_576

    /// The experience that wrote the snapshot.
    public let experience: ExperienceID
    /// The schema version of the experience that wrote the payload; never negative.
    public let schemaVersion: Int
    /// The seed the state was prepared with.
    public let seed: UInt64
    /// The step index at capture; never negative.
    public let stepIndex: Int
    /// The digest of the state at capture.
    public let digest: StateDigest
    /// The UTF-8 text of one JSON object: the state as the experience wrote it.
    public let payload: String
    /// `StableHash.sha256Hex` of the payload's UTF-8 bytes: 64 lower-case hexadecimal digits.
    public let checksum: String

    /// Creates a snapshot and computes its checksum.
    ///
    /// Throws `SnapshotError.corrupt` when the payload is not UTF-8 text of one JSON object or when the schema
    /// version or the step index is negative, and `SnapshotError.tooLarge` when the encoded snapshot would be
    /// larger than `maxBytes`.
    public init(experience: ExperienceID, schemaVersion: Int, seed: UInt64, stepIndex: Int, digest: StateDigest,
                payload: Data) throws(SnapshotError) {
        guard schemaVersion >= 0 else { throw .corrupt(reason: "the schema version is negative") }
        guard stepIndex >= 0 else { throw .corrupt(reason: "the step index is negative") }
        guard let text = String(data: payload, encoding: .utf8) else {
            throw .corrupt(reason: "the payload is not UTF-8 text")
        }
        guard Self.isJSONObject(text) else { throw .corrupt(reason: "the payload is not a JSON object") }
        self.experience = experience
        self.schemaVersion = schemaVersion
        self.seed = seed
        self.stepIndex = stepIndex
        self.digest = digest
        self.payload = text
        self.checksum = StableHash.sha256Hex(Array(text.utf8))
        _ = try encoded()
    }

    /// Reads an encoded snapshot.
    ///
    /// The checks run in this order: size (`tooLarge`), JSON shape and field types (`corrupt` with the reason),
    /// format (`unknownFormat`), the forms of experience id, schema version, seed, step index and digest
    /// (`corrupt`), checksum (`checksumMismatch`), the payload is a JSON object (`corrupt`).
    public init(data: Data) throws(SnapshotError) {
        guard data.count <= Self.maxBytes else { throw .tooLarge(bytes: data.count) }
        let fields: SnapshotFields
        do {
            fields = try JSONDecoder().decode(SnapshotFields.self, from: data)
        } catch {
            throw .corrupt(reason: Self.shapeProblem(error))
        }
        self = try ExperienceSnapshot(fields: fields)
    }

    /// The snapshot as deterministic JSON: sorted keys, no insignificant white space, the seed as decimal text.
    ///
    /// Encoding the same snapshot again gives the same bytes, and a snapshot read from these bytes encodes to
    /// them. Throws `SnapshotError.tooLarge` when the result is larger than `maxBytes`.
    public func encoded() throws(SnapshotError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data: Data
        do {
            data = try encoder.encode(SnapshotFields(self))
        } catch {
            throw .corrupt(reason: "the snapshot cannot be encoded")
        }
        guard data.count <= Self.maxBytes else { throw .tooLarge(bytes: data.count) }
        return data
    }

    /// Decodes a snapshot from the eight keys of the encoded form and validates it like `init(data:)` does, apart
    /// from the size. A refused snapshot is a `DecodingError.dataCorrupted` whose description starts with the
    /// code of the `SnapshotError`, so a document store reports the file as corrupt.
    public init(from decoder: any Decoder) throws {
        let fields = try SnapshotFields(from: decoder)
        do {
            self = try ExperienceSnapshot(fields: fields)
        } catch {
            let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                debugDescription: "\(error.code): \(error)")
            throw DecodingError.dataCorrupted(context)
        }
    }

    /// Encodes the snapshot as the eight keys of the encoded form.
    public func encode(to encoder: any Encoder) throws {
        try SnapshotFields(self).encode(to: encoder)
    }

    /// The validation shared by `init(data:)` and `init(from:)`: everything after the JSON shape.
    private init(fields: SnapshotFields) throws(SnapshotError) {
        guard fields.format == Self.format else { throw .unknownFormat(fields.format) }
        let experience: ExperienceID
        do {
            experience = try ExperienceID(fields.experience)
        } catch {
            throw .corrupt(reason: "the experience id is malformed")
        }
        guard fields.schema >= 0 else { throw .corrupt(reason: "the schema version is negative") }
        guard let seed = UInt64(fields.seed), String(seed) == fields.seed else {
            throw .corrupt(reason: "the seed is not the decimal text of an unsigned 64-bit integer")
        }
        guard fields.step >= 0 else { throw .corrupt(reason: "the step index is negative") }
        guard let digest = StateDigest(hex: fields.digest) else {
            throw .corrupt(reason: "the digest is not 64 lower-case hexadecimal digits")
        }
        guard StableHash.sha256Hex(Array(fields.payload.utf8)) == fields.checksum else { throw .checksumMismatch }
        guard Self.isJSONObject(fields.payload) else { throw .corrupt(reason: "the payload is not a JSON object") }
        self.experience = experience
        self.schemaVersion = fields.schema
        self.seed = seed
        self.stepIndex = fields.step
        self.digest = digest
        self.payload = fields.payload
        self.checksum = fields.checksum
    }

    /// Whether `text` is the text of one JSON object.
    private static func isJSONObject(_ text: String) -> Bool {
        guard let value = try? JSONSerialization.jsonObject(with: Data(text.utf8)) else { return false }
        return value is [String: Any]
    }

    /// The reason text for an input that does not have the shape of the encoded form.
    private static func shapeProblem(_ error: any Error) -> String {
        guard let error = error as? DecodingError else { return "not JSON" }
        switch error {
        case .keyNotFound(let key, _):
            return "the key \(key.stringValue) is missing"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            guard let key = context.codingPath.last else { return "not a JSON object" }
            return "the key \(key.stringValue) has the wrong type"
        case .dataCorrupted(let context):
            if let key = context.codingPath.last { return "the key \(key.stringValue) has the wrong type" }
            let text = context.debugDescription
            return text.hasPrefix(SnapshotFields.unknownKeyPrefix) ? text : "not JSON"
        @unknown default:
            return "not JSON"
        }
    }
}

/// The eight fields of the encoded form, before validation.
private struct SnapshotFields: Codable {
    /// The start of the description of the error for a key the encoded form does not have.
    static let unknownKeyPrefix = "the key "

    let checksum: String
    let digest: String
    let experience: String
    let format: Int
    let payload: String
    let schema: Int
    let seed: String
    let step: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case checksum, digest, experience, format, payload, schema, seed, step
    }

    /// Any key of an object, to find keys the encoded form does not have.
    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(_ snapshot: ExperienceSnapshot) {
        checksum = snapshot.checksum
        digest = snapshot.digest.hex
        experience = snapshot.experience.rawValue
        format = ExperienceSnapshot.format
        payload = snapshot.payload
        schema = snapshot.schemaVersion
        seed = String(snapshot.seed)
        step = snapshot.stepIndex
    }

    init(from decoder: any Decoder) throws {
        let all = try decoder.container(keyedBy: AnyKey.self)
        let known = Set(CodingKeys.allCases.map(\.rawValue))
        if let extra = all.allKeys.map(\.stringValue).sorted().first(where: { !known.contains($0) }) {
            let text = Self.unknownKeyPrefix + String(extra.prefix(40)) + " is not part of a snapshot"
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: text))
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        checksum = try container.decode(String.self, forKey: .checksum)
        digest = try container.decode(String.self, forKey: .digest)
        experience = try container.decode(String.self, forKey: .experience)
        format = try container.decode(Int.self, forKey: .format)
        payload = try container.decode(String.self, forKey: .payload)
        schema = try container.decode(Int.self, forKey: .schema)
        seed = try container.decode(String.self, forKey: .seed)
        step = try container.decode(Int.self, forKey: .step)
    }
}
