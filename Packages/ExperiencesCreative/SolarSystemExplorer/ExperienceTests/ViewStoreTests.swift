// ViewStoreTests — feature 106 (A14-P04) T-A14-408 (FR-A14-421; SC-A14-405; clarification Q5). The saved view of Solar
// System Explorer in a temporary experience storage: a saved view loads back identical from `view.json`; no file is
// its own result; damaged, newer and oversized files written raw into the storage are refused with their reasons and
// left untouched; the in-memory store follows the same rules. Short and file-local.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience

/// A fresh experience storage under the temporary directory for Solar System Explorer tests.
struct TemporarySolarStorage {
    /// The storage root.
    let root: URL
    /// The defaults suite name.
    let suite: String
    /// The experience's storage.
    let storage: ExperienceStorage

    /// A new empty storage under the temporary directory.
    init() {
        let name = "sse-view-" + UUID().uuidString
        root = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        suite = name
        let id = ExperienceID(rawValue: SolarCore.experienceID) ?? ExperienceID(rawValue: "a14.unknown")!
        storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: name) ?? .standard)
    }

    /// Removes the folder and the defaults suite.
    func remove() {
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}

final class ViewStoreTests: XCTestCase {
    private var temporary: TemporarySolarStorage!

    override func setUp() async throws {
        temporary = TemporarySolarStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    /// A view off every default: Mars, day 1,234.5, rate 2, yaw −3, pitch 55, zoom 4, true relative.
    private func sampleView() throws -> SavedView {
        try XCTUnwrap(SavedView(selection: 4, dayOffset: 1_234.5, rateIndex: 2, yawSteps: -3, pitchDegrees: 55,
                                zoomSteps: 4, scaleMode: 1))
    }

    func testASavedViewLoadsBackIdentical() throws {
        let store = ViewStore(storage: temporary.storage)
        XCTAssertEqual(store.load(), .failure(.missing), "nothing saved yet")
        let view = try sampleView()
        try store.save(view)
        XCTAssertEqual(store.writes, 1)
        XCTAssertTrue(temporary.storage.exists(SavedView.fileName))
        XCTAssertEqual(try temporary.storage.read(SavedView.fileName), view.encoded(), "the file holds the document")
        XCTAssertEqual(store.load(), .success(view))
        // A second store over the same storage reads the same view (it survives the presenter).
        XCTAssertEqual(ViewStore(storage: temporary.storage).load(), .success(view))
        // Saving again replaces the file.
        let other = try XCTUnwrap(SavedView(selection: 0, dayOffset: 0, rateIndex: 0, yawSteps: 0, pitchDegrees: 35,
                                            zoomSteps: 0, scaleMode: 0))
        try store.save(other)
        XCTAssertEqual(store.load(), .success(other))
    }

    func testAMissingFileIsItsOwnResult() {
        let store = ViewStore(storage: temporary.storage)
        XCTAssertEqual(store.load(), .failure(.missing))
        XCTAssertEqual(ViewLoadFailure.missing.words, "No view has been saved yet.")
        XCTAssertFalse(temporary.storage.exists(SavedView.fileName), "loading never writes")
    }

    func testDamagedNewerAndOversizedFilesAreRefusedAndLeftUntouched() throws {
        let store = ViewStore(storage: temporary.storage)
        let valid = String(decoding: try sampleView().encoded(), as: UTF8.self)
        let newer = valid.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        XCTAssertNotEqual(newer, valid, "the sample names its schema")
        var oversized = Data(valid.utf8)
        oversized.removeLast()   // drop the closing brace, then pad the document beyond 4,096 bytes
        oversized.append(Data((",\"pad\":\"" + String(repeating: "x", count: SavedView.maxBytes) + "\"}").utf8))
        XCTAssertGreaterThan(oversized.count, SavedView.maxBytes)
        let outOfRange = valid.replacingOccurrences(of: "\"selection\":4", with: "\"selection\":9")
        XCTAssertNotEqual(outOfRange, valid)
        let cases: [(bytes: Data, refusal: SavedViewRefusal)] = [
            (Data("not json".utf8), .damaged),
            (Data(valid.utf8.prefix(20)), .damaged),
            (Data(newer.utf8), .newerVersion),
            (oversized, .oversized),
            (Data(outOfRange.utf8), .outOfRange),
        ]
        for entry in cases {
            try temporary.storage.write(entry.bytes, to: SavedView.fileName)
            XCTAssertEqual(store.load(), .failure(.refused(entry.refusal)), "\(entry.refusal)")
            XCTAssertEqual(try temporary.storage.read(SavedView.fileName), entry.bytes, "a refused file stays as it was")
        }
        XCTAssertEqual(ViewLoadFailure.refused(.damaged).words, "The saved view could not be read (damaged).")
        XCTAssertEqual(ViewLoadFailure.refused(.newerVersion).words,
                       "The saved view could not be read (newer-version).")
        XCTAssertEqual(store.writes, 0, "loading never writes")
    }

    func testWithoutStorageTheViewIsKeptInMemory() throws {
        let store = ViewStore(storage: nil)
        XCTAssertEqual(store.load(), .failure(.missing))
        let view = try sampleView()
        try store.save(view)
        XCTAssertEqual(store.load(), .success(view))
        XCTAssertEqual(store.writes, 1)
    }
}
