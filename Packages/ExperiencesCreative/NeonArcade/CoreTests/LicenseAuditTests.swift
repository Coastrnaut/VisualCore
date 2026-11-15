// LicenseAuditTests — feature 075 (A10-P01) T-A10-103 (FR-A10-113; clarification 5; SC-A10-104). The content license
// audit, host-free and short: one row per catalog item with role, id, name, author and license and none missing an
// author or license; no problems for the bundled catalog; a missing author, a missing license and an unsupported
// license are each named; the Markdown document has the title, the table header and every item, and is deterministic.
// A10-P02 (feature 076, T-A10-202; FR-A10-222): the four spawn patterns follow the items as rows with role `pattern`,
// author "VisualCore project" and license "MIT"; a pattern's broken record is named like an item's.
import Foundation
import Testing
import NeonArcadeCore

@Suite struct LicenseAuditTests {
    private let catalog = ArcadeCatalog.bundled

    @Test func everyItemHasOneRowWithAuthorAndLicense() {
        let rows = LicenseAudit.rows(catalog)
        #expect(rows.count == catalog.items.count + PatternTable.bundled.count)
        #expect(rows.map(\.id) == catalog.items.map(\.id) + ["rain", "wall", "zigzag", "orb-trail"])
        #expect(rows.map(\.role) == [.player, .hazard, .hazard, .orb, .pattern, .pattern, .pattern, .pattern])
        #expect(rows.filter { $0.role == .pattern }.map(\.name) == ["Rain", "Wall", "Zigzag", "Orb trail"])
        #expect(LicenseAudit.rows(catalog, patterns: []).count == catalog.items.count)
        #expect(rows.allSatisfy { !$0.author.isEmpty && !$0.license.isEmpty })
        #expect(rows.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
    }

    @Test func theBundledCatalogHasNoProblems() {
        #expect(LicenseAudit.problems(catalog).isEmpty)
    }

    @Test func missingOrUnsupportedRecordsAreNamed() {
        var broken = catalog
        broken.items[0].author = ""
        broken.items[1].license = " "
        broken.items[3].license = "CC-BY-NC-4.0"
        #expect(LicenseAudit.problems(broken) == ["player chevron: missing-license",
                                                  "hazard spike-ball: missing-license",
                                                  "orb glow-orb: unsupported-license"])
        #expect(LicenseAudit.markdown(broken).contains("3 problems."))
        var patterns = PatternTable.bundled
        patterns[1].license = "CC-BY-4.0"
        patterns[2].author = ""
        #expect(LicenseAudit.problems(catalog, patterns: patterns) == ["pattern wall: unsupported-license",
                                                                       "pattern zigzag: missing-license"])
        #expect(LicenseAudit.markdown(catalog, patterns: patterns).contains("2 problems."))
    }

    @Test func theMarkdownListsEveryItemDeterministically() {
        let text = LicenseAudit.markdown(catalog)
        #expect(text.hasPrefix("# Neon Arcade — content licenses\n"))
        #expect(text.contains("| Role | Id | Name | Author | License |\n|---|---|---|---|---|\n"))
        for row in LicenseAudit.rows(catalog) {
            #expect(text.contains("| \(row.role.rawValue) | \(row.id) | \(row.name) | VisualCore project | MIT |"))
        }
        #expect(text.contains("| hazard | bar | Bar | VisualCore project | MIT |"))
        #expect(text.contains("| pattern | wall | Wall | VisualCore project | MIT |"))
        #expect(text.contains("| pattern | orb-trail | Orb trail | VisualCore project | MIT |"))
        #expect(text.contains("PatternTable.bundled"))
        #expect(text.contains("8 entries (1 player, 2 hazards, 1 orb, 4 patterns); 0 problems."))
        #expect(text.hasSuffix("\n") && !text.contains("\r"))
        #expect(LicenseAudit.markdown(catalog) == text)
    }

    @Test func cellTextIsEscaped() {
        var odd = catalog
        odd.items[0].name = "Pipe | and\nbreak"
        #expect(LicenseAudit.markdown(odd).contains("| player | chevron | Pipe \\| and break | VisualCore project |"))
    }

    /// T-A10-108 (FR-A10-113): the committed `docs/apps/neon-arcade/content-licenses.md` is the audit's Markdown of the
    /// bundled catalog, so it lists every item. `UPDATE_SCENARIO_MANIFEST=1` (on the simulator
    /// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedLicenseDocumentMatchesTheCatalog() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/neon-arcade/content-licenses.md")
        let text = LicenseAudit.markdown(catalog)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" {
            try Data(text.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        #expect(committed == text, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the document")
        for row in LicenseAudit.rows(catalog) { #expect(committed.contains(row.id), "\(row.id) is listed") }
    }
}
