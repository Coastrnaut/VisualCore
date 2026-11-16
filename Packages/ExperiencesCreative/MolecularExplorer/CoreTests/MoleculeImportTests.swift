// MoleculeImportTests — feature 114 (A15-P05) T-A15-503 (FR-A15-502, FR-A15-503; clarifications Q2, Q3; SC-A15-502).
// The words and actions of an import, host-free and short: the size refusal at 65,536 / 65,537 bytes; one fixed
// sentence per parser reason, with " (line N)" before the period where a line is known; the unreadable sentence;
// titles from file names (extension dropped, markup stripped, long names cut to 40 characters, empty and symbol-only
// names giving "Imported molecule", letters of other scripts kept); water's action list; and every refusal fixture of
// the parser giving its sentence.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct MoleculeImportTests {
    @Test func theSizeIsCheckedAtTheParserLimit() {
        #expect(MoleculeImport.maxBytes == 65_536 && MoleculeImport.titleLimit == 40)
        #expect(MoleculeImport.sizeRefusal(byteCount: 65_536) == nil)
        #expect(MoleculeImport.sizeRefusal(byteCount: 0) == nil)
        #expect(MoleculeImport.sizeRefusal(byteCount: 65_537)
                == "This file is larger than 64 KB, the limit for a molecule file.")
        #expect(MoleculeImport.sizeRefusal(byteCount: Int.max) == MoleculeImport.tooLargeSentence)
        #expect(MoleculeImport.unreadableSentence == "The file could not be read.")
    }

    @Test func everyReasonHasItsOwnSentence() {
        let expected: [XYZRefusal.Reason: String] = [
            .empty: "the file is empty",
            .tooLarge: "the file is larger than 64 KB",
            .notText: "the file is not plain text",
            .badCount: "the first line is not a whole atom count",
            .tooManyAtoms: "more atoms than this explorer can show (at most 500)",
            .countMismatch: "the number of atom lines differs from the atom count",
            .lineTooLong: "a line longer than 256 bytes",
            .malformedLine: "a line that is not an element and three coordinates",
            .unknownElement: "an element this explorer does not know",
            .nonFinite: "a coordinate that is not a number",
            .outOfRange: "a coordinate beyond 1,000 Å",
            .overlappingAtoms: "two atoms closer than 0.4 Å",
        ]
        #expect(expected.count == XYZRefusal.Reason.allCases.count)
        var sentences: Set<String> = []
        for reason in XYZRefusal.Reason.allCases {
            let phrase = expected[reason] ?? ""
            #expect(MoleculeImport.phrase(reason) == phrase, "\(reason)")
            #expect(MoleculeImport.sentence(XYZRefusal(reason)) == "This file could not be opened: \(phrase).")
            let lined = MoleculeImport.sentence(XYZRefusal(reason, line: 7))
            #expect(lined == "This file could not be opened: \(phrase) (line 7).", "\(reason)")
            sentences.insert(lined)
            #expect(MoleculeReview.claimWords(in: lined).isEmpty, "\(reason)")
        }
        #expect(sentences.count == 12, "one distinct sentence per reason")
    }

    @Test func eachRefusalFixtureGivesItsSentence() {
        let fixtures: [(String, String)] = [
            ("", "This file could not be opened: the file is empty."),
            ("-3\nx\nO 0 0 0\n", "This file could not be opened: the first line is not a whole atom count (line 1)."),
            ("501\nx\n", "This file could not be opened: more atoms than this explorer can show (at most 500) (line 1)."),
            ("2\nx\nO 0 0 0\n", "This file could not be opened: the number of atom lines differs from the atom count (line 1)."),
            ("1\nx\nO 0 0\n", "This file could not be opened: a line that is not an element and three coordinates (line 3)."),
            ("1\nx\nXe 0 0 0\n", "This file could not be opened: an element this explorer does not know (line 3)."),
            ("2\nx\nO 0 0 0\nH nan 0 0\n", "This file could not be opened: a coordinate that is not a number (line 4)."),
            ("1\nx\nO 0 0 1000.5\n", "This file could not be opened: a coordinate beyond 1,000 Å (line 3)."),
            ("2\nx\nO 0 0 0\nH 0.1 0 0\n", "This file could not be opened: two atoms closer than 0.4 Å (line 4)."),
        ]
        for (text, sentence) in fixtures {
            guard case .failure(let refusal) = XYZParser.parse(text) else {
                Issue.record("\(text) parsed")
                continue
            }
            #expect(MoleculeImport.sentence(refusal) == sentence, "\(text)")
        }
        let long = "1\n" + "x\n" + "O 0 0 0" + String(repeating: " ", count: 300) + "\n"
        if case .failure(let refusal) = XYZParser.parse(long) {
            #expect(MoleculeImport.sentence(refusal) == "This file could not be opened: a line longer than 256 bytes (line 3).")
        }
        if case .failure(let refusal) = XYZParser.parse(Data([0x31, 0x0A, 0xFF, 0xFE])) {
            #expect(MoleculeImport.sentence(refusal) == "This file could not be opened: the file is not plain text.")
        }
    }

    @Test func titlesComeFromTheFileName() {
        let cases: [(String, String)] = [
            ("water.xyz", "water"),
            ("My molecule (v2).xyz", "My molecule (v2)"),
            ("ring_C6-H6.final.xyz", "ring_C6-H6.final"),
            ("<script>alert(1)</script>.xyz", "scriptalert(1)script"),
            ("<b>bold</b> & \"quoted\"; name.XYZ", "bboldb  quoted name"),
            ("", "Imported molecule"),
            (".xyz", "Imported molecule"),
            ("<>&;!?.xyz", "Imported molecule"),
            ("   .xyz", "Imported molecule"),
            ("Café Ünïcode 分子.xyz", "Café Ünïcode 分子"),
            ("caffeine ☕️ cup.xyz", "caffeine  cup"),
            ("tab\tand\nnewline.xyz", "tabandnewline"),
            ("noextension", "noextension"),
        ]
        for (name, title) in cases {
            #expect(MoleculeImport.title(fileName: name) == title, "\(name)")
        }
        let long = String(repeating: "abcdefghij", count: 8) + ".xyz"
        #expect(MoleculeImport.title(fileName: long) == String(repeating: "abcdefghij", count: 4))
        let spaced = String(repeating: "a", count: 39) + "   tail.xyz"
        #expect(MoleculeImport.title(fileName: spaced) == String(repeating: "a", count: 39), "trimmed after the cut")
        let wide = String(repeating: "é", count: 50) + ".xyz"
        #expect(MoleculeImport.title(fileName: wide).count == 40)
        #expect(MoleculeImport.title(fileName: "  padded name  .xyz") == "padded name")
    }

    @Test func waterBecomesItsActionList() throws {
        let parsed = try XYZParser.parse(MoleculeLibraryData.records[0].xyz).get()
        let actions = MoleculeImport.actions(parsed)
        let controls = actions.map(\.control)
        #expect(controls == ["import.begin", "import.atom", "import.atom", "import.atom", "import.end", "molecule.select"])
        let values = actions.map(\.values)
        #expect(values == [[3], [8, 0, 0, 0], [1, 0.2774, 0.8929, 0.2544], [1, 0.6068, -0.2383, -0.7169], [], [5]])
        // The actions rebuild the same atoms in the state.
        var state = MoleculeState.initial
        var accepted = state.beginImport(count: Int(values[0][0]))
        for value in values[1...3] {
            guard let atom = ImportedMolecule.atom(atomicNumber: Int(value[0]), x: value[1], y: value[2], z: value[3])
            else { Issue.record("atom \(value)"); continue }
            accepted = accepted && state.addImportedAtom(atom)
        }
        #expect(accepted && (try? state.endImport().get()) != nil)
        accepted = state.select(Int(values[5][0]))
        #expect(accepted && state.molecule?.atoms == MoleculeLibrary.molecules[0].atoms)
        for record in MoleculeLibraryData.records {
            let library = try XYZParser.parse(record.xyz).get()
            #expect(MoleculeImport.actions(library).count == library.atoms.count + 3, "\(record.id)")
        }
    }
}
