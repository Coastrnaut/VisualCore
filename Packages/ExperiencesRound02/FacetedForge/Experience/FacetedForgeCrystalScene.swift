// FacetedForgeCrystalScene — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-001 … 004, 007; clarifications
// Q1–Q4). Draws one `FacetedForgeSceneSnapshot` at one tier through the real GL path: the ground clear; the crystal
// (ground plane, the bevelled pieces opened about the crystal's centre and emitted back to front, the ruby preview
// plane with its dashed rim, the sliver cross and the cut mark) with `FacetedForgeShaders.crystal*`, premultiplied
// alpha so the ice glass and the preview are translucent while every other material is opaque, the dispersion shimmer
// following `u_time` (held at 0 under Reduce Motion); and the tier's glow shells over the cut faces with the glow
// program, additive (level-0 two, level-1 one, level-2 none). Depth testing is off on this path, so the order is the
// layering; back faces are culled on every draw. Geometry is rebuilt only when the level, the pieces (cuts), the
// preview choice, the stage, the failure, the opening while it eases, the tier or the mode change; the shimmer moves by
// a uniform. Reduce Motion shows the opening at full distance without easing. Reduce Flashing passes
// `FacetedForgeShaders.glowLimit(reduceFlashing:)` as `u_glowLimit`. If a program fails, the scene falls back to the
// level-2 geometry drawn unlit with the shared `MeshRenderer` (ambient 1, per-vertex colours) and keeps the reason;
// nothing here can reach the kernel.
// Feature 374 (R02-G08-04): the camera follows the presenter's orbit (`camera(_:aspect:orbit:)`) and the pieces are
// emitted back to front for that orbit's eye; the snapshot drawn may carry a gesture's candidate preview choice.
#if os(iOS)
import FacetedForgeCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Faceted Forge.
@MainActor
final class FacetedForgeCrystalScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The crystal fragment source (the tests' seam replaces it with a broken one before setup).
    var crystalFragment = FacetedForgeShaders.crystalFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the opening is shown at full distance without easing (Reduce Motion).
    var reduceMotion = false
    /// The camera orbit (presentation only), set by the presenter before each frame (feature 374).
    var orbit: FacetedForgeOrbit = .authored
    /// The light direction of the crystal (towards the light, from the upper left front).
    static let lightDirection = SIMD3<Float>(-0.35, 0.8, 0.5)

    /// What the geometry depends on: everything of the snapshot that the meshes read, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let cuts: Int
        let corners: [[SIMD3<Double>]]
        let choice: FacetedForgePreviewChoice
        let stage: FacetedForgeStage
        let failure: FacetedForgeFailure?
        let opening: Double
        let orbit: FacetedForgeOrbit
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var crystalRenderer: ShaderMeshRenderer?
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
        crystalRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        crystalRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { FacetedForgeShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the shimmer still.
    func render(_ snapshot: FacetedForgeSceneSnapshot, tier: FacetedForgeTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let ground = FacetedForgePalette.ground
        let clear = ClearColorScene(red: Float(ground.x), green: Float(ground.y), blue: Float(ground.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = FacetedForgeSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        let key = key(snapshot, tier: tier)
        if key != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = self.key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let time = Float(animate ? snapshot.time : 0)
        try drawCrystal(camera, time: time, layers: FacetedForgeShaders.dispersionLayers(for: tier))
        let gain = FacetedForgeShaders.glowGain(for: tier)
        guard tier.glowShells > 0, gain > 0 else { return }
        try drawGlow(camera, gain: gain)
    }

    /// The geometry key of `snapshot` at `tier` in the current mode.
    private func key(_ s: FacetedForgeSceneSnapshot, tier: FacetedForgeTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, cuts: s.cuts, corners: s.pieces.map(\.corners), choice: s.choice,
                    stage: s.stage, failure: s.failure,
                    opening: FacetedForgeSceneGeometry.opening(s, reduceMotion: reduceMotion), orbit: orbit,
                    tier: tier.index,
                    fallback: fallbackReason != nil)
    }

    private func rebuild(_ snapshot: FacetedForgeSceneSnapshot, tier: FacetedForgeTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let crystal = try FacetedForgeSceneGeometry.crystalMesh(snapshot, tier: tier,
                                                                       reduceMotion: reduceMotion, orbit: orbit)
                crystalRenderer = try Self.renderer(crystal, vertex: FacetedForgeShaders.crystalVertex,
                                                    fragment: crystalFragment, name: "faceted-forge-crystal",
                                                    registry: registry)
                let glow = try FacetedForgeSceneGeometry.glowMesh(snapshot, tier: tier, reduceMotion: reduceMotion,
                                                                  orbit: orbit)
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: FacetedForgeShaders.glowVertex,
                                                     fragment: FacetedForgeShaders.glowFragment,
                                                     name: "faceted-forge-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "faceted-forge shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its per-vertex colours.
        let minimal = FacetedForgeTier.of(FacetedForgeTier.all.count - 1)
        let up = Vec3(0, 1, 0)
        let parts: [(part: FacetedForgeColouredMesh, colourInNormals: Bool)] = [
            (part: try FacetedForgeSceneGeometry.crystalPart(snapshot, tier: minimal, reduceMotion: reduceMotion,
                                                             orbit: orbit), colourInNormals: false),
            (part: try FacetedForgeSceneGeometry.glowPart(snapshot, tier: minimal, reduceMotion: reduceMotion,
                                                          orbit: orbit), colourInNormals: true),
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

    private func drawCrystal(_ camera: FacetedForgeCamera, time: Float, layers: Double) throws {
        guard let crystalRenderer else { return }
        let mvp = camera.viewProjection
        let eye = SIMD3<Float>(Float(camera.eye.x), Float(camera.eye.y), Float(camera.eye.z))
        try crystalRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(FacetedForgeShaders.mvpUniform, matrix4: mvp.floats)
            p.set(FacetedForgeShaders.lightDirectionUniform, Self.lightDirection)
            p.set(FacetedForgeShaders.eyeUniform, eye)
            p.set(FacetedForgeShaders.timeUniform, time)
            p.set(FacetedForgeShaders.layersUniform, Float(layers))
        }
    }

    private func drawGlow(_ camera: FacetedForgeCamera, gain: Double) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: true) { p in
            p.set(FacetedForgeShaders.mvpUniform, matrix4: mvp.floats)
            p.set(FacetedForgeShaders.glowUniform, Float(gain))
            p.set(FacetedForgeShaders.glowLimitUniform, limit)
        }
    }

    private func drawFallback(_ camera: FacetedForgeCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
