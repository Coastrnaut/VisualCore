// SettingsStoreTests — feature 113 (A15-P04) T-A15-404 (FR-A15-420, FR-A15-440; SC-A15-403; clarifications Q2, Q3).
// The settings of Molecular Explorer in a temporary experience storage: no file gives labels for all atoms and writes
// nothing; a changed label mode loads back in a new store and in a new presenter; damaged, oversized, newer and
// out-of-range files are refused with their messages, give the default and stay byte-identical (also while a session
// opens over them); removing the folder (the app's data reset) gives the default; a refused write (a read-only folder)
// keeps the previous file while the mode in memory still changes; without storage the same rules hold in memory.
// Short runs only (each test well under 10 s), no wall-clock assertion, no system prompt.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var temporary: TemporaryMoleculeStorage!

    override func setUp() async throws {
        temporary = TemporaryMoleculeStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    func testNoFileGivesLabelsForAllAtomsAndWritesNothing() {
        let store = SettingsStore(storage: temporary.storage)
        XCTAssertEqual(store.loadResult, .missing)
        XCTAssertEqual(store.labels, .all)
        XCTAssertEqual(store.message, "")
        XCTAssertFalse(store.setLabels(.all), "an unchanged mode is not written")
        XCTAssertFalse(temporary.storage.exists(MoleculeSettings.fileName), "loading never writes")
        XCTAssertEqual(store.writes, 0)
    }

    func testAChangedModeLoadsBackInANewStore() throws {
        let store = SettingsStore(storage: temporary.storage)
        XCTAssertTrue(store.setLabels(.selected))
        XCTAssertEqual(try temporary.storage.read(MoleculeSettings.fileName),
                       MoleculeSettings(labels: .selected).encoded())
        let again = SettingsStore(storage: temporary.storage)
        XCTAssertEqual(again.loadResult, .loaded(MoleculeSettings(labels: .selected)))
        XCTAssertEqual(again.labels, .selected)
        XCTAssertTrue(again.setLabels(.none))
        XCTAssertEqual(SettingsStore(storage: temporary.storage).labels, .none)
    }

    func testRefusedFilesStayByteIdenticalWithTheirMessages() throws {
        let valid = String(decoding: MoleculeSettings(labels: .none).encoded(), as: UTF8.self)
        let newer = valid.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2")
        XCTAssertNotEqual(newer, valid, "the sample names its schema")
        let older = valid.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":0")
        let unknown = valid.replacingOccurrences(of: "\"labels\":\"none\"", with: "\"labels\":\"some\"")
        XCTAssertNotEqual(unknown, valid, "the sample names its mode")
        let oversized = Data(("{\"labels\":\"all\",\"pad\":\"" + String(repeating: "x", count: MoleculeSettings.maxBytes)
                              + "\",\"schemaVersion\":1}").utf8)
        XCTAssertGreaterThan(oversized.count, MoleculeSettings.maxBytes)
        let cases: [(bytes: Data, refusal: DocumentRefusal)] = [
            (Data("not json".utf8), .damaged),
            (Data("{\"labels\":3,\"schemaVersion\":1}".utf8), .damaged),
            (oversized, .oversized),
            (Data(newer.utf8), .newerVersion),
            (Data(older.utf8), .outOfRange),
            (Data(unknown.utf8), .outOfRange),
        ]
        for entry in cases {
            try temporary.storage.write(entry.bytes, to: MoleculeSettings.fileName)
            let store = SettingsStore(storage: temporary.storage)
            XCTAssertEqual(store.loadResult, .refused(entry.refusal), "\(entry.refusal)")
            XCTAssertEqual(store.labels, .all, "a refused file gives the default")
            XCTAssertEqual(store.message,
                           "Settings could not be read (\(entry.refusal.rawValue)); labels are shown for all atoms.")
            XCTAssertEqual(store.writes, 0)
            XCTAssertEqual(try temporary.storage.read(MoleculeSettings.fileName), entry.bytes,
                           "a refused file stays as it was")
        }
        XCTAssertEqual(SettingsStore.readWords(.unreadable("storage.invalid-name")),
                       "Settings could not be read (storage.invalid-name); labels are shown for all atoms.")
        XCTAssertEqual(SettingsStore.saveWords("storage.write-failed"),
                       "Settings could not be saved (storage.write-failed).")
    }

    func testASessionOverARefusedFileLeavesItAndShowsWhy() async throws {
        let newer = Data("{\"labels\":\"none\",\"schemaVersion\":9}".utf8)
        try temporary.storage.write(newer, to: MoleculeSettings.fileName)
        let presenter = TemporaryMoleculeStorage.presenter(temporary.storage)
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, presenter: presenter)
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [4]).isAccepted)
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(presenter.mirror.labelMode, .all)
        XCTAssertFalse(presenter.mirror.labels.isEmpty, "labels for all atoms")
        XCTAssertEqual(presenter.mirror.settingsMessage,
                       "Settings could not be read (newer-version); labels are shown for all atoms.")
        XCTAssertEqual(try temporary.storage.read(MoleculeSettings.fileName), newer, "the file stays byte for byte")
        session.close()
    }

    func testTheSettingsSurviveANewPresenter() async throws {
        let first = TemporaryMoleculeStorage.presenter(temporary.storage)
        let session = ExperienceSession()
        _ = try await MoleculeTest.open(session, presenter: first)
        first.setLabelMode(.none)
        XCTAssertEqual(first.mirror.labelMode, .none)
        session.close()
        let second = TemporaryMoleculeStorage.presenter(temporary.storage)
        XCTAssertEqual(second.mirror.labelMode, .none)
        XCTAssertEqual(second.settingsStore.loadResult, .loaded(MoleculeSettings(labels: .none)))
        let reopened = ExperienceSession()
        _ = try await MoleculeTest.open(reopened, presenter: second)
        XCTAssertEqual(second.mirror.labels, [], "no labels after reopening with None")
        reopened.close()
    }

    func testRemovingTheFolderGivesTheDefault() throws {
        let store = SettingsStore(storage: temporary.storage)
        XCTAssertTrue(store.setLabels(.selected))
        try FileManager.default.removeItem(at: temporary.folder)
        let again = SettingsStore(storage: temporary.storage)
        XCTAssertEqual(again.loadResult, .missing)
        XCTAssertEqual(again.labels, .all)
        XCTAssertEqual(again.message, "")
    }

    func testAFailedWriteKeepsThePreviousFile() throws {
        let store = SettingsStore(storage: temporary.storage)
        XCTAssertTrue(store.setLabels(.selected))
        let before = try temporary.storage.read(MoleculeSettings.fileName)
        try temporary.setReadOnly(true)
        let written = store.setLabels(.none)
        try temporary.setReadOnly(false)
        XCTAssertFalse(written)
        XCTAssertEqual(store.message, "Settings could not be saved (storage.write-failed).")
        XCTAssertEqual(store.labels, .none, "the mode in memory still changes")
        XCTAssertEqual(try temporary.storage.read(MoleculeSettings.fileName), before, "the previous file is kept")
        XCTAssertEqual(store.writes, 1)
        XCTAssertEqual(SettingsStore(storage: temporary.storage).labels, .selected)
    }

    func testWithoutStorageTheSettingsAreKeptInMemory() {
        let store = SettingsStore(storage: nil)
        XCTAssertEqual(store.loadResult, .missing)
        XCTAssertTrue(store.setLabels(.selected))
        XCTAssertEqual(store.reload(), .loaded(MoleculeSettings(labels: .selected)))
        XCTAssertEqual(store.writes, 1)
    }
}
