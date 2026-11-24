// AcousticConstellatorConstellationScene — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-001 … 004, 007;
// clarifications Q1–Q4). Draws one `AcousticConstellatorSceneSnapshot` at one tier through the real GL path: the night
// sky clear; the constellation mesh (sky plane, gauges, guides, links, outlines, phase hands and stars, in painter's
// order) with `AcousticConstellatorShaders.constellation*`, premultiplied, the stars pulsing by uniforms: `u_phasesLow`/`u_phasesHigh`
// (`AcousticConstellatorShaders.phaseUniform` of the phases at the drawn tick) and `u_pulse`
// (`AcousticConstellatorShaders.pulse(for:reduceMotion:)`, 0 at level-2 and under Reduce Motion); and the tier's glow
// (wave shells on a coherent drawn tick, then glow shells around teal links and stars) with the glow program, additive
// (level-0 two wave and two glow shells, level-1 one glow shell, level-2 none). Depth testing is off on this path: the
// geometry emits its triangles in painter's order, and back faces are culled on every draw. The constellation mesh is
// rebuilt only when the level, the links, the phases, the stage, the failure, the actions left, the drawn tick, the
// tier or the mode change (the pulse moves by uniforms). The glow program has no time input, so while wave shells are
// shown (level-0, a coherent drawn tick, no Reduce Motion) the glow mesh is also rebuilt whenever the time into the
// shown tick moves; otherwise it follows the constellation key. A failure's missing guide or snapped link is outlined
// by the geometry (it reads the snapshot's failure); a won level's symbol links are drawn in the won-link colour by the
// geometry and their glow lifted. Reduce Flashing passes `AcousticConstellatorShaders.glowLimit(reduceFlashing:)` as
// `u_glowLimit`. If a program fails, the scene falls back to the level-2 geometry drawn unlit with the shared
// `MeshRenderer` (ambient 1, the geometry's fallback colours) and keeps the reason; nothing here can reach the kernel.
// A zero-sized drawable is cleared and nothing else is drawn.
// Feature 424 (R02-G13-04) T-R02G1304-005: the scene draws the presenter's orbit (`orbit`; the stars' painter's order
// and the strips' winding follow the drawn eye, so the geometry key includes the orbit) and, while a link is dragged,
// the teal filament from the dragged star to the finger (`filament`, its own renderer, drawn after the constellation).
#if os(iOS)
import AcousticConstellatorCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Acoustic Constellator.
@MainActor
final class AcousticConstellatorConstellationScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The constellation fragment source (the tests' seam replaces it with a broken one before setup).
    var constellationFragment = AcousticConstellatorShaders.constellationFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the stars are drawn at tick 0 without pulsing and the preview is not played (Reduce Motion).
    var reduceMotion = false
    /// How many times the constellation mesh was built (tests: it is not rebuilt while only the pulse moves).
    private(set) var constellationBuilds = 0
    /// How many times the glow mesh was built (tests: rebuilt while wave shells expand).
    private(set) var glowBuilds = 0

    /// What the constellation mesh depends on: everything of the snapshot that it reads, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let links: [AcousticConstellatorLink]
        let phases: [Int]
        let stage: AcousticConstellatorStage
        let failure: AcousticConstellatorFailure?
        let actionsLeft: Int
        let tick: Int
        let tier: Int
        let reduceMotion: Bool
        let fallback: Bool
        /// The drawn orbit (feature 424): the stars' order and the strips' winding follow its eye.
        let orbit: AcousticConstellatorOrbit
    }

    /// What the glow mesh depends on: the geometry key and, while wave shells are shown, the time into the shown tick.
    private struct GlowKey: Equatable {
        let geometry: GeometryKey
        let shellTime: Double?
    }

    private var registry: ResourceRegistry?
    private var constellationRenderer: ShaderMeshRenderer?
    private var glowRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var geometryKey: GeometryKey?
    private var glowKey: GlowKey?
    private var aspect = 1.0
    /// The drag filament's renderer and what it was built for (feature 424).
    private var filamentRenderer: ShaderMeshRenderer?
    private var filamentKey: Filament?

    /// The orbit drawn (feature 424): presentation only, never part of the snapshot or the digest.
    var orbit: AcousticConstellatorOrbit = .authored

    /// A link drag's preview: the dragged star and the world point the filament ends at.
    struct Filament: Equatable {
        /// The dragged star.
        let star: Int
        /// Where the filament ends: the target star's centre or the point under the finger.
        let point: SIMD3<Double>
    }

    /// The filament drawn while a link is dragged (feature 424); nil draws none.
    var filament: Filament?

    /// Records the registry and the view's aspect.
    func setup(_ context: RenderContext) {
        registry = context.resources
        resize(context)
    }

    /// Records the new aspect; the camera follows on the next draw.
    func resize(_ context: RenderContext) {
        aspect = Double(max(1, context.pixelWidth)) / Double(max(1, context.pixelHeight))
        geometryKey = nil
        glowKey = nil
    }

    /// Releases every GPU object; the next draw rebuilds them (memory warning, teardown).
    func release() {
        constellationRenderer?.release()
        glowRenderer?.release()
        filamentRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        constellationRenderer = nil
        glowRenderer = nil
        filamentRenderer = nil
        filamentKey = nil
        fallbackRenderers = []
        geometryKey = nil
        glowKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if constellationRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        if filamentRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { AcousticConstellatorShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// The tick drawn for `snapshot`: tick 0 under Reduce Motion (or when `animate` is false), else the shown tick.
    func drawnTick(_ snapshot: AcousticConstellatorSceneSnapshot, animate: Bool) -> Int {
        AcousticConstellatorSceneGeometry.drawnTick(snapshot, reduceMotion: reduceMotion || !animate)
    }

    /// The `u_pulse` value drawn for `tier`: 0 under Reduce Motion (or when `animate` is false) and at level-2.
    func pulse(for tier: AcousticConstellatorTier, animate: Bool) -> Double {
        AcousticConstellatorShaders.pulse(for: tier, reduceMotion: reduceMotion || !animate)
    }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false draws the stars at tick 0 without
    /// pulsing and does not play the preview.
    func render(_ snapshot: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let sky = AcousticConstellatorPalette.sky
        let clear = ClearColorScene(red: Float(sky.x), green: Float(sky.y), blue: Float(sky.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let still: Bool = reduceMotion || !animate
        let camera = AcousticConstellatorSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        let wanted = key(snapshot, tier: tier, still: still)
        let rebuilt: Bool = wanted != geometryKey
        if rebuilt { try rebuild(snapshot, tier: tier, still: still) }
        let current = key(snapshot, tier: tier, still: still)
        geometryKey = current
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        // The glow program has no time input: while wave shells expand, the glow mesh follows the time into the tick.
        let glowWanted = GlowKey(geometry: current, shellTime: shellTime(snapshot, tier: tier, still: still))
        if !rebuilt, glowWanted != glowKey { try rebuildGlow(snapshot, tier: tier, still: still) }
        glowKey = glowWanted
        try drawConstellation(snapshot, camera: camera, tier: tier, still: still)
        try drawFilament(snapshot, camera: camera)
        // The glow gain is 0 without glow shells (level-2), where the glow mesh is also empty.
        let gain = AcousticConstellatorShaders.glowGain(for: tier)
        guard gain > 0 else { return }
        try drawGlow(camera, gain: gain)
    }

    /// The geometry key of `snapshot` at `tier` in the current mode.
    private func key(_ s: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier,
                     still: Bool) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, links: s.links, phases: s.phases, stage: s.stage, failure: s.failure,
                    actionsLeft: s.actionsLeft,
                    tick: AcousticConstellatorSceneGeometry.drawnTick(s, reduceMotion: still), tier: tier.index,
                    reduceMotion: still, fallback: fallbackReason != nil, orbit: orbit)
    }

    /// The time into the shown tick while wave shells are shown (the tier has them, the drawn tick is coherent and
    /// the mode is not still); nil otherwise, so the glow mesh then follows the geometry key alone.
    private func shellTime(_ s: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier,
                           still: Bool) -> Double? {
        guard !still, tier.waveShells > 0 else { return nil }
        let tick: Int = AcousticConstellatorSceneGeometry.drawnTick(s, reduceMotion: still)
        guard s.isCoherent(at: tick) else { return nil }
        return s.secondsIntoShownTick
    }

    /// Rebuilds the GPU objects for `snapshot` at `tier`: the two programs, or the unlit fallback.
    private func rebuild(_ snapshot: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier,
                         still: Bool) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let constellation = try AcousticConstellatorSceneGeometry.constellationMesh(snapshot, tier: tier,
                                                                                         reduceMotion: still,
                                                                                         orbit: orbit)
                constellationRenderer = try Self.renderer(constellation,
                                                          vertex: AcousticConstellatorShaders.constellationVertex,
                                                          fragment: constellationFragment,
                                                          name: "acoustic-constellator-constellation",
                                                          registry: registry)
                constellationBuilds += 1
                try rebuildGlow(snapshot, tier: tier, still: still)
                return
            } catch {
                release()
                fallbackReason = "acoustic-constellator shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its fallback colours (the broken outline and the won links
        // included; level-2 has no glow).
        let minimal = AcousticConstellatorTier.of(AcousticConstellatorTier.all.count - 1)
        let up = Vec3(0, 1, 0)
        let parts: [AcousticConstellatorColouredMesh] = [
            try AcousticConstellatorSceneGeometry.constellationPart(snapshot, tier: minimal, reduceMotion: still, orbit: orbit),
            try AcousticConstellatorSceneGeometry.glowPart(snapshot, tier: minimal, reduceMotion: still, orbit: orbit),
        ]
        for part in parts where !part.mesh.indices.isEmpty {
            var mesh = part.mesh
            // The normal slot carries shader data (strip coordinates, unit-sphere directions, glow colours); lighting
            // is off (ambient 1), so every vertex gets a real normal and the fallback reads the colour stream.
            mesh.normals = Array(repeating: up, count: mesh.positions.count)
            let renderer = try MeshRenderer(mesh: mesh, colors: part.colours, registry: registry)
            renderer.ambient = 1
            fallbackRenderers.append(renderer)
        }
        constellationBuilds += 1
    }

    /// Rebuilds only the glow renderer for `snapshot` at `tier` (none when the glow mesh is empty, as at level-2).
    private func rebuildGlow(_ snapshot: AcousticConstellatorSceneSnapshot, tier: AcousticConstellatorTier,
                             still: Bool) throws {
        guard let registry, fallbackReason == nil else { return }
        glowRenderer?.release()
        glowRenderer = nil
        let glow = try AcousticConstellatorSceneGeometry.glowMesh(snapshot, tier: tier, reduceMotion: still, orbit: orbit)
        glowBuilds += 1
        guard !glow.indices.isEmpty else { return }
        glowRenderer = try Self.renderer(glow, vertex: AcousticConstellatorShaders.glowVertex,
                                         fragment: AcousticConstellatorShaders.glowFragment,
                                         name: "acoustic-constellator-glow", registry: registry)
    }

    /// A shader mesh renderer for `mesh` with the named program.
    private static func renderer(_ mesh: Mesh, vertex: String, fragment: String, name: String,
                                 registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: vertex, fragment: fragment, registry: registry,
                               vertexName: name + ".vert", fragmentName: name + ".frag")
    }

    /// Draws the constellation mesh: `u_mvp`, `u_phasesLow` and `u_phasesHigh` (the phases at the drawn tick) and `u_pulse`.
    private func drawConstellation(_ snapshot: AcousticConstellatorSceneSnapshot, camera: AcousticConstellatorCamera,
                                   tier: AcousticConstellatorTier, still: Bool) throws {
        guard let constellationRenderer else { return }
        let mvp = camera.viewProjection
        let tick: Int = AcousticConstellatorSceneGeometry.drawnTick(snapshot, reduceMotion: still)
        let rows: [SIMD4<Float>] = AcousticConstellatorShaders.phaseUniform(snapshot.phases(at: tick)).map {
            SIMD4<Float>(Float($0.x), Float($0.y), Float($0.z), Float($0.w))
        }
        let pulse = Float(AcousticConstellatorShaders.pulse(for: tier, reduceMotion: still))
        try constellationRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(AcousticConstellatorShaders.mvpUniform, matrix4: mvp.floats)
            for (name, row) in zip(AcousticConstellatorShaders.phaseRowUniforms, rows) { p.set(name, row) }
            p.set(AcousticConstellatorShaders.pulseUniform, pulse)
        }
    }

    /// Draws the drag filament with the constellation program (no pulse; both faces, since it may face away from an
    /// orbiting eye), rebuilding its mesh when the filament changes; nothing without a filament.
    private func drawFilament(_ snapshot: AcousticConstellatorSceneSnapshot, camera: AcousticConstellatorCamera) throws {
        guard let filament, let registry else {
            filamentRenderer?.release()
            filamentRenderer = nil
            filamentKey = nil
            return
        }
        if filament != filamentKey || filamentRenderer == nil {
            filamentRenderer?.release()
            filamentRenderer = nil
            filamentKey = filament
            let mesh = try AcousticConstellatorSceneGeometry.filamentMesh(from: filament.star, to: filament.point,
                                                                          snapshot)
            guard !mesh.indices.isEmpty else { return }
            filamentRenderer = try Self.renderer(mesh, vertex: AcousticConstellatorShaders.constellationVertex,
                                                 fragment: constellationFragment,
                                                 name: "acoustic-constellator-filament", registry: registry)
        }
        guard let filamentRenderer else { return }
        let mvp = camera.viewProjection
        let rows: [SIMD4<Float>] = AcousticConstellatorShaders.phaseUniform([]).map {
            SIMD4<Float>(Float($0.x), Float($0.y), Float($0.z), Float($0.w))
        }
        try filamentRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: false) { p in
            p.set(AcousticConstellatorShaders.mvpUniform, matrix4: mvp.floats)
            for (name, row) in zip(AcousticConstellatorShaders.phaseRowUniforms, rows) { p.set(name, row) }
            p.set(AcousticConstellatorShaders.pulseUniform, Float(0))
        }
    }

    /// Draws the glow additively: `u_mvp`, `u_glowGain` and `u_glowLimit`.
    private func drawGlow(_ camera: AcousticConstellatorCamera, gain: Double) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: true) { p in
            p.set(AcousticConstellatorShaders.mvpUniform, matrix4: mvp.floats)
            p.set(AcousticConstellatorShaders.glowGainUniform, Float(gain))
            p.set(AcousticConstellatorShaders.glowLimitUniform, limit)
        }
    }

    /// Draws the unlit fallback parts.
    private func drawFallback(_ camera: AcousticConstellatorCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
