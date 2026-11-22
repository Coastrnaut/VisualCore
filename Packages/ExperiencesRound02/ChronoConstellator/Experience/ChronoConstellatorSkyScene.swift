// ChronoConstellatorSkyScene — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-001 … 004, 007; clarifications
// Q1–Q4). Draws one `ChronoConstellatorSceneSnapshot` at one tier through the real GL path: the indigo clear; the field
// (quad, grid lines, silver tracks, target rings with their shapes, hold bars and the amber collision cross) with
// `ChronoConstellatorShaders.field*`, opaque; the star nodes and lit-ring glows with the glow program, premultiplied
// alpha; the history ribbons with the glow program, premultiplied alpha, their alpha falling as 1 − age/R and their
// shimmer following `u_time` (held at 0 under Reduce Motion); and the tier's glow shells (the ribbons again with `u_shell`
// 1, additive: level-0 two, level-1 one, level-2 none). Depth testing is off on this path, so the order is the layering;
// back faces are culled on every draw (every face is wound counter-clockwise seen from its front; the hold bars are
// two-sided). Geometry is rebuilt only when the level, star cells, history, timeline, stage, failure, tier or mode change;
// the shimmer moves by a uniform. Reduce Flashing passes `ChronoConstellatorShaders.glowLimit(reduceFlashing:)` as
// `u_glowLimit`. If a program fails, the scene falls back to the level-2 geometry drawn unlit with the shared
// `MeshRenderer` (ambient 1, per-vertex colours) and keeps the reason; nothing here can reach the kernel.
// Feature 354 (R02-G06-04) T-R02G0604-005 (FR-R02G0604-005, 006; research R6): the camera follows the gesture
// controller's orbit (`ChronoConstellatorSceneGeometry.camera(_:aspect:orbit:)`), and the cell a star drag would start
// the star on gets a ring (`ChronoConstellatorSceneGeometry.candidatePart(_:_:)`) drawn after the field with the field
// program (or unlit in the fallback).
#if os(iOS)
import ChronoConstellatorCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Chrono Constellator.
@MainActor
final class ChronoConstellatorSkyScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The field fragment source (the tests' seam replaces it with a broken one before setup).
    var fieldFragment = ChronoConstellatorShaders.fieldFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// The camera orbit (presentation only), set by the presenter before each frame.
    var orbit: ChronoConstellatorOrbit = .authored
    /// The cell a star drag would start the star on, set by the presenter before each frame.
    var candidateCell: Int?
    /// The light direction of the field (towards the light, from the upper left front).
    static let lightDirection = SIMD3<Float>(-0.4, 0.8, 0.45)

    /// What the geometry depends on: everything of the snapshot that the meshes read, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let histories: [[Int]]
        let phases: [Int]
        let holds: [ChronoConstellatorHold]
        let stage: ChronoConstellatorStage
        let failure: ChronoConstellatorFailure?
        let tick: Int
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var fieldRenderer: ShaderMeshRenderer?
    private var starRenderer: ShaderMeshRenderer?
    private var ribbonRenderer: ShaderMeshRenderer?
    private var fallbackRenderers: [MeshRenderer] = []
    private var candidateRenderer: ShaderMeshRenderer?
    private var candidateFallback: MeshRenderer?
    /// What the candidate ring was built for: the cell, the level and the mode.
    private var candidateKey: [Int]?
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
        fieldRenderer?.release()
        starRenderer?.release()
        ribbonRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        fieldRenderer = nil
        starRenderer = nil
        ribbonRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
        releaseCandidate()
    }

    private func releaseCandidate() {
        candidateRenderer?.release()
        candidateFallback?.release()
        candidateRenderer = nil
        candidateFallback = nil
        candidateKey = nil
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { ChronoConstellatorShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the shimmer still.
    func render(_ snapshot: ChronoConstellatorSceneSnapshot, tier: ChronoConstellatorTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let field = ChronoConstellatorPalette.field
        let clear = ClearColorScene(red: Float(field.x), green: Float(field.y), blue: Float(field.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = ChronoConstellatorSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        let key = Self.key(snapshot, tier: tier, fallback: fallbackReason != nil)
        if key != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = Self.key(snapshot, tier: tier, fallback: fallbackReason != nil)
        if fallbackReason != nil {
            try drawFallback(camera)
            try drawCandidate(snapshot, camera: camera)
            return
        }
        let time = Float(animate ? snapshot.time : 0)
        let cell = Float(ChronoConstellatorSceneGeometry.cellSize(snapshot))
        try drawField(camera, cell: cell)
        try drawCandidate(snapshot, camera: camera)
        let gain = ChronoConstellatorShaders.glowGain(for: tier)
        try drawGlow(starRenderer, camera: camera, time: time, ticks: tier.ribbonTicks, animate: animate,
                     gain: gain, shell: false)
        try drawGlow(ribbonRenderer, camera: camera, time: time, ticks: tier.ribbonTicks, animate: animate,
                     gain: gain, shell: false)
        guard tier.glowShells > 0, gain > 0 else { return }
        for _ in 0..<tier.glowShells {
            try drawGlow(ribbonRenderer, camera: camera, time: time, ticks: tier.ribbonTicks, animate: animate,
                         gain: gain, shell: true)
        }
    }

    /// The geometry key of `snapshot` at `tier` in the given mode.
    private static func key(_ s: ChronoConstellatorSceneSnapshot, tier: ChronoConstellatorTier,
                            fallback: Bool) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, histories: s.stars.map(\.history), phases: s.phases, holds: s.holds,
                    stage: s.stage, failure: s.failure, tick: s.tick, tier: tier.index, fallback: fallback)
    }

    private func rebuild(_ snapshot: ChronoConstellatorSceneSnapshot, tier: ChronoConstellatorTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let field = try ChronoConstellatorSceneGeometry.fieldMesh(snapshot, tier: tier)
                fieldRenderer = try Self.renderer(field, vertex: ChronoConstellatorShaders.fieldVertex,
                                                  fragment: fieldFragment, name: "chrono-constellator-field",
                                                  registry: registry)
                let stars = try ChronoConstellatorSceneGeometry.starMesh(snapshot, tier: tier)
                if !stars.indices.isEmpty {
                    starRenderer = try Self.renderer(stars, vertex: ChronoConstellatorShaders.glowVertex,
                                                     fragment: ChronoConstellatorShaders.glowFragment,
                                                     name: "chrono-constellator-glow", registry: registry)
                }
                let ribbons = try ChronoConstellatorSceneGeometry.ribbonMesh(snapshot, tier: tier)
                if !ribbons.indices.isEmpty {
                    ribbonRenderer = try Self.renderer(ribbons, vertex: ChronoConstellatorShaders.glowVertex,
                                                       fragment: ChronoConstellatorShaders.glowFragment,
                                                       name: "chrono-constellator-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "chrono-constellator shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its per-vertex colours.
        let minimal = ChronoConstellatorTier.of(ChronoConstellatorTier.all.count - 1)
        let up = Vec3(0, 1, 0)
        let parts: [(part: ChronoConstellatorColouredMesh, colourInNormals: Bool)] = [
            (part: try ChronoConstellatorSceneGeometry.fieldPart(snapshot, tier: minimal), colourInNormals: false),
            (part: try ChronoConstellatorSceneGeometry.starPart(snapshot, tier: minimal), colourInNormals: true),
            (part: try ChronoConstellatorSceneGeometry.ribbonPart(snapshot, tier: minimal), colourInNormals: true),
        ]
        for entry in parts where !entry.part.mesh.indices.isEmpty {
            var mesh = entry.part.mesh
            // The glow meshes carry colours in the normal slot; the fallback reads the colour stream instead and gets a
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

    private func drawField(_ camera: ChronoConstellatorCamera, cell: Float) throws {
        guard let fieldRenderer else { return }
        let mvp = camera.viewProjection
        try fieldRenderer.draw(blend: .opaque, cullBackFaces: true) { p in
            p.set(ChronoConstellatorShaders.mvpUniform, matrix4: mvp.floats)
            p.set(ChronoConstellatorShaders.cellUniform, cell)
            p.set(ChronoConstellatorShaders.lightDirectionUniform, Self.lightDirection)
        }
    }

    /// Draws the ring of ``candidateCell`` after the field, rebuilding it when the cell, level or mode change.
    private func drawCandidate(_ snapshot: ChronoConstellatorSceneSnapshot, camera: ChronoConstellatorCamera) throws {
        guard let cell = candidateCell, cell >= 0, cell < snapshot.columns * snapshot.rows, let registry else {
            if candidateKey != nil { releaseCandidate() }
            return
        }
        let key = [cell, snapshot.levelNumber, fallbackReason == nil ? 0 : 1]
        if key != candidateKey {
            releaseCandidate()
            let part = try ChronoConstellatorSceneGeometry.candidatePart(cell, snapshot)
            if fallbackReason == nil {
                candidateRenderer = try Self.renderer(part.mesh, vertex: ChronoConstellatorShaders.fieldVertex,
                                                      fragment: fieldFragment, name: "chrono-constellator-field",
                                                      registry: registry)
            } else {
                let renderer = try MeshRenderer(mesh: part.mesh, colors: part.colours, registry: registry)
                renderer.ambient = 1
                candidateFallback = renderer
            }
            candidateKey = key
        }
        if let candidateRenderer {
            let mvp = camera.viewProjection
            let unit = Float(ChronoConstellatorSceneGeometry.cellSize(snapshot))
            try candidateRenderer.draw(blend: .opaque, cullBackFaces: true) { p in
                p.set(ChronoConstellatorShaders.mvpUniform, matrix4: mvp.floats)
                p.set(ChronoConstellatorShaders.cellUniform, unit)
                p.set(ChronoConstellatorShaders.lightDirectionUniform, Self.lightDirection)
            }
        } else if let candidateFallback {
            try candidateFallback.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                                       color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }

    private func drawGlow(_ renderer: ShaderMeshRenderer?, camera: ChronoConstellatorCamera, time: Float, ticks: Int,
                          animate: Bool, gain: Double, shell: Bool) throws {
        guard let renderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try renderer.draw(blend: shell ? .additive : .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(ChronoConstellatorShaders.mvpUniform, matrix4: mvp.floats)
            p.set(ChronoConstellatorShaders.timeUniform, time)
            p.set(ChronoConstellatorShaders.reduceMotionUniform, Float(animate ? 0 : 1))
            p.set(ChronoConstellatorShaders.ribbonTicksUniform, Float(ticks))
            p.set(ChronoConstellatorShaders.glowGainUniform, Float(gain))
            p.set(ChronoConstellatorShaders.glowLimitUniform, limit)
            p.set(ChronoConstellatorShaders.shellUniform, Float(shell ? 1 : 0))
        }
    }

    private func drawFallback(_ camera: ChronoConstellatorCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
