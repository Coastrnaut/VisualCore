// ParticleLayerScene.swift — a generic RenderScene that clears to a background and draws particles from a source,
// fitting a world rectangle into the drawable (feature 034 A04-P02 T-A04-212; FR-A04-206; contract C8; research R6).
// Reusable by any app that shows a 2D particle world (A04 sandbox, A09 aquarium, A19 wallpapers). GPU objects live
// only between setup and teardown, so a context recreation rebuilds them; the particle state belongs to the caller.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

/// Draws `[ParticleInstance]` from a source closure each frame over a solid background, with the world rectangle
/// aspect-fitted into the drawable (y up, centered).
@MainActor
public final class ParticleLayerScene: RenderScene {
    /// An axis-aligned world rectangle that must stay fully visible.
    public struct WorldRect: Sendable, Equatable {
        /// The world point shown at the center of the view.
        public var center: Vec2
        /// Width and height in world units (both > 0 to be valid).
        public var size: Vec2
        /// Creates a rectangle from its center and size.
        public init(center: Vec2, size: Vec2) { self.center = center; self.size = size }
        /// A square of side `2 × halfExtent` centered on the origin.
        public static func square(halfExtent: Double) -> WorldRect { WorldRect(center: .zero, size: Vec2(2 * halfExtent, 2 * halfExtent)) }
        /// True when the size is positive and everything is finite.
        public var isValid: Bool { center.isFinite && size.isFinite && size.x > 0 && size.y > 0 }
    }

    /// The world area to show; may change between frames.
    public var world: WorldRect
    /// The clear color (straight RGBA, 0…1).
    public var background: Vec4
    /// Particles drawn in the last rendered frame.
    public private(set) var lastInstanceCount = 0
    /// The last setup or draw error, if any (also thrown to the host, which reports it).
    public private(set) var lastError: String?

    private let source: @MainActor (FrameInfo) -> [ParticleInstance]
    private var renderer: ParticleRenderer?

    /// Creates the scene. `source` is called once per rendered frame (on the main thread) and returns the particles
    /// to draw; it may advance a simulation with the frame's time. Particle sizes are diameters in world units.
    public init(world: WorldRect, background: Vec4 = Vec4(0, 0, 0, 1), source: @escaping @MainActor (FrameInfo) -> [ParticleInstance]) {
        self.world = world
        self.background = background
        self.source = source
    }

    /// The camera and metrics that aspect-fit `world` into a view of `viewSize` (any unit: points or pixels), or nil
    /// for an invalid world or view. The camera keeps zoom 1 (the fit scale is carried by the metrics), so any fit
    /// scale is allowed, unlike `Camera2D.zoomRange`.
    public static func fit(world: WorldRect, viewSize: Vec2) -> (camera: Camera2D, metrics: ViewMetrics)? {
        guard world.isValid, viewSize.isFinite, viewSize.x > 0, viewSize.y > 0 else { return nil }
        let k = min(viewSize.x / world.size.x, viewSize.y / world.size.y)   // view units per world unit
        guard k.isFinite, k > 0 else { return nil }
        return (Camera2D(center: world.center), ViewMetrics(size: viewSize / k, scale: k))
    }

    /// The world point under `viewPoint` (top-left origin, y down, same unit as `viewSize`); nil when invalid.
    public static func worldPoint(_ viewPoint: Vec2, viewSize: Vec2, world: WorldRect) -> Vec2? {
        guard viewPoint.isFinite, let f = fit(world: world, viewSize: viewSize), let p = f.metrics.fromPixels(viewPoint) else { return nil }
        return f.metrics.toWorld(p, camera: f.camera)
    }

    /// The view point (top-left origin, y down, same unit as `viewSize`) showing `worldPoint`; nil when invalid.
    public static func viewPoint(_ worldPoint: Vec2, viewSize: Vec2, world: WorldRect) -> Vec2? {
        guard worldPoint.isFinite, let f = fit(world: world, viewSize: viewSize),
              let p = f.metrics.fromWorld(worldPoint, camera: f.camera) else { return nil }
        return f.metrics.toPixels(p)
    }

    /// Creates the particle renderer (throws on shader errors, which the host reports).
    public func setup(_ context: RenderContext) throws {
        do {
            renderer = try ParticleRenderer(registry: context.resources)
            lastError = nil
        } catch {
            lastError = "particle renderer: \(error)"
            throw error
        }
    }

    /// Nothing to rebuild: the fit is computed from the context each frame.
    public func resize(_ context: RenderContext) {}

    /// Clears to `background`, asks the source for particles and draws them fitted into the drawable.
    public func render(_ context: RenderContext, frame: FrameInfo) throws {
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
        vcglViewport(0, 0, GLsizei(context.pixelWidth), GLsizei(context.pixelHeight))
        let b = background
        vcglClearColor(Float(b.x), Float(b.y), Float(b.z), Float(b.w))
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        let particles = source(frame)
        lastInstanceCount = 0
        guard let renderer,
              let f = Self.fit(world: world, viewSize: Vec2(Double(context.pixelWidth), Double(context.pixelHeight))) else { return }
        do {
            try renderer.draw(particles, camera: f.camera, metrics: f.metrics)
            lastInstanceCount = renderer.lastInstanceCount
        } catch {
            lastError = "particle draw: \(error)"
            throw error
        }
    }

    /// Releases the renderer's GPU objects.
    public func teardown(_ context: RenderContext) {
        renderer?.release()
        renderer = nil
    }
}
