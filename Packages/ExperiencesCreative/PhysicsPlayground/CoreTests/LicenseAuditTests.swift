// LicenseAuditTests — feature 082 (A11-P01) T-A11-103 (FR-A11-114; clarification 3; SC-A11-106). The content license
// audit, host-free and short: one row per material with id, name, author and license; no problems for the bundled
// catalog; a missing author, a missing license and an unsupported license are each named; the Markdown document has
// the title, the table header and every material, and is deterministic.
import Foundation
import Testing
import PhysicsPlaygroundCore

@Suite struct LicenseAuditTests {
    private let catalog = MaterialCatalog.bundled

    @Test func everyMaterialHasOneRowWithAuthorAndLicense() {
        let rows = LicenseAudit.rows(catalog)
        #expect(rows.map(\.id) == ["rubber", "wood", "steel", "ice"])
        #expect(rows.map(\.name) == ["Rubber", "Wood", "Steel", "Ice"])
        #expect(rows.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
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
        #expect(LicenseAudit.markdown(broken).hasSuffix("4 materials; 3 problems.\n"))
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
        #expect(text.hasSuffix("4 materials; 0 problems.\n") && !text.contains("\r"))
        #expect(LicenseAudit.markdown(catalog) == text)
        var piped = catalog
        piped.materials[0].name = "Rub|ber\nX"
        #expect(LicenseAudit.markdown(piped).contains("| rubber | Rub\\|ber X | 1.2 |"))
    }
}
