// ChronoConstellatorPresenter — feature 353 (R02-G06-03) T-R02G0603-006 (FR-R02G0603-003, 004, 005, 007; clarifications
// Q2, Q4). Draws the adapter's immutable snapshot with `ChronoConstellatorSkyScene` at the host's quality tier (tier n is
// the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the ribbon shimmer
// still under Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory warning
// releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result
// reaches the kernel (renderer purity). Its probes (two field corners) let the verification runner check a frame.
// Feature 354 (R02-G06-04) T-R02G0604-005 (FR-R02G0604-001 … 008; clarifications Q1–Q5): canvas touches go through
// `ChronoConstellatorGestureController`: a star dragged at tick 0 to another cell of its loop sends one `star.phase`, a
// scrub along the timeline band sends `time.step` or `time.rewind` then `time.step`, a long press on a star toggles its
// standard hold (`star.hold` / `star.release`), a tap on a star picks it in the panel, two fingers orbit the camera and
// a double tap on empty space or `resetView()` ("Reset view") returns to the authored view (presentation only: never in
// the digest, the snapshot or the kernel). While a star is dragged its candidate cell is outlined and the description
// begins "Star n (shape) would start at row r, column c"; while scrubbing it begins "Scrub to tick t of T"; a star
// gesture after tick 0 says "Edits are made at tick 0: rewind first". A refused action is shown in the panel and its
// code kept in ``ChronoConstellatorPresenter/refusalLog``.
// Feature 355 (R02-G06-05) T-R02G0605-005 (FR-R02G0605-001 … 005; clarifications Q1–Q5): the mirror carries the
// tutorial instruction, the hint revealed so far (`showHint()` reveals the next of three levels for the current play;
// the hint level is presentation only and any change of the play — level, mode or play fingerprint — hides it), the
// failure explanation, the mode, the open levels with their stars and the goal (edits in use, budget and certified
// smallest edit count); `retry` starts the level again in its mode, `undo` takes back the last change, `rewind` returns
// to tick 0, and the daily level is chosen from the local calendar date read here (`playDaily(port:date:)`, sent as
// `mode.daily [year, month, day]`), never in the core.
#if os(iOS)
import ChronoConstellatorCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class ChronoConstellatorMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The edits left.
    var remaining = 0
    /// The replay tick and the tick limit.
    var tick = 0
    var tickLimit = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// Each star's name ("star 1 (ring)"), start phase, loop length and holds (presentation only).
    var starNames: [String] = []
    var phases: [Int] = []
    var loopLengths: [Int] = []
    var holds: [[String]] = []
    /// The star picked (presentation only).
    var pickedStar = 0
    /// The text of the last refused change, if any.
    var message: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 355).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 355).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 355).
    var failureText: String?
    /// The mode (feature 355).
    var mode: ChronoConstellatorMode = .campaign
    /// The highest open level and the stars of each won level (feature 355).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The goal: the edits in use, the budget and the certified smallest edit count (feature 355).
    var spent = 0
    var budget = 0
    var smallest = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen).
    var pickedLevel = 1

    /// The picked star's name, or "none".
    var pickedStarLabel: String {
        starNames.indices.contains(pickedStar) ? starNames[pickedStar].capitalized : "none"
    }

    /// The picked star's start phase as "phase p of L".
    var pickedPhaseLabel: String {
        guard phases.indices.contains(pickedStar), loopLengths.indices.contains(pickedStar) else { return "" }
        return "phase \(phases[pickedStar]) of \(loopLengths[pickedStar])"
    }

    /// The picked star's holds, or "no holds".
    var pickedHoldsLabel: String {
        guard holds.indices.contains(pickedStar), !holds[pickedStar].isEmpty else { return "no holds" }
        return holds[pickedStar].joined(separator: ", ")
    }

    /// Moves the pick by `delta` stars, wrapping.
    func pickNext(_ delta: Int) {
        guard !starNames.isEmpty else { return }
        pickedStar = ((pickedStar + delta) % starNames.count + starNames.count) % starNames.count
    }

    /// The picked star's start phase moved by `delta` cells round its loop; nil without a star.
    func phase(after delta: Int) -> Int? {
        guard phases.indices.contains(pickedStar), loopLengths.indices.contains(pickedStar),
              loopLengths[pickedStar] > 0 else { return nil }
        let length = loopLengths[pickedStar]
        return ((phases[pickedStar] + delta) % length + length) % length
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct ChronoConstellatorTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Chrono Constellator.
@MainActor
final class ChronoConstellatorPresenter: ExperiencePresenter {
    typealias Core = ChronoConstellatorExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = ChronoConstellatorMirror()
    let scene = ChronoConstellatorSkyScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0603-004).
    private(set) var tierLog: [ChronoConstellatorTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: ChronoConstellatorSceneSnapshot?
    /// The gesture controller (feature 354): star drags, scrubs, hold presses, taps, orbit and the candidate cell.
    private(set) var gestures = ChronoConstellatorGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64
    /// The latest core described (feature 355): hints and retry read it.
    private(set) var latestCore: ChronoConstellatorExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 355).
    private var hintKey: String?
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 355).
    private(set) var dailyDate: DateComponents?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the field program's fragment source with one that does not compile.
    func breakFieldShader() {
        scene.fieldFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: ChronoConstellatorExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = ChronoConstellatorTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(ChronoConstellatorTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        scene.orbit = gestures.orbit
        scene.candidateCell = gestures.candidateCell
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    // MARK: Touch controls (feature 354)

    /// The canvas gestures send start phases, holds, releases, steps and rewinds.
    var gestureActions: Set<String> { ["star.phase", "star.hold", "star.release", "time.step", "time.rewind"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(ChronoConstellatorExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller and sends the actions it returns, in order; a star
    /// gesture released after tick 0 explains that edits are made at tick 0.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let wasStarGesture: Bool = gestures.state == .starDrag
        let actions: [ChronoConstellatorGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        if wasStarGesture, event.phase == .ended, actions.isEmpty, snapshot.tick > 0, snapshot.stage == .playing {
            mirror.message = Self.tickZeroMessage
        }
        for action in actions {
            switch action {
            case .phase(let star, let index):
                send("star.phase", [Double(star), Double(index)], port: port)
            case .step(let ticks):
                send("time.step", [Double(ticks)], port: port)
            case .rewind:
                send("time.rewind", [], port: port)
            case .hold(let star, let start, let length):
                send("star.hold", [Double(star), Double(start), Double(length)], port: port)
            case .release(let star, let start):
                send("star.release", [Double(star), Double(start)], port: port)
            case .select(let star):
                mirror.pickedStar = star
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
    }

    /// What a star gesture after tick 0 shows.
    static let tickZeroMessage = "Edits are made at tick 0: rewind first"

    /// Drops a touch in progress (the shell suspends the experience): a gesture under way is abandoned without an
    /// action; the orbit is presentation only and returns to the authored view.
    func cancelPointers() {
        gestures.cancel()
    }

    /// Returns the camera to the authored view ("Reset view").
    func resetView() {
        gestures.resetView()
    }

    /// Sends `control` with `values`, shows a refusal in the panel and keeps its code in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            mirror.message = "That change was refused: \(result.code)"
            refusalLog.append(result.code)
            if refusalLog.count > Self.refusalLogLimit { refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit) }
        }
        return result
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the grid (the camera fits
    /// the scene inside a 5 % margin), are `dark` (the indigo clear) once a snapshot was drawn by the real scene; none
    /// otherwise.
    func probes(_ core: ChronoConstellatorExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "field-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "field-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    // MARK: Teaching and progression (feature 355)

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: ChronoConstellatorExperienceCore) -> String {
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

    /// Returns the replay to tick 0 keeping the timeline (`time.rewind`); also after a failure.
    @discardableResult
    func rewind(port: ExperienceActionPort) -> ActionResult {
        send("time.rewind", [], port: port)
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
    func retry(port: ExperienceActionPort, date: DateComponents = ChronoConstellatorPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort,
                   date: DateComponents = ChronoConstellatorPresenter.today()) -> ActionResult {
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

    func describe(_ core: ChronoConstellatorExperienceCore) -> String {
        let play = core.play
        let level = play.level
        let snapshot = core.snapshot(time: 0)
        mirror.levelNumber = core.levelNumber
        mirror.remaining = snapshot.remaining
        mirror.tick = snapshot.tick
        mirror.tickLimit = snapshot.tickLimit
        mirror.starNames = level.stars.indices.map { "star \($0 + 1) (\(ChronoConstellatorLevel.shape(of: $0).name))" }
        mirror.phases = snapshot.phases
        mirror.loopLengths = snapshot.stars.map(\.loop.count)
        mirror.holds = level.stars.indices.map { star in
            snapshot.holds.filter { $0.star == star }.map { "hold from tick \($0.start) for \($0.length) ticks" }
        }
        if mirror.pickedStar >= level.stars.count { mirror.pickedStar = 0 }
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        latestCore = core
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = core.failureExplanation?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.spent = core.play.spent
        mirror.budget = core.play.level.budget
        mirror.smallest = core.certifiedSmallest
        var text = ""
        if let cell = gestures.candidateCell, gestures.state == .starDrag, cell >= 0, cell < level.columns * level.rows,
           let star = gestures.draggedStar, level.stars.indices.contains(star) {
            text += "Star \(star + 1) (\(ChronoConstellatorLevel.shape(of: star).name)) would start at row "
                + "\(cell / max(level.columns, 1) + 1), column \(cell % max(level.columns, 1) + 1). "
        }
        if let tick = gestures.scrubTick, gestures.state == .scrub {
            text += "Scrub to tick \(tick) of \(snapshot.tickLimit). "
        }
        text += "Chrono Constellator level \(core.levelNumber). "
        text += "Tick \(snapshot.tick) of \(snapshot.tickLimit); \(snapshot.remaining) edits left. "
        for index in level.stars.indices {
            let star = snapshot.stars[index]
            let where_ = star.onTarget ? "on its target" : "off its target"
            text += level.description(ofStar: index).prefix(1).uppercased()
                + level.description(ofStar: index).dropFirst() + "; start phase \(snapshot.phases[index]), \(where_). "
        }
        switch play.stage {
        case .won:
            text += "Every star stands on its target."
            if let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
            mirror.status = "Won"
        case .failed:
            let reason: String
            switch play.failure {
            case .collision(let a, let b, let cell):
                reason = "Star \(a + 1) and star \(b + 1) collided at row \(cell / max(level.columns, 1) + 1), "
                    + "column \(cell % max(level.columns, 1) + 1)."
            case .time, .none: reason = "Time ran out before every star reached its target."
            }
            text += reason
            if let explanation = mirror.failureText { text += " " + explanation }
            mirror.status = "Failed: " + reason
        default:
            mirror.status = snapshot.tick == 0 ? "Editing the timeline" : "Replaying"
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ChronoConstellatorControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
