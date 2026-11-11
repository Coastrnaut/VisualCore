// AnimatedGeometryScene.swift — Showcase scene 2: lit meshes animated on a timeline, orbited by drag
// (feature 007 T-F606; FR-F603, FR-F606, FR-F609; uses F05 MeshRenderer, OrbitCamera, Timeline, DragRecognizer).
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class AnimatedGeometryScene: ShowcaseRenderScene {
    private let settings: ShowcaseSettings
    private var cube: MeshRenderer?
    private var sphere: MeshRenderer?
    private var camera = OrbitCamera(distance: 6, pitch: 0.25)
    private var timeline = Timeline()
    private var tracker = PointerTracker()
    private var drag = DragRecognizer(minDistance: 4)
    private var lastTranslation = Vec2.zero
    private var aspect = 1.0
    private(set) var errorMessage: String?
    var scale = 1.0
    var status: String {
        String(format: "yaw=%.2f pitch=%.2f spin=%@", camera.yaw, camera.pitch, settings.reduceMotion ? "off" : "on")
    }

    init(settings: ShowcaseSettings) {
        self.settings = settings
        timeline.add(Tween(from: 0, to: 2 * .pi, duration: 6, repeatCount: nil), name: "spin")
        timeline.add(Tween(from: -0.4, to: 0.4, duration: 1.5, curve: .sine, mode: .inOut, repeatCount: nil, autoreverses: true), name: "bob")
    }

    /// Spin angle (radians) currently applied; constant under Reduce Motion.
    var spin: Double { settings.reduceMotion ? 0.6 : (timeline.value(of: "spin") ?? 0) }

    func handle(_ event: PointerEvent) {
        tracker.handle(event)
        drag.handle(event, tracker: tracker)
        switch drag.state {
        case .began: lastTranslation = drag.translation
        case .changed:
            let d = drag.translation - lastTranslation
            lastTranslation = drag.translation
            camera.orbit(dYaw: -d.x * 0.01, dPitch: d.y * 0.01)
        default: break
        }
    }

    func setup(_ context: RenderContext) throws {
        do {
            cube = try MeshRenderer(mesh: .cube(), registry: context.resources)
            sphere = try MeshRenderer(mesh: .uvSphere(segments: 48, rings: 24), registry: context.resources)
            errorMessage = nil
        } catch { errorMessage = "Mesh setup failed: \(error)" }
        resize(context)
    }

    func resize(_ context: RenderContext) {
        aspect = context.pixelHeight > 0 ? Double(context.pixelWidth) / Double(context.pixelHeight) : 1
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        timeline.reduceMotion = settings.reduceMotion
        if !settings.reduceMotion { timeline.advance(by: frame.delta) }
        vcglClearColor(0.05, 0.05, 0.09, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        let bob = settings.reduceMotion ? 0 : (timeline.value(of: "bob") ?? 0)
        let spinQ = Quat(axis: Vec3(0.3, 1, 0.2), angle: spin)
        try cube?.draw(model: .translation(Vec3(-1.6, bob, 0)) * .rotation(spinQ) * .scale(Vec3(1.6, 1.6, 1.6)),
                       camera: camera, aspect: aspect, color: Vec4(0.25, 0.6, 1, 1))
        try sphere?.draw(model: .translation(Vec3(1.6, -bob, 0)) * .rotation(spinQ),
                         camera: camera, aspect: aspect, color: Vec4(1, 0.55, 0.25, 1))
    }

    func teardown(_ context: RenderContext) {
        cube?.release(); sphere?.release()
        cube = nil; sphere = nil
    }
}
