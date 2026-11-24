// VoxelOrigamiPresenter — feature 443 (R02-G15-03) T-R02G1503-006 (FR-R02G1503-003, 004, 005, 007; clarifications
// Q2, Q4, Q5). Draws the adapter's immutable snapshot with `VoxelOrigamiVoxelScene` at the host's quality tier (tier n
// is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`), keeps a log of every tier change
// with its reason, draws the chain still under Reduce Motion (presentation time 0), and caps the glow under Reduce
// Flashing. The presentation time handed to the snapshot is the seconds since the play last changed: the presenter notes
// the frame time whenever the level, the turns, the actions spent, the stage, the failure or the chosen hinge change.
// The chosen hinge is the adapter's presentation state (`hinge.choose`), read from the core; a level opens with its
// first turnable hinge chosen. A refused action is shown in words. A memory warning releases the GPU objects; the next
// frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel (renderer purity).
// Its probes (two backdrop corners) let the verification runner check a frame.
// Since feature 444 (R02-G15-04) canvas touches go through `VoxelOrigamiGestureController`: a tap chooses a hinge
// (`hinge.choose`), a double tap or a drag turns one (`hinge.turn`), the pending turn of a drag is shown in words, a
// drag that cannot turn explains why, two fingers orbit the camera (presentation only), and refused actions are shown
// and logged with their codes, read with or without the engine's `action.rule.` prefix.
// Feature 445 (R02-G15-05) T-R02G1505-005 (FR-R02G1505-001 … 005; clarifications Q1–Q5): the mirror carries the
// tutorial instruction, the hint revealed so far (`showHint()` reveals the next of three levels; the bounded search
// runs off the main actor, a stale search owns nothing, and any change of the play hides it), the failure explanation
// (`explanation`; `failureText` stays the short status line), the mode, the open levels with their bands and stars and
// the goal (the certified witness's turn count); `retry` starts the level again in its mode, `undoAction` takes back
// the last turn, and the daily level is chosen from the local calendar date read here (`playDaily(port:date:)`), never
// by the core. A refused `level.next` before a win (`r02-g15.locked`) and an impossible date (`r02-g15.date`) read in
// words.
// Feature 446 (R02-G15-06) T-R02G1506-005 (FR-R02G1506-001 … 006; clarifications Q1 … Q5): the presenter routes
// `VoxelOrigamiFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route (`feedback`,
// injectable; the shared `ExperienceFeedback` by default) and keeps a feedback log (`feedbackLog`); refusals are shown
// and announced in words (`refused(code:)`; the panel shows exactly the plan's text), and a revealed hint is announced
// as `state`. Choosing a hinge, the pending drag text and orbit are not announced (the hinge speaks its value). The
// scene's lights (`VoxelOrigamiLights`: the glow and the won look) step toward the drawn snapshot every frame by the
// frame clock's elapsed time (0.15 s fades, 0.45 s under Reduce Flashing; the first frame settles them), so fades finish
// under Reduce Motion too, where the presentation time is held at 0. The ambient loop (`VoxelOrigamiSound`) is offered
// the recipe of the actions left, the quarters of the cubes in place and the stage when the first state is described,
// when a level or mode opens and when that recipe changes; choosing a hinge plays its audition
// (`VoxelOrigamiAudition.of(_:hinge:)`) when the sound is on, on screen and active. The mirror carries the summary
// element's text (`VoxelOrigamiFeedbackPlan.summaryText(core:hinge:)`) and the sound choice (off by default).
// Presentation only.
#if os(iOS)
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreAudioDSP
import VisualCoreScenes
import VoxelOrigamiCore

/// What the controls show: the latest state the presenter described and the chosen hinge.
@MainActor
@Observable
final class VoxelOrigamiMirror {
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
    /// The progress in words (the kernel's shape report and the actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen hinge (1 … cubes − 1), the adapter's.
    var hinge = 1
    /// The play followed (a copy; never sent anywhere).
    var play: VoxelOrigamiPlay?
    /// The text of the last refused change, or why a gesture sent nothing, if any.
    var message: String?
    /// The pending turn of a canvas drag in words (feature 444), nil when no drag is pending.
    var pending: String?
    /// The tutorial instruction; nil when the tutorial is done (feature 445).
    var instruction: String?
    /// The hint level revealed (0 … 3; 0 while no hint is shown) (feature 445).
    var hintLevel = 0
    /// The text of the hint revealed, or ``VoxelOrigamiPresenter/searchingText`` while its search runs (feature 445).
    var hintText: String?
    /// The failure explanation (the failing turn, its cause and the advice), nil without a failure (feature 445).
    var explanation: String?
    /// The mode (feature 445).
    var mode: VoxelOrigamiMode = .campaign
    /// The highest open level (feature 445).
    var frontier = 1
    /// The stars of each won level, by level number (feature 445).
    var stars: [Int: Int] = [:]
    /// The certified witness's turn count of the current level (the goal, feature 445).
    var certifiedTurns = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen) (feature 445).
    var pickedLevel = 1
    /// The summary element's text (feature 446): `VoxelOrigamiFeedbackPlan.summaryText(core:hinge:)` of the latest
    /// core and the chosen hinge.
    var summary = ""
    /// Whether the sound is on (feature 446; off by default; presentation only).
    var soundOn = false

    /// The goal and the level's difficulty band (of the five bands of 20), with its best stars when won (feature 445).
    var goalLabel: String {
        let band: Int = VoxelOrigamiProgress.band(of: levelNumber)
        let unit: String = certifiedTurns == 1 ? "turn" : "turns"
        var text = "Goal: match the target in \(certifiedTurns) \(unit); band \(band) of 5"
        if let best = stars[levelNumber] { text += "; best \(best) of 3 stars" }
        return text
    }

    /// The number of cubes of the followed level (2 while no play is followed, so hinge 1 exists).
    var cubeCount: Int { max(play?.level.cubes.count ?? 2, 2) }
    /// The chosen hinge in words.
    var hingeLabel: String { "hinge \(hinge)" }
    /// The chosen hinge in words with its quarter turn and whether it can turn, if a play is followed.
    var hingeDetail: String {
        guard let play, hinge >= 1, hinge < play.level.cubes.count, hinge < play.turns.count else { return hingeLabel }
        let name: String = play.level.hingeName(hinge, turn: play.turns[hinge])
        return play.level.canTurn(hinge, turns: play.turns) ? name : name + ", nothing would move"
    }

    /// `value` clamped to the hinges of the followed level.
    func clampedHinge(_ value: Int) -> Int { min(max(value, 1), cubeCount - 1) }

    /// Takes the new `play` and chosen hinge.
    func follow(_ play: VoxelOrigamiPlay, chosenHinge: Int) {
        self.play = play
        hinge = clampedHinge(chosenHinge)
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: VoxelOrigamiFailure?) -> String? {
        switch failure {
        case let .collision(hinge, moving, still, cell)?:
            "Turning hinge \(hinge) would put cube \(moving) on cube \(still) at \(cell)."
        case let .sweep(hinge, moving, still, cell)?:
            "Turning hinge \(hinge) would swing cube \(moving) through cube \(still) at \(cell)."
        case let .budget(index)?: "The budget ran out at action \(index + 1)."
        case nil: nil
        }
    }

    /// The engine's prefix on a kernel refusal's code (`action.rule.` before the kernel's `r02-g15.*` code).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix`` (feature 444: codes are read with or without it).
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``. Since feature 446 it
    /// forwards to `VoxelOrigamiFeedbackPlan.refusalText(code:)` (clarification Q1's sentences, e.g. "That hinge cannot
    /// turn: nothing would move.").
    static func refusalText(code: String) -> String {
        VoxelOrigamiFeedbackPlan.refusalText(code: code)
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct VoxelOrigamiTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Voxel Origami.
@MainActor
final class VoxelOrigamiPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = VoxelOrigamiExperienceCore

    /// Whether the chain is drawn still at presentation time 0 (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = VoxelOrigamiMirror()
    /// The GL scene.
    let scene = VoxelOrigamiVoxelScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1503-004).
    private(set) var tierLog: [VoxelOrigamiTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: VoxelOrigamiSceneSnapshot?
    /// The gesture controller (feature 444): cube taps, double taps and drags, orbit.
    private(set) var gestures = VoxelOrigamiGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability, feature 444).
    private(set) var refusalLog: [String] = []
    /// How many refusal codes ``refusalLog`` keeps.
    static let refusalLogLimit = 64
    /// The feedback route of announcements and haptics (feature 446; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first (feature 446; tests and diagnostics).
    private(set) var feedbackLog: [VoxelOrigamiFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 446).
    private(set) var lights: VoxelOrigamiLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient loop and the chosen hinge's audition (feature 446).
    let sound: VoxelOrigamiSound
    /// The latest core described (feature 445): hints and retry read it.
    private(set) var latestCore: VoxelOrigamiExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 445).
    private var hintKey: String?
    /// The hints searched for a play, by that play's key: one search per play, every level from it (feature 445).
    private var hintCache: (key: String, hints: [VoxelOrigamiHint?])?
    /// The search under way, off the main actor, for the play of ``hintKey`` (feature 445).
    private(set) var hintSearch: Task<Void, Never>?
    /// What the hint line shows while the search runs (feature 445).
    static let searchingText = "Finding a hint…"
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 445).
    private(set) var dailyDate: DateComponents?

    /// What restarts the presentation clock.
    private struct PlayKey: Equatable {
        let levelNumber: Int
        let turns: [Int]
        let actionsSpent: Int
        let stage: VoxelOrigamiStage
        let failure: VoxelOrigamiFailure?
        let chosenHinge: Int
    }

    /// The play last seen and the frame time it was first drawn (the presentation clock starts there).
    private var playKey: PlayKey?
    private var playStart: Double = 0

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        lights = VoxelOrigamiLights(reducedFlash: reduceFlashing)
        sound = VoxelOrigamiSound(recipe: VoxelOrigamiSoundRecipe.recipe(rootStep: 0, quarters: 0, stage: .loading))
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the voxel program's fragment source with one that does not compile.
    func breakVoxelShader() {
        scene.voxelFragment = "this is not a shader;"
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

    /// Follows `core`'s play and chosen hinge in the mirror when they changed.
    private func follow(_ core: VoxelOrigamiExperienceCore) {
        if mirror.play != core.play || mirror.hinge != core.chosenHinge {
            mirror.follow(core.play, chosenHinge: core.chosenHinge)
        }
    }

    /// The seconds since the play last changed at frame time `now` (0 under Reduce Motion).
    func presentationTime(_ core: VoxelOrigamiExperienceCore, now: Double) -> Double {
        let play: VoxelOrigamiPlay = core.play
        let key = PlayKey(levelNumber: core.levelNumber, turns: play.turns, actionsSpent: play.actionsSpent,
                          stage: play.stage, failure: play.failure, chosenHinge: core.chosenHinge)
        if key != playKey {
            playKey = key
            playStart = now
        }
        guard !reduceMotion else { return 0 }
        let elapsed: Double = now - playStart
        return elapsed.isFinite ? max(0, elapsed) : 0
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: VoxelOrigamiExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = VoxelOrigamiTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(VoxelOrigamiTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time = presentationTime(core, now: frame.time)
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        // The lights settle on the very first frame only; every later change, a level change included, fades, stepped
        // by the frame clock (not the presentation time, which Reduce Motion holds at 0).
        if let last = lastFrameTime {
            lights.step(toward: snapshot, elapsed: frame.time > last ? frame.time - last : 0)
        } else {
            lights.settle(to: snapshot)
        }
        lastFrameTime = frame.time
        scene.lights = lights
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the chain, the
    /// target and the gauges (the camera fits the scene inside a 5 % margin), are `dark` (the night backdrop) once a
    /// snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: VoxelOrigamiExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "night-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "night-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: VoxelOrigamiExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.targetLabel = "Level: fold a chain of \(level.cubes.count) cubes on \(level.hingeCount) hinges into "
            + "the turquoise target shape (\(level.orientations.rawValue) orientation)"
        let measure: String = level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        if let previous = latestCore {
            route(VoxelOrigamiFeedbackPlan.after(old: previous, new: core))
            let opened: Bool = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
            // Choosing a hinge (presentation state of the adapter) plays its audition when the sound is on.
            if !opened, previous.chosenHinge != core.chosenHinge, mirror.soundOn {
                sound.audition(VoxelOrigamiAudition.of(core.play, hinge: core.chosenHinge))
            }
        } else {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(Self.recipe(core))
        }
        absorbProgress(core)
        mirror.summary = VoxelOrigamiFeedbackPlan.summaryText(core: core, hinge: core.chosenHinge)
        var text = "Voxel Origami level \(core.levelNumber). "
        text += measure + ". "
        if let pending = mirror.pending { text += pending + ". " }
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The chain matches the target shape."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = VoxelOrigamiMirror.failureText(play.failure) ?? "The play failed."
            text += reason
            // Since feature 445 the failure explanation too (the failing turn, its cause and the advice).
            if let explanation = mirror.explanation { text += " " + explanation }
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        default:
            mirror.status = play.records.isEmpty ? "Ready" : "Playing"
            mirror.failureText = nil
        }
        if play.stage == .won || play.stage == .failed || play.stage == .result {
            text += " " + Self.finishedMessage + "."
        }
        if play.stage == .won, let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
        text += " " + mirror.goalLabel + "."
        if let instruction = mirror.instruction { text += " Tutorial: " + instruction }
        if let hint = mirror.hintText { text += " Hint: " + hint }
        return text
    }

    /// The control panel: "Reset view" returns to the authored orbit; every button sends through ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(VoxelOrigamiControls(port: port, mirror: mirror, presenter: self,
                                     resetView: { [weak self] in self?.resetView() },
                                     sender: { [weak self] control, values in
                                         self?.send(control, values, port: port)
                                     }))
    }

    // MARK: Touch controls (feature 444, R02-G15-04)

    /// What a finished play says when a one-finger gesture sent nothing.
    static let finishedMessage = VoxelOrigamiGestureController.finishedReason

    /// The pending turn of a cube drag in words: "Turn hinge h forward" or "Turn hinge h back".
    static func pendingTurnText(hinge: Int, step: Int) -> String {
        "Turn hinge \(hinge) \(step > 0 ? "forward" : "back")"
    }

    /// The canvas gestures send hinge turns and hinge choices; the pending text and the orbit are presentation state.
    var gestureActions: Set<String> { ["hinge.turn", "hinge.choose"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(VoxelOrigamiExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a turn goes through `hinge.turn` (one quarter turn, its own undo step), a choice through `hinge.choose`
    /// (presentation only), the pending turn to the mirror, and an explanation to the mirror's message.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let actions: [VoxelOrigamiGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        for action in actions {
            switch action {
            case let .chooseHinge(hinge):
                send("hinge.choose", [Double(hinge)], port: port)
            case let .pendingTurn(hinge, step):
                mirror.pending = Self.pendingTurnText(hinge: hinge, step: step)
            case .clearPending:
                mirror.pending = nil
            case let .turn(hinge, step):
                mirror.pending = nil
                send("hinge.turn", [Double(hinge), Double(step)], port: port)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            case let .explain(reason):
                mirror.message = reason
            }
        }
        if event.phase == .ended || event.phase == .cancelled || gestures.state == .orbiting
            || gestures.state == .cancelled {
            mirror.pending = nil
        }
        scene.orbit = gestures.orbit
    }

    /// Cancels the touches in progress (suspension): nothing is sent and the pending text disappears.
    func cancelPointers() {
        gestures.cancel()
        mirror.pending = nil
    }

    /// Returns the camera to the authored view ("Reset view"; presentation only).
    func resetView() {
        gestures.resetView()
        scene.orbit = gestures.orbit
    }

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its code (read with or without
    /// the engine's `action.rule.` prefix) in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            let plan = VoxelOrigamiFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            route(plan)
            refusalLog.append(VoxelOrigamiMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }

    // MARK: Teaching and progression (feature 445, R02-G15-05)

    /// Takes the core's teaching and progress state into the mirror: the tutorial instruction, the failure
    /// explanation, the mode, the open levels with their stars and the goal; a change of the play hides the hint.
    private func absorbProgress(_ core: VoxelOrigamiExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        latestCore = core
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.explanation = VoxelOrigamiFailureExplanation(play: core.play)?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.certifiedTurns = core.certifiedTurns
    }

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: VoxelOrigamiExperienceCore) -> String {
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

    /// The three hint levels of `play` from one search: the exact hint's turn gives every level's text
    /// (`VoxelOrigamiHint.turnText(level:hinge:step:cube:)`, the cube the hinge's tracked cube); a stuck or failed
    /// hint reads the same at every level; nil at every level for a play without a hint (won).
    nonisolated static func hintLevels(_ play: VoxelOrigamiPlay) -> [VoxelOrigamiHint?] {
        guard let exact = VoxelOrigamiHints.hint(level: 3, play: play) else { return [nil, nil, nil] }
        guard exact.kind == .turn, case .turn(let hinge, let step)? = exact.action else {
            return [exact, exact, exact]
        }
        let cubes: [VoxelOrigamiCube] = play.level.cubes
        let moving: [Int] = VoxelOrigamiLattice.swinging(cubes, pose: play.pose, hinge: hinge)
        let cube: Int = VoxelOrigamiPicker.trackedCube(hinge, cubes: cubes, pose: play.pose, moving: moving)
        var hints: [VoxelOrigamiHint?] = []
        for level in 1...3 {
            var hint: VoxelOrigamiHint = exact
            hint.text = VoxelOrigamiHint.turnText(level: level, hinge: hinge, step: step, cube: cube)
            hints.append(hint)
        }
        return hints
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
        let play: VoxelOrigamiPlay = core.play
        hintSearch = Task.detached(priority: .userInitiated) { [weak self] in
            let hints: [VoxelOrigamiHint?] = VoxelOrigamiPresenter.hintLevels(play)
            await self?.finishSearch(hints, key: key)
        }
    }

    /// Takes the three hint levels searched for the play of `key`: cached, and shown when that play is still current.
    private func finishSearch(_ hints: [VoxelOrigamiHint?], key: String) {
        // A search for a play that is no longer the hinted one (hidden or replaced since) owns nothing: it must not
        // clear a newer search's handle or overwrite the cache.
        guard hintKey == key else { return }
        hintSearch = nil
        hintCache = (key, hints)
        guard let core = latestCore, Self.hintKey(core) == key else { return }
        reveal(hints, level: mirror.hintLevel, key: key)
    }

    /// Shows `hints`' level `level` for the play of `key`, or hides the hint when the play has none.
    private func reveal(_ hints: [VoxelOrigamiHint?], level: Int, key: String) {
        guard hints.indices.contains(level - 1), let hint = hints[level - 1] else {
            clearHint()
            return
        }
        let revealed: Bool = mirror.hintLevel != level || mirror.hintText != hint.text
        hintKey = key
        mirror.hintLevel = level
        mirror.hintText = hint.text
        if revealed { route(VoxelOrigamiFeedbackPlan.hint(text: hint.text)) }   // feature 446: announced as state
    }

    /// Ends the tutorial of the current level (`tutorial.dismiss`).
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", [], port: port)
    }

    /// Takes back the last turn (`play.undo`); after a failure this returns the play to playing.
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
        case .replay(let level): return ("replay.start", [Double(level)])   // feature 447: the replay from the start
        }
    }

    /// Starts the current level again in its mode; in daily mode with the date that opened it (today's local date
    /// when none is known).
    @discardableResult
    func retry(port: ExperienceActionPort, date: DateComponents = VoxelOrigamiPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort, date: DateComponents = VoxelOrigamiPresenter.today()) -> ActionResult {
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

    // MARK: Feedback and sound (feature 446, R02-G15-06)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: VoxelOrigamiFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
    }

    /// The ambient recipe of `core`: its actions left, the quarters of its cubes in place and its stage.
    static func recipe(_ core: VoxelOrigamiExperienceCore) -> AmbientLoopRecipe {
        VoxelOrigamiSoundRecipe.recipe(play: core.play)
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
}
#endif
