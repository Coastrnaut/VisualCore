// AcousticConstellatorFeedbackPlanTests — feature 426 (R02-G13-06) T-R02G1306-003 (FR-R02G1306-001, 002, 003;
// SC-R02G1306-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `AcousticConstellatorFeedbackPlan`
// on real certified cores driven through `AcousticConstellatorExperienceCore.apply`: links, an unlink, nudges, an undo
// and a redo, then a 3-star campaign win (the winning listen plans only the outcome) and the `stage` refusals after it;
// a 2-star campaign win with an undone detour, a practice win without stars and a daily win; every refusal code
// (provoked where the core can produce it, every code by table, bare and with the engine's `action.rule.` prefix);
// failures by each listen outcome (missing, disconnected, incoherent; undo and a redo that fails again plan the
// outcome only) and by the budget (the budget-ending nudge plans only the warning); level and mode changes with and
// without the tutorial; choosing, the drag preview (no core change) and the dismissal plan nothing; a revealed hint;
// the summary element.
// Seed 40 opens level 41 (band 3, no tutorial): 5 stars, phases 7, 4, 9, 8, 10; fixed links 0–3, 1–2; symbol 0–3, 1–2,
// 1–4, 2–3, 3–4; budget 13; certified witness link 1–4, 2–3, 3–4 and listen (4 actions). Seed 0 opens level 1
// (tutorial): 3 stars, rates 9, 9, 10, phases 7, 5, 4; fixed link 1–2; symbol 0–1, 1–2; hold 8 within 24; budget 9;
// witness link 0–1 and listen (2 actions). Level 3 (seed 2): phases 4, 4, 9, symbol 0–2, 1–2; a nudge of star 2 after
// linking both snaps link 1–2 on tick 1. Level 20 (seed 19): phases 6, 1, 8, 4; fixed 1–2, 1–3; links 0–2 and 0–3 and a
// nudge of star 0 never cohere (hold 6 within 24). The daily level of 2026-11-23 is level 15 (band 1), witness link
// 0–1, 2–3 and listen. The expected texts are written out here, not built with the plan's helpers. Explicit types,
// plain loops, short runs.
// Feature 427 (R02-G13-07) T-R02G1307-003: the replay codes' words (`r02-g13.no-replay`, `r02-g13.replay-end`,
// `r02-g13.replay`) in the table and provoked through the core; replaying level 41's stored trace announces the replay
// opening, each step like the action it applies and the replayed win without stars; stopping announces campaign.
import Foundation
import Testing
@testable import AcousticConstellatorCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct AcousticConstellatorFeedbackPlanTests {
    typealias Core = AcousticConstellatorExperienceCore
    typealias Plan = AcousticConstellatorFeedbackPlan

    /// The tutorial's first instruction (feature 425).
    static let linkStep: String = "Drag from one star to another (or use the panel's star, partner and Link) to link a "
        + "pair the dashed plum guides show"

    /// The advice that ends every failure explanation (feature 425).
    static let advice: String = "Undo the last action or retry the level."

    /// The bare action `control` with `values`.
    static func bare(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// Applies `control` with `values` to `core`, expects it accepted and returns the plan of the change.
    static func accepted(_ core: inout Core, _ control: String, _ values: [Double] = []) -> Plan {
        let old: Core = core
        let result: ActionResult = core.apply(bare(control, values))
        #expect(result == .accepted, "\(control) \(values): \(result)")
        return Plan.after(old: old, new: core)
    }

    /// Links star `a` to star `b` and returns the plan.
    static func link(_ core: inout Core, _ a: Int, _ b: Int) -> Plan {
        accepted(&core, "link.add", [Double(a), Double(b)])
    }

    /// Nudges star `star` by `step` and returns the plan.
    static func nudge(_ core: inout Core, _ star: Int, _ step: Int) -> Plan {
        accepted(&core, "star.nudge", [Double(star), Double(step)])
    }

    /// Applies `control` with `values` to `core`, expects the refusal `code` with the core unchanged and no change
    /// plan, and returns the refusal plan.
    static func refused(_ core: inout Core, _ control: String, _ values: [Double], code: String) -> Plan {
        let old: Core = core
        let result: ActionResult = core.apply(bare(control, values))
        #expect(result == .rejected(.rule(code: code)), "\(control) \(values): \(result)")
        #expect(core == old)
        #expect(Plan.after(old: old, new: core) == Plan.none)
        return Plan.refused(code: code)
    }

    /// Applies the kernel `action` through the adapter, expects it accepted and returns the plan.
    static func act(_ core: inout Core, _ action: AcousticConstellatorAction) -> Plan {
        switch action {
        case let .link(a, b): link(&core, a, b)
        case let .unlink(a, b): accepted(&core, "link.remove", [Double(a), Double(b)])
        case let .nudge(star, step): nudge(&core, star, step)
        case .listen: accepted(&core, "constellation.listen")
        }
    }

    /// A `state` plan with haptic `selection`.
    static func state(_ text: String) -> Plan { Plan(text: text, kind: .state, haptic: .selection) }

    /// A `level` plan without haptic.
    static func level(_ text: String) -> Plan { Plan(text: text, kind: .level, haptic: nil) }

    /// A `rejection` plan with haptic `error`.
    static func rejection(_ text: String) -> Plan { Plan(text: text, kind: .rejection, haptic: .error) }

    /// An `outcome` plan with haptic `success`.
    static func won(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .success) }

    /// An `outcome` plan with haptic `warning`.
    static func failed(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .warning) }

    @Test func linksNudgesUndoRedoAndA3StarCampaignWin() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41 && core.tutorial == .done && core.certifiedActions == 4)
        #expect(Self.link(&core, 1, 4)
                == Self.state("Linked star 1 to star 4, gap 6. 2 symbol pairs missing, 12 actions left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 3 symbol pairs missing, 13 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 2 symbol pairs missing, 12 actions left."))
        // Links given in either order are worded with the lower star first.
        #expect(Self.link(&core, 3, 2)
                == Self.state("Linked star 2 to star 3, gap 1. 1 symbol pair missing, 11 actions left."))
        #expect(Self.link(&core, 3, 4)
                == Self.state("Linked star 3 to star 4, gap 2. The symbol is linked, 10 actions left."))
        // The listen always ends the level: it plans only the outcome. 4 actions against the certified 4 → 3 stars.
        #expect(Self.accepted(&core, "constellation.listen")
                == Self.won("The symbol rings together. Level won spending 4 actions, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won play is final: the real `stage` refusals.
        #expect(Self.refused(&core, "link.add", [0, 1], code: "r02-g13.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "constellation.listen", [], code: "r02-g13.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g13.stage") == Self.rejection("The level has ended."))
        // level.next after the win opens level 42.
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 42, band 3, campaign."))
    }

    @Test func nudgesAndAnUnlinkSayTheirChange() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(Self.nudge(&core, 0, 1)
                == Self.state("Star 0 nudged to phase 8. 3 symbol pairs missing, 12 actions left."))
        #expect(Self.nudge(&core, 0, -1)
                == Self.state("Star 0 nudged to phase 7. 3 symbol pairs missing, 11 actions left."))
        // The gap is read at the new play's starting phases.
        #expect(Self.nudge(&core, 4, 1)
                == Self.state("Star 4 nudged to phase 11. 3 symbol pairs missing, 10 actions left."))
        #expect(Self.link(&core, 1, 4)
                == Self.state("Linked star 1 to star 4, gap 5. 2 symbol pairs missing, 9 actions left."))
        #expect(Self.accepted(&core, "link.remove", [4, 1])
                == Self.state("Unlinked star 1 and star 4. 3 symbol pairs missing, 8 actions left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 2 symbol pairs missing, 9 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 3 symbol pairs missing, 8 actions left."))
    }

    @Test func a2StarCampaignWinAPracticeWinWithoutStarsAndADailyWin() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        let witness: [AcousticConstellatorAction] = try Core.generated(number: 41).actions
        #expect(Self.link(&core, 0, 1)
                == Self.state("Linked star 0 to star 1, gap 3. 3 symbol pairs missing, 12 actions left."))
        #expect(Self.accepted(&core, "link.remove", [0, 1])
                == Self.state("Unlinked star 0 and star 1. 3 symbol pairs missing, 11 actions left."))
        var plans: [Plan] = []
        for action in witness { plans.append(Self.act(&core, action)) }
        // The detour still counts: 6 actions against the certified 4 → 2 stars.
        #expect(plans.last == Self.won("The symbol rings together. Level won spending 6 actions, 2 of 3 stars."))
        for index in 0..<(plans.count - 1) { #expect(plans[index].kind == .state && plans[index].haptic == .selection) }

        var practice: Core = try await Core.prepare(seed: 40)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 41, band 3, practice."))
        #expect(Self.link(&practice, 1, 4)
                == Self.state("Linked star 1 to star 4, gap 6. 2 symbol pairs missing, 39 actions left."))
        var last: Plan = .none
        for action in witness.dropFirst() { last = Self.act(&practice, action) }
        #expect(last == Self.won("The symbol rings together. Level won spending 4 actions."))

        var daily: Core = try await Core.prepare(seed: 40)
        #expect(Self.accepted(&daily, "mode.daily", [2026, 11, 23]) == Self.level("Level 15, band 1, daily."))
        for action in try Core.generated(number: 15).actions { last = Self.act(&daily, action) }
        #expect(last == Self.won("The symbol rings together. Level won spending 3 actions, 3 of 3 stars."))
    }

    @Test func everyRefusalCode() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(Self.refused(&core, "level.select", [2], code: "r02-g13.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g13.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g13.date")
                == Self.rejection("That date cannot be used."))
        let notAllowed: Plan = Self.rejection("That change is not allowed for these stars.")
        #expect(Self.refused(&core, "link.add", [0, 0], code: "r02-g13.action") == notAllowed)
        #expect(Self.refused(&core, "link.add", [1, 2], code: "r02-g13.action") == notAllowed)
        #expect(Self.refused(&core, "link.add", [0, 5], code: "r02-g13.action") == notAllowed)
        #expect(Self.refused(&core, "link.remove", [1, 2], code: "r02-g13.action") == notAllowed)
        #expect(Self.refused(&core, "star.nudge", [0, 0], code: "r02-g13.action") == notAllowed)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g13.action") == notAllowed)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g13.action") == notAllowed)
        #expect(Self.refused(&core, "link.add", [0.5, 1], code: "r02-g13.not-whole")
                == Self.rejection("That value must be a whole number."))
        // `stage` is provoked in the win test; the other codes cannot arise through the core.
        let codes: [String] = ["r02-g13.locked", "r02-g13.date", "r02-g13.action", "r02-g13.stage", "r02-g13.not-whole",
                               "r02-g13.no-replay", "r02-g13.replay-end", "r02-g13.replay",
                               "r02-g13.stale", "r02-g13.level", "r02-g13.malformed", "r02-g13.newer-schema",
                               "action.out-of-range", ""]
        let refusedText: String = "That action was refused."
        let texts: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That change is not allowed for these stars.", "The level has ended.",
                               "That value must be a whole number.",
                               "There is no saved solution to replay for this level.", "The replay is over.",
                               "Stop the replay first.", refusedText, refusedText, refusedText,
                               refusedText, refusedText, refusedText]
        #expect(codes.count == texts.count)
        for index in codes.indices {
            #expect(Plan.refusalText(code: codes[index]) == texts[index], "\(codes[index])")
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == texts[index], "\(codes[index])")
            #expect(Plan.refused(code: codes[index]) == Self.rejection(texts[index]))
            #expect(Plan.refused(code: "action.rule." + codes[index]) == Self.rejection(texts[index]))
        }
        // A code that only contains a known code is not that code.
        #expect(Plan.refusalText(code: "x.r02-g13.locked") == refusedText)
        // Another game's code is not this game's.
        #expect(Plan.refusalText(code: "r02-g12.locked") == refusedText)
    }

    @Test func aMissingPairListenPlansOnlyTheOutcome() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let failure: String = "Action 1 (the listen) found the symbol's pair star 0 \u{2013} star 1 unlinked. "
            + Self.advice
        #expect(Self.accepted(&core, "constellation.listen") == Self.failed(failure))
        #expect(core.play.stage == .failed)
        #expect(Self.refused(&core, "link.add", [0, 1], code: "r02-g13.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 symbol pair missing, 9 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.failed(failure))
    }

    @Test func aDisconnectedAndAnIncoherentListenPlanOnlyTheOutcome() async throws {
        var snapping: Core = try await Core.prepare(seed: 2)
        #expect(Self.link(&snapping, 0, 2).text == "Linked star 0 to star 2, gap 5. 1 symbol pair missing, "
                + "10 actions left.")
        #expect(Self.link(&snapping, 1, 2).text == "Linked star 1 to star 2, gap 5. The symbol is linked, "
                + "9 actions left.")
        #expect(Self.nudge(&snapping, 2, 1)
                == Self.state("Star 2 nudged to phase 10. The symbol is linked, 8 actions left."))
        let snapped: String = "Action 4 (the listen): on tick 1 the link from star 1 to star 2 snapped and the symbol "
            + "came apart. " + Self.advice
        #expect(Self.accepted(&snapping, "constellation.listen") == Self.failed(snapped))
        #expect(Self.accepted(&snapping, "play.undo")
                == Self.state("Undone. The symbol is linked, 8 actions left."))
        #expect(Self.accepted(&snapping, "play.redo") == Self.failed(snapped))

        var incoherent: Core = try await Core.prepare(seed: 19)
        #expect(Self.link(&incoherent, 0, 2)
                == Self.state("Linked star 0 to star 2, gap 2. 1 symbol pair missing, 7 actions left."))
        #expect(Self.link(&incoherent, 0, 3)
                == Self.state("Linked star 0 to star 3, gap 2. The symbol is linked, 6 actions left."))
        #expect(Self.nudge(&incoherent, 0, 1)
                == Self.state("Star 0 nudged to phase 7. The symbol is linked, 5 actions left."))
        #expect(Self.accepted(&incoherent, "constellation.listen")
                == Self.failed("Action 4 (the listen): the stars held together for at most 0 of the 6 ticks needed "
                               + "within 24. " + Self.advice))
    }

    @Test func aBudgetEndingNudgePlansOnlyTheWarning() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        for index in 0..<8 {
            let step: Int = index % 2 == 0 ? 1 : -1
            let phase: Int = index % 2 == 0 ? 8 : 7
            let left: Int = 8 - index
            let noun: String = left == 1 ? "action" : "actions"
            #expect(Self.nudge(&core, 0, step) == Self.state("Star 0 nudged to phase \(phase). 1 symbol pair missing, "
                                                             + "\(left) \(noun) left."))
        }
        let failure: String = "Action 9 (a nudge of star 0 by +1) spent the last move without a win. " + Self.advice
        #expect(Self.nudge(&core, 0, 1) == Self.failed(failure))
        #expect(core.play.stage == .failed && core.play.actionsLeft == 0)
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 symbol pair missing, 1 action left."))
        #expect(Self.accepted(&core, "play.redo") == Self.failed(failure))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 symbol pair missing, 1 action left."))
        // The last action as a listen: the missing pair is the outcome.
        let missing: String = "Action 9 (the listen) found the symbol's pair star 0 \u{2013} star 1 unlinked. "
            + Self.advice
        #expect(Self.accepted(&core, "constellation.listen") == Self.failed(missing))
    }

    @Test func levelAndModeChanges() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.levelNumber == 1 && core.tutorial == .link)
        // A link on a tutorial level: the tutorial moves on, the plan is the link's.
        #expect(Self.link(&core, 0, 1)
                == Self.state("Linked star 0 to star 1, gap 2. The symbol is linked, 8 actions left."))
        #expect(core.tutorial != .link)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.linkStep))
        // The dismissal plans nothing.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.linkStep))
        // The same untouched play reopened with its tutorial shown again.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.linkStep))
        // Reopening the untouched play with the tutorial still shown changes nothing.
        #expect(Self.accepted(&core, "mode.campaign") == Plan.none)
        // A linked play reselected: a fresh play, the level plan.
        #expect(Self.link(&core, 0, 1).kind == .state)
        #expect(Self.accepted(&core, "level.select", [1]) == Self.level("Level 1, band 1, campaign. " + Self.linkStep))
        // The daily level 1 (2026-01-01): the same play in another mode.
        #expect(Self.accepted(&core, "mode.daily", [2026, 1, 1]) == Self.level("Level 1, band 1, daily. "
                                                                               + Self.linkStep))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 23]) == Self.level("Level 15, band 1, daily."))
        // Level 15 is not open in the campaign: back to the frontier, level 1.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.linkStep))
        // Win level 1 and move on: level 2 carries the tutorial too.
        #expect(Self.link(&core, 0, 1).kind == .state)
        #expect(Self.accepted(&core, "constellation.listen")
                == Self.won("The symbol rings together. Level won spending 2 actions, 3 of 3 stars."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.linkStep))
    }

    @Test func choosingTheDragPreviewAndUnchangedCoresPlanNothing() async throws {
        let core: Core = try await Core.prepare(seed: 40)
        // Choosing a star or partner and the drag preview are presentation only: the core does not change.
        #expect(Plan.after(old: core, new: core) == Plan.none)
        let first: String = Plan.summaryText(core: core, star: 0, partner: 1)
        let second: String = Plan.summaryText(core: core, star: 1, partner: 2)
        #expect(first != second)
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Plan.none == Plan(text: nil, kind: nil, haptic: nil))
        // A snapshot at any time is presentation too.
        let snapshot: AcousticConstellatorSceneSnapshot = core.snapshot(time: 7.3)
        #expect(snapshot.levelNumber == 41)
        #expect(Plan.after(old: core, new: core) == Plan.none)
    }

    @Test func aRevealedHintAndTheSummary() async throws {
        #expect(Plan.hint(text: "Link star 0 to star 1") == Plan(text: "Link star 0 to star 1", kind: .state,
                                                                  haptic: nil))
        let one: Core = try await Core.prepare(seed: 0)
        let levelOne: String = "Level: level 1, band 1, campaign; 3 stars, 2 symbol pairs, 1 fixed link; a hold of 8 "
            + "ticks within 24; a budget of 9 actions."
        #expect(Plan.summaryText(core: one, star: 0, partner: 1)
                == "9 actions left. 1 symbol pair missing. Tick 0: coherence 7 of 12, run 0 of 8. Chosen: star 0, "
                + "rate 9, phase 7 and star 1, rate 9, phase 5, not linked. " + levelOne)
        // A missing pair ends the listen report on tick 0, which is not coherent: run 0. A linked pair (the fixed link
        // 1–2), the same star twice, and a star the level lacks.
        #expect(Plan.summaryText(core: one, star: 2, partner: 1)
                == "9 actions left. 1 symbol pair missing. Tick 0: coherence 7 of 12, run 0 of 8. Chosen: star 2, "
                + "rate 10, phase 4 and star 1, rate 9, phase 5, linked. " + levelOne)
        #expect(Plan.summaryText(core: one, star: 1, partner: 1)
                == "9 actions left. 1 symbol pair missing. Tick 0: coherence 7 of 12, run 0 of 8. Chosen: star 1, "
                + "rate 9, phase 5 and star 1, rate 9, phase 5. " + levelOne)
        #expect(Plan.summaryText(core: one, star: 0, partner: 9)
                == "9 actions left. 1 symbol pair missing. Tick 0: coherence 7 of 12, run 0 of 8. Chosen: star 0, "
                + "rate 9, phase 7 and star 9. " + levelOne)
        var won: Core = try await Core.prepare(seed: 40)
        for action in try Core.generated(number: 41).actions { _ = Self.act(&won, action) }
        let tick: Int = won.play.report.lastTick
        #expect(Plan.summaryText(core: won, star: 3, partner: 4)
                == "9 actions left. 0 symbol pairs missing. Tick \(tick): coherence "
                + "\(won.snapshot(time: 0).coherenceBars(at: tick)) of 12, run 7 of 7. Chosen: star 3, rate 10, "
                + "phase 8 and star 4, rate 11, phase 10, linked. Level: level 41, band 3, campaign; 5 stars, 5 symbol "
                + "pairs, 2 fixed links; a hold of 7 ticks within 32; a budget of 13 actions.")
        // 1 action left in a play one nudge from the budget's end.
        var low: Core = try await Core.prepare(seed: 0)
        for index in 0..<8 { _ = Self.nudge(&low, 0, index % 2 == 0 ? 1 : -1) }
        #expect(Plan.summaryText(core: low, star: 0, partner: 1).hasPrefix("1 action left. 1 symbol pair missing. "))
    }

    /// Feature 427: the replay is worded like play — its opening as a level change, each step like the action it
    /// applies, the replayed win without stars — and its refusals have their own words.
    @Test func aReplayIsAnnouncedLikePlayAndItsWinClaimsNoStars() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(Self.refused(&core, "replay.start", [41], code: "r02-g13.no-replay")
                == Self.rejection("There is no saved solution to replay for this level."))
        #expect(Self.refused(&core, "replay.step", [], code: "r02-g13.no-replay")
                == Self.rejection("There is no saved solution to replay for this level."))
        let witness: [AcousticConstellatorAction] = try Core.generated(number: 41).actions
        for action in witness { _ = Self.act(&core, action) }
        #expect(core.play.stage == .won)
        #expect(Self.accepted(&core, "replay.start", [41]) == Self.level("Level 41, band 3, replay."))
        #expect(Self.refused(&core, "link.add", [1, 4], code: "r02-g13.replay")
                == Self.rejection("Stop the replay first."))
        #expect(Self.accepted(&core, "replay.step")
                == Self.state("Linked star 1 to star 4, gap 6. 2 symbol pairs missing, 12 actions left."))
        #expect(Self.accepted(&core, "replay.step")
                == Self.state("Linked star 2 to star 3, gap 1. 1 symbol pair missing, 11 actions left."))
        #expect(Self.accepted(&core, "replay.step")
                == Self.state("Linked star 3 to star 4, gap 2. The symbol is linked, 10 actions left."))
        #expect(Self.accepted(&core, "replay.step")
                == Self.won("The symbol rings together. Level won spending 4 actions."))
        #expect(Self.refused(&core, "replay.step", [], code: "r02-g13.replay-end")
                == Self.rejection("The replay is over."))
        // The sound setting changes no announced state.
        #expect(Self.accepted(&core, "settings.sound", [1]) == Plan.none)
        #expect(Self.accepted(&core, "replay.stop") == Self.level("Level 41, band 3, campaign."))
    }
}
