// FacetedForgeFeedbackPlanTests — feature 376 (R02-G08-06) T-R02G0806-003 (FR-R02G0806-001, 002, 003, 005;
// SC-R02G0806-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `FacetedForgeFeedbackPlan` on
// real certified cores: cuts, undo and redo, the certified solution of level 77 ending in a 3-star campaign win (the
// winning cut plans only the outcome), wins with 2 and 1 stars after detours and a practice win without stars, a sliver
// failure (a failing cut and a failing redo plan only the outcome) with its undo, a budget failure on the last cut (the
// cuts left down to the singular), every refusal code (raw, prefixed and as the core reports it, engine codes
// included), `level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` with and without the
// tutorial, the dismissal, the summary element (including a plane that misses its piece) and no plan for an unchanged
// core or a preview choice change.
// Seed 2_376 opens level 77 (band 4, no tutorial): budget 15, sliver limit 1/64, certified smallest 5 (solution: piece
// 1 x+y −2, piece 1 x+z −1, piece 1 x+y 2, piece 2 x+y+z −2, piece 4 x+y−z −4); the whole crystal is crossed at depths
// −5 … 5 in every direction and its first cut in direction x at depth −5 leaves a sliver of 1/432. Level 1 (band 1,
// tutorial `aim`): budget 9, target 4 pieces; halving the largest piece in direction x nine times runs the budget out.
// Level 2 (band 1, tutorial): budget 10, certified smallest 2 (piece 1 x −1, piece 1 x 1), target three thirds. The
// daily level of 2026-11-22 is level 76. The expected texts are written out here, not built with the plan's helpers.
// Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import FacetedForgeCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct FacetedForgeFeedbackPlanTests {
    typealias Core = FacetedForgeExperienceCore
    typealias Plan = FacetedForgeFeedbackPlan

    /// The seed of these tests: level 2_376 % 100 + 1 = 77.
    static let seed: UInt64 = 2_376

    /// The tutorial's first instruction (feature 375).
    static let aim: String = "Choose a piece and aim the ruby plane — drag its rim to tilt it, drag inside it to slide "
        + "it, or use the panel — then tap the plane (or Cut) to split the piece; a hint shows where"

    /// The shared advice that ends every failure explanation (feature 375).
    static let advice: String = "Undo the last cut or retry the level."

    /// Level 77's target in words.
    static let target77: String = "6 pieces: 8/27 of the crystal with 8 faces; 397/1728 of the crystal with 8 faces; "
        + "371/1728 of the crystal with 7 faces; 7/54 of the crystal with 8 faces; 2/27 of the crystal with 8 faces; "
        + "1/18 of the crystal with 5 faces"

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

    @Test func cutsUndoRedoAndACampaignWinWithThreeStars() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 77 && core.tutorial == .done && core.mode == .campaign)
        #expect(core.play.level.budget == 15 && core.certifiedSmallest == 5)
        #expect(Self.accepted(&core, "piece.cut", [0, 3, -2])
            == Self.state("Piece 1 cut in direction x+y at depth -2: 2 pieces now. 14 cuts left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 piece. 15 cuts left."))
        #expect(Self.accepted(&core, "play.redo") == Self.state("Redone. 2 pieces. 14 cuts left."))
        let cuts: [[Double]] = [[0, 5, -1], [0, 3, 2], [1, 9, -2]]
        let texts: [String] = ["Piece 1 cut in direction x+z at depth -1: 3 pieces now. 13 cuts left.",
                               "Piece 1 cut in direction x+y at depth 2: 4 pieces now. 12 cuts left.",
                               "Piece 2 cut in direction x+y+z at depth -2: 5 pieces now. 11 cuts left."]
        for index in cuts.indices {
            #expect(Self.accepted(&core, "piece.cut", cuts[index]) == Self.state(texts[index]), "cut \(index)")
        }
        // The winning cut plans only the outcome: 5 cuts made against the certified 5.
        #expect(Self.accepted(&core, "piece.cut", [3, 10, -4])
            == Self.won("The pieces match the target. Level won with 5 cuts made, 3 of 3 stars."))
        #expect(core.play.stage == .won)
        #expect(Self.refused(&core, "piece.cut", [0, 0, 0], code: "r02-g08.stage")
            == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g08.stage") == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 78, band 4, campaign."))
    }

    @Test func detoursCostStarsAndPracticeHasNone() throws {
        // Level 2 with one detour: 3 cuts made against the certified 2, 2 stars.
        var core: Core = try Core.opening(number: 2)
        #expect(core.certifiedSmallest == 2 && core.play.level.budget == 10)
        #expect(Self.accepted(&core, "piece.cut", [0, 0, -1])
            == Self.state("Piece 1 cut in direction x at depth -1: 2 pieces now. 9 cuts left."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 piece. 10 cuts left."))
        #expect(Self.accepted(&core, "piece.cut", [0, 0, -1])
            == Self.state("Piece 1 cut in direction x at depth -1: 2 pieces now. 9 cuts left."))
        #expect(Self.accepted(&core, "piece.cut", [0, 0, 1])
            == Self.won("The pieces match the target. Level won with 3 cuts made, 2 of 3 stars."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 3, band 1, campaign. " + Self.aim))
        // Level 2 again with three detours: 5 cuts made, 1 star.
        #expect(Self.accepted(&core, "level.select", [2]) == Self.level("Level 2, band 1, campaign. " + Self.aim))
        for _ in 0..<3 {
            #expect(Self.accepted(&core, "piece.cut", [0, 0, -1])
                == Self.state("Piece 1 cut in direction x at depth -1: 2 pieces now. 9 cuts left."))
            #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 piece. 10 cuts left."))
        }
        _ = Self.accepted(&core, "piece.cut", [0, 0, -1])
        #expect(Self.accepted(&core, "piece.cut", [0, 0, 1])
            == Self.won("The pieces match the target. Level won with 5 cuts made, 1 of 3 stars."))
        // Practice: the budget raised to 20, no stars.
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 2, band 1, practice. " + Self.aim))
        #expect(Self.accepted(&core, "piece.cut", [0, 0, -1])
            == Self.state("Piece 1 cut in direction x at depth -1: 2 pieces now. 19 cuts left."))
        #expect(Self.accepted(&core, "piece.cut", [0, 0, 1])
            == Self.won("The pieces match the target. Level won with 2 cuts made."))
        #expect(core.play.stage == .won)
    }

    @Test func aSliverFailurePlansOnlyTheOutcome() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let sliver: String = "Cut 1 left piece 2 at 1/432 of the crystal, thinner than the sliver limit of 1/64. "
            + Self.advice
        #expect(Self.accepted(&core, "piece.cut", [0, 0, -5]) == Self.failed(sliver))
        #expect(core.play.stage == .failed)
        #expect(Self.refused(&core, "piece.cut", [0, 0, 0], code: "r02-g08.stage")
            == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 piece. 15 cuts left."))
        #expect(core.play.stage == .playing)
        // A redo that fails the play again plans only the outcome.
        #expect(Self.accepted(&core, "play.redo") == Self.failed(sliver))
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 1 piece. 15 cuts left."))
    }

    @Test func theLastCutOfTheBudgetPlansOnlyTheOutcome() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(core.play.level.budget == 9)
        let depths: [Double] = [0, -2, 3, -3, 2, -4, -1, 1]
        let texts: [String] = ["Piece 1 cut in direction x at depth 0: 2 pieces now. 8 cuts left.",
                               "Piece 1 cut in direction x at depth -2: 3 pieces now. 7 cuts left.",
                               "Piece 1 cut in direction x at depth 3: 4 pieces now. 6 cuts left.",
                               "Piece 1 cut in direction x at depth -3: 5 pieces now. 5 cuts left.",
                               "Piece 1 cut in direction x at depth 2: 6 pieces now. 4 cuts left.",
                               "Piece 1 cut in direction x at depth -4: 7 pieces now. 3 cuts left.",
                               "Piece 1 cut in direction x at depth -1: 8 pieces now. 2 cuts left.",
                               "Piece 1 cut in direction x at depth 1: 9 pieces now. 1 cut left."]
        for index in depths.indices {
            #expect(Self.accepted(&core, "piece.cut", [0, 0, depths[index]]) == Self.state(texts[index]),
                    "cut \(index)")
        }
        let budget: String = "The cuts ran out: 9 of 9 spent with 10 pieces; the target has 4. " + Self.advice
        #expect(Self.accepted(&core, "piece.cut", [0, 0, 4]) == Self.failed(budget))
        #expect(core.play.stage == .failed && core.play.failure == .budget)
        #expect(Self.accepted(&core, "play.undo") == Self.state("Undone. 9 pieces. 1 cut left."))
    }

    @Test func everyRefusalCodeHasItsWords() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.refused(&core, "piece.cut", [5, 0, 0], code: "r02-g08.action")
            == Self.rejection("That cut is not possible here."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g08.action")
            == Self.rejection("That cut is not possible here."))
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g08.action")
            == Self.rejection("That cut is not possible here."))
        #expect(Self.refused(&core, "piece.cut", [0, 0, 20], code: "r02-g08.miss")
            == Self.rejection("That plane misses the piece."))
        #expect(Self.refused(&core, "piece.cut", [0.5, 0, 0], code: "r02-g08.not-whole")
            == Self.rejection("That value must be a whole number."))
        #expect(Self.refused(&core, "level.select", [100], code: "r02-g08.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g08.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2027, 2, 29], code: "r02-g08.date")
            == Self.rejection("That date cannot be used."))
        // The words alone, raw and prefixed, and the codes without words of their own.
        let codes: [String] = ["r02-g08.locked", "r02-g08.date", "r02-g08.action", "r02-g08.miss", "r02-g08.stage",
                               "r02-g08.not-whole", "r02-g08.stale", "r02-g08.malformed", "action.out-of-range",
                               "action.unknown-control", ""]
        let words: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That cut is not possible here.", "That plane misses the piece.",
                               "The level has ended.", "That value must be a whole number.", "That move was refused.",
                               "That move was refused.", "That move was refused.", "That move was refused.",
                               "That move was refused."]
        for index in codes.indices {
            #expect(Plan.refusalText(code: codes[index]) == words[index], "\(codes[index])")
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == words[index], "\(codes[index])")
            #expect(Plan.refused(code: codes[index]) == Self.rejection(words[index]), "\(codes[index])")
        }
    }

    @Test func levelAndModeChangesAndTheTutorial() async throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        // The same untouched level reopened shows the tutorial again.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.aim))
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.aim))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 22]) == Self.level("Level 76, band 4, daily."))
        #expect(Self.accepted(&core, "level.select", [1]) == Self.level("Level 1, band 1, campaign. " + Self.aim))
        // A cut moves the tutorial on but announces only the cut.
        #expect(Self.accepted(&core, "piece.cut", [0, 0, 0])
            == Self.state("Piece 1 cut in direction x at depth 0: 2 pieces now. 8 cuts left."))
        #expect(core.tutorial == .match)
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        // Level 77: no tutorial; an untouched campaign reopened plans nothing; a played level reopened is a level plan.
        var other: Core = try await Core.prepare(seed: Self.seed)
        #expect(Plan.after(old: other, new: other) == Plan.none)
        #expect(Self.accepted(&other, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&other, "mode.campaign") == Plan.none)
        #expect(Self.accepted(&other, "mode.practice") == Self.level("Level 77, band 4, practice."))
        #expect(Self.accepted(&other, "mode.campaign") == Self.level("Level 77, band 4, campaign."))
        #expect(Self.accepted(&other, "piece.cut", [0, 3, -2])
            == Self.state("Piece 1 cut in direction x+y at depth -2: 2 pieces now. 14 cuts left."))
        #expect(Self.accepted(&other, "level.select", [77]) == Self.level("Level 77, band 4, campaign."))
        #expect(other.play.records.isEmpty)
    }

    @Test func theSummaryNamesPiecesTargetAndNextCut() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let opening: FacetedForgePreviewChoice = FacetedForgePreviewChoice.initial(core.play)
        #expect(Plan.summaryText(core: core, choice: opening) == "15 cuts left. 1 piece: the whole crystal. Target: "
            + Self.target77 + ". Next cut: piece 1, direction z, depth 0.")
        // A choice whose plane misses the piece, and a piece the play does not have.
        let missing: FacetedForgePreviewChoice = FacetedForgePreviewChoice(piece: 0, direction: 0, depth: 20)
        #expect(Plan.summaryText(core: core, choice: missing) == "15 cuts left. 1 piece: the whole crystal. Target: "
            + Self.target77 + ". Next cut: piece 1, direction x, the plane misses this piece.")
        let absent: FacetedForgePreviewChoice = FacetedForgePreviewChoice(piece: 3, direction: 9, depth: 0)
        #expect(Plan.summaryText(core: core, choice: absent) == "15 cuts left. 1 piece: the whole crystal. Target: "
            + Self.target77 + ". Next cut: piece 4, direction x+y+z, the plane misses this piece.")
        // A preview choice change is presentation only: the core is unchanged and nothing is planned.
        #expect(Plan.after(old: core, new: core) == Plan.none)
        _ = Self.accepted(&core, "piece.cut", [0, 3, -2])
        let choice: FacetedForgePreviewChoice = FacetedForgePreviewChoice(piece: 1, direction: 12, depth: -1)
        #expect(Plan.summaryText(core: core, choice: choice) == "14 cuts left. 2 pieces: piece 1: 20/27 of the "
            + "crystal, 9 faces; piece 2: 7/27 of the crystal, 7 faces. Target: " + Self.target77
            + ". Next cut: piece 2, direction −x+y+z, depth -1.")
        // Level 2's thirds in words.
        var thirds: Core = try Core.opening(number: 2)
        _ = Self.accepted(&thirds, "piece.cut", [0, 0, -1])
        let half: FacetedForgePreviewChoice = FacetedForgePreviewChoice(piece: 0, direction: 0, depth: 1)
        #expect(Plan.summaryText(core: thirds, choice: half) == "9 cuts left. 2 pieces: piece 1: 2/3 of the crystal, "
            + "6 faces; piece 2: a third of the crystal, 6 faces. Target: 3 pieces: a third of the crystal with 6 "
            + "faces; a third of the crystal with 6 faces; a third of the crystal with 6 faces. Next cut: piece 1, "
            + "direction x, depth 1.")
    }
}
