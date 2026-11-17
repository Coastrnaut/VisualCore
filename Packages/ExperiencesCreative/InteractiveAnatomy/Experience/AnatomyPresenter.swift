// AnatomyPresenter — feature 125 (A17-P02) T-A17-204 (FR-A17-202, FR-A17-204, FR-A17-205, FR-A17-207, FR-A17-208;
// clarifications Q2–Q5; contracts/scene.md; plan "Lifecycle"). Draws Interactive Anatomy through the host only (the
// host's context and registry, VisualCore's `DepthMeshPass` and `MeshRenderer` with an `OrbitCamera`; no context of
// its own, no second renderer, no assets). The presenter reads the core and never writes it:
//   - Renderers: one `MeshRenderer` per item mesh of the CURRENT tier's scene and one `DepthMeshPass` (backdrop
//     (0.07, 0.08, 0.10)), all made together in `setup` (after releasing everything; again after a context
//     recreation), all released and made again in `draw` when one is missing or the tier changed, and all released
//     together with the pass in `teardown`. Every mesh renderer shares one cached program in the host's registry and
//     releasing a renderer releases it for all, so no renderer is ever released on its own.
//   - Items: the scene's solid items (see below; without an isolate the items of the shown layers) in item order,
//     each with its model matrix and its layer's colour (bones ivory, cartilage and menisci blue-grey, ligaments and
//     tendons rose); the selected part's items are amber.
//   - Camera: `AnatomyCore.camera(aspect:)` at the drawable's pixel aspect (the framed part's sphere, else the
//     region's). Framing and Reset view cut to the new view in one frame, so Reduce Motion changes nothing.
//   - Pointer: one tap declaration (`pick`, `.tap`, one finger) over VisualCore's `GestureArbiter`; a recognized tap
//     becomes a normalised device point and is picked with the camera and aspect of the LAST DRAWN frame
//     (the `AnatomyPicker` rule over the solid parts), so what is tapped is what was seen: a hit sends
//     `structure.select [i]`, a miss `structure.clear`. Drags and any touch with a second finger never tap (since
//     feature 127 they turn, tilt and zoom; see below).
//   - Probe: the backdrop at (0.5, 0.04) from the top, expected dark, when the line of sight there meets no drawn
//     part (solid or ghost).
//   - Words: the canvas description of `AnatomyCore.describe()`; the mirror holds what the controls show.
// Feature 126 (A17-P03) T-A17-306 (FR-A17-302, FR-A17-304, FR-A17-305, FR-A17-307; clarifications Q3, Q4;
// contracts/layers-search.md):
//   - Solid and ghost items: the items of `AnatomyCore.solidIndices` (layer colours, the selection amber) are the
//     opaque list, the items of `ghostIndices` (the layer colour at alpha 0.25, sorted by the world centre of the
//     item's mesh bounds) the translucent list of `DepthMeshPass.draw(_:translucent:camera:context:)`. If the draw
//     with ghosts throws (or the test seam `failNextTranslucentDraw` is set), ghosts are off for the rest of the
//     session (`ghostsOff`): the frame is drawn again without them, as the hide mode, and the panel says
//     "Ghosts are off.".
//   - Picking only meets solid parts (a ghost or a hidden part is never picked).
//   - The view file: after each change of the core's view the presenter sees (accepted actions refresh the
//     description), `AnatomyViewDocument.encode` is written to `view.json` in the experience's storage; writes and
//     failed writes are counted and a failure changes nothing else. On the first frame, when the core holds the
//     opening view and `view.json` decodes to another view, the presenter sends `view.apply`
//     (`AnatomyCore.viewApplyValues(_:parts:)`) through the shell's port once; a damaged, newer or unreadable file is
//     ignored and counted in `viewReadRefusals`. Teardown forgets both, so a re-entry opens from the file again.
// Feature 127 (A17-P04) T-A17-405 (FR-A17-401, FR-A17-402, FR-A17-404–406; clarifications Q1–Q3;
// contracts/accessibility-pack.md):
//   - Gestures: `pointer(_:viewSize:port:)` feeds ``AnatomyGestures`` (drag turns and tilts, pinch zooms, a tap picks)
//     in place of the A17-P02 tap-only tracking; every step goes through ``send(_:_:through:)``, so a step refused at
//     a limit (`a17.camera-limit`) shows and speaks "The camera is at its limit.", as a refused button does. A drag and
//     a two-finger touch never tap.
//   - Labels: after each drawn frame `lastLabels` is `AnchoredLabelLayout.place` of `AnatomyLabels.candidates` (the
//     solid parts; ghosted and hidden parts get none) through the frame's camera and aspect, on the canvas in points
//     (the overlay's reported size, else the pixels over ``displayScale``), at most the level's `maxLabels` (16). The
//     host draws them through ``makeCanvasOverlay(_:)`` (``AnatomyOverlay``, hit testing off).
//   - Announcements: a selection change seen by `sync` is submitted to an `AnnouncementPlanner(minimumInterval: 0.5)`
//     ("<English name> selected." or "Selection cleared."; the first state seen announces nothing), timed by the
//     host's frame clock (the sum of the drawn frames' `delta`, so a test's frames of 1/60 s are deterministic); every
//     drawn frame flushes the planner, so the last change is always announced. Posts are kept in `announced` and go to
//     ``announcementSink`` (by default a VoiceOver announcement, only while VoiceOver is running).
//   - Reduce Motion: kept from the factory; nothing animates in any mode (framing, Reset view and every camera step cut
//     in one frame), so ``cameraTransitionSeconds`` is `transitionDuration(0, reduceMotion:)`, always 0.
// Feature 128 (A17-P05) T-A17-503 (FR-A17-503, FR-A17-504; clarification Q3; contracts/review.md):
//   - Review: the panel is made with the review record of ``reviewRecordLoader`` (by default
//     `AnatomyReviewRecord.bundled(for:)`), loaded at the first state seen and again after the loader changes. A
//     refused record is counted in ``reviewRecordProblems`` and the panel then shows only "Not reviewed by a
//     clinician." for every part; the content stays usable and nothing is shown as a review.
import Foundation
import InteractiveAnatomyCore
import SwiftUI
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// The error of the test seam `AnatomyPresenter.failNextTranslucentDraw`.
struct AnatomyGhostFailure: Error {}

/// One row of the structure list: a part's English name and layer.
struct AnatomyPartRow: Equatable, Sendable {
    /// The English name.
    let name: String
    /// The layer.
    let layer: AnatomyLayer
}

/// One label drawn over the canvas: a part's English name in its placed box (canvas points, origin top-left).
struct AnatomyCanvasLabel: Equatable, Sendable {
    /// The part's inventory index.
    let index: Int
    /// The English name.
    let text: String
    /// The box's left edge.
    let minX: Double
    /// The box's top edge.
    let minY: Double
    /// The box's width.
    let width: Double
    /// The box's height.
    let height: Double
}

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class AnatomyMirror {
    /// Whether a state was seen.
    var ready = false
    /// The parts in inventory order.
    var parts: [AnatomyPartRow] = []
    /// Whether each layer is shown (bones, cartilage, ligaments).
    var visibleLayers = [true, true, true]
    /// The selected part's index, or nil.
    var selected: Int?
    /// The camera steps.
    var camera = AnatomyCameraState.opening
    /// The parts drawn solid (selectable), by inventory index.
    var solid: Set<Int> = []
    /// The current isolate; nil when none.
    var isolate: AnatomyIsolate?
    /// The mode the next isolate uses.
    var isolateMode: AnatomyIsolate.Mode = .ghost
    /// The description panel of the selection.
    var panel: AnatomyPanel?
    /// Whether ghosts are off for the session (the translucent draw failed).
    var ghostsOff = false
    /// The text of the search field.
    var query = ""
    /// The answer to the last refused control action; empty when it was accepted.
    var message = ""
    /// The labels of the last drawn frame, in canvas points (feature 127).
    var labels: [AnatomyCanvasLabel] = []
    /// The canvas size in points the labels were laid out in (feature 127).
    var canvasSize = Vec2(0, 0)
    /// The overlay's own size in points, as it reported it; nil before it reports (feature 127).
    var overlaySize: Vec2?
}

/// Draws Interactive Anatomy and owns its presentation state (renderers and the depth pass; see the file header).
@MainActor
public final class AnatomyPresenter: ExperiencePresenter {
    /// The backdrop colour.
    nonisolated static let backgroundColor = Vec4(0.07, 0.08, 0.10, 1)
    /// The bones' colour (ivory).
    nonisolated static let bonesColor = Vec4(0.90, 0.86, 0.76, 1)
    /// The cartilage and menisci colour (blue-grey).
    nonisolated static let cartilageColor = Vec4(0.55, 0.70, 0.85, 1)
    /// The ligaments and tendons colour (rose).
    nonisolated static let ligamentsColor = Vec4(0.80, 0.45, 0.45, 1)
    /// The selected part's colour (amber).
    nonisolated static let selectionColor = Vec4(1.00, 0.80, 0.20, 1)
    /// The alpha of a ghost (its layer's colour at this alpha).
    nonisolated static let ghostAlpha = 0.25
    /// The panel sentence while ghosts are off.
    nonisolated static let ghostsOffSentence = "Ghosts are off."
    /// The ambient light fraction of every renderer.
    nonisolated static let ambient = 0.3
    /// The answer and announcement of a camera step refused at a limit (feature 127).
    nonisolated static let cameraLimitSentence = "The camera is at its limit."
    /// The announcement of a cleared selection (feature 127).
    nonisolated static let selectionClearedSentence = "Selection cleared."
    /// The shortest time between two announcements, seconds (feature 127).
    nonisolated static let announcementInterval = 0.5
    /// The length of a camera transition before Reduce Motion: none, every camera change cuts (feature 127).
    nonisolated static let cameraTransition = 0.0

    /// The experience this presenter draws.
    let experienceID: ExperienceID
    /// What the controls show.
    let mirror = AnatomyMirror()
    /// Whether the GPU side is set up (between `setup` and `teardown`).
    private(set) var isLive = false
    /// The renderers of the current tier's item meshes, by mesh id; empty after `teardown`.
    private(set) var renderers: [String: MeshRenderer] = [:]
    /// The tier the renderers were made for; nil while there are none.
    private(set) var rendererTier: Int?
    /// The depth-correct pass; made in `setup`, released in `teardown`.
    private(set) var depthPass: DepthMeshPass?
    /// How many times the renderers were made (all together each time).
    private(set) var resourceBuildCount = 0
    /// The camera of the last frame; nil before the first frame.
    private(set) var lastCamera: OrbitCamera?
    /// The pixel aspect (width / height) of the last frame.
    private(set) var lastAspect = 1.0
    /// The mesh ids drawn by the last frame, in draw order (the solid ones, then the ghosts).
    private(set) var lastDrawnMeshIDs: [String] = []
    /// The mesh ids drawn solid by the last frame, in draw order.
    private(set) var lastSolidMeshIDs: [String] = []
    /// The mesh ids drawn as ghosts by the last frame, in submission order.
    private(set) var lastGhostMeshIDs: [String] = []
    /// Whether ghosts are off for the rest of the session (a translucent draw failed); the hide mode is drawn.
    public private(set) var ghostsOff = false
    /// The test seam: the next draw with ghosts throws (it clears itself).
    var failNextTranslucentDraw = false
    /// How many times `view.json` was written.
    private(set) var viewWrites = 0
    /// How many writes of `view.json` failed.
    private(set) var viewWriteFailures = 0
    /// How many times an existing `view.json` was refused on opening (unreadable, damaged, newer, too large).
    private(set) var viewReadRefusals = 0
    /// The experience's storage; nil when there is none (nothing is written or read).
    let storage: ExperienceStorage?
    /// The port of the shell, for opening the view file; set by the factory.
    weak var port: ExperienceActionPort?
    /// Whether the view file was considered for opening (once per session; teardown forgets it).
    private(set) var openedViewFile = false
    /// The view seen last by `sync`; nil before the first.
    private var lastSeenView: AnatomyViewState?
    /// The view `view.json` is known to hold; nil when unknown.
    private var storedView: AnatomyViewState?
    /// The tier of the last frame.
    private(set) var lastTier = 0
    /// The drawable size in pixels of the last frame; nil before the first.
    private(set) var lastCanvas: Vec2?
    /// The core of the last frame or description; nil before the first.
    private(set) var lastCore: AnatomyCore?
    /// The canvas gestures: drag, pinch and tap (feature 127).
    private(set) var gestures = AnatomyGestures()
    /// Whether Reduce Motion was on when the experience was made; nothing animates either way (feature 127).
    let reduceMotion: Bool
    /// The points-per-pixel factor used for the label canvas before the overlay reports its size (feature 127).
    let displayScale: Double
    /// The labels placed for the last drawn frame, in placing order (feature 127).
    private(set) var lastLabels: [AnchoredLabelLayout.Placement] = []
    /// The canvas size in points the last labels were laid out in; nil before the first frame (feature 127).
    private(set) var lastLabelCanvas: Vec2?
    /// The rate limit of the announcements (feature 127).
    private(set) var planner = AnnouncementPlanner(minimumInterval: AnatomyPresenter.announcementInterval)
    /// The host's frame clock, seconds: the sum of the drawn frames' `delta` (feature 127).
    private(set) var clock = 0.0
    /// The selection last seen by the announcements: nil before the first state, `.some(nil)` with none (feature 127).
    private var announcedSelection: Int??
    /// Where posted announcements go: by default a VoiceOver announcement, only while VoiceOver runs (feature 127).
    var announcementSink: @MainActor (String) -> Void = AnatomyPresenter.voiceOverAnnouncement
    /// Every announcement posted to the sink, oldest first (feature 127).
    private(set) var announced: [String] = []
    /// Loads the review record of a region (test seam; by default the bundled record); setting it reloads (feature
    /// 128).
    var reviewRecordLoader: (AnatomyRegion) -> Result<AnatomyReviewRecord, ContentRefusal> =
        AnatomyPresenter.bundledReviewRecord {
        didSet { loadedReviewRecord = nil }
    }
    /// The review record the panel uses: nil before the first state, `.some(nil)` when the record was refused
    /// (feature 128).
    private var loadedReviewRecord: AnatomyReviewRecord??
    /// How many times the review record was refused; each refusal leaves only the not-reviewed line (feature 128).
    private(set) var reviewRecordProblems = 0

    /// The number of renderers made now.
    var rendererCount: Int { renderers.count }

    /// The length of every camera change: `transitionDuration(0, reduceMotion:)`, 0 in every mode (feature 127).
    var cameraTransitionSeconds: Double {
        transitionDuration(Self.cameraTransition, reduceMotion: reduceMotion)
    }

    /// A presenter for the experience `experienceID` storing its view file in `storage` (none when nil);
    /// `reduceMotion` is the factory's setting (nothing animates either way); `displayScale` turns pixels into points
    /// for the labels until the overlay reports its size (nil: the current trait collection's, else 2).
    init(experienceID: ExperienceID, storage: ExperienceStorage? = nil, reduceMotion: Bool = false,
         displayScale: Double? = nil) {
        self.experienceID = experienceID
        self.storage = storage
        self.reduceMotion = reduceMotion
        let traitScale = Double(UITraitCollection.current.displayScale)
        let scale = displayScale ?? (traitScale > 0 ? traitScale : 2)
        self.displayScale = scale.isFinite && scale > 0 ? scale : 2
    }

    /// The production announcement sink: posts `text` as a VoiceOver announcement only while VoiceOver is running.
    static func voiceOverAnnouncement(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    // MARK: Render scene

    /// Makes the depth pass and the current tier's renderers with the host's registry (again after a recreation).
    public func setup(_ context: RenderContext) throws {
        releaseGPU()
        depthPass = DepthMeshPass(registry: context.resources)
        if let core = lastCore {
            try makeRenderers(core.scene, tier: core.tier, context: context)
        } else if let prepared = try? AnatomyCore.bundled.get(), prepared.scenes.indices.contains(lastTier) {
            try makeRenderers(prepared.scenes[lastTier], tier: lastTier, context: context)
        }
        isLive = true
    }

    /// Draws the visible items with depth through the core's camera at the pixel aspect.
    public func draw(_ core: AnatomyCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if frame.delta.isFinite, frame.delta > 0 { clock += frame.delta }
        defer { flushAnnouncements() }
        sync(core)
        var core = core
        if openViewFileIfNeeded(core), let opened = lastCore { core = opened }
        let width = Double(max(1, context.pixelWidth)), height = Double(max(1, context.pixelHeight))
        if depthPass == nil { depthPass = DepthMeshPass(registry: context.resources) }
        let scene = core.scene
        if rendererTier != core.tier || renderers.count != scene.items.count
            || scene.items.contains(where: { renderers[$0.meshID] == nil }) {
            // Something is missing or the tier changed: release all together and make all again.
            releaseRenderers()
            try makeRenderers(scene, tier: core.tier, context: context)
        }
        guard let depthPass else { return }
        let aspect = width / height
        let camera = core.camera(aspect: aspect)
        let selected = core.selectedIndex
        let solid = core.solidIndices
        let ghosts = ghostsOff ? [] : core.ghostIndices
        depthPass.clearColor = Self.backgroundColor
        var opaque: [DepthMeshPass.Item] = [], translucent: [DepthMeshPass.Item] = []
        var solidIDs: [String] = [], ghostIDs: [String] = []
        for item in scene.items {
            guard let renderer = renderers[item.meshID] else { continue }
            if solid.contains(item.structureIndex) {
                let color = item.structureIndex == selected ? Self.selectionColor : Self.color(item.layer)
                opaque.append(DepthMeshPass.Item(renderer: renderer, model: item.model, color: color))
                solidIDs.append(item.meshID)
            } else if ghosts.contains(item.structureIndex) {
                translucent.append(DepthMeshPass.Item(renderer: renderer, model: item.model,
                                                      color: Self.ghostColor(item.layer),
                                                      center: Self.boundsCenter(item.mesh)))
                ghostIDs.append(item.meshID)
            }
        }
        if translucent.isEmpty {
            try depthPass.draw(opaque, camera: camera, context: context)
        } else {
            do {
                if failNextTranslucentDraw {
                    failNextTranslucentDraw = false
                    throw AnatomyGhostFailure()
                }
                try depthPass.draw(opaque, translucent: translucent, camera: camera, context: context)
            } catch {
                // Ghosts are off for the session: the hide mode is drawn instead.
                ghostsOff = true
                mirror.ghostsOff = true
                ghostIDs = []
                try depthPass.draw(opaque, camera: camera, context: context)
            }
        }
        lastCamera = camera
        lastAspect = aspect
        lastSolidMeshIDs = solidIDs
        lastGhostMeshIDs = ghostIDs
        lastDrawnMeshIDs = solidIDs + ghostIDs
        lastTier = core.tier
        lastCanvas = Vec2(width, height)
        placeLabels(core, camera: camera, aspect: aspect, pixels: Vec2(width, height))
    }

    // MARK: Labels

    /// The labels of `core` seen through `camera` with `aspect` on a canvas of `canvas` points: the solid parts'
    /// candidates (`AnatomyLabels.candidates`, the selection first) placed by `AnchoredLabelLayout`, at most the
    /// level's label budget.
    nonisolated static func labelPlacements(_ core: AnatomyCore, camera: OrbitCamera, aspect: Double,
                                            canvas: Vec2) -> [AnchoredLabelLayout.Placement] {
        let candidates = AnatomyLabels.candidates(scene: core.scene, solid: core.solidIndices,
                                                  selected: core.selectedIndex)
        return AnchoredLabelLayout.place(candidates, camera: camera, aspect: aspect, canvas: canvas,
                                         budget: core.scene.quality.maxLabels)
    }

    /// Places the labels of the frame just drawn on the canvas in points (the overlay's reported size, else `pixels`
    /// over ``displayScale``) and shows them in the mirror.
    private func placeLabels(_ core: AnatomyCore, camera: OrbitCamera, aspect: Double, pixels: Vec2) {
        let canvas: Vec2
        if let reported = mirror.overlaySize, reported.x > 0, reported.y > 0, reported.isFinite {
            canvas = reported
        } else {
            canvas = Vec2(pixels.x / displayScale, pixels.y / displayScale)
        }
        let placed = Self.labelPlacements(core, camera: camera, aspect: aspect, canvas: canvas)
        lastLabels = placed
        lastLabelCanvas = canvas
        let parts = core.scene.parts
        let labels = placed.compactMap { placement -> AnatomyCanvasLabel? in
            guard parts.indices.contains(placement.id) else { return nil }
            return AnatomyCanvasLabel(index: placement.id, text: parts[placement.id].englishName,
                                      minX: placement.minX, minY: placement.minY,
                                      width: placement.maxX - placement.minX, height: placement.maxY - placement.minY)
        }
        if mirror.labels != labels { mirror.labels = labels }
        if mirror.canvasSize != canvas { mirror.canvasSize = canvas }
    }

    /// The labels over the canvas (``AnatomyOverlay``); the host draws it with hit testing off.
    public func makeCanvasOverlay(_ port: ExperienceActionPort) -> AnyView? {
        AnyView(AnatomyOverlay(mirror: mirror))
    }

    // MARK: Announcements

    /// The announcement of selecting the part named `name`: "<name> selected.".
    nonisolated static func selectedSentence(_ name: String) -> String {
        "\(name) selected."
    }

    /// Submits `text` to the planner at the frame clock and posts it when the planner lets it through.
    func announce(_ text: String, kind: AnnouncementKind = .state) {
        guard !text.isEmpty else { return }
        if let posted = planner.submit(Announcement(text: text, kind: kind, time: clock)) { post(posted.text) }
    }

    /// Records `text` and hands it to the sink.
    private func post(_ text: String) {
        announced.append(text)
        announcementSink(text)
    }

    /// Posts the held announcement once the planner's interval has passed on the frame clock.
    private func flushAnnouncements() {
        if let posted = planner.flush(now: clock) { post(posted.text) }
    }

    /// Announces a change of the selection since the state last seen; the first state announces nothing.
    private func noteSelection(_ core: AnatomyCore) {
        let selected = core.selectedIndex
        defer { announcedSelection = .some(selected) }
        guard let previous = announcedSelection, previous != selected else { return }
        if let selected, core.scene.parts.indices.contains(selected) {
            announce(Self.selectedSentence(core.scene.parts[selected].englishName))
        } else {
            announce(Self.selectionClearedSentence)
        }
    }

    /// Releases every GPU object.
    public func teardown(_ context: RenderContext) {
        isLive = false
        releaseGPU()
        lastDrawnMeshIDs = []
        lastSolidMeshIDs = []
        lastGhostMeshIDs = []
        // A new session (a re-entry prepares the opening view again) opens from the view file again.
        openedViewFile = false
        lastSeenView = nil
        cancelPointers()
        // A new session announces from its own first state; nothing held is spoken later (feature 127).
        planner = AnnouncementPlanner(minimumInterval: Self.announcementInterval)
        announcedSelection = nil
        lastLabels = []
    }

    /// Releases the renderers and the depth pass, together.
    private func releaseGPU() {
        releaseRenderers()
        depthPass?.release()
        depthPass = nil
    }

    /// Releases every renderer, together.
    private func releaseRenderers() {
        for renderer in renderers.values { renderer.release() }
        renderers = [:]
        rendererTier = nil
    }

    /// Makes one renderer per item mesh of `scene` (the scene of `tier`), together; a failure releases those made
    /// and rethrows.
    private func makeRenderers(_ scene: AnatomyScene, tier: Int, context: RenderContext) throws {
        var made: [String: MeshRenderer] = [:]
        do {
            for item in scene.items where made[item.meshID] == nil {
                let renderer = try MeshRenderer(mesh: item.mesh, registry: context.resources)
                renderer.ambient = Self.ambient
                made[item.meshID] = renderer
            }
        } catch {
            for renderer in made.values { renderer.release() }
            throw error
        }
        renderers = made
        rendererTier = tier
        resourceBuildCount += 1
    }

    /// The ghost colour of `layer`: its colour at alpha 0.25.
    nonisolated static func ghostColor(_ layer: AnatomyLayer) -> Vec4 {
        let base = color(layer)
        return Vec4(base.x, base.y, base.z, ghostAlpha)
    }

    /// The centre of `mesh`'s bounds in model space (the origin for a mesh without a box).
    nonisolated static func boundsCenter(_ mesh: Mesh) -> Vec3 {
        if case let .box(low, high) = mesh.bounds { return (low + high) * 0.5 }
        return .zero
    }

    /// The colour of `layer`.
    nonisolated static func color(_ layer: AnatomyLayer) -> Vec4 {
        switch layer {
        case .bones: return bonesColor
        case .cartilage: return cartilageColor
        case .ligaments: return ligamentsColor
        }
    }

    /// The backdrop probe at (0.5, 0.04) from the top, expected dark, when its line of sight meets no drawn part
    /// (solid or ghost).
    public func probes(_ core: AnatomyCore) -> [FrameProbe] {
        guard let canvas = lastCanvas, canvas.y > 0 else { return [] }
        let aspect = canvas.x / canvas.y
        let drawn = core.solidIndices.union(ghostsOff ? [] : core.ghostIndices)
        let hit = Self.pick(ndc: Vec2(0, 1 - 2 * 0.04), camera: core.camera(aspect: aspect), aspect: aspect,
                            scene: core.scene, candidates: drawn)
        guard hit == nil,
              let probe = FrameProbe(name: "background", x: 0.5, y: 0.04, expected: FrameColorClass.dark.rawValue)
        else { return [] }
        return [probe]
    }

    // MARK: Words and controls

    /// Shows `core` in the mirror.
    func sync(_ core: AnatomyCore) {
        lastCore = core
        if !mirror.ready { mirror.ready = true }
        let parts = core.scene.parts.map { AnatomyPartRow(name: $0.englishName, layer: $0.layer ?? .bones) }
        if mirror.parts != parts { mirror.parts = parts }
        if mirror.visibleLayers != core.view.visibleLayers { mirror.visibleLayers = core.view.visibleLayers }
        if mirror.selected != core.selectedIndex { mirror.selected = core.selectedIndex }
        if mirror.camera != core.view.camera { mirror.camera = core.view.camera }
        let solid = core.solidIndices
        if mirror.solid != solid { mirror.solid = solid }
        if mirror.isolate != core.view.isolate { mirror.isolate = core.view.isolate }
        if mirror.isolateMode != core.isolateMode { mirror.isolateMode = core.isolateMode }
        let panel = AnatomyPanel.make(partIndex: core.selectedIndex, region: core.region,
                                      record: reviewRecord(for: core.region))
        if mirror.panel != panel { mirror.panel = panel }
        if mirror.ghostsOff != ghostsOff { mirror.ghostsOff = ghostsOff }
        noteView(core.view)
        noteSelection(core)
    }

    /// The bundled review record of `region`, `AnatomyReviewRecord.bundled(for:)` (feature 128).
    nonisolated static func bundledReviewRecord(_ region: AnatomyRegion) -> Result<AnatomyReviewRecord, ContentRefusal> {
        AnatomyReviewRecord.bundled(for: region)
    }

    /// The review record for `region` from ``reviewRecordLoader``, loaded once (again after the loader changes);
    /// nil when it was refused, which is counted in ``reviewRecordProblems`` (feature 128).
    func reviewRecord(for region: AnatomyRegion) -> AnatomyReviewRecord? {
        if let loaded = loadedReviewRecord { return loaded }
        let record: AnatomyReviewRecord?
        switch reviewRecordLoader(region) {
        case .success(let value): record = value
        case .failure: record = nil; reviewRecordProblems += 1
        }
        loadedReviewRecord = .some(record)
        return record
    }

    // MARK: View file

    /// Writes `view.json` when `view` differs from the view seen last and from the one the file holds; the first
    /// view seen is only remembered.
    private func noteView(_ view: AnatomyViewState) {
        defer { lastSeenView = view }
        guard let seen = lastSeenView, seen != view, view != storedView, let storage else { return }
        do {
            try storage.write(AnatomyViewDocument.encode(view), to: AnatomyViewDocument.fileName)
            viewWrites += 1
            storedView = view
        } catch {
            viewWriteFailures += 1
        }
    }

    /// On the first frame: when `core` holds the opening view and `view.json` decodes to another view, sends
    /// `view.apply` through the port; true when that was accepted. Considered once per presenter (again only while
    /// the port says the experience is not active yet).
    private func openViewFileIfNeeded(_ core: AnatomyCore) -> Bool {
        guard !openedViewFile else { return false }
        guard core.view == .opening, let storage, storage.exists(AnatomyViewDocument.fileName) else {
            openedViewFile = true
            return false
        }
        let data: Data
        do {
            data = try storage.read(AnatomyViewDocument.fileName)
        } catch {
            openedViewFile = true
            viewReadRefusals += 1
            return false
        }
        let decoded: (Result<AnatomyViewState, ContentRefusal>, dropped: [String]) =
            AnatomyViewDocument.decode(data, parts: core.partIDs)
        guard case .success(let view) = decoded.0 else {
            openedViewFile = true
            viewReadRefusals += 1
            return false
        }
        guard view != core.view else {
            openedViewFile = true
            storedView = view
            return false
        }
        guard let port else { return false }
        let previous = storedView
        storedView = view   // the file already holds it: opening writes nothing
        let result = port.send("view.apply", AnatomyCore.viewApplyValues(view, parts: core.partIDs))
        if !result.isAccepted { storedView = previous }
        if case .rejected(.notActive) = result { return false }
        openedViewFile = true
        return result.isAccepted
    }

    /// The search results of `query` over the region of the last core seen (`AnatomySearch.results`); empty before
    /// the first core.
    func searchResults(_ query: String) -> [AnatomySearch.Result] {
        guard let region = lastCore?.region else { return [] }
        return AnatomySearch.results(query, region: region)
    }

    /// The canvas description (`AnatomyCore.describe()`).
    public func describe(_ core: AnatomyCore) -> String {
        sync(core)
        return core.describe()
    }

    /// The native controls, sending through `port`.
    public func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AnatomyControls(port: port, mirror: mirror, presenter: self))
    }

    /// Every action has a native control (`view.apply` is sent by the presenter itself when it opens the view
    /// file).
    public var nativeActions: Set<String> { Set(AnatomyCore.actionIDs) }

    /// The actions the canvas gestures send (drag, pinch and tap; ``AnatomyGestures``).
    public var gestureActions: Set<String> { AnatomyGestures.gestureActions }

    /// The answer to a refused `control` in words; empty when accepted.
    nonisolated static func answerWords(control: String, result: ActionResult) -> String {
        guard !result.isAccepted else { return "" }
        if result == .rejected(.rule(code: AnatomyRule.cameraLimit)) { return cameraLimitSentence }
        if result == .rejected(.rule(code: AnatomyRule.hiddenStructure)) {
            return "That structure is on a hidden layer."
        }
        switch control {
        case "camera.turn": return "The camera turns one step left or right."
        case "camera.tilt": return "The camera is tilted as far as it goes."
        case "camera.zoom": return "The camera is zoomed as far as it goes."
        case "structure.select": return "There is no such structure."
        case "layer.show", "isolate.layer": return "There is no such layer."
        case "isolate.part": return "There is no such structure."
        case "isolate.mode": return "The isolate either ghosts or hides the rest."
        case "view.apply": return "The saved view could not be opened."
        default: return "That is not possible here."
        }
    }

    /// Sends `control` with `values` through `port` and shows the answer in the mirror (empty when accepted); a camera
    /// step refused at a limit is also announced ("The camera is at its limit.", rate-limited; feature 127).
    @discardableResult
    func send(_ control: String, _ values: [Double] = [], through port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        let words = Self.answerWords(control: control, result: result)
        if mirror.message != words { mirror.message = words }
        if result == .rejected(.rule(code: AnatomyRule.cameraLimit)) { announce(words, kind: .rejection) }
        return result
    }

    // MARK: Pointer and picking

    /// Forgets every touch in progress (suspension and teardown); sends nothing.
    public func cancelPointers() {
        gestures.reset()
    }

    /// A canvas touch through ``AnatomyGestures``: a drag turns and tilts, a pinch zooms (each step through
    /// ``send(_:_:through:)``, which answers a refused step), and a single-finger tap picks
    /// (``tap(atNDC:through:)``).
    public func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        var current = gestures
        var taps: [Vec2] = []
        current.handle(event, send: { self.send($0, $1, through: port) }, tap: { taps.append($0) })
        gestures = current
        for point in taps {
            guard let ndc = Self.ndc(of: point, viewSize: viewSize) else { continue }
            tap(atNDC: ndc, through: port)
        }
    }

    /// The normalised device point (x, y in −1…1, y up) of the view point `point` in a view of `viewSize` points;
    /// nil for an empty view or a non-finite point.
    nonisolated static func ndc(of point: Vec2, viewSize: Vec2) -> Vec2? {
        guard viewSize.x > 0, viewSize.y > 0, point.isFinite, viewSize.isFinite else { return nil }
        return Vec2(2 * point.x / viewSize.x - 1, 1 - 2 * point.y / viewSize.y)
    }

    /// The part among `candidates` (inventory indices) the line of sight through `ndc` meets first, as
    /// `AnatomyPicker` picks it (nearest hit; ties within `AnatomyPicker.tieTolerance` go to the lower index);
    /// nil on a miss. Taps pass `AnatomyCore.solidIndices`, so a ghost or a hidden part is never picked.
    static func pick(ndc: Vec2, camera: OrbitCamera, aspect: Double, scene: AnatomyScene,
                     candidates: Set<Int>) -> (index: Int, distance: Double)? {
        let ray = camera.ray(ndc: ndc, aspect: aspect)
        guard let line = Ray3(origin: ray.origin, direction: ray.direction) else { return nil }
        var best: (index: Int, distance: Double)?
        for item in scene.items where candidates.contains(item.structureIndex) {
            guard line.intersect(sphereCenter: item.worldCenter, radius: max(item.worldRadius, 1e-9)) != nil else {
                continue
            }
            let corners = item.worldTriangles
            var t = 0
            while t + 2 < corners.count {
                if let hit = line.intersect(triangle: corners[t], corners[t + 1], corners[t + 2]) {
                    let candidate = (index: item.structureIndex, distance: hit.distance)
                    if let current = best {
                        if abs(candidate.distance - current.distance) <= AnatomyPicker.tieTolerance {
                            if candidate.index < current.index { best = candidate }
                        } else if candidate.distance < current.distance {
                            best = candidate
                        }
                    } else {
                        best = candidate
                    }
                }
                t += 3
            }
        }
        return best
    }

    /// Picks the part under `ndc` with the camera and aspect of the last drawn frame and sends
    /// `structure.select [i]` on a hit, `structure.clear` on a miss. Nil (nothing sent) before the first frame.
    @discardableResult
    func tap(atNDC ndc: Vec2, through port: ExperienceActionPort) -> ActionResult? {
        guard let camera = lastCamera, let core = lastCore else { return nil }
        if let hit = Self.pick(ndc: ndc, camera: camera, aspect: lastAspect, scene: core.scene,
                               candidates: core.solidIndices) {
            return send("structure.select", [Double(hit.index)], through: port)
        }
        return send("structure.clear", through: port)
    }
}
