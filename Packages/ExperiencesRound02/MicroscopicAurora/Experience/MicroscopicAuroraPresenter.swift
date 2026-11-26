// MicroscopicAuroraPresenter — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-003, 004, 005, 007; clarifications
// Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `MicroscopicAuroraDishScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`), keeps a log of every
// tier change with its reason, and caps the glow under Reduce Flashing. Nothing moves by time: the shown tick is the
// adapter's presentation state (`clock.show`) and is never advanced by time. The tutorial of levels 1 … 3 is shown in
// words, as presentation, not as a kernel stage. A refused action is shown in words. A memory warning releases the GPU
// objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel
// (renderer purity). Its probes (two backdrop corners) let the verification runner check a frame.
// Feature 484 (R02-G19-04) T-R02G1904-005 (FR-R02G1904-001 … 010): a canvas touch goes through the presenter's
// `MicroscopicAuroraGestureController` with the drawn snapshot (`pointer`): a tap on an empty site places a well with the
// panel's strength and sense in the first free slot (`well.place`), a well drag previews the swim with the well moved
// (the preview of `MicroscopicAuroraSceneSnapshot.previewing`, presentation only, kept in the mirror) and its release
// sends one `well.place` to the new site or one `well.remove` off the dish; a scrubber drag shows ticks (`clock.show`, in
// any stage); a tap on the dish field toggles the freeze (`toggleFreeze()`, presentation only: the committed swim stays
// drawn and only the gauges preview); two fingers orbit the camera and a double tap outside the dish or "Reset view"
// (`resetView()`) returns it (presentation only; the meshes are rebuilt). A refused action is shown in the panel and its
// code, read with or without the engine's `action.rule.` prefix, is kept in the refusal log.
#if os(iOS)
import Foundation
import MicroscopicAuroraCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described, the shown tick and the panel's selection.
@MainActor
@Observable
final class MicroscopicAuroraMirror {
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
    /// The shown tick, the adapter's.
    var shownTick = 0
    /// The play followed (a copy; never sent anywhere).
    var play: MicroscopicAuroraPlay?
    /// The text of the last refused change, or why a gesture did nothing, if any.
    var message: String?
    /// A well drag's preview (feature 484; presentation only): the slot and its target, nil while no drag previews.
    var preview: (slot: Int, target: MicroscopicAuroraPreviewTarget)?
    /// Whether the freeze is on (feature 484; presentation only): the committed swim stays drawn under a preview.
    var frozen = false
    /// The slot the panel edits (0 … 2).
    var slot = 0
    /// The index of the site the panel would place on.
    var siteIndex = 0
    /// The strength the panel would place (1 … 4).
    var strength = 2
    /// Whether the panel would place a counterclockwise well.
    var counterclockwise = true

    /// The level's sites (empty while no play is followed).
    var sites: [MicroscopicAuroraCell] { play?.level.sites ?? [] }
    /// The ticks swum by the followed play's predicted swim (0 while no play is followed).
    var ticksSwum: Int { play?.report.ticks ?? 0 }

    /// `value` clamped to the ticks 0 … ticks swum.
    func clampedTick(_ value: Int) -> Int { min(max(value, 0), ticksSwum) }

    /// The site the panel would place on, or nil without sites.
    var selectedSite: MicroscopicAuroraCell? {
        guard !sites.isEmpty else { return nil }
        return sites[min(max(siteIndex, 0), sites.count - 1)]
    }

    /// The wells in words.
    var wellsLabel: String {
        guard let play else { return "no wells" }
        var parts: [String] = []
        for slot in play.wells.indices { parts.append(play.level.wellDescription(slot, well: play.wells[slot])) }
        return parts.joined(separator: "; ")
    }

    /// The well the panel would place, in words.
    var selectionLabel: String {
        guard let site = selectedSite else { return "no site" }
        return "well \(slot + 1) at " + MicroscopicAuroraLevel.cellWords(site) + ", strength \(strength), "
            + (counterclockwise ? "counterclockwise" : "clockwise")
    }

    /// The shown tick in words.
    var tickLabel: String { "tick \(clampedTick(shownTick)) of \(ticksSwum)" }

    /// Takes the new `play` and presentation.
    func follow(_ play: MicroscopicAuroraPlay, shownTick: Int) {
        self.play = play
        self.shownTick = shownTick
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: MicroscopicAuroraFailure?) -> String? {
        switch failure {
        case let .exit(swimmer, tick)?: "Swimmer \(swimmer + 1) left the dish at tick \(tick)."
        case let .coherence(tick, group)?: "The swarm split at tick \(tick): its largest group had \(group) swimmers."
        case let .coverage(lit, needed)?: "Only \(lit) stencil cells were lit; \(needed) were needed."
        case let .connectedness(cell)?: MicroscopicAuroraLevel.cellWords(cell).capitalizedFirst
            + " is not joined to the pattern."
        case nil: nil
        }
    }

    /// The engine's prefix of rule codes (feature 484: codes are read with or without it).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix``.
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// The panel line of a refusal: "That change was refused: " and the reason in words.
    static func refusalMessage(code: String) -> String {
        "That change was refused: \(refusalText(code: code))."
    }

    /// Records the result of sending a control (feature 484): a refusal is shown in words; an accepted action clears
    /// the message.
    func record(accepted: Bool, code: String) {
        message = accepted ? nil : Self.refusalMessage(code: code)
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``.
    static func refusalText(code: String) -> String {
        switch bareCode(code) {
        case "r02-g19.stage": "the play is over: undo a failed play or go to the next level"
        case "r02-g19.action": "that well cannot be placed there, or there is nothing to undo, redo or remove"
        case "r02-g19.budget": "no actions are left: play the swim or undo a placement"
        case "r02-g19.stale": "the play changed before the action arrived"
        case "r02-g19.level": "the next level could not be made"
        case MicroscopicAuroraExperienceRule.notWhole: "the slot, cell, strength, sense and tick must be whole numbers"
        case MicroscopicAuroraExperienceRule.tick: "that tick is past the end of the swim"
        default: "that action is not available now"
        }
    }
}

private extension String {
    /// The string with its first letter in upper case.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct MicroscopicAuroraTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Microscopic Aurora.
@MainActor
final class MicroscopicAuroraPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = MicroscopicAuroraExperienceCore

    /// The tutorial shown on levels that have one (presentation, not a kernel stage).
    static let tutorial = "Place magnetic wells on the marked sites so the swimmers' glowing trails cover the "
        + "stencil as one pattern, without a swimmer leaving the dish or the swarm breaking apart; then play the swim."

    /// Whether Reduce Motion is on (the scene is still already).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = MicroscopicAuroraMirror()
    /// The GL scene.
    let scene = MicroscopicAuroraDishScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1903-004).
    private(set) var tierLog: [MicroscopicAuroraTierChange] = []
    /// The last snapshot drawn (tests, the description and the gestures), with the drawn preview and freeze applied.
    private(set) var lastSnapshot: MicroscopicAuroraSceneSnapshot?
    /// The core's snapshot last drawn, without the preview or the freeze, and its level (feature 484).
    private var lastBase: (snapshot: MicroscopicAuroraSceneSnapshot, level: MicroscopicAuroraLevel)?
    /// The gesture controller (feature 484): site taps, well drags, the scrubber, the freeze, double taps and the orbit.
    private(set) var gestures = MicroscopicAuroraGestureController()
    /// The bare codes of refused actions, oldest first, at most ``refusalLogLimit`` (feature 484).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the dish program's fragment source with one that does not compile.
    func breakDishShader() {
        scene.dishFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the Core's `qualityTiers` (`level-0` … `level-2`).
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(MicroscopicAuroraTier.of(tier).name) }
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
    private func follow(_ core: MicroscopicAuroraExperienceCore) {
        if mirror.play != core.play || mirror.shownTick != core.shownTick {
            mirror.follow(core.play, shownTick: core.shownTick)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: MicroscopicAuroraExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = MicroscopicAuroraTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(MicroscopicAuroraTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let base: MicroscopicAuroraSceneSnapshot = core.snapshot(time: time)
        lastBase = (snapshot: base, level: core.play.level)
        let snapshot = presented(base, level: core.play.level)
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the dish, the gauges
    /// and the actions bars (the camera fits the scene inside a 5 % margin), are `dark` (the abyss backdrop) once a
    /// snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: MicroscopicAuroraExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: MicroscopicAuroraExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.tutorialText = level.tutorial ? Self.tutorial : nil
        mirror.targetLabel = "Level: a stencil of \(level.stencil.count) cells, \(level.swimmers.count) swimmers, "
            + "\(level.sites?.count ?? 0) well sites, \(level.length) ticks per swim"
        let measure: String = level.progressDescription(report: play.report, wells: play.wells,
                                                        actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Microscopic Aurora level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The trails covered the stencil as one pattern."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = MicroscopicAuroraMirror.failureText(play.failure) ?? "The play failed."
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

    /// `snapshot` with the mirror's freeze and drag preview applied (feature 484; presentation only).
    private func presented(_ snapshot: MicroscopicAuroraSceneSnapshot,
                           level: MicroscopicAuroraLevel) -> MicroscopicAuroraSceneSnapshot {
        var shown: MicroscopicAuroraSceneSnapshot = snapshot.freezing(mirror.frozen)
        if let preview = mirror.preview {
            shown = shown.previewing(slot: preview.slot, target: preview.target, level: level)
        }
        return shown
    }

    /// Re-applies the mirror's preview and freeze to the last snapshot, so tests and the next gesture read them.
    private func refreshPreview() {
        guard let base = lastBase else { return }
        lastSnapshot = presented(base.snapshot, level: base.level)
    }

    /// The control panel: "Freeze" and "Reset view" (feature 484); every kernel button sends through
    /// ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MicroscopicAuroraControls(port: port, mirror: mirror,
                                          sendAction: { [weak self] control, values in
                                              self?.send(control, values, port: port)
                                          },
                                          freeze: { [weak self] in self?.toggleFreeze() },
                                          resetView: { [weak self] in self?.resetView() }))
    }

    /// The camera's orbit (presentation only; the gesture controller's).
    var orbit: MicroscopicAuroraViewOrbit { gestures.orbit }

    /// The canvas gestures place, move and remove wells and show ticks; the preview, the freeze and the orbit are
    /// presentation state.
    var gestureActions: Set<String> { ["well.place", "well.remove", "clock.show"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(Core.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a placement or move through `well.place` and a removal through `well.remove` (one action each; the preview
    /// is dropped), a tick through `clock.show` (presentation only), a preview kept in the mirror and drawn, the freeze
    /// toggled, a slot selected in the panel, a reset view (the controller is already at the authored orbit) and an
    /// explanation to the mirror's message. The controller places with the panel's strength and sense.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let drawn = lastSnapshot else { return }
        gestures.strength = mirror.strength
        gestures.sense = mirror.counterclockwise ? .counterclockwise : .clockwise
        let actions: [MicroscopicAuroraGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: drawn)
        for action in actions {
            switch action {
            case let .place(slot, well), let .move(slot, well):
                mirror.preview = nil
                send("well.place", [Double(slot), Double(well.cell.row), Double(well.cell.column),
                                    Double(well.strength), well.sense == .counterclockwise ? 1 : 0], port: port)
            case let .remove(slot):
                mirror.preview = nil
                send("well.remove", [Double(slot)], port: port)
            case let .showTick(tick):
                send("clock.show", [Double(tick)], port: port)
            case let .preview(slot, target):
                mirror.preview = (slot: slot, target: target)
            case .clearPreview:
                mirror.preview = nil
            case .toggleFreeze:
                mirror.frozen.toggle()
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

    /// Toggles the freeze ("Freeze", or a tap on the dish field; presentation only).
    func toggleFreeze() {
        mirror.frozen.toggle()
        refreshPreview()
    }

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its bare code in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        mirror.record(accepted: result.isAccepted, code: result.code)
        if !result.isAccepted {
            refusalLog.append(MicroscopicAuroraMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        refreshPreview()
        return result
    }
}
#endif
