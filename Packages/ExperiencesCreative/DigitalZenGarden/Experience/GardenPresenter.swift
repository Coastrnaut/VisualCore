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
// Feature 147 (A20-P03) T-A20-303, T-A20-305 (FR-A20-301–306; clarifications Q1–Q5; contracts/stones.md "Gestures";
// gaps G-STONES, G-SELECTION, G-SHADOWS):
//   - Scene: each draw also brings the stone layer up to the garden's stones (`SandScene.syncStones`); the first
//     draw after a resize and every `setup` (a new context) rasterize it again. The cache key includes the layer.
//   - Tool: with `tool.mode [0]` (rake) a drag rakes as before and the stones stay on top. With `tool.mode [1]`
//     (stones) one finger that lifts within 10 points of where it landed is a tap: `stone.select` with the id of the
//     topmost stone under it (`StoneSelection.topmost`), or 0 on empty sand. A one-finger drag that starts on the
//     selected stone moves it: the overlay shows the stone's outline at the dragged place and one `stone.move` (the
//     new centre, clamped inside the tray) is sent when the finger lifts. A second finger turns the selected stone
//     with `RotateRecognizer` (a drag in progress is dropped): the overlay shows the turned outline and one
//     `stone.rotate` is sent when a finger of the pair lifts. A cancelled touch, or `cancelPointers`, sends nothing.
//     Nothing animates: Reduce Motion changes nothing (placing and moving are direct).
//   - Selection: the overlay draws a dashed outline of the selected stone with its kind's name (hidden from assistive
//     technology); the controls speak "<kind> selected, <n> of <count>, turned <degrees>°" (n in depth order from the
//     lowest; degrees positive clockwise), never colour alone.
//   - Gestures: the stroke actions and `stone.select`, `stone.move` and `stone.rotate`; every one is a native action.
//
// Feature 148 (A20-P04) T-A20-402, T-A20-403, T-A20-405 (FR-A20-401, FR-A20-403, FR-A20-405; clarifications Q1, Q3,
// Q4, Q5; gaps G-LIBRARY, G-A11Y):
//   - Library: the presenter holds the `GardenLibrary` over the launch's storage (nil without storage) and the
//     library actions (`saveGarden`, `openGarden`, `renameGarden`, `deleteGarden`, in GardenLibrary.swift). Opening
//     restores the saved document through the shell (`restoreDocument`, set by the factory), so the undo history
//     restarts and the digest equals the opened document's.
//   - Words: the canvas description always names the tone, the rake, the strokes, the stones and the selection, for
//     example "Zen garden, Pale sand, Fine rake, 3 strokes, 2 stones, No stone selected". The mirror carries the
//     spoken values of undo and redo ("a stroke", "moving a stone", "nothing to undo").
//   - Announcements through `port.announce` (route `feedback`): "Undid <command>" and "Redid <command>" (for
//     example "Undid a stroke", "Redid moving a stone"), "Saved <name>.", "Opened <name>.", "Renamed <old> to
//     <new>.", "Deleted <name>.", the picture's outcome, and each refusal (a full garden, the stone cap, a library
//     refusal) of kind `.rejection`.
//   - Still: `makeStill(renderer:)` exports the 1600 × 1200 PNG through `GardenStill` for the share control.
//
// Feature 149 (A20-P05) T-A20-503 (FR-A20-501–503; clarifications Q1–Q3; contracts/quiet.md; gap G-QUIET):
//   - Calm switches: the presenter keeps the person's `CalmSettings`, read from the experience value `calm.v1` when it
//     is made (damaged or missing: all off). A calm action the core accepted (its `calmRevision` moved) is adopted and
//     written back; a core that lost the switches (a restore or a fresh preparation, revision 0) gets the kept switches
//     again through the port at the next draw (`applyKeptCalm()`, also run by the controls when they appear).
//   - Drift: with `calm.drift` on and Reduce Motion off, each draw adds the frame's delta to `driftTime` and the grain
//     moves by `driftSpeed` (0.01) tray widths per second (`SandScene.grainOffset`, wrapped every `driftPeriod` tray
//     widths); the cache key then includes the offset, so a frame is drawn each draw (at most 30 per second).
//     Otherwise the offset is 0, `driftTime` restarts and the cached still frame is reused. Reduce Motion (`reduceMotion`,
//     read at launch, may turn on later) stops the drift at the next draw without changing the switch. The relief,
//     stones and shadows never move and nothing flashes, so Reduce Flashing changes nothing.
//   - Sound: `soundSink` (default `GardenSoundPlayer`, VisualCore's `SoundEffectPlayer`) is enabled only while
//     `calm.sound` is on; the `stroke` tone follows a committed stroke (a drag or a pattern), `place` a placed stone and
//     `remove` a removed stone. Every tone stops when the experience suspends (`cancelPointers`) or tears down.
//   - Haptics: with `calm.haptics` on, `HapticKind.selection` when a stone is selected and `.impactLight` when one is
//     placed, through `feedback` (the person's switch and the rate limit decide).
//   Neither sound nor haptics changes the state.
//
// No GL call: everything is drawn through VisualCoreRendering's scenes.
import Foundation
import DigitalZenGardenCore
import Observation
import SwiftUI
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

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
    /// The short message of a refused stroke or stone; nil when there is none.
    var message: String?
    /// The canvas tool: 0 rake, 1 stones (feature 147).
    var toolMode = 0
    /// The garden's stones (feature 147).
    var stones: [Stone] = []
    /// The selected stone's id; nil when none is (feature 147).
    var selectedStone: UInt32?
    /// The kind index the "Place" control places (presentation only; feature 147).
    var placeKind = 0
    /// Whether a place was refused at the stone cap and the garden is still full (feature 147).
    var stoneCapShown = false
    /// The spoken selection: "<kind> selected, <n> of <count>, turned <degrees>°" or "No stone selected" (feature 147).
    var selectionValue = GardenPresenter.noSelectionValue
    /// The spoken value of undo: the command it undoes ("a stroke") or "nothing to undo" (feature 148).
    var undoValue = GardenPresenter.nothingToUndo
    /// The spoken value of redo: the command it redoes or "nothing to redo" (feature 148).
    var redoValue = GardenPresenter.nothingToRedo
    /// The last sentence of the library (saved, opened, renamed, deleted or refused); nil before one (feature 148).
    var libraryMessage: String?
    /// The written still the share control offers; nil before an export and after a failure (feature 148).
    var stillURL: URL?
    /// The sentence of the last still export; nil before one (feature 148).
    var stillMessage: String?
    /// The calm switches the controls show (feature 149).
    var calm = CalmSettings.off
}

/// A touch of the stone tool in progress (feature 147).
struct StoneTouch: Equatable {
    /// The pointer's id.
    var id: Int
    /// Where it landed, in view points.
    var start: Vec2
    /// The selected stone's centre when it landed, when it landed on that stone; nil otherwise.
    var stoneStart: Vec2?
    /// Whether it moved farther than ``GardenPresenter/tapSlop`` (no longer a tap).
    var moved = false
    /// The dragged stone's new centre (normalized tray coordinates) while it is dragged; nil otherwise.
    var dragTo: Vec2?
}

/// Draws Digital Zen Garden and owns its presentation state (see the file header).
@MainActor
final class GardenPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = GardenCore

    /// The sentence shown when a stroke is refused because the garden is full.
    static let fullMessage = "The garden holds \(GardenDocument.maxStrokes) strokes. Undo one to rake again."

    /// Whether Reduce Motion is on: read when the experience was made; turning it on stops the sand drift at the next
    /// draw without changing the switch (feature 149).
    var reduceMotion: Bool
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
    /// The touches of the stone tool (feature 147).
    private(set) var stoneTracker = PointerTracker()
    /// The two-finger turn of the selected stone (feature 147).
    private(set) var rotator = RotateRecognizer()
    /// The one-finger touch of the stone tool; nil without one (feature 147).
    private(set) var stoneTouch: StoneTouch?
    /// The selected stone's id and rotation when a two-finger turn began; nil without a turn (feature 147).
    private(set) var turnStart: (id: UInt32, rotation: Double)?
    /// The turned rotation shown while two fingers turn the selected stone; nil otherwise (feature 147).
    private(set) var turnTo: Double?
    /// How far, in view points, a finger may move and still tap (feature 147).
    static let tapSlop = 10.0
    /// The spoken selection without a selected stone (feature 147).
    static let noSelectionValue = "No stone selected"
    /// The frame cap: 30 frames per second (only the optional sand drift moves on its own).
    var maxFramesPerSecond: Int { 30 }
    /// The spoken value of undo with nothing to undo (feature 148).
    static let nothingToUndo = "nothing to undo"
    /// The spoken value of redo with nothing to redo (feature 148).
    static let nothingToRedo = "nothing to redo"

    /// The named gardens in the launch's storage; nil when the experience was made without storage (feature 148).
    let library: GardenLibrary?
    /// The still export for the share control (feature 148).
    let still: GardenStill
    /// Restores a document through the shell (the undo history restarts); set by the factory; returns whether the
    /// shell accepted it (feature 148).
    var restoreDocument: ((GardenDocument) -> Bool)?
    /// The shell's current core; set by the factory; nil falls back to the last core followed (feature 148).
    var coreSource: (() -> GardenCore?)?
    /// The route of the announcements (`ExperienceFeedback.shared` in the app; a recording route in tests).
    var feedback: ExperienceFeedback = .shared
    /// The name of the garden last saved or opened, the name field's suggestion; nil before one (feature 148).
    var openedName: String?
    /// Where the tones go (feature 149): `GardenSoundPlayer` in the app, a recording sink in tests (set after the
    /// factory; a new sink is enabled exactly when the sound switch of the last core seen is on).
    var soundSink: any GardenSoundSink {
        didSet { soundSink.isEnabled = lastCore.calm.sound }
    }
    /// The launch's storage, which keeps the calm switches as `calm.v1`; nil without storage (feature 149).
    let storage: ExperienceStorage?
    /// The person's calm switches: read from `calm.v1` when made, updated when a calm action is accepted (feature 149).
    private(set) var calm: CalmSettings
    /// Whether the kept switches are being sent to the core (the follow-ups of those sends are not adopted).
    private var applyingCalm = false
    /// Seconds of frame time the drift has run since it last started; 0 while it is off (feature 149).
    var driftTime = 0.0
    /// The grain offset of the last draw in tray widths; 0 without drift (feature 149).
    private(set) var grainOffset = 0.0
    /// The drift speed: 0.01 tray widths per second of frame time (feature 149).
    nonisolated static let driftSpeed = 0.01
    /// The grain offset wraps after this many tray widths (about 2.8 hours of drift), keeping the noise coordinates
    /// small (feature 149).
    nonisolated static let driftPeriod = 100.0

    /// A presenter; `reduceMotion` is recorded (raking is direct and nothing animates); `forceFallback` stores the
    /// field in `rgba8`; `storage` holds the library (none without it); `still` is the still export (feature 148).
    /// The calm switches are read from `storage`'s value `calm.v1` (all off without one or for damaged data);
    /// `soundSink` (nil: `GardenSoundPlayer`) and `feedback` (nil: the shared route) are the test seams of the tones
    /// and the haptics (feature 149). The sink starts disabled.
    init(reduceMotion: Bool = false, forceFallback: Bool = false, storage: ExperienceStorage? = nil,
         still: GardenStill = GardenStill(), soundSink: (any GardenSoundSink)? = nil,
         feedback: ExperienceFeedback? = nil) {
        self.reduceMotion = reduceMotion
        self.forceFallback = forceFallback
        library = storage.map { GardenLibrary(storage: $0) }
        self.still = still
        self.storage = storage
        calm = Self.keptCalm(storage)
        let sink = soundSink ?? GardenSoundPlayer()
        sink.isEnabled = false
        self.soundSink = sink
        self.feedback = feedback ?? .shared
        mirror.calm = calm
    }

    /// The calm switches kept in `storage` as `calm.v1`; all off without storage, without the value or for damaged
    /// data (feature 149).
    static func keptCalm(_ storage: ExperienceStorage?) -> CalmSettings {
        guard let data = storage?.value(for: CalmSettings.storageKey) else { return .off }
        return CalmSettings.decode(data) ?? .off
    }

    /// The shell's current core, or the last core followed (feature 148).
    var currentCore: GardenCore { coreSource?() ?? lastCore }

    // MARK: Render scene

    /// Makes the sand and its cache and replays the field from the last core seen.
    func setup(_ context: RenderContext) throws {
        if let cache { cache.teardown(context) }
        let made = SandScene(forceFallback: forceFallback)
        made.rebuild(from: lastCore.document.strokes)
        made.rebuildStones(from: lastCore.document.stones)
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
        var core = core
        if core.calm != calm, applyKeptCalm() { core = coreSource?() ?? core }
        follow(core)
        guard let sand, let cache else { return }
        let pending = drawnPending(core)
        if replayPending {
            replayPending = false
            sand.stampInProgress(pending)
            sand.rebuild(from: core.document.strokes)
            sand.rebuildStones(from: core.document.stones)
        } else {
            sand.sync(strokes: core.document.strokes, pending: pending)
            sand.syncStones(core.document.stones)
        }
        let tone = GardenPalette.tones[core.toneIndex]
        sand.tone = SIMD3(Float(tone.red), Float(tone.green), Float(tone.blue))
        sand.grain = tier == 0
        let drifting = core.calm.drift && !reduceMotion
        if drifting {
            driftTime += frame.delta.isFinite ? max(frame.delta, 0) : 0
            grainOffset = Self.driftOffset(seconds: driftTime)
        } else {
            driftTime = 0
            grainOffset = 0
        }
        sand.grainOffset = Float(grainOffset)
        var hasher = Hasher()
        hasher.combine(sand.revision)
        hasher.combine(sand.stoneRebuildCount)
        hasher.combine(core.toneIndex)
        hasher.combine(tier)
        if tier == 0, grainOffset != 0 { hasher.combine(grainOffset.bitPattern) }
        cache.key = hasher.finalize()
        try cache.render(context, frame: frame)
    }

    /// The grain offset in tray widths after `seconds` of drift: `driftSpeed × seconds`, wrapped every
    /// `driftPeriod` tray widths (feature 149).
    nonisolated static func driftOffset(seconds: Double) -> Double {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return (driftSpeed * seconds).truncatingRemainder(dividingBy: driftPeriod)
    }

    /// Releases the cache and the sand; every tone stops (feature 149).
    func teardown(_ context: RenderContext) {
        soundSink.stopAll()
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

    /// Turns the touches into the stroke actions of the rake tool or the stone actions of the stone tool (see the file
    /// header) and moves the preview.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard viewSize.isFinite, viewSize.x > 0, viewSize.y > 0, event.location.isFinite else { return }
        let stoneGesture = stoneTracker.count > 0
        if stoneGesture || (event.phase == .began && activePointer == nil && lastCore.toolMode == GardenCore.stoneTool) {
            stonePointer(event, viewSize: viewSize, port: port)
            return
        }
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
                let result = port.send("stroke.end")
                if result.isAccepted, currentCore.lastRefusal == nil { play(.stroke) }
                announceStrokeRefusal()
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

    /// Forgets every touch in progress without committing a stroke or a stone change and hides the preview; every
    /// tone stops (the shell calls it when the experience suspends; feature 149).
    func cancelPointers() {
        cancelStroke()
        resetStoneGesture()
        soundSink.stopAll()
    }

    // MARK: Stone tool

    /// The stone tool's handling of `event` (see the file header).
    private func stonePointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard stoneTracker.handle(event) else { return }
        rotator.handle(event, tracker: stoneTracker)
        switch event.phase {
        case .began:
            if stoneTracker.count == 1 {
                var touch = StoneTouch(id: event.id, start: event.location)
                if let stone = lastCore.selected, let tray = TrayFit.trayPoint(event.location, viewSize: viewSize),
                   StoneShape(stone: stone)?.contains(tray) == true {
                    touch.stoneStart = stone.position
                }
                stoneTouch = touch
            } else if stoneTracker.count == 2 {
                // A second finger: the one-finger touch is dropped and a turn of the selected stone begins.
                stoneTouch = nil
                if let stone = lastCore.selected { turnStart = (stone.id, stone.rotation) }
            }
        case .moved:
            if let start = turnStart {
                if rotator.state.isActive { turnTo = Self.normalizedAngle(start.rotation - rotator.angle) }
            } else if var touch = stoneTouch, touch.id == event.id {
                if (event.location - touch.start).length > Self.tapSlop { touch.moved = true }
                if touch.moved, let origin = touch.stoneStart {
                    touch.dragTo = Self.draggedCentre(origin, from: touch.start, to: event.location, viewSize: viewSize)
                }
                stoneTouch = touch
            }
        case .ended:
            if let start = turnStart {
                if rotator.state == .ended, let angle = turnTo, lastCore.selectedStone == start.id {
                    port.send("stone.rotate", [angle])
                }
                turnStart = nil
                turnTo = nil
            } else if let touch = stoneTouch, touch.id == event.id {
                if let origin = touch.stoneStart, touch.moved {
                    let target = Self.draggedCentre(origin, from: touch.start, to: event.location, viewSize: viewSize)
                    port.send("stone.move", [target.x, target.y])
                } else if !touch.moved, let tray = TrayFit.trayPoint(event.location, viewSize: viewSize) {
                    let id = TrayFit.isInside(tray) ? StoneSelection.topmost(at: tray, in: lastCore.document.stones) : nil
                    selectStone([Double(id ?? 0)], port: port)
                }
                stoneTouch = nil
            }
            if stoneTracker.count == 0 { resetStoneGesture() }
        case .cancelled:
            resetStoneGesture()
        }
        updateSelectionOutline()
    }

    /// The centre of a stone that was at `origin` (normalized tray coordinates) dragged from the view point `from` to
    /// `to`, clamped inside the tray.
    nonisolated static func draggedCentre(_ origin: Vec2, from: Vec2, to: Vec2, viewSize: Vec2) -> Vec2 {
        let tray = TrayFit.rect(width: viewSize.x, height: viewSize.y)
        guard tray.width > 0, tray.height > 0 else { return origin }
        let moved = Vec2(origin.x + (to.x - from.x) / tray.width, origin.y + (to.y - from.y) / tray.height)
        return TrayFit.clamped(moved)
    }

    /// `angle` wrapped into −π…π.
    nonisolated static func normalizedAngle(_ angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        return min(max(remainder(angle, 2 * Double.pi), -Double.pi), Double.pi)
    }

    /// Forgets the stone tool's touches, drag and turn; nothing is sent.
    private func resetStoneGesture() {
        stoneTracker = PointerTracker()
        rotator.reset()
        stoneTouch = nil
        turnStart = nil
        turnTo = nil
        updateSelectionOutline()
    }

    /// The selected stone as the overlay shows it: moved to the dragged centre or turned to the shown rotation while a
    /// gesture is in progress; nil without a selection.
    var shownSelection: Stone? {
        guard var stone = lastCore.selected else { return nil }
        if let to = stoneTouch?.dragTo { stone.position = to }
        if let turnTo, turnStart?.id == stone.id { stone.rotation = turnTo }
        return stone
    }

    /// Brings the overlay's selection outline up to ``shownSelection``.
    private func updateSelectionOutline() {
        guard let stone = shownSelection, let shape = StoneShape(stone: stone) else {
            preview.hideSelection()
            return
        }
        let name = GardenPalette.stones[shape.kindIndex].name
        preview.showSelection(outline: shape.outline(), label: name)
    }

    /// The spoken selection of `core`: "<kind> selected, <n> of <count>, turned <degrees>°" (n in depth order from the
    /// lowest stone, degrees rounded and positive clockwise), or "No stone selected".
    static func selectionValue(_ core: GardenCore) -> String {
        guard let stone = core.selected, let place = StoneSelection.place(of: stone.id, in: core.document.stones),
              let kind = GardenPalette.stone(id: stone.kind) else { return noSelectionValue }
        let degrees = Int((stone.rotation * 180 / Double.pi).rounded())
        return "\(kind.name) selected, \(place) of \(core.document.stones.count), turned \(degrees)°"
    }

    /// The stroke actions and the stone tool's `stone.select`, `stone.move` and `stone.rotate`.
    var gestureActions: Set<String> { GardenCore.strokeActionIDs.union(GardenCore.stoneGestureActionIDs) }

    /// The actions of the native controls: the stroke actions (the patterns), the rake, the tone, undo and redo, and
    /// every stone and tool action (feature 147).
    var nativeActions: Set<String> { Set(GardenCore.actionIDs) }

    // MARK: Words, probes and views

    /// Brings the mirror up to `core` (each field written only when it changes); adopts a calm switch the core
    /// accepted and keeps the sound sink enabled only while the sound is on (feature 149).
    func follow(_ core: GardenCore) {
        if !applyingCalm, core.calm != calm, core.calmRevision > 0,
           core.calmRevision != lastCore.calmRevision || core.calm != lastCore.calm {
            adoptCalm(core.calm)
        }
        if soundSink.isEnabled != core.calm.sound { soundSink.isEnabled = core.calm.sound }
        if mirror.calm != core.calm { mirror.calm = core.calm }
        lastCore = core
        if mirror.rakeStyle != core.rakeStyle { mirror.rakeStyle = core.rakeStyle }
        if mirror.tone != core.toneIndex { mirror.tone = core.toneIndex }
        if mirror.canUndo != core.history.canUndo { mirror.canUndo = core.history.canUndo }
        if mirror.canRedo != core.history.canRedo { mirror.canRedo = core.history.canRedo }
        if mirror.strokeCount != core.document.strokes.count { mirror.strokeCount = core.document.strokes.count }
        if mirror.stoneCapShown && !core.isAtStoneCap { mirror.stoneCapShown = false }
        var message: String? = core.lastRefusal == nil ? (core.isAtStrokeCap && core.isRaking ? Self.fullMessage : nil)
            : Self.fullMessage
        if message == nil, mirror.stoneCapShown { message = GardenCore.stoneCapMessage }
        if mirror.message != message { mirror.message = message }
        if mirror.toolMode != core.toolMode { mirror.toolMode = core.toolMode }
        if mirror.stones != core.document.stones { mirror.stones = core.document.stones }
        if mirror.selectedStone != core.selectedStone { mirror.selectedStone = core.selectedStone }
        let value = Self.selectionValue(core)
        if mirror.selectionValue != value { mirror.selectionValue = value }
        let undo = core.history.done.last.map(Self.phrase) ?? Self.nothingToUndo
        if mirror.undoValue != undo { mirror.undoValue = undo }
        let redo = core.history.undone.last.map(Self.phrase) ?? Self.nothingToRedo
        if mirror.redoValue != redo { mirror.redoValue = redo }
        updateSelectionOutline()
    }

    // MARK: Calm switches (feature 149)

    /// Keeps `settings` as the person's switches and writes them as `calm.v1` (a refused write keeps the switches for
    /// this session only).
    private func adoptCalm(_ settings: CalmSettings) {
        calm = settings
        try? storage?.setValue(settings.encoded(), for: CalmSettings.storageKey)
    }

    /// Sends the kept switches that the shell's core does not have yet through the port (none without a port, or
    /// when the core has them); returns whether anything was accepted. A refused send (the experience is not active)
    /// is tried again at the next draw.
    @discardableResult
    func applyKeptCalm() -> Bool {
        guard let port, !applyingCalm else { return false }
        let have = currentCore.calm
        guard have != calm else { return false }
        applyingCalm = true
        defer { applyingCalm = false }
        var accepted = false
        let pairs = [("calm.sound", calm.sound, have.sound), ("calm.drift", calm.drift, have.drift),
                     ("calm.haptics", calm.haptics, have.haptics)]
        for (control, want, current) in pairs where want != current {
            if port.send(control, [want ? 1 : 0]).isAccepted { accepted = true }
        }
        if accepted { follow(currentCore) }
        return accepted
    }

    /// Sets the calm switch `control` (`calm.sound`, `calm.drift` or `calm.haptics`) on or off through `port`; the
    /// accepted switch is kept as `calm.v1`.
    @discardableResult
    func setCalm(_ control: String, on: Bool, port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, [on ? 1 : 0])
        if result.isAccepted { follow(currentCore) }
        return result
    }

    /// Plays `sound` through the sink when the sound switch is on (feature 149).
    private func play(_ sound: GardenSound) {
        guard currentCore.calm.sound else { return }
        if !soundSink.isEnabled { soundSink.isEnabled = true }
        soundSink.play(sound.effect, id: sound.id)
    }

    /// Whether a haptic may be planned: the haptics switch is on (feature 149; the route then applies the person's
    /// switch and the rate limit).
    private var hapticsOn: Bool { currentCore.calm.haptics }

    /// Sends `stone.select` with `values` through `port`; selecting a stone (an id other than 0) plans the selection
    /// haptic (feature 149).
    @discardableResult
    func selectStone(_ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send("stone.select", values)
        if result.isAccepted, values.first.map({ $0 != 0 }) == true, hapticsOn { feedback.haptic(.selection) }
        return result
    }

    /// Sends `stone.remove` through `port`; a removal plays the `remove` tone (feature 149).
    @discardableResult
    func removeStone(port: ExperienceActionPort) -> ActionResult {
        let result = port.send("stone.remove")
        if result.isAccepted { play(.remove) }
        return result
    }

    // MARK: Announced actions (feature 148)

    /// The spoken name of `command`: "a stroke", "placing a stone", "moving a stone", "turning a stone", "removing a
    /// stone" or "a sand tone change".
    nonisolated static func phrase(_ command: GardenCommand) -> String {
        switch command {
        case .rake: return "a stroke"
        case .place: return "placing a stone"
        case .move: return "moving a stone"
        case .rotate: return "turning a stone"
        case .remove: return "removing a stone"
        case .tone: return "a sand tone change"
        }
    }

    /// Announces `text` with `kind` through the port (or straight through ``feedback`` before the port is set).
    func announce(_ text: String, kind: AnnouncementKind) {
        if let port {
            port.announce(text, kind: kind, route: feedback)
        } else {
            feedback.announce(text, kind: kind)
        }
    }

    /// Sends `edit.undo` through `port` and announces "Undid <command>", for example "Undid a stroke".
    @discardableResult
    func undo(port: ExperienceActionPort) -> ActionResult {
        let command = currentCore.history.done.last
        let result = port.send("edit.undo")
        if result.isAccepted, let command { announce("Undid " + Self.phrase(command), kind: .outcome) }
        return result
    }

    /// Sends `edit.redo` through `port` and announces "Redid <command>", for example "Redid moving a stone".
    @discardableResult
    func redo(port: ExperienceActionPort) -> ActionResult {
        let command = currentCore.history.undone.last
        let result = port.send("edit.redo")
        if result.isAccepted, let command { announce("Redid " + Self.phrase(command), kind: .outcome) }
        return result
    }

    /// Places a stone of the kind index `kind` at the tray centre through `port`; at the stone cap the controls show
    /// and announce "The garden holds 24 stones.".
    @discardableResult
    func placeStone(kind: Int, port: ExperienceActionPort) -> ActionResult {
        let result = port.send("stone.place", StoneControlValues.place(kind: kind))
        if result.isAccepted {
            play(.place)
            if hapticsOn { feedback.haptic(.impactLight) }
        }
        if result.code == "action.rule." + GardenRule.stoneCap {
            mirror.stoneCapShown = true
            follow(currentCore)
            announce(GardenCore.stoneCapMessage, kind: .rejection)
        }
        return result
    }

    /// Rakes the pattern `index` with the chosen rake through `port`; a stroke refused at the stroke cap is announced.
    @discardableResult
    func rakePattern(_ index: Int, port: ExperienceActionPort) -> [ActionResult] {
        let results = StrokePatterns.send(StrokePatterns.points(index: index), rake: mirror.rakeStyle, port: port)
        if results.count > 1, results.last?.isAccepted == true, currentCore.lastRefusal == nil { play(.stroke) }
        announceStrokeRefusal()
        return results
    }

    /// Announces the full-garden sentence when the last stroke was refused.
    private func announceStrokeRefusal() {
        if currentCore.lastRefusal != nil { announce(Self.fullMessage, kind: .rejection) }
    }

    /// Exports the 1600 × 1200 still with `renderer` (nil: no experience is open) for the share control and
    /// announces the outcome; returns it.
    @discardableResult
    func makeStill(renderer: ExperienceStillRenderer?) -> Result<URL, StillFailure> {
        var render: GardenStill.Render?
        if let renderer {
            render = { (width: Int, height: Int) throws(OffscreenRenderError) -> StillImage in
                try renderer(width: width, height: height)
            }
        }
        let result = still.export(render: render)
        switch result {
        case .success(let url):
            mirror.stillURL = url
            mirror.stillMessage = Self.stillMadeMessage
            announce(Self.stillMadeMessage, kind: .outcome)
        case .failure(let failure):
            mirror.stillURL = nil
            mirror.stillMessage = failure.sentence
            announce(failure.sentence, kind: .rejection)
        }
        return result
    }

    /// The sentence of a written still.
    static let stillMadeMessage = "The picture is ready to share: \(GardenStill.width) by \(GardenStill.height) pixels."

    /// The canvas label: "Zen garden, <tone>, <rake>, <n> strokes, <m> stones, <selection>", for example "Zen
    /// garden, Pale sand, Fine rake, 3 strokes, 2 stones, Flat slate selected, 2 of 2, turned 0°" or "…, 0 stones,
    /// No stone selected" (feature 148: the stones and the selection are always named).
    func describe(_ core: GardenCore) -> String {
        follow(core)
        let tone = GardenPalette.tones[core.toneIndex].name
        let rake = GardenCore.rake(index: core.rakeStyle).name
        let count = core.document.strokes.count
        var label = "Zen garden, \(tone), \(rake), \(count) " + (count == 1 ? "stroke" : "strokes")
        let stones = core.document.stones.count
        label += ", \(stones) " + (stones == 1 ? "stone" : "stones")
        label += ", " + Self.selectionValue(core)
        return label
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
        AnyView(GardenControls(port: port, mirror: mirror, presenter: self))
    }
}
