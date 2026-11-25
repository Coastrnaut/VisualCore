// CelestialEclipseLabPresenter — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-003, 004, 005, 007;
// clarifications Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `CelestialEclipseLabSkyScene` at the
// host's quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`),
// keeps a log of every tier change with its reason, and caps the glow under Reduce Flashing. One clock feeds the
// picture, presentation only: the corona halos pulse with the frame time (`u_pulse`, held at 1 under Reduce Motion);
// the shown tick is the adapter's presentation state (`clock.show`) and is never advanced by time. The chosen body and
// the shown tick are read from the core. The tutorial of levels 1 … 3 is shown in words, as presentation, not as a
// kernel stage. A refused action is shown in words. A memory warning releases the GPU objects; the next frame
// rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel (renderer purity). Its
// probes (two backdrop corners) let the verification runner check a frame.
//
// Feature 464 (R02-G17-04) T-R02G1704-005 (FR-R02G1704-001 … 009; clarifications Q1 … Q5) wires touch: a canvas touch
// goes through the presenter's `CelestialEclipseLabGestureController` with the drawn snapshot (`pointer`); a tap on a
// planet sends `orbit.choose [body]`, the time dial `clock.show [tick]` (both presentation only, in any stage), a phase
// drag previews its pending offset (the ghost and the predicted timeline of
// `CelestialEclipseLabSceneSnapshot.previewing(body:offset:)`, presentation state kept in the mirror) and its release
// sends one `orbit.phase [body, offset]`; a drag on a fixed planet or a finished play explains why nothing happens;
// two fingers orbit the camera and a double tap on empty space or "Reset view" (`resetView()`) returns it (the orbit
// is presentation only and rebuilds the meshes). The panel's phase − and + move a pending offset of the chosen planet,
// drawn as the same preview, and "Set phase" commits it as one action. A refused action is shown in words and its
// code logged (`refusalLog`), read with or without the engine's `action.rule.` prefix.
//
// Feature 465 (R02-G17-05) T-R02G1705-005 (FR-R02G1705-001 … 005, 007; clarifications Q1 … Q5) adds teaching and
// progression to the panel: the tutorial instruction (`core.tutorial.text` until the step is `done`), the hint at its
// current level (`showHint()`: each press raises the level 1 → 2 → 3; any change of the play hides it, so the next
// press shows level 1; one search per play through `CelestialEclipseLabHints.hint(level:play:)`, run off the main actor
// in a detached task, with a generation counter so that a stale search never owns the hint state; hints never send an
// action), the failure explanation (`CelestialEclipseLabFailureExplanation(play:)`, while `failureText` stays the short
// status line), the mode, the open levels, the level's band (of the five bands of 20), its goal (the target eclipses in
// words and the certified phase-change count) and its best stars (`core.progress.stars(of:)`). The description includes
// them. The daily level is asked for with today's local calendar date read here (`playDaily(port:date:)`); the core
// never reads a clock. A refused `level.select` or `level.next` (`r02-g17.locked`) and an impossible date
// (`r02-g17.date`) read in words.
//
// Feature 466 (R02-G17-06) T-R02G1706-005 (FR-R02G1706-001 … 006; clarifications Q1 … Q5): the presenter routes
// `CelestialEclipseLabFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route
// (`feedback`, injectable; the shared `ExperienceFeedback` by default) once for every new core it takes in, from the
// frame or the description, and keeps a feedback log (`feedbackLog`); refusals are shown and announced in words
// (`refused(code:)`; the panel shows exactly the plan's text), and a revealed hint is announced as `state`. Choosing a
// body, the pending phase, the shown tick and orbit are not announced (the adjustable elements speak their values).
// The scene's lights (`CelestialEclipseLabLights`: the glow and the won look) step toward the drawn snapshot every
// frame by the frame clock's elapsed time (0.15 s fades, 0.45 s under Reduce Flashing; the first frame settles them),
// so fades finish under Reduce Motion too, where the halos hold still. The ambient loop (`CelestialEclipseLabSound`) is
// offered the recipe of the actions left, the quarters of the target matched and the stage when the first core is
// taken in, when a level or mode opens and when that recipe changes; choosing another body (the play unchanged) plays
// its audition (`CelestialEclipseLabAudition.of(_:body:)`) when the sound is on, on screen and active. The mirror
// carries the summary element's text (`CelestialEclipseLabFeedbackPlan.summaryText(core:body:phase:)`) and the sound
// choice (off by default). Presentation only.
#if os(iOS)
import CelestialEclipseLabCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreAudioDSP
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// A previewed phase: planet `body` drawn at offset `offset` (feature 464; presentation only, never sent).
struct CelestialEclipseLabPreview: Equatable {
    /// The previewed planet.
    let body: Int
    /// The previewed offset, 0 … period − 1.
    let offset: Int
}

/// What the controls show: the latest state the presenter described and the chosen body and shown tick.
@MainActor
@Observable
final class CelestialEclipseLabMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions left.
    var actionsLeft = 0
    /// The action budget.
    var budget = 0
    /// A one-line status: "Ready", "Playing", "Won" or "Failed: " and the failure in words.
    var status = ""
    /// The failure in words, if the run failed.
    var failureText: String?
    /// The progress in words (the kernel's progress description and the actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The tutorial instruction of the current step (`core.tutorial.text`, feature 465); nil once the step is `done`.
    var tutorialText: String?
    /// The chosen body, the adapter's.
    var chosenBody = 0
    /// The shown tick, the adapter's.
    var shownTick = 0
    /// The play followed (a copy; never sent anywhere).
    var play: CelestialEclipseLabPlay?
    /// The text of the last refused change, or why a gesture did nothing, if any.
    var message: String?
    /// The panel's pending phase of the chosen planet (feature 464; presentation only), nil when none is pending. It
    /// is dropped when the chosen planet changes, after any applied kernel action and on the next level.
    var pendingOffset: Int?
    /// The phase drag's preview (feature 464; presentation only), nil when no drag previews.
    var preview: CelestialEclipseLabPreview?
    /// The hint level shown, 1 … 3; 0 while no hint is shown (feature 465; presentation only).
    var hintLevel = 0
    /// The hint shown at ``hintLevel``, ``CelestialEclipseLabPresenter/searchingText`` while its search runs, or
    /// ``CelestialEclipseLabPresenter/noHintText`` when the play has no hint; nil while no hint is shown (feature 465).
    var hintText: String?
    /// The failure explanation (`CelestialEclipseLabFailureExplanation`: what went wrong, then the advice), nil without
    /// a failure (feature 465).
    var explanation: String?
    /// The latest core taken in, for the summary element (feature 466); nil before the first.
    var summaryCore: CelestialEclipseLabExperienceCore?
    /// Whether the sound is on (feature 466; off by default; presentation only).
    var soundOn = false
    /// The summary element's text (feature 466): `CelestialEclipseLabFeedbackPlan.summaryText(core:body:phase:)` of
    /// the latest core, the chosen body and its pending phase (the current one when no change is pending).
    var summary: String {
        guard let core = summaryCore else { return "" }
        return CelestialEclipseLabFeedbackPlan.summaryText(core: core, body: chosenBody,
                                                           phase: pendingOffset ?? chosenPhase)
    }
    /// The mode (feature 465).
    var mode: CelestialEclipseLabMode = .campaign
    /// The highest open level (feature 465).
    var frontier = 1
    /// The level's difficulty band, 1 … 5 (the five bands of 20; feature 465).
    var band = 1
    /// The best stars of the current level, 0 … 3 (0 while it has not been won; feature 465).
    var bestStars = 0
    /// The stars of each won level, by level number (the level picker; feature 465).
    var stars: [Int: Int] = [:]
    /// The goal in words: the target eclipses in order and the certified phase-change count (feature 465).
    var goalLabel = ""
    /// The level the picker holds, 1 … ``frontier`` (presentation only; feature 465).
    var pickedLevel = 1

    /// "Band b of 5" (feature 465).
    var bandLabel: String { "Band \(band) of 5" }

    /// "Best: s of 3 stars", or "Best: not won yet" while the level has not been won (feature 465).
    var starsLabel: String {
        bestStars > 0 ? "Best: \(bestStars) of 3 stars" : "Best: not won yet"
    }

    /// "Mode: campaign", "Mode: practice" or "Mode: daily" (feature 465).
    var modeLabel: String { "Mode: " + Self.modeName(mode) }

    /// The mode's name: campaign, practice or daily (feature 465).
    static func modeName(_ mode: CelestialEclipseLabMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// The picker's line for level `level`: "Level n, band b", with ", s of 3 stars" once it has been won
    /// (feature 465).
    func levelLabel(_ level: Int) -> String {
        let band: Int = CelestialEclipseLabProgress.band(of: level)
        if let won = stars[level] { return "Level \(level), band \(band), \(won) of 3 stars" }
        return "Level \(level), band \(band)"
    }

    /// The goal of `level` with `certified` phase changes in the certified witness (feature 465): "Goal: target 1,
    /// planet f in front of planet b in ticks o … c; target 2, …; in order, then run the clock. 3 stars within C
    /// actions" ("1 action" singular).
    static func goalText(_ level: CelestialEclipseLabLevel, certified: Int) -> String {
        var parts: [String] = []
        for (index, target) in level.target.enumerated() {
            parts.append("target \(index + 1), planet \(target.front) in front of planet \(target.back) in ticks "
                         + "\(target.open) … \(target.close)")
        }
        let unit: String = certified == 1 ? "action" : "actions"
        return "Goal: " + parts.joined(separator: "; ") + "; in order, then run the clock. 3 stars within "
            + "\(certified) \(unit)"
    }

    /// The number of bodies of the followed level (1 while no play is followed).
    var bodyCount: Int { max(play?.level.bodies.count ?? 1, 1) }
    /// The horizon of the followed level in ticks (1 while no play is followed).
    var horizon: Int { max(play?.level.horizon ?? 1, 1) }
    /// The period of the chosen body (1 while no play is followed or the body is unknown).
    var chosenPeriod: Int {
        guard let play, play.level.bodies.indices.contains(chosenBody) else { return 1 }
        return max(play.level.bodies[chosenBody].period, 1)
    }
    /// The current phase of the chosen body (0 while no play is followed or the body is unknown).
    var chosenPhase: Int {
        guard let play, play.phases.indices.contains(chosenBody) else { return 0 }
        return play.phases[chosenBody]
    }
    /// Whether the chosen body's phase is fixed.
    var chosenFixed: Bool {
        guard let play, play.level.bodies.indices.contains(chosenBody) else { return false }
        return play.level.bodies[chosenBody].fixed
    }

    /// The next movable body after `chosenBody` in direction `step` (±1), wrapping around; the chosen body when no
    /// other is movable.
    func nextBody(_ step: Int) -> Int {
        guard let play else { return chosenBody }
        let count: Int = bodyCount
        var candidate: Int = chosenBody
        for _ in 0..<count {
            candidate = ((candidate + step) % count + count) % count
            if play.level.bodies.indices.contains(candidate), !play.level.bodies[candidate].fixed { return candidate }
        }
        return chosenBody
    }

    /// The chosen body's phase moved by `step` (±1) modulo its period.
    func steppedPhase(_ step: Int) -> Int {
        let period: Int = chosenPeriod
        return ((chosenPhase + step) % period + period) % period
    }

    /// The pending phase of the chosen planet, or its current phase when none is pending (feature 464).
    var pendingPhase: Int { pendingOffset ?? chosenPhase }

    /// Whether a pending phase differs from the chosen planet's current phase ("Set phase" is enabled).
    var pendingDiffers: Bool {
        guard let pendingOffset else { return false }
        return pendingOffset != chosenPhase
    }

    /// The pending phase moved by `step` (±1) modulo the chosen planet's period (feature 464).
    func steppedPending(_ step: Int) -> Int {
        let period: Int = chosenPeriod
        return ((pendingPhase + step) % period + period) % period
    }

    /// The preview drawn: the drag's preview first, else the pending phase of the chosen planet when it is movable;
    /// nil without either.
    var drawnPreview: CelestialEclipseLabPreview? {
        if let preview { return preview }
        guard let pendingOffset, play != nil, !chosenFixed else { return nil }
        return CelestialEclipseLabPreview(body: chosenBody, offset: pendingOffset)
    }

    /// `value` clamped to the ticks 0 … horizon − 1.
    func clampedTick(_ value: Int) -> Int { min(max(value, 0), horizon - 1) }

    /// The chosen body in words: its name, phase and period, and whether it is fixed.
    var bodyLabel: String {
        guard let play else { return "body \(chosenBody)" }
        let name: String = play.level.bodyName(chosenBody)
        let fixed: String = chosenFixed ? ", fixed" : ""
        return "\(name), phase \(chosenPhase) of \(chosenPeriod)\(fixed)"
    }

    /// The shown tick in words with the eclipses under way at it.
    var tickLabel: String {
        guard let play else { return "tick \(shownTick)" }
        let level: CelestialEclipseLabLevel = play.level
        let eclipses: [CelestialEclipseLabEclipse] =
            CelestialEclipseLabSceneSnapshot.eclipses(level, phases: play.phases, tick: clampedTick(shownTick))
        var text: String = "tick \(shownTick) of \(level.horizon)"
        if eclipses.isEmpty { return text + ": no eclipse" }
        var parts: [String] = []
        for eclipse in eclipses {
            parts.append(level.eclipseName(front: eclipse.front, back: eclipse.back) + ", "
                         + eclipse.visibility.rawValue)
        }
        text += ": " + parts.joined(separator: "; ")
        return text
    }

    /// Takes the new `play` and presentation; a changed play (an applied kernel action, the next level) or a newly
    /// chosen planet drops the pending phase.
    func follow(_ play: CelestialEclipseLabPlay, chosenBody: Int, shownTick: Int) {
        if self.play != play || self.chosenBody != chosenBody { pendingOffset = nil }
        self.play = play
        self.chosenBody = chosenBody
        self.shownTick = shownTick
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: CelestialEclipseLabFailure?) -> String? {
        switch failure {
        case let .unwanted(front, back, tick)?:
            "Body \(front) passed in front of body \(back) at tick \(tick) before the next target eclipse."
        case let .window(front, back, tick, open, close)?:
            "Body \(front) passed in front of body \(back) at tick \(tick), outside its window, ticks \(open) to "
                + "\(close)."
        case let .horizon(front, back, open, close)?:
            "The clock reached its horizon before body \(front) passed in front of body \(back) in its window, ticks "
                + "\(open) to \(close)."
        case nil: nil
        }
    }

    /// The engine's prefix on a kernel refusal's code (`action.rule.` before the kernel's `r02-g17.*` code).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix`` (feature 464: codes are read with or without it).
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// The panel line of a refusal: since feature 466 exactly the feedback plan's sentence
    /// (`CelestialEclipseLabFeedbackPlan.refusalText(code:)`, clarification Q1), the words that are announced.
    static func refusalMessage(code: String) -> String {
        CelestialEclipseLabFeedbackPlan.refusalText(code: code)
    }

    /// Records the result of sending `control` with `values` (feature 464): a refusal is shown in words; an accepted
    /// kernel action drops the pending phase, and so does choosing another planet.
    func record(_ control: String, _ values: [Double], accepted: Bool, code: String) {
        guard accepted else {
            message = Self.refusalMessage(code: code)
            return
        }
        message = nil
        switch control {
        case "clock.show":
            break
        case "orbit.choose":
            if let first = values.first, Int(exactly: first) != chosenBody { pendingOffset = nil }
        default:
            pendingOffset = nil
        }
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``. Since feature 466 it
    /// forwards to `CelestialEclipseLabFeedbackPlan.refusalText(code:)` (clarification Q1's sentences, e.g. "That body
    /// is not in this level.").
    static func refusalText(code: String) -> String {
        CelestialEclipseLabFeedbackPlan.refusalText(code: code)
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct CelestialEclipseLabTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Celestial Eclipse Lab.
@MainActor
final class CelestialEclipseLabPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = CelestialEclipseLabExperienceCore

    /// Whether the halos are still (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = CelestialEclipseLabMirror()
    /// The GL scene.
    let scene = CelestialEclipseLabSkyScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1703-004).
    private(set) var tierLog: [CelestialEclipseLabTierChange] = []
    /// The last snapshot drawn (tests, the description and the gestures), with the drawn preview applied.
    private(set) var lastSnapshot: CelestialEclipseLabSceneSnapshot?
    /// The gesture controller (feature 464): planet taps and drags, the time dial, double taps and the orbit.
    private(set) var gestures = CelestialEclipseLabGestureController()
    /// The reason codes of refused actions without the engine's prefix, oldest first, at most ``refusalLogLimit``
    /// (observability, feature 464).
    private(set) var refusalLog: [String] = []
    /// How many refusal codes ``refusalLog`` keeps.
    static let refusalLogLimit = 64
    /// The latest core seen (feature 465): hints, the daily date and the progress lines read it.
    private(set) var latestCore: CelestialEclipseLabExperienceCore?
    /// The play the shown hint belongs to; nil while no hint is shown (feature 465).
    private var hintPlay: CelestialEclipseLabPlay?
    /// The hint texts of levels 1 … 3 searched for a play (nil texts: the play has no hint), one search per play
    /// (feature 465).
    private var hintCache: (play: CelestialEclipseLabPlay, texts: [String]?)?
    /// The search under way, off the main actor, for ``hintPlay`` (feature 465); tests may await its value.
    private(set) var hintSearch: Task<Void, Never>?
    /// The hint generation (feature 465): raised by every new search and every hidden hint; a search whose generation
    /// is no longer current owns nothing.
    private(set) var hintGeneration = 0
    /// What the hint line shows while the search runs (feature 465).
    static let searchingText = "Finding a hint…"
    /// What the hint line shows when the play has no hint (won, or not under way; feature 465).
    static let noHintText = "No hint now: the level is not being played."

    /// The feedback route of announcements and haptics (feature 466; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first (feature 466; tests and diagnostics).
    private(set) var feedbackLog: [CelestialEclipseLabFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 466).
    private(set) var lights: CelestialEclipseLabLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient loop and the chosen body's audition (feature 466).
    let sound: CelestialEclipseLabSound

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        lights = CelestialEclipseLabLights(reducedFlash: reduceFlashing)
        sound = CelestialEclipseLabSound(recipe: CelestialEclipseLabSoundRecipe.recipe(rootStep: 0, quarters: 0,
                                                                                      stage: .loading))
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the sky program's fragment source with one that does not compile.
    func breakSkyShader() {
        scene.skyFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the Core's `qualityTiers` (`level-0` … `level-2`).
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(CelestialEclipseLabTier.of(tier).name) }
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
    private func follow(_ core: CelestialEclipseLabExperienceCore) {
        if mirror.play != core.play || mirror.chosenBody != core.chosenBody || mirror.shownTick != core.shownTick {
            mirror.follow(core.play, chosenBody: core.chosenBody, shownTick: core.shownTick)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: CelestialEclipseLabExperienceCore, tier: Int, context: RenderContext,
              frame: FrameInfo) throws {
        let drawn = CelestialEclipseLabTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(CelestialEclipseLabTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        if latestCore != core { absorbProgress(core) }
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let snapshot = presented(core.snapshot(time: time))
        lastSnapshot = snapshot
        scene.orbit = gestures.orbit
        // The lights settle on the very first frame only; every later change, a level change included, fades, stepped
        // by the frame clock (feature 466; Reduce Motion holds the halos, not the fades).
        if let last = lastFrameTime {
            lights.step(toward: snapshot, elapsed: frame.time > last ? frame.time - last : 0)
        } else {
            lights.settle(to: snapshot)
        }
        lastFrameTime = frame.time
        scene.lights = lights
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the sky, the rings,
    /// the timeline and the actions bars (the camera fits the scene inside a 6 % margin), are `dark` (the ink
    /// backdrop) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: CelestialEclipseLabExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: CelestialEclipseLabExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        absorbProgress(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.targetLabel = "Level: \(level.target.count) target eclipses in order among \(level.bodies.count) "
            + "bodies over \(level.horizon) ticks"
        let measure: String = level.progressDescription(timeline: play.timeline, actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Celestial Eclipse Lab level \(core.levelNumber). "
        text += measure + ". "
        text += previewText(level)
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every target eclipse came in order inside its window."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = CelestialEclipseLabMirror.failureText(play.failure) ?? "The run failed."
            text += reason
            // Since feature 465 the failure explanation too (what went wrong, then the advice).
            if let explanation = mirror.explanation { text += " " + explanation }
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
        text += " " + teachingText()
        return text
    }

    /// The teaching and progress sentences of the description (feature 465): the mode, the band, the goal, the best
    /// stars, then the tutorial instruction and the hint when shown; each ends in a full stop, joined by spaces.
    private func teachingText() -> String {
        var parts: [String] = [mirror.modeLabel, mirror.bandLabel, mirror.goalLabel, mirror.starsLabel]
        if let tutorial = mirror.tutorialText { parts.append("Tutorial: " + tutorial) }
        if let hint = mirror.hintText {
            parts.append((mirror.hintLevel > 0 ? "Hint \(mirror.hintLevel) of 3: " : "Hint: ") + hint)
        }
        var sentences: [String] = []
        for part in parts {
            sentences.append(part.hasSuffix(".") || part.hasSuffix("…") ? part : part + ".")
        }
        return sentences.joined(separator: " ")
    }

    /// The drag's preview or the pending phase in words (feature 464), each followed by ". "; empty without either.
    private func previewText(_ level: CelestialEclipseLabLevel) -> String {
        var text: String = ""
        if let preview = mirror.preview {
            text += "Previewing \(level.bodyName(preview.body)) at phase \(preview.offset)"
            if let snapshot = lastSnapshot, snapshot.isPreviewing {
                text += ": \(snapshot.previewMatched) of \(snapshot.target.count) target eclipses in order"
            }
            text += ". "
        }
        if let pending = mirror.pendingOffset {
            text += "Pending phase \(pending) for \(level.bodyName(mirror.chosenBody)), now \(mirror.chosenPhase)"
            text += mirror.pendingDiffers ? ": Set phase applies it. " : ". "
        }
        return text
    }

    /// `snapshot` with the mirror's drawn preview applied (the drag's preview first, else the pending phase of the
    /// chosen movable planet); without a preview when neither exists.
    private func presented(_ snapshot: CelestialEclipseLabSceneSnapshot) -> CelestialEclipseLabSceneSnapshot {
        guard let preview = mirror.drawnPreview else { return snapshot.withoutPreview() }
        return snapshot.previewing(body: preview.body, offset: preview.offset)
    }

    /// Redraws the last snapshot with the mirror's current preview (the next frame draws the same).
    private func refreshPreview() {
        guard let snapshot = lastSnapshot else { return }
        lastSnapshot = presented(snapshot)
    }

    /// The control panel: "Reset view" returns to the authored orbit; every button sends through ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(CelestialEclipseLabControls(port: port, mirror: mirror, presenter: self,
                                            resetView: { [weak self] in self?.resetView() },
                                            sender: { [weak self] control, values in
                                                self?.send(control, values, port: port)
                                            },
                                            redraw: { [weak self] in self?.refreshPreview() }))
    }

    // MARK: Touch controls (feature 464, R02-G17-04)

    /// What a finished play says when a one-finger gesture sent nothing.
    static let finishedMessage = CelestialEclipseLabGestureController.finishedReason

    /// The camera's orbit (presentation only; the gesture controller's).
    var orbit: CelestialEclipseLabOrbit { gestures.orbit }

    /// The canvas gestures set phases, choose planets and show ticks; the preview and the orbit are presentation
    /// state.
    var gestureActions: Set<String> { ["orbit.phase", "orbit.choose", "clock.show"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(Core.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a planet through `orbit.choose`, a tick through `clock.show` (presentation only), a phase through
    /// `orbit.phase` (one undo step; the preview is dropped), a preview kept in the mirror and drawn, a reset view
    /// (the controller is already at the authored orbit), and an explanation to the mirror's message.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let drawn = lastSnapshot else { return }
        let actions: [CelestialEclipseLabGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: drawn)
        for action in actions {
            switch action {
            case let .choosePlanet(body):
                send("orbit.choose", [Double(body)], port: port)
            case let .showTick(tick):
                send("clock.show", [Double(tick)], port: port)
            case let .setPhase(body, offset):
                mirror.preview = nil
                send("orbit.phase", [Double(body), Double(offset)], port: port)
            case let .preview(body, offset):
                mirror.preview = CelestialEclipseLabPreview(body: body, offset: offset)
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
    /// the engine's `action.rule.` prefix) in ``refusalLog``; an accepted kernel action drops the pending phase.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        mirror.record(control, values, accepted: result.isAccepted, code: result.code)
        if !result.isAccepted {
            route(CelestialEclipseLabFeedbackPlan.refused(code: result.code))   // feature 466: announced and felt
            refusalLog.append(CelestialEclipseLabMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        refreshPreview()
        return result
    }

    // MARK: Teaching and progression (feature 465, R02-G17-05)

    /// Takes the core's teaching and progress state into the mirror (feature 465): the tutorial instruction, the
    /// failure explanation, the mode, the open levels with their stars, the band, the goal and the best stars; a change
    /// of the play hides the hint (the next press shows level 1).
    private func absorbProgress(_ core: CelestialEclipseLabExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        absorbFeedback(core)
        latestCore = core
        mirror.summaryCore = core
        if let shown = hintPlay, shown != core.play { clearHint() }
        mirror.tutorialText = core.tutorial == .done ? nil : core.tutorial.text
        mirror.explanation = CelestialEclipseLabFailureExplanation(play: core.play)?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        mirror.pickedLevel = min(max(mirror.pickedLevel, 1), core.progress.frontier)
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.band = core.band
        mirror.bestStars = core.progress.stars(of: core.levelNumber)
        mirror.goalLabel = CelestialEclipseLabMirror.goalText(core.play.level, certified: core.certifiedChanges)
    }

    /// Hides the hint shown and drops a search under way; the generation is raised so that search owns nothing.
    private func clearHint() {
        hintSearch?.cancel()
        hintSearch = nil
        hintGeneration += 1
        hintPlay = nil
        mirror.hintLevel = 0
        mirror.hintText = nil
    }

    /// The hint texts of levels 1 … 3 of `play` from one search (`CelestialEclipseLabHints.hint(level:play:)` at level
    /// 1): a phase-change hint gives each level's text (`CelestialEclipseLabHint.changeText`); a run or stuck hint
    /// reads the same at every level; nil when the play has no hint (won, or not under way). Runs off the main actor.
    nonisolated static func hintTexts(_ play: CelestialEclipseLabPlay) -> [String]? {
        guard let first = CelestialEclipseLabHints.hint(level: 1, play: play) else { return nil }
        guard first.kind == .change, case .phase(let body, let offset)? = first.action,
              play.level.bodies.indices.contains(body), play.phases.indices.contains(body) else {
            return [first.text, first.text, first.text]
        }
        let period: Int = play.level.bodies[body].period
        var texts: [String] = []
        for level in 1...3 {
            texts.append(CelestialEclipseLabHint.changeText(level: level, body: body, from: play.phases[body],
                                                            to: offset, period: period))
        }
        return texts
    }

    /// Shows the next hint level (1 → 2 → 3, then 3 again) for the current play; never sends an action. The search
    /// runs once per play in a detached task, never on the frame: meanwhile the hint line reads ``searchingText`` (a
    /// press during the search raises the level it will show); the result is shown only when its generation is still
    /// current, and later levels come from the cache.
    func showHint() {
        guard let core = latestCore else { return }
        let play: CelestialEclipseLabPlay = core.play
        let next: Int = hintPlay == play ? min(mirror.hintLevel + 1, 3) : 1
        if let cached = hintCache, cached.play == play {
            reveal(cached.texts, level: next, play: play)
            return
        }
        if hintSearch != nil, hintPlay == play {
            mirror.hintLevel = next   // the search for this play is running; it shows this level
            return
        }
        hintSearch?.cancel()
        hintGeneration += 1
        let generation: Int = hintGeneration
        hintPlay = play
        mirror.hintLevel = next
        mirror.hintText = Self.searchingText
        hintSearch = Task.detached(priority: .userInitiated) { [weak self] in
            let texts: [String]? = CelestialEclipseLabPresenter.hintTexts(play)
            await self?.finishSearch(texts, play: play, generation: generation)
        }
    }

    /// Takes the hint texts searched for `play` by the search of `generation`: cached and shown when that generation
    /// is still current (a stale search changes nothing, not even the handle of a newer search).
    private func finishSearch(_ texts: [String]?, play: CelestialEclipseLabPlay, generation: Int) {
        guard generation == hintGeneration, hintPlay == play else { return }
        hintSearch = nil
        hintCache = (play, texts)
        reveal(texts, level: mirror.hintLevel, play: play)
    }

    /// Shows level `level` of `texts` for `play`, or ``noHintText`` (level 0) when the play has no hint.
    private func reveal(_ texts: [String]?, level: Int, play: CelestialEclipseLabPlay) {
        hintPlay = play
        let before: (Int, String?) = (mirror.hintLevel, mirror.hintText)
        if let texts, texts.indices.contains(level - 1) {
            mirror.hintLevel = level
            mirror.hintText = texts[level - 1]
        } else {
            mirror.hintLevel = 0
            mirror.hintText = Self.noHintText
        }
        // Feature 466: a newly shown hint (or the no-hint line) is announced as `state`.
        if let text = mirror.hintText, before.0 != mirror.hintLevel || before.1 != text {
            route(CelestialEclipseLabFeedbackPlan.hint(text: text))
        }
    }

    /// Ends the tutorial of the current level (`tutorial.dismiss`).
    @discardableResult
    func dismissTutorial(port: ExperienceActionPort) -> ActionResult {
        send("tutorial.dismiss", [], port: port)
    }

    /// Plays open level `level` in campaign mode (`level.select [level]`; a closed level is refused in words).
    @discardableResult
    func selectLevel(_ level: Int, port: ExperienceActionPort) -> ActionResult {
        send("level.select", [Double(level)], port: port)
    }

    /// Plays the daily level of `date` (`mode.daily [year, month, day]`; the local calendar date by default; the core
    /// never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort,
                   date: DateComponents = CelestialEclipseLabPresenter.today()) -> ActionResult {
        send("mode.daily", Self.dateValues(date), port: port)
    }

    /// Replays the current level with the practice budget (`mode.practice`).
    @discardableResult
    func playPractice(port: ExperienceActionPort) -> ActionResult {
        send("mode.practice", [], port: port)
    }

    /// Returns to the campaign (`mode.campaign`).
    @discardableResult
    func playCampaign(port: ExperienceActionPort) -> ActionResult {
        send("mode.campaign", [], port: port)
    }

    /// The local calendar date now: Gregorian year, month and day in the current time zone.
    static func today() -> DateComponents {
        Calendar(identifier: .gregorian).dateComponents(in: .current, from: Date())
    }

    /// The values of `mode.daily` for `date`: year, month, day (0 for a missing part, which the core refuses).
    static func dateValues(_ date: DateComponents) -> [Double] {
        [Double(date.year ?? 0), Double(date.month ?? 0), Double(date.day ?? 0)]
    }

    // MARK: Feedback and sound (feature 466, R02-G17-06)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: CelestialEclipseLabFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
    }

    /// Takes a new core into the feedback and the sound, once per core (from the frame or the description): routes the
    /// plan of the change from the latest core, offers the ambient recipe when a level or mode opened or the recipe
    /// changed, and plays the audition of a newly chosen body (the play unchanged) when the sound is on. The first core
    /// only offers its recipe, so the sound never holds a placeholder.
    private func absorbFeedback(_ core: CelestialEclipseLabExperienceCore) {
        guard let previous = latestCore else {
            sound.offer(Self.recipe(core))
            return
        }
        // No early return on `previous == core`: the core's equality leaves out presentation state (the chosen body,
        // the shown tick), so a body choice compares equal; the plan of an unchanged play is `.none`.
        route(CelestialEclipseLabFeedbackPlan.after(old: previous, new: core))
        let opened: Bool = previous.levelNumber != core.levelNumber || previous.mode != core.mode
        if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
        if !opened, previous.play == core.play, previous.chosenBody != core.chosenBody, mirror.soundOn {
            sound.audition(CelestialEclipseLabAudition.of(core.play, body: core.chosenBody))
        }
    }

    /// The ambient recipe of `core`: its actions left, the quarters of its target matched and its stage.
    static func recipe(_ core: CelestialEclipseLabExperienceCore) -> AmbientLoopRecipe {
        CelestialEclipseLabSoundRecipe.recipe(play: core.play)
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
