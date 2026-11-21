// AuroraLoomPresenter — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-003 … 005, 007; clarifications Q4, Q5).
// Draws the adapter's immutable snapshot with `AuroraLoomRibbonScene` at the host's quality tier (tier n is the
// catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the silk still under
// Reduce Motion (the snapshot time stays at 0 and the wave and shimmer stop) and caps the glow under Reduce Flashing.
// A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`:
// no drawing result reaches the kernel (renderer purity, R2-G01-INV-10). Feature 304 (R02-G01-04) T-R02G0104-004 routes
// canvas touches through `AuroraLoomGestureController`: one finger drags an anchor or a dial and sends one `ribbon.move` on
// release, two fingers orbit the camera (presentation only), and the selection and the drag preview are mirrored for the
// scene, the description and the controls. Feature 305 (R02-G01-05) T-R02G0105-005 (FR-R02G0105-001 … 005): the mirror
// carries the tutorial instruction, the hint revealed so far (`showHint()` reveals the next of three levels for the
// current play; a change of the play hides it), the failure explanation with undo and retry, the mode, the open levels,
// the goal (allowance and certified shortest) and the stars; the daily level is chosen from the local calendar date read
// here (`playDaily(port:date:)`), never in the core. Feature 306 (R02-G01-06) T-R02G0106-006 (FR-R02G0106-001 … 006):
// after each described change the presenter routes `AuroraLoomFeedbackPlan.after(old:new:)` (an announcement and a
// haptic) through its feedback route (`ExperienceFeedback.shared` unless a test injects one), plans refusals with
// `refused(code:)` where it sends an action, keeps a feedback log, eases the scene's lights (`AuroraLoomLights`, 0.45 s
// fades under Reduce Flashing), offers the ambient recipe to `AuroraLoomSound` at level openings and play ends, and
// exposes `adjust(ribbon:control:by:port:)`, the one operation the steppers and their accessibility actions use.
// Feature 307 (R02-G01-07) T-R02G0107-005 (FR-R02G0107-003, 004): the mirror carries whether a replay is available or
// running with its position; `startReplay`, `stepReplay` and `stopReplay` send the replay actions; the first described
// core whose restore dropped results announces them once (`AuroraLoomFeedbackPlan.dropped(count:)`).
// Feature 309 (R02-G01-09) T-R02G0109-003 (FR-R02G0109-008; spec Amendment): the panel's steppers set pending steps
// (`stepPending`, announced, no move); `applyPending` commits each pending change as one move (ribbon order, wave
// before phase), stops at the first refusal and drops the rest; `clearPending` drops them; a change of the level, mode
// or play from elsewhere drops them too.
#if os(iOS)
import AuroraLoomCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// What the controls show: the latest snapshot the presenter saw.
@MainActor
@Observable
final class AuroraLoomMirror {
    /// The six steps, the stage and the level number; nil before the first description.
    var steps: AuroraLoomSteps?
    var stage: AuroraLoomStage = .loading
    var levelNumber = 1
    var spent = 0
    var allowance = 0
    /// The selected ribbon (0 … 2).
    var selectedRibbon = 0
    /// The step a drag would set, while dragging.
    var preview: AuroraLoomMove?
    /// The text of the last refused move, if any.
    var message: String?
    /// The tutorial instruction for the current step; nil when the tutorial is done (feature 305).
    var instruction: String?
    /// The hint level revealed for the current play (0 = none, 1 … 3).
    var hintLevel = 0
    /// The text of the revealed hint; nil when none is revealed or the play has ended.
    var hintText: String?
    /// The failure explanation while the play has failed; nil otherwise.
    var failureText: String?
    /// The mode: campaign, practice or the daily level.
    var mode: AuroraLoomMode = .campaign
    /// The highest open level (levels 1 … frontier are open).
    var frontier = 1
    /// The certified shortest solution of the level (the best possible).
    var shortest = 0
    /// The stars earned on this level so far; nil when it is not solved yet.
    var stars: Int?
    /// The band of the level (1 … 5, 20 levels each).
    var band = 1
    /// Whether the person turned the ambient sound on (off by default; feature 306).
    var soundOn = false
    /// Whether the level has a stored verified winning trace to replay and no replay is running (feature 307).
    var replayAvailable = false
    /// Whether a replay is running (feature 307).
    var replaying = false
    /// The replay moves played so far (feature 307).
    var replayPosition = 0
    /// The moves of the stored trace of the level (feature 307); 0 when none is stored.
    var replayLength = 0
    /// The steps the panel's steppers set but did not apply yet (feature 309); nil when nothing is pending. Controls
    /// without a pending change hold the current step.
    var pending: AuroraLoomSteps?
}

/// One entry of the feedback log (feature 306): the announcement and haptic planned for a change or refusal.
struct AuroraLoomFeedbackEntry: Equatable {
    let text: String?
    let kind: AnnouncementKind?
    let haptic: HapticKind?
}

/// One entry of the tier log: the tier drawn and why it changed.
struct AuroraLoomTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Aurora Loom.
@MainActor
final class AuroraLoomPresenter: ExperiencePresenter {
    typealias Core = AuroraLoomExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = AuroraLoomMirror()
    let scene = AuroraLoomRibbonScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0103-004).
    private(set) var tierLog: [AuroraLoomTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: AuroraLoomSceneSnapshot?
    /// The touch controls: arbitration, drags, orbit and selection.
    private(set) var gestures = AuroraLoomGestureController()
    /// The steps and whether the level is playing, from the latest core the presenter saw.
    private var latest: (steps: AuroraLoomSteps, playing: Bool)?
    /// The latest core the presenter described (hints are computed from it).
    private(set) var latestCore: AuroraLoomExperienceCore?
    /// The level and play fingerprint the revealed hint belongs to; a different play hides the hint.
    private var hintKey: String?
    /// The route haptics and announcements go through (tests inject recording sinks; feature 306).
    var feedback: ExperienceFeedback = .shared
    /// Every feedback plan routed, oldest first (feature 306; tests and diagnostics).
    private(set) var feedbackLog: [AuroraLoomFeedbackEntry] = []
    /// The core described before the latest one (feature 306).
    private var previousCore: AuroraLoomExperienceCore?
    /// The eased light levels drawn by the scene (feature 306).
    private(set) var lights: AuroraLoomLights
    /// The frame time of the last drawn frame; nil before the first.
    private var lastFrameTime: Double?
    /// The ambient loop's policy (feature 306).
    let sound: AuroraLoomSound
    /// Whether the dropped-results announcement was made (once per presenter; feature 307).
    private(set) var droppedAnnounced = false
    /// True while `applyPending` sends its moves, so the described changes do not count as outside changes.
    private var applying = false

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        lights = AuroraLoomLights(reducedFlash: reduceFlashing)
        sound = AuroraLoomSound(recipe: AuroraLoomSoundRecipe.recipe(
            steps: AuroraLoomSteps(wave: [0, 0, 0], phase: [0, 0, 0]), stage: .playing))
    }

    /// The tests' seam: before `setup`, replaces the ribbon program's fragment source with one that does not compile.
    func breakRibbonShader() {
        scene.ribbonFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: AuroraLoomExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = AuroraLoomTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(AuroraLoomTierChange(tier: drawn.index, reason: reason))
        }
        let ticks = reduceMotion ? 0 : frame.time * 120
        let snapshot = core.snapshot(time: ticks)
        lastSnapshot = snapshot
        if let last = lastFrameTime {
            lights.step(toward: snapshot, elapsed: frame.time - last)
        } else {
            lights.settle(to: snapshot)
        }
        lastFrameTime = frame.time
        scene.lights = lights
        latest = (core.play.steps, core.play.stage == .playing)
        scene.orbit = gestures.orbit
        scene.selectedRibbon = gestures.selectedRibbon
        scene.preview = gestures.preview
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    // MARK: Touch controls

    /// The canvas gestures send kernel moves only.
    var gestureActions: Set<String> { ["ribbon.move"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(AuroraLoomExperienceCore.actionIDs) }

    /// Routes a touch through the gesture controller; a finished drag that changed a step sends one `ribbon.move`.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let latest else { return }
        let move = gestures.handle(event, viewSize: viewSize, steps: latest.steps, playing: latest.playing)
        mirror.selectedRibbon = gestures.selectedRibbon
        mirror.preview = gestures.preview
        guard let move else { return }
        let control: Double = move.control == .wave ? 0 : 1
        let result = send("ribbon.move", [Double(move.ribbon), control, Double(move.step)], port: port)
        mirror.message = result.isAccepted ? nil : "That move was refused: \(result.code)"
    }

    /// Ends every touch without a move.
    func cancelPointers() {
        gestures.cancel()
        mirror.preview = nil
    }

    /// Returns the camera to the authored pose.
    func resetView() {
        gestures.resetOrbit()
    }

    /// Selects `ribbon` (the steppers call this).
    func select(ribbon: Int) {
        gestures.select(ribbon: ribbon)
        mirror.selectedRibbon = gestures.selectedRibbon
    }

    // MARK: Teaching (feature 305)

    /// The key of a play for the revealed hint: the level number and the play's fingerprint.
    private static func hintKey(_ core: AuroraLoomExperienceCore) -> String {
        "\(core.levelNumber)/\(core.play.fingerprint)"
    }

    /// Reveals the next hint level (up to 3) for the current play; nothing when the play has ended. Never changes
    /// the state.
    func showHint() {
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
    }

    /// The action and values that start the current level again in its mode: `mode.practice` in practice, the daily
    /// date's `mode.daily` in daily mode, `level.select` of the level in campaign, `replay.start` of the level in
    /// replay.
    func retryAction(date: DateComponents) -> (control: String, values: [Double]) {
        guard let core = latestCore else { return ("mode.campaign", []) }
        switch core.mode {
        case .practice: return ("mode.practice", [])
        case .daily: return ("mode.daily", Self.dateValues(date))
        case .campaign: return ("level.select", [Double(core.levelNumber)])
        case .replay(let level): return ("replay.start", [Double(level)])
        }
    }

    /// Starts the current level again in its mode (see ``retryAction(date:)``), with today's local date in daily mode.
    @discardableResult
    func retry(port: ExperienceActionPort, date: DateComponents = AuroraLoomPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort, date: DateComponents = AuroraLoomPresenter.today()) -> ActionResult {
        send("mode.daily", Self.dateValues(date), port: port)
    }

    /// The local calendar date now, in the user's calendar converted to Gregorian year, month and day.
    static func today() -> DateComponents {
        Calendar(identifier: .gregorian).dateComponents(in: .current, from: Date())
    }

    /// The values of `mode.daily` for `date`: year, month, day (0 for a missing part, which the core refuses).
    static func dateValues(_ date: DateComponents) -> [Double] {
        [Double(date.year ?? 0), Double(date.month ?? 0), Double(date.day ?? 0)]
    }

    // MARK: Feedback, sound and adjustment (feature 306)

    /// Sends `control` with `values` through `port`; a refusal is announced and felt (`AuroraLoomFeedbackPlan.refused`).
    @discardableResult
    func send(_ control: String, _ values: [Double] = [], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if !result.isAccepted { route(AuroraLoomFeedbackPlan.refused(code: result.code)) }
        return result
    }

    /// Changes `ribbon`'s `control` (0 = wave, 1 = phase) by `delta` steps, wrapping 0 … 15, as one kernel move — the
    /// one operation the steppers and their accessibility increment and decrement use.
    @discardableResult
    func adjust(ribbon: Int, control: Int, by delta: Int, port: ExperienceActionPort) -> ActionResult? {
        guard let core = latestCore, (0..<3).contains(ribbon) else { return nil }
        select(ribbon: ribbon)
        let current = control == 0 ? core.play.steps.wave[ribbon] : core.play.steps.phase[ribbon]
        let step = ((current + delta) % 16 + 16) % 16
        return send("ribbon.move", [Double(ribbon), Double(control), Double(step)], port: port)
    }

    /// Steps the pending value of `ribbon`'s `control` (0 = wave, 1 = phase) by `delta`, wrapping 0 … 15, starting from
    /// the pending value or the current step; announces "Ribbon r wave s pending. Apply to move." and sends no action
    /// (feature 309).
    func stepPending(ribbon: Int, control: Int, by delta: Int) {
        guard let core = latestCore, (0..<3).contains(ribbon), (0...1).contains(control) else { return }
        select(ribbon: ribbon)
        var pending = mirror.pending ?? core.play.steps
        let current = control == 0 ? pending.wave[ribbon] : pending.phase[ribbon]
        let step = ((current + delta) % 16 + 16) % 16
        if control == 0 { pending.wave[ribbon] = step } else { pending.phase[ribbon] = step }
        mirror.pending = pending
        let name = control == 0 ? "wave" : "phase"
        route(AuroraLoomFeedbackPlan(text: "Ribbon \(ribbon + 1) \(name) \(step) pending. Apply to move.", kind: .state,
                                     haptic: nil))
    }

    /// Sends one `ribbon.move` per control whose pending step differs from the current one, ribbon order, wave before
    /// phase; stops at the first refusal (announced by `send`) and drops every remaining pending step; clears the pending
    /// steps in every case. Returns the results in order (feature 309).
    @discardableResult
    func applyPending(port: ExperienceActionPort) -> [ActionResult] {
        guard let pending = mirror.pending, let core = latestCore else { return [] }
        applying = true
        defer {
            applying = false
            mirror.pending = nil
        }
        let current = core.play.steps
        var results: [ActionResult] = []
        for ribbon in 0..<3 {
            for control in 0..<2 {
                let target = control == 0 ? pending.wave[ribbon] : pending.phase[ribbon]
                let now = control == 0 ? current.wave[ribbon] : current.phase[ribbon]
                guard target != now else { continue }
                let result = send("ribbon.move", [Double(ribbon), Double(control), Double(target)], port: port)
                results.append(result)
                if !result.isAccepted { return results }
            }
        }
        return results
    }

    /// Drops the pending steps; sends nothing (feature 309).
    func clearPending() {
        mirror.pending = nil
    }

    /// Starts the replay of the current level's stored winning moves (`replay.start`; feature 307).
    @discardableResult
    func startReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.start", [Double(mirror.levelNumber)], port: port)
    }

    /// Plays the next move of the running replay (`replay.step`).
    @discardableResult
    func stepReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.step", port: port)
    }

    /// Stops the running replay and returns to the campaign (`replay.stop`).
    @discardableResult
    func stopReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.stop", port: port)
    }

    /// Plays `plan` through the feedback route and logs it; an empty plan does nothing.
    func route(_ plan: AuroraLoomFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(AuroraLoomFeedbackEntry(text: plan.text, kind: plan.kind, haptic: plan.haptic))
    }

    /// Turns the ambient sound on or off; turning it on plays the recipe of the current steps and stage.
    func setSound(on: Bool) {
        if on, let core = latestCore {
            sound.offer(AuroraLoomSoundRecipe.recipe(steps: core.play.steps, stage: core.play.stage))
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

    func describe(_ core: AuroraLoomExperienceCore) -> String {
        let play = core.play
        if !applying, mirror.pending != nil, let previous = previousCore,
           previous.levelNumber != core.levelNumber || previous.mode != core.mode
            || previous.play.records != core.play.records {
            mirror.pending = nil
        }
        if !droppedAnnounced && core.reconciliationDropped > 0 {
            droppedAnnounced = true
            route(AuroraLoomFeedbackPlan.dropped(count: core.reconciliationDropped))
        }
        if let previous = previousCore {
            route(AuroraLoomFeedbackPlan.after(old: previous, new: core))
            let opened = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            let ended = previous.play.stage != core.play.stage && (core.play.stage == .won || core.play.stage == .failed)
            if opened || ended {
                sound.offer(AuroraLoomSoundRecipe.recipe(steps: play.steps, stage: play.stage))
            }
        } else {
            sound.offer(AuroraLoomSoundRecipe.recipe(steps: play.steps, stage: play.stage))
        }
        previousCore = core
        latestCore = core
        mirror.steps = play.steps
        mirror.stage = play.stage
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.allowance = play.level.allowance
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = core.failureExplanation?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        mirror.shortest = core.certifiedShortest
        mirror.stars = core.progress.solved[core.levelNumber]?.stars
        mirror.band = AuroraLoomProgress.band(of: core.levelNumber)
        var replayLevel = core.levelNumber
        if case .replay(let level) = core.mode {
            replayLevel = level
            mirror.replaying = true
        } else {
            mirror.replaying = false
        }
        let stored = core.progress.solved[replayLevel]
        let traced = stored?.verified == true && !(stored?.trace.isEmpty ?? true)
        mirror.replayLength = traced ? (stored?.trace.count ?? 0) : 0
        mirror.replayPosition = mirror.replaying ? play.spent : 0
        mirror.replayAvailable = traced && !mirror.replaying
        if hintKey != Self.hintKey(core) || play.stage != .playing {
            hintKey = nil
            mirror.hintLevel = 0
            mirror.hintText = nil
        }
        let snapshot = core.snapshot(time: 0)
        var met = 0
        for ribbon in 0..<3 { for gate in 0..<4 where snapshot.lit(ribbon: ribbon, gate: gate) { met += 1 } }
        var text = "Aurora Loom level \(core.levelNumber), band \(mirror.band). "
        switch core.mode {
        case .campaign: break
        case .practice: text += "Practice. "
        case .daily: text += "Daily level. "
        case .replay: text += "Replay, move \(mirror.replayPosition) of \(mirror.replayLength). "
        }
        if let instruction = mirror.instruction { text += instruction + " " }
        for ribbon in 0..<3 {
            text += "Ribbon \(ribbon + 1): wave \(play.steps.wave[ribbon]), phase \(play.steps.phase[ribbon]). "
        }
        text += "\(met) of 12 gate crossings in harmony. Moves \(play.spent) of \(play.level.allowance); "
        text += "best possible \(core.certifiedShortest). "
        let selected = gestures.selectedRibbon
        text += "Ribbon \(selected + 1) selected: wave \(play.steps.wave[selected]), phase \(play.steps.phase[selected]). "
        if let preview = gestures.preview {
            text += "Dragging ribbon \(preview.ribbon + 1) \(preview.control == .wave ? "wave" : "phase") to \(preview.step). "
        }
        if let hint = mirror.hintText { text += "Hint: \(hint) " }
        switch play.stage {
        case .won:
            text += "The loom is in harmony."
            if let stars = mirror.stars { text += " \(stars) of 3 stars." }
        case .failed:
            text += "Out of moves. " + (mirror.failureText ?? "")
        default: break
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AuroraLoomControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
