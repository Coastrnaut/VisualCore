// MushroomWeatherForestScene — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-001 … 004, 007; clarifications
// Q1–Q4). Draws one `MushroomWeatherSceneSnapshot` at one tier through the real GL path: the midnight clear; the forest
// mesh (the backdrop, the moon and its phase ticks, the floor, the logs and stones, the fronds, the mist, the mold
// patch, the site rings, the band rings, the stalks, the caps, the pods, the droplets, the motes, the vents, the
// gauges, the run bars and the actions bars, in the geometry's fixed order) with `MushroomWeatherShaders.forest*`,
// premultiplied, with `u_time` (the presentation time wrapped by `shaderTime`), `u_motion` (0 under Reduce Motion, so
// the droplets and motes stand still) and `u_won` (1 on a won level, lighting every cap); and the tier's glow shells
// (around the caps and pods) with the glow program, additive and last (level-0 two shells, level-1 one, level-2 none),
// the gain capped by `u_glowLimit` (the Reduce Flashing cap). The meshes do not depend on the time, so they are rebuilt
// only when what they read changes: the level, the pods, the vents, the moonlight, the shown cycle, the stage, the
// failure, the actions left, the tier, the aspect, the fallback or (feature 494, R02-G20-04 T-R02G2004-005,
// FR-R02G2004-006, 008) the camera's orbit or the drawn preview; the meshes face the camera of the presenter's orbit
// (`MushroomWeatherSceneGeometry.camera(aspect:orbit:)` and the camera-taking mesh builders) and draw the preview
// (the previewed run, the ghost pod) and the cycle scrubber. Depth and blend state as Microscopic Aurora's scene
// (feature 483): depth testing off (the window surface carries no depth buffer) and no face culling; the geometry
// emits its triangles in its fixed order (by kind, then index; a cap's underside before its dome), and a quad's
// transparent fringe (its quad spans ±1.25 of its shape, the shader gives the fringe coverage 0, premultiplied zero)
// leaves what is beneath unchanged and writes no depth, so it never clips a coplanar or later neighbour. If a program
// fails, the scene falls back to the level-2 geometry drawn unlit with the shared `MeshRenderer` (ambient 1, the
// geometry's fallback colours, the broken marks and the won look included) and keeps the reason; nothing here can reach
// the kernel. A zero-sized drawable is cleared and nothing else is drawn. Modelled on `MicroscopicAuroraDishScene`.
//
// Feature 496 (R02-G20-06) T-R02G2006-005 (FR-R02G2006-004; clarification Q3): the presenter's eased lights
// (`MushroomWeatherLights`) are drawn: the glow gain is multiplied by the glow level and `u_won` is the won level.
// `u_motion` is 0 under Reduce Motion or Reduce Flashing, so the droplets and motes stand still and the forest is still
// between actions. The unlit fallback's geometry takes a won flag, not a level, so the fallback forest blends the
// colours of the not-won and the won forest part by the won level (`blendedColours(off:on:level:)`; the two parts share
// their positions, the won look changes colours only) and is rebuilt when that level moves by a tenth or more. Without
// lights the snapshot's levels are drawn at once. Modelled on `MicroscopicAuroraDishScene` (feature 486).
#if os(iOS)
import Foundation
import MushroomWeatherCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Mushroom Weather.
@MainActor
final class MushroomWeatherForestScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The forest fragment source (the tests' seam replaces it with a broken one before setup).
    var forestFragment = MushroomWeatherShaders.forestFragment
    /// Whether the droplets and motes stand still (Reduce Motion): `u_motion` 0.
    var reducedMotion = false
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// How many times the forest mesh was built (tests: it is not rebuilt while nothing it reads changes).
    private(set) var forestBuilds = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds = 0
    /// The `u_time` value of the last frame drawn by the shader path (tests; it still advances under Reduce Motion,
    /// where `u_motion` 0 keeps the droplets and motes still).
    private(set) var lastShaderTime: Double = 0
    /// The camera's orbit (feature 494; presentation only, the presenter's gesture controller's). A changed orbit
    /// rebuilds the meshes on the next draw.
    var orbit: MushroomWeatherViewOrbit = .authored
    /// The eased light levels the presenter steps every frame (feature 496): the glow gain is multiplied by
    /// `lights.glow`, `u_won` is `lights.won`, and the fallback forest's won colours are blended by `lights.won`
    /// (rebuilt when it moves by a tenth or more). Nil draws the snapshot's levels at once (the renderer tests'
    /// default).
    var lights: MushroomWeatherLights?

    /// What the meshes depend on: everything of the snapshot that the geometry reads, the tier and the fallback.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let pods: [MushroomWeatherCell?]
        let ventsOpen: [Bool]
        let moonlight: Int
        let shownCycle: Int
        let stage: MushroomWeatherStage
        let failure: MushroomWeatherFailure?
        let actionsLeft: Int
        let tier: Int
        let fallback: Bool
        /// The camera's orbit (feature 494; the meshes face the drawn camera).
        let orbit: MushroomWeatherViewOrbit
        /// The aspect the meshes were built for.
        let aspect: Double
        /// The drawn preview (feature 494; presentation only).
        let preview: MushroomWeatherPreview?
        /// The won level in tenths, in the fallback only (feature 496): the fallback's colours depend on it.
        let wonTenths: Int
    }

    private var registry: ResourceRegistry?
    private var forestRenderer: ShaderMeshRenderer?
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
        forestRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        forestRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if forestRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { MushroomWeatherShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// The motion passed as `u_motion`: 0 under Reduce Motion or (feature 496) Reduce Flashing, else 1.
    var motion: Double { MushroomWeatherShaders.motion(reduceMotion: reducedMotion || reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer.
    func render(_ snapshot: MushroomWeatherSceneSnapshot, tier: MushroomWeatherTier, context: RenderContext,
                frame: FrameInfo) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let midnight = MushroomWeatherPalette.midnight
        let clear = ClearColorScene(red: Float(midnight.x), green: Float(midnight.y), blue: Float(midnight.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = MushroomWeatherSceneGeometry.camera(aspect: aspect, orbit: orbit)
        let next: GeometryKey = key(snapshot, tier: tier)
        if next != geometryKey { try rebuild(snapshot, tier: tier, camera: camera) }
        geometryKey = key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won = Float(wonLevel(snapshot))
        let time: Double = MushroomWeatherShaders.shaderTime(snapshot.time)
        lastShaderTime = time
        try drawForest(camera, time: time, won: won)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        // Feature 496 eases the glow gain by the glow level.
        let gain = MushroomWeatherShaders.glowGain(for: tier) * (lights?.glow ?? 1)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won)
    }

    /// The geometry key of `snapshot` at `tier`.
    private func key(_ s: MushroomWeatherSceneSnapshot, tier: MushroomWeatherTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, pods: s.pods, ventsOpen: s.ventsOpen, moonlight: s.moonlight,
                    shownCycle: s.shownCycle, stage: s.stage, failure: s.failure, actionsLeft: s.actionsLeft,
                    tier: tier.index, fallback: fallbackReason != nil, orbit: orbit, aspect: aspect,
                    preview: s.preview,
                    wonTenths: fallbackReason != nil ? Int((wonLevel(s) * 10).rounded(.down)) : 0)
    }

    /// The won level drawn (feature 496): the eased `lights.won`, or 1 on a won snapshot and 0 otherwise without
    /// lights.
    private func wonLevel(_ snapshot: MushroomWeatherSceneSnapshot) -> Double {
        lights?.won ?? (snapshot.isWon ? 1 : 0)
    }

    /// The colours of the fallback forest at won level `level` (feature 496): each colour of `off` (the not-won part)
    /// moved toward the same vertex's colour of `on` (the won part) by `level`, clamped to 0 … 1 (a non-finite level
    /// reads 0). Parts of different sizes cannot be blended vertex by vertex: then `on`'s colours from a level of 0.5
    /// up, `off`'s below. Pure.
    static func blendedColours(off: [Vec4], on: [Vec4], level: Double) -> [Vec4] {
        let t: Double = level.isFinite ? min(max(level, 0), 1) : 0
        guard off.count == on.count else { return t >= 0.5 ? on : off }
        return zip(off, on).map { a, b in a + (b - a) * t }
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier` facing `camera`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: MushroomWeatherSceneSnapshot, tier: MushroomWeatherTier,
                         camera: MushroomWeatherCamera) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let forest = try MushroomWeatherSceneGeometry.forestMesh(snapshot, tier: tier, camera: camera)
                forestRenderer = try Self.renderer(forest, vertex: MushroomWeatherShaders.forestVertex,
                                                   fragment: forestFragment, name: "mushroom-weather-forest",
                                                   registry: registry)
                forestBuilds += 1
                let glow = try MushroomWeatherSceneGeometry.glowMesh(snapshot, tier: tier, camera: camera)
                glowBuilds += 1
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: MushroomWeatherShaders.glowVertex,
                                                     fragment: MushroomWeatherShaders.glowFragment,
                                                     name: "mushroom-weather-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "mushroom-weather shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the broken marks and the won look
        // included; level-2 has no glow, no droplets and no motes).
        let minimal = MushroomWeatherTier.of(MushroomWeatherTier.all.count - 1)
        let up = Vec3(0, 0, 1)
        // Feature 496: the forest's won colours blended by the won level (the won look changes colours, not positions).
        let off = try MushroomWeatherSceneGeometry.forestPart(snapshot, tier: minimal, wonLevel: false, camera: camera)
        let on = try MushroomWeatherSceneGeometry.forestPart(snapshot, tier: minimal, wonLevel: true, camera: camera)
        let level: Double = wonLevel(snapshot)
        // Parts of different sizes switch whole at a level of 0.5 (see `blendedColours(off:on:level:)`).
        let forestMesh: Mesh = off.colours.count == on.colours.count || level < 0.5 ? off.mesh : on.mesh
        let glow = try MushroomWeatherSceneGeometry.glowPart(snapshot, tier: minimal, camera: camera)
        let parts: [(mesh: Mesh, colours: [Vec4])] = [
            (forestMesh, Self.blendedColours(off: off.colours, on: on.colours, level: level)),
            (glow.mesh, glow.colours),
        ]
        for part in parts where !part.mesh.indices.isEmpty {
            var mesh = part.mesh
            // The normal slot carries shader data (quad-local coordinates, flat solids' zero normals); lighting is off
            // (ambient 1), so every vertex gets a real normal and the fallback reads the colour stream.
            mesh.normals = Array(repeating: up, count: mesh.positions.count)
            let renderer = try MeshRenderer(mesh: mesh, colors: part.colours, registry: registry)
            renderer.ambient = 1
            fallbackRenderers.append(renderer)
        }
        forestBuilds += 1
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the forest mesh: `u_mvp`, `u_time`, `u_motion` and `u_won`.
    private func drawForest(_ camera: MushroomWeatherCamera, time: Double, won: Float) throws {
        guard let forestRenderer else { return }
        let mvp = camera.viewProjection
        let motion = Float(motion)
        try forestRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: false) { p in
            p.set(MushroomWeatherShaders.mvpUniform, matrix4: mvp.floats)
            p.set(MushroomWeatherShaders.timeUniform, Float(time))
            p.set(MushroomWeatherShaders.motionUniform, motion)
            p.set(MushroomWeatherShaders.wonUniform, won)
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain`, `u_glowLimit` and `u_won`.
    private func drawGlow(_ camera: MushroomWeatherCamera, gain: Double, won: Float) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: false) { p in
            p.set(MushroomWeatherShaders.mvpUniform, matrix4: mvp.floats)
            p.set(MushroomWeatherShaders.glowGainUniform, Float(gain))
            p.set(MushroomWeatherShaders.glowLimitUniform, limit)
            p.set(MushroomWeatherShaders.wonUniform, won)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: MushroomWeatherCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
