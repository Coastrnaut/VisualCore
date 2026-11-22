// ChronoConstellatorFeedbackPlanTests — feature 356 (R02-G06-06) T-R02G0606-002 (FR-R02G0606-001, 002, 003, 005;
// SC-R02G0606-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `ChronoConstellatorFeedbackPlan`
// on real certified cores: phase changes, holds and releases, undo and redo, steps and a rewind, the summary of one
// core, the edits left down to the singular and the budget refusal, every refusal code (raw, prefixed and as the core
// reports it, engine codes included), a campaign win with 3 and with 2 stars and a practice win (a winning step plans
// only the outcome), a time failure with its undo and its rewind (a failing step plans only the outcome), `level.next`,
// `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` with and without the tutorial, the dismissal, star
// picks and no plan for an unchanged core.
// Seed 2_356 opens level 57 (band 3, no tutorial): 7 columns, 3 stars, budget 13, tick limit 267; star 1 (ring) loop
// [31, 32, 33, 34, 27, 26, 25, 24] phase 2 target 26; star 2 (cross) loop [21, 28, 35, 36, 29, 22, 15, 14] phase 3
// target 22; star 3 (diamond) loop [7, 8, 9, 16, 23, 22, 21, 14] phase 4 target 16. Level 1 (band 1, tutorial
// `shift`): 6 columns, budget 9, tick limit 145, certified smallest 1, witness phase(0, 8) then step 145 (won at tick
// 3). The daily level of 2026-11-21 is level 17. The expected texts are written out here, not built with the plan's
// helpers. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import ChronoConstellatorCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct ChronoConstellatorFeedbackPlanTests {
    typealias Core = ChronoConstellatorExperienceCore
    typealias Plan = ChronoConstellatorFeedbackPlan

    /// The seed of these tests: level 2_356 % 100 + 1 = 57.
    static let seed: UInt64 = 2_356

    /// The tutorial's first instruction (feature 355).
    static let shift: String = "Drag a star along its silver loop (or use Phase − and +) to change where it starts, "
        + "until every star can meet its target on the same tick; a hint shows which"

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

    /// A `rejection` plan with haptic `error`.
    static func rejection(_ text: String) -> Plan { Plan(text: text, kind: .rejection, haptic: .error) }

    @Test func editsUndoRedoStepsRewindAndTheSummary() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 57 && core.tutorial == .done && core.mode == .campaign)
        #expect(Self.accepted(&core, "star.phase", [0, 3])
            == Self.state("Star 1 (ring) starts at row 5, column 7. 12 edits left."))
        #expect(Self.accepted(&core, "star.hold", [1, 5, 3])
            == Self.state("Star 2 holds from tick 5 for 3 ticks. 11 edits left."))
        #expect(Self.accepted(&core, "star.hold", [2, 10, 1])
            == Self.state("Star 3 holds from tick 10 for 1 tick. 10 edits left."))
        #expect(Self.accepted(&core, "star.release", [1, 5])
            == Self.state("Star 2's hold from tick 5 removed. 11 edits left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. Tick 0 of 267. 10 edits left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. Tick 0 of 267. 11 edits left."))
        #expect(Self.accepted(&core, "star.hold", [2, 20, 2])
            == Self.state("Star 3 holds from tick 20 for 2 ticks. 10 edits left."))
        #expect(Plan.summaryText(core: core) == "Tick 0 of 267. 10 edits left. "
            + "Star 1 (ring): row 5, column 7, start phase 3, no holds, off its target. "
            + "Star 2 (cross): row 6, column 2, start phase 3, no holds, off its target. "
            + "Star 3 (diamond): row 4, column 3, start phase 4, holds from tick 10 for 1 tick and holds from tick 20 "
            + "for 2 ticks, off its target.")
        #expect(Self.accepted(&core, "time.step", [1]) == Self.state("Tick 1 of 267. 0 of 3 stars on target."))
        #expect(Self.accepted(&core, "time.step", [1]) == Self.state("Tick 2 of 267. 2 of 3 stars on target."))
        #expect(Plan.summaryText(core: core) == "Tick 2 of 267. 10 edits left. "
            + "Star 1 (ring): row 4, column 6, start phase 3, no holds, on its target. "
            + "Star 2 (cross): row 4, column 2, start phase 3, no holds, on its target. "
            + "Star 3 (diamond): row 4, column 1, start phase 4, holds from tick 10 for 1 tick and holds from tick 20 "
            + "for 2 ticks, off its target.")
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. Tick 1 of 267. 10 edits left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. Tick 2 of 267. 10 edits left."))
        #expect(Self.accepted(&core, "time.rewind") == Self.state("Rewound to tick 0."))
        #expect(core.play.tick == 0 && core.play.stage == .playing)
    }

    @Test func theEditsLeftReachTheSingularAndTheBudgetRefuses() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let budget: Int = core.play.level.budget
        #expect(budget == 13)
        for index in 0..<budget {
            let start: Int = 30 + 10 * index
            let left: Int = budget - 1 - index
            let suffix: String = left == 1 ? "1 edit left." : "\(left) edits left."
            let plan: Plan = Self.accepted(&core, "star.hold", [0, Double(start), 1])
            #expect(plan == Self.state("Star 1 holds from tick \(start) for 1 tick. \(suffix)"))
        }
        #expect(core.play.remaining == 0)
        let refusal: Plan = Self.refused(&core, "star.hold", [1, 30, 1], code: "r02-g06.budget")
        #expect(refusal == Self.rejection("No edits are left."))
    }

    @Test func everyRefusalCodeHasItsWords() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.refused(&core, "star.phase", [0, 2], code: "r02-g06.action")
            == Self.rejection("That change is not allowed here."))
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g06.action")
            == Self.rejection("That change is not allowed here."))
        #expect(Self.refused(&core, "star.phase", [0.5, 1], code: "r02-g06.not-whole")
            == Self.rejection("That value must be a whole number."))
        #expect(Self.refused(&core, "level.select", [100], code: "r02-g06.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g06.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2027, 2, 29], code: "r02-g06.date")
            == Self.rejection("That date cannot be used."))
        #expect(Self.accepted(&core, "time.step", [1]) == Self.state("Tick 1 of 267. 0 of 3 stars on target."))
        #expect(Self.refused(&core, "star.phase", [0, 3], code: "r02-g06.action")
            == Self.rejection("That change is not allowed here."))
        // The words alone, raw and prefixed, and the codes without words of their own.
        let codes: [String] = ["r02-g06.locked", "r02-g06.date", "r02-g06.action", "r02-g06.budget", "r02-g06.stage",
                               "r02-g06.not-whole", "r02-g06.stale", "r02-g06.malformed", "action.out-of-range",
                               "action.unknown-control", ""]
        let words: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That change is not allowed here.", "No edits are left.", "The level has ended.",
                               "That value must be a whole number.", "That change was refused.",
                               "That change was refused.", "That change was refused.", "That change was refused.",
                               "That change was refused."]
        for index in codes.indices {
            #expect(Plan.refusalText(code: codes[index]) == words[index], "\(codes[index])")
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == words[index], "\(codes[index])")
            #expect(Plan.refused(code: codes[index]) == Self.rejection(words[index]), "\(codes[index])")
        }
    }

    @Test func aWinningStepPlansOnlyTheOutcomeWithItsStars() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&core, "star.phase", [0, 8])
            == Self.state("Star 1 (ring) starts at row 4, column 3. 8 edits left."))
        let won: Plan = Self.accepted(&core, "time.step", [145])
        #expect(won == Plan(text: "Every star is on its target. Level won with 1 edit, 3 of 3 stars.", kind: .outcome,
                            haptic: .success))
        #expect(core.play.stage == .won && core.play.tick == 3)
        #expect(Self.refused(&core, "time.step", [1], code: "r02-g06.stage") == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.shift))
        // Two edits against the certified smallest 1: two stars.
        var second: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&second, "star.phase", [0, 8])
            == Self.state("Star 1 (ring) starts at row 4, column 3. 8 edits left."))
        #expect(Self.accepted(&second, "star.hold", [0, 100, 1])
            == Self.state("Star 1 holds from tick 100 for 1 tick. 7 edits left."))
        #expect(Self.accepted(&second, "time.step", [145])
            == Plan(text: "Every star is on its target. Level won with 2 edits, 2 of 3 stars.", kind: .outcome,
                    haptic: .success))
        // Practice awards no stars.
        var practice: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.shift))
        #expect(Self.accepted(&practice, "star.phase", [0, 8])
            == Self.state("Star 1 (ring) starts at row 4, column 3. 19 edits left."))
        #expect(Self.accepted(&practice, "time.step", [145])
            == Plan(text: "Every star is on its target. Level won with 1 edit.", kind: .outcome, haptic: .success))
    }

    @Test func aFailingStepPlansOnlyTheFailureExplanation() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let failed: Plan = Self.accepted(&core, "time.step", [267])
        #expect(failed == Plan(text: "Time ran out at tick 267: star 2 (cross) is at row 3, column 2, its target is "
            + "row 4, column 2; star 3 (diamond) is at row 3, column 1, its target is row 3, column 3. Undo the last "
            + "change, rewind or retry the level.", kind: .outcome, haptic: .warning))
        #expect(core.play.stage == .failed)
        var retried: Core = core
        #expect(Self.accepted(&retried, "time.rewind") == Self.state("Rewound to tick 0."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. Tick 0 of 267. 13 edits left."))
        #expect(core.play.stage == .playing)
    }

    @Test func levelAndModeChangesAndTheTutorial() async throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        // The same untouched level reopened shows the tutorial again.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.shift))
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.shift))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 21]) == Self.level("Level 17, band 1, daily."))
        #expect(Self.accepted(&core, "level.select", [1]) == Self.level("Level 1, band 1, campaign. " + Self.shift))
        // Level 57: no tutorial; an untouched campaign reopened plans nothing; an edited play reopened is a level plan.
        var other: Core = try await Core.prepare(seed: Self.seed)
        #expect(Plan.after(old: other, new: other) == Plan.none)
        #expect(Self.accepted(&other, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&other, "mode.campaign") == Plan.none)
        #expect(Self.accepted(&other, "mode.practice") == Self.level("Level 57, band 3, practice."))
        #expect(Self.accepted(&other, "mode.campaign") == Self.level("Level 57, band 3, campaign."))
        #expect(Self.accepted(&other, "star.phase", [0, 3])
            == Self.state("Star 1 (ring) starts at row 5, column 7. 12 edits left."))
        #expect(Self.accepted(&other, "level.select", [57]) == Self.level("Level 57, band 3, campaign."))
        #expect(other.play.records.isEmpty)
    }

    @Test func starPicksAreStateWithoutHaptic() {
        let shapes: [String] = ["ring", "cross", "diamond", "triangle", "square"]
        for index in shapes.indices {
            #expect(Plan.picked(star: index)
                == Plan(text: "Star \(index + 1) (\(shapes[index])) picked.", kind: .state, haptic: nil))
        }
    }
}
