// ParticlesArtScene.swift — the "Particles" family: palette background plus a seeded fountain drawn with VisualCore's
// ParticleRenderer (feature 012 T-A01-109). Particle state comes from ParticleReplayCursor, so live frames and
// fixed-time renders of the same document agree.
import Foundation
import GenerativeArtStudioCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

@MainActor
final class ParticlesArtScene: ArtScene {
    let background: FullScreenShaderScene
    private(set) var document: ArtDocument
    private var renderer: ParticleRenderer?
    private var cursor: ParticleReplayCursor?
    private var pixelSize = (1, 1)
    private var particleError: String?

    var fixedTime: Double? { didSet { background.fixedTime = fixedTime } }
    var timeScale: Double = 1 { didSet { background.timeScale = timeScale } }
    var displayScale: Double = 1
    var errorMessage: String? { background.errorMessage ?? particleError }

    init(document: ArtDocument, background: FullScreenShaderScene) {
        self.document = document
        self.background = background
    }

    /// Switches to an edited composition; the next frame replays it to the current time (deterministic).
    func update(document: ArtDocument) {
        self.document = document
        cursor = nil
    }

    private var pointSize: Vec2 { Vec2(Double(pixelSize.0) / max(displayScale, 1), Double(pixelSize.1) / max(displayScale, 1)) }

    func setup(_ context: RenderContext) throws {
        pixelSize = (max(1, context.pixelWidth), max(1, context.pixelHeight))
        try background.setup(context)
        do { renderer = try ParticleRenderer(registry: context.resources); particleError = nil }
        catch { particleError = "particles: \(error)" }
        cursor = nil
    }

    func resize(_ context: RenderContext) {
        pixelSize = (max(1, context.pixelWidth), max(1, context.pixelHeight))
        background.resize(context)
        cursor = nil   // the fountain is placed relative to the view height
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        try background.render(context, frame: frame)
        guard let renderer else { return }
        let size = pointSize
        if cursor == nil || cursor?.worldHeight != size.y { cursor = ParticleReplayCursor(document: document, worldHeight: size.y) }
        let time = fixedTime ?? frame.time * timeScale
        let particles = cursor!.instances(at: time)
        try renderer.draw(particles, camera: Camera2D(), metrics: ViewMetrics(size: size, scale: max(displayScale, 1)))
    }

    func teardown(_ context: RenderContext) {
        renderer?.release()
        renderer = nil
        background.teardown(context)
    }
}
