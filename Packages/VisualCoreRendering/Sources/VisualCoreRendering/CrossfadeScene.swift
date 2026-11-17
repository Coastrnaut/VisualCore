// CrossfadeScene — feature 133 (A18-P03) T-A18-302 (FR-A18-303, FR-A18-307; G-TRANSITION).
// Contract: specs/133-ac-p03-themes-favourites/contracts/crossfade.md; clarifications Q1 and Q5 of its spec.
// A RenderScene that mixes two child scenes: each is drawn into an owned RGBA8 render target of the drawable size
// through `context.redirected(to:width:height:)`, and one full-screen pass writes `mix(a, b, progress)` (linear in
// display space) to `context.framebuffer`. The mix reads exact texels (`texelFetch` at the fragment's pixel), and at
// progress 0 or 1 only the visible child is drawn, straight into the context's framebuffer, so the end frames are byte
// for byte the child's own frame. The targets are made lazily at the first mixed frame, released on resize (and made
// again at the next mixed frame at the new size) and rebuilt after a context recreation. A change during a fade
// restarts it from the current mix: `captureOutgoingFromMix(_:)` reads the picture back once and keeps it as a still
// outgoing picture (re-uploaded after a context loss); `replaceIncoming(_:context:)` does that and swaps the incoming
// scene.
import CVisualCoreGL

/// A scene crossfading from one child scene to another, on the main thread.
///
/// While it is set up, the crossfade owns the lifecycle of its children: `setup`, `resize` and `teardown` are forwarded
/// to `from` and `to` (once when they are the same object), and `replaceIncoming(_:context:)` sets up the new incoming
/// scene and tears down the scenes it drops. The caller sets `progress` (for example from the frame time with an easing);
/// the crossfade never reads the clock. A caller that shows a child alone after the fade should take the child out
/// of the crossfade first (tear the crossfade down, or keep drawing the crossfade at progress 1, which costs the same as
/// drawing the child alone).
@MainActor
public final class CrossfadeScene: RenderScene {
    /// The outgoing scene, shown alone at progress 0. After `captureOutgoingFromMix(_:)` or `replaceIncoming(_:context:)`
    /// this is an internal still picture of the mix captured at that moment, not a caller's scene.
    public private(set) var from: any RenderScene
    /// The incoming scene, shown alone at progress 1.
    public private(set) var to: any RenderScene
    /// How far the fade is, clamped to 0…1 (NaN is taken as 0): 0 draws `from` alone, 1 draws `to` alone, values in
    /// between draw both and mix them per channel as `from × (1 − progress) + to × progress`.
    public var progress: Double {
        get { storedProgress }
        set { storedProgress = newValue.isNaN ? 0 : min(1, max(0, newValue)) }
    }
    /// True between a successful `setup` and the next `teardown`.
    public private(set) var isSetUp = false

    private var storedProgress: Double = 0
    private var program: ShaderProgram?
    private var targetA: RenderTarget?
    private var targetB: RenderTarget?
    private var registry: ResourceRegistry?
    /// Frame timing of the last `render`, used to draw the picture again when it is captured.
    private var lastFrame = FrameInfo(index: 0, time: 0, delta: 0, targetTimestamp: 0)
    /// Distinguishes this instance's mix program in the registry's program cache, so tearing one crossfade down
    /// never deletes the program another crossfade on the same registry still draws with.
    private let instanceID: Int
    private static var nextInstanceID = 0

    /// The mix fragment: exact texels of both targets at this pixel; exactly `a` at progress ≤ 0 and `b` at ≥ 1.
    static let mixFragment = """
    precision highp float;
    uniform highp sampler2D u_from;
    uniform highp sampler2D u_to;
    uniform float u_progress;
    out vec4 color;
    void main() {
        ivec2 p = ivec2(gl_FragCoord.xy);
        vec4 a = texelFetch(u_from, p, 0);
        vec4 b = texelFetch(u_to, p, 0);
        color = u_progress <= 0.0 ? a : (u_progress >= 1.0 ? b : mix(a, b, u_progress));
    }
    """

    /// A crossfade from `from` to `to` at progress 0. Nothing is allocated before `setup`.
    public init(from: any RenderScene, to: any RenderScene) {
        self.from = from
        self.to = to
        Self.nextInstanceID += 1
        instanceID = Self.nextInstanceID
    }

    /// Sets up `from` and `to` and compiles the mix program; the two render targets are made at the first mixed frame.
    /// Targets from an earlier context generation are forgotten (they died with that context). On a failure everything
    /// set up so far is torn down again and the error is rethrown.
    public func setup(_ context: RenderContext) throws {
        registry = context.resources
        releaseTargets()
        try from.setup(context)
        do {
            if to !== from { try to.setup(context) }
        } catch {
            from.teardown(context)
            throw error
        }
        do {
            program = try context.resources.program(vertex: FullScreenShaderScene.vertexSource, fragment: Self.mixFragment,
                                                    defines: ["VC_CROSSFADE_INSTANCE": "\(instanceID)"],
                                                    vertexName: "fullscreen.vert", fragmentName: "crossfade.frag")
        } catch {
            if to !== from { to.teardown(context) }
            from.teardown(context)
            throw error
        }
        isSetUp = true
    }

    /// Resizes both children and releases the targets; the next mixed frame makes them at the new size.
    public func resize(_ context: RenderContext) {
        from.resize(context)
        if to !== from { to.resize(context) }
        releaseTargets()
    }

    /// Draws the picture for `progress` into `context.framebuffer`: `from` alone at 0, `to` alone at 1, otherwise both
    /// into the targets and the mix over the whole framebuffer. A zero-sized context draws nothing. Rethrows a child's
    /// error.
    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        lastFrame = frame
        try drawPicture(context, frame: frame)
    }

    /// Tears down both children and releases the targets and the mix program.
    public func teardown(_ context: RenderContext) {
        if to !== from { to.teardown(context) }
        from.teardown(context)
        releaseTargets()
        if let program { context.resources.release(program) }
        program = nil
        isSetUp = false
    }

    /// Makes the picture shown now the new outgoing picture and restarts the fade at progress 0, so the next frame looks
    /// the same as the last one. The current mix is drawn once more (at the last frame's time) into a temporary target,
    /// read back and kept as a still picture, which becomes `from`; it is re-uploaded after a context recreation and
    /// stretched when drawn at another size. The previous `from` is torn down unless it is also `to`. A zero-sized
    /// context cannot be read back: then the scene that dominates the mix (`to` at progress ≥ 0.5, else `from`)
    /// becomes the outgoing scene. Before `setup` only `progress` is reset.
    public func captureOutgoingFromMix(_ context: RenderContext) throws {
        guard isSetUp else { progress = 0; return }
        let width = context.pixelWidth, height = context.pixelHeight
        let oldFrom = from
        guard width > 0, height > 0 else {
            if progress >= 0.5 {
                from = to
                if oldFrom !== to { oldFrom.teardown(context) }
            }
            progress = 0
            return
        }
        let temporary = try context.resources.makeRenderTarget(width: width, height: height, label: "crossfade-capture")
        let pixels: [UInt8]
        do {
            try drawPicture(context.redirected(to: temporary.handle.name, width: width, height: height), frame: lastFrame)
            pixels = temporary.readPixels()
        } catch {
            context.resources.release(temporary)
            vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
            throw error
        }
        context.resources.release(temporary)
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
        vcglViewport(0, 0, GLsizei(width), GLsizei(height))
        let still = StillPictureScene(width: width, height: height, pixels: pixels)
        try still.setup(context)
        from = still
        if oldFrom !== to { oldFrom.teardown(context) }
        progress = 0
    }

    /// Restarts the fade from the current mix towards `scene`: captures the current picture as the outgoing one
    /// (`captureOutgoingFromMix(_:)`), sets up and resizes `scene` (unless it already is `to` or `from`), makes it `to`
    /// and tears down the previous `to` unless it is still `from`. When `scene` fails to set up, the error is rethrown
    /// and the previous `to` stays the incoming scene (the restart from the current mix has happened). Before `setup`
    /// only `to` and `progress` change; `setup` then sets `scene` up.
    public func replaceIncoming(_ scene: any RenderScene, context: RenderContext) throws {
        guard isSetUp else {
            to = scene
            progress = 0
            return
        }
        try captureOutgoingFromMix(context)
        guard scene !== to else { return }
        if scene !== from {
            try scene.setup(context)
            scene.resize(context)
        }
        let old = to
        to = scene
        if old !== from { old.teardown(context) }
    }

    // MARK: Drawing

    /// The picture for the current progress into `context.framebuffer` (window, export or capture target).
    private func drawPicture(_ context: RenderContext, frame: FrameInfo) throws {
        let width = context.pixelWidth, height = context.pixelHeight
        guard width > 0, height > 0 else { return }
        let p = progress
        guard p > 0, p < 1, let program else {
            vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
            vcglViewport(0, 0, GLsizei(width), GLsizei(height))
            try (p >= 1 ? to : from).render(context, frame: frame)
            return
        }
        let (a, b) = try ensureTargets(width: width, height: height, registry: context.resources)
        for (target, scene) in [(a, from), (b, to)] {
            target.bind()
            vcglViewport(0, 0, GLsizei(width), GLsizei(height))
            try scene.render(context.redirected(to: target.handle.name, width: width, height: height), frame: frame)
        }
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
        vcglViewport(0, 0, GLsizei(width), GLsizei(height))
        vcglBindVertexArray(0)
        for cap in [GL_BLEND, GL_DEPTH_TEST, GL_STENCIL_TEST, GL_CULL_FACE, GL_SCISSOR_TEST] { vcglDisable(GLenum(cap)) }
        vcglColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
        program.use()
        a.bindColor(unit: 0)
        b.bindColor(unit: 1)
        program.set("u_from", Int32(0))
        program.set("u_to", Int32(1))
        program.set("u_progress", Float(p))
        vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        vcglActiveTexture(GLenum(GL_TEXTURE1))
        vcglBindTexture(GLenum(GL_TEXTURE_2D), 0)
        vcglActiveTexture(GLenum(GL_TEXTURE0))
        vcglBindTexture(GLenum(GL_TEXTURE_2D), 0)
    }

    // MARK: Targets

    /// Both targets at `width`×`height`, rebuilt when missing, resized or from another registry generation.
    private func ensureTargets(width: Int, height: Int, registry: ResourceRegistry) throws -> (RenderTarget, RenderTarget) {
        if let targetA, let targetB, targetA.width == width, targetA.height == height,
           targetA.handle.generation == registry.generation, targetB.handle.generation == registry.generation {
            return (targetA, targetB)
        }
        self.registry = registry
        releaseTargets()
        let a = try registry.makeRenderTarget(width: width, height: height, label: "crossfade-from")
        let b: RenderTarget
        do {
            b = try registry.makeRenderTarget(width: width, height: height, label: "crossfade-to")
        } catch {
            registry.release(a)
            throw error
        }
        targetA = a
        targetB = b
        return (a, b)
    }

    /// Releases both targets to the registry; targets of an ended generation are only forgotten.
    private func releaseTargets() {
        for target in [targetA, targetB].compactMap({ $0 }) {
            if let registry, target.handle.generation == registry.generation { registry.release(target) }
        }
        targetA = nil
        targetB = nil
    }
}

/// A still RGBA8 picture drawn as a scene: kept in memory (rows bottom-up), uploaded into an owned render target in
/// `setup` (again after a context recreation) and copied to the context's framebuffer with a framebuffer blit —
/// exact at the same size, stretched linearly at another size. The outgoing picture of a restarted crossfade.
@MainActor
final class StillPictureScene: RenderScene {
    let width: Int, height: Int
    let pixels: [UInt8]
    private var target: RenderTarget?
    private var registry: ResourceRegistry?

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    func setup(_ context: RenderContext) throws {
        release()
        registry = context.resources
        let made = try context.resources.makeRenderTarget(width: width, height: height, label: "crossfade-still")
        if pixels.count == width * height * 4 {
            vcglBindTexture(GLenum(GL_TEXTURE_2D), made.colorTexture)
            vcglPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
            pixels.withUnsafeBytes {
                vcglTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0, GLsizei(width), GLsizei(height),
                                  GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), $0.baseAddress)
            }
            vcglPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 4)
            vcglBindTexture(GLenum(GL_TEXTURE_2D), 0)
        }
        target = made
    }

    func resize(_ context: RenderContext) {}

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        let w = context.pixelWidth, h = context.pixelHeight
        guard w > 0, h > 0, let target, target.handle.generation == context.resources.generation else { return }
        vcglDisable(GLenum(GL_SCISSOR_TEST))
        vcglBindFramebuffer(GLenum(GL_READ_FRAMEBUFFER), target.handle.name)
        vcglBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), context.framebuffer)
        let filter = (w == width && h == height) ? GL_NEAREST : GL_LINEAR
        vcglBlitFramebuffer(0, 0, GLint(width), GLint(height), 0, 0, GLint(w), GLint(h),
                            GLbitfield(GL_COLOR_BUFFER_BIT), GLenum(filter))
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
    }

    func teardown(_ context: RenderContext) { release() }

    private func release() {
        if let target, let registry, target.handle.generation == registry.generation { registry.release(target) }
        target = nil
    }
}
