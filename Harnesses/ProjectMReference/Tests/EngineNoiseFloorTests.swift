// EngineNoiseFloorTests — feature 008 T-F708 investigation: two identical reference-sequence renderers (path A vs
// path A') in lockstep, no VisualCore host in the comparison. Their difference is the engine's own run-to-run
// variance (wall-clock animation, creation-time skew), the floor any A/B comparison can reach.
import VisualCoreRendering
import XCTest
@testable import ProjectMReference

@MainActor
final class EngineNoiseFloorTests: XCTestCase {
    func noiseFloor(preset: String, frames: Int = 60, size: Int = 192) throws -> ImageDiff.Result {
        let a = EngineFramebufferPath(presetPath: HarnessSupport.preset(preset), width: size, height: size)
        let a2 = EngineFramebufferPath(presetPath: HarnessSupport.preset(preset), width: size, height: size)
        let hostA = try HarnessSupport.host(a), hostA2 = try HarnessSupport.host(a2)
        for i in 0..<frames {
            if i == frames - 1 { a.captureNextFrame = true; a2.captureNextFrame = true }
            XCTAssertTrue(hostA.renderOneFrame(present: false))
            XCTAssertTrue(hostA2.renderOneFrame(present: false))
        }
        let r = try XCTUnwrap(ImageDiff.compare(a.captured, a2.captured))
        print("NOISEFLOOR \(preset) frames=\(frames) size=\(size)x\(size) \(r)")
        hostA.destroy(); hostA2.destroy()
        return r
    }

    func testMeasureNoiseFloor() throws {
        for preset in ["100-square.milk", "200-wave.milk"] {
            for _ in 0..<3 { _ = try noiseFloor(preset: preset) }
        }
    }
}
