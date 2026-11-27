// BinaryGardensFeedbackPlan — feature 506 (R02-G21-06) T-R02G2106-003 (FR-R02G2106-001, 002, 003; SC-R02G2106-002;
// clarifications Q1, Q2, Q5; contracts/api.md). The VoiceOver announcement, the haptic and the trigger of one change
// of Binary Gardens, as a pure function of the core before and after accepted actions (or of a refusal's reason code,
// or of a revealed hint's text), and the words of the panel's summary element. The presenter only routes the plan
// through the shared feedback route (the person's haptics switch, the shared planners' rate limits); a plan never
// changes state. Modelled on feature 496's `MushroomWeatherFeedbackPlan`.
//
// Words: stars, rings and worlds counted from 1; ρ a ring's radius and L a luminosity in units as the level words
// them (`ringRadii`, `luminosityLevels`); the phase is the step itself and the tilt "t of T steps". The progress that
// follows every accepted ring, phase, luminosity and tilt action, undo and redo is " w of n worlds keep their light,
// running now would win, a actions left." ("… would fail" when the play's report fails; "1 action left" for one) — n
// the level's worlds and w those keeping their light (``BinaryGardensFeedbackPlan/keepsLight(_:play:)``): in the play's
// report of the current arrangement, the world's longest lethal run is at most the level's lethal tolerance, its
// comfortable window reaches its required window and its total light lies inside its bloom band.
//
// Mode, tutorial, stars and band come from feature 505's adapter state on the cores: `mode`, `tutorial`,
// `certifiedActionCount` (the certified plan's arrangement actions the stars count against) and `band`
// (`BinaryGardensProgress.band(of:)`, equal to the manifest entry's band for every catalog level).
//
// Classification of `after(old:new:)`, first match wins:
//   1. a level or mode change: the level number or `mode` differs, or the play was replaced by another one that is
//      not the old play plus one or more records (`level.next`, `level.select`, `mode.*` open a fresh play) →
//      `level`, "Level n, band b, <campaign|practice|daily>." plus " " and the tutorial instruction while the new
//      core's `tutorial` is not done; no haptic; trigger "level";
//   2. accepted actions: the play gained records of which at least one is a player record (ring, phase, luminosity,
//      tilt, run, undo or redo); the trigger is the control of the last such record ("star.ring", "star.phase",
//      "star.luminosity", "orbit.tilt", "light.run", "play.undo", "play.redo"):
//        a new end (the stage became won or failed; the run always ends the level and plans only its outcome, and so
//        does a redo that restores a won or failed moment):
//          won: `outcome`, "Every world kept its light and bloomed. Level won spending a actions, k of 3 stars."
//               (practice: "… Level won spending a actions."; "1 action" for one), haptic `success`; a is
//               `BinaryGardensProgress.actionsSpent(_:)` and k `BinaryGardensProgress.stars(actionsSpent:certified:)`
//               against the new core's `certifiedActionCount`;
//          failed: `outcome`, the failure explanation of feature 505 (the new core's `failureExplanation?.text`,
//               its advice alone when there is none), haptic `warning`;
//        otherwise, for one player record by its kind: "Star n moved to ring r (ρ units).", "Star n shifted to phase
//        p.", "Star n's luminosity set to L.", "Tilt set to t of T steps.", "Undone.", "Redone."; several player
//        records the progress alone; each followed by the progress, `state`, haptic `selection` (an undo out of a
//        failed play returns it to playing and is a `state`);
//   3. the same untouched play (no ring, phase, luminosity, tilt, run, undo or redo recorded) reopened with its
//      tutorial shown again (the new core's `tutorial` is the level's initial step, not done, and differs from the old
//      core's) → the `level` plan of case 1;
//   4. otherwise (nothing changed, only event records added, the tutorial dismissed, or only the shown tick changed:
//      `clock.show`) → ``BinaryGardensFeedbackPlan/none``.
// The panel's selected star, previews, the shown tick, inspections and the view are presentation only and plan
// nothing. A revealed hint is `hint(text:)`: `state` with the hint's words, no haptic, trigger "hint". A refusal is
// `refused(code:)`: `rejection`, haptic `error`, the trigger the bare code. Integers only; no clock, no randomness.
import Foundation
import VisualCoreSimulation

/// The announcement (text and kind), the haptic and the trigger of one change of Binary Gardens (feature 506,
/// clarifications Q1, Q2). Texts are plain English with whole numbers, built from the cores alone so tests compare
/// them exactly.
public struct BinaryGardensFeedbackPlan: Sendable, Equatable {
    /// The text VoiceOver speaks, or nil when nothing is announced.
    public let text: String?
    /// The announcement kind, or nil when nothing is announced.
    public let kind: AnnouncementKind?
    /// The haptic to play, or nil for none.
    public let haptic: HapticKind?
    /// What caused the plan, for the feedback log: the control ("star.ring", "play.undo", …), the bare refusal code,
    /// "hint" or "level"; empty for ``none``.
    public let trigger: String

    /// A plan of the given parts (not checked; the factory functions keep text and kind together).
    public init(text: String?, kind: AnnouncementKind?, haptic: HapticKind?, trigger: String) {
        self.text = text
        self.kind = kind
        self.haptic = haptic
        self.trigger = trigger
    }

    /// No announcement, no haptic and an empty trigger: nothing to say.
    public static let none = BinaryGardensFeedbackPlan(text: nil, kind: nil, haptic: nil, trigger: "")

    /// The opening sentence of a win: "Every world kept its light and bloomed."
    public static let wonText: String = "Every world kept its light and bloomed."

    /// The engine's prefix of a refusal that the core itself returned (`action.rule.<code>`).
    public static let rulePrefix: String = "action.rule."

    /// The trigger of a level or mode change.
    public static let levelTrigger: String = "level"

    /// The trigger of a revealed hint.
    public static let hintTrigger: String = "hint"

    /// The plan for the change from `old` to `new` (see the file header for the order of the cases and the exact
    /// texts): reads the cores' play, level number, `mode`, `tutorial`, `certifiedActionCount` and `band` (feature
    /// 505). Reads only.
    ///
    /// - Parameters:
    ///   - old: the core before the change.
    ///   - new: the core after it.
    public static func after(old: BinaryGardensExperienceCore,
                             new: BinaryGardensExperienceCore) -> BinaryGardensFeedbackPlan {
        let oldRecords: [BinaryGardensRecord] = old.play.records
        let newRecords: [BinaryGardensRecord] = new.play.records
        let extended: Bool = old.play.level == new.play.level
            && newRecords.count > oldRecords.count
            && Array(newRecords.prefix(oldRecords.count)) == oldRecords
        let sameLevel: Bool = old.levelNumber == new.levelNumber && old.mode == new.mode
        if !sameLevel || (old.play != new.play && !extended) {
            return levelPlan(new)
        }
        if extended {
            let added: [BinaryGardensRecord] = Array(newRecords.dropFirst(oldRecords.count))
            var players: [BinaryGardensRecord] = []
            for record in added where control(of: record.kind) != nil { players.append(record) }
            guard !players.isEmpty else { return .none }
            return playPlan(old: old, new: new, players: players)
        }
        if old.play == new.play && old.tutorial != new.tutorial
            && new.tutorial == BinaryGardensTutorialStep.initial(level: new.levelNumber)
            && new.tutorial != .done && !hasPlayerRecords(new.play) {
            return levelPlan(new)
        }
        return .none
    }

    /// The plan of a refused action with reason code `code` (bare, "r02-g21.budget", or as the engine reports it,
    /// "action.rule.r02-g21.budget"): kind `rejection`, haptic `error`, text ``refusalText(code:)``, trigger the bare
    /// code.
    public static func refused(code: String) -> BinaryGardensFeedbackPlan {
        BinaryGardensFeedbackPlan(text: refusalText(code: code), kind: .rejection, haptic: .error,
                                  trigger: bareCode(code))
    }

    /// `code` without the engine's ``rulePrefix``.
    public static func bareCode(_ code: String) -> String {
        code.hasPrefix(rulePrefix) ? String(code.dropFirst(rulePrefix.count)) : code
    }

    /// The words of a refusal with reason code `code`, also shown by the panel (clarification Q1, word for word). The
    /// engine's ``rulePrefix`` is read as the bare code: "That level is not open yet." (`r02-g21.locked`), "That date
    /// cannot be used." (`r02-g21.date`), "That ring, phase, brightness or tilt change cannot be made (locked,
    /// unchanged, off the phase grid or too close to the other star), or there is nothing to undo or redo."
    /// (`r02-g21.action`), "No actions are left: run the light or undo a change." (`r02-g21.budget`), "The level has
    /// ended." (`r02-g21.stage`), "The play changed before the action arrived." (`r02-g21.stale`), "That level could
    /// not be made." (`r02-g21.level`, `r02-g21.generation`), "That value must be a whole number."
    /// (`r02-g21.not-whole`), "Only ticks 1 to 48 can be shown." (`r02-g21.tick`); any other code (the kernel's
    /// `newer-schema`, `malformed`, `witness`, the engine's own codes such as `action.out-of-range`) "That action was
    /// refused."
    public static func refusalText(code: String) -> String {
        switch bareCode(code) {
        case BinaryGardensExperienceRule.locked: return "That level is not open yet."
        case BinaryGardensExperienceRule.date: return "That date cannot be used."
        case BinaryGardensError.action("").reasonCode:
            return "That ring, phase, brightness or tilt change cannot be made (locked, unchanged, off the phase grid "
                + "or too close to the other star), or there is nothing to undo or redo."
        case BinaryGardensError.budget.reasonCode: return "No actions are left: run the light or undo a change."
        case BinaryGardensError.stage.reasonCode: return "The level has ended."
        case BinaryGardensError.stale.reasonCode: return "The play changed before the action arrived."
        case BinaryGardensError.level("").reasonCode, BinaryGardensError.generation(0).reasonCode:
            return "That level could not be made."
        case BinaryGardensExperienceRule.notWhole: return "That value must be a whole number."
        case BinaryGardensExperienceRule.tick: return "Only ticks 1 to 48 can be shown."
        default: return "That action was refused."
        }
    }

    /// The plan of a revealed hint (clarification Q1): kind `state` with the hint's words `text`, no haptic, trigger
    /// "hint".
    public static func hint(text: String) -> BinaryGardensFeedbackPlan {
        BinaryGardensFeedbackPlan(text: text, kind: .state, haptic: nil, trigger: hintTrigger)
    }

    /// The words of the panel's summary element (clarification Q5): "a actions left. <the progress in words>.
    /// Selected: <the selected star in words>. Shown: tick t of 48: <every world at the shown tick in words>. Level:
    /// <the level in words>."
    ///
    /// The progress is ``progressWords(_:)`` capitalised; the selected star is the level's star words of `star`
    /// (clamped to 0 … 1: "star 1 on ring 3, 12 units, phase 9, luminosity 24"); every world at the core's shown tick
    /// in the level's words ("world 1 at tick 48: 41 250 milliflux, comfortable, band 30 000 … 52 000"), joined by
    /// "; "; the level is ``levelWords(_:)``. "1 action left" for one. A pure function of the core (its mode
    /// included) and the star.
    public static func summaryText(core: BinaryGardensExperienceCore, star: Int) -> String {
        let play: BinaryGardensPlay = core.play
        let selected: Int = min(max(star, 0), 1)
        var worlds: [String] = []
        for world in play.level.worlds.indices where world < play.report.worlds.count {
            worlds.append(play.level.worldTickDescription(world, tick: core.shownTick, report: play.report))
        }
        return capitalised(actionsLeftWords(play.actionsLeft)) + ". " + capitalised(progressWords(play))
            + ". Selected: " + play.level.starDescription(selected, arrangement: play.arrangement)
            + ". Shown: tick \(core.shownTick) of \(BinaryGardensSky.cycle): " + worlds.joined(separator: "; ")
            + ". Level: " + levelWords(core) + "."
    }

    /// The level in words for the summary: "level n, band b, <mode>; rings of ρ1, ρ2, … units; luminosity levels L1,
    /// L2, …; tilt up to T steps; phase step g; k worlds; lethal tolerance E ticks; a budget of B actions" ("1 world",
    /// "1 tick", "1 step", "1 action" for one); the band is the core's `band` and the mode its `mode` (feature 505).
    public static func levelWords(_ core: BinaryGardensExperienceCore) -> String {
        let level: BinaryGardensLevel = core.play.level
        let rings: String = level.ringRadii.map { String($0) }.joined(separator: ", ")
        let lights: String = level.luminosityLevels.map { String($0) }.joined(separator: ", ")
        return "level \(core.levelNumber), band \(core.band), " + modeName(core.mode)
            + "; rings of " + rings + " units; luminosity levels " + lights + "; tilt up to "
            + counted(level.maxTilt, "step") + "; phase step \(level.phaseStep); "
            + counted(level.worlds.count, "world")
            + "; lethal tolerance " + counted(level.lethalTolerance, "tick") + "; a budget of "
            + actionsWords(level.budget)
    }

    /// The name of a mode in a level announcement: "campaign", "practice" or "daily" (feature 505).
    public static func modeName(_ mode: BinaryGardensMode) -> String {
        switch mode {
        case .campaign: "campaign"
        case .practice: "practice"
        case .daily: "daily"
        }
    }

    /// The progress in words, without the actions: the level's own progress words
    /// (`BinaryGardensLevel.progressDescription(report:arrangement:actionsLeft:)`) without their closing actions left,
    /// which the summary says first.
    public static func progressWords(_ play: BinaryGardensPlay) -> String {
        var words: String = play.level.progressDescription(report: play.report, arrangement: play.arrangement,
                                                           actionsLeft: play.actionsLeft)
        let suffix: String = "; " + actionsLeftWords(play.actionsLeft)
        if words.hasSuffix(suffix) { words = String(words.dropLast(suffix.count)) }
        return words
    }

    /// Whether world `world` (0-based) of `play` keeps its light: in the play's report of the current arrangement its
    /// longest lethal run is at most the level's lethal tolerance, its comfortable window reaches its required window
    /// and its total light lies inside its bloom band. False for a world the level or the report lacks.
    public static func keepsLight(_ world: Int, play: BinaryGardensPlay) -> Bool {
        guard play.level.worlds.indices.contains(world), play.report.worlds.indices.contains(world) else {
            return false
        }
        let light: BinaryGardensWorldLight = play.report.worlds[world]
        return light.longestLethalRun <= play.level.lethalTolerance
            && light.window >= play.level.worlds[world].window
            && light.bloom == .inside
    }

    /// The worlds of `play` keeping their light (``keepsLight(_:play:)``).
    public static func worldsKeepingLight(_ play: BinaryGardensPlay) -> Int {
        var count: Int = 0
        for world in play.level.worlds.indices where keepsLight(world, play: play) { count += 1 }
        return count
    }

    /// The control of a player record kind ("star.ring", "star.phase", "star.luminosity", "orbit.tilt", "light.run",
    /// "play.undo", "play.redo"); nil for an event record.
    public static func control(of kind: BinaryGardensRecord.Kind) -> String? {
        switch kind {
        case .ring: "star.ring"
        case .phase: "star.phase"
        case .luminosity: "star.luminosity"
        case .tilt: "orbit.tilt"
        case .run: "light.run"
        case .undo: "play.undo"
        case .redo: "play.redo"
        case .begin, .dismissTutorial, .pause, .resume, .showResult: nil
        }
    }

    /// "n <noun>s" ("1 <noun>" for one).
    static func counted(_ count: Int, _ noun: String) -> String {
        count == 1 ? "1 " + noun : "\(count) " + noun + "s"
    }

    /// "a actions left" ("1 action left" for one).
    static func actionsLeftWords(_ count: Int) -> String {
        count == 1 ? "1 action left" : "\(count) actions left"
    }

    /// "a actions" ("1 action" for one).
    static func actionsWords(_ count: Int) -> String {
        count == 1 ? "1 action" : "\(count) actions"
    }

    /// The progress after an accepted action: "w of n worlds keep their light, running now would win, a actions
    /// left." ("… would fail" when the play's report fails).
    static func progress(_ play: BinaryGardensPlay) -> String {
        let verdict: String = play.report.wins ? "running now would win" : "running now would fail"
        return "\(worldsKeepingLight(play)) of \(play.level.worlds.count) worlds keep their light, " + verdict + ", "
            + actionsLeftWords(play.actionsLeft) + "."
    }

    /// `text` with its first character upper-cased.
    static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Whether `play` recorded a ring, phase, luminosity or tilt action, a run, an undo or a redo.
    static func hasPlayerRecords(_ play: BinaryGardensPlay) -> Bool {
        for record in play.records where control(of: record.kind) != nil { return true }
        return false
    }

    /// The `level` plan of `core`: "Level n, band b, <mode>." from its level number, `band` and `mode`, and its
    /// tutorial instruction while its `tutorial` is not done.
    static func levelPlan(_ core: BinaryGardensExperienceCore) -> BinaryGardensFeedbackPlan {
        var text: String = "Level \(core.levelNumber), band \(core.band), " + modeName(core.mode) + "."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return BinaryGardensFeedbackPlan(text: text, kind: .level, haptic: nil, trigger: levelTrigger)
    }

    /// The `outcome` plan of `core`'s ended play: the win with its actions spent (and stars against its
    /// `certifiedActionCount` when its `mode` awards them: campaign and daily, never practice), haptic `success`; or
    /// its `failureExplanation`, haptic `warning`.
    static func outcomePlan(_ core: BinaryGardensExperienceCore, trigger: String) -> BinaryGardensFeedbackPlan {
        let play: BinaryGardensPlay = core.play
        if play.stage == .won {
            let spent: Int = BinaryGardensProgress.actionsSpent(play)
            var text: String = wonText + " Level won spending " + actionsWords(spent)
            if core.mode.awardsStars {
                let stars: Int = BinaryGardensProgress.stars(actionsSpent: spent, certified: core.certifiedActionCount)
                text += ", \(stars) of 3 stars"
            }
            return BinaryGardensFeedbackPlan(text: text + ".", kind: .outcome, haptic: .success, trigger: trigger)
        }
        let text: String = core.failureExplanation?.text ?? BinaryGardensFailureExplanation.advice
        return BinaryGardensFeedbackPlan(text: text, kind: .outcome, haptic: .warning, trigger: trigger)
    }

    /// The first sentence of one accepted `record` of `level`: "Star n moved to ring r (ρ units).", "Star n shifted
    /// to phase p.", "Star n's luminosity set to L.", "Tilt set to t of T steps.", "Undone." or "Redone."; empty for
    /// any other kind or a value the level lacks.
    static func changeWords(record: BinaryGardensRecord, level: BinaryGardensLevel) -> String {
        switch record.kind {
        case .undo: return "Undone."
        case .redo: return "Redone."
        case .ring:
            guard case .ring(let star, let index)? = record.action, level.ringRadii.indices.contains(index) else {
                return ""
            }
            return "Star \(star + 1) moved to ring \(index + 1) (\(level.ringRadii[index]) units)."
        case .phase:
            guard case .phase(let star, let step)? = record.action else { return "" }
            return "Star \(star + 1) shifted to phase \(step)."
        case .luminosity:
            guard case .luminosity(let star, let index)? = record.action,
                  level.luminosityLevels.indices.contains(index) else { return "" }
            return "Star \(star + 1)'s luminosity set to \(level.luminosityLevels[index])."
        case .tilt:
            guard case .tilt(let step)? = record.action else { return "" }
            return "Tilt set to \(step) of \(level.maxTilt) steps."
        case .run, .begin, .dismissTutorial, .pause, .resume, .showResult: return ""
        }
    }

    /// The plan of the accepted player records `players` that took `old` to `new`.
    static func playPlan(old: BinaryGardensExperienceCore, new: BinaryGardensExperienceCore,
                         players: [BinaryGardensRecord]) -> BinaryGardensFeedbackPlan {
        let play: BinaryGardensPlay = new.play
        let trigger: String = players.last.flatMap { control(of: $0.kind) } ?? ""
        if play.stage != old.play.stage && (play.stage == .won || play.stage == .failed) {
            return outcomePlan(new, trigger: trigger)
        }
        let first: String = players.count == 1 ? changeWords(record: players[0], level: play.level) : ""
        let text: String = first.isEmpty ? progress(play) : first + " " + progress(play)
        return BinaryGardensFeedbackPlan(text: text, kind: .state, haptic: .selection, trigger: trigger)
    }
}
