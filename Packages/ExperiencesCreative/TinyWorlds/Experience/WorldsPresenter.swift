// WorldsPresenter — feature 089 (A12-P01) T-A12-104 (FR-A12-120, FR-A12-121; clarifications 3 and 4; research D4;
// plan "Lifecycle"). Draws Tiny Worlds through the host only (the host's context and registry, VisualCore's
// `DepthMeshPass` and `MeshRenderer`; no context of its own, no second renderer, no imported assets). The presenter
// reads the core and never writes it:
//   - Parts: the world's parts (`TerrainGenerator.parts(preset:seed:)`: the terrain, and for the island and the
//     miniature city the sea plane; at most `TerrainGenerator.maxParts`) are generated on the CPU when the core's
//     preset or terrain digest differs from the cached one; the CPU parts survive a context recreation and are
//     dropped by `shedCaches()`.
//   - GPU objects: one `DepthMeshPass` (made in `setup`, so it is remade after a context recreation) and one
//     `MeshRenderer` per part, made with `context.resources` when the host's context is current (in `draw`), rebuilt
//     when the parts' key changes or after a context recreation (teardown forgets them), and all released in
//     `teardown`.
//   - Light: every part is drawn in its palette colour (opaque, premultiplied) with Lambert lighting from the fixed
//     direction normalize(0.4, 1, 0.3) and ambient 0.35, with depth, through an `OrbitCamera` built from the view:
//     target (0, 0.3, 0), the view's yaw, pitch and distance, field of view 60°, near 0.1 m and far 100 m.
//   - Background: the pass clears to the palette's sea (or void) colour.
//   - Probe: one point of the background that the CPU proves uncovered (outside the projected bounds of the world's
//     box, x and z in −6…6 m and y in −1…1.6 m, by 4 pixels), expecting the colour class of the background; none
//     when no candidate is uncovered or when the background's class could change with the 8-bit rounding of a
//     channel (the miniature city's sea lies on the blue threshold).
//   - Words: the compass direction of the eye (north is +z, east is +x), the pitch in whole degrees and the distance in
//     whole metres; the canvas description is "Tiny Worlds: Island, seed 1; view from the north-east, 35 degrees up,
//     18 metres away."
// There is no motion, so Reduce Motion changes nothing; nothing flashes. No audio.
import Foundation
import SwiftUI
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class WorldsMirror {
    /// Whether a state was seen (the controls show a progress indicator before).
    var ready = false
    /// The preset index, 0…2.
    var presetIndex = 0
    /// The world's seed.
    var seed: UInt32 = WorldState.defaultSeed
    /// The view.
    var view = WorldView.default
    /// The status line: world, seed and view in words.
    var status = ""
}

/// Draws Tiny Worlds and owns its presentation state (the cached parts and the GPU objects).
@MainActor
final class WorldsPresenter: ExperiencePresenter {
    /// The point the camera orbits: the world centre, 0.3 m up.
    nonisolated static let target = Vec3(0, 0.3, 0)
    /// The camera's vertical field of view (60°).
    nonisolated static let fieldOfView = Double.pi / 3
    /// The camera's near and far planes in metres.
    nonisolated static let near = 0.1, far = 100.0
    /// The direction towards the light, fixed in this phase.
    nonisolated static let lightDirection = Vec3(0.4, 1, 0.3).normalized
    /// The ambient fraction added to the Lambert term.
    nonisolated static let ambient = 0.35
    /// The world's box: x and z in −6…6 m, y in the terrain's height range.
    nonisolated static let worldLow = Vec3(WorldPreset.worldOrigin, WorldPreset.heightRange.lowerBound,
                                           WorldPreset.worldOrigin)
    /// The far corner of the world's box.
    nonisolated static let worldHigh = Vec3(WorldPreset.worldOrigin + WorldPreset.worldSize,
                                            WorldPreset.heightRange.upperBound,
                                            WorldPreset.worldOrigin + WorldPreset.worldSize)
    /// The probe candidates, measured from the top left: the corners, then the edge midpoints.
    nonisolated static let probeCandidates: [(x: Double, y: Double)] = [
        (0.04, 0.04), (0.96, 0.04), (0.04, 0.96), (0.96, 0.96), (0.5, 0.04), (0.04, 0.5), (0.96, 0.5), (0.5, 0.96),
    ]
    /// The margin around the world's projected bounds that a probe point keeps, in pixels.
    nonisolated static let probeMarginPixels = 4.0

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// What the controls show.
    let mirror = WorldsMirror()

    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// The world's CPU parts for ``partsKey``; kept across context recreations.
    private(set) var parts: [WorldPart] = []
    /// The key (preset index and terrain digest) `parts` were generated for.
    private(set) var partsKey: String?
    /// One renderer per part, made for ``renderersKey`` with the current context's registry.
    private(set) var renderers: [MeshRenderer] = []
    /// The key the renderers were made for; nil after `teardown`.
    private(set) var renderersKey: String?
    /// How many times the renderers were (re)built.
    private(set) var rebuildCount = 0
    /// The number of parts drawn by the last frame.
    private(set) var lastPartsDrawn = 0
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The depth-correct pass the parts are drawn through; made in `setup`, released in `teardown`.
    private var depthPass: DepthMeshPass?

    /// A presenter for the experience `experienceID`.
    init(experienceID: ExperienceID) {
        self.experienceID = experienceID
    }

    // MARK: Render scene

    /// Makes the depth pass with the host's registry (again after a context recreation).
    func setup(_ context: RenderContext) throws {
        depthPass = DepthMeshPass(registry: context.resources)
        isLive = true
    }

    /// Draws `core`'s world: generates the parts and makes the renderers when their key changed or the context was
    /// recreated, then draws every part lit, with depth, through the view's orbit camera.
    func draw(_ core: WorldsCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        lastCanvas = Vec2(Double(max(1, context.pixelWidth)), Double(max(1, context.pixelHeight)))
        let key = Self.key(core)
        if partsKey != key {
            parts = Array(try TerrainGenerator.parts(preset: core.preset, seed: core.seed)
                .prefix(TerrainGenerator.maxParts))
            partsKey = key
        }
        if renderersKey != key || renderers.count != parts.count {
            try rebuildRenderers(context, key: key)
        }
        if depthPass == nil { depthPass = DepthMeshPass(registry: context.resources) }
        guard let depthPass else { return }
        depthPass.clearColor = Self.backgroundColor(core.preset)
        let items = zip(renderers, parts).map { renderer, part in
            DepthMeshPass.Item(renderer: renderer, color: Self.vector(part.color))
        }
        try depthPass.draw(items, camera: Self.camera(core.view), context: context)
        lastPartsDrawn = items.count
    }

    /// Releases the renderers and the depth pass; the CPU parts stay for the next context.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseRenderers()
        depthPass?.release()
        depthPass = nil
        lastPartsDrawn = 0
    }

    /// Drops the CPU parts; the next draw generates them again from the core.
    func shedCaches() {
        parts = []
        partsKey = nil
    }

    /// Releases the old renderers and makes one per part with the registry of `context`, lit by the fixed light; a
    /// failure releases the renderers made so far and rethrows.
    private func rebuildRenderers(_ context: RenderContext, key: String) throws {
        releaseRenderers()
        var made: [MeshRenderer] = []
        do {
            for part in parts {
                let renderer = try MeshRenderer(mesh: part.mesh, registry: context.resources)
                renderer.lightDirection = Self.lightDirection
                renderer.ambient = Self.ambient
                made.append(renderer)
            }
        } catch {
            for renderer in made { renderer.release() }
            throw error
        }
        renderers = made
        renderersKey = key
        rebuildCount += 1
    }

    /// Releases every renderer and forgets their key.
    private func releaseRenderers() {
        for renderer in renderers { renderer.release() }
        renderers = []
        renderersKey = nil
    }

    // MARK: Geometry and colour

    /// The parts' key of `core`: its preset index and terrain digest.
    nonisolated static func key(_ core: WorldsCore) -> String {
        "\(core.state.presetIndex)|\(core.terrainDigest)"
    }

    /// The orbit camera of `view`: target (0, 0.3, 0), the view's yaw, pitch and distance, 60°, near 0.1 m, far 100 m.
    nonisolated static func camera(_ view: WorldView) -> OrbitCamera {
        OrbitCamera(target: target, distance: view.distance, yaw: view.yaw, pitch: view.pitch, fovY: fieldOfView,
                    near: near, far: far)
    }

    /// A palette colour as a premultiplied vector.
    nonisolated static func vector(_ color: RGBA) -> Vec4 {
        Vec4(color.r * color.a, color.g * color.a, color.b * color.a, color.a)
    }

    /// The background of `preset`: its palette's sea (or void) colour, opaque; mid grey when the palette is missing.
    nonisolated static func backgroundColor(_ preset: WorldPreset) -> Vec4 {
        guard let sea = ContentCatalog.bundled.palette(id: preset.paletteId)?.sea else { return Vec4(0.5, 0.5, 0.5, 1) }
        return Vec4(sea.r, sea.g, sea.b, 1)
    }

    /// The `FrameColorClass` raw value of 8-bit channels by the frame checks' rules (luma below 40 dark; luma above
    /// 215 with a spread below 30 light; a channel 30 above both others red, green or blue; otherwise other).
    nonisolated static func classify(red r: Int, green g: Int, blue b: Int) -> String {
        let luma = 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
        if luma < 40 { return FrameColorClass.dark.rawValue }
        if luma > 215, max(r, g, b) - min(r, g, b) < 30 { return FrameColorClass.light.rawValue }
        if r - g >= 30, r - b >= 30 { return FrameColorClass.red.rawValue }
        if g - r >= 30, g - b >= 30 { return FrameColorClass.green.rawValue }
        if b - r >= 30, b - g >= 30 { return FrameColorClass.blue.rawValue }
        return FrameColorClass.other.rawValue
    }

    /// The colour class of a cleared colour (channels 0…1): the class every 8-bit conversion gives (each channel to
    /// either of its two nearest values, as OpenGL ES allows), or nil when the conversions disagree.
    nonisolated static func colorClass(_ color: Vec4) -> String? {
        func nearest(_ value: Double) -> [Int] {
            let scaled = min(max(value.isFinite ? value : 0, 0), 1) * 255
            return Array(Set([Int(scaled.rounded(.down)), Int(scaled.rounded(.up))]))
        }
        var classes: Set<String> = []
        for r in nearest(color.x) {
            for g in nearest(color.y) {
                for b in nearest(color.z) { classes.insert(classify(red: r, green: g, blue: b)) }
            }
        }
        return classes.count == 1 ? classes.first : nil
    }

    /// The first probe candidate outside the projected bounds of the world's box (by ``probeMarginPixels``) seen
    /// through `view` on a canvas of `size` pixels, or nil.
    nonisolated static func backgroundPoint(view: WorldView, size: Vec2) -> (x: Double, y: Double)? {
        let width = max(size.x, 1), height = max(size.y, 1)
        let vp = camera(view).viewProjection(aspect: width / height)
        var minX = Double.infinity, maxX = -Double.infinity, minY = Double.infinity, maxY = -Double.infinity
        for corner in 0..<8 {
            let p = Vec3(corner & 1 == 0 ? worldLow.x : worldHigh.x, corner & 2 == 0 ? worldLow.y : worldHigh.y,
                         corner & 4 == 0 ? worldLow.z : worldHigh.z)
            let clip = vp * Vec4(p, 1)
            guard clip.w > 1e-9 else { return nil }
            minX = min(minX, clip.x / clip.w); maxX = max(maxX, clip.x / clip.w)
            minY = min(minY, clip.y / clip.w); maxY = max(maxY, clip.y / clip.w)
        }
        let mx = 2 * probeMarginPixels / width, my = 2 * probeMarginPixels / height
        return probeCandidates.first { candidate in
            let nx = candidate.x * 2 - 1, ny = 1 - candidate.y * 2
            return nx < minX - mx || nx > maxX + mx || ny < minY - my || ny > maxY + my
        }
    }

    /// One background probe (see the file header); none before the first frame.
    func probes(_ core: WorldsCore) -> [FrameProbe] {
        guard let size = lastCanvas, let expected = Self.colorClass(Self.backgroundColor(core.preset)),
              let point = Self.backgroundPoint(view: core.view, size: size) else { return [] }
        return [FrameProbe(name: "background", x: point.x, y: point.y, expected: expected)].compactMap { $0 }
    }

    // MARK: Words and controls

    /// Brings the controls' mirror in line with `core`.
    func sync(_ core: WorldsCore) {
        if !mirror.ready { mirror.ready = true }
        if mirror.presetIndex != core.state.presetIndex { mirror.presetIndex = core.state.presetIndex }
        if mirror.seed != core.seed { mirror.seed = core.seed }
        if mirror.view != core.view { mirror.view = core.view }
        let status = Self.status(preset: core.preset, seed: core.seed, view: core.view)
        if mirror.status != status { mirror.status = status }
    }

    /// The compass direction the view looks from (north is +z, east is +x): "north", "north-east", … "north-west".
    nonisolated static func compass(yawDegrees: Double) -> String {
        let names = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
        guard yawDegrees.isFinite else { return names[0] }
        let sector = Int((yawDegrees / 45).rounded())
        return names[((sector % 8) + 8) % 8]
    }

    /// The pitch in words: "35 degrees up".
    nonisolated static func pitchWords(_ view: WorldView) -> String {
        "\(Int(view.pitchDegrees.rounded())) degrees up"
    }

    /// The distance in words: "18 metres away".
    nonisolated static func distanceWords(_ view: WorldView) -> String {
        "\(Int(view.distance.rounded())) metres away"
    }

    /// The direction in words: "view from the north-east".
    nonisolated static func directionWords(_ view: WorldView) -> String {
        "view from the \(compass(yawDegrees: view.yawDegrees))"
    }

    /// The view in words: "view from the north-east, 35 degrees up, 18 metres away".
    nonisolated static func viewWords(_ view: WorldView) -> String {
        "\(directionWords(view)), \(pitchWords(view)), \(distanceWords(view))"
    }

    /// The status line: "Island, seed 1; view from the north-east, 35 degrees up, 18 metres away".
    nonisolated static func status(preset: WorldPreset, seed: UInt32, view: WorldView) -> String {
        "\(preset.name), seed \(seed); \(viewWords(view))"
    }

    /// The canvas description: "Tiny Worlds: Island, seed 1; view from the north-east, 35 degrees up, 18 metres away."
    nonisolated static func description(preset: WorldPreset, seed: UInt32, view: WorldView) -> String {
        "Tiny Worlds: \(status(preset: preset, seed: seed, view: view))."
    }

    /// The description of `core`'s world.
    func describe(_ core: WorldsCore) -> String {
        sync(core)
        return Self.description(preset: core.preset, seed: core.seed, view: core.view)
    }

    /// The native controls, sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(WorldsControls(port: port, mirror: mirror))
    }

    /// Every action has a native control; there is no canvas gesture in this phase.
    var nativeActions: Set<String> { Set(WorldsCore.actionIDs) }
}
