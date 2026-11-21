// LissajousLabyrinthFeedbackPlanTests — feature 316 (R02-G02-06) T-R02G0206-002 (FR-R02G0206-002, 003; clarifications
// Q1, Q2; research R1, R2). The exact announcement texts, kinds and haptics of `LissajousLabyrinthFeedbackPlan` on real
// cores: an action, undo and redo, a lap touching an obstacle, campaign wins with 3 and 2 stars, a practice win, a
// failure (allowance spent) and the undo that rewinds it, `level.select`, `level.next`, `mode.daily`, `mode.practice`,
// `mode.campaign` with and without the tutorial, the tutorial dismissal, no change, and every refusal code (raw,
// prefixed and as the core reports it). Seed 2_316 opens level 17 (band 1, start Frequency A 5, Frequency B 3,
// Phase A 14, Phase C 10, allowance 9, 2 checkpoints, certified shortest 1: Phase C to 1). The expected texts are
// written out here, not built with the plan's helpers. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct LissajousLabyrinthFeedbackPlanTests {
    typealias Core = LissajousLabyrinthExperienceCore
    typealias Plan = LissajousLabyrinthFeedbackPlan

    /// The seed of every scenario: level 17.
    static let seed: UInt64 = 2_316

    /// The `dial.set` action of dial index `dial` (0 = Frequency A, 1 = Frequency B, 2 = Phase A, 3 = Phase C) and
    /// `value`.
    static func dial(_ dial: Int, _ value: Int) -> ExperienceAction {
        ExperienceAction(control: "dial.set", values: [Double(dial), Double(value)], step: 0)
    }

    /// The bare action `control` with `values`.
    static func bare(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// Applies `action` to `core` (it must be accepted) and returns the plan of the change.
    static func step(_ core: inout Core, _ action: ExperienceAction) -> Plan {
        let old: Core = core
        let result: ActionResult = core.apply(action)
        #expect(result == .accepted, "\(action.control) \(action.values)")
        return Plan.after(old: old, new: core)
    }

    /// A `state` plan with the selection haptic.
    static func state(_ text: String) -> Plan { Plan(text: text, kind: .state, haptic: .selection) }

    @Test func actionUndoRedoAndNoChange() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 17 && core.tutorial == .done && core.play.level.allowance == 9)
        #expect(core.play.level.checkpoints.count == 2 && core.certifiedShortest == 1)
        #expect(Plan.after(old: core, new: core) == .none)
        let action: Plan = Self.step(&core, Self.dial(2, 7))
        #expect(action == Self.state("Phase A 7. 1 of 2 checkpoints in order. Actions 1 of 9."))
        let undo: Plan = Self.step(&core, Self.bare("play.undo"))
        #expect(undo == Self.state("Undone: Phase A 14. 0 of 2 checkpoints in order. Actions 0 of 9."))
        let redo: Plan = Self.step(&core, Self.bare("play.redo"))
        #expect(redo == Self.state("Redone: Phase A 7. 1 of 2 checkpoints in order. Actions 1 of 9."))
        let frequency: Plan = Self.step(&core, Self.dial(1, 4))
        #expect(frequency.text?.hasPrefix("Frequency B 4. ") == true && frequency.kind == .state)
        #expect(Plan.after(old: core, new: core) == .none)
    }

    @Test func contactNamesTheObstacle() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let touching: Plan = Self.step(&core, Self.dial(2, 3))
        let text: String = "Phase A 3. 0 of 2 checkpoints in order. Actions 1 of 9. The path touches obstacle 2."
        #expect(touching == Self.state(text))
        let clear: Plan = Self.step(&core, Self.dial(2, 14))
        #expect(clear == Self.state("Phase A 14. 0 of 2 checkpoints in order. Actions 2 of 9."))
        let back: Plan = Self.step(&core, Self.bare("play.undo"))
        #expect(back == Self.state("Undone: Phase A 3. 0 of 2 checkpoints in order. Actions 1 of 9. "
                                   + "The path touches obstacle 2."))
        var other: Core = try await Core.prepare(seed: Self.seed)
        let frequency: Plan = Self.step(&other, Self.dial(0, 8))
        #expect(frequency == Self.state("Frequency A 8. 1 of 2 checkpoints in order. Actions 1 of 9. "
                                        + "The path touches obstacle 1."))
    }

    @Test func campaignWinsWithStars() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let fresh: Core = core
        let won: Plan = Self.step(&core, Self.dial(3, 1))
        #expect(won == Plan(text: "The path is safe. Level won in 1 action, 3 of 3 stars.", kind: .outcome,
                            haptic: .success))
        // Three actions against a shortest of one: 2 stars.
        core = fresh
        #expect(Self.step(&core, Self.dial(2, 7)).haptic == .selection)
        #expect(Self.step(&core, Self.dial(2, 14)).haptic == .selection)
        let slower: Plan = Self.step(&core, Self.dial(3, 1))
        #expect(slower == Plan(text: "The path is safe. Level won in 3 actions, 2 of 3 stars.", kind: .outcome,
                               haptic: .success))
        // Ended: a further action is refused with the stage code.
        let refused: ActionResult = core.apply(Self.dial(2, 7))
        #expect(refused.code == "action.rule.r02-g02.stage")
        #expect(Plan.refused(code: refused.code) == Plan(text: "The level has ended.", kind: .rejection,
                                                         haptic: .error))
    }

    @Test func practiceWinHasNoStars() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let practice: Plan = Self.step(&core, Self.bare("mode.practice"))
        #expect(practice == Plan(text: "Level 17, band 1, practice.", kind: .level, haptic: nil))
        let won: Plan = Self.step(&core, Self.dial(3, 1))
        #expect(won == Plan(text: "The path is safe. Level won in 1 action.", kind: .outcome, haptic: .success))
        let campaign: Plan = Self.step(&core, Self.bare("mode.campaign"))
        #expect(campaign == Plan(text: "Level 17, band 1, campaign.", kind: .level, haptic: nil))
    }

    @Test func failureAndItsRewind() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        // Eight actions alternate Phase A between 7 and 14; the ninth (Phase A 7) spends the allowance without a win.
        for index in 0..<8 {
            let plan: Plan = Self.step(&core, Self.dial(2, index % 2 == 0 ? 7 : 14))
            #expect(plan.kind == .state && plan.haptic == .selection)
        }
        let failed: Plan = Self.step(&core, Self.dial(2, 7))
        #expect(core.play.stage == .failed)
        let explanation: String = "Checkpoint 2 is not reached in order. Undo the last change or retry the level."
        #expect(failed == Plan(text: explanation, kind: .outcome, haptic: .warning))
        let rewound: Plan = Self.step(&core, Self.bare("play.undo"))
        #expect(rewound == Self.state("Undone: Phase A 14. 0 of 2 checkpoints in order. Actions 8 of 9."))
    }

    @Test func levelAndModeChanges() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.step(&core, Self.dial(2, 7)).kind == .state)
        // The same level selected again: a fresh play, announced as a level.
        let again: Plan = Self.step(&core, Self.bare("level.select", [17]))
        #expect(again == Plan(text: "Level 17, band 1, campaign.", kind: .level, haptic: nil))
        // Level 1 shows the tutorial (its first hint dial is Phase C).
        let tutorialText: String = "Level 1, band 1, campaign. Turn the Phase C ring to change the path."
        let first: Plan = Self.step(&core, Self.bare("level.select", [1]))
        #expect(first == Plan(text: tutorialText, kind: .level, haptic: nil))
        // Dismissing the tutorial is not announced; reopening the untouched level shows it again.
        #expect(Self.step(&core, Self.bare("tutorial.dismiss")) == .none)
        #expect(Self.step(&core, Self.bare("mode.campaign")) == Plan(text: tutorialText, kind: .level, haptic: nil))
        // level.next from 17 wraps to level 1 (18 is not open).
        var fromSeventeen: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.step(&fromSeventeen, Self.bare("level.next")) == Plan(text: tutorialText, kind: .level,
                                                                            haptic: nil))
        // The daily level of 2026-11-21 is level 85, band 5.
        var daily: Core = try await Core.prepare(seed: Self.seed)
        let dailyPlan: Plan = Self.step(&daily, Self.bare("mode.daily", [2026, 11, 21]))
        #expect(dailyPlan == Plan(text: "Level 85, band 5, daily level.", kind: .level, haptic: nil))
    }

    @Test func refusals() async throws {
        let cases: [(String, String)] = [
            ("r02-g02.locked", "That level is not open yet."),
            ("r02-g02.date", "That date cannot be used."),
            ("r02-g02.move",
             "That change is not allowed: the frequencies must share no factor, and a dial must change."),
            ("r02-g02.allowance", "No actions are left."),
            ("r02-g02.stage", "The level has ended."),
            ("r02-g02.stale", "That change was refused."),
            ("r02-g02.not-whole", "That change was refused."),
            ("action.unknown-control", "That change was refused."),
        ]
        for (code, text) in cases {
            let expected: Plan = Plan(text: text, kind: .rejection, haptic: .error)
            #expect(Plan.refused(code: code) == expected, "\(code)")
            #expect(Plan.refused(code: "action.rule." + code) == expected, "prefixed \(code)")
        }
        // The codes the core reports.
        var core: Core = try await Core.prepare(seed: Self.seed)
        let before: Core = core
        let notCoprime: ActionResult = core.apply(Self.dial(0, 3))
        let locked: ActionResult = core.apply(Self.bare("level.select", [50]))
        let date: ActionResult = core.apply(Self.bare("mode.daily", [2026, 2, 30]))
        #expect(core == before)
        #expect(Plan.refused(code: notCoprime.code).text
                == "That change is not allowed: the frequencies must share no factor, and a dial must change.")
        #expect(Plan.refused(code: locked.code).text == "That level is not open yet.")
        #expect(Plan.refused(code: date.code).text == "That date cannot be used.")
    }
}
