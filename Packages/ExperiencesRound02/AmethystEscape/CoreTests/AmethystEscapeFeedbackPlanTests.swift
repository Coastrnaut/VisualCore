// AmethystEscapeFeedbackPlanTests — feature 366 (R02-G07-06) T-R02G0706-003 (FR-R02G0706-001, 002, 003, 005;
// SC-R02G0706-002; clarifications Q1, Q2, Q5). The exact texts, kinds and haptics of `AmethystEscapeFeedbackPlan` on
// real certified cores: turns both ways, advances, undo and redo, the summary of one core, a wedge failure (a failing
// advance and a failing redo plan only the outcome) with its undo, a stuck advance, a budget failure on the last move
// (the moves left down to the singular), every refusal code (raw, prefixed and as the core reports it, engine codes
// included), a campaign win with 3 and with 2 stars and a practice win (a winning advance plans only the outcome),
// `level.next`, `level.select`, `mode.daily`, `mode.practice`, `mode.campaign` with and without the tutorial, the
// dismissal, drags of 1 and 3 sectors (one plan; a drag that ends the play plans only the outcome), shell picks and no
// plan for an unchanged core.
// Seed 2_366 opens level 67 (band 4, no tutorial): 8 sectors, 4 shells, start sector 7 of 8, budget 17, certified
// smallest 9 (solution: shell 1 −1 three times, shell 2 +1, shell 3 −1, four advances); shell 1 (inner) openings 3, 7,
// walls after 3, 4, blocked 2; shell 2 openings 1, 3, wall after 4, blocked 2, 4, 5; shell 3 openings 5, 7, walls after
// 1, 2, 4, blocked 1, 6; shell 4 (outer) exit gap 4, wall after 6, blocked 8 (1-based own sectors). Level 1 (band 1,
// tutorial `turn`): 6 sectors, 2 shells, start sector 5 of 6, budget 9, certified smallest 3 (shell 1 −1, two
// advances); its first advance falls into the blocked wedge of shell 2 (outer), sector 5. The daily level of 2026-11-22
// is level 26. The expected texts are written out here, not built with the plan's helpers. Explicit types, plain loops,
// short runs.
// Feature 367 (R02-G07-07) T-R02G0707-003: the replay refusal words (raw and prefixed, as the core reports them) and a
// replay of level 1's certified solution: start and stop are level plans, each step is announced like the action it
// replays, and the replayed win claims no stars.
import Foundation
import Testing
@testable import AmethystEscapeCore
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct AmethystEscapeFeedbackPlanTests {
    typealias Core = AmethystEscapeExperienceCore
    typealias Plan = AmethystEscapeFeedbackPlan

    /// The seed of these tests: level 2_366 % 100 + 1 = 67.
    static let seed: UInt64 = 2_366

    /// The tutorial's first instruction (feature 365).
    static let turn: String = "Drag a shell round the centre (or use Turn − and +) to line an opening up with the "
        + "pearl, or roll the pearl when its way is open; a hint shows which"

    /// The shared advice that ends every failure explanation (feature 365).
    static let advice: String = "Undo the last move or retry the level."

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

    @Test func turnsAdvancesUndoRedoAndTheSummary() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(core.levelNumber == 67 && core.tutorial == .done && core.mode == .campaign)
        #expect(core.play.level.budget == 17 && core.certifiedSmallest == 9)
        #expect(Self.accepted(&core, "shell.rotate", [0, 1])
            == Self.state("Shell 1 (inner) turned one sector clockwise. 16 moves left."))
        #expect(Self.accepted(&core, "shell.rotate", [1, -1])
            == Self.state("Shell 2 turned one sector anticlockwise. 15 moves left."))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. The pearl is in shell 1 (inner), sector 8 of 8. 16 moves left."))
        #expect(Self.accepted(&core, "play.redo")
            == Self.state("Redone. The pearl is in shell 1 (inner), sector 8 of 8. 15 moves left."))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. The pearl is in shell 1 (inner), sector 8 of 8. 16 moves left."))
        #expect(Self.accepted(&core, "shell.rotate", [0, -1])
            == Self.state("Shell 1 (inner) turned one sector anticlockwise. 15 moves left."))
        #expect(Self.accepted(&core, "pearl.advance")
            == Self.state("The pearl rolled to shell 2, sector 7 of 8. 14 moves left."))
        #expect(Self.accepted(&core, "pearl.advance")
            == Self.state("The pearl rolled to shell 2, sector 8 of 8. 13 moves left."))
        #expect(Self.accepted(&core, "shell.rotate", [3, 1])
            == Self.state("Shell 4 (outer) turned one sector clockwise. 12 moves left."))
        #expect(Plan.summaryText(core: core) == "12 moves left. The pearl is in shell 2, sector 8 of 8. "
            + "The exit gap is at sector 5 of 8. "
            + "Shell 1 (inner): openings at sectors 3, 7; walls after sectors 3, 4; blocked sectors 2, turned 0. "
            + "Shell 2: openings at sectors 1, 3; walls after sectors 4; blocked sectors 2, 4, 5, turned 0. "
            + "Shell 3: openings at sectors 5, 7; walls after sectors 1, 2, 4; blocked sectors 1, 6, turned 0. "
            + "Shell 4 (outer): exit gap at sector 4; walls after sectors 6; blocked sectors 8, turned 1.")
        #expect(Self.accepted(&core, "pearl.advance")
            == Self.state("The pearl rolled to shell 2, sector 1 of 8. 11 moves left."))
    }

    @Test func aWedgeFailurePlansOnlyTheOutcomeAndAStuckAdvanceRefuses() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.accepted(&core, "pearl.advance")
            == Self.state("The pearl rolled to shell 2, sector 7 of 8. 16 moves left."))
        #expect(Self.accepted(&core, "pearl.advance")
            == Self.state("The pearl rolled to shell 2, sector 8 of 8. 15 moves left."))
        #expect(Self.accepted(&core, "pearl.advance")
            == Self.state("The pearl rolled to shell 2, sector 1 of 8. 14 moves left."))
        let wedge: String = "The pearl fell into the blocked wedge of shell 3, sector 1 of 8, on move 4. " + Self.advice
        #expect(Self.accepted(&core, "pearl.advance") == Self.failed(wedge))
        #expect(core.play.stage == .failed)
        #expect(Self.refused(&core, "shell.rotate", [0, 1], code: "r02-g07.stage")
            == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "pearl.advance", [], code: "r02-g07.stage")
            == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. The pearl is in shell 2, sector 1 of 8. 14 moves left."))
        #expect(core.play.stage == .playing)
        // A redo that fails the play again plans only the outcome.
        #expect(Self.accepted(&core, "play.redo") == Self.failed(wedge))
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. The pearl is in shell 2, sector 1 of 8. 14 moves left."))
        // Shell 3 turned back one sector: the pearl arrives in its own sector 2, where a wall stops it.
        #expect(Self.accepted(&core, "shell.rotate", [2, -1])
            == Self.state("Shell 3 turned one sector anticlockwise. 13 moves left."))
        #expect(Self.accepted(&core, "pearl.advance")
            == Self.state("The pearl rolled to shell 3, sector 1 of 8. 12 moves left."))
        #expect(Self.refused(&core, "pearl.advance", [], code: "r02-g07.stuck")
            == Self.rejection("A wall stops the pearl: turn a shell first."))
    }

    @Test func theLastMoveOfTheBudgetPlansOnlyTheOutcome() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(core.play.level.budget == 9)
        for index in 0..<8 {
            let step: Double = index % 2 == 0 ? 1 : -1
            let way: String = index % 2 == 0 ? "clockwise" : "anticlockwise"
            let left: Int = 8 - index
            let suffix: String = left == 1 ? "1 move left." : "\(left) moves left."
            #expect(Self.accepted(&core, "shell.rotate", [1, step])
                == Self.state("Shell 2 (outer) turned one sector \(way). \(suffix)"))
        }
        let budget: String = "The moves ran out: 9 of 9 spent and the pearl is in shell 1 (inner), sector 5 of 6. "
            + Self.advice
        #expect(Self.accepted(&core, "shell.rotate", [1, 1]) == Self.failed(budget))
        #expect(core.play.stage == .failed && core.play.failure == .budget)
        #expect(Self.accepted(&core, "play.undo")
            == Self.state("Undone. The pearl is in shell 1 (inner), sector 5 of 6. 1 move left."))
        // Level 1's first advance falls into a wedge on move 1.
        var wedge: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&wedge, "pearl.advance") == Self.failed("The pearl fell into the blocked wedge of "
            + "shell 2 (outer), sector 5 of 6, on move 1. " + Self.advice))
    }

    @Test func everyRefusalCodeHasItsWords() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Self.refused(&core, "shell.rotate", [4, 1], code: "r02-g07.action")
            == Self.rejection("That move is not allowed here."))
        #expect(Self.refused(&core, "shell.rotate", [0, 0], code: "r02-g07.action")
            == Self.rejection("That move is not allowed here."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g07.action")
            == Self.rejection("That move is not allowed here."))
        #expect(Self.refused(&core, "play.redo", [], code: "r02-g07.action")
            == Self.rejection("That move is not allowed here."))
        #expect(Self.refused(&core, "shell.rotate", [0.5, 1], code: "r02-g07.not-whole")
            == Self.rejection("That value must be a whole number."))
        #expect(Self.refused(&core, "level.select", [100], code: "r02-g07.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "level.next", [], code: "r02-g07.locked")
            == Self.rejection("That level is not open yet."))
        #expect(Self.refused(&core, "mode.daily", [2027, 2, 29], code: "r02-g07.date")
            == Self.rejection("That date cannot be used."))
        // The words alone, raw and prefixed, and the codes without words of their own.
        let codes: [String] = ["r02-g07.locked", "r02-g07.date", "r02-g07.action", "r02-g07.stuck", "r02-g07.stage",
                               "r02-g07.not-whole", "r02-g07.stale", "r02-g07.malformed", "action.out-of-range",
                               "action.unknown-control", "", "r02-g07.no-replay", "r02-g07.replay-end",
                               "r02-g07.replay"]
        let words: [String] = ["That level is not open yet.", "That date cannot be used.",
                               "That move is not allowed here.", "A wall stops the pearl: turn a shell first.",
                               "The level has ended.", "That value must be a whole number.", "That move was refused.",
                               "That move was refused.", "That move was refused.", "That move was refused.",
                               "That move was refused.", "There is no saved solution to replay for this level.",
                               "The replay is over.", "Stop the replay first."]
        for index in codes.indices {
            #expect(Plan.refusalText(code: codes[index]) == words[index], "\(codes[index])")
            #expect(Plan.refusalText(code: "action.rule." + codes[index]) == words[index], "\(codes[index])")
            #expect(Plan.refused(code: codes[index]) == Self.rejection(words[index]), "\(codes[index])")
        }
    }

    @Test func aCampaignWinPlansOnlyTheOutcomeWithItsStars() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        let expected: [Plan] = [
            Self.state("Shell 1 (inner) turned one sector anticlockwise. 16 moves left."),
            Self.state("Shell 1 (inner) turned one sector anticlockwise. 15 moves left."),
            Self.state("Shell 1 (inner) turned one sector anticlockwise. 14 moves left."),
            Self.state("Shell 2 turned one sector clockwise. 13 moves left."),
            Self.state("Shell 3 turned one sector anticlockwise. 12 moves left."),
            Self.state("The pearl rolled to shell 2, sector 4 of 8. 11 moves left."),
            Self.state("The pearl rolled to shell 3, sector 4 of 8. 10 moves left."),
            Self.state("The pearl rolled to shell 4 (outer), sector 4 of 8. 9 moves left."),
            Self.won("The pearl escaped. Level won in 9 moves, 3 of 3 stars."),
        ]
        let controls: [String] = ["shell.rotate", "shell.rotate", "shell.rotate", "shell.rotate", "shell.rotate",
                                  "pearl.advance", "pearl.advance", "pearl.advance", "pearl.advance"]
        let values: [[Double]] = [[0, -1], [0, -1], [0, -1], [1, 1], [2, -1], [], [], [], []]
        for index in expected.indices {
            #expect(Self.accepted(&core, controls[index], values[index]) == expected[index], "step \(index)")
        }
        #expect(core.play.stage == .won)
        #expect(Self.refused(&core, "shell.rotate", [0, 1], code: "r02-g07.stage")
            == Self.rejection("The level has ended."))
        #expect(Self.refused(&core, "play.undo", [], code: "r02-g07.stage") == Self.rejection("The level has ended."))
        #expect(Self.accepted(&core, "level.next") == Self.level("Level 68, band 4, campaign."))
        // Level 1 with two extra turns against the certified smallest 3: two stars; then level 2 with its tutorial.
        var second: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&second, "shell.rotate", [1, 1])
            == Self.state("Shell 2 (outer) turned one sector clockwise. 8 moves left."))
        #expect(Self.accepted(&second, "shell.rotate", [1, -1])
            == Self.state("Shell 2 (outer) turned one sector anticlockwise. 7 moves left."))
        #expect(Self.accepted(&second, "shell.rotate", [0, -1])
            == Self.state("Shell 1 (inner) turned one sector anticlockwise. 6 moves left."))
        #expect(Self.accepted(&second, "pearl.advance")
            == Self.state("The pearl rolled to shell 2 (outer), sector 4 of 6. 5 moves left."))
        #expect(Self.accepted(&second, "pearl.advance")
            == Self.won("The pearl escaped. Level won in 5 moves, 2 of 3 stars."))
        #expect(Self.accepted(&second, "level.next") == Self.level("Level 2, band 1, campaign. " + Self.turn))
    }

    /// Feature 367: a replay of level 1's certified solution (shell 1 −1, two advances) after a 3-star campaign win.
    @Test func aReplayIsAnnouncedLikePlayAndClaimsNoStars() throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Self.refused(&core, "replay.start", [1], code: "r02-g07.no-replay")
            == Self.rejection("There is no saved solution to replay for this level."))
        #expect(Self.refused(&core, "replay.step", [], code: "r02-g07.no-replay")
            == Self.rejection("There is no saved solution to replay for this level."))
        _ = Self.accepted(&core, "shell.rotate", [0, -1])
        _ = Self.accepted(&core, "pearl.advance")
        #expect(Self.accepted(&core, "pearl.advance") == Self.won("The pearl escaped. Level won in 3 moves, 3 of 3 stars."))
        #expect(Self.accepted(&core, "replay.start", [1]) == Self.level("Level 1, band 1, replay."))
        #expect(Self.refused(&core, "shell.rotate", [0, 1], code: "r02-g07.replay")
            == Self.rejection("Stop the replay first."))
        #expect(Self.accepted(&core, "replay.step")
            == Self.state("Shell 1 (inner) turned one sector anticlockwise. 8 moves left."))
        #expect(Self.accepted(&core, "replay.step")
            == Self.state("The pearl rolled to shell 2 (outer), sector 4 of 6. 7 moves left."))
        #expect(Self.accepted(&core, "replay.step") == Self.won("The pearl escaped. Level won in 3 moves."))
        #expect(Self.refused(&core, "replay.step", [], code: "r02-g07.replay-end")
            == Self.rejection("The replay is over."))
        #expect(Self.accepted(&core, "replay.stop") == Self.level("Level 1, band 1, campaign. " + Self.turn))
    }

    @Test func aPracticeWinHasNoStars() throws {
        var practice: Core = try Core.opening(number: 1)
        #expect(Self.accepted(&practice, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.turn))
        #expect(Self.accepted(&practice, "shell.rotate", [0, -1])
            == Self.state("Shell 1 (inner) turned one sector anticlockwise. 59 moves left."))
        #expect(Self.accepted(&practice, "pearl.advance")
            == Self.state("The pearl rolled to shell 2 (outer), sector 4 of 6. 58 moves left."))
        #expect(Self.accepted(&practice, "pearl.advance") == Self.won("The pearl escaped. Level won in 3 moves."))
        #expect(practice.play.stage == .won)
    }

    @Test func levelAndModeChangesAndTheTutorial() async throws {
        var core: Core = try Core.opening(number: 1)
        #expect(Plan.after(old: core, new: core) == Plan.none)
        #expect(Self.accepted(&core, "tutorial.dismiss") == Plan.none)
        // The same untouched level reopened shows the tutorial again.
        #expect(Self.accepted(&core, "mode.campaign") == Self.level("Level 1, band 1, campaign. " + Self.turn))
        #expect(Self.accepted(&core, "mode.practice") == Self.level("Level 1, band 1, practice. " + Self.turn))
        #expect(Self.accepted(&core, "mode.daily", [2026, 11, 22]) == Self.level("Level 26, band 2, daily."))
        #expect(Self.accepted(&core, "level.select", [1]) == Self.level("Level 1, band 1, campaign. " + Self.turn))
        // Level 67: no tutorial; an untouched campaign reopened plans nothing; a played level reopened is a level plan.
        var other: Core = try await Core.prepare(seed: Self.seed)
        #expect(Plan.after(old: other, new: other) == Plan.none)
        #expect(Self.accepted(&other, "tutorial.dismiss") == Plan.none)
        #expect(Self.accepted(&other, "mode.campaign") == Plan.none)
        #expect(Self.accepted(&other, "mode.practice") == Self.level("Level 67, band 4, practice."))
        #expect(Self.accepted(&other, "mode.campaign") == Self.level("Level 67, band 4, campaign."))
        #expect(Self.accepted(&other, "shell.rotate", [2, 1])
            == Self.state("Shell 3 turned one sector clockwise. 16 moves left."))
        #expect(Self.accepted(&other, "level.select", [67]) == Self.level("Level 67, band 4, campaign."))
        #expect(other.play.records.isEmpty)
    }

    @Test func aDragIsPlannedOnce() async throws {
        var core: Core = try await Core.prepare(seed: Self.seed)
        #expect(Plan.drag(old: core, new: core, shell: 2, sectors: 0) == Plan.none)
        var before: Core = core
        for _ in 0..<3 { #expect(core.apply(Self.bare("shell.rotate", [2, 1])) == .accepted) }
        #expect(Plan.drag(old: before, new: core, shell: 2, sectors: 3)
            == Self.state("Shell 3 turned 3 sectors clockwise. 14 moves left."))
        before = core
        #expect(core.apply(Self.bare("shell.rotate", [3, -1])) == .accepted)
        #expect(Plan.drag(old: before, new: core, shell: 3, sectors: 1)
            == Self.state("Shell 4 (outer) turned one sector anticlockwise. 13 moves left."))
        // A drag across a mode change is the level plan.
        before = core
        #expect(core.apply(Self.bare("mode.practice")) == .accepted)
        #expect(Plan.drag(old: before, new: core, shell: 3, sectors: 1) == Self.level("Level 67, band 4, practice."))
        // A drag whose last turn spends the budget plans only the outcome.
        var budget: Core = try Core.opening(number: 1)
        for index in 0..<7 {
            #expect(budget.apply(Self.bare("shell.rotate", [1, index % 2 == 0 ? 1 : -1])) == .accepted)
        }
        let start: Core = budget
        for _ in 0..<2 { #expect(budget.apply(Self.bare("shell.rotate", [1, 1])) == .accepted) }
        #expect(Plan.drag(old: start, new: budget, shell: 1, sectors: 2)
            == Self.failed("The moves ran out: 9 of 9 spent and the pearl is in shell 1 (inner), sector 5 of 6. "
                + Self.advice))
    }

    @Test func shellPicksAreStateWithoutHaptic() async throws {
        let core: Core = try await Core.prepare(seed: Self.seed)
        let names: [String] = ["Shell 1 (inner)", "Shell 2", "Shell 3", "Shell 4 (outer)"]
        for index in names.indices {
            #expect(Plan.picked(shell: index, core: core)
                == Plan(text: names[index] + " picked.", kind: .state, haptic: nil))
        }
        #expect(Plan.picked(shell: 4, core: core) == Plan.none)
        #expect(Plan.picked(shell: -1, core: core) == Plan.none)
    }
}
