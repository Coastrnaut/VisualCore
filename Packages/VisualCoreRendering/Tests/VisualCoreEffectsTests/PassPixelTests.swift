// PassPixelTests — feature 005, one test group per built-in pass (SC-F402). Added one effect per task.
import CVisualCoreGL
import VisualCoreEffectsGraph
import XCTest
@testable import VisualCoreEffects
@testable import VisualCoreRendering

@MainActor
final class PassPixelTests: XCTestCase {
    // MARK: copy (T-F406)

    func testCopyReproducesTheInputAndOrdersPasses() throws {
        var out: [UInt8] = []
        var order: [String] = []
        _ = try EffectHarness.run { ctx in
            let scene = try EffectHarness.solid(0.2, 0.4, 0.6, in: ctx)
            let renderer = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "A", type: "copy", inputs: ["input": "scene"], output: "a"),
                EffectPassDescription(id: "B", type: "copy", inputs: ["input": "a"], output: "b"),
            ], output: "b"), registry: ctx.resources)
            let result = try renderer.render(scene: scene, time: 0, delta: 1.0 / 60)
            out = result.readPixels()
            order = renderer.lastOrder
        }
        XCTAssertEqual(order, ["A", "B"])
        let p = EffectHarness.pixel(out, width: 16, x: 8, y: 8)
        XCTAssertEqual(p.x, 51, accuracy: 1); XCTAssertEqual(p.y, 102, accuracy: 1); XCTAssertEqual(p.z, 153, accuracy: 1)
    }

    func testInvalidGraphIsRejectedBeforeGPUWork() throws {
        var caught: Error?
        let host = try EffectHarness.run { ctx in
            do {
                _ = try EffectRenderer(graph: EffectHarness.graph([
                    EffectPassDescription(id: "A", type: "copy", inputs: ["input": "b"], output: "a"),
                    EffectPassDescription(id: "B", type: "copy", inputs: ["input": "a"], output: "b"),
                ], output: "b"), registry: ctx.resources)
            } catch { caught = error }
        }
        XCTAssertEqual(caught as? EffectGraphError, .cycle(["A", "B"]))
        XCTAssertEqual(host.resources.compileCount, 0)
    }
}
