// RingRecordTests — feature 105 (A14-P03) T-A14-303 (FR-A14-302; clarification Q2; data-model "RingRecord"). Saturn's
// main rings: the sourced values in order, the Cassini division, the audit of the record and its sources (a missing,
// duplicate, damaged or orphan record is named) and the "Saturn's rings" section of the data-sources document.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct RingRecordTests {
    @Test func saturnsRingsHaveTheFactSheetValuesInOrder() {
        let ring = RingRecord.saturn
        #expect(ring.bodyID == "saturn")
        #expect(ring.innerKm == 74_500 && ring.cassiniInnerKm == 117_580)
        #expect(ring.cassiniOuterKm == 122_170 && ring.outerKm == 136_775)
        #expect(ring.problems.isEmpty)
        let saturnRadius = BodyCatalog.bundled.bodies.first { $0.id == "saturn" }?.meanRadiusKm ?? 0
        #expect(ring.innerKm > saturnRadius, "the rings lie outside the planet")
        #expect(ring.inCassiniDivision(120_000) && !ring.inCassiniDivision(100_000) && !ring.inCassiniDivision(130_000))
    }

    @Test func damagedRecordsAreRefused() {
        let disordered = RingRecord(bodyID: "saturn", innerKm: 130_000, cassiniInnerKm: 117_580,
                                    cassiniOuterKm: 122_170, outerKm: 136_775)
        #expect(disordered.problems == ["saturn rings: edges out of order"])
        let nan = RingRecord(bodyID: "saturn", innerKm: .nan, cassiniInnerKm: 1, cassiniOuterKm: 2, outerKm: 3)
        #expect(nan.problems == ["saturn rings: a value is not finite and positive"])
    }

    @Test func theRingSourcesAreAudited() {
        let records = SourceRecord.ringRecords
        #expect(records.count == 3 && CitationAudit.ringProblems().isEmpty)
        for record in records {
            #expect(record.epoch == "J2000.0" && record.units == "km" && record.license == "public-domain")
            #expect(record.link == "nssdc.gsfc.nasa.gov/planetary/factsheet/satringfact.html")
        }
        var damaged: [SourceRecord] = Array(records.dropFirst())
        damaged.append(records[1])
        let wrong = SourceRecord(bodyID: "saturn", quantity: "cassini-division", title: "t", publisher: "p",
                                 link: "l", epoch: "J2000.0", units: "AU", license: "CC-BY-4.0")
        damaged[1] = wrong
        let orphan = SourceRecord(bodyID: "uranus", quantity: "ring-inner-radius", title: "t", publisher: "p",
                                  link: "l", epoch: "J2000.0", units: "km", license: "public-domain")
        damaged.append(orphan)
        let problems = CitationAudit.ringProblems(.saturn, sources: damaged)
        #expect(problems.contains("saturn ring-inner-radius: no source record"))
        #expect(problems.contains("saturn ring-outer-radius: duplicate source record"))
        #expect(problems.contains("saturn cassini-division: wrong units AU"))
        #expect(problems.contains("saturn cassini-division: unsupported license CC-BY-4.0"))
        #expect(problems.contains("uranus ring-inner-radius: source record without a ring value"))
    }

    @Test func theDocumentListsTheRings() {
        let text = CitationAudit.markdown(.bundled)
        #expect(text.contains("## Saturn's rings\n"))
        #expect(text.contains("| ring-inner-radius | 74,500 | km | Saturnian Rings Fact Sheet, "))
        #expect(text.contains("| ring-outer-radius | 136,775 | km | "))
        #expect(text.contains("| cassini-division | 117,580–122,170 | km | "))
        #expect(text.hasSuffix(" values; 0 problems.\n"))
        let without = CitationAudit.markdown(.bundled, ring: nil)
        #expect(!without.contains("## Saturn's rings"))
    }
}
