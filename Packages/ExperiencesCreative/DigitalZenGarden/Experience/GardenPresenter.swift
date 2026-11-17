// GardenPresenter — feature 146 (A20-P02) T-A20-204, T-A20-206 (FR-A20-201–205, FR-A20-207; clarifications Q1–Q4;
// contracts/experience.md). Draws Digital Zen Garden through the host only and owns its presentation state:
//
//   - Scene: a `SandScene` inside a `CachedScene` (not pass-through), both made in every `setup`; the field is
//     replayed from the last core seen, so a context recreation rebuilds it. A resize replays it at the next draw.
//     Each `draw` brings the field up to the core (`SandScene.sync`: a commit or a replay after undo, redo or a
//     restore) with the stroke in progress (not while the garden is at its stroke cap, and not a stroke whose touches
//     were cancelled), sets the tone and the grain (level-0, the full level) and sets the cache key from the field's revision, the
//     tone and the tier: a still garden is drawn once and the cached picture is repeated (`maxFramesPerSecond` 30).
//   - Pointer: one finger rakes. A touch that begins outside the tray is ignored until it enters it; then
//     `stroke.begin` with the tray point and the rake style, `stroke.add` with each new point (clamped to the tray;
//     the unused pairs repeat it) and `stroke.end` when the finger lifts, inside the tray or not. A second finger is
//     ignored. A cancelled touch, and `cancelPointers`, end the drag without a commit (the core's stroke in progress
//     is discarded by the next `stroke.begin` and is not drawn meanwhile). A `stroke.begin` the core refuses
//     ends the drag there.
//   - Preview, words and views: the brush preview follows the finger (`BrushPreviewModel`); the canvas overlay is
//     `BrushPreview`; the controls are `GardenControls` over the mirror; the canvas label names the tone, the rake
//     and the number of strokes. Probes: the top-leading corner is outside the tray (`dark`).
//
// No GL call: everything is drawn through VisualCoreRendering's scenes.
import Foundation
import DigitalZenGardenCore
import Observation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show, updated only when a field changes.
@MainActor
@Observable
final class GardenMirror {
    /// The rake style index (0 fine, 1 wide).
    var rakeStyle = 0
    /// The tone index of `GardenPalette.tones`.
    var tone = 0
    /// Whether undo is possible.
    var canUndo = false
    /// Whether redo is possible.
    var canRedo = false
    /// The number of strokes of the garden.
    var strokeCount = 0
    /// The short message of a refused stroke; nil when there is none.
    var message: String?
}

/// Draws Digital Zen Garden and owns its presentation state (see the file header).
@MainActor
final class GardenPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = GardenCore

    /// The sentence shown when a stroke is refused because the garden is full.
    static let fullMessage = "The garden holds \(GardenDocument.maxStrokes) strokes. Undo one to rake again."

    /// Whether Reduce Motion was on when the experience was made (nothing animates on its own either way).
    let reduceMotion: Bool
    /// Whether the sand uses the 8-bit fallback even where half floats render (tests).
    let forceFallback: Bool
    /// What the controls show.
    let mirror = GardenMirror()
    /// The brush preview the overlay draws.
    let preview = BrushPreviewModel()
    /// The port of the shell, for the controls' identifiers; set by the factory.
    var port: ExperienceActionPort?
    /// The sand drawn; made in `setup`, released in `teardown`.
    private(set) var sand: SandScene?
    /// The cache around `sand`.
    private(set) var cache: CachedScene?
    /// The last core drawn or followed.
    private(set) var lastCore = GardenCore()
    /// How many times `setup` made the scenes.
    private(set) var setupCount = 0
    /// The pointer that rakes, or that waits outside the tray; nil without one.
    private(set) var activePointer: Int?
    /// Whether the active pointer has begun a stroke.
    private(set) var isStroking = false
    /// The last tray point sent for the active pointer.
    private(set) var lastTrayPoint: Vec2?
    /// The raw points of a stroke in progress whose touches were cancelled: not drawn until the core's stroke changes.
    private(set) var cancelledStroke: [Vec2]?
    /// Whether the next draw replays the field (after a resize).
    private var replayPending = false
    /// The frame cap: 30 frames per second (nothing moves on its own).
    var maxFramesPerSecond: Int { 30 }

    /// A presenter; `reduceMotion` is recorded (raking is direct and nothing animates); `forceFallback` stores the
    /// field in `rgba8`.
    init(reduceMotion: Bool = false, forceFallback: Bool = false) {
        self.reduceMotion = reduceMotion
        self.forceFallback = forceFallback
    }

    // MARK: Render scene

    /// Makes the sand and its cache and replays the field from the last core seen.
    func setup(_ context: RenderContext) throws {
        if let cache { cache.teardown(context) }
        let made = SandScene(forceFallback: forceFallback)
        made.rebuild(from: lastCore.document.strokes)
        made.stampInProgress(drawnPending(lastCore))
        let wrapper = CachedScene(child: made)
        wrapper.passThrough = false
        try wrapper.setup(context)
        sand = made
        cache = wrapper
        replayPending = false
        setupCount += 1
    }

    /// Passes the new drawable size on; the next draw replays the field.
    func resize(_ context: RenderContext) {
        cache?.resize(context)
        replayPending = true
    }

    /// Brings the field up to `core`, sets the tone and grain of `tier` and draws (the cached picture when nothing
    /// changed).
    func draw(_ core: GardenCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        follow(core)
        guard let sand, let cache else { return }
        let pending = drawnPending(core)
        if replayPending {
            replayPending = false
            sand.stampInProgress(pending)
            sand.rebuild(from: core.document.strokes)
        } else {
            sand.sync(strokes: core.document.strokes, pending: pending)
        }
        let tone = GardenPalette.tones[core.toneIndex]
        sand.tone = SIMD3(Float(tone.red), Float(tone.green), Float(tone.blue))
        sand.grain = tier == 0
        var hasher = Hasher()
        hasher.combine(sand.revision)
        hasher.combine(core.toneIndex)
        hasher.combine(tier)
        cache.key = hasher.finalize()
        try cache.render(context, frame: frame)
    }

    /// Releases the cache and the sand.
    func teardown(_ context: RenderContext) {
        cache?.teardown(context)
        cache = nil
        sand = nil
    }

    /// The stroke in progress to draw for `core`: none at the stroke cap or for a cancelled stroke.
    private func drawnPending(_ core: GardenCore) -> RakeStroke? {
        if let cancelledStroke {
            if core.isRaking, core.inProgress == cancelledStroke { return nil }
            self.cancelledStroke = nil
        }
        guard !core.isAtStrokeCap else { return nil }
        return core.pendingStroke
    }

    // MARK: Pointer

    /// The tray width in view points of a view of `viewSize`.
    static func trayWidth(viewSize: Vec2) -> Double {
        TrayFit.rect(width: viewSize.x, height: viewSize.y).width
    }

    /// Turns one finger's touches into the stroke actions (see the file header) and moves the preview.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard viewSize.isFinite, viewSize.x > 0, viewSize.y > 0, event.location.isFinite else { return }
        switch event.phase {
        case .began:
            guard activePointer == nil else { return }
            activePointer = event.id
            isStroking = false
            lastTrayPoint = nil
            move(event, viewSize: viewSize, port: port)
        case .moved:
            guard activePointer == event.id else { return }
            move(event, viewSize: viewSize, port: port)
        case .ended:
            guard activePointer == event.id else { return }
            if isStroking {
                move(event, viewSize: viewSize, port: port)
                port.send("stroke.end")
            }
            finishPointer()
        case .cancelled:
            guard activePointer == event.id else { return }
            cancelStroke()
        }
    }

    /// Sends the touch's tray point: the begin when it first lies inside the tray, then an add for each new point.
    private func move(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let raw = TrayFit.trayPoint(event.location, viewSize: viewSize) else { return }
        let trayWidth = Self.trayWidth(viewSize: viewSize)
        if !isStroking {
            guard TrayFit.isInside(raw) else { return }
            let rake = lastCore.rakeStyle
            let result = port.send("stroke.begin", [raw.x, raw.y, Double(rake)])
            guard result.isAccepted else {
                finishPointer()
                return
            }
            isStroking = true
            cancelledStroke = nil
            lastTrayPoint = raw
            mirror.message = lastCore.isAtStrokeCap ? Self.fullMessage : nil
            preview.show(at: event.location, direction: nil, rakeStyle: rake, trayWidth: trayWidth)
            return
        }
        let point = TrayFit.clamped(raw)
        let previous = lastTrayPoint
        if let previous, previous == point { return }
        lastTrayPoint = point
        var values: [Double] = []
        values.reserveCapacity(GardenCore.pointsPerAdd * 2)
        for _ in 0..<GardenCore.pointsPerAdd {
            values.append(point.x)
            values.append(point.y)
        }
        port.send("stroke.add", values)
        var direction: Vec2?
        if let previous {
            direction = Vec2((point.x - previous.x) * trayWidth,
                             (point.y - previous.y) * trayWidth / GardenPalette.smallTray.aspect)
        }
        let rake = lastCore.inProgressRake ?? lastCore.rakeStyle
        preview.show(at: event.location, direction: direction, rakeStyle: rake, trayWidth: trayWidth)
    }

    /// Forgets the active pointer and hides the preview.
    private func finishPointer() {
        activePointer = nil
        isStroking = false
        lastTrayPoint = nil
        preview.hide()
    }

    /// Ends the drag without a commit: the stroke in progress is no longer drawn.
    private func cancelStroke() {
        if isStroking, lastCore.isRaking { cancelledStroke = lastCore.inProgress }
        finishPointer()
    }

    /// Forgets every touch in progress without committing a stroke and hides the preview.
    func cancelPointers() {
        cancelStroke()
    }

    /// The three stroke actions a drag sends.
    var gestureActions: Set<String> { GardenCore.strokeActionIDs }

    /// The actions of the native controls: the stroke actions (the patterns), the rake, the tone, undo and redo.
    var nativeActions: Set<String> { Set(GardenCore.actionIDs) }

    // MARK: Words, probes and views

    /// Brings the mirror up to `core` (each field written only when it changes).
    func follow(_ core: GardenCore) {
        lastCore = core
        if mirror.rakeStyle != core.rakeStyle { mirror.rakeStyle = core.rakeStyle }
        if mirror.tone != core.toneIndex { mirror.tone = core.toneIndex }
        if mirror.canUndo != core.history.canUndo { mirror.canUndo = core.history.canUndo }
        if mirror.canRedo != core.history.canRedo { mirror.canRedo = core.history.canRedo }
        if mirror.strokeCount != core.document.strokes.count { mirror.strokeCount = core.document.strokes.count }
        let message: String? = core.lastRefusal == nil ? (core.isAtStrokeCap && core.isRaking ? Self.fullMessage : nil)
            : Self.fullMessage
        if mirror.message != message { mirror.message = message }
    }

    /// The canvas label: "Zen garden, <tone>, <rake>, <n> strokes", for example "Zen garden, Pale sand, Fine rake,
    /// 3 strokes".
    func describe(_ core: GardenCore) -> String {
        follow(core)
        let tone = GardenPalette.tones[core.toneIndex].name
        let rake = GardenCore.rake(index: core.rakeStyle).name
        let count = core.document.strokes.count
        return "Zen garden, \(tone), \(rake), \(count) " + (count == 1 ? "stroke" : "strokes")
    }

    /// One probe at the top-leading corner, outside the tray: `dark`.
    func probes(_ core: GardenCore) -> [FrameProbe] {
        [FrameProbe(name: "corner", x: 0, y: 0, expected: FrameColorClass.dark.rawValue)].compactMap { $0 }
    }

    /// The brush preview over the canvas (``BrushPreview``).
    func makeCanvasOverlay(_ port: ExperienceActionPort) -> AnyView? {
        AnyView(BrushPreview(model: preview))
    }

    /// The native controls (``GardenControls``), sending through `port`.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(GardenControls(port: port, mirror: mirror))
    }
}
