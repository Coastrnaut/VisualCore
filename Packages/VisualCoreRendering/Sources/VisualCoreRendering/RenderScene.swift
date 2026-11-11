// RenderScene.swift — the scene contract driven by RenderHost (feature 003 T-F211).
// Contract: specs/003-rendering-lifecycle/contracts/render-host-api.md.
import VisualCoreDiagnostics

/// Everything a scene may use during a host callback. Valid only inside that callback, on the main
/// thread, so it is not `Sendable` (feature 004 analyze I1).
@MainActor
public struct RenderContext: Equatable {
    /// Context generation (Constitution III): GPU objects from another generation are invalid.
    public let generation: Int
    public let pixelWidth: Int
    public let pixelHeight: Int
    /// The framebuffer to draw into (0 = the window surface).
    public let framebuffer: UInt32
    /// The host's resource registry (one per host; feature 004).
    public let resources: ResourceRegistry

    public nonisolated static func == (a: RenderContext, b: RenderContext) -> Bool {
        a.generation == b.generation && a.pixelWidth == b.pixelWidth && a.pixelHeight == b.pixelHeight
            && a.framebuffer == b.framebuffer && a.resources === b.resources
    }
}

/// Timing of one frame.
public struct FrameInfo: Sendable, Equatable {
    public let index: Int
    /// Seconds since the host started rendering.
    public let time: Double
    /// Seconds since the previous frame, clamped to 0…0.1 (FramePacing.clampedDelta).
    public let delta: Double
    public let targetTimestamp: Double
}

/// A scene owns its GPU objects: it creates them in `setup` and releases them in `teardown`, both
/// called with its context current on the main thread.
@MainActor
public protocol RenderScene: AnyObject {
    func setup(_ context: RenderContext) throws
    func resize(_ context: RenderContext)
    func render(_ context: RenderContext, frame: FrameInfo) throws
    func teardown(_ context: RenderContext)
}

/// Host errors (contract resources-shaders-errors.md, error categories).
public enum RenderHostError: Error, Equatable, Sendable {
    /// No ES 3.0 configuration, context or GL entry points (not recoverable).
    case unsupported(String)
    /// EGL allocation failed, with the EGL error code (recoverable; retried on layout).
    case allocation(String, Int32)
    /// The context was lost and recreated.
    case contextLost
    /// The scene threw from setup or render; a black frame is presented instead.
    case scene(String)
}
