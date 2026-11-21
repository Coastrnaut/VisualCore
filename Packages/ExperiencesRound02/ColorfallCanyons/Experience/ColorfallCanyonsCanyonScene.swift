// ColorfallCanyonsCanyonScene — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-001 … 004, 007; clarifications
// Q1–Q4). Draws one `ColorfallCanyonsSceneSnapshot` at one tier through the real GL path: the night clear; the terrain
// (blocks, rock slabs, drain pits and basin rims) with `ColorfallCanyonsShaders.terrain*`, opaque; the spring emitters and
// basin target arcs with the fluid program (one-hot colour weights, no flow), premultiplied alpha; the fluid sheets and
// falls with the fluid program, premultiplied alpha, their flow bands following `u_time` (held at 0 under Reduce Motion)
// with the tier's band count; and the tier's glow shells (the fluid sheets again with `u_shell` 1, additive: level-0 two,
// level-1 one, level-2 none). Depth testing is off on this path, so the order is the layering; back faces are culled
// (every face is wound counter-clockwise seen from its front), so a block's far side never covers its own top, and the
// rows are built far to near, so nearer blocks cover farther ones. Geometry is rebuilt only
// when the level, heights, fluid, valves, stage, tier or mode change; the bands move by a uniform. Reduce Flashing passes
// `ColorfallCanyonsShaders.glowLimit(reduceFlashing:)` as `u_glowLimit`. If a program fails, the scene falls back to the
// level-2 geometry drawn unlit with the shared `MeshRenderer` (ambient 1, per-vertex colours) and keeps the reason;
// nothing here can reach the kernel. Feature 344 (R02-G05-04) T-R02G0504-005 (FR-R02G0504-004, 005; research R5): the
// camera follows the gesture controller's orbit (`ColorfallCanyonsSceneGeometry.camera(_:aspect:orbit:)`), and the cell a
// drag would carve gets a pearl ring (`ColorfallCanyonsSceneGeometry.highlightPart(_:_:)`) drawn last with the terrain
// program (or, in the fallback, unlit with its per-vertex colour), so it stays visible over the fluid.
#if os(iOS)
import ColorfallCanyonsCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Colorfall Canyons.
@MainActor
final class ColorfallCanyonsCanyonScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The fluid fragment source (the tests' seam replaces it with a broken one before setup).
    var fluidFragment = ColorfallCanyonsShaders.fluidFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// The camera orbit (presentation only), set by the presenter before each frame.
    var orbit: ColorfallCanyonsOrbit = .authored
    /// The cell a drag in progress would carve, outlined in pearl; nil when no drag is in progress.
    var highlightedCell: Int?
    /// The eased light levels of the sheets, emitters and win glow (feature 346); nil draws feature 343's levels.
    var lights: ColorfallCanyonsLights?
    /// The light direction of the terrain (towards the light, from the upper left front).
    static let lightDirection = SIMD3<Float>(-0.4, 0.8, 0.45)

    /// What the geometry depends on: everything of the snapshot that the meshes read, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let heights: [Int]
        let masses: [[Int]]
        let valves: [Bool]
        let supplies: [Int]
        let stage: ColorfallCanyonsStage
        let tier: Int
        let fallback: Bool
        /// The eased lights (feature 346): while a fade runs they change every frame and the fluid is rebuilt.
        let lights: ColorfallCanyonsLights?
    }

    private var registry: ResourceRegistry?
    private var terrainRenderer: ShaderMeshRenderer?
    private var featureRenderer: ShaderMeshRenderer?
    private var fluidRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var highlightRenderer: ShaderMeshRenderer?
    private var highlightFallback: MeshRenderer?
    /// What the highlight ring was built for: the cell, the level and the heights (the ring sits on the block top).
    private var highlightKey: [Int]?
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
        terrainRenderer?.release()
        featureRenderer?.release()
        fluidRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        releaseHighlight()
        terrainRenderer = nil
        featureRenderer = nil
        fluidRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    private func releaseHighlight() {
        highlightRenderer?.release()
        highlightFallback?.release()
        highlightRenderer = nil
        highlightFallback = nil
        highlightKey = nil
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { ColorfallCanyonsShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the flow bands still.
    func render(_ snapshot: ColorfallCanyonsSceneSnapshot, tier: ColorfallCanyonsTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let night = ColorfallCanyonsPalette.night
        let clear = ClearColorScene(red: Float(night.x), green: Float(night.y), blue: Float(night.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = ColorfallCanyonsSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        let key = Self.key(snapshot, tier: tier, fallback: fallbackReason != nil, lights: lights)
        if key != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = Self.key(snapshot, tier: tier, fallback: fallbackReason != nil, lights: lights)
        if fallbackReason != nil {
            try drawFallback(camera)
            try drawHighlight(snapshot, camera: camera)
            return
        }
        let time = Float(animate ? snapshot.time : 0)
        let cell = Float(ColorfallCanyonsSceneGeometry.cellSize(snapshot))
        try drawTerrain(camera, unit: cell * Float(ColorfallCanyonsSceneGeometry.heightStep))
        try drawFluid(featureRenderer, camera: camera, cell: cell, time: time, bands: tier.flowBands,
                      gain: ColorfallCanyonsShaders.standardGlowGain, shell: false)
        try drawFluid(fluidRenderer, camera: camera, cell: cell, time: time, bands: tier.flowBands,
                      gain: ColorfallCanyonsShaders.standardGlowGain, shell: false)
        // Feature 346 (research R5): the win glow scales the shells' gain; `u_glowLimit` still caps it.
        let gain = ColorfallCanyonsShaders.glowGain(for: tier) * (1 + (lights?.glow ?? 0))
        if tier.glowShells > 0, gain > 0 {
            for _ in 0..<tier.glowShells {
                try drawFluid(fluidRenderer, camera: camera, cell: cell, time: time, bands: tier.flowBands, gain: gain,
                              shell: true)
            }
        }
        try drawHighlight(snapshot, camera: camera)
    }

    /// Draws the pearl ring of ``highlightedCell`` last, rebuilding it when the cell, level or heights change.
    private func drawHighlight(_ snapshot: ColorfallCanyonsSceneSnapshot, camera: ColorfallCanyonsCamera) throws {
        guard let cell = highlightedCell, (0..<snapshot.cellCount).contains(cell), let registry else {
            if highlightKey != nil { releaseHighlight() }
            return
        }
        let key = [cell, snapshot.levelNumber, fallbackReason == nil ? 0 : 1] + snapshot.heights
        if key != highlightKey {
            releaseHighlight()
            let part = try ColorfallCanyonsSceneGeometry.highlightPart(cell, snapshot)
            if fallbackReason == nil {
                highlightRenderer = try Self.renderer(part.mesh, vertex: ColorfallCanyonsShaders.terrainVertex,
                                                      fragment: ColorfallCanyonsShaders.terrainFragment,
                                                      name: "colorfall-canyons-terrain", registry: registry)
            } else {
                let renderer = try MeshRenderer(mesh: part.mesh, colors: part.colours, registry: registry)
                renderer.ambient = 1
                highlightFallback = renderer
            }
            highlightKey = key
        }
        if let highlightRenderer {
            let mvp = camera.viewProjection
            let eye = Self.float3(camera.eye)
            let unit = Float(ColorfallCanyonsSceneGeometry.cellSize(snapshot) * ColorfallCanyonsSceneGeometry.heightStep)
            try highlightRenderer.draw(blend: .opaque, cullBackFaces: true) { p in
                p.set(ColorfallCanyonsShaders.mvpUniform, matrix4: mvp.floats)
                p.set(ColorfallCanyonsShaders.modelUniform, matrix4: Mat4.identity.floats)
                p.set(ColorfallCanyonsShaders.eyeUniform, eye)
                p.set(ColorfallCanyonsShaders.unitUniform, unit)
                p.set(ColorfallCanyonsShaders.lightDirectionUniform, Self.lightDirection)
            }
        } else if let highlightFallback {
            try highlightFallback.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                                       color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }

    /// The geometry key of `snapshot` at `tier` in the given mode.
    private static func key(_ s: ColorfallCanyonsSceneSnapshot, tier: ColorfallCanyonsTier,
                            fallback: Bool, lights: ColorfallCanyonsLights?) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, heights: s.heights, masses: s.masses, valves: s.springs.map(\.open),
                    supplies: s.springs.map(\.supplyLeft), stage: s.stage, tier: tier.index, fallback: fallback,
                    lights: lights)
    }

    private func rebuild(_ snapshot: ColorfallCanyonsSceneSnapshot, tier: ColorfallCanyonsTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let terrain = try ColorfallCanyonsSceneGeometry.terrainMesh(snapshot, tier: tier)
                terrainRenderer = try Self.renderer(terrain, vertex: ColorfallCanyonsShaders.terrainVertex,
                                                    fragment: ColorfallCanyonsShaders.terrainFragment,
                                                    name: "colorfall-canyons-terrain", registry: registry)
                let feature = try ColorfallCanyonsSceneGeometry.featureMesh(snapshot, tier: tier, lights: lights)
                if !feature.indices.isEmpty {
                    featureRenderer = try Self.renderer(feature, vertex: ColorfallCanyonsShaders.fluidVertex,
                                                        fragment: fluidFragment, name: "colorfall-canyons-fluid",
                                                        registry: registry)
                }
                let fluid = try ColorfallCanyonsSceneGeometry.fluidMesh(snapshot, tier: tier, lights: lights)
                if !fluid.indices.isEmpty {
                    fluidRenderer = try Self.renderer(fluid, vertex: ColorfallCanyonsShaders.fluidVertex,
                                                      fragment: fluidFragment, name: "colorfall-canyons-fluid",
                                                      registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "colorfall-canyons shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its per-vertex colours.
        let minimal = ColorfallCanyonsTier.of(ColorfallCanyonsTier.all.count - 1)
        let up = Vec3(0, 1, 0)
        let parts: [(part: ColorfallCanyonsColouredMesh, colourInNormals: Bool)] = [
            (part: try ColorfallCanyonsSceneGeometry.terrainPart(snapshot, tier: minimal), colourInNormals: false),
            (part: try ColorfallCanyonsSceneGeometry.featurePart(snapshot, tier: minimal, lights: lights), colourInNormals: true),
            (part: try ColorfallCanyonsSceneGeometry.fluidPart(snapshot, tier: minimal, lights: lights), colourInNormals: true),
        ]
        for entry in parts where !entry.part.mesh.indices.isEmpty {
            var mesh = entry.part.mesh
            // The fluid meshes carry colour weights in the normal slot; the fallback reads the colour stream instead and
            // gets a real normal (lighting is off: ambient 1).
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

    private static func float3(_ v: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3<Float>(Float(v.x), Float(v.y), Float(v.z))
    }

    private func drawTerrain(_ camera: ColorfallCanyonsCamera, unit: Float) throws {
        guard let terrainRenderer else { return }
        let mvp = camera.viewProjection
        let eye = Self.float3(camera.eye)
        try terrainRenderer.draw(blend: .opaque, cullBackFaces: true) { p in
            p.set(ColorfallCanyonsShaders.mvpUniform, matrix4: mvp.floats)
            p.set(ColorfallCanyonsShaders.modelUniform, matrix4: Mat4.identity.floats)
            p.set(ColorfallCanyonsShaders.eyeUniform, eye)
            p.set(ColorfallCanyonsShaders.unitUniform, unit)
            p.set(ColorfallCanyonsShaders.lightDirectionUniform, Self.lightDirection)
        }
    }

    private func drawFluid(_ renderer: ShaderMeshRenderer?, camera: ColorfallCanyonsCamera, cell: Float, time: Float,
                           bands: Int, gain: Double, shell: Bool) throws {
        guard let renderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try renderer.draw(blend: shell ? .additive : .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(ColorfallCanyonsShaders.mvpUniform, matrix4: mvp.floats)
            p.set(ColorfallCanyonsShaders.cellUniform, cell)
            p.set(ColorfallCanyonsShaders.timeUniform, time)
            p.set(ColorfallCanyonsShaders.flowBandsUniform, Float(bands))
            p.set(ColorfallCanyonsShaders.glowGainUniform, Float(gain))
            p.set(ColorfallCanyonsShaders.glowLimitUniform, limit)
            p.set(ColorfallCanyonsShaders.shellUniform, Float(shell ? 1 : 0))
        }
    }

    private func drawFallback(_ camera: ColorfallCanyonsCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
