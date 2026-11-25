// StarlitCartouchePresenter — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-003, 004, 005, 007; clarifications
// Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `StarlitCartoucheChartScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`), keeps a log of every
// tier change with its reason, and caps the glow under Reduce Flashing. Two clocks feed the picture, both presentation
// only: the firmament turns with the frame time (0 under Reduce Motion), and the ship glides along its newest trail
// over ``glideSeconds`` from the frame at which that leg was first drawn (at once under Reduce Motion); an undo, a
// failed leg or a new level leaves the ship at rest. The chosen destination and wait are the adapter's presentation
// state (`route.choose`), read from the core. A refused action is shown in words. A memory warning releases the GPU
// objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel
// (renderer purity). Its probes (two backdrop corners) let the verification runner check a frame.
// Since feature 454 (R02-G16-04) canvas touches go through `StarlitCartoucheGestureController`: a tap chooses a
// destination and the slider a wait (`route.choose`), a double tap or a drag from the ship flies a leg (`route.fly`), a
// ship drag previews its destination (restored when the drag is cleared), two fingers orbit the camera (presentation
// only), and refused actions are shown and logged with their codes, read with or without the engine's `action.rule.`
// prefix.
// Feature 455 (R02-G16-05) T-R02G1605-005 (FR-R02G1605-001 … 005; clarifications Q1–Q5): the mirror carries the
// tutorial instruction, the hint revealed so far (`showHint()` reveals the next of three levels; the bounded search
// runs off the main actor, a stale search owns nothing, and any change of the play hides it), the failure explanation
// (`explanation`; `failureText` stays the short status line), the mode, the open levels with their bands and stars and
// the goal (the certified witness's leg count); `retry` starts the level again in its mode, `undoAction` takes back the
// last leg, and the daily level is chosen from the local calendar date read here (`playDaily(port:date:)`), never by
// the core. A refused `level.next` before a win (`r02-g16.locked`) and an impossible date (`r02-g16.date`) read in
// words.
// Feature 456 (R02-G16-06) T-R02G1606-005 (FR-R02G1606-001 … 006; clarifications Q1 … Q5): the presenter routes
// `StarlitCartoucheFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route (`feedback`,
// injectable; the shared `ExperienceFeedback` by default) and keeps a feedback log (`feedbackLog`); refusals are shown
// and announced in words (`refused(code:)`; the panel shows exactly the plan's text), and a revealed hint is announced
// as `state`. Choosing a destination or wait, the pending drag text, the slider and orbit are not announced (the
// adjustable elements speak their values). The scene's lights (`StarlitCartoucheLights`: the glow and the won look)
// step toward the drawn snapshot every frame by the frame clock's elapsed time (0.15 s fades, 0.45 s under Reduce
// Flashing; the first frame settles them), so fades finish under Reduce Motion too, where the firmament is still. The
// ambient loop (`StarlitCartoucheSound`) is offered the recipe of the actions left, the quarters of the symbol drawn
// and the stage when the first state is described, when a level or mode opens and when that recipe changes; choosing
// another destination (the play unchanged) plays its audition (`StarlitCartoucheAudition.of(_:star:)`) when the sound
// is on, on screen and active; choosing a wait plays none. The mirror carries the summary element's text
// (`StarlitCartoucheFeedbackPlan.summaryText(core:destination:wait:)`) and the sound choice (off by default).
// Presentation only.
#if os(iOS)
import Foundation
import StarlitCartoucheCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreAudioDSP
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described and the chosen destination and wait.
@MainActor
@Observable
final class StarlitCartoucheMirror {
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
    /// The progress in words (the kernel's route report and the actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen destination star, the adapter's.
    var destination = 1
    /// The chosen wait (0 … 8), the adapter's.
    var wait = 0
    /// The play followed (a copy; never sent anywhere).
    var play: StarlitCartouchePlay?
    /// The text of the last refused change, or why a gesture sent nothing, if any.
    var message: String?
    /// The pending leg of a ship drag in words (feature 454), nil when no drag is pending.
    var pending: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 455).
    var instruction: String?
    /// The hint level revealed (0 … 3; 0 while no hint is shown) (feature 455).
    var hintLevel = 0
    /// The text of the hint revealed, or ``StarlitCartouchePresenter/searchingText`` while its search runs
    /// (feature 455).
    var hintText: String?
    /// The failure explanation (the failing leg, its cause and the advice), nil without a failure (feature 455).
    var explanation: String?
    /// The mode (feature 455).
    var mode: StarlitCartoucheMode = .campaign
    /// The highest open level (feature 455).
    var frontier = 1
    /// The stars of each won level, by level number (feature 455).
    var stars: [Int: Int] = [:]
    /// The certified witness's leg count of the current level (the goal, feature 455).
    var certifiedLegs = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen) (feature 455).
    var pickedLevel = 1
    /// The summary element's text (feature 456): `StarlitCartoucheFeedbackPlan.summaryText(core:destination:wait:)` of
    /// the latest core and the chosen leg.
    var summary = ""
    /// Whether the sound is on (feature 456; off by default; presentation only).
    var soundOn = false

    /// The goal and the level's difficulty band (of the five bands of 20), with its best stars when won (feature 455).
    var goalLabel: String {
        let band: Int = StarlitCartoucheProgress.band(of: levelNumber)
        let unit: String = certifiedLegs == 1 ? "leg" : "legs"
        var text = "Goal: draw the symbol in \(certifiedLegs) \(unit); band \(band) of 5"
        if let best = stars[levelNumber] { text += "; best \(best) of 3 stars" }
        return text
    }

    /// The number of stars of the followed level (2 while no play is followed).
    var starCount: Int { max(play?.level.stars.count ?? 2, 2) }
    /// The ship's star (0 while no play is followed).
    var shipStar: Int { play?.star ?? 0 }

    /// The next destination after `destination` in direction `step` (±1), skipping the ship's star, wrapping around.
    func nextDestination(_ step: Int) -> Int {
        var candidate: Int = destination
        for _ in 0..<starCount {
            candidate = ((candidate + step) % starCount + starCount) % starCount
            if candidate != shipStar { return candidate }
        }
        return destination
    }

    /// `value` clamped to the waits 0 … 8.
    func clampedWait(_ value: Int) -> Int { min(max(value, 0), 8) }

    /// The chosen leg in words: the destination, the corridor (or that none joins them) and the wait.
    var legLabel: String {
        guard let play else { return "star \(destination), wait \(wait)" }
        let level: StarlitCartoucheLevel = play.level
        let beats: String = wait == 1 ? "1 beat" : "\(wait) beats"
        guard let corridor = StarlitCartoucheChart.corridor(level, joining: play.star, destination) else {
            return "\(level.starName(destination)): no corridor from \(level.starName(play.star)), wait \(beats)"
        }
        return "\(level.starName(destination)) along \(level.corridorName(corridor)), wait \(beats)"
    }

    /// Takes the new `play` and choice.
    func follow(_ play: StarlitCartouchePlay, destination: Int, wait: Int) {
        self.play = play
        self.destination = destination
        self.wait = clampedWait(wait)
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: StarlitCartoucheFailure?) -> String? {
        switch failure {
        case let .departure(star, beat, close)?:
            "Leaving star \(star) at beat \(beat) misses its window, which closed at beat \(close)."
        case let .hazard(corridor, hazard, from, to)?:
            "Corridor \(corridor) crosses hazard \(hazard), active from beat \(from) to beat \(to)."
        case let .arrival(star, beat, open, close)?:
            "Arriving at star \(star) at beat \(beat) misses its window, beats \(open) to \(close)."
        case let .deadline(beat, deadline)?:
            "The ship would arrive at beat \(beat), after the deadline at beat \(deadline)."
        case let .stroke(corridor)?: "Corridor \(corridor) is not part of the symbol."
        case let .budget(spent)?: "The budget ran out after \(spent) actions."
        case nil: nil
        }
    }

    /// The engine's prefix on a kernel refusal's code (`action.rule.` before the kernel's `r02-g16.*` code).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix`` (feature 454: codes are read with or without it).
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``. Since feature 456 it
    /// forwards to `StarlitCartoucheFeedbackPlan.refusalText(code:)` (clarification Q1's sentences, e.g. "No corridor
    /// can be flown there now.").
    static func refusalText(code: String) -> String {
        StarlitCartoucheFeedbackPlan.refusalText(code: code)
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct StarlitCartoucheTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Starlit Cartouche.
@MainActor
final class StarlitCartouchePresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = StarlitCartoucheExperienceCore

    /// The seconds the ship takes to glide along its newest trail (clarification Q1).
    static let glideSeconds: Double = 0.5

    /// Whether the firmament and the glide are still (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = StarlitCartoucheMirror()
    /// The GL scene.
    let scene = StarlitCartoucheChartScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1603-004).
    private(set) var tierLog: [StarlitCartoucheTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: StarlitCartoucheSceneSnapshot?
    /// The glide (0 … 1) of the last frame drawn (tests).
    private(set) var lastGlide: Double = 1
    /// The gesture controller (feature 454): star taps and double taps, the slider, ship drags, orbit.
    private(set) var gestures = StarlitCartoucheGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability, feature 454).
    private(set) var refusalLog: [String] = []
    /// How many refusal codes ``refusalLog`` keeps.
    static let refusalLogLimit = 64
    /// The feedback route of announcements and haptics (feature 456; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first (feature 456; tests and diagnostics).
    private(set) var feedbackLog: [StarlitCartoucheFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 456).
    private(set) var lights: StarlitCartoucheLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient loop and the chosen destination's audition (feature 456).
    let sound: StarlitCartoucheSound
    /// The destination chosen before a ship drag began previewing another, restored when the preview is cleared.
    private var previewRestore: Int?
    /// The latest core described (feature 455): hints and retry read it.
    private(set) var latestCore: StarlitCartoucheExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 455).
    private var hintKey: String?
    /// The hints searched for a play, by that play's key: one search per play, every level from it (feature 455).
    private var hintCache: (key: String, hints: [StarlitCartoucheHint?])?
    /// The search under way, off the main actor, for the play of ``hintKey`` (feature 455).
    private(set) var hintSearch: Task<Void, Never>?
    /// What the hint line shows while the search runs (feature 455).
    static let searchingText = "Finding a hint…"
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 455).
    private(set) var dailyDate: DateComponents?

    /// The level and the number of flown legs last seen, and the frame time of the newest leg (the glide starts
    /// there).
    private var seenLevel: Int?
    private var seenLegs = 0
    private var playStart: Double = -Double.greatestFiniteMagnitude

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        lights = StarlitCartoucheLights(reducedFlash: reduceFlashing)
        sound = StarlitCartoucheSound(recipe: StarlitCartoucheSoundRecipe.recipe(rootStep: 0, quarters: 0,
                                                                                 stage: .loading))
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the chart program's fragment source with one that does not compile.
    func breakChartShader() {
        scene.chartFragment = "this is not a shader;"
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

    /// Follows `core`'s play and choice in the mirror when they changed.
    private func follow(_ core: StarlitCartoucheExperienceCore) {
        if mirror.play != core.play || mirror.destination != core.chosenStar || mirror.wait != core.chosenWait {
            mirror.follow(core.play, destination: core.chosenStar, wait: core.chosenWait)
        }
    }

    /// The ship's glide (0 … 1) at frame time `now`: 1 under Reduce Motion or without a leg, else the share of
    /// ``glideSeconds`` since the newest leg was first drawn. Only a leg added (flown or redone) restarts the glide: an
    /// undo, a failed leg (the ship stays at its star) or a new level leaves the ship at rest.
    func glide(_ core: StarlitCartoucheExperienceCore, now: Double) -> Double {
        let play: StarlitCartouchePlay = core.play
        let legs: Int = play.legs.count
        if seenLevel != core.levelNumber {
            seenLevel = core.levelNumber
            seenLegs = legs
            playStart = -Double.greatestFiniteMagnitude
        } else if legs > seenLegs {
            seenLegs = legs
            playStart = now
        } else if legs < seenLegs {
            seenLegs = legs
            playStart = -Double.greatestFiniteMagnitude
        }
        guard !reduceMotion, legs > 0 else { return 1 }
        let share: Double = (now - playStart) / Self.glideSeconds
        return share.isFinite ? min(max(share, 0), 1) : 1
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: StarlitCartoucheExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = StarlitCartoucheTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(StarlitCartoucheTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let glide: Double = glide(core, now: frame.time)
        lastGlide = glide
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        // The lights settle on the very first frame only; every later change, a level change included, fades, stepped
        // by the frame clock (feature 456; Reduce Motion stills the firmament, not the fades).
        if let last = lastFrameTime {
            lights.step(toward: snapshot, elapsed: frame.time > last ? frame.time - last : 0)
        } else {
            lights.settle(to: snapshot)
        }
        lastFrameTime = frame.time
        scene.lights = lights
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, glide: glide)
    }

    /// Releases every GPU object.
    func teardown(_ context: RenderContext) {
        scene.release()
    }

    /// Releases every GPU object (memory warning); the next frame rebuilds them.
    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the chart, the
    /// cartouche and the gauges (the camera fits the scene inside a 5 % margin), are `dark` (the ultramarine
    /// firmament) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: StarlitCartoucheExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "firmament-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "firmament-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: StarlitCartoucheExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.targetLabel = "Level: draw the symbol of \(level.symbol.count) strokes across \(level.stars.count) "
            + "stars and reach \(level.starName(level.beacon)) by beat \(level.deadline)"
        let measure: String = level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        if let previous = latestCore {
            route(StarlitCartoucheFeedbackPlan.after(old: previous, new: core))
            let opened: Bool = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
            // Choosing another destination (presentation state of the adapter; the play unchanged, so a leg's reset of
            // the choice does not count) plays its audition when the sound is on; choosing a wait plays none.
            if !opened, previous.play == core.play, previous.chosenStar != core.chosenStar, mirror.soundOn {
                sound.audition(StarlitCartoucheAudition.of(core.play, star: core.chosenStar))
            }
        } else {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(Self.recipe(core))
        }
        absorbProgress(core)
        mirror.summary = StarlitCartoucheFeedbackPlan.summaryText(core: core, destination: core.chosenStar,
                                                                  wait: core.chosenWait)
        var text = "Starlit Cartouche level \(core.levelNumber). "
        text += measure + ". "
        if let pending = mirror.pending { text += pending + ". " }
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The trail draws the symbol and the ship rests at the beacon."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = StarlitCartoucheMirror.failureText(play.failure) ?? "The play failed."
            text += reason
            // Since feature 455 the failure explanation too (the failing leg, its cause and the advice).
            if let explanation = mirror.explanation { text += " " + explanation }
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        default:
            mirror.status = play.records.isEmpty ? "Ready" : "Playing"
            mirror.failureText = nil
        }
        if play.stage == .won || play.stage == .failed || play.stage == .result {
            text += " " + Self.finishedMessage + "."
        }
        if play.stage == .won, let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
        text += " " + mirror.goalLabel + "."
        if let instruction = mirror.instruction { text += " Tutorial: " + instruction }
        if let hint = mirror.hintText { text += " Hint: " + hint }
        return text
    }

    /// The control panel: "Reset view" returns to the authored orbit; every button sends through ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(StarlitCartoucheControls(port: port, mirror: mirror, presenter: self,
                                         resetView: { [weak self] in self?.resetView() },
                                         sender: { [weak self] control, values in
                                             self?.send(control, values, port: port)
                                         }))
    }

    // MARK: Touch controls (feature 454, R02-G16-04)

    /// What a finished play says when a one-finger gesture sent nothing.
    static let finishedMessage = StarlitCartoucheGestureController.finishedReason

    /// The pending leg of a ship drag in words: "Fly to star s".
    static func pendingLegText(star: Int) -> String { "Fly to star \(star)" }

    /// The canvas gestures fly legs and choose the destination and wait; the pending text, the preview and the orbit
    /// are presentation state.
    var gestureActions: Set<String> { ["route.fly", "route.choose"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(StarlitCartoucheExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a leg goes through `route.fly` (its own undo step), a destination or wait through `route.choose`
    /// (presentation only), a ship drag's preview through `route.choose` (the earlier destination is restored when the
    /// preview is cleared), and an explanation to the mirror's message.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let actions: [StarlitCartoucheGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        var destination: Int = snapshot.chosenStar
        var wait: Int = snapshot.chosenWait
        for action in actions {
            switch action {
            case let .chooseDestination(star):
                previewRestore = nil
                if send("route.choose", [Double(star), Double(wait)], port: port).isAccepted { destination = star }
            case let .chooseWait(next):
                if send("route.choose", [Double(destination), Double(next)], port: port).isAccepted { wait = next }
            case let .preview(star):
                if previewRestore == nil { previewRestore = destination }
                if send("route.choose", [Double(star), Double(wait)], port: port).isAccepted { destination = star }
                mirror.pending = Self.pendingLegText(star: star)
            case .clearPreview:
                mirror.pending = nil
                if let restore = previewRestore {
                    previewRestore = nil
                    if send("route.choose", [Double(restore), Double(wait)], port: port).isAccepted {
                        destination = restore
                    }
                }
            case let .fly(star, legWait):
                mirror.pending = nil
                previewRestore = nil
                send("route.fly", [Double(star), Double(legWait)], port: port)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            case let .explain(reason):
                mirror.message = reason
            }
        }
        if event.phase == .ended || event.phase == .cancelled || gestures.state == .orbiting
            || gestures.state == .cancelled {
            mirror.pending = nil
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
            let plan = StarlitCartoucheFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            route(plan)
            refusalLog.append(StarlitCartoucheMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }

    // MARK: Teaching and progression (feature 455, R02-G16-05)

    /// Takes the core's teaching and progress state into the mirror: the tutorial instruction, the failure
    /// explanation, the mode, the open levels with their stars and the goal; a change of the play hides the hint.
    private func absorbProgress(_ core: StarlitCartoucheExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        latestCore = core
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.explanation = StarlitCartoucheFailureExplanation(play: core.play)?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.certifiedLegs = core.certifiedLegs
    }

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: StarlitCartoucheExperienceCore) -> String {
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

    /// The three hint levels of `play` from one search: the exact hint's leg gives every level's text
    /// (`StarlitCartoucheHint.legText(level:star:wait:corridor:a:b:)`, the corridor joining the ship's star and the
    /// destination); a stuck or failed hint reads the same at every level; nil at every level for a play without a hint
    /// (won).
    nonisolated static func hintLevels(_ play: StarlitCartouchePlay) -> [StarlitCartoucheHint?] {
        guard let exact = StarlitCartoucheHints.hint(level: 3, play: play) else { return [nil, nil, nil] }
        guard exact.kind == .leg, case .leg(let star, let wait)? = exact.action,
              let corridor = StarlitCartoucheChart.corridor(play.level, joining: play.star, star) else {
            return [exact, exact, exact]
        }
        let joined: StarlitCartoucheCorridor = play.level.corridors[corridor]
        var hints: [StarlitCartoucheHint?] = []
        for level in 1...3 {
            var hint: StarlitCartoucheHint = exact
            hint.text = StarlitCartoucheHint.legText(level: level, star: star, wait: wait, corridor: corridor,
                                                     a: joined.a, b: joined.b)
            hints.append(hint)
        }
        return hints
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
        let play: StarlitCartouchePlay = core.play
        hintSearch = Task.detached(priority: .userInitiated) { [weak self] in
            let hints: [StarlitCartoucheHint?] = StarlitCartouchePresenter.hintLevels(play)
            await self?.finishSearch(hints, key: key)
        }
    }

    /// Takes the three hint levels searched for the play of `key`: cached, and shown when that play is still current.
    private func finishSearch(_ hints: [StarlitCartoucheHint?], key: String) {
        // A search for a play that is no longer the hinted one (hidden or replaced since) owns nothing: it must not
        // clear a newer search's handle or overwrite the cache.
        guard hintKey == key else { return }
        hintSearch = nil
        hintCache = (key, hints)
        guard let core = latestCore, Self.hintKey(core) == key else { return }
        reveal(hints, level: mirror.hintLevel, key: key)
    }

    /// Shows `hints`' level `level` for the play of `key`, or hides the hint when the play has none.
    private func reveal(_ hints: [StarlitCartoucheHint?], level: Int, key: String) {
        guard hints.indices.contains(level - 1), let hint = hints[level - 1] else {
            clearHint()
            return
        }
        let revealed: Bool = mirror.hintLevel != level || mirror.hintText != hint.text
        hintKey = key
        mirror.hintLevel = level
        mirror.hintText = hint.text
        if revealed { route(StarlitCartoucheFeedbackPlan.hint(text: hint.text)) }   // feature 456: announced as state
    }

    /// Ends the tutorial of the current level (`tutorial.dismiss`).
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", [], port: port)
    }

    /// Takes back the last leg (`play.undo`); after a failure this returns the play to playing.
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
        }
    }

    /// Starts the current level again in its mode; in daily mode with the date that opened it (today's local date
    /// when none is known).
    @discardableResult
    func retry(port: ExperienceActionPort, date: DateComponents = StarlitCartouchePresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort,
                   date: DateComponents = StarlitCartouchePresenter.today()) -> ActionResult {
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

    // MARK: Feedback and sound (feature 456, R02-G16-06)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: StarlitCartoucheFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
    }

    /// The ambient recipe of `core`: its actions left, the quarters of its symbol drawn and its stage.
    static func recipe(_ core: StarlitCartoucheExperienceCore) -> AmbientLoopRecipe {
        StarlitCartoucheSoundRecipe.recipe(play: core.play)
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
}
#endif
