// SourcesDocumentTests — feature 126 (A17-P03) T-A17-304 (FR-A17-308; clarification Q5). The generated table of
// sources in `docs/apps/interactive-anatomy/content-sources.md`: one row per part (Part | Standard name | Citations |
// Licenses) built from the bundled content, between `<!-- BEGIN GENERATED -->` and `<!-- END GENERATED -->`. The test
// fails when the committed table differs; run the core tests with `UPDATE_DATA_SOURCES=1` (or
// `TEST_RUNNER_UPDATE_DATA_SOURCES=1` through xcodebuild) to rewrite the block.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

/// The opening marker of the generated block.
private let sourcesBeginMarker = "<!-- BEGIN GENERATED -->\n"
/// The closing marker of the generated block.
private let sourcesEndMarker = "<!-- END GENERATED -->"

/// The generated table: a header, a separator and one row per part in inventory order; citations as
/// "Title, edition, section" joined by "; ", licenses distinct in citation order joined by ", ".
private func sourcesTable(_ region: AnatomyRegion) -> String {
    var lines = ["| Part | Standard name | Citations | Licenses |", "|---|---|---|---|"]
    for part in region.structures where part.parent != nil {
        let cited = part.sourceRefs.compactMap { id in region.manifest.citations.first { $0.id == id } }
        var licenses: [String] = []
        for citation in cited where !licenses.contains(citation.license) { licenses.append(citation.license) }
        let works = cited.map { "\($0.title), \($0.edition), \($0.section)" }.joined(separator: "; ")
        lines.append("| \(part.englishName) | \(part.standardName) | \(works) | \(licenses.joined(separator: ", ")) |")
    }
    return lines.joined(separator: "\n") + "\n"
}

/// The text between the markers of `document`, or nil when a marker is missing.
private func sourcesBlock(_ document: String) -> String? {
    guard let begin = document.range(of: sourcesBeginMarker),
          let end = document.range(of: sourcesEndMarker, range: begin.upperBound..<document.endIndex) else { return nil }
    return String(document[begin.upperBound..<end.lowerBound])
}

@Suite struct SourcesDocumentTests {
    @Test func theTableListsEveryPartWithItsCitationsAndLicenses() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let table = sourcesTable(region)
        let rows = table.split(separator: "\n")
        #expect(rows.count == 16)
        #expect(rows.contains(
            "| Femur | Femur | Anatomy of the Human Body, 20th (1918), Osteology: The Femur; Terminologia Anatomica, 1998, Lower limb; Interactive Anatomy descriptions, 1, All structures | public-domain, facts, original |"))
        for part in region.structures where part.parent != nil {
            #expect(table.contains("| \(part.englishName) | \(part.standardName) |"), "\(part.id)")
        }
        #expect(sourcesBlock("a\n\(sourcesBeginMarker)x\n\(sourcesEndMarker)\n") == "x\n")
        #expect(sourcesBlock("no markers") == nil)
    }

    /// The committed document's generated block equals the table; reads the repository through `#filePath`, so it
    /// runs from the repository's own package, not from a scratch copy.
    @Test func theCommittedSourcesDocumentMatchesTheContent() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/interactive-anatomy/content-sources.md")
        let table = sourcesTable(try AnatomyContent.bundledRightKnee())
        let environment = ProcessInfo.processInfo.environment
        if environment["UPDATE_DATA_SOURCES"] == "1" || environment["TEST_RUNNER_UPDATE_DATA_SOURCES"] == "1" {
            let document = try String(contentsOf: file, encoding: .utf8)
            let begin = try #require(document.range(of: sourcesBeginMarker))
            let end = try #require(document.range(of: sourcesEndMarker, range: begin.upperBound..<document.endIndex))
            let rewritten = document.replacingCharacters(in: begin.upperBound..<end.lowerBound, with: table)
            try Data(rewritten.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        let block = try #require(sourcesBlock(committed), "the document has both markers")
        #expect(block == table, "run with UPDATE_DATA_SOURCES=1 and commit the document")
    }
}
