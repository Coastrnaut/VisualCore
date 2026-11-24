// VoxelOrigamiFeedbackPlan — feature 446 (R02-G15-06) T-R02G1506-003 (FR-R02G1506-001, 002, 003, 005;
// SC-R02G1506-001, 002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one
// change of Voxel Origami, as a pure function of the core before and after an accepted action (or of a refusal's reason
// code, or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes the plan
// through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never
// changes state. Modelled on feature 436's `MoonlitMechanismFeedbackPlan`.
//
// Words: hinges and cubes count from 0 as the level words them (`VoxelOrigamiLevel.hingeName(_:turn:)`, hinge 0 being
// the root, which never turns), actions from 1. The progress that follows every accepted turn, undo and redo is
// " c of n cubes in place, a actions left." — c the new play's cubes in place (`VoxelOrigamiShapeReport.covered`), n
// the level's cube count; "1 action left" for one.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one or more records (`level.next`, `level.select`, `mode.daily`, `mode.practice`,
//      `mode.campaign` open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      `VoxelOrigamiProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction while the tutorial is shown (not
//      done); no haptic;
//   2. accepted actions: the play gained one or more records (one per accepted action) →
//      a new end (the stage became won or failed; Q2: a turn that wins, collides, sweeps or spends the last of the
//      budget, or a redo that restores a failed moment, plans only the outcome):
//        won: `outcome`, "The chain matches the target. Level won spending a actions, k of 3 stars." (practice: "…
//             Level won spending a actions."), haptic `success`; a is `VoxelOrigamiProgress.actionsSpent(_:)` (undone
//             turns included; "1 action" for one) and k is `VoxelOrigamiProgress.stars(actionsSpent:certified:)` of
//             this win against the certified witness's turn count (`VoxelOrigamiExperienceCore.certifiedTurns`);
//        failed: `outcome`, the failure explanation of feature 445 (`VoxelOrigamiFailureExplanation`), haptic
//             `warning`;
//      otherwise, for one record by its kind: a turn "Turned hinge h forward a quarter turn." (step +1) or "Turned
//      hinge h back a quarter turn." (step −1); an undo or redo "Undone." or "Redone."; any run of several records
//      (a caller that plans several actions at once; one drag sends one turn) the progress alone; each followed by the
//      progress, each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`; or only the chosen hinge
//      changed: `hinge.choose`) → ``VoxelOrigamiFeedbackPlan/none``.
// Choosing a hinge, the pending drag texts and orbit are presentation only and plan nothing (the core's state does not
// change; the adjustable hinge speaks its own value). A revealed hint is `hint(text:)`: `state` with the hint's words
// and no haptic. Integers only.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Voxel Origami (feature 446, clarifications Q1, Q2).
/// Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct VoxelOrigamiFeedbackPlan: Sendable, Equatable {
    /// The text VoiceOver speaks, or nil when nothing is announced.
    public let text: String?
    /// The announcement kind, or nil when nothing is announced.
    public let kind: AnnouncementKind?
    /// The haptic to play, or nil for none.
    public let haptic: HapticKind?

    /// A plan of the given parts (not checked; the factory functions keep text and kind together).
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?) {
        self.text = text
        self.kind = kind
        self.haptic = haptic
    }

    /// No announcement and no haptic: nothing changed.
    public static let none = VoxelOrigamiFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "The chain matches the target."
    public static let wonText: String = "The chain matches the target."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<code>`).
    public static let rulePrefix: String = "action.rule."

    /// The plan for the change from `old` to `new` after one or more accepted actions (see the file header for the
    /// order of the cases and the exact texts). Reads only.
    public static func after(old: VoxelOrigamiExperienceCore,
                             new: VoxelOrigamiExperienceCore) -> VoxelOrigamiFeedbackPlan {
        let oldRecords: [VoxelOrigamiRecord] = old.play.records
        let newRecords: [VoxelOrigamiRecord] = new.play.records
        let extended: Bool = old.play.level == new.play.level
            && newRecords.count > oldRecords.count
            && Array(newRecords.prefix(oldRecords.count)) == oldRecords
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        if !sameLevel || (old.play != new.play && !extended) {
            return levelPlan(new)
        }
        if extended {
            return playPlan(old: old, new: new, added: Array(newRecords.dropFirst(oldRecords.count)))
        }
        if old.play == new.play && old.tutorial != new.tutorial
            && new.tutorial == VoxelOrigamiTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g15.locked", or as the engine reports it,
    /// "action.rule.r02-g15.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> VoxelOrigamiFeedbackPlan {
        VoxelOrigamiFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g15.locked`), "That date
    /// cannot be used." (`r02-g15.date`), "That hinge cannot turn: nothing would move." (`r02-g15.action`), "The level
    /// has ended." (`r02-g15.stage`), "That value must be a whole number." (`r02-g15.not-whole`), "This chain has no
    /// such hinge." (`r02-g15.hinge`); any other code (`r02-g15.stale`, `r02-g15.level`, `r02-g15.malformed`, the
    /// engine's own codes such as `action.out-of-range`) "That action was refused.".
    public static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch bare {
        case VoxelOrigamiExperienceRule.locked: return "That level is not open yet."
        case VoxelOrigamiExperienceRule.date: return "That date cannot be used."
        case VoxelOrigamiError.action("").reasonCode: return "That hinge cannot turn: nothing would move."
        case VoxelOrigamiError.stage.reasonCode: return "The level has ended."
        case VoxelOrigamiExperienceRule.notWhole: return "That value must be a whole number."
        case VoxelOrigamiExperienceRule.hinge: return "This chain has no such hinge."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> VoxelOrigamiFeedbackPlan {
        VoxelOrigamiFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. <the progress in words>. Chosen:
    /// <the hinge in words>. Level: <the level in words>."
    ///
    /// The progress is ``progressWords(_:)`` of the play (capitalised: "c of n cubes in place; the shape does not match
    /// yet" or "…; the shape matches the target"); the hinge is ``hingeWords(_:_:)`` of `hinge`; the level is
    /// ``levelWords(_:)``. "1 action left" for one. A pure function of the core and the chosen hinge.
    public static func summaryText(core: VoxelOrigamiExperienceCore, hinge: Int) -> String {
        let play: VoxelOrigamiPlay = core.play
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". " + capitalised(progressWords(play))
            + ". Chosen: " + hingeWords(play, hinge) + ". Level: " + levelWords(core) + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; c cubes, h hinges; <the orientation words>; a
    /// budget of B actions" ("1 action" for one), the orientation words being ``orientationWords(_:)`` of the level.
    public static func levelWords(_ core: VoxelOrigamiExperienceCore) -> String {
        let level: VoxelOrigamiLevel = core.play.level
        return "level \(core.levelNumber), band \(VoxelOrigamiProgress.band(of: core.levelNumber)), "
            + modeName(core.mode) + "; \(level.cubes.count) cubes, \(level.hingeCount) hinges; "
            + orientationWords(level.orientations) + "; a budget of " + actionsWords(level.budget)
    }

    /// The orientations a match allows, in words: "the target as placed" (`fixed`), "the target in any upright turn"
    /// (`upright`), "the target in any orientation" (`any`).
    public static func orientationWords(_ orientations: VoxelOrigamiOrientations) -> String {
        switch orientations {
        case .fixed: "the target as placed"
        case .upright: "the target in any upright turn"
        case .any: "the target in any orientation"
        }
    }

    /// The name of a mode in a level announcement: "campaign", "practice", "daily" or "replay".
    public static func modeName(_ mode: VoxelOrigamiMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// Hinge `index` of `play` in words at its current turn, as the level words it, then whether it can turn: ", can
    /// turn, swings cube k" (k the cube a drag on it follows, `VoxelOrigamiPicker.trackedCube`) or ", nothing would
    /// move"; "hinge i" for the root (hinge 0) or an index the level lacks.
    public static func hingeWords(_ play: VoxelOrigamiPlay, _ index: Int) -> String {
        let cubes: [VoxelOrigamiCube] = play.level.cubes
        guard index >= 1, index < cubes.count, index < play.turns.count else { return "hinge \(index)" }
        let name: String = play.level.hingeName(index, turn: play.turns[index])
        let moving: [Int] = VoxelOrigamiLattice.swinging(cubes, pose: play.pose, hinge: index)
        guard !moving.isEmpty else { return name + ", nothing would move" }
        let tracked: Int = VoxelOrigamiPicker.trackedCube(index, cubes: cubes, pose: play.pose, moving: moving)
        return name + ", can turn, swings cube \(tracked)"
    }

    /// The progress in words, without the actions: the level's own progress words
    /// (`VoxelOrigamiLevel.progressDescription(report:actionsLeft:)`, "c of n cubes in place; the shape does not match
    /// yet" or "…; the shape matches the target", with "; two cubes share a cell" should the pose ever overlap) without
    /// their closing actions left, which the summary says first.
    public static func progressWords(_ play: VoxelOrigamiPlay) -> String {
        let full: String = play.level.progressDescription(report: play.report, actionsLeft: play.actionsLeft)
        let suffix: String = "; " + actionsLeftWords(play.actionsLeft)
        return full.hasSuffix(suffix) ? String(full.dropLast(suffix.count)) : full
    }

    /// "a actions left" ("1 action left" for one).
    static func actionsLeftWords(_ count: Int) -> String {
        count == 1 ? "1 action left" : "\(count) actions left"
    }

    /// "a actions" ("1 action" for one).
    static func actionsWords(_ count: Int) -> String {
        count == 1 ? "1 action" : "\(count) actions"
    }

    /// The progress after an accepted action: "c of n cubes in place, a actions left."
    static func progress(_ play: VoxelOrigamiPlay) -> String {
        "\(play.report.covered) of \(play.level.cubes.count) cubes in place, " + actionsLeftWords(play.actionsLeft)
            + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: VoxelOrigamiExperienceCore) -> VoxelOrigamiFeedbackPlan {
        let band: Int = VoxelOrigamiProgress.band(of: core.levelNumber)
        var text: String = "Level \(core.levelNumber), band \(band), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return VoxelOrigamiFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars in campaign and daily;
    /// never in practice), haptic `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: VoxelOrigamiExperienceCore) -> VoxelOrigamiFeedbackPlan {
        let play: VoxelOrigamiPlay = core.play
        if play.stage == .won {
            let spent: Int = VoxelOrigamiProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = VoxelOrigamiProgress.stars(actionsSpent: spent, certified: core.certifiedTurns)
                text += ", \(stars) of 3 stars"
            }
            return VoxelOrigamiFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = VoxelOrigamiFailureExplanation(play: play)?.text ?? VoxelOrigamiFailureExplanation.advice
        return VoxelOrigamiFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The first sentence of one accepted `record`: "Turned hinge h forward a quarter turn." (or "back"), "Undone." or
    /// "Redone.".
    static func changeWords(record: VoxelOrigamiRecord) -> String {
        switch record.kind {
        case .undo: return "Undone."
        case .redo: return "Redone."
        case .turn: break
        }
        switch record.action {
        case .turn(let hinge, let step):
            return "Turned hinge \(hinge) " + (step > 0 ? "forward" : "back") + " a quarter turn."
        case nil:
            return ""
        }
    }

    /// The plan of the accepted records `added` that took `old` to `new`.
    static func playPlan(old: VoxelOrigamiExperienceCore, new: VoxelOrigamiExperienceCore,
                         added: [VoxelOrigamiRecord]) -> VoxelOrigamiFeedbackPlan {
        let play: VoxelOrigamiPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String = added.count == 1 ? changeWords(record: added[0]) : ""
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return VoxelOrigamiFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
