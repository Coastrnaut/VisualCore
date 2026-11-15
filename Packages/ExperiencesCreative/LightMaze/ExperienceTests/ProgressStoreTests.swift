// ProgressStoreTests — feature 098 (A13-P03) T-A13-303 (FR-A13-320; SC-A13-303; clarifications Q1 and Q2; contract
// contracts/progress.md). The saved level progress of Light Maze, files only (each test well under a second):
//   - a save and load round trip is identical (the file is `progress.json` holding exactly the progress's `encoded()`
//     bytes);
//   - damaged (not JSON, unknown id, a different count), truncated, too large (above 16 KB) and newer files are
//     reported with their codes, give fresh progress and are left byte for byte as they were (loading never writes);
//     the next save replaces them;
//   - an interrupted write (a leftover temporary file) and a refused write (a read-only folder) keep the previous file
//     byte-identical, the refusal reported with the storage error's code;
//   - an absent file, as after the app's data reset, gives fresh progress: level 1 open, nothing solved;
//   - without storage the same rules hold in memory.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience

/// A temporary storage of Light Maze (feature 098): its root folder and defaults suite are removed by ``remove()``.
struct TemporaryMazeStorage {
    let root: URL
    let suite: String
    let storage: ExperienceStorage

    /// A new empty storage under the temporary directory.
    init() {
        let name = "lm-progress-" + UUID().uuidString
        root = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        suite = name
        let id = ExperienceID(rawValue: MazeCore.experienceID) ?? ExperienceID(rawValue: "a13.unknown")!
        storage = ExperienceStorage(id: id, root: root, defaults: UserDefaults(suiteName: name) ?? .standard)
    }

    /// The experience's folder (`<root>/a13.light-maze/`).
    var folder: URL {
        root.appendingPathComponent(storage.id.storageNamespace, isDirectory: true)
    }

    /// Removes the folder and the defaults suite.
    func remove() {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
        try? FileManager.default.removeItem(at: root)
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }
}

final class ProgressStoreTests: XCTestCase {
    private var temporary: TemporaryMazeStorage!

    override func setUp() async throws {
        temporary = TemporaryMazeStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    /// Progress with levels 1 and 2 solved (5 and 9 moves), level 3 open.
    private func played() -> LightMazeCore.Progress {
        var progress = LightMazeCore.Progress.fresh()
        XCTAssertTrue(progress.recordSolved(levelIndex: 0, moves: 5))
        XCTAssertTrue(progress.recordSolved(levelIndex: 1, moves: 9))
        return progress
    }

    /// Asserts that `progress` is fresh: 20 levels, level 1 open, every other level locked, nothing solved.
    private func assertFresh(_ progress: LightMazeCore.Progress, _ message: String = "", line: UInt = #line) {
        XCTAssertEqual(progress.encoded(), LightMazeCore.Progress.fresh().encoded(), message, line: line)
        XCTAssertEqual(progress.levels.count, LevelCatalog.bundled.levels.count, message, line: line)
        XCTAssertEqual(progress.levels.count, 20, message, line: line)
        XCTAssertTrue(progress.levels[0].open, message, line: line)
        XCTAssertTrue(progress.levels.dropFirst().allSatisfy { !$0.open }, message, line: line)
        XCTAssertTrue(progress.levels.allSatisfy { !$0.solved && $0.best == nil }, message, line: line)
    }

    /// `data` with the JSON object edited by `change`, sorted keys.
    private func edited(_ data: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    func testASaveAndLoadRoundTripIsIdentical() throws {
        let store = ProgressStore(storage: storage)
        let progress = played()
        XCTAssertEqual(ProgressStore.fileName, "progress.json")
        XCTAssertNil(store.save(progress))
        XCTAssertEqual(storage.list(), ["progress.json"])
        XCTAssertEqual(try storage.read("progress.json"), progress.encoded(), "exactly the encoded progress")
        let loaded = store.load()
        XCTAssertNil(loaded.refusal)
        XCTAssertEqual(loaded.progress.encoded(), progress.encoded())
        XCTAssertTrue(loaded.progress.levels[0].solved)
        XCTAssertEqual(loaded.progress.levels[0].best, 5)
        XCTAssertEqual(loaded.progress.levels[1].best, 9)
        XCTAssertTrue(loaded.progress.levels[2].open)
        XCTAssertFalse(loaded.progress.levels[3].open)
        XCTAssertEqual(store.writes, 1)

        // A new store over the same storage reads the same progress; saving again replaces the file.
        XCTAssertEqual(ProgressStore(storage: storage).load().progress.encoded(), progress.encoded())
        var more = progress
        XCTAssertTrue(more.recordSolved(levelIndex: 2, moves: 3))
        XCTAssertNil(store.save(more))
        XCTAssertEqual(try storage.read("progress.json"), more.encoded())
        XCTAssertEqual(store.load().progress.encoded(), more.encoded())
        XCTAssertEqual(storage.list(), ["progress.json"])
    }

    func testAnAbsentFileGivesFreshProgressAndWritesNothing() throws {
        let store = ProgressStore(storage: storage)
        let loaded = store.load()
        XCTAssertNil(loaded.refusal)
        assertFresh(loaded.progress)
        XCTAssertEqual(storage.list(), [], "loading never writes")
        XCTAssertEqual(store.writes, 0)

        // After the app's data reset (the file removed), progress starts fresh again.
        XCTAssertNil(store.save(played()))
        try storage.remove("progress.json")
        let reset = store.load()
        XCTAssertNil(reset.refusal)
        assertFresh(reset.progress, "after a data reset")
    }

    func testRefusedFilesAreReportedAndLeftUntouched() throws {
        let store = ProgressStore(storage: storage)
        let valid = played().encoded()
        XCTAssertLessThanOrEqual(valid.count, 16 * 1024)
        let unknownID = try edited(valid) { object in
            var levels = object["levels"] as? [[String: Any]] ?? []
            levels[4]["id"] = "lm-99"
            object["levels"] = levels
        }
        let shortList = try edited(valid) { object in
            var levels = object["levels"] as? [[String: Any]] ?? []
            levels.removeLast()
            object["levels"] = levels
        }
        let newer = try edited(valid) { $0["schema"] = 2 }
        var oversized = valid
        oversized.append(Data(repeating: 0x20, count: 16 * 1024))
        let cases: [(bytes: Data, code: String)] = [
            (Data("not progress".utf8), "damaged"),
            (valid.prefix(valid.count / 2), "damaged"),
            (unknownID, "damaged"),
            (shortList, "damaged"),
            (oversized, "too-large"),
            (newer, "newer-version"),
        ]
        for item in cases {
            try storage.write(item.bytes, to: "progress.json")
            let loaded = store.load()
            XCTAssertEqual(loaded.refusal, item.code)
            assertFresh(loaded.progress, item.code)
            XCTAssertEqual(try storage.read("progress.json"), item.bytes, "\(item.code): left byte for byte")
        }
        XCTAssertEqual(store.writes, 0, "loading never writes")

        // The next real change replaces a refused file.
        XCTAssertNil(store.save(played()))
        let loaded = store.load()
        XCTAssertNil(loaded.refusal)
        XCTAssertEqual(loaded.progress.encoded(), valid)
    }

    func testAnInterruptedOrRefusedWriteKeepsThePreviousFileByteIdentical() throws {
        let store = ProgressStore(storage: storage)
        let first = played()
        XCTAssertNil(store.save(first))
        let before = try storage.read("progress.json")

        // A process that ended mid-write leaves its hidden temporary file: readers still see the previous file.
        let partial = Data(before.prefix(before.count / 3))
        try partial.write(to: temporary.folder.appendingPathComponent(".progress.json.tmp-interrupted"))
        XCTAssertEqual(try storage.read("progress.json"), before)
        XCTAssertEqual(store.load().progress.encoded(), first.encoded())
        XCTAssertNil(store.load().refusal)
        XCTAssertEqual(storage.list(), ["progress.json"], "the temporary file is not saved progress")

        // The file system refuses the write midway (a read-only folder): the save is refused and nothing changes.
        var second = first
        XCTAssertTrue(second.recordSolved(levelIndex: 2, moves: 4))
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: temporary.folder.path)
        let refused = store.save(second)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.folder.path)
        XCTAssertEqual(refused, "storage.write-failed")
        XCTAssertEqual(try storage.read("progress.json"), before, "the previous file is byte-identical")
        XCTAssertEqual(store.load().progress.encoded(), first.encoded())
        XCTAssertEqual(store.writes, 1)
    }

    func testWithoutStorageProgressIsKeptInMemory() throws {
        let store = ProgressStore(storage: nil)
        XCTAssertNil(store.storage)
        XCTAssertNil(store.bytes(), "no file yet")
        let empty = store.load()
        XCTAssertNil(empty.refusal)
        assertFresh(empty.progress)
        XCTAssertEqual(store.writes, 0)

        let progress = played()
        XCTAssertNil(store.save(progress))
        XCTAssertEqual(try store.bytes()?.get(), progress.encoded())
        let loaded = store.load()
        XCTAssertNil(loaded.refusal)
        XCTAssertEqual(loaded.progress.encoded(), progress.encoded())
        XCTAssertEqual(store.writes, 1)
    }
}
