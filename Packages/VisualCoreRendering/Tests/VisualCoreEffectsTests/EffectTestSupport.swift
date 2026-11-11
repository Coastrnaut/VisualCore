// EffectTestSupport — shared helpers for feature 005 simulator tests.
import CVisualCoreGL
import UIKit
import VisualCoreEffectsGraph
@testable import VisualCoreEffects
@testable import VisualCoreRendering

/// Runs a closure once inside scene setup, with the context current.
@MainActor
final class SetupProbe: RenderScene {
    let body: (RenderContext) throws -> Void
    init(_ body: @escaping (RenderContext) throws -> Void) { self.body = body }
    func setup(_ context: RenderContext) throws { try body(context) }
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {}
}

@MainActor
enum EffectHarness {
    /// Creates a host whose scene setup runs `body`; keeps the host alive for the caller.
    static func run(_ body: @escaping (RenderContext) throws -> Void) throws -> RenderHost {
        let host = try RenderHost(scene: SetupProbe(body))
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        return host
    }

    /// A target filled with one color.
    static func solid(_ r: Float, _ g: Float, _ b: Float, _ a: Float = 1, size: Int = 16, in ctx: RenderContext) throws -> RenderTarget {
        let t = try ctx.resources.makeRenderTarget(width: size, height: size, label: "solid")
        t.bind()
        vcglViewport(0, 0, GLsizei(size), GLsizei(size))
        vcglClearColor(r, g, b, a)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        return t
    }

    /// A black target with one white pixel at (x, y).
    static func dot(size: Int = 32, x: Int, y: Int, in ctx: RenderContext) throws -> RenderTarget {
        let t = try solid(0, 0, 0, size: size, in: ctx)
        vcglEnable(GLenum(GL_SCISSOR_TEST))
        vcglScissor(GLint(x), GLint(y), 1, 1)
        vcglClearColor(1, 1, 1, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        vcglDisable(GLenum(GL_SCISSOR_TEST))
        return t
    }

    static func pixel(_ p: [UInt8], width: Int, x: Int, y: Int) -> SIMD4<Int> {
        let i = (y * width + x) * 4
        return SIMD4(Int(p[i]), Int(p[i + 1]), Int(p[i + 2]), Int(p[i + 3]))
    }

    static func graph(_ passes: [EffectPassDescription], output: String) -> EffectGraphDescription {
        EffectGraphDescription(passes: passes, output: output)
    }
}
