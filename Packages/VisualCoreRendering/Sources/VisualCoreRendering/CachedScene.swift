// CachedScene — feature 135 (A18-P05) T-A18-502 (FR-A18-501–503).
// Contract: specs/135-ac-p05-device-qa/contracts/qa.md ("CachedScene"); clarification Q1 of its spec.
// A RenderScene that keeps the picture of one child scene while the picture is still: the child draws into an owned
// RGBA8 render target of the drawable size through `context.redirected(to:width:height:)` only when the owner's `key`
// changed, the scene was invalidated, or the target is missing (first frame, after setup, resize or a context
// recreation); every other frame only copies the target to `context.framebuffer` with a framebuffer blit, exact at
// the same size, so a cached frame is byte for byte the child's own frame. With `passThrough` (the default) the child
// draws straight into the context's framebuffer every frame and no target is kept.
import CVisualCoreGL

/// A scene that draws its child once per still picture and repeats that picture by copying it, on the main thread.
///
/// The owner decides when the picture is still and what makes it different: it sets `passThrough` to false while
/// nothing moves and sets `key` to a value that changes whenever the picture would change (for example a hash of
/// theme, palette and size). The cache never reads the clock: frame times only reach the child when it draws. While it
/// is set up, the cache owns the lifecycle of its child: `setup`, `resize` and `teardown` are forwarded to it.
@MainActor
public final class CachedScene: RenderScene {
    /// The wrapped scene; it draws into the cache target (or straight to the framebuffer in pass-through).
    public private(set) var child: any RenderScene
    /// The owner's identity of the still picture: a frame whose key differs from the key of the last cached draw
    /// draws the child again. Ignored while `passThrough` is true.
    public var key: Int = 0
    /// When true (the default) the child draws straight into `context.framebuffer` every frame, as without the cache,
    /// and the target is released; when false the cached picture is copied and the child draws only when needed.
    public var passThrough: Bool = true
    /// How many times the child has drawn (pass-through frames and cache refreshes alike) since `init`.
    public private(set) var childDrawCount: Int = 0
    /// True between a successful `setup` and the next `teardown`.
    public private(set) var isSetUp = false

    private var target: RenderTarget?
    private var registry: ResourceRegistry?
    /// The key of the picture in `target`; nil when the target holds no valid picture.
    private var lastDrawnKey: Int?

    /// A cache around `child`, in pass-through. Nothing is allocated before `setup`.
    public init(child: any RenderScene) {
        self.child = child
    }

    /// Marks the cached picture stale: the next frame that is not pass-through draws the child again.
    public func invalidate() {
        lastDrawnKey = nil
    }

    /// Sets up the child. A target from earlier is released (or only forgotten when it belongs to an ended context
    /// generation), so the next cached frame draws the child again. Rethrows the child's error.
    public func setup(_ context: RenderContext) throws {
        releaseTarget()
        registry = context.resources
        try child.setup(context)
        isSetUp = true
    }

    /// Resizes the child and releases the target; the next cached frame makes it at the new size and draws the child.
    public func resize(_ context: RenderContext) {
        child.resize(context)
        releaseTarget()
    }

    /// Draws the frame into `context.framebuffer`: in pass-through the child itself; otherwise the cached picture,
    /// drawing the child into the target first when the key changed, the scene was invalidated or the target is
    /// missing, of another size or of an ended context generation. A zero-sized context draws nothing. Rethrows the
    /// child's error (the cached picture is then stale).
    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        let width = context.pixelWidth, height = context.pixelHeight
        guard width > 0, height > 0 else { return }
        guard !passThrough else {
            releaseTarget()
            vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
            vcglViewport(0, 0, GLsizei(width), GLsizei(height))
            childDrawCount += 1
            try child.render(context, frame: frame)
            return
        }
        let resources = context.resources
        if let current = target, current.width != width || current.height != height
            || current.handle.generation != resources.generation || registry !== resources {
            releaseTarget()
        }
        let cache: RenderTarget
        if let current = target {
            cache = current
        } else {
            cache = try resources.makeRenderTarget(width: width, height: height, label: "cached-scene")
            registry = resources
            target = cache
            lastDrawnKey = nil
        }
        if lastDrawnKey != key {
            lastDrawnKey = nil
            cache.bind()
            vcglViewport(0, 0, GLsizei(width), GLsizei(height))
            childDrawCount += 1
            do {
                try child.render(context.redirected(to: cache.handle.name, width: width, height: height), frame: frame)
            } catch {
                vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
                throw error
            }
            lastDrawnKey = key
        }
        vcglDisable(GLenum(GL_SCISSOR_TEST))
        vcglColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
        vcglBindFramebuffer(GLenum(GL_READ_FRAMEBUFFER), cache.handle.name)
        vcglBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), context.framebuffer)
        vcglBlitFramebuffer(0, 0, GLint(width), GLint(height), 0, 0, GLint(width), GLint(height),
                            GLbitfield(GL_COLOR_BUFFER_BIT), GLenum(GL_NEAREST))
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
        vcglViewport(0, 0, GLsizei(width), GLsizei(height))
    }

    /// Tears down the child and releases the target.
    public func teardown(_ context: RenderContext) {
        child.teardown(context)
        releaseTarget()
        isSetUp = false
    }

    /// Releases the target to its registry (a target of an ended generation is only forgotten) and drops the picture.
    private func releaseTarget() {
        if let target, let registry, target.handle.generation == registry.generation { registry.release(target) }
        target = nil
        lastDrawnKey = nil
    }
}
