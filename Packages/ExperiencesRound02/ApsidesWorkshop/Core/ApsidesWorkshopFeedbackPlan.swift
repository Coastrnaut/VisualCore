// ApsidesWorkshopFeedbackPlan — feature 476 (R02-G18-06) T-R02G1806-003 (FR-R02G1806-001, 002, 003; clarifications
// Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of Apsides Workshop, as a pure
// function of the core before and after an accepted action (or of a refusal's reason code, or of a revealed hint's
// text), and the words of the panel's summary element. The presenter only routes the plan through the shared feedback
// route (the person's haptics switch, the shared planners' rate limits); a plan never changes state. Modelled on
// feature 466's `CelestialEclipseLabFeedbackPlan`.
//
// Words: the level's own words (`ApsidesWorkshopLevel.orbitDescription(_:)`: "size a, eccentricity 0.ee, periapsis at
// d°" with the eccentricity k × 0.05 written with two decimals and the direction d × 15°; "sector s", "planet p"),
// targets counted from 1. The progress that follows every accepted tuning, undo and redo is " m of n targets met in
// order, playing now would win, a actions left." ("… would fail" when the play's report fails) — m the new play's
// report's met count, n the level's target count; "1 action left" for one.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one or more records (`level.next`, `level.select`, `mode.daily`, `mode.practice`,
//      `mode.campaign` open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      `ApsidesWorkshopProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction while the tutorial is shown
//      (not done); no haptic;
//   2. accepted actions: the play gained one or more records (one per accepted action) →
//      a new end (the stage became won or failed; Q2: the play always ends the level and plans only its outcome, and
//      so does a redo that restores a won or failed moment):
//        won: `outcome`, "Every target was met in order. Level won spending a actions, k of 3 stars." (practice: "…
//             Level won spending a actions."), haptic `success`; a is `ApsidesWorkshopProgress.actionsSpent(_:)`
//             (undone tunings included; "1 action" for one) and k is
//             `ApsidesWorkshopProgress.stars(actionsSpent:certified:)` of this win against the certified witness's
//             tuning count (`ApsidesWorkshopExperienceCore.certifiedTunings`);
//        failed: `outcome`, the failure explanation of feature 475 (`ApsidesWorkshopFailureExplanation(play:)?.text`),
//             haptic `warning`;
//      otherwise, for one record by its kind: a periapsis tuning "Periapsis set: eccentricity 0.ee, periapsis at d°."
//      and a size tuning "Size set to a." (the record's action, in the level's orbit words); an undo or redo "Undone."
//      or "Redone."; any run of several records the progress alone; each followed by the progress, each `state` with
//      haptic `selection` (an undo out of a failed play returns the play to playing and is a `state`);
//   3. the same untouched play (no tuning, play, undo or redo recorded) reopened with its tutorial shown again → the
//      `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`; or only the shown tick changed:
//      `clock.show`) → ``ApsidesWorkshopFeedbackPlan/none``.
// The pending orbit, drag previews, the shown tick and the view are presentation only and plan nothing (the core's
// state does not change; the adjustable elements speak their own values). A revealed hint is `hint(text:)`: `state`
// with the hint's words and no haptic. Integers only.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Apsides Workshop (feature 476, clarifications Q1,
/// Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct ApsidesWorkshopFeedbackPlan: Sendable, Equatable {
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
    public static let none = ApsidesWorkshopFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "Every target was met in order."
    public static let wonText: String = "Every target was met in order."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<code>`).
    public static let rulePrefix: String = "action.rule."

    /// The plan for the change from `old` to `new` after one or more accepted actions (see the file header for the
    /// order of the cases and the exact texts). Reads only.
    public static func after(old: ApsidesWorkshopExperienceCore,
                             new: ApsidesWorkshopExperienceCore) -> ApsidesWorkshopFeedbackPlan {
        let oldRecords: [ApsidesWorkshopRecord] = old.play.records
        let newRecords: [ApsidesWorkshopRecord] = new.play.records
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
            && new.tutorial == ApsidesWorkshopTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && !hasPlayerRecords(new.play) {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g18.locked", or as the engine reports it,
    /// "action.rule.r02-g18.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> ApsidesWorkshopFeedbackPlan {
        ApsidesWorkshopFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g18.locked`), "That date
    /// cannot be used." (`r02-g18.date`), "That orbit cannot be set, or there is nothing to undo or redo."
    /// (`r02-g18.action`), "No actions are left: undo or retry." (`r02-g18.budget`), "The level has ended."
    /// (`r02-g18.stage`), "The play changed before the action arrived." (`r02-g18.stale`), "That level could not be
    /// made." (`r02-g18.level`), "That value must be a whole number." (`r02-g18.not-whole`), "That tick is outside the
    /// revolution." (`r02-g18.tick`); any other code (the kernel's `r02-g18.malformed`, the engine's own codes such as
    /// `action.out-of-range`) "That action was refused.".
    public static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch bare {
        case ApsidesWorkshopExperienceRule.locked: return "That level is not open yet."
        case ApsidesWorkshopExperienceRule.date: return "That date cannot be used."
        case ApsidesWorkshopError.action("").reasonCode:
            return "That orbit cannot be set, or there is nothing to undo or redo."
        case ApsidesWorkshopError.budget.reasonCode: return "No actions are left: undo or retry."
        case ApsidesWorkshopError.stage.reasonCode: return "The level has ended."
        case ApsidesWorkshopError.stale.reasonCode: return "The play changed before the action arrived."
        case ApsidesWorkshopError.level("").reasonCode: return "That level could not be made."
        case ApsidesWorkshopExperienceRule.notWhole: return "That value must be a whole number."
        case ApsidesWorkshopExperienceRule.tick: return "That tick is outside the revolution."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> ApsidesWorkshopFeedbackPlan {
        ApsidesWorkshopFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. <the progress in words>. Pending:
    /// size a, eccentricity 0.ee, periapsis at d°. Level: <the level in words>."
    ///
    /// The progress is ``progressWords(_:)`` of the play (capitalised: "m of n targets met in order; next: …; playing
    /// now would win (fail)"); the pending orbit is `pending` in the level's orbit words, or the play's current orbit
    /// when `pending` is nil (nothing pending); the level is ``levelWords(_:)``. "1 action left" for one. A pure
    /// function of the core and the pending orbit.
    public static func summaryText(core: ApsidesWorkshopExperienceCore, pending: ApsidesWorkshopOrbit?) -> String {
        let play: ApsidesWorkshopPlay = core.play
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". " + capitalised(progressWords(play))
            + ". Pending: " + play.level.orbitDescription(pending ?? play.orbit) + ". Level: " + levelWords(core) + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; t targets in order, p planets, a period of h
    /// ticks; a budget of B actions" ("1 target", "1 planet", "no planets", "1 action" for one).
    public static func levelWords(_ core: ApsidesWorkshopExperienceCore) -> String {
        let level: ApsidesWorkshopLevel = core.play.level
        let targets: String = level.targets.count == 1 ? "1 target" : "\(level.targets.count) targets"
        let planets: String
        switch level.planets.count {
        case 0: planets = "no planets"
        case 1: planets = "1 planet"
        default: planets = "\(level.planets.count) planets"
        }
        return "level \(core.levelNumber), band \(ApsidesWorkshopProgress.band(of: core.levelNumber)), "
            + modeName(core.mode) + "; " + targets + " in order, " + planets + ", a period of \(level.period) ticks; "
            + "a budget of " + actionsWords(level.budget)
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily".
    public static func modeName(_ mode: ApsidesWorkshopMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"   // feature 477
        }
    }

    /// The progress in words, without the orbit and the actions: the level's own progress words
    /// (`ApsidesWorkshopLevel.progressDescription(report:orbit:actionsLeft:)`, "<orbit>; m of n targets met in order;
    /// next: … (or: the orbit strikes planet p after tick t); playing now would win (fail); a actions left") without
    /// their leading orbit, which the summary says as the pending orbit, and their closing actions left, which the
    /// summary says first.
    public static func progressWords(_ play: ApsidesWorkshopPlay) -> String {
        let level: ApsidesWorkshopLevel = play.level
        var words: String = level.progressDescription(report: play.report, orbit: play.orbit,
                                                      actionsLeft: play.actionsLeft)
        let prefix: String = level.orbitDescription(play.orbit) + "; "
        if words.hasPrefix(prefix) { words = String(words.dropFirst(prefix.count)) }
        let suffix: String = "; " + actionsLeftWords(play.actionsLeft)
        if words.hasSuffix(suffix) { words = String(words.dropLast(suffix.count)) }
        return words
    }

    /// "a actions left" ("1 action left" for one).
    static func actionsLeftWords(_ count: Int) -> String {
        count == 1 ? "1 action left" : "\(count) actions left"
    }

    /// "a actions" ("1 action" for one).
    static func actionsWords(_ count: Int) -> String {
        count == 1 ? "1 action" : "\(count) actions"
    }

    /// The progress after an accepted action: "m of n targets met in order, playing now would win, a actions left."
    /// ("… would fail" when the play's report fails).
    static func progress(_ play: ApsidesWorkshopPlay) -> String {
        let verdict: String = play.report.wins ? "playing now would win" : "playing now would fail"
        return "\(play.report.met) of \(play.level.targets.count) targets met in order, " + verdict + ", "
            + actionsLeftWords(play.actionsLeft) + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Whether `play` recorded a tuning, a play, an undo or a redo (not only its opening events).
    static func hasPlayerRecords(_ play: ApsidesWorkshopPlay) -> Bool {
        for record in play.records {
            switch record.kind {
            case .periapsis, .size, .play, .undo, .redo: return true
            case .begin, .dismissTutorial, .pause, .resume: continue
            }
        }
        return false
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: ApsidesWorkshopExperienceCore) -> ApsidesWorkshopFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(core.band), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return ApsidesWorkshopFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars in campaign and daily,
    /// never in practice), haptic `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: ApsidesWorkshopExperienceCore) -> ApsidesWorkshopFeedbackPlan {
        let play: ApsidesWorkshopPlay = core.play
        if play.stage == .won {
            let spent: Int = ApsidesWorkshopProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = ApsidesWorkshopProgress.stars(actionsSpent: spent, certified: core.certifiedTunings)
                text += ", \(stars) of 3 stars"
            }
            return ApsidesWorkshopFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = ApsidesWorkshopFailureExplanation(play: play)?.text
            ?? ApsidesWorkshopFailureExplanation.advice
        return ApsidesWorkshopFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The orbit words of a periapsis tuning to eccentricity step `eccentricity` and direction step `direction` in
    /// `play`'s level: "eccentricity 0.ee, periapsis at d°" (the level's `orbitDescription(_:)` without its size).
    static func periapsisWords(eccentricity: Int, direction: Int, play: ApsidesWorkshopPlay) -> String {
        let orbit: ApsidesWorkshopOrbit = ApsidesWorkshopOrbit(size: play.orbit.size, eccentricity: eccentricity,
                                                               direction: direction)
        let full: String = play.level.orbitDescription(orbit)
        let prefix: String = "size \(orbit.size), "
        return full.hasPrefix(prefix) ? String(full.dropFirst(prefix.count)) : full
    }

    /// The first sentence of one accepted `record` of `play`: "Periapsis set: eccentricity 0.ee, periapsis at d°."
    /// (the record's periapsis tuning), "Size set to a." (its size tuning), "Undone." or "Redone."; empty for any
    /// other kind.
    static func changeWords(record: ApsidesWorkshopRecord, play: ApsidesWorkshopPlay) -> String {
        switch record.kind {
        case .undo: return "Undone."
        case .redo: return "Redone."
        case .periapsis:
            guard case .periapsis(let eccentricity, let direction)? = record.action else { return "" }
            return "Periapsis set: " + periapsisWords(eccentricity: eccentricity, direction: direction, play: play)
                + "."
        case .size:
            guard case .size(let size)? = record.action else { return "" }
            return "Size set to \(size)."
        case .play, .begin, .dismissTutorial, .pause, .resume: return ""
        }
    }

    /// The plan of the accepted records `added` that took `old` to `new`.
    static func playPlan(old: ApsidesWorkshopExperienceCore, new: ApsidesWorkshopExperienceCore,
                         added: [ApsidesWorkshopRecord]) -> ApsidesWorkshopFeedbackPlan {
        let play: ApsidesWorkshopPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String = added.count == 1 ? changeWords(record: added[0], play: play) : ""
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return ApsidesWorkshopFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
