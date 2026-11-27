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
// Feature 505 (R02-G21-05) T-R02G2105-005 (FR-R02G2105-001 … 004, 008, 009; clarifications Q1 … Q3, Q5) adds teaching
// and progression to the panel: the tutorial instruction (`core.tutorial.text` until the step is `done`, replacing the
// presenter's own tutorial sentence, which is kept only as a name), the hint at its current level (`showHint()`: each
// press raises the level 1 → 2 → 3; any change of the play hides it, so the next press shows level 1; one search per
// play through `BinaryGardensHints.hint(level:play:certified:)` with the core's certified plan, run off the main actor
// in a detached task, with a generation counter so that a stale search never owns the hint state; hints never send an
// action), the failure explanation (`core.failureExplanation`, shown in the panel in place of the mirror's short
// `failureText`, which stays the status line), the mode, the open levels, the level's band ("Band b of 5"), its goal
// ("Win in at most k actions for 3 stars", k the certified witness's `core.certifiedActionCount`) and its best stars
// ("Best: s of 3 stars" or "Best: not won yet", `core.progress.stars(of:)`). The description includes them. The daily
// level is asked for with today's local calendar date read here (`playDaily(port:date:)`); the core never reads a
// clock. A refused `level.select` or `level.next` (`r02-g21.locked`: "that level is not open yet") and an impossible
// date (`r02-g21.date`: "that date cannot be used") read in words. Modelled on `MushroomWeatherPresenter`
// (feature 495).
// Feature 506 (R02-G21-06) T-R02G2106-005 (FR-R02G2106-001 … 008; clarifications Q1 … Q6): the presenter routes
// `BinaryGardensFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route (`feedback`,
// injectable; the shared `ExperienceFeedback` by default) once for every new core it takes in, from the frame or the
// description, and keeps a feedback log (`feedbackLog`, at most 256 plans) beside the tier log and the refusal log;
// refusals are shown and announced in words (`refused(code:)`; the panel shows exactly the plan's sentence,
// `refusalText(code:)`, in place of the former "That change was refused: …" line), and a revealed hint is announced as
// `state` (`hint(text:)`). Changing the panel's selected star or phase target, previews, the shown tick, an
// inspection, the view, dismissing the tutorial and the Sound toggle are not announced (the controls speak their own
// values). The scene's lights (`BinaryGardensLights`: the glow, the won look and each world's bloom) step toward the
// drawn snapshot (the preview applied) every frame by the frame clock's elapsed time (0.15 s fades, 0.45 s under Reduce
// Flashing; the first frame settles them). The ambient loop (`BinaryGardensSound`) is offered the recipe of the
// actions left, the quarters of the worlds keeping their light, the stars' brightness and the stage when the first
// core is taken in, when a level or mode opens and when that recipe changes; a change of the panel's selected star
// (`changeStar(_:)`: the star picker, the adjustable star and a star tapped on the canvas) and an accepted ring change
// of the selected star play its audition (`BinaryGardensAudition.of(ring:canChange:)`) when the sound is on, on screen
// and active; previews play none. A tier change or a memory warning resets no eased level, feedback log or sound
// state. The mirror carries the summary element's text (`BinaryGardensFeedbackPlan.summaryText(core:star:)`), the
// controls' values in words (clarification Q5, ", locked" for a locked control) and the sound choice (off by default;
// saving it is R02-G21-07). Presentation only. Modelled on `MushroomWeatherPresenter` (feature 496).
// Feature 507 (R02-G21-07) T-R02G2107-006 (FR-R02G2107-004, 005, 007, 008, 009; clarifications Q2, Q4, Q5): the
// mirror carries whether the current level has a verified solution to replay (`replayAvailable`: the core's
// `canReplay(level:)` for its level, outside replay), whether a replay runs (`replaying`, the core's `isReplaying`) and
// its position (`replayPosition`, the trace actions applied, and `replayLength`, the trace's actions with the run: the
// core's own counts); the mode's name is `BinaryGardensFeedbackPlan.modeName(_:)` (campaign, practice, daily or
// replay), so the panel and the announcements use the same word; `startReplay`, `stepReplay` and `stopReplay` send
// `replay.start [level]`, `replay.step` and `replay.stop` through ``send(_:_:port:)``, so a refusal
// (`r02-g21.no-replay`, `r02-g21.replay-end` or `r02-g21.replay`) is shown and announced in the plan's words and its
// bare code kept in the refusal log like every other refusal; the Sound toggle saves the choice through
// `settings.sound [1/0]` (`saveSound(on:port:)`), and the saved choice (`core.soundOn`) is applied when the experience
// opens (the first core taken in) and whenever it changes, replacing R02-G21-06's presenter-held choice
// (`setSound(on:)` stays as a presentation-only path that saves nothing); the results a restore dropped
// (`core.reconciliationDropped`) are announced once per presenter as `state` ("n saved results could not be checked
// and were removed.", "1 saved result could not be checked and was removed."). Modelled on `MushroomWeatherPresenter`
// (feature 497).
#if os(iOS)
import BinaryGardensCore
import Foundation
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
    /// The tutorial instruction of the current step (`core.tutorial.text`, feature 505); nil once the step is `done`.
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
    /// The hint level shown, 1 … 3; 0 while no hint is shown (feature 505; presentation only).
    var hintLevel = 0
    /// The hint shown at ``hintLevel``, ``BinaryGardensPresenter/searchingText`` while its search runs, or
    /// ``BinaryGardensPresenter/noHintText`` when the play has no hint; nil while no hint is shown (feature 505).
    var hintText: String?
    /// The failure explanation (`core.failureExplanation`: what went wrong, then the advice), nil without a failure
    /// (feature 505).
    var explanation: String?
    /// The mode (feature 505).
    var mode: BinaryGardensMode = .campaign
    /// The highest open level (feature 505).
    var frontier = 1
    /// The level's difficulty band, 1 … 5 (the five bands of 20; feature 505).
    var band = 1
    /// The best stars of the current level, 0 … 3 (0 while it has not been won; feature 505).
    var bestStars = 0
    /// The stars of each won level, by level number (the level picker; feature 505).
    var stars: [Int: Int] = [:]
    /// The goal in words: "Win in at most k actions for 3 stars" (feature 505).
    var goalLabel = ""
    /// The level the picker holds, 1 … ``frontier`` (presentation only; feature 505).
    var pickedLevel = 1

    /// "Band b of 5" (feature 505).
    var bandLabel: String { "Band \(band) of 5" }

    /// "Best: s of 3 stars", or "Best: not won yet" while the level has not been won (feature 505).
    var starsLabel: String {
        bestStars > 0 ? "Best: \(bestStars) of 3 stars" : "Best: not won yet"
    }

    /// "Mode: campaign", "Mode: practice", "Mode: daily" or "Mode: replay" (feature 505; replay since feature 507).
    var modeLabel: String { "Mode: " + Self.modeName(mode) }

    /// The mode's name: campaign, practice, daily or replay (feature 505; since feature 507 the feedback plan's
    /// `BinaryGardensFeedbackPlan.modeName(_:)`, so the panel and the announcements use the same word).
    static func modeName(_ mode: BinaryGardensMode) -> String {
        BinaryGardensFeedbackPlan.modeName(mode)
    }

    /// The picker's line for level `level`: "Level n, band b", with ", s of 3 stars" once it has been won
    /// (feature 505).
    func levelLabel(_ level: Int) -> String {
        let band: Int = BinaryGardensProgress.band(of: level)
        if let won = stars[level] { return "Level \(level), band \(band), \(won) of 3 stars" }
        return "Level \(level), band \(band)"
    }

    /// The goal with `certified` actions in the certified plan (feature 505): "Win in at most k actions for 3 stars"
    /// ("1 action" in the singular).
    static func goalText(certified: Int) -> String {
        let unit: String = certified == 1 ? "action" : "actions"
        return "Win in at most \(certified) \(unit) for 3 stars"
    }

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

    /// The panel line of a refusal: since feature 506 exactly the feedback plan's sentence
    /// (`BinaryGardensFeedbackPlan.refusalText(code:)`, clarification Q1), the words that are announced.
    static func refusalMessage(code: String) -> String {
        BinaryGardensFeedbackPlan.refusalText(code: code)
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
        default: return previewReasonText(code: refusal.reasonCode)
        }
    }

    /// The panel line of a refused preview: "That change would be refused: " and the reason in words, with a full stop.
    static func previewRefusalMessage(_ refusal: BinaryGardensError) -> String {
        "That change would be refused: \(previewRefusalText(refusal))."
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``. Since feature 506 it
    /// forwards to `BinaryGardensFeedbackPlan.refusalText(code:)` (clarification Q1's sentences, e.g. "That level is
    /// not open yet.").
    static func refusalText(code: String) -> String {
        BinaryGardensFeedbackPlan.refusalText(code: code)
    }

    /// A refused preview's reason code in lower-case words, inside "That change would be refused: …" (feature 504's
    /// words, unchanged by feature 506: a preview is not a sent action and is never announced).
    static func previewReasonText(code: String) -> String {
        let rule: String = bareCode(code)
        switch rule {
        case "r02-g21.stage": return "the play is over: undo a failed run or go to the next level"
        case "r02-g21.action": return "that ring, phase, luminosity or tilt cannot be set that way (locked, unchanged, off "
            + "the phase grid or too close to the other star), or there is nothing to undo or redo"
        case "r02-g21.budget": return "no actions are left: run the light or undo a change"
        case "r02-g21.stale": return "the play changed before the action arrived"
        case "r02-g21.level": return "the next level could not be made"
        case "r02-g21.generation": return "the next level could not be made"
        case BinaryGardensExperienceRule.locked: return "that level is not open yet"
        case BinaryGardensExperienceRule.date: return "that date cannot be used"
        case BinaryGardensExperienceRule.notWhole: return "the star, ring, phase, luminosity, tilt and tick must be whole "
            + "numbers"
        case BinaryGardensExperienceRule.tick: return "only ticks 1 to 48 can be shown"
        default: return "that action is not available now"
        }
    }

    // MARK: Accessibility (feature 506, R02-G21-06)

    /// The latest core taken in, for the summary element (feature 506); nil before the first.
    var summaryCore: BinaryGardensExperienceCore?
    /// Whether the sound is on (feature 506; off by default; since feature 507 the core's saved choice, `soundOn`).
    var soundOn = false
    /// Whether the current level has a verified solution to replay, outside replay (feature 507).
    var replayAvailable = false
    /// Whether a replay is running (feature 507).
    var replaying = false
    /// The trace actions of the running replay applied so far (0 when no replay runs; feature 507).
    var replayPosition = 0
    /// The actions of the running replay's trace, the run included (0 when no replay runs; feature 507).
    var replayLength = 0

    /// The replay position line (feature 507): "Replay: action k of n".
    var replayPositionLabel: String { "Replay: action \(replayPosition) of \(replayLength)" }

    /// Step's value (feature 507): "Action k of n", the trace actions applied of the trace's.
    var replayStepValue: String { "Action \(replayPosition) of \(replayLength)" }

    /// Stop's value (feature 507): the trace's actions, "n actions" ("1 action" for one).
    var replayStopValue: String { replayLength == 1 ? "1 action" : "\(replayLength) actions" }

    /// Replay's value (feature 507): "level n", the level whose solution it replays.
    var replayValue: String { "level \(levelNumber)" }

    /// The summary element's text (feature 506): `BinaryGardensFeedbackPlan.summaryText(core:star:)` of the latest core
    /// and the panel's selected star; empty before the first core.
    var summary: String {
        guard let core = summaryCore else { return "" }
        return BinaryGardensFeedbackPlan.summaryText(core: core, star: selectedStar)
    }

    /// The selected star's level entry, or nil while no play is followed.
    private var selectedStarRules: BinaryGardensStar? {
        guard let stars = play?.level.stars, stars.indices.contains(selectedStar) else { return nil }
        return stars[selectedStar]
    }

    /// Whether the level locks the selected star's ring (feature 506); false while no play is followed.
    var ringLocked: Bool { selectedStarRules.map { !$0.ringAdjustable } ?? false }
    /// Whether the level locks the selected star's phase (feature 506); false while no play is followed.
    var phaseLocked: Bool { selectedStarRules.map { !$0.phaseAdjustable } ?? false }
    /// Whether the level locks the selected star's luminosity (feature 506); false while no play is followed.
    var luminosityLocked: Bool { selectedStarRules.map { !$0.luminosityAdjustable } ?? false }
    /// Whether the level locks the tilt (T_max = 0; feature 506).
    var tiltLocked: Bool { maxTilt == 0 }

    /// `words` with ", locked" when `locked` (clarification Q5).
    static func locking(_ words: String, _ locked: Bool) -> String { locked ? words + ", locked" : words }

    /// The adjustable star's value (clarification Q5): "star n of 2".
    var starValue: String { "star \(selectedStar + 1) of 2" }

    /// The adjustable ring's value (clarification Q5): "ring r of R, ρ units" (", locked" when the level locks the
    /// selected star's ring).
    var ringValue: String {
        let radii: [Int] = play?.level.ringRadii ?? []
        let radius: Int = radii.indices.contains(ring) ? radii[ring] : 0
        return Self.locking("ring \(ring + 1) of \(ringCount), \(radius) units", ringLocked)
    }

    /// The adjustable phase's value (clarification Q5): "phase p of 47, step g" (", locked" when locked).
    var phaseValue: String {
        Self.locking("phase \(phase) of \(Self.cycle - 1), step \(phaseStep)", phaseLocked)
    }

    /// The adjustable luminosity's value (clarification Q5): "level l of m, luminosity L" (", locked" when locked).
    var luminosityValue: String {
        let levels: [Int] = play?.level.luminosityLevels ?? []
        let units: Int = levels.indices.contains(luminosity) ? levels[luminosity] : 0
        return Self.locking("level \(luminosity + 1) of \(luminosityCount), luminosity \(units)", luminosityLocked)
    }

    /// The adjustable tilt's value (clarification Q5): "tilt t of T steps" (", locked" when T_max = 0).
    var tiltValue: String { Self.locking(tiltLabel, tiltLocked) }

    /// The adjustable shown tick's value (clarification Q5): "tick t of 48".
    var tickValue: String { tickLabel }

    /// The actions made of the budget, in words (feature 506; Undo and Redo's value): "k actions made" ("1 action
    /// made" for one).
    var actionsMadeLabel: String {
        let made: Int = max(budget - actionsLeft, 0)
        return made == 1 ? "1 action made" : "\(made) actions made"
    }

    /// Next level's value (feature 506): "level n" when the next level is open, else "no further level open".
    var nextLevelLabel: String {
        levelNumber < frontier ? "level \(levelNumber + 1)" : "no further level open"
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

    /// The single tutorial sentence of feature 503, no longer shown: since feature 505 the panel shows the tutorial
    /// step's instruction (`core.tutorial.text`). Kept as a name.
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
    /// The latest core seen (feature 505): hints, the daily date and the progress lines read it.
    private(set) var latestCore: BinaryGardensExperienceCore?
    /// The play the shown hint belongs to; nil while no hint is shown (feature 505).
    private var hintPlay: BinaryGardensPlay?
    /// The hint texts of levels 1 … 3 searched for a play (nil texts: the play has no hint), one search per play
    /// (feature 505).
    private var hintCache: (play: BinaryGardensPlay, texts: [String]?)?
    /// The search under way, off the main actor, for ``hintPlay`` (feature 505); tests may await its end.
    private(set) var hintSearch: Task<Void, Never>?
    /// The hint generation (feature 505): raised by every new search and every hidden hint; a search whose generation
    /// is no longer current owns nothing.
    private(set) var hintGeneration = 0
    /// What the hint line shows while the search runs (feature 505).
    static let searchingText = "Finding a hint…"
    /// What the hint line shows when the play has no hint (won, or not under way; feature 505).
    static let noHintText = "No hint now: the level is not being played."
    /// The feedback route of announcements and haptics (feature 506; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first, at most ``feedbackLogLimit`` (feature 506; tests and diagnostics).
    private(set) var feedbackLog: [BinaryGardensFeedbackPlan] = []
    /// The most feedback plans kept.
    static let feedbackLogLimit = 256
    /// The eased light levels drawn by the scene (feature 506).
    private(set) var lights: BinaryGardensLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient loop and the selected star's audition (feature 506).
    let sound: BinaryGardensSound

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedMotion = reduceMotion
        scene.reducedFlash = reduceFlashing
        lights = BinaryGardensLights(reducedFlash: reduceFlashing)
        // A placeholder recipe until the first core is taken in, which offers its own (feature 506).
        sound = BinaryGardensSound(recipe: AmbientLoopRecipe.gentle)
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
        if latestCore != core {
            absorbFeedback(core)
            absorbProgress(core)
        }
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let base: BinaryGardensSceneSnapshot = core.snapshot(time: time)
        lastBase = (snapshot: base, level: core.play.level)
        let snapshot: BinaryGardensSceneSnapshot = presented(base, level: core.play.level)
        lastSnapshot = snapshot
        mirror.previewRefusal = snapshot.preview?.refusal
        scene.orbit = gestures.orbit
        // The lights settle on the very first frame; every later change, a level change included, fades, stepped by
        // the frame clock from the drawn snapshot (the preview applied; feature 506). A frame clock that went back (an
        // off-screen still drawn at an earlier time than the last frame, never a live frame) is not a frame sequence
        // and settles them too, so a still shows the state at rest. A tier change or a memory warning resets nothing.
        if let last = lastFrameTime, frame.time.isFinite, frame.time >= last {
            lights.step(toward: snapshot, elapsed: frame.time - last)
        } else {
            lights.settle(to: snapshot)
        }
        if frame.time.isFinite { lastFrameTime = frame.time }
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
        absorbFeedback(core)
        absorbProgress(core)
        mirror.summaryCore = core
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
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
            // Since feature 505 the failure explanation too (what went wrong, then the advice).
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
        if !text.hasSuffix(" ") { text += " " }
        text += teachingText()
        if let inspected = mirror.inspectedLabel {
            if !text.hasSuffix(" ") { text += " " }
            text += "Inspected " + inspected + "."
        }
        return text
    }

    /// The teaching and progress sentences of the description (feature 505): the mode, the band, the goal, the best
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
        AnyView(BinaryGardensControls(port: port, mirror: mirror, presenter: self,
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

    /// The native controls send every declared control, every action a gesture can and more (since feature 507 the
    /// panel's Replay, Step, Stop and Sound send `replay.start`, `replay.step`, `replay.stop` and `settings.sound`).
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
            changeStar(star)   // feature 506: plays the selected star's audition when the sound is on
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
            route(BinaryGardensFeedbackPlan.refused(code: result.code))   // feature 506: announced and felt
            refusalLog.append(BinaryGardensMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        refreshPreview()
        return result
    }

    // MARK: Teaching and progression (feature 505, R02-G21-05)

    /// Takes the core's teaching and progress state into the mirror (feature 505): the tutorial instruction, the
    /// failure explanation, the mode, the open levels with their stars, the band, the goal and the best stars; a change
    /// of the play hides the hint (the next press shows level 1).
    private func absorbProgress(_ core: BinaryGardensExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        absorbSaved(core)    // feature 507: before `latestCore` moves on, so the first core and a change are seen
        absorbReplay(core)
        latestCore = core
        if let shown = hintPlay, shown != core.play { clearHint() }
        mirror.tutorialText = core.tutorial == .done ? nil : core.tutorial.text
        mirror.explanation = core.failureExplanation?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        mirror.pickedLevel = min(max(mirror.pickedLevel, 1), core.progress.frontier)
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.band = core.band
        mirror.bestStars = core.progress.stars(of: core.levelNumber)
        mirror.goalLabel = BinaryGardensMirror.goalText(certified: core.certifiedActionCount)
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

    /// The hint texts of levels 1 … 3 of `play` from one search (`BinaryGardensHints.hint(level:play:certified:)` at
    /// level 1): a ring, phase, luminosity or tilt hint gives each level's text
    /// (`BinaryGardensHint.actionText(level:action:gardens:arrangement:)` from the play's level and arrangement); a
    /// run, stuck or retry hint reads the same at every level; nil when the play has no hint (won, or not under way).
    /// Runs off the main actor.
    nonisolated static func hintTexts(_ play: BinaryGardensPlay, certified: BinaryGardensPlan?) -> [String]? {
        guard let first = BinaryGardensHints.hint(level: 1, play: play, certified: certified) else { return nil }
        let changes: Bool = first.kind == .ring || first.kind == .phase || first.kind == .luminosity
            || first.kind == .tilt
        guard changes, let action = first.action else {
            return [first.text, first.text, first.text]
        }
        var texts: [String] = []
        for level in 1...3 {
            let text: String? = BinaryGardensHint.actionText(level: level, action: action, gardens: play.level,
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
        let play: BinaryGardensPlay = core.play
        let certified: BinaryGardensPlan = core.certifiedPlan
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
            let texts: [String]? = BinaryGardensPresenter.hintTexts(play, certified: certified)
            await self?.finishSearch(texts, play: play, generation: generation)
        }
    }

    /// Takes the hint texts searched for `play` by the search of `generation`: cached and shown when that generation is
    /// still current (a stale search changes nothing, not even the handle of a newer search).
    private func finishSearch(_ texts: [String]?, play: BinaryGardensPlay, generation: Int) {
        guard generation == hintGeneration, hintPlay == play else { return }
        hintSearch = nil
        hintCache = (play, texts)
        reveal(texts, level: mirror.hintLevel, play: play)
    }

    /// Shows level `level` of `texts` for `play`, or ``noHintText`` (level 0) when the play has no hint.
    private func reveal(_ texts: [String]?, level: Int, play: BinaryGardensPlay) {
        hintPlay = play
        let before: (Int, String?) = (mirror.hintLevel, mirror.hintText)
        if let texts, texts.indices.contains(level - 1) {
            mirror.hintLevel = level
            mirror.hintText = texts[level - 1]
        } else {
            mirror.hintLevel = 0
            mirror.hintText = Self.noHintText
        }
        // Feature 506: a newly shown hint (or the no-hint line) is announced as `state`.
        if let text = mirror.hintText, before.0 != mirror.hintLevel || before.1 != text {
            route(BinaryGardensFeedbackPlan.hint(text: text))
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
                   date: DateComponents = BinaryGardensPresenter.today()) -> ActionResult {
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

    // MARK: Feedback and sound (feature 506, R02-G21-06)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it (at most
    /// ``feedbackLogLimit``); `.none` does nothing.
    func route(_ plan: BinaryGardensFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
        if feedbackLog.count > Self.feedbackLogLimit {
            feedbackLog.removeFirst(feedbackLog.count - Self.feedbackLogLimit)
        }
    }

    /// Takes a new core into the feedback and the sound, once per core (from the frame or the description): routes the
    /// plan of the change from the latest core, plays the selected star's audition after an accepted ring change of
    /// it, and offers the ambient recipe when a level or mode opened or the recipe changed. The first core only offers
    /// its recipe, so the sound never holds the placeholder. Runs before ``absorbProgress(_:)``, which takes the core
    /// as the latest.
    private func absorbFeedback(_ core: BinaryGardensExperienceCore) {
        guard let previous = latestCore else {
            sound.offer(Self.recipe(core))
            return
        }
        guard previous != core else { return }
        let plan: BinaryGardensFeedbackPlan = BinaryGardensFeedbackPlan.after(old: previous, new: core)
        route(plan)
        let star: Int = mirror.selectedStar
        if plan.trigger == "star.ring", previous.play.arrangement.rings.indices.contains(star),
           core.play.arrangement.rings.indices.contains(star),
           previous.play.arrangement.rings[star] != core.play.arrangement.rings[star], mirror.soundOn {
            sound.audition(Self.audition(star: star, play: core.play))
        }
        let opened: Bool = previous.levelNumber != core.levelNumber || previous.mode != core.mode
        if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
    }

    /// The ambient recipe of `core`: its actions left, the quarters of the worlds keeping their light, the stars'
    /// brightness and its stage.
    static func recipe(_ core: BinaryGardensExperienceCore) -> AmbientLoopRecipe {
        BinaryGardensSoundRecipe.recipe(play: core.play)
    }

    /// The audition of star `star` (0 … 1) of `play`: `BinaryGardensAudition.of(ring:canChange:)` of its ring index
    /// and whether it can change now.
    static func audition(star: Int, play: BinaryGardensPlay) -> BinaryGardensAudition {
        let rings: [Int] = play.arrangement.rings
        let ring: Int = rings.indices.contains(star) ? rings[star] : 0
        return BinaryGardensAudition.of(ring: ring,
                                        canChange: BinaryGardensAudition.canChange(star: star, play: play))
    }

    /// The audition of the panel's selected star (its ring and whether it can change now); the outermost tone that
    /// cannot change while no play is followed.
    var selectedAudition: BinaryGardensAudition {
        guard let play = mirror.play else { return BinaryGardensAudition.of(ring: 0, canChange: false) }
        return Self.audition(star: mirror.selectedStar, play: play)
    }

    /// Selects star `star` in the panel (clamped to 0 … 1; presentation only: the star picker, the adjustable star and
    /// a star tapped on the canvas); when the selected star changed (clarification Q4: once per change) and the sound
    /// is on, plays its audition (feature 506). Previews never come here.
    func changeStar(_ star: Int) {
        let before: Int = mirror.selectedStar
        mirror.select(star: star)
        guard mirror.soundOn, mirror.selectedStar != before else { return }
        sound.audition(selectedAudition)
    }

    /// Turns the sound on or off (presentation only, saves nothing; since feature 507 the Sound toggle saves the
    /// choice through ``saveSound(on:port:)`` and the saved choice is applied by ``absorbSaved(_:)``); turning it on
    /// plays the recipe of the current play.
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

    /// The summary element's words (feature 506): the mirror's summary of the latest core and the selected star.
    var summaryText: String { mirror.summary }

    // MARK: Persistence and replay (feature 507, R02-G21-07)

    /// Saves the sound choice through `settings.sound [1]` or `[0]` (feature 507); the change taken in turns the loop
    /// on or off (``absorbSaved(_:)`` applies `core.soundOn`).
    @discardableResult
    func saveSound(on: Bool, port: ExperienceActionPort) -> ActionResult {
        send("settings.sound", [on ? 1 : 0], port: port)
    }

    /// Starts the replay of the current level's verified stored solution (`replay.start [level]`; refused in words
    /// without one).
    @discardableResult
    func startReplay(port: ExperienceActionPort) -> ActionResult {
        let level: Int = latestCore?.levelNumber ?? mirror.levelNumber
        return send("replay.start", [Double(level)], port: port)
    }

    /// Applies the next action of the running replay (`replay.step`; refused in words after the last or outside
    /// replay).
    @discardableResult
    func stepReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.step", [], port: port)
    }

    /// Stops the running replay and returns to the campaign (`replay.stop`; refused in words outside replay).
    @discardableResult
    func stopReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.stop", [], port: port)
    }

    /// The trigger of the dropped-results announcement in the feedback log (feature 507).
    static let droppedTrigger = "reconciliation"

    /// Whether the dropped-results announcement was made (once per presenter; feature 507).
    private(set) var droppedAnnounced = false

    /// The announcement of `count` saved results a restore dropped (feature 507): "n saved results could not be
    /// checked and were removed.", in the singular "1 saved result could not be checked and was removed.".
    static func droppedText(_ count: Int) -> String {
        count == 1 ? "1 saved result could not be checked and was removed."
            : "\(count) saved results could not be checked and were removed."
    }

    /// The `state` plan announcing `count` dropped results (feature 507): no haptic, trigger ``droppedTrigger``.
    static func droppedPlan(_ count: Int) -> BinaryGardensFeedbackPlan {
        BinaryGardensFeedbackPlan(text: droppedText(count), kind: .state, haptic: nil, trigger: droppedTrigger)
    }

    /// Takes the saved parts of `core` in (feature 507): the saved sound choice when the first core arrives (the
    /// experience opens) or the choice changes, and the dropped results announced once. Runs before `latestCore`
    /// moves on.
    private func absorbSaved(_ core: BinaryGardensExperienceCore) {
        if latestCore == nil || latestCore?.soundOn != core.soundOn {
            // As `setSound(on:)`, with the recipe of this core (`latestCore` is still the previous one).
            if core.soundOn { sound.offer(Self.recipe(core)) }
            sound.setWanted(core.soundOn)
            mirror.soundOn = core.soundOn
        }
        if !droppedAnnounced, core.reconciliationDropped > 0 {
            droppedAnnounced = true
            route(Self.droppedPlan(core.reconciliationDropped))
        }
    }

    /// Takes the replay state of `core` into the mirror (feature 507): Replay is offered for a level with a verified
    /// result that has a trace, outside replay; during replay the position is the core's trace actions applied of the
    /// trace's actions.
    private func absorbReplay(_ core: BinaryGardensExperienceCore) {
        mirror.replaying = core.isReplaying
        mirror.replayAvailable = !core.isReplaying && core.canReplay(level: core.levelNumber)
        mirror.replayPosition = core.replayPosition
        mirror.replayLength = core.replayLength
    }
}
#endif
