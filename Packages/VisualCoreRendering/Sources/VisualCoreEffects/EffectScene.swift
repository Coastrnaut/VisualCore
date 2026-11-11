// EffectScene.swift — wraps any RenderScene with an effect graph (feature 005 T-F415; FR-F410, FR-F411).
// The content renders into a pooled-size scene target, the graph runs over it, and the result is
// copied to the window. With `reduceFlashing` the flash limiter is appended as the final pass.
import CVisualCoreGL
import VisualCoreEffectsGraph
import VisualCoreRendering

@MainActor
public final class EffectScene: RenderScene {
    public static let flashLimitPassID = "__flashLimit"

    public let content: RenderScene
    public var graph: EffectGraphDescription { didSet { rebuildPending = true } }
    /// Appends the Reduce-Flashing limiter (FR-F409) as the final pass.
    public var reduceFlashing = false { didSet { if reduceFlashing != oldValue { rebuildPending = true } } }
    /// Maximum change of displayed mean luminance per second; a change rebuilds the graph (FR-F409).
    public var flashLimitPerSecond = 0.3 { didSet { if flashLimitPerSecond != oldValue, reduceFlashing { rebuildPending = true } } }
    public private(set) var lastError: Error?
    public private(set) var renderer: EffectRenderer?

    private var sceneTarget: RenderTarget?
    private var present: ShaderProgram?
    private var rebuildPending = true

    public init(content: RenderScene, graph: EffectGraphDescription) {
        self.content = content
        self.graph = graph
    }

    /// The graph actually run: the app graph plus the limiter when Reduce Flashing is on.
    public var effectiveGraph: EffectGraphDescription {
        guard reduceFlashing else { return graph }
        var g = graph
        g.passes.append(EffectPassDescription(id: Self.flashLimitPassID, type: "flashLimit", inputs: ["input": graph.output],
                                              output: Self.flashLimitPassID, params: ["limit": [flashLimitPerSecond]]))
        g.output = Self.flashLimitPassID
        return g
    }

    public func setup(_ context: RenderContext) throws {
        try content.setup(context)
        present = try context.resources.program(vertex: EffectShaders.vertex, fragment: EffectShaders.copy)
        rebuildPending = true
        if context.pixelWidth > 0, context.pixelHeight > 0 { try makeSceneTarget(context) }
    }

    public func resize(_ context: RenderContext) {
        do { try makeSceneTarget(context) } catch { lastError = error }
        renderer?.invalidate()
        content.resize(context)
    }

    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        if sceneTarget == nil { try makeSceneTarget(context) }
        guard let sceneTarget, let present else { return }
        if rebuildPending {
            renderer?.invalidate()
            do {
                renderer = try EffectRenderer(graph: effectiveGraph, registry: context.resources)
                lastError = nil
            } catch {
                renderer = nil
                lastError = error
            }
            rebuildPending = false
        }
        sceneTarget.bind()
        vcglViewport(0, 0, GLsizei(sceneTarget.width), GLsizei(sceneTarget.height))
        // Content that binds `context.framebuffer` itself (the host contract, e.g. a foreign engine) must still land
        // in the scene target (feature 008 T-F706).
        try content.render(context.redirected(to: sceneTarget.handle.name, width: sceneTarget.width, height: sceneTarget.height),
                           frame: frame)
        var output = sceneTarget
        if let renderer {
            do { output = try renderer.render(scene: sceneTarget, time: frame.time, delta: frame.delta) }
            catch { lastError = error }
        }
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
        vcglViewport(0, 0, GLsizei(context.pixelWidth), GLsizei(context.pixelHeight))
        present.use()
        output.bindColor(unit: 0)
        present.set("u_input", Int32(0))
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
    }

    public func teardown(_ context: RenderContext) {
        renderer?.invalidate()
        renderer = nil
        if let sceneTarget { context.resources.release(sceneTarget) }
        sceneTarget = nil
        if let present { context.resources.release(present) }
        present = nil
        content.teardown(context)
    }

    private func makeSceneTarget(_ context: RenderContext) throws {
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        if let t = sceneTarget, t.width == context.pixelWidth, t.height == context.pixelHeight { return }
        if let t = sceneTarget { context.resources.release(t) }
        sceneTarget = try context.resources.makeRenderTarget(width: context.pixelWidth, height: context.pixelHeight, label: "effect scene")
    }
}
