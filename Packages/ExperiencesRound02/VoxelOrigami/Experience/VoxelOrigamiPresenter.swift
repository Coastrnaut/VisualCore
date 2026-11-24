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
#if os(iOS)
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
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

    /// A refused action's reason code in words, read with or without the engine's ``rulePrefix``.
    static func refusalText(code: String) -> String {
        switch bareCode(code) {
        case "r02-g15.stage": "the play is over: undo or go to the next level"
        case "r02-g15.action": "that hinge cannot turn: nothing would move"
        case "r02-g15.stale": "the play changed before the action arrived"
        case "r02-g15.level": "the next level could not be made"
        case VoxelOrigamiExperienceRule.notWhole: "a hinge and a step must be whole numbers"
        case VoxelOrigamiExperienceRule.hinge: "this chain has no such hinge"
        default: "that action is not available now"
        }
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
        AnyView(VoxelOrigamiControls(port: port, mirror: mirror,
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
            mirror.message = "That change was refused: \(VoxelOrigamiMirror.refusalText(code: result.code))."
            refusalLog.append(VoxelOrigamiMirror.bareCode(result.code))
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }
}
#endif
