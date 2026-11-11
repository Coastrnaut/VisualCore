// ParticleShowcaseScene.swift — Showcase scene 4: fixed-step particles spawned by drag, camera zoomed by pinch
// (feature 007 T-F608; FR-F603, FR-F606; US3 AC2; F05 ParticleSystem, FixedStepClock, recognizers, renderers).
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class ParticleShowcaseScene: ShowcaseRenderScene {
    private let settings: ShowcaseSettings
    private var system = ParticleSystem(capacity: 20_000, seed: 7)
    private var clock = FixedStepClock()
    private(set) var camera = Camera2D()
    private var metrics = ViewMetrics(size: .zero, scale: 1)
    private var tracker = PointerTracker()
    private var drag = DragRecognizer(minDistance: 4)
    private var pinch = PinchRecognizer()
    private var lastScale = 1.0
    private var renderer: ParticleRenderer?
    private var primitives: PrimitiveRenderer?
    private let ground = SceneNode(id: "ground", position: Vec2(0, -150), primitive: .rect(Vec2(400, 6)), color: Vec4(0.3, 0.35, 0.5, 1))
    private(set) var errorMessage: String?
    var scale = 1.0
    var particleCount: Int { system.aliveCount }
    var status: String { "particles=\(system.aliveCount) zoom=\(String(format: "%.2f", camera.zoom))" }

    init(settings: ShowcaseSettings) {
        self.settings = settings
        system.emitters = [Emitter(rate: 0, lifetime: 0.8...2.0, speed: 60...220, direction: .pi / 2, spread: 1.6,
                                   startSize: 9, endSize: 2, startColor: Vec4(0.5, 0.9, 1, 1), endColor: Vec4(0.9, 0.3, 1, 0))]
        system.forces = [.gravity(Vec2(0, -300)), .drag(0.4)]
    }

    func handle(_ event: PointerEvent) {
        tracker.handle(event)
        drag.handle(event, tracker: tracker)
        pinch.handle(event, tracker: tracker)
        if event.phase == .began, tracker.count == 1, let w = metrics.toWorld(event.location, camera: camera) {
            system.emitters[0].position = w
            system.burst(30)
        }
        if drag.state.isActive, let loc = drag.location, let w = metrics.toWorld(loc, camera: camera) {
            system.emitters[0].position = w
            system.emitters[0].rate = 500
            system.emitters[0].isEmitting = true
        } else {
            system.emitters[0].isEmitting = false
        }
        // The pinch's scale is relative to where the fingers started, so the change that made it begin counts too.
        if pinch.state == .began { lastScale = 1 }
        if pinch.state.isActive {
            if let c = pinch.center, let anchor = metrics.toCamera(c), lastScale > 0 {
                camera.zoom(by: pinch.scale / lastScale, around: anchor)
            }
            lastScale = pinch.scale
        }
    }

    func setup(_ context: RenderContext) throws {
        do {
            renderer = try ParticleRenderer(registry: context.resources)
            primitives = try PrimitiveRenderer(registry: context.resources)
            errorMessage = nil
        } catch { errorMessage = "Particle renderer failed: \(error)" }
        resize(context)
    }

    func resize(_ context: RenderContext) {
        let s = scale > 0 ? scale : 1
        metrics = ViewMetrics(size: Vec2(Double(context.pixelWidth) / s, Double(context.pixelHeight) / s), scale: s)
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        if metrics.pixelSize.x != Double(context.pixelWidth) || metrics.scale != scale { resize(context) }
        for _ in 0..<clock.advance(by: frame.delta) { system.step(clock.step) }
        vcglClearColor(0.02, 0.02, 0.05, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        try primitives?.draw(ground, camera: camera, metrics: metrics)
        try renderer?.draw(system.instances(), camera: camera, metrics: metrics)
    }

    func teardown(_ context: RenderContext) {
        renderer?.release(); primitives?.release()
        renderer = nil; primitives = nil
    }
}
