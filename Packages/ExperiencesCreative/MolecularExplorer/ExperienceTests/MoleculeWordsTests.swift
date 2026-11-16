// MoleculeWordsTests — feature 114 (A15-P05) T-A15-510 (FR-A15-521; SC-A15-504; clarification Q5). Every sentence
// Molecular Explorer can show, gathered from the words helpers of the core (`MoleculeImport`, `MoleculeCore`), the
// presenter (`MoleculePresenter`), the importer (`MoleculeImporter`), the stores (`RecentStore`, `SettingsStore`) and
// the controls (`MoleculeControls`), host-free: every library molecule's name, counts, source and status lines and its
// library entry words; every atom's panel lines, bond lines and canvas description in both display modes; the
// legends; every import refusal sentence (each `XYZRefusal.Reason` with and without a line, the size refusal and the
// unreadable sentence); the import, keep-failed and gone words; the store read and save words for every refusal reason
// and storage code; the answers to refused actions; the camera, zoom and pan words; the controls' static labels and
// hints; and the lines of a molecule imported into a core. None holds a claim word of `MoleculeReview.claimWords`, and
// the panel shows both statements (the legend ends with `MoleculeReview.displayStatement`, the `inferred-note` line
// is `MoleculeReview.inferredStatement`). T-A15-516 adds a scan of every string literal in the experience's sources,
// so the inline control labels and hints are checked too. Plain loops, no session, no prompt, no network; well under a second.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreUI

/// No sentence Molecular Explorer shows makes a safety, toxicity, medical or therapeutic claim, and the panel shows
/// the display and inferred-bond statements.
@MainActor
final class MoleculeWordsTests: XCTestCase {
    /// The publishers' proper names, removed from a sentence before it is checked: "National Library of Medicine
    /// (NCBI)" names the publisher of PubChem and is not a medical claim, exactly as
    /// `CoreTests/MoleculeReviewTests.swift` removes them from the review document. Nothing else is removed.
    private let publishers: [String] = [SourceRecord.pubChemPublisher, SourceRecord.corderoPublisher]

    /// Every storage error code a store or the importer can show.
    private let storageCodes: [String] = [
        StorageError.invalidName("x").code, StorageError.reservedName("x").code, StorageError.quotaExceeded("x").code,
        StorageError.notFound("x").code, StorageError.writeFailed("x").code, StorageError.tooLarge(1).code,
    ]

    /// Every reason a stored document is refused for.
    private let documentRefusals: [DocumentRefusal] = [.damaged, .oversized, .newerVersion, .outOfRange]

    /// A small valid XYZ fixture: hydrogen chloride, one inferred bond.
    private let fixture = "2\nHCl\nCl 0 0 0\nH 1.27 0 0\n"

    /// Applies `control` with `values` to `core` as the engine does: the declared count and ranges first, then the
    /// core's own rules.
    private func applied(_ control: String, _ values: [Double] = [], to core: inout MoleculeCore) -> ActionResult {
        if let rejection = ExperienceInput.validate(control: control, values: values, controls: MoleculeCore.controls) {
            return .rejected(rejection)
        }
        return core.apply(ExperienceAction(control: control, values: values, step: 0))
    }

    /// The library sentences: name, counts, source and status lines, the library entry words, the menu words and,
    /// for every atom, its panel lines, bond lines and canvas description in both modes.
    private func librarySentences() -> [String] {
        var sentences: [String] = []
        let count = MoleculeCore.moleculeCount
        for index in 0..<count {
            sentences.append(MoleculeCore.title(index: index))
            sentences.append(MoleculeCore.nameLine(index: index))
            sentences.append(MoleculeCore.countsLine(index: index))
            sentences.append(MoleculeCore.sourceLine(index: index))
            sentences.append(MoleculeCore.status(selection: index))
            sentences.append(MoleculeControls.sentence(MoleculeCore.status(selection: index)))
            sentences.append(MoleculeControls.moleculeWords(index: index, count: count))
            sentences += MoleculeControls.libraryWords(index: index)
            for mode in DisplayMode.allCases {
                sentences.append(MoleculeCore.canvasDescription(selection: index, mode: mode))
            }
            guard let molecule = MoleculeCore.molecule(index: index) else { continue }
            sentences.append(MoleculeCore.elementNames(molecule).joined(separator: ", "))
            for atom in molecule.atoms.indices {
                sentences += MoleculePresenter.atomPanel(molecule, atom: atom)
                sentences += MoleculePresenter.bondLines(molecule, atom: atom)
                for mode in DisplayMode.allCases {
                    sentences.append(MoleculeCore.canvasDescription(selection: index, mode: mode, atom: atom))
                }
            }
        }
        sentences.append(MoleculeCore.title(index: count + 3))
        sentences.append(MoleculeCore.nameLine(index: count + 3))
        sentences.append(MoleculeCore.canvasDescription(molecule: nil))
        sentences.append(MoleculeControls.sentence(""))
        sentences.append(MoleculeControls.recentValue([]))
        sentences.append(MoleculeControls.recentValue(MoleculeControls.moleculeTitles))
        sentences.append(MoleculeControls.noRecentWords)
        sentences += MoleculeControls.moleculeTitles
        sentences += MoleculePresenter.recentTitles(RecentStore.libraryIDs.sorted() + [ImportedMolecule.id])
        return sentences
    }

    /// The import sentences: every parser reason with and without a line, the size refusal, the unreadable
    /// sentence, the engine refusal, the importer and presenter words, and the fallback title.
    private func importSentences() -> [String] {
        var sentences: [String] = []
        for reason in XYZRefusal.Reason.allCases {
            sentences.append(MoleculeImport.phrase(reason))
            sentences.append(MoleculeImport.sentence(XYZRefusal(reason)))
            sentences.append(MoleculeImport.sentence(XYZRefusal(reason, line: 3)))
        }
        sentences.append(MoleculeImport.sizeRefusal(byteCount: MoleculeImport.maxBytes + 1) ?? "")
        sentences.append(MoleculeImport.tooLargeSentence)
        sentences.append(MoleculeImport.unreadableSentence)
        sentences.append(MoleculeImport.fallbackTitle)
        sentences.append(MoleculeImporter.engineRefusalSentence("action.rule." + MoleculeRule.invalidImport))
        sentences.append(MoleculePresenter.importedWords(title: "hydrogen chloride", atoms: 2))
        sentences.append(MoleculePresenter.importedWords(title: MoleculeImport.fallbackTitle, atoms: 1))
        for code in storageCodes { sentences.append(MoleculePresenter.keepFailedWords(code)) }
        sentences.append(MoleculePresenter.importGoneWords)
        sentences.append(MoleculePresenter.inferredNote)
        sentences.append(MoleculeControls.importLabel)
        sentences.append(MoleculeControls.importHint)
        return sentences
    }

    /// The store messages: the read words of every refusal reason and storage code, and the save words of every
    /// storage code, for the recent list and the settings.
    private func storeSentences() -> [String] {
        var sentences: [String] = []
        for refusal in documentRefusals {
            sentences.append(RecentStore.readWords(.refused(refusal)))
            sentences.append(SettingsStore.readWords(.refused(refusal)))
        }
        for code in storageCodes {
            sentences.append(RecentStore.readWords(.unreadable(code)))
            sentences.append(SettingsStore.readWords(.unreadable(code)))
            sentences.append(RecentStore.saveWords(code))
            sentences.append(SettingsStore.saveWords(code))
        }
        return sentences
    }

    /// The control words: mode and label titles, legends, the answers to every refused action and the camera words
    /// at the ends of their ranges.
    private func controlSentences() -> [String] {
        var sentences: [String] = []
        for mode in DisplayMode.allCases {
            sentences.append(MoleculePresenter.modeTitle(mode))
            sentences.append(MoleculePresenter.legend(mode))
            sentences.append(mode.name)
        }
        for mode in LabelMode.allCases { sentences.append(MoleculePresenter.labelTitle(mode)) }
        let refused = ActionResult.rejected(.rule(code: MoleculeRule.invalidChoice))
        for control in MoleculeCore.actionIDs + ["bogus"] {
            sentences.append(MoleculePresenter.answerWords(control: control, result: refused))
        }
        sentences.append(MoleculePresenter.answerWords(control: "camera.pan",
                                                       result: .rejected(.rule(code: MoleculeRule.cameraLimit))))
        sentences.append(MoleculePresenter.noAtomWords)
        let cameras: [CameraSettings] = [
            .default,
            CameraSettings(turnSteps: 23, tiltSteps: CameraSettings.tiltRange.lowerBound,
                           zoomSteps: CameraSettings.zoomRange.lowerBound, panX: -10, panY: -10),
            CameraSettings(turnSteps: 0, tiltSteps: CameraSettings.tiltRange.upperBound,
                           zoomSteps: CameraSettings.zoomRange.upperBound, panX: 10, panY: 10),
        ]
        for camera in cameras {
            sentences.append(MoleculePresenter.cameraWords(camera))
            sentences.append(MoleculePresenter.zoomWords(camera))
            sentences.append(MoleculePresenter.panWords(camera))
        }
        return sentences
    }

    /// The lines of the fixture imported into a core: name, counts, source and status lines with the file's title,
    /// the descriptions, the menu words and every atom's panel and bond lines.
    private func importedSentences() throws -> [String] {
        var core = MoleculeCore(seed: 1)
        let parsed = try XYZParser.parse(fixture).get()
        for entry in MoleculeImport.actions(parsed) {
            XCTAssertTrue(applied(entry.control, entry.values, to: &core).isAccepted, entry.control)
        }
        let molecule = try XCTUnwrap(core.imported?.molecule)
        XCTAssertEqual(core.selection, MoleculeCore.importedSelection)
        let title = MoleculeImport.title(fileName: "hydrogen chloride.xyz")
        var sentences: [String] = [
            title, core.title, core.nameLine(), core.nameLine(title: title), core.countsLine, core.sourceLine,
            core.status(), core.status(title: title), core.canvasDescription, core.titledCanvasDescription(title),
            MoleculeControls.moleculeWords(title: title, index: core.selection, count: MoleculeCore.moleculeCount),
            MoleculeControls.sentence(core.status(title: title)),
        ]
        sentences += MoleculePresenter.recentTitles([ImportedMolecule.id, "water"], importedTitle: title)
        for atom in molecule.atoms.indices {
            sentences += MoleculePresenter.atomPanel(molecule, atom: atom)
            sentences += MoleculePresenter.bondLines(molecule, atom: atom)
            sentences.append(MoleculeCore.canvasDescription(molecule: molecule, atom: atom, title: title))
        }
        XCTAssertEqual(core.sourceLine, "imported file — your own data")
        return sentences
    }

    func testNoShownSentenceHoldsAClaimWord() throws {
        var sentences: [String] = []
        sentences += librarySentences()
        sentences += importSentences()
        sentences += storeSentences()
        sentences += controlSentences()
        sentences += try importedSentences()
        sentences.append(MoleculeReview.displayStatement)
        sentences.append(MoleculeReview.inferredStatement)
        // Five molecules with 53 atoms in all: the atoms' panel, bond and description lines alone pass 300.
        XCTAssertGreaterThanOrEqual(sentences.count, 400, "every source of words was gathered")
        var empty = 0
        var named = 0
        for sentence in sentences {
            if sentence.isEmpty { empty += 1 }
            var checked = sentence
            for publisher in publishers where checked.contains(publisher) {
                checked = checked.replacingOccurrences(of: publisher, with: "")
                named += 1
            }
            XCTAssertEqual(MoleculeReview.claimWords(in: checked), [], "claim word in: \(sentence)")
        }
        XCTAssertLessThanOrEqual(empty, 3, "only the out-of-library lines are empty")
        XCTAssertEqual(named, 0, "no shown sentence names a publisher; the source lines name the record")
        // The checker itself finds a claim word in a sentence of the same shape, so an empty result means something.
        XCTAssertEqual(MoleculeReview.claimWords(in: "Caffeine selected, a Stimulant"), ["stimulant"])
    }

    func testThePanelShowsBothStatements() throws {
        XCTAssertEqual(MoleculePresenter.inferredNote, MoleculeReview.inferredStatement)
        XCTAssertEqual(MoleculePresenter.legendNote, MoleculeReview.displayStatement)
        let presenter = TemporaryMoleculeStorage.presenter(nil)
        var core = MoleculeCore(seed: 1)
        for mode in DisplayMode.allCases {
            XCTAssertTrue(applied("display.mode", [Double(mode.rawValue)], to: &core).isAccepted, mode.name)
            presenter.sync(core)
            XCTAssertEqual(presenter.mirror.mode, mode)
            XCTAssertEqual(presenter.mirror.legend, MoleculePresenter.legend(mode))
            XCTAssertTrue(presenter.mirror.legend.hasSuffix(MoleculeReview.displayStatement), presenter.mirror.legend)
            XCTAssertEqual(MoleculeReview.claimWords(in: presenter.mirror.legend), [])
        }
    }

    /// Every string literal in the experience's Swift sources (`Experience/*.swift` and `Experience/Adapter/*.swift`,
    /// found from `#filePath`), the inline accessibility labels, values and hints of `MoleculeControls` included, holds
    /// no claim word (T-A15-516, FR-A15-521). Comment lines are skipped; publishers' names are removed as above.
    func testNoStringLiteralInTheSourcesHoldsAClaimWord() throws {
        let experience = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Experience")
        var folders: [URL] = [experience, experience.appendingPathComponent("Adapter")]
        var files: [URL] = []
        while let folder = folders.popLast() {
            let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            for name in names where name.hasSuffix(".swift") {
                files.append(folder.appendingPathComponent(name))
            }
        }
        XCTAssertGreaterThanOrEqual(files.count, 8, "the experience's sources were found")
        let literal = try NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)""#)
        var literals = 0
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            var number = 0
            for line in text.components(separatedBy: "\n") {
                number += 1
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { continue }
                let range = NSRange(line.startIndex..., in: line)
                for match in literal.matches(in: line, range: range) {
                    guard let found = Range(match.range(at: 1), in: line) else { continue }
                    var words = String(line[found])
                    for publisher in publishers { words = words.replacingOccurrences(of: publisher, with: "") }
                    literals += 1
                    XCTAssertEqual(MoleculeReview.claimWords(in: words), [],
                                   "\(file.lastPathComponent):\(number): \(words)")
                }
            }
        }
        XCTAssertGreaterThan(literals, 200, "the string literals were read")
    }
}
