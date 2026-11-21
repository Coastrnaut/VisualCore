// HueCompassPresenter — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-003, 004, 005, 007; clarifications Q2,
// Q4). Draws the adapter's immutable snapshot with `HueCompassCompassScene` at the host's quality tier (tier n is the
// catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the fog drift still under
// Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory warning releases the
// GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the
// kernel (renderer purity).
// Feature 334 (R02-G04-04) T-R02G0404-005 (FR-R02G0404-001 … 005; clarifications Q3, Q4): canvas touches go through
// `HueCompassGestureController` with the drawn view size and the last drawn snapshot: a released swipe sends one
// `compass.turn [steps]`, a tap on the hub one `compass.probe`; two fingers orbit the camera and a double tap on empty
// space or `resetView()` ("Reset view") returns to the authored view (presentation only: never in the digest or the
// snapshot). While a swipe previews a bearing the scene draws a ghost needle there and the description reads "Turning
// to bearing n of 96"; a refused action is shown with its reason.
// Feature 335 (R02-G04-05) T-R02G0405-005 (FR-R02G0405-001 … 005; clarifications Q1–Q5): the mirror carries the tutorial
// instruction, the hint revealed so far (`showHint(port:)` reveals the next of three levels for the current play; the
// hint level is presentation only and any change of the play — level, mode or play fingerprint — hides it), the failure
// explanation, the mode, the open levels with their stars and the goal (allowance and certified smallest probe count);
// `retry` starts the level again in its mode (probes and selections cannot be undone, so there is no Undo after a
// failure), and the daily level is chosen from the local calendar date read here (`playDaily(port:date:)`, sent as
// `mode.daily [year, month, day]`), never in the core.
// Feature 336 (R02-G04-06) T-R02G0406-006 (FR-R02G0406-001 … 006; clarifications Q1–Q5): the presenter routes
// `HueCompassFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route (`feedback`,
// `.shared` unless a test injects one), plans band picks with `picked(band:)` and refusals with `refused(code:)`, showing
// the same words in the panel; it keeps a feedback log, eases the scene's lights (`HueCompassLights`, 0.45 s fades under
// Reduce Flashing) and offers the ambient recipe to `HueCompassSound` at level openings, new clues and play ends.
#if os(iOS)
import Foundation
import HueCompassCore
import SwiftUI
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class HueCompassMirror {
    /// The compass bearing, 0 … 95.
    var bearing = 0
    /// The hue band under the needle, 0 … 23.
    var bandUnderNeedle = 0
    /// The band the picker holds for the next selection, 0 … 23 (presentation only).
    var pickedBand = 0
    /// The play's stage.
    var stage: HueCompassStage = .loading
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The units spent and the allowance.
    var spent = 0
    var allowance = 0
    /// The number of clues seen.
    var clueCount = 0
    /// The text of the last refused change, if any.
    var message: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 335).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 335).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 335).
    var failureText: String?
    /// The mode (feature 335).
    var mode: HueCompassMode = .campaign
    /// The highest open level and the stars of each won level (feature 335).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The certified smallest probe count of the current level (feature 335).
    var smallest = 0
    /// The summary element's words (feature 336): bearing, band, units and the last clue.
    var summary = ""
    /// Whether the ambient sound is on (feature 336; off by default).
    var soundOn = false
}

/// One entry of the tier log: the tier drawn and why it changed.
struct HueCompassTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Hue Compass.
@MainActor
final class HueCompassPresenter: ExperiencePresenter {
    typealias Core = HueCompassExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = HueCompassMirror()
    let scene = HueCompassCompassScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0403-004).
    private(set) var tierLog: [HueCompassTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: HueCompassSceneSnapshot?
    /// The gesture controller (feature 334): swipes, hub taps, orbit and the swipe preview.
    private(set) var gestures = HueCompassGestureController()
    /// The latest core described (feature 335): hints and retry read it.
    private(set) var latestCore: HueCompassExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 335).
    private var hintKey: String?
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 335).
    private(set) var dailyDate: DateComponents?
    /// The feedback route of announcements and haptics (feature 336; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every announced text, oldest first (feature 336; tests and diagnostics).
    private(set) var announcements: [String] = []
    /// Every routed feedback plan, oldest first (feature 336; tests and diagnostics).
    private(set) var feedbackLog: [HueCompassFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 336).
    private(set) var lights: HueCompassLights
    /// The frame time of the last draw, for easing the lights.
    private var lastFrameTime: Double?
    /// The fingerprint of the level (and mode copy) the lights belong to.
    private var lightsLevel: String?
    /// The ambient sound (feature 336).
    let sound: HueCompassSound

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        lights = HueCompassLights(reducedFlash: reduceFlashing)
        sound = HueCompassSound(recipe: HueCompassSoundRecipe.recipe(clue: nil, stage: .loading))
    }

    /// The tests' seam: before `setup`, replaces the glass program's fragment source with one that does not compile.
    func breakGlassShader() {
        scene.glassFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: HueCompassExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = HueCompassTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(HueCompassTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        // A new level (or mode) starts from its own lights: they settle at once, only changes within a play fade. A
        // frame time that does not advance (an off-screen still drawn at its own or the same time) is a separate
        // picture: it settles too, so a still always shows the state it was asked for.
        let level = "\(core.levelNumber)/\(core.mode)/\(core.play.level.fingerprint)"
        if let last = lastFrameTime, lightsLevel == level, frame.time > last {
            lights.step(toward: snapshot, elapsed: frame.time - last)
        } else {
            lights.settle(to: snapshot)
        }
        lightsLevel = level
        lastFrameTime = frame.time
        scene.lights = lights
        scene.orbit = gestures.orbit
        scene.previewBearing = gestures.previewBearing
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    // MARK: Touch controls (feature 334)

    /// The canvas gestures send turns and probes only.
    var gestureActions: Set<String> { ["compass.turn", "compass.probe"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(HueCompassExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller; a released swipe or a hub tap sends its one action.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let actions: [HueCompassGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        for action in actions {
            switch action {
            case .turn(let steps):
                send("compass.turn", [Double(steps)], port: port)
            case .probe:
                send("compass.probe", [], port: port)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
    }

    /// Drops a touch in progress (the shell suspends the experience): a gesture under way is abandoned without an
    /// action by starting a fresh controller, which forgets the fingers it held. The orbit is presentation only and
    /// never saved (clarification Q3), so the camera returns to the authored view with it.
    func cancelPointers() {
        gestures.cancel()
    }

    /// Returns the camera to the authored view ("Reset view").
    func resetView() {
        gestures.resetView()
    }

    /// Sends `control` with `values`; a refusal is shown and announced in words (feature 336).
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            let plan = HueCompassFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            route(plan)
        }
        return result
    }

    // MARK: Feedback and sound (feature 336)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: HueCompassFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind {
            feedback.announce(text, kind: kind)
            announcements.append(text)
        }
        feedbackLog.append(plan)
    }

    /// Sets the band the picker holds for the next selection (0 … 23) and announces it ("Band h picked.").
    func pickBand(_ band: Int) {
        let picked: Int = min(max(band, 0), HueCompassWheel.bands - 1)
        guard picked != mirror.pickedBand else { return }
        mirror.pickedBand = picked
        route(HueCompassFeedbackPlan.picked(band: picked))
    }

    /// The ambient recipe of `core`'s last clue and stage.
    static func recipe(_ core: HueCompassExperienceCore) -> AmbientLoopRecipe {
        HueCompassSoundRecipe.recipe(clue: core.play.clues.last, stage: core.play.stage)
    }

    /// Turns the ambient sound on or off; turning it on plays the recipe of the current clue and stage.
    func setSound(on: Bool) {
        if on, let core = latestCore { sound.offer(Self.recipe(core)) }
        sound.setWanted(on)
        mirror.soundOn = on
    }

    /// The controls view appeared (the loop may play).
    func controlsAppeared() { sound.setOnScreen(true) }

    /// The controls view disappeared (the loop stops).
    func controlsDisappeared() { sound.setOnScreen(false) }

    /// The scene became active or inactive.
    func sceneActive(_ active: Bool) { sound.setActive(active) }

    // MARK: Teaching and progression (feature 335)

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: HueCompassExperienceCore) -> String {
        "\(core.levelNumber)/\(core.mode)/\(core.play.fingerprint)"
    }

    /// Hides the hint shown.
    private func clearHint() {
        hintKey = nil
        mirror.hintLevel = 0
        mirror.hintText = nil
    }

    /// Reveals the next hint level (up to 3) for the current play; nothing (the hint hidden) when the play is not in
    /// stage `playing`. Hints never change the state: no action is sent.
    func showHint(port: ExperienceActionPort) {
        guard let core = latestCore else { return }
        let key: String = Self.hintKey(core)
        let next: Int = hintKey == key ? min(mirror.hintLevel + 1, 3) : 1
        guard let hint = core.hint(level: next) else {
            clearHint()
            return
        }
        hintKey = key
        mirror.hintLevel = next
        mirror.hintText = hint.text
    }

    /// Ends the tutorial of the current level.
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", [], port: port)
    }

    /// The action and values that start the current level again in its mode: `mode.practice` in practice, the daily
    /// date's `mode.daily` in daily mode, `level.select` of the level in campaign.
    func retryAction(date: DateComponents) -> (control: String, values: [Double]) {
        guard let core = latestCore else { return ("mode.campaign", []) }
        switch core.mode {
        case .practice: return ("mode.practice", [])
        case .daily: return ("mode.daily", Self.dateValues(dailyDate ?? date))
        case .campaign: return ("level.select", [Double(core.levelNumber)])
        }
    }

    /// Starts the current level again in its mode; in daily mode with the date that opened it (today's local date
    /// when none is known).
    @discardableResult
    func retry(port: ExperienceActionPort, date: DateComponents = HueCompassPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort, date: DateComponents = HueCompassPresenter.today()) -> ActionResult {
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

    func describe(_ core: HueCompassExperienceCore) -> String {
        if let previous = latestCore {
            route(HueCompassFeedbackPlan.after(old: previous, new: core))
            let opened = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            let clued = previous.play.clues != core.play.clues
            let ended = previous.play.stage != core.play.stage
            if opened || clued || ended { sound.offer(Self.recipe(core)) }
        } else {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(Self.recipe(core))
        }
        latestCore = core
        mirror.summary = HueCompassFeedbackPlan.summaryText(core: core)
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = core.failureExplanation?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (level, result) in core.progress.solved { stars[level] = result.stars }
        mirror.stars = stars
        mirror.smallest = core.certifiedSmallest
        let play = core.play
        let snapshot = core.snapshot(time: 0)
        let band = snapshot.band(of: snapshot.bearing)
        mirror.bearing = snapshot.bearing
        mirror.bandUnderNeedle = band
        mirror.stage = play.stage
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.allowance = play.level.allowance
        mirror.clueCount = snapshot.clues.count
        var text = "Hue Compass level \(core.levelNumber). "
        text += "The needle points to bearing \(snapshot.bearing) of 96, hue band \(band + 1) of 24. "
        let density: Int = snapshot.fog.indices.contains(snapshot.bearing) ? snapshot.fog[snapshot.bearing] : 0
        if let preview = gestures.previewBearing {
            text += "Turning to bearing \(preview) of 96. "
        }
        text += "Fog density here \(density) of 9. "
        if let clue = snapshot.clues.last {
            text += "Last clue at bearing \(clue.bearing): hue gap \(clue.hueGap), depth \(clue.depth). "
        }
        text += "\(snapshot.clues.count) clues seen. "
        if let selection = snapshot.selection {
            text += "Selected bearing \(selection.bearing), band \(selection.band + 1). "
        }
        text += "Units \(play.spent) of \(play.level.allowance). "
        switch play.stage {
        case .won:
            text += "The bearing and hue match."
            if core.mode != .practice {
                let stars: Int = HueCompassProgress.stars(units: play.spent, smallest: core.certifiedSmallest)
                text += " \(stars) of 3 stars."
            }
        case .failed:
            text += "The search failed. " + (core.failureExplanation?.text ?? "")
        default: break
        }
        if let target = snapshot.target { text += " The target was bearing \(target)." }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(HueCompassControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
