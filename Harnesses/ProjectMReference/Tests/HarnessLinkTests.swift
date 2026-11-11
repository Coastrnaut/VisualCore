// HarnessLinkTests — feature 008 T-F702: the reference engine framework and VisualCore load in one process.
import ProjectMBridge
import VisualCoreRendering
import XCTest
@testable import ProjectMReference

final class HarnessLinkTests: XCTestCase {
    func testEngineFrameworkAndVisualCoreLoad() {
        XCTAssertGreaterThan(ProjectMEngine.maxSamplesPerFrame, 0, "the reference engine framework is linked and loaded")
        XCTAssertEqual(Bundle.main.bundleIdentifier, "dev.visualcore.harness.ProjectMReference")
    }

    /// Upstream test presets read in place from the read-only reference (as its own tests do).
    static let presetsDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("External/projectm-ios/Vendor/projectM/presets/tests")

    func testUpstreamTestPresetsAreReadable() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: Self.presetsDirectory.appendingPathComponent("100-square.milk").path))
    }
}
