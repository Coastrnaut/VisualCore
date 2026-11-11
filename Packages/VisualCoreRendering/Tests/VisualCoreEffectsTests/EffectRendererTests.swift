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
}
