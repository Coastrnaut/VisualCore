// BinaryGardensSystemScene — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-001 … 004, 007, 010;
// clarifications Q1–Q4). Draws one `BinaryGardensSceneSnapshot` at one tier through the real GL path: the space clear;
// the system mesh (the backdrop with its starfield, the tilt dial, the star rings, the world orbits, the trails, the
// worlds and stars sorted back to front with their pips, coronas, broken rings and motes, the gauges and the actions
// bars, in the geometry's painter's order) with `BinaryGardensShaders.system*`, premultiplied, with `u_time` (the
// presentation time wrapped by `shaderTime`), `u_motion` (0 under Reduce Motion, so the coronas and motes stand still),
// `u_won` (1 on a won level, making every world bloom) and `u_star1`, `u_star2` (both stars' centres at the shown tick,
// `BinaryGardensSceneGeometry.starUniforms`, the light directions of the two-sun shading); and the tier's glow shells
// (around the stars and the blooming worlds) with the glow program, additive and last (level-0 two shells, level-1 one,
// level-2 none), the gain capped by `u_glowLimit` (the Reduce Flashing cap). The meshes do not depend on the time, so
// they are rebuilt only when what they read changes: the level, the arrangement, the shown tick, the stage, the
// failure, the actions left, the tier, the aspect or the fallback. Depth and blend state as Mushroom Weather's scene
// (feature 493): depth testing off (the window surface carries no depth buffer) and no face culling; the geometry emits
// its triangles in painter's order (by kind, the bodies back to front by eye distance, a cube-sphere's quads
// far-first), and a quad's transparent fringe (its quad spans ±1.25 of its shape, the shader gives the fringe
// coverage 0, premultiplied zero) leaves what is beneath unchanged. If a program fails, the scene falls back to the
// level-2 geometry drawn unlit with the shared `MeshRenderer` (ambient 1, the geometry's fallback colours, the broken
// marks and the won look included) and keeps the reason; nothing here can reach the kernel. A zero-sized drawable is
// cleared and nothing else is drawn. Modelled on `MushroomWeatherForestScene` (feature 493).
#if os(iOS)
import BinaryGardensCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Binary Gardens.
@MainActor
final class BinaryGardensSystemScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The system fragment source (the tests' seam replaces it with a broken one before setup).
    var systemFragment = BinaryGardensShaders.systemFragment
    /// Whether the coronas and motes stand still (Reduce Motion): `u_motion` 0.
    var reducedMotion = false
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// How many times the system mesh was built (tests: it is not rebuilt while nothing it reads changes).
    private(set) var systemBuilds = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds = 0
    /// The `u_time` value of the last frame drawn by the shader path (tests; it still advances under Reduce Motion,
    /// where `u_motion` 0 keeps the coronas and motes still).
    private(set) var lastShaderTime: Double = 0
    /// The `u_star1` and `u_star2` values of the last frame drawn by the shader path (tests).
    private(set) var lastStarUniforms: (SIMD3<Double>, SIMD3<Double>)?

    /// What the meshes depend on: everything of the snapshot that the geometry reads, the tier and the fallback.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let arrangement: BinaryGardensArrangement
        let shownTick: Int
        let stage: BinaryGardensStage
        let failure: BinaryGardensFailure?
        let actionsLeft: Int
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var systemRenderer: ShaderMeshRenderer?
    private var glowRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var geometryKey: GeometryKey?
    private var aspect = 1.0

    /// Records the registry and the view's aspect.
    func setup(_ context: RenderContext) {
        registry = context.resources
        resize(context)
    }

    /// Records the new aspect; the camera follows on the next draw. The meshes face the authored eye, so they are
    /// rebuilt only when the aspect really changed.
    func resize(_ context: RenderContext) {
        let next: Double = Double(max(1, context.pixelWidth)) / Double(max(1, context.pixelHeight))
        if next != aspect { geometryKey = nil }
        aspect = next
    }

    /// Releases every GPU object; the next draw rebuilds them (memory warning, teardown).
    func release() {
        systemRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        systemRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if systemRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { BinaryGardensShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// The motion passed as `u_motion`: 0 under Reduce Motion, else 1.
    var motion: Double { BinaryGardensShaders.motion(reduceMotion: reducedMotion) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer.
    func render(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier, context: RenderContext,
                frame: FrameInfo) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let space = BinaryGardensPalette.space
        let clear = ClearColorScene(red: Float(space.x), green: Float(space.y), blue: Float(space.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = BinaryGardensSceneGeometry.camera(aspect: aspect)
        let next: GeometryKey = key(snapshot, tier: tier)
        if next != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won: Float = snapshot.isWon ? 1 : 0
        let time: Double = BinaryGardensShaders.shaderTime(snapshot.time)
        lastShaderTime = time
        let stars: (SIMD3<Double>, SIMD3<Double>) = BinaryGardensSceneGeometry.starUniforms(snapshot)
        lastStarUniforms = stars
        try drawSystem(camera, time: time, won: won, stars: stars)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        let gain = BinaryGardensShaders.glowGain(for: tier)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won)
    }

    /// The geometry key of `snapshot` at `tier`.
    private func key(_ s: BinaryGardensSceneSnapshot, tier: BinaryGardensTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, arrangement: s.arrangement, shownTick: s.shownTick, stage: s.stage,
                    failure: s.failure, actionsLeft: s.actionsLeft, tier: tier.index, fallback: fallbackReason != nil)
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let system = try BinaryGardensSceneGeometry.systemMesh(snapshot, tier: tier)
                systemRenderer = try Self.renderer(system, vertex: BinaryGardensShaders.systemVertex,
                                                   fragment: systemFragment, name: "binary-gardens-system",
                                                   registry: registry)
                systemBuilds += 1
                let glow = try BinaryGardensSceneGeometry.glowMesh(snapshot, tier: tier)
                glowBuilds += 1
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: BinaryGardensShaders.glowVertex,
                                                     fragment: BinaryGardensShaders.glowFragment,
                                                     name: "binary-gardens-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "binary-gardens shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the broken marks and the won look
        // included; level-2 has no glow, no coronas, no trails and no motes).
        let minimal = BinaryGardensTier.of(BinaryGardensTier.all.count - 1)
        let up = Vec3(0, 0, 1)
        let parts: [BinaryGardensColouredMesh] = [
            try BinaryGardensSceneGeometry.systemPart(snapshot, tier: minimal),
            try BinaryGardensSceneGeometry.glowPart(snapshot, tier: minimal),
        ]
        for part in parts where !part.mesh.indices.isEmpty {
            var mesh = part.mesh
            // The normal slot carries shader data (quad-local coordinates, plane offsets, sphere normals); lighting is
            // off (ambient 1), so every vertex gets a real normal and the fallback reads the colour stream.
            mesh.normals = Array(repeating: up, count: mesh.positions.count)
            let renderer = try MeshRenderer(mesh: mesh, colors: part.colours, registry: registry)
            renderer.ambient = 1
            fallbackRenderers.append(renderer)
        }
        systemBuilds += 1
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// `v` as the `vec3` a uniform takes.
    private static func floats(_ v: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z))
    }

    /// Draws the system mesh: `u_mvp`, `u_time`, `u_motion`, `u_won`, `u_star1` and `u_star2`.
    private func drawSystem(_ camera: BinaryGardensCamera, time: Double, won: Float,
                            stars: (SIMD3<Double>, SIMD3<Double>)) throws {
        guard let systemRenderer else { return }
        let mvp = camera.viewProjection
        let motion = Float(motion)
        let one: SIMD3<Float> = Self.floats(stars.0)
        let two: SIMD3<Float> = Self.floats(stars.1)
        try systemRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: false) { p in
            p.set(BinaryGardensShaders.mvpUniform, matrix4: mvp.floats)
            p.set(BinaryGardensShaders.timeUniform, Float(time))
            p.set(BinaryGardensShaders.motionUniform, motion)
            p.set(BinaryGardensShaders.wonUniform, won)
            p.set(BinaryGardensShaders.starOneUniform, one)
            p.set(BinaryGardensShaders.starTwoUniform, two)
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain`, `u_glowLimit` and `u_won`.
    private func drawGlow(_ camera: BinaryGardensCamera, gain: Double, won: Float) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: false) { p in
            p.set(BinaryGardensShaders.mvpUniform, matrix4: mvp.floats)
            p.set(BinaryGardensShaders.glowGainUniform, Float(gain))
            p.set(BinaryGardensShaders.glowLimitUniform, limit)
            p.set(BinaryGardensShaders.wonUniform, won)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: BinaryGardensCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
