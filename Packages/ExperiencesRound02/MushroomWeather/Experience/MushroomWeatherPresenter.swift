// MushroomWeatherPresenter — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-003, 004, 005, 007; clarifications
// Q2, Q4, Q5). Draws the adapter's immutable snapshot with `MushroomWeatherForestScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityProfile` names, the names of
// `MushroomWeatherTier.all`), keeps a log of every tier change with its reason, stops the droplets and motes under
// Reduce Motion and caps the glow under Reduce Flashing. The humidity field never moves by time: the shown cycle is the
// adapter's presentation state (`clock.show`) and is never advanced by time; only the droplets and motes move with the
// presentation time. The tutorial of levels 1 … 3 is shown in words, as presentation, not as a kernel stage. A refused
// action is shown in words. A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only
// reads `core.snapshot`: no drawing result reaches the kernel (renderer purity). Its probes (two backdrop corners) let
// the verification runner check a frame. Modelled on `MicroscopicAuroraPresenter` (feature 483).
// Feature 494 (R02-G20-04) T-R02G2004-005 (FR-R02G2004-001 … 011): a canvas touch goes through the presenter's
// `MushroomWeatherGestureController` with the drawn snapshot (`pointer`): a tap on an empty site places a pod in the
// first free slot (`pod.place [slot, row, column]`), a pod drag previews the weather with the pod moved or removed (the
// preview of `MushroomWeatherSceneSnapshot.previewing`, presentation only, kept in the mirror) and its release sends
// one `pod.place` to the new site or one `pod.remove` off the floor; a vent tap sends `vent.set [index, open]` with the
// other state; a vertical moon drag previews the moonlight and its release sends one `moon.set [level]`; a scrubber
// drag shows cycles (`clock.show`, in any stage); a tapped pod selects its slot in the panel; two fingers orbit the
// camera and a double tap off the floor or "Reset view" (`resetView()`) returns it (presentation only; the meshes are
// rebuilt). Kernel actions are sent only while playing (the controller's rule); a gesture on a finished play says "The
// play is over: undo or go to the next level". A refused action is shown in the panel and its code, read with or
// without the engine's `action.rule.` prefix, is kept in the refusal log. Modelled on `MicroscopicAuroraPresenter`
// (feature 484).
#if os(iOS)
import Foundation
import MushroomWeatherCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described, the shown cycle and the panel's selection.
@MainActor
@Observable
final class MushroomWeatherMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions left.
    var actionsLeft = 0
    /// The action budget.
    var budget = 0
    /// A one-line status: "Ready", "Playing", "Won" or "Failed: " and the failure in words.
    var status = ""
    /// The failure in words, if the play failed.
    var failureText: String?
    /// The progress in words (the kernel's progress description).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The tutorial in words on levels that have one; nil otherwise.
    var tutorialText: String?
    /// The shown cycle, the adapter's.
    var shownCycle = 0
    /// The play followed (a copy; never sent anywhere).
    var play: MushroomWeatherPlay?
    /// The text of the last refused change, or why a gesture did nothing, if any.
    var message: String?
    /// A pod or moon drag's preview (feature 494; presentation only): what the drag would change, nil while no drag
    /// previews.
    var preview: MushroomWeatherPreviewKind?
    /// The pod slot the panel edits (0 … slots − 1).
    var slot = 0
    /// The index of the site the panel would place on.
    var siteIndex = 0
    /// The moonlight level the panel would set (presentation only; Set moonlight spends one action).
    var chosenMoonlight = 0

    /// The pod slots of the followed level (1 while no play is followed).
    var slotCount: Int { max(play?.level.podRules.slots ?? 1, 1) }

    /// The cells a pod may be placed on: the level's sites, or, on a level without sites, every floor cell no colony
    /// stands on (row-major); empty while no play is followed.
    var sites: [MushroomWeatherCell] {
        guard let level = play?.level else { return [] }
        if let sites = level.sites { return sites }
        let colonies: Set<MushroomWeatherCell> = level.colonyCells
        var cells: [MushroomWeatherCell] = []
        for index in 0..<(level.rows * level.columns) {
            let cell: MushroomWeatherCell = level.cell(at: index)
            if level.isFloor(cell) && !colonies.contains(cell) { cells.append(cell) }
        }
        return cells
    }

    /// The cycles run by the followed play's predicted run (0 while no play is followed).
    var cyclesRun: Int { play?.report.cycles ?? 0 }

    /// The moonlight of the followed arrangement (0 while no play is followed).
    var moonlight: Int { play?.arrangement.moonlight ?? 0 }

    /// The vents' states of the followed arrangement, by vent index (empty while no play is followed).
    var ventsOpen: [Bool] { play?.arrangement.ventsOpen ?? [] }

    /// `value` clamped to the cycles 0 … cycles run.
    func clampedCycle(_ value: Int) -> Int { min(max(value, 0), cyclesRun) }

    /// `value` clamped to the moonlight levels 0 … 3.
    func clampedMoonlight(_ value: Int) -> Int {
        let levels: ClosedRange<Int> = MushroomWeatherLevel.moonlightLevels
        return min(max(value, levels.lowerBound), levels.upperBound)
    }

    /// The slot the panel edits, clamped to the level's slots.
    var selectedSlot: Int { min(max(slot, 0), slotCount - 1) }

    /// The site the panel would place on, or nil without sites.
    var selectedSite: MushroomWeatherCell? {
        let sites: [MushroomWeatherCell] = sites
        guard !sites.isEmpty else { return nil }
        return sites[min(max(siteIndex, 0), sites.count - 1)]
    }

    /// The pods in words.
    var podsLabel: String {
        guard let play else { return "no pods" }
        var parts: [String] = []
        for slot in play.arrangement.pods.indices {
            let grownAt: Int? = slot < play.report.grownAt.count ? play.report.grownAt[slot] : nil
            parts.append(play.level.podDescription(slot, cell: play.arrangement.pods[slot], grownAt: grownAt))
        }
        return parts.joined(separator: "; ")
    }

    /// Vent `index` in words ("vent 1 at row 2, column 4, open"), or "no vent".
    func ventLabel(_ index: Int) -> String {
        guard let play, index < play.level.vents.count, index < ventsOpen.count else { return "no vent" }
        return play.level.ventDescription(index, open: ventsOpen[index])
    }

    /// The pod the panel would place, in words.
    var selectionLabel: String {
        guard let site = selectedSite else { return "no site" }
        return "pod \(selectedSlot + 1) at " + MushroomWeatherLevel.cellWords(site)
    }

    /// The moonlight in words.
    var moonLabel: String { "moonlight \(moonlight) of \(MushroomWeatherLevel.moonlightLevels.upperBound)" }
    /// The chosen moonlight level in words.
    var chosenMoonLabel: String {
        "set to \(clampedMoonlight(chosenMoonlight)) of \(MushroomWeatherLevel.moonlightLevels.upperBound)"
    }

    /// The shown cycle in words.
    var cycleLabel: String { "cycle \(clampedCycle(shownCycle)) of \(cyclesRun)" }

    /// Takes the new `play` and presentation.
    func follow(_ play: MushroomWeatherPlay, shownCycle: Int) {
        self.play = play
        self.shownCycle = shownCycle
    }

    /// A failure in words, naming what the kernel's reason names (the level's failure description, first letter in
    /// upper case, with a full stop); nil without a failure.
    static func failureText(_ failure: MushroomWeatherFailure?, level: MushroomWeatherLevel) -> String? {
        guard let failure else { return nil }
        return level.failureDescription(failure).capitalizedFirst + "."
    }

    /// The engine's prefix of rule codes (feature 494: codes are read with or without it).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix``.
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// The panel line of a refusal: "That change was refused: " and the reason in words.
    static func refusalMessage(code: String) -> String {
        "That change was refused: \(refusalText(code: code))."
    }

    /// Records the result of sending a control (feature 494): a refusal is shown in words; an accepted action clears
    /// the message.
    func record(accepted: Bool, code: String) {
        message = accepted ? nil : Self.refusalMessage(code: code)
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix`` (feature 494).
    static func refusalText(code: String) -> String {
        switch bareCode(code) {
        case "r02-g20.stage": "the play is over: undo a failed run or go to the next level"
        case "r02-g20.action": "that pod, vent or moonlight cannot be set that way, or there is nothing to undo, redo "
            + "or remove"
        case "r02-g20.budget": "no actions are left: run the weather or undo a change"
        case "r02-g20.stale": "the play changed before the action arrived"
        case "r02-g20.level": "the next level could not be made"
        case "r02-g20.generation": "the next level could not be made"
        case MushroomWeatherExperienceRule.notWhole: "the slot, cell, vent, state, moonlight and cycle must be whole "
            + "numbers"
        case MushroomWeatherExperienceRule.cycle: "that cycle is past the end of the run"
        default: "that action is not available now"
        }
    }
}

private extension String {
    /// The string with its first letter in upper case.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct MushroomWeatherTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Mushroom Weather.
@MainActor
final class MushroomWeatherPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = MushroomWeatherExperienceCore

    /// The tutorial shown on levels that have one (presentation, not a kernel stage).
    static let tutorial = "Place spore pods on the marked sites, open or shut the canopy vents and set the moonlight "
        + "so every colony's humidity ends the run inside its band, without a colony drying out or a cell turning to "
        + "mold; then run the weather."

    /// Whether Reduce Motion is on (the droplets and motes stop).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = MushroomWeatherMirror()
    /// The GL scene.
    let scene = MushroomWeatherForestScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G2003-004).
    private(set) var tierLog: [MushroomWeatherTierChange] = []
    /// The last snapshot drawn (tests, the description and the gestures), with the drawn preview applied.
    private(set) var lastSnapshot: MushroomWeatherSceneSnapshot?
    /// The core's snapshot last drawn, without the preview, and its level (feature 494).
    private var lastBase: (snapshot: MushroomWeatherSceneSnapshot, level: MushroomWeatherLevel)?
    /// The gesture controller (feature 494): site, pod, vent and moon gestures, the scrubber, double taps and orbits.
    private(set) var gestures = MushroomWeatherGestureController()
    /// The bare codes of refused actions, oldest first, at most ``refusalLogLimit`` (feature 494).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedMotion = reduceMotion
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the forest program's fragment source with one that does not compile.
    func breakForestShader() {
        scene.forestFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the names of the Core's `qualityProfile` (`level-0` … `level-2`, the
    /// names of `MushroomWeatherTier.all`).
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(MushroomWeatherTier.of(tier).name) }
        return names
    }

    /// Records the registry and the aspect.
    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    /// Follows the new drawable size.
    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    /// Follows `core`'s play and presentation in the mirror when they changed.
    private func follow(_ core: MushroomWeatherExperienceCore) {
        if mirror.play != core.play || mirror.shownCycle != core.shownCycle {
            mirror.follow(core.play, shownCycle: core.shownCycle)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: MushroomWeatherExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = MushroomWeatherTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(MushroomWeatherTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let base: MushroomWeatherSceneSnapshot = core.snapshot(time: time)
        lastBase = (snapshot: base, level: core.play.level)
        let snapshot: MushroomWeatherSceneSnapshot = presented(base, level: core.play.level)
        lastSnapshot = snapshot
        scene.orbit = gestures.orbit
        try scene.render(snapshot, tier: drawn, context: context, frame: frame)
    }

    /// Releases every GPU object.
    func teardown(_ context: RenderContext) {
        scene.release()
    }

    /// Releases every GPU object (memory warning); the next frame rebuilds them.
    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the floor, the gauges,
    /// the run bars and the actions bars (the camera fits the scene's box inside a 5 % margin), are `dark` (the
    /// midnight backdrop) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: MushroomWeatherExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: MushroomWeatherExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.tutorialText = level.tutorial ? Self.tutorial : nil
        let siteWords: String = level.sites.map { "\($0.count) pod sites" } ?? "pods on any free floor cell"
        mirror.targetLabel = "Level: a floor of \(level.rows) by \(level.columns) cells, \(level.colonies.count) "
            + "colonies, \(level.podRules.slots) pods, " + siteWords + ", \(level.vents.count) vents, "
            + "\(level.length) cycles per run"
        let measure: String = level.progressDescription(report: play.report, arrangement: play.arrangement,
                                                        actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Mushroom Weather level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every colony ended the run in its band."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = MushroomWeatherMirror.failureText(play.failure, level: level) ?? "The run failed."
            text += reason
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        default:
            let played: Bool = play.records.contains { record in
                record.kind != .begin && record.kind != .dismissTutorial
            }
            mirror.status = played ? "Playing" : "Ready"
            mirror.failureText = nil
        }
        return text
    }

    /// `snapshot` with the mirror's drag preview applied (feature 494; presentation only).
    private func presented(_ snapshot: MushroomWeatherSceneSnapshot,
                           level: MushroomWeatherLevel) -> MushroomWeatherSceneSnapshot {
        guard let preview = mirror.preview else { return snapshot }
        return snapshot.previewing(preview, level: level)
    }

    /// Re-applies the mirror's preview to the last snapshot, so tests and the next gesture read it.
    private func refreshPreview() {
        guard let base = lastBase else { return }
        lastSnapshot = presented(base.snapshot, level: base.level)
    }

    /// The control panel: "Reset view" (feature 494); every kernel button sends through ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MushroomWeatherControls(port: port, mirror: mirror,
                                        sendAction: { [weak self] control, values in
                                            self?.send(control, values, port: port)
                                        },
                                        resetView: { [weak self] in self?.resetView() }))
    }

    /// The camera's orbit (presentation only; the gesture controller's).
    var orbit: MushroomWeatherViewOrbit { gestures.orbit }

    /// The canvas gestures place, move and remove pods, open and shut vents, set the moonlight and show cycles; the
    /// preview and the orbit are presentation state.
    var gestureActions: Set<String> { ["pod.place", "pod.remove", "vent.set", "moon.set", "clock.show"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(Core.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a placement or move through `pod.place [slot, row, column]` and a removal through `pod.remove [slot]`
    /// (one action each; the preview is dropped), a vent through `vent.set [index, open]`, the moonlight through
    /// `moon.set [level]` (the preview is dropped and the panel's chosen level follows), a cycle through `clock.show
    /// [cycle]` (presentation only), a preview kept in the mirror and drawn, a slot selected in the panel, a reset view
    /// (the controller is already at the authored orbit) and an explanation to the mirror's message.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let drawn = lastSnapshot else { return }
        let actions: [MushroomWeatherGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: drawn)
        for action in actions {
            switch action {
            case let .place(slot, cell), let .move(slot, cell):
                mirror.preview = nil
                send("pod.place", [Double(slot), Double(cell.row), Double(cell.column)], port: port)
            case let .remove(slot):
                mirror.preview = nil
                send("pod.remove", [Double(slot)], port: port)
            case let .setVent(index, open):
                send("vent.set", [Double(index), open ? 1 : 0], port: port)
            case let .setMoonlight(level):
                mirror.preview = nil
                mirror.chosenMoonlight = mirror.clampedMoonlight(level)
                send("moon.set", [Double(level)], port: port)
            case let .showCycle(cycle):
                send("clock.show", [Double(cycle)], port: port)
            case let .preview(kind):
                mirror.preview = kind
            case .clearPreview:
                mirror.preview = nil
            case let .selectSlot(slot):
                mirror.slot = slot
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            case let .explain(reason):
                mirror.message = reason
            }
        }
        if event.phase == .ended || event.phase == .cancelled || gestures.state == .orbiting
            || gestures.state == .cancelled {
            mirror.preview = nil
        }
        scene.orbit = gestures.orbit
        refreshPreview()
    }

    /// Cancels the touches in progress (suspension): nothing is sent and the preview disappears.
    func cancelPointers() {
        gestures.cancel()
        mirror.preview = nil
        refreshPreview()
    }

    /// Returns the camera to the authored view ("Reset view"; presentation only).
    func resetView() {
        gestures.resetView()
        scene.orbit = gestures.orbit
    }

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its bare code in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        mirror.record(accepted: result.isAccepted, code: result.code)
        if !result.isAccepted {
            refusalLog.append(MushroomWeatherMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        refreshPreview()
        return result
    }
}
#endif
