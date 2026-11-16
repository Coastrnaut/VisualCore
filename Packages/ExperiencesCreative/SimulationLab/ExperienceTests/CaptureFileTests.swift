// CaptureFileTests — feature 120 (A16-P04) T-A16-409 (FR-A16-440; SC-A16-404). The capture class alone, with a
// fake render closure: two captures leave exactly one 1024 × 1024 PNG named `a16-capture-*.png`, a throwing render
// leaves no file and shows the failure sentence, and `clearFolder()` empties the folder.
import Foundation
import ImageIO
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreRendering

/// `SimulationCapture` with a fake renderer in a temporary folder of its own.
@MainActor
final class CaptureFileTests: XCTestCase {
    /// The folder of the running test.
    private var folder: TemporaryFolder!

    /// A failure of the fake renderer.
    private struct RenderFailed: Error {}

    /// A unique folder per test.
    override func setUp() async throws {
        folder = TemporaryFolder(name: "a16-captures-test-" + UUID().uuidString)
    }

    /// Removes the folder.
    override func tearDown() async throws {
        folder.removeAll()
        folder = nil
    }

    /// A fake render: a solid image of the requested size.
    private static func render(_ width: Int, _ height: Int) throws -> StillImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) { bytes[index] = 32 }
        guard let image = StillImage(width: width, height: height, topDownRGBA: bytes) else { throw RenderFailed() }
        return image
    }

    /// The PNG signature.
    private static let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// The regular files in the folder.
    private func files() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder.url, includingPropertiesForKeys: nil)
    }

    /// Two captures leave exactly one 1024 × 1024 PNG named `a16-capture-*.png`, the current one.
    func testTwoCapturesLeaveOneFile() throws {
        let capture = SimulationCapture(folder: folder)
        capture.capture(Self.render)
        let first = try XCTUnwrap(capture.url)
        capture.capture(Self.render)
        let second = try XCTUnwrap(capture.url)
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertEqual(folder.fileCount, 1)
        XCTAssertNil(capture.message)
        let name = second.lastPathComponent
        XCTAssertTrue(name.hasPrefix("a16-capture-") && name.hasSuffix(".png"), name)
        XCTAssertEqual(try files().map(\.lastPathComponent), [name])
        let data = try Data(contentsOf: second)
        XCTAssertEqual(Array(data.prefix(8)), Self.pngSignature)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, SimulationCapture.size)
        XCTAssertEqual(image.height, 1024)
    }

    /// A throwing render after a good capture leaves no file, no url and the failure sentence.
    func testThrowingRenderLeavesNoFile() {
        let capture = SimulationCapture(folder: folder)
        capture.capture(Self.render)
        XCTAssertEqual(folder.fileCount, 1)
        capture.capture { _, _ in throw RenderFailed() }
        XCTAssertEqual(folder.fileCount, 0)
        XCTAssertNil(capture.url)
        XCTAssertEqual(capture.message, SimulationCapture.failureSentence)
        XCTAssertEqual(capture.message, "The picture could not be captured. Please try again.")
    }

    /// `clearFolder()` empties the folder and forgets the capture.
    func testClearFolderEmpties() {
        let capture = SimulationCapture(folder: folder)
        capture.capture(Self.render)
        XCTAssertEqual(folder.fileCount, 1)
        capture.clearFolder()
        XCTAssertEqual(folder.fileCount, 0)
        XCTAssertNil(capture.url)
    }

    /// The default folder is `a16-captures` under the temporary directory.
    func testDefaultFolderName() {
        XCTAssertEqual(SimulationCapture().folder.url.lastPathComponent, "a16-captures")
    }
}
