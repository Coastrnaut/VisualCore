// MoleculeReviewTests — feature 114 (A15-P05) T-A15-504 (FR-A15-520, FR-A15-521; clarification Q5; SC-A15-504). The
// scientific review, host-free and short: the two statements; the claim words of clarification Q5 and the whole-word,
// case-insensitive matcher on positive and negative examples; the review document lists every element's five values
// with units, source and license, every library molecule with formula, counts, source and license, and both
// statements, is deterministic with LF line endings and a final newline, and holds no claim word outside the
// publishers' proper names; the committed `docs/apps/molecular-explorer/data-review.md` equals it.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct MoleculeReviewTests {
    @Test func theStatementsAndClaimWordsAreFixed() {
        #expect(MoleculeReview.inferredStatement == "Bonds marked inferred are estimated from atom distances.")
        #expect(MoleculeReview.displayStatement == "Display radii, not measured sizes.")
        #expect(MoleculeReview.claimWords == ["safe", "safety", "toxic", "toxicity", "poison", "hazard", "hazardous",
                                              "medical", "medicine", "medicinal", "drug", "therapy", "therapeutic",
                                              "cure", "treatment", "dose", "health", "stimulant"])
        #expect(MoleculeReview.claimWords(in: MoleculeReview.inferredStatement).isEmpty)
        #expect(MoleculeReview.claimWords(in: MoleculeReview.displayStatement).isEmpty)
    }

    @Test func claimWordsAreMatchedAsWholeWordsIgnoringCase() {
        let positive: [(String, [String])] = [
            ("Caffeine is a Stimulant.", ["stimulant"]),
            ("SAFE to handle", ["safe"]),
            ("toxic; Toxicity, and a poison.", ["toxic", "toxicity", "poison"]),
            ("Medical-grade medicine", ["medical", "medicine"]),
            ("a drug for therapy (therapeutic) and a cure", ["drug", "therapy", "therapeutic", "cure"]),
            ("dose: health hazard, hazardous treatment", ["dose", "health", "hazard", "hazardous", "treatment"]),
            ("safe and safe again", ["safe"]),
            ("medicinal\nsafety", ["medicinal", "safety"]),
        ]
        for (sentence, words) in positive {
            #expect(MoleculeReview.claimWords(in: sentence) == words, "\(sentence)")
        }
        let negative: [String] = [
            "unsafe", "safely", "drugstore", "curator", "dosage", "healthy", "Bonds marked inferred",
            "Caffeine — C8H10N4O2", "Nitrogen (N), atom 3 of 24", "Covalent radius 0.71 Å", "", "secure",
        ]
        for sentence in negative {
            #expect(MoleculeReview.claimWords(in: sentence).isEmpty, "\(sentence)")
        }
    }

    @Test func theDocumentListsEveryValueAndBothStatements() {
        let text = MoleculeReview.document()
        #expect(text.hasPrefix("# Molecular Explorer — data review\n"))
        #expect(text.hasSuffix("\n") && !text.hasSuffix("\n\n") && !text.contains("\r"))
        #expect(text == MoleculeReview.document(), "deterministic")
        #expect(text.contains("| Hydrogen (H) | covalent-radius | 0.31 | Å | Covalent radii revisited"))
        #expect(text.contains("| Hydrogen (H) | van-der-waals-radius | 1.20 | Å | PubChem Periodic Table of Elements |"))
        #expect(text.contains("| Iodine (I) | color | `940094` | — | PubChem Periodic Table of Elements |"))
        #expect(text.contains("| Chlorine (Cl) | atomic-number | 17 | — |"))
        for element in Elements.all {
            for quantity in ElementQuantity.allCases {
                #expect(text.contains("| \(element.name) (\(element.symbol)) | \(quantity.rawValue) | "),
                        "\(element.symbol) \(quantity.rawValue)")
            }
        }
        for record in Elements.sources { #expect(text.contains("| \(record.license) |")) }
        #expect(text.contains("| Caffeine | C8H10N4O2 | 24 | 25 | Å | PubChem Compound CID 2519, 3D conformer |"))
        #expect(text.contains("| Water | H2O | 3 | 2 | Å | PubChem Compound CID 962, 3D conformer |"))
        for molecule in MoleculeLibrary.molecules {
            #expect(text.contains("| \(molecule.title) | \(molecule.formula) | \(molecule.atoms.count) | "
                                  + "\(molecule.bonds.count) |"), "\(molecule.id)")
        }
        #expect(text.contains("- Display radii, not measured sizes."))
        #expect(text.contains("- Bonds marked inferred are estimated from atom distances."))
        #expect(text.contains("\"imported file\"") && text.contains("`own-data`"))
        var lines = 0
        for line in text.split(separator: "\n") where line.hasPrefix("| ") && !line.hasPrefix("| Element ")
            && !line.hasPrefix("| Molecule ") {
            lines += 1
        }
        #expect(lines == 55, "50 element values and 5 molecules")
    }

    @Test func theDocumentHoldsNoClaimWord() {
        // The publishers' names are proper names (the National Library of Medicine), not claims; the rest of the
        // document must hold no claim word.
        var text = MoleculeReview.document()
        let names: [String] = [SourceRecord.pubChemPublisher, SourceRecord.corderoPublisher]
        for name in names { text = text.replacingOccurrences(of: name, with: "") }
        #expect(MoleculeReview.claimWords(in: text).isEmpty, "\(MoleculeReview.claimWords(in: text))")
    }

    /// The committed `docs/apps/molecular-explorer/data-review.md` equals the generated document; run the package
    /// tests with `UPDATE_DATA_REVIEW=1` (or `TEST_RUNNER_UPDATE_DATA_REVIEW=1` through xcodebuild) to rewrite it.
    /// Reads the repository through `#filePath`, so it runs from the repository's own package, not from a scratch
    /// copy.
    @Test func theCommittedDataReviewMatchesTheData() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/molecular-explorer/data-review.md")
        let text = MoleculeReview.document()
        let environment = ProcessInfo.processInfo.environment
        if environment["UPDATE_DATA_REVIEW"] == "1" || environment["TEST_RUNNER_UPDATE_DATA_REVIEW"] == "1" {
            try Data(text.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        #expect(committed == text, "run with UPDATE_DATA_REVIEW=1 and commit the document")
        #expect(committed.contains(MoleculeReview.inferredStatement))
    }
}
