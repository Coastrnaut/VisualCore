// EngineFramebufferPath.swift — "path A" of the baseline comparison (feature 008 T-F708; FR-F705; research R3):
// the reference renderer's per-frame sequence (ANGLERenderer.renderFrame: PCM → renderFrame(toFramebuffer:) into
// a framebuffer it owns) reproduced with the unmodified engine into an offscreen target. Path B is ProjectMScene on
// the VisualCore host's window surface.
import CVisualCoreEGL
import ProjectMBridge
import VisualCoreRendering

@MainActor
final class EngineFramebufferPath: RenderScene {
    let presetPath: String
    let width: Int, height: Int
    var signal = SyntheticSignal()
    private var engine: ProjectMEngine?
    private var target: RenderTarget?
    private(set) var frames = 0
    private(set) var lastError: Error?

    init(presetPath: String, width: Int, height: Int) {
        self.presetPath = presetPath; self.width = width; self.height = height
    }

    func setup(_ context: RenderContext) throws {
        target = try context.resources.makeRenderTarget(width: width, height: height, label: "path A")
        target?.bind()
        do {
            let e = try ProjectMEngine(glLoader: vcEGLLoadProc, userData: nil)
            e.setViewportWidth(width, height: height)
            try e.loadPreset(atPath: presetPath, smooth: false)
            engine = e
        } catch { lastError = error }
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth, height: context.pixelHeight)
    }

    func resize(_ context: RenderContext) {}

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let engine, let target else { return }
        target.bind()
        for chunk in signal.chunksForVideoFrame(maxFramesPerCall: Int(ProjectMEngine.maxSamplesPerFrame)) {
            chunk.withUnsafeBufferPointer { engine.addPCMInterleavedStereo($0.baseAddress!, frames: UInt(chunk.count / 2)) }
        }
        engine.renderFrame(toFramebuffer: target.handle.name)
        frames += 1
        if captureNextFrame { captured = target.readPixels(); captureNextFrame = false }   // own context is current here
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth, height: context.pixelHeight)
    }

    /// Set before a frame to read back that frame while this host's context is current (another host's context may
    /// be current between calls, so reading later would target the wrong context).
    var captureNextFrame = false
    /// RGBA8 rows bottom-up, like RenderHost.readPixels.
    private(set) var captured: [UInt8] = []

    func teardown(_ context: RenderContext) {
        engine = nil
        if let target { context.resources.release(target) }
        target = nil
    }
}
