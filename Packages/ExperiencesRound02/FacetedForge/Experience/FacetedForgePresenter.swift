// FacetedForgePresenter — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-003, 004, 005, 007; clarifications
// Q2, Q4, Q5). Draws the adapter's immutable snapshot with `FacetedForgeCrystalScene` at the host's quality tier (tier
// n is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the shimmer
// still and shows the opening without easing under Reduce Motion, and caps the glow under Reduce Flashing. The preview
// choice (piece, direction, depth) lives in the mirror as presentation state: it starts at piece 0, direction 0 and
// the middle crossing depth, and is clamped to the play after every cut, undo or redo; it never reaches the kernel. A
// memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no
// drawing result reaches the kernel (renderer purity). Its probes (two ground corners) let the verification runner
// check a frame.
// Feature 374 (R02-G08-04) T-R02G0804-005 (FR-R02G0804-001 … 008; clarifications Q1–Q5): canvas touches go through
// `FacetedForgeGestureController`: a tap on a piece chooses it, a drag on the preview's rim tilts the plane to the
// nearest of the 13 directions, a drag on its interior (the depth slider) moves it by whole crossing depths, a tap on
// the plane commits the cut (`piece.cut`, never twice within 0.35 s), two fingers orbit the camera and a double tap on
// empty space or `resetView()` ("Reset view") returns to the authored view (presentation only: never in the digest,
// the snapshot or the kernel). While a drag previews a choice the scene draws it and the description begins "The cut
// plane would …"; a commit on a finished play says "The play is over: undo or go to the next level". A refused action
// is shown in the panel and its code kept in ``FacetedForgePresenter/refusalLog``.
// Feature 375 (R02-G08-05) T-R02G0805-005 (FR-R02G0805-001 … 005; clarifications Q1–Q5): the mirror carries the
// tutorial instruction, the hint revealed so far (`showHint()` reveals the next of three levels for the current play;
// the hint level is presentation only and any change of the play — level, mode or play fingerprint — hides it; a hint
// runs the solver's bounded search, so it is computed only when asked), the failure explanation, the mode, the open
// levels with their stars and the goal (cuts spent, budget and certified smallest cut count); `retry` starts the level
// again in its mode, `undoCut` takes back the last cut, and the daily level is chosen from the local calendar date read
// here (`playDaily(port:date:)`, sent as `mode.daily [year, month, day]`), never in the core.
// Feature 376 (R02-G08-06) T-R02G0806-005 (FR-R02G0806-001 … 006; clarifications Q1–Q5): after every described change
// the presenter routes `FacetedForgeFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback
// route (`feedback`, injectable; the shared `ExperienceFeedback` by default) and keeps a feedback log; refusals are
// announced with `refused(code:)` and shown in the panel in the same words (`refusalText(code:)`); preview choices are
// not announced (the pickers speak their values). The scene's lights (`FacetedForgeLights`: the cut-face glow and the
// sliver mark) settle on the first frame and afterwards fade every frame by the frame's elapsed time (0.45 s fades
// under Reduce Flashing). The ambient loop (`FacetedForgeSound`) is offered the recipe of the piece count, the target's piece
// count and the stage (`FacetedForgeSoundRecipe`) when a level or mode opens and when that recipe changes. The mirror
// carries the summary element's text and the sound choice. Presentation only.
// Feature 377 (R02-G08-07) T-R02G0807-005 (clarifications Q2, Q4, Q5): the mirror carries whether a verified replay
// exists for the level and the replay position; `startReplay`, `stepReplay` and `stopReplay` send `replay.start
// [level]`, `replay.step` and `replay.stop`; the Sound toggle saves the choice through `settings.sound [0/1]`
// (`saveSound(on:port:)`), and the restored choice (`core.soundOn`) is applied when the experience opens or the value
// changes; the results a restore dropped (`core.reconciliationDropped`) are announced once as `state` ("n saved
// results could not be checked and were removed.", "1 saved result could not be checked and was removed.").
#if os(iOS)
import FacetedForgeCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreAudioDSP

/// What the controls show and choose: the latest state the presenter described and the preview choice.
@MainActor
@Observable
final class FacetedForgeMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The cuts spent and the budget.
    var cuts = 0
    var budget = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// The target in words.
    var targetLabel = ""
    /// Each piece in words, in canonical order.
    var pieceNames: [String] = []
    /// The preview choice (presentation only).
    var choice = FacetedForgePreviewChoice(piece: 0, direction: 0, depth: 0)
    /// The play the choice is clamped against (a copy; never sent anywhere).
    var play: FacetedForgePlay?
    /// The text of the last refused change, if any.
    var message: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 375).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 375).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 375).
    var failureText: String?
    /// The mode (feature 375).
    var mode: FacetedForgeMode = .campaign
    /// The highest open level and the stars of each won level (feature 375).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The certified smallest cut count of the current level (the goal, feature 375).
    var smallest = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen).
    var pickedLevel = 1
    /// The summary element's text (feature 376): cuts left, every piece, the target and the next cut.
    var summary = ""
    /// Whether the ambient sound is on (feature 376; off by default).
    var soundOn = false
    /// Whether the current level has a verified solution to replay (feature 377).
    var replayAvailable = false
    /// Whether a replay is running (feature 377).
    var replaying = false
    /// The cuts of the running replay played so far (0 when no replay runs; feature 377).
    var replayPosition = 0
    /// The cuts of the running replay's trace (0 when no replay runs; feature 377).
    var replayLength = 0

    /// The chosen piece in words.
    var pieceLabel: String {
        pieceNames.indices.contains(choice.piece) ? pieceNames[choice.piece].capitalized : "none"
    }

    /// The chosen direction in words.
    var directionLabel: String { "direction " + FacetedForgeDirection.all[choice.direction].name }

    /// The chosen depth in words, or that the plane misses the chosen piece (feature 374, T-R02G0804-013).
    var depthLabel: String { misses ? "the plane misses this piece" : "depth \(choice.depth)" }

    /// Whether the chosen plane does not cross the chosen piece (no depth of the direction crosses it, or the chosen
    /// depth lies outside it): the plane is not drawn and a commit sends nothing.
    var misses: Bool {
        guard let play, play.pieces.indices.contains(choice.piece) else { return false }
        return !play.pieces[choice.piece].isCrossed(direction: choice.direction, depth: choice.depth)
    }

    /// Moves the piece pick by `delta`, wrapping; the depth moves to the middle crossing depth of the new piece.
    func pickPiece(_ delta: Int) {
        guard let play, !play.pieces.isEmpty else { return }
        let count = play.pieces.count
        let piece = ((choice.piece + delta) % count + count) % count
        choice = Self.middle(FacetedForgePreviewChoice(piece: piece, direction: choice.direction, depth: 0), play)
    }

    /// Moves the direction pick by `delta`, wrapping over the 13 directions; the depth moves to the middle crossing
    /// depth.
    func pickDirection(_ delta: Int) {
        guard let play else { return }
        let count = FacetedForgeDirection.all.count
        let direction = ((choice.direction + delta) % count + count) % count
        choice = Self.middle(FacetedForgePreviewChoice(piece: choice.piece, direction: direction, depth: 0), play)
    }

    /// Moves the depth by `step` crossing depths of the chosen piece.
    func stepDepth(_ step: Int) {
        guard let play else { return }
        choice = choice.steppingDepth(step, in: play)
    }

    /// Takes the new `play` and clamps the choice to it (after a cut, undo, redo or a new level).
    func follow(_ play: FacetedForgePlay) {
        let changedLevel = self.play?.level.id != play.level.id
        self.play = play
        choice = changedLevel ? FacetedForgePreviewChoice.initial(play) : choice.clamped(to: play)
    }

    /// `choice` with its depth set to the middle of the depths whose plane crosses its piece.
    static func middle(_ choice: FacetedForgePreviewChoice, _ play: FacetedForgePlay) -> FacetedForgePreviewChoice {
        guard play.pieces.indices.contains(choice.piece) else { return choice.clamped(to: play) }
        var crossing: [Int] = []
        for depth in FacetedForgeHalfSpace.depths
        where play.pieces[choice.piece].isCrossed(direction: choice.direction, depth: depth) {
            crossing.append(depth)
        }
        guard !crossing.isEmpty else { return choice }
        return FacetedForgePreviewChoice(piece: choice.piece, direction: choice.direction,
                                         depth: crossing[crossing.count / 2])
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct FacetedForgeTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Faceted Forge.
@MainActor
final class FacetedForgePresenter: ExperiencePresenter {
    typealias Core = FacetedForgeExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = FacetedForgeMirror()
    let scene = FacetedForgeCrystalScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0803-004).
    private(set) var tierLog: [FacetedForgeTierChange] = []
    /// The last snapshot of the kernel drawn with the mirror's choice (tests, the description and the gestures; never
    /// a gesture's candidate).
    private(set) var lastSnapshot: FacetedForgeSceneSnapshot?
    /// The play last drawn (the gestures' crossing depths).
    private(set) var lastPlay: FacetedForgePlay?
    /// The gesture controller (feature 374): piece choice, rim tilt, depth slide, commit, orbit.
    private(set) var gestures = FacetedForgeGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64
    /// The latest core described (feature 375): hints and retry read it.
    private(set) var latestCore: FacetedForgeExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 375).
    private var hintKey: String?
    /// The hint searched for a play, by that play's key (T-R02G0805-012): one search per play, every level from it.
    private var hintCache: (key: String, hint: FacetedForgeHint?)?
    /// The search under way, off the main actor, for the play of ``hintKey`` (T-R02G0805-012).
    private(set) var hintSearch: Task<Void, Never>?
    /// The text shown while the search runs.
    static let searchingText = "Finding a hint…"
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 375).
    private(set) var dailyDate: DateComponents?

    /// The feedback route of announcements and haptics (feature 376; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first (feature 376; tests and diagnostics).
    private(set) var feedbackLog: [FacetedForgeFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 376).
    private(set) var lights: FacetedForgeLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient sound (feature 376).
    let sound: FacetedForgeSound
    /// The opened centre of the last sliver piece drawn, so its cross can fade out after an undo (T-R02G0806-013).
    private(set) var fadingSliver: SIMD3<Double>?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        lights = FacetedForgeLights(reducedFlash: reduceFlashing)
        sound = FacetedForgeSound(recipe: FacetedForgeSoundRecipe.recipe(pieces: 1, target: 1, stage: .loading))
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
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

    /// The preview choice of `core`'s play, following it when the play changed.
    private func choice(for core: FacetedForgeExperienceCore) -> FacetedForgePreviewChoice {
        if mirror.play != core.play { mirror.follow(core.play) }
        return mirror.choice
    }

    func draw(_ core: FacetedForgeExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = FacetedForgeTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(FacetedForgeTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(choice: choice(for: core), time: time)
        lastSnapshot = snapshot
        lastPlay = core.play
        // The lights settle on the very first frame only; every later change, a level change included, fades.
        if let last = lastFrameTime {
            lights.step(toward: snapshot, elapsed: frame.time > last ? frame.time - last : 0)
        } else {
            lights.settle(to: snapshot)
        }
        lastFrameTime = frame.time
        if let piece = snapshot.failurePiece, snapshot.pieces.indices.contains(piece) {
            fadingSliver = FacetedForgeSceneGeometry.pieceCentre(piece, snapshot, reduceMotion: reduceMotion)
        } else if lights.sliver <= 0 {
            fadingSliver = nil
        }
        scene.lights = lights
        scene.fadingSliver = fadingSliver
        scene.orbit = gestures.orbit
        let shown: FacetedForgeSceneSnapshot
        if let candidate = gestures.candidate {
            shown = core.snapshot(choice: candidate, time: time)
        } else {
            shown = snapshot
        }
        try scene.render(shown, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    // MARK: Touch controls (feature 374)

    /// The canvas gestures send cuts.
    var gestureActions: Set<String> { ["piece.cut"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(FacetedForgeExperienceCore.actionIDs) }

    /// What a commit on a finished play shows.
    static let finishedMessage = "The play is over: undo or go to the next level"

    /// The touch-down of the current one-finger touch: its point and what it picked (for the finished-play message).
    private var touchDown: (id: Int, point: Vec2, pick: FacetedForgePick)?
    /// The fingers down now.
    private var fingersDown: Set<Int> = []
    /// Whether more than one finger has been down since the last time none was: such a gesture shows no message and
    /// commits nothing.
    private var multiTouch = false

    /// Routes a canvas touch through the gesture controller and applies what it returns, in order: a chosen preview
    /// goes to the mirror, a cut is sent through the port; a tap on the plane of a finished play explains that the play
    /// is over.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot, let play = lastPlay else { return }
        switch event.phase {
        case .began:
            fingersDown.insert(event.id)
            if fingersDown.count == 1, !multiTouch {
                let pick: FacetedForgePick = FacetedForgePicker.pick(
                    SIMD2(Double(event.location.x), Double(event.location.y)),
                    size: SIMD2(Double(viewSize.x), Double(viewSize.y)), snapshot: snapshot, orbit: gestures.orbit,
                    reduceMotion: reduceMotion)
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
        let actions: [FacetedForgeGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot,
                                                                   play: play)
        if event.phase == .ended, let down = touchDown, down.id == event.id, !multiTouch {
            touchDown = nil
            let travel: Double = Double((event.location - down.point).length)
            let tapped: Bool = down.pick == .plane && travel < FacetedForgeGestureController.tapDistance
            if tapped, actions.isEmpty, snapshot.stage != .playing { mirror.message = Self.finishedMessage }
        }
        if event.phase == .ended || event.phase == .cancelled {
            fingersDown.remove(event.id)
            if fingersDown.isEmpty { multiTouch = false }
        }
        for action in actions {
            switch action {
            case .choose(let choice):
                mirror.choice = choice.clamped(to: play)
            case .cut(let piece, let direction, let depth):
                send("piece.cut", [Double(piece), Double(direction), Double(depth)], port: port)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
    }

    // MARK: Teaching and progression (feature 375)

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: FacetedForgeExperienceCore) -> String {
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

    /// Reveals the next hint level (up to 3) for the current play; the hint is hidden when the play has none (won, or
    /// not started). Hints never change the state: no action is sent. The solver's bounded search runs once per play
    /// in a detached task, never on the frame (T-R02G0805-012): meanwhile the panel reads "Finding a hint…", and the
    /// result is shown only if the play it belongs to is still the current one; later levels come from the cache.
    func showHint() {
        guard let core = latestCore else { return }
        let key: String = Self.hintKey(core)
        let next: Int = hintKey == key ? min(mirror.hintLevel + 1, 3) : 1
        if let cached = hintCache, cached.key == key {
            reveal(cached.hint, level: next, key: key)
            return
        }
        guard hintSearch == nil || hintKey != key else { return }   // the search for this play is running
        hintKey = key
        mirror.hintLevel = next
        mirror.hintText = Self.searchingText
        let play: FacetedForgePlay = core.play
        hintSearch = Task.detached(priority: .userInitiated) { [weak self] in
            let found: FacetedForgeHint? = FacetedForgeHints.hint(level: 3, play: play)
            await self?.finishSearch(found, key: key)
        }
    }

    /// Takes the result of the search for the play of `key`: cached, and shown when that play is still current.
    private func finishSearch(_ hint: FacetedForgeHint?, key: String) {
        hintSearch = nil
        hintCache = (key, hint)
        guard hintKey == key, let core = latestCore, Self.hintKey(core) == key else { return }
        reveal(hint, level: mirror.hintLevel, key: key)
    }

    /// Shows `hint` at `level` for the play of `key`, or hides the hint when the play has none.
    private func reveal(_ hint: FacetedForgeHint?, level: Int, key: String) {
        guard let hint else {
            clearHint()
            return
        }
        hintKey = key
        mirror.hintLevel = max(level, 1)
        mirror.hintText = hint.at(level: max(level, 1)).text
    }

    /// Ends the tutorial of the current level.
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", [], port: port)
    }

    /// Takes back the last cut (`play.undo`); after a failure this returns the play to playing.
    @discardableResult
    func undoCut(port: ExperienceActionPort) -> ActionResult {
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
        case .replay(let level): return ("replay.start", [Double(level)])
        }
    }

    /// Starts the current level again in its mode; in daily mode with the date that opened it (today's local date
    /// when none is known).
    @discardableResult
    func retry(port: ExperienceActionPort, date: DateComponents = FacetedForgePresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort, date: DateComponents = FacetedForgePresenter.today()) -> ActionResult {
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
            let plan = FacetedForgeFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            route(plan)
            refusalLog.append(result.code)
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the crystal (the camera
    /// fits the scene inside a 5 % margin), are `dark` (the ground clear) once a snapshot was drawn by the real scene;
    /// none otherwise.
    func probes(_ core: FacetedForgeExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "ground-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "ground-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// Piece `index` of `play` in words: "piece 2: a quarter of the crystal, 6 faces" (the whole crystal is named as
    /// such).
    static func pieceName(_ index: Int, _ play: FacetedForgePlay) -> String {
        let share = play.shares[index]
        let faces = play.pieces[index].faceCount
        if share == .one { return "piece \(index + 1): the whole crystal, \(faces) faces" }
        return play.level.pieceName(index, share: share, faces: faces)
    }

    func describe(_ core: FacetedForgeExperienceCore) -> String {
        let play = core.play
        let level = play.level
        let choice = choice(for: core)
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        mirror.levelNumber = core.levelNumber
        if let previous = latestCore {
            route(FacetedForgeFeedbackPlan.after(old: previous, new: core))
            let opened = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
        } else {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(Self.recipe(core))
        }
        mirror.summary = FacetedForgeFeedbackPlan.summaryText(core: core, choice: choice)
        // Feature 377: the saved sound choice is applied when it first appears or changes.
        if latestCore == nil || latestCore?.soundOn != core.soundOn {
            if core.soundOn { sound.offer(Self.recipe(core)) }
            sound.setWanted(core.soundOn)
            mirror.soundOn = core.soundOn
        }
        if !droppedAnnounced, core.reconciliationDropped > 0 {
            droppedAnnounced = true
            route(FacetedForgeFeedbackPlan(text: Self.droppedText(core.reconciliationDropped), kind: .state,
                                           haptic: nil))
        }
        if let result = core.progress.solved[core.levelNumber] {
            mirror.replayAvailable = result.verified && !result.trace.isEmpty && !Self.isReplay(core.mode)
        } else {
            mirror.replayAvailable = false
        }
        if case .replay(let level) = core.mode {
            mirror.replaying = true
            mirror.replayPosition = core.play.records.count
            mirror.replayLength = core.progress.solved[level]?.trace.count ?? 0
        } else {
            mirror.replaying = false
            mirror.replayPosition = 0
            mirror.replayLength = 0
        }
        latestCore = core
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = core.failureExplanation?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.smallest = core.certifiedSmallest
        mirror.cuts = play.cuts
        mirror.budget = level.budget
        mirror.pieceNames = play.pieces.indices.map { Self.pieceName($0, play) }
        mirror.targetLabel = "Target: " + level.targetDescription()
        var text = ""
        if let candidate = gestures.candidate {
            if gestures.state == .rimDrag {
                text += "The cut plane would tilt to direction \(FacetedForgeDirection.all[candidate.direction].name). "
            } else if gestures.state == .depthDrag {
                text += "The cut plane would move to depth \(candidate.depth). "
            }
        }
        text += "Faceted Forge level \(core.levelNumber). "
        text += "\(play.cuts) of \(level.budget) cuts spent. Target: \(level.targetDescription()). "
        text += "\(play.pieces.count) " + (play.pieces.count == 1 ? "piece: " : "pieces: ")
        text += mirror.pieceNames.joined(separator: "; ") + ". "
        if mirror.misses {
            text += "The cut plane misses piece \(choice.piece + 1) in direction "
            text += "\(FacetedForgeDirection.all[choice.direction].name). "
        } else {
            text += "Next cut: piece \(choice.piece + 1), direction "
            text += "\(FacetedForgeDirection.all[choice.direction].name), depth \(choice.depth). "
        }
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The pieces match the target."
            if let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
            mirror.status = "Won"
        case .failed, .result:
            let reason: String
            switch play.failure {
            case .sliver(let piece, let cut):
                reason = "Cut \(cut + 1) left piece \(piece + 1) thinner than the sliver limit."
            case .budget, .none: reason = "The cut budget ran out before the pieces matched the target."
            }
            text += reason
            if let explanation = mirror.failureText { text += " " + explanation }
            mirror.status = "Failed: " + reason
        default:
            mirror.status = play.cuts == 0 ? "Ready" : "Playing"
        }
        if let instruction = mirror.instruction { text += " Tutorial: " + instruction }
        if let hint = mirror.hintText { text += " Hint: " + hint }
        return text
    }

    // MARK: Feedback and sound (feature 376)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: FacetedForgeFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
    }

    /// The ambient recipe of `core`: its piece count, its target's piece count and its stage.
    static func recipe(_ core: FacetedForgeExperienceCore) -> AmbientLoopRecipe {
        FacetedForgeSoundRecipe.recipe(pieces: core.play.pieces.count, target: core.play.level.target.count,
                                       stage: core.play.stage)
    }

    /// Turns the ambient sound on or off; turning it on plays the recipe of the current crystal.
    func setSound(on: Bool) {
        if on, let core = latestCore { sound.offer(Self.recipe(core)) }
        sound.setWanted(on)
        mirror.soundOn = on
    }

    /// Saves the sound choice through `settings.sound [0/1]` (feature 377); the described change turns the loop on or
    /// off.
    @discardableResult
    func saveSound(on: Bool, port: ExperienceActionPort) -> ActionResult {
        send("settings.sound", [on ? 1 : 0], port: port)
    }

    // MARK: Replay (feature 377)

    /// Starts the replay of the current level's best stored solution (`replay.start [level]`).
    @discardableResult
    func startReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.start", [Double(mirror.levelNumber)], port: port)
    }

    /// Plays the next cut of the running replay (`replay.step`).
    @discardableResult
    func stepReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.step", [], port: port)
    }

    /// Stops the running replay and returns to the campaign (`replay.stop`).
    @discardableResult
    func stopReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.stop", [], port: port)
    }

    /// Whether the dropped-results announcement was made (once per presenter; feature 377).
    private var droppedAnnounced = false

    /// The announcement of `count` saved results dropped by a restore (feature 377).
    static func droppedText(_ count: Int) -> String {
        count == 1 ? "1 saved result could not be checked and was removed."
            : "\(count) saved results could not be checked and were removed."
    }

    /// Whether `mode` is a replay (feature 377).
    static func isReplay(_ mode: FacetedForgeMode) -> Bool {
        if case .replay = mode { return true }
        return false
    }

    /// The controls view appeared (the loop may play).
    func controlsAppeared() { sound.setOnScreen(true) }

    /// The controls view disappeared (the loop stops).
    func controlsDisappeared() { sound.setOnScreen(false) }

    /// The scene became active or inactive.
    func sceneActive(_ active: Bool) { sound.setActive(active) }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(FacetedForgeControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
