// ChronoConstellatorFeedbackPlan — feature 356 (R02-G06-06) T-R02G0606-002 (FR-R02G0606-001, 002, 003, 005;
// SC-R02G0606-002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of
// Chrono Constellator, as a pure function of the core before and after an accepted action (or of a refusal's reason
// code), and the words of the panel's summary element. The presenter only routes the plan through the shared feedback
// route (the person's haptics switch, the shared planners' rate limits); a plan never changes state. Modelled on
// feature 346's ColorfallCanyonsFeedbackPlan.
//
// Numbers: stars are spoken 1-based with their shape ("Star 2 (cross)"); places are `ChronoConstellatorLevel.place`
// ("row r, column c", 1-based); n is the edits LEFT (`ChronoConstellatorPlay.remaining`, the budget minus the edits in
// use); e is the edits in use (`spent`); t is the replay tick and T the level's tick limit; a start phase p is the
// 0-based index into the star's loop (as the hints say it).
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`) → `level`, "Level n, band b,
//      <campaign|practice|daily>." (b = `ChronoConstellatorProgress.band(of:)` 1 … 5) plus " " and the tutorial
//      instruction while the tutorial is not done; no haptic;
//   2. an accepted action: the play gained exactly one record (its kind decides the text) →
//      a new end (the stage became won or failed; Q2: an action that ends the play plans only the outcome):
//        won: `outcome`, "Every star is on its target. Level won with e edits, k of 3 stars." (practice: "Every star is
//             on its target. Level won with e edits."), haptic `success`; k is `ChronoConstellatorProgress.stars(edits:
//             smallest:)` of this win against the certified smallest edit count;
//        failed: `outcome`, the failure explanation of feature 355, haptic `warning`;
//      a phase: "Star k (shape) starts at row r, column c. n edits left." (the cell loop[phase] of tick 0);
//      a hold: "Star k holds from tick s for l ticks. n edits left.";
//      a release: "Star k's hold from tick s removed. n edits left.";
//      a step: "Tick t of T. m of N stars on target.";
//      a rewind: "Rewound to tick 0.";
//      an undo or redo: "Undone. Tick t of T. n edits left." or "Redone. Tick t of T. n edits left.";
//      each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``ChronoConstellatorFeedbackPlan/none``.
// A count of 1 takes the singular noun ("1 edit left", "Level won with 1 edit", "for 1 tick").
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Chrono Constellator (feature 356, clarifications
/// Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct ChronoConstellatorFeedbackPlan: Sendable, Equatable {
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
    public static let none = ChronoConstellatorFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: ChronoConstellatorExperienceCore,
                             new: ChronoConstellatorExperienceCore) -> ChronoConstellatorFeedbackPlan {
        let oldRecords: [ChronoConstellatorRecord] = old.play.records
        let newRecords: [ChronoConstellatorRecord] = new.play.records
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
            && new.tutorial == ChronoConstellatorTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a star pick on the panel's star picker (presentation only, no state change): `state`, "Star k
    /// (shape) picked." with k = `star` + 1, no haptic.
    public static func picked(star: Int) -> ChronoConstellatorFeedbackPlan {
        ChronoConstellatorFeedbackPlan(text: starWords(star) + " picked.", kind: .state, haptic: nil)
    }

    /// The plan of a refused action with reason code `code` (raw, "r02-g06.locked", or prefixed,
    /// "action.rule.r02-g06.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> ChronoConstellatorFeedbackPlan {
        ChronoConstellatorFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code` (raw or prefixed), also shown by the panel (clarification Q1):
    /// "That level is not open yet." (a code containing `r02-g06.locked`), "That date cannot be used."
    /// (`r02-g06.date`), "That change is not allowed here." (`r02-g06.action`), "No edits are left."
    /// (`r02-g06.budget`), "The level has ended." (`r02-g06.stage`), "That value must be a whole number."
    /// (`r02-g06.not-whole`), otherwise (also the engine's own codes such as `action.out-of-range`) "That change was
    /// refused.".
    public static func refusalText(code: String) -> String {
        if code.contains(ChronoConstellatorExperienceRule.locked) { return "That level is not open yet." }
        if code.contains(ChronoConstellatorExperienceRule.date) { return "That date cannot be used." }
        if code.contains(ChronoConstellatorExperienceRule.notWhole) { return "That value must be a whole number." }
        if code.contains(ChronoConstellatorError.action("").reasonCode) { return "That change is not allowed here." }
        if code.contains(ChronoConstellatorError.budget.reasonCode) { return "No edits are left." }
        if code.contains(ChronoConstellatorError.stage.reasonCode) { return "The level has ended." }
        return "That change was refused."
    }

    /// The words of the panel's summary element (clarification Q5): "Tick t of T. n edits left. " followed, for every
    /// star k = 1 … N, by "Star k (shape): row r, column c, start phase p, <holds>, <on|off> its target.", joined by
    /// " "; (r, c) is the star's cell at the current tick, p its start phase, and <holds> is "no holds" or each hold as
    /// "holds from tick s for l ticks" joined by " and ".
    public static func summaryText(core: ChronoConstellatorExperienceCore) -> String {
        let play: ChronoConstellatorPlay = core.play
        let level: ChronoConstellatorLevel = play.level
        let positions: [Int] = play.positions
        var parts: [String] = []
        for star in level.stars.indices {
            var holds: [String] = []
            for hold in play.timeline.holds where hold.star == star {
                holds.append("holds from tick \(hold.start) for \(ticks(hold.length))")
            }
            let holdWords: String = holds.isEmpty ? "no holds" : holds.joined(separator: " and ")
            let onTarget: Bool = positions[star] == level.stars[star].target
            parts.append(starWords(star) + ": " + level.place(positions[star])
                + ", start phase \(play.timeline.phases[star]), " + holdWords + ", "
                + (onTarget ? "on" : "off") + " its target.")
        }
        return tickText(play) + " " + editsLeft(play.remaining) + ". " + parts.joined(separator: " ")
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily".
    public static func modeName(_ mode: ChronoConstellatorMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// "1 edit left" or "n edits left".
    public static func editsLeft(_ count: Int) -> String { count == 1 ? "1 edit left" : "\(count) edits left" }

    /// "1 edit" or "e edits".
    public static func edits(_ count: Int) -> String { count == 1 ? "1 edit" : "\(count) edits" }

    /// "1 tick" or "l ticks".
    public static func ticks(_ count: Int) -> String { count == 1 ? "1 tick" : "\(count) ticks" }

    /// "Star k (shape)" of the 0-based star `index`: k = `index` + 1 and the shape of
    /// ``ChronoConstellatorLevel/shape(of:)``.
    public static func starWords(_ index: Int) -> String {
        "Star \(index + 1) (\(ChronoConstellatorLevel.shape(of: index).name))"
    }

    /// "Tick t of T." of `play`.
    static func tickText(_ play: ChronoConstellatorPlay) -> String {
        "Tick \(play.tick) of \(play.level.tickLimit)."
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: ChronoConstellatorExperienceCore) -> ChronoConstellatorFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(ChronoConstellatorProgress.band(of: core.levelNumber)), "
            + "\(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return ChronoConstellatorFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The plan of the accepted `record` that took `old` to `new`.
    static func playPlan(old: ChronoConstellatorExperienceCore, new: ChronoConstellatorExperienceCore,
                         record: ChronoConstellatorRecord) -> ChronoConstellatorFeedbackPlan {
        let play: ChronoConstellatorPlay = new.play
        let ended: Bool = play.stage != old.play.stage && (play.stage == .won || play.stage == .failed)
        if ended && play.stage == .won {
            var text: String = "Every star is on its target. Level won with \(edits(play.spent))"
            if new.mode.awardsStars {
                let stars: Int = ChronoConstellatorProgress.stars(edits: play.spent, smallest: new.certifiedSmallest)
                text += ", \(stars) of 3 stars"
            }
            return ChronoConstellatorFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        if ended {
            let text: String = new.failureExplanation?.text ?? ChronoConstellatorFailureExplanation.advice
            return ChronoConstellatorFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
        }
        let left: String = editsLeft(play.remaining) + "."
        let text: String
        switch record.kind {
        case .phase:
            if case .phase(let star, let phase)? = record.action, play.level.stars.indices.contains(star),
               play.level.stars[star].loop.indices.contains(phase) {
                let cell: Int = play.level.stars[star].loop[phase]
                text = starWords(star) + " starts at " + play.level.place(cell) + ". " + left
            } else {
                text = left
            }
        case .hold:
            if case .hold(let star, let start, let length)? = record.action {
                text = "Star \(star + 1) holds from tick \(start) for \(ticks(length)). " + left
            } else {
                text = left
            }
        case .release:
            if case .release(let star, let start)? = record.action {
                text = "Star \(star + 1)'s hold from tick \(start) removed. " + left
            } else {
                text = left
            }
        case .step:
            let positions: [Int] = play.positions
            var onTarget: Int = 0
            for star in play.level.stars.indices where positions[star] == play.level.stars[star].target {
                onTarget += 1
            }
            text = tickText(play) + " \(onTarget) of \(play.level.stars.count) stars on target."
        case .rewind: text = "Rewound to tick 0."
        case .undo: text = "Undone. " + tickText(play) + " " + left
        case .redo: text = "Redone. " + tickText(play) + " " + left
        }
        return ChronoConstellatorFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
