// RecentStoreTests — feature 113 (A15-P04) T-A15-404 (FR-A15-410, FR-A15-411, FR-A15-440; SC-A15-402, SC-A15-403;
// clarifications Q1, Q3). The recent-molecules list of Molecular Explorer in a temporary experience storage: a recorded
// list loads back in a new store; ids outside the library are dropped on read; damaged, oversized, newer and
// out-of-range files are refused with their messages and stay byte-identical (also while a session opens over them,
// until the next molecule change replaces them); the list survives a new session over the same storage; removing the
// folder (the app's data reset) gives an empty list; the engine digest is the same with and without storage; a refused
// write (a read-only folder) keeps the previous file while the list in memory still changes; without storage the same
// rules hold in memory. Short runs only (each test well under 10 s), no wall-clock assertion, no system prompt.
import Foundation
import XCTest
@testable import MolecularExplorerExperience
import MolecularExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// A fresh experience storage of Molecular Explorer under the temporary directory: its root folder and defaults suite
/// are removed by ``remove()``.
struct TemporaryMoleculeStorage {
    /// The storage root.
    let root: URL
    /// The defaults suite name.
    let suite: String
    /// The experience's storage.
    let storage: ExperienceStorage

    /// A new empty storage under the temporary directory.
    init() {
        let name = "me-library-" + UUID().uuidString
        root = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        suite = name
        let id = ExperienceID(rawValue: MoleculeCore.experienceID) ?? ExperienceID(rawValue: "a15.unknown")!
        storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: name) ?? .standard)
    }

    /// The experience's folder (`<root>/a15.molecular-explorer/`).
    var folder: URL {
        root.appendingPathComponent(storage.id.storageNamespace, isDirectory: true)
    }

    /// Makes the folder read-only (`true`) or writable again (`false`).
    func setReadOnly(_ readOnly: Bool) throws {
        try FileManager.default.setAttributes([.posixPermissions: readOnly ? 0o555 : 0o755],
                                              ofItemAtPath: folder.path)
    }

    /// Removes the folder and the defaults suite (the app's data reset removes the folder the same way).
    func remove() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    /// A presenter whose recent list and settings are kept in `storage` (nil: in memory), with a recording
    /// announcement sink.
    @MainActor
    static func presenter(_ storage: ExperienceStorage?) -> MoleculePresenter {
        MoleculePresenter(experienceID: MoleculeTest.id, announcementSink: RecordingAnnouncementSink(),
                          displayScale: 2, recentStore: RecentStore(storage: storage),
                          settingsStore: SettingsStore(storage: storage))
    }
}

@MainActor
final class RecentStoreTests: XCTestCase {
    private var temporary: TemporaryMoleculeStorage!

    override func setUp() async throws {
        temporary = TemporaryMoleculeStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    /// A valid recent document holding `ids` (newest first).
    private func document(_ ids: [String]) -> Data {
        RecentMolecules(ids: ids).encoded()
    }

    func testARecordedListLoadsBackInANewStore() throws {
        let store = RecentStore(storage: temporary.storage)
        XCTAssertEqual(store.loadResult, .missing)
        XCTAssertEqual(store.message, "")
        XCTAssertFalse(temporary.storage.exists(RecentMolecules.fileName), "loading never writes")
        XCTAssertTrue(store.record("water"))
        XCTAssertTrue(store.record("caffeine"))
        XCTAssertTrue(store.record("benzene"))
        XCTAssertFalse(store.record("benzene"), "an unchanged list is not written again")
        XCTAssertEqual(store.writes, 3)
        XCTAssertEqual(store.recent.ids, ["benzene", "caffeine", "water"])
        XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName), store.recent.encoded())
        let again = RecentStore(storage: temporary.storage)
        XCTAssertEqual(again.loadResult, .loaded(RecentMolecules(ids: ["benzene", "caffeine", "water"])))
        XCTAssertEqual(again.recent.ids, ["benzene", "caffeine", "water"])
        XCTAssertEqual(again.writes, 0)
    }

    func testIdsOutsideTheLibraryAreDroppedOnRead() throws {
        try temporary.storage.write(document(["argon", "water", "ethanol"]), to: RecentMolecules.fileName)
        let before = try temporary.storage.read(RecentMolecules.fileName)
        let store = RecentStore(storage: temporary.storage)
        XCTAssertEqual(store.recent.ids, ["water", "ethanol"])
        XCTAssertEqual(store.message, "")
        XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName), before, "loading never writes")
    }

    func testRefusedFilesStayByteIdenticalWithTheirMessages() throws {
        let valid = String(decoding: document(["water"]), as: UTF8.self)
        let newer = valid.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2")
        XCTAssertNotEqual(newer, valid, "the sample names its schema")
        let older = valid.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":0")
        let oversized = Data(("{\"ids\":[],\"pad\":\"" + String(repeating: "x", count: RecentMolecules.maxBytes)
                              + "\",\"schemaVersion\":1}").utf8)
        XCTAssertGreaterThan(oversized.count, RecentMolecules.maxBytes)
        var nine: [String] = []
        for index in 0..<9 { nine.append("m\(index)") }
        let tooMany = Data(("{\"ids\":[\"" + nine.joined(separator: "\",\"") + "\"],\"schemaVersion\":1}").utf8)
        let duplicate = Data("{\"ids\":[\"water\",\"water\"],\"schemaVersion\":1}".utf8)
        let malformed = Data("{\"ids\":[\"Water\"],\"schemaVersion\":1}".utf8)
        let cases: [(bytes: Data, refusal: DocumentRefusal)] = [
            (Data("not json".utf8), .damaged),
            (Data(valid.utf8.prefix(12)), .damaged),
            (oversized, .oversized),
            (Data(newer.utf8), .newerVersion),
            (Data(older.utf8), .outOfRange),
            (tooMany, .outOfRange),
            (duplicate, .outOfRange),
            (malformed, .outOfRange),
        ]
        for entry in cases {
            try temporary.storage.write(entry.bytes, to: RecentMolecules.fileName)
            let store = RecentStore(storage: temporary.storage)
            XCTAssertEqual(store.loadResult, .refused(entry.refusal), "\(entry.refusal)")
            XCTAssertEqual(store.recent.ids, [], "a refused file leaves the list empty")
            XCTAssertEqual(store.message, "Recent molecules could not be read (\(entry.refusal.rawValue)).")
            XCTAssertEqual(store.writes, 0)
            XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName), entry.bytes,
                           "a refused file stays as it was")
        }
        XCTAssertEqual(RecentStore.readWords(.refused(.newerVersion)),
                       "Recent molecules could not be read (newer-version).")
        XCTAssertEqual(RecentStore.readWords(.missing), "")
        XCTAssertEqual(RecentStore.readWords(.unreadable("storage.invalid-name")),
                       "Recent molecules could not be read (storage.invalid-name).")
    }

    func testASessionOverARefusedFileLeavesItUntilTheNextMoleculeChange() async throws {
        let damaged = Data("{\"ids\":".utf8)
        try temporary.storage.write(damaged, to: RecentMolecules.fileName)
        let presenter = TemporaryMoleculeStorage.presenter(temporary.storage)
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, presenter: presenter)
        XCTAssertEqual(presenter.mirror.recentMessage, "Recent molecules could not be read (damaged).")
        XCTAssertEqual(presenter.mirror.recentIDs, ["water"], "the first molecule counts as opened, in memory")
        XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName), damaged,
                       "opening leaves the refused file byte for byte")
        XCTAssertTrue(shell.handle(control: "molecule.select", values: [1]).isAccepted)
        try MoleculeTest.frames(session, 1)
        XCTAssertEqual(presenter.mirror.recentIDs, ["methane", "water"])
        XCTAssertEqual(presenter.mirror.recentMessage, "", "the change replaced the file")
        XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName), document(["methane", "water"]))
        session.close()
    }

    func testTheListSurvivesANewSessionOverTheSameStorage() async throws {
        let first = TemporaryMoleculeStorage.presenter(temporary.storage)
        let session = ExperienceSession()
        let shell = try await MoleculeTest.open(session, presenter: first)
        XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName), document(["water"]),
                       "the first state is recorded and written")
        for index in [4, 3] {
            XCTAssertTrue(shell.handle(control: "molecule.select", values: [Double(index)]).isAccepted)
            try MoleculeTest.frames(session, 1)
        }
        XCTAssertEqual(first.mirror.recentIDs, ["benzene", "caffeine", "water"])
        session.close()
        XCTAssertEqual(RecentStore(storage: temporary.storage).recent.ids, ["benzene", "caffeine", "water"])

        let second = TemporaryMoleculeStorage.presenter(temporary.storage)
        XCTAssertEqual(second.mirror.recentTitles, ["Benzene", "Caffeine", "Water"], "loaded when the presenter is made")
        let reopened = ExperienceSession()
        _ = try await MoleculeTest.open(reopened, presenter: second)
        XCTAssertEqual(second.mirror.recentTitles, ["Water", "Benzene", "Caffeine"], "water opened again")
        reopened.close()
    }

    func testRemovingTheFolderGivesAnEmptyList() async throws {
        try temporary.storage.write(document(["caffeine", "water"]), to: RecentMolecules.fileName)
        try FileManager.default.removeItem(at: temporary.folder)
        let store = RecentStore(storage: temporary.storage)
        XCTAssertEqual(store.loadResult, .missing)
        XCTAssertEqual(store.recent.ids, [])
        XCTAssertEqual(store.message, "")
        let presenter = TemporaryMoleculeStorage.presenter(temporary.storage)
        XCTAssertEqual(presenter.mirror.recentIDs, [])
        XCTAssertEqual(presenter.mirror.labelMode, .all)
    }

    func testTheEngineDigestIsTheSameWithAndWithoutStorage() async throws {
        let actions: [(control: String, values: [Double])] = [
            ("molecule.select", [4]), ("atom.select", [2]), ("camera.orbit", [1]), ("molecule.previous", []),
            ("display.mode", [1]),
        ]
        var digests: [String] = []
        for storage in [temporary.storage, nil] as [ExperienceStorage?] {
            let presenter = TemporaryMoleculeStorage.presenter(storage)
            let session = ExperienceSession()
            let shell = try await MoleculeTest.open(session, presenter: presenter)
            for action in actions {
                XCTAssertTrue(shell.handle(control: action.control, values: action.values).isAccepted, action.control)
                try MoleculeTest.frames(session, 1)
            }
            presenter.setLabelMode(.none)
            digests.append(try moleculeDigest(try MoleculeTest.core(shell)))
            XCTAssertEqual(presenter.mirror.recentIDs, ["benzene", "caffeine", "water"])
            session.close()
        }
        XCTAssertEqual(digests.count, 2)
        XCTAssertEqual(digests[0], digests[1], "the recent list and the settings live outside the engine state")
        XCTAssertTrue(temporary.storage.exists(RecentMolecules.fileName))
        XCTAssertTrue(temporary.storage.exists(MoleculeSettings.fileName))
    }

    func testAFailedWriteKeepsThePreviousFile() throws {
        let store = RecentStore(storage: temporary.storage)
        XCTAssertTrue(store.record("water"))
        let before = try temporary.storage.read(RecentMolecules.fileName)
        try temporary.setReadOnly(true)
        let written = store.record("caffeine")
        try temporary.setReadOnly(false)
        XCTAssertFalse(written)
        XCTAssertEqual(store.message, "Recent molecules could not be saved (storage.write-failed).")
        XCTAssertEqual(store.recent.ids, ["caffeine", "water"], "the list in memory still changes")
        XCTAssertEqual(try temporary.storage.read(RecentMolecules.fileName), before, "the previous file is kept")
        XCTAssertEqual(store.writes, 1)
        XCTAssertTrue(store.record("ethanol"), "the next change is written again")
        XCTAssertEqual(store.message, "")
        XCTAssertEqual(RecentStore(storage: temporary.storage).recent.ids, ["ethanol", "caffeine", "water"])
    }

    func testWithoutStorageTheListIsKeptInMemory() {
        let store = RecentStore(storage: nil)
        XCTAssertEqual(store.loadResult, .missing)
        XCTAssertTrue(store.record("water"))
        XCTAssertTrue(store.record("benzene"))
        XCTAssertEqual(store.reload(), .loaded(RecentMolecules(ids: ["benzene", "water"])))
        XCTAssertEqual(store.writes, 2)
        let factory = MolecularExplorerExperience.make(id: MoleculeTest.id, storage: temporary.storage)
        XCTAssertNotNil(factory.presenter.recentStore.storage, "the factory hands its storage to the stores")
        XCTAssertNotNil(factory.presenter.settingsStore.storage)
        XCTAssertNil(MolecularExplorerExperience.make(id: MoleculeTest.id).presenter.recentStore.storage)
    }
}
