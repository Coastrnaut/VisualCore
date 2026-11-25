// StarlitCartoucheFeedbackPlan — feature 456 (R02-G16-06) T-R02G1606-003 (FR-R02G1606-001, 002, 003, 005;
// SC-R02G1606-001, 002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one
// change of Starlit Cartouche, as a pure function of the core before and after an accepted action (or of a refusal's
// reason code, or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes
// the plan through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan
// never changes state. Modelled on feature 446's `VoxelOrigamiFeedbackPlan`.
// Feature 457 (R02-G16-07): the mode `replay` is named "replay"; a replay step is a leg record, announced like the leg
// it applies; a replayed win claims no stars (replay awards none); the three replay refusals have their own words.
//
// Words: stars and corridors as the level words them (`StarlitCartoucheLevel.starName(_:)`, "star j";
// `corridorName(_:)`, "the corridor between star a and star b"), actions from 1. The progress that follows every
// accepted leg, undo and redo is " d of n strokes drawn, a actions left." — d the symbol's strokes drawn in the new
// play's route report (the symbol's count minus its missing strokes), n the symbol's stroke count; "1 action left" for
// one.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one or more records (`level.next`, `level.select`, `mode.daily`, `mode.practice`,
//      `mode.campaign` open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      `StarlitCartoucheProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction while the tutorial is shown
//      (not done); no haptic;
//   2. accepted actions: the play gained one or more records (one per accepted action) →
//      a new end (the stage became won or failed; Q2: a leg that wins, fails a leg check or spends the last of the
//      budget, or a redo that restores a won or failed moment, plans only the outcome):
//        won: `outcome`, "The trail draws the symbol at the beacon. Level won spending a actions, k of 3 stars."
//             (practice: "… Level won spending a actions."), haptic `success`; a is
//             `StarlitCartoucheProgress.actionsSpent(_:)` (undone legs included; "1 action" for one) and k is
//             `StarlitCartoucheProgress.stars(actionsSpent:certified:)` of this win against the certified witness's
//             leg count (`StarlitCartoucheExperienceCore.certifiedLegs`);
//        failed: `outcome`, the failure explanation of feature 455 (`StarlitCartoucheFailureExplanation(play:)?.text`),
//             haptic `warning`;
//      otherwise, for one record by its kind: a leg "Flew to star j after w beats along the corridor between star a
//      and star b." ("1 beat" singular; the new play's last leg); an undo or redo "Undone." or "Redone."; any run of
//      several records the progress alone; each followed by the progress, each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`; or only the chosen destination
//      or wait changed: `route.choose`) → ``StarlitCartoucheFeedbackPlan/none``.
// Choosing a destination or wait, the pending drag texts, the slider and orbit are presentation only and plan nothing
// (the core's state does not change; the adjustable elements speak their own values). A revealed hint is
// `hint(text:)`: `state` with the hint's words and no haptic. Integers only.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Starlit Cartouche (feature 456, clarifications
/// Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct StarlitCartoucheFeedbackPlan: Sendable, Equatable {
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
    public static let none = StarlitCartoucheFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "The trail draws the symbol at the beacon."
    public static let wonText: String = "The trail draws the symbol at the beacon."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<code>`).
    public static let rulePrefix: String = "action.rule."

    /// The plan for the change from `old` to `new` after one or more accepted actions (see the file header for the
    /// order of the cases and the exact texts). Reads only.
    public static func after(old: StarlitCartoucheExperienceCore,
                             new: StarlitCartoucheExperienceCore) -> StarlitCartoucheFeedbackPlan {
        let oldRecords: [StarlitCartoucheRecord] = old.play.records
        let newRecords: [StarlitCartoucheRecord] = new.play.records
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
            && new.tutorial == StarlitCartoucheTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g16.locked", or as the engine reports it,
    /// "action.rule.r02-g16.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> StarlitCartoucheFeedbackPlan {
        StarlitCartoucheFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g16.locked`), "That date
    /// cannot be used." (`r02-g16.date`), "No corridor can be flown there now." (`r02-g16.action`), "The level has
    /// ended." (`r02-g16.stage`), "That value must be a whole number." (`r02-g16.not-whole`), "That destination or
    /// wait cannot be chosen." (`r02-g16.choice`), "There is no saved solution to replay for this level."
    /// (`r02-g16.no-replay`), "The replay is over." (`r02-g16.replay-end`), "Stop the replay first." (`r02-g16.replay`,
    /// feature 457); any other code (`r02-g16.stale`, `r02-g16.level`, the engine's own
    /// codes such as `action.out-of-range`) "That action was refused.".
    public static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch bare {
        case StarlitCartoucheExperienceRule.locked: return "That level is not open yet."
        case StarlitCartoucheExperienceRule.date: return "That date cannot be used."
        case StarlitCartoucheError.action("").reasonCode: return "No corridor can be flown there now."
        case StarlitCartoucheError.stage.reasonCode: return "The level has ended."
        case StarlitCartoucheExperienceRule.notWhole: return "That value must be a whole number."
        case StarlitCartoucheExperienceRule.choice: return "That destination or wait cannot be chosen."
        // Feature 457: the replay refusals.
        case StarlitCartoucheExperienceRule.noReplay: return "There is no saved solution to replay for this level."
        case StarlitCartoucheExperienceRule.replayEnd: return "The replay is over."
        case StarlitCartoucheExperienceRule.replay: return "Stop the replay first."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> StarlitCartoucheFeedbackPlan {
        StarlitCartoucheFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. <the progress in words>. Chosen:
    /// <the leg in words>. Level: <the level in words>."
    ///
    /// The progress is ``progressWords(_:)`` of the play (capitalised: "At star j, beat t; d of n strokes drawn; …;
    /// b beats to the deadline"); the leg is ``legWords(_:destination:wait:)`` of `destination` and `wait`; the level
    /// is ``levelWords(_:)``. "1 action left" for one. A pure function of the core and the chosen leg.
    public static func summaryText(core: StarlitCartoucheExperienceCore, destination: Int, wait: Int) -> String {
        let play: StarlitCartouchePlay = core.play
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". " + capitalised(progressWords(play))
            + ". Chosen: " + legWords(play, destination: destination, wait: wait) + ". Level: " + levelWords(core)
            + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; draw the symbol of s strokes across t stars and
    /// reach star k by beat d; a budget of B actions" ("1 stroke", "1 action" for one), k the beacon and d the
    /// deadline.
    public static func levelWords(_ core: StarlitCartoucheExperienceCore) -> String {
        let level: StarlitCartoucheLevel = core.play.level
        let strokes: String = level.symbol.count == 1 ? "1 stroke" : "\(level.symbol.count) strokes"
        return "level \(core.levelNumber), band \(StarlitCartoucheProgress.band(of: core.levelNumber)), "
            + modeName(core.mode) + "; draw the symbol of " + strokes + " across \(level.stars.count) stars and reach "
            + level.starName(level.beacon) + " by beat \(level.deadline); a budget of " + actionsWords(level.budget)
    }

    /// The name of a mode in a level announcement: "campaign", "practice", "daily" or "replay" (feature 457).
    public static func modeName(_ mode: StarlitCartoucheMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// The leg to `destination` after `wait` beats from `play`'s star, as the panel words it: "star j along the
    /// corridor between star a and star b, wait w beats", or "star j: no corridor from star i, wait w beats" when no
    /// corridor joins the ship's star i to star j ("1 beat" singular).
    public static func legWords(_ play: StarlitCartouchePlay, destination: Int, wait: Int) -> String {
        let level: StarlitCartoucheLevel = play.level
        let beats: String = StarlitCartoucheHint.beatsText(wait)
        guard let corridor = StarlitCartoucheChart.corridor(level, joining: play.star, destination) else {
            return level.starName(destination) + ": no corridor from " + level.starName(play.star) + ", wait " + beats
        }
        return level.starName(destination) + " along " + level.corridorName(corridor) + ", wait " + beats
    }

    /// The progress in words, without the actions: the level's own progress words
    /// (`StarlitCartoucheLevel.progressDescription(report:actionsLeft:)`, "at star j, beat t; d of n strokes drawn;
    /// …; b beats to the deadline") without their closing actions left, which the summary says first.
    public static func progressWords(_ play: StarlitCartouchePlay) -> String {
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

    /// The progress after an accepted action: "d of n strokes drawn, a actions left."
    static func progress(_ play: StarlitCartouchePlay) -> String {
        let total: Int = play.level.symbol.count
        let drawn: Int = total - play.report.missing.count
        return "\(drawn) of \(total) strokes drawn, " + actionsLeftWords(play.actionsLeft) + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: StarlitCartoucheExperienceCore) -> StarlitCartoucheFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(core.band), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return StarlitCartoucheFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars in campaign and daily;
    /// never in practice or replay, feature 457), haptic `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: StarlitCartoucheExperienceCore) -> StarlitCartoucheFeedbackPlan {
        let play: StarlitCartouchePlay = core.play
        if play.stage == .won {
            let spent: Int = StarlitCartoucheProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = StarlitCartoucheProgress.stars(actionsSpent: spent, certified: core.certifiedLegs)
                text += ", \(stars) of 3 stars"
            }
            return StarlitCartoucheFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = StarlitCartoucheFailureExplanation(play: play)?.text
            ?? StarlitCartoucheFailureExplanation.advice
        return StarlitCartoucheFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The first sentence of one accepted `record` of `play`: "Flew to star j after w beats along the corridor
    /// between star a and star b." (the play's last leg), "Undone." or "Redone.".
    static func changeWords(record: StarlitCartoucheRecord, play: StarlitCartouchePlay) -> String {
        switch record.kind {
        case .undo: return "Undone."
        case .redo: return "Redone."
        case .leg: break
        }
        guard let leg = play.legs.last else { return "" }
        return "Flew to " + play.level.starName(leg.to) + " after " + StarlitCartoucheHint.beatsText(leg.wait)
            + " along " + play.level.corridorName(leg.corridor) + "."
    }

    /// The plan of the accepted records `added` that took `old` to `new`.
    static func playPlan(old: StarlitCartoucheExperienceCore, new: StarlitCartoucheExperienceCore,
                         added: [StarlitCartoucheRecord]) -> StarlitCartoucheFeedbackPlan {
        let play: StarlitCartouchePlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String = added.count == 1 ? changeWords(record: added[0], play: play) : ""
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return StarlitCartoucheFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
