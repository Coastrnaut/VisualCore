// AmethystEscapePresenter — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-003, 004, 005, 007; clarifications
// Q2, Q4). Draws the adapter's immutable snapshot with `AmethystEscapeCrystalScene` at the host's quality tier (tier n
// is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the facet
// highlights still under Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory
// warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing
// result reaches the kernel (renderer purity). Its probes (two backdrop corners) let the verification runner check a
// frame.
// Feature 364 (R02-G07-04) T-R02G0704-006 (FR-R02G0704-001 … 008; clarifications Q1–Q5): canvas touches go through
// `AmethystEscapeGestureController`: a shell dragged round the centre sends one `shell.rotate [k, ±1]` per whole sector
// swept (the shortest way round), a tap on the pearl sends `pearl.advance`, a tap on a shell picks it in the panel, a
// double tap on a shell isolates it (the other shells darken; again to clear; "Show all layers" and `level.next` clear
// it), two fingers orbit the camera and a double tap on empty space or `resetView()` ("Reset view") returns to the
// authored view (presentation only: never in the digest, the snapshot or the kernel). While a shell is dragged the scene
// draws the turn it would make and the description begins "Shell k would turn n sectors clockwise"; a gesture on a
// finished play says "The play is over: undo or go to the next level". A refused action is shown in the panel and its
// code kept in ``AmethystEscapePresenter/refusalLog``.
// Feature 365 (R02-G07-05) T-R02G0705-005 (FR-R02G0705-001 … 005; clarifications Q1–Q5): the mirror carries the
// tutorial instruction, the hint revealed so far (`showHint()` reveals the next of three levels for the current play;
// the hint level is presentation only and any change of the play — level, mode or play fingerprint — hides it), the
// failure explanation, the mode, the open levels with their stars and the goal (moves spent, budget and certified
// smallest move count); `retry` starts the level again in its mode, `undoMove` takes back the last move, and the daily
// level is chosen from the local calendar date read here (`playDaily(port:date:)`, sent as `mode.daily [year, month,
// day]`), never in the core.
// Feature 366 (R02-G07-06) T-R02G0706-005 (FR-R02G0706-001 … 006; clarifications Q1–Q5): after every described change
// the presenter routes `AmethystEscapeFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback
// route (`feedback`, injectable; the shared `ExperienceFeedback` by default) and keeps a feedback log; a shell drag that
// sends several turns is announced once, after its last turn, with `AmethystEscapeFeedbackPlan.drag(old:new:shell:
// sectors:)`; shell picks (panel or tap) are announced with `picked(shell:core:)`; refusals are announced with
// `refused(code:)` and shown in the panel in the same words (`refusalText(code:)`). The scene's lights
// (`AmethystEscapeLights`: pearl glow, exit glow and the failed wedge's amber) settle on the first frame and afterwards
// fade every frame by the frame's elapsed time (0.45 s fades under Reduce Flashing), a level change included. The
// ambient loop (`AmethystEscapeSound`) is offered the recipe of the pearl's shell, the shell count and the stage
// (`AmethystEscapeSoundRecipe`) when a level or mode opens and when that recipe changes. The mirror carries the summary
// element's text and the sound choice. Presentation only.
#if os(iOS)
import AmethystEscapeCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreAudioDSP

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class AmethystEscapeMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The moves spent and the budget.
    var moves = 0
    var budget = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// Each shell's name ("shell 1 (inner)") and offset (presentation only).
    var shellNames: [String] = []
    var offsets: [Int] = []
    /// The sectors per shell.
    var sectors = 0
    /// Where the pearl is, in words.
    var pearlLabel = ""
    /// The shell picked (presentation only).
    var pickedShell = 0
    /// The text of the last refused change, if any.
    var message: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 365).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 365).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 365).
    var failureText: String?
    /// The mode (feature 365).
    var mode: AmethystEscapeMode = .campaign
    /// The highest open level and the stars of each won level (feature 365).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The certified smallest move count of the current level (the goal, feature 365).
    var smallest = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen).
    var pickedLevel = 1
    /// The summary element's text (feature 366): the moves left, the pearl, the exit gap and every shell.
    var summary = ""
    /// Whether the ambient sound is on (feature 366; off by default).
    var soundOn = false

    /// The picked shell's name ("Shell 1 (inner)"), or "none".
    var pickedShellLabel: String {
        // Only the first letter is raised, as the announcements say it (feature 366).
        guard shellNames.indices.contains(pickedShell) else { return "none" }
        let name: String = shellNames[pickedShell]
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// The shell picker's value (feature 366): "<Shell>, turned t of N".
    var pickedShellValue: String {
        guard shellNames.indices.contains(pickedShell) else { return "none" }
        return pickedShellLabel + ", " + pickedOffsetLabel
    }

    /// The picked shell's turn as "turned t of N".
    var pickedOffsetLabel: String {
        guard offsets.indices.contains(pickedShell) else { return "" }
        return "turned \(offsets[pickedShell]) of \(sectors)"
    }

    /// Moves the pick by `delta` shells, wrapping.
    func pickNext(_ delta: Int) {
        guard !shellNames.isEmpty else { return }
        pickedShell = ((pickedShell + delta) % shellNames.count + shellNames.count) % shellNames.count
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct AmethystEscapeTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Amethyst Escape.
@MainActor
final class AmethystEscapePresenter: ExperiencePresenter {
    typealias Core = AmethystEscapeExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = AmethystEscapeMirror()
    let scene = AmethystEscapeCrystalScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0703-004).
    private(set) var tierLog: [AmethystEscapeTierChange] = []
    /// The last snapshot of the kernel drawn (tests, the description and the gestures; never a preview).
    private(set) var lastSnapshot: AmethystEscapeSceneSnapshot?
    /// The gesture controller (feature 364): shell drags, pearl taps, selection, isolation, orbit.
    private(set) var gestures = AmethystEscapeGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64
    /// The feedback route of announcements and haptics (feature 366; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first (feature 366; tests and diagnostics).
    private(set) var feedbackLog: [AmethystEscapeFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 366).
    private(set) var lights: AmethystEscapeLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient sound (feature 366).
    let sound: AmethystEscapeSound
    /// The gesture drag whose turns are being sent: the core before its first turn (nil before any was described),
    /// the turns accepted so far and the first refusal's code; while it is set, per-turn plans and refusals are not
    /// routed (feature 366).
    private var dragTurns: (before: AmethystEscapeExperienceCore?, accepted: Int, refusal: String?)?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        lights = AmethystEscapeLights(reducedFlash: reduceFlashing)
        sound = AmethystEscapeSound(recipe: AmethystEscapeSoundRecipe.recipe(pearlShell: 0, shells: 1,
                                                                             stage: .loading))
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the crystal program's fragment source with one that does not compile.
    func breakCrystalShader() {
        scene.crystalFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: AmethystEscapeExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = AmethystEscapeTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(AmethystEscapeTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        // The lights settle on the very first frame only; every later change, a level change included, fades.
        if let last = lastFrameTime {
            lights.step(toward: snapshot, elapsed: frame.time > last ? frame.time - last : 0)
        } else {
            lights.settle(to: snapshot)
        }
        lastFrameTime = frame.time
        scene.lights = lights
        scene.orbit = gestures.orbit
        scene.isolated = gestures.isolated
        try scene.render(previewed(snapshot), tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    /// `snapshot` with the turn of the shell being dragged, while a drag previews one; `snapshot` otherwise.
    func previewed(_ snapshot: AmethystEscapeSceneSnapshot) -> AmethystEscapeSceneSnapshot {
        guard gestures.state == .shellDrag, let shell = gestures.draggedShell, gestures.candidateSectors != 0 else {
            return snapshot
        }
        return snapshot.previewing(shell: shell, sectors: gestures.candidateSectors)
    }

    // MARK: Touch controls (feature 364)

    /// The canvas gestures send turns and advances.
    var gestureActions: Set<String> { ["shell.rotate", "pearl.advance"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(AmethystEscapeExperienceCore.actionIDs) }

    /// What a turn or advance gesture on a finished play shows.
    static let finishedMessage = "The play is over: undo or go to the next level"

    /// The latest core described (feature 365): hints and retry read it.
    private(set) var latestCore: AmethystEscapeExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 365).
    private var hintKey: String?
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 365).
    private(set) var dailyDate: DateComponents?

    // MARK: Teaching and progression (feature 365)

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: AmethystEscapeExperienceCore) -> String {
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

    /// Takes back the last move (`play.undo`); after a failure this returns the play to playing.
    @discardableResult
    func undoMove(port: ExperienceActionPort) -> ActionResult {
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
    func retry(port: ExperienceActionPort, date: DateComponents = AmethystEscapePresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort, date: DateComponents = AmethystEscapePresenter.today()) -> ActionResult {
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

    /// The touch-down of the current one-finger touch: its point and what it picked (for the finished-play message).
    private var touchDown: (id: Int, point: Vec2, pick: AmethystEscapePick)?
    /// The fingers down now (T-R02G0704-014).
    private var fingersDown: Set<Int> = []
    /// Whether more than one finger has been down since the last time none was: such a gesture shows no message.
    private var multiTouch = false

    /// Routes a canvas touch through the gesture controller and sends the actions it returns, in order; a drag on a
    /// shell (at least ``AmethystEscapeGestureController/dragDistance`` points) or a touch on the pearl on a finished
    /// play explains that the play is over (a shell tap still picks the shell).
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        switch event.phase {
        case .began:
            fingersDown.insert(event.id)
            if fingersDown.count == 1, !multiTouch {
                let pick: AmethystEscapePick = AmethystEscapePicker.pick(
                    SIMD2(event.location.x, event.location.y), size: SIMD2(viewSize.x, viewSize.y),
                    snapshot: snapshot, orbit: gestures.orbit)
                touchDown = (event.id, event.location, pick)
            } else {
                multiTouch = true   // a second (or later) finger: this gesture shows no message
                touchDown = nil
            }
        case .cancelled:
            touchDown = nil
        default:
            break
        }
        let actions: [AmethystEscapeGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        if event.phase == .ended, let down = touchDown, down.id == event.id, !multiTouch {
            touchDown = nil
            let travel: Double = (event.location - down.point).length
            let moved: Bool = down.pick != .empty
                && (down.pick == .pearl || travel >= AmethystEscapeGestureController.dragDistance)
            if moved, actions.isEmpty, snapshot.stage != .playing { mirror.message = Self.finishedMessage }
        }
        if event.phase == .ended || event.phase == .cancelled {
            fingersDown.remove(event.id)
            if fingersDown.isEmpty { multiTouch = false }
        }
        // The turns of one drag are announced once, after the last (feature 366).
        var dragged: Int?
        for action in actions {
            if case .turn(let shell, _) = action { dragged = shell }
        }
        if dragged != nil { dragTurns = (before: latestCore, accepted: 0, refusal: nil) }
        for action in actions {
            switch action {
            case .turn(let shell, let step):
                let result = send("shell.rotate", [Double(shell), Double(step)], port: port)
                if result.isAccepted {
                    dragTurns?.accepted += 1
                } else if dragTurns?.refusal == nil {
                    dragTurns?.refusal = result.code
                }
            case .advance:
                send("pearl.advance", [], port: port)
            case .select(let shell):
                if mirror.pickedShell != shell, let core = latestCore {
                    route(AmethystEscapeFeedbackPlan.picked(shell: shell, core: core))
                }
                mirror.pickedShell = shell
            case .isolate:
                break   // the controller keeps the isolated shell; the next frame draws it
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
        if let shell = dragged, let drag = dragTurns {
            dragTurns = nil
            if drag.accepted > 0, let before = drag.before, let after = latestCore {
                route(AmethystEscapeFeedbackPlan.drag(old: before, new: after, shell: shell, sectors: drag.accepted))
            } else if let code = drag.refusal {
                route(AmethystEscapeFeedbackPlan.refused(code: code))
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

    /// Brings every shell back ("Show all layers").
    func showAllLayers() {
        gestures.clearIsolation()
    }

    /// Sends `control` with `values`, shows a refusal in the panel and keeps its code in ``refusalLog``; an accepted
    /// `level.next` clears the isolation.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
            if control == "level.next" { gestures.clearIsolation() }
        } else {
            let plan = AmethystEscapeFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            // A drag's refusals are announced once, after its last turn, and only when no turn was accepted.
            if dragTurns == nil { route(plan) }
            refusalLog.append(result.code)
            if refusalLog.count > Self.refusalLogLimit { refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit) }
        }
        return result
    }

    // MARK: Feedback and sound (feature 366)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: AmethystEscapeFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
    }

    /// Moves the panel's shell pick by `delta` shells (wrapping) and announces the shell ("Shell 2 picked.").
    func pickShell(_ delta: Int) {
        let before = mirror.pickedShell
        mirror.pickNext(delta)
        guard mirror.pickedShell != before, let core = latestCore else { return }
        route(AmethystEscapeFeedbackPlan.picked(shell: mirror.pickedShell, core: core))
    }

    /// The ambient recipe of `core`: its pearl's shell, its shell count and its stage.
    static func recipe(_ core: AmethystEscapeExperienceCore) -> AmbientLoopRecipe {
        AmethystEscapeSoundRecipe.recipe(core.snapshot(time: 0))
    }

    /// Turns the ambient sound on or off; turning it on plays the recipe of the current crystal.
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

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the crystal (the camera
    /// fits the scene inside a 5 % margin), are `dark` (the backdrop clear) once a snapshot was drawn by the real scene;
    /// none otherwise.
    func probes(_ core: AmethystEscapeExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    func describe(_ core: AmethystEscapeExperienceCore) -> String {
        let play = core.play
        let level = play.level
        let snapshot = core.snapshot(time: 0)
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        mirror.levelNumber = core.levelNumber
        if let previous = latestCore {
            if dragTurns == nil { route(AmethystEscapeFeedbackPlan.after(old: previous, new: core)) }
            let opened = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
        } else {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(Self.recipe(core))
        }
        latestCore = core
        mirror.summary = AmethystEscapeFeedbackPlan.summaryText(core: core)
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = core.failureExplanation?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.smallest = core.certifiedSmallest
        mirror.moves = snapshot.moves
        mirror.budget = snapshot.budget
        mirror.sectors = snapshot.sectors
        mirror.shellNames = level.shells.indices.map { level.shellName($0) }
        mirror.offsets = snapshot.shells.map(\.offset)
        if mirror.pickedShell >= level.shells.count { mirror.pickedShell = 0 }
        let pearl = snapshot.escaped ? "outside the crystal"
            : "in \(level.shellName(snapshot.pearl.shell)), \(level.sectorName(snapshot.pearl.sector))"
        mirror.pearlLabel = "The pearl is " + pearl
        var text = ""
        if gestures.state == .shellDrag, let shell = gestures.draggedShell, level.shells.indices.contains(shell) {
            let n: Int = gestures.candidateSectors
            let name: String = level.shellName(shell)
            let sectors: String = abs(n) == 1 ? "1 sector" : "\(abs(n)) sectors"
            text += n == 0 ? name.prefix(1).uppercased() + name.dropFirst() + " would not turn. "
                : name.prefix(1).uppercased() + name.dropFirst()
                    + " would turn \(sectors) \(n > 0 ? "clockwise" : "anticlockwise"). "
        }
        if let isolated = gestures.isolated, level.shells.indices.contains(isolated) {
            text += "Showing \(level.shellName(isolated)) alone. "
        }
        text += "Amethyst Escape level \(core.levelNumber). "
        text += "\(snapshot.moves) of \(snapshot.budget) moves spent. The pearl is \(pearl). "
        text += "The exit gap is at \(level.sectorName(snapshot.exitGap)). "
        for index in level.shells.indices {
            let description = level.description(ofShell: index)
            text += description.prefix(1).uppercased() + description.dropFirst()
                + "; turned \(snapshot.shells[index].offset). "
        }
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The pearl escaped through the exit gap."
            if let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
            mirror.status = "Won"
        case .failed, .result:
            let reason: String
            switch play.failure {
            case .wedge(let shell, let sector):
                reason = "The pearl fell into the blocked wedge of \(level.shellName(shell)), "
                    + "\(level.sectorName(sector))."
            case .budget, .none: reason = "The move budget ran out before the pearl escaped."
            }
            text += reason
            if let explanation = mirror.failureText { text += " " + explanation }
            mirror.status = "Failed: " + reason
        default:
            mirror.status = snapshot.moves == 0 ? "Ready" : "Playing"
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AmethystEscapeControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
