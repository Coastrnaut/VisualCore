// AmethystEscapeCrystalScene — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-001 … 004, 007; clarifications
// Q1–Q4). Draws one `AmethystEscapeSceneSnapshot` at one tier through the real GL path: the backdrop clear; the crystal
// (backdrop plane, bevelled wedge prisms emitted back to front, platinum wall fins, dark blocked wedges with cross marks,
// the exit arrow and the move bar) with `AmethystEscapeShaders.crystal*`, premultiplied alpha so the amethyst facets are
// translucent (alpha 0.55) while every other material is opaque, their highlights following `u_time` (held at 0 under
// Reduce Motion); the pearl and the exit glow with the glow program, premultiplied alpha; and the tier's glow shells
// (the glow mesh again with `u_shell` 1, additive: level-0 two, level-1 one, level-2 none). Depth testing is off on this
// path, so the order is the layering; back faces are culled on every draw. Geometry is rebuilt only when the level,
// offsets, pearl, stage, failure, moves, tier or mode change; the highlights move by a uniform. Reduce Flashing passes
// `AmethystEscapeShaders.glowLimit(reduceFlashing:)` as `u_glowLimit`. If a program fails, the scene falls back to the
// level-2 geometry drawn unlit with the shared `MeshRenderer` (ambient 1, per-vertex colours) and keeps the reason;
// nothing here can reach the kernel.
// Feature 364 (R02-G07-04) T-R02G0704-006 (FR-R02G0704-003, 005, 006): the camera follows the gesture controller's
// orbit (`AmethystEscapeSceneGeometry.camera(_:aspect:orbit:)`), the snapshot drawn may be a drag preview (the presenter
// passes it), and an isolated shell leaves every other shell at shade 0.25 (`crystalMesh(_:tier:isolated:)`, also in
// the fallback).
#if os(iOS)
import AmethystEscapeCore
import Foundation
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The GL scene of Amethyst Escape.
@MainActor
final class AmethystEscapeCrystalScene {
    /// Why the scene draws the fallback; nil while the shader programs work.
    private(set) var fallbackReason: String?
    /// The crystal fragment source (the tests' seam replaces it with a broken one before setup).
    var crystalFragment = AmethystEscapeShaders.crystalFragment
    /// Whether the glow gain is capped (Reduce Flashing).
    var reducedFlash = false
    /// The light direction of the crystal (towards the light, from the upper left front).
    static let lightDirection = SIMD3<Float>(-0.4, 0.8, 0.45)
    /// The camera orbit (presentation only), set by the presenter before each frame.
    var orbit: AmethystEscapeOrbit = .authored
    /// The isolated shell (presentation only), set by the presenter before each frame.
    var isolated: Int?

    /// What the geometry depends on: everything of the snapshot that the meshes read, the tier and the mode.
    private struct GeometryKey: Equatable {
        let levelNumber: Int
        let offsets: [Int]
        let pearl: AmethystEscapePocket
        let stage: AmethystEscapeStage
        let failure: AmethystEscapeFailure?
        let moves: Int
        let isolated: Int?
        let tier: Int
        let fallback: Bool
    }

    private var registry: ResourceRegistry?
    private var crystalRenderer: ShaderMeshRenderer?
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
        crystalRenderer?.release()
        glowRenderer?.release()
        for renderer in fallbackRenderers { renderer.release() }
        crystalRenderer = nil
        glowRenderer = nil
        fallbackRenderers = []
        geometryKey = nil
    }

    /// The glow limit passed as `u_glowLimit`.
    var glowLimit: Double { AmethystEscapeShaders.glowLimit(reduceFlashing: reducedFlash) }

    /// Draws `snapshot` at `tier` into `context`'s framebuffer; `animate` false holds the highlights still.
    func render(_ snapshot: AmethystEscapeSceneSnapshot, tier: AmethystEscapeTier, context: RenderContext,
                frame: FrameInfo, animate: Bool) throws {
        GLState.resetForVisualCore(framebuffer: context.framebuffer, width: context.pixelWidth,
                                   height: context.pixelHeight)
        let backdrop = AmethystEscapePalette.backdrop
        let clear = ClearColorScene(red: Float(backdrop.x), green: Float(backdrop.y), blue: Float(backdrop.z))
        try clear.render(context, frame: frame)
        guard context.pixelWidth > 0, context.pixelHeight > 0 else { return }
        aspect = Double(context.pixelWidth) / Double(context.pixelHeight)
        let camera = AmethystEscapeSceneGeometry.camera(snapshot, aspect: aspect, orbit: orbit)
        let key = Self.key(snapshot, tier: tier, isolated: isolated, fallback: fallbackReason != nil)
        if key != geometryKey { try rebuild(snapshot, tier: tier) }
        geometryKey = Self.key(snapshot, tier: tier, isolated: isolated, fallback: fallbackReason != nil)
        if fallbackReason != nil {
            try drawFallback(camera)
            return
        }
        let time = Float(animate ? snapshot.time : 0)
        try drawCrystal(camera, time: time, layers: AmethystEscapeShaders.highlightLayers(for: tier))
        let gain = AmethystEscapeShaders.glowGain(for: tier)
        try drawGlow(camera, gain: gain, shell: false)
        guard tier.glowShells > 0, gain > 0 else { return }
        for _ in 0..<tier.glowShells { try drawGlow(camera, gain: gain, shell: true) }
    }

    /// The geometry key of `snapshot` at `tier` in the given mode.
    private static func key(_ s: AmethystEscapeSceneSnapshot, tier: AmethystEscapeTier, isolated: Int?,
                            fallback: Bool) -> GeometryKey {
        GeometryKey(levelNumber: s.levelNumber, offsets: s.shells.map(\.offset), pearl: s.pearl, stage: s.stage,
                    failure: s.failure, moves: s.moves, isolated: isolated, tier: tier.index, fallback: fallback)
    }

    private func rebuild(_ snapshot: AmethystEscapeSceneSnapshot, tier: AmethystEscapeTier) throws {
        guard let registry else { return }
        let keepFallback = fallbackReason
        release()
        fallbackReason = keepFallback
        if fallbackReason == nil {
            do {
                let crystal = try AmethystEscapeSceneGeometry.crystalMesh(snapshot, tier: tier, isolated: isolated)
                crystalRenderer = try Self.renderer(crystal, vertex: AmethystEscapeShaders.crystalVertex,
                                                    fragment: crystalFragment, name: "amethyst-escape-crystal",
                                                    registry: registry)
                let glow = try AmethystEscapeSceneGeometry.glowMesh(snapshot, tier: tier)
                if !glow.indices.isEmpty {
                    glowRenderer = try Self.renderer(glow, vertex: AmethystEscapeShaders.glowVertex,
                                                     fragment: AmethystEscapeShaders.glowFragment,
                                                     name: "amethyst-escape-glow", registry: registry)
                }
                return
            } catch {
                release()
                fallbackReason = "amethyst-escape shader: \(error)"
            }
        }
        // Fallback: the level-2 geometry, unlit, with its per-vertex colours.
        let minimal = AmethystEscapeTier.of(AmethystEscapeTier.all.count - 1)
        let up = Vec3(0, 1, 0)
        let parts: [(part: AmethystEscapeColouredMesh, colourInNormals: Bool)] = [
            (part: try AmethystEscapeSceneGeometry.crystalPart(snapshot, tier: minimal, isolated: isolated),
             colourInNormals: false),
            (part: try AmethystEscapeSceneGeometry.glowPart(snapshot, tier: minimal), colourInNormals: true),
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

    private func drawCrystal(_ camera: AmethystEscapeCamera, time: Float, layers: Double) throws {
        guard let crystalRenderer else { return }
        let mvp = camera.viewProjection
        try crystalRenderer.draw(blend: .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(AmethystEscapeShaders.mvpUniform, matrix4: mvp.floats)
            p.set(AmethystEscapeShaders.lightDirectionUniform, Self.lightDirection)
            p.set(AmethystEscapeShaders.timeUniform, time)
            p.set(AmethystEscapeShaders.highlightLayersUniform, Float(layers))
            p.set(AmethystEscapeShaders.failureUniform, Float(0))
        }
    }

    private func drawGlow(_ camera: AmethystEscapeCamera, gain: Double, shell: Bool) throws {
        guard let glowRenderer else { return }
        let mvp = camera.viewProjection
        let limit = Float(glowLimit)
        try glowRenderer.draw(blend: shell ? .additive : .premultipliedAlpha, cullBackFaces: true) { p in
            p.set(AmethystEscapeShaders.mvpUniform, matrix4: mvp.floats)
            p.set(AmethystEscapeShaders.glowGainUniform, Float(gain))
            p.set(AmethystEscapeShaders.glowLimitUniform, limit)
            p.set(AmethystEscapeShaders.shellUniform, Float(shell ? 1 : 0))
        }
    }

    private func drawFallback(_ camera: AmethystEscapeCamera) throws {
        for renderer in fallbackRenderers {
            try renderer.draw(model: .identity, view: .identity, projection: camera.viewProjection,
                              color: Vec4(1, 1, 1, 1), fog: nil)
        }
    }
}
#endif
