// BackwardsAuroraAuroraScene — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-001 … 004, 007; clarifications
// Q1–Q4). Draws one `BackwardsAuroraSceneSnapshot` at one tier through the real GL path: the midnight ground clear; the
// aurora (ground plane, section band, trailing layers, ghost trail, checkpoint ticks, the ribbon through the kernel's
// exact samples, rings and discs, kink and tear crosses, the reversal gauge) with `BackwardsAuroraShaders.aurora*`,
// premultiplied, the shimmer and the direction-coded pulses following `u_time` (held at 0 under Reduce Motion); and the
// tier's glow shells around the ribbon with the glow program, additive (level-0 two, level-1 one, level-2 none). Depth
// testing is off on this path, so the order the geometry emits is the layering; back faces are culled on every draw.
// Geometry is rebuilt only when the level, the samples, the section, the stage, the failure, the reversals spent, the
// tier or the mode change; the shimmer and the pulses move by uniforms. Reduce Flashing passes
// `BackwardsAuroraShaders.glowLimit(reduceFlashing:)` as `u_glowLimit`. If a program fails, the scene falls back to
// the level-2 geometry drawn unlit with the shared `MeshRenderer` (ambient 1, per-vertex colours) and keeps the reason;
// nothing here can reach the kernel. Feature 394 (R02-G10-04): the camera follows the presenter's orbit and the snapshot
// may carry a freeze preview, drawn as a pale dashed ribbon. Feature 396 (R02-G10-06) T-R02G1006-005: the presenter's
// eased lights set `u_won` (`lights.won`), scale the glow gain (`lights.glow`) and the tear cross's and preview ribbon's
// alphas (`u_tearLight`, `u_previewLight`); the tear cross is kept on `fadingTear` (the last torn seam) while its light
// fades out after an undo. The lights are uniforms, so a fade rebuilds no geometry; only `fadingTear` joins the key.
#if os(iOS)
import BackwardsAuroraCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Backwards Aurora.
@MainActor
final class BackwardsAuroraAuroraScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The aurora fragment source (the tests' seam replaces it with a broken one before setup).
    var auroraFragment = BackwardsAuroraShaders.auroraFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the pulses and the shimmer stand still (Reduce Motion).
    var reduceMotion = false
    /// The camera orbit (presentation only), set by the presenter before each frame (feature 394, R02-G10-04).
    var orbit: BackwardsAuroraOrbit = .authored
    /// The eased light levels (presentation only), set by the presenter before each frame (feature 396); nil draws
    /// the full levels (`u_won` from the stage, the full glow gain, the tear cross and the preview at full alpha).
    var lights: BackwardsAuroraLights?
    /// The last torn seam, where the tear cross fades out after an undo (feature 396), set by the presenter.
    var fadingTear: Int?
    /// The light direction of the aurora (from the upper front).
    static let lightDirection = SIMD3<Float>(0.2, 0.6, 0.77)

    /// What the geometry depends on: everything of the snapshot that the meshes read, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let samples: [Int]
        let sectionStart: Int
        let sectionEnd: Int
        let stage: BackwardsAuroraStage
        let failure: BackwardsAuroraFailure?
        let spent: Int
        let preview: [Int]
        let fadingTear: Int?
        let orbit: BackwardsAuroraOrbit
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var auroraRenderer: ShaderMeshRenderer?
    private var glowRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var geometryKey: GeometryKey?
    private var aspect = 1.0

    /// Records the registry and the view's aspect.
    func setup(_ context: RenderContext) {
        registry = context.resources
        resize(context)
    }

    /// Records the new aspect; the camera follows on the next draw.
    func resize(_ context: RenderContext) {
        aspect = Double(max(1, context.pixelWidth)) / Double(max(1, context.pixelHeight))
        geometryKey = nil
    }

    /// Releases every GPU object; the next draw rebuilds them (memory warning, teardown).
    func release() {
        auroraRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        auroraRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if auroraRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { BackwardsAuroraShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the shimmer and the pulses still.
    func render(_ snapshot: BackwardsAuroraSceneSnapshot, tier: BackwardsAuroraTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let ground = BackwardsAuroraPalette.ground
        let clear = ClearColorScene(red: Float(ground.x), green: Float(ground.y), blue: Float(ground.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = BackwardsAuroraSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        let key = key(snapshot, tier: tier)
        if key != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = self.key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let time = Float(animate && !reduceMotion ? snapshot.time : 0)
        let won: Float = lights.map { Float(min(max($0.won, 0), 1)) }
            ?? BackwardsAuroraShaders.won(stage: snapshot.stage, failure: snapshot.failure)
        try drawAurora(camera, time: time, tier: tier, won: won,
                       tearLight: Float(min(max(lights?.tear ?? 1, 0), 1)),
                       previewLight: Float(min(max(lights?.preview ?? 1, 0), 1)))
        let gain = BackwardsAuroraShaders.glowGain(for: tier) * min(max(lights?.glow ?? 1, 0), 1)
        guard tier.glowShells > 0, gain > 0 else { return }
        try drawGlow(camera, gain: gain)
    }

    /// The geometry key of `snapshot` at `tier` in the current mode.
    private func key(_ s: BackwardsAuroraSceneSnapshot, tier: BackwardsAuroraTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, samples: s.samples, sectionStart: s.sectionStart,
                    sectionEnd: s.sectionEnd, stage: s.stage, failure: s.failure, spent: s.spent, preview: s.preview,
                    fadingTear: s.tear == nil ? fadingTear : nil, orbit: orbit, tier: tier.index,
                    fallback: fallbackReason != nil)
    }

    private func rebuild(_ snapshot: BackwardsAuroraSceneSnapshot, tier: BackwardsAuroraTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let aurora = try BackwardsAuroraSceneGeometry.auroraMesh(snapshot, tier: tier,
                                                                          reduceMotion: reduceMotion,
                                                                          fadingTear: fadingTear)
                auroraRenderer = try Self.renderer(aurora, vertex: BackwardsAuroraShaders.auroraVertex,
                                                   fragment: auroraFragment, name: "backwards-aurora-aurora",
                                                   registry: registry)
                let glow = try BackwardsAuroraSceneGeometry.glowMesh(snapshot, tier: tier)
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: BackwardsAuroraShaders.glowVertex,
                                                     fragment: BackwardsAuroraShaders.glowFragment,
                                                     name: "backwards-aurora-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "backwards-aurora shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its per-vertex colours.
        let minimal = BackwardsAuroraTier.of(BackwardsAuroraTier.all.count - 1)
        let up = Vec3(0, 1, 0)
        let parts: [(part: BackwardsAuroraColouredMesh, colourInNormals: Bool)] = [
            (part: try BackwardsAuroraSceneGeometry.auroraPart(snapshot, tier: minimal), colourInNormals: false),
            (part: try BackwardsAuroraSceneGeometry.glowPart(snapshot, tier: minimal), colourInNormals: true),
        ]
        for entry in parts where !entry.part.mesh.indices.isEmpty {
            var mesh = entry.part.mesh
            // The glow mesh carries colours in the normal slot; the fallback reads the colour stream instead and gets a
            // real normal (lighting is off: ambient 1).
            if entry.colourInNormals { mesh.normals = Array(repeating: up, count: mesh.positions.count) }
            let renderer = try MeshRenderer(mesh: mesh, colors: entry.part.colours, registry: registry)
            renderer.ambient = 1
            fallbackRenderers.append(renderer)
        }
    }

    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    private func drawAurora(_ camera: BackwardsAuroraCamera, time: Float, tier: BackwardsAuroraTier,
                            won: Float, tearLight: Float, previewLight: Float) throws {
        guard let auroraRenderer else { return }
        let mvp = camera.viewProjection
        let eye = SIMD3<Float>(Float(camera.eye.x), Float(camera.eye.y), Float(camera.eye.z))
        try auroraRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(BackwardsAuroraShaders.mvpUniform, matrix4: mvp.floats)
            p.set(BackwardsAuroraShaders.lightDirectionUniform, Self.lightDirection)
            p.set(BackwardsAuroraShaders.eyeUniform, eye)
            p.set(BackwardsAuroraShaders.timeUniform, time)
            p.set(BackwardsAuroraShaders.pulsesUniform, Float(tier.pulses))
            p.set(BackwardsAuroraShaders.wonUniform, won)
            p.set(BackwardsAuroraShaders.tearLightUniform, tearLight)
            p.set(BackwardsAuroraShaders.previewLightUniform, previewLight)
        }
    }

    private func drawGlow(_ camera: BackwardsAuroraCamera, gain: Double) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: true) { p in
            p.set(BackwardsAuroraShaders.mvpUniform, matrix4: mvp.floats)
            p.set(BackwardsAuroraShaders.glowUniform, Float(gain))
            p.set(BackwardsAuroraShaders.glowLimitUniform, limit)
        }
    }

    private func drawFallback(_ camera: BackwardsAuroraCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
