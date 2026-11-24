// MoonlitMechanismPresenter — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-003, 004, 005, 007;
// clarifications Q2, Q4, Q5). Draws the adapter's immutable snapshot with `MoonlitMechanismClockworkScene` at the
// host's quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`),
// keeps a log of every tier change with its reason, draws the gears at the set-up phases of the shown key frame without
// a turning preview under Reduce Motion (presentation time 0), and caps the glow under Reduce Flashing. The
// presentation time handed to the snapshot is the seconds since the play last changed: the presenter notes the frame
// time whenever the level, the phases, the lamp height, the actions spent, the stage, the failure or the shown key
// frame change. The panel's chosen gear lives in the mirror as presentation state: a level opens with gear 1 chosen, clamped
// to the level's gears; it never reaches the kernel except through the declared `gear.reseat` control. The shown key
// frame is the adapter's (`frame.show`), read from the core. A refused action is shown in words. A memory warning
// releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result
// reaches the kernel (renderer purity). Its probes (two backdrop corners) let the verification runner check a frame.
// Feature 435 (R02-G14-05) T-R02G1405-005 (FR-R02G1405-001 … 005; clarifications Q1–Q5): the mirror carries the
// tutorial instruction, the hint revealed so far (`showHint()` reveals the next of three levels; the bounded search
// runs off the main actor, a stale search owns nothing, and any change of the play hides it), the failure explanation
// (`explanation`; `failureText` stays the short status line), the mode, the open levels with their bands and stars and
// the goal (the certified witness's action count); `retry` starts the level again in its mode, `undoAction` takes back
// the last action, and the daily level is chosen from the local calendar date read here (`playDaily(port:date:)`),
// never by the core. A refused `level.next` before a win (`r02-g14.locked`) and an impossible date (`r02-g14.date`)
// read in words.
// Feature 436 (R02-G14-06) T-R02G1406-005 (FR-R02G1406-001 … 006; clarifications Q1 … Q5): the presenter routes
// `MoonlitMechanismFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route (`feedback`,
// injectable; the shared `ExperienceFeedback` by default) and keeps a feedback log (`feedbackLog`); a gear drag's turns
// are routed once, from the core before the first turn to the core after the last; refusals are shown and announced in
// words (`refused(code:)`; the panel shows exactly the plan's text), and a revealed hint is announced as `state`.
// Choosing a gear, showing a key frame, the pending drag texts and orbit are not announced (the gear and key frame
// speak their values). The scene's lights (`MoonlitMechanismLights`: the glow and the won brightening of the wall) step
// toward the drawn snapshot every frame by the frame clock's elapsed time (0.15 s fades, 0.45 s under Reduce Flashing;
// the first frame settles them), so fades finish under Reduce Motion too, where the presentation time is held at 0. The
// ambient loop (`MoonlitMechanismSound`) is offered the recipe of the actions left, the covered quarters and the stage
// when the first state is described, when a level or mode opens and when that recipe changes; choosing a gear plays its
// audition (`MoonlitMechanismAudition.of(_:gear:)`) when the sound is on, on screen and active. The mirror carries the
// summary element's text (`MoonlitMechanismFeedbackPlan.summaryText(core:gear:)`) and the sound choice (off by default).
// Presentation only.
#if os(iOS)
import Foundation
import MoonlitMechanismCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreAudioDSP

/// What the controls show and choose: the latest state the presenter described, the shown key frame and the panel's
/// chosen gear.
@MainActor
@Observable
final class MoonlitMechanismMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions left.
    var actionsLeft = 0
    /// The action budget.
    var budget = 0
    /// A one-line status: "Ready", "Playing", "Won" or "Failed: " and the failure in words (the progress has its
    /// own line, ``measureLabel``).
    var status = ""
    /// The failure in words, if the play failed.
    var failureText: String?
    /// The progress in words (the kernel's run report of the current set-up, actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen gear (0-based; gear 0 is the driver).
    var gear = MoonlitMechanismExperienceCore.openingGear
    /// The key frame the core shows (0-based).
    var shownFrame = MoonlitMechanismExperienceCore.openingFrame
    /// The play the choice is clamped against (a copy; never sent anywhere).
    var play: MoonlitMechanismPlay?
    /// The text of the last refused change, if any.
    var message: String?
    /// The pending turn or lamp steps of a canvas drag in words (feature 434), nil when no drag is pending.
    var pending: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 435).
    var instruction: String?
    /// The hint level revealed (0 … 3; 0 while no hint is shown) (feature 435).
    var hintLevel = 0
    /// The text of the hint revealed, or ``MoonlitMechanismPresenter/searchingText`` while its search runs (feature 435).
    var hintText: String?
    /// The failure explanation (the failing action, its cause and the advice), nil without a failure (feature 435).
    var explanation: String?
    /// The mode (feature 435).
    var mode: MoonlitMechanismMode = .campaign
    /// The highest open level (feature 435).
    var frontier = 1
    /// The stars of each won level, by level number (feature 435).
    var stars: [Int: Int] = [:]
    /// The certified witness's action count of the current level (its turns, re-seats and lamp steps plus the run;
    /// the goal, feature 435).
    var certifiedActions = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen) (feature 435).
    var pickedLevel = 1
    /// The summary element's text (feature 436): `MoonlitMechanismFeedbackPlan.summaryText(core:gear:)` of the latest
    /// core and the chosen gear.
    var summary = ""
    /// Whether the sound is on (feature 436; off by default; presentation only).
    var soundOn = false

    /// The goal and the level's difficulty band (of the five bands of 20), with its best stars when won (feature 435).
    var goalLabel: String {
        let band: Int = MoonlitMechanismProgress.band(of: levelNumber)
        var text = "Goal: cast every required key frame spending \(certifiedActions) actions; band \(band) of 5"
        if let best = stars[levelNumber] { text += "; best \(best) of 3 stars" }
        return text
    }

    /// The number of gears of the followed level (2 while no play is followed, so gear 1 exists).
    var gearCount: Int { max(play?.level.gears.count ?? 2, 1) }
    /// The number of key frames of the followed level (1 while no play is followed).
    var frameCount: Int { max(play?.level.keyFrames.count ?? 1, 1) }
    /// The chosen gear in words.
    var gearLabel: String { gear == 0 ? "gear 0 (driver)" : "gear \(gear)" }
    /// The chosen gear in words with its teeth and current phase, if a play is followed.
    var gearDetail: String {
        guard let play, gear >= 0, gear < play.level.gears.count, gear < play.phases.count else { return gearLabel }
        return play.level.gearName(gear, phase: play.phases[gear])
    }
    /// The lamp in words, if a play is followed.
    var lampLabel: String {
        guard let play else { return "lamp" }
        return play.level.lampName(play.height)
    }
    /// The shown key frame in words: its number, whether it is required and its covered cells.
    var frameLabel: String {
        guard let play, shownFrame >= 0, shownFrame < play.level.keyFrames.count,
              shownFrame < play.report.frames.count else { return "key frame \(shownFrame)" }
        let frame = play.report.frames[shownFrame]
        let required: String = play.level.keyFrames[shownFrame].required ? "required" : "not required"
        return "key frame \(shownFrame) of \(play.level.keyFrames.count), \(required), "
            + "\(frame.covered) of \(frame.covered + frame.missing) covered"
    }

    /// Moves the chosen gear by `delta`, clamped to the level's gears.
    func stepGear(_ delta: Int) { gear = clampedGear(gear + delta) }

    /// `value` clamped to the gears of the followed level.
    func clampedGear(_ value: Int) -> Int { min(max(value, 0), gearCount - 1) }

    /// `value` clamped to the key frames of the followed level.
    func clampedFrame(_ value: Int) -> Int { min(max(value, 0), frameCount - 1) }

    /// Takes the new `play` and shown key frame: a new level chooses gear 1; otherwise the choice is clamped.
    func follow(_ play: MoonlitMechanismPlay, shownFrame: Int) {
        let changedLevel: Bool = self.play?.level.id != play.level.id
        self.play = play
        self.shownFrame = shownFrame
        gear = clampedGear(changedLevel ? MoonlitMechanismExperienceCore.openingGear : gear)
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: MoonlitMechanismFailure?) -> String? {
        switch failure {
        case let .jammed(child)?: "Gear \(child) jams against its parent."
        case let .forbidden(frame, cell)?: "Key frame \(frame) shadows forbidden cell \(cell)."
        case let .missing(frame, count)?:
            "Key frame \(frame) misses \(count == 1 ? "1 target cell" : "\(count) target cells")."
        case let .stray(frame, count)?:
            "Key frame \(frame) casts \(count == 1 ? "1 stray cell" : "\(count) stray cells")."
        case let .budget(index)?: "The budget ran out at action \(index + 1)."
        case nil: nil
        }
    }

    /// The engine's prefix on a kernel refusal's code (`action.rule.` before the kernel's `r02-g14.*` code).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix`` (feature 434: codes are read with or without it).
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``. Since feature 436 it
    /// forwards to `MoonlitMechanismFeedbackPlan.refusalText(code:)` (clarification Q1's sentences, e.g. "That change is
    /// not allowed for this machine.").
    static func refusalText(code: String) -> String {
        MoonlitMechanismFeedbackPlan.refusalText(code: code)
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct MoonlitMechanismTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Moonlit Mechanism.
@MainActor
final class MoonlitMechanismPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = MoonlitMechanismExperienceCore

    /// Whether the gears are drawn without a turning preview at presentation time 0 (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show and choose.
    let mirror = MoonlitMechanismMirror()
    /// The GL scene.
    let scene = MoonlitMechanismClockworkScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1403-004).
    private(set) var tierLog: [MoonlitMechanismTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: MoonlitMechanismSceneSnapshot?
    /// The gesture controller (feature 434): gear drags, lamp drags, taps, double taps, orbit.
    private(set) var gestures = MoonlitMechanismGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability, feature 434).
    private(set) var refusalLog: [String] = []
    /// How many refusal codes ``refusalLog`` keeps.
    static let refusalLogLimit = 64
    /// The latest core described (feature 435): hints and retry read it.
    private(set) var latestCore: MoonlitMechanismExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 435).
    private var hintKey: String?
    /// The hints searched for a play, by that play's key: one search per play, every level from it (feature 435).
    private var hintCache: (key: String, hints: [MoonlitMechanismHint?])?
    /// The search under way, off the main actor, for the play of ``hintKey`` (feature 435).
    private(set) var hintSearch: Task<Void, Never>?
    /// What the hint line shows while the search runs (feature 435).
    static let searchingText = "Finding a hint…"
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 435).
    private(set) var dailyDate: DateComponents?

    /// What restarts the presentation clock: the play's level, phases, lamp, actions spent, stage, failure and the
    /// shown key frame.
    private struct PlayKey: Equatable {
        let levelNumber: Int
        let phases: [Int]
        let height: Int
        let actionsSpent: Int
        let stage: MoonlitMechanismStage
        let failure: MoonlitMechanismFailure?
        let shownFrame: Int
    }

    /// The play last seen and the frame time it was first drawn (the presentation clock starts there).
    private var playKey: PlayKey?
    private var playStart: Double = 0

    /// The feedback route of announcements and haptics (feature 436; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first (feature 436; tests and diagnostics).
    private(set) var feedbackLog: [MoonlitMechanismFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 436).
    private(set) var lights: MoonlitMechanismLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient loop and the chosen gear's audition (feature 436).
    let sound: MoonlitMechanismSound
    /// While a gear drag's turns are sent, feedback waits so the drag is announced once (feature 436).
    private var holdingFeedback = false

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        lights = MoonlitMechanismLights(reducedFlash: reduceFlashing)
        sound = MoonlitMechanismSound(recipe: MoonlitMechanismSoundRecipe.recipe(rootStep: 0, quarters: 0,
                                                                                 stage: .loading))
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the clockwork program's fragment source with one that does not
    /// compile.
    func breakClockworkShader() {
        scene.clockworkFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// Records the registry and the aspect.
    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    /// Follows the new drawable size.
    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    /// Follows `core`'s play and shown key frame in the mirror when they changed.
    private func follow(_ core: MoonlitMechanismExperienceCore) {
        if mirror.play != core.play || mirror.shownFrame != core.shownFrame {
            mirror.follow(core.play, shownFrame: core.shownFrame)
        }
    }

    /// The seconds since the play last changed at frame time `now` (0 under Reduce Motion): the clock restarts
    /// whenever the level, the phases, the lamp, the actions spent, the stage, the failure or the shown key frame
    /// change.
    func presentationTime(_ core: MoonlitMechanismExperienceCore, now: Double) -> Double {
        let play: MoonlitMechanismPlay = core.play
        let key = PlayKey(levelNumber: core.levelNumber, phases: play.phases, height: play.height,
                          actionsSpent: play.actionsSpent, stage: play.stage, failure: play.failure,
                          shownFrame: core.shownFrame)
        if key != playKey {
            playKey = key
            playStart = now
        }
        guard !reduceMotion else { return 0 }
        let elapsed: Double = now - playStart
        return elapsed.isFinite ? max(0, elapsed) : 0
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: MoonlitMechanismExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = MoonlitMechanismTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(MoonlitMechanismTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time = presentationTime(core, now: frame.time)
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        // The lights settle on the very first frame only; every later change, a level change included, fades, stepped
        // by the frame clock (not the presentation time, which Reduce Motion holds at 0).
        if let last = lastFrameTime {
            lights.step(toward: snapshot, elapsed: frame.time > last ? frame.time - last : 0)
        } else {
            lights.settle(to: snapshot)
        }
        lastFrameTime = frame.time
        scene.lights = lights
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    /// Releases every GPU object.
    func teardown(_ context: RenderContext) {
        scene.release()
    }

    /// Releases every GPU object (memory warning); the next frame rebuilds them.
    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the wall, the gears,
    /// the lamp and the gauges (the camera fits the scene inside a 5 % margin), are `dark` (the night backdrop) once a
    /// snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: MoonlitMechanismExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "night-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "night-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: MoonlitMechanismExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        if let previous = latestCore {
            if !holdingFeedback { route(MoonlitMechanismFeedbackPlan.after(old: previous, new: core)) }
            let opened: Bool = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
        } else {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(Self.recipe(core))
        }
        if !holdingFeedback { absorbProgress(core) } else { absorbProgressKeepingCore(core) }
        mirror.summary = MoonlitMechanismFeedbackPlan.summaryText(core: core, gear: mirror.gear)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        let required: Int = level.keyFrames.filter(\.required).count
        mirror.targetLabel = "Level: cast the targets of \(required) required of \(level.keyFrames.count) key frames "
            + "on a \(level.width) × \(level.rows) wall with \(level.gears.count) gears and \(level.lampHeights) lamp "
            + "heights; \(level.forbidden.count) forbidden cells, \(level.allowance) stray cells allowed"
        let measure: String = level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Moonlit Mechanism level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The shadows match every required key frame."
            if let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = MoonlitMechanismMirror.failureText(play.failure) ?? "The play failed."
            text += reason
            // Since feature 435 the failure explanation too (the failing action, its cause and the advice).
            if let explanation = mirror.explanation { text += " " + explanation }
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        default:
            mirror.status = play.records.isEmpty ? "Ready" : "Playing"
            mirror.failureText = nil
        }
        text += " " + mirror.goalLabel + "."
        if let instruction = mirror.instruction { text += " Tutorial: " + instruction }
        if let hint = mirror.hintText { text += " Hint: " + hint }
        if let pending = mirror.pending { text += " " + pending + "." }
        if play.stage == .won || play.stage == .failed || play.stage == .result {
            text += " " + Self.finishedMessage + "."
        }
        return text
    }

    /// The control panel: "Reset view" returns to the authored orbit; every button sends through ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MoonlitMechanismControls(port: port, mirror: mirror, presenter: self,
                                         resetView: { [weak self] in self?.resetView() },
                                         sender: { [weak self] control, values in
                                             self?.send(control, values, port: port)
                                         }))
    }

    // MARK: Feedback and sound (feature 436, R02-G14-06)

    /// The latest core described while a gear drag's feedback waits (feature 436).
    private var heldCore: MoonlitMechanismExperienceCore?

    /// Keeps `core` for the drag's single plan while feedback waits; the mirror still follows its progress.
    private func absorbProgressKeepingCore(_ core: MoonlitMechanismExperienceCore) {
        heldCore = core
    }

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: MoonlitMechanismFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
    }

    /// The ambient recipe of `core`: its actions left, the covered quarters of its required target cells and its stage.
    static func recipe(_ core: MoonlitMechanismExperienceCore) -> AmbientLoopRecipe {
        MoonlitMechanismSoundRecipe.recipe(play: core.play)
    }

    /// Chooses `gear` in the panel (clamped) and, when the sound is on, plays its audition (presentation only).
    func chooseGear(_ gear: Int) {
        mirror.gear = mirror.clampedGear(gear)
        if mirror.soundOn, let core = latestCore {
            sound.audition(MoonlitMechanismAudition.of(core.play, gear: mirror.gear))
        }
        refreshSummary()
    }

    /// Turns the sound on or off; turning it on plays the recipe of the current play.
    func setSound(on: Bool) {
        if on, let core = latestCore { sound.offer(Self.recipe(core)) }
        sound.setWanted(on)
        mirror.soundOn = on
    }

    /// The controls view appeared (the loop may play).
    func controlsAppeared() { sound.setOnScreen(true) }

    /// The controls view disappeared (the loop and any audition stop).
    func controlsDisappeared() { sound.setOnScreen(false) }

    /// The scene became active or inactive.
    func sceneActive(_ active: Bool) { sound.setActive(active) }

    /// The summary element's text for the chosen gear (the choice is presentation state of the panel).
    func refreshSummary() {
        guard let core = latestCore else { return }
        mirror.summary = MoonlitMechanismFeedbackPlan.summaryText(core: core, gear: mirror.gear)
    }

    // MARK: Teaching and progression (feature 435, R02-G14-05)

    /// Takes the core's teaching and progress state into the mirror: the tutorial instruction, the failure
    /// explanation, the mode, the open levels with their stars and the goal; a change of the play hides the hint.
    private func absorbProgress(_ core: MoonlitMechanismExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        latestCore = core
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.explanation = MoonlitMechanismFailureExplanation(play: core.play)?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.certifiedActions = core.certifiedActions
    }

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: MoonlitMechanismExperienceCore) -> String {
        "\(core.levelNumber)/\(core.mode)/\(core.play.fingerprint)"
    }

    /// Hides the hint shown and drops a search under way.
    private func clearHint() {
        hintSearch?.cancel()
        hintSearch = nil
        hintKey = nil
        mirror.hintLevel = 0
        mirror.hintText = nil
    }

    /// Reveals the next hint level (up to 3) for the current play; the hint is hidden when the play has none (won).
    /// Hints never change the state: no action is sent. The bounded search runs once per play in a detached task,
    /// never on the frame: meanwhile the panel reads "Finding a hint…", and the result is shown only if the play it
    /// belongs to is still the current one; later levels come from the cache.
    func showHint() {
        guard let core = latestCore else { return }
        let key: String = Self.hintKey(core)
        let next: Int = hintKey == key ? min(mirror.hintLevel + 1, 3) : 1
        if let cached = hintCache, cached.key == key {
            reveal(cached.hints, level: next, key: key)
            return
        }
        guard hintSearch == nil || hintKey != key else { return }   // the search for this play is running
        hintKey = key
        mirror.hintLevel = next
        mirror.hintText = Self.searchingText
        let play: MoonlitMechanismPlay = core.play
        hintSearch = Task.detached(priority: .userInitiated) { [weak self] in
            // One search: the plan's first action gives every level (`MoonlitMechanismHint.at(level:)`).
            let first: MoonlitMechanismHint? = MoonlitMechanismHints.hint(level: 1, play: play)
            var hints: [MoonlitMechanismHint?] = []
            for level in 1...3 { hints.append(first?.at(level: level)) }
            await self?.finishSearch(hints, key: key)
        }
    }

    /// Takes the three hint levels searched for the play of `key`: cached, and shown when that play is still current.
    private func finishSearch(_ hints: [MoonlitMechanismHint?], key: String) {
        // A search for a play that is no longer the hinted one (hidden or replaced since) owns nothing: it must not
        // clear a newer search's handle or overwrite the cache.
        guard hintKey == key else { return }
        hintSearch = nil
        hintCache = (key, hints)
        guard let core = latestCore, Self.hintKey(core) == key else { return }
        reveal(hints, level: mirror.hintLevel, key: key)
    }

    /// Shows `hints`' level `level` for the play of `key`, or hides the hint when the play has none.
    private func reveal(_ hints: [MoonlitMechanismHint?], level: Int, key: String) {
        guard hints.indices.contains(level - 1), let hint = hints[level - 1] else {
            clearHint()
            return
        }
        let revealed: Bool = mirror.hintLevel != level || mirror.hintText != hint.text
        hintKey = key
        mirror.hintLevel = level
        mirror.hintText = hint.text
        if revealed { route(MoonlitMechanismFeedbackPlan.hint(text: hint.text)) }   // feature 436: announced as state
    }

    /// Ends the tutorial of the current level (`tutorial.dismiss`).
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", [], port: port)
    }

    /// Takes back the last action (`play.undo`); after a failure this returns the play to playing.
    @discardableResult
    func undoAction(port: ExperienceActionPort) -> ActionResult {
        send("play.undo", [], port: port)
    }

    /// The action and values that start the current level again in its mode: `mode.practice` in practice, the daily
    /// date's `mode.daily` in daily mode, `level.select` of the level in campaign.
    func retryAction(date: DateComponents) -> (control: String, values: [Double]) {
        guard let core = latestCore else { return ("mode.campaign", []) }
        switch core.mode {
        case .practice: return ("mode.practice", [])
        case .daily: return ("mode.daily", Self.dateValues(dailyDate ?? date))
        case .campaign: return ("level.select", [Double(core.levelNumber)])
        case .replay: return ("level.select", [Double(core.levelNumber)])   // feature 437; replay restarts in T-005
        }
    }

    /// Starts the current level again in its mode; in daily mode with the date that opened it (today's local date
    /// when none is known).
    @discardableResult
    func retry(port: ExperienceActionPort, date: DateComponents = MoonlitMechanismPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort,
                   date: DateComponents = MoonlitMechanismPresenter.today()) -> ActionResult {
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

    // MARK: Touch controls (feature 434, R02-G14-04)

    /// What a finished play says when a one-finger gesture sent nothing.
    static let finishedMessage = "The play is over: undo or go to the next level"
    /// What a double tap on the driver says.
    static let driverMessage = "The driver cannot be re-seated"

    /// The pending turn of a gear drag in words.
    static func pendingTurnText(teeth: Int) -> String {
        let count: Int = abs(teeth)
        return "Turn \(count) \(count == 1 ? "tooth" : "teeth") (\(count) \(count == 1 ? "action" : "actions"))"
    }

    /// The pending lamp steps of a lamp drag in words.
    static func pendingLampText(steps: Int) -> String {
        let count: Int = abs(steps)
        let way: String = steps > 0 ? "up" : "down"
        return "Lamp \(count) \(count == 1 ? "step" : "steps") \(way)"
    }

    /// The canvas gestures send handle turns, lamp steps, re-seats, runs and shown key frames; the chosen gear, the
    /// pending texts and the orbit are presentation state.
    var gestureActions: Set<String> { ["handle.turn", "lamp.step", "gear.reseat", "machine.run", "frame.show"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(MoonlitMechanismExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: kernel actions are sent through the port (a turn or lamp drag as that many single steps, each its own
    /// undo step), the chosen gear and the pending texts go to the mirror; a double tap on the driver says it cannot be
    /// re-seated; a one-finger gesture that ends on a won or failed play without choosing explains that the play is
    /// over.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let before: MoonlitMechanismGestureController.State = gestures.state
        let actions: [MoonlitMechanismGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        let finished: Bool = snapshot.stage == .won || snapshot.stage == .failed || snapshot.stage == .result
        let oneFinger: Bool = [.gearPress, .gearDrag, .lampPress, .lampDrag, .cardPress].contains(before)
        var sentKernel = false
        var chose = false
        for action in actions {
            switch action {
            case let .chooseGear(gear):
                chose = true
                chooseGear(gear)
            case let .pendingTurn(_, teeth):
                mirror.pending = teeth == 0 ? nil : Self.pendingTurnText(teeth: teeth)
            case let .turn(step, count):
                sentKernel = true
                mirror.pending = nil
                // Feature 436: the drag's turns are announced and felt once, from the core before the first turn to
                // the core after the last.
                let before: MoonlitMechanismExperienceCore? = latestCore
                holdingFeedback = count > 1
                for _ in 0..<max(count, 0) {
                    // The count is capped at the actions left; a refusal (the play ended) stops the rest.
                    if !send("handle.turn", [Double(step)], port: port).isAccepted { break }
                }
                if holdingFeedback {
                    holdingFeedback = false
                    if let before, let after = heldCore {
                        route(MoonlitMechanismFeedbackPlan.after(old: before, new: after))
                        absorbProgress(after)
                    }
                    heldCore = nil
                }
            case let .pendingLamp(steps):
                mirror.pending = steps == 0 ? nil : Self.pendingLampText(steps: steps)
            case let .lampStep(step, count):
                sentKernel = true
                mirror.pending = nil
                for _ in 0..<max(count, 0) {
                    send("lamp.step", [Double(step)], port: port)
                }
            case let .reseat(gear):
                sentKernel = true
                send("gear.reseat", [Double(gear), 1], port: port)
            case let .showFrame(frame):
                chose = true
                send("frame.show", [Double(frame)], port: port)
            case .run:
                sentKernel = true
                send("machine.run", [], port: port)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
        if gestures.refusedDriverReseat {
            mirror.message = Self.driverMessage
        }
        if event.phase == .ended || event.phase == .cancelled || gestures.state == .orbiting
            || gestures.state == .cancelled {
            if !sentKernel { mirror.pending = nil }
        }
        if event.phase == .ended, finished, oneFinger, !chose, !sentKernel {
            mirror.message = Self.finishedMessage
        }
        scene.orbit = gestures.orbit
    }

    /// Cancels the touches in progress (suspension): nothing is sent and the pending text disappears.
    func cancelPointers() {
        gestures.cancel()
        mirror.pending = nil
    }

    /// Returns the camera to the authored view ("Reset view"; presentation only).
    func resetView() {
        gestures.resetView()
        scene.orbit = gestures.orbit
    }

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its code (read with or without
    /// the engine's `action.rule.` prefix) in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            let plan = MoonlitMechanismFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            route(plan)
            refusalLog.append(MoonlitMechanismMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }
}
#endif
