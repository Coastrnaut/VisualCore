// MoleculeImportSessionTests — feature 114 (A15-P05) T-A15-506, T-A15-507 and the experience slice of T-A15-508
// (FR-A15-501–506, FR-A15-510, FR-A15-540; SC-A15-501–503; clarifications Q1–Q4; contracts/import.md). The import of a
// person's XYZ file through the presenter and the importer in the one app's session host, with temporary files in a
// temporary folder and a temporary experience storage (no picker is ever presented, nothing prompts, no network):
// each valid fixture imports with its counts; reopening shows the import and the recent list holds `imported`; each
// refusal fixture shows its sentence and leaves the engine digest, `import.xyz` and `recent.json` byte-identical; an
// oversized file (65,537 bytes) is refused without being read; an import while the experience is not active changes
// nothing; a library molecule and then `imported` from the recent list shows the import again, also by replaying the
// stored copy; a missing or damaged copy at reopening still shows the saved molecule, and `imported` chosen with
// neither an engine import nor a readable copy is dropped; the success and refusal announcements; a refused copy write
// still imports with its message; the Import button's words and the controls holding references only; and 200 files
// of the fuzz corpus (seeds 1…200, the mutation scheme of `CoreTests/ImportFuzzTests.swift`, whose generator is copied
// here because the test targets are separate) sent through `MoleculeCore` actions with no crash and every refusal
// typed. Short runs only (each test well under 10 s), plain loops, no wall-clock assertion.
import Foundation
import UniformTypeIdentifiers
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

@MainActor
final class MoleculeImportSessionTests: XCTestCase {
    /// The experience's temporary storage.
    private var temporary: TemporaryMoleculeStorage!
    /// The temporary folder the picked files are written to.
    private var files: URL!

    override func setUp() async throws {
        temporary = TemporaryMoleculeStorage()
        files = FileManager.default.temporaryDirectory
            .appendingPathComponent("me-import-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        temporary.remove()
        try? FileManager.default.removeItem(at: files)
    }

    // MARK: Helpers

    /// A picked file `name` holding `data`.
    private func file(_ name: String, _ data: Data) throws -> URL {
        let url = files.appendingPathComponent(name, isDirectory: false)
        try data.write(to: url)
        return url
    }

    /// A picked file `name` holding the UTF-8 text `text`.
    private func file(_ name: String, _ text: String) throws -> URL {
        try file(name, Data(text.utf8))
    }

    /// Opens Molecular Explorer in `session` with a presenter over the temporary storage (recording announcements),
    /// optionally restoring `snapshot`, and attaches the shell's port and activity as the factory does.
    private func open(_ session: ExperienceSession, snapshot: ExperienceSnapshot? = nil) async throws
        -> ExperienceShell<MoleculePresenter> {
        let presenter = TemporaryMoleculeStorage.presenter(temporary.storage)
        let shell = try await MoleculeTest.open(session, snapshot: snapshot, presenter: presenter)
        MolecularExplorerExperience.attach(shell)
        return shell
    }

    /// The announcements recorded by `shell`'s presenter.
    private func announced(_ shell: ExperienceShell<MoleculePresenter>) -> [String] {
        (shell.presenter.announcementSink as? RecordingAnnouncementSink)?.announced ?? []
    }

    /// The stored bytes of `name`, or nil.
    private func stored(_ name: String) -> Data? {
        try? temporary.storage.read(name)
    }

    /// The valid fixtures: a file name, its text, its title.
    private var validFixtures: [(name: String, text: String, title: String)] {
        var fixtures: [(name: String, text: String, title: String)] = []
        for record in MoleculeLibraryData.records {
            fixtures.append(("\(record.id) copy.xyz", record.xyz, "\(record.id) copy"))
        }
        fixtures.append(("hydrogen_chloride.xyz", "2\nHCl\nCl 0 0 0\nH 1.27 0 0\n", "hydrogen_chloride"))
        fixtures.append(("lone (H).xyz", "1\none atom\nH 0 0 0\n", "lone (H)"))
        let windows = "3\r\nwindows\r\nO 0 0 0\r\nH 0.2774 0.8929 0.2544\r\nH 0.6068 -0.2383 -0.7169\r\n"
        fixtures.append(("windows.txt", windows, "windows"))
        return fixtures
    }

    /// The refusal fixtures: a file name, its bytes, the sentence shown.
    private var refusalFixtures: [(name: String, data: Data, sentence: String)] {
        let opened = "This file could not be opened: "
        let texts: [(String, String)] = [
            ("", "the file is empty."),
            ("-3\nx\nO 0 0 0\n", "the first line is not a whole atom count (line 1)."),
            ("501\nx\n", "more atoms than this explorer can show (at most 500) (line 1)."),
            ("2\nx\nO 0 0 0\n", "the number of atom lines differs from the atom count (line 1)."),
            ("1\nx\nO 0 0\n", "a line that is not an element and three coordinates (line 3)."),
            ("1\nx\nXe 0 0 0\n", "an element this explorer does not know (line 3)."),
            ("2\nx\nO 0 0 0\nH nan 0 0\n", "a coordinate that is not a number (line 4)."),
            ("1\nx\nO 0 0 1000.5\n", "a coordinate beyond 1,000 Å (line 3)."),
            ("2\nx\nO 0 0 0\nH 0.1 0 0\n", "two atoms closer than 0.4 Å (line 4)."),
            ("1\nx\nO 0 0 0" + String(repeating: " ", count: 300) + "\n", "a line longer than 256 bytes (line 3)."),
        ]
        var fixtures: [(name: String, data: Data, sentence: String)] = []
        for (index, entry) in texts.enumerated() {
            fixtures.append(("refused-\(index).xyz", Data(entry.0.utf8), opened + entry.1))
        }
        fixtures.append(("not-text.xyz", Data([0x31, 0x0A, 0xFF, 0xFE]), opened + "the file is not plain text."))
        fixtures.append(("oversized.xyz", Data(repeating: 0x20, count: MoleculeImport.maxBytes + 1),
                         MoleculeImport.tooLargeSentence))
        return fixtures
    }

    // MARK: Import

    func testEachValidFixtureImportsWithItsCounts() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        for fixture in validFixtures {
            let url = try file(fixture.name, fixture.text)
            let parsed = try XYZParser.parse(fixture.text).get()
            let expected = try ImportedMolecule.make(atoms: parsed.atoms).get().molecule
            let outcome = presenter.importFile(at: url)
            XCTAssertEqual(outcome, .imported(title: fixture.title, atoms: expected.atoms.count, storageCode: nil),
                           fixture.name)
            let core = try MoleculeTest.core(shell)
            XCTAssertEqual(core.selection, MoleculeCore.importedSelection, fixture.name)
            XCTAssertEqual(core.imported?.molecule, expected, fixture.name)
            XCTAssertEqual(presenter.mirror.nameLine, "\(fixture.title) — \(expected.formula)")
            XCTAssertEqual(presenter.mirror.countsLine, MoleculeCore.countsLine(expected))
            XCTAssertEqual(presenter.mirror.sourceLine, "imported file — your own data")
            XCTAssertEqual(presenter.mirror.status, "\(fixture.title) selected, molecule 6 of 6")
            XCTAssertEqual(presenter.mirror.title, fixture.title)
            XCTAssertTrue(presenter.mirror.hasImport)
            XCTAssertEqual(presenter.mirror.importMessage, "")
            XCTAssertEqual(shell.accessibilitySummary, MoleculeCore.canvasDescription(molecule: expected,
                                                                                      title: fixture.title))
            XCTAssertEqual(stored(MoleculeImporter.fileName), Data(fixture.text.utf8), "the accepted bytes are kept")
            XCTAssertEqual(stored(MoleculeImporter.titleFileName), Data(fixture.title.utf8))
            XCTAssertEqual(presenter.mirror.recentIDs.first, ImportedMolecule.id)
            XCTAssertEqual(presenter.mirror.recentTitles.first, fixture.title)
            try MoleculeTest.frames(session, 1)
            XCTAssertEqual(presenter.lastAtomsDrawn, expected.atoms.count, fixture.name)
        }
        XCTAssertEqual(MoleculeCore.countsLine(try XCTUnwrap(try MoleculeTest.core(shell).molecule)),
                       "3 atoms, 2 bonds", "the last fixture is water with Windows line endings")
        XCTAssertEqual(presenter.importer.readCount, validFixtures.count)
        session.close()
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testReopeningShowsTheImportAndTheRecentListHoldsIt() async throws {
        let first = ExperienceSession()
        let shell = try await open(first)
        let url = try file("my caffeine.xyz", MoleculeLibraryData.records[4].xyz)
        XCTAssertEqual(shell.presenter.importFile(at: url),
                       .imported(title: "my caffeine", atoms: 24, storageCode: nil))
        let snapshot = try shell.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 4)
        first.close()

        let second = ExperienceSession()
        let reopened = try await open(second, snapshot: snapshot)
        XCTAssertNil(second.lastRestoreRefusal)
        let core = try MoleculeTest.core(reopened)
        XCTAssertEqual(core.selection, 5)
        XCTAssertEqual(core.imported?.molecule.atoms.count, 24)
        let presenter = reopened.presenter
        XCTAssertEqual(presenter.mirror.nameLine, "my caffeine — C8H10N4O2", "the title comes from import-title.txt")
        XCTAssertEqual(presenter.mirror.recentIDs.first, ImportedMolecule.id)
        XCTAssertEqual(presenter.mirror.recentTitles.first, "my caffeine")
        XCTAssertEqual(presenter.recentStore.reload(),
                       .loaded(RecentMolecules(ids: [ImportedMolecule.id, "water"])), "recent.json holds it")
        XCTAssertEqual(presenter.lastAtomsDrawn, 24)
        second.close()
    }

    func testEachRefusalShowsItsSentenceAndChangesNothing() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        let water = try file("water.xyz", MoleculeLibraryData.records[0].xyz)
        XCTAssertEqual(presenter.importFile(at: water), .imported(title: "water", atoms: 3, storageCode: nil))
        XCTAssertTrue(presenter.send("molecule.select", [2], through: shell.port).isAccepted)
        let digest = try moleculeDigest(try MoleculeTest.core(shell))
        let copy = try XCTUnwrap(stored(MoleculeImporter.fileName))
        let title = try XCTUnwrap(stored(MoleculeImporter.titleFileName))
        let recent = try XCTUnwrap(stored(RecentMolecules.fileName))
        var cases: [(url: URL, sentence: String)] = []
        for fixture in refusalFixtures {
            cases.append((url: try file(fixture.name, fixture.data), sentence: fixture.sentence))
        }
        cases.append((url: files.appendingPathComponent("removed meanwhile.xyz"),
                      sentence: MoleculeImport.unreadableSentence))
        for entry in cases {
            let url = entry.url
            XCTAssertEqual(presenter.importFile(at: url), .refused(entry.sentence), url.lastPathComponent)
            XCTAssertEqual(presenter.mirror.importMessage, entry.sentence)
            XCTAssertEqual(announced(shell).last, entry.sentence)
            XCTAssertEqual(try moleculeDigest(try MoleculeTest.core(shell)), digest, url.lastPathComponent)
            XCTAssertEqual(stored(MoleculeImporter.fileName), copy, "import.xyz is byte-identical")
            XCTAssertEqual(stored(MoleculeImporter.titleFileName), title)
            XCTAssertEqual(stored(RecentMolecules.fileName), recent, "recent.json is byte-identical")
            XCTAssertEqual(presenter.mirror.nameLine, "Ethanol — C2H6O", "the shown molecule is unchanged")
        }
        XCTAssertEqual(MoleculeImport.sentence(XYZRefusal(.tooManyAtoms)),
                       "This file could not be opened: more atoms than this explorer can show (at most 500).")
        session.close()
    }

    func testAnOversizedFileIsRefusedWithoutBeingRead() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        let url = try file("big.xyz", Data(repeating: 0x0A, count: 65_537))
        XCTAssertEqual(MoleculeImporter.fileSize(url), 65_537)
        XCTAssertEqual(presenter.importFile(at: url),
                       .refused("This file is larger than 64 KB, the limit for a molecule file."))
        XCTAssertEqual(presenter.importer.readCount, 0, "the bytes were never read")
        XCTAssertFalse(temporary.storage.exists(MoleculeImporter.fileName))
        // The size alone decides: an injected reader is never asked for a file it reports as too large.
        var reads = 0
        let counting = MoleculeImporter(storage: nil, reader: { _ in reads += 1; return Data() },
                                        sizeReader: { _ in MoleculeImport.maxBytes + 1 })
        let outcome = counting.importFile(at: url, isActive: true) { _, _ in .accepted }
        XCTAssertEqual(outcome, .refused(MoleculeImport.tooLargeSentence))
        XCTAssertEqual(reads, 0)
        // Exactly the limit is read (and refused by the parser as not an atom count).
        let limit = try file("limit.xyz", Data(repeating: 0x0A, count: 65_536))
        if case .refused(let sentence) = presenter.importFile(at: limit) {
            XCTAssertNotEqual(sentence, MoleculeImport.tooLargeSentence)
        } else {
            XCTFail("a file of blank lines is refused")
        }
        XCTAssertEqual(presenter.importer.readCount, 1)
        session.close()
    }

    func testAnImportWhileNotActiveChangesNothing() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        let url = try file("water.xyz", MoleculeLibraryData.records[0].xyz)
        let digest = try moleculeDigest(try MoleculeTest.core(shell))
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        XCTAssertEqual(presenter.importFile(at: url), .inactive)
        XCTAssertEqual(presenter.importer.readCount, 0, "nothing is read while suspended")
        XCTAssertEqual(presenter.mirror.importMessage, "")
        XCTAssertEqual(announced(shell), [])
        XCTAssertFalse(temporary.storage.exists(MoleculeImporter.fileName))
        session.setScenePhase(.active)
        XCTAssertEqual(try moleculeDigest(try MoleculeTest.core(shell)), digest)
        // A presenter without an attached port imports nothing either.
        let detached = TemporaryMoleculeStorage.presenter(temporary.storage)
        XCTAssertEqual(detached.importFile(at: url), .inactive)
        XCTAssertEqual(detached.importer.readCount, 0)
        // Active again, the same file imports.
        XCTAssertEqual(presenter.importFile(at: url), .imported(title: "water", atoms: 3, storageCode: nil))
        session.close()
    }

    func testTheRecentListShowsTheImportAgainAndReplaysTheStoredCopy() async throws {
        let first = ExperienceSession()
        let shell = try await open(first)
        let presenter = shell.presenter
        let url = try file("benzene ring.xyz", MoleculeLibraryData.records[3].xyz)
        XCTAssertEqual(presenter.importFile(at: url), .imported(title: "benzene ring", atoms: 12, storageCode: nil))
        XCTAssertEqual(presenter.chooseRecent("water", through: shell.port), .accepted)
        XCTAssertEqual(try MoleculeTest.core(shell).selection, 0)
        XCTAssertEqual(presenter.mirror.recentIDs, ["water", ImportedMolecule.id])
        XCTAssertEqual(presenter.chooseRecent(ImportedMolecule.id, through: shell.port), .accepted)
        XCTAssertEqual(try MoleculeTest.core(shell).selection, 5)
        XCTAssertEqual(presenter.mirror.nameLine, "benzene ring — C6H6")
        first.close()

        // A new session without the saved state: the engine holds no import, the stored copy is replayed.
        let second = ExperienceSession()
        let fresh = try await open(second)
        XCTAssertNil(try MoleculeTest.core(fresh).imported)
        XCTAssertTrue(fresh.presenter.mirror.recentIDs.contains(ImportedMolecule.id), "a readable copy is offered")
        XCTAssertEqual(fresh.presenter.chooseRecent(ImportedMolecule.id, through: fresh.port), .accepted)
        let core = try MoleculeTest.core(fresh)
        XCTAssertEqual(core.selection, 5)
        XCTAssertEqual(core.imported?.molecule.atoms.count, 12)
        XCTAssertEqual(fresh.presenter.mirror.nameLine, "benzene ring — C6H6")
        XCTAssertEqual(fresh.presenter.mirror.recentIDs.first, ImportedMolecule.id)
        try MoleculeTest.frames(second, 1)
        XCTAssertEqual(fresh.presenter.lastAtomsDrawn, 12)
        second.close()
    }

    func testAMissingOrDamagedCopyKeepsTheSavedMoleculeAndAnUnavailableEntryIsDropped() async throws {
        let first = ExperienceSession()
        let shell = try await open(first)
        let url = try file("ethanol.xyz", MoleculeLibraryData.records[2].xyz)
        XCTAssertEqual(shell.presenter.importFile(at: url), .imported(title: "ethanol", atoms: 9, storageCode: nil))
        let snapshot = try shell.snapshot()
        first.close()

        // Damaged, then missing: the saved state still shows the imported molecule.
        try temporary.storage.write(Data("damaged".utf8), to: MoleculeImporter.fileName)
        for round in 0..<2 {
            if round == 1 { try temporary.storage.remove(MoleculeImporter.fileName) }
            let session = ExperienceSession()
            let reopened = try await open(session, snapshot: snapshot)
            let core = try MoleculeTest.core(reopened)
            XCTAssertEqual(core.selection, 5, "round \(round)")
            XCTAssertEqual(core.imported?.molecule.atoms.count, 9, "round \(round)")
            XCTAssertEqual(reopened.presenter.mirror.nameLine, "ethanol — C2H6O", "round \(round)")
            XCTAssertFalse(reopened.presenter.importer.hasReadableCopy, "round \(round)")
            XCTAssertEqual(reopened.presenter.mirror.recentIDs.first, ImportedMolecule.id, "the engine holds it")
            XCTAssertEqual(reopened.presenter.lastAtomsDrawn, 9)
            session.close()
        }

        // No saved state and no copy: the entry is not offered, and choosing it drops it from recent.json.
        let last = ExperienceSession()
        let fresh = try await open(last)
        let presenter = fresh.presenter
        XCTAssertNil(try MoleculeTest.core(fresh).imported)
        XCTAssertFalse(presenter.mirror.recentIDs.contains(ImportedMolecule.id))
        XCTAssertTrue(presenter.recentStore.recent.ids.contains(ImportedMolecule.id), "still in the file")
        let before = try moleculeDigest(try MoleculeTest.core(fresh))
        XCTAssertEqual(presenter.chooseRecent(ImportedMolecule.id, through: fresh.port),
                       .rejected(.rule(code: MoleculeRule.invalidImport)))
        XCTAssertFalse(presenter.recentStore.recent.ids.contains(ImportedMolecule.id))
        guard case .loaded(let list) = presenter.recentStore.reload() else { return XCTFail("recent.json reads") }
        XCTAssertFalse(list.ids.contains(ImportedMolecule.id), "dropped from recent.json")
        XCTAssertEqual(presenter.mirror.importMessage, MoleculePresenter.importGoneWords)
        XCTAssertEqual(try moleculeDigest(try MoleculeTest.core(fresh)), before, "nothing was sent")
        last.close()
    }

    func testTheSuccessAndRefusalAnnouncements() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        let water = try file("water.xyz", MoleculeLibraryData.records[0].xyz)
        let lone = try file("lone.xyz", "1\nx\nH 0 0 0\n")
        let refused = try file("argon.xyz", "1\nx\nAr 0 0 0\n")
        presenter.importFile(at: water)
        XCTAssertEqual(announced(shell).last, "water imported, 3 atoms")
        presenter.importFile(at: lone)
        XCTAssertEqual(announced(shell).last, "lone imported, 1 atom")
        presenter.importFile(at: refused)
        XCTAssertEqual(announced(shell).last,
                       "This file could not be opened: an element this explorer does not know (line 3).")
        XCTAssertEqual(announced(shell).count, 3, "one announcement per import")
        XCTAssertEqual(presenter.lastAnnouncement, announced(shell).last)
        XCTAssertEqual(MoleculePresenter.importedWords(title: "caffeine", atoms: 24), "caffeine imported, 24 atoms")
        session.close()
    }

    func testARefusedCopyWriteStillImportsWithItsMessage() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        let water = try file("water.xyz", MoleculeLibraryData.records[0].xyz)
        XCTAssertEqual(presenter.importFile(at: water), .imported(title: "water", atoms: 3, storageCode: nil))
        let copy = try XCTUnwrap(stored(MoleculeImporter.fileName))
        let caffeine = try file("caffeine.xyz", MoleculeLibraryData.records[4].xyz)
        try temporary.setReadOnly(true)
        let outcome = presenter.importFile(at: caffeine)
        try temporary.setReadOnly(false)
        XCTAssertEqual(outcome, .imported(title: "caffeine", atoms: 24, storageCode: "storage.write-failed"))
        XCTAssertEqual(presenter.mirror.importMessage,
                       "The molecule was opened but could not be kept for the recent list (storage.write-failed).")
        XCTAssertEqual(MoleculePresenter.keepFailedWords("storage.quota-exceeded"),
                       "The molecule was opened but could not be kept for the recent list (storage.quota-exceeded).")
        let core = try MoleculeTest.core(shell)
        XCTAssertEqual(core.imported?.molecule.atoms.count, 24, "the engine holds the new import")
        XCTAssertEqual(core.selection, 5)
        XCTAssertEqual(stored(MoleculeImporter.fileName), copy, "the previous copy is kept")
        XCTAssertEqual(announced(shell).last, "caffeine imported, 24 atoms")
        session.close()
    }

    // MARK: Controls (T-A15-507)

    func testTheImportButtonsWordsAndTheControlsHoldOnlyReferences() async throws {
        XCTAssertEqual(MoleculeControls.importLabel, "Import XYZ file")
        XCTAssertEqual(MoleculeControls.importHint, "Opens a small XYZ file from Files")
        XCTAssertEqual(MoleculeControls.importTypes.count, 2)
        XCTAssertTrue(MoleculeControls.importTypes.contains(.plainText))
        XCTAssertEqual(MoleculeControls.importTypes.first, UTType(filenameExtension: "xyz"))
        XCTAssertEqual(MoleculePresenter.inferredNote, "Bonds marked inferred are estimated from atom distances.")
        XCTAssertEqual(MoleculeControls.moleculeWords(title: "my file", index: 5, count: 5), "my file, molecule 6 of 6")
        XCTAssertEqual(MoleculeControls.moleculeWords(index: 4, count: 5), "Caffeine, molecule 5 of 5")
        let words = [MoleculeControls.importLabel, MoleculeControls.importHint, MoleculePresenter.inferredNote,
                     MoleculePresenter.importGoneWords, MoleculePresenter.keepFailedWords("storage.write-failed")]
        for text in words {
            XCTAssertFalse(text.lowercased().contains("camera"), text)
            XCTAssertEqual(MoleculeReview.claimWords(in: text), [], text)
        }

        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        XCTAssertTrue(presenter.nativeActions.isSuperset(of: ["import.begin", "import.atom", "import.end"]))
        XCTAssertFalse(presenter.mirror.importing, "the picker is not shown")
        let controls = MoleculeControls(port: shell.port, mirror: presenter.mirror, presenter: presenter)
        let children = Mirror(reflecting: controls).children
        XCTAssertEqual(children.compactMap(\.label), ["port", "mirror", "presenter"])
        for child in children {
            let type = String(describing: Swift.type(of: child.value))
            XCTAssertFalse(type.contains("->"), "\(child.label ?? "?") is a closure: \(type)")
            XCTAssertEqual(Mirror(reflecting: child.value).displayStyle, .class,
                           "\(child.label ?? "?") is not a class reference: \(type)")
        }
        XCTAssertEqual(Mirror(reflecting: presenter.importer).displayStyle, .class)
        session.close()
    }

    // MARK: Fuzz slice (T-A15-508)

    func testTwoHundredMutatedFilesThroughTheCoreActions() throws {
        let bases = ImportFuzzCorpus.bases()
        let allowed: Set<String> = ["action.rule." + MoleculeRule.invalidImport, "action.out-of-range"]
        var problems: [String] = []
        var accepted = 0
        var refused = 0
        for seed in UInt64(1)...200 {
            let bytes = ImportFuzzCorpus.file(seed: seed, bases: bases)
            if MoleculeImport.sizeRefusal(byteCount: bytes.count) != nil {
                refused += 1
                continue
            }
            let parsed: ParsedXYZ
            switch XYZParser.parse(Data(bytes)) {
            case .failure(let refusal):
                refused += 1
                if MoleculeImport.sentence(refusal).isEmpty { problems.append("seed \(seed): no sentence") }
                continue
            case .success(let value):
                parsed = value
            }
            let rule = ImportedMolecule.make(atoms: parsed.atoms)
            var core = MoleculeCore(seed: 1)
            let start = core
            var firstRefusal: ActionResult?
            for entry in MoleculeImport.actions(parsed) {
                let result: ActionResult
                if let rejection = ExperienceInput.validate(control: entry.control, values: entry.values,
                                                            controls: MoleculeCore.controls) {
                    result = .rejected(rejection)
                } else {
                    result = core.apply(ExperienceAction(control: entry.control, values: entry.values, step: 0))
                }
                if !result.isAccepted {
                    firstRefusal = result
                    break
                }
            }
            switch rule {
            case .success(let molecule):
                accepted += 1
                if let firstRefusal { problems.append("seed \(seed): refused \(firstRefusal.code)") }
                if core.imported != molecule || core.selection != 5 { problems.append("seed \(seed): not shown") }
            case .failure:
                refused += 1
                guard let firstRefusal else {
                    problems.append("seed \(seed): accepted a file the rule refuses")
                    continue
                }
                if !allowed.contains(firstRefusal.code) { problems.append("seed \(seed): \(firstRefusal.code)") }
                if core.imported != nil || core.selection != start.selection {
                    problems.append("seed \(seed): the shown molecule changed")
                }
            }
        }
        XCTAssertEqual(problems, [])
        XCTAssertEqual(accepted + refused, 200)
        XCTAssertGreaterThan(accepted, 0, "the slice reaches an import")
        XCTAssertGreaterThan(refused, 0, "the slice reaches a refusal")
    }
}

// MARK: - The fuzz corpus (copied from CoreTests/ImportFuzzTests.swift; the test targets are separate)

/// SplitMix64: a small deterministic generator for the corpus.
private struct ImportFuzzGenerator {
    /// The state.
    var state: UInt64

    /// The next 64-bit value.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0..<bound (0 for a bound of 0).
    mutating func below(_ bound: Int) -> Int {
        bound <= 0 ? 0 : Int(next() % UInt64(bound))
    }
}

/// The mutations of the corpus.
private enum ImportFuzzMutation: Int, CaseIterable {
    /// One bit of one byte flipped.
    case byteFlip
    /// One byte inserted (mostly from the XYZ alphabet).
    case byteInsert
    /// One byte deleted.
    case byteDelete
    /// One line written twice.
    case lineDuplicate
    /// One line removed.
    case lineDelete
    /// The file cut at a random length.
    case truncate
    /// One decimal digit replaced by another.
    case digitChange
}

/// The seeded corpus: the same bases, mutations and seeds as the core's fuzz test.
private enum ImportFuzzCorpus {
    /// The bytes an insert mostly draws from: digits, signs, separators, line endings and letters of the syntax.
    static let alphabet: [UInt8] = Array("0123456789 \t\n\r.-+eEnNaAiIfFHCOClBr".utf8)

    /// The base files: the five library molecules as XYZ text and the refusal fixtures.
    static func bases() -> [[UInt8]] {
        var texts: [String] = []
        for record in MoleculeLibraryData.records { texts.append(record.xyz) }
        texts.append("-3\nnegative count\nO 0 0 0\nH 0.2774 0.8929 0.2544\nH 0.6068 -0.2383 -0.7169\n")
        texts.append("3\nNaN coordinate\nO 0 0 0\nH 0.2774 nan 0.2544\nH 0.6068 -0.2383 -0.7169\n")
        texts.append("2\nclose atoms\nC 0 0 0\nC 0.39 0 0\n")
        texts.append("1\nunknown\nXe 0 0 0\n")
        texts.append("2\nfar\nH 0 0 999.9999\nH 0 0 -1000\n")
        texts.append("3\r\nwindows\r\nO 0 0 0\r\nH 0.2774 0.8929 0.2544\r\nH 0.6068 -0.2383 -0.7169\r\n")
        var bases: [[UInt8]] = []
        for text in texts { bases.append(Array(text.utf8)) }
        return bases
    }

    /// The line ranges of `bytes` (split after each "\n"; the last line may lack one).
    static func lineRanges(_ bytes: [UInt8]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0
        var index = 0
        while index < bytes.count {
            if bytes[index] == 0x0A {
                ranges.append(start..<(index + 1))
                start = index + 1
            }
            index += 1
        }
        if start < bytes.count { ranges.append(start..<bytes.count) }
        return ranges
    }

    /// `bytes` changed by `mutation`, drawing positions from `generator`.
    static func apply(_ mutation: ImportFuzzMutation, to bytes: [UInt8], _ generator: inout ImportFuzzGenerator)
        -> [UInt8] {
        var result = bytes
        switch mutation {
        case .byteFlip:
            guard !result.isEmpty else { return result }
            let index = generator.below(result.count)
            result[index] ^= UInt8(1 << generator.below(8))
        case .byteInsert:
            let byte = generator.below(4) == 0 ? UInt8(generator.below(256)) : alphabet[generator.below(alphabet.count)]
            result.insert(byte, at: generator.below(result.count + 1))
        case .byteDelete:
            guard !result.isEmpty else { return result }
            result.remove(at: generator.below(result.count))
        case .lineDuplicate:
            let lines = lineRanges(result)
            guard !lines.isEmpty else { return result }
            let line = lines[generator.below(lines.count)]
            result.insert(contentsOf: Array(result[line]), at: line.upperBound)
        case .lineDelete:
            let lines = lineRanges(result)
            guard !lines.isEmpty else { return result }
            result.removeSubrange(lines[generator.below(lines.count)])
        case .truncate:
            result.removeSubrange(generator.below(result.count + 1)..<result.count)
        case .digitChange:
            var digits: [Int] = []
            for (index, byte) in result.enumerated() where byte >= 0x30 && byte <= 0x39 { digits.append(index) }
            guard !digits.isEmpty else { return result }
            result[digits[generator.below(digits.count)]] = UInt8(0x30 + generator.below(10))
        }
        return result
    }

    /// The file of `seed`: a base chosen by the generator with one to four mutations.
    static func file(seed: UInt64, bases: [[UInt8]]) -> [UInt8] {
        var generator = ImportFuzzGenerator(state: seed)
        var bytes = bases[generator.below(bases.count)]
        let count = 1 + generator.below(4)
        for _ in 0..<count {
            let mutation = ImportFuzzMutation(rawValue: generator.below(ImportFuzzMutation.allCases.count)) ?? .byteFlip
            bytes = apply(mutation, to: bytes, &generator)
        }
        return bytes
    }
}
