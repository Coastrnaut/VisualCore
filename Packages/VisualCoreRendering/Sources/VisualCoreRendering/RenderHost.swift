// RenderHost.swift — VisualCore's app-neutral render host over the owner's ANGLE Metal backend
// (feature 003 T-F208, T-F213, T-F214, T-F215; FR-F201–FR-F216).
//
// Re-implements the audited reference sequence (docs/architecture/current-rendering-pipeline.md §2–§7,
// ADR-0002) without any ProjectM type: process-wide Metal-platform display → ES 3.0 context → 1×1 pbuffer
// placeholder current until the view has a size → window surface on the view's CAMetalLayer, rebuilt
// when the pixel size changes → CADisplayLink frames on the main thread → eglSwapBuffers. Additions over
// the reference (contracts/render-lifecycle.md): explicit lifecycle states and generations, context
// recreation (API and EGL_CONTEXT_LOST), capability report, surface-failure reporting, scene-error
// isolation, background suspension.
import CVisualCoreEGL
import CVisualCoreGL
import Foundation
import QuartzCore
import UIKit
import VisualCoreDiagnostics


/// One frame that reached the display (feature 192, UA-F06).
public struct PresentedFrame: Sendable, Equatable {
    /// The index of the frame since the host was created.
    public let index: Int
    /// The host time, in seconds, right after the frame was presented.
    public let time: Double
    /// The host time, in seconds, the display link named as the frame's target.
    public let targetTime: Double

    /// Creates the description of a presented frame.
    public init(index: Int, time: Double, targetTime: Double) {
        self.index = index
        self.time = time
        self.targetTime = targetTime
    }
}

/// App-neutral render host over ANGLE's Metal backend: owns the EGL context and surface, drives a RenderScene from CADisplayLink on the main thread, and tracks lifecycle states and context generations.
@MainActor
public final class RenderHost {
    // MARK: Public state

    /// The view whose CAMetalLayer backs the window surface; add it to the hierarchy.
    public var view: UIView { renderView }
    /// Current lifecycle state.
    public var state: RenderLifecycleState { lifecycle.state }
    /// Current context generation; incremented on every context recreation.
    public var generation: Int { lifecycle.generation }
    /// Lifecycle events in order, for diagnostics and tests.
    public var lifecycleHistory: [RenderLifecycleEvent] { lifecycle.history }
    /// Count of invalid lifecycle transitions that were rejected.
    public var rejectedTransitions: Int { lifecycle.rejectedTransitions }
    /// Capabilities reported by the current context.
    public private(set) var capabilities = RenderCapabilities()
    /// The most recent host error (surface, context or scene), if any.
    public private(set) var lastError: RenderHostError?
    /// The window surface size in pixels ((0, 0) without a surface).
    public private(set) var pixelSize: (width: Int, height: Int) = (0, 0)
    /// Frames presented with eglSwapBuffers since creation.
    public private(set) var presentedFrameCount = 0
    /// The display-link pacing currently in effect.
    public var framePacing: FramePacing { scheduler.pacing }
    /// GPU objects of this host (feature 004): budgets, stale/leak accounting, program creation.
    public private(set) var resources: ResourceRegistry

    // MARK: Private state

    private var lifecycle = RenderLifecycle()
    let renderView = RenderView(frame: .zero)
    private let display: EGLDisplay
    private let config: EGLConfig
    private var context: EGLContext?
    private var placeholder: EGLSurface?
    private var surface: EGLSurface?
    private var scene: RenderScene
    private var sceneReady = false
    private var sceneFailed = false
    private var appPaused = false
    private var backgrounded = false
    private var consecutiveSurfaceFailures = 0
    private var injectedSurfaceFailures = 0
    private var frameIndex = 0
    private var startTime: CFTimeInterval?
    private var lastTimestamp: CFTimeInterval?
    private var observers: [(RenderLifecycleEvent) -> Void] = []
    private var errorObservers: [(RenderHostError) -> Void] = []
    private var presentObservers: [(PresentedFrame) -> Void] = []
    private var notificationTokens: [NSObjectProtocol] = []
    private lazy var scheduler = FrameScheduler(requestedMaxFPS: maxFramesPerSecond) { [weak self] link in
        self?.displayLinkFired(link)
    }
    private let maxFramesPerSecond: Int

    // MARK: Creation

    /// Creates the context and runs `scene.setup`. The window surface is created on the first layout
    /// with a non-zero size. Throws `RenderHostError.unsupported` when ANGLE cannot provide ES 3.0.
    public init(scene: RenderScene, maxFramesPerSecond: Int = 60, budget: ResourceBudget = ResourceBudget()) throws {
        Self.assertMainThread()
        (display, config) = try EGLDisplayProvider.shared()
        self.scene = scene
        self.maxFramesPerSecond = maxFramesPerSecond
        (context, placeholder) = try Self.makeContext(display: display, config: config)
        surface = nil
        resources = ResourceRegistry(budget: budget, generation: 0)
        let missing = vcglLoadFromEGL()
        guard missing == 0 else {
            eglMakeCurrent(display, nil, nil, nil)
            eglDestroySurface(display, placeholder)
            eglDestroyContext(display, context)
            throw RenderHostError.unsupported("\(missing) OpenGL ES 3.0 entry points missing from ANGLE")
        }
        lifecycle.transition(to: .surfaceReady)
        resources.contextDidStart(generation: lifecycle.generation)
        takeCapabilities(missingEntryPoints: 0)
        setupScene()
        renderView.onLayout = { [weak self] in self?.layoutSurface() }
        renderView.onWindowChange = { [weak self] inWindow in self?.windowChanged(inWindow) }
        scheduler.onPacingChange = { [weak self] _ in self?.renderView.setNeedsLayout() }
        observeApplication()
    }

    isolated deinit {
        destroy()
    }

    private static func makeContext(display: EGLDisplay, config: EGLConfig) throws -> (EGLContext, EGLSurface) {
        let contextAttributes: [EGLint] = [EGL_CONTEXT_MAJOR_VERSION, 3, EGL_CONTEXT_MINOR_VERSION, 0, EGL_NONE]
        guard let context = eglCreateContext(display, config, nil, contextAttributes) else {
            throw RenderHostError.unsupported("OpenGL ES 3.0 context unavailable (EGL error 0x\(String(eglGetError(), radix: 16)))")
        }
        let pbuffer: [EGLint] = [EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE]
        guard let placeholder = eglCreatePbufferSurface(display, config, pbuffer),
              eglMakeCurrent(display, placeholder, placeholder, context) == EGL_TRUE else {
            let error = eglGetError()
            eglDestroyContext(display, context)
            throw RenderHostError.allocation("placeholder pbuffer", error)
        }
        return (context, placeholder)
    }

    // MARK: Observation

    /// Called synchronously on the main thread for every accepted or rejected transition.
    public func addObserver(_ observer: @escaping @MainActor (RenderLifecycleEvent) -> Void) {
        observers.append(observer)
    }

    /// Called synchronously on the main thread for each reported error.
    public func addErrorObserver(_ observer: @escaping @MainActor (RenderHostError) -> Void) {
        errorObservers.append(observer)
    }

    /// Called synchronously on the main thread after each frame that was presented on the display (feature 192,
    /// UA-F06): the time between two calls is the interval a person sees. A frame that is drawn without being
    /// presented, or whose presentation failed, gives no call.
    public func addPresentObserver(_ observer: @escaping @MainActor (PresentedFrame) -> Void) {
        presentObservers.append(observer)
    }

    @discardableResult
    private func transition(to next: RenderLifecycleState) -> Bool {
        let ok = lifecycle.transition(to: next)
        if let event = lifecycle.history.last { for o in observers { o(event) } }
        return ok
    }

    private func report(_ error: RenderHostError) {
        lastError = error
        for o in errorObservers { o(error) }
    }

    // MARK: Scene

    private var renderContext: RenderContext {
        RenderContext(generation: lifecycle.generation, pixelWidth: pixelSize.width, pixelHeight: pixelSize.height, framebuffer: 0,
                      resources: resources)
    }

    private func setupScene() {
        makeCurrent()
        sceneReady = false
        do {
            try scene.setup(renderContext)
            sceneReady = true
            sceneFailed = false
            if case .scene = lastError { lastError = nil }
        } catch {
            sceneFailed = true
            report(.scene(String(describing: error)))
        }
    }

    private func teardownScene() {
        guard sceneReady else { return }
        makeCurrent()
        scene.teardown(renderContext)
        sceneReady = false
    }

    /// Tears down the current scene and sets up `newScene` on the same context.
    public func replaceScene(_ newScene: RenderScene) {
        guard state != .destroyed else { return }
        teardownScene()
        scene = newScene
        setupScene()
        if surface != nil, sceneReady { scene.resize(renderContext) }
    }

    // MARK: Surface (FR-F205, FR-F214)

    /// Test hook: the next `count` window-surface creations fail as if EGL returned no surface.
    func failNextSurfaceCreations(_ count: Int) { injectedSurfaceFailures = count }

    private func layoutSurface() {
        guard state != .destroyed, state != .uninitialized else { return }
        let displayScale = renderView.traitCollection.displayScale > 0 ? renderView.traitCollection.displayScale : 2
        let scale = displayScale * scheduler.pacing.renderScale
        renderView.contentScaleFactor = scale
        renderView.metalLayer.contentsScale = scale
        let width = Int((renderView.bounds.width * scale).rounded())
        let height = Int((renderView.bounds.height * scale).rounded())
        guard width > 0, height > 0 else {
            destroyWindowSurface()
            enterSurfaceInvalid()
            return
        }
        if surface != nil, (width, height) == pixelSize { return }
        renderView.metalLayer.drawableSize = CGSize(width: width, height: height)
        destroyWindowSurface()
        let layer = Unmanaged.passUnretained(renderView.metalLayer).toOpaque()
        var created: EGLSurface? = nil
        if injectedSurfaceFailures > 0 {
            injectedSurfaceFailures -= 1
        } else {
            created = eglCreateWindowSurface(display, config, layer, nil)
        }
        guard let created else {
            let error = eglGetError()
            consecutiveSurfaceFailures += 1
            if consecutiveSurfaceFailures == 3 { report(.allocation("window surface", error)) }
            enterSurfaceInvalid()
            return
        }
        consecutiveSurfaceFailures = 0
        surface = created
        var w: EGLint = 0, h: EGLint = 0
        eglQuerySurface(display, created, EGL_WIDTH, &w)
        eglQuerySurface(display, created, EGL_HEIGHT, &h)
        pixelSize = (Int(w), Int(h))
        makeCurrent()
        if sceneReady { scene.resize(renderContext) }
        enterRenderableState()
    }

    private func destroyWindowSurface() {
        guard let old = surface else { return }
        eglMakeCurrent(display, placeholder, placeholder, context)
        eglDestroySurface(display, old)
        surface = nil
        pixelSize = (0, 0)
    }

    private func enterSurfaceInvalid() {
        if state != .surfaceInvalid { transition(to: .surfaceInvalid) }
        scheduler.setPaused(true)
    }

    /// After a surface exists: active, or suspended while paused/backgrounded.
    private func enterRenderableState() {
        let wantSuspended = appPaused || backgrounded
        switch state {
        case .surfaceReady, .reinitialized:
            transition(to: .active)
            if wantSuspended { transition(to: .suspended) }
        case .surfaceInvalid:
            transition(to: wantSuspended ? .suspended : .active)
        default:
            break
        }
        scheduler.setPaused(state != .active)
    }

    // MARK: Suspension (FR-F207)

    /// App-requested pause; survives a background/foreground cycle.
    public func pause() {
        appPaused = true
        applySuspension()
    }

    /// Clears the app-requested pause; rendering resumes unless the app is in the background or there is no surface.
    public func resume() {
        appPaused = false
        applySuspension()
    }

    private func applySuspension() {
        guard state != .destroyed else { return }
        let wantSuspended = appPaused || backgrounded
        if wantSuspended, state == .active {
            transition(to: .suspended)
        } else if !wantSuspended, state == .suspended {
            transition(to: surface != nil ? .active : .surfaceInvalid)
        }
        scheduler.setPaused(state != .active)
        if state != .active { lastTimestamp = nil }
    }

    private func observeApplication() {
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state != .destroyed else { return }
                self.makeCurrent()
                vcglFinish()   // iOS forbids GPU work in the background: drain before suspending
                self.backgrounded = true
                self.applySuspension()
            }
        })
        notificationTokens.append(center.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state != .destroyed else { return }
                self.makeCurrent()
                self.resources.trimPools()   // FR-F312
            }
        })
        notificationTokens.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.backgrounded = false
                self.applySuspension()
            }
        })
    }

    private func windowChanged(_ inWindow: Bool) {
        guard state != .destroyed else { return }
        if inWindow { scheduler.start(paused: state != .active) } else { scheduler.stop(); lastTimestamp = nil }
    }

    // MARK: Recreation (FR-F208)

    /// Takes the renderer's report for the current context generation (feature 202). Call with the context current.
    private func takeCapabilities(missingEntryPoints: Int) {
        var caps = RenderCapabilities.query(display: display)
        caps.missingEntryPoints = missingEntryPoints
        caps.generation = lifecycle.generation
        capabilities = caps
        resources.maxTextureSize = caps.maxTextureSize
    }

    /// Destroys and recreates the context (API, tests, or after EGL_CONTEXT_LOST); the scene is set up again.
    public func recreateContext() {
        guard state != .destroyed, state != .uninitialized else { return }
        teardownScene()
        makeCurrent()
        resources.contextWillEnd()
        eglMakeCurrent(display, nil, nil, nil)
        if let surface { eglDestroySurface(display, surface) }
        surface = nil
        pixelSize = (0, 0)
        eglDestroySurface(display, placeholder)
        eglDestroyContext(display, context)
        transition(to: .reinitialized)
        do {
            (context, placeholder) = try Self.makeContext(display: display, config: config)
        } catch let error as RenderHostError {
            context = nil
            placeholder = nil
            report(error)
            enterSurfaceInvalid()
            return
        } catch {
            return
        }
        // Feature 202 (R02-F02, FR-R02F02-003/004): a reload that misses entry points fails like a first load, and the
        // report is taken again for the new context generation.
        let missing = Int(vcglLoadFromEGL())
        guard missing == 0 else {
            report(.unsupported("\(missing) OpenGL ES 3.0 entry points missing from ANGLE after context recreation"))
            enterSurfaceInvalid()
            return
        }
        resources.contextDidStart(generation: lifecycle.generation)
        takeCapabilities(missingEntryPoints: missing)
        setupScene()
        layoutSurface()
        if state == .reinitialized { enterSurfaceInvalid() }   // no valid size yet
    }

    // MARK: Frames

    private func makeCurrent() {
        guard context != nil else { return }
        let target = surface ?? placeholder
        eglMakeCurrent(display, target, target, context)
    }

    /// Renders one frame now (tests, automation). Returns false unless the host is active with a surface.
    @discardableResult
    public func renderOneFrame(present: Bool = true) -> Bool {
        renderFrame(present: present, delta: 1.0 / 60, target: CACurrentMediaTime())
    }

    private func displayLinkFired(_ link: CADisplayLink) {
        let delta = lastTimestamp.map { FramePacing.clampedDelta(link.timestamp - $0) } ?? 0
        lastTimestamp = link.timestamp
        renderFrame(present: true, delta: delta, target: link.targetTimestamp)
    }

    @discardableResult
    private func renderFrame(present: Bool, delta: Double, target: CFTimeInterval) -> Bool {
        Self.assertMainThread()
        guard state == .active, let surface else { return false }
        guard eglMakeCurrent(display, surface, surface, context) == EGL_TRUE else {
            handleEGLFailure(eglGetError())
            return false
        }
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        vcglViewport(0, 0, GLsizei(pixelSize.width), GLsizei(pixelSize.height))
        let now = CACurrentMediaTime()
        if startTime == nil { startTime = now }
        let frame = FrameInfo(index: frameIndex, time: now - (startTime ?? now), delta: FramePacing.clampedDelta(delta),
                              targetTimestamp: target)
        frameIndex += 1
        if sceneReady, !sceneFailed {
            do {
                try scene.render(renderContext, frame: frame)
            } catch {
                sceneFailed = true
                report(.scene(String(describing: error)))
            }
        }
        if !sceneReady || sceneFailed {
            vcglClearColor(0, 0, 0, 1)
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        }
        if injectContextLoss {
            // Test hook: behave exactly as if eglSwapBuffers had failed with EGL_CONTEXT_LOST.
            injectContextLoss = false
            handleEGLFailure(EGL_CONTEXT_LOST)
            return false
        }
        if present {
            guard eglSwapBuffers(display, surface) == EGL_TRUE else {
                handleEGLFailure(eglGetError())
                return false
            }
            presentedFrameCount += 1
            if !presentObservers.isEmpty {
                let presented = PresentedFrame(index: frame.index, time: CACurrentMediaTime(), targetTime: target)
                for observer in presentObservers { observer(presented) }
            }
        }
        return true
    }

    /// FR-F208: a lost context is reported and recreated; other EGL failures are left to the next frame.
    private func handleEGLFailure(_ error: EGLint) {
        if error == EGL_CONTEXT_LOST {
            report(.contextLost)
            recreateContext()
        }
    }

    /// Test hook (simulators cannot lose a context): the next frame takes the EGL_CONTEXT_LOST path.
    func simulateContextLossOnNextFrame() { injectContextLoss = true }
    private var injectContextLoss = false

    // MARK: Readback (FR-F211)

    /// The window surface's default framebuffer as RGBA bytes, rows bottom-up; empty without a surface.
    public func readPixels() -> [UInt8] {
        guard let surface, state != .destroyed else { return [] }
        eglMakeCurrent(display, surface, surface, context)
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
        var pixels = [UInt8](repeating: 0, count: pixelSize.width * pixelSize.height * 4)
        vcglReadPixels(0, 0, GLsizei(pixelSize.width), GLsizei(pixelSize.height), GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &pixels)
        return vcglGetError() == GLenum(GL_NO_ERROR) ? pixels : []
    }

    // MARK: Offscreen still export (feature 015 T-A01-402; FR-A01-402, FR-A01-405, FR-A01-408)

    /// Pixel-count cap per offscreen render (64 million).
    public static let maxOffscreenPixels = 64_000_000

    /// The largest edge an offscreen render may use: min(max texture, max renderbuffer, max viewport width and
    /// height); 0 before a context reported its limits.
    public var maxRenderSize: Int {
        let c = capabilities
        let limits = [c.maxTextureSize, c.maxRenderbufferSize, c.maxViewport.width, c.maxViewport.height]
        return limits.contains { $0 <= 0 } ? 0 : limits.min() ?? 0
    }

    /// Renders the current scene into a `width`×`height` registry render target at frame time `time`, on this host's
    /// context, and returns the pixels top-down. The size is validated before any GPU work. On every path the
    /// target is released, framebuffer 0 is rebound and the scene is resized back to the live surface; a failure
    /// never marks the live scene failed.
    public func renderOffscreen(width: Int, height: Int, time: Double) throws(OffscreenRenderError) -> StillImage {
        Self.assertMainThread()
        guard state != .destroyed, context != nil else { throw .unavailable("host destroyed or without a context") }
        guard sceneReady, !sceneFailed else { throw .unavailable("scene not set up or failed") }
        let limit = maxRenderSize
        guard width > 0, height > 0, width <= limit, height <= limit, width * height <= Self.maxOffscreenPixels else {
            throw .invalidSize(width: width, height: height, max: limit)
        }
        makeCurrent()
        let target: RenderTarget
        do {
            target = try resources.makeRenderTarget(width: width, height: height, label: "offscreen-export")
        } catch {
            throw .resource(String(describing: error))
        }
        let offscreen = renderContext.redirected(to: target.handle.name, width: width, height: height)
        defer {
            resources.release(target)
            vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
            if surface != nil {
                makeCurrent()
                scene.resize(renderContext)
            }
        }
        scene.resize(offscreen)
        target.bind()
        vcglViewport(0, 0, GLsizei(width), GLsizei(height))
        let frame = FrameInfo(index: frameIndex, time: time, delta: 0, targetTimestamp: CACurrentMediaTime())
        do {
            try scene.render(offscreen, frame: frame)
        } catch {
            throw .scene(String(describing: error))
        }
        let pixels = target.readPixels()
        guard let image = StillImage(width: width, height: height, bottomUpRGBA: pixels) else { throw .readback }
        return image
    }

    // MARK: Teardown (FR-F209)

    /// Contract order: stop frames → scene teardown with the context current → unbind → destroy
    /// surfaces and context. The process-wide display is kept (FR-F216). Further calls are no-ops.
    public func destroy() {
        guard state != .destroyed else { return }
        scheduler.shutdown()
        for t in notificationTokens { NotificationCenter.default.removeObserver(t) }
        notificationTokens.removeAll()
        teardownScene()
        makeCurrent()
        resources.contextWillEnd()
        eglMakeCurrent(display, nil, nil, nil)
        if let surface { eglDestroySurface(display, surface) }
        if let placeholder { eglDestroySurface(display, placeholder) }
        if let context { eglDestroyContext(display, context) }
        surface = nil
        placeholder = nil
        context = nil
        pixelSize = (0, 0)
        transition(to: .destroyed)
        renderView.onLayout = nil
        renderView.onWindowChange = nil
    }

    // MARK: Threading (FR-F204)

    private static func assertMainThread() {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
    }
}
