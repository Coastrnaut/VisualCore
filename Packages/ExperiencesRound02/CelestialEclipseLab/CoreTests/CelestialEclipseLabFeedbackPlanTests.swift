// CelestialEclipseLabFeedbackPlanTests — feature 466 (R02-G17-06) T-R02G1706-003 (FR-R02G1706-001, 002, 003, 005;
// SC-R02G1706-001, 002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of
// `CelestialEclipseLabFeedbackPlan` on real certified cores driven through `CelestialEclipseLabExperienceCore.apply`:
// phase changes with an undo and a redo, then a 3-star campaign win along the certified witness (the run plans only
// the outcome) and the `stage` refusals after it; a 2-star and a 1-star campaign win after undone phase changes (undone
// changes count), a 1-action win, a practice win without stars and a daily win; every refusal code (provoked through
// the adapter where the core can produce it, with the engine's `action.rule.` prefix as `ActionResult.code` reports it,
// and every code by table, bare and prefixed); failed runs of every failure kind (window, unwanted before target 1 and
// before target 2, horizon) with an undo (state) and a redo back into the failure (only the outcome); a whole budget
// spent (the 10th change refused `budget`, the run then fails); level and mode changes with and without the tutorial;
// choosing a body, showing a tick and dismissing the tutorial plan nothing; a revealed hint; the summary element.
// Seed 2_466 opens level 67 (band 4, no tutorial): 6 bodies (body 0 fixed; body 1 period 6, phase 4), horizon 37,
// target body 1 in front of body 3 in ticks 0 … 2, body 1 in front of body 5 in 2 … 3, body 4 in front of body 0 in
// 3 … 3, budget 17; certified witness phase(1, 1), phase(3, 5), phase(4, 4), run (3 changes); its opening run fails
// `unwanted` (body 4 in front of body 0 at tick 0). Seed 0 opens level 1 (tutorial): 3 bodies, budget 9, target body 2
// in front of body 1 in ticks 4 … 4 and 10 … 14, witness phase(1, 2), phase(2, 0); its opening run fails `window`
// (tick 2). Seed 1 opens level 2 (tutorial): witness phase(1, 0) (1 change), budget 10. Level 36: phase(1, 1) makes the
// run fail `horizon` (horizon 36). The daily level of 2026-01-01 is level 1, that of 2026-02-24 level 67. The values
// were read from the stored witnesses (docs/games/celestial-eclipse-lab/levels/) and the kernel's sky rules; the
// expected texts are written out here, not built with the plan's helpers. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import CelestialEclipseLabCore
import VisualCoreExperience
import VisualCoreSimulation

/// One failed run: the level, the phase changes before the run, the failure code, the explanation's sentence and the
/// progress after undoing the run.
private struct FailureCase {
    /// The manifest number.
    let level: Int
    /// The phase changes (body, offset) before the run.
    let changes: [(Int, Int)]
    /// The failure code.
    let code: String
    /// The explanation's sentence (before the advice).
    let sentence: String
    /// The progress after the undo.
    let progress: String
}

@Suite struct CelestialEclipseLabFeedbackPlanTests {
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Plan = CelestialEclipseLabFeedbackPlan

    /// The seed of level 67.
    static let seed67: UInt64 = 2_466

    /// The certified witness of level 67 (phase changes before the run).
    static let witness67: [(Int, Int)] = [(1, 1), (3, 5), (4, 4)]

    /// The tutorial's first instruction (feature 465).
    static let phaseStep: String = "Drag a planet along its orbit (or use Phase \u{2212} and + and Set phase) to "
        + "change when it passes the others; the timeline below the sky shows the eclipses that would follow"

    /// The advice that ends every failure explanation (feature 465).
    static let advice: String = "Undo the last action or retry the level."

    /// The opening sentence of a win.
    static let won: String = "The eclipses came in the target order."

    /// The words of a `stage` refusal.
    static let ended: String = "The level has ended."

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

    /// Sets `body` to phase `offset` and returns the plan.
    static func phase(_ core: inout Core, _ body: Int, _ offset: Int) -> Plan {
        accepted(&core, "orbit.phase", [Double(body), Double(offset)])
    }

    /// Runs the clock and returns the plan.
    static func run(_ core: inout Core) -> Plan {
        accepted(&core, "clock.run")
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

    @Test func phaseChangesUndoRedoAndA3StarCampaignWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed67)
        #expect(core.levelNumber == 67 && core.tutorial == .done && core.certifiedChanges == 3)
        #expect(core.play.level.budget == 17 && core.play.phases[1] == 4)
        #expect(Self.phase(&core, 1, 1) == Self.state("Body 1 set to phase 1. 0 of 3 eclipses in order, a run now "
            + "would fail, 16 actions left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 0 of 3 eclipses in order, a run now would "
            + "fail, 17 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 0 of 3 eclipses in order, a run now would "
            + "fail, 16 actions left."))
        #expect(Self.phase(&core, 3, 5) == Self.state("Body 3 set to phase 5. 1 of 3 eclipses in order, a run now "
            + "would fail, 15 actions left."))
        #expect(Self.phase(&core, 4, 4) == Self.state("Body 4 set to phase 4. 3 of 3 eclipses in order, a run now "
            + "would win, 14 actions left."))
        // The run plans only the outcome: 3 phase changes (the redo spends nothing) against the certified 3.
        #expect(Self.run(&core) == Self.success(Self.won + " Level won spending 3 actions, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won play is final: the real `stage` refusals.
        let ended: Plan = Self.rejection(Self.ended)
        #expect(Self.refused(&core, "orbit.phase", [1, 2], code: "r02-g17.stage") == ended)
        #expect(Self.refused(&core, "clock.run", [], code: "r02-g17.stage") == ended)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g17.stage") == ended)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g17.stage") == ended)
        // The campaign win opened level 68.
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 68, band 4, campaign."))
        // "1 action" singular, on the tutorial level 2 (witness of 1 change).
        var second: Core = try await Core.prepare(seed: 1)
        #expect(second.levelNumber == 2 && second.certifiedChanges == 1)
        #expect(Self.phase(&second, 1, 0) == Self.state("Body 1 set to phase 0. 1 of 1 eclipses in order, a run now "
            + "would win, 9 actions left."))
        #expect(Self.run(&second) == Self.success(Self.won + " Level won spending 1 action, 3 of 3 stars."))
    }

    @Test func undoneChangesCountAndPracticeAndDailyWins() async throws {
        // Two undone changes: 5 actions against the certified 3 → 2 stars.
        var two: Core = try await Core.prepare(seed: Self.seed67)
        for _ in 0..<2 {
            #expect(Self.phase(&two, 1, 1) == Self.state("Body 1 set to phase 1. 0 of 3 eclipses in order, a run now "
                + "would fail, 16 actions left."))
            #expect(Self.accepted(&two, "play.undo") == Self.state("Undone. 0 of 3 eclipses in order, a run now "
                + "would fail, 17 actions left."))
        }
        var plans: [Plan] = []
        for (body, offset) in Self.witness67 { plans.append(Self.phase(&two, body, offset)) }
        for plan in plans { #expect(plan.kind == .state && plan.haptic == .selection) }
        #expect(Self.run(&two) == Self.success(Self.won + " Level won spending 5 actions, 2 of 3 stars."))
        // Four undone changes: 7 actions → 1 star.
        var one: Core = try await Core.prepare(seed: Self.seed67)
        for _ in 0..<4 {
            #expect(Self.phase(&one, 1, 1).kind == .state)
            #expect(Self.accepted(&one, "play.undo").kind == .state)
        }
        for (body, offset) in Self.witness67 { #expect(Self.phase(&one, body, offset).kind == .state) }
        #expect(Self.run(&one) == Self.success(Self.won + " Level won spending 7 actions, 1 of 3 stars."))
        // Practice: the budget raised to 24, no stars.
        var practice: Core = try await Core.prepare(seed: Self.seed67)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 67, band 4, practice."))
        #expect(Self.phase(&practice, 1, 1) == Self.state("Body 1 set to phase 1. 0 of 3 eclipses in order, a run "
            + "now would fail, 23 actions left."))
        for index in 1..<Self.witness67.count {
            #expect(Self.phase(&practice, Self.witness67[index].0, Self.witness67[index].1).kind == .state)
        }
        #expect(Self.run(&practice) == Self.success(Self.won + " Level won spending 3 actions."))
        // Daily: 2026-01-01 is level 1 (its tutorial shown), with stars.
        var daily: Core = try await Core.prepare(seed: Self.seed67)
        #expect(Self.accepted(&daily, "mode.daily", [2026, 1, 1])
                == Self.level("Level 1, band 1, daily. " + Self.phaseStep))
        #expect(daily.certifiedChanges == 2)
        #expect(Self.phase(&daily, 1, 2) == Self.state("Body 1 set to phase 2. 0 of 2 eclipses in order, a run now "
            + "would fail, 8 actions left."))
        #expect(Self.phase(&daily, 2, 0) == Self.state("Body 2 set to phase 0. 2 of 2 eclipses in order, a run now "
            + "would win, 7 actions left."))
        #expect(Self.run(&daily) == Self.success(Self.won + " Level won spending 2 actions, 3 of 3 stars."))
    }

    @Test func everyRefusalCodeInWords() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed67)
        let action: Plan = Self.rejection("That phase change, undo or redo cannot be made now.")
        // Provoked through the adapter (the engine reports `action.rule.<code>`): a fixed body, the same offset, an
        // offset outside the period, nothing to undo or redo.
        #expect(Self.refused(&core, "orbit.phase", [0, 1], code: "r02-g17.action") == action)
        #expect(Self.refused(&core, "orbit.phase", [1, 4], code: "r02-g17.action") == action)
        #expect(Self.refused(&core, "orbit.phase", [1, 6], code: "r02-g17.action") == action)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g17.action") == action)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g17.action") == action)
        #expect(Self.refused(&core, "orbit.phase", [1.5, 0], code: "r02-g17.not-whole")
                == Self.rejection("That value must be a whole number."))
        #expect(Self.refused(&core, "clock.show", [37], code: "r02-g17.tick")
                == Self.rejection("That tick is outside the timeline."))
        #expect(Self.refused(&core, "clock.show", [40], code: "r02-g17.tick")
                == Self.rejection("That tick is outside the timeline."))
        #expect(Self.refused(&core, "level.select", [100], code: "r02-g17.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g17.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g17.date")
                == Self.rejection("That date cannot be used."))
        // Level 1 has 3 bodies.
        var first: Core = try await Core.prepare(seed: 0)
        #expect(Self.refused(&first, "orbit.choose", [3], code: "r02-g17.choice")
                == Self.rejection("That body is not in this level."))
        // Every code by table, bare and with the engine's prefix.
        let table: [(String, String)] = [
            ("r02-g17.locked", "That level is not open yet."),
            ("r02-g17.date", "That date cannot be used."),
            ("r02-g17.action", "That phase change, undo or redo cannot be made now."),
            ("r02-g17.budget", "No actions are left: undo or retry."),
            ("r02-g17.stage", "The level has ended."),
            ("r02-g17.not-whole", "That value must be a whole number."),
            ("r02-g17.choice", "That body is not in this level."),
            ("r02-g17.tick", "That tick is outside the timeline."),
            ("r02-g17.stale", "That action was refused."),
            ("r02-g17.level", "That action was refused."),
            ("r02-g17.malformed", "That action was refused."),
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
            FailureCase(level: 1, changes: [], code: "window",
                        sentence: "Target 1 (planet 2 in front of planet 1) began at tick 2, outside its window from "
                            + "tick 4 to tick 4.",
                        progress: "0 of 2 eclipses in order, a run now would fail, 9 actions left."),
            FailureCase(level: 67, changes: [], code: "unwanted",
                        sentence: "The run met an unwanted eclipse first: planet 4 in front of planet 0 at tick 0, "
                            + "before target 1 (planet 1 in front of planet 3).",
                        progress: "0 of 3 eclipses in order, a run now would fail, 17 actions left."),
            FailureCase(level: 67, changes: [(1, 1), (3, 5)], code: "unwanted",
                        sentence: "The run met an unwanted eclipse first: planet 4 in front of planet 0 at tick 0, "
                            + "before target 2 (planet 1 in front of planet 5).",
                        progress: "1 of 3 eclipses in order, a run now would fail, 15 actions left."),
            FailureCase(level: 36, changes: [(1, 1)], code: "horizon",
                        sentence: "The clock reached tick 35 before target 1 (planet 1 in front of planet 2, window "
                            + "4 \u{2026} 5) happened.",
                        progress: "0 of 3 eclipses in order, a run now would fail, 9 actions left."),
        ]
        var codes: [String] = []
        for sample in cases {
            var core: Core = try Core.opening(number: sample.level)
            for (body, offset) in sample.changes {
                #expect(Self.phase(&core, body, offset).kind == .state, "level \(sample.level)")
            }
            let failing: Plan = Self.warning(sample.sentence + " " + Self.advice)
            #expect(Self.run(&core) == failing, "level \(sample.level)")
            #expect(core.play.stage == .failed)
            #expect(failing.text == CelestialEclipseLabFailureExplanation(play: core.play)?.text)
            if let failure = core.play.failure { codes.append(failure.code) }
            #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. " + sample.progress),
                    "level \(sample.level)")
            #expect(Self.accepted(&core, "play.redo") == failing, "level \(sample.level)")
        }
        #expect(codes == ["window", "unwanted", "unwanted", "horizon"])
    }

    @Test func aWholeBudgetSpentThenTheBudgetRefusalAndAFailedRun() throws {
        // Level 1 (budget 9): body 1 set to 0, 1, 0, … nine times; every setting fails `window`.
        var core: Core = try Core.opening(number: 1)
        #expect(core.play.level.budget == 9 && core.play.phases[1] == 3)
        let left: [String] = ["8 actions left", "7 actions left", "6 actions left", "5 actions left",
                              "4 actions left", "3 actions left", "2 actions left", "1 action left", "0 actions left"]
        for index in 0..<left.count {
            let offset: Int = index % 2
            let expected: Plan = Self.state("Body 1 set to phase \(offset). 0 of 2 eclipses in order, a run now "
                + "would fail, " + left[index] + ".")
            #expect(Self.phase(&core, 1, offset) == expected, "change \(index + 1)")
        }
        #expect(Self.refused(&core, "orbit.phase", [1, 1], code: "r02-g17.budget")
                == Self.rejection("No actions are left: undo or retry."))
        // The run is still allowed and plans only the warning.
        let failing: Plan = Self.warning("Target 1 (planet 2 in front of planet 1) began at tick 6, outside its "
            + "window from tick 4 to tick 4. " + Self.advice)
        #expect(Self.run(&core) == failing)
        let ended: Plan = Self.rejection(Self.ended)
        #expect(Self.refused(&core, "orbit.phase", [1, 1], code: "r02-g17.stage") == ended)
        #expect(Self.refused(&core, "clock.run", [], code: "r02-g17.stage") == ended)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g17.stage") == ended)
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 0 of 2 eclipses in order, a run now would "
            + "fail, 0 actions left."))
        #expect(Self.accepted(&core, "play.redo") == failing)
    }

    @Test func levelAndModeChanges() async throws {
        // Level 1 (tutorial): dismissing plans nothing; reopening it shows the tutorial again.
        var first: Core = try await Core.prepare(seed: 0)
        #expect(first.tutorial == .phase)
        #expect(Self.accepted(&first, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&first, "level.select", [1])
                == Self.level("Level 1, band 1, campaign. " + Self.phaseStep))
        #expect(Self.accepted(&first, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.phaseStep))
        #expect(Self.phase(&first, 1, 2) == Self.state("Body 1 set to phase 2. 0 of 2 eclipses in order, a run now "
            + "would fail, 23 actions left."))
        #expect(Self.accepted(&first, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.phaseStep))
        // Level 67 (no tutorial): modes, the daily level, other levels.
        var core: Core = try await Core.prepare(seed: Self.seed67)
        #expect(Self.phase(&core, 1, 1).kind == .state)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 67, band 4, practice."))
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 67, band 4, campaign."))
        #expect(Self.phase(&core, 1, 1).kind == .state)
        #expect(Self.accepted(&core, "level.select", [67]) == Self.level("Level 67, band 4, campaign."))
        #expect(Self.accepted(&core, "mode.daily", [2026, 2, 24]) == Self.level("Level 67, band 4, daily."))
        #expect(Self.accepted(&core, "level.select", [3])
                == Self.level("Level 3, band 1, campaign. " + Self.phaseStep))
        #expect(Self.accepted(&core, "level.select", [4]) == Self.level("Level 4, band 1, campaign."))
        // Reopening an untouched level without a tutorial changes nothing.
        #expect(Self.accepted(&core, "level.select", [4]) == Plan.none)
    }

    @Test func choosingAndShowingPlanNothingAHintAndTheSummary() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed67)
        let controls: [(String, Double)] = [("orbit.choose", 3), ("orbit.choose", 5), ("clock.show", 10),
                                            ("clock.show", 36), ("clock.show", 0), ("orbit.choose", 1)]
        for (control, value) in controls {
            #expect(Self.accepted(&core, control, [value]) == Plan.none, "\(control) \(value)")
        }
        let hint: Plan = Plan.hint(text: "Set planet 1 to phase 1")
        #expect(hint == Plan(text: "Set planet 1 to phase 1", kind: .state, haptic: nil))
        let level67: String = "Level: level 67, band 4, campaign; 3 target eclipses in order among 6 bodies over 37 "
            + "ticks; a budget of 17 actions."
        let next: String = "next: body 1 in front of body 3 between tick 0 and tick 2"
        #expect(Plan.summaryText(core: core, body: 1, phase: 4) == "17 actions left. 0 of 3 eclipses in order; "
            + next + "; a run now would fail. Chosen: body 1 at phase 4. " + level67)
        #expect(Plan.summaryText(core: core, body: 3, phase: 5) == "17 actions left. 0 of 3 eclipses in order; "
            + next + "; a run now would fail. Chosen: body 3 at phase 5. " + level67)
        #expect(Self.phase(&core, 1, 1).kind == .state)
        #expect(Plan.summaryText(core: core, body: 1, phase: 1) == "16 actions left. 0 of 3 eclipses in order; "
            + next + "; a run now would fail. Chosen: body 1 at phase 1. " + level67)
        #expect(Self.phase(&core, 3, 5).kind == .state)
        #expect(Self.phase(&core, 4, 4).kind == .state)
        #expect(Plan.summaryText(core: core, body: 4, phase: 4) == "14 actions left. 3 of 3 eclipses in order; a run "
            + "now would win. Chosen: body 4 at phase 4. " + level67)
        #expect(Self.accepted(&core, "mode.practice").kind == .level)
        #expect(Plan.summaryText(core: core, body: 1, phase: 4).hasSuffix("Level: level 67, band 4, practice; 3 target "
            + "eclipses in order among 6 bodies over 37 ticks; a budget of 24 actions."))
        // One target eclipse (level 2).
        let second: Core = try await Core.prepare(seed: 1)
        #expect(Plan.summaryText(core: second, body: 1, phase: 1) == "10 actions left. 0 of 1 eclipses in order; "
            + "next: body 0 in front of body 1 between tick 0 and tick 0; a run now would fail. Chosen: body 1 at "
            + "phase 1. Level: level 2, band 1, campaign; 1 target eclipse in order among 3 bodies over 25 ticks; a "
            + "budget of 10 actions.")
    }
}
