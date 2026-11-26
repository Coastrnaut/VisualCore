// MicroscopicAuroraDishScene — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-001 … 004, 007; clarifications
// Q1–Q4). Draws one `MicroscopicAuroraSceneSnapshot` at one tier through the real GL path: the abyss clear; the dish
// mesh (the backdrop, the field, the fronds, the rim, the stencil outlines, the lit and stray cells, the site rings, the
// well spirals, the ribbons, the swimmers, the gauges and the actions bars, in painter's order) with
// `MicroscopicAuroraShaders.dish*`, premultiplied, with `u_won` (1 on a won level) brightening the ribbons and lighting
// every stencil cell; and the tier's glow shells (the swimmers and ribbons) with the glow program, additive and last
// (level-0 two shells, level-1 one, level-2 none), the gain capped by `u_glowLimit` (the Reduce Flashing cap). Nothing
// moves by time, so the meshes are rebuilt only when what they read changes: the level, the wells, the shown tick, the
// stage, the failure, the actions left, the tier or the fallback. Depth testing is off on this path: the geometry emits
// its triangles in painter's order. If a program fails, the scene falls back to the level-2 geometry drawn unlit with
// the shared `MeshRenderer` (ambient 1, the geometry's fallback colours, the won look included) and keeps the reason;
// nothing here can reach the kernel. A zero-sized drawable is cleared and nothing else is drawn.
#if os(iOS)
import MicroscopicAuroraCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Microscopic Aurora.
@MainActor
final class MicroscopicAuroraDishScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The dish fragment source (the tests' seam replaces it with a broken one before setup).
    var dishFragment = MicroscopicAuroraShaders.dishFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// How many times the dish mesh was built (tests: it is not rebuilt while nothing it reads changes).
    private(set) var dishBuilds = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds = 0

    /// What the meshes depend on: everything of the snapshot that the geometry reads, the tier and the fallback.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let wells: [MicroscopicAuroraWell?]
        let shownTick: Int
        let stage: MicroscopicAuroraStage
        let failure: MicroscopicAuroraFailure?
        let actionsLeft: Int
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var dishRenderer: ShaderMeshRenderer?
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
        dishRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        dishRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if dishRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { MicroscopicAuroraShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer.
    func render(_ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier, context: RenderContext,
                frame: FrameInfo) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let abyss = MicroscopicAuroraPalette.abyss
        let clear = ClearColorScene(red: Float(abyss.x), green: Float(abyss.y), blue: Float(abyss.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = MicroscopicAuroraSceneGeometry.camera(aspect: aspect)
        let next: GeometryKey = key(snapshot, tier: tier)
        if next != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won: Float = snapshot.isWon ? 1 : 0
        try drawDish(camera, won: won)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        let gain = MicroscopicAuroraShaders.glowGain(for: tier)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won)
    }

    /// The geometry key of `snapshot` at `tier`.
    private func key(_ s: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, wells: s.wells, shownTick: s.shownTick, stage: s.stage,
                    failure: s.failure, actionsLeft: s.actionsLeft, tier: tier.index, fallback: fallbackReason != nil)
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let dish = try MicroscopicAuroraSceneGeometry.dishMesh(snapshot, tier: tier)
                dishRenderer = try Self.renderer(dish, vertex: MicroscopicAuroraShaders.dishVertex,
                                                 fragment: dishFragment, name: "microscopic-aurora-dish",
                                                 registry: registry)
                dishBuilds += 1
                let glow = try MicroscopicAuroraSceneGeometry.glowMesh(snapshot, tier: tier)
                glowBuilds += 1
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: MicroscopicAuroraShaders.glowVertex,
                                                     fragment: MicroscopicAuroraShaders.glowFragment,
                                                     name: "microscopic-aurora-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "microscopic-aurora shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the failure marks and the won marks
        // included; level-2 has no glow).
        let minimal = MicroscopicAuroraTier.of(MicroscopicAuroraTier.all.count - 1)
        let up = Vec3(0, 0, 1)
        let parts: [MicroscopicAuroraColouredMesh] = [
            try MicroscopicAuroraSceneGeometry.dishPart(snapshot, tier: minimal),
            try MicroscopicAuroraSceneGeometry.glowPart(snapshot, tier: minimal),
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
        dishBuilds += 1
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the dish mesh: `u_mvp` and `u_won`.
    private func drawDish(_ camera: MicroscopicAuroraCamera, won: Float) throws {
        guard let dishRenderer else { return }
        let mvp = camera.viewProjection
        try dishRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: false) { p in
            p.set(MicroscopicAuroraShaders.mvpUniform, matrix4: mvp.floats)
            p.set(MicroscopicAuroraShaders.wonUniform, won)
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain`, `u_glowLimit` and `u_won`.
    private func drawGlow(_ camera: MicroscopicAuroraCamera, gain: Double, won: Float) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: false) { p in
            p.set(MicroscopicAuroraShaders.mvpUniform, matrix4: mvp.floats)
            p.set(MicroscopicAuroraShaders.glowGainUniform, Float(gain))
            p.set(MicroscopicAuroraShaders.glowLimitUniform, limit)
            p.set(MicroscopicAuroraShaders.wonUniform, won)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: MicroscopicAuroraCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
