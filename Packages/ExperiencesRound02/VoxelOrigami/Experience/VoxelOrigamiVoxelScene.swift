// VoxelOrigamiVoxelScene — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-001 … 004, 007; clarifications Q1–Q4).
// Draws one `VoxelOrigamiSceneSnapshot` at one tier through the real GL path: the night clear; the voxel mesh (backdrop,
// target wireframes, chamfered cubes with glyphs and dots, hinge bars, failure outlines and gauges, in painter's order)
// with `VoxelOrigamiShaders.voxel*`, premultiplied, `u_won` (`VoxelOrigamiSceneGeometry.wonFlag`) flaring the target of
// a won level; and the tier's glow shells (lit cubes and target cells) with the glow program, additive and last
// (level-0 two shells, level-1 one, level-2 none). Depth testing is off on this path: the geometry emits its triangles
// in painter's order and winds every front face counter-clockwise, and back faces are culled on every draw. Neither
// program has a time input and the geometry never previews a turn, so both meshes are rebuilt only when what they read
// changes: the level, the cells, the chosen hinge, the report, the stage, the failure, the actions left, the tier or the
// mode. If a program fails, the scene falls back to the level-2 geometry drawn unlit with the shared `MeshRenderer`
// (ambient 1, the geometry's fallback colours) and keeps the reason; nothing here can reach the kernel. A zero-sized
// drawable is cleared and nothing else is drawn.
#if os(iOS)
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VoxelOrigamiCore

/// The GL scene of Voxel Origami.
@MainActor
final class VoxelOrigamiVoxelScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The voxel fragment source (the tests' seam replaces it with a broken one before setup).
    var voxelFragment = VoxelOrigamiShaders.voxelFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the chain is drawn still (Reduce Motion).
    var reduceMotion = false
    /// How many times the voxel mesh was built (tests: it is not rebuilt while only the time moves).
    private(set) var voxelBuilds = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds = 0

    /// What the meshes depend on: everything of the snapshot that the geometry reads, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let cells: [VoxelOrigamiVector]
        let turns: [Int]
        let chosenHinge: Int
        let report: VoxelOrigamiShapeReport
        let stage: VoxelOrigamiStage
        let failure: VoxelOrigamiFailure?
        let actionsLeft: Int
        let tier: Int
        let reduceMotion: Bool
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var voxelRenderer: ShaderMeshRenderer?
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
        voxelRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        voxelRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if voxelRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { VoxelOrigamiShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false draws as under Reduce Motion.
    func render(_ snapshot: VoxelOrigamiSceneSnapshot, tier: VoxelOrigamiTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let night = VoxelOrigamiPalette.night
        let clear = ClearColorScene(red: Float(night.x), green: Float(night.y), blue: Float(night.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let still: Bool = reduceMotion || !animate
        let camera = VoxelOrigamiSceneGeometry.camera(snapshot, aspect: aspect)
        if key(snapshot, tier: tier, still: still) != geometryKey { try rebuild(snapshot, tier: tier, still: still) }
        geometryKey = key(snapshot, tier: tier, still: still)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won = Float(VoxelOrigamiSceneGeometry.wonFlag(snapshot))
        try drawVoxels(camera, won: won)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        let gain = VoxelOrigamiShaders.glowGain(for: tier)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won)
    }

    /// The geometry key of `snapshot` at `tier` in the current mode.
    private func key(_ s: VoxelOrigamiSceneSnapshot, tier: VoxelOrigamiTier, still: Bool) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, cells: s.cells, turns: s.turns, chosenHinge: s.chosenHinge,
                    report: s.report, stage: s.stage, failure: s.failure, actionsLeft: s.actionsLeft,
                    tier: tier.index, reduceMotion: still, fallback: fallbackReason != nil)
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: VoxelOrigamiSceneSnapshot, tier: VoxelOrigamiTier, still: Bool) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let voxels = try VoxelOrigamiSceneGeometry.voxelMesh(snapshot, tier: tier, reduceMotion: still)
                voxelRenderer = try Self.renderer(voxels, vertex: VoxelOrigamiShaders.voxelVertex,
                                                  fragment: voxelFragment, name: "voxel-origami-voxels",
                                                  registry: registry)
                voxelBuilds += 1
                let glow = try VoxelOrigamiSceneGeometry.glowMesh(snapshot, tier: tier)
                glowBuilds += 1
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: VoxelOrigamiShaders.glowVertex,
                                                     fragment: VoxelOrigamiShaders.glowFragment,
                                                     name: "voxel-origami-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "voxel-origami shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the broken outlines and the won lift
        // included; level-2 has no glow).
        let minimal = VoxelOrigamiTier.of(VoxelOrigamiTier.all.count - 1)
        let up = Vec3(0, 0, 1)
        let parts: [VoxelOrigamiColouredMesh] = [
            try VoxelOrigamiSceneGeometry.voxelPart(snapshot, tier: minimal, reduceMotion: still),
            try VoxelOrigamiSceneGeometry.glowPart(snapshot, tier: minimal),
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
        voxelBuilds += 1
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the voxel mesh: `u_mvp` and `u_won`.
    private func drawVoxels(_ camera: VoxelOrigamiCamera, won: Float) throws {
        guard let voxelRenderer else { return }
        let mvp = camera.viewProjection
        try voxelRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(VoxelOrigamiShaders.mvpUniform, matrix4: mvp.floats)
            p.set(VoxelOrigamiShaders.wonUniform, won)
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain`, `u_glowLimit` and `u_won`.
    private func drawGlow(_ camera: VoxelOrigamiCamera, gain: Double, won: Float) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: true) { p in
            p.set(VoxelOrigamiShaders.mvpUniform, matrix4: mvp.floats)
            p.set(VoxelOrigamiShaders.glowGainUniform, Float(gain))
            p.set(VoxelOrigamiShaders.glowLimitUniform, limit)
            p.set(VoxelOrigamiShaders.wonUniform, won)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: VoxelOrigamiCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
