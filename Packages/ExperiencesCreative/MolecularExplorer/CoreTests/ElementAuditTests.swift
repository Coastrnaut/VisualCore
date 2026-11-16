// ElementAuditTests — feature 110 (A15-P01) T-A15-102, T-A15-105, T-A15-109 (FR-A15-101, FR-A15-130;
// clarifications Q1, Q2; SC-A15-101). The provenance audit, host-free and short: the allowed licenses; 0 problems for
// the bundled catalog and library; one damaged fixture per problem kind (a missing or duplicate source record, an empty
// title or publisher, wrong units, an unsupported license, a record without a value, a duplicate symbol or atomic
// number, a non-finite or out-of-range radius, a malformed colour; a molecule record with another key, no source,
// wrong units or an unsupported license), each named with its reason; the Markdown document has the title, the ten
// elements, the sources and the five molecules, LF line endings and a final newline, and is deterministic; the
// committed `docs/apps/molecular-explorer/data-sources.md` equals it.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct ElementAuditTests {
    /// `element` with one value replaced.
    private func changed(_ element: Element, symbol: String? = nil, atomicNumber: Int? = nil,
                         covalentRadius: Double? = nil, vanDerWaalsRadius: Double? = nil,
                         colorHex: String? = nil) -> Element {
        Element(symbol: symbol ?? element.symbol, name: element.name, atomicNumber: atomicNumber ?? element.atomicNumber,
                covalentRadius: covalentRadius ?? element.covalentRadius,
                vanDerWaalsRadius: vanDerWaalsRadius ?? element.vanDerWaalsRadius, colorHex: colorHex ?? element.colorHex)
    }

    /// `record` with one field replaced.
    private func changed(_ record: SourceRecord, key: String? = nil, title: String? = nil, publisher: String? = nil,
                         units: String? = nil, license: String? = nil) -> SourceRecord {
        SourceRecord(key: key ?? record.key, quantity: record.quantity, title: title ?? record.title,
                     publisher: publisher ?? record.publisher, link: record.link, units: units ?? record.units,
                     license: license ?? record.license)
    }

    /// The catalog's audit with element `index` replaced by `element`.
    private func elementProblems(replacing index: Int, with element: Element) -> [String] {
        var elements = Elements.all
        elements[index] = element
        return ElementAudit.problems(elements: elements, sources: Elements.sources)
    }

    /// The catalog's audit with source record `index` replaced by `record`.
    private func sourceProblems(replacing index: Int, with record: SourceRecord) -> [String] {
        var sources = Elements.sources
        sources[index] = record
        return ElementAudit.problems(elements: Elements.all, sources: sources)
    }

    /// Water with its structure record replaced by `record`.
    private func water(source record: SourceRecord) -> Molecule {
        let water = MoleculeLibrary.molecules[0]
        return Molecule(id: water.id, title: water.title, atoms: water.atoms, bonds: water.bonds, source: record)
    }

    @Test func theBundledDataHasNoProblems() {
        #expect(ElementAudit.allowedLicenses == ["public-domain", "CC0-1.0", "factual-data"])
        #expect(ElementAudit.problems(elements: Elements.all, sources: Elements.sources).isEmpty)
        #expect(ElementAudit.problems(molecules: MoleculeLibrary.molecules).isEmpty)
        #expect(ElementAudit.problems().isEmpty)
    }

    @Test func eachDamagedSourceRecordIsNamedWithItsReason() {
        let sources = Elements.sources
        // sources[0…4] are hydrogen's name, atomic-number, covalent-radius, van-der-waals-radius and color.
        var damaged = sources
        damaged.remove(at: 2)
        #expect(ElementAudit.problems(elements: Elements.all, sources: damaged)
                == ["H covalent-radius: no source record"])
        damaged = sources + [sources[3]]
        #expect(ElementAudit.problems(elements: Elements.all, sources: damaged)
                == ["H van-der-waals-radius: duplicate source record"])
        #expect(sourceProblems(replacing: 0, with: changed(sources[0], title: "")) == ["H name: missing source"])
        #expect(sourceProblems(replacing: 1, with: changed(sources[1], publisher: "  "))
                == ["H atomic-number: missing source"])
        #expect(sourceProblems(replacing: 3, with: changed(sources[3], units: "pm"))
                == ["H van-der-waals-radius: wrong units pm"])
        #expect(sourceProblems(replacing: 2, with: changed(sources[2], units: ""))
                == ["H covalent-radius: wrong units (none)"])
        #expect(sourceProblems(replacing: 4, with: changed(sources[4], license: "CC-BY-4.0"))
                == ["H color: unsupported license CC-BY-4.0"])
        #expect(sourceProblems(replacing: 4, with: changed(sources[4], license: ""))
                == ["H color: unsupported license (none)"])
        let orphan = changed(sources[0], key: "He")
        #expect(ElementAudit.problems(elements: Elements.all, sources: sources + [orphan])
                == ["He name: source record without a value"])
    }

    @Test func eachDamagedElementIsNamedWithItsReason() {
        let all = Elements.all
        let duplicateSymbol = changed(all[0], symbol: "h", atomicNumber: 99)
        var duplicateSources = Elements.sources
        for quantity in ElementQuantity.allCases {
            duplicateSources.append(Elements.record(symbol: "h", quantity: quantity))
        }
        #expect(ElementAudit.problems(elements: all + [duplicateSymbol], sources: duplicateSources)
                == ["h: duplicate symbol"])
        let duplicateNumber = changed(all[1], symbol: "Xx", atomicNumber: 1)
        var numberSources = Elements.sources
        for quantity in ElementQuantity.allCases {
            numberSources.append(Elements.record(symbol: "Xx", quantity: quantity))
        }
        #expect(ElementAudit.problems(elements: all + [duplicateNumber], sources: numberSources)
                == ["Xx: duplicate atomic number 1"])
        #expect(elementProblems(replacing: 1, with: changed(all[1], covalentRadius: .nan))
                == ["C covalent-radius: non-finite radius"])
        #expect(elementProblems(replacing: 2, with: changed(all[2], vanDerWaalsRadius: .infinity))
                == ["N van-der-waals-radius: non-finite radius"])
        #expect(elementProblems(replacing: 3, with: changed(all[3], covalentRadius: 0.05))
                == ["O covalent-radius: radius 0.05 outside 0.1…3.0 Å"])
        #expect(elementProblems(replacing: 9, with: changed(all[9], vanDerWaalsRadius: 3.5))
                == ["I van-der-waals-radius: radius 3.5 outside 0.1…3.0 Å"])
        #expect(elementProblems(replacing: 4, with: changed(all[4], covalentRadius: 0.1, vanDerWaalsRadius: 3.0))
                .isEmpty, "the radius limits are inclusive")
        let malformed: [String] = ["FFF", "#FFFFFF", "GGGGGG", "", "FFFFFFF"]
        for hex in malformed {
            let label = hex.isEmpty ? "(none)" : hex
            #expect(elementProblems(replacing: 5, with: changed(all[5], colorHex: hex))
                    == ["P color: malformed colour hex \(label)"], "\(hex)")
        }
        #expect(elementProblems(replacing: 5, with: changed(all[5], colorHex: "ff8000")).isEmpty)
    }

    @Test func eachDamagedMoleculeRecordIsNamedWithItsReason() {
        let source = MoleculeLibrary.molecules[0].source
        #expect(ElementAudit.problems(molecules: [water(source: changed(source, key: "methane"))])
                == ["water structure: source key methane"])
        #expect(ElementAudit.problems(molecules: [water(source: changed(source, title: ""))])
                == ["water structure: missing source"])
        #expect(ElementAudit.problems(molecules: [water(source: changed(source, publisher: ""))])
                == ["water structure: missing source"])
        #expect(ElementAudit.problems(molecules: [water(source: changed(source, units: "nm"))])
                == ["water structure: wrong units nm"])
        #expect(ElementAudit.problems(molecules: [water(source: changed(source, license: "proprietary"))])
                == ["water structure: unsupported license proprietary"])
    }

    @Test func theMarkdownDocumentListsElementsSourcesAndMolecules() {
        let text = ElementAudit.markdown()
        #expect(text.hasPrefix("# Molecular Explorer — data sources\n"))
        #expect(text.hasSuffix("10 elements, 50 element source records, 5 molecules; 0 problems.\n"))
        #expect(!text.contains("\r"))
        #expect(text == ElementAudit.markdown(), "deterministic")
        #expect(text.contains("| 1 | H | Hydrogen | 0.31 | 1.20 | `FFFFFF` |"))
        #expect(text.contains("| 17 | Cl | Chlorine | 1.02 | 1.75 | `1FF01F` |"))
        #expect(text.contains("| 53 | I | Iodine | 1.39 | 1.98 | `940094` |"))
        #expect(text.contains("| covalent-radius | Å | H, C, N, O, F, P, S, Cl, Br, I | Covalent radii revisited"))
        #expect(text.contains("| factual-data |") && text.contains("| public-domain |"))
        #expect(text.contains("| Caffeine | 2519 | C8H10N4O2 | 24 | 25 | PubChem Compound CID 2519, 3D conformer |"))
        #expect(text.contains("| Water | 962 | H2O | 3 | 2 |"))
        for element in Elements.all { #expect(text.contains("| \(element.name) |"), "\(element.symbol)") }
        for molecule in MoleculeLibrary.molecules { #expect(text.contains("| \(molecule.title) |"), "\(molecule.id)") }
    }

    /// The committed `docs/apps/molecular-explorer/data-sources.md` equals the generated document (T-A15-109); run
    /// the package tests with `UPDATE_DATA_SOURCES=1` (or `TEST_RUNNER_UPDATE_DATA_SOURCES=1` through xcodebuild) to
    /// rewrite it. Reads the repository through `#filePath`, so it runs from the repository's own package, not from a
    /// scratch copy.
    @Test func theCommittedDataSourcesDocumentMatchesTheData() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/molecular-explorer/data-sources.md")
        let text = ElementAudit.markdown()
        let environment = ProcessInfo.processInfo.environment
        if environment["UPDATE_DATA_SOURCES"] == "1" || environment["TEST_RUNNER_UPDATE_DATA_SOURCES"] == "1" {
            try Data(text.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        #expect(committed == text, "run with UPDATE_DATA_SOURCES=1 and commit the document")
        for element in Elements.all { #expect(committed.contains("| \(element.name) |"), "\(element.symbol) is listed") }
    }
}
