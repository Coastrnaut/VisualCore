// ApsidesWorkshopPresenter — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-003, 004, 005, 007; clarifications
// Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `ApsidesWorkshopCompassScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`), keeps a log of every
// tier change with its reason, and caps the glow under Reduce Flashing. One clock feeds the picture, presentation only:
// the star's glow pulses with the frame time (`u_pulse`, held at 1 under Reduce Motion); the shown tick is the
// adapter's presentation state (`clock.show`) and is never advanced by time. The tutorial of levels 1 … 3 is shown in
// words, as presentation, not as a kernel stage. A refused action is shown in words. A memory warning releases the GPU
// objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel
// (renderer purity). Its probes (two backdrop corners) let the verification runner check a frame.
#if os(iOS)
import ApsidesWorkshopCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show: the latest state the presenter described and the shown tick.
@MainActor
@Observable
final class ApsidesWorkshopMirror {
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
    /// The progress in words (the kernel's progress description and the actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The tutorial in words on levels that have one; nil otherwise.
    var tutorialText: String?
    /// The shown tick, the adapter's.
    var shownTick = 0
    /// The play followed (a copy; never sent anywhere).
    var play: ApsidesWorkshopPlay?
    /// The text of the last refused change, if any.
    var message: String?

    /// The current orbit of the followed play (a mid-range orbit while no play is followed).
    var orbit: ApsidesWorkshopOrbit { play?.orbit ?? ApsidesWorkshopOrbit(size: 24, eccentricity: 0, direction: 0) }
    /// The period of the followed level in ticks (1 while no play is followed).
    var period: Int { max(play?.level.period ?? 1, 1) }

    /// `value` clamped to the ticks 0 … period − 1.
    func clampedTick(_ value: Int) -> Int { min(max(value, 0), period - 1) }

    /// The orbit in words: its size, eccentricity and periapsis direction, and its apsides.
    var orbitLabel: String {
        guard let play else { return "no orbit" }
        let orbit: ApsidesWorkshopOrbit = play.orbit
        return play.level.orbitDescription(orbit) + "; periapsis in " + play.level.sectorName(orbit.periapsisSector)
            + " at " + ApsidesWorkshopLevel.distanceWords(orbit.periapsisDistance) + ", apoapsis in "
            + play.level.sectorName(orbit.apoapsisSector) + " at "
            + ApsidesWorkshopLevel.distanceWords(orbit.apoapsisDistance)
    }

    /// The shown tick in words with the orbiter's sector.
    var tickLabel: String {
        guard let play else { return "tick \(shownTick)" }
        let tick: Int = clampedTick(shownTick)
        let point: ApsidesWorkshopPoint = play.report.positions[tick]
        return "tick \(tick) of \(play.level.period): the orbiter is in "
            + play.level.sectorName(ApsidesWorkshopSky.sector(of: point))
    }

    /// Takes the new `play` and presentation.
    func follow(_ play: ApsidesWorkshopPlay, shownTick: Int) {
        self.play = play
        self.shownTick = shownTick
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: ApsidesWorkshopFailure?) -> String? {
        switch failure {
        case let .contact(planet, tick)?:
            "The orbit struck planet \(planet) after tick \(tick)."
        case let .order(target, tick)?:
            "Target \(target) came at tick \(tick), before the target before it."
        case let .share(target, tick, share)?:
            "Target \(target) (first reached at tick \(tick)) swept "
                + ApsidesWorkshopLevel.shareWords(share) + ", outside its band."
        case let .apsisSector(target, sector)?:
            "Target \(target): the apsis lies in sector \(sector), not the sector it asks for."
        case let .apsisDistance(target, distance)?:
            "Target \(target): the apsis lies at " + ApsidesWorkshopLevel.distanceWords(distance)
                + ", outside its range."
        case nil: nil
        }
    }

    /// A refused action's reason code in words.
    static func refusalText(code: String) -> String {
        switch code {
        case "r02-g18.stage": "the play is over: undo a failed play or go to the next level"
        case "r02-g18.action": "that orbit cannot be set, or there is nothing to undo or redo"
        case "r02-g18.budget": "no actions are left: play the orbit or undo a tuning"
        case "r02-g18.stale": "the play changed before the action arrived"
        case "r02-g18.level": "the next level could not be made"
        case ApsidesWorkshopExperienceRule.notWhole: "the orbit's steps and the tick must be whole numbers"
        case ApsidesWorkshopExperienceRule.tick: "that tick is past the end of the revolution"
        default: "that action is not available now"
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct ApsidesWorkshopTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Apsides Workshop.
@MainActor
final class ApsidesWorkshopPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = ApsidesWorkshopExperienceCore

    /// The tutorial shown on levels that have one (presentation, not a kernel stage).
    static let tutorial = "Tune the orbit with the periapsis knob and the size so it sweeps the target sectors and "
        + "puts its apsides where the gauges ask, in order, without striking a planet; then play the revolution."

    /// Whether the star is still (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = ApsidesWorkshopMirror()
    /// The GL scene.
    let scene = ApsidesWorkshopCompassScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1803-004).
    private(set) var tierLog: [ApsidesWorkshopTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: ApsidesWorkshopSceneSnapshot?

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the compass program's fragment source with one that does not compile.
    func breakCompassShader() {
        scene.compassFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the Core's `qualityTiers` (`level-0` … `level-2`).
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(ApsidesWorkshopTier.of(tier).name) }
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
    private func follow(_ core: ApsidesWorkshopExperienceCore) {
        if mirror.play != core.play || mirror.shownTick != core.shownTick {
            mirror.follow(core.play, shownTick: core.shownTick)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: ApsidesWorkshopExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = ApsidesWorkshopTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(ApsidesWorkshopTierChange(tier: drawn.index, reason: reason))
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the compass, the
    /// gauges and the actions bars (the camera fits the scene inside a 5 % margin), are `dark` (the midnight backdrop)
    /// once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: ApsidesWorkshopExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: ApsidesWorkshopExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.tutorialText = level.tutorial ? Self.tutorial : nil
        mirror.targetLabel = "Level: \(level.targets.count) targets in order, \(level.planets.count) planets, "
            + "\(level.period) ticks per revolution"
        let measure: String = level.progressDescription(report: play.report, orbit: play.orbit,
                                                        actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Apsides Workshop level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every target was met in order without striking a planet."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = ApsidesWorkshopMirror.failureText(play.failure) ?? "The play failed."
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
        AnyView(ApsidesWorkshopControls(port: port, mirror: mirror))
    }
}
#endif
