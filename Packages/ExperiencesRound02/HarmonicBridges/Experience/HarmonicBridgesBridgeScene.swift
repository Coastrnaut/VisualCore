// HarmonicBridgesBridgeScene — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-001 … 004, 007; clarifications
// Q1–Q4). Draws one `HarmonicBridgesSceneSnapshot` at one tier through the real GL path: the mist ground clear; the
// bridge mesh (ground, flat rings, membranes, wave shells, strings, the broken string's outline, marks, island prisms,
// step pips and the moves gauge) with `HarmonicBridgesShaders.bridge*`, premultiplied, the strings' wave and the shells
// following `u_time` (`HarmonicBridgesShaders.wrappedTime` of the snapshot's time) and `u_motion`
// (`HarmonicBridgesShaders.motion(for:reduceMotion:)`, 0 under Reduce Motion); and the tier's glow shells around the
// shown step's membranes and reached islands with the glow program, additive (level-0 two, level-1 one, level-2 none).
// Depth testing is off on this path: the geometry emits its triangles in painter's order, and back faces are culled on
// every draw. Geometry is rebuilt only when the level, the pegs, the stage, the failure, the actions left, the drawn
// step, the tier or the mode change; the wave moves by uniforms. A failure's broken step pip and broken string are
// outlined by the geometry (it reads the snapshot's failure); a won level's membranes, glow rings and glow shells are
// brightened by the shaders (the geometry's won flag). Reduce Flashing passes `HarmonicBridgesShaders.glowLimit(
// reduceFlashing:)` as `u_glowLimit`. If a program fails, the scene falls back to the level-2 geometry drawn unlit with
// the shared `MeshRenderer` (ambient 1, the geometry's fallback colours) and keeps the reason; nothing here can reach
// the kernel. A zero-sized drawable is cleared and nothing else is drawn.
// Feature 416 (R02-G12-06) T-R02G1206-005 (FR-R02G1206-004; clarification Q3): the presenter's eased lights scale the
// glow gain (`lights.glow`) and the won lift of both programs (`u_wonLight`, `lights.won`), so a win brightens as a fade
// rather than at once; under Reduce Flashing the scene also draws the resting step with the strings at rest
// (`u_motion` 0) and no wave shell, exactly as under Reduce Motion (`stringsAtRest`). The lights are uniforms, so a
// fade rebuilds no geometry.
#if os(iOS)
import Foundation
import HarmonicBridgesCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Harmonic Bridges.
@MainActor
final class HarmonicBridgesBridgeScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The bridge fragment source (the tests' seam replaces it with a broken one before setup).
    var bridgeFragment = HarmonicBridgesShaders.bridgeFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the strings are drawn at rest and the shown step is held (Reduce Motion).
    var reduceMotion = false
    /// The orbit drawn (feature 414): presentation only, never part of the snapshot or the digest.
    var orbit: HarmonicBridgesOrbit = .authored
    /// The eased light levels (presentation only), set by the presenter before each frame (feature 416); nil draws the
    /// full levels (the full glow gain and won lift).
    var lights: HarmonicBridgesLights?
    /// Whether the strings are drawn at rest, the resting step is held and no wave shell is drawn: under Reduce Motion
    /// or Reduce Flashing (feature 416).
    var stringsAtRest: Bool { reduceMotion || reducedFlash }

    /// What the geometry depends on: everything of the snapshot that the meshes read, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let pegs: [Int]
        let stage: HarmonicBridgesStage
        let failure: HarmonicBridgesFailure?
        let actionsLeft: Int
        let step: Int
        let tier: Int
        let reduceMotion: Bool
        let fallback: Bool
        /// The islands' painter's order for the drawn orbit (feature 414): a turn that reorders them rebuilds.
        let islandOrder: [Int]
    }

    private var registry: ResourceRegistry?
    private var bridgeRenderer: ShaderMeshRenderer?
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
        bridgeRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        bridgeRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if bridgeRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { HarmonicBridgesShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// The step drawn for `snapshot`: the resting step under Reduce Motion or Reduce Flashing (feature 416), or when
    /// `animate` is false, else the shown step.
    func drawnStep(_ snapshot: HarmonicBridgesSceneSnapshot, animate: Bool) -> Int {
        HarmonicBridgesSceneGeometry.drawnStep(snapshot, reduceMotion: stringsAtRest || !animate)
    }

    /// The won light passed as `u_wonLight`: `lights.won` clamped to 0 … 1, or 1 without lights (feature 416).
    var wonLight: Double { min(max(lights?.won ?? 1, 0), 1) }

    /// The glow gain drawn at `tier`: the tier's gain times `lights.glow` clamped to 0 … 1 (1 without lights;
    /// feature 416).
    func glowGain(for tier: HarmonicBridgesTier) -> Double {
        HarmonicBridgesShaders.glowGain(for: tier) * min(max(lights?.glow ?? 1, 0), 1)
    }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false draws the strings at rest and holds the
    /// shown step.
    func render(_ snapshot: HarmonicBridgesSceneSnapshot, tier: HarmonicBridgesTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let ground = HarmonicBridgesPalette.ground
        let clear = ClearColorScene(red: Float(ground.x), green: Float(ground.y), blue: Float(ground.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let still: Bool = stringsAtRest || !animate
        let camera = HarmonicBridgesSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        let wanted = key(snapshot, tier: tier, still: still)
        if wanted != geometryKey { try rebuild(snapshot, tier: tier, still: still) }
        geometryKey = key(snapshot, tier: tier, still: still)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won = Float(wonLight)
        try drawBridges(snapshot, camera: camera, tier: tier, still: still, wonLight: won)
        let gain = glowGain(for: tier)
        guard tier.glowShells > 0, gain > 0 else { return }
        try drawGlow(camera, gain: gain, wonLight: won)
    }

    /// The geometry key of `snapshot` at `tier` in the current mode.
    private func key(_ s: HarmonicBridgesSceneSnapshot, tier: HarmonicBridgesTier, still: Bool) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, pegs: s.pegs, stage: s.stage, failure: s.failure,
                    actionsLeft: s.actionsLeft,
                    step: HarmonicBridgesSceneGeometry.drawnStep(s, reduceMotion: still), tier: tier.index,
                    reduceMotion: still, fallback: fallbackReason != nil,
                    islandOrder: HarmonicBridgesSceneGeometry.islandOrder(s, orbit: orbit))
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: HarmonicBridgesSceneSnapshot, tier: HarmonicBridgesTier, still: Bool) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let bridges = try HarmonicBridgesSceneGeometry.bridgeMesh(snapshot, tier: tier, reduceMotion: still,
                                                                          orbit: orbit)
                bridgeRenderer = try Self.renderer(bridges, vertex: HarmonicBridgesShaders.bridgeVertex,
                                                   fragment: bridgeFragment, name: "harmonic-bridges-bridge",
                                                   registry: registry)
                let glow = try HarmonicBridgesSceneGeometry.glowMesh(snapshot, tier: tier, reduceMotion: still, orbit: orbit)
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: HarmonicBridgesShaders.glowVertex,
                                                     fragment: HarmonicBridgesShaders.glowFragment,
                                                     name: "harmonic-bridges-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "harmonic-bridges shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the broken outline and the won lift
        // included).
        let minimal = HarmonicBridgesTier.of(HarmonicBridgesTier.all.count - 1)
        let up = Vec3(0, 1, 0)
        let parts: [HarmonicBridgesColouredMesh] = [
            try HarmonicBridgesSceneGeometry.bridgePart(snapshot, tier: minimal, reduceMotion: still, orbit: orbit),
            try HarmonicBridgesSceneGeometry.glowPart(snapshot, tier: minimal, reduceMotion: still, orbit: orbit),
        ]
        for part in parts where !part.mesh.indices.isEmpty {
            var mesh = part.mesh
            // The normal slot carries shader data (string coordinates, glow colours, won flags); lighting is off
            // (ambient 1), so every vertex gets a real normal and the fallback reads the colour stream.
            mesh.normals = Array(repeating: up, count: mesh.positions.count)
            let renderer = try MeshRenderer(mesh: mesh, colors: part.colours, registry: registry)
            renderer.ambient = 1
            fallbackRenderers.append(renderer)
        }
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the bridge mesh: `u_mvp`, `u_time` (wrapped presentation time), `u_motion` and `u_wonLight`.
    private func drawBridges(_ snapshot: HarmonicBridgesSceneSnapshot, camera: HarmonicBridgesCamera,
                             tier: HarmonicBridgesTier, still: Bool, wonLight: Float) throws {
        guard let bridgeRenderer else { return }
        let mvp = camera.viewProjection
        let time = Float(HarmonicBridgesShaders.wrappedTime(snapshot.time))
        let motion = Float(HarmonicBridgesShaders.motion(for: tier, reduceMotion: still))
        try bridgeRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(HarmonicBridgesShaders.mvpUniform, matrix4: mvp.floats)
            p.set(HarmonicBridgesShaders.timeUniform, time)
            p.set(HarmonicBridgesShaders.motionUniform, motion)
            p.set(HarmonicBridgesShaders.wonLightUniform, wonLight)
        }
    }

    /// Draws the glow shells additively: `u_mvp`, `u_glowGain`, `u_glowLimit` and `u_wonLight`.
    private func drawGlow(_ camera: HarmonicBridgesCamera, gain: Double, wonLight: Float) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: true) { p in
            p.set(HarmonicBridgesShaders.mvpUniform, matrix4: mvp.floats)
            p.set(HarmonicBridgesShaders.glowGainUniform, Float(gain))
            p.set(HarmonicBridgesShaders.glowLimitUniform, limit)
            p.set(HarmonicBridgesShaders.wonLightUniform, wonLight)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: HarmonicBridgesCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
