// StillCaptureTests — feature 029 T-A03-404 (FR-A03-403; contract capture-tour-cost).
import CVisualCoreGL
import ImageIO
import VisualCorePersistence
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
private final class SolidScene: RenderScene {
    func setup(_ context: RenderContext) throws {}
    func resize(_ context: RenderContext) {}
    func teardown(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(0.2, 0.6, 1.0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
}

@MainActor
final class StillCaptureTests: XCTestCase {
    private var folder: TemporaryFolder!
    private var host: RenderHost!

    override func setUp() async throws {
        folder = TemporaryFolder(name: "StillCaptureTests-\(UUID().uuidString)")
        host = try RenderHost(scene: SolidScene())
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
    }

    override func tearDown() async throws {
        host.destroy()
        _ = folder.removeAll()
    }

    private func pngSize(_ url: URL) throws -> (Int, Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image.width, image.height)
    }

    func testCaptureWritesAPNGOfTheRequestedSize() throws {
        let capture = StillCapture(folder: folder)
        guard case .done(let url) = capture.capture(host: host, size: ExportSize(width: 96, height: 64), prefix: "Test") else {
            return XCTFail("capture failed: \(capture.state)")
        }
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Test"))
        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertEqual(try pngSize(url).0, 96)
        XCTAssertEqual(try pngSize(url).1, 64)
        XCTAssertEqual(folder.fileCount, 1)
        let p = try XCTUnwrap(capture.lastImage).pixel(x: 10, y: 10)
        XCTAssertEqual(Int(p.z), 255)
    }

    func testASecondCaptureReplacesTheFile() throws {
        let capture = StillCapture(folder: folder)
        guard case .done(let first) = capture.capture(host: host, size: ExportSize(width: 32, height: 32), prefix: "A"),
              case .done(let second) = capture.capture(host: host, size: ExportSize(width: 48, height: 32), prefix: "B") else {
            return XCTFail("capture failed")
        }
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertEqual(folder.fileCount, 1)
    }

    func testInvalidSizeFailsWithAMessageAndNoFile() {
        let capture = StillCapture(folder: folder)
        _ = capture.capture(host: host, size: ExportSize(width: 32, height: 32), prefix: "Ok")
        let huge = host.maxRenderSize + 2
        XCTAssertEqual(capture.capture(host: host, size: ExportSize(width: huge, height: 32), prefix: "Huge"),
                       .failed("This picture size is too large for this device."))
        XCTAssertEqual(folder.fileCount, 0)
    }

    func testRemoveFileDeletes() throws {
        let capture = StillCapture(folder: folder)
        guard case .done(let url) = capture.capture(host: host, size: ExportSize(width: 32, height: 32), prefix: "R") else {
            return XCTFail("capture failed")
        }
        capture.removeFile()
        XCTAssertEqual(capture.state, .idle)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
