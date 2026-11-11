// EffectCleanupSweepTests — feature 010 T-F919 (FR-F908): EffectScene (bloom + feedback graph, with and without Reduce
// Flashing) over a sample scene releases every pooled target, history and program after context loss and destroy.
import XCTest
import VisualCoreEffectsGraph
@testable import VisualCoreEffects
@testable import VisualCoreRendering

@MainActor
final class EffectCleanupSweepTests: XCTestCase {
    private func graph() -> EffectGraphDescription {
        EffectGraphDescription(passes: [
            EffectPassDescription(id: "glow", type: "bloom", inputs: ["input": effectSceneSource], output: "glow"),
            EffectPassDescription(id: "trail", type: "feedback", inputs: ["input": "glow"], output: "trail"),
        ], output: "trail")
    }

    private func sweep(reduceFlashing: Bool) throws {
        let scene = EffectScene(content: GradientQuadScene(), graph: graph())
        scene.reduceFlashing = reduceFlashing
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 48, height: 32)
        host.view.layoutIfNeeded()
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        host.recreateContext()
        for _ in 0..<5 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertNil(scene.lastError)
        XCTAssertEqual(host.resources.stats.leaked, 0, "after context loss")
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0, "after destroy")
    }

    func testEffectSceneReleasesEverything() throws { try sweep(reduceFlashing: false) }
    func testEffectSceneWithReduceFlashingReleasesEverything() throws { try sweep(reduceFlashing: true) }
}
