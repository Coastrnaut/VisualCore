// ApsidesWorkshopFeedbackPlanTests — feature 476 (R02-G18-06) T-R02G1806-003 (FR-R02G1806-001, 002, 003;
// clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `ApsidesWorkshopFeedbackPlan` on real certified
// cores driven through `ApsidesWorkshopExperienceCore.apply`: size and periapsis tunings with an undo and a redo, then
// a 3-star campaign win along the certified witness (the play plans only the outcome) and the `stage` refusals after
// it; a 2-star and a 1-star campaign win after undone tunings (undone tunings count), a 1-action win, a practice win
// without stars and a daily win; every refusal code (provoked through the adapter where the core can produce it, with
// the engine's `action.rule.` prefix as `ActionResult.code` reports it, and every code by table, bare and prefixed);
// failed plays of every failure kind, each from a real level's opening orbit (order on level 1, share on level 2,
// contact on level 22, apsis sector on level 24, apsis distance on level 26), with an undo (state) and a redo back into
// the failure (only the outcome); a whole budget spent (the 10th tuning refused `budget`, the play then fails); level
// and mode changes with and without the tutorial; showing a tick and dismissing the tutorial plan nothing; a revealed
// hint; the summary element with and without a pending orbit.
// Seed 52 opens level 53 (band 3, no tutorial): period 32, 1 planet, targets sweep of sector 4 (2.3 % … 10.1 %),
// periapsis in sector 4 (22.75 … 26.75 units), sweep of sector 0; starting orbit size 16, eccentricity step 4,
// direction step 20; budget 13; certified witness size(29), periapsis(4, 12), play (2 tunings); its opening meets no
// target (sector 4 swept 12.4 %). Seed 0 opens level 1 (tutorial): period 24, no planets, 2 sweep targets, starting
// orbit (18, 10, 6) meeting target 1 only, budget 9, witness periapsis(0, 0) (1 tuning); its opening play fails `order`
// (target 2 at tick 12). Level 2 (budget 10) fails `share` (sector 1 swept 21.1 %), level 22 (budget 12) `contact`
// (planet 0 after tick 21), level 24 (budget 10) `apsis-sector` (apoapsis in sector 4, not 0), level 26 (budget 12)
// `apsis-distance` (apoapsis at 24.20 units, outside 25.20 … 29.80). Level 6 has 1 target and no planets. The daily
// level of 2026-01-01 is level 1, that of 2026-01-25 level 53. The values were read from the stored witnesses
// (docs/games/apsides-workshop/levels/) and the kernel's sky rules (worked out independently of the kernel's code
// path); the expected texts are written out here, not built with the plan's helpers. Explicit types, plain loops,
// short runs.
import Foundation
import Testing
@testable import ApsidesWorkshopCore
import VisualCoreExperience
import VisualCoreSimulation

/// One failed play from a level's opening orbit: the level, the failure code, the explanation's sentence and the
/// progress after undoing the play.
private struct FailureCase {
    /// The manifest number.
    let level: Int
    /// The failure code.
    let code: String
    /// The explanation's sentence (before the advice).
    let sentence: String
    /// The progress after the undo.
    let progress: String
}

@Suite struct ApsidesWorkshopFeedbackPlanTests {
    typealias Core = ApsidesWorkshopExperienceCore
    typealias Plan = ApsidesWorkshopFeedbackPlan

    /// The seed of level 53.
    static let seed53: UInt64 = 52

    /// The tutorial's first instruction (feature 475).
    static let knobStep: String = "Drag the periapsis knob (or use the \u{2212} and + buttons and Set periapsis) to "
        + "shape and aim the orbit; the gauges show what the new orbit would read"

    /// The advice that ends every failure explanation (feature 475).
    static let advice: String = "Undo the last action or retry the level."

    /// The opening sentence of a win.
    static let won: String = "Every target was met in order."

    /// The words of a `stage` refusal.
    static let ended: String = "The level has ended."

    /// The words of an `action` refusal.
    static let cannot: String = "That orbit cannot be set, or there is nothing to undo or redo."

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

    /// Sets the periapsis knob to eccentricity step `k` and direction step `d` and returns the plan.
    static func periapsis(_ core: inout Core, _ k: Int, _ d: Int) -> Plan {
        accepted(&core, "orbit.periapsis", [Double(k), Double(d)])
    }

    /// Sets the size to `a` and returns the plan.
    static func size(_ core: inout Core, _ a: Int) -> Plan {
        accepted(&core, "orbit.size", [Double(a)])
    }

    /// Plays the revolution and returns the plan.
    static func play(_ core: inout Core) -> Plan {
        accepted(&core, "orbit.play")
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

    @Test func tuningsUndoRedoAndA3StarCampaignWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed53)
        #expect(core.levelNumber == 53 && core.tutorial == .done && core.certifiedTunings == 2)
        let start: ApsidesWorkshopOrbit = ApsidesWorkshopOrbit(size: 16, eccentricity: 4, direction: 20)
        #expect(core.play.level.budget == 13 && core.play.orbit == start)
        #expect(Self.size(&core, 29) == Self.state("Size set to 29. 0 of 3 targets met in order, playing now would "
            + "fail, 12 actions left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 0 of 3 targets met in order, playing now "
            + "would fail, 13 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 0 of 3 targets met in order, playing now "
            + "would fail, 12 actions left."))
        #expect(Self.periapsis(&core, 4, 12) == Self.state("Periapsis set: eccentricity 0.20, periapsis at 180\u{B0}. "
            + "3 of 3 targets met in order, playing now would win, 11 actions left."))
        // The play plans only the outcome: 2 tunings (the redo spends nothing) against the certified 2.
        #expect(Self.play(&core) == Self.success(Self.won + " Level won spending 2 actions, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won play is final: the real `stage` refusals.
        let ended: Plan = Self.rejection(Self.ended)
        #expect(Self.refused(&core, "orbit.periapsis", [5, 12], code: "r02-g18.stage") == ended)
        #expect(Self.refused(&core, "orbit.size", [30], code: "r02-g18.stage") == ended)
        #expect(Self.refused(&core, "orbit.play", [], code: "r02-g18.stage") == ended)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g18.stage") == ended)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g18.stage") == ended)
        // The campaign win opened level 54.
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 54, band 3, campaign."))
        // "1 action" singular, on the tutorial level 1 (witness of 1 tuning).
        var first: Core = try await Core.prepare(seed: 0)
        #expect(first.levelNumber == 1 && first.certifiedTunings == 1 && first.tutorial == .knob)
        #expect(Self.periapsis(&first, 0, 0) == Self.state("Periapsis set: eccentricity 0.00, periapsis at 0\u{B0}. "
            + "2 of 2 targets met in order, playing now would win, 8 actions left."))
        #expect(Self.play(&first) == Self.success(Self.won + " Level won spending 1 action, 3 of 3 stars."))
    }

    @Test func undoneTuningsCountAndPracticeAndDailyWins() async throws {
        // Two undone tunings: 4 actions against the certified 2 → 2 stars.
        var two: Core = try await Core.prepare(seed: Self.seed53)
        for _ in 0..<2 {
            #expect(Self.periapsis(&two, 4, 12) == Self.state("Periapsis set: eccentricity 0.20, periapsis at "
                + "180\u{B0}. 1 of 3 targets met in order, playing now would fail, 12 actions left."))
            #expect(Self.accepted(&two, "play.undo") == Self.state("Undone. 0 of 3 targets met in order, playing now "
                + "would fail, 13 actions left."))
        }
        #expect(Self.size(&two, 29).kind == .state)
        #expect(Self.periapsis(&two, 4, 12).haptic == .selection)
        #expect(Self.play(&two) == Self.success(Self.won + " Level won spending 4 actions, 2 of 3 stars."))
        // Four undone tunings: 6 actions → 1 star.
        var one: Core = try await Core.prepare(seed: Self.seed53)
        for _ in 0..<4 {
            #expect(Self.periapsis(&one, 4, 12).kind == .state)
            #expect(Self.accepted(&one, "play.undo").kind == .state)
        }
        #expect(Self.size(&one, 29).kind == .state)
        #expect(Self.periapsis(&one, 4, 12).kind == .state)
        #expect(Self.play(&one) == Self.success(Self.won + " Level won spending 6 actions, 1 of 3 stars."))
        // Practice: the budget raised to 24, no stars.
        var practice: Core = try await Core.prepare(seed: Self.seed53)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 53, band 3, practice."))
        #expect(Self.size(&practice, 29) == Self.state("Size set to 29. 0 of 3 targets met in order, playing now "
            + "would fail, 23 actions left."))
        #expect(Self.periapsis(&practice, 4, 12) == Self.state("Periapsis set: eccentricity 0.20, periapsis at "
            + "180\u{B0}. 3 of 3 targets met in order, playing now would win, 22 actions left."))
        #expect(Self.play(&practice) == Self.success(Self.won + " Level won spending 2 actions."))
        // Daily: 2026-01-01 is level 1 (its tutorial shown), with stars.
        var daily: Core = try await Core.prepare(seed: Self.seed53)
        #expect(Self.accepted(&daily, "mode.daily", [2026, 1, 1])
                == Self.level("Level 1, band 1, daily. " + Self.knobStep))
        #expect(daily.certifiedTunings == 1)
        #expect(Self.periapsis(&daily, 0, 0) == Self.state("Periapsis set: eccentricity 0.00, periapsis at 0\u{B0}. "
            + "2 of 2 targets met in order, playing now would win, 8 actions left."))
        #expect(Self.play(&daily) == Self.success(Self.won + " Level won spending 1 action, 3 of 3 stars."))
    }

    @Test func everyRefusalCodeInWords() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed53)
        let action: Plan = Self.rejection(Self.cannot)
        // Provoked through the adapter (the engine reports `action.rule.<code>`): the same periapsis, the same size,
        // nothing to undo or redo.
        #expect(Self.refused(&core, "orbit.periapsis", [4, 20], code: "r02-g18.action") == action)
        #expect(Self.refused(&core, "orbit.size", [16], code: "r02-g18.action") == action)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g18.action") == action)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g18.action") == action)
        #expect(Self.refused(&core, "orbit.periapsis", [1.5, 0], code: "r02-g18.not-whole")
                == Self.rejection("That value must be a whole number."))
        #expect(Self.refused(&core, "orbit.size", [20.25], code: "r02-g18.not-whole")
                == Self.rejection("That value must be a whole number."))
        // The period of level 53 is 32 ticks.
        #expect(Self.refused(&core, "clock.show", [32], code: "r02-g18.tick")
                == Self.rejection("That tick is outside the revolution."))
        #expect(Self.refused(&core, "clock.show", [40], code: "r02-g18.tick")
                == Self.rejection("That tick is outside the revolution."))
        #expect(Self.refused(&core, "level.select", [100], code: "r02-g18.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g18.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g18.date")
                == Self.rejection("That date cannot be used."))
        // Level 2's orbit has size 39: eccentricity step 15 would carry the apoapsis out of the sky (39 × 35 > 1280).
        var second: Core = try Core.opening(number: 2)
        #expect(Self.refused(&second, "orbit.periapsis", [15, 14], code: "r02-g18.action") == action)
        // Every code by table, bare and with the engine's prefix.
        let table: [(String, String)] = [
            ("r02-g18.locked", "That level is not open yet."),
            ("r02-g18.date", "That date cannot be used."),
            ("r02-g18.action", "That orbit cannot be set, or there is nothing to undo or redo."),
            ("r02-g18.budget", "No actions are left: undo or retry."),
            ("r02-g18.stage", "The level has ended."),
            ("r02-g18.stale", "The play changed before the action arrived."),
            ("r02-g18.level", "That level could not be made."),
            ("r02-g18.not-whole", "That value must be a whole number."),
            ("r02-g18.tick", "That tick is outside the revolution."),
            ("r02-g18.malformed", "That action was refused."),
            ("r02-g18.generation", "That action was refused."),
            ("r02-g17.locked", "That action was refused."),
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
            FailureCase(level: 1, code: "order",
                        sentence: "Target 2 was reached at tick 12, before the target before it.",
                        progress: "1 of 2 targets met in order, playing now would fail, 9 actions left."),
            FailureCase(level: 2, code: "share",
                        sentence: "Target 1 (sector 1, reached at tick 16) swept 21.1 %, outside its band from 0.3 % "
                            + "to 16.1 %.",
                        progress: "0 of 2 targets met in order, playing now would fail, 10 actions left."),
            FailureCase(level: 22, code: "contact",
                        sentence: "The orbit struck planet 0 after tick 21.",
                        progress: "0 of 2 targets met in order, playing now would fail, 12 actions left."),
            FailureCase(level: 24, code: "apsis-sector",
                        sentence: "Target 1: the apoapsis lies in sector 4, not in sector 0.",
                        progress: "0 of 2 targets met in order, playing now would fail, 10 actions left."),
            FailureCase(level: 26, code: "apsis-distance",
                        sentence: "Target 1: the apoapsis lies at 24.20 units, outside its range from 25.20 units to "
                            + "29.80 units.",
                        progress: "0 of 2 targets met in order, playing now would fail, 12 actions left."),
        ]
        var codes: [String] = []
        for sample in cases {
            var core: Core = try Core.opening(number: sample.level)
            let failing: Plan = Self.warning(sample.sentence + " " + Self.advice)
            #expect(Self.play(&core) == failing, "level \(sample.level)")
            #expect(core.play.stage == .failed)
            #expect(failing.text == ApsidesWorkshopFailureExplanation(play: core.play)?.text)
            if let failure = core.play.failure { codes.append(failure.code) }
            #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. " + sample.progress),
                    "level \(sample.level)")
            #expect(Self.accepted(&core, "play.redo") == failing, "level \(sample.level)")
        }
        #expect(codes == ["order", "share", "contact", "apsis-sector", "apsis-distance"])
    }

    @Test func aWholeBudgetSpentThenTheBudgetRefusalAndAFailedPlay() throws {
        // Level 1 (budget 9): the size set to 19, 18, 19, … nine times; every orbit still fails `order`.
        var core: Core = try Core.opening(number: 1)
        #expect(core.play.level.budget == 9 && core.play.orbit.size == 18)
        let left: [String] = ["8 actions left", "7 actions left", "6 actions left", "5 actions left",
                              "4 actions left", "3 actions left", "2 actions left", "1 action left", "0 actions left"]
        for index in 0..<left.count {
            let a: Int = index % 2 == 0 ? 19 : 18
            let expected: Plan = Self.state("Size set to \(a). 1 of 2 targets met in order, playing now would fail, "
                + left[index] + ".")
            #expect(Self.size(&core, a) == expected, "tuning \(index + 1)")
        }
        #expect(Self.refused(&core, "orbit.size", [18], code: "r02-g18.budget")
                == Self.rejection("No actions are left: undo or retry."))
        #expect(Self.refused(&core, "orbit.periapsis", [0, 0], code: "r02-g18.budget")
                == Self.rejection("No actions are left: undo or retry."))
        // The play is still allowed and plans only the warning.
        let failing: Plan = Self.warning("Target 2 was reached at tick 12, before the target before it. "
            + Self.advice)
        #expect(Self.play(&core) == failing)
        let ended: Plan = Self.rejection(Self.ended)
        #expect(Self.refused(&core, "orbit.size", [18], code: "r02-g18.stage") == ended)
        #expect(Self.refused(&core, "orbit.play", [], code: "r02-g18.stage") == ended)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g18.stage") == ended)
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 of 2 targets met in order, playing now "
            + "would fail, 0 actions left."))
        #expect(Self.accepted(&core, "play.redo") == failing)
    }

    @Test func levelAndModeChanges() async throws {
        // Level 1 (tutorial): dismissing plans nothing; reopening it shows the tutorial again.
        var first: Core = try await Core.prepare(seed: 0)
        #expect(first.tutorial == .knob)
        #expect(Self.accepted(&first, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&first, "level.select", [1])
                == Self.level("Level 1, band 1, campaign. " + Self.knobStep))
        #expect(Self.accepted(&first, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.knobStep))
        #expect(Self.periapsis(&first, 0, 0) == Self.state("Periapsis set: eccentricity 0.00, periapsis at 0\u{B0}. "
            + "2 of 2 targets met in order, playing now would win, 23 actions left."))
        #expect(Self.accepted(&first, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.knobStep))
        // Level 53 (no tutorial): modes, the daily level, other levels.
        var core: Core = try await Core.prepare(seed: Self.seed53)
        #expect(Self.size(&core, 29).kind == .state)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 53, band 3, practice."))
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 53, band 3, campaign."))
        #expect(Self.size(&core, 29).kind == .state)
        #expect(Self.accepted(&core, "level.select", [53]) == Self.level("Level 53, band 3, campaign."))
        #expect(Self.accepted(&core, "mode.daily", [2026, 1, 25]) == Self.level("Level 53, band 3, daily."))
        #expect(Self.accepted(&core, "level.select", [3])
                == Self.level("Level 3, band 1, campaign. " + Self.knobStep))
        #expect(Self.accepted(&core, "level.select", [4]) == Self.level("Level 4, band 1, campaign."))
        // Reopening an untouched level without a tutorial changes nothing.
        #expect(Self.accepted(&core, "level.select", [4]) == Plan.none)
    }

    @Test func showingATickPlansNothingAHintAndTheSummary() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed53)
        let ticks: [Double] = [10, 31, 0, 16]
        for tick in ticks {
            #expect(Self.accepted(&core, "clock.show", [tick]) == Plan.none, "tick \(tick)")
        }
        // The tutorial of level 53 is already done: dismissing it changes nothing.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        let hint: Plan = Plan.hint(text: "Change the size next")
        #expect(hint == Plan(text: "Change the size next", kind: .state, haptic: nil))
        let level53: String = "Level: level 53, band 3, campaign; 3 targets in order, 1 planet, a period of 32 ticks; "
            + "a budget of 13 actions."
        let next: String = "next: sector 4 swept 12.4 %, needs 2.3 % to 10.1 %"
        let opening: String = "13 actions left. 0 of 3 targets met in order; " + next + "; playing now would fail. "
        #expect(Plan.summaryText(core: core, pending: nil) == opening
            + "Pending: size 16, eccentricity 0.20, periapsis at 300\u{B0}. " + level53)
        let pending: ApsidesWorkshopOrbit = ApsidesWorkshopOrbit(size: 29, eccentricity: 4, direction: 20)
        #expect(Plan.summaryText(core: core, pending: pending) == opening
            + "Pending: size 29, eccentricity 0.20, periapsis at 300\u{B0}. " + level53)
        #expect(Self.size(&core, 29).kind == .state)
        #expect(Plan.summaryText(core: core, pending: nil) == "12 actions left. 0 of 3 targets met in order; " + next
            + "; playing now would fail. Pending: size 29, eccentricity 0.20, periapsis at 300\u{B0}. " + level53)
        #expect(Self.periapsis(&core, 4, 12).kind == .state)
        #expect(Plan.summaryText(core: core, pending: nil) == "11 actions left. 3 of 3 targets met in order; playing "
            + "now would win. Pending: size 29, eccentricity 0.20, periapsis at 180\u{B0}. " + level53)
        #expect(Self.accepted(&core, "mode.practice").kind == .level)
        #expect(Plan.summaryText(core: core, pending: nil).hasSuffix("Level: level 53, band 3, practice; 3 targets in "
            + "order, 1 planet, a period of 32 ticks; a budget of 24 actions."))
        // Level 1: no planets.
        let first: Core = try await Core.prepare(seed: 0)
        #expect(Plan.summaryText(core: first, pending: nil) == "9 actions left. 1 of 2 targets met in order; next: "
            + "sector 6 swept 29.5 %, needs 6.4 % to 18.4 %; playing now would fail. Pending: size 18, eccentricity "
            + "0.50, periapsis at 90\u{B0}. Level: level 1, band 1, campaign; 2 targets in order, no planets, a period "
            + "of 24 ticks; a budget of 9 actions.")
        // Level 22: the orbit strikes a planet.
        let struck: Core = try Core.opening(number: 22)
        #expect(Plan.summaryText(core: struck, pending: nil) == "12 actions left. 0 of 2 targets met in order; the "
            + "orbit strikes planet 0 after tick 21; playing now would fail. Pending: size 44, eccentricity 0.25, "
            + "periapsis at 315\u{B0}. Level: level 22, band 2, campaign; 2 targets in order, 1 planet, a period of 24 "
            + "ticks; a budget of 12 actions.")
        // Level 6: one target.
        let single: Core = try Core.opening(number: 6)
        #expect(Plan.summaryText(core: single, pending: nil) == "10 actions left. 0 of 1 targets met in order; next: "
            + "sector 7 swept 8.2 %, needs 9.9 % to 23.3 %; playing now would fail. Pending: size 11, eccentricity "
            + "0.15, periapsis at 0\u{B0}. Level: level 6, band 1, campaign; 1 target in order, no planets, a period "
            + "of 24 ticks; a budget of 10 actions.")
    }
}
