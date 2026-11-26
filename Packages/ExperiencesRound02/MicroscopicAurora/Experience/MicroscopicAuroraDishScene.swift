// MicroscopicAuroraDishScene — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-001 … 004, 007; clarifications
// Q1–Q4). Draws one `MicroscopicAuroraSceneSnapshot` at one tier through the real GL path: the abyss clear; the dish
// mesh (the backdrop, the field, the fronds, the rim, the stencil outlines, the lit and stray cells, the site rings, the
// well spirals, the ribbons, the swimmers, the gauges and the actions bars, in painter's order) with
// `MicroscopicAuroraShaders.dish*`, premultiplied, with `u_won` (1 on a won level) brightening the ribbons and lighting
// every stencil cell; and the tier's glow shells (the swimmers and ribbons) with the glow program, additive and last
// (level-0 two shells, level-1 one, level-2 none), the gain capped by `u_glowLimit` (the Reduce Flashing cap). Nothing
// moves by time, so the meshes are rebuilt only when what they read changes: the level, the wells, the shown tick, the
// stage, the failure, the actions left, the tier, the fallback or (feature 484, R02-G19-04 T-R02G1904-005) the camera's
// orbit, the aspect, the drawn preview or the freeze; the meshes face the camera of the presenter's orbit. Depth testing is off on this path: the geometry emits
// its triangles in painter's order. If a program fails, the scene falls back to the level-2 geometry drawn unlit with
// the shared `MeshRenderer` (ambient 1, the geometry's fallback colours, the won look included) and keeps the reason;
// nothing here can reach the kernel. A zero-sized drawable is cleared and nothing else is drawn.
//
// Feature 486 (R02-G19-06) T-R02G1906-005 (FR-R02G1906-004; clarification Q3): the presenter's eased lights
// (`MicroscopicAuroraLights`) are drawn: the glow gain is multiplied by the glow level and `u_won` is the won level.
// Nothing in the dish moves by time, so under Reduce Motion or Reduce Flashing the dish is still between actions. The
// unlit fallback's geometry takes a won flag, not a level, so the fallback dish blends the colours of the not-won and
// the won dish part by the won level (`blendedColours(off:on:level:)`; the two parts share their positions, the won
// look changes colours only) and is rebuilt when that level moves by a tenth or more. Without lights the snapshot's
// levels are drawn at once.
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
        /// The camera's orbit (feature 484; the meshes face the drawn camera).
        let orbit: MicroscopicAuroraViewOrbit
        /// The aspect the meshes were built for.
        let aspect: Double
        /// The drawn preview (feature 484; presentation only).
        let preview: MicroscopicAuroraPreview?
        /// Whether the freeze is on (feature 484; presentation only).
        let frozen: Bool
        /// The won level in tenths, in the fallback only (feature 486): the fallback's colours depend on it.
        let wonTenths: Int
    }

    private var registry: ResourceRegistry?
    private var dishRenderer: ShaderMeshRenderer?
    private var glowRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var geometryKey: GeometryKey?
    private var aspect = 1.0
    /// The camera's orbit (feature 484; presentation only, the presenter's gesture controller's). A changed orbit
    /// rebuilds the meshes on the next draw.
    var orbit: MicroscopicAuroraViewOrbit = .authored
    /// The eased light levels the presenter steps every frame (feature 486): the glow gain is multiplied by
    /// `lights.glow`, `u_won` is `lights.won`, and the fallback dish's won colours are blended by `lights.won`
    /// (rebuilt when it moves by a tenth or more). Nil draws the snapshot's levels at once (the renderer tests'
    /// default).
    var lights: MicroscopicAuroraLights?

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
        let camera = MicroscopicAuroraSceneGeometry.camera(aspect: aspect, orbit: orbit)
        let next: GeometryKey = key(snapshot, tier: tier)
        if next != geometryKey { try rebuild(snapshot, tier: tier, camera: camera) }
        geometryKey = key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won = Float(wonLevel(snapshot))
        try drawDish(camera, won: won)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        // Feature 486 eases the glow gain by the glow level.
        let gain = MicroscopicAuroraShaders.glowGain(for: tier) * (lights?.glow ?? 1)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won)
    }

    /// The geometry key of `snapshot` at `tier`.
    private func key(_ s: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, wells: s.wells, shownTick: s.shownTick, stage: s.stage,
                    failure: s.failure, actionsLeft: s.actionsLeft, tier: tier.index, fallback: fallbackReason != nil,
                    orbit: orbit, aspect: aspect, preview: s.preview, frozen: s.frozen,
                    wonTenths: fallbackReason != nil ? Int((wonLevel(s) * 10).rounded(.down)) : 0)
    }

    /// The won level drawn (feature 486): the eased `lights.won`, or 1 on a won snapshot and 0 otherwise without
    /// lights.
    private func wonLevel(_ snapshot: MicroscopicAuroraSceneSnapshot) -> Double {
        lights?.won ?? (snapshot.isWon ? 1 : 0)
    }

    /// The colours of the fallback dish at won level `level` (feature 486): each colour of `off` (the not-won part)
    /// moved toward the same vertex's colour of `on` (the won part) by `level`, clamped to 0 … 1 (a non-finite level
    /// reads 0). Parts of different sizes cannot be blended vertex by vertex: then `on`'s colours from a level of 0.5
    /// up, `off`'s below. Pure.
    static func blendedColours(off: [Vec4], on: [Vec4], level: Double) -> [Vec4] {
        let t: Double = level.isFinite ? min(max(level, 0), 1) : 0
        guard off.count == on.count else { return t >= 0.5 ? on : off }
        return zip(off, on).map { a, b in a + (b - a) * t }
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier` facing `camera`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier,
                         camera: MicroscopicAuroraCamera) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let dish = try MicroscopicAuroraSceneGeometry.dishMesh(snapshot, tier: tier, camera: camera)
                dishRenderer = try Self.renderer(dish, vertex: MicroscopicAuroraShaders.dishVertex,
                                                 fragment: dishFragment, name: "microscopic-aurora-dish",
                                                 registry: registry)
                dishBuilds += 1
                let glow = try MicroscopicAuroraSceneGeometry.glowMesh(snapshot, tier: tier, camera: camera)
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
        // Feature 486: the dish's won colours blended by the won level (the won look changes colours, not positions).
        let off = try MicroscopicAuroraSceneGeometry.dishPart(snapshot, tier: minimal, wonLevel: false, camera: camera)
        let on = try MicroscopicAuroraSceneGeometry.dishPart(snapshot, tier: minimal, wonLevel: true, camera: camera)
        let level: Double = wonLevel(snapshot)
        // Parts of different sizes switch whole at a level of 0.5 (see `blendedColours(off:on:level:)`).
        let dishMesh: Mesh = off.colours.count == on.colours.count || level < 0.5 ? off.mesh : on.mesh
        let glow = try MicroscopicAuroraSceneGeometry.glowPart(snapshot, tier: minimal, camera: camera)
        let parts: [(mesh: Mesh, colours: [Vec4])] = [
            (dishMesh, Self.blendedColours(off: off.colours, on: on.colours, level: level)),
            (glow.mesh, glow.colours),
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
