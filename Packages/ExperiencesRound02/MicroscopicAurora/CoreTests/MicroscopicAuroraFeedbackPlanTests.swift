// MicroscopicAuroraFeedbackPlanTests — feature 486 (R02-G19-06) T-R02G1906-003 (FR-R02G1906-001, 002, 003;
// SC-R02G1906-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `MicroscopicAuroraFeedbackPlan`
// on real certified cores driven through `MicroscopicAuroraExperienceCore.apply`: placements with an undo and a redo,
// then a 3-star campaign win along the certified plan (the play plans only the outcome) and the `stage` refusals after
// it; a 2-star win after a placement and a removal, a 1-star win after undone placements (undone ones count), a
// 1-action win, a practice win without stars and daily wins; every refusal code (provoked through the adapter where
// the core can produce it, with the engine's `action.rule.` prefix as `ActionResult.code` reports it, the engine's own
// range refusal, and every code by table, bare and prefixed); failed plays of every failure kind (coverage from level
// 1's opening, coherence from level 3's, exit after a placement on level 3, connectedness after a placement on level
// 1), each with an undo (state) and a redo back into the failure (only the outcome); a whole budget spent (the 10th
// placement refused `budget`, the play then fails); level and mode changes with and without the tutorial; showing a
// tick and dismissing the tutorial plan nothing; a revealed hint; the summary element with a selected well and with no
// site. Level facts used (read from the kernel's reports of the certified levels, worked out independently of the
// plan): level 1 (tutorial): stencil 24 cells, coverage 71.5 % (18 cells needed), 4 swimmers, 120 ticks, sites (9, 7),
// (11, 18), (17, 8), budget 9, certified plan one clockwise well of strength 2 on (11, 18), which lights 22 cells and
// wins; its opening (no wells) lights 4 cells and fails coverage; a well on (9, 7) of strength 1 or 2 clockwise still
// lights 4; a counterclockwise well of strength 1 on (17, 8) lights 18 cells but leaves (11, 10) cut off
// (connectedness). Level 3 (tutorial, budget 11, stencil 24, coherence 3): its opening lights 8 cells and splits at
// tick 81 into a largest group of 2; a clockwise well of strength 1 on (9, 14) lights 14 cells and swimmer 3 leaves the
// dish at tick 116. Level 41 (band 3, no tutorial): stencil 34 cells, coverage 85.5 % (30 needed), 6 swimmers, 140
// ticks, 4 sites, budget 13, certified plan counterclockwise wells of strength 2 on (5, 14) and (14, 15) (34 cells,
// a win); its opening lights 7 cells; (5, 14) alone lights 16 and fails; with a clockwise well of strength 1 on (7, 5)
// still 16. Level 4: budget 8, no tutorial. The daily level of 2026-01-01 is level 1, that of 2026-11-26 level 52
// (band 3). The expected texts are written out here, not built with the plan's helpers. Explicit types, plain loops,
// short runs. Modelled on feature 476's ApsidesWorkshopFeedbackPlanTests.
import Foundation
import Testing
@testable import MicroscopicAuroraCore
import VisualCoreExperience
import VisualCoreSimulation

/// One failed play: the level, the placement made first (nil for the opening wells), the failure code, the
/// placement's announcement, the explanation's sentence and the progress after undoing the play.
private struct FailureCase {
    /// The manifest number.
    let level: Int
    /// The `well.place` values made before the play, or nil.
    let placement: [Double]?
    /// The placement's announcement (unused without a placement).
    let placed: String
    /// The failure code.
    let code: String
    /// The explanation's sentence (before the advice).
    let sentence: String
    /// The progress after the undo.
    let progress: String
}

@Suite struct MicroscopicAuroraFeedbackPlanTests {
    typealias Core = MicroscopicAuroraExperienceCore
    typealias Plan = MicroscopicAuroraFeedbackPlan

    /// The tutorial's first instruction (feature 485).
    static let placeStep: String = "Tap a marked site (or choose a site and press Place) to put a magnetic well there; "
        + "the trails and gauges show the new swim"

    /// The advice that ends every failure explanation (feature 485).
    static let advice: String = "Undo the last action or retry the level."

    /// The opening sentence of a win.
    static let won: String = "The trails covered the stencil as one pattern."

    /// The words of a `stage` refusal.
    static let ended: String = "The level has ended."

    /// The words of an `action` refusal.
    static let cannot: String = "That well cannot be placed there, or there is nothing to remove, undo or redo."

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

    /// Places a well in `slot` on (`row`, `column`) of `strength`, clockwise unless `counter`, and returns the plan.
    static func place(_ core: inout Core, _ slot: Int, _ row: Int, _ column: Int, _ strength: Int,
                      counter: Bool = false) -> Plan {
        accepted(&core, "well.place", [Double(slot), Double(row), Double(column), Double(strength), counter ? 1 : 0])
    }

    /// Plays the swim and returns the plan.
    static func play(_ core: inout Core) -> Plan {
        accepted(&core, "swim.play")
    }

    /// Applies `control` with `values` to `core`, expects the refusal with bare reason code `code` and the core
    /// unchanged with no change plan, and returns the refusal plan of the code as the engine reports it.
    static func refused(_ core: inout Core, _ control: String, _ values: [Double], code: String) -> Plan {
        let old: Core = core
        let result: ActionResult = core.apply(bare(control, values))
        #expect(result == .rejected(.rule(code: code)), "\(control) \(values): \(result)")
        #expect(result.code == "action.rule." + code)
        #expect(core == old)
        #expect(Plan.after(old: old, new: core) == Plan.none)
        #expect(Plan.refused(code: code) == Plan.refused(code: result.code))
        return Plan.refused(code: result.code)
    }

    /// A `state` plan with haptic `selection`.
    static func state(_ text: String) -> Plan { Plan(text: text, kind: .state, haptic: .selection) }

    /// A `level` plan without haptic.
    static func level(_ text: String) -> Plan { Plan(text: text, kind: .level, haptic: nil) }

    /// A `rejection` plan with haptic `error`.
    static func rejection(_ text: String) -> Plan { Plan(text: text, kind: .rejection, haptic: .error) }

    /// An `outcome` plan with haptic `success`.
    static func success(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .success) }

    /// An `outcome` plan with haptic `warning`.
    static func warning(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .warning) }

    @Test func placementsUndoRedoAndA3StarCampaignWin() throws {
        var core: Core = try Core.opening(number: 41)
        #expect(core.tutorial == .done && core.certifiedPlacements == 2 && core.play.level.budget == 13)
        #expect(Self.place(&core, 0, 5, 14, 2, counter: true) == Self.state("Well 1 placed at row 5, column 14, "
            + "strength 2, counterclockwise. 16 of 34 stencil cells lit, playing now would fail, 12 actions left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 7 of 34 stencil cells lit, playing now would "
            + "fail, 13 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 16 of 34 stencil cells lit, playing now would "
            + "fail, 12 actions left."))
        #expect(Self.place(&core, 1, 14, 15, 2, counter: true) == Self.state("Well 2 placed at row 14, column 15, "
            + "strength 2, counterclockwise. 34 of 34 stencil cells lit, playing now would win, 11 actions left."))
        // The play plans only the outcome: 2 placements (the redo spends nothing) against the certified 2.
        #expect(Self.play(&core) == Self.success(Self.won + " Level won spending 2 actions, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won play is final: the real `stage` refusals.
        let ended: Plan = Self.rejection(Self.ended)
        #expect(Self.refused(&core, "well.place", [2, 7, 5, 1, 0], code: "r02-g19.stage") == ended)
        #expect(Self.refused(&core, "well.remove", [0], code: "r02-g19.stage") == ended)
        #expect(Self.refused(&core, "swim.play", [], code: "r02-g19.stage") == ended)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g19.stage") == ended)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g19.stage") == ended)
        // The campaign win opened level 42.
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 42, band 3, campaign."))
        // "1 action" singular, on the tutorial level 1 (certified plan of 1 placement); the next level shows the
        // tutorial again.
        var first: Core = try Core.opening(number: 1)
        #expect(first.certifiedPlacements == 1 && first.tutorial == .place)
        #expect(Self.place(&first, 0, 11, 18, 2) == Self.state("Well 1 placed at row 11, column 18, strength 2, "
            + "clockwise. 22 of 24 stencil cells lit, playing now would win, 8 actions left."))
        #expect(Self.play(&first) == Self.success(Self.won + " Level won spending 1 action, 3 of 3 stars."))
        #expect(Self.accepted(&first, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.placeStep))
    }

    @Test func removalsAndUndoneActionsCountAndPracticeAndDailyWins() throws {
        // A placement and a removal on the way: 4 actions against the certified 2 → 2 stars.
        var two: Core = try Core.opening(number: 41)
        #expect(Self.place(&two, 0, 5, 14, 2, counter: true).kind == .state)
        #expect(Self.place(&two, 1, 7, 5, 1) == Self.state("Well 2 placed at row 7, column 5, strength 1, clockwise. "
            + "16 of 34 stencil cells lit, playing now would fail, 11 actions left."))
        #expect(Self.accepted(&two, "well.remove", [1]) == Self.state("Well 2 removed. 16 of 34 stencil cells lit, "
            + "playing now would fail, 10 actions left."))
        #expect(Self.place(&two, 1, 14, 15, 2, counter: true) == Self.state("Well 2 placed at row 14, column 15, "
            + "strength 2, counterclockwise. 34 of 34 stencil cells lit, playing now would win, 9 actions left."))
        #expect(Self.play(&two) == Self.success(Self.won + " Level won spending 4 actions, 2 of 3 stars."))
        // Three undone placements on level 1: 4 actions against the certified 1 → 1 star.
        var one: Core = try Core.opening(number: 1)
        for _ in 0..<3 {
            #expect(Self.place(&one, 0, 11, 18, 2).haptic == .selection)
            #expect(Self.accepted(&one, "play.undo") == Self.state("Undone. 4 of 24 stencil cells lit, playing now "
                + "would fail, 9 actions left."))
        }
        #expect(Self.place(&one, 0, 11, 18, 2).kind == .state)
        #expect(Self.play(&one) == Self.success(Self.won + " Level won spending 4 actions, 1 of 3 stars."))
        // Practice: the budget raised to 24, no stars.
        var practice: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 1, band 1, practice. "
            + Self.placeStep))
        #expect(Self.place(&practice, 0, 11, 18, 2) == Self.state("Well 1 placed at row 11, column 18, strength 2, "
            + "clockwise. 22 of 24 stencil cells lit, playing now would win, 23 actions left."))
        #expect(Self.play(&practice) == Self.success(Self.won + " Level won spending 1 action."))
        // Daily: 2026-01-01 is level 1 (its tutorial shown), with stars.
        var daily: Core = try Core.opening(number: 4)
        #expect(Self.accepted(&daily, "mode.daily", [2026, 1, 1])
                == Self.level("Level 1, band 1, daily. " + Self.placeStep))
        #expect(Self.place(&daily, 0, 11, 18, 2) == Self.state("Well 1 placed at row 11, column 18, strength 2, "
            + "clockwise. 22 of 24 stencil cells lit, playing now would win, 8 actions left."))
        #expect(Self.play(&daily) == Self.success(Self.won + " Level won spending 1 action, 3 of 3 stars."))
        // 2026-11-26 is level 52 (band 3, no tutorial).
        #expect(Self.accepted(&daily, "mode.daily", [2026, 11, 26]) == Self.level("Level 52, band 3, daily."))
    }

    @Test func everyRefusalCodeInWords() throws {
        var core: Core = try Core.opening(number: 1)
        let action: Plan = Self.rejection(Self.cannot)
        // Provoked through the adapter (the engine reports `action.rule.<code>`): a cell that is not a site, a cell
        // outside the enclosure, an empty slot removed, nothing to undo or redo.
        #expect(Self.refused(&core, "well.place", [0, 12, 12, 1, 0], code: "r02-g19.action") == action)
        #expect(Self.refused(&core, "well.place", [0, 0, 0, 1, 0], code: "r02-g19.action") == action)
        #expect(Self.refused(&core, "well.remove", [0], code: "r02-g19.action") == action)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g19.action") == action)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g19.action") == action)
        // The same well again, and another slot's cell.
        #expect(Self.place(&core, 0, 9, 7, 1).kind == .state)
        #expect(Self.refused(&core, "well.place", [0, 9, 7, 1, 0], code: "r02-g19.action") == action)
        #expect(Self.refused(&core, "well.place", [1, 9, 7, 3, 1], code: "r02-g19.action") == action)
        #expect(Self.refused(&core, "well.place", [0, 9.5, 7, 1, 0], code: "r02-g19.not-whole")
                == Self.rejection("That value must be a whole number."))
        #expect(Self.refused(&core, "well.remove", [0.25], code: "r02-g19.not-whole")
                == Self.rejection("That value must be a whole number."))
        // Level 1's swim lasts 120 ticks.
        #expect(Self.refused(&core, "clock.show", [121], code: "r02-g19.tick")
                == Self.rejection("That tick is outside the swim."))
        #expect(Self.refused(&core, "clock.show", [480], code: "r02-g19.tick")
                == Self.rejection("That tick is outside the swim."))
        #expect(Self.refused(&core, "level.select", [100], code: "r02-g19.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g19.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g19.date")
                == Self.rejection("That date cannot be used."))
        // The engine's own range refusal (slot 3 is outside 0 … 2) is "any other code".
        let old: Core = core
        let range: ActionResult = core.apply(Self.bare("well.place", [3, 9, 7, 1, 0]))
        #expect(range.code == "action.out-of-range")
        #expect(core == old)
        #expect(Plan.refused(code: range.code) == Self.rejection("That action was refused."))
        // Every code by table, bare and with the engine's prefix.
        let table: [(String, String)] = [
            ("r02-g19.locked", "That level is not open yet."),
            ("r02-g19.date", "That date cannot be used."),
            ("r02-g19.action", "That well cannot be placed there, or there is nothing to remove, undo or redo."),
            ("r02-g19.budget", "No actions are left: undo or retry."),
            ("r02-g19.stage", "The level has ended."),
            ("r02-g19.stale", "The play changed before the action arrived."),
            ("r02-g19.level", "That level could not be made."),
            ("r02-g19.not-whole", "That value must be a whole number."),
            ("r02-g19.tick", "That tick is outside the swim."),
            ("r02-g19.malformed", "That action was refused."),
            ("r02-g19.generation", "That action was refused."),
            ("r02-g19.witness", "That action was refused."),
            ("r02-g18.locked", "That action was refused."),
            ("action.out-of-range", "That action was refused."),
            ("", "That action was refused."),
        ]
        for (code, text) in table {
            #expect(Plan.refusalText(code: code) == text, "\(code)")
            #expect(Plan.refusalText(code: "action.rule." + code) == text, "prefixed \(code)")
            #expect(Plan.refused(code: code) == Self.rejection(text), "\(code)")
            #expect(Plan.refused(code: "action.rule." + code) == Self.rejection(text), "prefixed \(code)")
        }
    }

    @Test func everyFailureKindPlansOnlyItsOutcome() throws {
        let cases: [FailureCase] = [
            FailureCase(level: 1, placement: nil, placed: "", code: "coverage",
                        sentence: "Only 4 stencil cells were lit; 18 were needed.",
                        progress: "4 of 24 stencil cells lit, playing now would fail, 9 actions left."),
            FailureCase(level: 3, placement: nil, placed: "", code: "coherence",
                        sentence: "The swarm split at tick 81: its largest group had 2 swimmers, fewer than the 3 "
                            + "needed.",
                        progress: "8 of 24 stencil cells lit, playing now would fail, 11 actions left."),
            FailureCase(level: 3, placement: [0, 9, 14, 1, 0],
                        placed: "Well 1 placed at row 9, column 14, strength 1, clockwise. 14 of 24 stencil cells "
                            + "lit, playing now would fail, 10 actions left.",
                        code: "exit", sentence: "Swimmer 3 left the dish at tick 116.",
                        progress: "14 of 24 stencil cells lit, playing now would fail, 10 actions left."),
            FailureCase(level: 1, placement: [0, 17, 8, 1, 1],
                        placed: "Well 1 placed at row 17, column 8, strength 1, counterclockwise. 18 of 24 stencil "
                            + "cells lit, playing now would fail, 8 actions left.",
                        code: "connectedness",
                        sentence: "The cell at row 11, column 10 is lit but not joined to the pattern.",
                        progress: "18 of 24 stencil cells lit, playing now would fail, 8 actions left."),
        ]
        var codes: [String] = []
        for sample in cases {
            var core: Core = try Core.opening(number: sample.level)
            if let placement = sample.placement {
                #expect(Self.accepted(&core, "well.place", placement) == Self.state(sample.placed),
                        "level \(sample.level)")
            }
            let failing: Plan = Self.warning(sample.sentence + " " + Self.advice)
            #expect(Self.play(&core) == failing, "level \(sample.level)")
            #expect(core.play.stage == .failed)
            #expect(failing.text == MicroscopicAuroraFailureExplanation(play: core.play)?.text)
            if let failure = core.play.failure { codes.append(failure.code) }
            #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. " + sample.progress),
                    "level \(sample.level)")
            #expect(Self.accepted(&core, "play.redo") == failing, "level \(sample.level)")
        }
        #expect(codes == ["coverage", "coherence", "exit", "connectedness"])
    }

    @Test func aWholeBudgetSpentThenTheBudgetRefusalAndAFailedPlay() throws {
        // Level 1 (budget 9): well 1 on (9, 7) with strength 1, 2, 1, … nine times; every set still lights 4 cells.
        var core: Core = try Core.opening(number: 1)
        #expect(core.play.level.budget == 9)
        let left: [String] = ["8 actions left", "7 actions left", "6 actions left", "5 actions left",
                              "4 actions left", "3 actions left", "2 actions left", "1 action left", "0 actions left"]
        for index in 0..<left.count {
            let strength: Int = index % 2 == 0 ? 1 : 2
            let expected: Plan = Self.state("Well 1 placed at row 9, column 7, strength \(strength), clockwise. 4 of "
                + "24 stencil cells lit, playing now would fail, " + left[index] + ".")
            #expect(Self.place(&core, 0, 9, 7, strength) == expected, "placement \(index + 1)")
            if index == 7 {
                #expect(Plan.summaryText(core: core, selected: nil, slot: 1) == "1 action left. Well 1 at row 9, "
                    + "column 7, strength 2, clockwise; well 2 empty; well 3 empty; stencil 4 of 24 cells lit, 16.6 %, "
                    + "needs 71.5 %; playing now would fail: stencil 4 of 24 cells lit, needs 18. Selected: well 2, "
                    + "no site. Level: level 1, band 1, campaign; a stencil of 24 cells, 18 to light as one pattern, 4 "
                    + "swimmers, a swim of 120 ticks, 3 sites; a budget of 9 actions.")
            }
        }
        #expect(Self.refused(&core, "well.place", [0, 9, 7, 2, 0], code: "r02-g19.budget")
                == Self.rejection("No actions are left: undo or retry."))
        #expect(Self.refused(&core, "well.remove", [0], code: "r02-g19.budget")
                == Self.rejection("No actions are left: undo or retry."))
        // The play is still allowed and plans only the warning.
        let failing: Plan = Self.warning("Only 4 stencil cells were lit; 18 were needed. " + Self.advice)
        #expect(Self.play(&core) == failing)
        let ended: Plan = Self.rejection(Self.ended)
        #expect(Self.refused(&core, "well.place", [0, 9, 7, 2, 0], code: "r02-g19.stage") == ended)
        #expect(Self.refused(&core, "swim.play", [], code: "r02-g19.stage") == ended)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g19.stage") == ended)
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 4 of 24 stencil cells lit, playing now "
            + "would fail, 0 actions left."))
        #expect(Self.accepted(&core, "play.redo") == failing)
    }

    @Test func levelAndModeChanges() throws {
        // Level 1 (tutorial): dismissing plans nothing; reopening it shows the tutorial again.
        var first: Core = try Core.opening(number: 1)
        #expect(first.tutorial == .place)
        #expect(Self.accepted(&first, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&first, "level.select", [1])
                == Self.level("Level 1, band 1, campaign. " + Self.placeStep))
        #expect(Self.accepted(&first, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.placeStep))
        #expect(Self.place(&first, 0, 9, 7, 1) == Self.state("Well 1 placed at row 9, column 7, strength 1, "
            + "clockwise. 4 of 24 stencil cells lit, playing now would fail, 23 actions left."))
        #expect(Self.accepted(&first, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.placeStep))
        // Level 41 (no tutorial): modes, the daily level, other levels.
        var core: Core = try Core.opening(number: 41)
        #expect(Self.place(&core, 0, 5, 14, 2, counter: true).kind == .state)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 41, band 3, practice."))
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 41, band 3, campaign."))
        #expect(Self.place(&core, 0, 5, 14, 2, counter: true).kind == .state)
        #expect(Self.accepted(&core, "level.select", [41]) == Self.level("Level 41, band 3, campaign."))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 26]) == Self.level("Level 52, band 3, daily."))
        #expect(Self.accepted(&core, "level.select", [3])
                == Self.level("Level 3, band 1, campaign. " + Self.placeStep))
        #expect(Self.accepted(&core, "level.select", [4]) == Self.level("Level 4, band 1, campaign."))
        // Reopening an untouched level without a tutorial changes nothing.
        #expect(Self.accepted(&core, "level.select", [4]) == Plan.none)
    }

    @Test func showingATickPlansNothingAHintAndTheSummary() throws {
        var core: Core = try Core.opening(number: 41)
        let ticks: [Double] = [10, 140, 0, 70]
        for tick in ticks {
            #expect(Self.accepted(&core, "clock.show", [tick]) == Plan.none, "tick \(tick)")
        }
        // The tutorial of level 41 is already done: dismissing it changes nothing.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        let hint: Plan = Plan.hint(text: "Use the site at row 5, column 14 next")
        #expect(hint == Plan(text: "Use the site at row 5, column 14 next", kind: .state, haptic: nil))
        let level41: String = "Level: level 41, band 3, campaign; a stencil of 34 cells, 30 to light as one pattern, "
            + "6 swimmers, a swim of 140 ticks, 4 sites; a budget of 13 actions."
        let firstWell: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 5, column: 14),
                                                                     strength: 2, sense: .counterclockwise)
        #expect(Plan.summaryText(core: core, selected: firstWell, slot: 0) == "13 actions left. Well 1 empty; well 2 "
            + "empty; well 3 empty; stencil 7 of 34 cells lit, 20.5 %, needs 85.5 %; playing now would fail: stencil 7 "
            + "of 34 cells lit, needs 30. Selected: well 1 at row 5, column 14, strength 2, counterclockwise. "
            + level41)
        #expect(Self.place(&core, 0, 5, 14, 2, counter: true).kind == .state)
        let secondWell: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 14, column: 15),
                                                                      strength: 2, sense: .counterclockwise)
        #expect(Self.place(&core, 1, 14, 15, 2, counter: true).kind == .state)
        #expect(Plan.summaryText(core: core, selected: secondWell, slot: 1) == "11 actions left. Well 1 at row 5, "
            + "column 14, strength 2, counterclockwise; well 2 at row 14, column 15, strength 2, counterclockwise; "
            + "well 3 empty; stencil 34 of 34 cells lit, 100.0 %, needs 85.5 %; playing now would win. Selected: well "
            + "2 at row 14, column 15, strength 2, counterclockwise. " + level41)
        // Showing a tick after placements still plans nothing.
        #expect(Self.accepted(&core, "clock.show", [5]) == Plan.none)
        #expect(Self.accepted(&core, "mode.practice").kind == .level)
        #expect(Plan.summaryText(core: core, selected: nil, slot: 2).hasSuffix("Selected: well 3, no site. Level: "
            + "level 41, band 3, practice; a stencil of 34 cells, 30 to light as one pattern, 6 swimmers, a swim of "
            + "140 ticks, 4 sites; a budget of 24 actions."))
        // Level 1: a clockwise well selected.
        let first: Core = try Core.opening(number: 1)
        let certified: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 11, column: 18),
                                                                     strength: 2, sense: .clockwise)
        #expect(Plan.summaryText(core: first, selected: certified, slot: 0) == "9 actions left. Well 1 empty; well 2 "
            + "empty; well 3 empty; stencil 4 of 24 cells lit, 16.6 %, needs 71.5 %; playing now would fail: stencil 4 "
            + "of 24 cells lit, needs 18. Selected: well 1 at row 11, column 18, strength 2, clockwise. Level: level "
            + "1, band 1, campaign; a stencil of 24 cells, 18 to light as one pattern, 4 swimmers, a swim of 120 "
            + "ticks, 3 sites; a budget of 9 actions.")
    }
}
