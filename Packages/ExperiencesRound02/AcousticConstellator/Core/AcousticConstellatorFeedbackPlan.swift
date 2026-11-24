// AcousticConstellatorFeedbackPlan — feature 426 (R02-G13-06) T-R02G1306-003 (FR-R02G1306-001, 002, 003;
// SC-R02G1306-002; clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement and haptic of one change of
// Acoustic Constellator, as a pure function of the core before and after an accepted action (or of a refusal's reason
// code, or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes the plan
// through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never
// changes state. Modelled on feature 416's HarmonicBridgesFeedbackPlan.
//
// Words: stars and ticks count from 0 as the level words them (`AcousticConstellatorLevel.starName(_:phase:)`,
// `linkName(_:phases:)`), actions from 1. The progress that follows every accepted link, unlink, nudge, undo and redo
// is " k symbol pairs missing, a actions left." (k the level's symbol pairs not among the new play's links; "1 symbol
// pair missing" and "1 action left" for one) or " The symbol is linked, a actions left." when none is missing.
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or the mode differs, or the play was replaced by another one that is
//      not the old play plus one record (`level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign`
//      open a fresh play) → `level`, "Level n, band b, <campaign|practice|daily>." (b =
//      `AcousticConstellatorProgress.band(of:)` 1 … 5) plus " " and the tutorial instruction while the tutorial is
//      shown (not done); no haptic;
//   2. an accepted action: the play gained exactly one record →
//      a new end (the stage became won or failed; Q2: a listen always ends the level and a link, unlink or nudge that
//      spends the last action without a win ends it too, so each plans only the outcome):
//        won: `outcome`, "The symbol rings together. Level won spending a actions, k of 3 stars." (practice: "… Level
//             won spending a actions."), haptic `success`; a is `AcousticConstellatorProgress.actionsSpent(_:)` (undone
//             actions included) and k is `AcousticConstellatorProgress.stars(actionsSpent:certified:)` of this win
//             against the certified witness's action count;
//        failed: `outcome`, the failure explanation of feature 425 (`AcousticConstellatorFailureExplanation`), haptic
//             `warning`;
//      otherwise by the records' last kind: an undo or redo "Undone." or "Redone."; else the change of the cores — a
//      new link "Linked star a to star b, gap g." (g at the new play's starting phases, as `linkName(_:phases:)` words
//      it), a removed link "Unlinked star a and star b.", a changed starting phase of one star "Star s nudged to phase
//      p."; each followed by the progress, each `state` with haptic `selection`;
//   3. the same untouched play reopened with its tutorial shown again → the `level` plan of case 1;
//   4. otherwise (nothing changed, or only the tutorial step moved: `tutorial.dismiss`) →
//      ``AcousticConstellatorFeedbackPlan/none``.
// Choosing a star or partner, a drag preview and orbit are presentation only and plan nothing (the core does not
// change; the adjustable star and partner speak their own values). A revealed hint is `hint(text:)`: `state` with the
// hint's words and no haptic. Integers only, except the snapshot's coherence bars that the summary reads.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind) and the haptic of one change of Acoustic Constellator (feature 426, clarifications
/// Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare them exactly.
public struct AcousticConstellatorFeedbackPlan: Sendable, Equatable {
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
    public static let none = AcousticConstellatorFeedbackPlan(text: nil, kind: nil, haptic: nil)

    /// The opening sentence of a win: "The symbol rings together."
    public static let wonText: String = "The symbol rings together."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<code>`).
    public static let rulePrefix: String = "action.rule."

    /// The plan for the change from `old` to `new` after an accepted action (see the file header for the order of the
    /// cases and the exact texts). Reads only.
    public static func after(old: AcousticConstellatorExperienceCore,
                             new: AcousticConstellatorExperienceCore) -> AcousticConstellatorFeedbackPlan {
        let oldRecords: [AcousticConstellatorRecord] = old.play.records
        let newRecords: [AcousticConstellatorRecord] = new.play.records
        let extended: Bool = old.play.level == new.play.level
            && newRecords.count == oldRecords.count + 1
            && Array(newRecords.dropLast()) == oldRecords
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        if !sameLevel || (old.play != new.play && !extended) {
            return levelPlan(new)
        }
        if extended, let record = newRecords.last {
            return playPlan(old: old, new: new, record: record)
        }
        if old.play == new.play && old.tutorial != new.tutorial
            && new.tutorial == AcousticConstellatorTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && newRecords.isEmpty {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g13.locked", or as the engine reports it,
    /// "action.rule.r02-g13.locked"): kind `rejection`, haptic `error`, text ``refusalText(code:)``.
    public static func refused(code: String) -> AcousticConstellatorFeedbackPlan {
        AcousticConstellatorFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error)
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g13.locked`), "That date
    /// cannot be used." (`r02-g13.date`), "That change is not allowed for these stars." (`r02-g13.action`), "The level
    /// has ended." (`r02-g13.stage`), "That value must be a whole number." (`r02-g13.not-whole`); any other code
    /// (`r02-g13.stale`, `r02-g13.level`, `r02-g13.malformed`, the engine's own codes such as `action.out-of-range`)
    /// "That action was refused.".
    public static func refusalText(code: String) -> String {
        let bare: String = code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
        switch bare {
        case AcousticConstellatorExperienceRule.locked: return "That level is not open yet."
        case AcousticConstellatorExperienceRule.date: return "That date cannot be used."
        case AcousticConstellatorError.action("").reasonCode: return "That change is not allowed for these stars."
        case AcousticConstellatorError.stage.reasonCode: return "The level has ended."
        case AcousticConstellatorExperienceRule.notWhole: return "That value must be a whole number."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic.
    public static func hint(text: String) -> AcousticConstellatorFeedbackPlan {
        AcousticConstellatorFeedbackPlan(text: text, kind: .state, haptic: nil)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. k symbol pairs missing. Tick t:
    /// coherence c of 12, run r of h. Chosen: <the star in words> and <the partner in words>. Level: <the level in
    /// words>."
    ///
    /// The tick is the last tick of the play's listen report (`AcousticConstellatorListen.lastTick`, the tick the
    /// progress words and the ambient recipe read), c the coherence bars lit there
    /// (`AcousticConstellatorSceneSnapshot.coherenceBars(at:)`, 0 … 12), r the coherent run ending there
    /// (`run(at:)`) and h the level's hold; the summary is a pure function of the core and never follows the 0.25 s
    /// tick preview. "1 action left" and "1 symbol pair missing" for one. The star is
    /// `AcousticConstellatorLevel.starName(_:phase:)` of `star` at its current starting phase; the partner likewise,
    /// followed by ", linked" or ", not linked" (whether the pair is among the play's links) when it differs from the
    /// star; an index the level lacks reads "star i". The level is ``levelWords(_:)``.
    public static func summaryText(core: AcousticConstellatorExperienceCore, star: Int, partner: Int) -> String {
        let play: AcousticConstellatorPlay = core.play
        let snapshot: AcousticConstellatorSceneSnapshot = core.snapshot(time: 0)
        let tick: Int = max(0, play.report.lastTick)
        let bars: Int = snapshot.coherenceBars(at: tick)
        let run: Int = snapshot.run(at: tick)
        var partnerWords: String = starWords(play, partner)
        if partner != star && isStar(play, star) && isStar(play, partner) {
            let linked: Bool = play.links.contains(AcousticConstellatorLink.between(star, partner))
            partnerWords += linked ? ", linked" : ", not linked"
        }
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". " + missingWords(missingCount(play))
            + ". Tick \(tick): coherence \(bars) of 12, run \(run) of \(play.level.hold). Chosen: "
            + starWords(play, star) + " and " + partnerWords + ". Level: " + levelWords(core) + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; s stars, p symbol pairs, f fixed links; a hold of
    /// H ticks within W; a budget of B actions" ("1 fixed link" for one).
    public static func levelWords(_ core: AcousticConstellatorExperienceCore) -> String {
        let level: AcousticConstellatorLevel = core.play.level
        let fixed: String = level.fixedLinks.count == 1 ? "1 fixed link" : "\(level.fixedLinks.count) fixed links"
        return "level \(core.levelNumber), band \(AcousticConstellatorProgress.band(of: core.levelNumber)), "
            + modeName(core.mode) + "; \(level.stars.count) stars, \(level.symbol.count) symbol pairs, " + fixed
            + "; a hold of \(level.hold) ticks within \(level.window); a budget of \(level.budget) actions"
    }

    /// The name of a mode in a level announcement: "campaign", "practice", "daily" or "replay".
    public static func modeName(_ mode: AcousticConstellatorMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        case .replay: "replay"
        }
    }

    /// Whether `index` is a star of `play`'s level.
    static func isStar(_ play: AcousticConstellatorPlay, _ index: Int) -> Bool {
        index >= 0 && index < play.level.stars.count && index < play.phases.count
    }

    /// Star `index` in words at its current starting phase, or "star i" for an index the level lacks.
    static func starWords(_ play: AcousticConstellatorPlay, _ index: Int) -> String {
        isStar(play, index) ? play.level.starName(index, phase: play.phases[index]) : "star \(index)"
    }

    /// The level's symbol pairs not among `play`'s links.
    static func missingCount(_ play: AcousticConstellatorPlay) -> Int {
        let present: Set<AcousticConstellatorLink> = Set(play.links)
        var missing: Int = 0
        for pair in play.level.symbol where !present.contains(pair) { missing += 1 }
        return missing
    }

    /// "k symbol pairs missing" ("1 symbol pair missing" for one).
    static func missingWords(_ count: Int) -> String {
        count == 1 ? "1 symbol pair missing" : "\(count) symbol pairs missing"
    }

    /// "a actions left" ("1 action left" for one).
    static func actionsLeftWords(_ count: Int) -> String {
        count == 1 ? "1 action left" : "\(count) actions left"
    }

    /// "a actions" ("1 action" for one).
    static func actionsWords(_ count: Int) -> String {
        count == 1 ? "1 action" : "\(count) actions"
    }

    /// The progress after an accepted action: "k symbol pairs missing, a actions left." or "The symbol is linked, a
    /// actions left." when none is missing.
    static func progress(_ play: AcousticConstellatorPlay) -> String {
        let missing: Int = missingCount(play)
        let head: String = missing == 0 ? "The symbol is linked" : missingWords(missing)
        return head + ", " + actionsLeftWords(play.actionsLeft) + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." and the tutorial instruction while it is not done.
    static func levelPlan(_ core: AcousticConstellatorExperienceCore) -> AcousticConstellatorFeedbackPlan {
        let band: Int = AcousticConstellatorProgress.band(of: core.levelNumber)
        var text: String = "Level \(core.levelNumber), band \(band), \(modeName(core.mode))."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return AcousticConstellatorFeedbackPlan(text: text, kind: .level, haptic: nil)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars in campaign and daily;
    /// never in practice), haptic `success`; or the failure explanation, haptic `warning`.
    static func outcomePlan(_ core: AcousticConstellatorExperienceCore) -> AcousticConstellatorFeedbackPlan {
        let play: AcousticConstellatorPlay = core.play
        if play.stage == .won {
            let spent: Int = AcousticConstellatorProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = AcousticConstellatorProgress.stars(actionsSpent: spent,
                                                                    certified: core.certifiedActions)
                text += ", \(stars) of 3 stars"
            }
            return AcousticConstellatorFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success)
        }
        let text: String = AcousticConstellatorFailureExplanation(play: play)?.text
            ?? AcousticConstellatorFailureExplanation.advice
        return AcousticConstellatorFeedbackPlan(text: text, kind: .outcome, haptic: .warning)
    }

    /// The first sentence of an accepted link, unlink or nudge: the change from `old`'s play to `new`'s (a new link, a
    /// removed link, or one star's changed starting phase); empty when none of them changed.
    static func changeWords(old: AcousticConstellatorPlay, new: AcousticConstellatorPlay) -> String {
        let before: Set<AcousticConstellatorLink> = Set(old.links)
        let after: Set<AcousticConstellatorLink> = Set(new.links)
        if let added = new.links.first(where: { !before.contains($0) }),
           added.a >= 0, added.b < new.phases.count {
            return "Linked" + String(new.level.linkName(added, phases: new.phases).dropFirst("link".count)) + "."
        }
        if let removed = old.links.first(where: { !after.contains($0) }) {
            return "Unlinked star \(removed.a) and star \(removed.b)."
        }
        if old.phases.count == new.phases.count {
            for index in new.phases.indices where new.phases[index] != old.phases[index] {
                return "Star \(index) nudged to phase \(new.phases[index])."
            }
        }
        return ""
    }

    /// The plan of the accepted `record` that took `old` to `new`.
    static func playPlan(old: AcousticConstellatorExperienceCore, new: AcousticConstellatorExperienceCore,
                         record: AcousticConstellatorRecord) -> AcousticConstellatorFeedbackPlan {
        let play: AcousticConstellatorPlay = new.play
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new)
        }
        let first: String
        switch record.kind {
        case .undo: first = "Undone."
        case .redo: first = "Redone."
        case .link, .unlink, .nudge, .listen: first = changeWords(old: old.play, new: play)
        }
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return AcousticConstellatorFeedbackPlan(text: text, kind: .state, haptic: .selection)
    }
}
