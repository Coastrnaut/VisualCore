// ReviewDocumentTests — feature 128 (A17-P05) T-A17-502 (FR-A17-506; SC-A17-504; clarification Q4). The generated
// review table in `docs/apps/interactive-anatomy/review.md`: one row per part (Part | Sources checked | Editorial
// review | Clinical review) built from the bundled content and its review record, between `<!-- BEGIN GENERATED -->`
// and `<!-- END GENERATED -->`. The test fails when the committed table differs; run the core tests with
// `UPDATE_DATA_SOURCES=1` (or `TEST_RUNNER_UPDATE_DATA_SOURCES=1` through xcodebuild) to rewrite the block. The prose
// around the block is written by hand and never touched.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

/// The opening marker of the generated block.
private let reviewBeginMarker = "<!-- BEGIN GENERATED -->\n"
/// The closing marker of the generated block.
private let reviewEndMarker = "<!-- END GENERATED -->"

/// The generated table: a header, a separator and one row per part in inventory order; the sources checked as
/// "Title, edition, section" joined by "; ", each review as "<reviewer>, <date>" and a missing clinical review as
/// "not reviewed".
private func reviewTable(_ region: AnatomyRegion, _ record: AnatomyReviewRecord) -> String {
    var lines = ["| Part | Sources checked | Editorial review | Clinical review |", "|---|---|---|---|"]
    for part in region.structures where part.parent != nil {
        let entries = record.entries(for: part.id)
        let editorial = entries.first { $0.kind == .editorial }
        let clinical = entries.first { $0.kind == .clinical }
        let sources = (editorial?.sources ?? []).compactMap { id in region.manifest.citations.first { $0.id == id } }
            .map { "\($0.title), \($0.edition), \($0.section)" }.joined(separator: "; ")
        let editorialText = editorial.map { "\($0.reviewer), \($0.date)" } ?? "not reviewed"
        let clinicalText = clinical.map { "\($0.reviewer), \($0.date)" } ?? "not reviewed"
        lines.append("| \(part.englishName) | \(sources) | \(editorialText) | \(clinicalText) |")
    }
    return lines.joined(separator: "\n") + "\n"
}

/// The text between the markers of `document`, or nil when a marker is missing.
private func reviewBlock(_ document: String) -> String? {
    guard let begin = document.range(of: reviewBeginMarker),
          let end = document.range(of: reviewEndMarker, range: begin.upperBound..<document.endIndex) else { return nil }
    return String(document[begin.upperBound..<end.lowerBound])
}

@Suite struct ReviewDocumentTests {
    @Test func theTableListsEveryPartWithItsSourcesAndReviews() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let record = try AnatomyReviewRecord.bundled(for: region).get()
        let table = reviewTable(region, record)
        let rows = table.split(separator: "\n")
        #expect(rows.count == 16)
        #expect(rows.contains(
            "| Femur | Anatomy of the Human Body, 20th (1918), Osteology: The Femur; Terminologia Anatomica, 1998, Lower limb | Lead engineer (editorial review), 2026-11-16 | not reviewed |"))
        for part in region.structures where part.parent != nil {
            #expect(table.contains("| \(part.englishName) | "), "\(part.id)")
        }
        #expect(rows.dropFirst(2).allSatisfy { $0.hasSuffix("| Lead engineer (editorial review), 2026-11-16 | not reviewed |") })
        #expect(reviewBlock("a\n\(reviewBeginMarker)x\n\(reviewEndMarker)\n") == "x\n")
        #expect(reviewBlock("no markers") == nil)
    }

    /// The committed document's generated block equals the table; reads the repository through `#filePath`, so it
    /// runs from the repository's own package, not from a scratch copy.
    @Test func theCommittedReviewDocumentMatchesTheRecord() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/interactive-anatomy/review.md")
        let region = try AnatomyContent.bundledRightKnee()
        let table = reviewTable(region, try AnatomyReviewRecord.bundled(for: region).get())
        let environment = ProcessInfo.processInfo.environment
        if environment["UPDATE_DATA_SOURCES"] == "1" || environment["TEST_RUNNER_UPDATE_DATA_SOURCES"] == "1" {
            let document = try String(contentsOf: file, encoding: .utf8)
            let begin = try #require(document.range(of: reviewBeginMarker))
            let end = try #require(document.range(of: reviewEndMarker, range: begin.upperBound..<document.endIndex))
            let rewritten = document.replacingCharacters(in: begin.upperBound..<end.lowerBound, with: table)
            try Data(rewritten.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        let block = try #require(reviewBlock(committed), "the document has both markers")
        #expect(block == table, "run with UPDATE_DATA_SOURCES=1 and commit the document")
    }
}
