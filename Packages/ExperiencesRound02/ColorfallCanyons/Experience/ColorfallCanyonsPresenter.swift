// ColorfallCanyonsPresenter — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-003, 004, 005, 007; clarifications
// Q2, Q4). Draws the adapter's immutable snapshot with `ColorfallCanyonsCanyonScene` at the host's quality tier (tier n
// is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the flow bands
// still under Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory warning
// releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result
// reaches the kernel (renderer purity). Its probes (two night corners) let the verification runner check a frame.
// Feature 344 (R02-G05-04) T-R02G0504-005 (FR-R02G0504-001 … 006): canvas touches go through
// `ColorfallCanyonsGestureController` with the drawn view size and the last drawn snapshot: a released drag from a
// carvable cell sends one `canyon.carve [cell]`, a tap on a spring one `canyon.valve [spring]`; two fingers orbit the
// camera and a double tap on empty space or `resetView()` ("Reset view") returns to the authored view (presentation
// only: never in the digest, the snapshot or the kernel). While a drag is in progress the picked cell is outlined in
// pearl and the description begins "Carving row r, column c".
// Feature 345 (R02-G05-05) T-R02G0505-005 (FR-R02G0505-001 … 005; clarifications Q1–Q5): the mirror carries the tutorial
// instruction, the hint revealed so far (`showHint()` reveals the next of three levels for the current play; the hint
// level is presentation only and any change of the play — level, mode or play fingerprint — hides it), the failure
// explanation, the mode, the open levels with their stars and the goal (budget and certified smallest edit count);
// `retry` starts the level again in its mode, `undo` takes back the last change, and the daily level is chosen from
// the local calendar date read here (`playDaily(port:date:)`, sent as `mode.daily [year, month, day]`), never in the core.
#if os(iOS)
import ColorfallCanyonsCore
import Foundation
import SwiftUI
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

// Feature 346 (R02-G05-06) T-R02G0506-006 (FR-R02G0506-001 … 006; clarifications Q1–Q5): after each described change the
// presenter routes `ColorfallCanyonsFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback
// route (`feedback`, injectable), announces cell picks and refusals in words (the panel shows the same words), keeps a
// feedback log, eases the scene's lights (`ColorfallCanyonsLights`, 0.45 s fades under Reduce Flashing) and offers the
// ambient recipe to `ColorfallCanyonsSound` at level openings and changes of the basins or the stage. Presentation only.

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class ColorfallCanyonsMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The carves and valve toggles left.
    var remaining = 0
    /// The ticks run and the tick limit.
    var tick = 0
    var tickLimit = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// The carvable cells in order and the index picked (presentation only).
    var carvable: [Int] = []
    var pickedIndex = 0
    /// The columns of the grid (for the cell label).
    var columns = 1
    /// The springs' names and valve states.
    var springNames: [String] = []
    var springStates: [String] = []
    /// The text of the last refused change, if any.
    var message: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 345).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 345).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 345).
    var failureText: String?
    /// The mode (feature 345).
    var mode: ColorfallCanyonsMode = .campaign
    /// The highest open level and the stars of each won level (feature 345).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The goal: the actions spent, the budget and the certified smallest edit count (feature 345).
    var spent = 0
    var budget = 0
    var smallest = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen).
    var pickedLevel = 1

    /// The picked cell, if any cell can be carved.
    var pickedCell: Int? {
        carvable.isEmpty ? nil : carvable[min(max(pickedIndex, 0), carvable.count - 1)]
    }

    /// The picked cell as "row r, column c" (1-based), or "none".
    var pickedCellLabel: String {
        guard let cell = pickedCell else { return "none" }
        return "row \(cell / max(columns, 1) + 1), column \(cell % max(columns, 1) + 1)"
    }

    /// Moves the pick by `delta` carvable cells, wrapping.
    func pickNext(_ delta: Int) {
        guard !carvable.isEmpty else { return }
        pickedIndex = ((pickedIndex + delta) % carvable.count + carvable.count) % carvable.count
    }

    /// The summary element's words (feature 346): tick, actions left and every basin against its target.
    var summary = ""
    /// Whether the ambient sound is on (feature 346; off by default).
    var soundOn = false
}

/// One entry of the tier log: the tier drawn and why it changed.
struct ColorfallCanyonsTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Colorfall Canyons.
@MainActor
final class ColorfallCanyonsPresenter: ExperiencePresenter {
    typealias Core = ColorfallCanyonsExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = ColorfallCanyonsMirror()
    let scene = ColorfallCanyonsCanyonScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0503-004).
    private(set) var tierLog: [ColorfallCanyonsTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: ColorfallCanyonsSceneSnapshot?
    /// The gesture controller (feature 344): drags, valve taps, orbit and the drag highlight.
    private(set) var gestures = ColorfallCanyonsGestureController()
    /// The latest core described (feature 345): hints and retry read it.
    private(set) var latestCore: ColorfallCanyonsExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 345).
    private var hintKey: String?
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 345).
    private(set) var dailyDate: DateComponents?
    /// The feedback route of announcements and haptics (feature 346; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every announcement text routed, oldest first (feature 346).
    private(set) var announcements: [String] = []
    /// Every routed feedback plan, oldest first (feature 346; tests and diagnostics).
    private(set) var feedbackLog: [ColorfallCanyonsFeedbackPlan] = []
    /// The eased light levels the scene draws (feature 346).
    private(set) var lights: ColorfallCanyonsLights
    /// The frame time of the last draw, for easing the lights.
    private var lastFrameTime: Double?
    /// The level and mode the lights belong to.
    private var lightsLevel: String?
    /// The ambient sound (feature 346).
    let sound: ColorfallCanyonsSound

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        lights = ColorfallCanyonsLights(reducedFlash: reduceFlashing)
        sound = ColorfallCanyonsSound(recipe: ColorfallCanyonsSoundRecipe.recipe(basinMasses: [], stage: .loading))
    }

    /// The tests' seam: before `setup`, replaces the fluid program's fragment source with one that does not compile.
    func breakFluidShader() {
        scene.fluidFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: ColorfallCanyonsExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = ColorfallCanyonsTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(ColorfallCanyonsTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        // A new level (or mode) starts from its own lights: they settle at once; only changes within a play fade.
        let level = "\(core.levelNumber)/\(core.mode)"
        if let last = lastFrameTime, lightsLevel == level, frame.time > last {
            lights.step(toward: snapshot, elapsed: frame.time - last)
        } else {
            lights.settle(to: snapshot)
        }
        lightsLevel = level
        lastFrameTime = frame.time
        scene.lights = lights
        scene.orbit = gestures.orbit
        scene.highlightedCell = gestures.highlightedCell
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    // MARK: Touch controls (feature 344)

    /// The canvas gestures send carves and valve toggles only.
    var gestureActions: Set<String> { ["canyon.carve", "canyon.valve"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(ColorfallCanyonsExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller; a released carve drag or a spring tap sends its one
    /// action.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let actions: [ColorfallCanyonsGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        for action in actions {
            switch action {
            case .carve(let cell):
                send("canyon.carve", [Double(cell)], port: port)
            case .valve(let spring):
                send("canyon.valve", [Double(spring)], port: port)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
    }

    /// Drops a touch in progress (the shell suspends the experience): a gesture under way is abandoned without an
    /// action; the orbit is presentation only and returns to the authored view.
    func cancelPointers() {
        gestures.cancel()
    }

    /// Returns the camera to the authored view ("Reset view").
    func resetView() {
        gestures.resetView()
    }

    /// Sends `control` with `values` and shows a refusal.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            let plan = ColorfallCanyonsFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            route(plan)
        }
        return result
    }

    // MARK: Feedback and sound (feature 346)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: ColorfallCanyonsFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind {
            feedback.announce(text, kind: kind)
            announcements.append(text)
        }
        feedbackLog.append(plan)
    }

    /// Moves the panel's cell pick by `delta` carvable cells and announces the cell ("Row r, column c picked.").
    func pickCell(_ delta: Int) {
        let before = mirror.pickedCell
        mirror.pickNext(delta)
        guard let cell = mirror.pickedCell, cell != before else { return }
        route(ColorfallCanyonsFeedbackPlan.picked(cell: cell, columns: mirror.columns))
    }

    /// The ambient recipe of `core`'s basins and stage.
    static func recipe(_ core: ColorfallCanyonsExperienceCore) -> AmbientLoopRecipe {
        let snapshot = core.snapshot(time: 0)
        return ColorfallCanyonsSoundRecipe.recipe(basinMasses: ColorfallCanyonsSoundRecipe.basinMasses(snapshot),
                                                  stage: core.play.stage)
    }

    /// Turns the ambient sound on or off; turning it on plays the recipe of the current basins and stage.
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

    // MARK: Teaching and progression (feature 345)

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: ColorfallCanyonsExperienceCore) -> String {
        "\(core.levelNumber)/\(core.mode)/\(core.play.fingerprint)"
    }

    /// Hides the hint shown.
    private func clearHint() {
        hintKey = nil
        mirror.hintLevel = 0
        mirror.hintText = nil
    }

    /// Reveals the next hint level (up to 3) for the current play; the hint is hidden when the play has none (won, or
    /// not started). Hints never change the state: no action is sent.
    func showHint() {
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

    /// Takes back the last change (`play.undo`); after a failure this returns the play to playing.
    @discardableResult
    func undo(port: ExperienceActionPort) -> ActionResult {
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
    func retry(port: ExperienceActionPort, date: DateComponents = ColorfallCanyonsPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort,
                   date: DateComponents = ColorfallCanyonsPresenter.today()) -> ActionResult {
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right background corners, outside the terrain
    /// (the camera fits the scene inside a 5 % margin), are `dark` (the night clear) once a snapshot was drawn by the real
    /// scene; none otherwise.
    func probes(_ core: ColorfallCanyonsExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "night-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "night-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    func describe(_ core: ColorfallCanyonsExperienceCore) -> String {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        if let previous = latestCore {
            route(ColorfallCanyonsFeedbackPlan.after(old: previous, new: core))
            let opened = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            let changed = previous.play.fluid.masses != core.play.fluid.masses || previous.play.stage != core.play.stage
            if opened || changed { sound.offer(Self.recipe(core)) }
        } else {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(Self.recipe(core))
        }
        latestCore = core
        mirror.summary = ColorfallCanyonsFeedbackPlan.summaryText(core: core)
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = core.failureExplanation?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (level, result) in core.progress.solved { stars[level] = result.stars }
        mirror.stars = stars
        mirror.spent = core.play.spent
        mirror.budget = core.play.level.budget
        mirror.smallest = core.certifiedSmallest
        let play = core.play
        let level = play.level
        let snapshot = core.snapshot(time: 0)
        mirror.levelNumber = core.levelNumber
        mirror.remaining = play.remaining
        mirror.tick = snapshot.tick
        mirror.tickLimit = snapshot.tickLimit
        mirror.columns = level.columns
        mirror.carvable = (0..<level.cellCount).filter { level.isCarvable($0, heights: snapshot.heights) }
        mirror.springNames = snapshot.springs.map(\.color.name)
        mirror.springStates = snapshot.springs.map { spring in
            spring.supplyLeft == 0 ? "dry" : (spring.open ? "open, \(spring.supplyLeft) units left" : "closed")
        }
        var text = ""
        if let cell = gestures.highlightedCell, play.stage == .playing, cell < level.cellCount {
            text += "Carving row \(cell / max(level.columns, 1) + 1), column \(cell % max(level.columns, 1) + 1). "
        }
        text += "Colorfall Canyons level \(core.levelNumber). "
        text += "Tick \(snapshot.tick) of \(snapshot.tickLimit); \(play.remaining) actions left. "
        for (index, spring) in snapshot.springs.enumerated() {
            text += "Spring \(index + 1), \(spring.color.name): \(mirror.springStates[index]). "
        }
        for (index, basin) in snapshot.basins.enumerated() {
            let masses = snapshot.masses[basin.cell]
            let parts = ColorfallCanyonsColor.allCases.map { "\($0.name) \(masses[$0.rawValue])" }
            text += "Basin \(index + 1) holds \(parts.joined(separator: ", ")); target \(basin.description). "
        }
        switch play.stage {
        case .won:
            text += "Every basin is filled with its colours."
            if let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
            mirror.status = "Won"
        case .failed:
            let reason: String
            switch play.failure {
            case .contamination: reason = "Too much of a wrong colour entered a protected basin."
            case .overflow: reason = "A basin overflowed."
            case .time, .none: reason = "Time ran out before every basin was filled."
            }
            text += reason
            if let explanation = mirror.failureText { text += " " + explanation }
            mirror.status = "Failed: " + reason
        default:
            mirror.status = "Playing"
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ColorfallCanyonsControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
