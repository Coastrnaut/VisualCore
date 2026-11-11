// BaselineComparisonTests — feature 008 T-F708 (US2, FR-F705, SC-F702): the engine through the VisualCore host
// (path B) matches the reference renderer's sequence (path A) for the same preset, signal and frame steps,
// rendered in lockstep. Measured numbers are printed into the test log as evidence.
import VisualCoreRendering
import XCTest
@testable import ProjectMReference

@MainActor
final class BaselineComparisonTests: XCTestCase {
    private func compare(preset: String, frames: Int) throws -> ImageDiff.Result {
        let b = ProjectMScene(presetPath: HarnessSupport.preset(preset))
        let hostB = try HarnessSupport.host(b)
        let a = EngineFramebufferPath(presetPath: HarnessSupport.preset(preset), width: hostB.pixelSize.width, height: hostB.pixelSize.height)
        let hostA = try HarnessSupport.host(a)
        XCTAssertNil(a.lastError); XCTAssertNil(b.lastError)
        for i in 0..<frames {
            if i == frames - 1 { a.captureNextFrame = true }
            XCTAssertTrue(hostA.renderOneFrame(present: false))
            XCTAssertTrue(hostB.renderOneFrame(present: false))
        }
        let pa = a.captured, pb = hostB.readPixels()
        XCTAssertGreaterThan(ImageDiff.litFraction(pa), 0.01, "path A drew the preset")
        let result = try XCTUnwrap(ImageDiff.compare(pa, pb), "same size \(pa.count) vs \(pb.count)")
        print("BASELINE \(preset) frames=\(frames) size=\(hostB.pixelSize.width)x\(hostB.pixelSize.height) \(result)")
        hostA.destroy(); hostB.destroy()
        return result
    }

    /// SC-F702 (amended): judge VisualCore against the engine's own run-to-run variance measured in the same run.
    private func check(_ preset: String) throws {
        let floors = try (0..<3).map { _ in try EngineNoiseFloorTests().noiseFloor(preset: preset) }
        let floor = floors.map(\.within8).min()!
        let r = try compare(preset: preset, frames: 60)
        print("VERDICT \(preset) visualcore=\(r) engineFloorWithin8=\(String(format: "%.4f", floor)) required>=\(String(format: "%.4f", max(0.95, floor - 0.01)))")
        XCTAssertTrue(r.passes(noiseFloorWithin8: floor), "SC-F702: \(r) vs engine floor \(floor)")
    }

    func testSquarePresetMatchesTheReferenceSequence() throws { try check("100-square.milk") }

    func testWavePresetMatchesTheReferenceSequence() throws { try check("200-wave.milk") }
}
