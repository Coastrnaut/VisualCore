// WaveKnotKeeperRopeScene — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-001 … 004, 007; clarifications Q1–Q4;
// research R1–R4). Draws one `WaveKnotKeeperSceneSnapshot` at one tier through the real GL path: the night clear, the
// rope's glass tube with `WaveKnotKeeperShaders.rope*` (premultiplied; pearl and sapphire with a fresnel rim, ember
// caustic pulses on over-strands at projected crossings), the tier's glow shells (the same program on wider tubes,
// additive), the handles as pearl icospheres (ember when selected) over the rope and the crossing gates last as
// translucent sapphire cubes with bright edges. Geometry is rebuilt only when the points, gates, tier or aspect change; the pulses move by a
// uniform. If a program fails, the scene falls back to the minimal tier's tube drawn with the shared unlit `MeshRenderer`
// and keeps the reason; nothing here can reach the kernel.
#if os(iOS)
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import WaveKnotKeeperCore

/// The GL scene of Wave Knot Keeper.
@MainActor
final class WaveKnotKeeperRopeScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The rope fragment source (the tests' seam replaces it with a broken one before setup).
    var ropeFragment = WaveKnotKeeperShaders.ropeFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false

    private var registry: ResourceRegistry?
    private var ropeRenderer: ShaderMeshRenderer?
    private var glowRenderer: ShaderMeshRenderer?
    private var handleRenderer: ShaderMeshRenderer?
    private var gateRenderers: [ShaderMeshRenderer] = []
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
        ropeRenderer?.release()
        glowRenderer?.release()
        handleRenderer?.release()
        for r in gateRenderers { r.release() }
        fallbackRenderer?.release()
        ropeRenderer = nil
        glowRenderer = nil
        handleRenderer = nil
        gateRenderers = []
        fallbackRenderer = nil
        geometryKey = nil
    }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the pulses still.
    func render(_ snapshot: WaveKnotKeeperSceneSnapshot, tier: WaveKnotKeeperTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let night = WaveKnotKeeperPalette.night
        let clear = ClearColorScene(red: Float(night.x), green: Float(night.y), blue: Float(night.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = WaveKnotKeeperSceneGeometry.camera(for: snapshot, aspect: aspect)
        let key = Self.key(snapshot, tier: tier, aspect: aspect, fallback: fallbackReason != nil)
        if key != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = key
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        // Depth testing is off on this path, so the order is the layering: rope and glow, then the handles over the
        // rope (each handle sits on its control point, inside the tube), then the translucent gates.
        try drawRope(snapshot, tier: tier, camera: camera, animate: animate)
        try drawHandles(snapshot, camera: camera)
        try drawGates(snapshot, camera: camera)
    }

    /// The geometry key: points, gates, tier, aspect and mode.
    static func key(_ s: WaveKnotKeeperSceneSnapshot, tier: WaveKnotKeeperTier, aspect: Double, fallback: Bool) -> Int {
        var h = Hasher()
        h.combine(s.points)
        h.combine(s.gates)
        h.combine(tier.index)
        h.combine(aspect)
        h.combine(fallback)
        return h.finalize()
    }

    private func rebuild(_ snapshot: WaveKnotKeeperSceneSnapshot, tier: WaveKnotKeeperTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let rope = try WaveKnotKeeperSceneGeometry.ropeMesh(snapshot, tier: tier)
                ropeRenderer = try Self.ropeRenderer(rope, fragment: ropeFragment, registry: registry)
                if tier.glowShells > 0 {
                    let glow = try WaveKnotKeeperSceneGeometry.glowMesh(snapshot, tier: tier)
                    glowRenderer = try Self.ropeRenderer(glow, fragment: ropeFragment, registry: registry)
                }
                handleRenderer = try Self.solidRenderer(try WaveKnotKeeperSceneGeometry.handleMesh(), registry: registry)
                for gate in snapshot.gates {
                    gateRenderers.append(try Self.solidRenderer(try WaveKnotKeeperSceneGeometry.gateMesh(gate),
                                                                registry: registry))
                }
                return
            } catch {
                release()
                fallbackReason = "wave-knot-keeper shader: \(error)"
            }
        }
        // Fallback: the minimal tier's tube, unlit, in pearl.
        let minimal = WaveKnotKeeperTier.of(WaveKnotKeeperTier.all.count - 1)
        let mesh = try WaveKnotKeeperSceneGeometry.ropeMesh(snapshot, tier: minimal)
        fallbackRenderer = try MeshRenderer(mesh: mesh, registry: registry)
    }

    private static func ropeRenderer(_ mesh: Mesh, fragment: String,
                                     registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: WaveKnotKeeperShaders.ropeVertex, fragment: fragment,
                               registry: registry, vertexName: "wave-knot-keeper-rope.vert",
                               fragmentName: "wave-knot-keeper-rope.frag")
    }

    private static func solidRenderer(_ mesh: Mesh, registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: WaveKnotKeeperShaders.solidVertex,
                               fragment: WaveKnotKeeperShaders.solidFragment, registry: registry,
                               vertexName: "wave-knot-keeper-solid.vert",
                               fragmentName: "wave-knot-keeper-solid.frag")
    }

    private static func float3(_ v: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z))
    }

    /// The model-view-projection of a uniform scale `scale` and translation `offset` (the solid program's limit).
    private static func mvp(_ camera: WaveKnotKeeperCamera, offset: SIMD3<Double>, scale: Double = 1) -> Mat4 {
        let model = Mat4.translation(Vec3(offset.x, offset.y, offset.z)) * Mat4.scale(Vec3(scale, scale, scale))
        return camera.viewProjection * model
    }

    private func drawHandles(_ snapshot: WaveKnotKeeperSceneSnapshot, camera: WaveKnotKeeperCamera) throws {
        guard let handleRenderer else { return }
        let view = WaveKnotKeeperSceneGeometry.eyeDirection
        for (index, centre) in WaveKnotKeeperSceneGeometry.worldPoints(snapshot).enumerated() {
            let colour = snapshot.selected == index ? WaveKnotKeeperPalette.ember : WaveKnotKeeperPalette.pearl
            let mvp = Self.mvp(camera, offset: centre)
            try handleRenderer.draw(blend: .opaque) { p in
                p.set("u_mvp", matrix4: mvp.floats)
                p.set("u_color", Self.float3(colour))
                p.set("u_opacity", Float(1))
                p.set("u_rim", Float(0.5))
                p.set("u_viewDir", Self.float3(view))
                p.set("u_edge", Float(0))
                p.set("u_boxCenter", SIMD3<Float>(0, 0, 0))
                p.set("u_boxHalf", SIMD3<Float>(1, 1, 1))
            }
        }
    }

    private func drawRope(_ snapshot: WaveKnotKeeperSceneSnapshot, tier: WaveKnotKeeperTier,
                          camera: WaveKnotKeeperCamera, animate: Bool) throws {
        guard let ropeRenderer else { return }
        let pulse = Float(animate ? snapshot.pulse : 0.5)
        let gain = Float(WaveKnotKeeperShaders.gain(reduceFlashing: reducedFlash))
        let mvp = camera.viewProjection
        let setCommon: (ShaderProgram) -> Void = { p in
            p.set("u_mvp", matrix4: mvp.floats)
            p.set("u_eye", Self.float3(camera.eye))
            p.set("u_pulse", pulse)
            p.set("u_gain", gain)
            p.set("u_pearl", Self.float3(WaveKnotKeeperPalette.pearl))
            p.set("u_sapphire", Self.float3(WaveKnotKeeperPalette.sapphire))
            p.set("u_ember", Self.float3(WaveKnotKeeperPalette.ember))
        }
        try ropeRenderer.draw(blend: .premultipliedAlpha) { p in
            setCommon(p)
            p.set("u_shell", Float(0))
            p.set("u_opacity", Float(1))
        }
        if let glowRenderer {
            try glowRenderer.draw(blend: .additive) { p in
                setCommon(p)
                p.set("u_shell", Float(1))
                p.set("u_opacity", Float(1))
            }
        }
    }

    private func drawGates(_ snapshot: WaveKnotKeeperSceneSnapshot, camera: WaveKnotKeeperCamera) throws {
        let view = WaveKnotKeeperSceneGeometry.eyeDirection
        let mvp = camera.viewProjection
        for (index, renderer) in gateRenderers.enumerated() where snapshot.gates.indices.contains(index) {
            let gate = snapshot.gates[index]
            let centre = WaveKnotKeeperSceneGeometry.gateCentre(gate)
            let box = WaveKnotKeeperSceneGeometry.gateBox(gate)
            let half = (box.high - box.low) / 2
            try renderer.draw(blend: .premultipliedAlpha) { p in
                p.set("u_mvp", matrix4: mvp.floats)
                p.set("u_color", Self.float3(WaveKnotKeeperPalette.sapphire))
                p.set("u_opacity", Float(0.25))
                p.set("u_rim", Float(0))
                p.set("u_viewDir", Self.float3(view))
                p.set("u_edge", Float(1))
                p.set("u_boxCenter", Self.float3(centre))
                p.set("u_boxHalf", Self.float3(half))
            }
        }
    }

    private func drawFallback(_ camera: WaveKnotKeeperCamera) throws {
        guard let fallbackRenderer else { return }
        let c = WaveKnotKeeperPalette.pearl
        try fallbackRenderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                                  color: Vec4(c.x, c.y, c.z, 1), fog: nil)
    }
}
#endif
