// StarlitCartouchePresenter — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-003, 004, 005, 007; clarifications
// Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `StarlitCartoucheChartScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`), keeps a log of every
// tier change with its reason, and caps the glow under Reduce Flashing. Two clocks feed the picture, both presentation
// only: the firmament turns with the frame time (0 under Reduce Motion), and the ship glides along its newest trail
// over ``glideSeconds`` from the frame at which that leg was first drawn (at once under Reduce Motion); an undo, a
// failed leg or a new level leaves the ship at rest. The chosen destination and wait are the adapter's presentation
// state (`route.choose`), read from the core. A refused action is shown in words. A memory warning releases the GPU
// objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel
// (renderer purity). Its probes (two backdrop corners) let the verification runner check a frame.
// Since feature 454 (R02-G16-04) canvas touches go through `StarlitCartoucheGestureController`: a tap chooses a
// destination and the slider a wait (`route.choose`), a double tap or a drag from the ship flies a leg (`route.fly`), a
// ship drag previews its destination (restored when the drag is cleared), two fingers orbit the camera (presentation
// only), and refused actions are shown and logged with their codes, read with or without the engine's `action.rule.`
// prefix.
#if os(iOS)
import Foundation
import StarlitCartoucheCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described and the chosen destination and wait.
@MainActor
@Observable
final class StarlitCartoucheMirror {
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
    /// The progress in words (the kernel's route report and the actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen destination star, the adapter's.
    var destination = 1
    /// The chosen wait (0 … 8), the adapter's.
    var wait = 0
    /// The play followed (a copy; never sent anywhere).
    var play: StarlitCartouchePlay?
    /// The text of the last refused change, or why a gesture sent nothing, if any.
    var message: String?
    /// The pending leg of a ship drag in words (feature 454), nil when no drag is pending.
    var pending: String?

    /// The number of stars of the followed level (2 while no play is followed).
    var starCount: Int { max(play?.level.stars.count ?? 2, 2) }
    /// The ship's star (0 while no play is followed).
    var shipStar: Int { play?.star ?? 0 }

    /// The next destination after `destination` in direction `step` (±1), skipping the ship's star, wrapping around.
    func nextDestination(_ step: Int) -> Int {
        var candidate: Int = destination
        for _ in 0..<starCount {
            candidate = ((candidate + step) % starCount + starCount) % starCount
            if candidate != shipStar { return candidate }
        }
        return destination
    }

    /// `value` clamped to the waits 0 … 8.
    func clampedWait(_ value: Int) -> Int { min(max(value, 0), 8) }

    /// The chosen leg in words: the destination, the corridor (or that none joins them) and the wait.
    var legLabel: String {
        guard let play else { return "star \(destination), wait \(wait)" }
        let level: StarlitCartoucheLevel = play.level
        let beats: String = wait == 1 ? "1 beat" : "\(wait) beats"
        guard let corridor = StarlitCartoucheChart.corridor(level, joining: play.star, destination) else {
            return "\(level.starName(destination)): no corridor from \(level.starName(play.star)), wait \(beats)"
        }
        return "\(level.starName(destination)) along \(level.corridorName(corridor)), wait \(beats)"
    }

    /// Takes the new `play` and choice.
    func follow(_ play: StarlitCartouchePlay, destination: Int, wait: Int) {
        self.play = play
        self.destination = destination
        self.wait = clampedWait(wait)
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: StarlitCartoucheFailure?) -> String? {
        switch failure {
        case let .departure(star, beat, close)?:
            "Leaving star \(star) at beat \(beat) misses its window, which closed at beat \(close)."
        case let .hazard(corridor, hazard, from, to)?:
            "Corridor \(corridor) crosses hazard \(hazard), active from beat \(from) to beat \(to)."
        case let .arrival(star, beat, open, close)?:
            "Arriving at star \(star) at beat \(beat) misses its window, beats \(open) to \(close)."
        case let .deadline(beat, deadline)?:
            "The ship would arrive at beat \(beat), after the deadline at beat \(deadline)."
        case let .stroke(corridor)?: "Corridor \(corridor) is not part of the symbol."
        case let .budget(spent)?: "The budget ran out after \(spent) actions."
        case nil: nil
        }
    }

    /// The engine's prefix on a kernel refusal's code (`action.rule.` before the kernel's `r02-g16.*` code).
    static let rulePrefix = "action.rule."

    /// `code` without the engine's ``rulePrefix`` (feature 454: codes are read with or without it).
    static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``.
    static func refusalText(code: String) -> String {
        switch bareCode(code) {
        case "r02-g16.stage": "the play is over: undo or go to the next level"
        case "r02-g16.action": "no corridor can be flown there now"
        case "r02-g16.stale": "the play changed before the action arrived"
        case "r02-g16.level": "the next level could not be made"
        case StarlitCartoucheExperienceRule.notWhole: "a star and a wait must be whole numbers"
        case StarlitCartoucheExperienceRule.choice: "that destination or wait cannot be chosen"
        default: "that action is not available now"
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct StarlitCartoucheTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Starlit Cartouche.
@MainActor
final class StarlitCartouchePresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = StarlitCartoucheExperienceCore

    /// The seconds the ship takes to glide along its newest trail (clarification Q1).
    static let glideSeconds: Double = 0.5

    /// Whether the firmament and the glide are still (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = StarlitCartoucheMirror()
    /// The GL scene.
    let scene = StarlitCartoucheChartScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1603-004).
    private(set) var tierLog: [StarlitCartoucheTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: StarlitCartoucheSceneSnapshot?
    /// The glide (0 … 1) of the last frame drawn (tests).
    private(set) var lastGlide: Double = 1
    /// The gesture controller (feature 454): star taps and double taps, the slider, ship drags, orbit.
    private(set) var gestures = StarlitCartoucheGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability, feature 454).
    private(set) var refusalLog: [String] = []
    /// How many refusal codes ``refusalLog`` keeps.
    static let refusalLogLimit = 64
    /// The destination chosen before a ship drag began previewing another, restored when the preview is cleared.
    private var previewRestore: Int?

    /// The level and the number of flown legs last seen, and the frame time of the newest leg (the glide starts
    /// there).
    private var seenLevel: Int?
    private var seenLegs = 0
    private var playStart: Double = -Double.greatestFiniteMagnitude

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the chart program's fragment source with one that does not compile.
    func breakChartShader() {
        scene.chartFragment = "this is not a shader;"
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

    /// Follows `core`'s play and choice in the mirror when they changed.
    private func follow(_ core: StarlitCartoucheExperienceCore) {
        if mirror.play != core.play || mirror.destination != core.chosenStar || mirror.wait != core.chosenWait {
            mirror.follow(core.play, destination: core.chosenStar, wait: core.chosenWait)
        }
    }

    /// The ship's glide (0 … 1) at frame time `now`: 1 under Reduce Motion or without a leg, else the share of
    /// ``glideSeconds`` since the newest leg was first drawn. Only a leg added (flown or redone) restarts the glide: an
    /// undo, a failed leg (the ship stays at its star) or a new level leaves the ship at rest.
    func glide(_ core: StarlitCartoucheExperienceCore, now: Double) -> Double {
        let play: StarlitCartouchePlay = core.play
        let legs: Int = play.legs.count
        if seenLevel != core.levelNumber {
            seenLevel = core.levelNumber
            seenLegs = legs
            playStart = -Double.greatestFiniteMagnitude
        } else if legs > seenLegs {
            seenLegs = legs
            playStart = now
        } else if legs < seenLegs {
            seenLegs = legs
            playStart = -Double.greatestFiniteMagnitude
        }
        guard !reduceMotion, legs > 0 else { return 1 }
        let share: Double = (now - playStart) / Self.glideSeconds
        return share.isFinite ? min(max(share, 0), 1) : 1
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: StarlitCartoucheExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = StarlitCartoucheTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(StarlitCartoucheTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let glide: Double = glide(core, now: frame.time)
        lastGlide = glide
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, glide: glide)
    }

    /// Releases every GPU object.
    func teardown(_ context: RenderContext) {
        scene.release()
    }

    /// Releases every GPU object (memory warning); the next frame rebuilds them.
    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the chart, the
    /// cartouche and the gauges (the camera fits the scene inside a 5 % margin), are `dark` (the ultramarine
    /// firmament) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: StarlitCartoucheExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "firmament-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "firmament-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: StarlitCartoucheExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.targetLabel = "Level: draw the symbol of \(level.symbol.count) strokes across \(level.stars.count) "
            + "stars and reach \(level.starName(level.beacon)) by beat \(level.deadline)"
        let measure: String = level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Starlit Cartouche level \(core.levelNumber). "
        text += measure + ". "
        if let pending = mirror.pending { text += pending + ". " }
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The trail draws the symbol and the ship rests at the beacon."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = StarlitCartoucheMirror.failureText(play.failure) ?? "The play failed."
            text += reason
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        default:
            mirror.status = play.records.isEmpty ? "Ready" : "Playing"
            mirror.failureText = nil
        }
        if play.stage == .won || play.stage == .failed || play.stage == .result {
            text += " " + Self.finishedMessage + "."
        }
        return text
    }

    /// The control panel: "Reset view" returns to the authored orbit; every button sends through ``send(_:_:port:)``.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(StarlitCartoucheControls(port: port, mirror: mirror,
                                         resetView: { [weak self] in self?.resetView() },
                                         sender: { [weak self] control, values in
                                             self?.send(control, values, port: port)
                                         }))
    }

    // MARK: Touch controls (feature 454, R02-G16-04)

    /// What a finished play says when a one-finger gesture sent nothing.
    static let finishedMessage = StarlitCartoucheGestureController.finishedReason

    /// The pending leg of a ship drag in words: "Fly to star s".
    static func pendingLegText(star: Int) -> String { "Fly to star \(star)" }

    /// The canvas gestures fly legs and choose the destination and wait; the pending text, the preview and the orbit
    /// are presentation state.
    var gestureActions: Set<String> { ["route.fly", "route.choose"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(StarlitCartoucheExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: a leg goes through `route.fly` (its own undo step), a destination or wait through `route.choose`
    /// (presentation only), a ship drag's preview through `route.choose` (the earlier destination is restored when the
    /// preview is cleared), and an explanation to the mirror's message.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let actions: [StarlitCartoucheGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        var destination: Int = snapshot.chosenStar
        var wait: Int = snapshot.chosenWait
        for action in actions {
            switch action {
            case let .chooseDestination(star):
                previewRestore = nil
                if send("route.choose", [Double(star), Double(wait)], port: port).isAccepted { destination = star }
            case let .chooseWait(next):
                if send("route.choose", [Double(destination), Double(next)], port: port).isAccepted { wait = next }
            case let .preview(star):
                if previewRestore == nil { previewRestore = destination }
                if send("route.choose", [Double(star), Double(wait)], port: port).isAccepted { destination = star }
                mirror.pending = Self.pendingLegText(star: star)
            case .clearPreview:
                mirror.pending = nil
                if let restore = previewRestore {
                    previewRestore = nil
                    if send("route.choose", [Double(restore), Double(wait)], port: port).isAccepted {
                        destination = restore
                    }
                }
            case let .fly(star, legWait):
                mirror.pending = nil
                previewRestore = nil
                send("route.fly", [Double(star), Double(legWait)], port: port)
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
            mirror.message = "That change was refused: \(StarlitCartoucheMirror.refusalText(code: result.code))."
            refusalLog.append(StarlitCartoucheMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }
}
#endif
