// WaveKnotKeeperFeedbackPlan — feature 326 (R02-G03-06) T-R02G0306-002 (FR-R02G0306-002, 003; SC-R02G0306-002;
// clarifications Q1, Q2). The VoiceOver announcement and the haptic of one change of Wave Knot Keeper, as a pure function
// of the core before and after an accepted action (or of a refusal's reason code). The presenter only routes the plan
// through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never
// changes state. Modelled on feature 316's LissajousLabyrinthFeedbackPlan.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by a fresh one
//      (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, also of the same level) →
//      `level`, "Level n, band b, <Campaign|Practice|Daily level>." (b = (n − 1) / 20 + 1) plus " " and the tutorial
//      instruction while the tutorial is not done; no haptic;
//   2. an accepted move, undo or redo: the play gained exactly one record (its kind gives the prefix, its point and
//      direction the move named), or, after a failure, undo rewound the failing move (the records lost the last one;
//      prefix "Undone: ", the rewound move) →
//      won: `outcome`, "The knot matches. Level won in s moves, k of 3 stars." (practice: "The knot matches. Level won
//           in s moves."), haptic `success` — the outcome replaces the move's selection haptic (Q2); k is
//           `WaveKnotKeeperProgress.stars(moves:shortest:)` of this win against the certified shortest;
//      failed: `outcome`, the failure explanation of feature 325, haptic `warning`;
//      otherwise: `state`, "<prefix>Point n moved <direction>. c crossings, writhe w; target C, W. Moves s of a.",
//           haptic `selection`. n is the 1-based point; the direction is right, left, up, down, over or under (+x, −x,
//           +y, −y, +z, −z) and always names the move itself: for an undo, the direction of the move that was undone
//           (not the step back); c and w are the current projection's crossings and writhe, C and W the target's, s the
//           moves spent, a the allowance. For a degenerate projection the counts read "Two strands overlap in the view.
//           Target C crossings, writhe W." instead of "c crossings, writhe w; target C, W.";
//   3. the same untouched play reopened with its tutorial shown again (for example `mode.campaign` on a tutorial level
//      after a dismissal) → the `level` plan of case 1;
//   4. only the selection changed to a point (`point.select`) → `state`, "Point n selected.", no haptic;
//   5. otherwise (nothing changed, the selection cleared, or only the tutorial step moved: `tutorial.dismiss`,
//      `tutorial.hint`) → ``WaveKnotKeeperFeedbackPlan/none``.
// A count of 1 takes the singular noun ("1 crossing", "Target 1 crossing", "Level won in 1 move"); "Moves s of a." is
// kept as it is.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Wave Knot Keeper (feature 326, clarifications
/// Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct WaveKnotKeeperFeedbackPlan: Sendable, Equatable {
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
    public static let none = WaveKnotKeeperFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: WaveKnotKeeperExperienceCore, new: WaveKnotKeeperExperienceCore)
        -> WaveKnotKeeperFeedbackPlan {
        let oldRecords: [WaveKnotKeeperRecord] = old.play.records
        let newRecords: [WaveKnotKeeperRecord] = new.play.records
        let extended: Bool = newRecords.count == oldRecords.count + 1
            && Array(newRecords.dropLast()) == oldRecords
        let rewound: Bool = old.play.stage == .failed && !oldRecords.isEmpty
            && newRecords == Array(oldRecords.dropLast())
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        if !sameLevel || (old.play != new.play && !extended && !rewound) {
            return levelPlan(new)
        }
        if extended, let record = newRecords.last {
            // An undo record holds the step back; the announcement names the move that was undone.
            let direction: WaveKnotKeeperDirection = record.kind == .undo ? record.direction.opposite : record.direction
            return playPlan(new, point: record.point, direction: direction, kind: record.kind)
        }
        if rewound, let record = oldRecords.last {
            return playPlan(new, point: record.point, direction: record.direction, kind: .undo)
        }
        if old.play == new.play && old.tutorial != new.tutorial, case .move = new.tutorial, newRecords.isEmpty {
            return levelPlan(new)
        }
        if old.selected != new.selected, let point = new.selected {
            return WaveKnotKeeperFeedbackPlan(text: "Point \(point + 1) selected.", kind: .state, haptic: nil)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (raw, "r02-g03.locked", or prefixed,
    /// "action.rule.r02-g03.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> WaveKnotKeeperFeedbackPlan {
        WaveKnotKeeperFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code` (raw or prefixed), also shown by the panel: "That level is not
    /// open yet." (a code containing `r02-g03.locked`), "That date cannot be used." (`r02-g03.date`), "That move is not
    /// allowed: it would leave the space, meet another point, pass through a strand outside a gate or pull the rope too
    /// tight." (`r02-g03.move`), "No moves are left." (`r02-g03.allowance`), "The level has ended." (`r02-g03.stage`),
    /// otherwise "That change was refused.".
    public static func refusalText(code: String) -> String {
        if code.contains(WaveKnotKeeperExperienceRule.locked) {
            return "That level is not open yet."
        }
        if code.contains(WaveKnotKeeperExperienceRule.date) {
            return "That date cannot be used."
        }
        if code.contains(WaveKnotKeeperError.move("").reasonCode) {
            return "That move is not allowed: it would leave the space, meet another point, pass through a strand "
                + "outside a gate or pull the rope too tight."
        }
        if code.contains(WaveKnotKeeperError.allowance.reasonCode) {
            return "No moves are left."
        }
        if code.contains(WaveKnotKeeperError.stage.reasonCode) {
            return "The level has ended."
        }
        return "That change was refused."
    }

    /// The name of a mode in a level announcement: "Campaign", "Practice" or "Daily level".
    public static func modeName(_ mode: WaveKnotKeeperMode) -> String {
        switch mode {
        case .campaign: "Campaign"
        case .practice: "Practice"
        case .daily: "Daily level"
        }
    }

    /// The plain name of a move direction: "right" (+x), "left" (−x), "up" (+y), "down" (−y), "over" (+z) or
    /// "under" (−z).
    public static func directionWord(_ direction: WaveKnotKeeperDirection) -> String {
        switch direction {
        case .plusX: "right"
        case .minusX: "left"
        case .plusY: "up"
        case .minusY: "down"
        case .plusZ: "over"
        case .minusZ: "under"
        }
    }

    /// "1 crossing" or "c crossings".
    public static func crossings(_ count: Int) -> String { count == 1 ? "1 crossing" : "\(count) crossings" }

    /// "1 move" or "s moves".
    public static func moves(_ count: Int) -> String { count == 1 ? "1 move" : "\(count) moves" }

    /// The band of manifest level `number`: (number − 1) / 20 + 1, so levels 1 … 20 are band 1 and 81 … 100 band 5.
    public static func band(of number: Int) -> Int {
        (number - 1) / 20 + 1
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: WaveKnotKeeperExperienceCore) -> WaveKnotKeeperFeedbackPlan {
        let number: Int = core.levelNumber
        var text: String = "Level \(number), band \(band(of: number)), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return WaveKnotKeeperFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The plan of an accepted move, undo or redo of `point` in `direction` that left `core`.
    static func playPlan(_ core: WaveKnotKeeperExperienceCore, point: Int, direction: WaveKnotKeeperDirection,
                         kind: WaveKnotKeeperRecordKind) -> WaveKnotKeeperFeedbackPlan {
        let spent: Int = core.play.spent
        switch core.play.stage {
        case .won:
            let text: String
            if core.mode == .practice {
                text = "The knot matches. Level won in \(Self.moves(spent))."
            } else {
                let stars: Int = WaveKnotKeeperProgress.stars(moves: spent, shortest: core.certifiedShortest)
                text = "The knot matches. Level won in \(Self.moves(spent)), \(stars) of 3 stars."
            }
            return WaveKnotKeeperFeedbackPlan(text: text, kind: .outcome, haptic: .success)
        case .failed:
            let text: String = core.failureExplanation?.text
                ?? "The moves are spent without a match. Undo the last move or retry the level."
            return WaveKnotKeeperFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
        default:
            let prefix: String
            switch kind {
            case .move: prefix = ""
            case .undo: prefix = "Undone: "
            case .redo: prefix = "Redone: "
            }
            let summary: WaveKnotKeeperSummary = core.play.summary
            let target: WaveKnotKeeperTarget = core.play.level.target
            let counts: String
            if summary.degenerate {
                counts = "Two strands overlap in the view. Target \(Self.crossings(target.crossings)), "
                    + "writhe \(target.writhe)."
            } else {
                counts = "\(Self.crossings(summary.crossings)), writhe \(summary.writhe); "
                    + "target \(target.crossings), \(target.writhe)."
            }
            let text: String = "\(prefix)Point \(point + 1) moved \(directionWord(direction)). \(counts) "
                + "Moves \(spent) of \(core.play.level.allowance)."
            return WaveKnotKeeperFeedbackPlan(text: text, kind: .state, haptic: .selection)
        }
    }
}
