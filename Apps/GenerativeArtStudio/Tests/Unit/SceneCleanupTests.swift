// SceneCleanupTests — feature 012 T-A01-111 (FR-A01-110, SC-A01-105, edge cases): zero leaks after context loss and
// destroy, shader errors carry file:line, Reduce Motion slows animation.
import XCTest
import GenerativeArtStudioCore
import VisualCoreRendering
import VisualCoreTestSupport
@testable import GenerativeArtStudio

@MainActor
final class SceneCleanupTests: XCTestCase {
    func testContextLossRebuildsEveryFamilyWithoutLeaks() throws {
        for family in SceneFamilyID.allCases {
            let r = try ArtRender.render(ArtRender.document(family))
            let before = r.pixels
            r.host.recreateContext()
            for _ in 0..<3 { XCTAssertTrue(r.host.renderOneFrame(present: false)) }
            let d = ImageComparison.compare(before, r.host.readPixels())
            XCTAssertLessThanOrEqual(d.meanAbsolute, 0.5, "\(family) rebuilt from the document")
            XCTAssertEqual(r.host.resources.stats.leaked, 0, "\(family) after context loss")
            r.host.destroy()
            XCTAssertEqual(r.host.resources.stats.leaked, 0, "\(family) after destroy")
        }
    }

    func testBrokenFamilyShaderReportsFileAndLine() throws {
        let broken = ShaderBundle(files: ["gradient-noise.frag": "precision highp float;\nout vec4 color;\nvoid main() { color = vec4(missing); }\n"])
        let r = try ArtRender.render(ArtRender.document(.gradientNoise), bundle: broken)
        defer { r.host.destroy() }
        XCTAssertTrue(r.scene.errorMessage?.hasPrefix("gradient-noise.frag:3:") ?? false, r.scene.errorMessage ?? "nil")
    }

    func testReduceMotionHalvesTheTimeScale() {
        let slow = SceneModel(family: FamilyCatalog.family(.particles), reduceMotion: true)
        let normal = SceneModel(family: FamilyCatalog.family(.particles), reduceMotion: false)
        XCTAssertEqual(slow.scene.timeScale, 0.5)
        XCTAssertEqual(normal.scene.timeScale, 1)
        slow.close(); normal.close()
        XCTAssertEqual((slow.host?.resources.stats.leaked ?? 0) + (normal.host?.resources.stats.leaked ?? 0), 0)
    }
}
