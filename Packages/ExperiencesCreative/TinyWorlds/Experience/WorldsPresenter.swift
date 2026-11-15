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
// Feature 093 (A12-P05) T-A12-504 (FR-A12-502, FR-A12-505; SC-A12-501, SC-A12-502; clarifications Q1–Q3; research
// D2–D3): the tier a frame is drawn at is chosen by `TierPolicy` before anything is drawn: the host's tier, the
// lightest tier while Low Power Mode is on (injected `lowPowerMode`, default
// `ProcessInfo.processInfo.isLowPowerModeEnabled`), and the lightest tier from a memory warning (`shedCaches()`, which
// the host calls on a warning) until 30 s of frame time after the last one. The frame clock (``pressureClock``) is the
// sum of the frame times since the presenter was made; it does not restart in `setup`. A change of tier rebuilds the
// terrain renderer alone, once; repeated warnings at the lightest tier rebuild nothing. The tier is presentation only:
// the state, the world document and the digest never see it.
//
// Feature 094 (A12-P06) T-A12-604 (FR-A12-611): the test-only seam `failNextDraw` makes the next `draw` throw
// `WorldsDrawError.injected` once (and clears itself), so a test can drive the host into its failure state; nothing
// else reads it.
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
//
// Feature 091 (A12-P03) T-A12-303 (FR-A12-301–303, FR-A12-310, FR-A12-320–323; SC-A12-301–305; clarifications Q1–Q5;
// research D1–D5):
//   - Props: one `MeshRenderer` per prop kind (`PropCatalog.model(_:)`: its mesh and per-vertex colours), made lazily
//     with the host's registry the first time a prop of that kind is drawn, forgotten in teardown (so a recreated
//     context makes them again) and released there. Every placed prop is drawn after the world's parts through the
//     same depth pass with its model matrix (`PlacedProp.modelMatrix`), in a white draw colour; the selected prop in
//     ``highlight`` (1.3 in each colour channel), so it reads brighter.
//   - Light: every renderer (terrain, sea and props) takes the state's light every frame: `WorldLight.direction` and
//     its ambient level.
//   - Tap: the ray of the drawn camera through the tapped point is met with the props' picking boxes
//     (`WorldEditing.pick(ray:props:)`) and the level-0 terrain (`GroundPick`); a prop nearer than the ground (or with
//     no ground behind it) is selected by sending `prop.select [index]` through the caller's port, otherwise the ground
//     point is remembered (``lastGround``) for the next Place and spoken as before.
//   - Words: every editing and light action sent by the controls or a tap is answered in words (the refusal's reason
//     or a confirmation, ``editWords``), shown in the controls and spoken while VoiceOver runs; a preset or seed
//     change that removes props says so. The description adds the props ("; 2 props, the house selected") when there
//     are any.
//   - Saved worlds: the presenter's `WorldStore` saves, opens and clears the four slots for the controls, outside the
//     action replay. Saving writes `WorldDocument(state:)` of the current world, then a 160 × 120 still drawn off
//     screen by the session (`ExperienceStillRenderer`, which the host view hands to the controls) encoded by
//     `StillImageEncoder` (at most 64 KB; no picture without a renderer or when drawing fails). Opening reads and
//     validates the slot's file and restores a snapshot of `WorldsCore.opening(state:from:)` through the shell
//     (`ExperienceShell.restore`); a refused file is reported and the world stays as it was. Clearing removes both
//     files.
//
// Feature 092 (A12-P04) T-A12-403 (FR-A12-402, FR-A12-404, FR-A12-407; clarifications Q1 and Q3): opening a pack
// (`world.pack`, sent by the controls' Open pack and Reset to pack through ``send(_:_:through:)``) is answered in words,
// "Opened the island pack." (shown and spoken while VoiceOver runs); the camera eases to the pack's view as to any new
// view, and moves directly under Reduce Motion. While easing, the drawn view passes through the camera policy for the
// state (`CameraPolicy.clamp(_:state:field:)`: the preset's limits and the props as well as the terrain).
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
    /// The placed props (feature 091).
    var props: [PlacedProp] = []
    /// The selected prop's index, or `WorldState.noSelection`.
    var selection = WorldState.noSelection
    /// The world light.
    var light = WorldLight.default
    /// The prop kind the Place button places (presentation state, never in the world).
    var placeKind = PropKind.tree.rawValue
    /// The pack the Open pack button opens, 0…2 (presentation state, never in the world; feature 092).
    var packChoice = 0
    /// The words of the last editing action, tap or slot action.
    var message = ""
    /// The stored name of each slot, empty for an empty or refused slot.
    var slotNames = Array(repeating: "", count: WorldStore.slots.count)
    /// The status text of each slot: what it holds, or the result of the last save, open or clear.
    var slotStatus = Array(repeating: "", count: WorldStore.slots.count)
    /// The PNG thumbnail of each slot, nil when none is stored.
    var slotPictures: [Data?] = Array(repeating: nil, count: WorldStore.slots.count)
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
    /// The direction towards the default light (feature 091: every frame takes the state's light).
    nonisolated static let lightDirection = WorldLight.default.direction
    /// The default ambient fraction added to the Lambert term.
    nonisolated static let ambient = WorldLight.default.ambient
    /// The draw colour of the selected prop (brighter than the white of the others).
    nonisolated static let highlight = Vec4(1.3, 1.3, 1.3, 1)
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
    /// The vertex count of the terrain mesh the terrain renderer was made from; nil without renderers (feature 093).
    private(set) var terrainVertices: Int?
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

    /// One renderer per prop kind, made lazily with the current context's registry (feature 091).
    private(set) var propRenderers: [PropKind: MeshRenderer] = [:]
    /// How many prop renderers were made since the presenter was made.
    private(set) var propBuildCount = 0
    /// The number of props drawn by the last frame.
    private(set) var lastPropsDrawn = 0
    /// The light the renderers drew the last frame with; nil before the first frame.
    private(set) var lastLight: WorldLight?
    /// Set by a test to make the next draw throw `WorldsDrawError.injected` (the seam clears itself; feature 094).
    var failNextDraw = false
    /// Whether Low Power Mode is on, read every frame (feature 093).
    private let lowPowerMode: @MainActor () -> Bool
    /// The rules that choose the drawn tier (feature 093).
    private(set) var tierPolicy = TierPolicy()
    /// The frame clock of the tier policy: the sum of the frame times since the presenter was made, in seconds.
    private(set) var pressureClock = 0.0
    /// The tier the last frame was drawn at (after the policy); nil before the first frame.
    private(set) var lastTier: Int?
    /// The host tier the last frame was given; nil before the first frame.
    private(set) var lastHostTier: Int?
    /// The ground point of the last tap that met the ground, where Place puts a prop; nil before.
    private(set) var lastGround: Vec3?
    /// The saved worlds.
    let store: WorldStore
    /// The shell that holds this presenter: opening a slot restores a snapshot through it. Set by the factory; weak,
    /// because the shell holds the presenter.
    weak var shell: ExperienceShell<WorldsPresenter>?

    /// A presenter for the experience `experienceID`.
    /// - Parameters:
    ///   - reduceMotion: The one app's Reduce Motion flag (the drawn view moves directly).
    ///   - systemReduceMotion: The system setting, read every frame (nil: `UIAccessibility.isReduceMotionEnabled`).
    ///   - voiceOverRunning: Whether VoiceOver runs (nil: `UIAccessibility.isVoiceOverRunning`).
    ///   - announcementSink: Where spoken texts go (nil: the system's VoiceOver announcements).
    ///   - store: The saved worlds (in memory by default).
    ///   - lowPowerMode: Whether Low Power Mode is on (nil: `ProcessInfo.processInfo.isLowPowerModeEnabled`).
    init(experienceID: ExperienceID, reduceMotion: Bool = false,
         systemReduceMotion: (@MainActor () -> Bool)? = nil, voiceOverRunning: (@MainActor () -> Bool)? = nil,
         announcementSink: (any AnnouncementSink)? = nil, store: WorldStore = WorldStore(storage: nil),
         lowPowerMode: (@MainActor () -> Bool)? = nil) {
        self.experienceID = experienceID
        self.lowPowerMode = lowPowerMode ?? { ProcessInfo.processInfo.isLowPowerModeEnabled }
        self.store = store
        self.reduceMotion = reduceMotion
        self.systemReduceMotion = systemReduceMotion ?? { UIAccessibility.isReduceMotionEnabled }
        self.voiceOverRunning = voiceOverRunning ?? { UIAccessibility.isVoiceOverRunning }
        self.announcementSink = announcementSink ?? SystemAnnouncementSink()
        refreshSlots()
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
        if failNextDraw {
            failNextDraw = false
            throw WorldsDrawError.injected
        }
        let drawnTier = applyPressure(hostTier: tier, delta: frame.delta)
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
        let level = Self.level(forTier: drawnTier)
        if renderersKey != key || renderers.count != parts.count {
            try rebuildRenderers(context, key: key, core: core, level: level)
        } else if terrainLevel != level, hasTerrain {
            try rebuildTerrainRenderer(context, core: core, level: level)
        }
        if depthPass == nil { depthPass = DepthMeshPass(registry: context.resources) }
        guard let depthPass else { return }
        depthPass.clearColor = Self.backgroundColor(core.preset)
        var items = zip(renderers, parts).enumerated().map { index, pair in
            let colored = index == 0 && hasTerrain && terrainColored
            return DepthMeshPass.Item(renderer: pair.0, color: colored ? Vec4(1, 1, 1, 1) : Self.vector(pair.1.color))
        }
        let worldItems = items.count
        for (index, prop) in core.props.enumerated() {
            let renderer = try propRenderer(prop.kind, context)
            items.append(DepthMeshPass.Item(renderer: renderer, model: prop.modelMatrix,
                                            color: index == core.selection ? Self.highlight : Vec4(1, 1, 1, 1)))
        }
        let light = core.light, direction = core.light.direction
        for item in items {
            item.renderer.lightDirection = direction
            item.renderer.ambient = light.ambient
        }
        let view = drawnView(core, delta: frame.delta)
        try depthPass.draw(items, camera: Self.camera(view), context: context)
        lastDrawnView = view
        lastPartsDrawn = worldItems
        lastPropsDrawn = items.count - worldItems
        lastLight = light
        updateAnnouncements(core, delta: frame.delta)
    }

    /// Releases the renderers and the depth pass; the CPU parts stay for the next context. The easing, the
    /// announcements and the gestures start over.
    func teardown(_ context: RenderContext) {
        isLive = false
        releaseRenderers()
        releasePropRenderers()
        lastPropsDrawn = 0
        depthPass?.release()
        depthPass = nil
        lastPartsDrawn = 0
        resetMotionAndWords()
    }

    /// Advances the frame clock by `delta` (finite, non-negative) and chooses the tier of this frame from the host's
    /// `hostTier`, Low Power Mode read now and the memory hold (`TierPolicy`). Presentation only.
    @discardableResult
    func applyPressure(hostTier: Int, delta: Double) -> Int {
        if delta.isFinite, delta > 0 { pressureClock += delta }
        let chosen = tierPolicy.tier(host: hostTier, lowPower: lowPowerMode(), now: pressureClock)
        lastHostTier = hostTier
        lastTier = chosen
        return chosen
    }

    /// Records a memory warning at the current frame clock (the next frame draws the lightest tier for 30 s of frame
    /// time), then drops the CPU parts, the detail levels and the ground field; the next draw makes them again from
    /// the core.
    func shedCaches() {
        tierPolicy.recordMemoryWarning(at: pressureClock)
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
                    terrainVertices = terrain.mesh.positions.count
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
        terrainVertices = terrain.mesh.positions.count
        terrainColored = terrain.colors != nil
        terrainBuildCount += 1
    }

    /// The renderer of prop `kind`, made with the registry of `context` the first time it is needed.
    private func propRenderer(_ kind: PropKind, _ context: RenderContext) throws -> MeshRenderer {
        if let known = propRenderers[kind] { return known }
        let model = PropCatalog.model(kind)
        let renderer = try makeRenderer(model.mesh, colors: model.colors, context)
        propRenderers[kind] = renderer
        propBuildCount += 1
        return renderer
    }

    /// Releases the prop renderers; the next frame makes them again.
    private func releasePropRenderers() {
        for renderer in propRenderers.values { renderer.release() }
        propRenderers = [:]
    }

    /// Releases every renderer and forgets their key.
    private func releaseRenderers() {
        for renderer in renderers { renderer.release() }
        renderers = []
        renderersKey = nil
        terrainLevel = nil
        terrainVertices = nil
    }

    // MARK: Motion, words and gestures

    /// The level-0 height field of `core`'s world, made once per world (from the core's memo); nil when it cannot be
    /// built.
    func groundField(_ core: WorldsCore) -> HeightField? {
        if Self.key(core) == partsKey, let groundField { return groundField }
        let field = WorldsCore.heightField(of: core.state)
        if Self.key(core) == partsKey { groundField = field }
        return field
    }

    /// The view to draw for `core` after `delta` seconds: eased towards the state's view (direct under Reduce
    /// Motion); while easing it also keeps the camera policy for the state (preset limits, terrain and props).
    private func drawnView(_ core: WorldsCore, delta: Double) -> WorldView {
        let view = easing.advance(to: core.view, by: delta, reduceMotion: reducesMotion)
        guard view != core.view, let field = groundField(core) else { return view }
        return CameraPolicy.clamp(view, state: core.state, field: field)
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

    /// The ray of the camera of `view` through the view point `point` (points, top-left origin) on a canvas of
    /// `viewSize` points, or nil for a degenerate canvas.
    nonisolated static func ray(view: WorldView, point: Vec2, viewSize: Vec2) -> Ray3? {
        guard point.isFinite, viewSize.isFinite, viewSize.x > 0, viewSize.y > 0 else { return nil }
        let ndc = Vec2(2 * point.x / viewSize.x - 1, 1 - 2 * point.y / viewSize.y)
        let cast = camera(view).ray(ndc: ndc, aspect: viewSize.x / viewSize.y)
        return Ray3(origin: cast.origin, direction: cast.direction)
    }

    /// The ground point the view point `point` (points, top-left origin) on a canvas of `viewSize` points meets
    /// through the camera of `view` over `field`, or nil (sky, void or a degenerate canvas).
    nonisolated static func groundPoint(view: WorldView, point: Vec2, viewSize: Vec2, field: HeightField) -> Vec3? {
        guard let ray = ray(view: view, point: point, viewSize: viewSize) else { return nil }
        return GroundPick.hit(ray: ray, field: field)
    }

    /// What a tap along `ray` meets: the index of the nearest prop whose picking box it meets before the ground (or
    /// with no ground behind it), else the ground point (nil for a miss).
    nonisolated static func tapTarget(ray: Ray3, props: [PlacedProp], field: HeightField?)
        -> (prop: Int?, ground: Vec3?) {
        let ground = field.flatMap { GroundPick.hit(ray: ray, field: $0) }
        let groundDistance = ground.map { ($0 - ray.origin).length } ?? .infinity
        if let hit = WorldEditing.pick(ray: ray, props: props), hit.distance < groundDistance {
            return (hit.index, ground)
        }
        return (nil, ground)
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

    /// Resolves a tap at the view point `point` against the last drawn world and view: a prop nearer than the ground
    /// is selected through `send` (`prop.select`), otherwise the ground point is remembered for Place. The result is
    /// spoken and returned.
    @discardableResult
    func pick(at point: Vec2, viewSize: Vec2, send: WorldsGestures.Send) -> String? {
        guard let core = currentCore else { return nil }
        let view = lastDrawnView ?? core.view
        let target = Self.ray(view: view, point: point, viewSize: viewSize).map { ray in
            Self.tapTarget(ray: ray, props: core.props, field: groundField(core))
        }
        let words: String
        if let index = target?.prop {
            let result = send("prop.select", [Double(index)])
            words = Self.editWords("prop.select", [Double(index)], result: result, before: core.state,
                                   after: currentCore?.state ?? core.state) ?? "No prop selected."
        } else {
            let hit = target?.ground
            if let hit { lastGround = hit }
            words = Self.pickWords(hit)
        }
        lastPick = words
        mirror.message = words
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
        for point in taps { pick(at: point, viewSize: viewSize, send: send) }
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
        if mirror.props != core.props { mirror.props = core.props }
        if mirror.selection != core.selection { mirror.selection = core.selection }
        if mirror.light != core.light { mirror.light = core.light }
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

    /// The description of `core`'s world, with its props when there are any (feature 091).
    func describe(_ core: WorldsCore) -> String {
        sync(core)
        let base = Self.description(preset: core.preset, seed: core.seed, view: core.view)
        guard let props = Self.propsWords(core.props, selection: core.selection) else { return base }
        return String(base.dropLast()) + "; " + props + "."
    }

    /// The native controls, sending through `port`; editing actions are answered in words, slot actions go to the
    /// presenter.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        let edit = WorldsEditActions(
            send: { [weak self] control, values in
                guard let self else { _ = port.send(control, values); return }
                self.send(control, values) { port.send($0, $1) }
            },
            place: { [weak self] kind in
                guard let self else { return }
                self.send("prop.place", self.placeValues(kind: kind)) { port.send($0, $1) }
            })
        let slots = WorldsSlotActions(
            save: { [weak self] slot, still in _ = self?.saveWorld(slot: slot, still: still) },
            open: { [weak self] slot in _ = self?.openWorld(slot: slot) },
            clear: { [weak self] slot in _ = self?.clearWorld(slot: slot) })
        return AnyView(WorldsControls(port: port, mirror: mirror, edit: edit, slots: slots))
    }

    /// Every action has a native control, the gestures' `view.orbit`, `view.zoom` and `prop.select` among them.
    var nativeActions: Set<String> { Set(WorldsCore.actionIDs) }

    // MARK: Editing words (feature 091)

    /// The current core: the shell's, or the last one drawn.
    private var currentCore: WorldsCore? { shell?.engine.core ?? lastCore }

    /// The `prop.place` values for `kind`: the last tapped ground point (x and z clamped into −6…6), else the centre.
    func placeValues(kind: Int) -> [Double] {
        let range = WorldsCore.placeCoordinateRange
        func clamp(_ v: Double) -> Double { min(max(v, range.lowerBound), range.upperBound) }
        guard let ground = lastGround else { return [Double(kind), 0, 0] }
        return [Double(kind), clamp(ground.x), clamp(ground.z)]
    }

    /// Sends `control` with `values` through `send` and answers it in words (shown and spoken); returns the result.
    @discardableResult
    func send(_ control: String, _ values: [Double], through send: WorldsGestures.Send) -> ActionResult {
        let before = currentCore?.state
        let result = send(control, values)
        let after = currentCore?.state
        if let words = Self.editWords(control, values, result: result, before: before, after: after) {
            mirror.message = words
            speak(words)
        }
        return result
    }

    /// The name of prop `kind` in a sentence: "tree", "rock", "house", "lantern".
    nonisolated static func propName(_ kind: PropKind) -> String { kind.name.lowercased() }

    /// The props in words: "1 prop, the tree selected", "3 props, none selected"; nil without props.
    nonisolated static func propsWords(_ props: [PlacedProp], selection: Int) -> String? {
        guard !props.isEmpty else { return nil }
        let count = props.count == 1 ? "1 prop" : "\(props.count) props"
        guard props.indices.contains(selection) else { return count + ", none selected" }
        return count + ", the \(propName(props[selection].kind)) selected"
    }

    /// The reason of a refused action in words.
    nonisolated static func refusalWords(_ result: ActionResult) -> String {
        guard case .rejected(let reason) = result else { return "" }
        if case .rule(let code) = reason, let refusal = WorldEditRefusal(rawValue: code) {
            switch refusal {
            case .propCap: return "Not done: the world already holds \(WorldEditing.maxProps) props."
            case .outside: return "Not done: that point is outside the world."
            case .underWater: return "Not done: that point is under water."
            case .tooClose: return "Not done: too close to another prop."
            case .noSelection: return "Not done: no prop is selected."
            case .invalidChoice: return "Not done: that choice is not possible."
            }
        }
        return "Not done: that value is out of range."
    }

    /// The words that answer opening `pack`: "Opened the island pack.", "Opened the asteroid garden pack.".
    nonisolated static func packWords(_ pack: WorldPack) -> String { "Opened the \(pack.name.lowercased()) pack." }

    /// The light in words: "Light from 30 degrees, 50 degrees up, ambient 0.35."
    nonisolated static func lightWords(_ light: WorldLight) -> String {
        "Light from \(Int(light.azimuth.rounded())) degrees, \(Int(light.elevation.rounded())) degrees up, ambient "
            + String(format: "%.2f", light.ambient) + "."
    }

    /// The words that answer `control` sent with `values` (state `before` and `after` it), or nil when the action is
    /// answered elsewhere (the view's announcements) or changed nothing worth saying.
    nonisolated static func editWords(_ control: String, _ values: [Double], result: ActionResult,
                                      before: WorldState?, after: WorldState?) -> String? {
        guard result.isAccepted else {
            return control.hasPrefix("view.") ? nil : refusalWords(result)
        }
        switch control {
        case "world.preset", "world.seed":
            guard let before, !before.props.isEmpty, after?.props.isEmpty ?? true else { return nil }
            return "The props were cleared for the new terrain."
        case "world.pack":
            guard let after, let pack = WorldPack.pack(index: after.presetIndex) else { return nil }
            return packWords(pack)
        case "prop.place", "prop.move":
            guard let prop = after?.selectedProp else { return nil }
            let verb = control == "prop.place" ? "Placed a" : "Moved the"
            let preposition = control == "prop.place" ? "at" : "to"
            return "\(verb) \(propName(prop.kind)) \(preposition) x \(decimal(prop.x)), z \(decimal(prop.z))."
        case "prop.select":
            guard let after, let prop = after.selectedProp else { return "No prop selected." }
            return "Selected the \(propName(prop.kind)), prop \(after.selection + 1) of \(after.props.count)."
        case "prop.rotate":
            guard let prop = after?.selectedProp else { return nil }
            let degrees = Int((prop.rotation / WorldView.radiansPerDegree).rounded())
            return "Turned the \(propName(prop.kind)) to \(degrees == 0 ? 0 : degrees) degrees."
        case "prop.delete":
            guard let prop = before?.selectedProp else { return "Deleted the prop." }
            return "Deleted the \(propName(prop.kind))."
        case "light.azimuth", "light.elevation", "light.ambient":
            guard let light = after?.light else { return nil }
            return lightWords(light)
        default:
            return nil
        }
    }

    // MARK: Saved worlds (feature 091)

    /// What a refused save, open or clear means, in words.
    nonisolated static func refusalText(_ refusal: WorldStoreRefusal) -> String {
        switch refusal {
        case .emptySlot: "The slot is empty."
        case .invalidSlot: "There is no such slot."
        case .document(.damaged): "The saved file is damaged and was left as it is."
        case .document(.newerVersion): "The saved file comes from a newer version and was left as it is."
        case .document(.tooLarge): "The saved file is too large and was left as it is."
        case .storage(let error): "The storage refused it (\(error.code))."
        }
    }

    /// What a slot holds, in words: "Holds “Island, seed 1”.", "Holds “Island, seed 1”, no picture.", "Empty." or
    /// the refusal's text.
    nonisolated static func holdingText(_ result: Result<WorldDocument, WorldStoreRefusal>, hasPicture: Bool) -> String {
        switch result {
        case .success(let document): hasPicture ? "Holds “\(document.name)”." : "Holds “\(document.name)”, no picture."
        case .failure(.emptySlot): "Empty."
        case .failure(let refusal): refusalText(refusal)
        }
    }

    /// Reads every slot once: its name, picture and what it holds (nothing is written).
    func refreshSlots() {
        for slot in WorldStore.slots { refreshSlot(slot) }
    }

    /// Reads `slot` once: its name, picture and what it holds. A picture is shown only beside a world that reads (a
    /// picture left without its world file is not shown; feature 094).
    private func refreshSlot(_ slot: Int) {
        let result = store.read(slot: slot)
        let picture = (try? result.get()) == nil ? nil : store.thumbnail(slot: slot)
        let name = (try? result.get())?.name ?? ""
        if mirror.slotNames[slot] != name { mirror.slotNames[slot] = name }
        if mirror.slotPictures[slot] != picture { mirror.slotPictures[slot] = picture }
        mirror.slotStatus[slot] = Self.holdingText(result, hasPicture: picture != nil)
    }

    /// The 160 × 120 PNG of the current world drawn by `still`, or nil (no renderer, drawing or encoding failed, or
    /// more than 64 KB).
    static func thumbnail(_ still: ExperienceStillRenderer?) -> Data? {
        guard let still,
              let image = try? still(width: WorldStore.thumbnailWidth, height: WorldStore.thumbnailHeight),
              let png = try? StillImageEncoder.pngData(image), png.count <= WorldStore.maxThumbnailBytes else {
            return nil
        }
        return png
    }

    /// Saves the current world to `slot` as `WorldDocument(state:)` with a thumbnail drawn by `still` (no picture
    /// without one). Returns the status text, also set as the slot's status and spoken.
    @discardableResult
    func saveWorld(slot: Int, still: ExperienceStillRenderer?) -> String {
        guard WorldStore.slots.contains(slot) else { return Self.refusalText(.invalidSlot) }
        guard let core = currentCore else { return report(slot, "Not saved: the world is not ready.") }
        let document = WorldDocument(state: core.state)
        let picture = Self.thumbnail(still)
        switch store.save(document, slot: slot, thumbnail: picture) {
        case .success(let stored):
            refreshSlot(slot)
            return report(slot, stored ? "Saved “\(document.name)”." : "Saved “\(document.name)”, no picture.")
        case .failure(.document(.tooLarge)):
            return report(slot, "Not saved: the world is too large to save.")
        case .failure(let refusal):
            return report(slot, "Not saved: " + Self.refusalText(refusal))
        }
    }

    /// Opens the world saved in `slot`: the file is read and validated, and a snapshot of
    /// `WorldsCore.opening(state:from:)` is restored through the shell. A refused file is left as it is and the world
    /// stays. Returns the status text, also set as the slot's status and spoken.
    @discardableResult
    func openWorld(slot: Int) -> String {
        guard WorldStore.slots.contains(slot) else { return Self.refusalText(.invalidSlot) }
        let document: WorldDocument
        switch store.read(slot: slot) {
        case .success(let read): document = read
        case .failure(let refusal): return report(slot, "Not opened: " + Self.refusalText(refusal))
        }
        guard let shell, let core = shell.engine.core else { return report(slot, "Not opened: the world is not ready.") }
        let opened = WorldsCore.opening(state: document.state, from: core)
        do {
            let snapshot = try WorldsCore.openingSnapshot(of: opened, experience: shell.id,
                                                          stepIndex: shell.engine.stepIndex)
            try shell.restore(snapshot)
        } catch {
            return report(slot, "Not opened: the world could not be restored.")
        }
        lastGround = nil
        sync(opened)
        return report(slot, "Opened “\(document.name)”.")
    }

    /// Removes the world saved in `slot`. Returns the status text, also set as the slot's status and spoken.
    @discardableResult
    func clearWorld(slot: Int) -> String {
        guard WorldStore.slots.contains(slot) else { return Self.refusalText(.invalidSlot) }
        switch store.clear(slot: slot) {
        case .success:
            refreshSlot(slot)
            return report(slot, "Cleared.")
        case .failure(let refusal):
            return report(slot, "Not cleared: " + Self.refusalText(refusal))
        }
    }

    /// Sets `text` as the status of `slot` and the message, speaks it and returns it.
    private func report(_ slot: Int, _ text: String) -> String {
        mirror.slotStatus[slot] = text
        mirror.message = text
        speak(text)
        return text
    }
}

/// A failure the presenter injects for tests (`failNextDraw`; feature 094).
enum WorldsDrawError: Error, Equatable {
    /// The injected failure.
    case injected
}
