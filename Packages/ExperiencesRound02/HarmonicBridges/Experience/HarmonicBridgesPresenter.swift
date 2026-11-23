// HarmonicBridgesPresenter — feature 413 (R02-G12-03) T-R02G1203-006 (FR-R02G1203-003, 004, 005, 007; clarifications
// Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `HarmonicBridgesBridgeScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`), keeps a log of every
// tier change with its reason, draws the strings at rest and holds the shown step (step 0, or the broken step) under
// Reduce Motion, and caps the glow under Reduce Flashing. The presentation time handed to the snapshot is the seconds
// since the play last changed: the presenter notes the frame time whenever the level, the pegs, the actions spent, the
// stage or the failure change, so the window's steps cycle from step 0 after every change. The panel's choice (string,
// peg) lives in the mirror as presentation state: a level opens with string 0 chosen at its current peg, both clamped;
// it never reaches the kernel except through the declared `string.tune` control. A refused action is shown in words.
// A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`:
// no drawing result reaches the kernel (renderer purity). Its probes (two ground corners) let the verification runner
// check a frame.
#if os(iOS)
import Foundation
import HarmonicBridgesCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show and choose: the latest state the presenter described and the panel's chosen string and peg.
@MainActor
@Observable
final class HarmonicBridgesMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions left.
    var actionsLeft = 0
    /// The action budget.
    var budget = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// The failure in words, if the play failed.
    var failureText: String?
    /// The progress in words (bridges and goal per step, actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen string (0-based).
    var string = 0
    /// The chosen peg (1 … 12).
    var peg = 1
    /// The play the choice is clamped against (a copy; never sent anywhere).
    var play: HarmonicBridgesPlay?
    /// The text of the last refused change, if any.
    var message: String?

    /// The pegs a string may be tuned to.
    static let pegRange: ClosedRange<Int> = HarmonicBridgesExperienceCore.pegRange

    /// The number of strings of the followed level (1 while no play is followed).
    var stringCount: Int { max(play?.level.strings.count ?? 1, 1) }
    /// The chosen string in words.
    var stringLabel: String { "string \(string)" }
    /// The chosen peg in words.
    var pegLabel: String { "peg \(peg)" }
    /// The current peg of the chosen string in the followed play, if any.
    var currentPeg: Int? {
        guard let play, string >= 0, string < play.pegs.count else { return nil }
        return play.pegs[string]
    }
    /// The chosen string in words with its ends, current peg and lock, and the peg it would be tuned to.
    var choiceLabel: String {
        guard let play, string >= 0, string < play.level.strings.count else { return stringLabel + ", " + pegLabel }
        let current: Int = currentPeg ?? play.level.strings[string].peg
        return play.level.stringName(string, peg: current) + "; tune to " + pegLabel
    }

    /// Moves the chosen string by `delta`, clamped to the level's strings; the peg becomes that string's current peg.
    func stepString(_ delta: Int) {
        string = min(max(string + delta, 0), stringCount - 1)
        if let currentPeg { peg = Self.clampedPeg(currentPeg) }
    }

    /// Moves the chosen peg by `delta`, clamped to 1 … 12.
    func stepPeg(_ delta: Int) { peg = Self.clampedPeg(peg + delta) }

    /// `value` clamped to the peg range.
    static func clampedPeg(_ value: Int) -> Int { min(max(value, pegRange.lowerBound), pegRange.upperBound) }

    /// Takes the new `play`: a new level chooses string 0 at its current peg; otherwise the choice is clamped.
    func follow(_ play: HarmonicBridgesPlay) {
        let changedLevel: Bool = self.play?.level.id != play.level.id
        self.play = play
        if changedLevel {
            string = 0
            peg = Self.clampedPeg(currentPeg ?? Self.pegRange.lowerBound)
        } else {
            string = min(max(string, 0), stringCount - 1)
            peg = Self.clampedPeg(peg)
        }
    }

    /// A refused action's reason code in words.
    static func refusalText(code: String) -> String {
        switch code {
        case "r02-g12.noop": "that string is already at that peg"
        case "r02-g12.stage": "the play is over: undo or go to the next level"
        case "r02-g12.action": "that string cannot be tuned to that peg"
        case "r02-g12.stale": "the play changed before the action arrived"
        case "r02-g12.level": "the next level could not be made"
        case HarmonicBridgesExperienceRule.notWhole: "a string and a peg must be whole numbers"
        default: "that action is not available now"
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct HarmonicBridgesTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Harmonic Bridges.
@MainActor
final class HarmonicBridgesPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = HarmonicBridgesExperienceCore

    /// Whether the strings are drawn at rest and the shown step is held (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show and choose.
    let mirror = HarmonicBridgesMirror()
    /// The GL scene.
    let scene = HarmonicBridgesBridgeScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1203-004).
    private(set) var tierLog: [HarmonicBridgesTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: HarmonicBridgesSceneSnapshot?

    /// What restarts the step clock: the play's level, pegs, actions spent, stage and failure.
    private struct PlayKey: Equatable {
        let levelNumber: Int
        let pegs: [Int]
        let actionsSpent: Int
        let stage: HarmonicBridgesStage
        let failure: HarmonicBridgesFailure?
    }

    /// The play last seen and the frame time it was first drawn (the step clock starts there).
    private var playKey: PlayKey?
    private var playStart: Double = 0

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the bridge program's fragment source with one that does not compile.
    func breakBridgeShader() {
        scene.bridgeFragment = "this is not a shader;"
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
    private func follow(_ core: HarmonicBridgesExperienceCore) {
        if mirror.play != core.play { mirror.follow(core.play) }
    }

    /// The seconds since the play last changed at frame time `now`: the clock restarts whenever the level, the pegs,
    /// the actions spent, the stage or the failure change (a tune, a test, an undo, a redo or a new level).
    func stepTime(_ core: HarmonicBridgesExperienceCore, now: Double) -> Double {
        let play: HarmonicBridgesPlay = core.play
        let key = PlayKey(levelNumber: core.levelNumber, pegs: play.pegs, actionsSpent: play.actionsSpent,
                          stage: play.stage, failure: play.failure)
        if key != playKey {
            playKey = key
            playStart = now
        }
        let elapsed: Double = now - playStart
        return elapsed.isFinite ? max(0, elapsed) : 0
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: HarmonicBridgesExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = HarmonicBridgesTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(HarmonicBridgesTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time = stepTime(core, now: frame.time)
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the bridges (the camera
    /// fits the scene inside a 6 % margin), are `dark` (the mist ground) once a snapshot was drawn by the real scene;
    /// none otherwise.
    func probes(_ core: HarmonicBridgesExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "ground-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "ground-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: HarmonicBridgesExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        let reachable: String = level.steps.count == 1 ? "the one step" : "every one of the \(level.steps.count) steps"
        mirror.targetLabel = "Level: cross from island \(level.start) to island \(level.goal) in \(reachable); "
            + "\(level.strings.count) strings, threshold \(level.threshold)"
        let measure: String = play.progressDescription
        mirror.measureLabel = measure
        var text = "Harmonic Bridges level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The crossing holds in every step."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = HarmonicBridgesSceneSnapshot.failureText(play.failure) ?? "The play failed."
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
        AnyView(HarmonicBridgesControls(port: port, mirror: mirror))
    }
}
#endif
