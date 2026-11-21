// HueCompassFeedbackPlan — feature 336 (R02-G04-06) T-R02G0406-002 (FR-R02G0406-002, 003, 005; SC-R02G0406-002;
// clarifications Q1, Q2, Q5). The VoiceOver announcement and haptic of one change of Hue Compass, as a pure function
// of the core before and after an accepted action (or of a refusal's reason code), and the words of the panel's summary
// element. The presenter only routes the plan through the shared feedback route (the user's haptics switch, the shared
// planners' rate limits); a plan never changes state. Modelled on feature 326's WaveKnotKeeperFeedbackPlan.
//
// Numbers: b is the bearing 0 … 95 as the kernel holds it; h is the hue band of that bearing as shown, 1 … 24 (the
// kernel's band 0 … 23 plus one); L is the units LEFT (the allowance a minus `HueCompassPlay.spent`, the units spent by
// probes and the selection), as FR-R02G0406-002 asks (convergence task T-R02G0406-015); the win names the units spent.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, also of the same level) →
//      `level`, "Level n, band b, <Campaign|Practice|Daily level>." (b = the difficulty band 1 … 5) plus " " and
//      the tutorial instruction while the tutorial is not done; no haptic;
//   2. an accepted action: the play gained exactly one record (its kind decides the text) →
//      won: `outcome`, "The bearing and band match. Level won with s units, k of 3 stars." (practice: "The bearing and
//           band match. Level won with s units."), haptic `success`; k is `HueCompassProgress.stars(units:smallest:)`
//           of this win against the certified smallest probe count;
//      failed: `outcome`, the failure explanation of feature 335, haptic `warning`. A selection, or a probe that spent
//           the last unit, plans only the outcome (Q2: the outcome is never dropped behind a selection haptic);
//      a probe: `state`, "Probe at bearing b: hue gap g bands, fog depth d. Units left L of a.", haptic `selection`;
//      a turn, undo or redo: `state`, "<prefix>Bearing b of 96, band h. Units left L of a." with the prefix "", "Undone: "
//           or "Redone: ", haptic `selection`; b and h are the bearing after the action;
//   3. the same untouched play reopened with its tutorial shown again (for example `mode.campaign` on a tutorial level
//      after a dismissal) → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``HueCompassFeedbackPlan/none``.
// A count of 1 takes the singular noun ("hue gap 1 band", "Level won with 1 unit"); "Units left L of a." is kept as it is.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Hue Compass (feature 336, clarifications Q1, Q2).
/// Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct HueCompassFeedbackPlan: Sendable, Equatable {
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
    public static let none = HueCompassFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: HueCompassExperienceCore, new: HueCompassExperienceCore) -> HueCompassFeedbackPlan {
        let oldRecords: [HueCompassRecord] = old.play.records
        let newRecords: [HueCompassRecord] = new.play.records
        let extended: Bool = newRecords.count == oldRecords.count + 1
            && Array(newRecords.dropLast()) == oldRecords
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        if !sameLevel || (old.play != new.play && !extended) {
            return levelPlan(new)
        }
        if extended, let record = newRecords.last {
            return playPlan(new, kind: record.kind)
        }
        if old.play == new.play && old.tutorial != new.tutorial && new.tutorial == .aim && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a band pick on the panel's stepper (presentation only, no state change): `state`, "Band h picked."
    /// with h = `band` + 1 (the kernel's band 0 … 23 shown 1 … 24), no haptic.
    public static func picked(band: Int) -> HueCompassFeedbackPlan {
        HueCompassFeedbackPlan(text: "Band \(band + 1) picked.", kind: .state, haptic: nil)
    }

    /// The plan of a refused action with reason code `code` (raw, "r02-g04.locked", or prefixed,
    /// "action.rule.r02-g04.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> HueCompassFeedbackPlan {
        HueCompassFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code` (raw or prefixed), also shown by the panel: "That level is not
    /// open yet." (a code containing `r02-g04.locked`), "That date cannot be used." (`r02-g04.date`), "That action is
    /// not allowed here." (`r02-g04.action`), "No units are left." (`r02-g04.allowance`), "The level has ended."
    /// (`r02-g04.stage`), "That value must be a whole number." (`r02-g04.not-whole`), feature 337's "There is no saved
    /// solution to replay for this level." (`r02-g04.no-replay`), "The replay is over." (`r02-g04.replay-end`) and
    /// "Stop the replay first." (`r02-g04.replay`), otherwise "That change was refused.".
    public static func refusalText(code: String) -> String {
        if code.contains(HueCompassExperienceRule.noReplay) {
            return "There is no saved solution to replay for this level."
        }
        // Checked before `replay`, whose code is a prefix of `replay-end` (feature 337).
        if code.contains(HueCompassExperienceRule.replayEnd) { return "The replay is over." }
        if code.contains(HueCompassExperienceRule.replay) { return "Stop the replay first." }
        if code.contains(HueCompassExperienceRule.locked) { return "That level is not open yet." }
        if code.contains(HueCompassExperienceRule.date) { return "That date cannot be used." }
        if code.contains(HueCompassExperienceRule.notWhole) { return "That value must be a whole number." }
        if code.contains(HueCompassError.action("").reasonCode) { return "That action is not allowed here." }
        if code.contains(HueCompassError.allowance.reasonCode) { return "No units are left." }
        if code.contains(HueCompassError.stage.reasonCode) { return "The level has ended." }
        return "That change was refused."
    }

    /// The words of the panel's summary element (clarification Q5): "Bearing b, band h. Units left L of a. Last clue: hue
    /// gap g bands, fog depth d." with the latest clue, or "Bearing b, band h. Units left L of a. No clues yet." before any
    /// probe (b the bearing 0 … 95, h its band shown 1 … 24, L the units left of the allowance a; "1 band" for g = 1).
    public static func summaryText(core: HueCompassExperienceCore) -> String {
        let play: HueCompassPlay = core.play
        var text: String = "Bearing \(play.bearing), band \(play.level.band(of: play.bearing) + 1). "
            + "Units left \(play.level.allowance - play.spent) of \(play.level.allowance)."
        if let clue = play.clues.last {
            text += " Last clue: hue gap \(bands(clue.hueGap)), fog depth \(clue.depth)."
        } else {
            text += " No clues yet."
        }
        return text
    }

    /// The name of a mode in a level announcement: "Campaign", "Practice" or "Daily level".
    public static func modeName(_ mode: HueCompassMode) -> String {
        switch mode {
        case .campaign: "Campaign"
        case .practice: "Practice"
        case .daily: "Daily level"
        case .replay: "Replay"
        }
    }

    /// "1 band" or "g bands".
    public static func bands(_ count: Int) -> String { count == 1 ? "1 band" : "\(count) bands" }

    /// "1 unit" or "s units".
    public static func units(_ count: Int) -> String { count == 1 ? "1 unit" : "\(count) units" }

    /// The turn text of `core`'s play: "Bearing b of 96, band h. Units left L of a."
    public static func turnText(_ core: HueCompassExperienceCore) -> String {
        let play: HueCompassPlay = core.play
        return "Bearing \(play.bearing) of \(HueCompassWheel.bearings), "
            + "band \(play.level.band(of: play.bearing) + 1). Units left \(play.level.allowance - play.spent) of \(play.level.allowance)."
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: HueCompassExperienceCore) -> HueCompassFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(core.play.level.band), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return HueCompassFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The plan of an accepted action of `kind` that left `core`.
    static func playPlan(_ core: HueCompassExperienceCore, kind: HueCompassRecordKind) -> HueCompassFeedbackPlan {
        let play: HueCompassPlay = core.play
        let spent: Int = play.spent
        switch play.stage {
        case .won:
            var text: String = "The bearing and band match. Level won with \(units(spent))"
            // A replayed win re-runs a stored result and claims no stars (feature 337), like practice.
            if core.mode.awardsStars {
                let stars: Int = HueCompassProgress.stars(units: spent, smallest: core.certifiedSmallest)
                text += ", \(stars) of 3 stars"
            }
            return HueCompassFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        case .failed:
            let text: String = core.failureExplanation?.text ?? "The level failed. Retry the level."
            return HueCompassFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
        default:
            let text: String
            switch kind {
            case .probe:
                if let clue = play.clues.last {
                    text = "Probe at bearing \(clue.bearing): hue gap \(bands(clue.hueGap)), fog depth \(clue.depth). "
                        + "Units left \(play.level.allowance - spent) of \(play.level.allowance)."
                } else {
                    text = turnText(core)
                }
            case .undo: text = "Undone: " + turnText(core)
            case .redo: text = "Redone: " + turnText(core)
            case .turn, .select: text = turnText(core)
            }
            return HueCompassFeedbackPlan(text: text, kind: .state, haptic: .selection)
        }
    }
}
