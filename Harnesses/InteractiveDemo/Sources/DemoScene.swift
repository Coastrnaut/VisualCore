// DemoScene.swift — combines input, fixed-step particles, a timeline and 2D primitives on the VisualCore
// render host (feature 006 T-F519; FR-F510; spec US5). Drag spawns particles under the finger, pinch zooms
// the camera (with inertia unless Reduce Motion is on), shapes animate on a timeline.
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class DemoScene: RenderScene {
    let model: DemoModel
    /// Points → pixels (view contentScaleFactor), set by the view wrapper.
    var scale = 1.0

    private var particles = ParticleSystem(capacity: 10_000, seed: 2026)
    private var clock = FixedStepClock()
    private var timeline = Timeline()
    private var camera = Camera2D()
    private let root = SceneNode(id: "root")
    private let spinner = SceneNode(id: "spinner", primitive: .rect(Vec2(60, 60)), color: Vec4(0.2, 0.6, 1, 0.9))
    private let pulse = SceneNode(id: "pulse", position: Vec2(-90, 140), primitive: .circle(28), color: Vec4(1, 0.4, 0.3, 0.9))
    private let star = SceneNode(id: "star", position: Vec2(90, 140), color: Vec4(1, 0.85, 0.2, 0.9))

    private var tracker = PointerTracker()
    private var drag = DragRecognizer()
    private var pinch = PinchRecognizer()
    private var lastPinchScale = 1.0
    private var zoomVelocity = 0.0          // log-zoom per second (inertia)
    private var lastEventTime = 0.0
    private var metrics = ViewMetrics(size: .zero, scale: 1)

    private var primitives: PrimitiveRenderer?
    private var particleRenderer: ParticleRenderer?
    private var frameCounter = 0

    init(model: DemoModel) {
        self.model = model
        particles.emitters = [Emitter(rate: 0, lifetime: 0.6...1.6, speed: 40...160, direction: .pi / 2, spread: 2 * .pi,
                                      startSize: 10, endSize: 2, startColor: Vec4(1, 0.9, 0.4, 1), endColor: Vec4(1, 0.2, 0.6, 0))]
        particles.forces = [.gravity(Vec2(0, -240)), .drag(0.6)]
        timeline.add(Tween(from: 0, to: 2 * .pi, duration: 4, repeatCount: nil), name: "spin")
        timeline.add(Tween(from: 0.8, to: 1.25, duration: 0.9, curve: .sine, mode: .inOut, repeatCount: nil, autoreverses: true), name: "pulse")
        star.primitive = .polygon((0..<10).map { i in
            let a = Double(i) * .pi / 5 + .pi / 2, r = i % 2 == 0 ? 32.0 : 13.0
            return Vec2(cos(a) * r, sin(a) * r)
        })
        [spinner, pulse, star].forEach(root.add)
    }

    var reduceMotion = false {
        didSet {
            timeline.reduceMotion = reduceMotion
            if reduceMotion { zoomVelocity = 0 }
            model.reduceMotion = reduceMotion
        }
    }

    func setRunning(_ running: Bool) {
        model.running = running
        clock.resetAccumulator()
    }

    func reset() {
        particles = ParticleSystem(capacity: 10_000, seed: 2026)
        particles.emitters = [Emitter(rate: 0, lifetime: 0.6...1.6, speed: 40...160, direction: .pi / 2, spread: 2 * .pi,
                                      startSize: 10, endSize: 2, startColor: Vec4(1, 0.9, 0.4, 1), endColor: Vec4(1, 0.2, 0.6, 0))]
        particles.forces = [.gravity(Vec2(0, -240)), .drag(0.6)]
        camera = Camera2D()
        zoomVelocity = 0
        timeline.seek(to: 0)
        publish()
    }

    /// Called when the app returns to the foreground: no catch-up burst (spec US5 AC3).
    func didBecomeActive() {
        clock.resetAccumulator()
        model.maxStepsPerFrame = 0
    }

    // MARK: Input

    func handle(_ e: PointerEvent) {
        tracker.handle(e)
        drag.handle(e, tracker: tracker)
        pinch.handle(e, tracker: tracker)
        lastEventTime = e.timestamp
        switch drag.state {
        case .began, .changed:
            if let loc = drag.location, let world = metrics.toWorld(loc, camera: camera) {
                particles.emitters[0].position = world
                particles.emitters[0].rate = 400
                particles.emitters[0].isEmitting = true
            }
        default:
            particles.emitters[0].isEmitting = false
        }
        switch pinch.state {
        case .began:
            lastPinchScale = pinch.scale
        case .changed:
            let factor = pinch.scale / lastPinchScale
            if let c = pinch.center, let anchor = metrics.toCamera(c), factor.isFinite, factor > 0 {
                camera.zoom(by: factor, around: anchor)
                zoomVelocity = log(factor) * 60   // approximate per-second rate at ~60 Hz input
            }
            lastPinchScale = pinch.scale
        case .ended:
            if reduceMotion { zoomVelocity = 0 }
        default: break
        }
        publish()
    }

    // MARK: RenderScene

    func setup(_ context: RenderContext) throws {
        primitives = try PrimitiveRenderer(registry: context.resources)
        particleRenderer = try ParticleRenderer(registry: context.resources)
        resize(context)
    }

    func resize(_ context: RenderContext) {
        let s = scale > 0 ? scale : 1
        metrics = ViewMetrics(size: Vec2(Double(context.pixelWidth) / s, Double(context.pixelHeight) / s), scale: s)
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        if metrics.pixelSize.x != Double(context.pixelWidth) { resize(context) }
        if model.running {
            let steps = clock.advance(by: frame.delta)
            for _ in 0..<steps { particles.step(clock.step) }
            model.maxStepsPerFrame = max(model.maxStepsPerFrame, steps)
            timeline.advance(by: frame.delta)
            if !reduceMotion, zoomVelocity != 0, !pinch.state.isActive {
                camera.zoom(by: exp(zoomVelocity * frame.delta))
                zoomVelocity *= exp(-6 * frame.delta)
                if abs(zoomVelocity) < 0.01 { zoomVelocity = 0 }
            }
        }
        spinner.rotation = timeline.value(of: "spin") ?? 0
        let p = timeline.value(of: "pulse") ?? 1
        pulse.scale = Vec2(p, p)
        star.rotation = -(timeline.value(of: "spin") ?? 0) / 2

        vcglClearColor(0.04, 0.04, 0.08, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        try primitives?.draw(root, camera: camera, metrics: metrics)
        try particleRenderer?.draw(particles.instances(), camera: camera, metrics: metrics)
        frameCounter += 1
        if frameCounter % 6 == 0 { publish() }
    }

    func teardown(_ context: RenderContext) {
        primitives?.release(); primitives = nil
        particleRenderer?.release(); particleRenderer = nil
    }

    private func publish() {
        model.particles = particles.aliveCount
        model.zoom = camera.zoom
    }
}
