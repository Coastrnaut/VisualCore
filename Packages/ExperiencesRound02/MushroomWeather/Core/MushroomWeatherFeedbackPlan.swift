// MushroomWeatherFeedbackPlan — feature 496 (R02-G20-06) T-R02G2006-003 (FR-R02G2006-001, 002, 003;
// SC-R02G2006-002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of
// Mushroom Weather, as a pure function of the core before and after an accepted action (or of a refusal's reason code,
// or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes the plan
// through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never
// changes state. Modelled on feature 486's `MicroscopicAuroraFeedbackPlan`.
//
// Words: the level's own words (`MushroomWeatherLevel.cellWords(_:)`: "row r, column c"), pods and vents counted from 1
// (slot + 1, index + 1). The progress that follows every accepted pod, vent and moonlight action, undo and redo is
// " c of n colonies stay in band, running now would win, a actions left." ("… would fail" when the play's report
// fails) — n the level's colonies and c the colonies staying in band: those whose final in-band run in the predicted
// run of the current arrangement (`MushroomWeatherForest.report(level, arrangement:)`, which is the play's `report`)
// reaches the level's required cycles; "1 action left" for one.
//
// Classification of `after(old:new:)`, first match wins (the core's `mode`, `tutorial` and `certifiedActionCount` of
// feature 495 are read directly):
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one or more records (`level.next`, `level.select` and the mode actions `mode.campaign`,
//      `mode.practice`, `mode.daily` open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      the core's `band`, 1 … 5) plus " " and the tutorial instruction while the tutorial is shown (not done); no
//      haptic;
//   2. accepted actions: the play gained one or more records (one per accepted action) →
//      a new end (the stage became won or failed; Q2: the run always ends the level and plans only its outcome, and so
//      does a redo that restores a won or failed moment):
//        won: `outcome`, "Every colony stayed in its band. Level won spending a actions, k of 3 stars." (practice:
//             "… Level won spending a actions."), haptic `success`; a is `MushroomWeatherProgress.actionsSpent(_:)`
//             (undone pod, vent and moonlight actions included; "1 action" for one) and k is
//             `MushroomWeatherProgress.stars(actionsSpent:certified:)` against the core's `certifiedActionCount`;
//        failed: `outcome`, the failure explanation of feature 495 (`MushroomWeatherFailureExplanation(play:)?.text`),
//             haptic `warning`;
//      otherwise, for one record by its kind: a placement "Pod n placed at row r, column c." (the slot was empty) or
//      "Pod n moved to row r, column c." (the slot held a pod), a removal "Pod n removed.", a vent "Vent n opened." or
//      "Vent n closed.", the moonlight "Moonlight set to level l.", an undo or redo "Undone." or "Redone."; any run of
//      several records the progress alone; each followed by the progress, each `state` with haptic `selection` (an
//      undo out of a failed play returns the play to playing and is a `state`);
//   3. the same untouched play (no pod, vent, moonlight, run, undo or redo recorded) reopened with its tutorial shown
//      again (`level.select` or `mode.campaign` of the current level after `tutorial.dismiss`) → the `level` plan of
//      case 1;
//   4. otherwise (nothing changed, the tutorial dismissed — `tutorial.dismiss` is not announced, Q1 — or only the
//      shown cycle changed: `clock.show`) → ``MushroomWeatherFeedbackPlan/none``.
// The panel's selection, drag previews, the shown cycle and the view are presentation only and plan nothing. A
// revealed hint is `hint(text:)`: `state` with the hint's words and no haptic. A refusal is `refused(code:)` with the
// adapter's codes (`MushroomWeatherExperienceRule.locked`, `.date`, `.notWhole`, `.cycle`) and the kernel's. Integers
// only.
// Feature 497 (R02-G20-07) T-R02G2007-003 (FR-R02G2007-004; clarification Q4): the replay refusals have their words
// ("There is no saved solution to replay for this level." for `r02-g20.no-replay`, "The replay is over." for
// `r02-g20.replay-end`, "Stop the replay first." for `r02-g20.replay`); a `replay.step` adds one record to the same
// play, so it is announced like the action it applies (case 2), and `replay.start` and `replay.stop` open a fresh play
// (case 1, mode "replay" or "campaign"); a replayed win claims no stars (replay never awards them).
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Mushroom Weather (feature 496, clarifications
/// Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct MushroomWeatherFeedbackPlan: Sendable, Equatable {
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
    public static let none = MushroomWeatherFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "Every colony stayed in its band."
    public static let wonText: String = "Every colony stayed in its band."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<code>`).
    public static let rulePrefix: String = "action.rule."

    /// The plan for the change from `old` to `new` after one or more accepted actions (see the file header for the
    /// order of the cases and the exact texts). Reads only.
    public static func after(old: MushroomWeatherExperienceCore,
                             new: MushroomWeatherExperienceCore) -> MushroomWeatherFeedbackPlan {
        let oldRecords: [MushroomWeatherRecord] = old.play.records
        let newRecords: [MushroomWeatherRecord] = new.play.records
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
            && new.tutorial == MushroomWeatherTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && !hasPlayerRecords(new.play) {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g20.locked", or as the engine reports it,
    /// "action.rule.r02-g20.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> MushroomWeatherFeedbackPlan {
        MushroomWeatherFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g20.locked`), "That date
    /// cannot be used." (`r02-g20.date`), "That pod, vent or moonlight change cannot be made, or there is nothing to
    /// remove, undo or redo." (`r02-g20.action`), "No actions are left: undo or retry." (`r02-g20.budget`), "The level
    /// has ended." (`r02-g20.stage`), "The play changed before the action arrived." (`r02-g20.stale`), "That level
    /// could not be made." (`r02-g20.level`), "That value must be a whole number." (`r02-g20.not-whole`), "That cycle
    /// is outside the run." (`r02-g20.cycle`); any other code (the kernel's `r02-g20.malformed`, the engine's own codes
    /// such as `action.out-of-range`) "That action was refused."; since feature 497 "There is no saved solution to
    /// replay for this level." (`r02-g20.no-replay`), "The replay is over." (`r02-g20.replay-end`) and "Stop the replay
    /// first." (`r02-g20.replay`).
    public static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch bare {
        case MushroomWeatherExperienceRule.locked: return "That level is not open yet."
        case MushroomWeatherExperienceRule.date: return "That date cannot be used."
        case MushroomWeatherError.action("").reasonCode:
            return "That pod, vent or moonlight change cannot be made, or there is nothing to remove, undo or redo."
        case MushroomWeatherError.budget.reasonCode: return "No actions are left: undo or retry."
        case MushroomWeatherError.stage.reasonCode: return "The level has ended."
        case MushroomWeatherError.stale.reasonCode: return "The play changed before the action arrived."
        case MushroomWeatherError.level("").reasonCode: return "That level could not be made."
        case MushroomWeatherExperienceRule.notWhole: return "That value must be a whole number."
        case MushroomWeatherExperienceRule.cycle: return "That cycle is outside the run."
        // Feature 497: the replay refusals.
        case MushroomWeatherExperienceRule.noReplay: return "There is no saved solution to replay for this level."
        case MushroomWeatherExperienceRule.replayEnd: return "The replay is over."
        case MushroomWeatherExperienceRule.replay: return "Stop the replay first."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> MushroomWeatherFeedbackPlan {
        MushroomWeatherFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. <the progress in words>.
    /// Selected: pod n, site at row r, column c. Level: <the level in words>."
    ///
    /// The progress is ``progressWords(_:)`` of the play (capitalised: "Pod 1 at …; pod 2 empty; vent 1 at …, open;
    /// moonlight l of 3; colony 1 at …; needs every colony in band for the last K cycles of T cycles; running now would
    /// win (or fail: <reason>)"); the selection is pod `slot + 1` and the level's site number `site` (an index into the
    /// level's sorted `sites`) in the level's words, or "pod n, no site" when `site` is nil or names no site of the
    /// level; the level is ``levelWords(_:)``. "1 action left" for one. A pure function of the core, the slot and the
    /// site.
    public static func summaryText(core: MushroomWeatherExperienceCore, slot: Int, site: Int?) -> String {
        let play: MushroomWeatherPlay = core.play
        let sites: [MushroomWeatherCell] = play.level.sites ?? []
        var selection: String = "pod \(slot + 1), no site"
        if let site, site >= 0, site < sites.count {
            selection = "pod \(slot + 1), site at " + MushroomWeatherLevel.cellWords(sites[site])
        }
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". " + capitalised(progressWords(play))
            + ". Selected: " + selection + ". Level: " + levelWords(core) + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; a forest of R rows by C columns, k colonies, p
    /// sites, s pod slots, v vents; a run of T cycles; a budget of B actions" ("1 colony", "1 site", "1 pod slot",
    /// "1 vent", "no vents", "1 action" for one or none).
    static func levelWords(_ core: MushroomWeatherExperienceCore) -> String {
        let level: MushroomWeatherLevel = core.play.level
        let siteCount: Int = level.sites?.count ?? 0
        let vents: String = level.vents.isEmpty ? "no vents" : counted(level.vents.count, "vent")
        let sites: String = siteCount == 0 ? "no sites" : counted(siteCount, "site")
        return "level \(core.levelNumber), band \(core.band), " + modeName(core.mode) + "; a forest of "
            + counted(level.rows, "row") + " by "
            + counted(level.columns, "column") + ", " + colonyWords(level.colonies.count) + ", " + sites + ", "
            + counted(level.podRules.slots, "pod slot") + ", " + vents + "; a run of " + counted(level.length, "cycle")
            + "; a budget of " + actionsWords(level.budget)
    }

    /// The name of a mode in a level announcement: "campaign", "practice", "daily" or "replay" (feature 497).
    public static func modeName(_ mode: MushroomWeatherMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// The progress in words, without the actions: the level's own progress words
    /// (`MushroomWeatherLevel.progressDescription(report:arrangement:actionsLeft:)`, "<the pods>; <the vents>; <the
    /// moonlight>; <the colonies>; needs …; running now would win (or fail: <reason>); a actions left") without their
    /// closing actions left, which the summary says first.
    public static func progressWords(_ play: MushroomWeatherPlay) -> String {
        var words: String = play.level.progressDescription(report: play.report, arrangement: play.arrangement,
                                                           actionsLeft: play.actionsLeft)
        let suffix: String = "; " + actionsLeftWords(play.actionsLeft)
        if words.hasSuffix(suffix) { words = String(words.dropLast(suffix.count)) }
        return words
    }

    /// The colonies of `play` staying in band: those whose final in-band run in the predicted run of the current
    /// arrangement (the play's report, `MushroomWeatherForest.report(level, arrangement:)`) reaches the level's
    /// required cycles.
    public static func coloniesInBand(_ play: MushroomWeatherPlay) -> Int {
        var count: Int = 0
        for runs in play.report.colonies where runs.finalRun >= play.level.required {
            count += 1
        }
        return count
    }

    /// "n <noun>s" ("1 <noun>" for one).
    static func counted(_ count: Int, _ noun: String) -> String {
        count == 1 ? "1 " + noun : "\(count) " + noun + "s"
    }

    /// "n colonies" ("1 colony" for one).
    static func colonyWords(_ count: Int) -> String {
        count == 1 ? "1 colony" : "\(count) colonies"
    }

    /// "a actions left" ("1 action left" for one).
    static func actionsLeftWords(_ count: Int) -> String {
        count == 1 ? "1 action left" : "\(count) actions left"
    }

    /// "a actions" ("1 action" for one).
    static func actionsWords(_ count: Int) -> String {
        count == 1 ? "1 action" : "\(count) actions"
    }

    /// The progress after an accepted action: "c of n colonies stay in band, running now would win, a actions left."
    /// ("… would fail" when the play's report fails).
    static func progress(_ play: MushroomWeatherPlay) -> String {
        let verdict: String = play.report.wins ? "running now would win" : "running now would fail"
        return "\(coloniesInBand(play)) of \(play.level.colonies.count) colonies stay in band, " + verdict + ", "
            + actionsLeftWords(play.actionsLeft) + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Whether `play` recorded a pod, vent or moonlight action, a run, an undo or a redo (not only its opening events).
    static func hasPlayerRecords(_ play: MushroomWeatherPlay) -> Bool {
        for record in play.records {
            switch record.kind {
            case .place, .remove, .vent, .moonlight, .run, .undo, .redo: return true
            case .begin, .dismissTutorial, .pause, .resume: continue
            }
        }
        return false
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: MushroomWeatherExperienceCore) -> MushroomWeatherFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(core.band), " + modeName(core.mode) + "."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return MushroomWeatherFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars against the core's
    /// `certifiedActionCount` in campaign and daily, never in practice or replay, feature 497), haptic `success`; or the
    /// failure explanation, haptic `warning`.
    static func outcomePlan(_ core: MushroomWeatherExperienceCore) -> MushroomWeatherFeedbackPlan {
        let play: MushroomWeatherPlay = core.play
        if play.stage == .won {
            let spent: Int = MushroomWeatherProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = MushroomWeatherProgress.stars(actionsSpent: spent,
                                                               certified: core.certifiedActionCount)
                text += ", \(stars) of 3 stars"
            }
            return MushroomWeatherFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = MushroomWeatherFailureExplanation(play: play)?.text
            ?? MushroomWeatherFailureExplanation.advice
        return MushroomWeatherFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The first sentence of one accepted `record` that took the arrangement `before` on: "Pod n placed at row r,
    /// column c." (the slot was empty) or "Pod n moved to row r, column c." (it held a pod), "Pod n removed.", "Vent n
    /// opened." or "Vent n closed.", "Moonlight set to level l.", "Undone." or "Redone."; empty for any other kind.
    static func changeWords(record: MushroomWeatherRecord, before: MushroomWeatherArrangement) -> String {
        switch record.kind {
        case .undo: return "Undone."
        case .redo: return "Redone."
        case .place:
            guard case .place(let slot, let cell)? = record.action else { return "" }
            let moved: Bool = slot >= 0 && slot < before.pods.count && before.pods[slot] != nil
            let verb: String = moved ? "moved to " : "placed at "
            return "Pod \(slot + 1) " + verb + MushroomWeatherLevel.cellWords(cell) + "."
        case .remove:
            guard case .remove(let slot)? = record.action else { return "" }
            return "Pod \(slot + 1) removed."
        case .vent:
            guard case .vent(let index, let open)? = record.action else { return "" }
            return "Vent \(index + 1) " + (open ? "opened." : "closed.")
        case .moonlight:
            guard case .moonlight(let level)? = record.action else { return "" }
            return "Moonlight set to level \(level)."
        case .run, .begin, .dismissTutorial, .pause, .resume: return ""
        }
    }

    /// The plan of the accepted records `added` that took `old` to `new`.
    static func playPlan(old: MushroomWeatherExperienceCore, new: MushroomWeatherExperienceCore,
                         added: [MushroomWeatherRecord]) -> MushroomWeatherFeedbackPlan {
        let play: MushroomWeatherPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String = added.count == 1 ? changeWords(record: added[0], before: old.play.arrangement) : ""
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return MushroomWeatherFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
