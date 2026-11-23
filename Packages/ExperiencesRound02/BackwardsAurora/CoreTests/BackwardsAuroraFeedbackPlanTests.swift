// BackwardsAuroraFeedbackPlanTests — feature 396 (R02-G10-06) T-R02G1006-003 (FR-R02G1006-001, 002, 003, 005;
// SC-R02G1006-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `BackwardsAuroraFeedbackPlan` on
// real certified cores: reversals, undo and redo with a 3-star campaign win (the winning reversal plans only the
// outcome), a 2-star campaign win after two detours and a practice win without stars, every refusal code (raw, prefixed
// and as the core reports it), a tear failure (the tearing reversal and a tearing redo plan only the outcome), a budget
// failure on the last reversal (the reversals left down to the singular, undo after it), `level.next`, `level.select`,
// `mode.daily`, `mode.practice`, `mode.campaign` with and without the tutorial, the dismissal, a revealed hint, the
// summary element, and no plan for an unchanged core, a change of the section's ends or a freeze preview.
// Level 1 (band 1, tutorial `mark`): 14 samples, opening -24 -23 -23 -21 -22 -20 -20 -21 -26 -25 -24 -23 -27 -28,
// target -24 -23 -23 -22 -21 -20 -20 -21 -23 -24 -25 -26 -27 -28, checkpoints at positions 4 and 11, bend limit 1,
// breaking limit 128, sections of 2 … 14 samples, budget 9, certified smallest 2 ([3, 4] then [8, 11]). The opening's
// worst bend is 6 and no checkpoint matches; [3, 4] matches checkpoint 1 (worst bend still 6); [0, 1] is the neutral
// pair (no checkpoint, worst bend 6). Level 100 (band 5): breaking limit 18, bend limit 2, budget 16, 6 checkpoints;
// the first tearing section in (start, end) order is [0, 7], tearing at seam 8 with a bend of 20 and 1 checkpoint
// matched; its opening's worst bend is 12. Seed 2_396 opens level 97 (band 5, no tutorial). The daily level of
// 2026-11-23 is level 99 (band 5). The expected texts are written out here (computed independently from the waves),
// not built with the plan's helpers. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import BackwardsAuroraCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct BackwardsAuroraFeedbackPlanTests {
    typealias Core = BackwardsAuroraExperienceCore
    typealias Plan = BackwardsAuroraFeedbackPlan

    /// The seed of these tests: level 2_396 % 100 + 1 = 97.
    static let seed: UInt64 = 2_396

    /// The tutorial's first instruction (feature 395).
    static let markStep: String = "Tap two samples to mark the ends of a section (or use the panel) — a hint shows which"

    /// The shared advice that ends every failure explanation (feature 395).
    static let advice: String = "Undo the last reversal or retry the level."

    /// The opening sentence of every win.
    static let won: String = "Every checkpoint matches and every bend is within the limit."

    /// Level 1 in words.
    static let level1: String = "14 samples; 2 checkpoints at positions 4, 11; bend limit 1, breaking limit 128; "
        + "sections of 2 to 14 samples; 9 reversals"

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

    /// Reverses [start, end] of `core`, expects it accepted and returns the plan of the change.
    static func reverse(_ core: inout Core, _ start: Int, _ end: Int) -> Plan {
        accepted(&core, "wave.reverse", [Double(start), Double(end)])
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
    static func win(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .success) }

    /// An `outcome` plan of a failure, haptic `warning`.
    static func failure(_ text: String) -> Plan { Plan(text: text, kind: .outcome, haptic: .warning) }

    @Test func reversalUndoRedoAndAThreeStarCampaignWin() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(core.mode == .campaign && core.tutorial == .mark)
        #expect(Self.reverse(&core, 3, 4)
            == Self.state("Reversed samples 3 to 4. Checkpoints matched 1 of 2; worst bend 6 of limit 1. "
                + "8 reversals left."))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. Checkpoints matched 0 of 2; worst bend 6 of limit 1. 9 reversals left."))
        #expect(Self.accepted(&core, "play.redo")
            == Self.state("Redone. Checkpoints matched 1 of 2; worst bend 6 of limit 1. 8 reversals left."))
        // The winning reversal plans only the outcome (no selection haptic): 2 reversals made (the redo is none).
        let winning: Plan = Self.reverse(&core, 8, 11)
        #expect(core.play.stage == .won)
        #expect(winning == Self.win(Self.won + " Level won with 2 reversals made, 3 of 3 stars."))
        #expect(winning.haptic != .selection)
        // The adapter's own record of the win agrees with the announced stars.
        #expect(core.progress.solved[1]?.stars == 3)
    }

    @Test func aTwoStarCampaignWinAfterDetoursAndAPracticeWinWithoutStars() throws {
        var core: Core = try Core.opening(number: 1)
        for _ in 0..<2 {
            #expect(Self.reverse(&core, 0, 1)
                == Self.state("Reversed samples 0 to 1. Checkpoints matched 0 of 2; worst bend 6 of limit 1. "
                    + "8 reversals left."))
            #expect(Self.accepted(&core, "play.undo")
                == Self.state("Undone. Checkpoints matched 0 of 2; worst bend 6 of limit 1. 9 reversals left."))
        }
        #expect(Self.reverse(&core, 3, 4)
            == Self.state("Reversed samples 3 to 4. Checkpoints matched 1 of 2; worst bend 6 of limit 1. "
                + "8 reversals left."))
        #expect(Self.reverse(&core, 8, 11) == Self.win(Self.won + " Level won with 4 reversals made, 2 of 3 stars."))
        #expect(core.progress.solved[1]?.stars == 2)
        // Practice: a level plan, then a win without stars (the budget is 40).
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.markStep))
        #expect(Self.reverse(&core, 3, 4)
            == Self.state("Reversed samples 3 to 4. Checkpoints matched 1 of 2; worst bend 6 of limit 1. "
                + "39 reversals left."))
        #expect(Self.reverse(&core, 8, 11) == Self.win(Self.won + " Level won with 2 reversals made."))
    }

    @Test func everyRefusalCodeHasItsWords() throws {
        let words: [(code: String, text: String)] = [
            ("r02-g10.locked", "That level is not open yet."),
            ("r02-g10.date", "That date cannot be used."),
            ("r02-g10.action", "That section cannot be reversed here."),
            ("r02-g10.noop", "That section reads the same both ways; reversing it changes nothing."),
            ("r02-g10.stage", "The level has ended."),
            ("r02-g10.not-whole", "That value must be a whole number."),
            ("r02-g10.stale", "That reversal was refused."),
            ("r02-g10.malformed", "That reversal was refused."),
            ("action.out-of-range", "That reversal was refused."),
            ("something-else", "That reversal was refused."),
        ]
        for entry in words {
            #expect(Plan.refusalText(code: entry.code) == entry.text, "\(entry.code)")
            #expect(Plan.refused(code: entry.code) == Self.rejection(entry.text), "\(entry.code)")
            #expect(Plan.refusalText(code: "action.rule." + entry.code) == entry.text, "prefixed \(entry.code)")
        }
        // As the core reports them.
        var core: Core = try Core.opening(number: 1)
        #expect(Self.refused(&core, "level.select", [42], code: "r02-g10.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g10.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2027, 2, 29], code: "r02-g10.date")
            == Self.rejection("That date cannot be used."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g10.action")
            == Self.rejection("That section cannot be reversed here."))
        #expect(Self.refused(&core, "wave.reverse", [0, 14], code: "r02-g10.action")
            == Self.rejection("That section cannot be reversed here."))
        #expect(Self.refused(&core, "wave.reverse", [5, 6], code: "r02-g10.noop")
            == Self.rejection("That section reads the same both ways; reversing it changes nothing."))
        #expect(Self.refused(&core, "wave.reverse", [0.5, 2], code: "r02-g10.not-whole")
            == Self.rejection("That value must be a whole number."))
        _ = Self.reverse(&core, 3, 4)
        _ = Self.reverse(&core, 8, 11)
        #expect(core.play.stage == .won)
        #expect(Self.refused(&core, "wave.reverse", [0, 1], code: "r02-g10.stage")
            == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g10.stage") == Self.rejection("The level has ended."))
    }

    @Test func aTearPlansOnlyTheOutcomeAndARedoOfItToo() throws {
        var core: Core = try Core.opening(number: 100)
        let tear: String = "Reversal 1 (samples 0 to 7) tore the aurora at seam 8: a bend of 20 against the breaking "
            + "limit 18. " + Self.advice
        let tearing: Plan = Self.reverse(&core, 0, 7)
        #expect(core.play.stage == .failed)
        #expect(tearing == Self.failure(tear) && tearing.haptic != .selection)
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. Checkpoints matched 0 of 6; worst bend 12 of limit 2. 16 reversals left."))
        #expect(Self.accepted(&core, "play.redo") == Self.failure(tear))
        #expect(core.play.stage == .failed)
    }

    @Test func theLastReversalOfTheBudgetPlansOnlyTheOutcome() throws {
        var core: Core = try Core.opening(number: 1)
        for spent in 1...8 {
            let left: String = spent == 8 ? "1 reversal left" : "\(9 - spent) reversals left"
            #expect(Self.reverse(&core, 0, 1)
                == Self.state("Reversed samples 0 to 1. Checkpoints matched 0 of 2; worst bend 6 of limit 1. "
                    + left + "."))
        }
        let last: Plan = Self.reverse(&core, 0, 1)
        #expect(core.play.stage == .failed && core.play.failure == .budget)
        #expect(last == Self.failure("The reversals ran out: 9 of 9 spent with 0 of 2 checkpoints matched and a worst "
            + "bend of 6 against the limit 1. " + Self.advice))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. Checkpoints matched 0 of 2; worst bend 6 of limit 1. 1 reversal left."))
    }

    @Test func levelAndModeChangesAndTheTutorial() async throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.markStep))
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.markStep))
        // The dismissal alone plans nothing; reopening the untouched level shows the tutorial again.
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        #expect(core.tutorial == .done)
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.markStep))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 23]) == Self.level("Level 99, band 5, daily."))
        #expect(Self.accepted(&core, "level.select", [1]) == Self.level("Level 1, band 1, campaign. " + Self.markStep))
        // A reversal advances the tutorial, but the plan is the reversal's.
        #expect(Self.reverse(&core, 3, 4)
            == Self.state("Reversed samples 3 to 4. Checkpoints matched 1 of 2; worst bend 6 of limit 1. "
                + "8 reversals left."))
        _ = Self.reverse(&core, 8, 11)
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.markStep))
        // The seed's level (97, no tutorial): selecting an open level and practising it.
        var seeded: Core = try await Core.prepare(seed: Self.seed)
        #expect(seeded.levelNumber == 97 && seeded.tutorial == .done)
        #expect(Self.accepted(&seeded, "level.select", [21]) == Self.level("Level 21, band 2, campaign."))
        #expect(Self.accepted(&seeded, "mode.practice") == Self.level("Level 21, band 2, practice."))
        #expect(Self.accepted(&seeded, "level.select", [97]) == Self.level("Level 97, band 5, campaign."))
    }

    @Test func noPlanForAnUnchangedCoreTheSectionsEndsOrAPreview() throws {
        let core: Core = try Core.opening(number: 1)
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Plan.none == Plan(text: nil, kind: nil, haptic: nil))
        // Choosing the section's ends and reading snapshots (the freeze preview's input) is presentation only.
        var reads: Core = core
        for start in 0..<4 {
            _ = reads.snapshot(sectionStart: start, sectionEnd: start + 2, time: Double(start) * 0.25)
        }
        reads.setQualityTier(2)
        #expect(Plan.after(old: core, new: reads) == Plan.none)
    }

    @Test func theSummaryAndARevealedHint() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Plan.summaryText(core: core, sectionStart: 3, sectionEnd: 4)
            == "9 reversals left. Checkpoints matched 0 of 2; worst bend 6 of limit 1, breaking limit 128. Section 3 "
                + "to 4, 2 samples. Checkpoints: checkpoint 1 at position 4: height -22, target -21, not matched; "
                + "checkpoint 2 at position 11: height -23, target -26, not matched. Level: " + Self.level1 + ".")
        _ = Self.reverse(&core, 3, 4)
        #expect(Plan.summaryText(core: core, sectionStart: 8, sectionEnd: 11)
            == "8 reversals left. Checkpoints matched 1 of 2; worst bend 6 of limit 1, breaking limit 128. Section 8 "
                + "to 11, 4 samples. Checkpoints: checkpoint 1 at position 4: height -21, target -21, matched; "
                + "checkpoint 2 at position 11: height -23, target -26, not matched. Level: " + Self.level1 + ".")
        // A revealed hint: `state`, no haptic, its own words.
        let hint: BackwardsAuroraHint = try #require(BackwardsAuroraHints.hint(level: 3, play: core.play))
        #expect(hint.kind == .reverse)
        #expect(Plan.hint(text: hint.text) == Plan(text: hint.text, kind: .state, haptic: nil))
        #expect(Plan.hint(text: "Reverse samples 8 to 11") == Plan(text: "Reverse samples 8 to 11", kind: .state,
                                                                   haptic: nil))
        #expect(Plan.hint(text: BackwardsAuroraHint.failedText)
            == Plan(text: "Undo the last reversal or retry the level.", kind: .state, haptic: nil))
    }
}
