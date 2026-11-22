// NocturneGardenFeedbackPlan — feature 386 (R02-G09-06) T-R02G0906-003 (FR-R02G0906-001, 002, 003, 005;
// SC-R02G0906-002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of
// Nocturne Garden, as a pure function of the core before and after an accepted action (or of a refusal's reason code,
// or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes the plan
// through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never
// changes state. Modelled on feature 376's FacetedForgeFeedbackPlan.
//
// Words: blooms are 1-based and named in the canonical order of the play after the change (as the kernel's failure
// reason names them), a bloom in words is `NocturneGardenLevel.bloomName(_:bloom:)` ("bloom n: rose at column c, row r,
// size s"); a removed bloom is named by its number before the removal. The measure that follows every accepted move,
// undo and redo is " Match x/y, needs p/q; leak k cells, a allowed. m moves left." (x/y the cells dark and in the
// target over the cells dark or in the target, p/q the required match, k the dark forbidden cells with
// `NocturneGardenLevel.cellsText(_:)` ("1 cell"), a the leak allowance, m the moves left, "1 move left").
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`) → `level`, "Level n, band b,
//      <campaign|practice|daily>." (b = `NocturneGardenProgress.band(of:)` 1 … 5) plus " " and the tutorial
//      instruction while the tutorial is shown (not done); no haptic;
//   2. an accepted action: the play gained exactly one record (its kind decides the text) →
//      a new end (the stage became won or failed; Q2: a move or redo that ends the play plans only the outcome):
//        won: `outcome`, "The shadow matches the target. Level won with m moves made, k of 3 stars." (practice: "The
//             shadow matches the target. Level won with m moves made."), haptic `success`; m is
//             `NocturneGardenProgress.movesMade(_:)` (undone moves included) and k is
//             `NocturneGardenProgress.stars(movesMade:smallest:)` of this win against the certified smallest count;
//        failed: `outcome`, the failure explanation of feature 385 (`NocturneGardenFailureExplanation`), haptic
//             `warning`;
//      a plant: "Planted bloom n: k at column c, row r, size s."; a move: "Moved bloom n to column c, row r.";
//      a resize: "Bloom n is now size s."; a removal: "Removed bloom n."; the sun: "Sun e of 4.";
//      an undo or redo: "Undone." or "Redone."; each followed by the measure, each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``NocturneGardenFeedbackPlan/none``.
// Changes of the panel's pickers and drag previews are presentation only and plan nothing: the adjustable pickers speak
// their own values. A revealed hint is `hint(text:)`: `state` with the hint's words and no haptic.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Nocturne Garden (feature 386, clarifications Q1,
/// Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct NocturneGardenFeedbackPlan: Sendable, Equatable {
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
    public static let none = NocturneGardenFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: NocturneGardenExperienceCore,
                             new: NocturneGardenExperienceCore) -> NocturneGardenFeedbackPlan {
        let oldRecords: [NocturneGardenRecord] = old.play.records
        let newRecords: [NocturneGardenRecord] = new.play.records
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
            && new.tutorial == NocturneGardenTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (raw, "r02-g09.locked", or prefixed,
    /// "action.rule.r02-g09.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> NocturneGardenFeedbackPlan {
        NocturneGardenFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code` (raw or prefixed), also shown by the panel (clarification Q1):
    /// "That level is not open yet." (a code containing `r02-g09.locked`), "That date cannot be used."
    /// (`r02-g09.date`), "That move is not possible here." (`r02-g09.action`), "No bloom of that kind is left."
    /// (`r02-g09.supply`), "That changes nothing." (`r02-g09.noop`), "The level has ended." (`r02-g09.stage`),
    /// "That value must be a whole number." (`r02-g09.not-whole`), otherwise (`r02-g09.stale`, `r02-g09.malformed`,
    /// the engine's own codes such as `action.out-of-range`) "That move was refused.".
    public static func refusalText(code: String) -> String {
        if code.contains(NocturneGardenExperienceRule.locked) { return "That level is not open yet." }
        if code.contains(NocturneGardenExperienceRule.date) { return "That date cannot be used." }
        if code.contains(NocturneGardenError.action("").reasonCode) { return "That move is not possible here." }
        if code.contains(NocturneGardenError.supply.reasonCode) { return "No bloom of that kind is left." }
        if code.contains(NocturneGardenError.noop.reasonCode) { return "That changes nothing." }
        if code.contains(NocturneGardenError.stage.reasonCode) { return "The level has ended." }
        if code.contains(NocturneGardenExperienceRule.notWhole) { return "That value must be a whole number." }
        return "That move was refused."
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> NocturneGardenFeedbackPlan {
        NocturneGardenFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "m moves left. Match x/y, needs p/q; leak k cells,
    /// a allowed; sun e of 4. Blooms: <each planted bloom in words, joined by "; ">. Target: <the level in words>."
    /// ("Blooms: none." on an empty bed; the level in words is ``NocturneGardenLevel/targetDescription()``).
    public static func summaryText(core: NocturneGardenExperienceCore) -> String {
        let play: NocturneGardenPlay = core.play
        let level: NocturneGardenLevel = play.level
        var names: [String] = []
        for index in play.blooms.indices {
            names.append(level.bloomName(index, bloom: play.blooms[index]))
        }
        let blooms: String = names.isEmpty ? "none" : names.joined(separator: "; ")
        return movesLeft(play.remaining) + ". " + matchAndLeak(play) + "; sun " + String(play.elevation) + " of 4. "
            + "Blooms: " + blooms + ". Target: " + level.targetDescription() + "."
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily".
    public static func modeName(_ mode: NocturneGardenMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// "1 move left" or "m moves left".
    public static func movesLeft(_ count: Int) -> String { count == 1 ? "1 move left" : "\(count) moves left" }

    /// "1 move" or "m moves".
    public static func moves(_ count: Int) -> String { count == 1 ? "1 move" : "\(count) moves" }

    /// "Match x/y, needs p/q; leak k cells, a allowed" of `play` (no full stop).
    static func matchAndLeak(_ play: NocturneGardenPlay) -> String {
        let match: (shared: Int, either: Int) = play.match
        return "Match " + String(match.shared) + "/" + String(match.either) + ", needs " + play.level.required.text
            + "; " + play.level.leakText(play.leak)
    }

    /// The measure after an accepted move, undo or redo: "Match x/y, needs p/q; leak k cells, a allowed. m moves
    /// left." of `play`.
    static func measure(_ play: NocturneGardenPlay) -> String {
        matchAndLeak(play) + ". " + movesLeft(play.remaining) + "."
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: NocturneGardenExperienceCore) -> NocturneGardenFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(NocturneGardenProgress.band(of: core.levelNumber)), "
            + "\(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return NocturneGardenFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its moves made (and stars outside practice), haptic
    /// `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: NocturneGardenExperienceCore) -> NocturneGardenFeedbackPlan {
        let play: NocturneGardenPlay = core.play
        if play.stage == .won {
            let made: Int = NocturneGardenProgress.movesMade(play)
            var text: String = "The shadow matches the target. Level won with " + moves(made) + " made"
            if core.mode.awardsStars {
                let stars: Int = NocturneGardenProgress.stars(movesMade: made, smallest: core.certifiedSmallest)
                text += ", \(stars) of 3 stars"
            }
            return NocturneGardenFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = NocturneGardenFailureExplanation(play: play)?.text ?? NocturneGardenFailureExplanation.advice
        return NocturneGardenFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The 1-based number of `bloom` in `play`'s canonical order, or nil when it is not planted.
    static func number(of bloom: NocturneGardenBloom, in play: NocturneGardenPlay) -> Int? {
        guard let index = play.blooms.firstIndex(of: bloom) else { return nil }
        return index + 1
    }

    /// What the accepted `action` did, in words, naming blooms in the order of `new` (a removed one in the order of
    /// `old`), with a full stop.
    static func actionText(_ action: NocturneGardenAction, old: NocturneGardenPlay, new: NocturneGardenPlay) -> String {
        switch action {
        case let .plant(kind, column, row, size):
            let bloom: NocturneGardenBloom = NocturneGardenBloom(kind: kind, column: column, row: row, size: size)
            let index: Int = (number(of: bloom, in: new) ?? 1) - 1
            return "Planted " + new.level.bloomName(index, bloom: bloom) + "."
        case let .move(index, column, row):
            var shown: Int = index + 1
            if old.blooms.indices.contains(index) {
                let before: NocturneGardenBloom = old.blooms[index]
                let after: NocturneGardenBloom = NocturneGardenBloom(kind: before.kind, column: column, row: row,
                                                                     size: before.size)
                shown = number(of: after, in: new) ?? shown
            }
            return "Moved bloom " + String(shown) + " to column " + String(column) + ", row " + String(row) + "."
        case let .resize(index, size):
            var shown: Int = index + 1
            if old.blooms.indices.contains(index) {
                let before: NocturneGardenBloom = old.blooms[index]
                let after: NocturneGardenBloom = NocturneGardenBloom(kind: before.kind, column: before.column,
                                                                     row: before.row, size: size)
                shown = number(of: after, in: new) ?? shown
            }
            return "Bloom " + String(shown) + " is now size " + String(size) + "."
        case let .remove(index):
            return "Removed bloom " + String(index + 1) + "."
        case let .sun(elevation):
            return "Sun " + String(elevation) + " of 4."
        }
    }

    /// The plan of the accepted `record` that took `old` to `new`.
    static func playPlan(old: NocturneGardenExperienceCore, new: NocturneGardenExperienceCore,
                         record: NocturneGardenRecord) -> NocturneGardenFeedbackPlan {
        let play: NocturneGardenPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String
        switch record.kind {
        case .undo: first = "Undone."
        case .redo: first = "Redone."
        case .plant, .move, .resize, .remove, .sun:
            if let action = record.action {
                first = actionText(action, old: old.play, new: play)
            } else {
                first = ""
            }
        }
        let text: String = first.isEmpty ? measure(play) : first + " " + measure(play)
        return NocturneGardenFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
