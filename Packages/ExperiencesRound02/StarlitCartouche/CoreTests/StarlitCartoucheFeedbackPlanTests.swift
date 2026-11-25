// StarlitCartoucheFeedbackPlanTests — feature 456 (R02-G16-06) T-R02G1606-003 (FR-R02G1606-001, 002, 003, 005;
// SC-R02G1606-001, 002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of
// `StarlitCartoucheFeedbackPlan` on real certified cores driven through `StarlitCartoucheExperienceCore.apply`: legs
// with an undo and a redo, then a 3-star campaign win along the certified witness (the winning leg plans only the
// outcome) and the `stage` refusals after it; a 2-star and a 1-star campaign win after undone legs (undone legs count),
// a practice win without stars and a daily win; every refusal code (provoked through the adapter where the core can
// produce it, with the engine's `action.rule.` prefix as `ActionResult.code` reports it, and every code by table, bare
// and prefixed); failures of every leg kind (departure, hazard, arrival, deadline, stroke; each the first a search over
// the opening legs of levels 1 … 100 finds, pinned here) with an undo (state) and a redo back into the failure (only
// the outcome) and the budget (a whole budget of clear legs that never wins, found by a bounded depth-first search on
// the levels that allow one, as `StarlitCartoucheHintsTests` does: the budget-ending leg plans only the warning); level
// and mode changes with and without the tutorial; choosing a destination or wait and dismissing the tutorial plan
// nothing; a revealed hint; the summary element.
// Seed 46 opens level 47 (band 3, no tutorial): 7 stars, corridors 0–5, 2–5, 1–2, 1–3, 3–5, 1–5, symbol corridors
// 0 … 3, start star 5, beacon star 3, deadline beat 19, budget 15; certified witness (0, 0), (5, 0), (2, 0), (1, 0),
// (3, 3) (5 legs). Seed 0 opens level 1 (tutorial): corridors 1–4, 4–5, 2–4, symbol 0 and 1, budget 9, witness (4, 1),
// (5, 0). The daily level of 2026-01-01 is level 1, that of 2026-11-24 level 100. The expected texts are written out
// here, not built with the plan's helpers. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import StarlitCartoucheCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct StarlitCartoucheFeedbackPlanTests {
    typealias Core = StarlitCartoucheExperienceCore
    typealias Plan = StarlitCartoucheFeedbackPlan

    /// The seed of level 47.
    static let seed47: UInt64 = 46

    /// The tutorial's first instruction (feature 455).
    static let flyStep: String = "Tap a star to choose where to fly, set the wait on the slider "
        + "(or Wait \u{2212} and +) so the star is in range at launch, then double-tap it (or press Fly): "
        + "the trail draws a stroke of the symbol"

    /// The advice that ends every failure explanation (feature 455).
    static let advice: String = "Undo the last action or retry the level."

    /// The opening sentence of a win.
    static let won: String = "The trail draws the symbol at the beacon."

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

    /// Flies to `star` after `wait` beats and returns the plan.
    static func fly(_ core: inout Core, _ star: Int, _ wait: Int) -> Plan {
        accepted(&core, "route.fly", [Double(star), Double(wait)])
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

    @Test func legsUndoRedoAndA3StarCampaignWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed47)
        #expect(core.levelNumber == 47 && core.tutorial == .done && core.certifiedLegs == 5)
        #expect(Self.fly(&core, 0, 0) == Self.state("Flew to star 0 after 0 beats along the corridor between star 0 "
            + "and star 5. 1 of 4 strokes drawn, 14 actions left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 0 of 4 strokes drawn, 15 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 1 of 4 strokes drawn, 14 actions left."))
        #expect(Self.fly(&core, 5, 0) == Self.state("Flew to star 5 after 0 beats along the corridor between star 0 "
            + "and star 5. 1 of 4 strokes drawn, 13 actions left."))
        #expect(Self.fly(&core, 2, 0) == Self.state("Flew to star 2 after 0 beats along the corridor between star 2 "
            + "and star 5. 2 of 4 strokes drawn, 12 actions left."))
        #expect(Self.fly(&core, 1, 0) == Self.state("Flew to star 1 after 0 beats along the corridor between star 1 "
            + "and star 2. 3 of 4 strokes drawn, 11 actions left."))
        // The winning leg plans only the outcome: 5 legs (the redo spends nothing) against the certified 5.
        #expect(Self.fly(&core, 3, 3) == Self.success(Self.won + " Level won spending 5 actions, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won play is final: the real `stage` refusals.
        let ended: Plan = Self.rejection("The level has ended.")
        #expect(Self.refused(&core, "route.fly", [1, 0], code: "r02-g16.stage") == ended)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g16.stage") == ended)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g16.stage") == ended)
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 48, band 3, campaign."))
        // "1 beat" singular, on the tutorial level 1.
        var first: Core = try await Core.prepare(seed: 0)
        #expect(Self.fly(&first, 4, 1) == Self.state("Flew to star 4 after 1 beat along the corridor between star 1 "
            + "and star 4. 1 of 2 strokes drawn, 8 actions left."))
        #expect(Self.fly(&first, 5, 0) == Self.success(Self.won + " Level won spending 2 actions, 3 of 3 stars."))
    }

    @Test func undoneLegsCountAndPracticeAndDailyWins() async throws {
        let witness: [(Int, Int)] = [(0, 0), (5, 0), (2, 0), (1, 0), (3, 3)]
        // Two undone legs: 7 actions against the certified 5 → 2 stars.
        var two: Core = try await Core.prepare(seed: Self.seed47)
        for _ in 0..<2 {
            #expect(Self.fly(&two, 0, 0) == Self.state("Flew to star 0 after 0 beats along the corridor between star 0 "
                + "and star 5. 1 of 4 strokes drawn, 14 actions left."))
            #expect(Self.accepted(&two, "play.undo") == Self.state("Undone. 0 of 4 strokes drawn, 15 actions left."))
        }
        var plans: [Plan] = []
        for (star, wait) in witness { plans.append(Self.fly(&two, star, wait)) }
        #expect(plans.last == Self.success(Self.won + " Level won spending 7 actions, 2 of 3 stars."))
        for index in 0..<(plans.count - 1) { #expect(plans[index].kind == .state && plans[index].haptic == .selection) }
        // Four undone legs: 9 actions → 1 star.
        var one: Core = try await Core.prepare(seed: Self.seed47)
        for _ in 0..<4 {
            #expect(Self.fly(&one, 0, 0).kind == .state)
            #expect(Self.accepted(&one, "play.undo") == Self.state("Undone. 0 of 4 strokes drawn, 15 actions left."))
        }
        var last: Plan = .none
        for (star, wait) in witness { last = Self.fly(&one, star, wait) }
        #expect(last == Self.success(Self.won + " Level won spending 9 actions, 1 of 3 stars."))
        // Practice: the budget raised to 24, no stars.
        var practice: Core = try await Core.prepare(seed: Self.seed47)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 47, band 3, practice."))
        #expect(Self.fly(&practice, 0, 0) == Self.state("Flew to star 0 after 0 beats along the corridor between "
            + "star 0 and star 5. 1 of 4 strokes drawn, 23 actions left."))
        last = .none
        for index in 1..<witness.count { last = Self.fly(&practice, witness[index].0, witness[index].1) }
        #expect(last == Self.success(Self.won + " Level won spending 5 actions."))
        // Daily: 2026-01-01 is level 1 (its tutorial shown), with stars.
        var daily: Core = try await Core.prepare(seed: Self.seed47)
        #expect(Self.accepted(&daily, "mode.daily", [2026, 1, 1])
                == Self.level("Level 1, band 1, daily. " + Self.flyStep))
        #expect(Self.fly(&daily, 4, 1).kind == .state)
        #expect(Self.fly(&daily, 5, 0) == Self.success(Self.won + " Level won spending 2 actions, 3 of 3 stars."))
    }

    @Test func everyRefusalCodeInWords() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed47)
        // Provoked through the adapter (the engine reports `action.rule.<code>`).
        #expect(Self.refused(&core, "route.fly", [9, 0], code: "r02-g16.action")
                == Self.rejection("No corridor can be flown there now."))
        #expect(Self.refused(&core, "route.fly", [4, 0], code: "r02-g16.action")
                == Self.rejection("No corridor can be flown there now."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g16.action")
                == Self.rejection("No corridor can be flown there now."))
        #expect(Self.refused(&core, "route.fly", [0.5, 0], code: "r02-g16.not-whole")
                == Self.rejection("That value must be a whole number."))
        #expect(Self.refused(&core, "route.choose", [5, 0], code: "r02-g16.choice")
                == Self.rejection("That destination or wait cannot be chosen."))
        #expect(Self.refused(&core, "route.choose", [9, 0], code: "r02-g16.choice")
                == Self.rejection("That destination or wait cannot be chosen."))
        #expect(Self.refused(&core, "level.select", [100], code: "r02-g16.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g16.date")
                == Self.rejection("That date cannot be used."))
        // Every code by table, bare and with the engine's prefix.
        let table: [(String, String)] = [
            ("r02-g16.locked", "That level is not open yet."),
            ("r02-g16.date", "That date cannot be used."),
            ("r02-g16.action", "No corridor can be flown there now."),
            ("r02-g16.stage", "The level has ended."),
            ("r02-g16.not-whole", "That value must be a whole number."),
            ("r02-g16.choice", "That destination or wait cannot be chosen."),
            ("r02-g16.stale", "That action was refused."),
            ("r02-g16.level", "That action was refused."),
            ("r02-g16.malformed", "That action was refused."),
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

    @Test func everyLegFailureKindPlansOnlyItsOutcome() throws {
        // (level, star, wait, explanation sentence, progress after the undo), each the first of its kind found.
        let cases: [(Int, Int, Int, String, String)] = [
            (8, 3, 4, "Action 1 (a leg to star 3 after 4 beats) leaves star 0 at beat 4, after its window closed at "
                + "beat 3.", "0 of 2 strokes drawn, 8 actions left."),
            (2, 5, 5, "Action 1 (a leg to star 5 after 5 beats) flies corridor 0 through hazard 0, active from beat 8 "
                + "to beat 11.", "0 of 2 strokes drawn, 10 actions left."),
            (1, 4, 7, "Action 1 (a leg to star 4 after 7 beats) reaches star 4 at beat 10, outside its window from "
                + "beat 4 to beat 8.", "0 of 2 strokes drawn, 9 actions left."),
            (18, 3, 6, "Action 1 (a leg to star 3 after 6 beats) arrives at beat 8, after the deadline at beat 7.",
             "0 of 1 strokes drawn, 10 actions left."),
            (2, 3, 0, "Action 1 (a leg to star 3 after 0 beats) flies corridor 2, which is not part of the symbol.",
             "0 of 2 strokes drawn, 10 actions left."),
        ]
        var kinds: [String] = []
        for (number, star, wait, sentence, progress) in cases {
            var core: Core = try Core.opening(number: number)
            let failing: Plan = Self.warning(sentence + " " + Self.advice)
            #expect(Self.fly(&core, star, wait) == failing, "level \(number)")
            #expect(core.play.stage == .failed)
            if let failure = core.play.failure { kinds.append(String("\(failure)".prefix { $0 != "(" })) }
            #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. " + progress), "level \(number)")
            #expect(Self.accepted(&core, "play.redo") == failing, "level \(number)")
        }
        #expect(kinds == ["departure", "hazard", "arrival", "deadline", "stroke"])
    }

    /// A route of exactly `level.budget` clear symbol legs from the start that never wins (so its last leg spends the
    /// budget and fails `budget`), found by a depth-first search over (star, beat, drawn strokes) — corridors by index,
    /// waits 0 … 8 — with dead states remembered per depth; nil when none is found within `nodes` states.
    static func budgetRoute(_ level: StarlitCartoucheLevel, nodes: Int = 20_000) -> [(Int, Int)]? {
        var strokeBit: [Int: Int] = [:]
        for (bit, corridor) in level.symbol.enumerated() { strokeBit[corridor] = bit }
        let full: Int = (1 << level.symbol.count) - 1
        var dead: Set<[Int]> = []
        var visited: Int = 0
        var route: [(Int, Int)] = []
        func search(star: Int, beat: Int, mask: Int) -> Bool {
            if route.count == level.budget { return true }
            let key: [Int] = [star, beat, mask, route.count]
            if dead.contains(key) { return false }
            visited += 1
            if visited > nodes { return false }
            for corridor in level.corridors where corridor.a == star || corridor.b == star {
                let destination: Int = corridor.a == star ? corridor.b : corridor.a
                for wait in StarlitCartoucheChart.waits {
                    guard let leg = try? StarlitCartoucheChart.leg(level, from: star, at: beat, to: destination,
                                                                   wait: wait),
                          StarlitCartoucheChart.check(level, leg: leg) == nil,
                          let bit = strokeBit[leg.corridor] else { continue }
                    let next: Int = mask | (1 << bit)
                    if next == full && destination == level.beacon { continue }
                    route.append((destination, wait))
                    if search(star: destination, beat: leg.arrive, mask: next) { return true }
                    route.removeLast()
                    if visited > nodes { return false }
                }
            }
            dead.insert(key)
            return false
        }
        return search(star: level.start, beat: 0, mask: 0) ? route : nil
    }

    @Test func theBudgetEndingLegPlansOnlyTheWarning() throws {
        // The first of the levels known to allow a budget-out whose bounded search finds one.
        var found: (Int, [(Int, Int)])?
        for number in [12, 28, 41, 43] where found == nil {
            if let route = Self.budgetRoute(try Core.level(number: number)) { found = (number, route) }
        }
        let (number, route): (Int, [(Int, Int)]) = try #require(found)
        #expect(number == 12 && route.count == 8)
        var core: Core = try Core.opening(number: number)
        #expect(core.play.level.budget == 8 && core.certifiedLegs == 3)
        let expected: [String] = [
            "Flew to star 2 after 0 beats along the corridor between star 0 and star 2. 1 of 3 strokes drawn, "
                + "7 actions left.",
            "Flew to star 0 after 1 beat along the corridor between star 0 and star 2. 1 of 3 strokes drawn, "
                + "6 actions left.",
            "Flew to star 3 after 2 beats along the corridor between star 0 and star 3. 2 of 3 strokes drawn, "
                + "5 actions left.",
            "Flew to star 0 after 0 beats along the corridor between star 0 and star 3. 2 of 3 strokes drawn, "
                + "4 actions left.",
            "Flew to star 3 after 0 beats along the corridor between star 0 and star 3. 2 of 3 strokes drawn, "
                + "3 actions left.",
            "Flew to star 0 after 0 beats along the corridor between star 0 and star 3. 2 of 3 strokes drawn, "
                + "2 actions left.",
            "Flew to star 3 after 0 beats along the corridor between star 0 and star 3. 2 of 3 strokes drawn, "
                + "1 action left.",
        ]
        for index in 0..<expected.count {
            #expect(Self.fly(&core, route[index].0, route[index].1) == Self.state(expected[index]), "leg \(index)")
        }
        // The leg that spends the last of the budget plans only the warning.
        let budgetOut: Plan = Self.warning("Action 8 (a leg to star 2 after 0 beats) spent the last action without "
            + "completing the symbol at the beacon. " + Self.advice)
        #expect(Self.fly(&core, route[7].0, route[7].1) == budgetOut)
        #expect(core.play.failure == .budget(8))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 2 of 3 strokes drawn, 1 action left."))
        #expect(Self.accepted(&core, "play.redo") == budgetOut)
    }

    @Test func levelAndModeChanges() async throws {
        // Level 1 (tutorial): dismissing plans nothing; reopening it shows the tutorial again.
        var first: Core = try await Core.prepare(seed: 0)
        #expect(first.tutorial == .fly)
        #expect(Self.accepted(&first, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&first, "level.select", [1]) == Self.level("Level 1, band 1, campaign. " + Self.flyStep))
        #expect(Self.accepted(&first, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.flyStep))
        #expect(Self.fly(&first, 4, 1) == Self.state("Flew to star 4 after 1 beat along the corridor between star 1 "
            + "and star 4. 1 of 2 strokes drawn, 23 actions left."))
        #expect(Self.accepted(&first, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.flyStep))
        // Level 47 (no tutorial): modes, another level, the daily level.
        var core: Core = try await Core.prepare(seed: Self.seed47)
        #expect(Self.fly(&core, 0, 0).kind == .state)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 47, band 3, practice."))
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 47, band 3, campaign."))
        #expect(Self.fly(&core, 0, 0).kind == .state)
        #expect(Self.accepted(&core, "level.select", [47]) == Self.level("Level 47, band 3, campaign."))
        #expect(Self.accepted(&core, "level.select", [3]) == Self.level("Level 3, band 1, campaign. " + Self.flyStep))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 24]) == Self.level("Level 100, band 5, daily."))
        #expect(Self.accepted(&core, "level.select", [21]) == Self.level("Level 21, band 2, campaign."))
        // Reopening an untouched level without a tutorial changes nothing.
        #expect(Self.accepted(&core, "level.select", [21]) == Plan.none)
    }

    @Test func choosingPlansNothingAHintAndTheSummary() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed47)
        #expect(Self.accepted(&core, "route.choose", [2, 3]) == Plan.none)
        #expect(Self.accepted(&core, "route.choose", [4, 8]) == Plan.none)
        #expect(Self.accepted(&core, "route.choose", [0, 0]) == Plan.none)
        let hint: Plan = Plan.hint(text: "Fly to star 0 after waiting 0 beats")
        #expect(hint == Plan(text: "Fly to star 0 after waiting 0 beats", kind: .state, haptic: nil))
        let level47: String = "Level: level 47, band 3, campaign; draw the symbol of 4 strokes across 7 stars and "
            + "reach star 3 by beat 19; a budget of 15 actions."
        #expect(Plan.summaryText(core: core, destination: 0, wait: 0) == "15 actions left. At star 5, beat 0; 0 of 4 "
            + "strokes drawn; 19 beats to the deadline. Chosen: star 0 along the corridor between star 0 and star 5, "
            + "wait 0 beats. " + level47)
        #expect(Plan.summaryText(core: core, destination: 4, wait: 1) == "15 actions left. At star 5, beat 0; 0 of 4 "
            + "strokes drawn; 19 beats to the deadline. Chosen: star 4: no corridor from star 5, wait 1 beat. "
            + level47)
        #expect(Self.fly(&core, 0, 0).kind == .state)
        #expect(Plan.summaryText(core: core, destination: 5, wait: 2) == "14 actions left. At star 0, beat 2; 1 of 4 "
            + "strokes drawn; 17 beats to the deadline. Chosen: star 5 along the corridor between star 0 and star 5, "
            + "wait 2 beats. " + level47)
        #expect(Self.accepted(&core, "mode.practice").kind == .level)
        #expect(Plan.summaryText(core: core, destination: 0, wait: 0).hasSuffix("Level: level 47, band 3, practice; "
            + "draw the symbol of 4 strokes across 7 stars and reach star 3 by beat 19; a budget of 24 actions."))
    }
}
