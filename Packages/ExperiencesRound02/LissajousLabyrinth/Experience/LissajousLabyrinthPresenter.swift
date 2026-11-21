// LissajousLabyrinthPresenter — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-003 … 005, 007; clarifications Q4,
// Q5). Draws the adapter's immutable snapshot with `LissajousLabyrinthThreadScene` at the host's quality tier (tier n
// is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the tracer head
// still under Reduce Motion (the snapshot time stays at 0 and the shimmer stops) and caps the glow under Reduce
// Flashing. A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads
// `core.snapshot`: no drawing result reaches the kernel (renderer purity, R2-G02-INV-10).
// Feature 314 (R02-G02-04) T-R02G0204-005 (FR-R02G0204-001 … 006): canvas touches go through
// `LissajousLabyrinthGestureController`: one finger turns a dial ring and sends one `dial.set` on release, two fingers
// orbit the camera (presentation only), a double tap on empty space resets it. The selection, the turn's candidate and
// the pending values are mirrored for the scene, the description and the controls. The panel's steppers set pending
// values (`stepPending`, announced, no action); `applyPending` sends `LissajousLabyrinthPending.actions(from:)` in order,
// stops at the first refusal (announced with its reason) or when the level ends (announced as its outcome) and drops
// the rest; `clearPending` drops them; any change of the play or level from elsewhere drops them too. Announcements go
// through `ExperienceFeedback` (`feedback`, `.shared` unless a test injects one) and are logged in `announcements`.
// Feature 315 (R02-G02-05) T-R02G0205-005 (FR-R02G0205-001 … 005): the mirror carries the tutorial instruction, the hint
// revealed so far (`showHint(port:)` reveals the next of three levels for the current play and tells the core a hint
// was shown; any change of the play hides it), the failure explanation, the mode, the open levels with their stars, the
// goal (allowance and certified shortest); `retry` starts the level again in its mode, and the daily level is chosen
// from the local calendar date read here (`playDaily(port:date:)`), never in the core.
#if os(iOS)
import Foundation
import LissajousLabyrinthCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class LissajousLabyrinthMirror {
    /// The four dials; nil before the first description.
    var dials: LissajousLabyrinthDials?
    /// The play's stage.
    var stage: LissajousLabyrinthStage = .loading
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions spent.
    var spent = 0
    /// The action allowance.
    var allowance = 0
    /// The text of the last refused change, if any.
    var message: String?
    /// The selected dial (feature 314): outlined in the scene and named in the description.
    var selectedDial: LissajousLabyrinthDial = .frequencyA
    /// The value a running turn would set; nil while no dial is being turned.
    var candidate: LissajousLabyrinthAction?
    /// The values the panel's steppers set but did not apply yet (feature 314); empty when nothing is pending.
    var pending = LissajousLabyrinthPending()
    /// The tutorial instruction; nil when the tutorial is done (feature 315).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 315).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 315).
    var failureText: String?
    /// The mode (feature 315).
    var mode: LissajousLabyrinthMode = .campaign
    /// The highest open level and the stars of each solved level (feature 315).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The certified shortest solution length of the current level (feature 315).
    var shortest = 0
}

/// One entry of the tier log: the tier drawn and why it changed.
struct LissajousLabyrinthTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Lissajous Labyrinth.
@MainActor
final class LissajousLabyrinthPresenter: ExperiencePresenter {
    typealias Core = LissajousLabyrinthExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = LissajousLabyrinthMirror()
    let scene = LissajousLabyrinthThreadScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0203-004).
    private(set) var tierLog: [LissajousLabyrinthTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: LissajousLabyrinthSceneSnapshot?
    /// The gesture controller (feature 314): arbitration, turns, orbit and the selection.
    private(set) var gestures = LissajousLabyrinthGestureController()
    /// The last described core (pending values, adjustments and the outside-change check).
    private(set) var latestCore: LissajousLabyrinthExperienceCore?
    /// True while `applyPending` sends its actions, so the described changes do not count as outside changes.
    private var applying = false
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 315).
    private var hintKey: String?
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 315).
    private(set) var dailyDate: DateComponents?
    /// The feedback route of announcements (tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every announcement made, oldest first (tests and diagnostics).
    private(set) var announcements: [String] = []

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the thread program's fragment source with one that does not compile.
    func breakThreadShader() {
        scene.threadFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: LissajousLabyrinthExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = LissajousLabyrinthTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(LissajousLabyrinthTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        playing = core.play.stage == .playing
        scene.orbit = gestures.orbit
        scene.selectedDial = gestures.selectedDial
        scene.preview = gestures.preview
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// Whether the play was in stage `playing` at the last frame (gestures answer only then).
    private var playing = false

    // MARK: Touch controls (feature 314)

    /// The canvas gestures send kernel actions only.
    var gestureActions: Set<String> { ["dial.set"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(LissajousLabyrinthExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller; a finished turn sends its one `dial.set`.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let action = gestures.handle(event, viewSize: viewSize, snapshot: snapshot, playing: playing)
        mirror.selectedDial = gestures.selectedDial
        mirror.candidate = gestures.preview
        if let action { send(action, port: port) }
    }

    /// Drops a touch in progress (the shell suspends the experience): the turn ends without an action.
    func cancelPointers() {
        gestures.cancel()
        mirror.candidate = nil
    }

    /// Selects `dial` (a stepper was used or a test selects it).
    func select(_ dial: LissajousLabyrinthDial) {
        gestures.select(dial)
        mirror.selectedDial = dial
    }

    /// Returns the camera to the authored view ("Reset view").
    func resetView() {
        gestures.resetOrbit()
    }

    /// Sends `action` as `dial.set [index, value]`; a refusal is shown and announced with its reason.
    @discardableResult
    func send(_ action: LissajousLabyrinthAction, port: ExperienceActionPort) -> ActionResult {
        let index = LissajousLabyrinthDial.allCases.firstIndex(of: action.dial) ?? 0
        return send("dial.set", [Double(index), Double(action.value)], port: port)
    }

    /// Sends `control` with `values`; a refusal is shown and announced with its reason.
    @discardableResult
    func send(_ control: String, _ values: [Double] = [], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            let text = "That change was refused: \(result.code)"
            mirror.message = text
            announce(text, kind: .rejection)
        }
        return result
    }

    /// Steps the pending value of `dial` by `delta` (wrapping in its range), selects it and announces
    /// "<Dial name> <value> pending. Apply to change."; sends no action.
    func stepPending(_ dial: LissajousLabyrinthDial, by delta: Int) {
        guard let core = latestCore else { return }
        select(dial)
        mirror.pending.step(dial, by: delta, current: core.play.dials)
        let value = mirror.pending.values[dial] ?? core.play.dials[dial]
        announce("\(Self.title(dial)) \(value) pending. Apply to change.", kind: .state)
    }

    /// Sends the pending values as actions in `LissajousLabyrinthPending.actions(from:)` order; stops at the first
    /// refusal (announced by `send`) or when the level ends (its outcome is announced) and drops the rest; the pending
    /// values are cleared in every case. Returns the results in order.
    @discardableResult
    func applyPending(port: ExperienceActionPort) -> [ActionResult] {
        guard let core = latestCore, !mirror.pending.isEmpty else { return [] }
        let actions = mirror.pending.actions(from: core.play.dials)
        applying = true
        defer {
            applying = false
            mirror.pending.clear()
        }
        var results: [ActionResult] = []
        for action in actions {
            if let now = latestCore, now.play.stage != .playing {
                announce(now.play.stage == .won ? "The path is safe." : "Out of actions.", kind: .outcome)
                break
            }
            let result = send(action, port: port)
            results.append(result)
            if !result.isAccepted { break }
        }
        return results
    }

    // MARK: Teaching and progression (feature 315)

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: LissajousLabyrinthExperienceCore) -> String {
        "\(core.levelNumber)/\(core.mode)/\(core.play.fingerprint)"
    }

    /// Reveals the next hint level (up to 3) for the current play and tells the core that a hint was shown
    /// (`tutorial.hint`, which only advances the tutorial); nothing when the play has ended or no solution is reachable.
    func showHint(port: ExperienceActionPort) {
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
        announce(hint.text, kind: .state)
        if core.tutorial == .checkpoints { _ = port.send("tutorial.hint", []) }
    }

    /// Ends the tutorial of the current level.
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", port: port)
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
    func retry(port: ExperienceActionPort, date: DateComponents = LissajousLabyrinthPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort,
                   date: DateComponents = LissajousLabyrinthPresenter.today()) -> ActionResult {
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

    /// Drops the pending values; sends nothing.
    func clearPending() {
        mirror.pending.clear()
    }

    /// Announces `text` through the feedback route and logs it.
    func announce(_ text: String, kind: AnnouncementKind) {
        feedback.announce(text, kind: kind)
        announcements.append(text)
    }

    /// The dial names in control order.
    static let dialNames: [String] = ["frequency A", "frequency B", "phase A", "phase C"]

    /// The capitalised name of `dial`: "Frequency A", "Frequency B", "Phase A" or "Phase C".
    static func title(_ dial: LissajousLabyrinthDial) -> String {
        let name = dialNames[LissajousLabyrinthDial.allCases.firstIndex(of: dial) ?? 0]
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    func describe(_ core: LissajousLabyrinthExperienceCore) -> String {
        let play = core.play
        if !applying, !mirror.pending.isEmpty, let previous = latestCore,
           previous.levelNumber != core.levelNumber || previous.play.records != core.play.records
            || previous.play.dials != core.play.dials {
            mirror.pending.clear()
        }
        latestCore = core
        if let key = hintKey, key != Self.hintKey(core) {
            hintKey = nil
            mirror.hintLevel = 0
            mirror.hintText = nil
        }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = core.failureExplanation?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        mirror.stars = core.progress.solved.mapValues(\.stars)
        mirror.shortest = core.certifiedShortest
        mirror.dials = play.dials
        mirror.stage = play.stage
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.allowance = play.level.allowance
        let snapshot = core.snapshot(time: 0)
        var text = "Lissajous Labyrinth level \(core.levelNumber). "
        for (index, dial) in LissajousLabyrinthDial.allCases.enumerated() {
            text += "\(Self.dialNames[index].prefix(1).uppercased() + Self.dialNames[index].dropFirst()) \(play.dials[dial]). "
        }
        text += "\(snapshot.visits.count) of \(play.level.checkpoints.count) checkpoints in order. "
        if let obstacle = snapshot.contactObstacle { text += "The path touches obstacle \(obstacle + 1). " }
        let selected = gestures.selectedDial
        text += "Dial \(Self.title(selected)) selected: \(mirror.candidate?.value ?? play.dials[selected]). "
        text += "Actions \(play.spent) of \(play.level.allowance). "
        switch play.stage {
        case .won:
            text += "The path is safe."
            if core.mode != .practice {
                let stars = LissajousLabyrinthProgress.stars(actions: play.spent, shortest: core.certifiedShortest)
                text += " \(stars) of 3 stars."
            }
        case .failed:
            text += "Out of actions. " + (core.failureExplanation?.text ?? "")
        default: break
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(LissajousLabyrinthControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
