// BackwardsAuroraPresenter — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-003, 004, 005, 007; clarifications
// Q2, Q4, Q5). Draws the adapter's immutable snapshot with `BackwardsAuroraAuroraScene` at the host's quality tier (tier
// n is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the pulses and
// the shimmer still under Reduce Motion, and caps the glow under Reduce Flashing. The panel's chosen section (start,
// end) lives in the mirror as presentation state: a level opens with start 0 and end 1, both clamped to the wave; it
// never reaches the kernel except through the declared `wave.reverse` control. A memory warning releases the GPU
// objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel
// (renderer purity). Its probes (two ground corners) let the verification runner check a frame.
// Feature 394 (R02-G10-04): `pointer(_:viewSize:port:)` routes canvas touches through
// `BackwardsAuroraGestureController` (a tap on a sample moves the nearer end of the section, an end drag moves that end,
// a swipe along the section reverses it, a held press freezes the timeline and previews the reversal, two fingers
// orbit, a double tap or "Reset view" resets); the preview is drawn and described while it lasts, with the shimmer and
// pulses held; refused reversals are shown and kept in `refusalLog` with their reason codes.
// Feature 395 (R02-G10-05) T-R02G1005-005 (FR-R02G1005-001 … 005): the mirror carries the tutorial instruction, the
// hint revealed so far (`showHint()` reveals the next of three levels; the bounded search runs off the main actor, a
// stale search owns nothing, and any change of the play hides it), the failure explanation, the mode, the open levels
// with their bands and stars and the goal; `retry` starts the level again in its mode, `undoReversal` takes back the
// last reversal, and the daily level is chosen from the local calendar date read here (`playDaily(port:date:)`), never
// in the core.
#if os(iOS)
import BackwardsAuroraCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show and choose: the latest state the presenter described and the panel's section.
@MainActor
@Observable
final class BackwardsAuroraMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The reversals spent and the budget.
    var spent = 0
    var budget = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// The checkpoints, the worst bend and the distance in words.
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen section's start and end.
    var start = 0
    var end = 1
    /// The play the section is clamped against (a copy; never sent anywhere).
    var play: BackwardsAuroraPlay?
    /// The text of the last refused change, if any.
    var message: String?
    /// The freeze preview's words while it shows (feature 394), or nil.
    var previewText: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 395).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 395).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 395).
    var failureText: String?
    /// The mode (feature 395).
    var mode: BackwardsAuroraMode = .campaign
    /// The highest open level and the stars of each won level (feature 395).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The certified smallest reversal count of the current level (the goal, feature 395).
    var smallest = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen).
    var pickedLevel = 1

    /// The goal and the level's difficulty band, with its best stars when won (feature 395).
    var goalLabel: String {
        let band: Int = BackwardsAuroraProgress.band(of: levelNumber)
        var text = "Goal: fold the aurora back in \(smallest) reversals; band \(band) of 5"
        if let best = stars[levelNumber] { text += "; best \(best) of 3 stars" }
        return text
    }

    /// The wave's sample count (12 while no play is followed).
    var count: Int { play?.wave.count ?? 12 }
    /// The chosen start in words.
    var startLabel: String { "start at sample \(start)" }
    /// The chosen end in words.
    var endLabel: String { "end at sample \(end)" }
    /// The chosen section in words.
    var sectionLabel: String { "section \(start) to \(end), \(end - start + 1) samples" }

    /// Moves the start by `delta`, clamped to 0 … N − 2; the end follows to stay after it.
    func stepStart(_ delta: Int) {
        start = min(max(start + delta, 0), count - 2)
        if end <= start { end = start + 1 }
    }

    /// Moves the end by `delta`, clamped to 1 … N − 1; the start follows to stay before it.
    func stepEnd(_ delta: Int) {
        end = min(max(end + delta, 1), count - 1)
        if start >= end { start = end - 1 }
    }

    /// Takes the new `play`: a new level resets the section to 0 … 1; otherwise it is clamped to the wave.
    func follow(_ play: BackwardsAuroraPlay) {
        let changedLevel: Bool = self.play?.level.id != play.level.id
        self.play = play
        if changedLevel {
            start = 0
            end = 1
        } else {
            stepStart(0)
            stepEnd(0)
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct BackwardsAuroraTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Backwards Aurora.
@MainActor
final class BackwardsAuroraPresenter: ExperiencePresenter {
    typealias Core = BackwardsAuroraExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = BackwardsAuroraMirror()
    let scene = BackwardsAuroraAuroraScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1003-004).
    private(set) var tierLog: [BackwardsAuroraTierChange] = []
    /// The last snapshot drawn (tests and the description); never carries a freeze preview.
    private(set) var lastSnapshot: BackwardsAuroraSceneSnapshot?
    /// The play last drawn (the gestures read it).
    private(set) var lastPlay: BackwardsAuroraPlay?
    /// The gesture controller (feature 394): ends, swipes, freeze preview, orbit.
    private(set) var gestures = BackwardsAuroraGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64
    /// The latest core described (feature 395): hints and retry read it.
    private(set) var latestCore: BackwardsAuroraExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 395).
    private var hintKey: String?
    /// The hints searched for a play, by that play's key: one search per play, every level from it (feature 395).
    private var hintCache: (key: String, hints: [BackwardsAuroraHint?])?
    /// The search under way, off the main actor, for the play of ``hintKey`` (feature 395).
    private(set) var hintSearch: Task<Void, Never>?
    /// The text shown while the search runs.
    static let searchingText = "Finding a hint…"
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 395).
    private(set) var dailyDate: DateComponents?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the aurora program's fragment source with one that does not compile.
    func breakAuroraShader() {
        scene.auroraFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    /// Follows `core`'s play in the mirror when it changed.
    private func follow(_ core: BackwardsAuroraExperienceCore) {
        if mirror.play != core.play { mirror.follow(core.play) }
    }

    func draw(_ core: BackwardsAuroraExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = BackwardsAuroraTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(BackwardsAuroraTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(sectionStart: mirror.start, sectionEnd: mirror.end, time: time)
        lastSnapshot = snapshot
        lastPlay = core.play
        gestures.tick(at: ProcessInfo.processInfo.systemUptime, snapshot: snapshot, play: core.play)
        scene.orbit = gestures.orbit
        let shown: BackwardsAuroraSceneSnapshot
        if let preview = gestures.preview {
            shown = snapshot.withPreview(preview.samples)
            mirror.previewText = preview.text
        } else {
            shown = snapshot
            mirror.previewText = nil
        }
        // The timeline freezes while a preview shows: the shimmer and the pulses hold still.
        try scene.render(shown, tier: drawn, context: context, frame: frame,
                         animate: !reduceMotion && gestures.preview == nil)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the aurora (the camera
    /// fits the scene inside a 5 % margin), are `dark` (the midnight ground) once a snapshot was drawn by the real
    /// scene; none otherwise.
    func probes(_ core: BackwardsAuroraExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "ground-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "ground-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    func describe(_ core: BackwardsAuroraExperienceCore) -> String {
        let play = core.play
        let level = play.level
        let wave = play.wave
        follow(core)
        absorbProgress(core)
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.budget = level.budget
        mirror.targetLabel = "Level: " + level.targetDescription()
        var checkpoints: [String] = []
        for index in level.checkpoints.indices { checkpoints.append(level.checkpointName(index, wave: wave)) }
        let distance = play.distance
        mirror.measureLabel = level.bendDescription(wave) + "; distance \(distance.numerator)/\(distance.denominator); "
            + BackwardsAuroraLevel.reversalsText(play.remaining)
        var text = "Backwards Aurora level \(core.levelNumber). "
        text += "\(play.spent) of \(level.budget) reversals spent. \(mirror.measureLabel). "
        text += checkpoints.joined(separator: "; ") + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every checkpoint matches and every bend is within the limit."
            if let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
            mirror.status = "Won"
        case .failed, .result:
            let reason: String = mirror.failureText
                ?? BackwardsAuroraSceneSnapshot.failureText(play.failure, budget: level.budget) ?? "The play failed."
            text += reason
            mirror.status = "Failed: " + reason
        default:
            mirror.status = play.spent == 0 ? "Ready" : "Playing"
        }
        text += " " + mirror.goalLabel + "."
        if let instruction = mirror.instruction { text += " Tutorial: " + instruction }
        if let hint = mirror.hintText { text += " Hint: " + hint }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(BackwardsAuroraControls(port: port, mirror: mirror, presenter: self,
                                        resetView: { [weak self] in self?.resetView() },
                                        sender: { [weak self] control, values in
                                            self?.send(control, values, port: port)
                                        }))
    }

    // MARK: Touch controls (feature 394, R02-G10-04)

    /// The canvas gestures send reversals only; the ends are presentation state.
    var gestureActions: Set<String> { ["wave.reverse"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(BackwardsAuroraExperienceCore.actionIDs) }

    /// What a swipe on a finished play shows.
    static let finishedMessage = "The play is over: undo or go to the next level"

    /// Routes a canvas touch through the gesture controller with the panel's section and applies what it returns, in
    /// order: new ends go to the mirror, a reversal is sent through the port; a swipe on a finished play explains that
    /// the play is over.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let base = lastSnapshot, let play = lastPlay else { return }
        let snapshot: BackwardsAuroraSceneSnapshot = BackwardsAuroraSceneSnapshot(
            play: play, levelNumber: base.levelNumber, sectionStart: mirror.start, sectionEnd: mirror.end,
            time: base.time)
        let wasPlaying: Bool = play.stage == .playing
        let before: BackwardsAuroraGestureController.State = gestures.state
        let actions: [BackwardsAuroraGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot,
                                                                      play: play)
        if event.phase == .ended, !wasPlaying, actions.isEmpty, before == .swipe {
            mirror.message = Self.finishedMessage
        }
        for action in actions {
            switch action {
            case let .setStart(k):
                mirror.start = k
                mirror.stepStart(0)
            case let .setEnd(k):
                mirror.end = k
                mirror.stepEnd(0)
            case let .reverse(start, end):
                send("wave.reverse", [Double(start), Double(end)], port: port)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
    }

    // MARK: Teaching and progression (feature 395, R02-G10-05)

    /// Takes the core's teaching and progress state into the mirror: the tutorial instruction, the failure
    /// explanation, the mode, the open levels with their stars and the goal; a change of the play hides the hint.
    private func absorbProgress(_ core: BackwardsAuroraExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        latestCore = core
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = BackwardsAuroraFailureExplanation(play: core.play)?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.smallest = core.certifiedSmallest
    }

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: BackwardsAuroraExperienceCore) -> String {
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
        let play: BackwardsAuroraPlay = core.play
        hintSearch = Task.detached(priority: .userInitiated) { [weak self] in
            // One search: the plan's first reversal gives every level (`BackwardsAuroraHint.at(level:)`).
            let first: BackwardsAuroraHint? = BackwardsAuroraHints.hint(level: 1, play: play)
            var hints: [BackwardsAuroraHint?] = []
            for level in 1...3 { hints.append(first?.at(level: level)) }
            await self?.finishSearch(hints, key: key)
        }
    }

    /// Takes the three hint levels searched for the play of `key`: cached, and shown when that play is still current.
    private func finishSearch(_ hints: [BackwardsAuroraHint?], key: String) {
        // A search for a play that is no longer the hinted one (hidden or replaced since) owns nothing: it must not
        // clear a newer search's handle or overwrite the cache.
        guard hintKey == key else { return }
        hintSearch = nil
        hintCache = (key, hints)
        guard let core = latestCore, Self.hintKey(core) == key else { return }
        reveal(hints, level: mirror.hintLevel, key: key)
    }

    /// Shows `hints`' level `level` for the play of `key`, or hides the hint when the play has none.
    private func reveal(_ hints: [BackwardsAuroraHint?], level: Int, key: String) {
        guard hints.indices.contains(level - 1), let hint = hints[level - 1] else {
            clearHint()
            return
        }
        hintKey = key
        mirror.hintLevel = level
        mirror.hintText = hint.text
    }

    /// Ends the tutorial of the current level.
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", [], port: port)
    }

    /// Takes back the last reversal (`play.undo`); after a failure this returns the play to playing.
    @discardableResult
    func undoReversal(port: ExperienceActionPort) -> ActionResult {
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
    func retry(port: ExperienceActionPort, date: DateComponents = BackwardsAuroraPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort, date: DateComponents = BackwardsAuroraPresenter.today()) -> ActionResult {
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

    /// Returns the camera to the authored view ("Reset view"; presentation only).
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
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }
}
#endif
