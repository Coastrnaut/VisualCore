// BinaryGardensPresenter — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-003, 004, 005, 007, 010;
// clarifications Q2, Q4, Q5). Draws the adapter's immutable snapshot with `BinaryGardensSystemScene` at the host's
// quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityProfile` names, the
// names of `BinaryGardensTier.all`), keeps a log of every tier change with its reason, stops the coronas and the
// pollen motes under Reduce Motion and caps the glow under Reduce Flashing. No position moves by time: the shown tick
// is the adapter's presentation state (`clock.show`, 48 at an opening) and is never advanced by time; only the coronas
// and the motes move with the presentation time. The tutorial of the first levels is shown in words, as presentation,
// not as a kernel stage. A refused action is shown in words. A memory warning releases the GPU objects; the next frame
// rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel (renderer purity). Its
// probes (two backdrop corners) let the verification runner check a frame (the round-two X gates require them).
// Modelled on `MushroomWeatherPresenter` (feature 493).
#if os(iOS)
import BinaryGardensCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show: the latest state the presenter described, the shown tick and the panel's selection.
@MainActor
@Observable
final class BinaryGardensMirror {
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
    /// The progress in words (the kernel's progress description).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The tutorial in words on levels that have one; nil otherwise.
    var tutorialText: String?
    /// The shown tick, the adapter's (1 … 48).
    var shownTick = BinaryGardensExperienceCore.openingTick
    /// The play followed (a copy; never sent anywhere).
    var play: BinaryGardensPlay?
    /// The text of the last refused change, if any.
    var message: String?
    /// The star the panel edits (0 or 1).
    var star = 0

    /// The ticks of one cycle, 48.
    static var cycle: Int { BinaryGardensSky.cycle }

    /// The star the panel edits, clamped to 0 … 1.
    var selectedStar: Int { min(max(star, 0), 1) }

    /// The arrangement of the followed play (nil while no play is followed).
    var arrangement: BinaryGardensArrangement? { play?.arrangement }

    /// The rings of the followed level (1 while no play is followed).
    var ringCount: Int { max(play?.level.ringRadii.count ?? 1, 1) }

    /// The luminosity levels of the followed level (1 while no play is followed).
    var luminosityCount: Int { max(play?.level.luminosityLevels.count ?? 1, 1) }

    /// The largest tilt T_max of the followed level (0 while no play is followed).
    var maxTilt: Int { play?.level.maxTilt ?? 0 }

    /// The phase step g of the followed level (1 while no play is followed).
    var phaseStep: Int { max(play?.level.phaseStep ?? 1, 1) }

    /// The selected star's ring index (0 while no play is followed).
    var ring: Int { value(arrangement?.rings) }

    /// The selected star's phase (0 while no play is followed).
    var phase: Int { value(arrangement?.phases) }

    /// The selected star's luminosity index (0 while no play is followed).
    var luminosity: Int { value(arrangement?.luminosities) }

    /// The tilt (0 while no play is followed).
    var tilt: Int { arrangement?.tilt ?? 0 }

    /// The selected star's entry of `values`, or 0.
    private func value(_ values: [Int]?) -> Int {
        guard let values, values.indices.contains(selectedStar) else { return 0 }
        return values[selectedStar]
    }

    /// The ring index `step` rings from the selected star's, clamped to the level's rings (the kernel refuses the
    /// unchanged ring at an end).
    func ring(moved step: Int) -> Int { min(max(ring + step, 0), ringCount - 1) }

    /// The phase `step` phase steps g from the selected star's, read cyclically over 0 … 47 (always on the grid).
    func phase(moved step: Int) -> Int {
        let cycle: Int = Self.cycle
        return ((phase + step * phaseStep) % cycle + cycle) % cycle
    }

    /// The luminosity index `step` levels from the selected star's, clamped to the level's levels.
    func luminosity(moved step: Int) -> Int { min(max(luminosity + step, 0), luminosityCount - 1) }

    /// The tilt `step` steps from the current one, clamped to 0 … T_max.
    func tilt(moved step: Int) -> Int { min(max(tilt + step, 0), maxTilt) }

    /// Tick `tick` read cyclically as one of 1 … 48 (tick 49 is tick 1, tick 0 is tick 48).
    static func wrappedTick(_ tick: Int) -> Int {
        let cycle: Int = Self.cycle
        return ((tick - 1) % cycle + cycle) % cycle + 1
    }

    /// The selected star in words (the kernel's star description), or "no star".
    var starLabel: String {
        guard let play else { return "no star" }
        return play.level.starDescription(selectedStar, arrangement: play.arrangement)
    }

    /// The tilt in words.
    var tiltLabel: String { "tilt \(tilt) of \(maxTilt) steps" }

    /// The shown tick in words.
    var tickLabel: String { "tick \(shownTick) of \(Self.cycle)" }

    /// Every world at the shown tick in words (the kernel's tick descriptions), joined by "; ".
    var worldsLabel: String {
        guard let play else { return "no worlds" }
        let tick: Int = Self.wrappedTick(shownTick)
        var parts: [String] = []
        for world in play.level.worlds.indices where world < play.report.worlds.count {
            parts.append(play.level.worldTickDescription(world, tick: tick, report: play.report))
        }
        return parts.joined(separator: "; ")
    }

    /// Takes the new `play` and presentation.
    func follow(_ play: BinaryGardensPlay, shownTick: Int) {
        self.play = play
        self.shownTick = shownTick
    }

    /// A failure in words, naming what the kernel's reason names (the level's failure description, first letter in
    /// upper case, with a full stop); nil without a failure.
    static func failureText(_ failure: BinaryGardensFailure?, level: BinaryGardensLevel) -> String? {
        guard let failure else { return nil }
        return level.failureDescription(failure).capitalizedFirst + "."
    }

    /// The prefix the engine puts before a rule's code in an action result's code.
    static let rulePrefix = "action.rule."

    /// A refused action's reason code in words: the rule's code (`r02-g21.…`), with or without the engine's
    /// `action.rule.` prefix (an action result's code carries it).
    static func refusalText(code: String) -> String {
        let rule: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch rule {
        case "r02-g21.stage": return "the play is over: undo a failed run or go to the next level"
        case "r02-g21.action": return "that ring, phase, luminosity or tilt cannot be set that way (locked, unchanged, off "
            + "the phase grid or too close to the other star), or there is nothing to undo or redo"
        case "r02-g21.budget": return "no actions are left: run the light or undo a change"
        case "r02-g21.stale": return "the play changed before the action arrived"
        case "r02-g21.level": return "the next level could not be made"
        case "r02-g21.generation": return "the next level could not be made"
        case BinaryGardensExperienceRule.notWhole: return "the star, ring, phase, luminosity, tilt and tick must be whole "
            + "numbers"
        case BinaryGardensExperienceRule.tick: return "only ticks 1 to 48 can be shown"
        default: return "that action is not available now"
        }
    }
}

private extension String {
    /// The string with its first letter in upper case.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct BinaryGardensTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Binary Gardens.
@MainActor
final class BinaryGardensPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = BinaryGardensExperienceCore

    /// The tutorial shown on levels that have one (presentation, not a kernel stage).
    static let tutorial = "Move the twin stars between their rings, shift their phases, set their brightness and tilt "
        + "the orbit plane so every flower world keeps a long enough comfortable window and its total light inside "
        + "its bloom band, without freezing or scorching for too long; then run the light."

    /// Whether Reduce Motion is on (the coronas and motes stop).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = BinaryGardensMirror()
    /// The GL scene.
    let scene = BinaryGardensSystemScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G2103-004).
    private(set) var tierLog: [BinaryGardensTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: BinaryGardensSceneSnapshot?

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedMotion = reduceMotion
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the system program's fragment source with one that does not compile.
    func breakSystemShader() {
        scene.systemFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the names of the Core's `qualityProfile` (`level-0` … `level-2`, the
    /// names of `BinaryGardensTier.all`), as many as the Core's `qualityTiers`.
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(BinaryGardensTier.of(tier).name) }
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
    private func follow(_ core: BinaryGardensExperienceCore) {
        if mirror.play != core.play || mirror.shownTick != core.shownTick {
            mirror.follow(core.play, shownTick: core.shownTick)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: BinaryGardensExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = BinaryGardensTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(BinaryGardensTierChange(tier: drawn.index, reason: reason))
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the tilt dial, the
    /// system, the gauges and the actions bars (the camera fits the scene's box inside a 6 % margin per side), are
    /// `dark` (the space backdrop) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: BinaryGardensExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: BinaryGardensExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.tutorialText = level.tutorial ? Self.tutorial : nil
        let tiltWords: String = level.maxTilt == 0 ? "the orbit plane locked" : "tilt up to \(level.maxTilt) steps"
        mirror.targetLabel = "Level: \(level.ringRadii.count) rings, \(level.worlds.count) worlds, "
            + "\(level.luminosityLevels.count) luminosity levels, phase step \(level.phaseStep), " + tiltWords
            + ", lethal tolerance \(level.lethalTolerance) ticks, \(level.budget) actions"
        let measure: String = level.progressDescription(report: play.report, arrangement: play.arrangement,
                                                        actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Binary Gardens level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every world kept its window and bloomed."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = BinaryGardensMirror.failureText(play.failure, level: level) ?? "The run failed."
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
        AnyView(BinaryGardensControls(port: port, mirror: mirror))
    }
}
#endif
