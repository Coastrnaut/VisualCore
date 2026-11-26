// MicroscopicAuroraPresenter — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-003, 004, 005, 007; clarifications
// Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `MicroscopicAuroraDishScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`), keeps a log of every
// tier change with its reason, and caps the glow under Reduce Flashing. Nothing moves by time: the shown tick is the
// adapter's presentation state (`clock.show`) and is never advanced by time. The tutorial of levels 1 … 3 is shown in
// words, as presentation, not as a kernel stage. A refused action is shown in words. A memory warning releases the GPU
// objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel
// (renderer purity). Its probes (two backdrop corners) let the verification runner check a frame.
// Feature 484 (R02-G19-04) T-R02G1904-005 (FR-R02G1904-001 … 010): a canvas touch goes through the presenter's
// `MicroscopicAuroraGestureController` with the drawn snapshot (`pointer`): a tap on an empty site places a well with the
// panel's strength and sense in the first free slot (`well.place`), a well drag previews the swim with the well moved
// (the preview of `MicroscopicAuroraSceneSnapshot.previewing`, presentation only, kept in the mirror) and its release
// sends one `well.place` to the new site or one `well.remove` off the dish; a scrubber drag shows ticks (`clock.show`, in
// any stage); a tap on the dish field toggles the freeze (`toggleFreeze()`, presentation only: the committed swim stays
// drawn and only the gauges preview); two fingers orbit the camera and a double tap outside the dish or "Reset view"
// (`resetView()`) returns it (presentation only; the meshes are rebuilt). A refused action is shown in the panel and its
// code, read with or without the engine's `action.rule.` prefix, is kept in the refusal log.
//
// Feature 485 (R02-G19-05) T-R02G1905-005 (FR-R02G1905-001 … 005, 007; clarifications Q1 … Q5) adds teaching and
// progression to the panel: the tutorial instruction (`core.tutorial.text` until the step is `done`, replacing the
// presenter's own tutorial sentence), the hint at its current level (`showHint()`: each press raises the level
// 1 → 2 → 3; any change of the play hides it, so the next press shows level 1; one search per play through
// `MicroscopicAuroraHints.hint(level:play:certified:)` with the core's certified wells, run off the main actor in a
// detached task, with a generation counter so that a stale search never owns the hint state; hints never send an
// action), the failure explanation (`MicroscopicAuroraFailureExplanation(play:)`, shown in the panel in place of the
// mirror's short `failureText`, which stays the status line), the mode, the open levels, the level's band (of the five
// bands of 20), its goal (the stencil in words and the certified placement count that earns 3 stars,
// `core.certifiedPlacements`) and its best stars (`core.progress.stars(of:)`). The description includes them. The daily
// level is asked for with today's local calendar date read here (`playDaily(port:date:)`); the core never reads a
// clock. A refused `level.select` or `level.next` (`r02-g19.locked`) and an impossible date (`r02-g19.date`) read in
// words.
//
// Feature 486 (R02-G19-06) T-R02G1906-005 (FR-R02G1906-001 … 006; clarifications Q1 … Q5): the presenter routes
// `MicroscopicAuroraFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route
// (`feedback`, injectable; the shared `ExperienceFeedback` by default) once for every new core it takes in, from the
// frame or the description, and keeps a feedback log (`feedbackLog`); refusals are shown and announced in words
// (`refused(code:)`; the panel shows exactly the plan's text), and a revealed hint is announced as `state`. Changing the
// panel's selection, drag previews, the shown tick, the freeze, the view, dismissing the tutorial and the Sound toggle
// are not announced (the controls speak their own values). The scene's lights (`MicroscopicAuroraLights`: the glow and
// the won look) step toward the drawn snapshot every frame by the frame clock's elapsed time (0.15 s fades, 0.45 s
// under Reduce Flashing; the first frame settles them). The ambient loop (`MicroscopicAuroraSound`) is offered the
// recipe of the actions left, the quarters of the needed stencil cells lit and the stage when the first core is taken
// in, when a level or mode opens and when that recipe changes; a change of the panel's selection
// (`changeSelection(_:)`: slot, site, strength and sense, from the buttons and the adjustable values) plays the
// selected well's audition (`MicroscopicAuroraAudition.of(_:placeable:)`) when the sound is on, on screen and active;
// drag previews play none. The mirror carries the summary element's text
// (`MicroscopicAuroraFeedbackPlan.summaryText(core:selected:slot:)`) and the sound choice (off by default).
// Presentation only.
//
// Feature 487 (R02-G19-07) T-R02G1907-006 (FR-R02G1907-003, 004, 007; clarifications Q2, Q4, Q5): the mirror carries
// whether a verified replay exists for the level (`replayAvailable`: a verified result with a trace, outside replay),
// whether a replay runs and its position (`replaying`, `replayPosition` = the trace actions played, `replayLength` =
// the trace's actions, the play included); `startReplay`, `stepReplay` and `stopReplay` send `replay.start [level]`,
// `replay.step` and `replay.stop` (a refusal, `r02-g19.no-replay`, `r02-g19.replay-end` or `r02-g19.replay`, is shown
// and announced in the plan's words); the Sound toggle saves the choice through `settings.sound [0/1]`
// (`saveSound(on:port:)`), and the restored choice (`core.soundOn`) is applied when the experience opens (the first
// core taken in) and whenever it changes; the results a restore dropped (`core.reconciliationDropped`) are announced
// once per presenter as `state` ("n saved results could not be checked and were removed.", "1 saved result could not
// be checked and was removed.").
#if os(iOS)
import Foundation
import MicroscopicAuroraCore
import SwiftUI
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described, the shown tick and the panel's selection.
@MainActor
@Observable
final class MicroscopicAuroraMirror {
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
    /// The tutorial instruction of the current step (`core.tutorial.text`, feature 485); nil once the step is `done`.
    var tutorialText: String?
    /// The shown tick, the adapter's.
    var shownTick = 0
    /// The play followed (a copy; never sent anywhere).
    var play: MicroscopicAuroraPlay?
    /// The text of the last refused change, or why a gesture did nothing, if any.
    var message: String?
    /// A well drag's preview (feature 484; presentation only): the slot and its target, nil while no drag previews.
    var preview: (slot: Int, target: MicroscopicAuroraPreviewTarget)?
    /// Whether the freeze is on (feature 484; presentation only): the committed swim stays drawn under a preview.
    var frozen = false
    /// The hint level shown, 1 … 3; 0 while no hint is shown (feature 485; presentation only).
    var hintLevel = 0
    /// The hint shown at ``hintLevel``, ``MicroscopicAuroraPresenter/searchingText`` while its search runs, or
    /// ``MicroscopicAuroraPresenter/noHintText`` when the play has no hint; nil while no hint is shown (feature 485).
    var hintText: String?
    /// The failure explanation (`MicroscopicAuroraFailureExplanation`: what went wrong, then the advice), nil without
    /// a failure (feature 485).
    var explanation: String?
    /// The mode (feature 485).
    var mode: MicroscopicAuroraMode = .campaign
    /// The highest open level (feature 485).
    var frontier = 1
    /// The level's difficulty band, 1 … 5 (the five bands of 20; feature 485).
    var band = 1
    /// The best stars of the current level, 0 … 3 (0 while it has not been won; feature 485).
    var bestStars = 0
    /// The stars of each won level, by level number (the level picker; feature 485).
    var stars: [Int: Int] = [:]
    /// The goal in words: the stencil and the certified placement count that earns 3 stars (feature 485).
    var goalLabel = ""
    /// The level the picker holds, 1 … ``frontier`` (presentation only; feature 485).
    var pickedLevel = 1

    /// "Band b of 5" (feature 485).
    var bandLabel: String { "Band \(band) of 5" }

    /// "Best: s of 3 stars", or "Best: not won yet" while the level has not been won (feature 485).
    var starsLabel: String {
        bestStars > 0 ? "Best: \(bestStars) of 3 stars" : "Best: not won yet"
    }

    /// "Mode: campaign", "Mode: practice" or "Mode: daily" (feature 485).
    var modeLabel: String { "Mode: " + Self.modeName(mode) }

    /// The mode's name: campaign, practice or daily (feature 485).
    static func modeName(_ mode: MicroscopicAuroraMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"   // feature 487
        }
    }

    /// The picker's line for level `level`: "Level n, band b", with ", s of 3 stars" once it has been won
    /// (feature 485).
    func levelLabel(_ level: Int) -> String {
        let band: Int = MicroscopicAuroraProgress.band(of: level)
        if let won = stars[level] { return "Level \(level), band \(band), \(won) of 3 stars" }
        return "Level \(level), band \(band)"
    }

    /// The goal of `level` with `certified` placements in the certified plan (feature 485): "Goal: light at least L of
    /// the S stencil cells as one joined pattern, keeping a group of at least G swimmers, then play the swim. 3 stars
    /// within C actions" ("1 action" singular), L the cells the coverage needs.
    static func goalText(_ level: MicroscopicAuroraLevel, certified: Int) -> String {
        let needed: Int = MicroscopicAuroraDish.neededCells(stencil: level.stencil.count, required: level.coverage)
        let unit: String = certified == 1 ? "action" : "actions"
        return "Goal: light at least \(needed) of the \(level.stencil.count) stencil cells as one joined pattern, "
            + "keeping a group of at least \(level.coherence) swimmers, then play the swim. 3 stars within "
            + "\(certified) \(unit)"
    }
    /// The slot the panel edits (0 … 2).
    var slot = 0
    /// The index of the site the panel would place on.
    var siteIndex = 0
    /// The strength the panel would place (1 … 4).
    var strength = 2
    /// Whether the panel would place a counterclockwise well.
    var counterclockwise = true

    /// The level's sites (empty while no play is followed).
    var sites: [MicroscopicAuroraCell] { play?.level.sites ?? [] }
    /// The ticks swum by the followed play's predicted swim (0 while no play is followed).
    var ticksSwum: Int { play?.report.ticks ?? 0 }

    /// `value` clamped to the ticks 0 … ticks swum.
    func clampedTick(_ value: Int) -> Int { min(max(value, 0), ticksSwum) }

    /// The site the panel would place on, or nil without sites.
    var selectedSite: MicroscopicAuroraCell? {
        guard !sites.isEmpty else { return nil }
        return sites[min(max(siteIndex, 0), sites.count - 1)]
    }

    /// The wells in words.
    var wellsLabel: String {
        guard let play else { return "no wells" }
        var parts: [String] = []
        for slot in play.wells.indices { parts.append(play.level.wellDescription(slot, well: play.wells[slot])) }
        return parts.joined(separator: "; ")
    }

    /// The well the panel would place, in words.
    var selectionLabel: String {
        guard let site = selectedSite else { return "no site" }
        return "well \(slot + 1) at " + MicroscopicAuroraLevel.cellWords(site) + ", strength \(strength), "
            + (counterclockwise ? "counterclockwise" : "clockwise")
    }

    /// The shown tick in words.
    var tickLabel: String { "tick \(clampedTick(shownTick)) of \(ticksSwum)" }

    /// Takes the new `play` and presentation.
    func follow(_ play: MicroscopicAuroraPlay, shownTick: Int) {
        self.play = play
        self.shownTick = shownTick
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: MicroscopicAuroraFailure?) -> String? {
        switch failure {
        case let .exit(swimmer, tick)?: "Swimmer \(swimmer + 1) left the dish at tick \(tick)."
        case let .coherence(tick, group)?: "The swarm split at tick \(tick): its largest group had \(group) swimmers."
        case let .coverage(lit, needed)?: "Only \(lit) stencil cells were lit; \(needed) were needed."
        case let .connectedness(cell)?: MicroscopicAuroraLevel.cellWords(cell).capitalizedFirst
            + " is not joined to the pattern."
        case nil: nil
        }
    }

    /// The engine's prefix of rule codes (feature 484: codes are read with or without it).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix``.
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// The panel line of a refusal: since feature 486 exactly the feedback plan's sentence
    /// (`MicroscopicAuroraFeedbackPlan.refusalText(code:)`, clarification Q1), the words that are announced.
    static func refusalMessage(code: String) -> String {
        MicroscopicAuroraFeedbackPlan.refusalText(code: code)
    }

    /// Records the result of sending a control (feature 484): a refusal is shown in words; an accepted action clears
    /// the message.
    func record(accepted: Bool, code: String) {
        message = accepted ? nil : Self.refusalMessage(code: code)
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``. Since feature 486
    /// it forwards to `MicroscopicAuroraFeedbackPlan.refusalText(code:)` (clarification Q1's sentences, e.g. "That level
    /// is not open yet.").
    static func refusalText(code: String) -> String {
        MicroscopicAuroraFeedbackPlan.refusalText(code: code)
    }

    /// The latest core taken in, for the summary element (feature 486); nil before the first.
    var summaryCore: MicroscopicAuroraExperienceCore?
    /// Whether the sound is on (feature 486; off by default; since feature 487 the core's saved choice, `soundOn`).
    var soundOn = false
    /// Whether the current level has a verified solution to replay (feature 487).
    var replayAvailable = false
    /// Whether a replay is running (feature 487).
    var replaying = false
    /// The trace actions of the running replay played so far (0 when no replay runs; feature 487).
    var replayPosition = 0
    /// The actions of the running replay's trace, the play included (0 when no replay runs; feature 487).
    var replayLength = 0

    /// The panel's selected well: the selected site with the selected strength and sense; nil without sites
    /// (feature 486).
    var selectedWell: MicroscopicAuroraWell? {
        guard let site = selectedSite else { return nil }
        return MicroscopicAuroraWell(cell: site, strength: strength,
                                     sense: counterclockwise ? .counterclockwise : .clockwise)
    }

    /// Whether the selected well can be placed: a site no other slot's well holds (feature 486).
    var selectedPlaceable: Bool {
        guard let well = selectedWell, let play else { return false }
        for (index, other) in play.wells.enumerated() where index != slot {
            if other?.cell == well.cell { return false }
        }
        return true
    }

    /// The summary element's text (feature 486): `MicroscopicAuroraFeedbackPlan.summaryText(core:selected:slot:)` of the
    /// latest core and the panel's selection.
    var summary: String {
        guard let core = summaryCore else { return "" }
        return MicroscopicAuroraFeedbackPlan.summaryText(core: core, selected: selectedWell, slot: slot)
    }
}

private extension String {
    /// The string with its first letter in upper case.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct MicroscopicAuroraTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Microscopic Aurora.
@MainActor
final class MicroscopicAuroraPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = MicroscopicAuroraExperienceCore

    /// Whether Reduce Motion is on (the scene is still already).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = MicroscopicAuroraMirror()
    /// The GL scene.
    let scene = MicroscopicAuroraDishScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1903-004).
    private(set) var tierLog: [MicroscopicAuroraTierChange] = []
    /// The last snapshot drawn (tests, the description and the gestures), with the drawn preview and freeze applied.
    private(set) var lastSnapshot: MicroscopicAuroraSceneSnapshot?
    /// The core's snapshot last drawn, without the preview or the freeze, and its level (feature 484).
    private var lastBase: (snapshot: MicroscopicAuroraSceneSnapshot, level: MicroscopicAuroraLevel)?
    /// The gesture controller (feature 484): site taps, well drags, the scrubber, the freeze, double taps and the orbit.
    private(set) var gestures = MicroscopicAuroraGestureController()
    /// The bare codes of refused actions, oldest first, at most ``refusalLogLimit`` (feature 484).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64
    /// The feedback route of announcements and haptics (feature 486; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first (feature 486; tests and diagnostics).
    private(set) var feedbackLog: [MicroscopicAuroraFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 486).
    private(set) var lights: MicroscopicAuroraLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient loop and the selected well's audition (feature 486).
    let sound: MicroscopicAuroraSound
    /// The latest core seen (feature 485): hints, the daily date and the progress lines read it.
    private(set) var latestCore: MicroscopicAuroraExperienceCore?
    /// The play the shown hint belongs to; nil while no hint is shown (feature 485).
    private var hintPlay: MicroscopicAuroraPlay?
    /// The hint texts of levels 1 … 3 searched for a play (nil texts: the play has no hint), one search per play
    /// (feature 485).
    private var hintCache: (play: MicroscopicAuroraPlay, texts: [String]?)?
    /// The search under way, off the main actor, for ``hintPlay`` (feature 485); tests may await its end.
    private(set) var hintSearch: Task<Void, Never>?
    /// The hint generation (feature 485): raised by every new search and every hidden hint; a search whose generation
    /// is no longer current owns nothing.
    private(set) var hintGeneration = 0
    /// What the hint line shows while the search runs (feature 485).
    static let searchingText = "Finding a hint…"
    /// What the hint line shows when the play has no hint (won, or not under way; feature 485).
    static let noHintText = "No hint now: the level is not being played."

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        lights = MicroscopicAuroraLights(reducedFlash: reduceFlashing)
        sound = MicroscopicAuroraSound(recipe: MicroscopicAuroraSoundRecipe.recipe(rootStep: 0, quarters: 0,
                                                                                  stage: .loading))
    }

    /// The tests' seam: before `setup`, replaces the dish program's fragment source with one that does not compile.
    func breakDishShader() {
        scene.dishFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the Core's `qualityTiers` (`level-0` … `level-2`).
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(MicroscopicAuroraTier.of(tier).name) }
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
    private func follow(_ core: MicroscopicAuroraExperienceCore) {
        if mirror.play != core.play || mirror.shownTick != core.shownTick {
            mirror.follow(core.play, shownTick: core.shownTick)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: MicroscopicAuroraExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = MicroscopicAuroraTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(MicroscopicAuroraTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        if latestCore != core {
            absorbFeedback(core)
            absorbProgress(core)
        }
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let base: MicroscopicAuroraSceneSnapshot = core.snapshot(time: time)
        lastBase = (snapshot: base, level: core.play.level)
        let snapshot = presented(base, level: core.play.level)
        lastSnapshot = snapshot
        scene.orbit = gestures.orbit
        // The lights settle on the very first frame only; every later change, a level change included, fades, stepped
        // by the frame clock (feature 486).
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the dish, the gauges
    /// and the actions bars (the camera fits the scene inside a 5 % margin), are `dark` (the abyss backdrop) once a
    /// snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: MicroscopicAuroraExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: MicroscopicAuroraExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        absorbFeedback(core)
        absorbProgress(core)
        mirror.summaryCore = core
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.targetLabel = "Level: a stencil of \(level.stencil.count) cells, \(level.swimmers.count) swimmers, "
            + "\(level.sites?.count ?? 0) well sites, \(level.length) ticks per swim"
        let measure: String = level.progressDescription(report: play.report, wells: play.wells,
                                                        actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Microscopic Aurora level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The trails covered the stencil as one pattern."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = MicroscopicAuroraMirror.failureText(play.failure) ?? "The play failed."
            text += reason
            // Since feature 485 the failure explanation too (what went wrong, then the advice).
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

    /// The teaching and progress sentences of the description (feature 485): the mode, the band, the goal, the best
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

    /// `snapshot` with the mirror's freeze and drag preview applied (feature 484; presentation only).
    private func presented(_ snapshot: MicroscopicAuroraSceneSnapshot,
                           level: MicroscopicAuroraLevel) -> MicroscopicAuroraSceneSnapshot {
        var shown: MicroscopicAuroraSceneSnapshot = snapshot.freezing(mirror.frozen)
        if let preview = mirror.preview {
            shown = shown.previewing(slot: preview.slot, target: preview.target, level: level)
        }
        return shown
    }

    /// Re-applies the mirror's preview and freeze to the last snapshot, so tests and the next gesture read them.
    private func refreshPreview() {
        guard let base = lastBase else { return }
        lastSnapshot = presented(base.snapshot, level: base.level)
    }

    /// The control panel: "Freeze" and "Reset view" (feature 484); every kernel button sends through
    /// ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MicroscopicAuroraControls(port: port, mirror: mirror, presenter: self,
                                          sendAction: { [weak self] control, values in
                                              self?.send(control, values, port: port)
                                          },
                                          freeze: { [weak self] in self?.toggleFreeze() },
                                          resetView: { [weak self] in self?.resetView() }))
    }

    /// The camera's orbit (presentation only; the gesture controller's).
    var orbit: MicroscopicAuroraViewOrbit { gestures.orbit }

    /// The canvas gestures place, move and remove wells and show ticks; the preview, the freeze and the orbit are
    /// presentation state.
    var gestureActions: Set<String> { ["well.place", "well.remove", "clock.show"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(Core.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a placement or move through `well.place` and a removal through `well.remove` (one action each; the preview
    /// is dropped), a tick through `clock.show` (presentation only), a preview kept in the mirror and drawn, the freeze
    /// toggled, a slot selected in the panel, a reset view (the controller is already at the authored orbit) and an
    /// explanation to the mirror's message. The controller places with the panel's strength and sense.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let drawn = lastSnapshot else { return }
        gestures.strength = mirror.strength
        gestures.sense = mirror.counterclockwise ? .counterclockwise : .clockwise
        let actions: [MicroscopicAuroraGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: drawn)
        for action in actions {
            switch action {
            case let .place(slot, well), let .move(slot, well):
                mirror.preview = nil
                send("well.place", [Double(slot), Double(well.cell.row), Double(well.cell.column),
                                    Double(well.strength), well.sense == .counterclockwise ? 1 : 0], port: port)
            case let .remove(slot):
                mirror.preview = nil
                send("well.remove", [Double(slot)], port: port)
            case let .showTick(tick):
                send("clock.show", [Double(tick)], port: port)
            case let .preview(slot, target):
                mirror.preview = (slot: slot, target: target)
            case .clearPreview:
                mirror.preview = nil
            case .toggleFreeze:
                mirror.frozen.toggle()
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

    /// Toggles the freeze ("Freeze", or a tap on the dish field; presentation only).
    func toggleFreeze() {
        mirror.frozen.toggle()
        refreshPreview()
    }

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its bare code in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        mirror.record(accepted: result.isAccepted, code: result.code)
        if !result.isAccepted {
            route(MicroscopicAuroraFeedbackPlan.refused(code: result.code))   // feature 486: announced and felt
            refusalLog.append(MicroscopicAuroraMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        refreshPreview()
        return result
    }

    // MARK: Teaching and progression (feature 485, R02-G19-05)

    /// Takes the core's teaching and progress state into the mirror (feature 485): the tutorial instruction, the
    /// failure explanation, the mode, the open levels with their stars, the band, the goal and the best stars; a change
    /// of the play hides the hint (the next press shows level 1).
    private func absorbProgress(_ core: MicroscopicAuroraExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        absorbSaved(core)
        absorbReplay(core)
        latestCore = core
        if let shown = hintPlay, shown != core.play { clearHint() }
        mirror.tutorialText = core.tutorial == .done ? nil : core.tutorial.text
        mirror.explanation = MicroscopicAuroraFailureExplanation(play: core.play)?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        mirror.pickedLevel = min(max(mirror.pickedLevel, 1), core.progress.frontier)
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.band = core.band
        mirror.bestStars = core.progress.stars(of: core.levelNumber)
        mirror.goalLabel = MicroscopicAuroraMirror.goalText(core.play.level, certified: core.certifiedPlacements)
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

    /// The hint texts of levels 1 … 3 of `play` from one search (`MicroscopicAuroraHints.hint(level:play:certified:)`
    /// at level 1): a placement or removal hint gives each level's text (`MicroscopicAuroraHint.actionText(level:
    /// action:)`); a play, stuck or failed hint reads the same at every level; nil when the play has no hint (won, or
    /// not under way). Runs off the main actor.
    nonisolated static func hintTexts(_ play: MicroscopicAuroraPlay,
                                      certified: [MicroscopicAuroraWell]?) -> [String]? {
        guard let first = MicroscopicAuroraHints.hint(level: 1, play: play, certified: certified) else { return nil }
        guard first.kind == .place || first.kind == .remove, let action = first.action else {
            return [first.text, first.text, first.text]
        }
        var texts: [String] = []
        for level in 1...3 {
            let text: String? = MicroscopicAuroraHint.actionText(level: level, action: action)
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
        let play: MicroscopicAuroraPlay = core.play
        let certified: [MicroscopicAuroraWell] = core.certifiedWells
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
            let texts: [String]? = MicroscopicAuroraPresenter.hintTexts(play, certified: certified)
            await self?.finishSearch(texts, play: play, generation: generation)
        }
    }

    /// Takes the hint texts searched for `play` by the search of `generation`: cached and shown when that generation
    /// is still current (a stale search changes nothing, not even the handle of a newer search).
    private func finishSearch(_ texts: [String]?, play: MicroscopicAuroraPlay, generation: Int) {
        guard generation == hintGeneration, hintPlay == play else { return }
        hintSearch = nil
        hintCache = (play, texts)
        reveal(texts, level: mirror.hintLevel, play: play)
    }

    /// Shows level `level` of `texts` for `play`, or ``noHintText`` (level 0) when the play has no hint.
    private func reveal(_ texts: [String]?, level: Int, play: MicroscopicAuroraPlay) {
        hintPlay = play
        let before: (Int, String?) = (mirror.hintLevel, mirror.hintText)
        if let texts, texts.indices.contains(level - 1) {
            mirror.hintLevel = level
            mirror.hintText = texts[level - 1]
        } else {
            mirror.hintLevel = 0
            mirror.hintText = Self.noHintText
        }
        // Feature 486: a newly shown hint (or the no-hint line) is announced as `state`.
        if let text = mirror.hintText, before.0 != mirror.hintLevel || before.1 != text {
            route(MicroscopicAuroraFeedbackPlan.hint(text: text))
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
                   date: DateComponents = MicroscopicAuroraPresenter.today()) -> ActionResult {
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

    // MARK: Feedback and sound (feature 486, R02-G19-06)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: MicroscopicAuroraFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
    }

    /// Takes a new core into the feedback and the sound, once per core (from the frame or the description): routes the
    /// plan of the change from the latest core and offers the ambient recipe when a level or mode opened or the recipe
    /// changed. The first core only offers its recipe, so the sound never holds a placeholder.
    private func absorbFeedback(_ core: MicroscopicAuroraExperienceCore) {
        guard let previous = latestCore else {
            sound.offer(Self.recipe(core))
            return
        }
        route(MicroscopicAuroraFeedbackPlan.after(old: previous, new: core))
        let opened: Bool = previous.levelNumber != core.levelNumber || previous.mode != core.mode
        if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
    }

    /// The ambient recipe of `core`: its actions left, the quarters of the needed cells lit and its stage.
    static func recipe(_ core: MicroscopicAuroraExperienceCore) -> AmbientLoopRecipe {
        MicroscopicAuroraSoundRecipe.recipe(play: core.play)
    }

    /// Changes the panel's selection (slot, site, strength or sense; presentation only; the buttons and the adjustable
    /// values); when the selection changed (clarification Q4: once per change of slot, site, strength or sense) and the
    /// sound is on, plays the selected well's audition (feature 486).
    func changeSelection(_ change: (MicroscopicAuroraMirror) -> Void) {
        let before: [Int] = [mirror.slot, mirror.siteIndex, mirror.strength, mirror.counterclockwise ? 1 : 0]
        change(mirror)
        let after: [Int] = [mirror.slot, mirror.siteIndex, mirror.strength, mirror.counterclockwise ? 1 : 0]
        guard mirror.soundOn, after != before else { return }
        let well: MicroscopicAuroraWell = mirror.selectedWell ?? MicroscopicAuroraWell(
            cell: MicroscopicAuroraCell(row: 0, column: 0), strength: mirror.strength,
            sense: mirror.counterclockwise ? .counterclockwise : .clockwise)
        sound.audition(MicroscopicAuroraAudition.of(well, placeable: mirror.selectedPlaceable))
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

    /// Saves the sound choice through `settings.sound [0/1]` (feature 487); the change taken in turns the loop on or
    /// off (`absorbSaved(_:)` applies `core.soundOn`).
    @discardableResult
    func saveSound(on: Bool, port: ExperienceActionPort) -> ActionResult {
        send("settings.sound", [on ? 1 : 0], port: port)
    }

    // MARK: Persistence and replay (feature 487, R02-G19-07)

    /// Starts the replay of the current level's verified stored solution (`replay.start [level]`).
    @discardableResult
    func startReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.start", [Double(mirror.levelNumber)], port: port)
    }

    /// Applies the next action of the running replay (`replay.step`).
    @discardableResult
    func stepReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.step", [], port: port)
    }

    /// Stops the running replay and returns to the campaign (`replay.stop`).
    @discardableResult
    func stopReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.stop", [], port: port)
    }

    /// Whether the dropped-results announcement was made (once per presenter; feature 487).
    private var droppedAnnounced = false

    /// The announcement of `count` saved results dropped by a restore (feature 487).
    static func droppedText(_ count: Int) -> String {
        count == 1 ? "1 saved result could not be checked and was removed."
            : "\(count) saved results could not be checked and were removed."
    }

    /// Whether `mode` is a replay (feature 487).
    static func isReplay(_ mode: MicroscopicAuroraMode) -> Bool {
        if case .replay = mode { return true }
        return false
    }

    /// The trace actions a play applied: its placement, removal and play records (feature 487; a fresh play also holds
    /// its begin and tutorial records).
    static func appliedActions(_ play: MicroscopicAuroraPlay) -> Int {
        var count: Int = 0
        for record in play.records where record.kind == .place || record.kind == .remove || record.kind == .play {
            count += 1
        }
        return count
    }

    /// Takes the saved parts of `core` in (feature 487): the restored sound choice when it first appears (the
    /// experience opens) or changes, and the dropped results announced once.
    private func absorbSaved(_ core: MicroscopicAuroraExperienceCore) {
        if latestCore == nil || latestCore?.soundOn != core.soundOn {
            if core.soundOn { sound.offer(Self.recipe(core)) }
            sound.setWanted(core.soundOn)
            mirror.soundOn = core.soundOn
        }
        if !droppedAnnounced, core.reconciliationDropped > 0 {
            droppedAnnounced = true
            route(MicroscopicAuroraFeedbackPlan(text: Self.droppedText(core.reconciliationDropped), kind: .state,
                                                haptic: nil))
        }
    }

    /// Takes the replay state of `core` into the mirror: Replay is offered for a level with a verified result that has
    /// a trace (outside replay); during replay the position is the trace actions played of the trace's actions.
    private func absorbReplay(_ core: MicroscopicAuroraExperienceCore) {
        if let result = core.progress.solved[core.levelNumber] {
            mirror.replayAvailable = result.verified && !result.trace.isEmpty && !Self.isReplay(core.mode)
        } else {
            mirror.replayAvailable = false
        }
        if case .replay(let level) = core.mode {
            mirror.replaying = true
            mirror.replayPosition = Self.appliedActions(core.play)
            mirror.replayLength = core.progress.solved[level]?.trace.count ?? 0
        } else {
            mirror.replaying = false
            mirror.replayPosition = 0
            mirror.replayLength = 0
        }
    }
}
#endif
