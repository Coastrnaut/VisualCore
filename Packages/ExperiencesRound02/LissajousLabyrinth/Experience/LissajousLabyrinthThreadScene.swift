// LissajousLabyrinthThreadScene — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-001 … 004, 007; clarifications
// Q1–Q4; research R1–R4). Draws one `LissajousLabyrinthSceneSnapshot` at one tier through the real GL path: the night
// clear, the obstacles as violet translucent icospheres with a rim (copper when the lap touches them), the checkpoints
// as copper rings facing the camera (dim, lit when visited in order, the next one brighter), the lap's thread with
// `LissajousLabyrinthShaders.thread*` (premultiplied; cobalt to violet, a brighter trail behind the head), the tier's
// glow passes (the same strip, additive) and the tracer head last. Geometry is rebuilt only when the level, dials, tier
// or aspect change; the head and trail move by uniforms. If a program fails, the scene falls back to the minimal tier's
// thread drawn with the shared unlit `MeshRenderer` and keeps the reason; nothing here can reach the kernel.
// Feature 314 (R02-G02-04) T-R02G0204-005 (FR-R02G0204-001, 004, 005): the camera follows the presenter's orbit; the
// four dial rings beside the stage (`LissajousLabyrinthHandles`) are cobalt annuli facing the authored eye with a copper
// knob at each dial's value; the selected dial gets a copper outline and a brighter knob, and a running turn's candidate
// is shown as a violet knob. Rings are rebuilt with the level; knobs, outline and preview are small per-frame meshes.
#if os(iOS)
import Foundation
import LissajousLabyrinthCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Lissajous Labyrinth.
@MainActor
final class LissajousLabyrinthThreadScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The thread fragment source (the tests' seam replaces it with a broken one before setup).
    var threadFragment = LissajousLabyrinthShaders.threadFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// The glow gain without and with the cap.
    static let glowGain = 2.0
    static let reducedGlowGain = 0.6
    /// The camera orbit (presentation only; feature 314).
    var orbit: LissajousLabyrinthOrbit = .authored
    /// The selected dial, outlined (feature 314).
    var selectedDial: LissajousLabyrinthDial = .frequencyA
    /// The candidate of a running turn, drawn as a violet knob; nil when no turn runs (feature 314).
    var preview: LissajousLabyrinthAction?
    /// The half width of a dial ring's band and of the selection outline's band, as fractions of the ring radius.
    static let ringBand = 0.06
    static let outlineBand = 0.05
    /// The selection outline's radius as a fraction of the ring radius: inside the ring and clear of its knobs (which
    /// reach in to 0.75), so the outline stays within the content sphere the camera frames (ring plus knob, 1.25).
    static let outlineScale = 0.6

    private var registry: ResourceRegistry?
    private var threadRenderer: ShaderMeshRenderer?
    private var ringRenderers: [ShaderMeshRenderer] = []
    private var sphereRenderers: [ShaderMeshRenderer] = []
    private var dialRingRenderers: [ShaderMeshRenderer] = []
    private var fallbackRenderer: MeshRenderer?
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
        threadRenderer?.release()
        for r in ringRenderers { r.release() }
        for r in sphereRenderers { r.release() }
        for r in dialRingRenderers { r.release() }
        fallbackRenderer?.release()
        threadRenderer = nil
        ringRenderers = []
        sphereRenderers = []
        dialRingRenderers = []
        fallbackRenderer = nil
        geometryKey = nil
    }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the shimmer still.
    func render(_ snapshot: LissajousLabyrinthSceneSnapshot, tier: LissajousLabyrinthTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let night = LissajousLabyrinthPalette.night
        let clear = ClearColorScene(red: Float(night.x), green: Float(night.y), blue: Float(night.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let viewProjection = LissajousLabyrinthSceneGeometry.viewProjection(aspect: aspect, snapshot: snapshot,
                                                                            orbit: orbit)
        let key = Self.key(snapshot, tier: tier, aspect: aspect, fallback: fallbackReason != nil)
        if key != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = key
        if fallbackReason != nil {
            try drawFallback(snapshot)
            return
        }
        try drawSpheres(snapshot, viewProjection: viewProjection)
        try drawRings(snapshot, viewProjection: viewProjection)
        try drawThread(snapshot, tier: tier, viewProjection: viewProjection, aspect: aspect, animate: animate)
        try drawHead(snapshot, viewProjection: viewProjection)
        try drawDials(snapshot, viewProjection: viewProjection)
    }

    /// The geometry key: level, dials, tier, aspect and mode.
    static func key(_ s: LissajousLabyrinthSceneSnapshot, tier: LissajousLabyrinthTier, aspect: Double,
                    fallback: Bool) -> Int {
        var h = Hasher()
        h.combine(s.level.fingerprint)
        h.combine(s.dials)
        h.combine(tier.index)
        h.combine(aspect)
        h.combine(fallback)
        return h.finalize()
    }

    private func rebuild(_ snapshot: LissajousLabyrinthSceneSnapshot, tier: LissajousLabyrinthTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        let view = LissajousLabyrinthSceneGeometry.viewDirection
        if fallbackReason == nil {
            do {
                let thread = try LissajousLabyrinthSceneGeometry.threadMesh(snapshot, tier: tier)
                threadRenderer = try ShaderMeshRenderer(mesh: thread, vertex: LissajousLabyrinthShaders.threadVertex,
                                                        fragment: threadFragment, registry: registry,
                                                        vertexName: "lissajous-labyrinth-thread.vert",
                                                        fragmentName: "lissajous-labyrinth-thread.frag")
                for ball in snapshot.level.checkpoints {
                    let ring = try LissajousLabyrinthSceneGeometry.ringMesh(ball, viewDirection: view)
                    ringRenderers.append(try Self.solidRenderer(ring, registry: registry))
                }
                for ball in snapshot.level.obstacles {
                    let sphere = try LissajousLabyrinthSceneGeometry.sphereMesh(ball)
                    sphereRenderers.append(try Self.solidRenderer(sphere, registry: registry))
                }
                let ringRadius = LissajousLabyrinthHandles.ringRadius(level: snapshot.level)
                for dial in LissajousLabyrinthDial.allCases {
                    let centre = LissajousLabyrinthHandles.ringCentre(dial, level: snapshot.level)
                    let ring = try Self.annulus(centre: centre, radius: ringRadius, band: ringRadius * Self.ringBand)
                    dialRingRenderers.append(try Self.solidRenderer(ring, registry: registry))
                }
                return
            } catch {
                release()
                fallbackReason = "lissajous-labyrinth shader: \(error)"
            }
        }
        // Fallback: the minimal tier's thread, unlit, in cobalt.
        let minimal = LissajousLabyrinthTier.of(LissajousLabyrinthTier.all.count - 1)
        let mesh = try LissajousLabyrinthSceneGeometry.threadMesh(snapshot, tier: minimal)
        fallbackRenderer = try MeshRenderer(mesh: mesh, registry: registry)
    }

    private static func solidRenderer(_ mesh: Mesh, registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: LissajousLabyrinthShaders.solidVertex,
                               fragment: LissajousLabyrinthShaders.solidFragment, registry: registry,
                               vertexName: "lissajous-labyrinth-solid.vert",
                               fragmentName: "lissajous-labyrinth-solid.frag")
    }

    private static func float3(_ v: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z))
    }

    private func drawSpheres(_ snapshot: LissajousLabyrinthSceneSnapshot, viewProjection: Mat4) throws {
        let view = LissajousLabyrinthSceneGeometry.viewDirection
        for (index, renderer) in sphereRenderers.enumerated() {
            let touched = snapshot.contactObstacle == index
            let colour = touched ? LissajousLabyrinthPalette.copper : LissajousLabyrinthPalette.violet
            try renderer.draw(blend: .premultipliedAlpha) { p in
                p.set("u_mvp", matrix4: viewProjection.floats)
                p.set("u_color", Self.float3(colour))
                p.set("u_lit", Float(touched ? 1 : 0))
                p.set("u_opacity", Float(0.45))
                p.set("u_rim", Float(1))
                p.set("u_viewDir", SIMD3<Float>(Float(view.x), Float(view.y), Float(view.z)))
            }
        }
    }

    private func drawRings(_ snapshot: LissajousLabyrinthSceneSnapshot, viewProjection: Mat4) throws {
        let view = LissajousLabyrinthSceneGeometry.viewDirection
        for (index, renderer) in ringRenderers.enumerated() {
            let lit: Float = snapshot.visited(index) ? 1 : (snapshot.nextCheckpoint == index ? 0.5 : 0)
            try renderer.draw(blend: .opaque) { p in
                p.set("u_mvp", matrix4: viewProjection.floats)
                p.set("u_color", Self.float3(LissajousLabyrinthPalette.copper))
                p.set("u_lit", lit)
                p.set("u_opacity", Float(1))
                p.set("u_rim", Float(0))
                p.set("u_viewDir", SIMD3<Float>(Float(view.x), Float(view.y), Float(view.z)))
            }
        }
    }

    private func drawThread(_ snapshot: LissajousLabyrinthSceneSnapshot, tier: LissajousLabyrinthTier,
                            viewProjection: Mat4, aspect: Double, animate: Bool) throws {
        guard let threadRenderer else { return }
        let fade = LissajousLabyrinthSceneGeometry.depthRange(aspect: aspect, snapshot: snapshot, orbit: orbit)
        let head = Float(LissajousLabyrinthShaders.headFraction(tick: snapshot.headTick))
        let trail = Float(LissajousLabyrinthShaders.trailFraction(tier))
        let time = animate ? Float(snapshot.time.truncatingRemainder(dividingBy: 1_000)) : 0
        let gain = reducedFlash ? Self.reducedGlowGain : Self.glowGain
        let setCommon: (ShaderProgram) -> Void = { p in
            p.set("u_mvp", matrix4: viewProjection.floats)
            p.set("u_fadeNear", Float(fade.near))
            p.set("u_fadeFar", Float(fade.far))
            p.set("u_head", head)
            p.set("u_trail", trail)
            p.set("u_time", time)
            p.set("u_cobalt", Self.float3(LissajousLabyrinthPalette.cobalt))
            p.set("u_violet", Self.float3(LissajousLabyrinthPalette.violet))
            p.set("u_copper", Self.float3(LissajousLabyrinthPalette.copper))
        }
        try threadRenderer.draw(blend: .premultipliedAlpha) { p in
            setCommon(p)
            p.set("u_glow", Float(0))
            p.set("u_opacity", Float(1))
        }
        for pass in 0..<tier.glowPasses {
            try threadRenderer.draw(blend: .additive) { p in
                setCommon(p)
                p.set("u_glow", Float(gain) / Float(pass + 2))
                p.set("u_opacity", Float(0.3))
            }
        }
    }

    private func drawHead(_ snapshot: LissajousLabyrinthSceneSnapshot, viewProjection: Mat4) throws {
        guard let registry else { return }
        let view = LissajousLabyrinthSceneGeometry.viewDirection
        let disc = try LissajousLabyrinthSceneGeometry.headMesh(
            position: LissajousLabyrinthSceneGeometry.headPosition(snapshot), viewDirection: view)
        let renderer = try Self.solidRenderer(disc, registry: registry)
        defer { renderer.release() }
        try renderer.draw(blend: .opaque) { p in
            p.set("u_mvp", matrix4: viewProjection.floats)
            p.set("u_color", Self.float3(LissajousLabyrinthPalette.copper))
            p.set("u_lit", Float(1))
            p.set("u_opacity", Float(1))
            p.set("u_rim", Float(0))
            p.set("u_viewDir", SIMD3<Float>(Float(view.x), Float(view.y), Float(view.z)))
        }
    }

    /// A flat annulus in the plane of the dial rings (spanned by `LissajousLabyrinthHandles.right` and `.up`), centred
    /// at `centre` with mid radius `radius` and half band `band`, 48 segments, wound to face the authored eye.
    static func annulus(centre: Vec3, radius: Double, band: Double, segments: Int = 48) throws -> Mesh {
        let right = LissajousLabyrinthHandles.right, up = LissajousLabyrinthHandles.up
        let normal = right.cross(up).normalized
        var builder = MeshBuilder()
        var ids: [UInt32] = []
        for i in 0..<segments {
            let theta = 2 * Double.pi * Double(i) / Double(segments)
            let direction = up * cos(theta) + right * sin(theta)
            let u = Double(i) / Double(segments)
            ids.append(try builder.vertex(centre + direction * (radius - band), normal: normal, uv: Vec2(u, 0)))
            ids.append(try builder.vertex(centre + direction * (radius + band), normal: normal, uv: Vec2(u, 1)))
        }
        for i in 0..<segments {
            let j = (i + 1) % segments
            // Angles run up → right (clockwise seen from the eye), so (inner i, inner j, outer i) and
            // (inner j, outer j, outer i) have geometric normals along right × up, towards the eye.
            try builder.triangle(ids[2 * i], ids[2 * j], ids[2 * i + 1])
            try builder.triangle(ids[2 * j], ids[2 * j + 1], ids[2 * i + 1])
        }
        return builder.build()
    }

    private func drawDials(_ snapshot: LissajousLabyrinthSceneSnapshot, viewProjection: Mat4) throws {
        guard let registry, dialRingRenderers.count == 4 else { return }
        let view = LissajousLabyrinthSceneGeometry.viewDirection
        let viewDir = SIMD3<Float>(Float(view.x), Float(view.y), Float(view.z))
        let level = snapshot.level
        func solid(_ renderer: ShaderMeshRenderer, _ colour: SIMD3<Double>, lit: Float) throws {
            try renderer.draw(blend: .opaque) { p in
                p.set("u_mvp", matrix4: viewProjection.floats)
                p.set("u_color", Self.float3(colour))
                p.set("u_lit", lit)
                p.set("u_opacity", Float(1))
                p.set("u_rim", Float(0))
                p.set("u_viewDir", viewDir)
            }
        }
        for (index, dial) in LissajousLabyrinthDial.allCases.enumerated() {
            try solid(dialRingRenderers[index], LissajousLabyrinthPalette.cobalt, lit: dial == selectedDial ? 0.6 : 0.2)
        }
        let ringRadius = LissajousLabyrinthHandles.ringRadius(level: level)
        let outline = try Self.annulus(centre: LissajousLabyrinthHandles.ringCentre(selectedDial, level: level),
                                       radius: ringRadius * Self.outlineScale,
                                       band: ringRadius * Self.outlineBand)
        let outlineRenderer = try Self.solidRenderer(outline, registry: registry)
        defer { outlineRenderer.release() }
        try solid(outlineRenderer, LissajousLabyrinthPalette.copper, lit: 1)
        let knobRadius = LissajousLabyrinthHandles.knobRadius(level: level)
        for dial in LissajousLabyrinthDial.allCases {
            let position = LissajousLabyrinthHandles.knob(dial, value: snapshot.dials[dial], level: level)
            let disc = try LissajousLabyrinthSceneGeometry.headMesh(position: position, radius: knobRadius,
                                                                    viewDirection: view)
            let renderer = try Self.solidRenderer(disc, registry: registry)
            defer { renderer.release() }
            try solid(renderer, LissajousLabyrinthPalette.copper, lit: dial == selectedDial ? 1 : 0.4)
        }
        if let preview {
            let position = LissajousLabyrinthHandles.knob(preview.dial, value: preview.value, level: level)
            let disc = try LissajousLabyrinthSceneGeometry.headMesh(position: position, radius: knobRadius * 0.8,
                                                                    viewDirection: view)
            let renderer = try Self.solidRenderer(disc, registry: registry)
            defer { renderer.release() }
            try solid(renderer, LissajousLabyrinthPalette.violet, lit: 1)
        }
    }

    private func drawFallback(_ snapshot: LissajousLabyrinthSceneSnapshot) throws {
        guard let fallbackRenderer else { return }
        let viewProjection = LissajousLabyrinthSceneGeometry.viewProjection(aspect: aspect, snapshot: snapshot,
                                                                            orbit: orbit)
        let c = LissajousLabyrinthPalette.cobalt
        try fallbackRenderer.draw(model: .identity, view: .identity, projection: viewProjection,
                                  color: Vec4(c.x, c.y, c.z, 1), fog: nil)
    }
}
#endif
