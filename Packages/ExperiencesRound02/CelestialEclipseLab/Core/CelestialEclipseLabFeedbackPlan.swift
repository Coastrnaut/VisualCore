// CelestialEclipseLabFeedbackPlan — feature 466 (R02-G17-06) T-R02G1706-003 (FR-R02G1706-001, 002, 003, 005;
// SC-R02G1706-001, 002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one
// change of Celestial Eclipse Lab, as a pure function of the core before and after an accepted action (or of a
// refusal's reason code, or of a revealed hint's text), and the words of the panel's summary element. The presenter
// only routes the plan through the shared feedback route (the person's haptics switch, the shared planners' rate
// limits); a plan never changes state. Modelled on feature 456's `StarlitCartoucheFeedbackPlan`.
//
// Words: bodies as the level names them (`CelestialEclipseLabLevel.bodyName(_:)`, "body j", capitalised at the start
// of a sentence), phases as the kernel's offsets, actions from 1. The progress that follows every accepted phase
// change, undo and redo is " m of n eclipses in order, a run now would win, a actions left." ("… would fail" when the
// predicted timeline fails) — m the new play's timeline's matched count, n the target's length; "1 action left" for
// one.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one or more records (`level.next`, `level.select`, `mode.daily`, `mode.practice`,
//      `mode.campaign` open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      `CelestialEclipseLabProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction while the tutorial is shown
//      (not done); no haptic;
//   2. accepted actions: the play gained one or more records (one per accepted action) →
//      a new end (the stage became won or failed; Q2: the run always ends the level and plans only its outcome, and so
//      does a redo that restores a won or failed moment):
//        won: `outcome`, "The eclipses came in the target order. Level won spending a actions, k of 3 stars."
//             (practice: "… Level won spending a actions."), haptic `success`; a is
//             `CelestialEclipseLabProgress.actionsSpent(_:)` (undone phase changes included; "1 action" for one) and k
//             is `CelestialEclipseLabProgress.stars(actionsSpent:certified:)` of this win against the certified
//             witness's phase-change count (`CelestialEclipseLabExperienceCore.certifiedChanges`);
//        failed: `outcome`, the failure explanation of feature 465 (`CelestialEclipseLabFailureExplanation(play:)?
//             .text`), haptic `warning`;
//      otherwise, for one record by its kind: a phase change "Body j set to phase p." (the record's action); an undo or
//      redo "Undone." or "Redone."; any run of several records the progress alone; each followed by the progress, each
//      `state` with haptic `selection` (an undo out of a failed run returns the play to playing and is a `state`);
//   3. the same untouched play (no phase change, run, undo or redo recorded) reopened with its tutorial shown again →
//      the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`; or only the chosen body or the
//      shown tick changed: `orbit.choose`, `clock.show`) → ``CelestialEclipseLabFeedbackPlan/none``.
// Choosing a body, the pending phase texts, the shown tick and orbit are presentation only and plan nothing (the core's
// state does not change; the adjustable elements speak their own values). A revealed hint is `hint(text:)`: `state`
// with the hint's words and no haptic. Integers only.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Celestial Eclipse Lab (feature 466,
/// clarifications Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare
/// them exactly.
public struct CelestialEclipseLabFeedbackPlan: Sendable, Equatable {
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
    public static let none = CelestialEclipseLabFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "The eclipses came in the target order."
    public static let wonText: String = "The eclipses came in the target order."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<code>`).
    public static let rulePrefix: String = "action.rule."

    /// The plan for the change from `old` to `new` after one or more accepted actions (see the file header for the
    /// order of the cases and the exact texts). Reads only.
    public static func after(old: CelestialEclipseLabExperienceCore,
                             new: CelestialEclipseLabExperienceCore) -> CelestialEclipseLabFeedbackPlan {
        let oldRecords: [CelestialEclipseLabRecord] = old.play.records
        let newRecords: [CelestialEclipseLabRecord] = new.play.records
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
            && new.tutorial == CelestialEclipseLabTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && !hasPlayerRecords(new.play) {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g17.locked", or as the engine reports it,
    /// "action.rule.r02-g17.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> CelestialEclipseLabFeedbackPlan {
        CelestialEclipseLabFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g17.locked`), "That date
    /// cannot be used." (`r02-g17.date`), "That phase change, undo or redo cannot be made now." (`r02-g17.action`),
    /// "No actions are left: undo or retry." (`r02-g17.budget`), "The level has ended." (`r02-g17.stage`), "That value
    /// must be a whole number." (`r02-g17.not-whole`), "That body is not in this level." (`r02-g17.choice`), "That tick
    /// is outside the timeline." (`r02-g17.tick`); any other code (`r02-g17.stale`, `r02-g17.level`, the engine's own
    /// codes such as `action.out-of-range`) "That action was refused.".
    public static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch bare {
        case CelestialEclipseLabExperienceRule.locked: return "That level is not open yet."
        case CelestialEclipseLabExperienceRule.date: return "That date cannot be used."
        case CelestialEclipseLabError.action("").reasonCode:
            return "That phase change, undo or redo cannot be made now."
        case CelestialEclipseLabError.budget.reasonCode: return "No actions are left: undo or retry."
        case CelestialEclipseLabError.stage.reasonCode: return "The level has ended."
        case CelestialEclipseLabExperienceRule.notWhole: return "That value must be a whole number."
        case CelestialEclipseLabExperienceRule.choice: return "That body is not in this level."
        case CelestialEclipseLabExperienceRule.tick: return "That tick is outside the timeline."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> CelestialEclipseLabFeedbackPlan {
        CelestialEclipseLabFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. <the progress in words>. Chosen:
    /// body j at phase p. Level: <the level in words>."
    ///
    /// The progress is ``progressWords(_:)`` of the play (capitalised: "m of n eclipses in order; next: body f in front
    /// of body b between tick o and tick c; a run now would win (fail)"); `body` is the chosen body and `phase` the
    /// pending phase (the body's current phase when no change is pending), as the panel passes them; the level is
    /// ``levelWords(_:)``. "1 action left" for one. A pure function of the core and the chosen body and phase.
    public static func summaryText(core: CelestialEclipseLabExperienceCore, body: Int, phase: Int) -> String {
        let play: CelestialEclipseLabPlay = core.play
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". " + capitalised(progressWords(play))
            + ". Chosen: " + play.level.bodyName(body) + " at phase \(phase). Level: " + levelWords(core) + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; t target eclipses in order among k bodies over h
    /// ticks; a budget of B actions" ("1 target eclipse", "1 action" for one).
    public static func levelWords(_ core: CelestialEclipseLabExperienceCore) -> String {
        let level: CelestialEclipseLabLevel = core.play.level
        let targets: String = level.target.count == 1 ? "1 target eclipse" : "\(level.target.count) target eclipses"
        return "level \(core.levelNumber), band \(CelestialEclipseLabProgress.band(of: core.levelNumber)), "
            + modeName(core.mode) + "; " + targets + " in order among \(level.bodies.count) bodies over "
            + "\(level.horizon) ticks; a budget of " + actionsWords(level.budget)
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily".
    public static func modeName(_ mode: CelestialEclipseLabMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// The progress in words, without the actions: the level's own progress words
    /// (`CelestialEclipseLabLevel.progressDescription(timeline:actionsLeft:)`, "m of n eclipses in order; next: …
    /// between tick o and tick c; a run now would win (fail)") without their closing actions left, which the summary
    /// says first.
    public static func progressWords(_ play: CelestialEclipseLabPlay) -> String {
        let full: String = play.level.progressDescription(timeline: play.timeline, actionsLeft: play.actionsLeft)
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

    /// The progress after an accepted action: "m of n eclipses in order, a run now would win, a actions left." ("…
    /// would fail" when the predicted timeline fails).
    static func progress(_ play: CelestialEclipseLabPlay) -> String {
        let verdict: String = play.timeline.wins ? "a run now would win" : "a run now would fail"
        return "\(play.timeline.matched) of \(play.level.target.count) eclipses in order, " + verdict + ", "
            + actionsLeftWords(play.actionsLeft) + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Whether `play` recorded a phase change, a run, an undo or a redo (not only its opening events).
    static func hasPlayerRecords(_ play: CelestialEclipseLabPlay) -> Bool {
        for record in play.records {
            switch record.kind {
            case .phase, .run, .undo, .redo: return true
            case .begin, .dismissTutorial, .pause, .resume: continue
            }
        }
        return false
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: CelestialEclipseLabExperienceCore) -> CelestialEclipseLabFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(core.band), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return CelestialEclipseLabFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars in campaign and daily;
    /// never in practice), haptic `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: CelestialEclipseLabExperienceCore) -> CelestialEclipseLabFeedbackPlan {
        let play: CelestialEclipseLabPlay = core.play
        if play.stage == .won {
            let spent: Int = CelestialEclipseLabProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = CelestialEclipseLabProgress.stars(actionsSpent: spent,
                                                                   certified: core.certifiedChanges)
                text += ", \(stars) of 3 stars"
            }
            return CelestialEclipseLabFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = CelestialEclipseLabFailureExplanation(play: play)?.text
            ?? CelestialEclipseLabFailureExplanation.advice
        return CelestialEclipseLabFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The first sentence of one accepted `record` of `play`: "Body j set to phase p." (the record's phase change),
    /// "Undone." or "Redone."; empty for any other kind.
    static func changeWords(record: CelestialEclipseLabRecord, play: CelestialEclipseLabPlay) -> String {
        switch record.kind {
        case .undo: return "Undone."
        case .redo: return "Redone."
        case .phase:
            guard case .phase(let body, let offset)? = record.action else { return "" }
            return capitalised(play.level.bodyName(body)) + " set to phase \(offset)."
        case .run, .begin, .dismissTutorial, .pause, .resume: return ""
        }
    }

    /// The plan of the accepted records `added` that took `old` to `new`.
    static func playPlan(old: CelestialEclipseLabExperienceCore, new: CelestialEclipseLabExperienceCore,
                         added: [CelestialEclipseLabRecord]) -> CelestialEclipseLabFeedbackPlan {
        let play: CelestialEclipseLabPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String = added.count == 1 ? changeWords(record: added[0], play: play) : ""
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return CelestialEclipseLabFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
