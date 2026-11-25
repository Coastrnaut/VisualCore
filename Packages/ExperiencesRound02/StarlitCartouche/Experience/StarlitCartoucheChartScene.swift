// StarlitCartoucheChartScene — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-001 … 004, 007; clarifications
// Q1–Q4). Draws one `StarlitCartoucheSceneSnapshot` at one tier through the real GL path: the night clear; the chart
// mesh (the firmament, corridors, hazard tubes, trails and their ghosts, stars with notched rings, the ship, the beacon
// and chosen rings, the failed leg and the gauges, in painter's order) with `StarlitCartoucheShaders.chart*`,
// premultiplied, `u_firmamentAngle` turning the firmament with the presentation time (0 under Reduce Motion) and
// `u_won` (`StarlitCartoucheSceneGeometry.wonFlag`) flaring the trails and sealing the cartouche of a won level; and the
// tier's glow shells (stars, the ship and lit trails) with the glow program, additive and last (level-0 two shells,
// level-1 one, level-2 none). Depth testing is off on this path: the geometry emits its triangles in painter's order.
// The firmament turns by a uniform, so the meshes are rebuilt only when what they read changes: the level, the beat,
// the legs, the drawn strokes, the choice, the stage, the failure, the actions left, the ship's glide, the tier or the
// fallback. If a program fails, the scene falls back to the level-2 geometry drawn unlit with the shared `MeshRenderer`
// (ambient 1, the geometry's fallback colours) and keeps the reason; nothing here can reach the kernel. A zero-sized
// drawable is cleared and nothing else is drawn.
#if os(iOS)
import Foundation
import StarlitCartoucheCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Starlit Cartouche.
@MainActor
final class StarlitCartoucheChartScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The chart fragment source (the tests' seam replaces it with a broken one before setup).
    var chartFragment = StarlitCartoucheShaders.chartFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the firmament is still (Reduce Motion).
    var reduceMotion = false
    /// How many times the chart mesh was built (tests: it is not rebuilt while only the firmament turns).
    private(set) var chartBuilds = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds = 0
    /// The firmament angle passed on the last draw (tests).
    private(set) var lastFirmamentAngle: Double = 0

    /// What the meshes depend on: everything of the snapshot that the geometry reads, the glide, the tier and the
    /// fallback.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let beat: Int
        let star: Int
        let legs: [StarlitCartoucheLeg]
        let drawn: [Int]
        let chosenStar: Int
        let chosenWait: Int
        let stage: StarlitCartoucheStage
        let failure: StarlitCartoucheFailure?
        let actionsLeft: Int
        let glide: Double
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var chartRenderer: ShaderMeshRenderer?
    private var glowRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var geometryKey: GeometryKey?
    private var aspect = 1.0

    /// Records the registry and the view's aspect.
    func setup(_ context: RenderContext) {
        registry = context.resources
        resize(context)
    }

    /// Records the new aspect; the camera follows on the next draw. The meshes face the authored camera, so they are
    /// rebuilt only when the aspect really changed.
    func resize(_ context: RenderContext) {
        let next: Double = Double(max(1, context.pixelWidth)) / Double(max(1, context.pixelHeight))
        if next != aspect { geometryKey = nil }
        aspect = next
    }

    /// Releases every GPU object; the next draw rebuilds them (memory warning, teardown).
    func release() {
        chartRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        chartRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if chartRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { StarlitCartoucheShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer with the ship placed by `glide` (0 … 1).
    func render(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier, context: RenderContext,
                frame: FrameInfo, glide: Double) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let night = StarlitCartouchePalette.night
        let clear = ClearColorScene(red: Float(night.x), green: Float(night.y), blue: Float(night.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let place: Double = glide.isFinite ? min(max(glide, 0), 1) : 1
        let camera = StarlitCartoucheSceneGeometry.camera(snapshot, aspect: aspect)
        let next: GeometryKey = key(snapshot, tier: tier, glide: place)
        if next != geometryKey { try rebuild(snapshot, tier: tier, glide: place) }
        geometryKey = key(snapshot, tier: tier, glide: place)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won = Float(StarlitCartoucheSceneGeometry.wonFlag(snapshot))
        let angle: Double = StarlitCartoucheShaders.firmamentAngle(time: snapshot.time, reduceMotion: reduceMotion)
        lastFirmamentAngle = angle
        try drawChart(camera, won: won, angle: Float(angle))
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        let gain = StarlitCartoucheShaders.glowGain(for: tier)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won)
    }

    /// The geometry key of `snapshot` at `tier` with `glide`.
    private func key(_ s: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier, glide: Double) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, beat: s.beat, star: s.star, legs: s.legs, drawn: s.drawn,
                    chosenStar: s.chosenStar, chosenWait: s.chosenWait, stage: s.stage, failure: s.failure,
                    actionsLeft: s.actionsLeft, glide: glide, tier: tier.index, fallback: fallbackReason != nil)
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier, glide: Double) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let chart = try StarlitCartoucheSceneGeometry.chartMesh(snapshot, tier: tier, glide: glide)
                chartRenderer = try Self.renderer(chart, vertex: StarlitCartoucheShaders.chartVertex,
                                                  fragment: chartFragment, name: "starlit-cartouche-chart",
                                                  registry: registry)
                chartBuilds += 1
                let glow = try StarlitCartoucheSceneGeometry.glowMesh(snapshot, tier: tier, glide: glide)
                glowBuilds += 1
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: StarlitCartoucheShaders.glowVertex,
                                                     fragment: StarlitCartoucheShaders.glowFragment,
                                                     name: "starlit-cartouche-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "starlit-cartouche shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the failed leg and the won look included;
        // level-2 has no glow).
        let minimal = StarlitCartoucheTier.of(StarlitCartoucheTier.all.count - 1)
        let up = Vec3(0, 0, 1)
        let parts: [StarlitCartoucheColouredMesh] = [
            try StarlitCartoucheSceneGeometry.chartPart(snapshot, tier: minimal, glide: glide),
            try StarlitCartoucheSceneGeometry.glowPart(snapshot, tier: minimal, glide: glide),
        ]
        for part in parts where !part.mesh.indices.isEmpty {
            var mesh = part.mesh
            // The normal slot may carry shader data (glow colours); lighting is off (ambient 1), so every vertex gets
            // a real normal and the fallback reads the colour stream.
            mesh.normals = Array(repeating: up, count: mesh.positions.count)
            let renderer = try MeshRenderer(mesh: mesh, colors: part.colours, registry: registry)
            renderer.ambient = 1
            fallbackRenderers.append(renderer)
        }
        chartBuilds += 1
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the chart mesh: `u_mvp`, `u_won` and `u_firmamentAngle`.
    private func drawChart(_ camera: StarlitCartoucheCamera, won: Float, angle: Float) throws {
        guard let chartRenderer else { return }
        let mvp = camera.viewProjection
        try chartRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: false) { p in
            p.set(StarlitCartoucheShaders.mvpUniform, matrix4: mvp.floats)
            p.set(StarlitCartoucheShaders.wonUniform, won)
            p.set(StarlitCartoucheShaders.firmamentAngleUniform, angle)
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain`, `u_glowLimit` and `u_won`.
    private func drawGlow(_ camera: StarlitCartoucheCamera, gain: Double, won: Float) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: false) { p in
            p.set(StarlitCartoucheShaders.mvpUniform, matrix4: mvp.floats)
            p.set(StarlitCartoucheShaders.glowGainUniform, Float(gain))
            p.set(StarlitCartoucheShaders.glowLimitUniform, limit)
            p.set(StarlitCartoucheShaders.wonUniform, won)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: StarlitCartoucheCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
