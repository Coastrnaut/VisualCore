// ProjectMScene.swift — the UNMODIFIED ProjectM engine as a VisualCore RenderScene (feature 008 T-F705;
// FR-F702, FR-F703; migration-log boundary 2; research R1). Same engine calls as the reference ANGLERenderer
// (current-rendering-pipeline.md §4–§6): created with the host's EGL loader on the thread that owns the context,
// viewport from the drawable, PCM then renderFrame(toFramebuffer:), released with its context current.
// After each engine frame the GL state is handed back to VisualCore (boundary 2a, GLState).
import CVisualCoreEGL
import Foundation
import ProjectMBridge
import VisualCoreRendering

@MainActor
final class ProjectMScene: RenderScene {
    private(set) var presetPath: String
    private var engine: ProjectMEngine?
    /// Host context generation the current engine was created on.
    private(set) var engineGeneration: Int?
    private(set) var enginesCreated = 0
    private(set) var frames = 0
    private(set) var lastError: Error?
    /// Every viewport handed to the engine (tests: never zero).
    private(set) var viewports: [(width: Int, height: Int)] = []
    var signal = SyntheticSignal()
    /// GL entry-point loader; injectable so tests can force an engine-creation failure.
    var loader: PMGLLoadProc = vcEGLLoadProc

    init(presetPath: String) { self.presetPath = presetPath }

    var hasEngine: Bool { engine != nil }

    /// A preset change requested from UI; applied at the start of the next render, when the context is current.
    private var pendingPreset: String?
    func requestPreset(path: String) { pendingPreset = path }

    /// Loads another preset; on failure the previous preset keeps running (reference FR-045) and false is returned.
    @discardableResult
    func loadPreset(path: String) -> Bool {
        guard let engine else { lastError = ProjectMSceneError.noEngine; return false }
        do {
            try engine.loadPreset(atPath: path, smooth: false)
            presetPath = path
            return true
        } catch {
            lastError = error
            return false
        }
    }

    func setup(_ context: RenderContext) throws {
        engine = nil
        do {
            let e = try ProjectMEngine(glLoader: loader, userData: nil)
            enginesCreated += 1
            engineGeneration = context.generation
            engine = e
            applyViewport(context, to: e)
            try e.loadPreset(atPath: presetPath, smooth: false)
            lastError = nil
        } catch {
            lastError = error   // edge case: the host stays alive and reports the error
        }
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth, height: context.pixelHeight)
    }

    func resize(_ context: RenderContext) {
        if let engine { applyViewport(context, to: engine) }
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let engine, context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        if let path = pendingPreset { pendingPreset = nil; loadPreset(path: path) }
        if viewports.last.map({ $0.width != context.pixelWidth || $0.height != context.pixelHeight }) ?? true {
            applyViewport(context, to: engine)
        }
        for chunk in signal.chunksForVideoFrame(maxFramesPerCall: Int(ProjectMEngine.maxSamplesPerFrame)) {
            chunk.withUnsafeBufferPointer { engine.addPCMInterleavedStereo($0.baseAddress!, frames: UInt(chunk.count / 2)) }
        }
        engine.renderFrame(toFramebuffer: context.framebuffer)
        frames += 1
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth, height: context.pixelHeight)
    }

    /// Called with the context current (host contract), so the engine frees its GL objects in the right context.
    func teardown(_ context: RenderContext) {
        engine = nil
        engineGeneration = nil
    }

    private func applyViewport(_ context: RenderContext, to engine: ProjectMEngine) {
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }   // edge case: zero-size layout
        engine.setViewportWidth(context.pixelWidth, height: context.pixelHeight)
        viewports.append((context.pixelWidth, context.pixelHeight))
    }
}

enum ProjectMSceneError: Error { case noEngine }
