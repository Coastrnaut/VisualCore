// NocturneGardenFeedbackPlanTests — feature 386 (R02-G09-06) T-R02G0906-003 (FR-R02G0906-001, 002, 003, 005;
// SC-R02G0906-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `NocturneGardenFeedbackPlan` on
// real certified cores: plants, a move, undo and redo with a campaign win of 2 stars after a detour (the winning plant
// plans only the outcome), a 3-star campaign win and a practice win without stars, a resize, a removal and a sun change
// with undo and redo, every refusal code (raw, prefixed and as the core reports it), a leak failure by a plant (a
// failing plant and a failing redo plan only the outcome) and by a move, a budget failure on the last move (the moves
// left down to the singular), `level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` with and
// without the tutorial, the dismissal, a revealed hint, the summary element and no plan for an unchanged core.
// Level 1 (band 1, tutorial `plant`): a 16 × 12 bed, target 84 cells, forbidden 29 cells, supply 1 tulip and 1 star,
// size 2 only, sun 2 (2 or 3), budget 9, needs 4/5 with a leak of at most 2, certified smallest 2 (a tulip at column
// 4, row 0 and a star at column 11, row 0, both size 2; the target is their exact shadow under sun 2). The tulip alone
// matches 48/84 without leaking; moved to row 1 it matches 42/88 with a leak of 1; moved to column 5 it leaks 5; a
// tulip at column 1, row 0 leaks 3. Level 21 (band 2, no tutorial): a 20 × 14 bed, target 38 cells, sizes 1 and 2,
// sun 3 (2 or 3), budget 11, needs 17/20 with a leak of at most 2; a bell at column 13, row 8 matches 5/43 at size 1
// and 6/44 at size 2, leaking 2 each time. Seed 2_386 opens level 87 (band 5, no tutorial). The daily level of
// 2026-11-22 is level 76. The expected texts are written out here, not built with the plan's helpers.
// Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import NocturneGardenCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct NocturneGardenFeedbackPlanTests {
    typealias Core = NocturneGardenExperienceCore
    typealias Plan = NocturneGardenFeedbackPlan

    /// The seed of these tests: level 2_386 % 100 + 1 = 87.
    static let seed: UInt64 = 2_386

    /// The tutorial's first instruction (feature 385).
    static let plantStep: String = "Tap a cell of the mist to plant a bloom there (or use the panel); its black shadow "
        + "falls on the mist — a hint shows where"

    /// The shared advice that ends every failure explanation (feature 385).
    static let advice: String = "Undo the last move or retry the level."

    /// Level 1 in words.
    static let target1: String = "target 84 cells; forbidden 29 cells; needs a match of 4/5 with a leak of at most 2 "
        + "cells; 9 moves; 2 blooms: 1 tulip, 1 star; sun 2 of 4, upper middle, shadows as tall as the blooms"

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

    /// An `outcome` plan of a win, haptic `success`.
    static func won(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .success) }

    /// An `outcome` plan of a failure, haptic `warning`.
    static func failed(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .warning) }

    @Test func plantMoveUndoRedoAndACampaignWinWithTwoStars() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(core.levelNumber == 1 && core.mode == .campaign && core.tutorial == .plant)
        #expect(core.play.level.budget == 9 && core.certifiedSmallest == 2)
        #expect(Self.accepted(&core, "bloom.plant", [0, 4, 0, 2]) == Self.state("Planted bloom 1: tulip at column 4, "
            + "row 0, size 2. Match 48/84, needs 4/5; leak 0 cells, 2 allowed. 8 moves left."))
        #expect(Self.accepted(&core, "bloom.move", [0, 4, 1]) == Self.state("Moved bloom 1 to column 4, row 1. "
            + "Match 42/88, needs 4/5; leak 1 cell, 2 allowed. 7 moves left."))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. Match 48/84, needs 4/5; leak 0 cells, 2 allowed. 8 moves left."))
        #expect(Self.accepted(&core, "play.redo")
            == Self.state("Redone. Match 42/88, needs 4/5; leak 1 cell, 2 allowed. 7 moves left."))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. Match 48/84, needs 4/5; leak 0 cells, 2 allowed. 8 moves left."))
        // The winning plant plans only the outcome: 3 moves made (the undone move included) against the certified 2.
        let win: Plan = Self.accepted(&core, "bloom.plant", [2, 11, 0, 2])
        #expect(win == Self.won("The shadow matches the target. Level won with 3 moves made, 2 of 3 stars."))
        #expect(win.kind == .outcome && core.play.stage == .won)
        #expect(Self.refused(&core, "bloom.plant", [2, 8, 0, 2], code: "r02-g09.stage")
            == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g09.stage") == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.plantStep))
    }

    @Test func aThreeStarCampaignWinAndAPracticeWinWithoutStars() throws {
        var core: Core = try Core.opening(number: 1)
        _ = Self.accepted(&core, "bloom.plant", [0, 4, 0, 2])
        #expect(Self.accepted(&core, "bloom.plant", [2, 11, 0, 2])
            == Self.won("The shadow matches the target. Level won with 2 moves made, 3 of 3 stars."))
        // Practice: the budget raised to 40, no stars.
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.plantStep))
        #expect(Self.accepted(&core, "bloom.plant", [0, 4, 0, 2]) == Self.state("Planted bloom 1: tulip at column 4, "
            + "row 0, size 2. Match 48/84, needs 4/5; leak 0 cells, 2 allowed. 39 moves left."))
        #expect(Self.accepted(&core, "bloom.plant", [2, 11, 0, 2])
            == Self.won("The shadow matches the target. Level won with 2 moves made."))
        #expect(core.play.stage == .won)
    }

    @Test func resizeRemoveAndSunWithUndoAndRedo() throws {
        var core: Core = try Core.opening(number: 21)
        #expect(core.tutorial == .done && core.play.level.budget == 11 && core.play.elevation == 3)
        #expect(Self.accepted(&core, "bloom.plant", [1, 13, 8, 1]) == Self.state("Planted bloom 1: bell at column 13, "
            + "row 8, size 1. Match 5/43, needs 17/20; leak 2 cells, 2 allowed. 10 moves left."))
        #expect(Self.accepted(&core, "bloom.resize", [0, 2])
            == Self.state("Bloom 1 is now size 2. Match 6/44, needs 17/20; leak 2 cells, 2 allowed. 9 moves left."))
        #expect(Self.accepted(&core, "bloom.remove", [0])
            == Self.state("Removed bloom 1. Match 0/38, needs 17/20; leak 0 cells, 2 allowed. 8 moves left."))
        #expect(Self.accepted(&core, "sun.set", [2])
            == Self.state("Sun 2 of 4. Match 0/38, needs 17/20; leak 0 cells, 2 allowed. 7 moves left."))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. Match 0/38, needs 17/20; leak 0 cells, 2 allowed. 8 moves left."))
        #expect(Self.accepted(&core, "play.redo")
            == Self.state("Redone. Match 0/38, needs 17/20; leak 0 cells, 2 allowed. 7 moves left."))
        // Blooms are numbered in the canonical order after the change (row, then column): a star planted at row 2 is
        // bloom 1 before the bell at row 8, and moved to row 9 it becomes bloom 2.
        #expect(Self.accepted(&core, "bloom.plant", [1, 13, 8, 1]) == Self.state("Planted bloom 1: bell at column 13, "
            + "row 8, size 1. Match 7/39, needs 17/20; leak 1 cell, 2 allowed. 6 moves left."))
        #expect(Self.accepted(&core, "bloom.plant", [2, 13, 2, 1]) == Self.state("Planted bloom 1: star at column 13, "
            + "row 2, size 1. Match 11/45, needs 17/20; leak 1 cell, 2 allowed. 5 moves left."))
        #expect(core.play.level.bloomName(1, bloom: core.play.blooms[1]) == "bloom 2: bell at column 13, row 8, size 1")
        #expect(Self.accepted(&core, "bloom.move", [0, 5, 9])
            == Self.state("Moved bloom 2 to column 5, row 9. Match 7/48, needs 17/20; leak 1 cell, 2 allowed. "
                + "4 moves left."))
    }

    @Test func everyRefusalCodeHasItsWords() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.refused(&core, "bloom.plant", [0, 4.5, 0, 2], code: "r02-g09.not-whole")
            == Self.rejection("That value must be a whole number."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g09.action")
            == Self.rejection("That move is not possible here."))
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g09.action")
            == Self.rejection("That move is not possible here."))
        #expect(Self.refused(&core, "bloom.plant", [0, 20, 0, 2], code: "r02-g09.action")
            == Self.rejection("That move is not possible here."))
        #expect(Self.refused(&core, "bloom.plant", [0, 4, 0, 1], code: "r02-g09.action")
            == Self.rejection("That move is not possible here."))
        #expect(Self.refused(&core, "bloom.remove", [0], code: "r02-g09.action")
            == Self.rejection("That move is not possible here."))
        #expect(Self.refused(&core, "sun.set", [2], code: "r02-g09.noop") == Self.rejection("That changes nothing."))
        #expect(Self.refused(&core, "level.select", [2], code: "r02-g09.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g09.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2027, 2, 29], code: "r02-g09.date")
            == Self.rejection("That date cannot be used."))
        _ = Self.accepted(&core, "bloom.plant", [0, 4, 0, 2])
        #expect(Self.refused(&core, "bloom.plant", [0, 8, 0, 2], code: "r02-g09.supply")
            == Self.rejection("No bloom of that kind is left."))
        #expect(Self.refused(&core, "bloom.move", [0, 4, 0], code: "r02-g09.noop")
            == Self.rejection("That changes nothing."))
        // The words alone, raw and prefixed, and the codes without words of their own.
        let codes: [String] = ["r02-g09.locked", "r02-g09.date", "r02-g09.action", "r02-g09.supply", "r02-g09.noop",
                               "r02-g09.stage", "r02-g09.not-whole", "r02-g09.stale", "r02-g09.malformed",
                               "r02-g09.level", "action.out-of-range", "action.unknown-control", ""]
        let words: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That move is not possible here.", "No bloom of that kind is left.",
                               "That changes nothing.", "The level has ended.", "That value must be a whole number.",
                               "That move was refused.", "That move was refused.", "That move was refused.",
                               "That move was refused.", "That move was refused.", "That move was refused."]
        for index in codes.indices {
            #expect(Plan.refusalText(code: codes[index]) == words[index], "\(codes[index])")
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == words[index], "\(codes[index])")
            #expect(Plan.refused(code: codes[index]) == Self.rejection(words[index]), "\(codes[index])")
        }
    }

    @Test func aLeakFailurePlansOnlyTheOutcome() throws {
        var core: Core = try Core.opening(number: 1)
        let plantLeak: String = "The shadow leaked into 3 cells of the forbidden regions at move 1 (planting bloom 1: "
            + "tulip at column 1, row 0, size 2), 2 allowed. " + Self.advice
        #expect(Self.accepted(&core, "bloom.plant", [0, 1, 0, 2]) == Self.failed(plantLeak))
        #expect(core.play.stage == .failed)
        #expect(Self.refused(&core, "bloom.plant", [2, 11, 0, 2], code: "r02-g09.stage")
            == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 9 moves left."))
        #expect(core.play.stage == .playing)
        // A redo that fails the play again plans only the outcome.
        #expect(Self.accepted(&core, "play.redo") == Self.failed(plantLeak))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 9 moves left."))
        // A move that leaks plans only the outcome too.
        _ = Self.accepted(&core, "bloom.plant", [0, 4, 0, 2])
        let moveLeak: String = "The shadow leaked into 5 cells of the forbidden regions at move 2 (moving bloom 1: "
            + "tulip at column 5, row 0, size 2), 2 allowed. " + Self.advice
        #expect(Self.accepted(&core, "bloom.move", [0, 5, 0]) == Self.failed(moveLeak))
        #expect(core.play.failure == .leak(1))
    }

    @Test func theLastMoveOfTheBudgetPlansOnlyTheOutcome() throws {
        var core: Core = try Core.opening(number: 1)
        let suns: [Double] = [3, 2, 3, 2, 3, 2, 3, 2]
        let texts: [String] = ["Sun 3 of 4. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 8 moves left.",
                               "Sun 2 of 4. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 7 moves left.",
                               "Sun 3 of 4. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 6 moves left.",
                               "Sun 2 of 4. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 5 moves left.",
                               "Sun 3 of 4. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 4 moves left.",
                               "Sun 2 of 4. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 3 moves left.",
                               "Sun 3 of 4. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 2 moves left.",
                               "Sun 2 of 4. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 1 move left."]
        for index in suns.indices {
            #expect(Self.accepted(&core, "sun.set", [suns[index]]) == Self.state(texts[index]), "sun \(index)")
        }
        let budget: String = "The moves ran out: 9 of 9 spent with a match of 0/84; it needs 4/5. " + Self.advice
        #expect(Self.accepted(&core, "sun.set", [3]) == Self.failed(budget))
        #expect(core.play.stage == .failed && core.play.failure == .budget)
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. Match 0/84, needs 4/5; leak 0 cells, 2 allowed. 1 move left."))
    }

    @Test func levelAndModeChangesAndTheTutorial() async throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        // The same untouched level reopened shows the tutorial again.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.plantStep))
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.plantStep))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 22]) == Self.level("Level 76, band 4, daily."))
        #expect(Self.accepted(&core, "level.select", [1]) == Self.level("Level 1, band 1, campaign. " + Self.plantStep))
        // A plant moves the tutorial on but announces only the plant.
        #expect(Self.accepted(&core, "bloom.plant", [0, 4, 0, 2]) == Self.state("Planted bloom 1: tulip at column 4, "
            + "row 0, size 2. Match 48/84, needs 4/5; leak 0 cells, 2 allowed. 8 moves left."))
        #expect(core.tutorial == .shape)
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        // Level 87: no tutorial; an untouched campaign reopened plans nothing; a played level reopened is a level plan.
        var other: Core = try await Core.prepare(seed: Self.seed)
        #expect(other.levelNumber == 87 && other.tutorial == .done)
        #expect(Plan.after(old: other, new: other) == Plan.none)
        #expect(Self.accepted(&other, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&other, "mode.campaign") == Plan.none)
        #expect(Self.accepted(&other, "mode.practice") == Self.level("Level 87, band 5, practice."))
        #expect(Self.accepted(&other, "mode.campaign") == Self.level("Level 87, band 5, campaign."))
        let elevation: Int = other.play.level.elevations.sorted().first { $0 != other.play.elevation } ?? 1
        let sun: Plan = Self.accepted(&other, "sun.set", [Double(elevation)])
        #expect(sun.kind == .state && sun.text?.hasPrefix("Sun \(elevation) of 4. Match 0/") == true)
        #expect(Self.accepted(&other, "level.select", [87]) == Self.level("Level 87, band 5, campaign."))
        #expect(other.play.records.isEmpty)
    }

    @Test func theSummaryAndARevealedHint() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Plan.summaryText(core: core) == "9 moves left. Match 0/84, needs 4/5; leak 0 cells, 2 allowed; "
            + "sun 2 of 4. Blooms: none. Target: " + Self.target1 + ".")
        // A picker change or a drag preview is presentation only: the core is unchanged and nothing is planned.
        #expect(Plan.after(old: core, new: core) == Plan.none)
        _ = Self.accepted(&core, "bloom.plant", [0, 4, 0, 2])
        #expect(Plan.summaryText(core: core) == "8 moves left. Match 48/84, needs 4/5; leak 0 cells, 2 allowed; "
            + "sun 2 of 4. Blooms: bloom 1: tulip at column 4, row 0, size 2. Target: " + Self.target1 + ".")
        // A revealed hint is a state announcement with its words and no haptic.
        #expect(Plan.hint(text: "Plant a star") == Plan(text: "Plant a star", kind: .state, haptic: nil))
        let hint: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: 1, play: core.play))
        let plan: Plan = Plan.hint(text: hint.text)
        #expect(plan.text == hint.text && plan.kind == .state && plan.haptic == nil)
    }

    /// Feature 387 (clarification Q4): the replay refusals in words (raw and prefixed codes), the replay mode's name,
    /// and a replayed win that claims no stars; a replay step is announced like the move it plays.
    @Test func replayWordsAndAReplayedWin() throws {
        let words: [(code: String, text: String)] = [
            (code: "r02-g09.no-replay", text: "There is no saved solution to replay for this level."),
            (code: "r02-g09.replay-end", text: "The replay is over."),
            (code: "r02-g09.replay", text: "Stop the replay first."),
        ]
        for entry in words {
            #expect(Plan.refusalText(code: entry.code) == entry.text)
            #expect(Plan.refusalText(code: "action.rule." + entry.code) == entry.text)
            let plan: Plan = Plan.refused(code: entry.code)
            #expect(plan.kind == .rejection && plan.haptic == .error && plan.text == entry.text)
        }
        #expect(Plan.modeName(.replay(level: 4)) == "replay")
        let actions: [NocturneGardenAction] = try Core.generated(number: 1).solution.actions
        var core: Core = try Core.opening(number: 1)
        for action in actions { #expect(core.apply(Self.replayAct(action)) == .accepted) }
        #expect(core.apply(ExperienceAction(control: "replay.start", values: [1], step: 0)) == .accepted)
        var last: Plan = .none
        for _ in actions {
            let before: Core = core
            #expect(core.apply(ExperienceAction(control: "replay.step", values: [], step: 0)) == .accepted)
            last = Plan.after(old: before, new: core)
        }
        let text: String = try #require(last.text)
        #expect(last.kind == .outcome && last.haptic == .success)
        #expect(text.hasPrefix("The shadow matches the target.") && !text.contains("stars"), "\(text)")
    }

    /// The experience action that issues kernel move `action`.
    static func replayAct(_ action: NocturneGardenAction) -> ExperienceAction {
        switch action {
        case let .plant(kind, column, row, size):
            ExperienceAction(control: "bloom.plant", values: [Double(kind.order), Double(column), Double(row),
                                                              Double(size)], step: 0)
        case let .move(bloom, column, row):
            ExperienceAction(control: "bloom.move", values: [Double(bloom), Double(column), Double(row)], step: 0)
        case let .resize(bloom, size):
            ExperienceAction(control: "bloom.resize", values: [Double(bloom), Double(size)], step: 0)
        case let .remove(bloom):
            ExperienceAction(control: "bloom.remove", values: [Double(bloom)], step: 0)
        case let .sun(elevation):
            ExperienceAction(control: "sun.set", values: [Double(elevation)], step: 0)
        default:
            ExperienceAction(control: "play.undo", values: [], step: 0)
        }
    }
}
