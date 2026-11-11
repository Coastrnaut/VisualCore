// PostProcessingScene.swift — Showcase scene 5: a three-pass effect graph (grade → glow → wave) over the animated
// geometry, toggleable, with the Reduce Flashing limiter appended when enabled (feature 007 T-F609; FR-F603, FR-F605,
// FR-F609; US2 AC2; F04 EffectScene). Status `passes=a>b>c` or `passes=off`.
import Foundation
import VisualCoreEffects
import VisualCoreEffectsGraph
import VisualCoreRendering
import VisualCoreScenes

@MainActor
final class PostProcessingScene: ShowcaseRenderScene {
    private let settings: ShowcaseSettings
    private let content: AnimatedGeometryScene
    let effect: EffectScene

    /// Warm color grade, bloom glow, gentle wave distortion.
    static let graph = EffectGraphDescription(passes: [
        EffectPassDescription(id: "grade", type: "colorMatrix", inputs: ["input": "scene"], output: "graded",
                              params: ["matrix": [1.15, 0.05, 0, 0,  0.05, 1.0, 0, 0,  0, 0.05, 0.85, 0,  0, 0, 0, 1],
                                       "offset": [0.02, 0.0, 0.03, 0]]),
        EffectPassDescription(id: "glow", type: "bloom", inputs: ["input": "graded"], output: "glowing",
                              params: ["threshold": [0.55], "intensity": [1.4], "radius": [10]]),
        EffectPassDescription(id: "wave", type: "distort", inputs: ["input": "glowing"], output: "out",
                              params: ["strength": [0.012], "frequency": [10], "speed": [1]]),
    ], output: "out")
    static let passthrough = EffectGraphDescription(passes: [
        EffectPassDescription(id: "passthrough", type: "copy", inputs: ["input": "scene"], output: "out"),
    ], output: "out")

    private(set) var errorMessage: String?
    var scale: Double { get { content.scale } set { content.scale = newValue } }
    var effectsEnabled: Bool? {
        get { effect.graph == Self.graph }
        set { effect.graph = newValue == true ? Self.graph : Self.passthrough }
    }
    var status: String {
        guard effect.graph == Self.graph else { return "passes=off" }
        return "passes=" + effect.effectiveGraph.passes.map(\.id).joined(separator: ">")
    }

    init(settings: ShowcaseSettings) {
        self.settings = settings
        content = AnimatedGeometryScene(settings: settings)
        effect = EffectScene(content: content, graph: Self.graph)
        effect.reduceFlashing = settings.reduceFlashing
    }

    func handle(_ event: PointerEvent) { content.handle(event) }

    func setup(_ context: RenderContext) throws { try effect.setup(context) }
    func resize(_ context: RenderContext) { effect.resize(context) }
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        if effect.reduceFlashing != settings.reduceFlashing { effect.reduceFlashing = settings.reduceFlashing }
        try effect.render(context, frame: frame)
        errorMessage = effect.lastError.map { "Effect graph: \($0)" } ?? content.errorMessage
    }
    func teardown(_ context: RenderContext) { effect.teardown(context) }
}
