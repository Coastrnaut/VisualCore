// MyceliumArchitectPresenter — feature 513 (R02-G22-03) T-R02G2203-005 (FR-R02G2203-003, 004, 005, 007, 010;
// clarifications Q2, Q4, Q5). Draws the adapter's immutable snapshot with `MyceliumArchitectBoardScene` at the host's
// quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityProfile` names, the
// names of `MyceliumArchitectTier.all`), keeps a log of every tier change with its reason, stills the vein pulses,
// toxin ripples, hyphae fuzz and spores under Reduce Motion (`u_motion` 0) and caps the glow under Reduce Flashing
// (the glow gain per tier: level-0 1.5, level-1 1.0, level-2 none; the cap 0.5). Nothing moves the network by time:
// the shown pulse is the adapter's presentation state (`growth.show`, the pulses run at an opening and after every
// action) and is never advanced by time; only the pulses of light along the veins, the ripples, the fuzz and the
// spores move with the presentation time. The tutorial of the first levels is shown in words, as presentation, not as
// a kernel stage. A refused action is shown in words. A memory warning releases the GPU objects; the next frame
// rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel (renderer purity). Its
// probes (two backdrop corners) let the verification runner check a frame (the round-two X gates require them).
// Modelled on `BinaryGardensPresenter` (feature 503).
#if os(iOS)
import Foundation
import MyceliumArchitectCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show: the latest state the presenter described, the shown pulse and the panel's selection (the
/// cell cursor and the direction).
@MainActor
@Observable
final class MyceliumArchitectMirror {
    /// The level number (1 … 100).
    var levelNumber: Int = 1
    /// The actions left.
    var actionsLeft: Int = 0
    /// The action budget.
    var budget: Int = 0
    /// A one-line status: "Ready", "Playing", "Won" or "Failed: " and the failure in words.
    var status: String = ""
    /// The failure in words, if the play failed.
    var failureText: String?
    /// The progress in words (the kernel's progress description).
    var measureLabel: String = ""
    /// The level in words.
    var targetLabel: String = ""
    /// The tutorial in words on levels that have one; nil otherwise.
    var tutorialText: String?
    /// The shown pulse, the adapter's (0 … the pulses run).
    var shownPulse: Int = 0
    /// The play followed (a copy; never sent anywhere).
    var play: MyceliumArchitectPlay?
    /// The text of the last refused change, if any.
    var message: String?
    /// The cursor's column (the panel's selection; clamped to the board when read).
    var column: Int = 0
    /// The cursor's row (the panel's selection; clamped to the board when read).
    var row: Int = 0
    /// The direction the panel seeds or unseeds (0 north … 7 north-west).
    var direction: Int = 0

    /// The board's width of the followed play (1 while no play is followed).
    var boardWidth: Int { max(play?.level.width ?? 1, 1) }

    /// The board's height of the followed play (1 while no play is followed).
    var boardHeight: Int { max(play?.level.height ?? 1, 1) }

    /// The pulses run of the followed play's report (0 while no play is followed).
    var pulsesRun: Int { play?.report.pulsesRun ?? 0 }

    /// The cursor's column clamped to the board.
    var cursorColumn: Int { min(max(column, 0), boardWidth - 1) }

    /// The cursor's row clamped to the board.
    var cursorRow: Int { min(max(row, 0), boardHeight - 1) }

    /// The cursor's cell.
    var cursor: MyceliumArchitectCell { MyceliumArchitectCell(column: cursorColumn, row: cursorRow) }

    /// The selected direction clamped to 0 … 7.
    var selectedDirection: MyceliumArchitectDirection {
        MyceliumArchitectDirection(rawValue: min(max(direction, 0), 7)) ?? .north
    }

    /// Moves the cursor `step` columns, clamped to the board.
    func moveColumn(_ step: Int) { column = min(max(cursorColumn + step, 0), boardWidth - 1) }

    /// Moves the cursor `step` rows, clamped to the board.
    func moveRow(_ step: Int) { row = min(max(cursorRow + step, 0), boardHeight - 1) }

    /// The pulse `step` pulses from the shown one, clamped to 0 … the pulses run.
    func pulse(moved step: Int) -> Int { min(max(shownPulse + step, 0), pulsesRun) }

    /// The cursor's cell in words (the kernel's cell description), or "no cell".
    var cellLabel: String {
        guard let play else { return "no cell" }
        return play.level.cellDescription(cursor, arrangement: play.arrangement, report: play.report)
    }

    /// The selected direction in words, with whether it is seeded.
    var directionLabel: String {
        let words: String = selectedDirection.words
        guard let play else { return words }
        return play.arrangement.seeds.contains(selectedDirection) ? words + ", seeded" : words + ", not seeded"
    }

    /// The shown pulse in words.
    var pulseLabel: String { "pulse \(shownPulse) of \(pulsesRun)" }

    /// Every terminal in words (the kernel's terminal descriptions), joined by "; ".
    var terminalsLabel: String {
        guard let play else { return "no terminals" }
        var parts: [String] = []
        for terminal in play.level.terminals.indices where terminal < play.report.terminalPulses.count {
            parts.append(play.level.terminalDescription(terminal, report: play.report))
        }
        return parts.joined(separator: "; ")
    }

    /// Takes the new `play` and presentation.
    func follow(_ play: MyceliumArchitectPlay, shownPulse: Int) {
        self.play = play
        self.shownPulse = shownPulse
    }

    /// A failure in words, naming what the kernel's reason names (the level's failure description, first letter in
    /// upper case, with a full stop); nil without a failure.
    static func failureText(_ failure: MyceliumArchitectFailure?, level: MyceliumArchitectLevel) -> String? {
        guard let failure else { return nil }
        return level.failureDescription(failure).capitalizedFirst + "."
    }

    /// The prefix the engine puts before a rule's code in an action result's code.
    static let rulePrefix: String = "action.rule."

    /// A refused action's reason code in words: the rule's code (`r02-g22.…`), with or without the engine's
    /// `action.rule.` prefix (an action result's code carries it).
    static func refusalText(code: String) -> String {
        let rule: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch rule {
        case "r02-g22.stage": return "the play is over: undo a failed run or go to the next level"
        case "r02-g22.action": return "that cell or direction cannot be changed that way (off the board, not empty, "
            + "not a site, a limit reached, a starting seed or nothing to clear), or there is nothing to undo or redo"
        case "r02-g22.budget": return "no actions are left: run the growth or undo a change"
        case "r02-g22.stale": return "the play changed before the action arrived"
        case "r02-g22.level": return "the next level could not be made"
        case "r02-g22.generation": return "the next level could not be made"
        case MyceliumArchitectExperienceRule.notWhole: return "the column, row, direction and pulse must be whole "
            + "numbers"
        case MyceliumArchitectExperienceRule.pulse: return "only the pulses the growth has run can be shown"
        default: return "that action is not available now"
        }
    }
}

private extension String {
    /// The string with its first letter in upper case.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct MyceliumArchitectTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Mycelium Architect.
@MainActor
final class MyceliumArchitectPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = MyceliumArchitectExperienceCore

    /// The tutorial shown on levels that have one (presentation, not a kernel stage).
    static let tutorial: String = "Place nutrients and blockers on the marked sites and seed directions at the root so "
        + "the growing veins reach every terminal cap without entering a toxin, running out of nutrient or growing "
        + "heavier than the limit; then run the growth."

    /// Whether Reduce Motion is on (the vein pulses, ripples, fuzz and spores stand still).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror: MyceliumArchitectMirror = MyceliumArchitectMirror()
    /// The GL scene.
    let scene: MyceliumArchitectBoardScene = MyceliumArchitectBoardScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G2203-004).
    private(set) var tierLog: [MyceliumArchitectTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: MyceliumArchitectSceneSnapshot?

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedMotion = reduceMotion
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the board program's fragment source with one that does not compile.
    func breakBoardShader() {
        scene.boardFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the names of the Core's `qualityProfile` (`level-0` … `level-2`, the
    /// names of `MyceliumArchitectTier.all`), as many as the Core's `qualityTiers`.
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(MyceliumArchitectTier.of(tier).name) }
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
    private func follow(_ core: MyceliumArchitectExperienceCore) {
        if mirror.play != core.play || mirror.shownPulse != core.shownPulse {
            mirror.follow(core.play, shownPulse: core.shownPulse)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: MyceliumArchitectExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn: MyceliumArchitectTier = MyceliumArchitectTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason: String = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(MyceliumArchitectTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let snapshot: MyceliumArchitectSceneSnapshot = core.snapshot(time: time)
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the floor, the gauge,
    /// the pips and the actions bars (the camera fits the scene's box inside a 6 % margin per side), are `dark` (the
    /// cave backdrop) once a snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: MyceliumArchitectExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        let corners: [FrameProbe?] = [
            FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
            FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue),
        ]
        var probes: [FrameProbe] = []
        for corner in corners { if let corner { probes.append(corner) } }
        return probes
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: MyceliumArchitectExperienceCore) -> String {
        let play: MyceliumArchitectPlay = core.play
        let level: MyceliumArchitectLevel = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.tutorialText = level.tutorial ? Self.tutorial : nil
        let sites: Int = level.sites?.count ?? 0
        mirror.targetLabel = "Level: \(level.width) × \(level.height) cave, \(level.terminals.count) terminals, "
            + "\(level.rocks.count) rocks, \(level.toxins.count) toxins, \(sites) sites, up to \(level.maxNutrients) "
            + "nutrients, \(level.maxBlockers) blockers and \(level.maxSeeds) seeds, \(level.pulses) pulses, "
            + "\(level.budget) actions"
        let measure: String = level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text: String = "Mycelium Architect level \(core.levelNumber). "
        text += measure + ". "
        let won: Bool = play.stage == .won || (play.stage == .result && play.failure == nil)
        let failed: Bool = play.stage == .failed || play.stage == .result
        if won {
            text += "Every terminal was reached and opened."
            mirror.status = "Won"
            mirror.failureText = nil
        } else if failed {
            let reason: String = MyceliumArchitectMirror.failureText(play.failure, level: level) ?? "The run failed."
            text += reason
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        } else {
            var played: Bool = false
            for record in play.records where record.kind != .begin && record.kind != .dismissTutorial {
                played = true
            }
            mirror.status = played ? "Playing" : "Ready"
            mirror.failureText = nil
        }
        return text
    }

    /// The control panel.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MyceliumArchitectControls(port: port, mirror: mirror))
    }
}
#endif
