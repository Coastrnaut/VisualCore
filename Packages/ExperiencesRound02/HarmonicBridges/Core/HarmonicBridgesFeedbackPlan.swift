// HarmonicBridgesFeedbackPlan — feature 416 (R02-G12-06) T-R02G1206-003 (FR-R02G1206-001, 002, 003; SC-R02G1206-002;
// clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of Harmonic
// Bridges, as a pure function of the core before and after an accepted action (or of a refusal's reason code, or of a
// revealed hint's text), and the words of the panel's summary element. The presenter only routes the plan through the
// shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never changes state.
// Modelled on feature 406's EchoCartographerFeedbackPlan.
//
// Words: strings, steps and islands count from 0 as the level words them (`HarmonicBridgesLevel.stringName(_:peg:)`),
// actions from 1. The progress that follows every accepted tuning, undo and redo is " The start reaches the goal in k of
// n steps, a actions left." (k the steps whose goal the start reaches in the play's report, n the level's steps; "1
// action left" for one, as the level's own progress words say; "steps" always, as feature 415's failure explanation
// says).
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one record (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`
//      open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      `HarmonicBridgesProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction while the tutorial is shown
//      (not done); no haptic;
//   2. an accepted action: the play gained exactly one record →
//      a new end (the stage became won or failed; Q2: a test always ends the level and a tuning that spends the last
//      action without a win ends it too, so each plans only the outcome):
//        won: `outcome`, "The crossing holds in every step. Level won spending a actions, k of 3 stars." (practice:
//             "… Level won spending a actions."), haptic `success`; a is `HarmonicBridgesProgress.actionsSpent(_:)`
//             (undone actions included) and k is `HarmonicBridgesProgress.stars(actionsSpent:certified:)` of this win
//             against the certified witness's action count (the stars this win earned; the progress keeps the better
//             stored result);
//        failed: `outcome`, the failure explanation of feature 415 (`HarmonicBridgesFailureExplanation`), haptic
//             `warning`;
//      a tuning: "String i tuned to peg p."; an undo or redo: "Undone." or "Redone."; each followed by the progress,
//      each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``HarmonicBridgesFeedbackPlan/none``.
// Choosing a string, previewing a peg and orbit are presentation only and plan nothing (the core does not change; the
// adjustable string and peg speak their own values). A revealed hint is `hint(text:)`: `state` with the hint's words and
// no haptic. This file holds no floating-point value.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Harmonic Bridges (feature 416, clarifications Q1,
/// Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct HarmonicBridgesFeedbackPlan: Sendable, Equatable {
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
    public static let none = HarmonicBridgesFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "The crossing holds in every step."
    public static let wonText: String = "The crossing holds in every step."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<kernel code>`).
    public static let rulePrefix: String = "action.rule."

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: HarmonicBridgesExperienceCore,
                             new: HarmonicBridgesExperienceCore) -> HarmonicBridgesFeedbackPlan {
        let oldRecords: [HarmonicBridgesRecord] = old.play.records
        let newRecords: [HarmonicBridgesRecord] = new.play.records
        let extended: Bool = old.play.level == new.play.level
            && newRecords.count == oldRecords.count + 1
            && Array(newRecords.dropLast()) == oldRecords
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        if !sameLevel || (old.play != new.play && !extended) {
            return levelPlan(new)
        }
        if extended, let record = newRecords.last {
            return playPlan(old: old, new: new, record: record)
        }
        if old.play == new.play && old.tutorial != new.tutorial
            && new.tutorial == HarmonicBridgesTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g12.locked", or as the engine reports it,
    /// "action.rule.r02-g12.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> HarmonicBridgesFeedbackPlan {
        HarmonicBridgesFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g12.locked`), "That date
    /// cannot be used." (`r02-g12.date`), "That string cannot be tuned to that peg." (`r02-g12.action`), "That string is
    /// already at that peg." (`r02-g12.noop`), "The level has ended." (`r02-g12.stage`), "That value must be a whole
    /// number." (`r02-g12.not-whole`); any other code (`r02-g12.stale`, `r02-g12.level`, `r02-g12.malformed`, the
    /// engine's own codes such as `action.out-of-range`) "That action was refused.".
    public static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch bare {
        case HarmonicBridgesExperienceRule.locked: return "That level is not open yet."
        case HarmonicBridgesExperienceRule.date: return "That date cannot be used."
        case HarmonicBridgesError.action("").reasonCode: return "That string cannot be tuned to that peg."
        case HarmonicBridgesError.noop.reasonCode: return "That string is already at that peg."
        case HarmonicBridgesError.stage.reasonCode: return "The level has ended."
        case HarmonicBridgesExperienceRule.notWhole: return "That value must be a whole number."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> HarmonicBridgesFeedbackPlan {
        HarmonicBridgesFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. The start reaches the goal in k of
    /// n steps. Step s shows b bridges. Chosen: <the string in words>, tune to peg p. Level: <the level in words>."
    ///
    /// The step is the snapshot's resting step (`HarmonicBridgesSceneSnapshot.restingStep`: step 0, or the broken step
    /// after a broken test), which is also the step the snapshot shows at time 0; the summary is a pure function of the
    /// core and never follows the 1.2 s step cycle. "1 action left" and "1 bridge" for one. The string is
    /// `HarmonicBridgesLevel.stringName(_:peg:)` of `string` at its current peg (with ", locked"); a string the level
    /// lacks reads "string i". `peg` is the peg the panel would tune it to. The level is ``levelWords(_:)``.
    public static func summaryText(core: HarmonicBridgesExperienceCore, string: Int, peg: Int) -> String {
        let play: HarmonicBridgesPlay = core.play
        let snapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: 0)
        let step: Int = snapshot.restingStep
        var bridges: Int = 0
        if step < play.report.bridges.count {
            for bridge in play.report.bridges[step] where bridge { bridges += 1 }
        }
        let bridgeWords: String = bridges == 1 ? "1 bridge" : "\(bridges) bridges"
        var chosen: String = "string \(string)"
        if string >= 0 && string < play.level.strings.count && string < play.pegs.count {
            chosen = play.level.stringName(string, peg: play.pegs[string])
        }
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". The start reaches the goal in "
            + reachedWords(play) + ". Step \(step) shows " + bridgeWords + ". Chosen: " + chosen + ", tune to peg "
            + "\(peg). Level: " + levelWords(core) + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; i islands, start island s, goal island g; m
    /// strings; k steps; a budget of B actions" ("1 string", "1 step" for one).
    public static func levelWords(_ core: HarmonicBridgesExperienceCore) -> String {
        let level: HarmonicBridgesLevel = core.play.level
        let strings: String = level.strings.count == 1 ? "1 string" : "\(level.strings.count) strings"
        let steps: String = level.steps.count == 1 ? "1 step" : "\(level.steps.count) steps"
        return "level \(core.levelNumber), band \(HarmonicBridgesProgress.band(of: core.levelNumber)), "
            + modeName(core.mode) + "; \(level.islands.count) islands, start island \(level.start), goal island "
            + "\(level.goal); " + strings + "; " + steps + "; a budget of \(level.budget) actions"
    }

    /// The name of a mode in a level announcement: "campaign", "practice", "daily" or "replay".
    public static func modeName(_ mode: HarmonicBridgesMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// "k of n steps": the steps whose goal the start reaches in `play`'s report, of the level's steps.
    static func reachedWords(_ play: HarmonicBridgesPlay) -> String {
        var reached: Int = 0
        for stepReached in play.report.reached where play.level.goal < stepReached.count && stepReached[play.level.goal] {
            reached += 1
        }
        return "\(reached) of \(play.level.steps.count) steps"
    }

    /// "a actions left" ("1 action left" for one).
    static func actionsLeftWords(_ count: Int) -> String {
        count == 1 ? "1 action left" : "\(count) actions left"
    }

    /// "a actions" ("1 action" for one).
    static func actionsWords(_ count: Int) -> String {
        count == 1 ? "1 action" : "\(count) actions"
    }

    /// The progress after an accepted action: "The start reaches the goal in k of n steps, a actions left."
    static func progress(_ play: HarmonicBridgesPlay) -> String {
        "The start reaches the goal in " + reachedWords(play) + ", " + actionsLeftWords(play.actionsLeft) + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: HarmonicBridgesExperienceCore) -> HarmonicBridgesFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(HarmonicBridgesProgress.band(of: core.levelNumber)), "
            + "\(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return HarmonicBridgesFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars outside practice), haptic
    /// `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: HarmonicBridgesExperienceCore) -> HarmonicBridgesFeedbackPlan {
        let play: HarmonicBridgesPlay = core.play
        if play.stage == .won {
            let spent: Int = HarmonicBridgesProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = HarmonicBridgesProgress.stars(actionsSpent: spent, certified: core.certifiedActions)
                text += ", \(stars) of 3 stars"
            }
            return HarmonicBridgesFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = HarmonicBridgesFailureExplanation(play: play)?.text
            ?? HarmonicBridgesFailureExplanation.advice
        return HarmonicBridgesFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The plan of the accepted `record` that took `old` to `new`.
    static func playPlan(old: HarmonicBridgesExperienceCore, new: HarmonicBridgesExperienceCore,
                         record: HarmonicBridgesRecord) -> HarmonicBridgesFeedbackPlan {
        let play: HarmonicBridgesPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String
        switch record.kind {
        case .undo: first = "Undone."
        case .redo: first = "Redone."
        case .tune, .test:
            if case let .tune(string, peg)? = record.action {
                first = "String \(string) tuned to peg \(peg)."
            } else {
                first = ""
            }
        }
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return HarmonicBridgesFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
