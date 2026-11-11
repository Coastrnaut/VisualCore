// EffectSceneBypassTests — feature 016 T-A01-502 (FR-A01-502, FR-A01-506; research R3, R4).
import CVisualCoreGL
import UIKit
import VisualCoreEffectsGraph
import XCTest
@testable import VisualCoreEffects
@testable import VisualCoreRendering

/// Clears to a color chosen per frame (black on even frames, white on odd ones when `alternate`).
@MainActor
private final class ClearScene: RenderScene {
    var alternate = false
    var color: (Float, Float, Float) = (0.2, 0.4, 0.6)
    private var frames = 0
    func setup(_ context: RenderContext) throws {}
    func resize(_ context: RenderContext) {}
    func teardown(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        let c: (Float, Float, Float) = alternate ? (frames % 2 == 0 ? (0, 0, 0) : (1, 1, 1)) : color
        frames += 1
        vcglClearColor(c.0, c.1, c.2, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
}

@MainActor
final class EffectSceneBypassTests: XCTestCase {
    private let copyGraph = EffectGraphDescription(passes: [EffectPassDescription(id: "copy", type: "copy", inputs: ["input": effectSceneSource],
                                                                                  output: "out")], output: "out")

    private func host(_ scene: RenderScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        return host
    }

    private func meanLuma(_ p: [UInt8]) -> Double {
        var sum = 0.0
        for i in stride(from: 0, to: p.count, by: 4) { sum += 0.2126 * Double(p[i]) + 0.7152 * Double(p[i + 1]) + 0.0722 * Double(p[i + 2]) }
        return sum / Double(p.count / 4) / 255
    }

    func testBypassMatchesDirectContent() throws {
        let direct = try host(ClearScene())
        defer { direct.destroy() }
        XCTAssertTrue(direct.renderOneFrame(present: false))
        let effect = EffectScene(content: ClearScene(), graph: copyGraph)
        effect.bypassEffects = true
        let wrapped = try host(effect)
        defer { wrapped.destroy() }
        XCTAssertTrue(wrapped.renderOneFrame(present: false))
        XCTAssertEqual(direct.readPixels(), wrapped.readPixels())
        XCTAssertNil(effect.renderer, "bypass never builds the graph")
    }

    func testBypassKeepsLimiterState() throws {
        let content = ClearScene()
        content.alternate = true
        let effect = EffectScene(content: content, graph: copyGraph)
        effect.reduceFlashing = true
        let host = try host(effect)
        defer { host.destroy() }
        var lumas: [Double] = []
        for _ in 0..<6 { XCTAssertTrue(host.renderOneFrame(present: false)); lumas.append(meanLuma(host.readPixels())) }
        let renderer = try XCTUnwrap(effect.renderer)
        for (a, b) in zip(lumas, lumas.dropFirst()) { XCTAssertLessThanOrEqual(abs(b - a), 0.3 / 60 + 1.0 / 255 + 1e-9) }
        effect.bypassEffects = true
        XCTAssertTrue(host.renderOneFrame(present: false))
        let bypassed = meanLuma(host.readPixels())
        XCTAssertTrue(bypassed < 0.01 || bypassed > 0.99, "bypass shows the unlimited content: \(bypassed)")
        effect.bypassEffects = false
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertTrue(effect.renderer === renderer, "the limiter renderer survives a bypass")
        XCTAssertLessThanOrEqual(abs(meanLuma(host.readPixels()) - lumas.last!), 2 * (0.3 / 60) + 2.0 / 255,
                                 "no jump after the bypass")
    }

    func testNoLeaksAfterDestroy() throws {
        let effect = EffectScene(content: ClearScene(), graph: copyGraph)
        effect.reduceFlashing = true
        let host = try host(effect)
        for bypass in [false, true, false, true] { effect.bypassEffects = bypass; XCTAssertTrue(host.renderOneFrame(present: false)) }
        let registry = host.resources
        host.destroy()
        XCTAssertEqual(registry.stats.leaked, 0)
        XCTAssertEqual(registry.stats.liveTotal, 0)
    }
}
