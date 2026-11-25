// CelestialEclipseLabPresenter — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-003, 004, 005, 007;
// clarifications Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `CelestialEclipseLabSkyScene` at the
// host's quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`),
// keeps a log of every tier change with its reason, and caps the glow under Reduce Flashing. One clock feeds the
// picture, presentation only: the corona halos pulse with the frame time (`u_pulse`, held at 1 under Reduce Motion);
// the shown tick is the adapter's presentation state (`clock.show`) and is never advanced by time. The chosen body and
// the shown tick are read from the core. The tutorial of levels 1 … 3 is shown in words, as presentation, not as a
// kernel stage. A refused action is shown in words. A memory warning releases the GPU objects; the next frame
// rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel (renderer purity). Its
// probes (two backdrop corners) let the verification runner check a frame.
#if os(iOS)
import CelestialEclipseLabCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show: the latest state the presenter described and the chosen body and shown tick.
@MainActor
@Observable
final class CelestialEclipseLabMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions left.
    var actionsLeft = 0
    /// The action budget.
    var budget = 0
    /// A one-line status: "Ready", "Playing", "Won" or "Failed: " and the failure in words.
    var status = ""
    /// The failure in words, if the run failed.
    var failureText: String?
    /// The progress in words (the kernel's progress description and the actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The tutorial in words on levels that have one; nil otherwise.
    var tutorialText: String?
    /// The chosen body, the adapter's.
    var chosenBody = 0
    /// The shown tick, the adapter's.
    var shownTick = 0
    /// The play followed (a copy; never sent anywhere).
    var play: CelestialEclipseLabPlay?
    /// The text of the last refused change, if any.
    var message: String?

    /// The number of bodies of the followed level (1 while no play is followed).
    var bodyCount: Int { max(play?.level.bodies.count ?? 1, 1) }
    /// The horizon of the followed level in ticks (1 while no play is followed).
    var horizon: Int { max(play?.level.horizon ?? 1, 1) }
    /// The period of the chosen body (1 while no play is followed or the body is unknown).
    var chosenPeriod: Int {
        guard let play, play.level.bodies.indices.contains(chosenBody) else { return 1 }
        return max(play.level.bodies[chosenBody].period, 1)
    }
    /// The current phase of the chosen body (0 while no play is followed or the body is unknown).
    var chosenPhase: Int {
        guard let play, play.phases.indices.contains(chosenBody) else { return 0 }
        return play.phases[chosenBody]
    }
    /// Whether the chosen body's phase is fixed.
    var chosenFixed: Bool {
        guard let play, play.level.bodies.indices.contains(chosenBody) else { return false }
        return play.level.bodies[chosenBody].fixed
    }

    /// The next movable body after `chosenBody` in direction `step` (±1), wrapping around; the chosen body when no
    /// other is movable.
    func nextBody(_ step: Int) -> Int {
        guard let play else { return chosenBody }
        let count: Int = bodyCount
        var candidate: Int = chosenBody
        for _ in 0..<count {
            candidate = ((candidate + step) % count + count) % count
            if play.level.bodies.indices.contains(candidate), !play.level.bodies[candidate].fixed { return candidate }
        }
        return chosenBody
    }

    /// The chosen body's phase moved by `step` (±1) modulo its period.
    func steppedPhase(_ step: Int) -> Int {
        let period: Int = chosenPeriod
        return ((chosenPhase + step) % period + period) % period
    }

    /// `value` clamped to the ticks 0 … horizon − 1.
    func clampedTick(_ value: Int) -> Int { min(max(value, 0), horizon - 1) }

    /// The chosen body in words: its name, phase and period, and whether it is fixed.
    var bodyLabel: String {
        guard let play else { return "body \(chosenBody)" }
        let name: String = play.level.bodyName(chosenBody)
        let fixed: String = chosenFixed ? ", fixed" : ""
        return "\(name), phase \(chosenPhase) of \(chosenPeriod)\(fixed)"
    }

    /// The shown tick in words with the eclipses under way at it.
    var tickLabel: String {
        guard let play else { return "tick \(shownTick)" }
        let level: CelestialEclipseLabLevel = play.level
        let eclipses: [CelestialEclipseLabEclipse] =
            CelestialEclipseLabSceneSnapshot.eclipses(level, phases: play.phases, tick: clampedTick(shownTick))
        var text: String = "tick \(shownTick) of \(level.horizon)"
        if eclipses.isEmpty { return text + ": no eclipse" }
        var parts: [String] = []
        for eclipse in eclipses {
            parts.append(level.eclipseName(front: eclipse.front, back: eclipse.back) + ", "
                         + eclipse.visibility.rawValue)
        }
        text += ": " + parts.joined(separator: "; ")
        return text
    }

    /// Takes the new `play` and presentation.
    func follow(_ play: CelestialEclipseLabPlay, chosenBody: Int, shownTick: Int) {
        self.play = play
        self.chosenBody = chosenBody
        self.shownTick = shownTick
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: CelestialEclipseLabFailure?) -> String? {
        switch failure {
        case let .unwanted(front, back, tick)?:
            "Body \(front) passed in front of body \(back) at tick \(tick) before the next target eclipse."
        case let .window(front, back, tick, open, close)?:
            "Body \(front) passed in front of body \(back) at tick \(tick), outside its window, ticks \(open) to "
                + "\(close)."
        case let .horizon(front, back, open, close)?:
            "The clock reached its horizon before body \(front) passed in front of body \(back) in its window, ticks "
                + "\(open) to \(close)."
        case nil: nil
        }
    }

    /// A refused action's reason code in words.
    static func refusalText(code: String) -> String {
        switch code {
        case "r02-g17.stage": "the play is over: undo a failed run or go to the next level"
        case "r02-g17.action": "that phase cannot be set, or there is nothing to undo or redo"
        case "r02-g17.budget": "no actions are left: run the clock or undo a change"
        case "r02-g17.stale": "the play changed before the action arrived"
        case "r02-g17.level": "the next level could not be made"
        case CelestialEclipseLabExperienceRule.notWhole: "a body, phase and tick must be whole numbers"
        case CelestialEclipseLabExperienceRule.choice: "that body cannot be chosen"
        case CelestialEclipseLabExperienceRule.tick: "that tick is past the horizon"
        default: "that action is not available now"
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct CelestialEclipseLabTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Celestial Eclipse Lab.
@MainActor
final class CelestialEclipseLabPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = CelestialEclipseLabExperienceCore

    /// The tutorial shown on levels that have one (presentation, not a kernel stage).
    static let tutorial = "Set each planet's phase so the eclipses come in the target order, each inside its window "
        + "on the timeline, then run the clock."

    /// Whether the halos are still (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = CelestialEclipseLabMirror()
    /// The GL scene.
    let scene = CelestialEclipseLabSkyScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1703-004).
    private(set) var tierLog: [CelestialEclipseLabTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: CelestialEclipseLabSceneSnapshot?

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the sky program's fragment source with one that does not compile.
    func breakSkyShader() {
        scene.skyFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the Core's `qualityTiers` (`level-0` … `level-2`).
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(CelestialEclipseLabTier.of(tier).name) }
        return names
    }

    /// Records the registry and the aspect.
    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    /// Follows the new drawable size.
    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    /// Follows `core`'s play and presentation in the mirror when they changed.
    private func follow(_ core: CelestialEclipseLabExperienceCore) {
        if mirror.play != core.play || mirror.chosenBody != core.chosenBody || mirror.shownTick != core.shownTick {
            mirror.follow(core.play, chosenBody: core.chosenBody, shownTick: core.shownTick)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: CelestialEclipseLabExperienceCore, tier: Int, context: RenderContext,
              frame: FrameInfo) throws {
        let drawn = CelestialEclipseLabTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(CelestialEclipseLabTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        try scene.render(snapshot, tier: drawn, context: context, frame: frame)
    }

    /// Releases every GPU object.
    func teardown(_ context: RenderContext) {
        scene.release()
    }

    /// Releases every GPU object (memory warning); the next frame rebuilds them.
    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the sky, the rings,
    /// the timeline and the actions bars (the camera fits the scene inside a 6 % margin), are `dark` (the ink
    /// backdrop) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: CelestialEclipseLabExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: CelestialEclipseLabExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.tutorialText = level.tutorial ? Self.tutorial : nil
        mirror.targetLabel = "Level: \(level.target.count) target eclipses in order among \(level.bodies.count) "
            + "bodies over \(level.horizon) ticks"
        let measure: String = level.progressDescription(timeline: play.timeline, actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Celestial Eclipse Lab level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every target eclipse came in order inside its window."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = CelestialEclipseLabMirror.failureText(play.failure) ?? "The run failed."
            text += reason
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        default:
            let played: Bool = play.records.contains { record in
                record.kind != .begin && record.kind != .dismissTutorial
            }
            mirror.status = played ? "Playing" : "Ready"
            mirror.failureText = nil
        }
        return text
    }

    /// The control panel.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(CelestialEclipseLabControls(port: port, mirror: mirror))
    }
}
#endif
