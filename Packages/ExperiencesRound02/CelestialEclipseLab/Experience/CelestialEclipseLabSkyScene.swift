// CelestialEclipseLabSkyScene — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-001 … 004, 007; clarifications
// Q1–Q4). Draws one `CelestialEclipseLabSceneSnapshot` at one tier through the real GL path: the ink clear; the sky
// mesh (the backdrop, orbital rings with notches and fixed frames, the chosen ring, the bodies, the crescent shadow
// lenses, the corona halos and the gauges — timeline strip, window brackets, event marks, playhead and actions bars —
// in painter's order) with `CelestialEclipseLabShaders.sky*`, premultiplied, `u_pulse`
// (`CelestialEclipseLabShaders.haloPulse(time:reduceMotion:)`, 1 under Reduce Motion) pulsing the halos with the
// presentation time and `u_won` (1 on a won level) lighting every target bracket and flaring the matched halos; and
// the tier's glow shells (halos, the chosen ring and the matched marks) with the glow program, additive and last
// (level-0 two shells, level-1 one, level-2 none), its gain capped by `u_glowLimit` (the Reduce Flashing cap). Depth
// testing is off on this path: the geometry emits its triangles in painter's order. The halos pulse by a uniform, so
// the meshes are rebuilt only when what they read changes: the level, the phases, the shown tick, the chosen body, the
// stage, the failure, the matched count, the actions left, the tier or the fallback. If a program fails, the scene
// falls back to the level-2 geometry drawn unlit with the shared `MeshRenderer` (ambient 1, the geometry's fallback
// colours, the won brackets included) and keeps the reason; nothing here can reach the kernel. A zero-sized drawable
// is cleared and nothing else is drawn.
//
// Feature 464 (R02-G17-04) T-R02G1704-005 (FR-R02G1704-004, 006; clarifications Q3, Q4): the camera follows the
// gesture controller's orbit (`orbit`, presentation only) through `CelestialEclipseLabSceneGeometry.camera(_:aspect:
// orbit:)`, and the meshes are built with the camera-taking overloads (the backdrop, billboards, camera-facing strips
// and paint order face the drawn eye). The eye and view basis do not depend on the aspect, so an orbit change or a
// preview change (the previewed body and offset, which draw the ghost and the preview timeline) rebuilds the meshes,
// a resize alone does not.
//
// Feature 466 (R02-G17-06) T-R02G1706-005 (FR-R02G1706-004; clarification Q3): the presenter's eased lights
// (`CelestialEclipseLabLights`) are drawn: the glow gain is multiplied by the glow level and `u_won` is the won level;
// the halo pulse is asked with Reduce Motion or Reduce Flashing set, so under either the halos hold at 1 and the sky
// is still between actions. The unlit fallback's geometry takes a won flag, not a level, so the fallback sky blends the
// colours of the not-won and the won sky part by the won level (`blendedColours(off:on:level:)`; the two parts share
// their positions, the won look changes colours only) and is rebuilt when that level moves by a tenth or more. Without
// lights the snapshot's levels are drawn at once.
#if os(iOS)
import CelestialEclipseLabCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Celestial Eclipse Lab.
@MainActor
final class CelestialEclipseLabSkyScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The sky fragment source (the tests' seam replaces it with a broken one before setup).
    var skyFragment = CelestialEclipseLabShaders.skyFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the halos are still (Reduce Motion).
    var reduceMotion = false
    /// How many times the sky mesh was built (tests: it is not rebuilt while only the halos pulse).
    private(set) var skyBuilds = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds = 0
    /// The halo pulse passed as `u_pulse` on the last draw (tests).
    private(set) var lastPulse: Double = 1
    /// The orbit the camera is drawn at (feature 464, presentation only; the gesture controller's). The meshes are
    /// built for the drawn eye, so a new orbit rebuilds them.
    var orbit = CelestialEclipseLabOrbit.authored
    /// The eased light levels the presenter steps every frame (feature 466): the glow gain is multiplied by
    /// `lights.glow`, `u_won` is `lights.won`, and the fallback sky's won colours are blended by `lights.won` (rebuilt
    /// when it moves by a tenth or more). Nil draws the snapshot's levels at once (the renderer tests' default).
    var lights: CelestialEclipseLabLights?

    /// Whether the halos hold still: Reduce Motion or Reduce Flashing (feature 466).
    var halosStill: Bool { reduceMotion || reducedFlash }

    /// What the meshes depend on: everything of the snapshot that the geometry reads (the preview included), the
    /// orbit, the tier and the fallback.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let phases: [Int]
        let shownTick: Int
        let chosenBody: Int
        let stage: CelestialEclipseLabStage
        let failure: CelestialEclipseLabFailure?
        let matched: Int
        let actionsLeft: Int
        let previewBody: Int?
        let previewOffset: Int?
        let orbit: CelestialEclipseLabOrbit
        let tier: Int
        let fallback: Bool
        /// The won level in tenths, in the fallback only (feature 466): the fallback's colours depend on it.
        let wonTenths: Int
    }

    private var registry: ResourceRegistry?
    private var skyRenderer: ShaderMeshRenderer?
    private var glowRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var geometryKey: GeometryKey?
    private var aspect = 1.0

    /// Records the registry and the view's aspect.
    func setup(_ context: RenderContext) {
        registry = context.resources
        resize(context)
    }

    /// Records the new aspect; the camera follows on the next draw. The meshes face the drawn eye, which does not
    /// depend on the aspect, so a resize alone rebuilds nothing.
    func resize(_ context: RenderContext) {
        aspect = Double(max(1, context.pixelWidth)) / Double(max(1, context.pixelHeight))
    }

    /// Releases every GPU object; the next draw rebuilds them (memory warning, teardown).
    func release() {
        skyRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        skyRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if skyRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { CelestialEclipseLabShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer.
    func render(_ snapshot: CelestialEclipseLabSceneSnapshot, tier: CelestialEclipseLabTier, context: RenderContext,
                frame: FrameInfo) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let ink = CelestialEclipseLabPalette.ink
        let clear = ClearColorScene(red: Float(ink.x), green: Float(ink.y), blue: Float(ink.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = CelestialEclipseLabSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        let next: GeometryKey = key(snapshot, tier: tier)
        if next != geometryKey { try rebuild(snapshot, tier: tier, camera: camera) }
        geometryKey = key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won = Float(wonLevel(snapshot))
        let pulse: Double = CelestialEclipseLabShaders.haloPulse(time: snapshot.time, reduceMotion: halosStill)
        lastPulse = pulse
        try drawSky(camera, won: won, pulse: Float(pulse))
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty; feature 466 eases it by
        // the glow level.
        let gain = CelestialEclipseLabShaders.glowGain(for: tier) * (lights?.glow ?? 1)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won, pulse: Float(pulse))
    }

    /// The geometry key of `snapshot` at `tier`.
    private func key(_ s: CelestialEclipseLabSceneSnapshot, tier: CelestialEclipseLabTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, phases: s.phases, shownTick: s.shownTick, chosenBody: s.chosenBody,
                    stage: s.stage, failure: s.failure, matched: s.matched, actionsLeft: s.actionsLeft,
                    previewBody: s.previewBody, previewOffset: s.previewOffset, orbit: orbit, tier: tier.index,
                    fallback: fallbackReason != nil,
                    wonTenths: fallbackReason != nil ? Int((wonLevel(s) * 10).rounded(.down)) : 0)
    }

    /// The won level drawn (feature 466): the eased `lights.won`, or 1 on a won snapshot and 0 otherwise without
    /// lights.
    private func wonLevel(_ snapshot: CelestialEclipseLabSceneSnapshot) -> Double {
        lights?.won ?? (snapshot.isWon ? 1 : 0)
    }

    /// The colours of the fallback sky at won level `level` (feature 466): each colour of `off` (the not-won part)
    /// moved toward the same vertex's colour of `on` (the won part) by `level`, clamped to 0 … 1 (a non-finite level
    /// reads 0). Parts of different sizes cannot be blended vertex by vertex: then `on`'s colours from a level of 0.5
    /// up, `off`'s below. Pure.
    static func blendedColours(off: [Vec4], on: [Vec4], level: Double) -> [Vec4] {
        let t: Double = level.isFinite ? min(max(level, 0), 1) : 0
        guard off.count == on.count else { return t >= 0.5 ? on : off }
        return zip(off, on).map { a, b in a + (b - a) * t }
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier` seen from `camera`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: CelestialEclipseLabSceneSnapshot, tier: CelestialEclipseLabTier,
                         camera: CelestialEclipseLabCamera) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let sky = try CelestialEclipseLabSceneGeometry.skyMesh(snapshot, tier: tier, camera: camera)
                skyRenderer = try Self.renderer(sky, vertex: CelestialEclipseLabShaders.skyVertex,
                                                fragment: skyFragment, name: "celestial-eclipse-lab-sky",
                                                registry: registry)
                skyBuilds += 1
                let glow = try CelestialEclipseLabSceneGeometry.glowMesh(snapshot, tier: tier, camera: camera)
                glowBuilds += 1
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: CelestialEclipseLabShaders.glowVertex,
                                                     fragment: CelestialEclipseLabShaders.glowFragment,
                                                     name: "celestial-eclipse-lab-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "celestial-eclipse-lab shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the failure marks and the won brackets
        // included; level-2 has no glow).
        let minimal = CelestialEclipseLabTier.of(CelestialEclipseLabTier.all.count - 1)
        let up = Vec3(0, 0, 1)
        // Feature 466: the sky's won colours blended by the won level (the won look changes colours, not positions).
        let off = try CelestialEclipseLabSceneGeometry.skyPart(snapshot, tier: minimal, wonLevel: false, camera: camera)
        let on = try CelestialEclipseLabSceneGeometry.skyPart(snapshot, tier: minimal, wonLevel: true, camera: camera)
        let level: Double = wonLevel(snapshot)
        // Parts of different sizes switch whole at a level of 0.5 (see `blendedColours(off:on:level:)`).
        let skyMesh: Mesh = off.colours.count == on.colours.count || level < 0.5 ? off.mesh : on.mesh
        let glow = try CelestialEclipseLabSceneGeometry.glowPart(snapshot, tier: minimal, camera: camera)
        let parts: [(mesh: Mesh, colours: [Vec4])] = [
            (skyMesh, Self.blendedColours(off: off.colours, on: on.colours, level: level)),
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
        skyBuilds += 1
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the sky mesh: `u_mvp`, `u_won` and `u_pulse`.
    private func drawSky(_ camera: CelestialEclipseLabCamera, won: Float, pulse: Float) throws {
        guard let skyRenderer else { return }
        let mvp = camera.viewProjection
        try skyRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: false) { p in
            p.set(CelestialEclipseLabShaders.mvpUniform, matrix4: mvp.floats)
            p.set(CelestialEclipseLabShaders.wonUniform, won)
            p.set(CelestialEclipseLabShaders.pulseUniform, pulse)
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain`, `u_glowLimit`, `u_won` and `u_pulse`.
    private func drawGlow(_ camera: CelestialEclipseLabCamera, gain: Double, won: Float, pulse: Float) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: false) { p in
            p.set(CelestialEclipseLabShaders.mvpUniform, matrix4: mvp.floats)
            p.set(CelestialEclipseLabShaders.glowGainUniform, Float(gain))
            p.set(CelestialEclipseLabShaders.glowLimitUniform, limit)
            p.set(CelestialEclipseLabShaders.wonUniform, won)
            p.set(CelestialEclipseLabShaders.pulseUniform, pulse)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: CelestialEclipseLabCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
