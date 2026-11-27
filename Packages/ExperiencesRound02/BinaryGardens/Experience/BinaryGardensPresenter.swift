// BinaryGardensPresenter — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-003, 004, 005, 007, 010;
// clarifications Q2, Q4, Q5). Draws the adapter's immutable snapshot with `BinaryGardensSystemScene` at the host's
// quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityProfile` names, the
// names of `BinaryGardensTier.all`), keeps a log of every tier change with its reason, stops the coronas and the
// pollen motes under Reduce Motion and caps the glow under Reduce Flashing. No position moves by time: the shown tick
// is the adapter's presentation state (`clock.show`, 48 at an opening) and is never advanced by time; only the coronas
// and the motes move with the presentation time. The tutorial of the first levels is shown in words, as presentation,
// not as a kernel stage. A refused action is shown in words. A memory warning releases the GPU objects; the next frame
// rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel (renderer purity). Its
// probes (two backdrop corners) let the verification runner check a frame (the round-two X gates require them).
// Modelled on `MushroomWeatherPresenter` (feature 493).
// Feature 504 (R02-G21-04) T-R02G2104-005 (FR-R02G2104-001 … 016): a canvas touch goes through the presenter's
// `BinaryGardensGestureController` with the drawn snapshot (`pointer`; the core's snapshot with the mirror's preview
// and inspection applied): a star drag across the rings or along its orbit previews the change (the kernel's own
// preview, `BinaryGardensSceneSnapshot.previewing`, presentation only, kept in the mirror) and its release sends one
// `star.ring [star, index]` or `star.phase [star, step]`; a pip tap or drag sends one `star.luminosity [star, index]`,
// a dial tap or drag one `orbit.tilt [step]` (each dropping the preview); a world tap inspects the world (marked in the
// scene, its kernel words at the shown tick in the description) and a second tap clears it; a gauge press shows ticks
// (`clock.show [tick]`, in any stage); a tapped star is selected in the panel; two fingers orbit the camera and a
// double tap on empty space or "Reset view" (`resetView()`) returns it (presentation only; the meshes are rebuilt).
// Kernel actions are sent only while playing (the controller's rule); a gesture that does nothing for a stated reason
// says it in the mirror's message (the controller's texts verbatim). A refused preview is named in words; a refused
// action is shown in the panel and its code, read with or without the engine's `action.rule.` prefix, is kept in the
// refusal log (at most 64). An opening, `level.next`, reset or restore (a new level number, or records that no longer
// extend the followed ones) clears the preview, the inspection and the orbit. Modelled on `MushroomWeatherPresenter`
// (feature 494).
#if os(iOS)
import BinaryGardensCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described, the shown tick and the panel's selection.
@MainActor
@Observable
final class BinaryGardensMirror {
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
    /// The shown tick, the adapter's (1 … 48).
    var shownTick = BinaryGardensExperienceCore.openingTick
    /// The play followed (a copy; never sent anywhere).
    var play: BinaryGardensPlay?
    /// The text of the last refused change, or why a gesture did nothing, if any.
    var message: String?
    /// The star the panel edits (0 or 1).
    var star = 0
    /// A drag's preview (feature 504; presentation only): the change the drag would make, nil while no drag previews.
    var preview: BinaryGardensAction?
    /// The kernel's refusal of the drawn preview (feature 504), nil while no refused preview is drawn.
    var previewRefusal: BinaryGardensError?
    /// The inspected world (feature 504; presentation only), nil while no world is inspected.
    var inspectedWorld: Int?
    /// The panel's phase target for the selected star (feature 504; presentation only; on the phase grid 0 … 48 − g).
    var phaseTarget = 0

    /// The ticks of one cycle, 48.
    static var cycle: Int { BinaryGardensSky.cycle }

    /// The star the panel edits, clamped to 0 … 1.
    var selectedStar: Int { min(max(star, 0), 1) }

    /// The arrangement of the followed play (nil while no play is followed).
    var arrangement: BinaryGardensArrangement? { play?.arrangement }

    /// The rings of the followed level (1 while no play is followed).
    var ringCount: Int { max(play?.level.ringRadii.count ?? 1, 1) }

    /// The luminosity levels of the followed level (1 while no play is followed).
    var luminosityCount: Int { max(play?.level.luminosityLevels.count ?? 1, 1) }

    /// The largest tilt T_max of the followed level (0 while no play is followed).
    var maxTilt: Int { play?.level.maxTilt ?? 0 }

    /// The phase step g of the followed level (1 while no play is followed).
    var phaseStep: Int { max(play?.level.phaseStep ?? 1, 1) }

    /// The selected star's ring index (0 while no play is followed).
    var ring: Int { value(arrangement?.rings) }

    /// The selected star's phase (0 while no play is followed).
    var phase: Int { value(arrangement?.phases) }

    /// The selected star's luminosity index (0 while no play is followed).
    var luminosity: Int { value(arrangement?.luminosities) }

    /// The tilt (0 while no play is followed).
    var tilt: Int { arrangement?.tilt ?? 0 }

    /// The worlds of the followed level (0 while no play is followed; feature 504).
    var worldCount: Int { play?.level.worlds.count ?? 0 }

    /// The panel's phase target on the level's phase grid, within 0 … 48 − g (feature 504).
    var gridPhaseTarget: Int { Self.gridPhase(phaseTarget, step: phaseStep) }

    /// `phase` snapped down to the phase grid of step `step` and read within 0 … 48 − step (feature 504).
    static func gridPhase(_ phase: Int, step: Int) -> Int {
        let g: Int = max(step, 1)
        let cycle: Int = Self.cycle
        let wrapped: Int = (phase % cycle + cycle) % cycle
        return wrapped - wrapped % g
    }

    /// The phase target `step` grid steps from the current one, read cyclically over 0 … 47 (feature 504).
    func phaseTarget(moved step: Int) -> Int {
        let cycle: Int = Self.cycle
        return Self.gridPhase(((gridPhaseTarget + step * phaseStep) % cycle + cycle) % cycle, step: phaseStep)
    }

    /// Selects star `star` (clamped to 0 … 1) and takes its phase as the phase target (feature 504).
    func select(star: Int) {
        self.star = min(max(star, 0), 1)
        phaseTarget = phase
    }

    /// The inspected world's kernel words at the shown tick (its light, each star's share and band at the tick, then
    /// its window and bloom over the cycle), or nil while no world of the followed play is inspected (feature 504).
    var inspectedLabel: String? {
        guard let world = inspectedWorld, let play, play.level.worlds.indices.contains(world),
              world < play.report.worlds.count else { return nil }
        let tick: Int = Self.wrappedTick(shownTick)
        return play.level.worldTickDescription(world, tick: tick, report: play.report) + "; "
            + play.level.worldDescription(world, report: play.report)
    }

    /// The drawn refused preview in words, or nil (feature 504).
    var previewRefusalLabel: String? {
        guard let refusal = previewRefusal else { return nil }
        return Self.previewRefusalMessage(refusal)
    }

    /// Drops the preview, its refusal and the inspection (feature 504: an opening, `level.next`, reset or restore).
    func clearPresentation() {
        preview = nil
        previewRefusal = nil
        inspectedWorld = nil
    }

    /// The selected star's entry of `values`, or 0.
    private func value(_ values: [Int]?) -> Int {
        guard let values, values.indices.contains(selectedStar) else { return 0 }
        return values[selectedStar]
    }

    /// The ring index `step` rings from the selected star's, clamped to the level's rings (the kernel refuses the
    /// unchanged ring at an end).
    func ring(moved step: Int) -> Int { min(max(ring + step, 0), ringCount - 1) }

    /// The phase `step` phase steps g from the selected star's, read cyclically over 0 … 47 (always on the grid).
    func phase(moved step: Int) -> Int {
        let cycle: Int = Self.cycle
        return ((phase + step * phaseStep) % cycle + cycle) % cycle
    }

    /// The luminosity index `step` levels from the selected star's, clamped to the level's levels.
    func luminosity(moved step: Int) -> Int { min(max(luminosity + step, 0), luminosityCount - 1) }

    /// The tilt `step` steps from the current one, clamped to 0 … T_max.
    func tilt(moved step: Int) -> Int { min(max(tilt + step, 0), maxTilt) }

    /// Tick `tick` read cyclically as one of 1 … 48 (tick 49 is tick 1, tick 0 is tick 48).
    static func wrappedTick(_ tick: Int) -> Int {
        let cycle: Int = Self.cycle
        return ((tick - 1) % cycle + cycle) % cycle + 1
    }

    /// The selected star in words (the kernel's star description), or "no star".
    var starLabel: String {
        guard let play else { return "no star" }
        return play.level.starDescription(selectedStar, arrangement: play.arrangement)
    }

    /// The tilt in words.
    var tiltLabel: String { "tilt \(tilt) of \(maxTilt) steps" }

    /// The shown tick in words.
    var tickLabel: String { "tick \(shownTick) of \(Self.cycle)" }

    /// Every world at the shown tick in words (the kernel's tick descriptions), joined by "; ".
    var worldsLabel: String {
        guard let play else { return "no worlds" }
        let tick: Int = Self.wrappedTick(shownTick)
        var parts: [String] = []
        for world in play.level.worlds.indices where world < play.report.worlds.count {
            parts.append(play.level.worldTickDescription(world, tick: tick, report: play.report))
        }
        return parts.joined(separator: "; ")
    }

    /// Takes the new `play` and presentation.
    func follow(_ play: BinaryGardensPlay, shownTick: Int) {
        self.play = play
        self.shownTick = shownTick
    }

    /// A failure in words, naming what the kernel's reason names (the level's failure description, first letter in
    /// upper case, with a full stop); nil without a failure.
    static func failureText(_ failure: BinaryGardensFailure?, level: BinaryGardensLevel) -> String? {
        guard let failure else { return nil }
        return level.failureDescription(failure).capitalizedFirst + "."
    }

    /// The prefix the engine puts before a rule's code in an action result's code.
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix`` (feature 504: codes are read with or without it).
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// The panel line of a refusal: "That change was refused: " and the reason in words, with a full stop.
    static func refusalMessage(code: String) -> String {
        "That change was refused: \(refusalText(code: code))."
    }

    /// Records the result of sending a control (feature 504): a refusal is shown in words; an accepted action clears
    /// the message.
    func record(accepted: Bool, code: String) {
        message = accepted ? nil : Self.refusalMessage(code: code)
    }

    /// A refused preview's kernel refusal in words (feature 504): a separation break, a locked control and a value off
    /// the phase grid or out of range are named; any other refusal reads as its reason code does.
    static func previewRefusalText(_ refusal: BinaryGardensError) -> String {
        switch refusal {
        case .action("separation"): return "the two stars would come too close to each other"
        case .action("locked"): return "that control is locked on this level"
        case .action("off the phase grid"): return "that phase is off the level's phase grid"
        default: return refusalText(code: refusal.reasonCode)
        }
    }

    /// The panel line of a refused preview: "That change would be refused: " and the reason in words, with a full stop.
    static func previewRefusalMessage(_ refusal: BinaryGardensError) -> String {
        "That change would be refused: \(previewRefusalText(refusal))."
    }

    /// A refused action's reason code in words: the rule's code (`r02-g21.…`), with or without the engine's
    /// `action.rule.` prefix (an action result's code carries it).
    static func refusalText(code: String) -> String {
        let rule: String = bareCode(code)
        switch rule {
        case "r02-g21.stage": return "the play is over: undo a failed run or go to the next level"
        case "r02-g21.action": return "that ring, phase, luminosity or tilt cannot be set that way (locked, unchanged, off "
            + "the phase grid or too close to the other star), or there is nothing to undo or redo"
        case "r02-g21.budget": return "no actions are left: run the light or undo a change"
        case "r02-g21.stale": return "the play changed before the action arrived"
        case "r02-g21.level": return "the next level could not be made"
        case "r02-g21.generation": return "the next level could not be made"
        case BinaryGardensExperienceRule.notWhole: return "the star, ring, phase, luminosity, tilt and tick must be whole "
            + "numbers"
        case BinaryGardensExperienceRule.tick: return "only ticks 1 to 48 can be shown"
        default: return "that action is not available now"
        }
    }
}

private extension String {
    /// The string with its first letter in upper case.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct BinaryGardensTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Binary Gardens.
@MainActor
final class BinaryGardensPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = BinaryGardensExperienceCore

    /// The tutorial shown on levels that have one (presentation, not a kernel stage).
    static let tutorial = "Move the twin stars between their rings, shift their phases, set their brightness and tilt "
        + "the orbit plane so every flower world keeps a long enough comfortable window and its total light inside "
        + "its bloom band, without freezing or scorching for too long; then run the light."

    /// Whether Reduce Motion is on (the coronas and motes stop).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = BinaryGardensMirror()
    /// The GL scene.
    let scene = BinaryGardensSystemScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G2103-004).
    private(set) var tierLog: [BinaryGardensTierChange] = []
    /// The last snapshot drawn (tests, the description and the gestures), with the mirror's preview and inspection
    /// applied (feature 504).
    private(set) var lastSnapshot: BinaryGardensSceneSnapshot?
    /// The core's snapshot last drawn, without the preview and the inspection, and its level (feature 504).
    private var lastBase: (snapshot: BinaryGardensSceneSnapshot, level: BinaryGardensLevel)?
    /// The level number of the play last followed (feature 504: a new one is a new play).
    private var followedLevel: Int?
    /// The gesture controller (feature 504): star, pip, dial, world and gauge gestures, double taps and orbits.
    private(set) var gestures = BinaryGardensGestureController()
    /// The bare codes of refused actions, oldest first, at most ``refusalLogLimit`` (feature 504).
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

    /// The tests' seam: before `setup`, replaces the system program's fragment source with one that does not compile.
    func breakSystemShader() {
        scene.systemFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the names of the Core's `qualityProfile` (`level-0` … `level-2`, the
    /// names of `BinaryGardensTier.all`), as many as the Core's `qualityTiers`.
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(BinaryGardensTier.of(tier).name) }
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

    /// Follows `core`'s play and presentation in the mirror when they changed. A new play (an opening, `level.next`,
    /// reset or restore: another level number, or records that do not extend the followed ones) clears the preview,
    /// the inspection and the orbit (feature 504); a changed play takes the selected star's phase as the phase target.
    private func follow(_ core: BinaryGardensExperienceCore) {
        let previous: BinaryGardensPlay? = mirror.play
        let playChanged: Bool = previous != core.play
        guard playChanged || mirror.shownTick != core.shownTick else { return }
        let fresh: Bool = Self.isNewPlay(previous, core.play, followedLevel: followedLevel,
                                         levelNumber: core.levelNumber)
        followedLevel = core.levelNumber
        mirror.follow(core.play, shownTick: core.shownTick)
        if fresh { clearPresentation() }
        if playChanged { mirror.phaseTarget = mirror.phase }
    }

    /// Whether `next` (of level `levelNumber`) is a new play after `previous` (of level `followedLevel`): no play was
    /// followed, the level number changed, or `next`'s records do not extend `previous`'s (a reset or a restore; the
    /// records are append-only, undo and redo included).
    static func isNewPlay(_ previous: BinaryGardensPlay?, _ next: BinaryGardensPlay, followedLevel: Int?,
                          levelNumber: Int) -> Bool {
        guard let previous, followedLevel == levelNumber else { return true }
        let old: [BinaryGardensRecord] = previous.records
        let new: [BinaryGardensRecord] = next.records
        guard new.count >= old.count else { return true }
        return !new.starts(with: old)
    }

    /// Drops the preview and the inspection, cancels a gesture in progress and returns the camera to the authored view
    /// (feature 504: a new play).
    private func clearPresentation() {
        mirror.clearPresentation()
        if gestures.state != .idle { gestures.cancel() }
        gestures.resetView()
        scene.orbit = gestures.orbit
        refreshPreview()
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: BinaryGardensExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = BinaryGardensTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(BinaryGardensTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let base: BinaryGardensSceneSnapshot = core.snapshot(time: time)
        lastBase = (snapshot: base, level: core.play.level)
        let snapshot: BinaryGardensSceneSnapshot = presented(base, level: core.play.level)
        lastSnapshot = snapshot
        mirror.previewRefusal = snapshot.preview?.refusal
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the tilt dial, the
    /// system, the gauges and the actions bars (the camera fits the scene's box inside a 6 % margin per side), are
    /// `dark` (the space backdrop) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: BinaryGardensExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: BinaryGardensExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.tutorialText = level.tutorial ? Self.tutorial : nil
        let tiltWords: String = level.maxTilt == 0 ? "the orbit plane locked" : "tilt up to \(level.maxTilt) steps"
        mirror.targetLabel = "Level: \(level.ringRadii.count) rings, \(level.worlds.count) worlds, "
            + "\(level.luminosityLevels.count) luminosity levels, phase step \(level.phaseStep), " + tiltWords
            + ", lethal tolerance \(level.lethalTolerance) ticks, \(level.budget) actions"
        let measure: String = level.progressDescription(report: play.report, arrangement: play.arrangement,
                                                        actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Binary Gardens level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every world kept its window and bloomed."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = BinaryGardensMirror.failureText(play.failure, level: level) ?? "The run failed."
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
        if let inspected = mirror.inspectedLabel {
            if !text.hasSuffix(" ") { text += " " }
            text += "Inspected " + inspected + "."
        }
        return text
    }

    /// `snapshot` with the mirror's drag preview (judged by the kernel in `level`) and inspection applied (feature 504;
    /// presentation only).
    private func presented(_ snapshot: BinaryGardensSceneSnapshot,
                           level: BinaryGardensLevel) -> BinaryGardensSceneSnapshot {
        var shown: BinaryGardensSceneSnapshot = snapshot
        if let change = mirror.preview { shown = shown.previewing(change, level: level) }
        return shown.inspecting(mirror.inspectedWorld)
    }

    /// Re-applies the mirror's preview and inspection to the last core snapshot, so tests and the next gesture read
    /// them (feature 504).
    private func refreshPreview() {
        guard let base = lastBase else { return }
        let snapshot: BinaryGardensSceneSnapshot = presented(base.snapshot, level: base.level)
        lastSnapshot = snapshot
        mirror.previewRefusal = snapshot.preview?.refusal
    }

    /// The control panel: the direct choices, "Inspect" and "Reset view" (feature 504); every kernel control sends
    /// through ``send(_:_:port:)``, so refusals are shown and logged.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(BinaryGardensControls(port: port, mirror: mirror,
                                      sendAction: { [weak self] control, values in
                                          self?.send(control, values, port: port)
                                      },
                                      inspect: { [weak self] world in self?.inspect(world) },
                                      resetView: { [weak self] in self?.resetView() }))
    }

    // MARK: Gestures (feature 504)

    /// The camera's orbit (presentation only; the gesture controller's).
    var orbit: BinaryGardensViewOrbit { gestures.orbit }

    /// The gesture controller's state (diagnostics).
    var gestureState: BinaryGardensGestureController.State { gestures.state }

    /// The canvas gestures move stars between rings, shift their phases, set their luminosity, tilt the orbit plane
    /// and show ticks; the preview, the inspection and the orbit are presentation state.
    var gestureActions: Set<String> { ["star.ring", "star.phase", "star.luminosity", "orbit.tilt", "clock.show"] }

    /// The native controls send every declared control, every action a gesture can and more.
    var nativeActions: Set<String> { Set(Core.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a ring, phase, luminosity or tilt change through `star.ring [star, index]`, `star.phase [star, step]`,
    /// `star.luminosity [star, index]` or `orbit.tilt [step]` (one action each; the preview is dropped), a tick through
    /// `clock.show [tick]` (presentation only), an inspection kept in the mirror, a star selected in the panel, a
    /// preview kept in the mirror and drawn, a reset view (the controller is already at the authored orbit) and an
    /// explanation to the mirror's message.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let drawn = lastSnapshot else { return }
        let actions: [BinaryGardensGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: drawn)
        for action in actions { apply(action, port: port) }
        if event.phase == .ended || event.phase == .cancelled || gestures.state == .orbiting
            || gestures.state == .cancelled {
            mirror.preview = nil
        }
        scene.orbit = gestures.orbit
        refreshPreview()
    }

    /// Applies one gesture action (see ``pointer(_:viewSize:port:)``).
    private func apply(_ action: BinaryGardensGestureAction, port: ExperienceActionPort) {
        switch action {
        case let .setRing(star, index):
            mirror.preview = nil
            send("star.ring", [Double(star), Double(index)], port: port)
        case let .setPhase(star, step):
            mirror.preview = nil
            send("star.phase", [Double(star), Double(step)], port: port)
        case let .setLuminosity(star, index):
            mirror.preview = nil
            send("star.luminosity", [Double(star), Double(index)], port: port)
        case let .setTilt(step):
            mirror.preview = nil
            send("orbit.tilt", [Double(step)], port: port)
        case let .showTick(tick):
            send("clock.show", [Double(tick)], port: port)
        case let .inspectWorld(world):
            mirror.inspectedWorld = world
        case let .selectStar(star):
            mirror.select(star: star)
        case let .preview(change):
            mirror.preview = change
        case .clearPreview:
            mirror.preview = nil
        case .resetView:
            break   // the controller has already returned to the authored orbit; the next frame draws it
        case let .explain(reason):
            mirror.message = reason
        }
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

    /// Inspects world `world`, or clears the inspection with nil or a world the level lacks (the panel's "Inspect";
    /// presentation only).
    func inspect(_ world: Int?) {
        if let world, (0..<mirror.worldCount).contains(world) {
            mirror.inspectedWorld = world
        } else {
            mirror.inspectedWorld = nil
        }
        refreshPreview()
    }

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its bare code in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result: ActionResult = port.send(control, values)
        mirror.record(accepted: result.isAccepted, code: result.code)
        if !result.isAccepted {
            refusalLog.append(BinaryGardensMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        refreshPreview()
        return result
    }
}
#endif
