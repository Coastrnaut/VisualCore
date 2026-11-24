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
#if os(iOS)
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
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
    /// The text of the last refused change, if any.
    var message: String?

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

    /// A refused action's reason code in words.
    static func refusalText(code: String) -> String {
        switch code {
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
        return text
    }

    /// The control panel.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(VoxelOrigamiControls(port: port, mirror: mirror))
    }
}
#endif
