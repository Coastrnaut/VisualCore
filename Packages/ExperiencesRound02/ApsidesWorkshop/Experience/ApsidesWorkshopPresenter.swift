// ApsidesWorkshopPresenter — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-003, 004, 005, 007; clarifications
// Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `ApsidesWorkshopCompassScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`), keeps a log of every
// tier change with its reason, and caps the glow under Reduce Flashing. One clock feeds the picture, presentation only:
// the star's glow pulses with the frame time (`u_pulse`, held at 1 under Reduce Motion); the shown tick is the
// adapter's presentation state (`clock.show`) and is never advanced by time. The tutorial of levels 1 … 3 is shown in
// words, as presentation, not as a kernel stage. A refused action is shown in words. A memory warning releases the GPU
// objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel
// (renderer purity). Its probes (two backdrop corners) let the verification runner check a frame.
//
// Feature 474 (R02-G18-04) T-R02G1804-005 (FR-R02G1804-001 … 009; clarifications Q1 … Q5) wires touch: a canvas touch
// goes through the presenter's `ApsidesWorkshopGestureController` with the drawn snapshot (`pointer`); a knob drag
// previews its pending eccentricity and direction and a size-handle drag its pending size (the ghost loop and gauges of
// `ApsidesWorkshopSceneSnapshot.previewing(_:)`, presentation state kept in the mirror), and the release sends one
// `orbit.periapsis [k, d]` or `orbit.size [a]`; dragging the orbiter cranks the shown tick (`clock.show`, presentation
// only, in any stage); a drag on a finished play explains why nothing happens; two fingers orbit the camera and a
// double tap on empty space or "Reset view" (`resetView()`) returns it (the orbit is presentation only and rebuilds the
// meshes). The panel's − and + move a pending orbit, drawn as the same preview, and "Set periapsis" and "Set size"
// commit it as one action each. A refused action is shown in words and its code logged (`refusalLog`), read with or
// without the engine's `action.rule.` prefix.
#if os(iOS)
import ApsidesWorkshopCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described and the shown tick.
@MainActor
@Observable
final class ApsidesWorkshopMirror {
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
    /// The progress in words (the kernel's progress description and the actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The tutorial in words on levels that have one; nil otherwise.
    var tutorialText: String?
    /// The shown tick, the adapter's.
    var shownTick = 0
    /// The play followed (a copy; never sent anywhere).
    var play: ApsidesWorkshopPlay?
    /// The text of the last refused change, or why a gesture did nothing, if any.
    var message: String?
    /// The panel's pending orbit (feature 474; presentation only), nil when it equals the current orbit. It is dropped
    /// after any accepted kernel action and on the next level, so it follows the current orbit.
    var pendingOrbit: ApsidesWorkshopOrbit?
    /// A drag's preview (feature 474; presentation only), nil when no drag previews.
    var preview: ApsidesWorkshopOrbit?

    /// The current orbit of the followed play (a mid-range orbit while no play is followed).
    var orbit: ApsidesWorkshopOrbit { play?.orbit ?? ApsidesWorkshopOrbit(size: 24, eccentricity: 0, direction: 0) }
    /// The period of the followed level in ticks (1 while no play is followed).
    var period: Int { max(play?.level.period ?? 1, 1) }

    /// The pending orbit, or the current orbit when none is pending (feature 474; not checked for validity).
    var pending: ApsidesWorkshopOrbit { pendingOrbit ?? orbit }

    /// The orbit "Set periapsis" would make: the pending eccentricity and direction with the current size.
    var periapsisResult: ApsidesWorkshopOrbit {
        ApsidesWorkshopOrbit(size: orbit.size, eccentricity: pending.eccentricity, direction: pending.direction)
    }

    /// The orbit "Set size" would make: the pending size with the current eccentricity and direction.
    var sizeResult: ApsidesWorkshopOrbit {
        ApsidesWorkshopOrbit(size: pending.size, eccentricity: orbit.eccentricity, direction: orbit.direction)
    }

    /// Whether "Set periapsis" is enabled: a play is followed, the pending knob differs from the current one and the
    /// resulting orbit is valid.
    var periapsisSettable: Bool {
        guard play != nil else { return false }
        let differs: Bool = pending.eccentricity != orbit.eccentricity || pending.direction != orbit.direction
        return differs && periapsisResult.isValid
    }

    /// Whether "Set size" is enabled: a play is followed, the pending size differs and the resulting orbit is valid.
    var sizeSettable: Bool {
        guard play != nil else { return false }
        return pending.size != orbit.size && sizeResult.isValid
    }

    /// Why the pending orbit cannot be previewed, in words; nil while it is valid or none is pending. Each Set button
    /// is enabled on its own resulting orbit (``periapsisSettable``, ``sizeSettable``).
    var pendingReason: String? {
        guard let pendingOrbit else { return nil }
        return Self.invalidReason(pendingOrbit)
    }

    /// Why `orbit` is invalid, in words (the gesture controller's texts); nil when it is valid.
    static func invalidReason(_ orbit: ApsidesWorkshopOrbit) -> String? {
        if orbit.isValid { return nil }
        return ApsidesWorkshopGestureController.invalidReason(orbit) ?? "That orbit is outside the workshop's steps"
    }

    /// Moves the pending orbit by the given steps (feature 474; presentation only): the direction wraps 0 … 23, the
    /// eccentricity clamps to 0 … 15 and the size to 8 … 48. A pending orbit equal to the current one is dropped.
    func movePending(eccentricity: Int, direction: Int, size: Int) {
        let base: ApsidesWorkshopOrbit = pending
        let k: Int = min(max(base.eccentricity + eccentricity, ApsidesWorkshopOrbit.eccentricities.lowerBound),
                         ApsidesWorkshopOrbit.eccentricities.upperBound)
        let d: Int = ((base.direction + direction) % 24 + 24) % 24
        let a: Int = min(max(base.size + size, ApsidesWorkshopOrbit.sizes.lowerBound),
                         ApsidesWorkshopOrbit.sizes.upperBound)
        let moved = ApsidesWorkshopOrbit(size: a, eccentricity: k, direction: d)
        pendingOrbit = moved == orbit ? nil : moved
    }

    /// A panel line: "name value" without a pending change, "name value → pending" with one.
    func pendingLine(_ name: String, _ value: Int, _ pendingValue: Int, unit: String = "") -> String {
        guard pendingOrbit != nil, pendingValue != value else { return "\(name) \(value)\(unit)" }
        return "\(name) \(value)\(unit) → \(pendingValue)\(unit)"
    }

    /// The preview drawn: the drag's preview first, else the pending orbit when it is valid; nil without either.
    var drawnPreview: ApsidesWorkshopOrbit? {
        if let preview { return preview }
        guard let pendingOrbit, play != nil, pendingOrbit.isValid else { return nil }
        return pendingOrbit
    }

    /// `value` clamped to the ticks 0 … period − 1.
    func clampedTick(_ value: Int) -> Int { min(max(value, 0), period - 1) }

    /// The orbit in words: its size, eccentricity and periapsis direction, and its apsides.
    var orbitLabel: String {
        guard let play else { return "no orbit" }
        let orbit: ApsidesWorkshopOrbit = play.orbit
        return play.level.orbitDescription(orbit) + "; periapsis in " + play.level.sectorName(orbit.periapsisSector)
            + " at " + ApsidesWorkshopLevel.distanceWords(orbit.periapsisDistance) + ", apoapsis in "
            + play.level.sectorName(orbit.apoapsisSector) + " at "
            + ApsidesWorkshopLevel.distanceWords(orbit.apoapsisDistance)
    }

    /// The shown tick in words with the orbiter's sector.
    var tickLabel: String {
        guard let play else { return "tick \(shownTick)" }
        let tick: Int = clampedTick(shownTick)
        let point: ApsidesWorkshopPoint = play.report.positions[tick]
        return "tick \(tick) of \(play.level.period): the orbiter is in "
            + play.level.sectorName(ApsidesWorkshopSky.sector(of: point))
    }

    /// Takes the new `play` and presentation; a changed play (an applied kernel action, the next level) drops the
    /// pending orbit, so it follows the current orbit.
    func follow(_ play: ApsidesWorkshopPlay, shownTick: Int) {
        if self.play != play { pendingOrbit = nil }
        self.play = play
        self.shownTick = shownTick
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: ApsidesWorkshopFailure?) -> String? {
        switch failure {
        case let .contact(planet, tick)?:
            "The orbit struck planet \(planet) after tick \(tick)."
        case let .order(target, tick)?:
            "Target \(target) came at tick \(tick), before the target before it."
        case let .share(target, tick, share)?:
            "Target \(target) (first reached at tick \(tick)) swept "
                + ApsidesWorkshopLevel.shareWords(share) + ", outside its band."
        case let .apsisSector(target, sector)?:
            "Target \(target): the apsis lies in sector \(sector), not the sector it asks for."
        case let .apsisDistance(target, distance)?:
            "Target \(target): the apsis lies at " + ApsidesWorkshopLevel.distanceWords(distance)
                + ", outside its range."
        case nil: nil
        }
    }

    /// The engine's prefix on a kernel refusal's code (`action.rule.` before the kernel's `r02-g18.*` code).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix`` (feature 474: codes are read with or without it).
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// The panel line of a refusal: "That change was refused: " and the reason in words.
    static func refusalMessage(code: String) -> String {
        "That change was refused: \(refusalText(code: code))."
    }

    /// Records the result of sending `control` with `values` (feature 474): a refusal is shown in words; an accepted
    /// kernel action drops the pending orbit (it follows the current orbit); `clock.show` keeps it.
    func record(_ control: String, _ values: [Double], accepted: Bool, code: String) {
        guard accepted else {
            message = Self.refusalMessage(code: code)
            return
        }
        message = nil
        if control != "clock.show" { pendingOrbit = nil }
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``.
    static func refusalText(code: String) -> String {
        switch bareCode(code) {
        case "r02-g18.stage": "the play is over: undo a failed play or go to the next level"
        case "r02-g18.action": "that orbit cannot be set, or there is nothing to undo or redo"
        case "r02-g18.budget": "no actions are left: play the orbit or undo a tuning"
        case "r02-g18.stale": "the play changed before the action arrived"
        case "r02-g18.level": "the next level could not be made"
        case ApsidesWorkshopExperienceRule.notWhole: "the orbit's steps and the tick must be whole numbers"
        case ApsidesWorkshopExperienceRule.tick: "that tick is past the end of the revolution"
        default: "that action is not available now"
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct ApsidesWorkshopTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Apsides Workshop.
@MainActor
final class ApsidesWorkshopPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = ApsidesWorkshopExperienceCore

    /// The tutorial shown on levels that have one (presentation, not a kernel stage).
    static let tutorial = "Tune the orbit with the periapsis knob and the size so it sweeps the target sectors and "
        + "puts its apsides where the gauges ask, in order, without striking a planet; then play the revolution."

    /// Whether the star is still (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = ApsidesWorkshopMirror()
    /// The GL scene.
    let scene = ApsidesWorkshopCompassScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1803-004).
    private(set) var tierLog: [ApsidesWorkshopTierChange] = []
    /// The last snapshot drawn (tests, the description and the gestures), with the drawn preview applied.
    private(set) var lastSnapshot: ApsidesWorkshopSceneSnapshot?
    /// The gesture controller (feature 474): knob and size-handle drags, the time crank, double taps and the orbit.
    private(set) var gestures = ApsidesWorkshopGestureController()
    /// The reason codes of refused actions without the engine's prefix, oldest first, at most ``refusalLogLimit``
    /// (observability, feature 474).
    private(set) var refusalLog: [String] = []
    /// How many refusal codes ``refusalLog`` keeps.
    static let refusalLogLimit = 64

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the compass program's fragment source with one that does not compile.
    func breakCompassShader() {
        scene.compassFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the Core's `qualityTiers` (`level-0` … `level-2`).
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(ApsidesWorkshopTier.of(tier).name) }
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
    private func follow(_ core: ApsidesWorkshopExperienceCore) {
        if mirror.play != core.play || mirror.shownTick != core.shownTick {
            mirror.follow(core.play, shownTick: core.shownTick)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: ApsidesWorkshopExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = ApsidesWorkshopTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(ApsidesWorkshopTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let snapshot = presented(core.snapshot(time: time))
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the compass, the
    /// gauges and the actions bars (the camera fits the scene inside a 5 % margin), are `dark` (the midnight backdrop)
    /// once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: ApsidesWorkshopExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: ApsidesWorkshopExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.tutorialText = level.tutorial ? Self.tutorial : nil
        mirror.targetLabel = "Level: \(level.targets.count) targets in order, \(level.planets.count) planets, "
            + "\(level.period) ticks per revolution"
        let measure: String = level.progressDescription(report: play.report, orbit: play.orbit,
                                                        actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Apsides Workshop level \(core.levelNumber). "
        text += measure + ". "
        text += previewText()
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every target was met in order without striking a planet."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = ApsidesWorkshopMirror.failureText(play.failure) ?? "The play failed."
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
        if play.stage == .won || play.stage == .failed || play.stage == .result {
            text += " " + Self.finishedMessage + "."
        }
        return text
    }

    /// The drag's preview or the pending orbit in words (feature 474), each followed by ". "; empty without either.
    private func previewText() -> String {
        var text: String = ""
        if let preview = mirror.preview {
            text += "Previewing size \(preview.size), eccentricity \(preview.eccentricity), direction "
                + "\(preview.direction * 15)°"
            if let snapshot = lastSnapshot, snapshot.isPreviewing {
                var met: Int = 0
                for gauge in snapshot.previewGauges where gauge.met { met += 1 }
                text += ": \(met) of \(snapshot.previewGauges.count) targets met in order"
            }
            text += ". "
        }
        if let pending = mirror.pendingOrbit {
            text += "Pending size \(pending.size), eccentricity \(pending.eccentricity), direction "
                + "\(pending.direction * 15)°"
            if let reason = mirror.pendingReason {
                text += ": " + reason + ". "
            } else {
                text += ": Set periapsis or Set size applies it. "
            }
        }
        return text
    }

    /// `snapshot` with the mirror's drawn preview applied (the drag's preview first, else the valid pending orbit);
    /// without a preview when neither exists.
    private func presented(_ snapshot: ApsidesWorkshopSceneSnapshot) -> ApsidesWorkshopSceneSnapshot {
        guard let preview = mirror.drawnPreview else { return snapshot.withoutPreview() }
        return snapshot.previewing(preview)
    }

    /// Redraws the last snapshot with the mirror's current preview (the next frame draws the same).
    private func refreshPreview() {
        guard let snapshot = lastSnapshot else { return }
        lastSnapshot = presented(snapshot)
    }

    /// The control panel: "Reset view" returns to the authored orbit; every button sends through ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ApsidesWorkshopControls(port: port, mirror: mirror,
                                        resetView: { [weak self] in self?.resetView() },
                                        sender: { [weak self] control, values in
                                            self?.send(control, values, port: port)
                                        },
                                        redraw: { [weak self] in self?.refreshPreview() }))
    }

    // MARK: Touch controls (feature 474, R02-G18-04)

    /// What a finished play says when a one-finger gesture sent nothing.
    static let finishedMessage = ApsidesWorkshopGestureController.finishedReason

    /// The camera's orbit (presentation only; the gesture controller's).
    var orbit: ApsidesWorkshopViewOrbit { gestures.orbit }

    /// The canvas gestures tune the periapsis and the size and show ticks; the preview and the orbit are presentation
    /// state.
    var gestureActions: Set<String> { ["orbit.periapsis", "orbit.size", "clock.show"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(Core.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a periapsis through `orbit.periapsis` and a size through `orbit.size` (one undo step each; the preview is
    /// dropped), a tick through `clock.show` (presentation only), a preview kept in the mirror and drawn, a reset view
    /// (the controller is already at the authored orbit), and an explanation to the mirror's message.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let drawn = lastSnapshot else { return }
        let actions: [ApsidesWorkshopGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: drawn)
        for action in actions {
            switch action {
            case let .tunePeriapsis(eccentricity, direction):
                mirror.preview = nil
                send("orbit.periapsis", [Double(eccentricity), Double(direction)], port: port)
            case let .tuneSize(size):
                mirror.preview = nil
                send("orbit.size", [Double(size)], port: port)
            case let .showTick(tick):
                send("clock.show", [Double(tick)], port: port)
            case let .preview(orbit):
                mirror.preview = orbit
            case .clearPreview:
                mirror.preview = nil
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

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its code (read with or without
    /// the engine's `action.rule.` prefix) in ``refusalLog``; an accepted kernel action drops the pending orbit.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        mirror.record(control, values, accepted: result.isAccepted, code: result.code)
        if !result.isAccepted {
            refusalLog.append(ApsidesWorkshopMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        refreshPreview()
        return result
    }
}
#endif
