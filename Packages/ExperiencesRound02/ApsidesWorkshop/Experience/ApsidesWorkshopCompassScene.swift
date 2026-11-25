// ApsidesWorkshopCompassScene — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-001 … 004, 007; clarifications
// Q1–Q4). Draws one `ApsidesWorkshopSceneSnapshot` at one tier through the real GL path: the midnight clear; the
// compass mesh (the backdrop, the swept-area wedges, the compass spokes, rim, notches and brackets, the ghost loop, the
// orbit loop, the apsis markers, the planets with their hazard rings, the star, the orbiter, the gauges and the actions
// bars, in painter's order) with `ApsidesWorkshopShaders.compass*`, premultiplied, with `u_won` (1 on a won level)
// brightening the orbit loop and lighting every gauge mark; and the tier's glow shells (the star, the orbit loop and
// the orbiter) with the glow program, additive and last (level-0 two shells, level-1 one, level-2 none), the star's
// shell pulsed by `u_pulse` (`ApsidesWorkshopShaders.starPulse(time:reduceMotion:)`, 1 under Reduce Motion) and the
// gain capped by `u_glowLimit` (the Reduce Flashing cap). Depth testing is off on this path: the geometry emits its
// triangles in painter's order. The star pulses by a uniform, so the meshes are rebuilt only when what they read
// changes: the level, the orbit, the shown tick, the stage, the failure, the met count, the actions left, the tier or
// the fallback. If a program fails, the scene falls back to the level-2 geometry drawn unlit with the shared
// `MeshRenderer` (ambient 1, the geometry's fallback colours, the won marks included) and keeps the reason; nothing
// here can reach the kernel. A zero-sized drawable is cleared and nothing else is drawn.
#if os(iOS)
import ApsidesWorkshopCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Apsides Workshop.
@MainActor
final class ApsidesWorkshopCompassScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The compass fragment source (the tests' seam replaces it with a broken one before setup).
    var compassFragment = ApsidesWorkshopShaders.compassFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the star is still (Reduce Motion).
    var reduceMotion = false
    /// How many times the compass mesh was built (tests: it is not rebuilt while only the star pulses).
    private(set) var compassBuilds = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds = 0
    /// The star pulse passed as `u_pulse` on the last draw (tests).
    private(set) var lastPulse: Double = 1

    /// What the meshes depend on: everything of the snapshot that the geometry reads, the tier and the fallback.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let orbit: ApsidesWorkshopOrbit
        let shownTick: Int
        let stage: ApsidesWorkshopStage
        let failure: ApsidesWorkshopFailure?
        let met: [Bool]
        let actionsLeft: Int
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var compassRenderer: ShaderMeshRenderer?
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
        compassRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        compassRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if compassRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { ApsidesWorkshopShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer.
    func render(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier, context: RenderContext,
                frame: FrameInfo) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let midnight = ApsidesWorkshopPalette.midnight
        let clear = ClearColorScene(red: Float(midnight.x), green: Float(midnight.y), blue: Float(midnight.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = ApsidesWorkshopSceneGeometry.camera(aspect: aspect)
        let next: GeometryKey = key(snapshot, tier: tier)
        if next != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won: Float = snapshot.isWon ? 1 : 0
        let pulse: Double = ApsidesWorkshopShaders.starPulse(time: snapshot.time, reduceMotion: reduceMotion)
        lastPulse = pulse
        try drawCompass(camera, won: won)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        let gain = ApsidesWorkshopShaders.glowGain(for: tier)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won, pulse: Float(pulse))
    }

    /// The geometry key of `snapshot` at `tier`.
    private func key(_ s: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier) -> GeometryKey {
        var met: [Bool] = []
        for gauge in s.gauges { met.append(gauge.met) }
        return GeometryKey(levelNumber: s.levelNumber, orbit: s.orbit, shownTick: s.shownTick, stage: s.stage,
                           failure: s.failure, met: met, actionsLeft: s.actionsLeft, tier: tier.index,
                           fallback: fallbackReason != nil)
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let compass = try ApsidesWorkshopSceneGeometry.compassMesh(snapshot, tier: tier)
                compassRenderer = try Self.renderer(compass, vertex: ApsidesWorkshopShaders.compassVertex,
                                                    fragment: compassFragment, name: "apsides-workshop-compass",
                                                    registry: registry)
                compassBuilds += 1
                let glow = try ApsidesWorkshopSceneGeometry.glowMesh(snapshot, tier: tier)
                glowBuilds += 1
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: ApsidesWorkshopShaders.glowVertex,
                                                     fragment: ApsidesWorkshopShaders.glowFragment,
                                                     name: "apsides-workshop-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "apsides-workshop shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the failure marks and the won marks
        // included; level-2 has no glow).
        let minimal = ApsidesWorkshopTier.of(ApsidesWorkshopTier.all.count - 1)
        let up = Vec3(0, 0, 1)
        let parts: [ApsidesWorkshopColouredMesh] = [
            try ApsidesWorkshopSceneGeometry.compassPart(snapshot, tier: minimal),
            try ApsidesWorkshopSceneGeometry.glowPart(snapshot, tier: minimal),
        ]
        for part in parts where !part.mesh.indices.isEmpty {
            var mesh = part.mesh
            // The normal slot carries shader data (local coordinates, glow colours); lighting is off (ambient 1), so
            // every vertex gets a real normal and the fallback reads the colour stream.
            mesh.normals = Array(repeating: up, count: mesh.positions.count)
            let renderer = try MeshRenderer(mesh: mesh, colors: part.colours, registry: registry)
            renderer.ambient = 1
            fallbackRenderers.append(renderer)
        }
        compassBuilds += 1
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the compass mesh: `u_mvp` and `u_won`.
    private func drawCompass(_ camera: ApsidesWorkshopCamera, won: Float) throws {
        guard let compassRenderer else { return }
        let mvp = camera.viewProjection
        try compassRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: false) { p in
            p.set(ApsidesWorkshopShaders.mvpUniform, matrix4: mvp.floats)
            p.set(ApsidesWorkshopShaders.wonUniform, won)
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain`, `u_glowLimit`, `u_won` and `u_pulse`.
    private func drawGlow(_ camera: ApsidesWorkshopCamera, gain: Double, won: Float, pulse: Float) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: false) { p in
            p.set(ApsidesWorkshopShaders.mvpUniform, matrix4: mvp.floats)
            p.set(ApsidesWorkshopShaders.glowGainUniform, Float(gain))
            p.set(ApsidesWorkshopShaders.glowLimitUniform, limit)
            p.set(ApsidesWorkshopShaders.wonUniform, won)
            p.set(ApsidesWorkshopShaders.pulseUniform, pulse)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: ApsidesWorkshopCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
