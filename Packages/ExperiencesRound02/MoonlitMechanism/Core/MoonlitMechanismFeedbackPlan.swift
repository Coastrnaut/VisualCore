// MoonlitMechanismFeedbackPlan — feature 436 (R02-G14-06) T-R02G1406-003 (FR-R02G1406-001, 002, 003, 005;
// SC-R02G1406-001, 002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one
// change of Moonlit Mechanism, as a pure function of the core before and after an accepted action (or of a refusal's
// reason code, or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes
// the plan through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan
// never changes state. Modelled on feature 426's AcousticConstellatorFeedbackPlan.
//
// Words: gears, key frames and lamp heights count from 0 as the level words them
// (`MoonlitMechanismLevel.gearName(_:phase:)`, `lampName(_:)`), actions from 1. The progress that follows every
// accepted turn, re-seat, lamp step, undo and redo is " c of t required target cells covered, a actions left." — c the
// covered cells summed over the required key frames of the new play's run report
// (`MoonlitMechanismFrameReport.covered`), t the sum of their targets (covered + missing); "1 action left" for one — or
// " Every required key frame is covered, a actions left." when no required key frame misses a cell and every mesh is
// aligned (`MoonlitMechanismRunReport.aligned`).
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one or more records (`level.next`, `level.select`, `mode.daily`, `mode.practice`,
//      `mode.campaign` open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      `MoonlitMechanismProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction while the tutorial is shown
//      (not done); no haptic;
//   2. accepted actions: the play gained one or more records (one per accepted action; a gear drag sends several turns
//      and is planned once, from the core before the first turn to the core after the last) →
//      a new end (the stage became won or failed; Q2: a run always ends the level and a turn, re-seat or lamp step that
//      spends the last of the budget without a win ends it too, so each plans only the outcome):
//        won: `outcome`, "The shadows match. Level won spending a actions, k of 3 stars." (practice: "… Level won
//             spending a actions."), haptic `success`; a is `MoonlitMechanismProgress.actionsSpent(_:)` (undone actions
//             included) and k is `MoonlitMechanismProgress.stars(actionsSpent:certified:)` of this win against the
//             certified witness's action count;
//        failed: `outcome`, the failure explanation of feature 435 (`MoonlitMechanismFailureExplanation`), haptic
//             `warning`;
//      otherwise, for one record by its kind: a turn "Turned the handle forward one tooth." (step +1) or "Turned the
//      handle back one tooth." (step −1); a re-seat "Gear g re-seated to phase p." (p the gear's new phase); a lamp
//      step "Lamp raised to height h of L." or "Lamp lowered to height h of L." (h the new height, L the level's
//      heights); an undo or redo "Undone." or "Redone."; for n ≥ 2 records that are all turns of one step "Turned the
//      handle forward n teeth." (or "back"); any other run of several records the progress alone; each followed by the
//      progress, each `state` with haptic `selection` (one for a whole drag);
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the shown key frame or the tutorial step moved: `frame.show`,
//      `tutorial.dismiss`) → ``MoonlitMechanismFeedbackPlan/none``.
// Choosing a gear, showing a key frame, the pending drag texts and orbit are presentation only and plan nothing (the
// core's state does not change; the adjustable gear and key frame speak their own values). A revealed hint is
// `hint(text:)`: `state` with the hint's words and no haptic. Integers only.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Moonlit Mechanism (feature 436, clarifications Q1,
/// Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct MoonlitMechanismFeedbackPlan: Sendable, Equatable {
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
    public static let none = MoonlitMechanismFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "The shadows match."
    public static let wonText: String = "The shadows match."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<code>`).
    public static let rulePrefix: String = "action.rule."

    /// The plan for the change from `old` to `new` after one or more accepted actions (see the file header for the
    /// order of the cases and the exact texts). Reads only.
    public static func after(old: MoonlitMechanismExperienceCore,
                             new: MoonlitMechanismExperienceCore) -> MoonlitMechanismFeedbackPlan {
        let oldRecords: [MoonlitMechanismRecord] = old.play.records
        let newRecords: [MoonlitMechanismRecord] = new.play.records
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
            && new.tutorial == MoonlitMechanismTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g14.locked", or as the engine reports it,
    /// "action.rule.r02-g14.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> MoonlitMechanismFeedbackPlan {
        MoonlitMechanismFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g14.locked`), "That date
    /// cannot be used." (`r02-g14.date`), "That change is not allowed for this machine." (`r02-g14.action`), "The level
    /// has ended." (`r02-g14.stage`), "That value must be a whole number." (`r02-g14.not-whole`), "This level has no
    /// such key frame." (`r02-g14.frame`); any other code (`r02-g14.stale`, `r02-g14.level`, `r02-g14.malformed`, the
    /// engine's own codes such as `action.out-of-range`) "That action was refused.".
    public static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch bare {
        case MoonlitMechanismExperienceRule.locked: return "That level is not open yet."
        case MoonlitMechanismExperienceRule.date: return "That date cannot be used."
        case MoonlitMechanismError.action("").reasonCode: return "That change is not allowed for this machine."
        case MoonlitMechanismError.stage.reasonCode: return "The level has ended."
        case MoonlitMechanismExperienceRule.notWhole: return "That value must be a whole number."
        case MoonlitMechanismExperienceRule.frame: return "This level has no such key frame."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> MoonlitMechanismFeedbackPlan {
        MoonlitMechanismFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. <the progress in words>. Lamp
    /// height h of L. Showing key frame k. Chosen: <the gear in words>. Level: <the level in words>."
    ///
    /// The progress is ``progressWords(_:)`` of the play (capitalised: "c of t required target cells covered" or
    /// "Every required key frame is covered"); the lamp is `MoonlitMechanismLevel.lampName(_:)` of the play's height;
    /// the key frame is the core's shown key frame (`shownFrame`, presentation state the core holds); the gear is
    /// ``gearWords(_:_:)`` of `gear`; the level is ``levelWords(_:)``. "1 action left" for one. A pure function of the
    /// core and the chosen gear.
    public static func summaryText(core: MoonlitMechanismExperienceCore, gear: Int) -> String {
        let play: MoonlitMechanismPlay = core.play
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". " + capitalised(progressWords(play)) + ". "
            + capitalised(play.level.lampName(play.height)) + ". Showing key frame \(core.shownFrame). Chosen: "
            + gearWords(play, gear) + ". Level: " + levelWords(core) + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; g gears, f key frames, r required; L lamp heights;
    /// x forbidden cells; a stray allowance of s; a budget of B actions" ("1 required", "1 forbidden cell", "1 action"
    /// for one).
    public static func levelWords(_ core: MoonlitMechanismExperienceCore) -> String {
        let level: MoonlitMechanismLevel = core.play.level
        var required: Int = 0
        for frame in level.keyFrames where frame.required { required += 1 }
        let count: Int = level.forbidden.count
        let forbidden: String = count == 1 ? "1 forbidden cell" : "\(count) forbidden cells"
        return "level \(core.levelNumber), band \(MoonlitMechanismProgress.band(of: core.levelNumber)), "
            + modeName(core.mode) + "; \(level.gears.count) gears, \(level.keyFrames.count) key frames, "
            + "\(required) required; \(level.lampHeights) lamp heights; " + forbidden
            + "; a stray allowance of \(level.allowance); a budget of " + actionsWords(level.budget)
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily".
    public static func modeName(_ mode: MoonlitMechanismMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// Gear `index` of `play` in words at its current phase, as the level words it, then its mesh: ", aligned" or ",
    /// n teeth off" ("1 tooth off") for a child gear (`MoonlitMechanismRunReport.errors`), nothing more for the driver;
    /// "gear i" for an index the level lacks.
    public static func gearWords(_ play: MoonlitMechanismPlay, _ index: Int) -> String {
        guard index >= 0, index < play.level.gears.count, index < play.phases.count else { return "gear \(index)" }
        let name: String = play.level.gearName(index, phase: play.phases[index])
        guard index > 0 else { return name }
        let error: Int = index < play.report.errors.count ? play.report.errors[index] : 0
        if error == 0 { return name + ", aligned" }
        return name + (error == 1 ? ", 1 tooth off" : ", \(error) teeth off")
    }

    /// The progress in words, without the actions: "c of t required target cells covered" (summed over the required
    /// key frames of `play`'s run report) or "every required key frame is covered" when no required key frame misses a
    /// cell and every mesh is aligned.
    public static func progressWords(_ play: MoonlitMechanismPlay) -> String {
        let report: MoonlitMechanismRunReport = play.report
        var covered: Int = 0
        var total: Int = 0
        var missing: Int = 0
        for index in report.frames.indices where index < play.level.keyFrames.count
            && play.level.keyFrames[index].required {
            let frame: MoonlitMechanismFrameReport = report.frames[index]
            covered += frame.covered
            total += frame.covered + frame.missing
            missing += frame.missing
        }
        if missing == 0 && report.aligned { return "every required key frame is covered" }
        return "\(covered) of \(total) required target cells covered"
    }

    /// "a actions left" ("1 action left" for one).
    static func actionsLeftWords(_ count: Int) -> String {
        count == 1 ? "1 action left" : "\(count) actions left"
    }

    /// "a actions" ("1 action" for one).
    static func actionsWords(_ count: Int) -> String {
        count == 1 ? "1 action" : "\(count) actions"
    }

    /// The progress after an accepted action: "c of t required target cells covered, a actions left." or "Every
    /// required key frame is covered, a actions left."
    static func progress(_ play: MoonlitMechanismPlay) -> String {
        capitalised(progressWords(play)) + ", " + actionsLeftWords(play.actionsLeft) + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: MoonlitMechanismExperienceCore) -> MoonlitMechanismFeedbackPlan {
        let band: Int = MoonlitMechanismProgress.band(of: core.levelNumber)
        var text: String = "Level \(core.levelNumber), band \(band), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return MoonlitMechanismFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars in campaign and daily;
    /// never in practice), haptic `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: MoonlitMechanismExperienceCore) -> MoonlitMechanismFeedbackPlan {
        let play: MoonlitMechanismPlay = core.play
        if play.stage == .won {
            let spent: Int = MoonlitMechanismProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = MoonlitMechanismProgress.stars(actionsSpent: spent, certified: core.certifiedActions)
                text += ", \(stars) of 3 stars"
            }
            return MoonlitMechanismFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = MoonlitMechanismFailureExplanation(play: play)?.text
            ?? MoonlitMechanismFailureExplanation.advice
        return MoonlitMechanismFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// "forward" for a positive step, "back" otherwise.
    static func direction(_ step: Int) -> String { step > 0 ? "forward" : "back" }

    /// The first sentence of one accepted `record` that took `old` to `new` (not a run, which always ends the level).
    static func changeWords(record: MoonlitMechanismRecord, old: MoonlitMechanismPlay,
                            new: MoonlitMechanismPlay) -> String {
        switch record.kind {
        case .undo: return "Undone."
        case .redo: return "Redone."
        case .turn, .reseat, .lamp, .run: break
        }
        switch record.action {
        case .turn(let step):
            return "Turned the handle " + direction(step) + " one tooth."
        case .reseat(let gear, _):
            guard gear >= 0, gear < new.phases.count else { return "" }
            return "Gear \(gear) re-seated to phase \(new.phases[gear])."
        case .lamp:
            let verb: String = new.height > old.height ? "raised" : "lowered"
            return "Lamp " + verb + " to height \(new.height) of \(new.level.lampHeights)."
        case .run, nil:
            return ""
        }
    }

    /// The step shared by every record of `records` when all of them are turns of one step; nil otherwise.
    static func uniformTurnStep(_ records: [MoonlitMechanismRecord]) -> Int? {
        guard case .turn(let step)? = records.first?.action else { return nil }
        for record in records {
            guard record.kind == .turn, record.action == .turn(step) else { return nil }
        }
        return step
    }

    /// The plan of the accepted records `added` that took `old` to `new` (one action, or a gear drag's turns).
    static func playPlan(old: MoonlitMechanismExperienceCore, new: MoonlitMechanismExperienceCore,
                         added: [MoonlitMechanismRecord]) -> MoonlitMechanismFeedbackPlan {
        let play: MoonlitMechanismPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String
        if added.count == 1, let record = added.first {
            first = changeWords(record: record, old: old.play, new: play)
        } else if let step = uniformTurnStep(added) {
            first = "Turned the handle " + direction(step) + " \(added.count) teeth."
        } else {
            first = ""
        }
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return MoonlitMechanismFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
