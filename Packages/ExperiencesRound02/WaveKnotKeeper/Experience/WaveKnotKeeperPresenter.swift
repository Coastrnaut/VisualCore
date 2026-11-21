// WaveKnotKeeperPresenter — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-003 … 005, 007; clarifications Q4,
// Q5). Draws the adapter's immutable snapshot with `WaveKnotKeeperRopeScene` at the host's quality tier (tier n is the
// catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the caustic pulses still
// under Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory warning releases
// the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the
// kernel (renderer purity, R2-G03-INV-10).
// Feature 324 (R02-G03-04) T-R02G0304-005 (FR-R02G0304-002 … 006): canvas touches go through
// `WaveKnotKeeperGestureController`: one finger on a handle selects it (`point.select`) and, dragged past the snap
// distance and released while playing, sends one `point.move`; two fingers orbit (presentation only); a double tap on
// empty space or `resetView()` returns to the authored view. The drag's candidate is drawn as an ember ghost handle;
// a refused move is shown with its reason.
// Feature 325 (R02-G03-05) T-R02G0305-005 (FR-R02G0305-001 … 005): the mirror carries the tutorial instruction, the hint
// revealed so far (`showHint(port:)` reveals the next of three levels for the current play and tells the core a hint
// was shown; any change of the play hides it), the failure explanation, the mode, the open levels with their stars and
// the goal (allowance and certified shortest); `retry` starts the level again in its mode, and the daily level is
// chosen from the local calendar date read here (`playDaily(port:date:)`), never in the core.
// Feature 326 (R02-G03-06) T-R02G0306-006 (FR-R02G0306-002 … 004, 006): after each described change the presenter
// routes `WaveKnotKeeperFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route
// (`feedback`, `.shared` unless a test injects one) and plans refusals with `refused(code:)`, showing the same words in
// the panel; it keeps a feedback log, eases the scene's lights (`WaveKnotKeeperLights`, 0.45 s fades under Reduce
// Flashing) and offers the ambient recipe to `WaveKnotKeeperSound` at level openings, summary changes and play ends.
#if os(iOS)
import Foundation
import SwiftUI
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import WaveKnotKeeperCore

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class WaveKnotKeeperMirror {
    /// The rope's point count; 0 before the first description.
    var pointCount = 0
    /// The selected point (presentation only).
    var selected = 0
    /// The play's stage.
    var stage: WaveKnotKeeperStage = .loading
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The moves spent.
    var spent = 0
    /// The move allowance.
    var allowance = 0
    /// The rope's crossings and writhe, and the target's.
    var crossings = 0
    var writhe = 0
    var targetCrossings = 0
    var targetWrithe = 0
    /// The text of the last refused change, if any.
    var message: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 325).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 325).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 325).
    var failureText: String?
    /// The mode (feature 325).
    var mode: WaveKnotKeeperMode = .campaign
    /// The highest open level and the stars of each solved level (feature 325).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The certified shortest solution length of the current level (feature 325).
    var shortest = 0
    /// Whether the ambient sound is on (feature 326; off by default).
    var soundOn = false
}

/// One entry of the tier log: the tier drawn and why it changed.
struct WaveKnotKeeperTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Wave Knot Keeper.
@MainActor
final class WaveKnotKeeperPresenter: ExperiencePresenter {
    typealias Core = WaveKnotKeeperExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = WaveKnotKeeperMirror()
    let scene = WaveKnotKeeperRopeScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0303-004).
    private(set) var tierLog: [WaveKnotKeeperTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: WaveKnotKeeperSceneSnapshot?
    /// The gesture controller (feature 324): arbitration, drags, orbit and selection.
    private(set) var gestures = WaveKnotKeeperGestureController()
    /// The latest core described (feature 325): hints and retry read it.
    private(set) var latestCore: WaveKnotKeeperExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 325).
    private var hintKey: String?
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 325).
    private(set) var dailyDate: DateComponents?
    /// The feedback route of announcements and haptics (feature 326; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every announced text, oldest first (feature 326; tests and diagnostics).
    private(set) var announcements: [String] = []
    /// Every routed feedback plan, oldest first (feature 326; tests and diagnostics).
    private(set) var feedbackLog: [WaveKnotKeeperFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 326).
    private(set) var lights: WaveKnotKeeperLights
    /// The frame time of the last draw, for easing the lights.
    private var lastFrameTime: Double?
    /// The fingerprint of the level (and mode copy) the lights belong to.
    private var lightsLevel: String?
    /// The ambient sound (feature 326).
    let sound: WaveKnotKeeperSound

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        lights = WaveKnotKeeperLights(reducedFlash: reduceFlashing)
        sound = WaveKnotKeeperSound(recipe: WaveKnotKeeperSoundRecipe.quiet)
    }

    /// The tests' seam: before `setup`, replaces the rope program's fragment source with one that does not compile.
    func breakRopeShader() {
        scene.ropeFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: WaveKnotKeeperExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = WaveKnotKeeperTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(WaveKnotKeeperTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        // A new level (or mode) starts from its own lights: they settle at once, only changes within a play fade. A
        // frame time that goes back (an off-screen still drawn at its own time) is a separate picture: it settles too.
        let level = core.play.level.fingerprint
        if let last = lastFrameTime, lightsLevel == level, frame.time >= last {
            lights.step(toward: snapshot, elapsed: frame.time - last)
        } else {
            lights.settle(to: snapshot)
        }
        lightsLevel = level
        lastFrameTime = frame.time
        scene.lights = lights
        scene.orbit = gestures.orbit
        scene.preview = gestures.preview.flatMap { Self.ghost($0, snapshot: snapshot) }
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    // MARK: Touch controls (feature 324)

    /// The canvas gestures send kernel moves and selections only.
    var gestureActions: Set<String> { ["point.move", "point.select"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(WaveKnotKeeperExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller; a selection or a finished drag sends its one action.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        if let action = gestures.handle(event, viewSize: viewSize, snapshot: snapshot) {
            send(action.control, action.values, port: port)
        }
    }

    /// Drops a touch in progress (the shell suspends the experience): the drag ends without a move.
    func cancelPointers() {
        gestures.cancel()
    }

    /// Returns the camera to the authored view ("Reset view").
    func resetView() {
        gestures.resetOrbit()
    }

    /// Sends `control` with `values`; a refusal is shown with its reason.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            let plan = WaveKnotKeeperFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            route(plan)
        }
        return result
    }

    // MARK: Feedback and sound (feature 326)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: WaveKnotKeeperFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind {
            feedback.announce(text, kind: kind)
            announcements.append(text)
        }
        feedbackLog.append(plan)
    }

    /// The ambient recipe of `core`'s summary, target and stage.
    static func recipe(_ core: WaveKnotKeeperExperienceCore) -> AmbientLoopRecipe {
        WaveKnotKeeperSoundRecipe.recipe(summary: core.play.summary, target: core.play.level.target,
                                         stage: core.play.stage)
    }

    /// Turns the ambient sound on or off; turning it on plays the recipe of the current rope and stage.
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

    /// The rope point a previewed `point.move` would reach, in kernel units; nil for another action or a bad value.
    static func ghost(_ action: ScriptedAction, snapshot: WaveKnotKeeperSceneSnapshot) -> WaveKnotKeeperPoint? {
        guard action.control == WaveKnotKeeperGestureController.moveControl, action.values.count == 2 else { return nil }
        let point = Int(action.values[0]), index = Int(action.values[1])
        guard snapshot.points.indices.contains(point), WaveKnotKeeperDirection.allCases.indices.contains(index) else {
            return nil
        }
        return snapshot.points[point].moved(WaveKnotKeeperDirection.allCases[index])
    }

    // MARK: Teaching and progression (feature 325)

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: WaveKnotKeeperExperienceCore) -> String {
        "\(core.levelNumber)/\(core.mode)/\(core.play.fingerprint)"
    }

    /// Reveals the next hint level (up to 3) for the current play and tells the core that a hint was shown
    /// (`tutorial.hint`, which only advances the tutorial); nothing when the play has ended.
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
        if core.tutorial == .signature { _ = port.send("tutorial.hint", []) }
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
    func retry(port: ExperienceActionPort, date: DateComponents = WaveKnotKeeperPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort, date: DateComponents = WaveKnotKeeperPresenter.today()) -> ActionResult {
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

    func describe(_ core: WaveKnotKeeperExperienceCore) -> String {
        if let previous = latestCore {
            route(WaveKnotKeeperFeedbackPlan.after(old: previous, new: core))
            let opened = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            let changed = previous.play.summary != core.play.summary
            let ended = previous.play.stage != core.play.stage
            if opened || changed || ended { sound.offer(Self.recipe(core)) }
        } else {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(Self.recipe(core))
        }
        latestCore = core
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
        let play = core.play
        let snapshot = core.snapshot(time: 0)
        mirror.pointCount = play.points.count
        mirror.selected = snapshot.selected ?? 0
        mirror.stage = play.stage
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.allowance = play.level.allowance
        mirror.crossings = snapshot.summary.crossings
        mirror.writhe = snapshot.summary.writhe
        mirror.targetCrossings = play.level.target.crossings
        mirror.targetWrithe = play.level.target.writhe
        var text = "Wave Knot Keeper level \(core.levelNumber). "
        text += "A rope of \(play.points.count) points with \(snapshot.summary.crossings) crossings, "
        text += "writhe \(snapshot.summary.writhe). "
        text += "Target: \(play.level.target.crossings) crossings, writhe \(play.level.target.writhe). "
        if snapshot.summary.degenerate { text += "Two strands overlap in the view. " }
        if let selected = snapshot.selected { text += "Point \(selected + 1) selected. " }
        text += "Moves \(play.spent) of \(play.level.allowance). "
        switch play.stage {
        case .won:
            text += "The knot matches."
            if core.mode != .practice {
                let stars = WaveKnotKeeperProgress.stars(moves: play.spent, shortest: core.certifiedShortest)
                text += " \(stars) of 3 stars."
            }
        case .failed:
            text += "Out of moves. " + (core.failureExplanation?.text ?? "")
        default: break
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(WaveKnotKeeperControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
