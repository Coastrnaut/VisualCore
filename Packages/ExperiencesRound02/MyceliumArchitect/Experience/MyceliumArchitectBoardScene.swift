// MyceliumArchitectBoardScene — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-001 … 004, 007, 010;
// clarifications Q1–Q4). Draws one `MyceliumArchitectSceneSnapshot` at one tier through the real GL path: the cave
// clear; the board mesh (`MyceliumArchitectSceneGeometry.board`: the backdrop with its spore points, the floor and grid,
// the sites, toxins, rocks, blockers, nutrients, the veins up to the shown pulse, the blooms, the hyphae fuzz, the
// sprouts, the root and terminal caps with their pips, the spores, the weight gauge, the terminal pips and the actions
// bars, in the geometry's painter's order) with `MyceliumArchitectShaders.board*`, premultiplied, with `u_time` (the
// presentation time wrapped by `shaderTime`), `u_motion` (0 under Reduce Motion, so the vein pulses, toxin ripples,
// fuzz and spores stand still) and `u_won` (1 on a won level, brightening the veins and the luminous caps); and the
// tier's glow shells (around the root, the open terminal caps and the shown blooms) with the glow program, additive and
// last (level-0 two shells, level-1 one, level-2 none), the gain capped by `u_glowLimit` (the Reduce Flashing cap).
// The meshes do not depend on the time, so they are rebuilt only when what they read changes: the level, the
// arrangement, the shown pulse, the stage, the failure, the actions left, the tier, the aspect or the fallback. Depth
// and blend state as Binary Gardens' scene (feature 503): depth testing off (the window surface carries no depth
// buffer) and no face culling; the geometry emits its triangles in painter's order (by kind and index; a solid's far
// side first), and a flat quad's cut-out outside its shape has coverage 0 (premultiplied zero), leaving what is beneath
// unchanged. If a program fails, the scene falls back to the level-2 board drawn unlit with the shared `MeshRenderer`
// (`MyceliumArchitectSceneGeometry.fallback`: ambient 1, the palette colours, the broken marks included) and keeps the
// reason; nothing here can reach the kernel. A zero-sized drawable is cleared and nothing else is drawn. Modelled on
// `BinaryGardensSystemScene` (feature 503).
// Feature 514 (R02-G22-04) T-R02G2204-006 (FR-R02G2204-007, 008, 013): the scene draws with the snapshot's view orbit,
// `snapshot.orbit.camera(aspect:)` (at the authored orbit the fixed camera of R02-G22-03, bit for bit), the camera the
// picker reads, so drawing and picking agree; the meshes also depend on the snapshot's presentation state (the ghost
// veins of a preview, the inspection ring and the orbit's drawn eye and backdrop), so a change of the preview, the
// inspected cell or the orbit rebuilds them. The orbit last drawn is kept for diagnostics.
#if os(iOS)
import Foundation
import MyceliumArchitectCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Mycelium Architect.
@MainActor
final class MyceliumArchitectBoardScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The board fragment source (the tests' seam replaces it with a broken one before setup).
    var boardFragment: String = MyceliumArchitectShaders.boardFragment
    /// Whether the vein pulses, ripples, fuzz and spores stand still (Reduce Motion): `u_motion` 0.
    var reducedMotion: Bool = false
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash: Bool = false
    /// How many times the board mesh was built (tests: it is not rebuilt while nothing it reads changes).
    private(set) var boardBuilds: Int = 0
    /// How many times the glow mesh was built (tests).
    private(set) var glowBuilds: Int = 0
    /// The `u_time` value of the last frame drawn by the shader path (tests; it still advances under Reduce Motion,
    /// where `u_motion` 0 keeps everything still).
    private(set) var lastShaderTime: Double = 0
    /// The view orbit of the last frame drawn (feature 514; diagnostics and tests).
    private(set) var orbit: MyceliumArchitectViewOrbit = .authored

    /// The glow limit passed normally (no cap below the glow program's highest gain).
    static let standardGlowLimit: Double = MyceliumArchitectShaders.maxGlowGain
    /// The Reduce Flashing cap on the glow gain (the shared limit 0.5 of the round-two games).
    static let glowGainCap: Double = 0.5
    /// The glow gain base added to ``glowGainPerShell`` times the shells at a tier with glow shells.
    static let glowGainBase: Double = 0.5
    /// The glow gain per glow shell (level-0: 2 shells, level-1: 1).
    static let glowGainPerShell: Double = 0.5

    /// The glow gain passed as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its glow shells,
    /// capped at the glow program's highest gain, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    static func glowGain(for tier: MyceliumArchitectTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), MyceliumArchitectShaders.maxGlowGain)
    }

    /// The glow limit passed as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce Flashing.
    static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The value passed as `u_motion`: 0 under Reduce Motion, else 1.
    static func motion(reduceMotion: Bool) -> Double { reduceMotion ? 0 : 1 }

    /// The time passed as `u_time`: `time` wrapped into 0 ..< `MyceliumArchitectShaders.timeWrap` (non-finite or
    /// negative counts as 0), keeping float precision on long sessions.
    static func shaderTime(_ time: Double) -> Double {
        guard time.isFinite, time > 0 else { return 0 }
        return time.truncatingRemainder(dividingBy: MyceliumArchitectShaders.timeWrap)
    }

    /// What the meshes depend on: everything of the snapshot that the geometry reads, the tier and the fallback.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let arrangement: MyceliumArchitectArrangement
        let shownPulse: Int
        let stage: MyceliumArchitectStage
        let failure: MyceliumArchitectFailure?
        let actionsLeft: Int
        let tier: Int
        let fallback: Bool
        /// The previewed change and its verdict (feature 514: the ghost veins).
        let preview: MyceliumArchitectPreview?
        /// The inspected cell (feature 514: the inspection ring).
        let inspectedCell: MyceliumArchitectCell?
        /// The view orbit (feature 514: the drawn eye and the backdrop face it).
        let orbit: MyceliumArchitectViewOrbit
    }

    private var registry: ResourceRegistry?
    private var boardRenderer: ShaderMeshRenderer?
    private var glowRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var geometryKey: GeometryKey?
    private var aspect: Double = 1.0

    /// Records the registry and the view's aspect.
    func setup(_ context: RenderContext) {
        registry = context.resources
        resize(context)
    }

    /// Records the new aspect; the camera follows on the next draw. The meshes face the drawn eye of the snapshot's
    /// orbit, so they are rebuilt only when the aspect really changed (or the orbit, see the geometry key).
    func resize(_ context: RenderContext) {
        let next: Double = Double(max(1, context.pixelWidth)) / Double(max(1, context.pixelHeight))
        if next != aspect { geometryKey = nil }
        aspect = next
    }

    /// Releases every GPU object; the next draw rebuilds them (memory warning, teardown).
    func release() {
        boardRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        boardRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if boardRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { Self.glowLimit(reduceFlashing: reducedFlash) }

    /// The motion passed as `u_motion`: 0 under Reduce Motion, else 1.
    var motion: Double { Self.motion(reduceMotion: reducedMotion) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer.
    func render(_ snapshot: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier, context: RenderContext,
                frame: FrameInfo) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let cave: Vec4 = MyceliumArchitectPalette.cave
        let clear = ClearColorScene(red: Float(cave.x), green: Float(cave.y), blue: Float(cave.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        // The snapshot's orbit (feature 514): the camera the picker reads; the authored orbit is R02-G22-03's camera.
        orbit = snapshot.orbit
        let camera: MyceliumArchitectCamera = snapshot.orbit.camera(aspect: aspect)
        let next: GeometryKey = key(snapshot, tier: tier)
        if next != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let won: Float = snapshot.isWon ? 1 : 0
        let time: Double = Self.shaderTime(snapshot.time)
        lastShaderTime = time
        try drawBoard(camera, time: time, won: won)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        let gain: Double = Self.glowGain(for: tier)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain, won: won)
    }

    /// The geometry key of `snapshot` at `tier`.
    private func key(_ s: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, arrangement: s.arrangement, shownPulse: s.shownPulse, stage: s.stage,
                    failure: s.failure, actionsLeft: s.actionsLeft, tier: tier.index, fallback: fallbackReason != nil,
                    preview: s.preview, inspectedCell: s.inspectedCell, orbit: s.orbit)
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: MyceliumArchitectSceneSnapshot, tier: MyceliumArchitectTier) throws {
        guard let registry else { return }
        let keepFallback: String? = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let board: Mesh = MyceliumArchitectSceneGeometry.board(snapshot, tier: tier)
                boardRenderer = try Self.renderer(board, vertex: MyceliumArchitectShaders.boardVertex,
                                                  fragment: boardFragment, name: "mycelium-architect-board",
                                                  registry: registry)
                boardBuilds += 1
                let glow: Mesh = MyceliumArchitectSceneGeometry.glow(snapshot, tier: tier)
                glowBuilds += 1
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: MyceliumArchitectShaders.glowVertex,
                                                     fragment: MyceliumArchitectShaders.glowFragment,
                                                     name: "mycelium-architect-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "mycelium-architect shader: \(error)"
            }
        }
        // Fallback: the level-2 board, unlit, with its palette colours (the broken marks included; level-2 has no
        // glow, no fuzz and no spores).
        let part: MyceliumArchitectColouredMesh = MyceliumArchitectSceneGeometry.fallback(snapshot)
        if !part.mesh.indices.isEmpty {
            var mesh: Mesh = part.mesh
            // The normal slot carries shader data (quad-local coordinates, plane offsets); lighting is off (ambient 1),
            // so every vertex gets a real normal and the fallback reads the colour stream.
            mesh.normals = Array(repeating: Vec3(0, 0, 1), count: mesh.positions.count)
            let renderer: MeshRenderer = try MeshRenderer(mesh: mesh, colors: part.colours, registry: registry)
            renderer.ambient = 1
            fallbackRenderers.append(renderer)
        }
        boardBuilds += 1
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the board mesh: `u_mvp`, `u_time`, `u_motion` and `u_won`.
    private func drawBoard(_ camera: MyceliumArchitectCamera, time: Double, won: Float) throws {
        guard let boardRenderer else { return }
        let mvp: [Float] = camera.viewProjection.floats
        let motion: Float = Float(motion)
        try boardRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: false) { (p: ShaderProgram) in
            p.set(MyceliumArchitectShaders.mvpUniform, matrix4: mvp)
            p.set(MyceliumArchitectShaders.timeUniform, Float(time))
            p.set(MyceliumArchitectShaders.motionUniform, motion)
            p.set(MyceliumArchitectShaders.wonUniform, won)
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain`, `u_glowLimit` and `u_won`.
    private func drawGlow(_ camera: MyceliumArchitectCamera, gain: Double, won: Float) throws {
        guard let glowRenderer else { return }
        let mvp: [Float] = camera.viewProjection.floats
        let limit: Float = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: false) { (p: ShaderProgram) in
            p.set(MyceliumArchitectShaders.mvpUniform, matrix4: mvp)
            p.set(MyceliumArchitectShaders.glowGainUniform, Float(gain))
            p.set(MyceliumArchitectShaders.glowLimitUniform, limit)
            p.set(MyceliumArchitectShaders.wonUniform, won)
        }
    }

    /// Draws the unlit fallback.
    private func drawFallback(_ camera: MyceliumArchitectCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
