// GardenScene.swift — renders and drives Lumen Garden using only documented VisualCore APIs (feature 009 T-F805;
// FR-F802, FR-F803, FR-F805): ResourceRegistry.program + ShaderLibrary (bundled background shader), PrimitiveRenderer
// (flowers), ParticleSystem + ParticleRenderer (light), FixedStepClock, PointerTracker + TapRecognizer +
// DragRecognizer, ViewMetrics + Camera2D. The app wraps it in an EffectScene glow.
import CVisualCoreGL
import Foundation
import GardenKit
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreShaderSource
import VisualCoreSimulation

@MainActor
final class GardenScene: RenderScene {
    private(set) var garden = Garden(seed: 2026)
    private var particles = ParticleSystem(capacity: 6_000, seed: 7)
    private var clock = FixedStepClock()
    private(set) var camera = Camera2D()
    private var metrics = ViewMetrics(size: .zero, scale: 1)
    private var tracker = PointerTracker()
    private var tapRecognizer = TapRecognizer()
    private var dragRecognizer = DragRecognizer()
    private var background: ShaderProgram?
    private var primitives: PrimitiveRenderer?
    private var particleRenderer: ParticleRenderer?
    private var backgroundTime = 0.0
    private(set) var lastError: String?
    /// Last interaction result (diagnostics and hints).
    private(set) var lastInteraction: InteractionResult?
    var scale = 1.0
    var reduceMotion = false

    static let burstSize = 80
    var bloomRate: Double { reduceMotion ? 8 : 30 }

    var status: String {
        "planted=\(garden.plantedCount) blooming=\(garden.bloomingCount) score=\(garden.score) particles=\(particles.aliveCount)"
    }

    init() {
        particles.forces = [.gravity(Vec2(0, 20)), .drag(0.8)]
    }

    func reset() {
        garden = Garden(seed: 2026)
        particles = ParticleSystem(capacity: 6_000, seed: 7)
        particles.forces = [.gravity(Vec2(0, 20)), .drag(0.8)]
        lastInteraction = nil
    }

    /// Returning from the background must not replay the time away (spec edge case).
    func didBecomeActive() { clock.resetAccumulator() }

    // MARK: Input

    func handle(_ e: PointerEvent) {
        tracker.handle(e)
        tapRecognizer.handle(e, tracker: tracker)
        dragRecognizer.handle(e, tracker: tracker)
        if tapRecognizer.state == .recognized, let loc = tapRecognizer.location, let world = metrics.toWorld(loc, camera: camera) {
            let result = garden.interact(at: world)
            lastInteraction = result
            if case .harvested = result, !reduceMotion { burst(at: world) }
            tapRecognizer.reset()
        }
        if dragRecognizer.state.isActive {
            garden.drag(velocity: Vec2(dragRecognizer.velocity.x, -dragRecognizer.velocity.y))   // view y-down → world y-up
        }
    }

    private func burst(at p: Vec2) {
        particles.emitters[0].position = p
        particles.burst(Self.burstSize, from: 0)
    }

    // MARK: RenderScene

    func setup(_ context: RenderContext) throws {
        lastError = nil
        do {
            var library = ShaderLibrary()
            let dir = Bundle.main.resourceURL!.appendingPathComponent("Shaders")
            let vs = try String(contentsOf: dir.appendingPathComponent("field.vert"), encoding: .utf8)
            let fs = try String(contentsOf: dir.appendingPathComponent("field.frag"), encoding: .utf8)
            library.add("field.vert", vs)
            library.add("field.frag", fs)
            background = try context.resources.program(vertex: vs, fragment: fs, library: library,
                                                       vertexName: "field.vert", fragmentName: "field.frag")
            primitives = try PrimitiveRenderer(registry: context.resources)
            particleRenderer = try ParticleRenderer(registry: context.resources)
        } catch {
            lastError = "\(error)"
        }
        resize(context)
    }

    func resize(_ context: RenderContext) {
        let s = scale > 0 ? scale : 1
        metrics = ViewMetrics(size: Vec2(Double(context.pixelWidth) / s, Double(context.pixelHeight) / s), scale: s)
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        if metrics.pixelSize.x != Double(context.pixelWidth) || metrics.scale != scale { resize(context) }
        for _ in 0..<clock.advance(by: frame.delta) { stepSimulation(clock.step) }
        if !reduceMotion { backgroundTime += frame.delta }

        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
        vcglViewport(0, 0, GLsizei(context.pixelWidth), GLsizei(context.pixelHeight))
        if let background {
            background.use()
            background.set("u_time", Float(backgroundTime))
            vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        }
        try primitives?.draw(flowerNodes(), camera: camera, metrics: metrics)
        try particleRenderer?.draw(particles.instances(), camera: camera, metrics: metrics)
    }

    func teardown(_ context: RenderContext) {
        if let background { context.resources.release(background) }
        background = nil
        primitives?.release(); primitives = nil
        particleRenderer?.release(); particleRenderer = nil
    }

    // MARK: Simulation and drawing

    private func stepSimulation(_ dt: Double) {
        garden.step(dt)
        // Emitter 0 is the harvest burst; one shedding emitter per bloom follows.
        let blooms = garden.flowers.filter { $0.stage == .bloom }
        var emitters = [Emitter(rate: 0, lifetime: 0.6...1.4, speed: 60...200, direction: .pi / 2, spread: 2 * .pi,
                                startSize: 7, endSize: 1, startColor: Vec4(1, 0.95, 0.7, 1), endColor: Vec4(1, 0.5, 0.8, 0))]
        if let burstEmitter = particles.emitters.first { emitters[0].position = burstEmitter.position }
        for f in blooms {
            let c = Self.color(hue: f.hue)
            emitters.append(Emitter(position: f.position + Vec2(0, 14), rate: bloomRate, lifetime: 1.5...3.0, speed: 8...30,
                                    direction: .pi / 2, spread: 1.2, startSize: 5, endSize: 1,
                                    startColor: Vec4(c.x, c.y, c.z, 0.9), endColor: Vec4(c.x, c.y, c.z, 0)))
        }
        particles.emitters = emitters
        particles.forces = [.gravity(Vec2(garden.breeze.x, 20 + garden.breeze.y)), .drag(0.8)]
        particles.step(dt)
    }

    private func flowerNodes() -> SceneNode {
        let root = SceneNode(id: "garden")
        for f in garden.flowers where f.stage != .harvested {
            let c = Self.color(hue: f.hue)
            let size = 0.35 + 0.65 * f.growth
            let flower = SceneNode(id: "flower-\(f.id)", position: f.position)
            flower.add(SceneNode(position: Vec2(0, -10), primitive: .line(Vec2(0, -14), Vec2(0, 6), width: 2),
                                 color: Vec4(0.25, 0.6, 0.3, 1)))
            if f.stage != .seed {
                let petals = (0..<10).map { i -> Vec2 in
                    let a = Double(i) * .pi / 5, r = i % 2 == 0 ? 16.0 : 7.0
                    return Vec2(cos(a) * r, sin(a) * r)
                }
                flower.add(SceneNode(scale: Vec2(size, size), primitive: .polygon(petals), color: Vec4(c.x, c.y, c.z, 0.9)))
            }
            flower.add(SceneNode(primitive: .circle(3 + 4 * f.growth), color: f.stage == .bloom ? Vec4(1, 0.95, 0.6, 1) : Vec4(0.7, 0.8, 0.5, 1)))
            root.add(flower)
        }
        return root
    }

    /// Hue (0…1) → saturated RGB.
    static func color(hue h: Double) -> Vec3 {
        func f(_ n: Double) -> Double { let k = (n + h * 6).truncatingRemainder(dividingBy: 6); return 1 - max(0, min(k, 4 - k, 1)) * 0.75 }
        return Vec3(f(5), f(3), f(1))
    }
}
