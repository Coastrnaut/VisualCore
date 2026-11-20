// AuroraLoomFeedbackPlan — feature 306 (R02-G01-06) T-R02G0106-003 (FR-R02G0106-002, FR-R02G0106-003; clarifications
// Q1, Q2; research R1; contracts/api.md). The VoiceOver announcement and the haptic of one change of Aurora Loom, as a
// pure function of the core before and after an accepted action (or of a refusal's reason code). The presenter only
// routes the plan through the shared feedback route (the person's haptics switch, the shared planners' rate limits);
// a plan never changes state.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, also of the same level) →
//      `level`, "Level n, band b, <Campaign|Practice|Daily level>." plus " " and the tutorial instruction while the
//      tutorial is shown; no haptic;
//   2. an accepted move, undo or redo: the play gained exactly one record (its kind gives the prefix), or, after a
//      failure, undo rewound the failing move (its records lost the last one; prefix "Undone: ", the ribbon and control
//      of the rewound record) →
//      won: `outcome`, "Harmony. Level won in m moves, k of 3 stars." (practice: "Harmony. Practice won in m moves."),
//           haptic `success` — the outcome replaces the move's selection (Q2); k is this win's stars,
//           `AuroraLoomProgress.stars(moves:shortest:)` against the certified shortest, which is what the core records
//           for it (an earlier better result may keep more stars in the progress);
//      failed: `outcome`, the failure explanation, haptic `warning`;
//      otherwise: `state`, "<prefix>Ribbon r wave s. g of 12 gate crossings in harmony. Moves m of n." (phase
//           likewise), r numbered from 1, s the control's current step (after an undo, the restored one), g the lit
//           crossings of `snapshot(time: 0)`, m the moves spent, n the allowance; haptic `selection`;
//   3. only the tutorial changed and is now done (`tutorial.dismiss`) → `state`, "Tutorial skipped."; no haptic;
//   4. otherwise ``AuroraLoomFeedbackPlan/none``.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Aurora Loom (feature 306, clarifications Q1, Q2).
/// Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct AuroraLoomFeedbackPlan: Sendable, Equatable {
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
    public static let none = AuroraLoomFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The number of gate crossings: three ribbons at four gates.
    public static let crossingCount = 12

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: AuroraLoomExperienceCore, new: AuroraLoomExperienceCore)
        -> AuroraLoomFeedbackPlan {
        let oldRecords: [AuroraLoomRecord] = old.play.records
        let newRecords: [AuroraLoomRecord] = new.play.records
        let extended: Bool = newRecords.count == oldRecords.count + 1
            && Array(newRecords.dropLast()) == oldRecords
        let rewound: Bool = old.play.stage == .failed && !oldRecords.isEmpty
            && newRecords == Array(oldRecords.dropLast())
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        if !sameLevel || (old.play != new.play && !extended && !rewound) {
            return levelPlan(new)
        }
        if extended, let record = newRecords.last {
            return playPlan(new, ribbon: record.ribbon, control: record.control, kind: record.kind)
        }
        if rewound, let record = oldRecords.last {
            return playPlan(new, ribbon: record.ribbon, control: record.control, kind: .undo)
        }
        if old.play == new.play && old.tutorial != new.tutorial {
            if new.tutorial == .done {
                return AuroraLoomFeedbackPlan(text: "Tutorial skipped.", kind: .state, haptic: nil)
            }
            // The same level opened afresh with its tutorial shown again (for example `mode.campaign` of an
            // untouched tutorial level after a dismissal).
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code`: kind `rejection`, haptic `error`, and the text
    /// "That level is not open yet." (a code containing `r02-g01.locked`), "That date is not a calendar date."
    /// (`r02-g01.date`), "No moves are left." (`r02-g01.allowance`), otherwise "That move was refused.".
    public static func refused(code: String) -> AuroraLoomFeedbackPlan {
        let text: String
        if code.contains(AuroraLoomExperienceRule.locked) {
            text = "That level is not open yet."
        } else if code.contains(AuroraLoomExperienceRule.date) {
            text = "That date is not a calendar date."
        } else if code.contains(AuroraLoomError.allowance.reasonCode) {
            text = "No moves are left."
        } else {
            text = "That move was refused."
        }
        return AuroraLoomFeedbackPlan(text: text, kind: .rejection, haptic: .error)
    }

    /// The name of a mode in a level announcement: "Campaign", "Practice", "Daily level" or "Replay".
    public static func modeName(_ mode: AuroraLoomMode) -> String {
        switch mode {
        case .campaign: "Campaign"
        case .practice: "Practice"
        case .daily: "Daily level"
        case .replay: "Replay"
        }
    }

    /// The gate crossings in harmony that `core` shows at frame time 0 (0 … 12).
    public static func litCrossings(_ core: AuroraLoomExperienceCore) -> Int {
        let snapshot: AuroraLoomSceneSnapshot = core.snapshot(time: 0)
        var lit: Int = 0
        for ribbon in 0..<3 {
            for gate in 0..<snapshot.level.gates.count where snapshot.lit(ribbon: ribbon, gate: gate) {
                lit += 1
            }
        }
        return lit
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is shown.
    static func levelPlan(_ core: AuroraLoomExperienceCore) -> AuroraLoomFeedbackPlan {
        let number: Int = core.levelNumber
        var text: String = "Level \(number), band \(AuroraLoomProgress.band(of: number)), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return AuroraLoomFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The plan of an accepted move, undo or redo of `control` of `ribbon` that left `core`.
    static func playPlan(_ core: AuroraLoomExperienceCore, ribbon: Int, control: AuroraLoomControl,
                         kind: AuroraLoomRecordKind) -> AuroraLoomFeedbackPlan {
        let spent: Int = core.play.spent
        switch core.play.stage {
        case .won:
            let text: String
            if core.mode == .practice {
                text = "Harmony. Practice won in \(spent) moves."
            } else {
                let stars: Int = AuroraLoomProgress.stars(moves: spent, shortest: core.certifiedShortest)
                text = "Harmony. Level won in \(spent) moves, \(stars) of 3 stars."
            }
            return AuroraLoomFeedbackPlan(text: text, kind: .outcome, haptic: .success)
        case .failed:
            let text: String = core.failureExplanation?.text ?? "The moves are spent without harmony. Undo or retry."
            return AuroraLoomFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
        default:
            let prefix: String
            switch kind {
            case .move: prefix = ""
            case .undo: prefix = "Undone: "
            case .redo: prefix = "Redone: "
            }
            let step: Int = control == .wave ? core.play.steps.wave[ribbon] : core.play.steps.phase[ribbon]
            let text: String = "\(prefix)Ribbon \(ribbon + 1) \(control.rawValue) \(step). "
                + "\(litCrossings(core)) of \(crossingCount) gate crossings in harmony. "
                + "Moves \(spent) of \(core.play.level.allowance)."
            return AuroraLoomFeedbackPlan(text: text, kind: .state, haptic: .selection)
        }
    }
}
