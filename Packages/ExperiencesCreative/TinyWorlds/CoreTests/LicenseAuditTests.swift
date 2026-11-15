// LicenseAuditTests — feature 089 (A12-P01) T-A12-103 (FR-A12-113; clarification 5; G-CONTENTLICENSES; SC-A12-105).
// The content license audit, host-free and short: one row per preset (role preset) and then per palette (role palette)
// with id, name, author and license; no problems for the bundled catalog; a missing author, a missing license and an
// unsupported license are each named; the Markdown document has the title, both tables with every record and the
// summary line, and is deterministic. (The committed document is compared by T-A12-108.)
import Foundation
import Testing
import TinyWorldsCore

@Suite struct LicenseAuditTests {
    private let catalog = ContentCatalog.bundled

    @Test func everyPresetAndPaletteHasOneRowWithAuthorAndLicense() {
        let rows = LicenseAudit.rows(catalog)
        #expect(rows.map(\.role) == [.preset, .preset, .preset, .palette, .palette, .palette])
        #expect(rows.map(\.id) == ["island", "asteroid-garden", "miniature-city",
                                   "island", "asteroid-garden", "miniature-city"])
        #expect(rows.map(\.name) == ["Island", "Asteroid garden", "Miniature city",
                                     "Island", "Asteroid garden", "Miniature city"])
        #expect(rows.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
    }

    @Test func theBundledCatalogHasNoProblems() {
        #expect(LicenseAudit.problems(catalog).isEmpty)
    }

    @Test func missingOrUnsupportedRecordsAreNamed() {
        var broken = catalog
        broken.presets[0].author = ""
        broken.presets[2].license = " "
        broken.palettes[1].license = "GPL-3.0"
        #expect(LicenseAudit.problems(broken) == ["preset island: missing-license",
                                                  "preset miniature-city: missing-license",
                                                  "palette asteroid-garden: unsupported-license"])
        #expect(LicenseAudit.markdown(broken).hasSuffix("3 presets, 3 palettes; 3 problems.\n"))
    }

    @Test func theMarkdownListsEveryRecordDeterministically() {
        let text = LicenseAudit.markdown(catalog)
        #expect(text.hasPrefix("# Tiny Worlds — content licenses\n"))
        #expect(text.contains("Allowed licenses: MIT."))
        #expect(text.contains("| Id | Name | Palette | Author | License |\n|---|---|---|---|---|\n"))
        #expect(text.contains("| island | Island | island | VisualCore project | MIT |"))
        #expect(text.contains("| asteroid-garden | Asteroid garden | asteroid-garden | VisualCore project | MIT |"))
        #expect(text.contains("| miniature-city | Miniature city | miniature-city | VisualCore project | MIT |"))
        #expect(text.contains("| Id | Name | Sea or void | Low land | High land | Author | License |\n"
                              + "|---|---|---|---|---|---|---|\n"))
        for palette in catalog.palettes {
            let colours = palette.colors.map(LicenseAudit.hex).joined(separator: " | ")
            #expect(text.contains("| \(palette.id) | \(palette.name) | \(colours) | VisualCore project | MIT |"))
        }
        #expect(text.contains("| island | Island | #296B9E | #5C9E4D | #B8A880 | VisualCore project | MIT |"))
        #expect(text.hasSuffix("3 presets, 3 palettes; 0 problems.\n") && !text.contains("\r"))
        #expect(LicenseAudit.markdown(catalog) == text)
        var piped = catalog
        piped.presets[0].name = "Is|land\nX"
        #expect(LicenseAudit.markdown(piped).contains("| island | Is\\|land X | island |"))
    }

    @Test func coloursAreWrittenAsHexadecimal() {
        #expect(LicenseAudit.hex(RGBA(0, 0.5, 1)) == "#0080FF")
        #expect(LicenseAudit.hex(RGBA(1, 1, 1, 0.5)) == "#FFFFFF/80")
        #expect(LicenseAudit.hex(RGBA(.nan, 0, 0)) == "?")
    }
}
