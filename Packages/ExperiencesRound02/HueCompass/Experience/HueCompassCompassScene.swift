// HueCompassCompassScene — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-001 … 004, 007; clarifications
// Q1–Q4). Draws one `HueCompassSceneSnapshot` at one tier through the real GL path: the night clear; the wheel (ticks,
// the 24 band segments and their glyphs) with `HueCompassShaders.solid*` at `u_fog` 0, opaque; the fog prisms with the
// same program at `u_fog` 1, premultiplied alpha (brightness scales alpha; the drift follows `u_time`, held at 0 under
// Reduce Motion); the faceted glass needle with `HueCompassShaders.glass*` in pearl (the mesh is built at the snapshot's
// bearing, so its model matrix is the identity); the tier's glow shells (the needle again, scaled about its middle with
// `u_shell` 1, additive: level-0 two, level-1 one, level-2 none); and last the marks as glass, one draw per kind (pearl
// probe marks, the ember selection mark, the sapphire target ring once the play has ended). Depth testing is off on this
// path, so the order is the layering. Geometry is rebuilt only when the level, bearing, clues, selection, stage, tier or
// mode change; the fog drift moves by a uniform. Reduce Flashing passes `HueCompassShaders.gainLimit(reduceFlashing:)`
// as `u_gainLimit`. If a program fails, the scene falls back to the level-2 geometry drawn unlit with the shared
// `MeshRenderer` (ambient 1, per-vertex colours) and keeps the reason; nothing here can reach the kernel.
#if os(iOS)
import Foundation
import HueCompassCore
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Hue Compass.
@MainActor
final class HueCompassCompassScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The glass fragment source (the tests' seam replaces it with a broken one before setup).
    var glassFragment = HueCompassShaders.glassFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false

    /// The fog's translucency (`u_opacity` of the fog draw); the brightness density / 9 scales it further.
    static let fogOpacity: Double = 0.85
    /// The scale of glow shell `n` (1 …) about the needle's middle: 1 + 0.12 n.
    static let shellGrowth: Double = 0.12

    /// The marks of one kind: the renderer and the base colour of its draw.
    private struct MarkDraw {
        let renderer: ShaderMeshRenderer
        let colour: SIMD3<Double>
    }

    /// What the geometry depends on: everything of the snapshot that the meshes read, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let offset: Int
        let fog: [Int]
        let bearing: Int
        let clues: [HueCompassClue]
        let selection: HueCompassSelection?
        let stage: HueCompassStage
        let target: Int?
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var wheelRenderer: ShaderMeshRenderer?
    private var fogRenderer: ShaderMeshRenderer?
    private var needleRenderer: ShaderMeshRenderer?
    private var markDraws: [MarkDraw] = []
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
        wheelRenderer?.release()
        fogRenderer?.release()
        needleRenderer?.release()
        for draw in markDraws { draw.renderer.release() }
        for renderer in fallbackRenderers { renderer.release() }
        wheelRenderer = nil
        fogRenderer = nil
        needleRenderer = nil
        markDraws = []
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The glow gain limit passed as `u_gainLimit`.
    var gainLimit: Double { HueCompassShaders.gainLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the fog drift still.
    func render(_ snapshot: HueCompassSceneSnapshot, tier: HueCompassTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let night = HueCompassPalette.night
        let clear = ClearColorScene(red: Float(night.x), green: Float(night.y), blue: Float(night.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = HueCompassSceneGeometry.camera(aspect: aspect)
        let key = Self.key(snapshot, tier: tier, fallback: fallbackReason != nil)
        if key != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = Self.key(snapshot, tier: tier, fallback: fallbackReason != nil)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let time = Float(animate ? snapshot.time : 0)
        try drawWheel(camera, time: time)
        try drawFog(camera, time: time)
        try drawNeedle(snapshot, tier: tier, camera: camera)
        try drawMarks(camera)
    }

    /// The geometry key of `snapshot` at `tier` in the given mode.
    private static func key(_ s: HueCompassSceneSnapshot, tier: HueCompassTier, fallback: Bool) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, offset: s.offset, fog: s.fog, bearing: s.bearing, clues: s.clues,
                    selection: s.selection, stage: s.stage, target: s.target, tier: tier.index, fallback: fallback)
    }

    private func rebuild(_ snapshot: HueCompassSceneSnapshot, tier: HueCompassTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let wheel = try HueCompassSceneGeometry.wheelPart(snapshot, tier: tier)
                wheelRenderer = try Self.solidRenderer(wheel.mesh, registry: registry)
                let fog = try HueCompassSceneGeometry.fogPart(snapshot, tier: tier)
                fogRenderer = try Self.solidRenderer(fog.mesh, registry: registry)
                let needle = try HueCompassSceneGeometry.needlePart(snapshot, tier: tier)
                needleRenderer = try Self.glassRenderer(needle.mesh, fragment: glassFragment, registry: registry)
                let marks = try HueCompassSceneGeometry.markPart(snapshot)
                for kind in Self.markKinds {
                    let part = Self.subset(marks.mesh, kind: kind.code)
                    guard !part.indices.isEmpty else { continue }
                    markDraws.append(MarkDraw(renderer: try Self.glassRenderer(part, fragment: glassFragment,
                                                                               registry: registry),
                                              colour: kind.colour))
                }
                return
            } catch {
                release()
                fallbackReason = "hue-compass shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its per-vertex colours.
        let minimal = HueCompassTier.of(HueCompassTier.all.count - 1)
        let up = Vec3(0, 0, 1)
        let wheel: HueCompassColouredMesh = try HueCompassSceneGeometry.wheelPart(snapshot, tier: minimal)
        let fog: HueCompassColouredMesh = try HueCompassSceneGeometry.fogPart(snapshot, tier: minimal)
        let needle: HueCompassColouredMesh = try HueCompassSceneGeometry.needlePart(snapshot, tier: minimal)
        let marks: HueCompassColouredMesh = try HueCompassSceneGeometry.markPart(snapshot)
        let parts: [(part: HueCompassColouredMesh, colourInNormals: Bool)] = [
            (part: wheel, colourInNormals: true),
            (part: fog, colourInNormals: true),
            (part: needle, colourInNormals: false),
            (part: marks, colourInNormals: false),
        ]
        for entry in parts where !entry.part.mesh.indices.isEmpty {
            var mesh = entry.part.mesh
            // The unlit meshes carry their colour in the normal slot; the fallback reads the colour stream instead and
            // gets a real normal (lighting is off: ambient 1).
            if entry.colourInNormals { mesh.normals = Array(repeating: up, count: mesh.positions.count) }
            let renderer = try MeshRenderer(mesh: mesh, colors: entry.part.colours, registry: registry)
            renderer.ambient = 1
            fallbackRenderers.append(renderer)
        }
    }

    /// The three mark kinds: their uv.y code and base colour.
    private static let markKinds: [(code: Double, colour: SIMD3<Double>)] = [
        (code: 0, colour: HueCompassPalette.pearl),
        (code: 0.5, colour: HueCompassPalette.ember),
        (code: 1, colour: HueCompassPalette.sapphire),
    ]

    /// The triangles of `mesh` whose first vertex has uv.y `code` (the mark kind), with every vertex kept.
    private static func subset(_ mesh: Mesh, kind code: Double) -> Mesh {
        var result = mesh
        var indices: [UInt32] = []
        var i = 0
        while i + 2 < mesh.indices.count {
            let first = Int(mesh.indices[i])
            if mesh.uvs.indices.contains(first), abs(mesh.uvs[first].y - code) < 0.25 {
                indices.append(mesh.indices[i])
                indices.append(mesh.indices[i + 1])
                indices.append(mesh.indices[i + 2])
            }
            i += 3
        }
        result.indices = indices
        return result
    }

    private static func glassRenderer(_ mesh: Mesh, fragment: String,
                                      registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: HueCompassShaders.glassVertex, fragment: fragment,
                               registry: registry, vertexName: "hue-compass-glass.vert",
                               fragmentName: "hue-compass-glass.frag")
    }

    private static func solidRenderer(_ mesh: Mesh, registry: ResourceRegistry) throws -> ShaderMeshRenderer {
        try ShaderMeshRenderer(mesh: mesh, vertex: HueCompassShaders.solidVertex,
                               fragment: HueCompassShaders.solidFragment, registry: registry,
                               vertexName: "hue-compass-solid.vert", fragmentName: "hue-compass-solid.frag")
    }

    private static func float3(_ v: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z))
    }

    private func drawWheel(_ camera: HueCompassCamera, time: Float) throws {
        guard let wheelRenderer else { return }
        let mvp = camera.viewProjection
        try wheelRenderer.draw(blend: .opaque) { p in
            p.set("u_mvp", matrix4: mvp.floats)
            p.set("u_time", time)
            p.set("u_fog", Float(0))
            p.set("u_opacity", Float(1))
        }
    }

    private func drawFog(_ camera: HueCompassCamera, time: Float) throws {
        guard let fogRenderer else { return }
        let mvp = camera.viewProjection
        try fogRenderer.draw(blend: .premultipliedAlpha) { p in
            p.set("u_mvp", matrix4: mvp.floats)
            p.set("u_time", time)
            p.set("u_fog", Float(1))
            p.set("u_opacity", Float(Self.fogOpacity))
        }
    }

    /// Sets the glass program's uniforms for one draw.
    private func setGlass(_ p: ShaderProgram, camera: HueCompassCamera, model: Mat4, colour: SIMD3<Double>,
                          shell: Bool) {
        p.set("u_mvp", matrix4: (camera.viewProjection * model).floats)
        p.set("u_model", matrix4: model.floats)
        p.set("u_eye", Self.float3(camera.eye))
        p.set("u_color", Self.float3(colour))
        p.set("u_opacity", Float(1))
        p.set("u_gain", Float(HueCompassShaders.standardGain))
        p.set("u_gainLimit", Float(gainLimit))
        p.set("u_shell", Float(shell ? 1 : 0))
    }

    /// The model matrix of glow shell `n` (1 …): a uniform scale of 1 + 0.12 n about the needle's middle.
    static func shellModel(_ snapshot: HueCompassSceneSnapshot, shell n: Int) -> Mat4 {
        let d = HueCompassSceneGeometry.direction(snapshot.bearing)
        let middle = d * (HueCompassSceneGeometry.needleLength / 2)
            + SIMD3<Double>(0, 0, HueCompassSceneGeometry.needleHeight)
        let s = 1 + shellGrowth * Double(n)
        let m = Vec3(middle.x, middle.y, middle.z)
        return Mat4.translation(m) * Mat4.scale(Vec3(s, s, s)) * Mat4.translation(Vec3(-m.x, -m.y, -m.z))
    }

    private func drawNeedle(_ snapshot: HueCompassSceneSnapshot, tier: HueCompassTier,
                            camera: HueCompassCamera) throws {
        guard let needleRenderer else { return }
        let pearl = HueCompassPalette.pearl
        try needleRenderer.draw(blend: .premultipliedAlpha) { p in
            self.setGlass(p, camera: camera, model: .identity, colour: pearl, shell: false)
        }
        guard tier.glowShells > 0 else { return }
        for n in 1...tier.glowShells {
            let model = Self.shellModel(snapshot, shell: n)
            try needleRenderer.draw(blend: .additive) { p in
                self.setGlass(p, camera: camera, model: model, colour: pearl, shell: true)
            }
        }
    }

    private func drawMarks(_ camera: HueCompassCamera) throws {
        for draw in markDraws {
            let colour = draw.colour
            try draw.renderer.draw(blend: .premultipliedAlpha) { p in
                self.setGlass(p, camera: camera, model: .identity, colour: colour, shell: false)
            }
        }
    }

    private func drawFallback(_ camera: HueCompassCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
