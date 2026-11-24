// AcousticConstellatorPresenter — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-003, 004, 005, 007;
// clarifications Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `AcousticConstellatorConstellationScene`
// at the host's quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's
// `qualityTiers`), keeps a log of every tier change with its reason, draws the stars at tick 0 without pulsing and does
// not play the listen preview under Reduce Motion, and caps the glow under Reduce Flashing. The presentation time handed
// to the snapshot is the seconds since the play last changed: the presenter notes the frame time whenever the level,
// the links, the phases, the actions spent, the stage or the failure change, so the preview of the kernel's listen
// report plays from tick 0 after every change. The panel's choice (star, partner) lives in the mirror as presentation
// state: a level opens with star 0 and partner 1 chosen, both clamped to the level's stars; it never reaches the kernel
// except through the declared `link.add`, `link.remove` and `star.nudge` controls. A refused action is shown in words.
// A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no
// drawing result reaches the kernel (renderer purity). Its probes (two sky corners) let the verification runner check a
// frame.
#if os(iOS)
// Feature 424 (R02-G13-04) T-R02G1304-005: `pointer(_:viewSize:port:)` routes canvas touches through
// `AcousticConstellatorGestureController` with the drawn snapshot: a tap on a star nudges it forward and chooses it, a
// tap on a link chooses its stars and describes it, a tap on a gauge listens, a drag from a star draws the filament to
// the finger and links or unlinks on release; kernel actions go through the port (refusals are shown and kept with
// their code in `refusalLog`); a drag onto a fixed pair says the link is fixed; a one-finger gesture on a won or failed
// play says that the play is over; the scene draws the controller's orbit, and "Reset view" or a double tap on empty
// space returns to the authored view.
// Feature 425 (R02-G13-05) T-R02G1305-005 (FR-R02G1305-001 … 005; clarifications Q1–Q5): the mirror carries the
// tutorial instruction, the hint revealed so far (`showHint()` reveals the next of three levels; the bounded search
// runs off the main actor, a stale search owns nothing, and any change of the play hides it), the failure
// explanation, the mode, the open levels with their bands and stars and the goal (the certified witness's action
// count); `retry` starts the level again in its mode, `undoAction` takes back the last action, and the daily level is
// chosen from the local calendar date read here (`playDaily(port:date:)`), never by the core. A refused `level.next`
// before a win (`r02-g13.locked`) and an impossible date (`r02-g13.date`) read in words.
import AcousticConstellatorCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show and choose: the latest state the presenter described and the panel's chosen star and
/// partner.
@MainActor
@Observable
final class AcousticConstellatorMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions left.
    var actionsLeft = 0
    /// The action budget.
    var budget = 0
    /// A one-line status: "Ready", "Playing", "Won" or "Failed: " and the failure in words (the progress has its
    /// own line, ``measureLabel``).
    var status = ""
    /// The failure in words, if the play failed.
    var failureText: String?
    /// The progress in words (the kernel's listen report of the current state, actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen star (0-based).
    var star = AcousticConstellatorExperienceCore.openingStar
    /// The chosen partner star (0-based).
    var partner = AcousticConstellatorExperienceCore.openingPartner
    /// The play the choice is clamped against (a copy; never sent anywhere).
    var play: AcousticConstellatorPlay?
    /// The text of the last refused change, if any.
    var message: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 425).
    var instruction: String?
    /// The hint level revealed (0 … 3; 0 while no hint is shown) (feature 425).
    var hintLevel = 0
    /// The text of the hint revealed, or ``AcousticConstellatorPresenter/searchingText`` while its search runs
    /// (feature 425).
    var hintText: String?
    /// The mode (feature 425).
    var mode: AcousticConstellatorMode = .campaign
    /// The highest open level (feature 425).
    var frontier = 1
    /// The stars of each won level, by level number (feature 425).
    var stars: [Int: Int] = [:]
    /// The certified witness's action count of the current level (its links and nudges plus the listen; the goal,
    /// feature 425).
    var certifiedActions = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen) (feature 425).
    var pickedLevel = 1

    /// The goal and the level's difficulty band (of the five bands of 20), with its best stars when won (feature 425).
    var goalLabel: String {
        let band: Int = AcousticConstellatorProgress.band(of: levelNumber)
        var text = "Goal: link the symbol and hold it spending \(certifiedActions) actions; band \(band) of 5"
        if let best = stars[levelNumber] { text += "; best \(best) of 3 stars" }
        return text
    }

    /// The number of stars of the followed level (2 while no play is followed, so star 0 and partner 1 exist).
    var starCount: Int { max(play?.level.stars.count ?? 2, 1) }
    /// The chosen star in words.
    var starLabel: String { "star \(star)" }
    /// The chosen partner in words.
    var partnerLabel: String { "partner star \(partner)" }
    /// The chosen star in words with its rate and current phase, if a play is followed.
    var starDetail: String { detail(star) ?? starLabel }
    /// The chosen partner in words with its rate and current phase, if a play is followed.
    var partnerDetail: String { detail(partner).map { "partner " + $0 } ?? partnerLabel }
    /// Whether the chosen star and partner are linked in the followed play.
    var isLinked: Bool {
        guard let play, star != partner else { return false }
        return play.links.contains(AcousticConstellatorLink.between(star, partner))
    }
    /// The chosen pair in words: the link with its gap when linked, else that the stars are not linked.
    var choiceLabel: String {
        guard let play, star != partner, star >= 0, partner >= 0, star < play.phases.count,
              partner < play.phases.count else { return starLabel + ", " + partnerLabel }
        let link = AcousticConstellatorLink.between(star, partner)
        if isLinked { return play.level.linkName(link, phases: play.phases) }
        return "star \(link.a) and star \(link.b), not linked"
    }

    /// Star `index` in words with its rate and current phase; nil without a followed play or for an unknown star.
    private func detail(_ index: Int) -> String? {
        guard let play, index >= 0, index < play.level.stars.count, index < play.phases.count else { return nil }
        return play.level.starName(index, phase: play.phases[index])
    }

    /// Moves the chosen star by `delta`, clamped to the level's stars.
    func stepStar(_ delta: Int) { star = clampedStar(star + delta) }

    /// Moves the chosen partner by `delta`, clamped to the level's stars.
    func stepPartner(_ delta: Int) { partner = clampedStar(partner + delta) }

    /// `value` clamped to the stars of the followed level.
    func clampedStar(_ value: Int) -> Int { min(max(value, 0), starCount - 1) }

    /// Takes the new `play`: a new level chooses star 0 and partner 1; otherwise the choice is clamped.
    func follow(_ play: AcousticConstellatorPlay) {
        let changedLevel: Bool = self.play?.level.id != play.level.id
        self.play = play
        if changedLevel {
            star = clampedStar(AcousticConstellatorExperienceCore.openingStar)
            partner = clampedStar(AcousticConstellatorExperienceCore.openingPartner)
        } else {
            star = clampedStar(star)
            partner = clampedStar(partner)
        }
    }

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<kernel code>`).
    static let rulePrefix = "action.rule."

    /// A refused action's reason code in words; accepts the kernel's code bare or as the engine reports it
    /// (`action.rule.r02-g13.action`).
    static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        return switch bare {
        case "r02-g13.stage": "the play is over: undo or go to the next level"
        case "r02-g13.action": "that change is not allowed for these stars"
        case "r02-g13.stale": "the play changed before the action arrived"
        case "r02-g13.level": "the next level could not be made"
        case AcousticConstellatorExperienceRule.locked: "that level is not open yet: win the level before it first"
        case AcousticConstellatorExperienceRule.date: "that date is not a calendar date"
        case AcousticConstellatorExperienceRule.notWhole: "a star and a step must be whole numbers"
        default: "that action is not available now"
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct AcousticConstellatorTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Acoustic Constellator.
@MainActor
final class AcousticConstellatorPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = AcousticConstellatorExperienceCore

    /// Whether the stars are drawn at tick 0 without pulsing and the preview is not played (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show and choose.
    let mirror = AcousticConstellatorMirror()
    /// The GL scene.
    let scene = AcousticConstellatorConstellationScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1303-004).
    private(set) var tierLog: [AcousticConstellatorTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: AcousticConstellatorSceneSnapshot?
    /// The gesture controller (feature 424): nudge taps, link drags, inspection, listening, double taps, orbit.
    private(set) var gestures = AcousticConstellatorGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64
    /// What a gesture on a finished play shows, and what the description adds on a won or failed play.
    static let finishedMessage = "The play is over: undo or go to the next level"
    /// The latest core described (feature 425): hints and retry read it.
    private(set) var latestCore: AcousticConstellatorExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 425).
    private var hintKey: String?
    /// The hints searched for a play, by that play's key: one search per play, every level from it (feature 425).
    private var hintCache: (key: String, hints: [AcousticConstellatorHint?])?
    /// The search under way, off the main actor, for the play of ``hintKey`` (feature 425).
    private(set) var hintSearch: Task<Void, Never>?
    /// What the hint line shows while the search runs (feature 425).
    static let searchingText = "Finding a hint…"
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 425).
    private(set) var dailyDate: DateComponents?

    /// What restarts the preview clock: the play's level, links, phases, actions spent, stage and failure.
    private struct PlayKey: Equatable {
        let levelNumber: Int
        let links: [AcousticConstellatorLink]
        let phases: [Int]
        let actionsSpent: Int
        let stage: AcousticConstellatorStage
        let failure: AcousticConstellatorFailure?
    }

    /// The play last seen and the frame time it was first drawn (the preview clock starts there).
    private var playKey: PlayKey?
    private var playStart: Double = 0

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the constellation program's fragment source with one that does not
    /// compile.
    func breakConstellationShader() {
        scene.constellationFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// Records the registry and the aspect.
    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    /// Follows the new drawable size.
    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    /// Follows `core`'s play in the mirror when it changed.
    private func follow(_ core: AcousticConstellatorExperienceCore) {
        if mirror.play != core.play { mirror.follow(core.play) }
    }

    /// The seconds since the play last changed at frame time `now`: the clock restarts whenever the level, the links,
    /// the phases, the actions spent, the stage or the failure change (a link, an unlink, a nudge, a listen, an undo, a
    /// redo or a new level).
    func previewTime(_ core: AcousticConstellatorExperienceCore, now: Double) -> Double {
        let play: AcousticConstellatorPlay = core.play
        let key = PlayKey(levelNumber: core.levelNumber, links: play.links, phases: play.phases,
                          actionsSpent: play.actionsSpent, stage: play.stage, failure: play.failure)
        if key != playKey {
            playKey = key
            playStart = now
        }
        let elapsed: Double = now - playStart
        return elapsed.isFinite ? max(0, elapsed) : 0
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: AcousticConstellatorExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = AcousticConstellatorTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(AcousticConstellatorTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        scene.orbit = gestures.orbit
        let time = previewTime(core, now: frame.time)
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    /// Releases every GPU object.
    func teardown(_ context: RenderContext) {
        scene.release()
    }

    /// Releases every GPU object (memory warning); the next frame rebuilds them.
    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the constellation and
    /// its gauges (the camera fits the scene inside a 6 % margin), are `dark` (the night sky) once a snapshot was drawn
    /// by the real scene; none otherwise.
    func probes(_ core: AcousticConstellatorExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "sky-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "sky-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: AcousticConstellatorExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        absorbProgress(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        let pairs: String = level.symbol.count == 1 ? "1 pair" : "\(level.symbol.count) pairs"
        mirror.targetLabel = "Level: link the symbol's \(pairs) among \(level.stars.count) stars and hold "
            + "\(level.hold) coherent ticks within \(level.window); threshold \(level.threshold), "
            + "\(level.fixedLinks.count) fixed links"
        let measure: String = play.progressDescription
        mirror.measureLabel = measure
        var text = "Acoustic Constellator level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The symbol rings together."
            if let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            // Since feature 425 the failure explanation (the failing action, its cause and the advice).
            let reason: String = mirror.failureText
                ?? AcousticConstellatorSceneSnapshot.failureText(play.failure) ?? "The play failed."
            text += reason
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        default:
            mirror.status = play.records.isEmpty ? "Ready" : "Playing"
            mirror.failureText = nil
        }
        text += " " + mirror.goalLabel + "."
        if let instruction = mirror.instruction { text += " Tutorial: " + instruction }
        if let hint = mirror.hintText { text += " Hint: " + hint }
        if play.stage == .won || play.stage == .failed || play.stage == .result {
            text += " " + Self.finishedMessage + "."
        }
        return text
    }

    /// The control panel.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AcousticConstellatorControls(port: port, mirror: mirror, presenter: self,
                                             resetView: { [weak self] in self?.resetView() },
                                             sender: { [weak self] control, values in
                                                 self?.send(control, values, port: port)
                                             }))
    }

    // MARK: Touch controls (feature 424, R02-G13-04)

    /// The canvas gestures send links, unlinks, forward nudges and listens; choices, the filament and the orbit are
    /// presentation state.
    var gestureActions: Set<String> { ["link.add", "link.remove", "star.nudge", "constellation.listen"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(AcousticConstellatorExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: kernel actions are sent through the port, choices and previews go to the mirror and the scene's filament;
    /// a drag released onto a fixed pair says the link is fixed; a one-finger gesture that ends on a won or failed play
    /// without choosing explains that the play is over.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let before: AcousticConstellatorGestureController.State = gestures.state
        let actions: [AcousticConstellatorGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        let finished: Bool = snapshot.stage == .won || snapshot.stage == .failed || snapshot.stage == .result
        let oneFinger: Bool = [.starPress, .linkDrag, .targetPress, .linkPress].contains(before)
        var sentKernel = false
        var chose = false
        for action in actions {
            switch action {
            case let .nudge(star):
                sentKernel = true
                send("star.nudge", [Double(star), 1], port: port)
            case let .link(a, b):
                sentKernel = true
                send("link.add", [Double(a), Double(b)], port: port)
            case let .unlink(a, b):
                sentKernel = true
                send("link.remove", [Double(a), Double(b)], port: port)
            case .listen:
                sentKernel = true
                send("constellation.listen", [], port: port)
            case let .choose(star):
                chose = true
                choose(star)
            case let .choosePair(a, b):
                chose = true
                mirror.star = mirror.clampedStar(a)
                mirror.partner = mirror.clampedStar(b)
                if before == .linkPress {
                    mirror.message = Self.linkText(a, b, snapshot: snapshot,
                                                   tick: AcousticConstellatorSceneGeometry.drawnTick(
                                                       snapshot, reduceMotion: reduceMotion))
                } else if !sentKernel, !finished, snapshot.fixedLinks.contains(.between(a, b)) {
                    mirror.message = Self.fixedText(a, b)
                }
            case let .preview(from, target, point):
                mirror.star = mirror.clampedStar(from)
                if let target { mirror.partner = mirror.clampedStar(target) }
                scene.filament = filament(from, target: target, point: point, viewSize: viewSize, snapshot: snapshot)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
        if event.phase == .ended || event.phase == .cancelled || gestures.state == .orbiting
            || gestures.state == .cancelled {
            scene.filament = nil
        }
        if event.phase == .ended, finished, oneFinger, !chose, !sentKernel {
            mirror.message = Self.finishedMessage
        }
        scene.orbit = gestures.orbit
    }

    /// Cancels the touches in progress (suspension): nothing is sent and the filament disappears.
    func cancelPointers() {
        gestures.cancel()
        scene.filament = nil
    }

    // MARK: Teaching and progression (feature 425, R02-G13-05)

    /// Takes the core's teaching and progress state into the mirror: the tutorial instruction, the failure
    /// explanation, the mode, the open levels with their stars and the goal; a change of the play hides the hint.
    private func absorbProgress(_ core: AcousticConstellatorExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        latestCore = core
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = AcousticConstellatorFailureExplanation(play: core.play)?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.certifiedActions = core.certifiedActions
    }

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: AcousticConstellatorExperienceCore) -> String {
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
        let play: AcousticConstellatorPlay = core.play
        hintSearch = Task.detached(priority: .userInitiated) { [weak self] in
            // One search: the plan's first action gives every level (`AcousticConstellatorHint.at(level:)`).
            let first: AcousticConstellatorHint? = AcousticConstellatorHints.hint(level: 1, play: play)
            var hints: [AcousticConstellatorHint?] = []
            for level in 1...3 { hints.append(first?.at(level: level)) }
            await self?.finishSearch(hints, key: key)
        }
    }

    /// Takes the three hint levels searched for the play of `key`: cached, and shown when that play is still current.
    private func finishSearch(_ hints: [AcousticConstellatorHint?], key: String) {
        // A search for a play that is no longer the hinted one (hidden or replaced since) owns nothing: it must not
        // clear a newer search's handle or overwrite the cache.
        guard hintKey == key else { return }
        hintSearch = nil
        hintCache = (key, hints)
        guard let core = latestCore, Self.hintKey(core) == key else { return }
        reveal(hints, level: mirror.hintLevel, key: key)
    }

    /// Shows `hints`' level `level` for the play of `key`, or hides the hint when the play has none.
    private func reveal(_ hints: [AcousticConstellatorHint?], level: Int, key: String) {
        guard hints.indices.contains(level - 1), let hint = hints[level - 1] else {
            clearHint()
            return
        }
        hintKey = key
        mirror.hintLevel = level
        mirror.hintText = hint.text
    }

    /// Ends the tutorial of the current level (`tutorial.dismiss`).
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", [], port: port)
    }

    /// Takes back the last action (`play.undo`); after a failure this returns the play to playing.
    @discardableResult
    func undoAction(port: ExperienceActionPort) -> ActionResult {
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
    func retry(port: ExperienceActionPort,
               date: DateComponents = AcousticConstellatorPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort,
                   date: DateComponents = AcousticConstellatorPresenter.today()) -> ActionResult {
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
        scene.orbit = gestures.orbit
    }

    /// Chooses `star` in the panel; the partner moves to the next star (modulo the star count) when it equals it.
    private func choose(_ star: Int) {
        mirror.star = mirror.clampedStar(star)
        if mirror.partner == mirror.star {
            mirror.partner = (mirror.star + 1) % max(mirror.starCount, 1)
        }
    }

    /// The filament of a link drag from `from`: to the target star's centre, or to the point under the finger on the
    /// dragged star's height plane; nil when neither exists.
    private func filament(_ from: Int, target: Int?, point: SIMD2<Double>, viewSize: Vec2,
                          snapshot: AcousticConstellatorSceneSnapshot) -> AcousticConstellatorConstellationScene.Filament? {
        guard from >= 0, from < snapshot.stars.count else { return nil }
        if let target, target >= 0, target < snapshot.stars.count {
            return .init(star: from, point: AcousticConstellatorSceneGeometry.starCentre(target, snapshot))
        }
        guard let camera = gestures.camera(viewSize: viewSize, snapshot: snapshot) else { return nil }
        let height: Double = AcousticConstellatorSceneGeometry.starCentre(from, snapshot).y
        let size = SIMD2<Double>(Double(viewSize.x), Double(viewSize.y))
        guard let end = AcousticConstellatorPicker.fingerPoint(point, size: size, camera: camera, height: height) else {
            return nil
        }
        return .init(star: from, point: end)
    }

    /// The link between stars `a` and `b` in words at `tick`: its gap and whether it is fixed or placed; a pair that is
    /// not linked says so.
    static func linkText(_ a: Int, _ b: Int, snapshot: AcousticConstellatorSceneSnapshot, tick: Int) -> String {
        let link = AcousticConstellatorLink.between(a, b)
        guard let index = snapshot.links.firstIndex(of: link) else {
            return "Star \(link.a) and star \(link.b) are not linked."
        }
        let kind: String = snapshot.fixedLinks.contains(link) ? "fixed" : "placed"
        return "Link star \(link.a) to star \(link.b): gap \(snapshot.gap(index, at: tick)) at tick \(tick), \(kind)."
    }

    /// What a drag onto a fixed pair shows.
    static func fixedText(_ a: Int, _ b: Int) -> String {
        let link = AcousticConstellatorLink.between(a, b)
        return "The link from star \(link.a) to star \(link.b) is fixed: it cannot be removed."
    }

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its code in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            mirror.message = "That change was refused: \(AcousticConstellatorMirror.refusalText(code: result.code))."
            refusalLog.append(result.code)
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }
}
#endif
