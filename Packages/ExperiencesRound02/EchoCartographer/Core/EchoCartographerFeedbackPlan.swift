// EchoCartographerFeedbackPlan — feature 406 (R02-G11-06) T-R02G1106-003 (FR-R02G1106-002, 003, 005;
// SC-R02G1106-002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of
// Echo Cartographer, as a pure function of the core before and after an accepted action (or of a refusal's reason code,
// or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes the plan
// through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never
// changes state. Modelled on feature 396's BackwardsAuroraFeedbackPlan.
//
// Words: cells are "column x, row y" (0-based, as `EchoCartographerLevel.cellName(_:knowledge:)` names them). The
// progress that follows every accepted pulse, claim, marker, undo and redo is the level's progress words with a full
// stop: "k of n beacons located, e energy left." (`EchoCartographerLevel.progressDescription(located:energy:)`).
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one record (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`
//      open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      `EchoCartographerProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction while the tutorial is shown
//      (not done); no haptic;
//   2. an accepted action: the play gained exactly one record (its kind decides the text) →
//      a new end (the stage became won or failed; Q2: an action that ends the play plans only the outcome):
//        won: `outcome`, "Every beacon is located. Level won spending e energy, k of 3 stars." (practice: "… Level won
//             spending e energy."), haptic `success`; e is `EchoCartographerProgress.energySpent(_:)` (undone actions
//             included) and k is `EchoCartographerProgress.stars(energySpent:certified:)` of this win against the
//             certified plan's pulse count (the stars this win earned; the progress keeps the better stored result);
//        failed: `outcome`, the failure explanation of feature 405 (`EchoCartographerFailureExplanation`), haptic
//             `warning`;
//      a pulse: "Pulse from column x, row y; <rays and echoes>." (the level's pulse words, first letter capitalised);
//      a claim that located a beacon (the located count grew): "Beacon located at column x, row y."; a missed claim:
//      "No beacon at column x, row y; m energy spent." (m the energy the miss took: before minus after, never more than
//      was left); a marker: "Marker placed at column x, row y." or "Marker removed from column x, row y."; an undo or
//      redo: "Undone." or "Redone."; each followed by a space and the progress, each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``EchoCartographerFeedbackPlan/none``.
// Cursor moves and orbit are presentation only and plan nothing (the adjustable column and row speak their own values).
// A revealed hint is `hint(text:)`: `state` with the hint's words and no haptic. This file holds no floating-point
// value, so the kernel scan of the invariant tests covers it.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Echo Cartographer (feature 406, clarifications
/// Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct EchoCartographerFeedbackPlan: Sendable, Equatable {
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
    public static let none = EchoCartographerFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "Every beacon is located."
    public static let wonText: String = "Every beacon is located."

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: EchoCartographerExperienceCore,
                             new: EchoCartographerExperienceCore) -> EchoCartographerFeedbackPlan {
        let oldRecords: [EchoCartographerRecord] = old.play.records
        let newRecords: [EchoCartographerRecord] = new.play.records
        let extended: Bool = newRecords.count == oldRecords.count + 1
            && Array(newRecords.dropLast()) == oldRecords
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        if !sameLevel || (old.play != new.play && !extended) {
            return levelPlan(new)
        }
        if extended, let record = newRecords.last {
            return playPlan(old: old, new: new, record: record)
        }
        if old.play == new.play && old.tutorial != new.tutorial
            && new.tutorial == EchoCartographerTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (raw, "r02-g11.locked", or prefixed,
    /// "action.rule.r02-g11.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> EchoCartographerFeedbackPlan {
        EchoCartographerFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code` (raw or prefixed), also shown by the panel (clarification Q1):
    /// "That level is not open yet." (a code containing `r02-g11.locked`), "That date cannot be used."
    /// (`r02-g11.date`), "That action is not possible here." (`r02-g11.action`), "That beacon is already located;
    /// claiming it again changes nothing." (`r02-g11.noop`), "The level has ended." (`r02-g11.stage`), "That value must
    /// be a whole number." (`r02-g11.not-whole`), otherwise (`r02-g11.stale`, `r02-g11.malformed`, the engine's own
    /// codes such as `action.out-of-range`) "That action was refused.".
    public static func refusalText(code: String) -> String {
        if code.contains(EchoCartographerExperienceRule.locked) { return "That level is not open yet." }
        if code.contains(EchoCartographerExperienceRule.date) { return "That date cannot be used." }
        if code.contains(EchoCartographerError.action("").reasonCode) { return "That action is not possible here." }
        if code.contains(EchoCartographerError.noop.reasonCode) {
            return "That beacon is already located; claiming it again changes nothing."
        }
        if code.contains(EchoCartographerError.stage.reasonCode) { return "The level has ended." }
        if code.contains(EchoCartographerExperienceRule.notWhole) { return "That value must be a whole number." }
        return "That action was refused."
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> EchoCartographerFeedbackPlan {
        EchoCartographerFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "e energy left. k of n beacons located. Last echo:
    /// <the last pulse in words, or none>. Chosen cell: <the cell in words>. Level: <the level in words>." (the last
    /// pulse is ``EchoCartographerLevel/echoDescription(_:)`` of the play's last echo, the cell
    /// ``EchoCartographerLevel/cellName(_:knowledge:)`` of `cursor` with the play's knowledge, the level
    /// ``EchoCartographerLevel/levelDescription()``; "beacon" when the level has one).
    public static func summaryText(core: EchoCartographerExperienceCore, cursor: EchoCartographerCell) -> String {
        let play: EchoCartographerPlay = core.play
        let level: EchoCartographerLevel = play.level
        let noun: String = level.beacons.count == 1 ? "beacon" : "beacons"
        var echo: String = "none"
        if let last = play.lastEcho { echo = level.echoDescription(last) }
        return String(play.energy) + " energy left. " + String(play.located.count) + " of "
            + String(level.beacons.count) + " " + noun + " located. Last echo: " + echo + ". Chosen cell: "
            + level.cellName(cursor, knowledge: play.knowledge) + ". Level: " + level.levelDescription() + "."
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily".
    public static func modeName(_ mode: EchoCartographerMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// "column x, row y" of `cell`.
    static func cellWords(_ cell: EchoCartographerCell) -> String { "column \(cell.x), row \(cell.y)" }

    /// The progress after an accepted action: the level's progress words of `play` with a full stop.
    static func progress(_ play: EchoCartographerPlay) -> String { play.progressDescription + "." }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: EchoCartographerExperienceCore) -> EchoCartographerFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(EchoCartographerProgress.band(of: core.levelNumber)), "
            + "\(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return EchoCartographerFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its energy spent (and stars outside practice), haptic
    /// `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: EchoCartographerExperienceCore) -> EchoCartographerFeedbackPlan {
        let play: EchoCartographerPlay = core.play
        if play.stage == .won {
            let spent: Int = EchoCartographerProgress.energySpent(play)
            var text: String = wonText + " Level won spending " + String(spent) + " energy"
            if core.mode.awardsStars {
                let stars: Int = EchoCartographerProgress.stars(energySpent: spent, certified: core.certifiedPulses)
                text += ", \(stars) of 3 stars"
            }
            return EchoCartographerFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = EchoCartographerFailureExplanation(play: play)?.text
            ?? EchoCartographerFailureExplanation.advice
        return EchoCartographerFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The plan of the accepted `record` that took `old` to `new`.
    static func playPlan(old: EchoCartographerExperienceCore, new: EchoCartographerExperienceCore,
                         record: EchoCartographerRecord) -> EchoCartographerFeedbackPlan {
        let play: EchoCartographerPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String
        switch record.kind {
        case .undo: first = "Undone."
        case .redo: first = "Redone."
        case .pulse, .claim, .mark:
            first = actionWords(old: old.play, new: play, action: record.action)
        }
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return EchoCartographerFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }

    /// The change sentence of the accepted `action` that took `old` to `new` (empty when the record has no action).
    static func actionWords(old: EchoCartographerPlay, new: EchoCartographerPlay,
                            action: EchoCartographerAction?) -> String {
        guard let action else { return "" }
        let cell: EchoCartographerCell = action.cell
        switch action {
        case .pulse:
            guard let echo = new.lastEcho else { return "" }
            return capitalised(new.level.echoDescription(echo)) + "."
        case .claim:
            if new.located.count > old.located.count { return "Beacon located at " + cellWords(cell) + "." }
            let spent: Int = max(old.energy - new.energy, 0)
            return "No beacon at " + cellWords(cell) + "; " + String(spent) + " energy spent."
        case .mark:
            if new.markers.contains(cell) { return "Marker placed at " + cellWords(cell) + "." }
            return "Marker removed from " + cellWords(cell) + "."
        }
    }
}
