// MoonlitMechanismFeedbackPlanTests — feature 436 (R02-G14-06) T-R02G1406-003 (FR-R02G1406-001, 002, 003, 005;
// SC-R02G1406-001, 002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of
// `MoonlitMechanismFeedbackPlan` on real certified cores driven through `MoonlitMechanismExperienceCore.apply`: turns,
// re-seats, lamp steps, an undo and a redo, then a 3-star campaign win (the winning run plans only the outcome) and the
// `stage` refusals after it; a gear drag's turns planned once (forward and back, one tooth and several, a drag that
// spends the budget, a mixed run of records); a 2-star campaign win with a detour, a practice win without stars and a
// daily win; every refusal code (provoked where the core can produce it, every code by table, bare and with the
// engine's `action.rule.` prefix); failures by each run outcome (jammed, forbidden, missing, stray; an undo and a redo
// that fails again plan the outcome only) and by the budget (the budget-ending lamp step plans only the warning); level
// and mode changes with and without the tutorial; choosing a gear and showing a key frame plan nothing; a revealed
// hint; the summary element.
// Seed 2_436 opens level 37 (band 2, no tutorial): gears of 15, 12 and 20 teeth at phases 14, 1, 7 (gear 2 one tooth
// off); 3 lamp heights, height 2; 2 required key frames of 23 and 24 target cells, 16 covered; 5 forbidden cells,
// allowance 0, budget 11; certified witness turn −1, re-seat gear 2 by −1, lamp −1 and the run (4 actions). Seed 0
// opens level 1 (tutorial): gears of 9 and 12 teeth at phases 4, 8; height 2 of 3; required frames of 9 and 5 cells,
// none covered; budget 9; a turn +1 shadows forbidden cell 114 in key frame 0. Seed 4 opens level 5: turn +1, re-seat
// gear 1 by +1 and turn +1 cast 3 stray cells. Seed 47 opens level 48: three turns −1, re-seat gear 1 by +1 and gear 3
// by −1 twice cast 1 stray cell. The daily level of 2026-11-24 is level 20 (band 1), witness re-seat gear 1 by +1 twice
// and the run. The expected texts are written out here, not built with the plan's helpers. Explicit types, plain loops,
// short runs.
import Foundation
import Testing
@testable import MoonlitMechanismCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct MoonlitMechanismFeedbackPlanTests {
    typealias Core = MoonlitMechanismExperienceCore
    typealias Plan = MoonlitMechanismFeedbackPlan

    /// The seed of the feature: level 37.
    static let seed: UInt64 = 2_436

    /// The tutorial's first instruction (feature 435).
    static let changeStep: String = "Drag a gear around (or use Turn \u{2212} and +) to turn the handle, or double-tap "
        + "a gear (or use Re-seat) to shift it by a tooth: watch its shadow move on the paper"

    /// The advice that ends every failure explanation (feature 435).
    static let advice: String = "Undo the last action or retry the level."

    /// Level 37's summary words of the level.
    static let level37: String = "Level: level 37, band 2, campaign; 3 gears, 2 key frames, 2 required; "
        + "3 lamp heights; 5 forbidden cells; a stray allowance of 0; a budget of 11 actions."

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

    /// Turns the handle by `step` and returns the plan.
    static func turn(_ core: inout Core, _ step: Int) -> Plan { accepted(&core, "handle.turn", [Double(step)]) }

    /// Re-seats `gear` by `step` and returns the plan.
    static func reseat(_ core: inout Core, _ gear: Int, _ step: Int) -> Plan {
        accepted(&core, "gear.reseat", [Double(gear), Double(step)])
    }

    /// Steps the lamp by `step` and returns the plan.
    static func lamp(_ core: inout Core, _ step: Int) -> Plan { accepted(&core, "lamp.step", [Double(step)]) }

    /// A gear drag: `count` turns by `step` applied one by one, planned once from the core before the first turn to the
    /// core after the last.
    static func drag(_ core: inout Core, _ step: Int, count: Int) -> Plan {
        let old: Core = core
        for _ in 0..<count { apply(&core, "handle.turn", [Double(step)]) }
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

    /// Applies the kernel `action` through the adapter, expects it accepted and returns the plan.
    static func act(_ core: inout Core, _ action: MoonlitMechanismAction) -> Plan {
        switch action {
        case let .turn(step): turn(&core, step)
        case let .reseat(gear, step): reseat(&core, gear, step)
        case let .lamp(step): lamp(&core, step)
        case .run: accepted(&core, "machine.run")
        }
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

    @Test func turnsReseatsLampStepsUndoRedoAndA3StarCampaignWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 37 && core.tutorial == .done && core.certifiedActions == 4)
        #expect(Self.turn(&core, -1)
                == Self.state("Turned the handle back one tooth. 14 of 47 required target cells covered, "
                              + "10 actions left."))
        #expect(Self.accepted(&core, "play.undo")
                == Self.state("Undone. 16 of 47 required target cells covered, 11 actions left."))
        #expect(Self.accepted(&core, "play.redo")
                == Self.state("Redone. 14 of 47 required target cells covered, 10 actions left."))
        #expect(Self.reseat(&core, 2, -1)
                == Self.state("Gear 2 re-seated to phase 5. 13 of 47 required target cells covered, 9 actions left."))
        #expect(Self.lamp(&core, -1)
                == Self.state("Lamp lowered to height 1 of 3. Every required key frame is covered, 8 actions left."))
        // The run always ends the level: it plans only the outcome. 4 actions against the certified 4 → 3 stars.
        #expect(Self.accepted(&core, "machine.run")
                == Self.won("The shadows match. Level won spending 4 actions, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        // A won play is final: the real `stage` refusals.
        #expect(Self.refused(&core, "handle.turn", [1], code: "r02-g14.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "machine.run", [], code: "r02-g14.stage") == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g14.stage") == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 38, band 2, campaign."))
    }

    @Test func reseatsAndLampStepsSayTheirChangeAndCoverageNeedsAlignment() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.lamp(&core, -1)
                == Self.state("Lamp lowered to height 1 of 3. 28 of 47 required target cells covered, "
                              + "10 actions left."))
        #expect(Self.lamp(&core, 1)
                == Self.state("Lamp raised to height 2 of 3. 16 of 47 required target cells covered, 9 actions left."))
        #expect(Self.reseat(&core, 1, 1)
                == Self.state("Gear 1 re-seated to phase 2. 16 of 47 required target cells covered, 8 actions left."))
        #expect(Self.reseat(&core, 1, -1)
                == Self.state("Gear 1 re-seated to phase 1. 16 of 47 required target cells covered, 7 actions left."))
        #expect(Self.turn(&core, 1)
                == Self.state("Turned the handle forward one tooth. 19 of 47 required target cells covered, "
                              + "6 actions left."))
        // Level 5: every required target cell covered with a jammed mesh is not "every key frame covered".
        var five: Core = try await Core.prepare(seed: 4)
        #expect(five.levelNumber == 5)
        #expect(Self.turn(&five, 1)
                == Self.state("Turned the handle forward one tooth. 7 of 7 required target cells covered, "
                              + "8 actions left."))
        #expect(Self.reseat(&five, 1, 1)
                == Self.state("Gear 1 re-seated to phase 5. Every required key frame is covered, 7 actions left."))
    }

    @Test func aGearDragIsPlannedOnceAfterItsLastTurn() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        // A drag of one turn reads like a single turn.
        #expect(Self.drag(&core, 1, count: 1)
                == Self.state("Turned the handle forward one tooth. 19 of 47 required target cells covered, "
                              + "10 actions left."))
        #expect(Self.accepted(&core, "play.undo").text?.hasPrefix("Undone. ") == true)
        // A drag of three turns back on level 48: one plan, one selection haptic.
        var drag: Core = try await Core.prepare(seed: 47)
        #expect(drag.levelNumber == 48)
        #expect(Self.drag(&drag, -1, count: 3)
                == Self.state("Turned the handle back 3 teeth. 64 of 80 required target cells covered, "
                              + "9 actions left."))
        #expect(drag.play.records.count == 3)
        // A mixed run of records (a turn and a lamp step together) is the progress alone.
        let old: Core = core
        Self.apply(&core, "handle.turn", [1])
        Self.apply(&core, "lamp.step", [-1])
        let mixed: Plan = Plan.after(old: old, new: core)
        #expect(mixed.kind == .state && mixed.haptic == .selection)
        #expect(mixed.text?.hasSuffix("required target cells covered, 9 actions left.") == true)
        #expect(mixed.text?.hasPrefix("Turned") == false && mixed.text?.hasPrefix("Lamp") == false)
        // A drag that spends the last of the budget plans only the warning.
        var budget: Core = try await Core.prepare(seed: 0)
        for _ in 0..<7 { Self.apply(&budget, "handle.turn", [1]) }
        #expect(Self.drag(&budget, 1, count: 2)
                == Self.failed("Action 9 (a turn of the handle by +1) spent the last action without a win. "
                               + Self.advice))
        #expect(budget.play.stage == .failed && budget.play.actionsLeft == 0)
    }

    @Test func a2StarCampaignWinAPracticeWinWithoutStarsAndADailyWin() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let witness: [MoonlitMechanismAction] = MoonlitMechanismSolver.actions(try Core.generated(number: 37).plan)
        #expect(Self.lamp(&core, -1).kind == .state)
        #expect(Self.lamp(&core, 1).kind == .state)
        var plans: [Plan] = []
        for action in witness { plans.append(Self.act(&core, action)) }
        // The detour still counts: 6 actions against the certified 4 → 2 stars.
        #expect(plans.last == Self.won("The shadows match. Level won spending 6 actions, 2 of 3 stars."))
        for index in 0..<(plans.count - 1) { #expect(plans[index].kind == .state && plans[index].haptic == .selection) }

        var practice: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 37, band 2, practice."))
        #expect(Self.turn(&practice, -1)
                == Self.state("Turned the handle back one tooth. 14 of 47 required target cells covered, "
                              + "39 actions left."))
        var last: Plan = .none
        for action in witness.dropFirst() { last = Self.act(&practice, action) }
        #expect(last == Self.won("The shadows match. Level won spending 4 actions."))

        var daily: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.accepted(&daily, "mode.daily", [2026, 11, 24]) == Self.level("Level 20, band 1, daily."))
        for action in MoonlitMechanismSolver.actions(try Core.generated(number: 20).plan) {
            last = Self.act(&daily, action)
        }
        #expect(last == Self.won("The shadows match. Level won spending 3 actions, 3 of 3 stars."))
    }

    @Test func everyRefusalCode() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(Self.refused(&core, "level.select", [2], code: "r02-g14.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g14.locked")
                == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2026, 2, 30], code: "r02-g14.date")
                == Self.rejection("That date cannot be used."))
        let notAllowed: Plan = Self.rejection("That change is not allowed for this machine.")
        #expect(Self.refused(&core, "handle.turn", [0], code: "r02-g14.action") == notAllowed)
        #expect(Self.refused(&core, "gear.reseat", [0, 1], code: "r02-g14.action") == notAllowed)
        #expect(Self.refused(&core, "gear.reseat", [2, 1], code: "r02-g14.action") == notAllowed)
        #expect(Self.refused(&core, "lamp.step", [1], code: "r02-g14.action") == notAllowed)
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g14.action") == notAllowed)
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g14.action") == notAllowed)
        #expect(Self.refused(&core, "handle.turn", [0.5], code: "r02-g14.not-whole")
                == Self.rejection("That value must be a whole number."))
        #expect(Self.refused(&core, "frame.show", [2], code: "r02-g14.frame")
                == Self.rejection("This level has no such key frame."))
        // `stage` is provoked in the win test; the other codes cannot arise through the core.
        let codes: [String] = ["r02-g14.locked", "r02-g14.date", "r02-g14.action", "r02-g14.stage", "r02-g14.not-whole",
                               "r02-g14.frame", "r02-g14.stale", "r02-g14.level", "r02-g14.malformed",
                               "r02-g14.newer-schema", "action.out-of-range", ""]
        let refusedText: String = "That action was refused."
        let texts: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That change is not allowed for this machine.", "The level has ended.",
                               "That value must be a whole number.", "This level has no such key frame.",
                               refusedText, refusedText, refusedText, refusedText, refusedText, refusedText]
        #expect(codes.count == texts.count)
        for index in codes.indices {
            #expect(Plan.refusalText(code: codes[index]) == texts[index], "\(codes[index])")
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == texts[index], "\(codes[index])")
            #expect(Plan.refused(code: codes[index]) == Self.rejection(texts[index]))
            #expect(Plan.refused(code: "action.rule." + codes[index]) == Self.rejection(texts[index]))
        }
        // A code that only contains a known code is not that code; another game's code is not this game's.
        #expect(Plan.refusalText(code: "x.r02-g14.locked") == refusedText)
        #expect(Plan.refusalText(code: "r02-g13.locked") == refusedText)
    }

    @Test func aJammedAndAMissingRunPlanOnlyTheOutcome() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let jammed: String = "Action 1 (the run): gear 2 jammed against its parent, gear 1. " + Self.advice
        #expect(Self.accepted(&core, "machine.run") == Self.failed(jammed))
        #expect(core.play.stage == .failed)
        #expect(Self.refused(&core, "handle.turn", [1], code: "r02-g14.stage")
                == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "play.undo")
                == Self.state("Undone. 16 of 47 required target cells covered, 11 actions left."))
        #expect(Self.accepted(&core, "play.redo") == Self.failed(jammed))

        var missing: Core = try await Core.prepare(seed: 0)
        #expect(Self.accepted(&missing, "machine.run")
                == Self.failed("Action 1 (the run): key frame 0 missed 9 target cells. " + Self.advice))
        #expect(Self.accepted(&missing, "play.undo")
                == Self.state("Undone. 0 of 14 required target cells covered, 9 actions left."))
    }

    @Test func aForbiddenAndAStrayRunPlanOnlyTheOutcome() async throws {
        var forbidden: Core = try await Core.prepare(seed: 0)
        #expect(Self.turn(&forbidden, 1)
                == Self.state("Turned the handle forward one tooth. 2 of 14 required target cells covered, "
                              + "8 actions left."))
        #expect(Self.accepted(&forbidden, "machine.run")
                == Self.failed("Action 2 (the run): key frame 0 cast a shadow on forbidden cell 114. " + Self.advice))

        var stray: Core = try await Core.prepare(seed: 4)
        #expect(Self.turn(&stray, 1).kind == .state)
        #expect(Self.reseat(&stray, 1, 1).kind == .state)
        #expect(Self.turn(&stray, 1)
                == Self.state("Turned the handle forward one tooth. Every required key frame is covered, "
                              + "6 actions left."))
        #expect(Self.accepted(&stray, "machine.run")
                == Self.failed("Action 4 (the run): key frame 0 cast 3 stray cells, more than the 0 allowed. "
                               + Self.advice))

        var one: Core = try await Core.prepare(seed: 47)
        #expect(Self.drag(&one, -1, count: 3).kind == .state)
        #expect(Self.reseat(&one, 1, 1)
                == Self.state("Gear 1 re-seated to phase 4. Every required key frame is covered, 8 actions left."))
        #expect(Self.reseat(&one, 3, -1)
                == Self.state("Gear 3 re-seated to phase 1. 71 of 80 required target cells covered, 7 actions left."))
        #expect(Self.reseat(&one, 3, -1)
                == Self.state("Gear 3 re-seated to phase 0. Every required key frame is covered, 6 actions left."))
        #expect(Self.accepted(&one, "machine.run")
                == Self.failed("Action 7 (the run): key frame 0 cast 1 stray cell, more than the 0 allowed. "
                               + Self.advice))
    }

    @Test func aBudgetEndingLampStepPlansOnlyTheWarning() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        for index in 0..<10 {
            let step: Int = index % 2 == 0 ? -1 : 1
            let left: Int = 10 - index
            let noun: String = left == 1 ? "action" : "actions"
            let words: String = index % 2 == 0
                ? "Lamp lowered to height 1 of 3. 28 of 47" : "Lamp raised to height 2 of 3. 16 of 47"
            let expected: Plan = Self.state(words + " required target cells covered, \(left) \(noun) left.")
            #expect(Self.lamp(&core, step) == expected)
        }
        let failure: String = "Action 11 (a lamp step by \u{2212}1) spent the last action without a win. " + Self.advice
        #expect(Self.lamp(&core, -1) == Self.failed(failure))
        #expect(core.play.stage == .failed && core.play.actionsLeft == 0)
        let undone: Plan = Self.state("Undone. 16 of 47 required target cells covered, 1 action left.")
        #expect(Self.accepted(&core, "play.undo") == undone)
        #expect(Self.accepted(&core, "play.redo") == Self.failed(failure))
        #expect(Self.accepted(&core, "play.undo") == undone)
        // The last action as a run: the jam is the outcome.
        #expect(Self.accepted(&core, "machine.run")
                == Self.failed("Action 11 (the run): gear 2 jammed against its parent, gear 1. " + Self.advice))
    }

    @Test func levelAndModeChanges() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.levelNumber == 1 && core.tutorial == .change)
        // A turn on a tutorial level: the tutorial moves on, the plan is the turn's.
        #expect(Self.turn(&core, 1).kind == .state)
        #expect(core.tutorial != .change)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.changeStep))
        // The dismissal and showing a key frame plan nothing.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&core, "frame.show", [1]) == Plan.none)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.changeStep))
        // The same untouched play reopened with its tutorial shown again.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.changeStep))
        // Reopening the untouched play with the tutorial still shown changes nothing.
        #expect(Self.accepted(&core, "mode.campaign") == Plan.none)
        // A turned play reselected: a fresh play, the level plan.
        #expect(Self.turn(&core, 1).kind == .state)
        #expect(Self.accepted(&core, "level.select", [1])
                == Self.level("Level 1, band 1, campaign. " + Self.changeStep))
        // The daily level 1 (2026-01-01): the same play in another mode.
        #expect(Self.accepted(&core, "mode.daily", [2026, 1, 1])
                == Self.level("Level 1, band 1, daily. " + Self.changeStep))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 24]) == Self.level("Level 20, band 1, daily."))
        // Level 20 is not open in the campaign: back to the frontier, level 1.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.changeStep))
        // Win level 1 and move on: level 2 carries the tutorial too.
        #expect(Self.turn(&core, 1).kind == .state)
        #expect(Self.lamp(&core, -1)
                == Self.state("Lamp lowered to height 1 of 3. Every required key frame is covered, 7 actions left."))
        #expect(Self.accepted(&core, "machine.run")
                == Self.won("The shadows match. Level won spending 3 actions, 3 of 3 stars."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.changeStep))
    }

    @Test func choosingAGearAndShowingAKeyFramePlanNothing() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        // Choosing a gear is presentation of the controls: the core does not change.
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Plan.summaryText(core: core, gear: 1) != Plan.summaryText(core: core, gear: 2))
        #expect(Plan.after(old: core, new: core) == Plan.none)
        // Showing a key frame changes only the presentation state the core holds.
        #expect(Self.accepted(&core, "frame.show", [1]) == Plan.none)
        #expect(core.shownFrame == 1)
        #expect(Self.accepted(&core, "frame.show", [0]) == Plan.none)
        #expect(Plan.none == Plan(text: nil, kind: nil, haptic: nil))
    }

    @Test func aRevealedHintAndTheSummary() async throws {
        #expect(Plan.hint(text: "Turn the handle back by one tooth")
                == Plan(text: "Turn the handle back by one tooth", kind: .state, haptic: nil))
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Plan.summaryText(core: core, gear: 1)
                == "11 actions left. 16 of 47 required target cells covered. Lamp height 2 of 3. Showing key frame 0. "
                + "Chosen: gear 1, 12 teeth, phase 1, aligned. " + Self.level37)
        #expect(Plan.summaryText(core: core, gear: 2)
                == "11 actions left. 16 of 47 required target cells covered. Lamp height 2 of 3. Showing key frame 0. "
                + "Chosen: gear 2, 20 teeth, phase 7, 1 tooth off. " + Self.level37)
        // The driver has no mesh; a gear the level lacks reads "gear i".
        #expect(Plan.summaryText(core: core, gear: 0)
                == "11 actions left. 16 of 47 required target cells covered. Lamp height 2 of 3. Showing key frame 0. "
                + "Chosen: gear 0, 15 teeth, phase 14. " + Self.level37)
        #expect(Plan.summaryText(core: core, gear: 7)
                == "11 actions left. 16 of 47 required target cells covered. Lamp height 2 of 3. Showing key frame 0. "
                + "Chosen: gear 7. " + Self.level37)
        // The shown key frame is read from the core.
        Self.apply(&core, "frame.show", [1])
        #expect(Plan.summaryText(core: core, gear: 1).contains(". Showing key frame 1. "))
        // The witness set-up before the run: every required key frame covered.
        var ready: Core = try await Core.prepare(seed: Self.seed)
        Self.apply(&ready, "handle.turn", [-1])
        Self.apply(&ready, "gear.reseat", [2, -1])
        Self.apply(&ready, "lamp.step", [-1])
        #expect(Plan.summaryText(core: ready, gear: 2)
                == "8 actions left. Every required key frame is covered. Lamp height 1 of 3. Showing key frame 0. "
                + "Chosen: gear 2, 20 teeth, phase 5, aligned. " + Self.level37)
        // 1 action left in a play one lamp step from the budget's end.
        var low: Core = try await Core.prepare(seed: Self.seed)
        for index in 0..<10 { Self.apply(&low, "lamp.step", [index % 2 == 0 ? -1 : 1]) }
        #expect(Plan.summaryText(core: low, gear: 1)
                .hasPrefix("1 action left. 16 of 47 required target cells covered. Lamp height 2 of 3. "))
        let one: Core = try await Core.prepare(seed: 0)
        #expect(Plan.summaryText(core: one, gear: 1)
                == "9 actions left. 0 of 14 required target cells covered. Lamp height 2 of 3. Showing key frame 0. "
                + "Chosen: gear 1, 12 teeth, phase 8, aligned. Level: level 1, band 1, campaign; 2 gears, 2 key "
                + "frames, 2 required; 3 lamp heights; 3 forbidden cells; a stray allowance of 0; a budget of 9 "
                + "actions.")
    }
}
