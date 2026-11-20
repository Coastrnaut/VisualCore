// AuroraLoomRibbonScene — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-001 … 004, 007; clarifications Q1–Q4;
// research R4, R5, R8). Draws one `AuroraLoomSceneSnapshot` at one tier through the real GL path: the night clear, the
// four gate rings (teal, brighter when every ribbon meets the gate), the ribbons' layered silk back lane to front with
// `AuroraLoomShaders.ribbon*` (premultiplied), the tier's glow passes (the same program, additive, wider and fainter),
// and the target markers last as camera-facing discs (gold, dim or lit). Geometry is rebuilt only when the snapshot's
// steps, level, tick or the tier change. If a ribbon or gate program fails, the scene falls back to the minimal layer
// drawn with the shared unlit `MeshRenderer` in the palette colours and keeps the reason; nothing here can reach the
// kernel.
#if os(iOS)
import AuroraLoomCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Aurora Loom.
@MainActor
final class AuroraLoomRibbonScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The ribbon fragment source (the tests' seam replaces it with a broken one before setup).
    var ribbonFragment = AuroraLoomShaders.ribbonFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// The glow gain without and with the cap.
    static let glowGain = 2.5
    static let reducedGlowGain = 0.8
    /// The marker disc's radius in world units.
    static let markerRadius = 0.16

    private var registry: ResourceRegistry?
    private var ribbonRenderers: [ShaderMeshRenderer] = []
    private var gateRenderers: [ShaderMeshRenderer] = []
    private var markerRenderers: [ShaderMeshRenderer] = []
    private var fallbackRenderers: [MeshRenderer] = []
    private var geometryKey: Int?
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
        for r in ribbonRenderers { r.release() }
        for r in gateRenderers { r.release() }
        for r in markerRenderers { r.release() }
        for r in fallbackRenderers { r.release() }
        ribbonRenderers = []; gateRenderers = []; markerRenderers = []; fallbackRenderers = []
        geometryKey = nil
    }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the shimmer and the wave still.
    func render(_ snapshot: AuroraLoomSceneSnapshot, tier: AuroraLoomTier, context: RenderContext, frame: FrameInfo,
                animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let night = AuroraLoomPalette.night
        let clear = ClearColorScene(red: Float(night.x), green: Float(night.y), blue: Float(night.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = AuroraLoomSceneGeometry.camera(aspect: aspect)
        let viewProjection = camera.projection * camera.view
        let key = Self.key(snapshot, tier: tier, aspect: aspect, fallback: fallbackReason != nil)
        if key != geometryKey { try rebuild(snapshot, tier: tier, camera: camera) }
        geometryKey = key
        if fallbackReason != nil {
            try drawFallback(view: camera.view, projection: camera.projection)
            return
        }
        try drawGates(snapshot, viewProjection: viewProjection)
        try drawRibbons(snapshot, tier: tier, viewProjection: viewProjection, animate: animate)
        try drawMarkers(snapshot, viewProjection: viewProjection)
    }

    /// The geometry key: level, steps, tick, tier, aspect and mode.
    static func key(_ s: AuroraLoomSceneSnapshot, tier: AuroraLoomTier, aspect: Double, fallback: Bool) -> Int {
        var h = Hasher()
        h.combine(s.level.fingerprint)
        h.combine(s.steps)
        h.combine(s.tick)
        h.combine(tier.index)
        h.combine(aspect)
        h.combine(fallback)
        return h.finalize()
    }

    private func rebuild(_ snapshot: AuroraLoomSceneSnapshot, tier: AuroraLoomTier,
                         camera: (view: Mat4, projection: Mat4)) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                for mesh in try AuroraLoomSceneGeometry.ribbonMeshes(snapshot: snapshot, tier: tier) {
                    ribbonRenderers.append(try ShaderMeshRenderer(mesh: mesh, vertex: AuroraLoomShaders.ribbonVertex,
                                                                  fragment: ribbonFragment, registry: registry,
                                                                  vertexName: "aurora-loom-ribbon.vert",
                                                                  fragmentName: "aurora-loom-ribbon.frag"))
                }
                for gate in 0..<4 {
                    let ring = try Self.ringMesh(AuroraLoomSceneGeometry.gateRing(gate: gate, snapshot: snapshot))
                    gateRenderers.append(try Self.gateRenderer(ring, registry: registry))
                    let disc = try Self.disc(at: AuroraLoomSceneGeometry.marker(gate: gate, snapshot: snapshot),
                                         view: camera.view, radius: Self.markerRadius)
                    markerRenderers.append(try Self.gateRenderer(disc, registry: registry))
                }
                return
            } catch {
                fallbackReason = "aurora-loom shader: \(error)"
                release()
                fallbackReason = "aurora-loom shader: \(error)"
            }
        }
        // Fallback: the minimal layer, unlit, in the palette.
        let minimal = AuroraLoomTier.of(AuroraLoomTier.all.count - 1)
        for mesh in try AuroraLoomSceneGeometry.ribbonMeshes(snapshot: snapshot, tier: minimal) {
            fallbackRenderers.append(try MeshRenderer(mesh: mesh, registry: registry))
        }
    }

    private static func gateRenderer(_ mesh: Mesh, registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: AuroraLoomShaders.gateVertex, fragment: AuroraLoomShaders.gateFragment,
                               registry: registry, vertexName: "aurora-loom-gate.vert",
                               fragmentName: "aurora-loom-gate.frag")
    }

    /// A thin closed tube along a ring's points.
    static func ringMesh(_ points: [Vec3]) throws -> Mesh {
        try Mesh.tube(path: points, radius: 0.03, sides: 6, caps: false, closed: true)
    }

    /// A camera-facing disc of `radius` around `centre` (16 triangles), built with the shared `MeshBuilder`.
    static func disc(at centre: Vec3, view: Mat4, radius: Double) throws -> Mesh {
        // The view matrix's first two rows are the camera's right and up axes in world space.
        let right = Vec3(view.c0.x, view.c1.x, view.c2.x).normalized
        let up = Vec3(view.c0.y, view.c1.y, view.c2.y).normalized
        let normal = Vec3(view.c0.z, view.c1.z, view.c2.z).normalized
        var builder = MeshBuilder(weldPositionsOnly: false)
        let middle = try builder.vertex(centre, normal: normal, uv: Vec2(0.5, 0.5))
        let count = 16
        var rim: [UInt32] = []
        for i in 0..<count {
            let a = 2 * Double.pi * Double(i) / Double(count)
            let p = centre + right * (radius * Foundation.cos(a)) + up * (radius * Foundation.sin(a))
            rim.append(try builder.vertex(p, normal: normal,
                                          uv: Vec2(0.5 + 0.5 * Foundation.cos(a), 0.5 + 0.5 * Foundation.sin(a))))
        }
        for i in 0..<count { try builder.triangle(middle, rim[i], rim[(i + 1) % count]) }
        return builder.build()
    }

    private func drawGates(_ snapshot: AuroraLoomSceneSnapshot, viewProjection: Mat4) throws {
        let teal = AuroraLoomPalette.teal
        for (gate, renderer) in gateRenderers.enumerated() {
            let lit = (0..<3).allSatisfy { snapshot.lit(ribbon: $0, gate: gate) }
            try renderer.draw(blend: .opaque) { p in
                p.set("u_mvp", matrix4: viewProjection.floats)
                p.set("u_pointSize", Float(1))
                p.set("u_color", SIMD3<Float>(Float(teal.x), Float(teal.y), Float(teal.z)))
                p.set("u_lit", Float(lit ? 1 : 0))
                p.set("u_opacity", Float(1))
            }
        }
    }

    private func drawMarkers(_ snapshot: AuroraLoomSceneSnapshot, viewProjection: Mat4) throws {
        let gold = AuroraLoomPalette.gold
        for (gate, renderer) in markerRenderers.enumerated() {
            let lit = (0..<3).allSatisfy { snapshot.lit(ribbon: $0, gate: gate) }
            try renderer.draw(blend: .opaque) { p in
                p.set("u_mvp", matrix4: viewProjection.floats)
                p.set("u_pointSize", Float(1))
                p.set("u_color", SIMD3<Float>(Float(gold.x), Float(gold.y), Float(gold.z)))
                p.set("u_lit", Float(lit ? 1 : 0))
                p.set("u_opacity", Float(1))
            }
        }
    }

    private func drawRibbons(_ snapshot: AuroraLoomSceneSnapshot, tier: AuroraLoomTier, viewProjection: Mat4,
                             animate: Bool) throws {
        let layers = tier.layers
        let phase = animate ? snapshot.time / 60 : 0
        let gain = reducedFlash ? Self.reducedGlowGain : Self.glowGain
        // Lanes back to front: ribbon 2 (z = +D) is nearest the camera, so draw 0, 1, 2.
        for ribbon in 0..<3 {
            let base = AuroraLoomPalette.ribbons[ribbon]
            let highlight = AuroraLoomPalette.ribbons[(ribbon + 1) % 3]
            var litGates = 0
            for gate in 0..<4 where snapshot.lit(ribbon: ribbon, gate: gate) { litGates += 1 }
            let lit = Float(litGates) / 4
            for layer in 0..<layers {
                let index = ribbon * layers + layer
                guard index < ribbonRenderers.count else { continue }
                let opacity = Float(layers == 1 ? 1 : 0.35 + 0.65 / Double(layers))
                let passes = tier.glowPasses
                try ribbonRenderers[index].draw(blend: .premultipliedAlpha) { p in
                    Self.setRibbon(p, viewProjection: viewProjection, phase: phase, animate: animate, layer: layer,
                                   base: base, highlight: highlight, lit: lit, glow: 0, opacity: opacity)
                }
                for pass in 0..<passes {
                    try ribbonRenderers[index].draw(blend: .additive) { p in
                        Self.setRibbon(p, viewProjection: viewProjection, phase: phase, animate: animate, layer: layer,
                                       base: base, highlight: highlight, lit: lit,
                                       glow: Float(gain) / Float(pass + 2), opacity: 0.25)
                    }
                }
            }
        }
    }

    private static func setRibbon(_ p: ShaderProgram, viewProjection: Mat4, phase: Double, animate: Bool, layer: Int,
                                  base: SIMD3<Double>, highlight: SIMD3<Double>, lit: Float, glow: Float,
                                  opacity: Float) {
        p.set("u_mvp", matrix4: viewProjection.floats)
        p.set("u_model", matrix4: Mat4.identity.floats)
        p.set("u_wavePhase", Float(phase.truncatingRemainder(dividingBy: 1_000)))
        p.set("u_waveAmplitude", Float(animate ? 0.04 : 0))
        p.set("u_layer", Float(layer))
        p.set("u_baseColor", SIMD3<Float>(Float(base.x), Float(base.y), Float(base.z)))
        p.set("u_highlightColor", SIMD3<Float>(Float(highlight.x), Float(highlight.y), Float(highlight.z)))
        p.set("u_shimmerPhase", Float((phase * 1.7).truncatingRemainder(dividingBy: 1_000)))
        p.set("u_lit", lit)
        p.set("u_glowGain", glow)
        p.set("u_opacity", opacity)
    }

    private func drawFallback(view: Mat4, projection: Mat4) throws {
        for (ribbon, renderer) in fallbackRenderers.enumerated() {
            let c = AuroraLoomShaders.fallbackColour(ribbon: ribbon)
            try renderer.draw(model: .identity, view: view, projection: projection,
                              color: Vec4(c.x, c.y, c.z, 1), fog: nil)
        }
    }
}
#endif
