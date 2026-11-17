// ReviewRecordTests — feature 128 (A17-P05) T-A17-502 (FR-A17-501–504; SC-A17-501, SC-A17-502; clarifications Q1–Q3;
// data-model "AnatomyReviewRecord"). The review record: the bundled record is valid, has one editorial entry for each
// of the 14 parts (the lead engineer's role, 2026-11-16, the method, the part's Gray's Anatomy and Terminologia
// Anatomica citations) and no clinical entry, so every part reads the editorial line and "Not reviewed by a
// clinician."; each kind of invalid record is refused with its named reason; a clinical entry changes only its own
// part's lines; without a record only the not-reviewed line is shown.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

/// The method of every editorial entry (clarification Q2).
private let editorialMethod =
    "Name and description read against the cited Gray's Anatomy (1918) section and Terminologia Anatomica (1998)."

/// One entry as a JSON object.
private func entryObject(part: String, kind: String = "editorial", reviewer: String = "Lead engineer (editorial review)",
                         date: String = "2026-11-16", method: String = editorialMethod,
                         sources: [String] = ["ta-1998"]) -> [String: Any] {
    ["part": part, "kind": kind, "reviewer": reviewer, "date": date, "method": method, "sources": sources]
}

/// A review record file around `entries` for `contentVersion`, with the envelope `kind` and `schemaVersion`.
private func recordFile(_ entries: [[String: Any]], contentVersion: Int = 2, kind: String = AnatomyReviewRecord.kind,
                        schemaVersion: Int = 1) throws -> Data {
    let object: [String: Any] = ["kind": kind, "schemaVersion": schemaVersion, "savedAt": "2026-11-16T00:00:00Z",
                                 "payload": ["contentVersion": contentVersion, "entries": entries]]
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
}

/// The refusal reason of `data` against `region`, or nil when it decodes.
private func reason(_ data: Data, _ region: AnatomyRegion) -> ContentRefusal.Reason? {
    if case .failure(let refusal) = AnatomyReviewRecord.decode(data, region: region) { return refusal.reason }
    return nil
}

@Suite struct ReviewRecordTests {
    /// The bundled knee.
    private static func region() throws -> AnatomyRegion { try AnatomyContent.bundledRightKnee() }

    @Test func theBundledRecordHasOneEditorialEntryPerPartAndNoClinicalEntry() throws {
        let region = try Self.region()
        let record = try AnatomyReviewRecord.bundled(for: region).get()
        let parts = region.structures.filter { $0.parent != nil }
        #expect(parts.count == 14)
        #expect(record.contentVersion == region.contentVersion)
        #expect(record.entries.filter { $0.kind == .editorial }.count == 14)
        #expect(record.entries.filter { $0.kind == .clinical }.isEmpty)
        let gray = Set(region.manifest.citations
            .filter { ["Anatomy of the Human Body", "Terminologia Anatomica"].contains($0.title) }.map(\.id))
        for part in parts {
            let entries = record.entries(for: part.id)
            #expect(entries.count == 1, "\(part.id)")
            let entry = try #require(entries.first)
            #expect(entry.reviewer == "Lead engineer (editorial review)")
            #expect(entry.date == "2026-11-16")
            #expect(entry.method == editorialMethod)
            #expect(entry.sources == part.sourceRefs.filter { gray.contains($0) }, "\(part.id)")
            #expect(entry.sources.count == 2, "\(part.id) cites Gray's Anatomy and Terminologia Anatomica")
            let lines = AnatomyReview.lines(partID: part.id, record: record)
            #expect(lines == ["Text checked against its sources by the lead engineer on 2026-11-16.",
                              "Not reviewed by a clinician."], "\(part.id)")
        }
        let again = AnatomyReviewRecord.bundled(for: region)
        #expect(again == .success(record), "the cached record is the same")
    }

    @Test func theModelStatementAndTheLinesWithoutARecord() {
        #expect(AnatomyReview.modelStatement == "Schematic model for learning; shapes are simplified.")
        #expect(AnatomyReview.lines(partID: "knee.femur", record: nil) == ["Not reviewed by a clinician."])
        let empty = AnatomyReviewRecord(contentVersion: 2, entries: [])
        #expect(AnatomyReview.lines(partID: "knee.femur", record: empty) == ["Not reviewed by a clinician."])
    }

    @Test func theEnvelopeIsChecked() throws {
        let region = try Self.region()
        let valid = [entryObject(part: "knee.femur")]
        #expect(reason(try recordFile(valid), region) == nil)
        #expect(reason(Data("not json".utf8), region) == .damaged)
        #expect(reason(Data("{}".utf8), region) == .damaged)
        #expect(reason(try recordFile(valid, kind: "a17.view"), region) == .damaged)
        #expect(reason(try recordFile(valid, schemaVersion: 2), region) == .newerVersion)
        #expect(reason(try recordFile(valid, schemaVersion: 0), region) == .damaged)
        #expect(reason(try recordFile([entryObject(part: "knee.femur", kind: "surgical")]), region) == .damaged)
        #expect(reason(Data(count: AnatomyReviewRecord.maxBytes + 1), region) == .tooLarge)
    }

    @Test func anotherContentVersionIsRefused() throws {
        let region = try Self.region()
        let valid = [entryObject(part: "knee.femur")]
        #expect(reason(try recordFile(valid, contentVersion: region.contentVersion + 1), region) == .newerVersion)
        #expect(reason(try recordFile(valid, contentVersion: region.contentVersion - 1), region) == .damaged)
    }

    @Test func eachInvalidEntryIsRefusedWithItsReason() throws {
        let region = try Self.region()
        let cases: [(name: String, entries: [[String: Any]], reason: ContentRefusal.Reason)] = [
            ("unknown part", [entryObject(part: "knee.hip")], .missingReference),
            ("the root is not a part", [entryObject(part: "knee.joint")], .missingReference),
            ("empty reviewer", [entryObject(part: "knee.femur", reviewer: " ")], .emptyText),
            ("empty date", [entryObject(part: "knee.femur", date: "")], .emptyText),
            ("empty method", [entryObject(part: "knee.femur", method: "")], .emptyText),
            ("clinical without a reviewer", [entryObject(part: "knee.femur", kind: "clinical", reviewer: "")],
             .emptyText),
            ("bad date", [entryObject(part: "knee.femur", date: "16/11/2026")], .damaged),
            ("impossible date", [entryObject(part: "knee.femur", date: "2026-02-30")], .damaged),
            ("unknown source", [entryObject(part: "knee.femur", sources: ["gray-1918-tibia"])], .missingReference),
            ("duplicate", [entryObject(part: "knee.femur"), entryObject(part: "knee.femur")], .duplicateID),
        ]
        for item in cases {
            let got = reason(try recordFile(item.entries), region)
            #expect(got == item.reason, "\(item.name)")
        }
        let both = [entryObject(part: "knee.femur"),
                    entryObject(part: "knee.femur", kind: "clinical", reviewer: "A. Clinician", method: "Read.")]
        #expect(reason(try recordFile(both), region) == nil, "one editorial and one clinical entry are not duplicates")
    }

    @Test func aClinicalEntryChangesOnlyItsOwnPartsLines() throws {
        let region = try Self.region()
        let bundled = try AnatomyReviewRecord.bundled(for: region).get()
        let clinical = AnatomyReviewEntry(part: "knee.acl", kind: .clinical, reviewer: "A. Clinician",
                                          date: "2027-01-05", method: "Read every sentence.", sources: ["ta-1998"])
        let record = AnatomyReviewRecord(contentVersion: bundled.contentVersion, entries: bundled.entries + [clinical])
        #expect(AnatomyReviewRecord.validate(record.entries, region: region) == nil)
        for part in region.structures where part.parent != nil {
            let lines = AnatomyReview.lines(partID: part.id, record: record)
            if part.id == "knee.acl" {
                #expect(lines == ["Text checked against its sources by the lead engineer on 2026-11-16.",
                                  "Reviewed by A. Clinician on 2027-01-05."])
            } else {
                #expect(lines == AnatomyReview.lines(partID: part.id, record: bundled), "\(part.id)")
            }
        }
    }

    @Test func isoDates() {
        #expect(AnatomyReviewRecord.isISODate("2026-11-16"))
        #expect(AnatomyReviewRecord.isISODate("2028-02-29"))
        #expect(!AnatomyReviewRecord.isISODate("2026-13-01"))
        #expect(!AnatomyReviewRecord.isISODate("2026-1-01"))
        #expect(!AnatomyReviewRecord.isISODate("2026-11-16T00:00:00Z"))
        #expect(!AnatomyReviewRecord.isISODate("２０２６-11-16"))
    }
}
