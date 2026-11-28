// MyceliumArchitectPresenter — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-003, 004, 005, 007, 010;
// clarifications Q2, Q4, Q5). Draws the adapter's immutable snapshot with `MyceliumArchitectBoardScene` at the host's
// quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityProfile` names, the
// names of `MyceliumArchitectTier.all`), keeps a log of every tier change with its reason, stills the vein pulses,
// toxin ripples, hyphae fuzz and spores under Reduce Motion (`u_motion` 0) and caps the glow under Reduce Flashing
// (the glow gain per tier: level-0 1.5, level-1 1.0, level-2 none; the cap 0.5). Nothing moves the network by time:
// the shown pulse is the adapter's presentation state (`growth.show`, the pulses run at an opening and after every
// action) and is never advanced by time; only the pulses of light along the veins, the ripples, the fuzz and the
// spores move with the presentation time. The tutorial of the first levels is shown in words, as presentation, not as
// a kernel stage. A refused action is shown in words. A memory warning releases the GPU objects; the next frame
// rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel (renderer purity). Its
// probes (two backdrop corners) let the verification runner check a frame (the round-two X gates require them).
// Modelled on `BinaryGardensPresenter` (feature 503).
// Feature 514 (R02-G22-04) T-R02G2204-006 (FR-R02G2204-001 … 006, 008, 009, 011 … 014; clarifications Q1–Q5): a canvas
// touch goes through the presenter's `MyceliumArchitectGestureController` with the drawn snapshot, the panel's tool
// and the presenter's view orbit (`pointer`). The presenter owns the presentation state (the tool, the previewed
// change, the inspected cell and the orbit) and applies it through the adapter: every frame draws a copy of the core
// with `setTool`, `setPreview` or `clearPreview`, `inspect` and `setOrbit` applied (the kernel's own preview, judged by
// its change rule and growth; an inspection off the board and an orbit outside its bounds are corrected by the
// adapter), so the drawn snapshot carries the ghost veins, the inspection ring and the orbit, and the scene draws with
// `snapshot.orbit.camera(aspect:)`, the camera the picker reads. The copy never reaches the host: the host's core, its
// digest and its save do not change. A site tap or press sends one `cell.nutrient`, `cell.blocker` or `cell.clear`
// [column, row], a seed drag one `root.seed [direction]`, an unseed drag one `root.unseed [direction]` (each through
// ``send(_:_:port:)``, dropping the preview), a gauge press or scrub `growth.show [pulse]` (presentation only); a cell
// tap inspects (the description gives the kernel's cell words) and a second tap clears; two fingers orbit; a double
// tap on empty space or "Reset view" returns to the authored view. A gesture that does nothing for a stated reason
// (the root or a sprout tapped, the play not running) says it in the mirror's message and the description (the
// controller's texts verbatim). A preview is named in words (the predicted verdict, or the refusal). A refused action
// is shown in the panel and its bare code kept in the refusal log (at most 64). An opening, `level.next`, reset or
// restore (a new level number, or records that no longer extend the followed ones) returns the tool, the preview, the
// inspection and the orbit to their defaults, as the adapter does. Modelled on `BinaryGardensPresenter` (feature 504).
// Feature 515 (R02-G22-05) T-R02G2205-005 (FR-R02G2205-001 … 005, 008, 010; clarifications Q1 … Q5) adds teaching
// and progression to the panel: the tutorial instruction (`core.tutorial.text` until the step is `done`, replacing the
// presenter's own tutorial sentence, which is kept only as a name), the hint at its current level (`showHint()`: each
// press raises the level 1 → 2 → 3; any change of the play — an accepted action, undo, redo, an opening, a level or a
// mode — hides it, so the next press shows level 1; one search per play through
// `MyceliumArchitectHints.hint(level:play:certified:)` with the core's certified plan, run off the main actor in a
// detached task, with a generation counter so that a stale search never owns the hint state; hints never send an
// action), the failure explanation (`core.failureExplanation`, shown in the panel in place of the mirror's short
// `failureText`, which stays the status line), the mode, the open levels, the level's band ("Band b of 5"), its goal
// ("Win in at most k actions for 3 stars", "1 action" in the singular, k the certified plan's
// `core.certifiedActionCount`) and its best stars ("Best: s of 3 stars" or "Best: not won yet",
// `core.progress.stars(of:)`). The description includes them. The daily level is asked for with today's local calendar
// date read here (`playDaily(port:date:)`); the core never reads a clock. A refused `level.select` or `level.next`
// (`r02-g22.locked`: "that level is not open yet") and an impossible date (`r02-g22.date`: "that date cannot be used")
// read in words and are logged by code like every refusal. Modelled on `BinaryGardensPresenter` (feature 505).
#if os(iOS)
import Foundation
import MyceliumArchitectCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described, the shown pulse and the panel's selection (the
/// cell cursor and the direction).
@MainActor
@Observable
final class MyceliumArchitectMirror {
    /// The level number (1 … 100).
    var levelNumber: Int = 1
    /// The actions left.
    var actionsLeft: Int = 0
    /// The action budget.
    var budget: Int = 0
    /// A one-line status: "Ready", "Playing", "Won" or "Failed: " and the failure in words.
    var status: String = ""
    /// The failure in words, if the play failed.
    var failureText: String?
    /// The progress in words (the kernel's progress description).
    var measureLabel: String = ""
    /// The level in words.
    var targetLabel: String = ""
    /// The tutorial instruction of the current step (`core.tutorial.text`, feature 515); nil once the step is `done`.
    var tutorialText: String?
    /// The shown pulse, the adapter's (0 … the pulses run).
    var shownPulse: Int = 0
    /// The play followed (a copy; never sent anywhere).
    var play: MyceliumArchitectPlay?
    /// The text of the last refused change, if any.
    var message: String?
    /// The cursor's column (the panel's selection; clamped to the board when read).
    var column: Int = 0
    /// The cursor's row (the panel's selection; clamped to the board when read).
    var row: Int = 0
    /// The direction the panel seeds or unseeds (0 north … 7 north-west).
    var direction: Int = 0
    /// The placement tool: what a tap on an empty site and "Place at cursor" place (feature 514; presentation only).
    var tool: MyceliumArchitectTool = .nutrient
    /// The change a press or drag previews, if any (feature 514; presentation only).
    var preview: MyceliumArchitectAction?
    /// The preview in words: the predicted verdict, or the refusal; nil without a preview (feature 514).
    var previewLabel: String?
    /// The inspected cell, if any (feature 514; presentation only).
    var inspectedCell: MyceliumArchitectCell?
    /// Whether the camera is turned away from the authored view (feature 514; presentation only).
    var orbited: Bool = false
    /// The hint level shown, 1 … 3; 0 while no hint is shown (feature 515; presentation only).
    var hintLevel: Int = 0
    /// The hint shown at ``hintLevel``, ``MyceliumArchitectPresenter/searchingText`` while its search runs, or
    /// ``MyceliumArchitectPresenter/noHintText`` when the play has no hint; nil while no hint is shown (feature 515).
    var hintText: String?
    /// The failure explanation (`core.failureExplanation`: what went wrong, then the advice), nil without a failure
    /// (feature 515).
    var explanation: String?
    /// The mode (feature 515).
    var mode: MyceliumArchitectMode = .campaign
    /// The highest open level (feature 515).
    var frontier: Int = 1
    /// The level's difficulty band, 1 … 5 (the five bands of 20; feature 515).
    var band: Int = 1
    /// The best stars of the current level, 0 … 3 (0 while it has not been won; feature 515).
    var bestStars: Int = 0
    /// The stars of each won level, by level number (the level picker; feature 515).
    var stars: [Int: Int] = [:]
    /// The goal in words: "Win in at most k actions for 3 stars" (feature 515).
    var goalLabel: String = ""
    /// The level the picker holds, 1 … ``frontier`` (presentation only; feature 515).
    var pickedLevel: Int = 1

    /// "Band b of 5" (feature 515).
    var bandLabel: String { "Band \(band) of 5" }

    /// "Best: s of 3 stars", or "Best: not won yet" while the level has not been won (feature 515).
    var starsLabel: String {
        bestStars > 0 ? "Best: \(bestStars) of 3 stars" : "Best: not won yet"
    }

    /// "Mode: campaign", "Mode: practice" or "Mode: daily" (feature 515).
    var modeLabel: String { "Mode: " + Self.modeName(mode) }

    /// The mode's name: campaign, practice or daily (feature 515).
    nonisolated static func modeName(_ mode: MyceliumArchitectMode) -> String {
        switch mode {
        case .campaign: return "campaign"
        case .practice: return "practice"
        case .daily: return "daily"
        }
    }

    /// The picker's line for level `level`: "Level n, band b", with ", s of 3 stars" once it has been won
    /// (feature 515).
    func levelLabel(_ level: Int) -> String {
        let band: Int = MyceliumArchitectProgress.band(of: level)
        if let won = stars[level] { return "Level \(level), band \(band), \(won) of 3 stars" }
        return "Level \(level), band \(band)"
    }

    /// The goal with `certified` actions in the certified plan (feature 515): "Win in at most k actions for 3 stars"
    /// ("1 action" in the singular).
    nonisolated static func goalText(certified: Int) -> String {
        let unit: String = certified == 1 ? "action" : "actions"
        return "Win in at most \(certified) \(unit) for 3 stars"
    }

    /// The board's width of the followed play (1 while no play is followed).
    var boardWidth: Int { max(play?.level.width ?? 1, 1) }

    /// The board's height of the followed play (1 while no play is followed).
    var boardHeight: Int { max(play?.level.height ?? 1, 1) }

    /// The pulses run of the followed play's report (0 while no play is followed).
    var pulsesRun: Int { play?.report.pulsesRun ?? 0 }

    /// The cursor's column clamped to the board.
    var cursorColumn: Int { min(max(column, 0), boardWidth - 1) }

    /// The cursor's row clamped to the board.
    var cursorRow: Int { min(max(row, 0), boardHeight - 1) }

    /// The cursor's cell.
    var cursor: MyceliumArchitectCell { MyceliumArchitectCell(column: cursorColumn, row: cursorRow) }

    /// The selected direction clamped to 0 … 7.
    var selectedDirection: MyceliumArchitectDirection {
        MyceliumArchitectDirection(rawValue: min(max(direction, 0), 7)) ?? .north
    }

    /// Moves the cursor `step` columns, clamped to the board.
    func moveColumn(_ step: Int) { column = min(max(cursorColumn + step, 0), boardWidth - 1) }

    /// Moves the cursor `step` rows, clamped to the board.
    func moveRow(_ step: Int) { row = min(max(cursorRow + step, 0), boardHeight - 1) }

    /// The pulse `step` pulses from the shown one, clamped to 0 … the pulses run.
    func pulse(moved step: Int) -> Int { min(max(shownPulse + step, 0), pulsesRun) }

    /// The cursor's cell in words (the kernel's cell description), or "no cell".
    var cellLabel: String {
        guard let play else { return "no cell" }
        return play.level.cellDescription(cursor, arrangement: play.arrangement, report: play.report)
    }

    /// The selected direction in words, with whether it is seeded.
    var directionLabel: String {
        let words: String = selectedDirection.words
        guard let play else { return words }
        return play.arrangement.seeds.contains(selectedDirection) ? words + ", seeded" : words + ", not seeded"
    }

    /// The shown pulse in words.
    var pulseLabel: String { "pulse \(shownPulse) of \(pulsesRun)" }

    /// Every terminal in words (the kernel's terminal descriptions), joined by "; ".
    var terminalsLabel: String {
        guard let play else { return "no terminals" }
        var parts: [String] = []
        for terminal in play.level.terminals.indices where terminal < play.report.terminalPulses.count {
            parts.append(play.level.terminalDescription(terminal, report: play.report))
        }
        return parts.joined(separator: "; ")
    }

    /// Takes the new `play` and presentation.
    func follow(_ play: MyceliumArchitectPlay, shownPulse: Int) {
        self.play = play
        self.shownPulse = shownPulse
    }

    /// The tool in words: "nutrient" or "blocker" (feature 514).
    var toolLabel: String {
        switch tool {
        case .nutrient: return "nutrient"
        case .blocker: return "blocker"
        }
    }

    /// The inspected cell in words (the kernel's cell description), or nil without an inspection (feature 514).
    var inspectedLabel: String? {
        guard let cell = inspectedCell, let play else { return nil }
        return play.level.cellDescription(cell, arrangement: play.arrangement, report: play.report)
    }

    /// The tool, the preview, the inspection and the orbit flag back to their defaults (a new play; feature 514).
    func clearPresentation() {
        tool = .nutrient
        preview = nil
        previewLabel = nil
        inspectedCell = nil
        orbited = false
    }

    /// A preview in words (feature 514, clarification Q3): "Preview refused: " and the refusal in words, or
    /// "Preview: " and the predicted verdict (every terminal reached, or the failure the kernel's report names).
    static func previewText(_ preview: MyceliumArchitectPreview, level: MyceliumArchitectLevel) -> String {
        if let refusal = preview.refusal {
            return "Preview refused: " + refusalText(code: refusal.reasonCode)
        }
        if let failure = preview.failure {
            return "Preview: the growth would fail: " + level.failureDescription(failure)
        }
        return "Preview: the growth would reach every terminal"
    }

    /// A refused action's code without the engine's `action.rule.` prefix (the refusal log keeps bare codes).
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// The panel's sentence for a refused action of reason code `code`.
    static func refusalMessage(code: String) -> String {
        "That change was refused: \(refusalText(code: code))."
    }

    /// A failure in words, naming what the kernel's reason names (the level's failure description, first letter in
    /// upper case, with a full stop); nil without a failure.
    static func failureText(_ failure: MyceliumArchitectFailure?, level: MyceliumArchitectLevel) -> String? {
        guard let failure else { return nil }
        return level.failureDescription(failure).capitalizedFirst + "."
    }

    /// The prefix the engine puts before a rule's code in an action result's code.
    static let rulePrefix: String = "action.rule."

    /// A refused action's reason code in words: the rule's code (`r02-g22.…`), with or without the engine's
    /// `action.rule.` prefix (an action result's code carries it).
    static func refusalText(code: String) -> String {
        let rule: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch rule {
        case "r02-g22.stage": return "the play is over: undo a failed run or go to the next level"
        case "r02-g22.action": return "that cell or direction cannot be changed that way (off the board, not empty, "
            + "not a site, a limit reached, a starting seed or nothing to clear), or there is nothing to undo or redo"
        case "r02-g22.budget": return "no actions are left: run the growth or undo a change"
        case "r02-g22.stale": return "the play changed before the action arrived"
        case "r02-g22.level": return "the next level could not be made"
        case "r02-g22.generation": return "the next level could not be made"
        case MyceliumArchitectExperienceRule.locked: return "that level is not open yet"
        case MyceliumArchitectExperienceRule.date: return "that date cannot be used"
        case MyceliumArchitectExperienceRule.notWhole: return "the column, row, direction and pulse must be whole "
            + "numbers"
        case MyceliumArchitectExperienceRule.pulse: return "only the pulses the growth has run can be shown"
        default: return "that action is not available now"
        }
    }
}

private extension String {
    /// The string with its first letter in upper case.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct MyceliumArchitectTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Mycelium Architect.
@MainActor
final class MyceliumArchitectPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = MyceliumArchitectExperienceCore

    /// The single tutorial sentence of feature 513, no longer shown: since feature 515 the panel shows the tutorial
    /// step's instruction (`core.tutorial.text`). Kept as a name.
    static let tutorial: String = "Place nutrients and blockers on the marked sites and seed directions at the root so "
        + "the growing veins reach every terminal cap without entering a toxin, running out of nutrient or growing "
        + "heavier than the limit; then run the growth."

    /// The most refusal codes kept in ``refusalLog`` (feature 514).
    static let refusalLogLimit: Int = 64

    /// Whether Reduce Motion is on (the vein pulses, ripples, fuzz and spores stand still).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror: MyceliumArchitectMirror = MyceliumArchitectMirror()
    /// The GL scene.
    let scene: MyceliumArchitectBoardScene = MyceliumArchitectBoardScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G2203-004).
    private(set) var tierLog: [MyceliumArchitectTierChange] = []
    /// The last snapshot drawn (tests, the description and the gestures), with the presentation state applied through
    /// the adapter (feature 514): the tool, the preview, the inspected cell and the orbit.
    private(set) var lastSnapshot: MyceliumArchitectSceneSnapshot?
    /// The gesture controller (feature 514): site presses, seed and unseed drags, gauge presses and scrubs, cell taps,
    /// double taps and orbits.
    private(set) var gestures: MyceliumArchitectGestureController = MyceliumArchitectGestureController()
    /// The camera's orbit, clamped (feature 514; presentation only; passed with every pointer event).
    private(set) var orbit: MyceliumArchitectViewOrbit = .authored
    /// The bare codes of refused actions, oldest first, at most ``refusalLogLimit`` (feature 514).
    private(set) var refusalLog: [String] = []
    /// The host's core last drawn or described (without presentation state; feature 514).
    private var lastCore: MyceliumArchitectExperienceCore?
    /// The presentation time of the last frame drawn, seconds (feature 514: a refreshed snapshot keeps it).
    private var lastTime: Double = 0
    /// The level number of the play last followed (feature 514: a new one is a new play).
    private var followedLevel: Int?
    /// The latest core seen (feature 515): hints, the daily date and the progress lines read it.
    private(set) var latestCore: MyceliumArchitectExperienceCore?
    /// The play the shown hint belongs to; nil while no hint is shown (feature 515).
    private var hintPlay: MyceliumArchitectPlay?
    /// The hint texts of levels 1 … 3 searched for a play (nil texts: the play has no hint), one search per play
    /// (feature 515).
    private var hintCache: (play: MyceliumArchitectPlay, texts: [String]?)?
    /// The search under way, off the main actor, for ``hintPlay`` (feature 515); tests may await its end.
    private(set) var hintSearch: Task<Void, Never>?
    /// The hint generation (feature 515): raised by every new search and every hidden hint; a search whose generation
    /// is no longer current owns nothing.
    private(set) var hintGeneration: Int = 0
    /// What the hint line shows while the search runs (feature 515).
    static let searchingText: String = "Finding a hint…"
    /// What the hint line shows when the play has no hint (won, or not under way; feature 515).
    static let noHintText: String = "No hint now: the level is not being played."

    /// What a presented core depends on (feature 514): the host's core (its `==` compares the level and the play),
    /// the shown pulse (not in `==`) and the presentation state.
    private struct PresentationKey: Equatable {
        /// The host's core.
        let core: MyceliumArchitectExperienceCore
        /// The core's shown pulse.
        let shownPulse: Int
        /// The tool.
        let tool: MyceliumArchitectTool
        /// The previewed change.
        let preview: MyceliumArchitectAction?
        /// The inspected cell.
        let inspected: MyceliumArchitectCell?
        /// The orbit.
        let orbit: MyceliumArchitectViewOrbit
    }

    /// The last presented core with its key (feature 514): the preview's growth runs once per change, not per frame.
    private var presentedCache: (key: PresentationKey, core: MyceliumArchitectExperienceCore)?

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedMotion = reduceMotion
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the board program's fragment source with one that does not compile.
    func breakBoardShader() {
        scene.boardFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the names of the Core's `qualityProfile` (`level-0` … `level-2`, the
    /// names of `MyceliumArchitectTier.all`), as many as the Core's `qualityTiers`.
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(MyceliumArchitectTier.of(tier).name) }
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
    /// reset or restore: another level number, or records that do not extend the followed ones) returns the tool, the
    /// preview, the inspection and the orbit to their defaults (feature 514), as the adapter's own reset does.
    private func follow(_ core: MyceliumArchitectExperienceCore) {
        lastCore = core
        let previous: MyceliumArchitectPlay? = mirror.play
        guard previous != core.play || mirror.shownPulse != core.shownPulse || followedLevel != core.levelNumber else {
            return
        }
        let fresh: Bool = Self.isNewPlay(previous, core.play, followedLevel: followedLevel,
                                         levelNumber: core.levelNumber)
        followedLevel = core.levelNumber
        mirror.follow(core.play, shownPulse: core.shownPulse)
        if fresh { clearPresentation() }
    }

    /// Whether `next` (of level `levelNumber`) is a new play after `previous` (of level `followedLevel`): no play was
    /// followed, the level number changed, or `next`'s records do not extend `previous`'s (a reset or a restore; the
    /// records are append-only, undo and redo included).
    static func isNewPlay(_ previous: MyceliumArchitectPlay?, _ next: MyceliumArchitectPlay, followedLevel: Int?,
                          levelNumber: Int) -> Bool {
        guard let previous, followedLevel == levelNumber else { return true }
        let old: [MyceliumArchitectRecord] = previous.records
        let new: [MyceliumArchitectRecord] = next.records
        guard new.count >= old.count else { return true }
        return !new.starts(with: old)
    }

    /// Returns the tool, the preview, the inspection and the orbit to their defaults and cancels a gesture in progress
    /// (feature 514: a new play).
    private func clearPresentation() {
        mirror.clearPresentation()
        if gestures.state != .idle { gestures.cancel() }
        orbit = .authored
        refresh()
    }

    /// `core` with the presentation state applied through the adapter (feature 514): `setTool`, `setPreview` (the
    /// kernel's own preview of the change) or `clearPreview`, `inspect` and `setOrbit` (clamped). A copy: the host's
    /// core, its digest and its save do not change. Cached while nothing it reads changes.
    private func presented(_ core: MyceliumArchitectExperienceCore) -> MyceliumArchitectExperienceCore {
        let key: PresentationKey = PresentationKey(core: core, shownPulse: core.shownPulse, tool: mirror.tool,
                                                   preview: mirror.preview, inspected: mirror.inspectedCell,
                                                   orbit: orbit)
        if let cached = presentedCache, cached.key == key { return cached.core }
        var copy: MyceliumArchitectExperienceCore = core
        copy.setTool(mirror.tool)
        if let change = mirror.preview {
            copy.setPreview(change)
        } else {
            copy.clearPreview()
        }
        copy.inspect(mirror.inspectedCell)
        if orbit.isAuthored {
            copy.resetView()
        } else {
            copy.setOrbit(orbit)
        }
        presentedCache = (key: key, core: copy)
        return copy
    }

    /// Takes what the adapter made of the presentation state into the presenter and the mirror (feature 514): the
    /// inspection (none off the board), the orbit (clamped) and the preview in words.
    private func absorb(_ shown: MyceliumArchitectExperienceCore) {
        if mirror.inspectedCell != shown.inspectedCell { mirror.inspectedCell = shown.inspectedCell }
        if orbit != shown.orbit { orbit = shown.orbit }
        let orbited: Bool = !orbit.isAuthored
        if mirror.orbited != orbited { mirror.orbited = orbited }
        var label: String?
        if let preview = shown.preview { label = MyceliumArchitectMirror.previewText(preview, level: shown.play.level) }
        if mirror.previewLabel != label { mirror.previewLabel = label }
    }

    /// Re-applies the presentation state to the last core seen, so tests, the description and the next gesture read
    /// it (feature 514). The last snapshot is replaced only once a frame was drawn (the probes and the gestures wait for
    /// the first frame).
    private func refresh() {
        guard let base = lastCore else { return }
        let shown: MyceliumArchitectExperienceCore = presented(base)
        absorb(shown)
        if lastSnapshot != nil { lastSnapshot = shown.snapshot(time: lastTime) }
    }

    /// Draws `core` at host tier `tier`, logging tier changes; the drawn snapshot carries the presentation state.
    func draw(_ core: MyceliumArchitectExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn: MyceliumArchitectTier = MyceliumArchitectTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason: String = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(MyceliumArchitectTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        if latestCore != core { absorbProgress(core) }
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        lastTime = time
        let shown: MyceliumArchitectExperienceCore = presented(core)
        absorb(shown)
        let snapshot: MyceliumArchitectSceneSnapshot = shown.snapshot(time: time)
        lastSnapshot = snapshot
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the floor, the gauge,
    /// the pips and the actions bars (the camera fits the scene's box inside a 6 % margin per side), are `dark` (the
    /// cave backdrop) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: MyceliumArchitectExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        let corners: [FrameProbe?] = [
            FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
            FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue),
        ]
        var probes: [FrameProbe] = []
        for corner in corners { if let corner { probes.append(corner) } }
        return probes
    }

    /// The state in words; also refreshes the mirror. Since feature 514 it ends with the tool, the preview in words,
    /// the inspected cell's words ("Inspected " and the kernel's cell description) and the last explanation or refusal.
    /// Since feature 515 a failure is followed by its explanation, and the mode, band, goal and best stars sentences
    /// (then the tutorial instruction and the hint when shown) come before the tool.
    func describe(_ core: MyceliumArchitectExperienceCore) -> String {
        let play: MyceliumArchitectPlay = core.play
        let level: MyceliumArchitectLevel = play.level
        follow(core)
        refresh()
        absorbProgress(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        let sites: Int = level.sites?.count ?? 0
        mirror.targetLabel = "Level: \(level.width) × \(level.height) cave, \(level.terminals.count) terminals, "
            + "\(level.rocks.count) rocks, \(level.toxins.count) toxins, \(sites) sites, up to \(level.maxNutrients) "
            + "nutrients, \(level.maxBlockers) blockers and \(level.maxSeeds) seeds, \(level.pulses) pulses, "
            + "\(level.budget) actions"
        let measure: String = level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text: String = "Mycelium Architect level \(core.levelNumber). "
        text += measure + ". "
        let won: Bool = play.stage == .won || (play.stage == .result && play.failure == nil)
        let failed: Bool = play.stage == .failed || play.stage == .result
        if won {
            text += "Every terminal was reached and opened."
            mirror.status = "Won"
            mirror.failureText = nil
        } else if failed {
            let reason: String = MyceliumArchitectMirror.failureText(play.failure, level: level) ?? "The run failed."
            text += reason
            // Since feature 515 the failure explanation too (what went wrong, then the advice).
            if let explanation = mirror.explanation { text += " " + explanation }
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        } else {
            var played: Bool = false
            for record in play.records where record.kind != .begin && record.kind != .dismissTutorial {
                played = true
            }
            mirror.status = played ? "Playing" : "Ready"
            mirror.failureText = nil
        }
        if !text.hasSuffix(" ") { text += " " }
        text += teachingText()
        var extras: [String] = ["Tool: " + mirror.toolLabel]
        if let preview = mirror.previewLabel { extras.append(preview) }
        if let inspected = mirror.inspectedLabel { extras.append("Inspected " + inspected) }
        if let message = mirror.message { extras.append(message) }
        for extra in extras {
            if !text.hasSuffix(" ") { text += " " }
            text += extra.hasSuffix(".") ? extra : extra + "."
        }
        return text
    }

    /// The control panel: every kernel control sends through ``send(_:_:port:)`` (refusals shown and logged); the tool
    /// buttons, "Place at cursor", "Inspect cursor", "Inspect: none" and "Reset view" reach the presenter (feature 514);
    /// "Hint", "Dismiss tutorial", the modes and "Play level" reach it too (feature 515).
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MyceliumArchitectControls(port: port, mirror: mirror, presenter: self,
                                          sendAction: { [weak self] (control: String, values: [Double]) in
                                              self?.send(control, values, port: port)
                                          },
                                          chooseTool: { [weak self] (tool: MyceliumArchitectTool) in
                                              self?.chooseTool(tool)
                                          },
                                          placeAtCursor: { [weak self] in
                                              self?.placeAtCursor(port: port)
                                          },
                                          inspect: { [weak self] (cell: MyceliumArchitectCell?) in
                                              self?.inspect(cell)
                                          },
                                          resetView: { [weak self] in
                                              self?.resetView()
                                          }))
    }

    // MARK: Gestures and presentation (feature 514)

    /// The gesture controller's state (diagnostics, FR-R02G2204-013).
    var gestureState: MyceliumArchitectGestureController.State { gestures.state }

    /// The placement tool (diagnostics; the panel's).
    var tool: MyceliumArchitectTool { mirror.tool }

    /// The previewed change, if any (diagnostics).
    var previewChange: MyceliumArchitectAction? { mirror.preview }

    /// The inspected cell, if any (diagnostics).
    var inspectedCell: MyceliumArchitectCell? { mirror.inspectedCell }

    /// The canvas gestures place, clear, seed and unseed, and show pulses; the preview, the inspection and the orbit
    /// are presentation state.
    var gestureActions: Set<String> {
        ["cell.nutrient", "cell.blocker", "cell.clear", "root.seed", "root.unseed", "growth.show"]
    }

    /// The native controls send every declared control.
    var nativeActions: Set<String> { Set(Core.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot, the tool and the orbit, and
    /// applies what it returns, in order: a kernel action through ``send(_:_:port:)`` (one each; the preview is
    /// dropped), a pulse through `growth.show [pulse]` (presentation only), an inspection, a preview (judged by the
    /// adapter and drawn), an orbit, a reset view and an explanation to the mirror's message. A finished, orbiting or
    /// cancelled gesture leaves no preview.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let drawn = lastSnapshot else { return }
        let actions: [MyceliumArchitectGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: drawn,
                                                                        tool: mirror.tool, orbit: orbit)
        for action in actions { apply(action, port: port) }
        let state: MyceliumArchitectGestureController.State = gestures.state
        if state == .idle || state == .orbiting || state == .cancelled { mirror.preview = nil }
        refresh()
    }

    /// Applies one gesture action (see ``pointer(_:viewSize:port:)``).
    private func apply(_ action: MyceliumArchitectGestureAction, port: ExperienceActionPort) {
        switch action {
        case let .send(control, values):
            mirror.preview = nil
            send(control, values, port: port)
        case let .showPulse(pulse):
            send("growth.show", [Double(pulse)], port: port)
        case let .inspect(cell):
            mirror.inspectedCell = cell
        case let .preview(change):
            mirror.preview = change
        case .clearPreview:
            mirror.preview = nil
        case let .orbit(turned):
            orbit = turned.clamped()
        case .resetView:
            orbit = .authored
        case let .explain(reason):
            mirror.message = reason
        }
    }

    /// Cancels the touches in progress (suspension): nothing is sent and the preview disappears.
    func cancelPointers() {
        gestures.cancel()
        mirror.preview = nil
        refresh()
    }

    /// Chooses the placement tool ("Nutrient tool" or "Blocker tool"; presentation only, nothing is sent).
    func chooseTool(_ tool: MyceliumArchitectTool) {
        mirror.tool = tool
        refresh()
    }

    /// "Place at cursor": sends the tool's placement (`cell.nutrient` or `cell.blocker`) on the panel's cursor cell
    /// through ``send(_:_:port:)``.
    @discardableResult
    func placeAtCursor(port: ExperienceActionPort) -> ActionResult {
        let cell: MyceliumArchitectCell = mirror.cursor
        return send(mirror.tool.controlID, [Double(cell.column), Double(cell.row)], port: port)
    }

    /// Inspects `cell`, or clears the inspection with nil ("Inspect: none") or a cell off the board (presentation only).
    func inspect(_ cell: MyceliumArchitectCell?) {
        mirror.inspectedCell = cell
        refresh()
    }

    /// Returns the camera to the authored view ("Reset view"; presentation only).
    func resetView() {
        orbit = .authored
        refresh()
    }

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its bare code in ``refusalLog``;
    /// an accepted action leaves no message.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        // Cleared first, so the description the shell takes after an accepted action carries no stale message.
        mirror.message = nil
        let result: ActionResult = port.send(control, values)
        if !result.isAccepted {
            mirror.message = MyceliumArchitectMirror.refusalMessage(code: result.code)
            refusalLog.append(MyceliumArchitectMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        refresh()
        return result
    }

    // MARK: Teaching and progression (feature 515, R02-G22-05)

    /// The teaching and progress sentences of the description (feature 515): the mode, the band, the goal, the best
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

    /// Takes the core's teaching and progress state into the mirror (feature 515): the tutorial instruction, the
    /// failure explanation, the mode, the open levels with their stars, the band, the goal and the best stars. A change
    /// of the play (or of the level or the mode: a fresh opening) hides the hint, so the next press shows level 1.
    private func absorbProgress(_ core: MyceliumArchitectExperienceCore) {
        let previous: MyceliumArchitectExperienceCore? = latestCore
        if previous?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        var reopened: Bool = false
        if let previous, previous.levelNumber != core.levelNumber || previous.mode != core.mode { reopened = true }
        latestCore = core
        if let shown = hintPlay, shown != core.play || reopened { clearHint() }
        let tutorial: String? = core.tutorial == .done ? nil : core.tutorial.text
        if mirror.tutorialText != tutorial { mirror.tutorialText = tutorial }
        let explanation: String? = core.failureExplanation?.text
        if mirror.explanation != explanation { mirror.explanation = explanation }
        if mirror.mode != core.mode { mirror.mode = core.mode }
        let frontier: Int = core.progress.frontier
        if mirror.frontier != frontier { mirror.frontier = frontier }
        let picked: Int = min(max(mirror.pickedLevel, 1), frontier)
        if mirror.pickedLevel != picked { mirror.pickedLevel = picked }
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        if mirror.stars != stars { mirror.stars = stars }
        if mirror.band != core.band { mirror.band = core.band }
        let best: Int = core.progress.stars(of: core.levelNumber)
        if mirror.bestStars != best { mirror.bestStars = best }
        let goal: String = MyceliumArchitectMirror.goalText(certified: core.certifiedActionCount)
        if mirror.goalLabel != goal { mirror.goalLabel = goal }
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

    /// The hint texts of levels 1 … 3 of `play` from one search (`MyceliumArchitectHints.hint(level:play:certified:)`
    /// at level 1 against the certified plan `certified`): a nutrient, blocker, clear, seed or unseed hint gives each
    /// level's text (`MyceliumArchitectHint.actionText(level:action:on:)` on the play's level, the same text the
    /// adapter's `hint(level:)` gives); a run, stuck or retry hint reads the same at every level; nil when the play has
    /// no hint (won, or not under way). Runs off the main actor.
    nonisolated static func hintTexts(_ play: MyceliumArchitectPlay,
                                      certified: [MyceliumArchitectAction]) -> [String]? {
        guard let first = MyceliumArchitectHints.hint(level: 1, play: play, certified: certified) else { return nil }
        guard let action = first.action, action != .run else {
            return [first.text, first.text, first.text]
        }
        var texts: [String] = []
        for level in 1...3 {
            let text: String? = MyceliumArchitectHint.actionText(level: level, action: action, on: play.level)
            texts.append(text ?? first.text)
        }
        return texts
    }

    /// Shows the next hint level (1 → 2 → 3, then 3 again) for the current play; never sends an action. The search
    /// runs once per play in a detached task, never on the main actor or the frame: meanwhile the hint line reads
    /// ``searchingText`` (a press during the search raises the level it will show); the result is shown only when its
    /// generation is still current, and later levels come from the cache.
    func showHint() {
        guard let core = latestCore else { return }
        let play: MyceliumArchitectPlay = core.play
        let certified: [MyceliumArchitectAction] = core.certifiedPlan
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
            let texts: [String]? = MyceliumArchitectPresenter.hintTexts(play, certified: certified)
            await self?.finishSearch(texts, play: play, generation: generation)
        }
    }

    /// Takes the hint texts searched for `play` by the search of `generation`: cached and shown when that generation is
    /// still current (a stale search changes nothing, not even the handle of a newer search).
    private func finishSearch(_ texts: [String]?, play: MyceliumArchitectPlay, generation: Int) {
        guard generation == hintGeneration, hintPlay == play else { return }
        hintSearch = nil
        hintCache = (play: play, texts: texts)
        reveal(texts, level: mirror.hintLevel, play: play)
    }

    /// Shows level `level` of `texts` for `play`, or ``noHintText`` (level 0) when the play has no hint.
    private func reveal(_ texts: [String]?, level: Int, play: MyceliumArchitectPlay) {
        hintPlay = play
        guard let texts, texts.indices.contains(level - 1) else {
            mirror.hintLevel = 0
            mirror.hintText = Self.noHintText
            return
        }
        mirror.hintLevel = level
        mirror.hintText = texts[level - 1]
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
                   date: DateComponents = MyceliumArchitectPresenter.today()) -> ActionResult {
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
}
#endif
