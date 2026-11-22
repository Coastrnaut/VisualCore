// NocturneGardenGardenScene — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-001 … 004, 007; clarifications
// Q1–Q4). Draws one `NocturneGardenSceneSnapshot` at one tier through the real GL path: the midnight ground clear; the
// garden (ground plane, the upright mist bed, the kernel's exact shadow cells with their feathered edge, the gold target
// rim, the coral forbidden hatch, the leak crosses after a leak failure, the grown blooms in front of the mist, the
// lantern and the move gauge) with `NocturneGardenShaders.garden*`, opaque and premultiplied, the mist drift and the
// bloom sway following `u_time` (held at 0 under Reduce Motion); and the tier's glow shells over the blooms' heads and
// the lantern with the glow program, additive (level-0 two, level-1 one, level-2 none). Depth testing is off on this
// path, so the order the geometry emits is the layering; back faces are culled on every draw. Geometry is rebuilt only
// when the level, the cells, the blooms, the sun, the stage, the failure, the moves, the tier or the mode change; drift
// and sway move by uniforms. Feature 384 (R02-G09-04): the camera follows the presenter's orbit and the snapshot may
// carry a drag's preview cells, drawn as a pale dashed outline. Reduce Flashing passes `NocturneGardenShaders.glowLimit(reduceFlashing:)` as
// `u_glowLimit`. If a program fails, the scene falls back to the level-2 geometry drawn unlit with the shared
// `MeshRenderer` (ambient 1, per-vertex colours) and keeps the reason; nothing here can reach the kernel.
#if os(iOS)
import Foundation
import NocturneGardenCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Nocturne Garden.
@MainActor
final class NocturneGardenGardenScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The garden fragment source (the tests' seam replaces it with a broken one before setup).
    var gardenFragment = NocturneGardenShaders.gardenFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the mist drift and the sway stand still (Reduce Motion).
    var reduceMotion = false
    /// The camera orbit (presentation only), set by the presenter before each frame (feature 384, R02-G09-04).
    var orbit: NocturneGardenOrbit = .authored
    /// The light direction of the garden (towards the lantern side, from the upper right front).
    static let lightDirection = SIMD3<Float>(0.45, 0.7, 0.55)

    /// What the geometry depends on: everything of the snapshot that the meshes read, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let shadow: [Int]
        let blooms: [NocturneGardenBloom]
        let sun: Int
        let stage: NocturneGardenStage
        let failure: NocturneGardenFailure?
        let moves: Int
        let preview: [Int]
        let orbit: NocturneGardenOrbit
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var gardenRenderer: ShaderMeshRenderer?
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
        gardenRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        gardenRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if gardenRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { NocturneGardenShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the drift and the sway still.
    func render(_ snapshot: NocturneGardenSceneSnapshot, tier: NocturneGardenTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let ground = NocturneGardenPalette.ground
        let clear = ClearColorScene(red: Float(ground.x), green: Float(ground.y), blue: Float(ground.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = NocturneGardenSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        let key = key(snapshot, tier: tier)
        if key != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = self.key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let time = Float(animate && !reduceMotion ? snapshot.time : 0)
        try drawGarden(camera, time: time, layers: NocturneGardenShaders.mistLayers(for: tier))
        let gain = NocturneGardenShaders.glowGain(for: tier)
        guard tier.glowShells > 0, gain > 0 else { return }
        try drawGlow(camera, gain: gain)
    }

    /// The geometry key of `snapshot` at `tier` in the current mode.
    private func key(_ s: NocturneGardenSceneSnapshot, tier: NocturneGardenTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, shadow: s.shadow, blooms: s.blooms, sun: s.sun, stage: s.stage,
                    failure: s.failure, moves: s.moves, preview: s.preview, orbit: orbit, tier: tier.index,
                    fallback: fallbackReason != nil)
    }

    private func rebuild(_ snapshot: NocturneGardenSceneSnapshot, tier: NocturneGardenTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let garden = try NocturneGardenSceneGeometry.gardenMesh(snapshot, tier: tier,
                                                                         reduceMotion: reduceMotion)
                gardenRenderer = try Self.renderer(garden, vertex: NocturneGardenShaders.gardenVertex,
                                                   fragment: gardenFragment, name: "nocturne-garden-garden",
                                                   registry: registry)
                let glow = try NocturneGardenSceneGeometry.glowMesh(snapshot, tier: tier)
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: NocturneGardenShaders.glowVertex,
                                                     fragment: NocturneGardenShaders.glowFragment,
                                                     name: "nocturne-garden-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "nocturne-garden shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its per-vertex colours.
        let minimal = NocturneGardenTier.of(NocturneGardenTier.all.count - 1)
        let up = Vec3(0, 1, 0)
        let parts: [(part: NocturneGardenColouredMesh, colourInNormals: Bool)] = [
            (part: try NocturneGardenSceneGeometry.gardenPart(snapshot, tier: minimal, reduceMotion: reduceMotion),
             colourInNormals: false),
            (part: try NocturneGardenSceneGeometry.glowPart(snapshot, tier: minimal), colourInNormals: true),
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

    private func drawGarden(_ camera: NocturneGardenCamera, time: Float, layers: Double) throws {
        guard let gardenRenderer else { return }
        let mvp = camera.viewProjection
        let eye = SIMD3<Float>(Float(camera.eye.x), Float(camera.eye.y), Float(camera.eye.z))
        try gardenRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(NocturneGardenShaders.mvpUniform, matrix4: mvp.floats)
            p.set(NocturneGardenShaders.lightDirectionUniform, Self.lightDirection)
            p.set(NocturneGardenShaders.eyeUniform, eye)
            p.set(NocturneGardenShaders.timeUniform, time)
            p.set(NocturneGardenShaders.mistLayersUniform, Float(layers))
        }
    }

    private func drawGlow(_ camera: NocturneGardenCamera, gain: Double) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: true) { p in
            p.set(NocturneGardenShaders.mvpUniform, matrix4: mvp.floats)
            p.set(NocturneGardenShaders.glowUniform, Float(gain))
            p.set(NocturneGardenShaders.glowLimitUniform, limit)
        }
    }

    private func drawFallback(_ camera: NocturneGardenCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
