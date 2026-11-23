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
// Feature 414 (R02-G12-04): `pointer(_:viewSize:port:)` routes canvas touches through
// `HarmonicBridgesGestureController` with the drawn snapshot: a pluck chooses a string and describes its resonance in the
// drawn step, a peg drag previews the peg in the panel and tunes on release, a tap on the goal or a step pip tests the
// crossing; tunes and tests go through the port (refusals are shown and kept with their code in `refusalLog`); a drag
// that ends without a tune puts the panel's peg back to the string's current peg; a one-finger gesture on a won or
// failed play says that the play is over; the scene draws the controller's orbit, and "Reset view" or a double tap on
// empty space returns to the authored view.
#if os(iOS)
import Foundation
import HarmonicBridgesCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

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

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<kernel code>`).
    static let rulePrefix = "action.rule."

    /// A refused action's reason code in words; accepts the kernel's code bare or as the engine reports it
    /// (`action.rule.r02-g12.noop`).
    static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        return switch bare {
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

    /// The gesture controller (feature 414): plucks, peg drags, test taps, double taps, orbit.
    private(set) var gestures = HarmonicBridgesGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64
    /// What a gesture on a finished play shows, and what the description adds on a won or failed play.
    static let finishedMessage = "The play is over: undo or go to the next level"
    /// The string whose drag previewed a peg and has not ended in a tune, if any.
    private var previewing: Int?

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
        scene.orbit = gestures.orbit
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
            text += "The crossing holds in every step. " + Self.finishedMessage + "."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = HarmonicBridgesSceneSnapshot.failureText(play.failure) ?? "The play failed."
            text += reason + " " + Self.finishedMessage + "."
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
        AnyView(HarmonicBridgesControls(port: port, mirror: mirror,
                                        resetView: { [weak self] in self?.resetView() },
                                        sender: { [weak self] control, values in
                                            self?.send(control, values, port: port)
                                        }))
    }

    // MARK: Touch controls (feature 414, R02-G12-04)

    /// The canvas gestures send tunes and tests; the choice, the preview and the orbit are presentation state.
    var gestureActions: Set<String> { ["string.tune", "crossing.test"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(HarmonicBridgesExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and applies what it returns, in
    /// order: choices and previews go to the mirror (a choice also describes the string's resonance), tunes and tests
    /// are sent through the port; a drag that ends without a tune restores the panel's peg; a one-finger gesture that
    /// ends on a won or failed play explains that the play is over.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let before: HarmonicBridgesGestureController.State = gestures.state
        let actions: [HarmonicBridgesGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        let finished: Bool = snapshot.stage == .won || snapshot.stage == .failed || snapshot.stage == .result
        let oneFinger: Bool = before == .stringPress || before == .pegDrag || before == .targetPress
        var tuned = false
        var chose = false
        for action in actions {
            switch action {
            case let .choose(string, peg):
                chose = true
                choose(string, peg: peg, snapshot: snapshot)
            case let .preview(string, peg):
                mirror.string = string
                mirror.peg = HarmonicBridgesMirror.clampedPeg(peg)
                previewing = string
            case let .tune(string, peg):
                tuned = true
                previewing = nil
                send("string.tune", [Double(string), Double(peg)], port: port)
            case .test:
                send("crossing.test", [], port: port)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
        let ended: Bool = event.phase == .ended || event.phase == .cancelled || gestures.state == .orbiting
        if ended, !tuned { restorePreview(snapshot) }
        if event.phase == .ended, finished, oneFinger, !chose {
            mirror.message = Self.finishedMessage
        }
        scene.orbit = gestures.orbit
    }

    /// Cancels the touches in progress (suspension): nothing is sent and the panel's peg is restored.
    func cancelPointers() {
        gestures.cancel()
        if let snapshot = lastSnapshot { restorePreview(snapshot) }
    }

    /// Returns the camera to the authored view ("Reset view"; presentation only).
    func resetView() {
        gestures.resetView()
        scene.orbit = gestures.orbit
    }

    /// Chooses `string` at `peg` in the panel and describes its resonance in the drawn step.
    private func choose(_ string: Int, peg: Int, snapshot: HarmonicBridgesSceneSnapshot) {
        mirror.string = string
        mirror.peg = HarmonicBridgesMirror.clampedPeg(peg)
        previewing = nil
        mirror.message = Self.resonanceText(string, snapshot: snapshot,
                                            step: HarmonicBridgesSceneGeometry.drawnStep(snapshot,
                                                                                        reduceMotion: reduceMotion))
    }

    /// Puts the panel's peg back to the previewed string's current peg after a drag that ended without a tune.
    private func restorePreview(_ snapshot: HarmonicBridgesSceneSnapshot) {
        guard let string = previewing else { return }
        previewing = nil
        if string >= 0, string < snapshot.pegs.count, mirror.string == string {
            mirror.peg = HarmonicBridgesMirror.clampedPeg(snapshot.pegs[string])
        }
    }

    /// String `index` in step `step` in words: the modes it sings and how many of its five samples reach the threshold
    /// (the kernel's exact swings).
    static func resonanceText(_ index: Int, snapshot: HarmonicBridgesSceneSnapshot, step: Int) -> String {
        guard index >= 0, index < snapshot.strings.count else { return "That string is not in this level." }
        var modes: [Int] = []
        if step >= 0, step < snapshot.modes.count, index < snapshot.modes[step].count { modes = snapshot.modes[step][index] }
        var reaching = 0
        if step >= 0, step < snapshot.report.swings.count, index < snapshot.report.swings[step].count {
            for swing in snapshot.report.swings[step][index] where swing >= snapshot.threshold { reaching += 1 }
        }
        let peg: Int = index < snapshot.pegs.count ? snapshot.pegs[index] : snapshot.strings[index].peg
        var text = "String \(index) at peg \(peg)"
        if snapshot.strings[index].locked { text += " (locked)" }
        if modes.isEmpty {
            text += " sings no mode in step \(step)"
        } else {
            let names: [String] = modes.map { String($0) }
            text += " sings mode " + names.joined(separator: " and ") + " in step \(step)"
        }
        text += "; \(reaching) of 5 samples reach the threshold."
        return text
    }

    /// Sends `control` with `values`, shows a refusal in words in the panel and keeps its code in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            mirror.message = "That change was refused: \(HarmonicBridgesMirror.refusalText(code: result.code))."
            refusalLog.append(result.code)
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }
}
#endif
