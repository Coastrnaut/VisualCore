// CrashRecoveryTests — feature 031 T-A03-605 (FR-A03-603, SC-A03-603; US3 AC2–AC3; spec 031 clarification 2): a
// killed session leaves nothing that breaks or clutters the next one.
import FractalExplorerCore
import VisualCoreMath
import VisualCorePersistence
import VisualCoreRendering
import XCTest
@testable import FractalExplorer

@MainActor
final class CrashRecoveryTests: XCTestCase {
    func testStaleCapturesAreRemovedAtLaunch() throws {
        let folder = StillCapture.folder(named: ExplorerModel.captureFolderName)
        for i in 0..<3 { try Data([UInt8(i)]).write(to: try folder.makeFileURL(prefix: "Killed", extension: "png")) }
        XCTAssertGreaterThanOrEqual(folder.fileCount, 3)
        FractalExplorerApp.cleanUpCaptures()
        XCTAssertEqual(folder.fileCount, 0)
    }

    func testInterruptedBookmarkWriteRecovers() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fe-crash-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        var lib = BookmarkLibrary.bookmarks(directory: dir)
        let good = try lib.save(MigrationTests.expected, name: "Intact")
        let leftover = dir.appendingPathComponent(".\(UUID().uuidString).json.tmp-4242")
        try Data("half a bookmark".utf8).write(to: leftover)
        let unrelated = dir.appendingPathComponent("notes.txt")
        try Data("not a bookmark".utf8).write(to: unrelated)

        var again = BookmarkLibrary.bookmarks(directory: dir)
        again.reload()
        XCTAssertEqual(again.entries.map(\.id), [good.id], "the intact bookmark loads")
        XCTAssertEqual(again.problems, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: leftover.path), "the store's own leftover is removed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path), "other files are left alone")
    }
}
