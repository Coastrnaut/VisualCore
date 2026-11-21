// ColorfallCanyonsFeedbackPlanTests — feature 346 (R02-G05-06) T-R02G0506-002 (FR-R02G0506-001, 002, 003;
// SC-R02G0506-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `ColorfallCanyonsFeedbackPlan` on
// real cores: carves and valve toggles down to the singular "1 action left" and the budget refusal, steps, undo and
// redo, a campaign win with 3 and with 2 stars, a practice win, a time failure with its undo and its redo (a redo that
// ends the play plans only the outcome), `level.select`, `level.next`, `mode.daily`, `mode.practice`, `mode.campaign`
// with and without the tutorial, the dismissal, cell picks, the summary of one and of two basins, no change, and every
// refusal code (raw, prefixed and as the core reports it).
// Level 1: 6 columns, budget 9, tick limit 120, one cyan spring (cell 4, open), one basin (cell 16, at least 15 units
// of cyan), tutorial `steer`, certified smallest 2, certified actions carve 10, carve 10, step 120. Level 24: two
// basins. The daily level of 2026-11-21 is level 73 (band 4). The expected texts are written out here, not built
// with the plan's helpers. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import ColorfallCanyonsCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct ColorfallCanyonsFeedbackPlanTests {
    typealias Core = ColorfallCanyonsExperienceCore
    typealias Plan = ColorfallCanyonsFeedbackPlan

    /// The tutorial's first instruction (feature 345).
    static let steer: String = "Drag across a sandstone cell (or use Carve) to cut a channel, and tap a spring (or its "
        + "valve button) to open or close it, until the fluid will reach the right basins; a hint shows how"

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

    @Test func carvesAndValvesCountTheActionsLeftDownToTheSingular() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&core, "canyon.carve", [10]) == Self.state("Carved row 2, column 5. 8 actions left."))
        let words: [String] = ["closed", "open", "closed", "open", "closed", "open", "closed"]
        for index in 0..<words.count {
            let left: Int = 7 - index
            let suffix: String = left == 1 ? "1 action left." : "\(left) actions left."
            #expect(Self.accepted(&core, "canyon.valve", [0]) == Self.state("Cyan valve \(words[index]). \(suffix)"))
        }
        #expect(Self.accepted(&core, "canyon.valve", [0]) == Self.state("Cyan valve open. 0 actions left."))
        let budget: Plan = Self.refused(&core, "canyon.valve", [0], code: "r02-g05.budget")
        #expect(budget == Plan(text: "No actions are left.", kind: .rejection, haptic: .error))
        // A carve with a carvable cell is refused for the budget as well.
        #expect(Self.refused(&core, "canyon.carve", [10], code: "r02-g05.budget").text == "No actions are left.")
    }

    @Test func stepsUndoAndRedoNameTheTickAndTheActionsLeft() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&core, "time.step", [10]) == Self.state("Tick 10 of 120. 0 of 1 basins filled."))
        #expect(Self.accepted(&core, "canyon.carve", [10]) == Self.state("Carved row 2, column 5. 8 actions left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. Tick 10 of 120. 9 actions left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. Tick 0 of 120. 9 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. Tick 10 of 120. 9 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. Tick 10 of 120. 8 actions left."))
        let nothing: Plan = Self.refused(&core, "play.redo", [], code: "r02-g05.action")
        #expect(nothing == Plan(text: "That action is not allowed here.", kind: .rejection, haptic: .error))
    }

    @Test func aCampaignWinPlansOnlyTheOutcomeWithItsStars() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&core, "canyon.carve", [10]) == Self.state("Carved row 2, column 5. 8 actions left."))
        #expect(Self.accepted(&core, "canyon.carve", [10]) == Self.state("Carved row 2, column 5. 7 actions left."))
        let win: Plan = Self.accepted(&core, "time.step", [120])
        #expect(win == Plan(text: "Every basin is filled. Level won with 2 actions, 3 of 3 stars.", kind: .outcome,
                            haptic: .success))
        #expect(core.play.stage == .won && core.progress.solved[1]?.stars == 3)
        let ended: Plan = Self.refused(&core, "time.step", [1], code: "r02-g05.stage")
        #expect(ended == Plan(text: "The level has ended.", kind: .rejection, haptic: .error))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g05.stage").text == "The level has ended.")

        // Two valve toggles at tick 0 change no flow but cost two actions: 4 actions, 2 stars.
        var slower: Core = try Core.opening(number: 1)
        let script: [(String, Double)] = [("canyon.carve", 10), ("canyon.carve", 10), ("canyon.valve", 0),
                                          ("canyon.valve", 0)]
        for (control, value) in script { _ = Self.accepted(&slower, control, [value]) }
        let twoStars: Plan = Self.accepted(&slower, "time.step", [120])
        #expect(twoStars == Plan(text: "Every basin is filled. Level won with 4 actions, 2 of 3 stars.",
                                 kind: .outcome, haptic: .success))
    }

    @Test func aPracticeWinHasNoStars() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.steer))
        #expect(Self.accepted(&core, "canyon.carve", [10]) == Self.state("Carved row 2, column 5. 29 actions left."))
        #expect(Self.accepted(&core, "canyon.carve", [10]) == Self.state("Carved row 2, column 5. 28 actions left."))
        let win: Plan = Self.accepted(&core, "time.step", [120])
        #expect(win == Plan(text: "Every basin is filled. Level won with 2 actions.", kind: .outcome, haptic: .success))
    }

    @Test func aFailurePlansTheExplanationAndItsUndoAndRedo() throws {
        var core: Core = try Core.opening(number: 1)
        let failure: Plan = Self.accepted(&core, "time.step", [120])
        #expect(core.play.stage == .failed)
        let explanation: String = try #require(core.failureExplanation?.text)
        #expect(failure == Plan(text: explanation, kind: .outcome, haptic: .warning))
        #expect(explanation == "Time ran out at tick 120: basin 1 holds cyan 0, coral 0, yellow 0; it needs at least "
            + "15 units: cyan 1000 ± 150 per mille, coral none, yellow none. Undo the last change or retry the level.")
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. Tick 0 of 120. 9 actions left."))
        // A redo that ends the play again plans only the outcome.
        #expect(Self.accepted(&core, "play.redo") == Plan(text: explanation, kind: .outcome, haptic: .warning))
    }

    @Test func levelAndModeChangesNameTheLevelBandAndMode() throws {
        var core: Core = try Core.opening(number: 4)
        #expect(core.tutorial == .done)
        #expect(Self.accepted(&core, "level.select", [2]) == Self.level("Level 2, band 1, campaign. " + Self.steer))
        #expect(Self.accepted(&core, "level.select", [4]) == Self.level("Level 4, band 1, campaign."))
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 4, band 1, practice."))
        // A practice play with a record, reopened in campaign mode.
        _ = Self.accepted(&core, "time.step", [5])
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 4, band 1, campaign."))
        // The same level in the same mode, played and then reopened fresh by level.select.
        _ = Self.accepted(&core, "time.step", [5])
        #expect(Self.accepted(&core, "level.select", [4]) == Self.level("Level 4, band 1, campaign."))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 21]) == Self.level("Level 73, band 4, daily."))
        // Level 73 is not open in the campaign: mode.campaign goes to the frontier, 4.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 4, band 1, campaign."))
        #expect(Self.accepted(&core, "level.select", [3]) == Self.level("Level 3, band 1, campaign. " + Self.steer))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 4, band 1, campaign."))
        let none: Plan = Self.refused(&core, "level.next", [], code: "r02-g05.locked")
        #expect(none == Plan(text: "That level is not open yet.", kind: .rejection, haptic: .error))
    }

    @Test func theTutorialDismissalIsSilentAndItsReturnIsALevelPlan() throws {
        var core: Core = try Core.opening(number: 1)
        // Nothing changes: mode.campaign on a fresh campaign play with the tutorial shown.
        let same: Core = core
        #expect(core.apply(Self.bare("mode.campaign")) == .accepted)
        #expect(core == same && Plan.after(old: same, new: core) == Plan.none)
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(core.tutorial == .done)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.steer))
        #expect(Plan.after(old: core, new: core) == Plan.none)
    }

    @Test func everyRefusalCodeHasItsWords() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.refused(&core, "level.select", [3], code: "r02-g05.locked").text == "That level is not open yet.")
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g05.date").text
            == "That date cannot be used.")
        #expect(Self.refused(&core, "canyon.carve", [10.5], code: "r02-g05.not-whole").text
            == "That value must be a whole number.")
        #expect(Self.refused(&core, "canyon.carve", [4], code: "r02-g05.action").text
            == "That action is not allowed here.")
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g05.action").text == "That action is not allowed here.")
        #expect(Self.refused(&core, "canyon.valve", [1], code: "r02-g05.action").text
            == "That action is not allowed here.")
        let codes: [String] = ["r02-g05.locked", "r02-g05.date", "r02-g05.action", "r02-g05.budget", "r02-g05.stage",
                               "r02-g05.not-whole", "r02-g05.stale", "r02-g05.malformed", "something.else", ""]
        let words: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That action is not allowed here.", "No actions are left.", "The level has ended.",
                               "That value must be a whole number.", "That change was refused.",
                               "That change was refused.", "That change was refused.", "That change was refused."]
        for index in 0..<codes.count {
            let raw: Plan = Plan.refused(code: codes[index])
            #expect(raw == Plan(text: words[index], kind: .rejection, haptic: .error), "\(codes[index])")
            #expect(Plan.refusalText(code: codes[index]) == words[index], "\(codes[index])")
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == words[index], "prefixed \(codes[index])")
        }
    }

    @Test func cellPicksAreStateWithoutHaptic() {
        #expect(Plan.picked(cell: 10, columns: 6) == Plan(text: "Row 2, column 5 picked.", kind: .state, haptic: nil))
        #expect(Plan.picked(cell: 0, columns: 6).text == "Row 1, column 1 picked.")
        #expect(Plan.picked(cell: 119, columns: 12).text == "Row 10, column 12 picked.")
        #expect(Plan.none == Plan(text: nil, kind: nil, haptic: nil))
    }

    @Test func theSummaryNamesTickActionsAndEveryBasin() throws {
        var core: Core = try Core.opening(number: 1)
        let target1: String = "at least 15 units: cyan 1000 ± 150 per mille, coral none, yellow none"
        #expect(Plan.summaryText(core: core) == "Tick 0 of 120. 9 actions left. Basin 1: cyan 0, coral 0, yellow 0; "
            + "target \(target1).")
        _ = Self.accepted(&core, "canyon.carve", [10])
        _ = Self.accepted(&core, "canyon.carve", [10])
        _ = Self.accepted(&core, "time.step", [120])
        let cyan: Int = core.play.fluid.masses[16][0]
        #expect(cyan >= 15)
        #expect(Plan.summaryText(core: core) == "Tick \(core.play.fluid.tick) of 120. 7 actions left. Basin 1: cyan "
            + "\(cyan), coral 0, yellow 0; target \(target1).")
        let two: Core = try Core.opening(number: 24)
        #expect(Plan.summaryText(core: two) == "Tick 0 of 120. 10 actions left. "
            + "Basin 1: cyan 0, coral 0, yellow 0; target at least 9 units: cyan none, coral none, yellow 1000 ± 100 "
            + "per mille, protected (0 wrong units tolerated). "
            + "Basin 2: cyan 0, coral 0, yellow 0; target at least 24 units: cyan none, coral 1000 ± 100 per mille, "
            + "yellow none, protected (0 wrong units tolerated).")
    }
}
