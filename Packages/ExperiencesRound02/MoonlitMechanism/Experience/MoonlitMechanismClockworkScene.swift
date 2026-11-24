// MoonlitMechanismClockworkScene — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-001 … 004, 007;
// clarifications Q1–Q4). Draws one `MoonlitMechanismSceneSnapshot` at one tier through the real GL path: the night
// clear; the clockwork mesh (backdrop, paper wall, feathers, ink shadows, target outline, missing and stray cells,
// forbidden marks, gauges, gears back to front, ladder and lamp, in painter's order) with
// `MoonlitMechanismShaders.clockwork*`, premultiplied, `u_won` (`MoonlitMechanismSceneGeometry.wonFlag`) brightening
// the paper of a won level; and the tier's glow shells (lamp, lit key-frame cards and, on a won level, the wall) with the
// glow program, additive and last (level-0 two shells, level-1 one, level-2 none). Depth testing is off on this path:
// the geometry emits its triangles in painter's order, and back faces are culled on every draw. Neither program has a
// time input and the geometry never previews a turn, so both meshes are rebuilt only when what they read changes: the
// level, the drawn phases, the lamp, the shown key frame, the run report, the stage, the failure, the actions left, the
// tier or the mode. A failure's jammed teeth, forbidden cell or failing card are outlined by the geometry (it reads the
// snapshot's failure). Reduce Motion draws the gears at the set-up phases of the shown key frame; Reduce Flashing
// passes `MoonlitMechanismShaders.glowLimit(reduceFlashing:)` as `u_glowLimit`. If a program fails, the scene falls
// back to the level-2 geometry drawn unlit with the shared `MeshRenderer` (ambient 1, the geometry's fallback colours)
// and keeps the reason; nothing here can reach the kernel. A zero-sized drawable is cleared and nothing else is drawn.
#if os(iOS)
import Foundation
import MoonlitMechanismCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Moonlit Mechanism.
@MainActor
final class MoonlitMechanismClockworkScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The clockwork fragment source (the tests' seam replaces it with a broken one before setup).
    var clockworkFragment = MoonlitMechanismShaders.clockworkFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the gears are drawn at the shown key frame's set-up phases without a turning preview (Reduce Motion).
    var reduceMotion = false
    /// How many times the clockwork mesh was built (tests: it is not rebuilt while only the time moves).
    private(set) var clockworkBuilds = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds = 0

    /// What the meshes depend on: everything of the snapshot that the geometry reads, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let phases: [Int]
        let height: Int
        let shownFrame: Int
        let report: MoonlitMechanismRunReport
        let stage: MoonlitMechanismStage
        let failure: MoonlitMechanismFailure?
        let actionsLeft: Int
        let tier: Int
        let reduceMotion: Bool
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var clockworkRenderer: ShaderMeshRenderer?
    private var glowRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var geometryKey: GeometryKey?
    private var aspect = 1.0

    /// Records the registry and the view's aspect.
    func setup(_ context: RenderContext) {
        registry = context.resources
        resize(context)
    }

    /// Records the new aspect; the camera follows on the next draw. The meshes do not depend on the aspect (only the
    /// camera does), so they are rebuilt only when the aspect really changed (the offscreen host resizes before every
    /// still).
    func resize(_ context: RenderContext) {
        let next: Double = Double(max(1, context.pixelWidth)) / Double(max(1, context.pixelHeight))
        if next != aspect { geometryKey = nil }
        aspect = next
    }

    /// Releases every GPU object; the next draw rebuilds them (memory warning, teardown).
    func release() {
        clockworkRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        clockworkRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if clockworkRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { MoonlitMechanismShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false draws as under Reduce Motion.
    func render(_ snapshot: MoonlitMechanismSceneSnapshot, tier: MoonlitMechanismTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let night = MoonlitMechanismPalette.night
        let clear = ClearColorScene(red: Float(night.x), green: Float(night.y), blue: Float(night.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let still: Bool = reduceMotion || !animate
        let camera = MoonlitMechanismSceneGeometry.camera(snapshot, aspect: aspect)
        if key(snapshot, tier: tier, still: still) != geometryKey { try rebuild(snapshot, tier: tier, still: still) }
        geometryKey = key(snapshot, tier: tier, still: still)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won = Float(MoonlitMechanismSceneGeometry.wonFlag(snapshot))
        try drawClockwork(camera, won: won)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        let gain = MoonlitMechanismShaders.glowGain(for: tier)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won)
    }

    /// The geometry key of `snapshot` at `tier` in the current mode.
    private func key(_ s: MoonlitMechanismSceneSnapshot, tier: MoonlitMechanismTier, still: Bool) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, phases: s.phases, height: s.height, shownFrame: s.shownFrame,
                    report: s.report, stage: s.stage, failure: s.failure, actionsLeft: s.actionsLeft,
                    tier: tier.index, reduceMotion: still, fallback: fallbackReason != nil)
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: MoonlitMechanismSceneSnapshot, tier: MoonlitMechanismTier,
                         still: Bool) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let clockwork = try MoonlitMechanismSceneGeometry.clockworkMesh(snapshot, tier: tier,
                                                                               reduceMotion: still)
                clockworkRenderer = try Self.renderer(clockwork, vertex: MoonlitMechanismShaders.clockworkVertex,
                                                      fragment: clockworkFragment,
                                                      name: "moonlit-mechanism-clockwork", registry: registry)
                clockworkBuilds += 1
                let glow = try MoonlitMechanismSceneGeometry.glowMesh(snapshot, tier: tier)
                glowBuilds += 1
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: MoonlitMechanismShaders.glowVertex,
                                                     fragment: MoonlitMechanismShaders.glowFragment,
                                                     name: "moonlit-mechanism-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "moonlit-mechanism shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the broken outlines and the won paper
        // included; level-2 has no glow).
        let minimal = MoonlitMechanismTier.of(MoonlitMechanismTier.all.count - 1)
        let up = Vec3(0, 0, 1)
        let parts: [MoonlitMechanismColouredMesh] = [
            try MoonlitMechanismSceneGeometry.clockworkPart(snapshot, tier: minimal, reduceMotion: still),
            try MoonlitMechanismSceneGeometry.glowPart(snapshot, tier: minimal),
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
        clockworkBuilds += 1
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the clockwork mesh: `u_mvp` and `u_won`.
    private func drawClockwork(_ camera: MoonlitMechanismCamera, won: Float) throws {
        guard let clockworkRenderer else { return }
        let mvp = camera.viewProjection
        try clockworkRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(MoonlitMechanismShaders.mvpUniform, matrix4: mvp.floats)
            p.set(MoonlitMechanismShaders.wonUniform, won)
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain`, `u_glowLimit` and `u_won`.
    private func drawGlow(_ camera: MoonlitMechanismCamera, gain: Double, won: Float) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: true) { p in
            p.set(MoonlitMechanismShaders.mvpUniform, matrix4: mvp.floats)
            p.set(MoonlitMechanismShaders.glowGainUniform, Float(gain))
            p.set(MoonlitMechanismShaders.glowLimitUniform, limit)
            p.set(MoonlitMechanismShaders.wonUniform, won)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: MoonlitMechanismCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
