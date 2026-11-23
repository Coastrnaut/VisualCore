// EchoCartographerChamberScene — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-001 … 004, 007; clarifications
// Q1–Q4). Draws one `EchoCartographerSceneSnapshot` at one tier through the real GL path: the abyss ground clear; the
// chamber (ground, floor tiles, entry, markers, the last pulse's rays and ring field, the known walls' dark blocks with
// their sonar-mint edge strips, the beacon pillars and the energy gauge) with `EchoCartographerShaders.chamber*`,
// premultiplied, the pulse ring, the echo rings and the wall flares following `u_time` (seconds since the last pulse;
// drawn at rest under Reduce Motion); and the tier's glow shells around edges and pillars with the glow program,
// additive (level-0 two, level-1 one, level-2 none). Depth testing is off on this path: the geometry emits the flat
// layers first and the solids back to front, and back faces are culled on every draw. Geometry is rebuilt only when the
// level, the knowledge, the markers, the located beacons, the last echo, the stage, the energy, the tier or the mode
// change; the rings and flares move by uniforms. Reduce Flashing passes `EchoCartographerShaders.glowLimit(
// reduceFlashing:)` as `u_glowLimit`. If a program fails, the scene falls back to the level-2 geometry drawn unlit with
// the shared `MeshRenderer` (ambient 1, per-vertex colours) and keeps the reason; nothing here can reach the kernel.
#if os(iOS)
import EchoCartographerCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Echo Cartographer.
@MainActor
final class EchoCartographerChamberScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The chamber fragment source (the tests' seam replaces it with a broken one before setup).
    var chamberFragment = EchoCartographerShaders.chamberFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// Whether the rings and flares are drawn at rest (Reduce Motion).
    var reduceMotion = false
    /// The orbit drawn (feature 404): presentation only, never part of the snapshot or the digest.
    var orbit: EchoCartographerOrbit = .authored
    /// The light direction of the chamber (from above and in front).
    static let lightDirection = SIMD3<Float>(0.25, 0.85, 0.46)

    /// What the geometry depends on: everything of the snapshot that the meshes read, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let knowledge: [EchoCartographerKnown]
        let markers: [EchoCartographerCell]
        let located: [EchoCartographerCell]
        let lastEcho: EchoCartographerEcho?
        let stage: EchoCartographerStage
        let energy: Int
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var chamberRenderer: ShaderMeshRenderer?
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
        chamberRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        chamberRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The number of GPU objects the scene holds: 0 after ``release()`` and positive after a frame was drawn.
    var liveObjectCount: Int {
        var count: Int = fallbackRenderers.count
        if chamberRenderer != nil { count += 1 }
        if glowRenderer != nil { count += 1 }
        return count
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { EchoCartographerShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false draws the rings and flares at rest.
    func render(_ snapshot: EchoCartographerSceneSnapshot, tier: EchoCartographerTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let ground = EchoCartographerPalette.ground
        let clear = ClearColorScene(red: Float(ground.x), green: Float(ground.y), blue: Float(ground.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = EchoCartographerSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        if key(snapshot, tier: tier) != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = key(snapshot, tier: tier)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        try drawChamber(snapshot, camera: camera, tier: tier, animate: animate && !reduceMotion)
        let gain = EchoCartographerShaders.glowGain(for: tier)
        guard tier.glowShells > 0, gain > 0 else { return }
        try drawGlow(camera, gain: gain)
    }

    /// The geometry key of `snapshot` at `tier` in the current mode.
    private func key(_ s: EchoCartographerSceneSnapshot, tier: EchoCartographerTier) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, knowledge: s.knowledge, markers: s.markers, located: s.located,
                    lastEcho: s.lastEcho, stage: s.stage, energy: s.energy, tier: tier.index,
                    fallback: fallbackReason != nil)
    }

    private func rebuild(_ snapshot: EchoCartographerSceneSnapshot, tier: EchoCartographerTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let chamber = try EchoCartographerSceneGeometry.chamberMesh(snapshot, tier: tier,
                                                                             reduceMotion: reduceMotion)
                chamberRenderer = try Self.renderer(chamber, vertex: EchoCartographerShaders.chamberVertex,
                                                    fragment: chamberFragment, name: "echo-cartographer-chamber",
                                                    registry: registry)
                let glow = try EchoCartographerSceneGeometry.glowMesh(snapshot, tier: tier)
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: EchoCartographerShaders.glowVertex,
                                                     fragment: EchoCartographerShaders.glowFragment,
                                                     name: "echo-cartographer-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "echo-cartographer shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its per-vertex colours.
        let minimal = EchoCartographerTier.of(EchoCartographerTier.all.count - 1)
        let up = Vec3(0, 1, 0)
        let parts: [(part: EchoCartographerColouredMesh, colourInNormals: Bool)] = [
            (part: try EchoCartographerSceneGeometry.chamberPart(snapshot, tier: minimal), colourInNormals: false),
            (part: try EchoCartographerSceneGeometry.glowPart(snapshot, tier: minimal), colourInNormals: true),
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

    /// The ring field's uniforms from the last echo: the emitter's world position, the longest ray in world units and
    /// the echo delays in seconds (all zero without a pulse).
    private static func pulseUniforms(_ snapshot: EchoCartographerSceneSnapshot)
        -> (emitter: SIMD2<Float>, maxRadius: Float, delays: SIMD4<Float>, cellSize: Float) {
        let cellSize: Double = 1.8 / Double(max(snapshot.width, snapshot.height))
        guard let echo = snapshot.lastEcho else { return (.zero, 0, .zero, Float(cellSize)) }
        let centre: SIMD3<Double> = EchoCartographerSceneGeometry.cellCentre(echo.emitter, snapshot)
        var longest: Int = 0
        for ray in echo.rays { longest = max(longest, ray.distance) }
        let delays: SIMD4<Double> = EchoCartographerShaders.echoDelays(echo)
        let maxRadius: Double = max(0, Double(longest) - 0.5) * cellSize
        return (SIMD2(Float(centre.x), Float(centre.z)), Float(maxRadius),
                SIMD4(Float(delays.x), Float(delays.y), Float(delays.z), Float(delays.w)), Float(cellSize))
    }

    private func drawChamber(_ snapshot: EchoCartographerSceneSnapshot, camera: EchoCartographerCamera,
                             tier: EchoCartographerTier, animate: Bool) throws {
        guard let chamberRenderer else { return }
        let mvp = camera.viewProjection
        let pulse = Self.pulseUniforms(snapshot)
        let flags: SIMD3<Double> = EchoCartographerShaders.tierFlags(for: tier)
        let time = Float(snapshot.time)
        let still: Float = animate ? 0 : 1
        try chamberRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(EchoCartographerShaders.mvpUniform, matrix4: mvp.floats)
            p.set(EchoCartographerShaders.lightDirectionUniform, Self.lightDirection)
            p.set(EchoCartographerShaders.timeUniform, time)
            p.set(EchoCartographerShaders.cellSizeUniform, pulse.cellSize)
            p.set(EchoCartographerShaders.emitterUniform, pulse.emitter)
            p.set(EchoCartographerShaders.maxRadiusUniform, pulse.maxRadius)
            p.set(EchoCartographerShaders.echoDelaysUniform, pulse.delays)
            p.set(EchoCartographerShaders.tierUniform, SIMD3<Float>(Float(flags.x), Float(flags.y), Float(flags.z)))
            p.set(EchoCartographerShaders.reduceMotionUniform, still)
        }
    }

    private func drawGlow(_ camera: EchoCartographerCamera, gain: Double) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: .additive, cullBackFaces: true) { p in
            p.set(EchoCartographerShaders.mvpUniform, matrix4: mvp.floats)
            p.set(EchoCartographerShaders.glowGainUniform, Float(gain))
            p.set(EchoCartographerShaders.glowLimitUniform, limit)
        }
    }

    private func drawFallback(_ camera: EchoCartographerCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
