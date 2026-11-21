// ColorfallCanyonsFeedbackPlan — feature 346 (R02-G05-06) T-R02G0506-002 (FR-R02G0506-001, 002, 003; SC-R02G0506-002;
// clarifications Q1, Q2, Q5). The VoiceOver announcement and haptic of one change of Colorfall Canyons, as a pure
// function of the core before and after an accepted action (or of a refusal's reason code), and the words of the
// panel's summary element. The presenter only routes the plan through the shared feedback route (the user's haptics
// switch, the shared planners' rate limits); a plan never changes state. Modelled on feature 336's
// HueCompassFeedbackPlan.
//
// Numbers: rows and columns are spoken 1-based (row = cell / columns + 1, column = cell % columns + 1, as the failure
// explanation of feature 345 does); n is the actions LEFT (`ColorfallCanyonsPlay.remaining`, the level's budget minus
// the actions spent); t is the fluid tick and T the level's tick limit; basins are numbered 1 … m in the level's order.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, also of the same level) →
//      `level`, "Level n, band b, <campaign|practice|daily>." (b = `ColorfallCanyonsProgress.band(of:)` 1 … 5) plus
//      " " and the tutorial instruction while the tutorial is not done; no haptic;
//   2. an accepted action: the play gained exactly one record (its kind decides the text) →
//      a new end (the stage became won or failed; Q2: a step, or a redo, that ends the play plans only the outcome):
//        won: `outcome`, "Every basin is filled. Level won with s actions, k of 3 stars." (practice: "Every basin is
//             filled. Level won with s actions."), haptic `success`; k is `ColorfallCanyonsProgress.stars(actions:
//             smallest:)` of this win against the certified smallest edit count;
//        failed: `outcome`, the failure explanation of feature 345, haptic `warning`;
//      a carve: `state`, "Carved row r, column c. n actions left.", haptic `selection`;
//      a valve: `state`, "<Colour> valve open. n actions left." or "<Colour> valve closed. n actions left." (the valve
//           state after the toggle), haptic `selection`;
//      a step: `state`, "Tick t of T. f of m basins filled." (filled = the basin accepts its masses), haptic
//           `selection`;
//      an undo or redo: `state`, "Undone. Tick t of T. n actions left." or "Redone. Tick t of T. n actions left.",
//           haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again (for example `mode.campaign` on a tutorial level
//      after a dismissal) → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``ColorfallCanyonsFeedbackPlan/none``.
// A count of 1 takes the singular noun ("1 action left", "Level won with 1 action").
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Colorfall Canyons (feature 346, clarifications Q1,
/// Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct ColorfallCanyonsFeedbackPlan: Sendable, Equatable {
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
    public static let none = ColorfallCanyonsFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: ColorfallCanyonsExperienceCore,
                             new: ColorfallCanyonsExperienceCore) -> ColorfallCanyonsFeedbackPlan {
        let oldRecords: [ColorfallCanyonsRecord] = old.play.records
        let newRecords: [ColorfallCanyonsRecord] = new.play.records
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
            && new.tutorial == ColorfallCanyonsTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a cell pick on the panel's cell picker (presentation only, no state change): `state`, "Row r, column
    /// c picked." with r and c 1-based in a grid of `columns` columns, no haptic.
    public static func picked(cell: Int, columns: Int) -> ColorfallCanyonsFeedbackPlan {
        ColorfallCanyonsFeedbackPlan(text: cellWords(cell, columns: columns, capitalised: true) + " picked.",
                                     kind: .state, haptic: nil)
    }

    /// The plan of a refused action with reason code `code` (raw, "r02-g05.locked", or prefixed,
    /// "action.rule.r02-g05.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> ColorfallCanyonsFeedbackPlan {
        ColorfallCanyonsFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code` (raw or prefixed), also shown by the panel (clarification Q1):
    /// "That level is not open yet." (a code containing `r02-g05.locked`), "That date cannot be used."
    /// (`r02-g05.date`), "That action is not allowed here." (`r02-g05.action`), "No actions are left."
    /// (`r02-g05.budget`), "The level has ended." (`r02-g05.stage`), "That value must be a whole number."
    /// (`r02-g05.not-whole`), otherwise "That change was refused.".
    public static func refusalText(code: String) -> String {
        if code.contains(ColorfallCanyonsExperienceRule.locked) { return "That level is not open yet." }
        if code.contains(ColorfallCanyonsExperienceRule.date) { return "That date cannot be used." }
        if code.contains(ColorfallCanyonsExperienceRule.notWhole) { return "That value must be a whole number." }
        if code.contains(ColorfallCanyonsError.action("").reasonCode) { return "That action is not allowed here." }
        if code.contains(ColorfallCanyonsError.budget.reasonCode) { return "No actions are left." }
        if code.contains(ColorfallCanyonsError.stage.reasonCode) { return "The level has ended." }
        return "That change was refused."
    }

    /// The words of the panel's summary element (clarification Q5): "Tick t of T. n actions left." followed, for every
    /// basin k = 1 … m in the level's order, by " Basin k: cyan a, coral b, yellow c; target <description>." with a, b
    /// and c the units of each colour the basin holds and <description> ``ColorfallCanyonsBasin/description``.
    public static func summaryText(core: ColorfallCanyonsExperienceCore) -> String {
        let play: ColorfallCanyonsPlay = core.play
        var text: String = tickText(play) + " " + actionsLeft(play.remaining) + "."
        for index in play.level.basins.indices {
            let basin: ColorfallCanyonsBasin = play.level.basins[index]
            let masses: [Int] = play.fluid.masses[basin.cell]
            var parts: [String] = []
            for color in ColorfallCanyonsColor.allCases { parts.append("\(color.name) \(masses[color.rawValue])") }
            text += " Basin \(index + 1): " + parts.joined(separator: ", ") + "; target \(basin.description)."
        }
        return text
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily".
    public static func modeName(_ mode: ColorfallCanyonsMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// "1 action left" or "n actions left".
    public static func actionsLeft(_ count: Int) -> String { count == 1 ? "1 action left" : "\(count) actions left" }

    /// "1 action" or "s actions".
    public static func actions(_ count: Int) -> String { count == 1 ? "1 action" : "\(count) actions" }

    /// "row r, column c" (or "Row r, column c" when `capitalised`) of `cell` in a grid of `columns` columns, 1-based.
    public static func cellWords(_ cell: Int, columns: Int, capitalised: Bool = false) -> String {
        let width: Int = max(columns, 1)
        return (capitalised ? "Row" : "row") + " \(cell / width + 1), column \(cell % width + 1)"
    }

    /// "Tick t of T." of `play`.
    static func tickText(_ play: ColorfallCanyonsPlay) -> String {
        "Tick \(play.fluid.tick) of \(play.level.tickLimit)."
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: ColorfallCanyonsExperienceCore) -> ColorfallCanyonsFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(ColorfallCanyonsProgress.band(of: core.levelNumber)), "
            + "\(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return ColorfallCanyonsFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The plan of the accepted `record` that took `old` to `new`.
    static func playPlan(old: ColorfallCanyonsExperienceCore, new: ColorfallCanyonsExperienceCore,
                         record: ColorfallCanyonsRecord) -> ColorfallCanyonsFeedbackPlan {
        let play: ColorfallCanyonsPlay = new.play
        let ended: Bool = play.stage != old.play.stage && (play.stage == .won || play.stage == .failed)
        if ended && play.stage == .won {
            var text: String = "Every basin is filled. Level won with \(actions(play.spent))"
            if new.mode.awardsStars {
                let stars: Int = ColorfallCanyonsProgress.stars(actions: play.spent, smallest: new.certifiedSmallest)
                text += ", \(stars) of 3 stars"
            }
            return ColorfallCanyonsFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        if ended {
            let text: String = new.failureExplanation?.text ?? ColorfallCanyonsFailureExplanation.advice
            return ColorfallCanyonsFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
        }
        let left: String = actionsLeft(play.remaining) + "."
        let text: String
        switch record.kind {
        case .carve:
            if case .carve(let cell)? = record.action {
                text = "Carved " + cellWords(cell, columns: play.level.columns) + ". " + left
            } else {
                text = left
            }
        case .valve:
            if case .valve(let spring)? = record.action, play.level.springs.indices.contains(spring) {
                let name: String = play.level.springs[spring].color.name.capitalized
                let state: String = play.fluid.valves[spring] ? "open" : "closed"
                text = "\(name) valve \(state). " + left
            } else {
                text = left
            }
        case .step:
            var filled: Int = 0
            for basin in play.level.basins where basin.accepts(play.fluid.masses[basin.cell]) { filled += 1 }
            text = tickText(play) + " \(filled) of \(play.level.basins.count) basins filled."
        case .undo: text = "Undone. " + tickText(play) + " " + left
        case .redo: text = "Redone. " + tickText(play) + " " + left
        }
        return ColorfallCanyonsFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
