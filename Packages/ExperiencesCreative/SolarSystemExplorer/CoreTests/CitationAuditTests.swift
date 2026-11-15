// CitationAuditTests — feature 103 (A14-P01) T-A14-102, T-A14-106 (FR-A14-110; clarification Q1; SC-A14-103). The
// citation audit, host-free and short: one record per stored value (34) with the NSSDCA Planetary Fact Sheet, the IAU
// 2015 B3 nominal solar radius and the Sun Fact Sheet; 0 problems for the bundled catalog; each damaged-record fixture
// (a value without a record, a duplicate record, a record without source, epoch or units, wrong units, an unsupported
// or missing license, a record for a missing value) is refused with its reason naming the body id and the quantity;
// the Markdown document has the title, the table with every value and the closing count, LF line endings and a final
// newline, and is deterministic; the committed `docs/apps/solar-system-explorer/data-sources.md` equals it.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct CitationAuditTests {
    private let catalog = BodyCatalog.bundled

    /// `record` with one field replaced.
    private func changed(_ record: SourceRecord, title: String? = nil, publisher: String? = nil, link: String? = nil,
                         epoch: String? = nil, units: String? = nil, license: String? = nil) -> SourceRecord {
        SourceRecord(bodyID: record.bodyID, quantity: record.quantity, title: title ?? record.title,
                     publisher: publisher ?? record.publisher, link: link ?? record.link, epoch: epoch ?? record.epoch,
                     units: units ?? record.units, license: license ?? record.license)
    }

    /// The bundled catalog with its sources replaced.
    private func withSources(_ sources: [SourceRecord]) -> BodyCatalog {
        BodyCatalog(bodies: catalog.bodies, sources: sources)
    }

    @Test func everyStoredValueHasOneRecord() {
        #expect(catalog.sources.count == 34 && SourceRecord.bundled == catalog.sources)
        #expect(CitationAudit.allowedLicenses == ["public-domain", "CC0-1.0"])
        let sun: [SourceRecord] = catalog.sources.filter { $0.bodyID == "sun" }
        #expect(sun.map(\.quantity) == ["mean-radius", "axial-tilt"])
        #expect(sun[0].title == "Resolution B3 on recommended nominal conversion constants")
        #expect(sun[0].publisher == "International Astronomical Union (2015)" && sun[0].epoch == "nominal")
        #expect(sun[1].title == "Sun Fact Sheet" && sun[1].units == "degrees" && sun[1].epoch == "J2000.0")
        let planets: [SourceRecord] = catalog.sources.filter { $0.bodyID != "sun" }
        #expect(planets.count == 32)
        for record in planets {
            #expect(record.title == "Planetary Fact Sheet — Metric", "\(record.bodyID) \(record.quantity)")
            #expect(record.publisher == "NASA Space Science Data Coordinated Archive (D. R. Williams, NASA Goddard "
                    + "Space Flight Center)")
            #expect(record.link == "nssdc.gsfc.nasa.gov/planetary/factsheet" && record.epoch == "J2000.0")
        }
        #expect(catalog.sources.allSatisfy { $0.license == "public-domain" })
        let units: [String] = catalog.sources.map(\.units)
        #expect(Set(units) == ["km", "days", "degrees"])
        #expect(catalog.source(bodyID: "jupiter", quantity: .siderealPeriod)?.units == "days")
    }

    @Test func theBundledCatalogHasNoProblems() {
        #expect(CitationAudit.problems(catalog).isEmpty)
    }

    @Test func eachDamagedRecordIsRefusedWithItsReason() {
        let sources: [SourceRecord] = catalog.sources
        var damaged = sources
        damaged.remove(at: 2)
        #expect(CitationAudit.problems(withSources(damaged)) == ["mercury mean-radius: no source record"])
        damaged = sources + [sources[5]]
        #expect(CitationAudit.problems(withSources(damaged)) == ["mercury axial-tilt: duplicate source record"])
        let fixtures: [(Int, SourceRecord, String)] = [
            (6, changed(sources[6], title: ""), "venus mean-radius: missing source"),
            (7, changed(sources[7], publisher: " "), "venus semi-major-axis: missing source"),
            (8, changed(sources[8], link: ""), "venus sidereal-period: missing source"),
            (9, changed(sources[9], epoch: ""), "venus axial-tilt: missing epoch"),
            (10, changed(sources[10], units: ""), "earth mean-radius: missing units"),
            (11, changed(sources[11], units: "AU"), "earth semi-major-axis: wrong units AU"),
            (12, changed(sources[12], license: "CC-BY-4.0"), "earth sidereal-period: unsupported license CC-BY-4.0"),
            (0, changed(sources[0], license: ""), "sun mean-radius: unsupported license (none)"),
        ]
        for (index, record, problem) in fixtures {
            damaged = sources
            damaged[index] = record
            #expect(CitationAudit.problems(withSources(damaged)) == [problem], "\(problem)")
        }
        damaged = sources
        damaged[13] = changed(sources[13], license: "CC0-1.0")
        #expect(CitationAudit.problems(withSources(damaged)).isEmpty, "CC0-1.0 is allowed")
        let orphan = SourceRecord(bodyID: "sun", quantity: "semi-major-axis", title: "T", publisher: "P", link: "L",
                                  epoch: "J2000.0", units: "km", license: "public-domain")
        let plutoRecord = SourceRecord(bodyID: "pluto", quantity: "mean-radius", title: "T", publisher: "P",
                                       link: "L", epoch: "J2000.0", units: "km", license: "public-domain")
        #expect(CitationAudit.problems(withSources(sources + [orphan, plutoRecord])) == [
            "sun semi-major-axis: source record without a value", "pluto mean-radius: source record without a value",
        ])
        damaged = sources
        damaged[3] = changed(sources[3], title: "", epoch: "", license: "GPL")
        #expect(CitationAudit.problems(withSources(damaged)) == [
            "mercury semi-major-axis: missing source", "mercury semi-major-axis: missing epoch",
            "mercury semi-major-axis: unsupported license GPL",
        ])
        #expect(CitationAudit.markdown(withSources(damaged)).hasSuffix("\n34 values; 3 problems.\n"))
    }

    @Test func theMarkdownListsEveryValueDeterministically() {
        let text = CitationAudit.markdown(catalog)
        #expect(text.hasPrefix("# Solar System Explorer — data sources\n\n"))
        #expect(text.contains("1 AU = 149,597,870.7 km") && text.contains("Allowed licenses: public-domain, CC0-1.0."))
        #expect(text.contains("| Body | Quantity | Value | Units | Source | Epoch | License |\n"
                              + "|---|---|---|---|---|---|---|\n"))
        #expect(text.contains("| Sun | mean-radius | 695,700 | km | Resolution B3 on recommended nominal conversion "
                              + "constants, International Astronomical Union (2015) "
                              + "(iau.org/static/resolutions/IAU2015_English.pdf) | nominal | public-domain |"))
        #expect(text.contains("| Neptune | semi-major-axis | 4,514,953,000 | km | Planetary Fact Sheet — Metric, NASA "
                              + "Space Science Data Coordinated Archive (D. R. Williams, NASA Goddard Space Flight "
                              + "Center) (nssdc.gsfc.nasa.gov/planetary/factsheet) | J2000.0 | public-domain |"))
        #expect(text.contains("| Mercury | axial-tilt | 0.034 | degrees |"))
        let rows: [Substring] = text.split(separator: "\n").filter { $0.hasPrefix("| ") && !$0.hasPrefix("| Body") }
        #expect(rows.count == 34)
        #expect(text.hasSuffix("\n34 values; 0 problems.\n"))
        #expect(!text.contains("\r") && !text.hasSuffix("\n\n"))
        #expect(CitationAudit.markdown(catalog) == text)
        let piped = BodyCatalog(bodies: [catalog.bodies[0]], sources: [changed(catalog.sources[0], title: "A|B\nC")])
        let pipedText = CitationAudit.markdown(piped)
        #expect(pipedText.contains("| Sun | mean-radius | 695,700 | km | A\\|B C, "))
        #expect(pipedText.contains("| Sun | axial-tilt | 7.25 | — | — | — | — |"))
        #expect(pipedText.hasSuffix("\n2 values; 1 problems.\n"))
        let single = BodyCatalog(bodies: [catalog.bodies[0]], sources: [])
        #expect(CitationAudit.markdown(BodyCatalog(bodies: [], sources: [])).hasSuffix("\n0 values; 0 problems.\n"))
        #expect(CitationAudit.problems(single).count == 2)
    }

    /// The committed `docs/apps/solar-system-explorer/data-sources.md` equals the generated document (T-A14-106); run
    /// the package tests with `UPDATE_DATA_SOURCES=1` (or `TEST_RUNNER_UPDATE_DATA_SOURCES=1` through xcodebuild) to
    /// rewrite it. Reads the repository through `#filePath`, so it runs from the repository's own package, not from a
    /// scratch copy.
    @Test func theCommittedDataSourcesDocumentMatchesTheCatalog() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/solar-system-explorer/data-sources.md")
        let text = CitationAudit.markdown(catalog)
        let environment = ProcessInfo.processInfo.environment
        if environment["UPDATE_DATA_SOURCES"] == "1" || environment["TEST_RUNNER_UPDATE_DATA_SOURCES"] == "1" {
            try Data(text.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        #expect(committed == text, "run with UPDATE_DATA_SOURCES=1 and commit the document")
        for body in catalog.bodies { #expect(committed.contains("| \(body.name) |"), "\(body.id) is listed") }
    }
}
