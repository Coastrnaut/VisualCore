// LicenseAuditTests — feature 082 (A11-P01) T-A11-103 (FR-A11-114; clarification 3; SC-A11-106). The content license
// audit, host-free and short: one row per material with id, name, author and license; no problems for the bundled
// catalog; a missing author, a missing license and an unsupported license are each named; the Markdown document has
// the title, the table header and every material, and is deterministic. Feature 085 (A11-P04) T-A11-402 (FR-A11-431):
// the four presets (role preset) and the two tutorials (role tutorial) follow the materials, each with author and
// license, in a second table of the document.
import Foundation
import Testing
import PhysicsPlaygroundCore

@Suite struct LicenseAuditTests {
    private let catalog = MaterialCatalog.bundled

    @Test func everyMaterialHasOneRowWithAuthorAndLicense() {
        let rows = LicenseAudit.rows(catalog).filter { $0.role == LicenseAudit.materialRole }
        #expect(rows.map(\.id) == ["rubber", "wood", "steel", "ice"])
        #expect(rows.map(\.name) == ["Rubber", "Wood", "Steel", "Ice"])
        #expect(rows.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
    }

    @Test func presetsAndTutorialsFollowTheMaterialsWithTheirRoles() {
        let rows = LicenseAudit.rows(catalog)
        #expect(rows.map(\.role) == Array(repeating: "material", count: 4) + Array(repeating: "preset", count: 4)
                + ["tutorial", "tutorial"])
        #expect(rows.dropFirst(4).map(\.id) == ["free-play", "pendulum", "spring-chain", "stacked-objects",
                                                "controlling-time", "springs-and-energy"])
        #expect(rows.dropFirst(4).map(\.name) == ["Free play", "Pendulum", "Spring chain", "Stacked objects",
                                                  "Controlling time", "Springs and energy"])
        #expect(rows.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(LicenseAudit.contentRows() == Array(rows.dropFirst(4)))
        var broken = LicenseAudit.contentRows()
        broken[1].license = "CC-BY-4.0"
        broken[5].author = ""
        #expect(LicenseAudit.problems(broken) == ["preset pendulum: unsupported-license",
                                                  "tutorial springs-and-energy: missing-license"])
    }

    @Test func theBundledCatalogHasNoProblems() {
        #expect(LicenseAudit.problems(catalog).isEmpty)
    }

    @Test func missingOrUnsupportedRecordsAreNamed() {
        var broken = catalog
        broken.materials[0].author = ""
        broken.materials[2].license = " "
        broken.materials[3].license = "GPL-3.0"
        #expect(LicenseAudit.problems(broken) == ["material rubber: missing-license",
                                                  "material steel: missing-license",
                                                  "material ice: unsupported-license"])
        #expect(LicenseAudit.markdown(broken).hasSuffix("4 materials, 4 presets, 2 tutorials; 3 problems.\n"))
    }

    @Test func theMarkdownListsEveryMaterialDeterministically() {
        let text = LicenseAudit.markdown(catalog)
        #expect(text.hasPrefix("# Physics Playground — content licenses\n"))
        #expect(text.contains("| Id | Name | Density (kg/m²) | Restitution | Friction | Author | License |\n"
                              + "|---|---|---|---|---|---|---|\n"))
        #expect(text.contains("| rubber | Rubber | 1.2 | 0.8 | 0.9 | VisualCore project | MIT |"))
        #expect(text.contains("| wood | Wood | 0.6 | 0.4 | 0.5 | VisualCore project | MIT |"))
        #expect(text.contains("| steel | Steel | 7.8 | 0.25 | 0.4 | VisualCore project | MIT |"))
        #expect(text.contains("| ice | Ice | 0.9 | 0.1 | 0.05 | VisualCore project | MIT |"))
        #expect(text.contains("educational approximations"))
        #expect(text.contains("| Id | Role | Name | Author | License |\n|---|---|---|---|---|\n"))
        #expect(text.contains("| free-play | preset | Free play | VisualCore project | MIT |"))
        #expect(text.contains("| pendulum | preset | Pendulum | VisualCore project | MIT |"))
        #expect(text.contains("| spring-chain | preset | Spring chain | VisualCore project | MIT |"))
        #expect(text.contains("| stacked-objects | preset | Stacked objects | VisualCore project | MIT |"))
        #expect(text.contains("| controlling-time | tutorial | Controlling time | VisualCore project | MIT |"))
        #expect(text.contains("| springs-and-energy | tutorial | Springs and energy | VisualCore project | MIT |"))
        #expect(text.hasSuffix("4 materials, 4 presets, 2 tutorials; 0 problems.\n") && !text.contains("\r"))
        #expect(LicenseAudit.markdown(catalog) == text)
        var piped = catalog
        piped.materials[0].name = "Rub|ber\nX"
        #expect(LicenseAudit.markdown(piped).contains("| rubber | Rub\\|ber X | 1.2 |"))
    }

    /// T-A11-108 (FR-A11-114): the committed `docs/apps/physics-playground/content-licenses.md` is the audit's Markdown
    /// of the bundled catalog, so it lists every material. `UPDATE_SCENARIO_MANIFEST=1` (on the simulator
    /// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) rewrites it.
    @Test func theCommittedLicenseDocumentMatchesTheCatalog() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/physics-playground/content-licenses.md")
        let text = LicenseAudit.markdown(catalog)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" {
            try Data(text.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        #expect(committed == text, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the document")
        for row in LicenseAudit.rows(catalog) { #expect(committed.contains(row.id), "\(row.id) is listed") }
    }
}
