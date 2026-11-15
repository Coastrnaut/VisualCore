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
// Nothing flashes. No audio.
//
// Feature 090 (A12-P02) T-A12-205 (FR-A12-211–213, FR-A12-220–222; SC-A12-201, SC-A12-205; clarifications 3–5;
// research D3–D5; plan "Lifecycle"):
//   - Colour and detail: the terrain part is drawn from the terrain mesh at the detail level of the host's quality tier
//     (tier 0, 1, 2 → `TerrainDetail` level 0, 1, 2; level 0 is the P01 mesh itself) with one colour per vertex from
//     `TerrainColoring` and the palette, through `MeshRenderer(mesh:colors:registry:)` in a white draw colour; the sea
//     plane keeps its one palette colour and its plain renderer. A change of tier rebuilds the terrain renderer only
//     (`terrainBuildCount`); the sea renderer, the CPU parts and the state stay. The CPU meshes and colours of the
//     levels drawn so far are kept for the current world and dropped by `shedCaches()`.
//   - Easing: the drawn view eases towards the state's view over 0.35 s of frame time with smoothstep
//     (`ViewEasing`), directly under Reduce Motion (the flag the one app passes, or the system setting, read every
//     frame, so switching it on mid-ease jumps to the target). While it eases, the drawn view also passes through
//     the camera policy over the level-0 terrain, so no frame shows the eye inside a hill. The probe and a ground pick
//     use the view drawn last.
//   - Words: the canvas description always names the state's view. A change of the state's view is spoken ("View
//     from the north-east, 35 degrees up, 18 metres away.") at most once per second of frame time (`ViewAnnouncer`,
//     the latest change wins), while VoiceOver runs.
//   - Gestures (`WorldsGestures`): drag orbits and pinch zooms through the port as `view.orbit` and `view.zoom`, both
//     also sent by the native controls; a tap casts the ray of the drawn camera through the tapped point
//     (`OrbitCamera.ray(ndc:aspect:)`, `Ray3`) against the level-0 height field (`GroundPick.hit(ray:field:)`) and
//     speaks "Ground at x 1.2, z -0.5, height 0.3 metres." or "No ground there."; the state never changes.
import Foundation
import SwiftUI
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import UIKit
import VisualCoreUI

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

    /// The detail level the terrain renderer (`renderers[0]`) was made for; nil without renderers.
    private(set) var terrainLevel: Int?
    /// Whether the terrain renderer carries a colour stream (false only when the palette is missing).
    private(set) var terrainColored = false
    /// How many times the terrain renderer was (re)built, with the others or alone after a change of tier.
    private(set) var terrainBuildCount = 0
    /// The terrain meshes and colours by detail level for ``partsKey``; dropped by `shedCaches()`.
    private var terrainLevels: [Int: (mesh: Mesh, colors: [Vec4]?)] = [:]
    /// The level-0 height field for ``partsKey`` (ground picks and the eased view's clearance).
    private var groundField: HeightField?

    /// The flag the one app passed when it made the experience; settable (tests switch it mid-ease).
    var reduceMotion: Bool
    /// The system's Reduce Motion setting, read every frame.
    private let systemReduceMotion: @MainActor () -> Bool
    /// Whether VoiceOver runs (announcements are posted only then).
    private let voiceOverRunning: @MainActor () -> Bool
    /// Where announcements go.
    let announcementSink: any AnnouncementSink
    /// The easing of the drawn view.
    private(set) var easing = ViewEasing()
    /// The view drawn by the last frame; nil before the first frame after `setup`.
    private(set) var lastDrawnView: WorldView?
    /// The rate limit of the view announcements.
    private(set) var announcer = ViewAnnouncer()
    /// The frame clock of the announcements: the sum of the frame times since `setup`, in seconds.
    private(set) var announcementClock = 0.0
    /// The state's view seen by the last frame; nil until the first frame after `setup`.
    private(set) var announcedView: WorldView?
    /// Every text spoken (or offered to the sink while VoiceOver runs) since the presenter was made, oldest first.
    private(set) var spoken: [String] = []
    /// The words of the last tap; nil before the first.
    private(set) var lastPick: String?
    /// The core of the last frame (gestures resolve against it).
    private(set) var lastCore: WorldsCore?
    /// The canvas gestures.
    private(set) var gestures = WorldsGestures()

    /// A presenter for the experience `experienceID`.
    /// - Parameters:
    ///   - reduceMotion: The one app's Reduce Motion flag (the drawn view moves directly).
    ///   - systemReduceMotion: The system setting, read every frame (nil: `UIAccessibility.isReduceMotionEnabled`).
    ///   - voiceOverRunning: Whether VoiceOver runs (nil: `UIAccessibility.isVoiceOverRunning`).
    ///   - announcementSink: Where spoken texts go (nil: the system's VoiceOver announcements).
    init(experienceID: ExperienceID, reduceMotion: Bool = false,
         systemReduceMotion: (@MainActor () -> Bool)? = nil, voiceOverRunning: (@MainActor () -> Bool)? = nil,
         announcementSink: (any AnnouncementSink)? = nil) {
        self.experienceID = experienceID
        self.reduceMotion = reduceMotion
        self.systemReduceMotion = systemReduceMotion ?? { UIAccessibility.isReduceMotionEnabled }
        self.voiceOverRunning = voiceOverRunning ?? { UIAccessibility.isVoiceOverRunning }
        self.announcementSink = announcementSink ?? SystemAnnouncementSink()
    }

    /// True when the drawn view moves directly: the one app's flag or the system setting.
    var reducesMotion: Bool { reduceMotion || systemReduceMotion() }

    /// The detail level drawn at quality tier `tier` (0…2, clamped).
    nonisolated static func level(forTier tier: Int) -> Int {
        min(max(tier, TerrainDetail.levels.lowerBound), TerrainDetail.levels.upperBound)
    }

    // MARK: Render scene

    /// Makes the depth pass with the host's registry (again after a context recreation).
    func setup(_ context: RenderContext) throws {
        depthPass = DepthMeshPass(registry: context.resources)
        isLive = true
        resetMotionAndWords()
    }

    /// Draws `core`'s world: generates the parts and makes the renderers when their key changed or the context was
    /// recreated, remakes the terrain renderer alone when the tier's detail level changed, then draws every part lit,
    /// with depth, through the orbit camera of the eased view; then speaks a changed view when allowed.
    func draw(_ core: WorldsCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        sync(core)
        lastCore = core
        lastCanvas = Vec2(Double(max(1, context.pixelWidth)), Double(max(1, context.pixelHeight)))
        let key = Self.key(core)
        if partsKey != key {
            parts = Array(try TerrainGenerator.parts(preset: core.preset, seed: core.seed)
                .prefix(TerrainGenerator.maxParts))
            partsKey = key
            terrainLevels = [:]
            groundField = nil
        }
        let level = Self.level(forTier: tier)
        if renderersKey != key || renderers.count != parts.count {
            try rebuildRenderers(context, key: key, core: core, level: level)
        } else if terrainLevel != level, hasTerrain {
            try rebuildTerrainRenderer(context, core: core, level: level)
        }
        if depthPass == nil { depthPass = DepthMeshPass(registry: context.resources) }
        guard let depthPass else { return }
        depthPass.clearColor = Self.backgroundColor(core.preset)
        let items = zip(renderers, parts).enumerated().map { index, pair in
            let colored = index == 0 && hasTerrain && terrainColored
            return DepthMeshPass.Item(renderer: pair.0, color: colored ? Vec4(1, 1, 1, 1) : Self.vector(pair.1.color))
        }
        let view = drawnView(core, delta: frame.delta)
        try depthPass.draw(items, camera: Self.camera(view), context: context)
        lastDrawnView = view
        lastPartsDrawn = items.count
        updateAnnouncements(core, delta: frame.delta)
    }

    /// Releases the renderers and the depth pass; the CPU parts stay for the next context. The easing, the
    /// announcements and the gestures start over.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseRenderers()
        depthPass?.release()
        depthPass = nil
        lastPartsDrawn = 0
        resetMotionAndWords()
    }

    /// Drops the CPU parts, the detail levels and the ground field; the next draw makes them again from the core.
    func shedCaches() {
        parts = []
        partsKey = nil
        terrainLevels = [:]
        groundField = nil
    }

    /// Forgets the easing, the announcement state and every touch.
    private func resetMotionAndWords() {
        easing.reset()
        lastDrawnView = nil
        announcer.reset()
        announcementClock = 0
        announcedView = nil
        gestures.reset()
    }

    /// True when the first part is the terrain.
    private var hasTerrain: Bool { parts.first?.name == WorldPart.terrainName }

    /// The terrain mesh and colours of `core`'s world at `level` (level 0: the part's own mesh), made once per world
    /// and level; the colours are nil when the palette is missing.
    private func terrain(_ core: WorldsCore, level: Int) throws -> (mesh: Mesh, colors: [Vec4]?) {
        if let known = terrainLevels[level] { return known }
        let mesh = level == 0 ? parts[0].mesh
            : try TerrainDetail.mesh(preset: core.preset, seed: core.seed, level: level)
        let colors = ContentCatalog.bundled.palette(id: core.preset.paletteId).map { palette in
            TerrainColoring.colors(mesh: mesh, palette: palette, preset: core.preset)
        }
        terrainLevels[level] = (mesh, colors)
        return (mesh, colors)
    }

    /// A lit renderer of `mesh` with the optional colour stream `colors`, made with the registry of `context`.
    private func makeRenderer(_ mesh: Mesh, colors: [Vec4]?, _ context: RenderContext) throws -> MeshRenderer {
        let renderer = try MeshRenderer(mesh: mesh, colors: colors, registry: context.resources)
        renderer.lightDirection = Self.lightDirection
        renderer.ambient = Self.ambient
        return renderer
    }

    /// Releases the old renderers and makes one per part with the registry of `context`, lit by the fixed light, the
    /// terrain at `level` with its colours; a failure releases the renderers made so far and rethrows.
    private func rebuildRenderers(_ context: RenderContext, key: String, core: WorldsCore, level: Int) throws {
        releaseRenderers()
        var made: [MeshRenderer] = []
        var colored = false
        do {
            for (index, part) in parts.enumerated() {
                if index == 0, hasTerrain {
                    let terrain = try terrain(core, level: level)
                    made.append(try makeRenderer(terrain.mesh, colors: terrain.colors, context))
                    colored = terrain.colors != nil
                } else {
                    made.append(try makeRenderer(part.mesh, colors: nil, context))
                }
            }
        } catch {
            for renderer in made { renderer.release() }
            throw error
        }
        renderers = made
        renderersKey = key
        terrainLevel = hasTerrain ? level : nil
        terrainColored = colored
        rebuildCount += 1
        if hasTerrain { terrainBuildCount += 1 }
    }

    /// Replaces the terrain renderer by one at `level`; the other renderers stay. A failure keeps the old one.
    private func rebuildTerrainRenderer(_ context: RenderContext, core: WorldsCore, level: Int) throws {
        let terrain = try terrain(core, level: level)
        let renderer = try makeRenderer(terrain.mesh, colors: terrain.colors, context)
        renderers[0].release()
        renderers[0] = renderer
        terrainLevel = level
        terrainColored = terrain.colors != nil
        terrainBuildCount += 1
    }

    /// Releases every renderer and forgets their key.
    private func releaseRenderers() {
        for renderer in renderers { renderer.release() }
        renderers = []
        renderersKey = nil
        terrainLevel = nil
    }

    // MARK: Motion, words and gestures

    /// The level-0 height field of `core`'s world, made once per world; nil when it cannot be built.
    func groundField(_ core: WorldsCore) -> HeightField? {
        if Self.key(core) == partsKey, let groundField { return groundField }
        let field = try? TerrainGenerator.heightField(preset: core.preset, seed: core.seed)
        if Self.key(core) == partsKey { groundField = field }
        return field
    }

    /// The view to draw for `core` after `delta` seconds: eased towards the state's view (direct under Reduce
    /// Motion); while easing it also keeps the camera policy's clearance over the level-0 terrain.
    private func drawnView(_ core: WorldsCore, delta: Double) -> WorldView {
        let view = easing.advance(to: core.view, by: delta, reduceMotion: reducesMotion)
        guard view != core.view, let field = groundField(core) else { return view }
        return CameraPolicy.clamp(view, field: field)
    }

    /// Advances the announcement clock by `delta`, offers a change of the state's view and speaks what is due.
    private func updateAnnouncements(_ core: WorldsCore, delta: Double) {
        if delta.isFinite, delta > 0 { announcementClock += delta }
        if let previous = announcedView, previous != core.view {
            if let now = announcer.offer(Self.spokenView(core.view), at: announcementClock) { speak(now) }
        } else if let due = announcer.tick(at: announcementClock) {
            speak(due)
        }
        announcedView = core.view
    }

    /// Records `text` and posts it to the sink while VoiceOver runs.
    private func speak(_ text: String) {
        spoken.append(text)
        if voiceOverRunning() { announcementSink.announce(text) }
    }

    /// The spoken view: "View from the north-east, 35 degrees up, 18 metres away."
    nonisolated static func spokenView(_ view: WorldView) -> String {
        let words = viewWords(view)
        return words.prefix(1).uppercased() + words.dropFirst() + "."
    }

    /// The ground point the view point `point` (points, top-left origin) on a canvas of `viewSize` points meets
    /// through the camera of `view` over `field`, or nil (sky, void or a degenerate canvas).
    nonisolated static func groundPoint(view: WorldView, point: Vec2, viewSize: Vec2, field: HeightField) -> Vec3? {
        guard point.isFinite, viewSize.isFinite, viewSize.x > 0, viewSize.y > 0 else { return nil }
        let ndc = Vec2(2 * point.x / viewSize.x - 1, 1 - 2 * point.y / viewSize.y)
        let cast = camera(view).ray(ndc: ndc, aspect: viewSize.x / viewSize.y)
        guard let ray = Ray3(origin: cast.origin, direction: cast.direction) else { return nil }
        return GroundPick.hit(ray: ray, field: field)
    }

    /// A number in words with one decimal ("1.2", "-0.5"; never "-0.0").
    nonisolated static func decimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return String(format: "%.1f", rounded == 0 ? 0 : rounded)
    }

    /// The words of a tap: "Ground at x 1.2, z -0.5, height 0.3 metres." or "No ground there.".
    nonisolated static func pickWords(_ point: Vec3?) -> String {
        guard let point else { return "No ground there." }
        return "Ground at x \(decimal(point.x)), z \(decimal(point.z)), height \(decimal(point.y)) metres."
    }

    /// Resolves a tap at the view point `point` against the last drawn world and view, and speaks the result; the
    /// state never changes. Returns the words.
    @discardableResult
    func pick(at point: Vec2, viewSize: Vec2) -> String? {
        guard let core = lastCore else { return nil }
        let view = lastDrawnView ?? core.view
        let hit = groundField(core).flatMap { field in
            Self.groundPoint(view: view, point: point, viewSize: viewSize, field: field)
        }
        let words = Self.pickWords(hit)
        lastPick = words
        speak(words)
        return words
    }

    /// The two view actions the canvas gestures send.
    var gestureActions: Set<String> { WorldsGestures.gestureActions }

    /// Turns a canvas pointer event into view actions sent through `port`, or a spoken ground pick.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        pointer(event, viewSize: viewSize) { port.send($0, $1) }
    }

    /// The pointer event `event` turned into view actions sent through `send` (tests record them) or a ground pick.
    func pointer(_ event: PointerEvent, viewSize: Vec2, send: WorldsGestures.Send) {
        var current = gestures
        var taps: [Vec2] = []
        current.handle(event, send: send) { taps.append($0) }
        gestures = current
        for point in taps { pick(at: point, viewSize: viewSize) }
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

    /// One background probe (see the file header) for the view drawn last; none before the first frame.
    func probes(_ core: WorldsCore) -> [FrameProbe] {
        guard let size = lastCanvas, let expected = Self.colorClass(Self.backgroundColor(core.preset)),
              let point = Self.backgroundPoint(view: lastDrawnView ?? core.view, size: size) else { return [] }
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

    /// Every action has a native control, the gestures' `view.orbit` and `view.zoom` among them.
    var nativeActions: Set<String> { Set(WorldsCore.actionIDs) }
}
