// LicenseAuditTests — feature 068 (A09-P01) T-A09-102 (FR-A09-104; clarification 3; SC-A09-103). The content license
// audit, host-free and short: one row per species, plant and habitat with author and license; no problems for the
// bundled catalog; a missing author, a missing license and an unsupported license are each named; the Markdown document
// has the title, the table header and every id, and is deterministic.
// Feature 069 (A09-P02) T-A09-203 (FR-A09-212): decor kinds are audited too, after the plants and before the habitats.
import Foundation
import Testing
import DigitalAquariumCore

@Suite struct LicenseAuditTests {
    private let catalog = SpeciesCatalog.bundled

    @Test func everyItemHasOneRowWithAuthorAndLicense() {
        let rows = LicenseAudit.rows(catalog)
        #expect(rows.count == catalog.species.count + catalog.plants.count + catalog.decor.count
                + catalog.habitats.count)
        #expect(rows.map(\.id) == catalog.species.map(\.id) + catalog.plants.map(\.id) + catalog.decor.map(\.id)
                + catalog.habitats.map(\.id))
        #expect(catalog.decor.count == 3)
        #expect(rows.filter { $0.kind == .decor }.map(\.id) == ["round-rock", "flat-rock", "spiral-shell"])
        #expect(rows.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(rows.filter { $0.kind == .species }.count == catalog.species.count)
        #expect(rows.filter { $0.kind == .plant }.count == catalog.plants.count)
        #expect(rows.filter { $0.kind == .habitat }.count == catalog.habitats.count)
    }

    @Test func theBundledCatalogHasNoProblems() {
        #expect(LicenseAudit.problems(catalog).isEmpty)
    }

    @Test func missingOrUnsupportedRecordsAreNamed() {
        var broken = catalog
        broken.species[0].author = ""
        broken.plants[1].license = ""
        broken.habitats[0].license = "CC-BY-NC-4.0"
        let problems = LicenseAudit.problems(broken)
        #expect(problems == ["species \(catalog.species[0].id): missing-license",
                             "plant \(catalog.plants[1].id): missing-license",
                             "habitat \(catalog.habitats[0].id): unsupported-license"])
        #expect(LicenseAudit.markdown(broken).contains("3 problems."))
        var shell = catalog
        shell.decor[2].license = "CC-BY-SA-4.0"
        shell.decor[0].author = " "
        #expect(LicenseAudit.problems(shell) == ["decor round-rock: missing-license",
                                                 "decor spiral-shell: unsupported-license"])
    }

    @Test func theMarkdownListsEveryItemDeterministically() {
        let text = LicenseAudit.markdown(catalog)
        #expect(text.hasPrefix("# Digital Aquarium — content licenses\n"))
        #expect(text.contains("| Kind | Id | Name | Author | License |\n|---|---|---|---|---|\n"))
        for row in LicenseAudit.rows(catalog) {
            #expect(text.contains("| \(row.kind.rawValue) | \(row.id) | \(row.name) | VisualCore project | MIT |"))
        }
        #expect(text.contains("0 problems."))
        #expect(text.contains("3 decor kinds"))
        #expect(text.contains("| decor | spiral-shell | Spiral shell | VisualCore project | MIT |"))
        #expect(text.hasSuffix("\n") && !text.contains("\r"))
        #expect(LicenseAudit.markdown(catalog) == text)
    }

    @Test func tableCellsAreEscaped() {
        var odd = catalog
        odd.species[0].name = "Pipe | fish\nline"
        #expect(LicenseAudit.markdown(odd).contains("| Pipe \\| fish line |"))
    }

    /// T-A09-106 (FR-A09-104): the committed `docs/apps/digital-aquarium/content-licenses.md` is the audit's Markdown of
    /// the bundled catalog, so it lists every item. `UPDATE_SCENARIO_MANIFEST=1` (on the simulator
    /// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedLicenseDocumentMatchesTheCatalog() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/digital-aquarium/content-licenses.md")
        let text = LicenseAudit.markdown(catalog)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" {
            try Data(text.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        #expect(committed == text, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the document")
        for row in LicenseAudit.rows(catalog) { #expect(committed.contains(row.id), "\(row.id) is listed") }
    }
}
