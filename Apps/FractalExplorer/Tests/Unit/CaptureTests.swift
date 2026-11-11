// CaptureTests — feature 029 T-A03-407 (FR-A03-405, SC-A03-403; US2 AC1–AC4; analyze G2).
import FractalExplorerCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import XCTest
@testable import FractalExplorer

@MainActor
final class CaptureTests: XCTestCase {
    private func model(size: Vec2 = Vec2(300, 400)) -> ExplorerModel {
        let m = ExplorerModel(size: size,
                              bookmarksDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("fe-cap-\(UUID().uuidString)"))
        m.host?.view.frame = CGRect(x: 0, y: 0, width: size.x, height: size.y)
        m.host?.view.layoutIfNeeded()
        XCTAssertEqual(m.host?.renderOneFrame(present: false), true)
        m.pixelsPerPointOverride = 3
        m.mantissaBitsOverride = 23
        return m
    }

    func testCaptureMatchesTheCPUReferenceAndKeepsTheAspect() throws {
        let m = model()
        defer { m.close() }
        m.zoomIn()
        m.captureStill()
        guard case .done(let url) = m.capture.state else { return XCTFail("capture failed: \(m.capture.state)") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let image = try XCTUnwrap(m.capture.lastImage)
        XCTAssertEqual(max(image.width, image.height), min(4096, m.host?.maxRenderSize ?? 4096) - min(4096, m.host?.maxRenderSize ?? 4096) % 2)
        XCTAssertEqual(Double(image.width) / Double(image.height), 300.0 / 400.0, accuracy: 0.002)
        XCTAssertEqual(m.captureMessage, "Captured at \(max(image.width, image.height)) px")
        // 64 sample points: escape classes agree with the CPU reference at the same plane points.
        let state = m.state
        var agree = 0
        for j in 0..<8 { for i in 0..<8 {
            let x = (i * 2 + 1) * image.width / 16, y = (j * 2 + 1) * image.height / 16
            let screen = Vec2((Double(x) + 0.5) / Double(image.width) * 300, (Double(y) + 0.5) / Double(image.height) * 400)
            let cpu = state.escape(at: state.viewport.plane(fromScreen: screen)).interior
            let p = image.pixel(x: x, y: y)
            let gpu = Int(p.x) <= 1 && Int(p.y) <= 1 && Int(p.z) <= 1
            if cpu == gpu { agree += 1 }
        } }
        print("capture agreement: \(agree)/64")
        XCTAssertGreaterThanOrEqual(Double(agree) / 64, 0.99)
        XCTAssertEqual(m.scene.snapshot.animate, m.animate, "animation restored")
    }

    func testDeepViewIsLimitedByPrecision() throws {
        let m = model()
        defer { m.close() }
        m.mantissaBitsOverride = 10
        for _ in 0..<5 { m.zoomIn() }
        m.captureStill()
        guard case .done = m.capture.state else { return XCTFail("capture failed") }
        let image = try XCTUnwrap(m.capture.lastImage)
        XCTAssertLessThan(max(image.width, image.height), 4096)
        XCTAssertEqual(m.captureMessage, "Captured at \(max(image.width, image.height)) px — the precision limit allows no more detail here")
    }

    func testFailureLeavesNoFileAndCloseRemovesTheFile() throws {
        let m = model()
        m.captureStill()
        guard case .done(let url) = m.capture.state else { return XCTFail("capture failed") }
        m.captureSizeOverride = ExportSize(width: (m.host?.maxRenderSize ?? 8192) + 2, height: 32)
        m.captureStill()
        XCTAssertEqual(m.capture.state, .failed("This picture size is too large for this device."))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        m.captureSizeOverride = nil
        m.captureStill()
        guard case .done(let second) = m.capture.state else { return XCTFail("capture failed") }
        m.close()
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path), "leaving removes the file")
    }

    func testLaunchCleanupEmptiesTheFolder() throws {
        let folder = StillCapture.folder(named: ExplorerModel.captureFolderName)
        let url = try folder.makeFileURL(prefix: "Leftover", extension: "png")
        try Data([1, 2, 3]).write(to: url)
        XCTAssertGreaterThanOrEqual(FractalExplorerApp.cleanUpCaptures(), 1)
        XCTAssertEqual(folder.fileCount, 0)
    }

    func testNoCaptureWithoutAHost() {
        let m = model()
        m.close()
        XCTAssertFalse(m.canCapture)
        m.captureStill()
        XCTAssertEqual(m.capture.state, .idle)
    }
}
