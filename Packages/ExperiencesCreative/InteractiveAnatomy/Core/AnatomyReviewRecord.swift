// AnatomyReviewRecord — feature 128 (A17-P05) T-A17-502 (FR-A17-501, FR-A17-502; SC-A17-501, SC-A17-502;
// clarifications Q1, Q2; data-model "AnatomyReviewRecord", "AnatomyReviewEntry"; contracts/review.md). The review
// record of the bundled content, `Content/knee-right.review.json` beside the pack, so that a review never edits the
// content it reviews: one `DocumentEnvelope` (`kind` "a17.review-record", `schemaVersion` 1, `savedAt` as ISO 8601,
// `payload` {`contentVersion`, `entries`}). Each entry names a part, its kind (`editorial`, done and recorded by the
// engineer, or `clinical`, added only by the owner), the reviewer, the date (ISO, yyyy-MM-dd), the method and the
// citation ids checked.
//
// `decode(_:region:)` refuses, in this order: `too-large` (more than 65,536 bytes, not parsed), `damaged` (not a JSON
// object or not an envelope: no `kind`, whole-number `schemaVersion`, ISO 8601 `savedAt` or object `payload`),
// `damaged` (a kind other than "a17.review-record"), `newer-version` (an envelope schema above 1), `damaged` (an
// envelope schema below 1, or a payload that does not decode, an unknown entry kind included), `newer-version` (a
// content version above the region's), `damaged` (a content version below the region's); then for each entry in
// order: `missing-reference` (a part id that is not one of the region's parts), `empty-text` (an empty reviewer, date
// or method), `damaged` (a date that is not an ISO calendar date), `missing-reference` (a source that is not one of
// the part's citations), `duplicate-id` (a second entry for the same part and kind).
//
// `bundled(for:)` reads the bundled file once per process and keeps the result for the last region it was asked for.
import Foundation
import VisualCorePersistence

/// One review of one part's text (see the file header).
public struct AnatomyReviewEntry: Codable, Equatable, Sendable {
    /// The kind of review.
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// The text read against its cited sources; done and recorded by the engineer.
        case editorial
        /// A review by a named clinician; added only by the owner.
        case clinical
    }

    /// The reviewed part's id.
    public let part: String
    /// The kind of review.
    public let kind: Kind
    /// Who reviewed the text (a role for an editorial entry, a name for a clinical one).
    public let reviewer: String
    /// When, as an ISO date (yyyy-MM-dd).
    public let date: String
    /// How the text was checked.
    public let method: String
    /// The citation ids the text was checked against.
    public let sources: [String]

    /// Creates an entry.
    public init(part: String, kind: Kind, reviewer: String, date: String, method: String, sources: [String]) {
        self.part = part
        self.kind = kind
        self.reviewer = reviewer
        self.date = date
        self.method = method
        self.sources = sources
    }
}

/// The review record of a region's content (see the file header).
public struct AnatomyReviewRecord: Equatable, Sendable {
    /// The envelope kind.
    public static let kind = "a17.review-record"
    /// The envelope schema this code reads.
    public static let schemaVersion = 1
    /// The largest record that is read, in bytes.
    public static let maxBytes = 65_536
    /// The bundled resource name (in `Content/`, extension `json`).
    public static let bundledResource = "knee-right.review"

    /// The content version the record reviews; it must equal the region's.
    public let contentVersion: Int
    /// The reviews, in file order.
    public let entries: [AnatomyReviewEntry]

    /// Creates a record.
    public init(contentVersion: Int, entries: [AnatomyReviewEntry]) {
        self.contentVersion = contentVersion
        self.entries = entries
    }

    /// The entries of `partID`, in file order.
    public func entries(for partID: String) -> [AnatomyReviewEntry] {
        entries.filter { $0.part == partID }
    }

    /// Decodes and validates a review record of `region`: the record or the first refusal (see the file header).
    public static func decode(_ data: Data, region: AnatomyRegion) -> Result<AnatomyReviewRecord, ContentRefusal> {
        guard data.count <= maxBytes else {
            return .failure(ContentRefusal(.tooLarge,
                "The review record is \(data.count) bytes, more than the limit of \(maxBytes)."))
        }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let envelope = envelope(object), let payload = object["payload"] as? [String: Any] else {
            return .failure(ContentRefusal(.damaged, "The review record is not a document envelope."))
        }
        guard envelope.kind == kind else {
            return .failure(ContentRefusal(.damaged, "The review record holds a \(envelope.kind) document, not \(kind)."))
        }
        if envelope.schemaVersion > schemaVersion {
            return .failure(ContentRefusal(.newerVersion,
                "The review record uses schema \(envelope.schemaVersion), newer than schema \(schemaVersion)."))
        }
        guard envelope.schemaVersion >= 1, let body = try? JSONSerialization.data(withJSONObject: payload),
              let decoded = try? JSONDecoder().decode(RecordPayload.self, from: body) else {
            return .failure(ContentRefusal(.damaged, "The review record's payload cannot be read."))
        }
        if decoded.contentVersion > region.contentVersion {
            return .failure(ContentRefusal(.newerVersion,
                "The review record covers content version \(decoded.contentVersion), newer than version \(region.contentVersion)."))
        }
        if decoded.contentVersion < region.contentVersion {
            return .failure(ContentRefusal(.damaged,
                "The review record covers content version \(decoded.contentVersion), older than version \(region.contentVersion)."))
        }
        let record = AnatomyReviewRecord(contentVersion: decoded.contentVersion, entries: decoded.entries)
        if let refusal = validate(record.entries, region: region) { return .failure(refusal) }
        return .success(record)
    }

    /// The first problem of `entries` against the parts and citations of `region`, or nil.
    static func validate(_ entries: [AnatomyReviewEntry], region: AnatomyRegion) -> ContentRefusal? {
        let parts = region.structures.filter { $0.parent != nil }
        var seen = Set<String>()
        for entry in entries {
            guard let part = parts.first(where: { $0.id == entry.part }) else {
                return ContentRefusal(.missingReference, "The review record names the unknown part \(entry.part).")
            }
            for (name, value) in [("reviewer", entry.reviewer), ("date", entry.date), ("method", entry.method)]
                where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ContentRefusal(.emptyText, "The \(entry.kind.rawValue) review of \(entry.part) has an empty \(name).")
            }
            guard isISODate(entry.date) else {
                return ContentRefusal(.damaged,
                    "The \(entry.kind.rawValue) review of \(entry.part) has the date \(entry.date), not an ISO date.")
            }
            if let source = entry.sources.first(where: { !part.sourceRefs.contains($0) }) {
                return ContentRefusal(.missingReference,
                    "The \(entry.kind.rawValue) review of \(entry.part) names the source \(source), which the part does not cite.")
            }
            let key = "\(entry.part) \(entry.kind.rawValue)"
            guard seen.insert(key).inserted else {
                return ContentRefusal(.duplicateID,
                    "The review record has two \(entry.kind.rawValue) reviews of \(entry.part).")
            }
        }
        return nil
    }

    /// Whether `text` is an ISO calendar date, yyyy-MM-dd (Gregorian, a day that exists).
    public static func isISODate(_ text: String) -> Bool {
        let fields = text.split(separator: "-", omittingEmptySubsequences: false)
        guard fields.count == 3, fields[0].count == 4, fields[1].count == 2, fields[2].count == 2,
              fields.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(fields[0]), let month = Int(fields[1]), let day = Int(fields[2]) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return DateComponents(year: year, month: month, day: day).isValidDate(in: calendar)
    }

    /// The bundled review record (`Content/knee-right.review.json`) validated against `region`, or its refusal; the
    /// file is read once per process and the result kept for the last region asked for.
    public static func bundled(for region: AnatomyRegion) -> Result<AnatomyReviewRecord, ContentRefusal> {
        ReviewRecordCache.shared.record(for: region)
    }

    /// The bytes of the bundled record, or nil when the resource is missing.
    static func bundledData() -> Data? {
        guard let url = Bundle.module.url(forResource: bundledResource, withExtension: "json", subdirectory: "Content")
        else { return nil }
        return try? Data(contentsOf: url)
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

/// The payload of a review record; property names are the JSON keys.
private struct RecordPayload: Decodable {
    let contentVersion: Int
    let entries: [AnatomyReviewEntry]
}

/// The bundled record's bytes (read once) and the result for the last region, behind a lock.
private final class ReviewRecordCache: @unchecked Sendable {
    /// The one cache of the process.
    static let shared = ReviewRecordCache()

    /// Guards every field.
    private let lock = NSLock()
    /// The bundled bytes; nil until read, `.some(nil)` when missing.
    private var data: Data??
    /// The last region asked for and its result.
    private var last: (region: AnatomyRegion, result: Result<AnatomyReviewRecord, ContentRefusal>)?

    /// The bundled record validated against `region`.
    func record(for region: AnatomyRegion) -> Result<AnatomyReviewRecord, ContentRefusal> {
        lock.lock()
        defer { lock.unlock() }
        if let last, last.region == region { return last.result }
        if data == nil { data = .some(AnatomyReviewRecord.bundledData()) }
        let result: Result<AnatomyReviewRecord, ContentRefusal>
        if let bytes = data ?? nil {
            result = AnatomyReviewRecord.decode(bytes, region: region)
        } else {
            result = .failure(ContentRefusal(.damaged, "The bundled file knee-right.review.json is missing."))
        }
        last = (region, result)
        return result
    }
}
