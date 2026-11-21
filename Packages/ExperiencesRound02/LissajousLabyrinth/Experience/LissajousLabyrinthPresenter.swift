// LissajousLabyrinthPresenter — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-003 … 005, 007; clarifications Q4,
// Q5). Draws the adapter's immutable snapshot with `LissajousLabyrinthThreadScene` at the host's quality tier (tier n
// is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the tracer head
// still under Reduce Motion (the snapshot time stays at 0 and the shimmer stops) and caps the glow under Reduce
// Flashing. A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads
// `core.snapshot`: no drawing result reaches the kernel (renderer purity, R2-G02-INV-10).
// Feature 314 (R02-G02-04) T-R02G0204-005 (FR-R02G0204-001 … 006): canvas touches go through
// `LissajousLabyrinthGestureController`: one finger turns a dial ring and sends one `dial.set` on release, two fingers
// orbit the camera (presentation only), a double tap on empty space resets it. The selection, the turn's candidate and
// the pending values are mirrored for the scene, the description and the controls. The panel's steppers set pending
// values (`stepPending`, announced, no action); `applyPending` sends `LissajousLabyrinthPending.actions(from:)` in order,
// stops at the first refusal (announced with its reason) or when the level ends (announced as its outcome) and drops
// the rest; `clearPending` drops them; any change of the play or level from elsewhere drops them too. Announcements go
// through `ExperienceFeedback` (`feedback`, `.shared` unless a test injects one) and are logged in `announcements`.
// Feature 315 (R02-G02-05) T-R02G0205-005 (FR-R02G0205-001 … 005): the mirror carries the tutorial instruction, the hint
// revealed so far (`showHint(port:)` reveals the next of three levels for the current play and tells the core a hint
// was shown; any change of the play hides it), the failure explanation, the mode, the open levels with their stars, the
// goal (allowance and certified shortest); `retry` starts the level again in its mode, and the daily level is chosen
// from the local calendar date read here (`playDaily(port:date:)`), never in the core.
// Feature 316 (R02-G02-06) T-R02G0206-005 (FR-R02G0206-002 … 004, 006): after each described change the presenter
// routes `LissajousLabyrinthFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route and
// plans refusals with `refused(code:)`; it keeps a feedback log, eases the scene's lights (`LissajousLabyrinthLights`,
// 0.45 s fades under Reduce Flashing) and offers the ambient recipe to `LissajousLabyrinthSound` at level openings and
// play ends.
// Feature 317 (R02-G02-07) T-R02G0207-005 (FR-R02G0207-003, 004): the mirror carries whether a replay is available for
// the current level and, during replay, its position; `startReplay`, `stepReplay` and `stopReplay` send the replay
// actions; the first described core whose restore dropped results announces them once.
// Gate X-R02-G02: `probes` declares the frame probes the verification runner samples: two background corners, outside
// the figure and the dial rings, must be the dark night clear while the real scene (not the fallback) is drawn.
#if os(iOS)
import Foundation
import LissajousLabyrinthCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class LissajousLabyrinthMirror {
    /// The four dials; nil before the first description.
    var dials: LissajousLabyrinthDials?
    /// The play's stage.
    var stage: LissajousLabyrinthStage = .loading
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions spent.
    var spent = 0
    /// The action allowance.
    var allowance = 0
    /// The text of the last refused change, if any.
    var message: String?
    /// The selected dial (feature 314): outlined in the scene and named in the description.
    var selectedDial: LissajousLabyrinthDial = .frequencyA
    /// The value a running turn would set; nil while no dial is being turned.
    var candidate: LissajousLabyrinthAction?
    /// The values the panel's steppers set but did not apply yet (feature 314); empty when nothing is pending.
    var pending = LissajousLabyrinthPending()
    /// The tutorial instruction; nil when the tutorial is done (feature 315).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 315).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 315).
    var failureText: String?
    /// The mode (feature 315).
    var mode: LissajousLabyrinthMode = .campaign
    /// The highest open level and the stars of each solved level (feature 315).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The certified shortest solution length of the current level (feature 315).
    var shortest = 0
    /// Whether the ambient sound is on (feature 316; off by default).
    var soundOn = false
    /// Whether a verified result with a trace exists for the current level (feature 317).
    var replayAvailable = false
    /// Whether a replay is running, its position and its length (feature 317).
    var replaying = false
    var replayPosition = 0
    var replayLength = 0
}

/// One entry of the tier log: the tier drawn and why it changed.
struct LissajousLabyrinthTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Lissajous Labyrinth.
@MainActor
final class LissajousLabyrinthPresenter: ExperiencePresenter {
    typealias Core = LissajousLabyrinthExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = LissajousLabyrinthMirror()
    let scene = LissajousLabyrinthThreadScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0203-004).
    private(set) var tierLog: [LissajousLabyrinthTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: LissajousLabyrinthSceneSnapshot?
    /// The gesture controller (feature 314): arbitration, turns, orbit and the selection.
    private(set) var gestures = LissajousLabyrinthGestureController()
    /// The last described core (pending values, adjustments and the outside-change check).
    private(set) var latestCore: LissajousLabyrinthExperienceCore?
    /// Whether the dropped results of a restore were announced (feature 317).
    private var droppedAnnounced = false
    /// The haptic held while Apply sends its actions; played once when Apply ends (feature 316).
    private var heldHaptic: HapticKind?
    /// True while `applyPending` sends its actions, so the described changes do not count as outside changes.
    private var applying = false
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 315).
    private var hintKey: String?
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 315).
    private(set) var dailyDate: DateComponents?
    /// The feedback route of announcements (tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every announcement made, oldest first (tests and diagnostics).
    private(set) var announcements: [String] = []
    /// Every routed feedback plan, oldest first (feature 316; tests and diagnostics).
    private(set) var feedbackLog: [LissajousLabyrinthFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 316).
    private(set) var lights: LissajousLabyrinthLights
    /// The frame time of the last draw, for easing the lights.
    private var lastFrameTime: Double?
    /// The fingerprint of the level the lights belong to.
    private var lightsLevel: String?
    /// The ambient sound (feature 316).
    let sound: LissajousLabyrinthSound

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        lights = LissajousLabyrinthLights(reducedFlash: reduceFlashing)
        sound = LissajousLabyrinthSound(recipe: LissajousLabyrinthSoundRecipe.recipe(
            dials: LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0), stage: .playing))
    }

    /// The tests' seam: before `setup`, replaces the thread program's fragment source with one that does not compile.
    func breakThreadShader() {
        scene.threadFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: LissajousLabyrinthExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = LissajousLabyrinthTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(LissajousLabyrinthTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        // A new level (or mode) starts from its own lights: they settle at once, only changes within a play fade. A
        // frame time that does not move forward (an off-screen still drawn at its own time, or at the same time as the
        // last frame) is a separate picture: it settles too (feature 318: the hero golden frame).
        if let last = lastFrameTime, lightsLevel == snapshot.level.fingerprint, frame.time > last {
            lights.step(toward: snapshot, elapsed: frame.time - last)
        } else {
            lights.settle(to: snapshot)
        }
        lightsLevel = snapshot.level.fingerprint
        lastFrameTime = frame.time
        scene.lights = lights
        playing = core.play.stage == .playing
        scene.orbit = gestures.orbit
        scene.selectedDial = gestures.selectedDial
        scene.preview = gestures.preview
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn (see the file header): the top-left and bottom-right background
    /// corners are `dark` (the night clear) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: LissajousLabyrinthExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "night-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "night-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// Whether the play was in stage `playing` at the last frame (gestures answer only then).
    private var playing = false

    // MARK: Touch controls (feature 314)

    /// The canvas gestures send kernel actions only.
    var gestureActions: Set<String> { ["dial.set"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(LissajousLabyrinthExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller; a finished turn sends its one `dial.set`.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let action = gestures.handle(event, viewSize: viewSize, snapshot: snapshot, playing: playing)
        mirror.selectedDial = gestures.selectedDial
        mirror.candidate = gestures.preview
        if let action { send(action, port: port) }
    }

    /// Drops a touch in progress (the shell suspends the experience): the turn ends without an action.
    func cancelPointers() {
        gestures.cancel()
        mirror.candidate = nil
    }

    /// Selects `dial` (a stepper was used or a test selects it).
    func select(_ dial: LissajousLabyrinthDial) {
        gestures.select(dial)
        mirror.selectedDial = dial
    }

    /// Returns the camera to the authored view ("Reset view").
    func resetView() {
        gestures.resetOrbit()
    }

    /// Sends `action` as `dial.set [index, value]`; a refusal is shown and announced with its reason.
    @discardableResult
    func send(_ action: LissajousLabyrinthAction, port: ExperienceActionPort) -> ActionResult {
        let index = LissajousLabyrinthDial.allCases.firstIndex(of: action.dial) ?? 0
        return send("dial.set", [Double(index), Double(action.value)], port: port)
    }

    /// Sends `control` with `values`; a refusal is shown and announced with its reason.
    @discardableResult
    func send(_ control: String, _ values: [Double] = [], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            let plan = LissajousLabyrinthFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            route(plan)
        }
        return result
    }

    /// Steps the pending value of `dial` by `delta` (wrapping in its range), selects it and announces
    /// "<Dial name> <value> pending. Apply to change."; sends no action.
    func stepPending(_ dial: LissajousLabyrinthDial, by delta: Int) {
        guard let core = latestCore else { return }
        select(dial)
        mirror.pending.step(dial, by: delta, current: core.play.dials)
        let value = mirror.pending.values[dial] ?? core.play.dials[dial]
        announce("\(Self.title(dial)) \(value) pending. Apply to change.", kind: .state)
    }

    /// Sends the pending values as actions in `LissajousLabyrinthPending.actions(from:)` order; stops at the first
    /// refusal (announced by `send`) or when the level ends (its outcome is announced) and drops the rest; the pending
    /// values are cleared in every case. Returns the results in order.
    @discardableResult
    func applyPending(port: ExperienceActionPort) -> [ActionResult] {
        guard let core = latestCore, !mirror.pending.isEmpty else { return [] }
        let actions = mirror.pending.actions(from: core.play.dials)
        applying = true
        heldHaptic = nil
        defer {
            applying = false
            mirror.pending.clear()
            if let haptic = heldHaptic { feedback.haptic(haptic) }
            heldHaptic = nil
        }
        var results: [ActionResult] = []
        for action in actions {
            if let now = latestCore, now.play.stage != .playing {
                // The outcome was already announced by the feedback plan of the action that ended the play (316).
                break
            }
            let result = send(action, port: port)
            results.append(result)
            if !result.isAccepted { break }
        }
        return results
    }

    // MARK: Teaching and progression (feature 315)

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: LissajousLabyrinthExperienceCore) -> String {
        "\(core.levelNumber)/\(core.mode)/\(core.play.fingerprint)"
    }

    /// Reveals the next hint level (up to 3) for the current play and tells the core that a hint was shown
    /// (`tutorial.hint`, which only advances the tutorial); nothing when the play has ended or no solution is reachable.
    func showHint(port: ExperienceActionPort) {
        guard let core = latestCore else { return }
        let key = Self.hintKey(core)
        let next = hintKey == key ? min(mirror.hintLevel + 1, 3) : 1
        guard let hint = core.hint(level: next) else {
            hintKey = nil
            mirror.hintLevel = 0
            mirror.hintText = nil
            return
        }
        hintKey = key
        mirror.hintLevel = next
        mirror.hintText = hint.text
        announce(hint.text, kind: .state)
        if core.tutorial == .checkpoints { _ = port.send("tutorial.hint", []) }
    }

    /// Ends the tutorial of the current level.
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", port: port)
    }

    /// The action and values that start the current level again in its mode: `mode.practice` in practice, the daily
    /// date's `mode.daily` in daily mode, `level.select` of the level in campaign.
    func retryAction(date: DateComponents) -> (control: String, values: [Double]) {
        guard let core = latestCore else { return ("mode.campaign", []) }
        switch core.mode {
        case .practice: return ("mode.practice", [])
        case .daily: return ("mode.daily", Self.dateValues(dailyDate ?? date))
        case .campaign: return ("level.select", [Double(core.levelNumber)])
        case .replay(let level): return ("replay.start", [Double(level)])
        }
    }

    /// Starts the replay of the current level's best stored solution (`replay.start`; feature 317).
    @discardableResult
    func startReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.start", [Double(mirror.levelNumber)], port: port)
    }

    /// Plays the next action of the running replay (`replay.step`).
    @discardableResult
    func stepReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.step", port: port)
    }

    /// Stops the running replay and returns to the campaign (`replay.stop`).
    @discardableResult
    func stopReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.stop", port: port)
    }

    /// Starts the current level again in its mode; in daily mode with the date that opened it (today's local date
    /// when none is known).
    @discardableResult
    func retry(port: ExperienceActionPort, date: DateComponents = LissajousLabyrinthPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort,
                   date: DateComponents = LissajousLabyrinthPresenter.today()) -> ActionResult {
        let result = send("mode.daily", Self.dateValues(date), port: port)
        if result.isAccepted { dailyDate = date }
        return result
    }

    /// The local calendar date now, as Gregorian year, month and day in the current time zone.
    static func today() -> DateComponents {
        Calendar(identifier: .gregorian).dateComponents(in: .current, from: Date())
    }

    /// The values of `mode.daily` for `date`: year, month, day (0 for a missing part, which the engine refuses).
    static func dateValues(_ date: DateComponents) -> [Double] {
        [Double(date.year ?? 0), Double(date.month ?? 0), Double(date.day ?? 0)]
    }

    /// Drops the pending values; sends nothing.
    func clearPending() {
        mirror.pending.clear()
    }

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: LissajousLabyrinthFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic {
            if applying {
                // During Apply the actions come in one instant and the shared planner keeps only the first haptic, so
                // the most important one is held and played once when Apply ends (an outcome over a selection).
                if heldHaptic == nil || haptic != .selection { heldHaptic = haptic }
            } else {
                feedback.haptic(haptic)
            }
        }
        if let text = plan.text, let kind = plan.kind {
            feedback.announce(text, kind: kind)
            announcements.append(text)
        }
        feedbackLog.append(plan)
    }

    /// Turns the ambient sound on or off; turning it on plays the recipe of the current dials and stage.
    func setSound(on: Bool) {
        if on, let core = latestCore {
            sound.offer(LissajousLabyrinthSoundRecipe.recipe(dials: core.play.dials, stage: core.play.stage))
        }
        sound.setWanted(on)
        mirror.soundOn = on
    }

    /// The controls view appeared (the loop may play).
    func controlsAppeared() { sound.setOnScreen(true) }

    /// The controls view disappeared (the loop stops).
    func controlsDisappeared() { sound.setOnScreen(false) }

    /// The scene became active or inactive.
    func sceneActive(_ active: Bool) { sound.setActive(active) }

    /// Announces `text` through the feedback route and logs it.
    func announce(_ text: String, kind: AnnouncementKind) {
        feedback.announce(text, kind: kind)
        announcements.append(text)
    }

    /// The dial names in control order.
    static let dialNames: [String] = ["frequency A", "frequency B", "phase A", "phase C"]

    /// The capitalised name of `dial`: "Frequency A", "Frequency B", "Phase A" or "Phase C".
    static func title(_ dial: LissajousLabyrinthDial) -> String {
        let name = dialNames[LissajousLabyrinthDial.allCases.firstIndex(of: dial) ?? 0]
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    func describe(_ core: LissajousLabyrinthExperienceCore) -> String {
        let play = core.play
        if !applying, !mirror.pending.isEmpty, let previous = latestCore,
           previous.levelNumber != core.levelNumber || previous.play.records != core.play.records
            || previous.play.dials != core.play.dials {
            mirror.pending.clear()
        }
        if latestCore == nil {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(LissajousLabyrinthSoundRecipe.recipe(dials: core.play.dials, stage: core.play.stage))
        }
        if let previous = latestCore {
            route(LissajousLabyrinthFeedbackPlan.after(old: previous, new: core))
            let opened = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            let ended = previous.play.stage != core.play.stage && (core.play.stage == .won || core.play.stage == .failed)
            // A fresh play of the same level (Retry, level.select) after an ended one starts its own recipe again.
            let restarted = previous.play.stage != core.play.stage && core.play.stage == .playing
            if opened || ended || restarted {
                sound.offer(LissajousLabyrinthSoundRecipe.recipe(dials: core.play.dials, stage: core.play.stage))
            }
        }
        if !droppedAnnounced, core.reconciliationDropped > 0 {
            droppedAnnounced = true
            let count = core.reconciliationDropped
            let text = count == 1 ? "1 saved result could not be checked and was removed."
                : "\(count) saved results could not be checked and were removed."
            route(LissajousLabyrinthFeedbackPlan(text: text, kind: .state, haptic: nil))
        }
        latestCore = core
        if let level = core.progress.solved[core.levelNumber] {
            mirror.replayAvailable = level.verified && !level.trace.isEmpty
                && !LissajousLabyrinthFeedbackPlan.isReplay(core.mode)
        } else {
            mirror.replayAvailable = false
        }
        if case .replay(let level) = core.mode {
            mirror.replaying = true
            mirror.replayPosition = core.play.records.count
            mirror.replayLength = core.progress.solved[level]?.trace.count ?? 0
        } else {
            mirror.replaying = false
            mirror.replayPosition = 0
            mirror.replayLength = 0
        }
        if let key = hintKey, key != Self.hintKey(core) {
            hintKey = nil
            mirror.hintLevel = 0
            mirror.hintText = nil
        }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = core.failureExplanation?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        mirror.stars = core.progress.solved.mapValues(\.stars)
        mirror.shortest = core.certifiedShortest
        mirror.dials = play.dials
        mirror.stage = play.stage
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.allowance = play.level.allowance
        let snapshot = core.snapshot(time: 0)
        var text = "Lissajous Labyrinth level \(core.levelNumber). "
        for (index, dial) in LissajousLabyrinthDial.allCases.enumerated() {
            text += "\(Self.dialNames[index].prefix(1).uppercased() + Self.dialNames[index].dropFirst()) \(play.dials[dial]). "
        }
        text += "\(snapshot.visits.count) of \(play.level.checkpoints.count) checkpoints in order. "
        if let obstacle = snapshot.contactObstacle { text += "The path touches obstacle \(obstacle + 1). " }
        let selected = gestures.selectedDial
        text += "Dial \(Self.title(selected)) selected: \(mirror.candidate?.value ?? play.dials[selected]). "
        text += "Actions \(play.spent) of \(play.level.allowance). "
        switch play.stage {
        case .won:
            text += "The path is safe."
            if core.mode != .practice {
                let stars = LissajousLabyrinthProgress.stars(actions: play.spent, shortest: core.certifiedShortest)
                text += " \(stars) of 3 stars."
            }
        case .failed:
            text += "Out of actions. " + (core.failureExplanation?.text ?? "")
        default: break
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(LissajousLabyrinthControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
