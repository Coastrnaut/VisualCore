// HarmonicBridgesFeedbackPlanTests — feature 416 (R02-G12-06) T-R02G1206-003 (FR-R02G1206-001, 002, 003;
// SC-R02G1206-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `HarmonicBridgesFeedbackPlan` on
// real certified cores driven through `HarmonicBridgesExperienceCore.apply`: tunings, an undo and a redo, then a 3-star
// campaign win (the winning test plans only the outcome) and the `stage` refusals after it; a 2-star campaign win with
// an undone detour, a practice win without stars and a daily win; every refusal code (provoked where the core can
// produce it, every code by table, bare and with the engine's `action.rule.` prefix); a failure by a broken test (undo
// and a redo that fails again plan the outcome only) and by the budget (the budget-ending tuning plans only the
// warning); level and mode changes with and without the tutorial; choosing and previewing (no core change) and the
// dismissal plan nothing; a revealed hint; the summary element.
// Seed 40 opens level 41 (band 3, no tutorial): 7 strings at pegs 7, 11, 7 (locked), 7 (locked), 4, 3, 11; 6 islands
// from 0 to 5; 2 steps; budget 13; certified witness tune 0, 1, 4, 5 to peg 12 and test (5 actions). Seed 0 opens level
// 1 (tutorial): 1 string at peg 11, 2 islands, 1 step, budget 9; witness tune 0 to 12 and test (2 actions). The daily
// level of 2026-11-23 is level 59 (band 3), witness tune 2, 4, 5 to 12 and test. The expected texts are written out
// here, not built with the plan's helpers. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import HarmonicBridgesCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct HarmonicBridgesFeedbackPlanTests {
    typealias Core = HarmonicBridgesExperienceCore
    typealias Plan = HarmonicBridgesFeedbackPlan

    /// The seed of level 41.
    static let seed41: UInt64 = 40

    /// The seed of level 1 (the tutorial).
    static let seed1: UInt64 = 0

    /// The tutorial's first instruction (feature 415).
    static let tuneStep: String = "Drag a string's peg up or down (or use the panel's peg steppers and Tune) — when one "
        + "of its harmonics matches a tone of the step it swings and its samples fill"

    /// The advice that ends every failure explanation (feature 415).
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

    /// Applies the tuning of `string` to `peg` and returns the plan.
    static func tune(_ core: inout Core, _ string: Int, _ peg: Int) -> Plan {
        accepted(&core, "string.tune", [Double(string), Double(peg)])
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

    @Test func tuningsUndoRedoAndA3StarCampaignWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed41)
        #expect(core.levelNumber == 41 && core.tutorial == .done && core.certifiedActions == 5)
        #expect(Self.tune(&core, 0, 12)
                == Self.state("String 0 tuned to peg 12. The start reaches the goal in 0 of 2 steps, 12 actions left."))
        #expect(Self.tune(&core, 1, 12)
                == Self.state("String 1 tuned to peg 12. The start reaches the goal in 0 of 2 steps, 11 actions left."))
        #expect(Self.tune(&core, 4, 12)
                == Self.state("String 4 tuned to peg 12. The start reaches the goal in 0 of 2 steps, 10 actions left."))
        #expect(Self.accepted(&core, "play.undo")
                == Self.state("Undone. The start reaches the goal in 0 of 2 steps, 11 actions left."))
        #expect(Self.accepted(&core, "play.redo")
                == Self.state("Redone. The start reaches the goal in 0 of 2 steps, 10 actions left."))
        #expect(Self.tune(&core, 5, 12)
                == Self.state("String 5 tuned to peg 12. The start reaches the goal in 2 of 2 steps, 9 actions left."))
        // The test always ends the level: it plans only the outcome.
        #expect(Self.accepted(&core, "crossing.test")
                == Self.won("The crossing holds in every step. Level won spending 5 actions, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won play is final: the real `stage` refusals.
        #expect(Self.refused(&core, "string.tune", [0, 3], code: "r02-g12.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "crossing.test", [], code: "r02-g12.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g12.stage") == Self.rejection("The level has ended."))
        // level.next after the win opens level 42.
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 42, band 3, campaign."))
    }

    @Test func a2StarCampaignWinAPracticeWinWithoutStarsAndADailyWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed41)
        let witness: [HarmonicBridgesAction] = try Core.generated(number: 41).actions
        #expect(Self.tune(&core, 0, 3)
                == Self.state("String 0 tuned to peg 3. The start reaches the goal in 0 of 2 steps, 12 actions left."))
        #expect(Self.accepted(&core, "play.undo")
                == Self.state("Undone. The start reaches the goal in 0 of 2 steps, 13 actions left."))
        var plans: [Plan] = []
        for action in witness { plans.append(Self.act(&core, action)) }
        // The undone detour still counts: 6 actions against the certified 5 → 2 stars.
        #expect(plans.last == Self.won("The crossing holds in every step. Level won spending 6 actions, 2 of 3 stars."))
        for index in 0..<(plans.count - 1) { #expect(plans[index].kind == .state && plans[index].haptic == .selection) }

        var practice: Core = try await Core.prepare(seed: Self.seed41)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 41, band 3, practice."))
        #expect(Self.tune(&practice, 0, 12)
                == Self.state("String 0 tuned to peg 12. The start reaches the goal in 0 of 2 steps, 59 actions left."))
        var last: Plan = .none
        for action in witness.dropFirst() { last = Self.act(&practice, action) }
        #expect(last == Self.won("The crossing holds in every step. Level won spending 5 actions."))

        var daily: Core = try await Core.prepare(seed: Self.seed41)
        #expect(Self.accepted(&daily, "mode.daily", [2026, 11, 23]) == Self.level("Level 59, band 3, daily."))
        for action in try Core.generated(number: 59).actions { last = Self.act(&daily, action) }
        #expect(last == Self.won("The crossing holds in every step. Level won spending 4 actions, 3 of 3 stars."))
    }

    /// Applies the kernel `action` through the adapter, expects it accepted and returns the plan.
    static func act(_ core: inout Core, _ action: HarmonicBridgesAction) -> Plan {
        switch action {
        case let .tune(string, peg): tune(&core, string, peg)
        case .test: accepted(&core, "crossing.test")
        }
    }

    @Test func everyRefusalCode() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed1)
        #expect(Self.refused(&core, "level.select", [2], code: "r02-g12.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g12.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g12.date")
                == Self.rejection("That date cannot be used."))
        #expect(Self.refused(&core, "string.tune", [1, 3], code: "r02-g12.action")
                == Self.rejection("That string cannot be tuned to that peg."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g12.action")
                == Self.rejection("That string cannot be tuned to that peg."))
        #expect(Self.refused(&core, "string.tune", [0, 11], code: "r02-g12.noop")
                == Self.rejection("That string is already at that peg."))
        #expect(Self.refused(&core, "string.tune", [0.5, 2], code: "r02-g12.not-whole")
                == Self.rejection("That value must be a whole number."))
        var locked: Core = try Core.opening(number: 2)
        #expect(Self.refused(&locked, "string.tune", [0, 3], code: "r02-g12.action")
                == Self.rejection("That string cannot be tuned to that peg."))
        // `stage` is provoked in the win test; the other codes cannot arise through the core.
        let codes: [String] = ["r02-g12.locked", "r02-g12.date", "r02-g12.action", "r02-g12.noop", "r02-g12.stage",
                               "r02-g12.not-whole", "r02-g12.stale", "r02-g12.level", "r02-g12.malformed",
                               "r02-g12.newer-schema", "action.out-of-range", ""]
        let texts: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That string cannot be tuned to that peg.", "That string is already at that peg.",
                               "The level has ended.", "That value must be a whole number.",
                               "That action was refused.", "That action was refused.", "That action was refused.",
                               "That action was refused.", "That action was refused.", "That action was refused."]
        #expect(codes.count == texts.count)
        for index in codes.indices {
            #expect(Plan.refusalText(code: codes[index]) == texts[index], "\(codes[index])")
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == texts[index], "\(codes[index])")
            #expect(Plan.refused(code: codes[index]) == Self.rejection(texts[index]))
            #expect(Plan.refused(code: "action.rule." + codes[index]) == Self.rejection(texts[index]))
        }
        // A code that only contains a known code is not that code.
        #expect(Plan.refusalText(code: "x.r02-g12.locked") == "That action was refused.")
    }

    @Test func aBrokenTestPlansOnlyTheOutcome() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed41)
        #expect(Self.tune(&core, 0, 12)
                == Self.state("String 0 tuned to peg 12. The start reaches the goal in 0 of 2 steps, 12 actions left."))
        let failure: String = "Action 2 (the test) broke the crossing in step 0 at string 1: the start reached the goal "
            + "in 0 of 2 steps. " + Self.advice
        #expect(Self.accepted(&core, "crossing.test") == Self.failed(failure))
        #expect(core.play.stage == .failed)
        #expect(Self.refused(&core, "string.tune", [1, 12], code: "r02-g12.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "play.undo")
                == Self.state("Undone. The start reaches the goal in 0 of 2 steps, 12 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.failed(failure))
    }

    @Test func aBudgetEndingTuningPlansOnlyTheWarning() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed1)
        for index in 0..<8 {
            let peg: Int = index % 2 + 1
            let left: Int = 8 - index
            let noun: String = left == 1 ? "action" : "actions"
            #expect(Self.tune(&core, 0, peg) == Self.state("String 0 tuned to peg \(peg). The start reaches the goal "
                                                           + "in 0 of 1 steps, \(left) \(noun) left."))
        }
        let failure: String = "Action 9 (a tuning of string 0 to peg 1) spent the last move without a win: the start "
            + "reached the goal in 0 of 1 steps. " + Self.advice
        #expect(Self.tune(&core, 0, 1) == Self.failed(failure))
        #expect(core.play.stage == .failed && core.play.actionsLeft == 0)
        #expect(Self.accepted(&core, "play.undo")
                == Self.state("Undone. The start reaches the goal in 0 of 1 steps, 1 action left."))
        #expect(Self.accepted(&core, "play.redo") == Self.failed(failure))
        #expect(Self.accepted(&core, "play.undo")
                == Self.state("Undone. The start reaches the goal in 0 of 1 steps, 1 action left."))
        // The last action as a test: the broken test is the outcome.
        let broken: String = "Action 9 (the test) broke the crossing in step 0 at string 0: the start reached the goal "
            + "in 0 of 1 steps. " + Self.advice
        #expect(Self.accepted(&core, "crossing.test") == Self.failed(broken))
    }

    @Test func levelAndModeChanges() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed1)
        #expect(core.levelNumber == 1 && core.tutorial == .tune)
        // A tuning on a tutorial level: the tutorial moves on, the plan is the tuning's.
        #expect(Self.tune(&core, 0, 3)
                == Self.state("String 0 tuned to peg 3. The start reaches the goal in 0 of 1 steps, 8 actions left."))
        #expect(core.tutorial != .tune)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.tuneStep))
        // The dismissal plans nothing.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.tuneStep))
        // The same untouched play reopened with its tutorial shown again.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.tuneStep))
        // Reopening the untouched play with the tutorial still shown changes nothing.
        #expect(Self.accepted(&core, "mode.campaign") == Plan.none)
        // A tuned play reselected: a fresh play, the level plan.
        #expect(Self.tune(&core, 0, 4).kind == .state)
        #expect(Self.accepted(&core, "level.select", [1]) == Self.level("Level 1, band 1, campaign. " + Self.tuneStep))
        // The daily level 1 (2026-01-01): the same play in another mode.
        #expect(Self.accepted(&core, "mode.daily", [2026, 1, 1]) == Self.level("Level 1, band 1, daily. "
                                                                               + Self.tuneStep))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 23]) == Self.level("Level 59, band 3, daily."))
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.tuneStep))
        // Win level 1 and move on: level 2 carries the tutorial too.
        #expect(Self.tune(&core, 0, 12).kind == .state)
        #expect(Self.accepted(&core, "crossing.test")
                == Self.won("The crossing holds in every step. Level won spending 2 actions, 3 of 3 stars."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.tuneStep))
    }

    @Test func choosingPreviewingAndUnchangedCoresPlanNothing() async throws {
        let core: Core = try await Core.prepare(seed: Self.seed41)
        // Choosing a string and previewing a peg are presentation only: the core does not change.
        #expect(Plan.after(old: core, new: core) == Plan.none)
        let first: String = Plan.summaryText(core: core, string: 0, peg: 5)
        let second: String = Plan.summaryText(core: core, string: 1, peg: 9)
        #expect(first != second)
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Plan.none == Plan(text: nil, kind: nil, haptic: nil))
        // A snapshot at any time is presentation too.
        let snapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: 7.3)
        #expect(snapshot.levelNumber == 41)
        #expect(Plan.after(old: core, new: core) == Plan.none)
    }

    @Test func aRevealedHintAndTheSummary() async throws {
        #expect(Plan.hint(text: "Tune string 0 to peg 12.") == Plan(text: "Tune string 0 to peg 12.", kind: .state,
                                                                     haptic: nil))
        let one: Core = try await Core.prepare(seed: Self.seed1)
        #expect(Plan.summaryText(core: one, string: 0, peg: 5)
                == "9 actions left. The start reaches the goal in 0 of 1 steps. Step 0 shows 0 bridges. Chosen: "
                + "string 0, island 0 to island 1, peg 11, tune to peg 5. Level: level 1, band 1, campaign; 2 islands, "
                + "start island 0, goal island 1; 1 string; 1 step; a budget of 9 actions.")
        // A string the level lacks reads by its number.
        #expect(Plan.summaryText(core: one, string: 9, peg: 2)
                == "9 actions left. The start reaches the goal in 0 of 1 steps. Step 0 shows 0 bridges. Chosen: "
                + "string 9, tune to peg 2. Level: level 1, band 1, campaign; 2 islands, start island 0, goal island 1; "
                + "1 string; 1 step; a budget of 9 actions.")
        let two: Core = try Core.opening(number: 2)
        #expect(Plan.summaryText(core: two, string: 0, peg: 5)
                == "10 actions left. The start reaches the goal in 0 of 1 steps. Step 0 shows 1 bridge. Chosen: "
                + "string 0, island 0 to island 1, peg 11, locked, tune to peg 5. Level: level 2, band 1, campaign; "
                + "5 islands, start island 0, goal island 4; 4 strings; 1 step; a budget of 10 actions.")
        var won: Core = try await Core.prepare(seed: Self.seed41)
        for action in try Core.generated(number: 41).actions { _ = Self.act(&won, action) }
        #expect(Plan.summaryText(core: won, string: 0, peg: 12)
                == "8 actions left. The start reaches the goal in 2 of 2 steps. Step 0 shows "
                + "\(Self.bridges(won, step: 0)) bridges. Chosen: string 0, island 1 to island 5, peg 12, tune to peg "
                + "12. Level: level 41, band 3, campaign; 6 islands, start island 0, goal island 5; 7 strings; 2 steps; "
                + "a budget of 13 actions.")
        // A failed play by the budget: the resting step 0 (the summary takes no presentation time).
        var failing: Core = try await Core.prepare(seed: Self.seed1)
        for index in 0..<9 { _ = Self.tune(&failing, 0, index % 2 + 1) }
        #expect(Plan.summaryText(core: failing, string: 0, peg: 1)
                == "0 actions left. The start reaches the goal in 0 of 1 steps. Step 0 shows 0 bridges. Chosen: "
                + "string 0, island 0 to island 1, peg 1, tune to peg 1. Level: level 1, band 1, campaign; 2 islands, "
                + "start island 0, goal island 1; 1 string; 1 step; a budget of 9 actions.")
    }

    /// The bridges of `core`'s report in `step`, counted directly.
    static func bridges(_ core: Core, step: Int) -> Int {
        var count: Int = 0
        for bridge in core.play.report.bridges[step] where bridge { count += 1 }
        return count
    }
}
