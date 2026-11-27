// MushroomWeatherPresenter — feature 493 (R02-G20-03) T-R02G2003-006 (FR-R02G2003-003, 004, 005, 007; clarifications
// Q2, Q4, Q5). Draws the adapter's immutable snapshot with `MushroomWeatherForestScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityProfile` names, the names of
// `MushroomWeatherTier.all`), keeps a log of every tier change with its reason, stops the droplets and motes under
// Reduce Motion and caps the glow under Reduce Flashing. The humidity field never moves by time: the shown cycle is the
// adapter's presentation state (`clock.show`) and is never advanced by time; only the droplets and motes move with the
// presentation time. The tutorial of levels 1 … 3 is shown in words, as presentation, not as a kernel stage. A refused
// action is shown in words. A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only
// reads `core.snapshot`: no drawing result reaches the kernel (renderer purity). Its probes (two backdrop corners) let
// the verification runner check a frame. Modelled on `MicroscopicAuroraPresenter` (feature 483).
// Feature 494 (R02-G20-04) T-R02G2004-005 (FR-R02G2004-001 … 011): a canvas touch goes through the presenter's
// `MushroomWeatherGestureController` with the drawn snapshot (`pointer`): a tap on an empty site places a pod in the
// first free slot (`pod.place [slot, row, column]`), a pod drag previews the weather with the pod moved or removed (the
// preview of `MushroomWeatherSceneSnapshot.previewing`, presentation only, kept in the mirror) and its release sends
// one `pod.place` to the new site or one `pod.remove` off the floor; a vent tap sends `vent.set [index, open]` with the
// other state; a vertical moon drag previews the moonlight and its release sends one `moon.set [level]`; a scrubber
// drag shows cycles (`clock.show`, in any stage); a tapped pod selects its slot in the panel; two fingers orbit the
// camera and a double tap off the floor or "Reset view" (`resetView()`) returns it (presentation only; the meshes are
// rebuilt). Kernel actions are sent only while playing (the controller's rule); a gesture on a finished play says "The
// play is over: undo or go to the next level". A refused action is shown in the panel and its code, read with or
// without the engine's `action.rule.` prefix, is kept in the refusal log. Modelled on `MicroscopicAuroraPresenter`
// (feature 484).
//
// Feature 495 (R02-G20-05) T-R02G2005-005 (FR-R02G2005-001 … 005, 007; clarifications Q1 … Q5) adds teaching and
// progression to the panel: the tutorial instruction (`core.tutorial.text` until the step is `done`, replacing the
// presenter's own tutorial sentence), the hint at its current level (`showHint()`: each press raises the level
// 1 → 2 → 3; any change of the play hides it, so the next press shows level 1; one search per play through
// `MushroomWeatherHints.hint(level:play:certified:)` with the core's certified plan, run off the main actor in a
// detached task, with a generation counter so that a stale search never owns the hint state; hints never send an
// action), the failure explanation (`MushroomWeatherFailureExplanation(play:)`, shown in the panel in place of the
// mirror's short `failureText`, which stays the status line), the mode, the open levels, the level's band (of the five
// bands of 20), its goal (every colony in its band for the last K cycles of the run, and the action count that earns
// 3 stars, the certified witness's `core.certifiedActionCount`) and its best stars (`core.progress.stars(of:)`). The
// description includes them. The daily level is asked for with today's local calendar date read here
// (`playDaily(port:date:)`); the core never reads a clock. A refused `level.select` or `level.next`
// (`r02-g20.locked`: "that level is not open yet") and an impossible date (`r02-g20.date`: "that date cannot be used")
// read in words. Modelled on `MicroscopicAuroraPresenter` (feature 485).
//
// Feature 496 (R02-G20-06) T-R02G2006-005 (FR-R02G2006-001 … 006; clarifications Q1 … Q5): the presenter routes
// `MushroomWeatherFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route (`feedback`,
// injectable; the shared `ExperienceFeedback` by default) once for every new core it takes in, from the frame or the
// description, and keeps a feedback log (`feedbackLog`); refusals are shown and announced in words (`refused(code:)`;
// the panel shows exactly the plan's text, `refusalText(code:)`), and a revealed hint is announced as `state`
// (`hint(text:)`). Changing the panel's selection, drag previews, the shown cycle, the view, dismissing the tutorial
// and the Sound toggle are not announced (the controls speak their own values). The scene's lights
// (`MushroomWeatherLights`: the glow and the won look) step toward the drawn snapshot every frame by the frame clock's
// elapsed time (0.15 s fades, 0.45 s under Reduce Flashing; the first frame settles them). The ambient loop
// (`MushroomWeatherSound`) is offered the recipe of the actions left, the quarters of the colonies staying in band, the
// moonlight and the stage when the first core is taken in, when a level or mode opens and when that recipe changes; a
// change of the panel's selection (`changeSelection(_:)`: slot or site, from the buttons and the adjustable values)
// plays the selected site's audition (`MushroomWeatherAudition.of(site:placeable:)`) when the sound is on, on screen
// and active; drag previews and the chosen moonlight play none. The mirror carries the summary element's text
// (`MushroomWeatherFeedbackPlan.summaryText(core:slot:site:)`) and the sound choice (off by default; saving it is
// R02-G20-07). Presentation only. Modelled on `MicroscopicAuroraPresenter` (feature 486).
#if os(iOS)
import Foundation
import MushroomWeatherCore
import SwiftUI
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described, the shown cycle and the panel's selection.
@MainActor
@Observable
final class MushroomWeatherMirror {
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
    /// The tutorial instruction of the current step (`core.tutorial.text`, feature 495); nil once the step is `done`.
    var tutorialText: String?
    /// The shown cycle, the adapter's.
    var shownCycle = 0
    /// The play followed (a copy; never sent anywhere).
    var play: MushroomWeatherPlay?
    /// The text of the last refused change, or why a gesture did nothing, if any.
    var message: String?
    /// A pod or moon drag's preview (feature 494; presentation only): what the drag would change, nil while no drag
    /// previews.
    var preview: MushroomWeatherPreviewKind?
    /// The pod slot the panel edits (0 … slots − 1).
    var slot = 0
    /// The index of the site the panel would place on.
    var siteIndex = 0
    /// The moonlight level the panel would set (presentation only; Set moonlight spends one action).
    var chosenMoonlight = 0
    /// The hint level shown, 1 … 3; 0 while no hint is shown (feature 495; presentation only).
    var hintLevel = 0
    /// The hint shown at ``hintLevel``, ``MushroomWeatherPresenter/searchingText`` while its search runs, or
    /// ``MushroomWeatherPresenter/noHintText`` when the play has no hint; nil while no hint is shown (feature 495).
    var hintText: String?
    /// The failure explanation (`MushroomWeatherFailureExplanation`: what went wrong, then the advice), nil without a
    /// failure (feature 495).
    var explanation: String?
    /// The mode (feature 495).
    var mode: MushroomWeatherMode = .campaign
    /// The highest open level (feature 495).
    var frontier = 1
    /// The level's difficulty band, 1 … 5 (the five bands of 20; feature 495).
    var band = 1
    /// The best stars of the current level, 0 … 3 (0 while it has not been won; feature 495).
    var bestStars = 0
    /// The stars of each won level, by level number (the level picker; feature 495).
    var stars: [Int: Int] = [:]
    /// The goal in words: every colony in its band for the last K cycles and the action count that earns 3 stars
    /// (feature 495).
    var goalLabel = ""
    /// The level the picker holds, 1 … ``frontier`` (presentation only; feature 495).
    var pickedLevel = 1

    /// "Band b of 5" (feature 495).
    var bandLabel: String { "Band \(band) of 5" }

    /// "Best: s of 3 stars", or "Best: not won yet" while the level has not been won (feature 495).
    var starsLabel: String {
        bestStars > 0 ? "Best: \(bestStars) of 3 stars" : "Best: not won yet"
    }

    /// "Mode: campaign", "Mode: practice" or "Mode: daily" (feature 495).
    var modeLabel: String { "Mode: " + Self.modeName(mode) }

    /// The mode's name: campaign, practice or daily (feature 495).
    static func modeName(_ mode: MushroomWeatherMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// The picker's line for level `level`: "Level n, band b", with ", s of 3 stars" once it has been won
    /// (feature 495).
    func levelLabel(_ level: Int) -> String {
        let band: Int = MushroomWeatherProgress.band(of: level)
        if let won = stars[level] { return "Level \(level), band \(band), \(won) of 3 stars" }
        return "Level \(level), band \(band)"
    }

    /// The goal of `level` with `certified` actions in the certified plan (feature 495): "Goal: keep every colony in
    /// its band for the last K cycles of the run, then run the weather. 3 stars within C actions", K the level's
    /// required final run ("the last 1 cycle" and "1 action" in the singular).
    static func goalText(_ level: MushroomWeatherLevel, certified: Int) -> String {
        let cycles: String = level.required == 1 ? "cycle" : "cycles"
        let unit: String = certified == 1 ? "action" : "actions"
        return "Goal: keep every colony in its band for the last \(level.required) \(cycles) of the run, then run the "
            + "weather. 3 stars within \(certified) \(unit)"
    }

    /// The pod slots of the followed level (1 while no play is followed).
    var slotCount: Int { max(play?.level.podRules.slots ?? 1, 1) }

    /// The cells a pod may be placed on: the level's sites, or, on a level without sites, every floor cell no colony
    /// stands on (row-major); empty while no play is followed.
    var sites: [MushroomWeatherCell] {
        guard let level = play?.level else { return [] }
        if let sites = level.sites { return sites }
        let colonies: Set<MushroomWeatherCell> = level.colonyCells
        var cells: [MushroomWeatherCell] = []
        for index in 0..<(level.rows * level.columns) {
            let cell: MushroomWeatherCell = level.cell(at: index)
            if level.isFloor(cell) && !colonies.contains(cell) { cells.append(cell) }
        }
        return cells
    }

    /// The cycles run by the followed play's predicted run (0 while no play is followed).
    var cyclesRun: Int { play?.report.cycles ?? 0 }

    /// The moonlight of the followed arrangement (0 while no play is followed).
    var moonlight: Int { play?.arrangement.moonlight ?? 0 }

    /// The vents' states of the followed arrangement, by vent index (empty while no play is followed).
    var ventsOpen: [Bool] { play?.arrangement.ventsOpen ?? [] }

    /// `value` clamped to the cycles 0 … cycles run.
    func clampedCycle(_ value: Int) -> Int { min(max(value, 0), cyclesRun) }

    /// `value` clamped to the moonlight levels 0 … 3.
    func clampedMoonlight(_ value: Int) -> Int {
        let levels: ClosedRange<Int> = MushroomWeatherLevel.moonlightLevels
        return min(max(value, levels.lowerBound), levels.upperBound)
    }

    /// The slot the panel edits, clamped to the level's slots.
    var selectedSlot: Int { min(max(slot, 0), slotCount - 1) }

    /// The site the panel would place on, or nil without sites.
    var selectedSite: MushroomWeatherCell? {
        let sites: [MushroomWeatherCell] = sites
        guard !sites.isEmpty else { return nil }
        return sites[min(max(siteIndex, 0), sites.count - 1)]
    }

    /// The pods in words.
    var podsLabel: String {
        guard let play else { return "no pods" }
        var parts: [String] = []
        for slot in play.arrangement.pods.indices {
            let grownAt: Int? = slot < play.report.grownAt.count ? play.report.grownAt[slot] : nil
            parts.append(play.level.podDescription(slot, cell: play.arrangement.pods[slot], grownAt: grownAt))
        }
        return parts.joined(separator: "; ")
    }

    /// Vent `index` in words ("vent 1 at row 2, column 4, open"), or "no vent".
    func ventLabel(_ index: Int) -> String {
        guard let play, index < play.level.vents.count, index < ventsOpen.count else { return "no vent" }
        return play.level.ventDescription(index, open: ventsOpen[index])
    }

    /// The pod the panel would place, in words.
    var selectionLabel: String {
        guard let site = selectedSite else { return "no site" }
        return "pod \(selectedSlot + 1) at " + MushroomWeatherLevel.cellWords(site)
    }

    /// The moonlight in words.
    var moonLabel: String { "moonlight \(moonlight) of \(MushroomWeatherLevel.moonlightLevels.upperBound)" }
    /// The chosen moonlight level in words.
    var chosenMoonLabel: String {
        "set to \(clampedMoonlight(chosenMoonlight)) of \(MushroomWeatherLevel.moonlightLevels.upperBound)"
    }

    /// The shown cycle in words.
    var cycleLabel: String { "cycle \(clampedCycle(shownCycle)) of \(cyclesRun)" }

    /// Takes the new `play` and presentation.
    func follow(_ play: MushroomWeatherPlay, shownCycle: Int) {
        self.play = play
        self.shownCycle = shownCycle
    }

    /// A failure in words, naming what the kernel's reason names (the level's failure description, first letter in
    /// upper case, with a full stop); nil without a failure.
    static func failureText(_ failure: MushroomWeatherFailure?, level: MushroomWeatherLevel) -> String? {
        guard let failure else { return nil }
        return level.failureDescription(failure).capitalizedFirst + "."
    }

    /// The engine's prefix of rule codes (feature 494: codes are read with or without it).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix``.
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// The panel line of a refusal: since feature 496 exactly the feedback plan's sentence
    /// (`MushroomWeatherFeedbackPlan.refusalText(code:)`, clarification Q1), the words that are announced.
    static func refusalMessage(code: String) -> String {
        MushroomWeatherFeedbackPlan.refusalText(code: code)
    }

    /// Records the result of sending a control (feature 494): a refusal is shown in words; an accepted action clears
    /// the message.
    func record(accepted: Bool, code: String) {
        message = accepted ? nil : Self.refusalMessage(code: code)
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``. Since feature 496
    /// it forwards to `MushroomWeatherFeedbackPlan.refusalText(code:)` (clarification Q1's sentences, e.g. "That level
    /// is not open yet.").
    static func refusalText(code: String) -> String {
        MushroomWeatherFeedbackPlan.refusalText(code: code)
    }

    /// The latest core taken in, for the summary element (feature 496); nil before the first.
    var summaryCore: MushroomWeatherExperienceCore?
    /// Whether the sound is on (feature 496; off by default; presentation only, saving it is R02-G20-07).
    var soundOn = false

    /// The index of the selected site among the level's own sites, for the summary element (feature 496): the clamped
    /// site index on a level with sites; nil on a level without sites (any free floor cell), whose cells the summary
    /// does not name.
    var summarySiteIndex: Int? {
        guard let sites = play?.level.sites, !sites.isEmpty else { return nil }
        return min(max(siteIndex, 0), sites.count - 1)
    }

    /// The index of the selected site among ``sites`` (clamped), for the audition (feature 496); 0 without sites.
    var selectedSiteIndex: Int {
        let count: Int = sites.count
        guard count > 0 else { return 0 }
        return min(max(siteIndex, 0), count - 1)
    }

    /// Whether the selected site can take a pod (feature 496, clarification Q4): a site no pod holds while a slot is
    /// free; false without a site or a play.
    var selectedPlaceable: Bool {
        guard let site = selectedSite, let play else { return false }
        let pods: [MushroomWeatherCell?] = play.arrangement.pods
        return !pods.contains(site) && pods.contains(nil)
    }

    /// The selected slot's pod in words (feature 496; Remove's value): "pod n at row r, column c, grown at cycle t",
    /// "pod n empty", or "no pods" while no play is followed.
    var selectedPodLabel: String {
        guard let play else { return "no pods" }
        let slot: Int = selectedSlot
        guard slot < play.arrangement.pods.count else { return "pod \(slot + 1) empty" }
        let grownAt: Int? = slot < play.report.grownAt.count ? play.report.grownAt[slot] : nil
        return play.level.podDescription(slot, cell: play.arrangement.pods[slot], grownAt: grownAt)
    }

    /// The chosen moonlight in words (feature 496; the adjustable moonlight's value): "moonlight l of 3".
    var chosenMoonValue: String {
        "moonlight \(clampedMoonlight(chosenMoonlight)) of \(MushroomWeatherLevel.moonlightLevels.upperBound)"
    }

    /// The summary element's text (feature 496): `MushroomWeatherFeedbackPlan.summaryText(core:slot:site:)` of the
    /// latest core and the panel's selection; empty before the first core.
    var summary: String {
        guard let core = summaryCore else { return "" }
        return MushroomWeatherFeedbackPlan.summaryText(core: core, slot: selectedSlot, site: summarySiteIndex)
    }
}

private extension String {
    /// The string with its first letter in upper case.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct MushroomWeatherTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Mushroom Weather.
@MainActor
final class MushroomWeatherPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = MushroomWeatherExperienceCore

    /// Whether Reduce Motion is on (the droplets and motes stop).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = MushroomWeatherMirror()
    /// The GL scene.
    let scene = MushroomWeatherForestScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G2003-004).
    private(set) var tierLog: [MushroomWeatherTierChange] = []
    /// The last snapshot drawn (tests, the description and the gestures), with the drawn preview applied.
    private(set) var lastSnapshot: MushroomWeatherSceneSnapshot?
    /// The core's snapshot last drawn, without the preview, and its level (feature 494).
    private var lastBase: (snapshot: MushroomWeatherSceneSnapshot, level: MushroomWeatherLevel)?
    /// The gesture controller (feature 494): site, pod, vent and moon gestures, the scrubber, double taps and orbits.
    private(set) var gestures = MushroomWeatherGestureController()
    /// The bare codes of refused actions, oldest first, at most ``refusalLogLimit`` (feature 494).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64
    /// The feedback route of announcements and haptics (feature 496; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first (feature 496; tests and diagnostics).
    private(set) var feedbackLog: [MushroomWeatherFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 496).
    private(set) var lights: MushroomWeatherLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient loop and the selected site's audition (feature 496).
    let sound: MushroomWeatherSound
    /// The latest core seen (feature 495): hints, the daily date and the progress lines read it.
    private(set) var latestCore: MushroomWeatherExperienceCore?
    /// The play the shown hint belongs to; nil while no hint is shown (feature 495).
    private var hintPlay: MushroomWeatherPlay?
    /// The hint texts of levels 1 … 3 searched for a play (nil texts: the play has no hint), one search per play
    /// (feature 495).
    private var hintCache: (play: MushroomWeatherPlay, texts: [String]?)?
    /// The search under way, off the main actor, for ``hintPlay`` (feature 495); tests may await its end.
    private(set) var hintSearch: Task<Void, Never>?
    /// The hint generation (feature 495): raised by every new search and every hidden hint; a search whose generation
    /// is no longer current owns nothing.
    private(set) var hintGeneration = 0
    /// What the hint line shows while the search runs (feature 495).
    static let searchingText = "Finding a hint…"
    /// What the hint line shows when the play has no hint (won, or not under way; feature 495).
    static let noHintText = "No hint now: the level is not being played."

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedMotion = reduceMotion
        scene.reducedFlash = reduceFlashing
        lights = MushroomWeatherLights(reducedFlash: reduceFlashing)
        sound = MushroomWeatherSound(recipe: MushroomWeatherSoundRecipe.recipe(rootStep: 0, quarters: 0, moonlight: 0,
                                                                              stage: .loading))
    }

    /// The tests' seam: before `setup`, replaces the forest program's fragment source with one that does not compile.
    func breakForestShader() {
        scene.forestFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the names of the Core's `qualityProfile` (`level-0` … `level-2`, the
    /// names of `MushroomWeatherTier.all`).
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(MushroomWeatherTier.of(tier).name) }
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
    private func follow(_ core: MushroomWeatherExperienceCore) {
        if mirror.play != core.play || mirror.shownCycle != core.shownCycle {
            mirror.follow(core.play, shownCycle: core.shownCycle)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: MushroomWeatherExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = MushroomWeatherTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(MushroomWeatherTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        if latestCore != core {
            absorbFeedback(core)
            absorbProgress(core)
        }
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let base: MushroomWeatherSceneSnapshot = core.snapshot(time: time)
        lastBase = (snapshot: base, level: core.play.level)
        let snapshot: MushroomWeatherSceneSnapshot = presented(base, level: core.play.level)
        lastSnapshot = snapshot
        scene.orbit = gestures.orbit
        // The lights settle on the very first frame only; every later change, a level change included, fades, stepped
        // by the frame clock (feature 496).
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the floor, the gauges,
    /// the run bars and the actions bars (the camera fits the scene's box inside a 5 % margin), are `dark` (the
    /// midnight backdrop) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: MushroomWeatherExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: MushroomWeatherExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        absorbFeedback(core)
        absorbProgress(core)
        mirror.summaryCore = core
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        let siteWords: String = level.sites.map { "\($0.count) pod sites" } ?? "pods on any free floor cell"
        mirror.targetLabel = "Level: a floor of \(level.rows) by \(level.columns) cells, \(level.colonies.count) "
            + "colonies, \(level.podRules.slots) pods, " + siteWords + ", \(level.vents.count) vents, "
            + "\(level.length) cycles per run"
        let measure: String = level.progressDescription(report: play.report, arrangement: play.arrangement,
                                                        actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Mushroom Weather level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every colony ended the run in its band."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = MushroomWeatherMirror.failureText(play.failure, level: level) ?? "The run failed."
            text += reason
            // Since feature 495 the failure explanation too (what went wrong, then the advice).
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
        text += " " + teachingText()
        return text
    }

    /// The teaching and progress sentences of the description (feature 495): the mode, the band, the goal, the best
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

    /// `snapshot` with the mirror's drag preview applied (feature 494; presentation only).
    private func presented(_ snapshot: MushroomWeatherSceneSnapshot,
                           level: MushroomWeatherLevel) -> MushroomWeatherSceneSnapshot {
        guard let preview = mirror.preview else { return snapshot }
        return snapshot.previewing(preview, level: level)
    }

    /// Re-applies the mirror's preview to the last snapshot, so tests and the next gesture read it.
    private func refreshPreview() {
        guard let base = lastBase else { return }
        lastSnapshot = presented(base.snapshot, level: base.level)
    }

    /// The control panel: "Reset view" (feature 494); every kernel button sends through ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MushroomWeatherControls(port: port, mirror: mirror, presenter: self,
                                        sendAction: { [weak self] control, values in
                                            self?.send(control, values, port: port)
                                        },
                                        resetView: { [weak self] in self?.resetView() }))
    }

    /// The camera's orbit (presentation only; the gesture controller's).
    var orbit: MushroomWeatherViewOrbit { gestures.orbit }

    /// The canvas gestures place, move and remove pods, open and shut vents, set the moonlight and show cycles; the
    /// preview and the orbit are presentation state.
    var gestureActions: Set<String> { ["pod.place", "pod.remove", "vent.set", "moon.set", "clock.show"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(Core.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a placement or move through `pod.place [slot, row, column]` and a removal through `pod.remove [slot]`
    /// (one action each; the preview is dropped), a vent through `vent.set [index, open]`, the moonlight through
    /// `moon.set [level]` (the preview is dropped and the panel's chosen level follows), a cycle through `clock.show
    /// [cycle]` (presentation only), a preview kept in the mirror and drawn, a slot selected in the panel, a reset view
    /// (the controller is already at the authored orbit) and an explanation to the mirror's message.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let drawn = lastSnapshot else { return }
        let actions: [MushroomWeatherGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: drawn)
        for action in actions {
            switch action {
            case let .place(slot, cell), let .move(slot, cell):
                mirror.preview = nil
                send("pod.place", [Double(slot), Double(cell.row), Double(cell.column)], port: port)
            case let .remove(slot):
                mirror.preview = nil
                send("pod.remove", [Double(slot)], port: port)
            case let .setVent(index, open):
                send("vent.set", [Double(index), open ? 1 : 0], port: port)
            case let .setMoonlight(level):
                mirror.preview = nil
                mirror.chosenMoonlight = mirror.clampedMoonlight(level)
                send("moon.set", [Double(level)], port: port)
            case let .showCycle(cycle):
                send("clock.show", [Double(cycle)], port: port)
            case let .preview(kind):
                mirror.preview = kind
            case .clearPreview:
                mirror.preview = nil
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

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its bare code in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        mirror.record(accepted: result.isAccepted, code: result.code)
        if !result.isAccepted {
            route(MushroomWeatherFeedbackPlan.refused(code: result.code))   // feature 496: announced and felt
            refusalLog.append(MushroomWeatherMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        refreshPreview()
        return result
    }

    // MARK: Teaching and progression (feature 495, R02-G20-05)

    /// Takes the core's teaching and progress state into the mirror (feature 495): the tutorial instruction, the
    /// failure explanation, the mode, the open levels with their stars, the band, the goal and the best stars; a change
    /// of the play hides the hint (the next press shows level 1).
    private func absorbProgress(_ core: MushroomWeatherExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        latestCore = core
        if let shown = hintPlay, shown != core.play { clearHint() }
        mirror.tutorialText = core.tutorial == .done ? nil : core.tutorial.text
        mirror.explanation = MushroomWeatherFailureExplanation(play: core.play)?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        mirror.pickedLevel = min(max(mirror.pickedLevel, 1), core.progress.frontier)
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.band = core.band
        mirror.bestStars = core.progress.stars(of: core.levelNumber)
        mirror.goalLabel = MushroomWeatherMirror.goalText(core.play.level, certified: core.certifiedActionCount)
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

    /// The hint texts of levels 1 … 3 of `play` from one search (`MushroomWeatherHints.hint(level:play:certified:)` at
    /// level 1): a pod, vent or moonlight hint gives each level's text
    /// (`MushroomWeatherHint.actionText(level:action:arrangement:)` from the play's arrangement); a run, stuck or
    /// failed hint reads the same at every level; nil when the play has no hint (won, or not under way). Runs off the
    /// main actor.
    nonisolated static func hintTexts(_ play: MushroomWeatherPlay,
                                      certified: MushroomWeatherPlan?) -> [String]? {
        guard let first = MushroomWeatherHints.hint(level: 1, play: play, certified: certified) else { return nil }
        let changes: Bool = first.kind == .pod || first.kind == .vent || first.kind == .moonlight
        guard changes, let action = first.action else {
            return [first.text, first.text, first.text]
        }
        var texts: [String] = []
        for level in 1...3 {
            let text: String? = MushroomWeatherHint.actionText(level: level, action: action,
                                                               arrangement: play.arrangement)
            texts.append(text ?? first.text)
        }
        return texts
    }

    /// Shows the next hint level (1 → 2 → 3, then 3 again) for the current play; never sends an action. The search
    /// runs once per play in a detached task, never on the frame: meanwhile the hint line reads ``searchingText`` (a
    /// press during the search raises the level it will show); the result is shown only when its generation is still
    /// current, and later levels come from the cache.
    func showHint() {
        guard let core = latestCore else { return }
        let play: MushroomWeatherPlay = core.play
        let certified: MushroomWeatherPlan = core.certifiedPlan
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
            let texts: [String]? = MushroomWeatherPresenter.hintTexts(play, certified: certified)
            await self?.finishSearch(texts, play: play, generation: generation)
        }
    }

    /// Takes the hint texts searched for `play` by the search of `generation`: cached and shown when that generation is
    /// still current (a stale search changes nothing, not even the handle of a newer search).
    private func finishSearch(_ texts: [String]?, play: MushroomWeatherPlay, generation: Int) {
        guard generation == hintGeneration, hintPlay == play else { return }
        hintSearch = nil
        hintCache = (play, texts)
        reveal(texts, level: mirror.hintLevel, play: play)
    }

    /// Shows level `level` of `texts` for `play`, or ``noHintText`` (level 0) when the play has no hint.
    private func reveal(_ texts: [String]?, level: Int, play: MushroomWeatherPlay) {
        hintPlay = play
        let before: (Int, String?) = (mirror.hintLevel, mirror.hintText)
        if let texts, texts.indices.contains(level - 1) {
            mirror.hintLevel = level
            mirror.hintText = texts[level - 1]
        } else {
            mirror.hintLevel = 0
            mirror.hintText = Self.noHintText
        }
        // Feature 496: a newly shown hint (or the no-hint line) is announced as `state`.
        if let text = mirror.hintText, before.0 != mirror.hintLevel || before.1 != text {
            route(MushroomWeatherFeedbackPlan.hint(text: text))
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
                   date: DateComponents = MushroomWeatherPresenter.today()) -> ActionResult {
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

    // MARK: Feedback and sound (feature 496, R02-G20-06)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: MushroomWeatherFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
    }

    /// Takes a new core into the feedback and the sound, once per core (from the frame or the description): routes the
    /// plan of the change from the latest core and offers the ambient recipe when a level or mode opened or the recipe
    /// changed. The first core only offers its recipe, so the sound never holds a placeholder.
    private func absorbFeedback(_ core: MushroomWeatherExperienceCore) {
        guard let previous = latestCore else {
            sound.offer(Self.recipe(core))
            return
        }
        route(MushroomWeatherFeedbackPlan.after(old: previous, new: core))
        let opened: Bool = previous.levelNumber != core.levelNumber || previous.mode != core.mode
        if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
    }

    /// The ambient recipe of `core`: its actions left, the quarters of the colonies staying in band, its moonlight and
    /// its stage.
    static func recipe(_ core: MushroomWeatherExperienceCore) -> AmbientLoopRecipe {
        MushroomWeatherSoundRecipe.recipe(play: core.play)
    }

    /// The audition of the panel's selected site: `MushroomWeatherAudition.of(site:placeable:)` of the selected site's
    /// index and whether a pod can go there.
    var selectedAudition: MushroomWeatherAudition {
        MushroomWeatherAudition.of(site: mirror.selectedSiteIndex, placeable: mirror.selectedPlaceable)
    }

    /// Changes the panel's selection (slot or site; presentation only; the buttons and the adjustable values); when
    /// the selection changed (clarification Q4: once per change of slot or site) and the sound is on, plays the
    /// selected site's audition (feature 496). Drag previews never come here.
    func changeSelection(_ change: (MushroomWeatherMirror) -> Void) {
        let before: [Int] = [mirror.slot, mirror.siteIndex]
        change(mirror)
        let after: [Int] = [mirror.slot, mirror.siteIndex]
        guard mirror.soundOn, after != before else { return }
        sound.audition(selectedAudition)
    }

    /// Turns the sound on or off (presentation only); turning it on plays the recipe of the current play.
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
