// EffectRendererTests — feature 005 T-F413 (FR-F408, SC-F404) and T-F415 (EffectScene).
import CVisualCoreGL
import VisualCoreEffectsGraph
import XCTest
@testable import VisualCoreEffects
@testable import VisualCoreRendering

@MainActor
final class EffectRendererTests: XCTestCase {
    func testFailingPassPassesThroughAndIsReportedOnce() throws {
        var pixels: [[UInt8]] = []
        var failed: Set<String> = []
        let host = try EffectHarness.run { ctx in
            let red = try EffectHarness.solid(1, 0, 0, in: ctx)
            let swap: [Double] = [0, 0, 1, 0,  0, 1, 0, 0,  1, 0, 0, 0,  0, 0, 0, 1]
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "A", type: "copy", inputs: ["input": "scene"], output: "a"),
                EffectPassDescription(id: "B", type: "colorMatrix", inputs: ["input": "a"], output: "b", params: ["matrix": swap]),
                EffectPassDescription(id: "C", type: "copy", inputs: ["input": "b"], output: "c"),
            ], output: "c"), registry: ctx.resources)
            r.injectedFailures = ["B"]
            for _ in 0..<3 { pixels.append(try r.render(scene: red, time: 0, delta: 0).readPixels()) }
            failed = r.failedPasses
        }
        XCTAssertEqual(failed, ["B"])
        for p in pixels {
            let px = EffectHarness.pixel(p, width: 16, x: 1, y: 1)
            XCTAssertGreaterThanOrEqual(px.x, 254, "B passed red through instead of swapping to blue")
            XCTAssertLessThanOrEqual(px.z, 1)
        }
        XCTAssertEqual(host.resources.stats.warnings.filter { $0.contains("effect pass B failed") }.count, 1)
    }

    // MARK: EffectScene (T-F415; FR-F410, FR-F411, SC-F405)

    private static let swapGraph = EffectHarness.graph([
        EffectPassDescription(id: "swap", type: "colorMatrix", inputs: ["input": "scene"], output: "s",
                              params: ["matrix": [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1]]),
        EffectPassDescription(id: "soft", type: "blur", inputs: ["input": "s"], output: "b", params: ["radius": [1]]),
        EffectPassDescription(id: "out", type: "copy", inputs: ["input": "b"], output: "o"),
    ], output: "o")

    private func px(_ host: RenderHost, x: Int) -> SIMD4<Int> {
        EffectHarness.pixel(host.readPixels(), width: host.pixelSize.width, x: x, y: host.pixelSize.height / 2)
    }

    func testEffectSceneRendersContentThroughAThreePassGraph() throws {
        let scene = EffectScene(content: GradientQuadScene(), graph: Self.swapGraph)
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertNil(scene.lastError)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let left = px(host, x: 2), right = px(host, x: host.pixelSize.width - 3)
        XCTAssertGreaterThan(left.z, 200, "red gradient start swapped to blue")
        XCTAssertGreaterThan(right.x, 200, "blue gradient end swapped to red")
        XCTAssertEqual(scene.renderer?.lastOrder, ["swap", "soft", "out"])
    }

    func testEffectSceneSurvivesResizeAndRecreation() throws {
        let scene = EffectScene(content: GradientQuadScene(), graph: Self.swapGraph)
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 16)
        host.view.layoutIfNeeded()
        host.view.frame = CGRect(x: 0, y: 0, width: 20, height: 40)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertGreaterThan(px(host, x: 2).z, 200)
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertGreaterThan(px(host, x: 2).z, 200)
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0, "the effect scene releases what it allocated")
    }

    func testReduceFlashingAppendsTheLimiter() throws {
        let scene = EffectScene(content: ClearColorScene(red: 1, green: 1, blue: 1), graph: Self.swapGraph)
        scene.reduceFlashing = true
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(scene.renderer?.lastOrder.last, EffectScene.flashLimitPassID)
    }
}
