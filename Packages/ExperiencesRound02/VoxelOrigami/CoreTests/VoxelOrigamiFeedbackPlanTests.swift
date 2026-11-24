// VoxelOrigamiFeedbackPlanTests — feature 446 (R02-G15-06) T-R02G1506-003 (FR-R02G1506-001, 002, 003, 005;
// SC-R02G1506-001, 002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `VoxelOrigamiFeedbackPlan`
// on real certified cores driven through `VoxelOrigamiExperienceCore.apply`: turns forward and back, an undo and a
// redo, then a 3-star campaign win along the certified witness (the winning turn plans only the outcome) and the
// `stage` refusals after it; a 2-star and a 1-star campaign win with detours (undone turns count), a practice win
// without stars and a daily win; every refusal code (provoked through the adapter where the core can produce it, every
// code by table, bare and with the engine's `action.rule.` prefix); failures by collision, by sweep (each found by a
// search over the turns of the opening levels, then pinned) and by the budget (the budget-ending turn plans only the
// warning; an undo plans the state, a redo that fails again only the outcome); level and mode changes with and without
// the tutorial; choosing a hinge plans nothing; a revealed hint; the summary element.
// Seed 2_446 opens level 47 (band 3, no tutorial): 8 cubes, fixed orientation, budget 15, 4 cubes in place; hinges 1 …
// 5 can turn, 6 and 7 cannot; certified witness turn(1, −1), turn(2, +1), turn(1, −1), turn(5, +1) (4 turns). Level 1
// (tutorial): 6 cubes, budget 9, witness turn(4, −1) twice. Level 4: 6 cubes, budget 8, only hinge 1 can turn at the
// start. Level 2: turn(3, +1) twice collides (the first collision the search finds); level 3: turn(3, −1) then
// turn(1, +1) sweeps (the first sweep it finds). Level 5: turn(2, +1) collides at the start; turn(1, +1) then turn(2,
// +1) sweeps. The daily level of 2026-11-24 is level 38 (band 2, witness turn(2, −1), turn(3, −1) twice); that of
// 2026-01-01 is level 1. The expected texts are written out here, not built with the plan's helpers. Explicit types,
// plain loops, short runs.
import Foundation
import Testing
@testable import VoxelOrigamiCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct VoxelOrigamiFeedbackPlanTests {
    typealias Core = VoxelOrigamiExperienceCore
    typealias Plan = VoxelOrigamiFeedbackPlan

    /// The seed of the feature: level 47.
    static let seed: UInt64 = 2_446

    /// The tutorial's first instruction (feature 445).
    static let turnStep: String = "Tap a cube to choose its hinge, then drag the cube (or use Turn \u{2212} and +) to "
        + "turn the hinge a quarter turn: every cube beyond it swings"

    /// The advice that ends every failure explanation (feature 445).
    static let advice: String = "Undo the last action or retry the level."

    /// Level 47's summary words of the level.
    static let level47: String = "Level: level 47, band 3, campaign; 8 cubes, 7 hinges; the target as placed; "
        + "a budget of 15 actions."

    /// The bare action `control` with `values`.
    static func bare(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// Applies `control` with `values` to `core` and expects it accepted.
    static func apply(_ core: inout Core, _ control: String, _ values: [Double] = []) {
        let result: ActionResult = core.apply(bare(control, values))
        #expect(result == .accepted, "\(control) \(values): \(result)")
    }

    /// Applies `control` with `values` to `core`, expects it accepted and returns the plan of the change.
    static func accepted(_ core: inout Core, _ control: String, _ values: [Double] = []) -> Plan {
        let old: Core = core
        apply(&core, control, values)
        return Plan.after(old: old, new: core)
    }

    /// Turns `hinge` by `step` and returns the plan.
    static func turn(_ core: inout Core, _ hinge: Int, _ step: Int) -> Plan {
        accepted(&core, "hinge.turn", [Double(hinge), Double(step)])
    }

    /// Applies the kernel `action` through the adapter, expects it accepted and returns the plan.
    static func act(_ core: inout Core, _ action: VoxelOrigamiAction) -> Plan {
        switch action {
        case let .turn(hinge, step): turn(&core, hinge, step)
        }
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

    /// The certified witness turns of level `number`.
    static func witness(_ number: Int) throws -> [VoxelOrigamiAction] {
        try Core.generated(number: number).plan.turns
    }

    @Test func turnsUndoRedoAndA3StarCampaignWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 47 && core.tutorial == .done && core.certifiedTurns == 4)
        #expect(Self.turn(&core, 1, -1)
                == Self.state("Turned hinge 1 back a quarter turn. 4 of 8 cubes in place, 14 actions left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 4 of 8 cubes in place, 15 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 4 of 8 cubes in place, 14 actions left."))
        #expect(Self.turn(&core, 2, 1)
                == Self.state("Turned hinge 2 forward a quarter turn. 6 of 8 cubes in place, 13 actions left."))
        #expect(Self.turn(&core, 1, -1)
                == Self.state("Turned hinge 1 back a quarter turn. 7 of 8 cubes in place, 12 actions left."))
        // The winning turn plans only the outcome. 4 turns (the redo spends nothing) against the certified 4.
        #expect(Self.turn(&core, 5, 1)
                == Self.won("The chain matches the target. Level won spending 4 actions, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won play is final: the real `stage` refusals.
        let ended: Plan = Self.rejection("The level has ended.")
        #expect(Self.refused(&core, "hinge.turn", [1, 1], code: "r02-g15.stage") == ended)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g15.stage") == ended)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g15.stage") == ended)
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 48, band 3, campaign."))
    }

    @Test func detouredCampaignWinsAPracticeWinWithoutStarsAndADailyWin() async throws {
        let witness: [VoxelOrigamiAction] = try Self.witness(47)
        #expect(witness == [.turn(1, -1), .turn(2, 1), .turn(1, -1), .turn(5, 1)])
        // Two detour turns: 6 actions against the certified 4 → 2 stars.
        var two: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.turn(&two, 3, 1)
                == Self.state("Turned hinge 3 forward a quarter turn. 4 of 8 cubes in place, 14 actions left."))
        #expect(Self.turn(&two, 3, -1)
                == Self.state("Turned hinge 3 back a quarter turn. 4 of 8 cubes in place, 13 actions left."))
        var plans: [Plan] = []
        for action in witness { plans.append(Self.act(&two, action)) }
        #expect(plans.last == Self.won("The chain matches the target. Level won spending 6 actions, 2 of 3 stars."))
        for index in 0..<(plans.count - 1) { #expect(plans[index].kind == .state && plans[index].haptic == .selection) }
        // Three undone turns still count: 7 actions → 1 star.
        var one: Core = try await Core.prepare(seed: Self.seed)
        for _ in 0..<3 {
            #expect(Self.turn(&one, 3, 1).kind == .state)
            #expect(Self.accepted(&one, "play.undo") == Self.state("Undone. 4 of 8 cubes in place, 15 actions left."))
        }
        var last: Plan = .none
        for action in witness { last = Self.act(&one, action) }
        #expect(last == Self.won("The chain matches the target. Level won spending 7 actions, 1 of 3 stars."))

        var practice: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 47, band 3, practice."))
        #expect(Self.turn(&practice, 1, -1)
                == Self.state("Turned hinge 1 back a quarter turn. 4 of 8 cubes in place, 39 actions left."))
        for action in witness.dropFirst() { last = Self.act(&practice, action) }
        #expect(last == Self.won("The chain matches the target. Level won spending 4 actions."))

        var daily: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.accepted(&daily, "mode.daily", [2026, 11, 24]) == Self.level("Level 38, band 2, daily."))
        let dailyWitness: [VoxelOrigamiAction] = try Self.witness(38)
        for action in dailyWitness { last = Self.act(&daily, action) }
        #expect(dailyWitness == [.turn(2, -1), .turn(3, -1), .turn(3, -1)])
        #expect(last == Self.won("The chain matches the target. Level won spending 3 actions, 3 of 3 stars."))
    }

    @Test func everyRefusalCode() throws {
        var core: Core = try Core.opening(number: 1)
        let locked: Plan = Self.rejection("That level is not open yet.")
        #expect(Self.refused(&core, "level.select", [2], code: "r02-g15.locked") == locked)
        #expect(Self.refused(&core, "level.next", [], code: "r02-g15.locked") == locked)
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g15.date")
                == Self.rejection("That date cannot be used."))
        let idle: Plan = Self.rejection("That hinge cannot turn: nothing would move.")
        #expect(Self.refused(&core, "hinge.turn", [0, 1], code: "r02-g15.action") == idle)
        #expect(Self.refused(&core, "hinge.turn", [2, 1], code: "r02-g15.action") == idle)
        #expect(Self.refused(&core, "hinge.turn", [1, 0], code: "r02-g15.action") == idle)
        #expect(Self.refused(&core, "hinge.turn", [7, 1], code: "r02-g15.action") == idle)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g15.action") == idle)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g15.action") == idle)
        #expect(Self.refused(&core, "hinge.turn", [0.5, 1], code: "r02-g15.not-whole")
                == Self.rejection("That value must be a whole number."))
        let noHinge: Plan = Self.rejection("This chain has no such hinge.")
        #expect(Self.refused(&core, "hinge.choose", [0], code: "r02-g15.hinge") == noHinge)
        #expect(Self.refused(&core, "hinge.choose", [6], code: "r02-g15.hinge") == noHinge)
        // `stage` is provoked in the win and budget tests; the other codes cannot arise through the core.
        let codes: [String] = ["r02-g15.locked", "r02-g15.date", "r02-g15.action", "r02-g15.stage", "r02-g15.not-whole",
                               "r02-g15.hinge", "r02-g15.stale", "r02-g15.level", "r02-g15.malformed",
                               "r02-g15.newer-schema", "action.out-of-range", ""]
        let refusedText: String = "That action was refused."
        let texts: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That hinge cannot turn: nothing would move.", "The level has ended.",
                               "That value must be a whole number.", "This chain has no such hinge.",
                               refusedText, refusedText, refusedText, refusedText, refusedText, refusedText]
        #expect(codes.count == texts.count)
        for index in codes.indices {
            #expect(Plan.refusalText(code: codes[index]) == texts[index], "\(codes[index])")
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == texts[index], "\(codes[index])")
            #expect(Plan.refused(code: codes[index]) == Self.rejection(texts[index]))
            #expect(Plan.refused(code: "action.rule." + codes[index]) == Self.rejection(texts[index]))
        }
        // A code that only contains a known code is not that code; another game's code is not this game's.
        #expect(Plan.refusalText(code: "x.r02-g15.locked") == refusedText)
        #expect(Plan.refusalText(code: "r02-g14.locked") == refusedText)
    }

    /// The first turn (with an optional clear turn before it) on levels 1 … 10 that fails with `code`, searched in
    /// order: the level number, the clear turn (or nil) and the failing turn.
    static func search(code: String) throws -> (Int, VoxelOrigamiAction?, VoxelOrigamiAction)? {
        for number in 1...10 {
            let level: VoxelOrigamiLevel = try Core.generated(number: number).level
            let start: [Int] = try Core.opening(number: number).play.turns
            var prefixes: [VoxelOrigamiAction?] = [nil]
            for hinge in 1..<level.cubes.count {
                for step in [1, -1] { prefixes.append(.turn(hinge, step)) }
            }
            for prefix in prefixes {
                var turns: [Int] = start
                if case let .turn(hinge, step)? = prefix {
                    guard level.canTurn(hinge, turns: turns),
                          VoxelOrigamiLattice.check(level.cubes, turns: turns, hinge: hinge, step: step) == nil
                    else { continue }
                    turns = VoxelOrigamiLattice.turned(turns, hinge: hinge, step: step)
                    if level.report(turns: turns).matched { continue }
                }
                for hinge in 1..<level.cubes.count where level.canTurn(hinge, turns: turns) {
                    for step in [1, -1] {
                        let failure: VoxelOrigamiFailure? = VoxelOrigamiLattice.check(level.cubes, turns: turns,
                                                                                      hinge: hinge, step: step)
                        if failure?.code == code { return (number, prefix, .turn(hinge, step)) }
                    }
                }
            }
        }
        return nil
    }

    @Test func aCollisionAndASweepPlanOnlyTheOutcome() throws {
        // The search finds each failure; the pinned scripts below are the ones it finds first.
        let collision: (Int, VoxelOrigamiAction?, VoxelOrigamiAction)? = try Self.search(code: "collision")
        #expect(collision?.0 == 2 && collision?.1 == .turn(3, 1) && collision?.2 == .turn(3, 1))
        let sweep: (Int, VoxelOrigamiAction?, VoxelOrigamiAction)? = try Self.search(code: "sweep")
        #expect(sweep?.0 == 3 && sweep?.1 == .turn(3, -1) && sweep?.2 == .turn(1, 1))

        var five: Core = try Core.opening(number: 5)
        let collided: Plan = Self.failed("Action 1 (a turn of hinge 2 by +1) would put cube 3 on cube 4 at (0, 1, -1). "
                                         + Self.advice)
        #expect(Self.turn(&five, 2, 1) == collided)
        #expect(five.play.stage == .failed && five.play.failure?.code == "collision")
        #expect(Self.refused(&five, "hinge.turn", [1, 1], code: "r02-g15.stage")
                == Self.rejection("The level has ended."))
        // Undo returns the failed play to playing (the state plan); a redo that fails again plans only the outcome.
        #expect(Self.accepted(&five, "play.undo") == Self.state("Undone. 5 of 6 cubes in place, 9 actions left."))
        #expect(Self.accepted(&five, "play.redo") == collided)
        #expect(Self.accepted(&five, "play.undo") == Self.state("Undone. 5 of 6 cubes in place, 9 actions left."))

        var two: Core = try Core.opening(number: 2)
        #expect(Self.turn(&two, 3, 1)
                == Self.state("Turned hinge 3 forward a quarter turn. 3 of 5 cubes in place, 9 actions left."))
        #expect(Self.turn(&two, 3, 1)
                == Self.failed("Action 2 (a turn of hinge 3 by +1) would put cube 4 on cube 2 at (0, 1, -1). "
                               + Self.advice))

        var three: Core = try Core.opening(number: 3)
        #expect(Self.turn(&three, 3, -1).kind == .state)
        #expect(Self.turn(&three, 1, 1)
                == Self.failed("Action 2 (a turn of hinge 1 by +1) would swing cube 5 through cube 0 at (0, 0, 0). "
                               + Self.advice))
        #expect(three.play.failure?.code == "sweep")

        var swept: Core = try Core.opening(number: 5)
        #expect(Self.turn(&swept, 1, 1)
                == Self.state("Turned hinge 1 forward a quarter turn. 5 of 6 cubes in place, 8 actions left."))
        #expect(Self.turn(&swept, 2, 1)
                == Self.failed("Action 2 (a turn of hinge 2 by +1) would swing cube 3 through cube 5 at (1, 1, -1). "
                               + Self.advice))
    }

    @Test func aBudgetEndingTurnPlansOnlyTheWarning() throws {
        var core: Core = try Core.opening(number: 4)
        #expect(core.play.level.budget == 8 && core.tutorial == .done)
        for index in 0..<7 {
            let step: Int = index % 2 == 0 ? 1 : -1
            let left: Int = 7 - index
            let noun: String = left == 1 ? "action" : "actions"
            let words: String = index % 2 == 0 ? "Turned hinge 1 forward a quarter turn. 5 of 6"
                : "Turned hinge 1 back a quarter turn. 4 of 6"
            #expect(Self.turn(&core, 1, step) == Self.state(words + " cubes in place, \(left) \(noun) left."))
        }
        let failure: Plan = Self.failed("Action 8 (a turn of hinge 1 by \u{2212}1) spent the last action without a "
                                        + "match. " + Self.advice)
        #expect(Self.turn(&core, 1, -1) == failure)
        #expect(core.play.stage == .failed && core.play.actionsLeft == 0)
        let undone: Plan = Self.state("Undone. 5 of 6 cubes in place, 1 action left.")
        #expect(Self.accepted(&core, "play.undo") == undone)
        #expect(Self.accepted(&core, "play.redo") == failure)
        #expect(Self.accepted(&core, "play.undo") == undone)
    }

    @Test func levelAndModeChanges() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(core.levelNumber == 1 && core.tutorial == .turn)
        // A turn on a tutorial level: the tutorial moves on, the plan is the turn's.
        #expect(Self.turn(&core, 1, 1).kind == .state)
        #expect(core.tutorial != .turn)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.turnStep))
        // The dismissal plans nothing.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.turnStep))
        // The same untouched play reopened with its tutorial shown again.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.turnStep))
        // Reopening the untouched play with the tutorial still shown changes nothing.
        #expect(Self.accepted(&core, "mode.campaign") == Plan.none)
        // A turned play reselected: a fresh play, the level plan.
        #expect(Self.turn(&core, 1, 1).kind == .state)
        #expect(Self.accepted(&core, "level.select", [1])
                == Self.level("Level 1, band 1, campaign. " + Self.turnStep))
        // The daily level 1 (2026-01-01): the same play in another mode.
        #expect(Self.accepted(&core, "mode.daily", [2026, 1, 1])
                == Self.level("Level 1, band 1, daily. " + Self.turnStep))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 24]) == Self.level("Level 38, band 2, daily."))
        // Level 38 is not open in the campaign: back to the frontier, level 1.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.turnStep))
        // Win level 1 along its witness and move on: level 2 carries the tutorial too.
        let witness: [VoxelOrigamiAction] = try Self.witness(1)
        #expect(witness == [.turn(4, -1), .turn(4, -1)])
        #expect(Self.turn(&core, 4, -1)
                == Self.state("Turned hinge 4 back a quarter turn. 5 of 6 cubes in place, 8 actions left."))
        #expect(Self.turn(&core, 4, -1)
                == Self.won("The chain matches the target. Level won spending 2 actions, 3 of 3 stars."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.turnStep))
    }

    @Test func choosingAHingePlansNothing() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.chosenHinge == 1)
        let old: Core = core
        #expect(Self.accepted(&core, "hinge.choose", [3]) == Plan.none)
        #expect(core.chosenHinge == 3 && core == old)
        #expect(Self.accepted(&core, "hinge.choose", [6]) == Plan.none)
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Plan.summaryText(core: core, hinge: 1) != Plan.summaryText(core: core, hinge: 3))
        #expect(Plan.none == Plan(text: nil, kind: nil, haptic: nil))
    }

    @Test func aRevealedHintAndTheSummary() async throws {
        #expect(Plan.hint(text: "Turn hinge 1 back (\u{2212}1)")
                == Plan(text: "Turn hinge 1 back (\u{2212}1)", kind: .state, haptic: nil))
        let core: Core = try await Core.prepare(seed: Self.seed)
        let head: String = "15 actions left. 4 of 8 cubes in place; the shape does not match yet. Chosen: "
        #expect(Plan.summaryText(core: core, hinge: 1)
                == head + "hinge 1, turned 0 degrees, can turn, swings cube 7. " + Self.level47)
        #expect(Plan.summaryText(core: core, hinge: 3)
                == head + "hinge 3, turned 180 degrees, can turn, swings cube 6. " + Self.level47)
        #expect(Plan.summaryText(core: core, hinge: 6)
                == head + "hinge 6, turned 270 degrees, nothing would move. " + Self.level47)
        // The root has no hinge; a hinge the level lacks reads "hinge i".
        #expect(Plan.summaryText(core: core, hinge: 0) == head + "hinge 0. " + Self.level47)
        #expect(Plan.summaryText(core: core, hinge: 9) == head + "hinge 9. " + Self.level47)
        // The won play: the shape matches.
        var won: Core = try await Core.prepare(seed: Self.seed)
        for action in try Self.witness(47) { _ = Self.act(&won, action) }
        #expect(Plan.summaryText(core: won, hinge: 5)
                .hasPrefix("11 actions left. 8 of 8 cubes in place; the shape matches the target. Chosen: hinge 5, "))
        // 1 action left, and a level with another orientation group.
        var low: Core = try Core.opening(number: 4)
        for index in 0..<7 { Self.apply(&low, "hinge.turn", [1, index % 2 == 0 ? 1 : -1]) }
        #expect(Plan.summaryText(core: low, hinge: 1)
                .hasPrefix("1 action left. 5 of 6 cubes in place; the shape does not match yet. Chosen: hinge 1, "))
        let one: Core = try Core.opening(number: 1)
        #expect(Plan.summaryText(core: one, hinge: 4)
                == "9 actions left. 5 of 6 cubes in place; the shape does not match yet. Chosen: hinge 4, turned 90 "
                + "degrees, can turn, swings cube 5. Level: level 1, band 1, campaign; 6 cubes, 5 hinges; the target "
                + "in any upright turn; a budget of 9 actions.")
    }
}
