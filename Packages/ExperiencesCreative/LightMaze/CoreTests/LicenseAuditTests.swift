// LicenseAuditTests — feature 096 (A13-P01) T-A13-103 (FR-A13-114; clarification Q4; SC-A13-104). The content license
// audit, host-free and short: one row per level with id, name, size, tile count, author and license; no problems for
// the bundled catalog; a missing author, a missing license and an unsupported license are each named; the Markdown
// document has the title, the table with every level and the summary line, escapes table cells and is deterministic.
// (The committed document is compared by T-A13-108.)
import Foundation
import LightMazeCore
import Testing

@Suite struct LicenseAuditTests {
    private let catalog = LevelCatalog.bundled

    @Test func everyLevelHasOneRowWithAuthorAndLicense() {
        let rows = LicenseAudit.rows(catalog)
        #expect(rows.map(\.id) == catalog.levels.map(\.id))
        #expect(rows.map(\.name) == catalog.levels.map(\.name))
        #expect(rows.map(\.tiles) == catalog.levels.map { $0.board.tiles.count })
        #expect(rows[0].size == "5×5" && rows[0].tiles == 4)
        #expect(rows.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
    }

    @Test func theBundledCatalogHasNoProblems() {
        #expect(LicenseAudit.problems(catalog).isEmpty)
    }

    @Test func missingOrUnsupportedLevelsAreNamed() {
        var broken = catalog
        broken.levels[0].author = ""
        broken.levels[4].license = " "
        broken.levels[9].license = "GPL-3.0"
        #expect(LicenseAudit.problems(broken) == ["level lm-01: missing-license", "level lm-05: missing-license",
                                                  "level lm-10: unsupported-license"])
        #expect(LicenseAudit.markdown(broken).hasSuffix("20 levels; 3 problems.\n"))
    }

    @Test func theMarkdownListsEveryLevelDeterministically() {
        let text = LicenseAudit.markdown(catalog)
        #expect(text.hasPrefix("# Light Maze — content licenses\n"))
        #expect(text.contains("Allowed licenses: MIT."))
        #expect(text.contains("| Id | Name | Size | Tiles | Author | License |\n|---|---|---|---|---|---|\n"))
        #expect(text.contains("| lm-01 | First light | 5×5 | 4 | VisualCore project | MIT |"))
        for level in catalog.levels {
            let size = "\(level.board.width)×\(level.board.height)"
            #expect(text.contains("| \(level.id) | \(level.name) | \(size) | \(level.board.tiles.count) | "
                                  + "VisualCore project | MIT |"))
        }
        #expect(text.hasSuffix("\n20 levels; 0 problems.\n"))
        #expect(LicenseAudit.markdown(catalog) == text)
        var piped = catalog
        piped.levels[0].name = "First|light\nX"
        piped.levels[1].name = ""
        let pipedText = LicenseAudit.markdown(piped)
        #expect(pipedText.contains("| lm-01 | First\\|light X | 5×5 |"))
        #expect(pipedText.contains("| lm-02 | — |"))
        #expect(LicenseAudit.markdown(LevelCatalog(levels: [catalog.levels[0]])).hasSuffix("1 level; 0 problems.\n"))
    }

    /// The committed `docs/apps/light-maze/content-licenses.md` equals the generated document (T-A13-108); run the
    /// package tests with `UPDATE_SCENARIO_MANIFEST=1` to rewrite it. Reads the repository through `#filePath`, so it
    /// runs from the repository's own package, not from a symlinked scratch copy.
    @Test func theCommittedLicenseDocumentMatchesTheCatalog() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/light-maze/content-licenses.md")
        let text = LicenseAudit.markdown(catalog)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" {
            try Data(text.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        #expect(committed == text, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the document")
        for row in LicenseAudit.rows(catalog) { #expect(committed.contains(row.id), "\(row.id) is listed") }
    }
}
