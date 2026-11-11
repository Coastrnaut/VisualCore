// EffectsOverEngineTests — feature 008 T-F706 (US3, FR-F704; migration-log boundary 2a): VisualCore effect graphs
// run over the unmodified engine's output in the same GL context, and the engine keeps rendering.
import VisualCoreEffects
import VisualCoreEffectsGraph
import VisualCoreRendering
import XCTest
@testable import ProjectMReference

@MainActor
final class EffectsOverEngineTests: XCTestCase {
    static let swap = EffectGraphDescription(passes: [
        EffectPassDescription(id: "swap", type: "colorMatrix", inputs: ["input": "scene"], output: "o",
                              params: ["matrix": [0, 0, 1, 0,  0, 1, 0, 0,  1, 0, 0, 0,  0, 0, 0, 1]]),
    ], output: "o")
    static let passthrough = EffectGraphDescription(passes: [
        EffectPassDescription(id: "copy", type: "copy", inputs: ["input": "scene"], output: "o"),
    ], output: "o")

    private func means(_ p: [UInt8]) -> (r: Double, g: Double, b: Double) {
        var r = 0, g = 0, b = 0
        for i in stride(from: 0, to: p.count, by: 4) { r += Int(p[i]); g += Int(p[i + 1]); b += Int(p[i + 2]) }
        let n = Double(max(1, p.count / 4))
        return (Double(r) / n, Double(g) / n, Double(b) / n)
    }

    func testColorSwapOverTheEngine() throws {
        // AC1: engine alone (A) and engine inside EffectScene with a red↔blue swap (B), rendered in lockstep.
        let plain = ProjectMScene(presetPath: HarnessSupport.preset("100-square.milk"))
        let wrapped = ProjectMScene(presetPath: HarnessSupport.preset("100-square.milk"))
        let effect = EffectScene(content: wrapped, graph: Self.swap)
        let a = try HarnessSupport.host(plain), b = try HarnessSupport.host(effect)
        for _ in 0..<30 {
            XCTAssertTrue(a.renderOneFrame(present: false))
            XCTAssertTrue(b.renderOneFrame(present: false))
        }
        XCTAssertNil(effect.lastError)
        XCTAssertEqual(wrapped.frames, 30, "the engine keeps rendering inside the effect scene")
        let ma = means(a.readPixels()), mb = means(b.readPixels())
        XCTAssertGreaterThan(abs(ma.r - ma.b), 3, "the preset's red and blue differ, so a swap is observable (\(ma))")
        XCTAssertEqual(mb.r, ma.b, accuracy: 3, "B red = A blue (\(ma) vs \(mb))")
        XCTAssertEqual(mb.b, ma.r, accuracy: 3, "B blue = A red")
        XCTAssertEqual(mb.g, ma.g, accuracy: 3, "green unchanged")
        a.destroy(); b.destroy()
        XCTAssertEqual(a.resources.stats.leaked + b.resources.stats.leaked, 0)
    }

    func testReduceFlashingBoundsTheEngineOutput() throws {
        // Edge case: Reduce Flashing on → the limiter bounds the per-frame mean-luminance change of the engine output.
        let scene = ProjectMScene(presetPath: HarnessSupport.preset("200-wave.milk"))
        let effect = EffectScene(content: scene, graph: Self.passthrough)
        effect.reduceFlashing = true
        let host = try HarnessSupport.host(effect)
        var lumas: [Double] = []
        for _ in 0..<40 {
            XCTAssertTrue(host.renderOneFrame(present: false))
            let m = means(host.readPixels())
            lumas.append(0.2126 * m.r + 0.7152 * m.g + 0.0722 * m.b)
        }
        XCTAssertEqual(effect.renderer?.lastOrder.last, EffectScene.flashLimitPassID)
        let maxStep = zip(lumas, lumas.dropFirst()).map { abs($1 - $0) }.max() ?? 0
        // limit 0.3/s × 1/60 s × 255 ≈ 1.3 levels per frame, plus readback/quantization slack.
        XCTAssertLessThanOrEqual(maxStep, 0.3 / 60 * 255 + 2, "per-frame luminance steps \(maxStep)")
        host.destroy()
    }
}
