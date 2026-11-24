// MoonlitMechanismPresenter — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-003, 004, 005, 007;
// clarifications Q2, Q4, Q5). Draws the adapter's immutable snapshot with `MoonlitMechanismClockworkScene` at the
// host's quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`),
// keeps a log of every tier change with its reason, draws the gears at the set-up phases of the shown key frame without
// a turning preview under Reduce Motion (presentation time 0), and caps the glow under Reduce Flashing. The
// presentation time handed to the snapshot is the seconds since the play last changed: the presenter notes the frame
// time whenever the level, the phases, the lamp height, the actions spent, the stage, the failure or the shown key
// frame change. The panel's chosen gear lives in the mirror as presentation state: a level opens with gear 1 chosen, clamped
// to the level's gears; it never reaches the kernel except through the declared `gear.reseat` control. The shown key
// frame is the adapter's (`frame.show`), read from the core. A refused action is shown in words. A memory warning
// releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result
// reaches the kernel (renderer purity). Its probes (two backdrop corners) let the verification runner check a frame.
#if os(iOS)
import Foundation
import MoonlitMechanismCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show and choose: the latest state the presenter described, the shown key frame and the panel's
/// chosen gear.
@MainActor
@Observable
final class MoonlitMechanismMirror {
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
    /// The progress in words (the kernel's run report of the current set-up, actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen gear (0-based; gear 0 is the driver).
    var gear = MoonlitMechanismExperienceCore.openingGear
    /// The key frame the core shows (0-based).
    var shownFrame = MoonlitMechanismExperienceCore.openingFrame
    /// The play the choice is clamped against (a copy; never sent anywhere).
    var play: MoonlitMechanismPlay?
    /// The text of the last refused change, if any.
    var message: String?

    /// The number of gears of the followed level (2 while no play is followed, so gear 1 exists).
    var gearCount: Int { max(play?.level.gears.count ?? 2, 1) }
    /// The number of key frames of the followed level (1 while no play is followed).
    var frameCount: Int { max(play?.level.keyFrames.count ?? 1, 1) }
    /// The chosen gear in words.
    var gearLabel: String { gear == 0 ? "gear 0 (driver)" : "gear \(gear)" }
    /// The chosen gear in words with its teeth and current phase, if a play is followed.
    var gearDetail: String {
        guard let play, gear >= 0, gear < play.level.gears.count, gear < play.phases.count else { return gearLabel }
        return play.level.gearName(gear, phase: play.phases[gear])
    }
    /// The lamp in words, if a play is followed.
    var lampLabel: String {
        guard let play else { return "lamp" }
        return play.level.lampName(play.height)
    }
    /// The shown key frame in words: its number, whether it is required and its covered cells.
    var frameLabel: String {
        guard let play, shownFrame >= 0, shownFrame < play.level.keyFrames.count,
              shownFrame < play.report.frames.count else { return "key frame \(shownFrame)" }
        let frame = play.report.frames[shownFrame]
        let required: String = play.level.keyFrames[shownFrame].required ? "required" : "not required"
        return "key frame \(shownFrame) of \(play.level.keyFrames.count), \(required), "
            + "\(frame.covered) of \(frame.covered + frame.missing) covered"
    }

    /// Moves the chosen gear by `delta`, clamped to the level's gears.
    func stepGear(_ delta: Int) { gear = clampedGear(gear + delta) }

    /// `value` clamped to the gears of the followed level.
    func clampedGear(_ value: Int) -> Int { min(max(value, 0), gearCount - 1) }

    /// `value` clamped to the key frames of the followed level.
    func clampedFrame(_ value: Int) -> Int { min(max(value, 0), frameCount - 1) }

    /// Takes the new `play` and shown key frame: a new level chooses gear 1; otherwise the choice is clamped.
    func follow(_ play: MoonlitMechanismPlay, shownFrame: Int) {
        let changedLevel: Bool = self.play?.level.id != play.level.id
        self.play = play
        self.shownFrame = shownFrame
        gear = clampedGear(changedLevel ? MoonlitMechanismExperienceCore.openingGear : gear)
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: MoonlitMechanismFailure?) -> String? {
        switch failure {
        case let .jammed(child)?: "Gear \(child) jams against its parent."
        case let .forbidden(frame, cell)?: "Key frame \(frame) shadows forbidden cell \(cell)."
        case let .missing(frame, count)?:
            "Key frame \(frame) misses \(count == 1 ? "1 target cell" : "\(count) target cells")."
        case let .stray(frame, count)?:
            "Key frame \(frame) casts \(count == 1 ? "1 stray cell" : "\(count) stray cells")."
        case let .budget(index)?: "The budget ran out at action \(index + 1)."
        case nil: nil
        }
    }

    /// A refused action's reason code in words.
    static func refusalText(code: String) -> String {
        switch code {
        case "r02-g14.stage": "the play is over: undo or go to the next level"
        case "r02-g14.action": "that change is not allowed for this machine"
        case "r02-g14.stale": "the play changed before the action arrived"
        case "r02-g14.level": "the next level could not be made"
        case MoonlitMechanismExperienceRule.notWhole: "a step, a gear and a key frame must be whole numbers"
        case MoonlitMechanismExperienceRule.frame: "this level has no such key frame"
        default: "that action is not available now"
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct MoonlitMechanismTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Moonlit Mechanism.
@MainActor
final class MoonlitMechanismPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = MoonlitMechanismExperienceCore

    /// Whether the gears are drawn without a turning preview at presentation time 0 (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show and choose.
    let mirror = MoonlitMechanismMirror()
    /// The GL scene.
    let scene = MoonlitMechanismClockworkScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1403-004).
    private(set) var tierLog: [MoonlitMechanismTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: MoonlitMechanismSceneSnapshot?

    /// What restarts the presentation clock: the play's level, phases, lamp, actions spent, stage, failure and the
    /// shown key frame.
    private struct PlayKey: Equatable {
        let levelNumber: Int
        let phases: [Int]
        let height: Int
        let actionsSpent: Int
        let stage: MoonlitMechanismStage
        let failure: MoonlitMechanismFailure?
        let shownFrame: Int
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

    /// The tests' seam: before `setup`, replaces the clockwork program's fragment source with one that does not
    /// compile.
    func breakClockworkShader() {
        scene.clockworkFragment = "this is not a shader;"
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

    /// Follows `core`'s play and shown key frame in the mirror when they changed.
    private func follow(_ core: MoonlitMechanismExperienceCore) {
        if mirror.play != core.play || mirror.shownFrame != core.shownFrame {
            mirror.follow(core.play, shownFrame: core.shownFrame)
        }
    }

    /// The seconds since the play last changed at frame time `now` (0 under Reduce Motion): the clock restarts
    /// whenever the level, the phases, the lamp, the actions spent, the stage, the failure or the shown key frame
    /// change.
    func presentationTime(_ core: MoonlitMechanismExperienceCore, now: Double) -> Double {
        let play: MoonlitMechanismPlay = core.play
        let key = PlayKey(levelNumber: core.levelNumber, phases: play.phases, height: play.height,
                          actionsSpent: play.actionsSpent, stage: play.stage, failure: play.failure,
                          shownFrame: core.shownFrame)
        if key != playKey {
            playKey = key
            playStart = now
        }
        guard !reduceMotion else { return 0 }
        let elapsed: Double = now - playStart
        return elapsed.isFinite ? max(0, elapsed) : 0
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: MoonlitMechanismExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = MoonlitMechanismTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(MoonlitMechanismTierChange(tier: drawn.index, reason: reason))
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the wall, the gears,
    /// the lamp and the gauges (the camera fits the scene inside a 5 % margin), are `dark` (the night backdrop) once a
    /// snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: MoonlitMechanismExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "night-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "night-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: MoonlitMechanismExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        let required: Int = level.keyFrames.filter(\.required).count
        mirror.targetLabel = "Level: cast the targets of \(required) required of \(level.keyFrames.count) key frames "
            + "on a \(level.width) × \(level.rows) wall with \(level.gears.count) gears and \(level.lampHeights) lamp "
            + "heights; \(level.forbidden.count) forbidden cells, \(level.allowance) stray cells allowed"
        let measure: String = level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Moonlit Mechanism level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The shadows match every required key frame."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = MoonlitMechanismMirror.failureText(play.failure) ?? "The play failed."
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
        AnyView(MoonlitMechanismControls(port: port, mirror: mirror))
    }
}
#endif
