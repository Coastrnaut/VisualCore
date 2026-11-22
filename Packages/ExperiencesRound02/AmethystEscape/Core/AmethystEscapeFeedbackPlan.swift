// AmethystEscapeFeedbackPlan — feature 366 (R02-G07-06) T-R02G0706-003 (FR-R02G0706-001, 002, 003, 005;
// SC-R02G0706-002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of
// Amethyst Escape, as a pure function of the core before and after an accepted action (or of a refusal's reason code),
// and the words of the panel's summary element. The presenter only routes the plan through the shared feedback route
// (the person's haptics switch, the shared planners' rate limits); a plan never changes state. Modelled on feature 356's
// ChronoConstellatorFeedbackPlan.
//
// Words: shells are `AmethystEscapeLevel.shellName(_:)` ("shell 1 (inner)", "shell 2", "shell K (outer)"), capitalised
// when they begin a sentence ("Shell 1 (inner) turned …"); sectors are `AmethystEscapeLevel.sectorName(_:)` ("sector s of
// N", 1-based, absolute); n is the moves LEFT (the play's budget minus the moves spent; "1 move left").
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`) → `level`, "Level n, band b,
//      <campaign|practice|daily>." (b = `AmethystEscapeProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction
//      while the tutorial is shown (not done); no haptic;
//   2. an accepted action: the play gained exactly one record (its kind decides the text) →
//      a new end (the stage became won or failed; Q2: an action that ends the play plans only the outcome):
//        won: `outcome`, "The pearl escaped. Level won in m moves, k of 3 stars." (practice: "The pearl escaped. Level
//             won in m moves."), haptic `success`; k is `AmethystEscapeProgress.stars(moves:smallest:)` of this win
//             against the certified smallest move count;
//        failed: `outcome`, the failure explanation of feature 365, haptic `warning`;
//      a turn: "<Shell> turned one sector clockwise. n moves left." (anticlockwise for the step −1);
//      an advance: "The pearl rolled to <shell>, sector s of N. n moves left.";
//      an undo or redo: "Undone. " or "Redone. " followed by "The pearl is in <shell>, sector s of N. n moves left.";
//      each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``AmethystEscapeFeedbackPlan/none``.
// A multi-sector drag is planned once, after its last turn, by `drag(old:new:shell:sectors:)`: "<Shell> turned k sectors
// clockwise. n moves left." (one selection haptic), or only the outcome when a turn of the drag ended the play.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Amethyst Escape (feature 366, clarifications Q1,
/// Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct AmethystEscapeFeedbackPlan: Sendable, Equatable {
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
    public static let none = AmethystEscapeFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: AmethystEscapeExperienceCore,
                             new: AmethystEscapeExperienceCore) -> AmethystEscapeFeedbackPlan {
        let oldRecords: [AmethystEscapeRecord] = old.play.records
        let newRecords: [AmethystEscapeRecord] = new.play.records
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
            && new.tutorial == AmethystEscapeTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The one plan of a multi-sector drag of shell `shell` (0-based) by `sectors` turns, from `old` (before the drag's
    /// first turn) to `new` (after its last): `state`, "<Shell> turned k sectors clockwise. n moves left." ("one
    /// sector" for k = 1; anticlockwise when the last turn's step is −1), haptic `selection`; only the outcome (as
    /// ``after(old:new:)``) when the drag ended the play; ``none`` when no turn was made; the plan of
    /// ``after(old:new:)`` when `new` does not extend `old`'s play by turns (a level or mode change). Reads only.
    public static func drag(old: AmethystEscapeExperienceCore, new: AmethystEscapeExperienceCore, shell: Int,
                            sectors: Int) -> AmethystEscapeFeedbackPlan {
        let oldRecords: [AmethystEscapeRecord] = old.play.records
        let newRecords: [AmethystEscapeRecord] = new.play.records
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        guard sameLevel, newRecords.count >= oldRecords.count,
              Array(newRecords.prefix(oldRecords.count)) == oldRecords else {
            return after(old: old, new: new)
        }
        guard newRecords.count > oldRecords.count, sectors > 0, let last = newRecords.last else { return .none }
        let play: AmethystEscapePlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        guard play.level.shells.indices.contains(shell) else { return .none }
        var step: Int = 1
        if case .rotate(_, let lastStep)? = last.action { step = lastStep }
        let amount: String = sectors == 1 ? "one sector" : "\(sectors) sectors"
        let text: String = sentence(play.level.shellName(shell)) + " turned " + amount + " "
            + direction(step) + ". " + movesLeft(play.remaining) + "."
        return AmethystEscapeFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }

    /// The plan of a shell pick on the panel's shell picker (presentation only, no state change): `state`, "<Shell>
    /// picked." with the shell of `core`'s level in words, no haptic; ``none`` for a shell the level does not have.
    public static func picked(shell: Int, core: AmethystEscapeExperienceCore) -> AmethystEscapeFeedbackPlan {
        let level: AmethystEscapeLevel = core.play.level
        guard level.shells.indices.contains(shell) else { return .none }
        return AmethystEscapeFeedbackPlan(text: sentence(level.shellName(shell)) + " picked.", kind: .state,
                                          haptic: nil)
    }

    /// The plan of a refused action with reason code `code` (raw, "r02-g07.locked", or prefixed,
    /// "action.rule.r02-g07.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> AmethystEscapeFeedbackPlan {
        AmethystEscapeFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code` (raw or prefixed), also shown by the panel (clarification Q1):
    /// "That level is not open yet." (a code containing `r02-g07.locked`), "That date cannot be used."
    /// (`r02-g07.date`), "That move is not allowed here." (`r02-g07.action`), "A wall stops the pearl: turn a shell
    /// first." (`r02-g07.stuck`), "The level has ended." (`r02-g07.stage`), "That value must be a whole number."
    /// (`r02-g07.not-whole`), otherwise (`r02-g07.stale`, `r02-g07.malformed`, the engine's own codes such as
    /// `action.out-of-range`) "That move was refused.".
    public static func refusalText(code: String) -> String {
        if code.contains(AmethystEscapeExperienceRule.locked) { return "That level is not open yet." }
        if code.contains(AmethystEscapeExperienceRule.date) { return "That date cannot be used." }
        if code.contains(AmethystEscapeError.action("").reasonCode) { return "That move is not allowed here." }
        if code.contains(AmethystEscapeError.stuck.reasonCode) { return "A wall stops the pearl: turn a shell first." }
        if code.contains(AmethystEscapeError.stage.reasonCode) { return "The level has ended." }
        if code.contains(AmethystEscapeExperienceRule.notWhole) { return "That value must be a whole number." }
        return "That move was refused."
    }

    /// The words of the panel's summary element (clarification Q5): "n moves left. The pearl is in <shell>, sector s
    /// of N. The exit gap is at sector e of N. " followed, for every shell innermost first, by its description
    /// (``AmethystEscapeLevel/description(ofShell:)``, capitalised) and ", turned t." (t = the shell's offset, 0 … N −
    /// 1), joined by " ". The exit gap's sector is absolute: the outer shell's exit gap turned by its offset.
    public static func summaryText(core: AmethystEscapeExperienceCore) -> String {
        let play: AmethystEscapePlay = core.play
        let level: AmethystEscapeLevel = play.level
        let offsets: [Int] = play.crystal.offsets
        let exit: Int = ((level.exitGap + offsets[level.outermost]) % level.sectors + level.sectors) % level.sectors
        var parts: [String] = [movesLeft(play.remaining) + ".", "The pearl is in " + pearlWords(play) + ".",
                               "The exit gap is at " + level.sectorName(exit) + "."]
        for shell in level.shells.indices {
            parts.append(sentence(level.description(ofShell: shell)) + ", turned \(offsets[shell]).")
        }
        return parts.joined(separator: " ")
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily".
    public static func modeName(_ mode: AmethystEscapeMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// "1 move left" or "n moves left".
    public static func movesLeft(_ count: Int) -> String { count == 1 ? "1 move left" : "\(count) moves left" }

    /// "1 move" or "m moves".
    public static func moves(_ count: Int) -> String { count == 1 ? "1 move" : "\(count) moves" }

    /// "clockwise" for a positive step, "anticlockwise" otherwise.
    static func direction(_ step: Int) -> String { step > 0 ? "clockwise" : "anticlockwise" }

    /// `text` with its first character upper-cased (a sentence that begins with a shell name).
    static func sentence(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// "<shell>, sector s of N" of the pearl's pocket in `play`.
    static func pearlWords(_ play: AmethystEscapePlay) -> String {
        play.level.shellName(play.crystal.pearl.shell) + ", " + play.level.sectorName(play.crystal.pearl.sector)
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: AmethystEscapeExperienceCore) -> AmethystEscapeFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(AmethystEscapeProgress.band(of: core.levelNumber)), "
            + "\(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return AmethystEscapeFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its moves (and stars outside practice), haptic
    /// `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: AmethystEscapeExperienceCore) -> AmethystEscapeFeedbackPlan {
        let play: AmethystEscapePlay = core.play
        if play.stage == .won {
            var text: String = "The pearl escaped. Level won in " + moves(play.moves)
            if core.mode.awardsStars {
                let stars: Int = AmethystEscapeProgress.stars(moves: play.moves, smallest: core.certifiedSmallest)
                text += ", \(stars) of 3 stars"
            }
            return AmethystEscapeFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = core.failureExplanation?.text ?? AmethystEscapeFailureExplanation.advice
        return AmethystEscapeFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The plan of the accepted `record` that took `old` to `new`.
    static func playPlan(old: AmethystEscapeExperienceCore, new: AmethystEscapeExperienceCore,
                         record: AmethystEscapeRecord) -> AmethystEscapeFeedbackPlan {
        let play: AmethystEscapePlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let left: String = movesLeft(play.remaining) + "."
        let text: String
        switch record.kind {
        case .rotate:
            if case .rotate(let shell, let step)? = record.action, play.level.shells.indices.contains(shell) {
                text = sentence(play.level.shellName(shell)) + " turned one sector " + direction(step) + ". " + left
            } else {
                text = left
            }
        case .advance: text = "The pearl rolled to " + pearlWords(play) + ". " + left
        case .undo: text = "Undone. The pearl is in " + pearlWords(play) + ". " + left
        case .redo: text = "Redone. The pearl is in " + pearlWords(play) + ". " + left
        }
        return AmethystEscapeFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
