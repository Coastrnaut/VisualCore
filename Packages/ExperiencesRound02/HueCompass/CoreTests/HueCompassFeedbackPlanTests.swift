// HueCompassFeedbackPlanTests — feature 336 (R02-G04-06) T-R02G0406-002 (FR-R02G0406-002, 003, 005; SC-R02G0406-002;
// clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `HueCompassFeedbackPlan` on real cores:
// turns, undo and redo, probes (with the singular "1 band"), a campaign win with 3 and with 2 stars, a practice win, a
// probe-exhaustion failure and a selection failure, `level.select`, `level.next`, `mode.daily`, `mode.practice`,
// `mode.campaign` with and without the tutorial, the dismissal, band picks, the summary with and without clues,
// no change, and every refusal code (raw, prefixed and as the core reports it).
// Seed 2_336 opens level 37 (band 2, offset 7, target 6 in band 9 shown, start 87 in band 5 shown, tolerances 3 and 1,
// allowance 11, certified smallest 1, no tutorial). Clues: at 87 gap 4 depth 62; at 0 gap 1 depth 21; at 4 gap 0
// depth 3. Level 1 (start 35, allowance 9) shows the tutorial; the daily level of 2026-11-21 is level 29 (band 2).
// The expected texts are written out here, not built with the plan's helpers. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import HueCompassCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct HueCompassFeedbackPlanTests {
    typealias Core = HueCompassExperienceCore
    typealias Plan = HueCompassFeedbackPlan

    /// The seed of the main scenarios: level 37.
    static let seed: UInt64 = 2_336

    /// The tutorial's first instruction.
    static let aim: String = "Swipe the compass, or use Turn, to aim the needle"

    /// The bare action `control` with `values`.
    static func bare(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// A `compass.turn` of `steps`.
    static func turn(_ steps: Int) -> ExperienceAction { bare("compass.turn", [Double(steps)]) }

    /// A `compass.select` of `bearing` and kernel band `band` (0 … 23).
    static func select(_ bearing: Int, _ band: Int) -> ExperienceAction {
        bare("compass.select", [Double(bearing), Double(band)])
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

    /// A `level` plan without a haptic.
    static func level(_ text: String) -> Plan { Plan(text: text, kind: .level, haptic: nil) }

    /// An `outcome` plan with `haptic`.
    static func outcome(_ text: String, _ haptic: HapticKind) -> Plan {
        Plan(text: text, kind: .outcome, haptic: haptic)
    }

    @Test func turnsProbesUndoRedoAndCampaignWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 37 && core.tutorial == .done && core.play.level.allowance == 11)
        #expect(core.play.bearing == 87 && core.certifiedSmallest == 1 && core.mode == .campaign)
        #expect(Plan.after(old: core, new: core) == .none)
        #expect(Plan.summaryText(core: core) == "Bearing 87, band 5. Units left 11 of 11. No clues yet.")
        #expect(Self.step(&core, Self.turn(4)) == Self.state("Bearing 91 of 96, band 6. Units left 11 of 11."))
        let undone: Plan = Self.step(&core, Self.bare("play.undo"))
        #expect(undone == Self.state("Undone: Bearing 87 of 96, band 5. Units left 11 of 11."))
        let redone: Plan = Self.step(&core, Self.bare("play.redo"))
        #expect(redone == Self.state("Redone: Bearing 91 of 96, band 6. Units left 11 of 11."))
        #expect(Self.step(&core, Self.turn(5)) == Self.state("Bearing 0 of 96, band 8. Units left 11 of 11."))
        let first: Plan = Self.step(&core, Self.bare("compass.probe"))
        #expect(first == Self.state("Probe at bearing 0: hue gap 1 band, fog depth 21. Units left 10 of 11."))
        #expect(Plan.summaryText(core: core)
                == "Bearing 0, band 8. Units left 10 of 11. Last clue: hue gap 1 band, fog depth 21.")
        #expect(Self.step(&core, Self.turn(4)) == Self.state("Bearing 4 of 96, band 9. Units left 10 of 11."))
        let second: Plan = Self.step(&core, Self.bare("compass.probe"))
        #expect(second == Self.state("Probe at bearing 4: hue gap 0 bands, fog depth 3. Units left 9 of 11."))
        #expect(Plan.summaryText(core: core)
                == "Bearing 4, band 9. Units left 9 of 11. Last clue: hue gap 0 bands, fog depth 3.")
        // A probe clears undo: the refused undo changes nothing and plans nothing.
        let before: Core = core
        let undo: ActionResult = core.apply(Self.bare("play.undo"))
        #expect(core == before && Plan.after(old: before, new: core) == .none)
        #expect(Plan.refused(code: undo.code) == Plan(text: "That action is not allowed here.", kind: .rejection,
                                                      haptic: .error))
        // Three units spent against a smallest of one: 2 stars; only the outcome is planned.
        let won: Plan = Self.step(&core, Self.select(6, 8))
        #expect(won == Self.outcome("The bearing and band match. Level won with 3 units, 2 of 3 stars.", .success))
        let ended: ActionResult = core.apply(Self.turn(1))
        #expect(Plan.refused(code: ended.code).text == "The level has ended.")
        // A selection alone: 1 unit, 3 stars.
        var quick: Core = try await Core.prepare(seed: Self.seed)
        let quickWin: Plan = Self.step(&quick, Self.select(6, 8))
        #expect(quickWin == Self.outcome("The bearing and band match. Level won with 1 unit, 3 of 3 stars.", .success))
    }

    @Test func practiceWinHasNoStars() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.step(&core, Self.bare("mode.practice")) == Self.level("Level 37, band 2, Practice."))
        #expect(core.play.level.allowance == 24)
        #expect(Self.step(&core, Self.bare("compass.probe"))
                == Self.state("Probe at bearing 87: hue gap 4 bands, fog depth 62. Units left 23 of 24."))
        let won: Plan = Self.step(&core, Self.select(6, 8))
        #expect(won == Self.outcome("The bearing and band match. Level won with 2 units.", .success))
        #expect(Self.step(&core, Self.bare("mode.campaign")) == Self.level("Level 37, band 2, Campaign."))
    }

    @Test func probeExhaustionAndSelectionFailures() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        for spent in 1...10 {
            let plan: Plan = Self.step(&core, Self.bare("compass.probe"))
            #expect(plan == Self.state("Probe at bearing 87: hue gap 4 bands, fog depth 62. Units left \(11 - spent) of 11."))
        }
        let exhausted: Plan = Self.step(&core, Self.bare("compass.probe"))
        let probes: String = "The last unit went to a probe; keep one for the selection. Retry the level."
        #expect(core.play.stage == .failed && core.failureExplanation?.text == probes)
        #expect(exhausted == Self.outcome(probes, .warning))
        var missed: Core = try await Core.prepare(seed: Self.seed)
        let failed: Plan = Self.step(&missed, Self.select(50, 0))
        let selection: String = "The target was bearing 6 (band 9). Your selection was 44 bearings and 8 bands away; "
            + "the tolerances are 3 and 1. Retry the level."
        #expect(missed.failureExplanation?.text == selection)
        #expect(failed == Self.outcome(selection, .warning))
    }

    @Test func levelAndModeChangesWithTheTutorial() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.step(&core, Self.turn(1)).kind == .state)
        // The same level selected again: a fresh play, announced as a level.
        #expect(Self.step(&core, Self.bare("level.select", [37])) == Self.level("Level 37, band 2, Campaign."))
        // Level 1 shows the tutorial.
        let tutorialText: String = "Level 1, band 1, Campaign. " + Self.aim
        #expect(Self.step(&core, Self.bare("level.select", [1])) == Self.level(tutorialText))
        // Dismissing is not announced; reopening the untouched level shows the tutorial again.
        #expect(Self.step(&core, Self.bare("tutorial.dismiss")) == .none)
        #expect(Self.step(&core, Self.bare("mode.campaign")) == Self.level(tutorialText))
        // A turn advances the tutorial; its plan is still the turn's.
        #expect(Self.step(&core, Self.turn(1)) == Self.state("Bearing 36 of 96, band 24. Units left 9 of 9."))
        #expect(core.tutorial == .probe)
        // Practice on level 1 keeps the tutorial (every mode).
        #expect(Self.step(&core, Self.bare("mode.practice")) == Self.level("Level 1, band 1, Practice. " + Self.aim))
        // level.next from 1 in campaign: level 2, open.
        #expect(Self.step(&core, Self.bare("level.next")) == Self.level("Level 2, band 1, Campaign. " + Self.aim))
        // The daily level of 2026-11-21 is level 29, band 2.
        var daily: Core = try await Core.prepare(seed: Self.seed)
        let dailyPlan: Plan = Self.step(&daily, Self.bare("mode.daily", [2026, 11, 21]))
        #expect(dailyPlan == Self.level("Level 29, band 2, Daily level."))
    }

    @Test func bandPicks() {
        #expect(Plan.picked(band: 0) == Plan(text: "Band 1 picked.", kind: .state, haptic: nil))
        #expect(Plan.picked(band: 23) == Plan(text: "Band 24 picked.", kind: .state, haptic: nil))
    }

    @Test func refusals() async throws {
        let cases: [(String, String)] = [
            ("r02-g04.locked", "That level is not open yet."),
            ("r02-g04.date", "That date cannot be used."),
            ("r02-g04.action", "That action is not allowed here."),
            ("r02-g04.allowance", "No units are left."),
            ("r02-g04.stage", "The level has ended."),
            ("r02-g04.not-whole", "That value must be a whole number."),
            ("r02-g04.stale", "That change was refused."),
            ("action.unknown-control", "That change was refused."),
        ]
        for (code, text) in cases {
            let expected: Plan = Plan(text: text, kind: .rejection, haptic: .error)
            #expect(Plan.refused(code: code) == expected, "\(code)")
            #expect(Plan.refused(code: "action.rule." + code) == expected, "prefixed \(code)")
            #expect(Plan.refusalText(code: code) == text, "text \(code)")
            #expect(Plan.refusalText(code: "action.rule." + code) == text, "prefixed text \(code)")
        }
        // The codes the core reports; a refused action changes nothing, so it plans nothing.
        var core: Core = try await Core.prepare(seed: Self.seed)
        let before: Core = core
        let zero: ActionResult = core.apply(Self.turn(0))
        let half: ActionResult = core.apply(Self.bare("compass.turn", [1.5]))
        let locked: ActionResult = core.apply(Self.bare("level.select", [50]))
        let next: ActionResult = core.apply(Self.bare("level.next"))
        let date: ActionResult = core.apply(Self.bare("mode.daily", [2026, 2, 30]))
        #expect(core == before)
        #expect(Plan.after(old: before, new: core) == .none)
        #expect(Plan.refused(code: zero.code).text == "That action is not allowed here.")
        #expect(Plan.refused(code: half.code).text == "That value must be a whole number.")
        #expect(Plan.refused(code: locked.code).text == "That level is not open yet.")
        #expect(Plan.refused(code: next.code).text == "That level is not open yet.")
        #expect(Plan.refused(code: date.code).text == "That date cannot be used.")
    }
}
