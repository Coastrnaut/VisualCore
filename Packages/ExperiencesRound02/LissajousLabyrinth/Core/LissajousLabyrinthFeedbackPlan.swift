// LissajousLabyrinthFeedbackPlan — feature 316 (R02-G02-06) T-R02G0206-002 (FR-R02G0206-002, 003; clarifications
// Q1, Q2; research R1, R2). The VoiceOver announcement and the haptic of one change of Lissajous Labyrinth, as a pure
// function of the core before and after an accepted action (or of a refusal's reason code). The presenter only routes
// the plan through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan
// never changes state.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, also of the same level) →
//      `level`, "Level n, band b, <campaign|practice|daily level>." (b = (n − 1) / 20 + 1) plus " " and the tutorial
//      instruction while the tutorial is shown; no haptic;
//   2. an accepted action, undo or redo: the play gained exactly one record (its kind gives the prefix and its dial the
//      dial named), or, after a failure, undo rewound the failing action (the records lost the last one; prefix
//      "Undone: ", the dial of the rewound record) →
//      won: `outcome`, "The path is safe. Level won in s actions, k of 3 stars." ("1 action" for one) (practice: "The path is safe. Level
//           won in s actions."), haptic `success` — the outcome replaces the action's selection (Q2); k is
//           `LissajousLabyrinthProgress.stars(actions:shortest:)` of this win against the certified shortest;
//      failed: `outcome`, the failure explanation of feature 315, haptic `warning`;
//      otherwise: `state`, "<prefix><Dial> <value>. v of n checkpoints in order. Actions s of a." plus " The path
//           touches obstacle k." while the lap touches obstacle k (numbered from 1); the value is the dial's current
//           value (after an undo, the restored one), v the checkpoints visited in order by `snapshot(time: 0)`, n the
//           level's checkpoints, s the actions spent, a the allowance; haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again (for example `mode.campaign` on a tutorial level
//      after a dismissal) → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`, `tutorial.hint`) →
//      ``LissajousLabyrinthFeedbackPlan/none``.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Lissajous Labyrinth (feature 316, clarifications
/// Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct LissajousLabyrinthFeedbackPlan: Sendable, Equatable {
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
    public static let none = LissajousLabyrinthFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: LissajousLabyrinthExperienceCore, new: LissajousLabyrinthExperienceCore)
        -> LissajousLabyrinthFeedbackPlan {
        let oldRecords: [LissajousLabyrinthRecord] = old.play.records
        let newRecords: [LissajousLabyrinthRecord] = new.play.records
        let extended: Bool = newRecords.count == oldRecords.count + 1
            && Array(newRecords.dropLast()) == oldRecords
        let rewound: Bool = old.play.stage == .failed && !oldRecords.isEmpty
            && newRecords == Array(oldRecords.dropLast())
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        if !sameLevel || (old.play != new.play && !extended && !rewound) {
            return levelPlan(new)
        }
        if extended, let record = newRecords.last {
            return playPlan(new, dial: record.dial, kind: record.kind)
        }
        if rewound, let record = oldRecords.last {
            return playPlan(new, dial: record.dial, kind: .undo)
        }
        if old.play == new.play && old.tutorial != new.tutorial, case .turn = new.tutorial, newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// "1 action" or "n actions".
    static func actions(_ count: Int) -> String { count == 1 ? "1 action" : "\(count) actions" }

    /// The plan of a refused action with reason code `code` (raw, "r02-g02.locked", or prefixed,
    /// "action.rule.r02-g02.locked"): kind `rejection`, haptic `error`, and the text "That level is not open yet."
    /// (a code containing `r02-g02.locked`), "That date cannot be used." (`r02-g02.date`), "That change is not allowed:
    /// the frequencies must share no factor, and a dial must change." (`r02-g02.move`), "No actions are left."
    /// (`r02-g02.allowance`), "The level has ended." (`r02-g02.stage`), otherwise "That change was refused.".
    public static func refused(code: String) -> LissajousLabyrinthFeedbackPlan {
        let text: String
        if code.contains(LissajousLabyrinthExperienceRule.locked) {
            text = "That level is not open yet."
        } else if code.contains(LissajousLabyrinthExperienceRule.date) {
            text = "That date cannot be used."
        } else if code.contains(LissajousLabyrinthError.move("").reasonCode) {
            text = "That change is not allowed: the frequencies must share no factor, and a dial must change."
        } else if code.contains(LissajousLabyrinthError.allowance.reasonCode) {
            text = "No actions are left."
        } else if code.contains(LissajousLabyrinthError.stage.reasonCode) {
            text = "The level has ended."
        } else {
            text = "That change was refused."
        }
        return LissajousLabyrinthFeedbackPlan(text: text, kind: .rejection, haptic: .error)
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily level".
    public static func modeName(_ mode: LissajousLabyrinthMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily level"
        }
    }

    /// The band of manifest level `number`: (number − 1) / 20 + 1, so levels 1 … 20 are band 1 and 81 … 100 band 5.
    public static func band(of number: Int) -> Int {
        (number - 1) / 20 + 1
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is shown.
    static func levelPlan(_ core: LissajousLabyrinthExperienceCore) -> LissajousLabyrinthFeedbackPlan {
        let number: Int = core.levelNumber
        var text: String = "Level \(number), band \(band(of: number)), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return LissajousLabyrinthFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The plan of an accepted action, undo or redo of `dial` that left `core`.
    static func playPlan(_ core: LissajousLabyrinthExperienceCore, dial: LissajousLabyrinthDial,
                         kind: LissajousLabyrinthRecordKind) -> LissajousLabyrinthFeedbackPlan {
        let spent: Int = core.play.spent
        switch core.play.stage {
        case .won:
            let text: String
            if core.mode == .practice {
                text = "The path is safe. Level won in \(Self.actions(spent))."
            } else {
                let stars: Int = LissajousLabyrinthProgress.stars(actions: spent, shortest: core.certifiedShortest)
                text = "The path is safe. Level won in \(Self.actions(spent)), \(stars) of 3 stars."
            }
            return LissajousLabyrinthFeedbackPlan(text: text, kind: .outcome, haptic: .success)
        case .failed:
            let text: String = core.failureExplanation?.text
                ?? "The actions are spent without a safe path. Undo the last change or retry the level."
            return LissajousLabyrinthFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
        default:
            let prefix: String
            switch kind {
            case .action: prefix = ""
            case .undo: prefix = "Undone: "
            case .redo: prefix = "Redone: "
            }
            let snapshot: LissajousLabyrinthSceneSnapshot = core.snapshot(time: 0)
            var text: String = "\(prefix)\(LissajousLabyrinthHint.title(dial)) \(core.play.dials[dial]). "
                + "\(snapshot.visits.count) of \(snapshot.level.checkpoints.count) checkpoints in order. "
                + "Actions \(spent) of \(core.play.level.allowance)."
            if let obstacle = snapshot.contactObstacle {
                text += " The path touches obstacle \(obstacle + 1)."
            }
            return LissajousLabyrinthFeedbackPlan(text: text, kind: .state, haptic: .selection)
        }
    }
}
