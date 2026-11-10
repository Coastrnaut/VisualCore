# Contract: VisualCoreRendering public API (Phase 2)

```swift
@MainActor public protocol RenderScene: AnyObject {
    func setup(_ context: RenderContext) throws
    func resize(_ context: RenderContext)
    func render(_ context: RenderContext, frame: FrameInfo) throws
    func teardown(_ context: RenderContext)
}

@MainActor public final class RenderHost {
    public init(scene: RenderScene, maxFramesPerSecond: Int = 60) throws   // throws RenderHostError.unsupported
    public var view: UIView { get }                                       // RenderView (CAMetalLayer)
    public var state: RenderLifecycleState { get }
    public var generation: Int { get }
    public var capabilities: RenderCapabilities { get }
    public var lastError: RenderHostError? { get }
    public var lifecycleHistory: [RenderLifecycleEvent] { get }            // bounded (256), includes creation
    public var rejectedTransitions: Int { get }
    public var presentedFrameCount: Int { get }                            // frames swapped onto the layer
    public var framePacing: FramePacing { get }                            // current cap and render scale
    public func addObserver(_ observer: @escaping @MainActor (RenderLifecycleEvent) -> Void)
    public func addErrorObserver(_ observer: @escaping @MainActor (RenderHostError) -> Void)   // e.g. one .allocation after 3 surface failures
    public func pause() / resume()                                         // app-requested
    public func recreateContext()
    public func replaceScene(_ scene: RenderScene)
    public func destroy()
    // test hooks
    public func renderOneFrame(present: Bool = true) -> Bool
    public func readPixels() -> [UInt8]                                    // RGBA, rows bottom-up
    public var pixelSize: (width: Int, height: Int) { get }
    // internal test hooks (via @testable): failNextSurfaceCreations(_:), simulateContextLossOnNextFrame()
}
```

Lifecycle, threading, pacing and teardown semantics: `specs/002-architecture-contracts/contracts/render-lifecycle.md`.
Integration in < 30 lines (SC-F204): create the scene, `let host = try RenderHost(scene:)`, embed `host.view`.
