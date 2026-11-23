// BackwardsAuroraFeedbackPlan — feature 396 (R02-G10-06) T-R02G1006-003 (FR-R02G1006-001, 002, 003, 005;
// SC-R02G1006-002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of
// Backwards Aurora, as a pure function of the core before and after an accepted action (or of a refusal's reason code,
// or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes the plan
// through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never
// changes state. Modelled on feature 386's NocturneGardenFeedbackPlan.
//
// Words: positions are the sample positions the panel names (0-based, as `BackwardsAuroraLevel.sampleName(_:wave:)`
// does); checkpoints are 1-based in position order (`BackwardsAuroraLevel.checkpointName(_:wave:)`). The measure that
// follows every accepted reversal, undo and redo is "Checkpoints matched k of n; worst bend w of limit L. m reversals
// left." (k the checkpoints at their true height, n the level's checkpoints, w the wave's worst bend, L the bend limit,
// m the reversals left with `BackwardsAuroraLevel.reversalsText(_:)`, "1 reversal left").
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`) → `level`, "Level n, band b,
//      <campaign|practice|daily>." (b = `BackwardsAuroraProgress.band(of:)` 1 … 5) plus " " and the tutorial
//      instruction while the tutorial is shown (not done); no haptic;
//   2. an accepted action: the play gained exactly one record (its kind decides the text) →
//      a new end (the stage became won or failed; Q2: a reversal or redo that ends the play plans only the outcome):
//        won: `outcome`, "Every checkpoint matches and every bend is within the limit. Level won with m reversals
//             made, k of 3 stars." (practice: "… Level won with m reversals made."), haptic `success`; m is
//             `BackwardsAuroraProgress.reversalsMade(_:)` (undone reversals included; "1 reversal made") and k is
//             `BackwardsAuroraProgress.stars(reversalsMade:smallest:)` of this win against the certified smallest
//             count (the stars this win earned, consistent with m; the progress keeps the better stored result);
//        failed: `outcome`, the failure explanation of feature 395 (`BackwardsAuroraFailureExplanation`), haptic
//             `warning`;
//      a reversal: "Reversed samples i to j."; an undo or redo: "Undone." or "Redone."; each followed by a space and
//      the measure, each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``BackwardsAuroraFeedbackPlan/none``.
// Changes of the section's ends and the freeze preview are presentation only and plan nothing: the adjustable ends speak
// their own values and the preview is described in the panel. A revealed hint is `hint(text:)`: `state` with the hint's
// words and no haptic. This file holds no floating-point value, so the kernel scan of the invariant tests covers it.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Backwards Aurora (feature 396, clarifications Q1,
/// Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct BackwardsAuroraFeedbackPlan: Sendable, Equatable {
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
    public static let none = BackwardsAuroraFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "Every checkpoint matches and every bend is within the limit."
    public static let wonText: String = "Every checkpoint matches and every bend is within the limit."

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: BackwardsAuroraExperienceCore,
                             new: BackwardsAuroraExperienceCore) -> BackwardsAuroraFeedbackPlan {
        let oldRecords: [BackwardsAuroraRecord] = old.play.records
        let newRecords: [BackwardsAuroraRecord] = new.play.records
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
            && new.tutorial == BackwardsAuroraTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (raw, "r02-g10.locked", or prefixed,
    /// "action.rule.r02-g10.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> BackwardsAuroraFeedbackPlan {
        BackwardsAuroraFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code` (raw or prefixed), also shown by the panel (clarification Q1):
    /// "That level is not open yet." (a code containing `r02-g10.locked`), "That date cannot be used."
    /// (`r02-g10.date`), "That section cannot be reversed here." (`r02-g10.action`), "That section reads the same both
    /// ways; reversing it changes nothing." (`r02-g10.noop`), "The level has ended." (`r02-g10.stage`), "That value must
    /// be a whole number." (`r02-g10.not-whole`), otherwise (`r02-g10.stale`, `r02-g10.malformed`, the engine's own
    /// codes such as `action.out-of-range`) "That reversal was refused."; feature 397 adds "There is no saved
    /// solution to replay for this level." (`r02-g10.no-replay`), "The replay is over." (`r02-g10.replay-end`) and "Stop
    /// the replay first." (`r02-g10.replay`).
    public static func refusalText(code: String) -> String {
        // Feature 397: the replay codes; `no-replay` and `replay-end` first, since both contain `r02-g10.replay`.
        if code.contains(BackwardsAuroraExperienceRule.noReplay) {
            return "There is no saved solution to replay for this level."
        }
        if code.contains(BackwardsAuroraExperienceRule.replayEnd) { return "The replay is over." }
        if code.contains(BackwardsAuroraExperienceRule.replay) { return "Stop the replay first." }
        if code.contains(BackwardsAuroraExperienceRule.locked) { return "That level is not open yet." }
        if code.contains(BackwardsAuroraExperienceRule.date) { return "That date cannot be used." }
        if code.contains(BackwardsAuroraError.action("").reasonCode) { return "That section cannot be reversed here." }
        if code.contains(BackwardsAuroraError.noop.reasonCode) {
            return "That section reads the same both ways; reversing it changes nothing."
        }
        if code.contains(BackwardsAuroraError.stage.reasonCode) { return "The level has ended." }
        if code.contains(BackwardsAuroraExperienceRule.notWhole) { return "That value must be a whole number." }
        return "That reversal was refused."
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> BackwardsAuroraFeedbackPlan {
        BackwardsAuroraFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "m reversals left. Checkpoints matched k of n; worst
    /// bend w of limit L, breaking limit B. Section i to j, n samples. Checkpoints: <each checkpoint in words, joined by
    /// "; ">. Level: <the level in words>." (each checkpoint is ``BackwardsAuroraLevel/checkpointName(_:wave:)``, the
    /// level ``BackwardsAuroraLevel/targetDescription()``; the section's sample count is `sectionEnd − sectionStart + 1`,
    /// "1 sample" when it is one, as chosen in the panel and not checked against the level).
    public static func summaryText(core: BackwardsAuroraExperienceCore, sectionStart: Int,
                                   sectionEnd: Int) -> String {
        let play: BackwardsAuroraPlay = core.play
        let level: BackwardsAuroraLevel = play.level
        var names: [String] = []
        for index in level.checkpoints.indices {
            names.append(level.checkpointName(index, wave: play.wave))
        }
        let checkpoints: String = names.isEmpty ? "none" : names.joined(separator: "; ")
        let count: Int = sectionEnd - sectionStart + 1
        let samples: String = count == 1 ? "1 sample" : "\(count) samples"
        return BackwardsAuroraLevel.reversalsText(play.remaining) + ". " + matchAndBend(play) + ", breaking limit "
            + String(level.breakingLimit) + ". Section " + String(sectionStart) + " to " + String(sectionEnd) + ", "
            + samples + ". Checkpoints: " + checkpoints + ". Level: " + level.targetDescription() + "."
    }

    /// The name of a mode in a level announcement: "campaign", "practice", "daily" or "replay".
    public static func modeName(_ mode: BackwardsAuroraMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// "1 reversal" or "m reversals".
    public static func reversals(_ count: Int) -> String { count == 1 ? "1 reversal" : "\(count) reversals" }

    /// "Checkpoints matched k of n; worst bend w of limit L" of `play` (no full stop).
    static func matchAndBend(_ play: BackwardsAuroraPlay) -> String {
        let matched: Int = play.matched.filter { $0 }.count
        return "Checkpoints matched " + String(matched) + " of " + String(play.level.checkpoints.count)
            + "; worst bend " + String(play.worstBend) + " of limit " + String(play.level.bendLimit)
    }

    /// The measure after an accepted reversal, undo or redo: "Checkpoints matched k of n; worst bend w of limit L. m
    /// reversals left." of `play`.
    static func measure(_ play: BackwardsAuroraPlay) -> String {
        matchAndBend(play) + ". " + BackwardsAuroraLevel.reversalsText(play.remaining) + "."
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: BackwardsAuroraExperienceCore) -> BackwardsAuroraFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(BackwardsAuroraProgress.band(of: core.levelNumber)), "
            + "\(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return BackwardsAuroraFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its reversals made (and stars outside practice), haptic
    /// `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: BackwardsAuroraExperienceCore) -> BackwardsAuroraFeedbackPlan {
        let play: BackwardsAuroraPlay = core.play
        if play.stage == .won {
            let made: Int = BackwardsAuroraProgress.reversalsMade(play)
            var text: String = wonText + " Level won with " + reversals(made) + " made"
            if core.mode.awardsStars {
                let stars: Int = BackwardsAuroraProgress.stars(reversalsMade: made, smallest: core.certifiedSmallest)
                text += ", \(stars) of 3 stars"
            }
            return BackwardsAuroraFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = BackwardsAuroraFailureExplanation(play: play)?.text
            ?? BackwardsAuroraFailureExplanation.advice
        return BackwardsAuroraFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The plan of the accepted `record` that took `old` to `new`.
    static func playPlan(old: BackwardsAuroraExperienceCore, new: BackwardsAuroraExperienceCore,
                         record: BackwardsAuroraRecord) -> BackwardsAuroraFeedbackPlan {
        let play: BackwardsAuroraPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String
        switch record.kind {
        case .undo: first = "Undone."
        case .redo: first = "Redone."
        case .reverse:
            switch record.action {
            case let .reverse(start, end)?:
                first = "Reversed samples " + String(start) + " to " + String(end) + "."
            case nil:
                first = ""
            }
        }
        let text: String = first.isEmpty ? measure(play) : first + " " + measure(play)
        return BackwardsAuroraFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
