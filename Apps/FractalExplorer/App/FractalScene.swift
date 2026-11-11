// FractalScene.swift — the explorer's render scene (feature 027 T-A03-203; FR-A03-201, FR-A03-203; clarification 3).
// Wraps VisualCore's FullScreenShaderScene: each frame it advances a VisualCore SceneClock (paused when palette
// animation is off), pins the shader time to it, and binds the model's snapshot as validated uniforms. All GL work
// stays inside VisualCore's host and scene; the app owns no EGL context.
import FractalExplorerCore
import VisualCoreMath
import VisualCoreParameters
import VisualCoreRendering
import VisualCoreSimulation

@MainActor
final class FractalScene: RenderScene {
    /// What the next frame draws.
    struct Snapshot: Equatable {
        var state: FractalState
        var paletteID: String = "sunset"
        var animate = true
    }

    /// Palette cycles per second along the bands while animating (spec assumption).
    static let rate = 0.05

    let inner: FullScreenShaderScene
    var snapshot: Snapshot
    private(set) var clock = SceneClock(duration: 86_400)
    /// Frames drawn (tests).
    private(set) var frames = 0

    init(snapshot: Snapshot, fragment: String = FractalShaders.fragment) {
        self.snapshot = snapshot
        inner = FullScreenShaderScene(fragment: fragment, fragmentName: FractalShaders.fragmentName,
                                      bundle: ShaderBundle(files: [:]))
    }

    /// The shader's first compile or link diagnostic, or nil.
    var errorMessage: String? { inner.errorMessage }

    func setup(_ context: RenderContext) throws { try inner.setup(context) }

    func resize(_ context: RenderContext) { inner.resize(context) }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        if snapshot.animate { clock.play() } else { clock.pause() }
        clock.advance(by: frame.delta)
        inner.fixedTime = clock.time
        bind(pixelWidth: context.pixelWidth)
        frames += 1
        try inner.render(context, frame: frame)
    }

    func teardown(_ context: RenderContext) { inner.teardown(context) }

    /// The uniforms for a target `pixelWidth` pixels wide: the plane step per pixel follows from the viewport's points.
    func bind(pixelWidth: Int) {
        let s = snapshot.state
        let pixelsPerPoint = Double(max(1, pixelWidth)) / s.viewport.size.x
        inner.parameters = [
            "centerX": s.viewport.center.x, "centerY": s.viewport.center.y,
            "step": s.viewport.unitsPerPoint / pixelsPerPoint,
            "mode": s.mode == .julia ? 1 : 0,
            "seedX": s.juliaSeed.x, "seedY": s.juliaSeed.y,
            "cap": Double(s.iterationCap), "radius": s.escapeRadius,
            "rate": Self.rate,
        ]
        let palette = Palette.builtIn(snapshot.paletteID) ?? Palette.builtIns[0]
        inner.palette = palette.linearStops.map { SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z)) }
    }
}
