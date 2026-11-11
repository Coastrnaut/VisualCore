// CrashRecoveryTests — feature 024 T-A02-602 (FR-A02-605, SC-A02-603; US3 AC1; edge cases; analyze G1).
import FluidArtPlaygroundCore
import VisualCorePersistence
import VisualCoreRendering
import XCTest
@testable import FluidArtPlayground

@MainActor
final class CrashRecoveryTests: XCTestCase {
    private let folder = CaptureModel.folder

    override func setUp() async throws { folder.removeAll() }
    override func tearDown() async throws { folder.removeAll() }

    /// SC-A02-603: 3 stale captures and a stray file inside the folder are removed; a file outside is untouched.
    func testLaunchCleanupRemovesOnlyTheCaptureFolder() throws {
        for _ in 0..<3 { try Data([1]).write(to: folder.makeFileURL(prefix: "FluidArt", extension: "png")) }
        try Data("note".utf8).write(to: folder.url.appendingPathComponent("stray.txt"))
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("fap-outside-\(UUID().uuidString).png")
        try Data([2]).write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        XCTAssertEqual(folder.fileCount, 4)
        _ = FluidArtPlaygroundApp()   // its init runs the launch cleanup
        XCTAssertEqual(folder.fileCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path), "files outside the folder are untouched")
    }

    /// Edge cases: a missing folder gives 0; an unreadable folder does not crash.
    func testMissingAndUnreadableFolders() throws {
        XCTAssertEqual(folder.removeAll(), 0)
        try Data([1]).write(to: folder.makeFileURL(prefix: "FluidArt", extension: "png"))
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.url.path)
        let counted = folder.fileCount   // unreadable: 0, no crash
        XCTAssertEqual(counted, 0)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.url.path)
        XCTAssertEqual(folder.removeAll(), 1)
    }

    /// FR-A02-605 with feature 022's rule: captures land in tmp/Captures, only the latest exists, close removes it.
    func testCapturesLiveInTheFolderAndOnlyTheLatestExists() throws {
        var c = FluidConfiguration()
        c.gridWidth = 32
        c.gridHeight = 32
        let model = PlaygroundModel(configuration: c)
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        model.captureStill()
        guard case .done(let first) = model.capture.state else { return XCTFail("\(model.capture.state)") }
        XCTAssertEqual(first.deletingLastPathComponent().path, folder.url.path)
        model.captureStill()
        XCTAssertEqual(folder.fileCount, 1, "only the latest capture exists")
        model.close()
        XCTAssertEqual(folder.fileCount, 0, "closing removes it")
    }
}
