// MicroscopicAuroraFeedbackPlan — feature 486 (R02-G19-06) T-R02G1906-003 (FR-R02G1906-001, 002, 003;
// SC-R02G1906-002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of
// Microscopic Aurora, as a pure function of the core before and after an accepted action (or of a refusal's reason
// code, or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes the
// plan through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never
// changes state. Modelled on feature 476's `ApsidesWorkshopFeedbackPlan`.
//
// Words: the level's own words (`MicroscopicAuroraLevel.wellDescription(_:well:)`: "well n at row r, column c,
// strength s, clockwise" or "counterclockwise", or "well n empty"; `cellWords(_:)`: "row r, column c"), wells counted
// from 1 (slot + 1). The progress that follows every accepted placement, removal, undo and redo is " l of S stencil
// cells lit, playing now would win, a actions left." ("… would fail" when the play's report fails) — l the new play's
// report's lit stencil cells, S the level's stencil cells; "1 action left" for one.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one or more records (`level.next`, `level.select`, `mode.daily`, `mode.practice`,
//      `mode.campaign` open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      `MicroscopicAuroraProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction while the tutorial is shown
//      (not done); no haptic;
//   2. accepted actions: the play gained one or more records (one per accepted action) →
//      a new end (the stage became won or failed; Q2: the play always ends the level and plans only its outcome, and
//      so does a redo that restores a won or failed moment):
//        won: `outcome`, "The trails covered the stencil as one pattern. Level won spending a actions, k of 3 stars."
//             (practice: "… Level won spending a actions."), haptic `success`; a is
//             `MicroscopicAuroraProgress.actionsSpent(_:)` (undone placements and removals included; "1 action" for
//             one) and k is `MicroscopicAuroraProgress.stars(actionsSpent:certified:)` of this win against the
//             certified plan's placement count (`MicroscopicAuroraExperienceCore.certifiedPlacements`);
//        failed: `outcome`, the failure explanation of feature 485
//             (`MicroscopicAuroraFailureExplanation(play:)?.text`), haptic `warning`;
//      otherwise, for one record by its kind: a placement "Well n placed at row r, column c, strength s, clockwise."
//      (or "counterclockwise"; the record's slot and well), a removal "Well n removed.", an undo or redo "Undone." or
//      "Redone."; any run of several records the progress alone; each followed by the progress, each `state` with
//      haptic `selection` (an undo out of a failed play returns the play to playing and is a `state`);
//   3. the same untouched play (no placement, removal, play, undo or redo recorded) reopened with its tutorial shown
//      again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`; or only the shown tick changed:
//      `clock.show`) → ``MicroscopicAuroraFeedbackPlan/none``.
// The panel's selection, drag previews, the shown tick, the freeze and the view are presentation only and plan nothing
// (the core's state does not change; the adjustable elements speak their own values). A revealed hint is
// `hint(text:)`: `state` with the hint's words and no haptic. Integers only.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Microscopic Aurora (feature 486, clarifications
/// Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct MicroscopicAuroraFeedbackPlan: Sendable, Equatable {
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
    public static let none = MicroscopicAuroraFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "The trails covered the stencil as one pattern."
    public static let wonText: String = "The trails covered the stencil as one pattern."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<code>`).
    public static let rulePrefix: String = "action.rule."

    /// The plan for the change from `old` to `new` after one or more accepted actions (see the file header for the
    /// order of the cases and the exact texts). Reads only.
    public static func after(old: MicroscopicAuroraExperienceCore,
                             new: MicroscopicAuroraExperienceCore) -> MicroscopicAuroraFeedbackPlan {
        let oldRecords: [MicroscopicAuroraRecord] = old.play.records
        let newRecords: [MicroscopicAuroraRecord] = new.play.records
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
            && new.tutorial == MicroscopicAuroraTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && !hasPlayerRecords(new.play) {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g19.locked", or as the engine reports it,
    /// "action.rule.r02-g19.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> MicroscopicAuroraFeedbackPlan {
        MicroscopicAuroraFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g19.locked`), "That date
    /// cannot be used." (`r02-g19.date`), "That well cannot be placed there, or there is nothing to remove, undo or
    /// redo." (`r02-g19.action`), "No actions are left: undo or retry." (`r02-g19.budget`), "The level has ended."
    /// (`r02-g19.stage`), "The play changed before the action arrived." (`r02-g19.stale`), "That level could not be
    /// made." (`r02-g19.level`), "That value must be a whole number." (`r02-g19.not-whole`), "That tick is outside the
    /// swim." (`r02-g19.tick`); any other code (the kernel's `r02-g19.malformed`, the engine's own codes such as
    /// `action.out-of-range`) "That action was refused."; since feature 487 "There is no saved solution to replay for
    /// this level." (`r02-g19.no-replay`), "The replay is over." (`r02-g19.replay-end`) and "Stop the replay first."
    /// (`r02-g19.replay`).
    public static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch bare {
        case MicroscopicAuroraExperienceRule.locked: return "That level is not open yet."
        case MicroscopicAuroraExperienceRule.date: return "That date cannot be used."
        case MicroscopicAuroraError.action("").reasonCode:
            return "That well cannot be placed there, or there is nothing to remove, undo or redo."
        case MicroscopicAuroraError.budget.reasonCode: return "No actions are left: undo or retry."
        case MicroscopicAuroraError.stage.reasonCode: return "The level has ended."
        case MicroscopicAuroraError.stale.reasonCode: return "The play changed before the action arrived."
        case MicroscopicAuroraError.level("").reasonCode: return "That level could not be made."
        case MicroscopicAuroraExperienceRule.notWhole: return "That value must be a whole number."
        case MicroscopicAuroraExperienceRule.tick: return "That tick is outside the swim."
        // Feature 487: the replay refusals.
        case MicroscopicAuroraExperienceRule.noReplay: return "There is no saved solution to replay for this level."
        case MicroscopicAuroraExperienceRule.replayEnd: return "The replay is over."
        case MicroscopicAuroraExperienceRule.replay: return "Stop the replay first."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> MicroscopicAuroraFeedbackPlan {
        MicroscopicAuroraFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. <the progress in words>.
    /// Selected: well n at row r, column c, strength s, <sense>. Level: <the level in words>."
    ///
    /// The progress is ``progressWords(_:)`` of the play (capitalised: "Well 1 at …; well 2 empty; …; stencil l of S
    /// cells lit, x.x %, needs y.y %; playing now would win (or fail: <reason>)"); the selected well is `selected` in
    /// slot `slot` in the level's words (`wellDescription(_:well:)`), or "well n, no site" when `selected` is nil (the
    /// level has no site the panel can select); the level is ``levelWords(_:)``. "1 action left" for one. A pure
    /// function of the core, the selection and the slot.
    public static func summaryText(core: MicroscopicAuroraExperienceCore, selected: MicroscopicAuroraWell?,
                                   slot: Int) -> String {
        let play: MicroscopicAuroraPlay = core.play
        let selection: String
        if let selected {
            selection = play.level.wellDescription(slot, well: selected)
        } else {
            selection = "well \(slot + 1), no site"
        }
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". " + capitalised(progressWords(play))
            + ". Selected: " + selection + ". Level: " + levelWords(core) + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; a stencil of S cells, N to light as one pattern,
    /// k swimmers, a swim of T ticks, p sites; a budget of B actions" (N = `MicroscopicAuroraDish.neededCells`; "1
    /// cell", "1 swimmer", "1 site", "no sites", "1 action" for one or none).
    public static func levelWords(_ core: MicroscopicAuroraExperienceCore) -> String {
        let level: MicroscopicAuroraLevel = core.play.level
        let needed: Int = MicroscopicAuroraDish.neededCells(stencil: level.stencil.count, required: level.coverage)
        let siteCount: Int = level.sites?.count ?? 0
        let sites: String
        switch siteCount {
        case 0: sites = "no sites"
        case 1: sites = "1 site"
        default: sites = "\(siteCount) sites"
        }
        return "level \(core.levelNumber), band \(MicroscopicAuroraProgress.band(of: core.levelNumber)), "
            + modeName(core.mode) + "; a stencil of " + counted(level.stencil.count, "cell") + ", \(needed) to light "
            + "as one pattern, " + counted(level.swimmers.count, "swimmer") + ", a swim of "
            + counted(level.length, "tick") + ", " + sites + "; a budget of " + actionsWords(level.budget)
    }

    /// The name of a mode in a level announcement: "campaign", "practice", "daily" or "replay" (feature 487).
    public static func modeName(_ mode: MicroscopicAuroraMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// The progress in words, without the actions: the level's own progress words
    /// (`MicroscopicAuroraLevel.progressDescription(report:wells:actionsLeft:)`, "<the wells>; <the coverage>; playing
    /// now would win (or fail: <reason>); a actions left") without their closing actions left, which the summary says
    /// first.
    public static func progressWords(_ play: MicroscopicAuroraPlay) -> String {
        var words: String = play.level.progressDescription(report: play.report, wells: play.wells,
                                                           actionsLeft: play.actionsLeft)
        let suffix: String = "; " + actionsLeftWords(play.actionsLeft)
        if words.hasSuffix(suffix) { words = String(words.dropLast(suffix.count)) }
        return words
    }

    /// "n <noun>s" ("1 <noun>" for one).
    static func counted(_ count: Int, _ noun: String) -> String {
        count == 1 ? "1 " + noun : "\(count) " + noun + "s"
    }

    /// "a actions left" ("1 action left" for one).
    static func actionsLeftWords(_ count: Int) -> String {
        count == 1 ? "1 action left" : "\(count) actions left"
    }

    /// "a actions" ("1 action" for one).
    static func actionsWords(_ count: Int) -> String {
        count == 1 ? "1 action" : "\(count) actions"
    }

    /// The progress after an accepted action: "l of S stencil cells lit, playing now would win, a actions left."
    /// ("… would fail" when the play's report fails).
    static func progress(_ play: MicroscopicAuroraPlay) -> String {
        let verdict: String = play.report.wins ? "playing now would win" : "playing now would fail"
        return "\(play.report.litStencil.count) of \(play.level.stencil.count) stencil cells lit, " + verdict + ", "
            + actionsLeftWords(play.actionsLeft) + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Whether `play` recorded a placement, a removal, a play, an undo or a redo (not only its opening events).
    static func hasPlayerRecords(_ play: MicroscopicAuroraPlay) -> Bool {
        for record in play.records {
            switch record.kind {
            case .place, .remove, .play, .undo, .redo: return true
            case .begin, .dismissTutorial, .pause, .resume: continue
            }
        }
        return false
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: MicroscopicAuroraExperienceCore) -> MicroscopicAuroraFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(core.band), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return MicroscopicAuroraFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars in campaign and daily,
    /// never in practice or replay, feature 487), haptic `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: MicroscopicAuroraExperienceCore) -> MicroscopicAuroraFeedbackPlan {
        let play: MicroscopicAuroraPlay = core.play
        if play.stage == .won {
            let spent: Int = MicroscopicAuroraProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = MicroscopicAuroraProgress.stars(actionsSpent: spent,
                                                                 certified: core.certifiedPlacements)
                text += ", \(stars) of 3 stars"
            }
            return MicroscopicAuroraFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = MicroscopicAuroraFailureExplanation(play: play)?.text
            ?? MicroscopicAuroraFailureExplanation.advice
        return MicroscopicAuroraFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The first sentence of one accepted `record`: "Well n placed at row r, column c, strength s, clockwise." (or
    /// "counterclockwise"; the record's placement), "Well n removed." (its removal), "Undone." or "Redone."; empty
    /// for any other kind.
    static func changeWords(record: MicroscopicAuroraRecord) -> String {
        switch record.kind {
        case .undo: return "Undone."
        case .redo: return "Redone."
        case .place:
            guard case .place(let slot, let well)? = record.action else { return "" }
            return "Well \(slot + 1) placed at " + MicroscopicAuroraLevel.cellWords(well.cell)
                + ", strength \(well.strength), " + well.sense.rawValue + "."
        case .remove:
            guard case .remove(let slot)? = record.action else { return "" }
            return "Well \(slot + 1) removed."
        case .play, .begin, .dismissTutorial, .pause, .resume: return ""
        }
    }

    /// The plan of the accepted records `added` that took `old` to `new`.
    static func playPlan(old: MicroscopicAuroraExperienceCore, new: MicroscopicAuroraExperienceCore,
                         added: [MicroscopicAuroraRecord]) -> MicroscopicAuroraFeedbackPlan {
        let play: MicroscopicAuroraPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String = added.count == 1 ? changeWords(record: added[0]) : ""
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return MicroscopicAuroraFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
