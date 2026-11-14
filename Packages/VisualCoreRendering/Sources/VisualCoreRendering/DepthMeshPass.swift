// DepthMeshPass.swift — draws meshes with depth testing into an owned render target with depth and copies the colour
// to the context's framebuffer (feature 042 T-A05-303; FR-A05-320; research D1/D2 in specs/042-ig-p03-mesh-camera).
// The window surface and the offscreen export target carry no depth buffer, so the pass owns a registry render target
// with a 24-bit depth renderbuffer at the context's pixel size, rebuilt on resize and on a new context generation,
// and blits its colour (nearest) to `context.framebuffer`; screen and export therefore show the same result.
// Feature 055 (A07-P02) T-A07-203 (FR-A07-202; gap G-RAILDRAW) adds `draw(_:view:projection:fog:context:)` for a free
// camera with optional linear depth fog; the orbit-camera method forwards to it with fog nil.
import CVisualCoreGL
import VisualCoreMath

/// Draws a list of meshes with correct occlusion (depth test LESS, depth write on) into an owned depth render target
/// and copies the colour to the context's framebuffer with a framebuffer blit, on the main thread.
@MainActor
public final class DepthMeshPass {
    /// One mesh draw: the renderer, its model transform and its premultiplied-alpha colour (RGBA 0…1).
    public struct Item {
        /// The renderer whose mesh is drawn.
        public var renderer: MeshRenderer
        /// Model transform applied to the mesh.
        public var model: Mat4
        /// Premultiplied-alpha colour (RGBA 0…1).
        public var color: Vec4

        /// Creates an item drawing `renderer` with `model` and `color`.
        public init(renderer: MeshRenderer, model: Mat4 = .identity, color: Vec4) {
            self.renderer = renderer
            self.model = model
            self.color = color
        }
    }

    private let registry: ResourceRegistry
    private var target: RenderTarget?
    /// Colour the depth target is cleared to before the items are drawn (RGBA 0…1); opaque black by default.
    public var clearColor = Vec4(0, 0, 0, 1)

    /// Creates a pass whose depth target is allocated from `registry` on the first draw.
    public init(registry: ResourceRegistry) {
        self.registry = registry
    }

    /// Clears the depth target to `clearColor` and depth 1, draws `items` in order with depth testing through
    /// `camera`, restores depth state and copies the colour to `context.framebuffer`. A zero-sized context draws
    /// nothing; an empty item list clears and copies. The framebuffer binding and viewport of `context` are restored.
    /// Forwards to `draw(_:view:projection:fog:context:)` with the camera's view, its projection at the context's
    /// aspect and no fog.
    public func draw(_ items: [Item], camera: OrbitCamera, context: RenderContext) throws {
        let width = context.pixelWidth, height = context.pixelHeight
        guard width > 0, height > 0 else { return }
        let aspect = Double(width) / Double(height)
        try draw(items, view: camera.view(), projection: camera.projection(aspect: aspect), fog: nil, context: context)
    }

    /// Clears the depth target to `clearColor` and depth 1, draws `items` in order with depth testing through the free
    /// camera `view` and `projection` (GL clip space) with optional linear eye-depth `fog` (nil draws unfogged), restores
    /// depth state and copies the colour to `context.framebuffer`. A zero-sized context draws nothing; an empty item
    /// list clears and copies. The framebuffer binding and viewport of `context` are restored.
    public func draw(_ items: [Item], view: Mat4, projection: Mat4, fog: MeshFog?, context: RenderContext) throws {
        let width = context.pixelWidth, height = context.pixelHeight
        guard width > 0, height > 0 else { return }
        let target = try ensureTarget(width: width, height: height)
        defer {
            vcglDisable(GLenum(GL_DEPTH_TEST))
            vcglDepthMask(GLboolean(GL_TRUE))
            vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
            vcglViewport(0, 0, GLsizei(width), GLsizei(height))
        }
        target.bind()
        vcglViewport(0, 0, GLsizei(width), GLsizei(height))
        vcglDisable(GLenum(GL_BLEND))
        vcglDisable(GLenum(GL_SCISSOR_TEST))
        vcglDepthMask(GLboolean(GL_TRUE))
        vcglClearColor(GLfloat(clearColor.x), GLfloat(clearColor.y), GLfloat(clearColor.z), GLfloat(clearColor.w))
        vcglClearDepthf(1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        vcglEnable(GLenum(GL_DEPTH_TEST))
        vcglDepthFunc(GLenum(GL_LESS))
        for item in items {
            try item.renderer.draw(model: item.model, view: view, projection: projection, color: item.color, fog: fog)
        }
        vcglDisable(GLenum(GL_DEPTH_TEST))
        vcglBindFramebuffer(GLenum(GL_READ_FRAMEBUFFER), target.handle.name)
        vcglBindFramebuffer(GLenum(GL_DRAW_FRAMEBUFFER), context.framebuffer)
        vcglBlitFramebuffer(0, 0, GLint(width), GLint(height), 0, 0, GLint(width), GLint(height),
                            GLbitfield(GL_COLOR_BUFFER_BIT), GLenum(GL_NEAREST))
    }

    /// Releases the depth target back to the registry; the next draw allocates a new one.
    public func release() {
        if let target, target.handle.generation == registry.generation { registry.release(target) }
        target = nil
    }

    /// The depth target at `width`×`height`, rebuilt when missing, resized or from another registry generation
    /// (an old-generation target died with its context and was dropped by the registry, so it is only forgotten).
    private func ensureTarget(width: Int, height: Int) throws -> RenderTarget {
        if let target, target.width == width, target.height == height, target.handle.generation == registry.generation {
            return target
        }
        release()
        let made = try registry.makeRenderTarget(width: width, height: height, depth: true, label: "depth-mesh-pass")
        target = made
        return made
    }
}
