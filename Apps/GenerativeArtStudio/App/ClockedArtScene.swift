// ClockedArtScene.swift — drives an ArtScene from a VisualCore SceneClock: each frame advances the clock by the frame
// delta and renders the inner scene at that explicit time (feature 013 T-A01-206; FR-A01-204; research R1).
import VisualCoreRendering
import VisualCoreSimulation

@MainActor
final class ClockedArtScene: RenderScene {
    /// The scene being timed (replaced when the composition's family kind needs a new scene).
    let inner: ArtScene
    /// Play/pause/scrub state; read by the controls, advanced here.
    var clock: SceneClock

    init(inner: ArtScene, clock: SceneClock = SceneClock()) {
        self.inner = inner
        self.clock = clock
        inner.fixedTime = clock.time
    }

    func setup(_ context: RenderContext) throws { try inner.setup(context) }
    func resize(_ context: RenderContext) { inner.resize(context) }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        clock.advance(by: frame.delta)
        inner.fixedTime = clock.time
        try inner.render(context, frame: frame)
    }

    func teardown(_ context: RenderContext) { inner.teardown(context) }
}
