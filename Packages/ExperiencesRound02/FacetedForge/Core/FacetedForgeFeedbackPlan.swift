// FacetedForgeFeedbackPlan — feature 376 (R02-G08-06) T-R02G0806-003 (FR-R02G0806-001, 002, 003, 005;
// SC-R02G0806-002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of
// Faceted Forge, as a pure function of the core before and after an accepted action (or of a refusal's reason code),
// and the words of the panel's summary element. The presenter only routes the plan through the shared feedback route
// (the person's haptics switch, the shared planners' rate limits); a plan never changes state. Modelled on feature
// 366's AmethystEscapeFeedbackPlan.
//
// Words: pieces are 1-based ("piece p"); a piece in words is `FacetedForgeHints.pieceName(_:play:)` ("piece k: s of the
// crystal, f faces", "the whole crystal" before the first cut); directions are `FacetedForgeDirection.name` ("x",
// "x+y", "−x+y+z" …); c is the cuts LEFT (the play's budget minus the cuts spent; "1 cut left"); n is the piece count
// ("1 piece" after undoing the first cut).
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`) → `level`, "Level n, band b,
//      <campaign|practice|daily>." (b = `FacetedForgeProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction
//      while the tutorial is shown (not done); no haptic;
//   2. an accepted action: the play gained exactly one record (its kind decides the text) →
//      a new end (the stage became won or failed; Q2: a cut or redo that ends the play plans only the outcome):
//        won: `outcome`, "The pieces match the target. Level won with m cuts made, k of 3 stars." (practice: "The
//             pieces match the target. Level won with m cuts made."), haptic `success`; m is
//             `FacetedForgeProgress.cutsMade(_:)` (undone cuts included) and k is
//             `FacetedForgeProgress.stars(cutsMade:smallest:)` of this win against the certified smallest cut count;
//        failed: `outcome`, the failure explanation of feature 375, haptic `warning`;
//      a cut: "Piece p cut in direction x at depth d: n pieces now. c cuts left." (p = the cut record's piece + 1);
//      an undo or redo: "Undone. " or "Redone. " followed by "n pieces. c cuts left.";
//      each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``FacetedForgeFeedbackPlan/none``.
// Changes of the preview choice (piece, direction, depth) are presentation only and plan nothing: the adjustable
// pickers speak their own values.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Faceted Forge (feature 376, clarifications Q1,
/// Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct FacetedForgeFeedbackPlan: Sendable, Equatable {
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
    public static let none = FacetedForgeFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: FacetedForgeExperienceCore,
                             new: FacetedForgeExperienceCore) -> FacetedForgeFeedbackPlan {
        let oldRecords: [FacetedForgeRecord] = old.play.records
        let newRecords: [FacetedForgeRecord] = new.play.records
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
            && new.tutorial == FacetedForgeTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (raw, "r02-g08.locked", or prefixed,
    /// "action.rule.r02-g08.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> FacetedForgeFeedbackPlan {
        FacetedForgeFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code` (raw or prefixed), also shown by the panel (clarification Q1):
    /// "That level is not open yet." (a code containing `r02-g08.locked`), "That date cannot be used."
    /// (`r02-g08.date`), "That cut is not possible here." (`r02-g08.action`), "That plane misses the piece."
    /// (`r02-g08.miss`), "The level has ended." (`r02-g08.stage`), "That value must be a whole number."
    /// (`r02-g08.not-whole`), otherwise (`r02-g08.stale`, `r02-g08.malformed`, the engine's own codes such as
    /// `action.out-of-range`) "That move was refused.".
    public static func refusalText(code: String) -> String {
        if code.contains(FacetedForgeExperienceRule.locked) { return "That level is not open yet." }
        if code.contains(FacetedForgeExperienceRule.date) { return "That date cannot be used." }
        if code.contains(FacetedForgeError.action("").reasonCode) { return "That cut is not possible here." }
        if code.contains(FacetedForgeError.miss.reasonCode) { return "That plane misses the piece." }
        if code.contains(FacetedForgeError.stage.reasonCode) { return "The level has ended." }
        if code.contains(FacetedForgeExperienceRule.notWhole) { return "That value must be a whole number." }
        return "That move was refused."
    }

    /// The words of the panel's summary element (clarification Q5): "c cuts left. n pieces: <each piece in words,
    /// joined by "; ">. Target: <``FacetedForgeLevel/targetDescription()``>. Next cut: piece p, direction x, depth d."
    /// with p, x and d from `choice` (p 1-based); when the choice's plane does not cross its piece (or the piece does
    /// not exist), the last sentence is "Next cut: piece p, direction x, the plane misses this piece.".
    public static func summaryText(core: FacetedForgeExperienceCore, choice: FacetedForgePreviewChoice) -> String {
        let play: FacetedForgePlay = core.play
        var names: [String] = []
        for index in play.pieces.indices {
            names.append(FacetedForgeHints.pieceName(index, play: play))
        }
        var text: String = cutsLeft(play.remaining) + ". " + pieces(play.pieces.count) + ": "
            + names.joined(separator: "; ") + ". Target: " + play.level.targetDescription() + ". "
        let direction: String = directionName(choice.direction)
        text += "Next cut: piece " + String(choice.piece + 1) + ", direction " + direction + ", "
        var crossed: Bool = false
        if play.pieces.indices.contains(choice.piece) {
            crossed = play.pieces[choice.piece].isCrossed(direction: choice.direction, depth: choice.depth)
        }
        if crossed {
            text += "depth " + String(choice.depth) + "."
        } else {
            text += "the plane misses this piece."
        }
        return text
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily".
    public static func modeName(_ mode: FacetedForgeMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// "1 cut left" or "c cuts left".
    public static func cutsLeft(_ count: Int) -> String { count == 1 ? "1 cut left" : "\(count) cuts left" }

    /// "1 cut" or "m cuts".
    public static func cuts(_ count: Int) -> String { count == 1 ? "1 cut" : "\(count) cuts" }

    /// "1 piece" or "n pieces".
    public static func pieces(_ count: Int) -> String { count == 1 ? "1 piece" : "\(count) pieces" }

    /// The name of direction `index` (``FacetedForgeDirection/name``), or the number for an index outside 0 … 12.
    static func directionName(_ index: Int) -> String {
        FacetedForgeDirection.all.indices.contains(index) ? FacetedForgeDirection.all[index].name : String(index)
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: FacetedForgeExperienceCore) -> FacetedForgeFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(FacetedForgeProgress.band(of: core.levelNumber)), "
            + "\(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return FacetedForgeFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its cuts made (and stars outside practice), haptic
    /// `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: FacetedForgeExperienceCore) -> FacetedForgeFeedbackPlan {
        let play: FacetedForgePlay = core.play
        if play.stage == .won {
            let made: Int = FacetedForgeProgress.cutsMade(play)
            var text: String = "The pieces match the target. Level won with " + cuts(made) + " made"
            if core.mode.awardsStars {
                let stars: Int = FacetedForgeProgress.stars(cutsMade: made, smallest: core.certifiedSmallest)
                text += ", \(stars) of 3 stars"
            }
            return FacetedForgeFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = core.failureExplanation?.text ?? FacetedForgeFailureExplanation.advice
        return FacetedForgeFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The plan of the accepted `record` that took `old` to `new`.
    static func playPlan(old: FacetedForgeExperienceCore, new: FacetedForgeExperienceCore,
                         record: FacetedForgeRecord) -> FacetedForgeFeedbackPlan {
        let play: FacetedForgePlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let count: String = pieces(play.pieces.count)
        let left: String = cutsLeft(play.remaining) + "."
        let text: String
        switch record.kind {
        case .cut:
            if case .cut(let piece, let direction, let depth)? = record.action {
                text = "Piece " + String(piece + 1) + " cut in direction " + directionName(direction) + " at depth "
                    + String(depth) + ": " + count + " now. " + left
            } else {
                text = count + ". " + left
            }
        case .undo: text = "Undone. " + count + ". " + left
        case .redo: text = "Redone. " + count + ". " + left
        }
        return FacetedForgeFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
