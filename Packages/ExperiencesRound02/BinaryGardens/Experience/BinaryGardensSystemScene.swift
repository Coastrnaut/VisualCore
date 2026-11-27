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
// Feature 504 (R02-G21-04) T-R02G2104-005 (FR-R02G2104-008, 010, 015): the meshes face the camera of the presenter's
// orbit (`BinaryGardensSceneGeometry.camera(aspect:orbit:)` and the camera-taking mesh builders) and draw the
// snapshot's preview (the ghost star, the previewed light with the committed cells as ghost bands) and inspection (the
// ring round the inspected world, the bracket by its gauge row); the geometry key also holds the orbit, the aspect, the
// preview and the inspected world, so the meshes are rebuilt when any of them changes. The two-sun light directions are
// the drawn snapshot's stars (`BinaryGardensSceneGeometry.drawnSnapshot`: a previewed luminosity or tilt moves them).
// Feature 506 (R02-G21-06) T-R02G2106-005 (FR-R02G2106-004, 007; clarifications Q3, Q6; research R3 … R5): the
// presenter's eased lights (`BinaryGardensLights`) are drawn: the glow gain is multiplied by the glow level, `u_won` is
// the won level, and each world's glow shell factor is its bloom level (vertex data of the glow mesh, built by
// `BinaryGardensSceneGeometry.glowMesh(_:tier:camera:bloom:)`; only the glow mesh is rebuilt, when a bloom level crosses
// a 1/32 step). `u_motion` is 0 under Reduce Motion or Reduce Flashing, so the coronas and motes hold their time-zero
// places and the system is still between actions. The unlit fallback's geometry takes a won flag, not a level, so the
// fallback system blends the colours of the not-won and the won system part by the won level
// (`blendedColours(off:on:level:)`; the two parts share their positions, the won look changes colours only) and is
// rebuilt when that level moves by a tenth or more. Without lights the snapshot's levels are drawn at once. A tier
// change or a memory warning resets none of the presenter's levels. Modelled on `MushroomWeatherForestScene`
// (feature 496).
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
    /// Whether the glow gain is capped (Reduce Flashing); since feature 506 the coronas and motes stand still too.
    var reducedFlash = false
    /// How many times the system mesh was built (tests: it is not rebuilt while nothing it reads changes).
    private(set) var systemBuilds = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds = 0
    /// The `u_time` value of the last frame drawn by the shader path (tests; it still advances under Reduce Motion or
    /// Reduce Flashing, where `u_motion` 0 holds the coronas and motes at their time-zero places).
    private(set) var lastShaderTime: Double = 0
    /// The `u_star1` and `u_star2` values of the last frame drawn by the shader path (tests).
    private(set) var lastStarUniforms: (SIMD3<Double>, SIMD3<Double>)?
    /// The camera's orbit (feature 504; presentation only, the presenter's gesture controller's). A changed orbit
    /// rebuilds the meshes on the next draw.
    var orbit: BinaryGardensViewOrbit = .authored
    /// The eased light levels the presenter steps every frame (feature 506): the glow gain is multiplied by
    /// `lights.glow`, `u_won` is `lights.won`, each world's glow shell factor is `lights.bloom` (the glow mesh rebuilt
    /// when a level crosses a 1/32 step) and the fallback system's won colours are blended by `lights.won` (rebuilt
    /// when it moves by a tenth or more). Nil draws the snapshot's levels at once (the renderer tests' default).
    var lights: BinaryGardensLights?
    /// The steps of 1/32 of each world's bloom level the glow mesh was last built with (feature 506); nil without
    /// lights.
    private var glowBloomSteps: [Int]?
    /// The steps of a bloom level (feature 506).
    static let bloomStepsPerUnit: Double = 32

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
        /// The camera's orbit (feature 504; the meshes face the drawn camera).
        let orbit: BinaryGardensViewOrbit
        /// The aspect the meshes were built for (feature 504).
        let aspect: Double
        /// The drawn preview (feature 504; presentation only).
        let preview: BinaryGardensPreview?
        /// The inspected world (feature 504; presentation only).
        let inspectedWorld: Int?
        /// The won level in tenths, in the fallback only (feature 506): the fallback's colours depend on it.
        let wonTenths: Int
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

    /// Records the new aspect; the camera follows on the next draw. The meshes face the drawn camera, so they are
    /// rebuilt only when the aspect (or, at the next draw, the orbit) really changed.
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
        glowBloomSteps = nil
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

    /// The motion passed as `u_motion`: 0 under Reduce Motion or (feature 506) Reduce Flashing, else 1.
    var motion: Double { BinaryGardensShaders.motion(reduceMotion: reducedMotion || reducedFlash) }

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
        let camera = BinaryGardensSceneGeometry.camera(aspect: aspect, orbit: orbit)
        let next: GeometryKey = key(snapshot, tier: tier)
        if next != geometryKey {
            try rebuild(snapshot, tier: tier, camera: camera)
        } else if fallbackReason == nil, bloomSteps() != glowBloomSteps {
            try rebuildGlow(snapshot, tier: tier, camera: camera)
        }
        geometryKey = key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won = Float(wonLevel(snapshot))
        let time: Double = BinaryGardensShaders.shaderTime(snapshot.time)
        lastShaderTime = time
        let stars: (SIMD3<Double>, SIMD3<Double>) =
            BinaryGardensSceneGeometry.starUniforms(BinaryGardensSceneGeometry.drawnSnapshot(snapshot))
        lastStarUniforms = stars
        try drawSystem(camera, time: time, won: won, stars: stars)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty. Feature 506 eases the
        // glow gain by the glow level.
        let gain = BinaryGardensShaders.glowGain(for: tier) * (lights?.glow ?? 1)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won)
    }

    /// The geometry key of `snapshot` at `tier`.
    private func key(_ s: BinaryGardensSceneSnapshot, tier: BinaryGardensTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, arrangement: s.arrangement, shownTick: s.shownTick, stage: s.stage,
                    failure: s.failure, actionsLeft: s.actionsLeft, tier: tier.index, fallback: fallbackReason != nil,
                    orbit: orbit, aspect: aspect, preview: s.preview, inspectedWorld: s.inspectedWorld,
                    wonTenths: fallbackReason != nil ? Int((wonLevel(s) * 10).rounded(.down)) : 0)
    }

    /// The won level drawn (feature 506): the eased `lights.won`, or 1 on a won snapshot and 0 otherwise without
    /// lights.
    private func wonLevel(_ snapshot: BinaryGardensSceneSnapshot) -> Double {
        lights?.won ?? (snapshot.isWon ? 1 : 0)
    }

    /// The 1/32 steps of each world's eased bloom level (feature 506; a non-finite level reads 0); nil without lights.
    private func bloomSteps() -> [Int]? {
        guard let bloom = lights?.bloom else { return nil }
        var steps: [Int] = []
        steps.reserveCapacity(bloom.count)
        for level in bloom {
            let clamped: Double = level.isFinite ? min(max(level, 0), 1) : 0
            steps.append(Int((clamped * Self.bloomStepsPerUnit).rounded(.down)))
        }
        return steps
    }

    /// The colours of the fallback system at won level `level` (feature 506): each colour of `off` (the not-won part)
    /// moved toward the same vertex's colour of `on` (the won part) by `level`, clamped to 0 … 1 (a non-finite level
    /// reads 0). Parts of different sizes cannot be blended vertex by vertex: then `on`'s colours from a level of 0.5
    /// up, `off`'s below. Pure.
    static func blendedColours(off: [Vec4], on: [Vec4], level: Double) -> [Vec4] {
        let t: Double = level.isFinite ? min(max(level, 0), 1) : 0
        guard off.count == on.count else { return t >= 0.5 ? on : off }
        return zip(off, on).map { a, b in a + (b - a) * t }
    }

    /// Rebuilds only the glow mesh for the current bloom levels (feature 506: a bloom level crossed a 1/32 step while
    /// nothing else the meshes read changed). A failing glow program falls back like ``rebuild(_:tier:camera:)``.
    private func rebuildGlow(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                             camera: BinaryGardensCamera) throws {
        guard let registry else { return }
        glowRenderer?.release()
        glowRenderer = nil
        glowBloomSteps = bloomSteps()
        do {
            let glow = try BinaryGardensSceneGeometry.glowMesh(snapshot, tier: tier, camera: camera,
                                                               bloom: lights?.bloom)
            glowBuilds += 1
            if !glow.indices.isEmpty {
                glowRenderer = try Self.renderer(glow, vertex: BinaryGardensShaders.glowVertex,
                                                 fragment: BinaryGardensShaders.glowFragment,
                                                 name: "binary-gardens-glow", registry: registry)
            }
        } catch {
            release()
            fallbackReason = "binary-gardens shader: \(error)"
            try rebuild(snapshot, tier: tier, camera: camera)
        }
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier` facing `camera`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                         camera: BinaryGardensCamera) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let system = try BinaryGardensSceneGeometry.systemMesh(snapshot, tier: tier, camera: camera)
                systemRenderer = try Self.renderer(system, vertex: BinaryGardensShaders.systemVertex,
                                                   fragment: systemFragment, name: "binary-gardens-system",
                                                   registry: registry)
                systemBuilds += 1
                // Feature 506: each world's shell factor is its eased bloom level (nil lights: today's 0/1 factors).
                glowBloomSteps = bloomSteps()
                let glow = try BinaryGardensSceneGeometry.glowMesh(snapshot, tier: tier, camera: camera,
                                                                   bloom: lights?.bloom)
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
        // Feature 506: the system's won colours blended by the won level (the won look changes colours, not
        // positions).
        let off = try BinaryGardensSceneGeometry.systemPart(snapshot, tier: minimal, wonLevel: false, camera: camera)
        let on = try BinaryGardensSceneGeometry.systemPart(snapshot, tier: minimal, wonLevel: true, camera: camera)
        let level: Double = wonLevel(snapshot)
        // Parts of different sizes switch whole at a level of 0.5 (see `blendedColours(off:on:level:)`).
        let systemMesh: Mesh = off.colours.count == on.colours.count || level < 0.5 ? off.mesh : on.mesh
        let glow = try BinaryGardensSceneGeometry.glowPart(snapshot, tier: minimal, camera: camera)
        let parts: [(mesh: Mesh, colours: [Vec4])] = [
            (systemMesh, Self.blendedColours(off: off.colours, on: on.colours, level: level)),
            (glow.mesh, glow.colours),
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
