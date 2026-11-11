// DistortionScene.swift — Showcase scene 3: content rendered into a target, then a bundled ripple shader centered on the
// finger (feature 007 T-F607; FR-F603, FR-F604, FR-F606; US3 AC1). Status `touch=x,y` (view points) or `touch=none`.
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

@MainActor
final class DistortionScene: ShowcaseRenderScene {
    private let settings: ShowcaseSettings
    private var content: ShaderProgram?
    private var ripple: ShaderProgram?
    private var target: RenderTarget?
    private var metrics = ViewMetrics(size: .zero, scale: 1)
    private var tracker = PointerTracker()
    private(set) var touch: Vec2?          // view points
    private var center = Vec2(0.5, 0.5)    // uv
    private(set) var strength = 0.0
    private var time = 0.0
    private(set) var errorMessage: String?
    var scale = 1.0
    var status: String {
        guard let t = touch else { return "touch=none" }
        return "touch=\(Int(t.x.rounded())),\(Int(t.y.rounded()))"
    }

    init(settings: ShowcaseSettings) { self.settings = settings }

    func handle(_ event: PointerEvent) {
        tracker.handle(event)
        if let id = tracker.order.first, let p = tracker.active[id] {
            touch = p
            if let ndc = metrics.toNDC(p) { center = Vec2((ndc.x + 1) / 2, (ndc.y + 1) / 2) }
            strength = 1
        } else if tracker.count == 0 {
            touch = nil
        }
    }

    func setup(_ context: RenderContext) throws {
        let lib = BundleShaders.library()
        guard let vs = BundleShaders.source("gradient.vert"), let cs = BundleShaders.source("stripes.frag"),
              let rs = BundleShaders.source("ripple.frag") else {
            errorMessage = "Missing bundled shader (gradient.vert, stripes.frag or ripple.frag)"
            return
        }
        do {
            content = try context.resources.program(vertex: vs, fragment: cs, library: lib, vertexName: "gradient.vert", fragmentName: "stripes.frag")
            ripple = try context.resources.program(vertex: vs, fragment: rs, library: lib, vertexName: "gradient.vert", fragmentName: "ripple.frag")
            errorMessage = nil
        } catch ShaderError.compile(let d), ShaderError.link(let d) {
            errorMessage = d.first.map { "\($0.file):\($0.line): \($0.message)" } ?? "Shader failed"
        }
        resize(context)
    }

    func resize(_ context: RenderContext) {
        let s = scale > 0 ? scale : 1
        metrics = ViewMetrics(size: Vec2(Double(context.pixelWidth) / s, Double(context.pixelHeight) / s), scale: s)
        if let t = target, t.width == context.pixelWidth, t.height == context.pixelHeight { return }
        if let t = target { context.resources.release(t) }
        target = context.pixelWidth > 0 && context.pixelHeight > 0
            ? try? context.resources.makeRenderTarget(width: context.pixelWidth, height: context.pixelHeight, label: "distortion content")
            : nil
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        if target == nil || metrics.pixelSize.x != Double(context.pixelWidth) || metrics.scale != scale { resize(context) }
        if !settings.reduceMotion { time += frame.delta }
        if touch == nil { strength *= settings.reduceMotion ? 0 : exp(-3 * frame.delta); if strength < 0.01 { strength = 0 } }
        guard let content, let ripple, let target else { return }
        let aspect = context.pixelHeight > 0 ? Float(context.pixelWidth) / Float(context.pixelHeight) : 1
        target.bind()
        vcglViewport(0, 0, GLsizei(target.width), GLsizei(target.height))
        content.use()
        content.set("u_aspect", aspect)
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
        vcglViewport(0, 0, GLsizei(context.pixelWidth), GLsizei(context.pixelHeight))
        ripple.use()
        target.bindColor(unit: 0)
        ripple.set("u_content", Int32(0))
        ripple.set("u_center", SIMD2<Float>(Float(center.x), Float(center.y)))
        ripple.set("u_strength", Float(strength))
        ripple.set("u_time", Float(time))
        ripple.set("u_aspect", aspect)
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    }

    func teardown(_ context: RenderContext) {
        if let content { context.resources.release(content) }
        if let ripple { context.resources.release(ripple) }
        if let target { context.resources.release(target) }
        content = nil; ripple = nil; target = nil
    }
}
