// AmethystEscapeTeachingTests — feature 365 (R02-G07-05) T-R02G0705-005 (FR-R02G0705-001 … 005; clarifications Q1–Q5).
// On the simulator, through the one app's session host: the presenter's teaching and progression surface, modelled on
// feature 355's Chrono Constellator teaching tests. Tutorial: level 1 (seed 0) opens with the turn instruction; following
// the certified solution (`AmethystEscapeExperienceCore.certifiedActions(1)`) moves the instruction on (turn → advance
// after the first move, advance → escape after the first advance) and wins with the instruction gone, the stars recorded
// and named in the description, and the picker's frontier raised to level 2; Dismiss hides the instruction and leaves the
// digest alone (the tutorial step is never in the digest). Hints: `showHint()` reveals levels 1, 2, 3 in that order with
// the Q1 texts ("Turn a shell" / "Turn (shell)" / "Turn (shell) one sector clockwise|anticlockwise", or "Roll the pearl"
// / "Roll the pearl one pocket"), a fourth press stays at level 3, the digest never changes and a move hides the hint;
// following the level-3 hint from the opening of level 1 wins. Failure: alternating turns of shell 0 spend the budget
// and fail the play with the Q5 budget text ("The moves ran out: B of B spent and the pearl is in …", then the advice);
// Undo returns to playing; Retry in campaign is `level.select` of the level and restarts it with zero moves. Picker and
// modes: a locked level is refused with `r02-g07.locked` and the refusal is shown; an impossible date is refused with
// `r02-g07.date`; the daily level of 2026-01-01 is `AmethystEscapeProgress.dailyLevel(2026, 1, 1)` and Retry keeps that
// date; Practice raises the budget to 60; Campaign returns. Synthetic data, no sleep, no wall-clock assertion; each test
// short. Test data uses explicit types and plain loops (CI type-check rule).
#if os(iOS)
import AmethystEscapeCore
import CoreGraphics
import Foundation
import Testing
@testable import AmethystEscapeExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the teaching tests.
@MainActor
enum AmethystEscapeTeaching {
    typealias Shell = ExperienceShell<AmethystEscapePresenter>

    /// The advice every failure text ends with (clarification Q5).
    static let advice: String = AmethystEscapeFailureExplanation.advice

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn) and describes the opening so the presenter holds
    /// the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await AmethystEscapeTest.open(session, seed: seed, size: CGSize(width: 360, height: 240))
        let opening: AmethystEscapeExperienceCore = try AmethystEscapeTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> AmethystEscapeExperienceCore {
        try AmethystEscapeTest.core(shell)
    }

    /// Sends the kernel action `action` through the presenter (the path of the controls) and returns the result.
    @discardableResult
    static func send(_ action: AmethystEscapeAction, _ shell: Shell) -> ActionResult {
        let entry: (control: String, values: [Double]) = AmethystEscapeTest.control(action)
        return shell.presenter.send(entry.control, entry.values, port: shell.port)
    }

    /// The hint text of clarification Q1 for `hint` at `level` on `play`'s level, written out here independently of
    /// ``AmethystEscapeHint/text``; nil for a stuck hint.
    static func expectedText(_ hint: AmethystEscapeHint, level: Int, play: AmethystEscapePlay) -> String? {
        switch hint.kind {
        case .turn:
            guard let shell = hint.shell, let step = hint.step else { return nil }
            let name: String = play.level.shellName(shell)
            if level == 1 { return "Turn a shell" }
            if level == 2 { return "Turn \(name)" }
            return "Turn \(name) one sector " + (step > 0 ? "clockwise" : "anticlockwise")
        case .advance:
            return level < 3 ? "Roll the pearl" : "Roll the pearl one pocket"
        case .stuck:
            return nil
        }
    }

    /// The record kind an accepted `action` makes.
    static func kind(_ action: AmethystEscapeAction) -> AmethystEscapeRecordKind {
        switch action {
        case .rotate: .rotate
        case .advance: .advance
        }
    }

    /// Spends the budget of the play of `shell` with alternating turns of shell 0 (+1, −1, …) through the presenter; a
    /// turn never moves the pearl, so the move that reaches the budget fails the play. Returns the moves sent.
    @discardableResult
    static func spendBudget(_ shell: Shell) throws -> Int {
        let budget: Int = try core(shell).play.level.budget
        var sent: Int = 0
        for index in 0..<budget {
            let stage: AmethystEscapeStage = try core(shell).play.stage
            guard stage == .playing else { break }
            let step: Int = index % 2 == 0 ? 1 : -1
            let result: ActionResult = send(.rotate(0, step), shell)
            #expect(result == .accepted, "turn \(index): \(result.code)")
            sent += 1
        }
        return sent
    }
}

@MainActor
@Suite(.serialized) struct AmethystEscapeTeachingTests {
    typealias Teaching = AmethystEscapeTeaching

    /// Level 1 opens with the turn instruction; following the certified solution moves the instruction on and wins with
    /// it gone, the stars in the description and the frontier raised.
    @Test func tutorialFollowedToAWin() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: AmethystEscapePresenter = shell.presenter
        let opening: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .turn)
        #expect(presenter.mirror.instruction == AmethystEscapeTutorialStep.turn.text,
                "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.smallest == opening.certifiedSmallest)

        let actions: [AmethystEscapeAction] = AmethystEscapeExperienceCore.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        var expected: AmethystEscapeTutorialStep = .turn
        for (index, action) in actions.enumerated() {
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "move \(index + 1): \(result.code)")
            let now: AmethystEscapeExperienceCore = try Teaching.core(shell)
            let ended: Bool = now.play.stage == .won || now.play.stage == .failed
            expected = expected.advanced(after: Teaching.kind(action), ended: ended)
            #expect(now.tutorial == expected, "move \(index + 1): \(now.tutorial) != \(expected)")
            if index == 0 && !ended {
                #expect(now.tutorial == .advance, "one move moves the tutorial on to the advance")
                #expect(presenter.mirror.instruction == AmethystEscapeTutorialStep.advance.text)
            }
            if expected == .done {
                #expect(presenter.mirror.instruction == nil)
            } else {
                #expect(presenter.mirror.instruction == expected.text)
            }
        }
        let won: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "the instruction is gone after the win")

        let stars: Int = AmethystEscapeProgress.stars(moves: won.play.moves, smallest: won.certifiedSmallest)
        #expect(won.progress.solved[1]?.stars == stars)
        #expect(presenter.mirror.stars[1] == stars)
        let text: String = presenter.describe(won)
        #expect(text.contains("Stars: \(stars) of 3."), "\(text)")
        #expect(presenter.mirror.status == "Won")

        // The picker's frontier rises after a campaign win, and the next level can be picked.
        #expect(won.progress.frontier == 2)
        #expect(presenter.mirror.frontier == 2)
        let pick: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(pick == .accepted, "\(pick.code)")
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.pickedLevel == 2)
        #expect(presenter.mirror.moves == 0)
    }

    /// Dismiss hides the instruction and leaves the digest unchanged.
    @Test func dismissHidesTheInstruction() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: AmethystEscapePresenter = shell.presenter
        #expect(presenter.mirror.instruction == AmethystEscapeTutorialStep.turn.text)
        let digest: String = try AmethystEscapeTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let dismissed: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        let after: String = try AmethystEscapeTest.digest(shell)
        #expect(after == digest, "the tutorial step is not in the digest")
    }

    /// Three hints reveal levels 1, 2, 3 with the Q1 texts; a fourth stays at level 3; the digest never changes; a move
    /// hides the hint.
    @Test func hintLevelsThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: AmethystEscapePresenter = shell.presenter
        let opening: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(opening.play.stage == .playing)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try AmethystEscapeTest.digest(shell)
        let third: AmethystEscapeHint = try #require(opening.hint(level: 3))
        #expect(third.kind != .stuck, "level 1 has an escape from its opening")

        for level in 1...3 {
            presenter.showHint()
            let want: AmethystEscapeHint = try #require(opening.hint(level: level))
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            let written: String? = Teaching.expectedText(want, level: level, play: opening.play)
            #expect(written != nil)
            #expect(presenter.mirror.hintText == written, "level \(level): Q1 text")
            let now: String = try AmethystEscapeTest.digest(shell)
            #expect(now == digest, "hint \(level) leaves the state alone")
        }
        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 3, "a fourth press stays at level 3")
        #expect(presenter.mirror.hintText == third.text)
        let still: String = try AmethystEscapeTest.digest(shell)
        #expect(still == digest)

        // A move hides the hint.
        let moved: ActionResult = Teaching.send(.rotate(0, 1), shell)
        #expect(moved == .accepted, "\(moved.code)")
        let changed: String = try AmethystEscapeTest.digest(shell)
        #expect(changed != digest)
        #expect(presenter.mirror.hintLevel == 0, "a move hides the hint")
        #expect(presenter.mirror.hintText == nil)

        // The next press starts again at level 1 for the new play.
        let after: AmethystEscapeExperienceCore = try Teaching.core(shell)
        presenter.showHint()
        let first: AmethystEscapeHint = try #require(after.hint(level: 1))
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == first.text)
    }

    /// Following the level-3 hint from the opening of level 1 wins within the budget.
    @Test func followingExactHintsWins() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: AmethystEscapePresenter = shell.presenter
        let budget: Int = try Teaching.core(shell).play.level.budget
        var followed: Int = 0
        for _ in 0..<budget {
            let before: AmethystEscapeExperienceCore = try Teaching.core(shell)
            guard before.play.stage == .playing else { break }
            presenter.showHint()
            presenter.showHint()
            presenter.showHint()
            #expect(presenter.mirror.hintLevel == 3)
            let hint: AmethystEscapeHint = try #require(before.hint(level: 3))
            #expect(presenter.mirror.hintText == hint.text)
            let action: AmethystEscapeAction = try #require(hint.action, "move \(followed + 1): \(hint.text)")
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "move \(followed + 1): \(result.code)")
            followed += 1
        }
        let end: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(end.play.stage == .won, "following exact hints wins (\(followed) moves)")
        #expect(followed <= budget)
        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 0, "a won play has no hint")
        #expect(presenter.mirror.hintText == nil)
    }

    /// Spending the budget with turns fails with the Q5 budget text; Undo returns to playing; Retry restarts the level
    /// with zero moves.
    @Test func budgetFailureUndoAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: AmethystEscapePresenter = shell.presenter
        #expect(presenter.mirror.failureText == nil)
        let budget: Int = try Teaching.core(shell).play.level.budget
        let sent: Int = try Teaching.spendBudget(shell)
        #expect(sent == budget)

        let failed: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        #expect(failed.play.failure == .budget)
        let explanation: AmethystEscapeFailureExplanation = try #require(failed.failureExplanation)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == explanation.text)
        let level: AmethystEscapeLevel = failed.play.level
        let pearl: AmethystEscapePocket = failed.play.crystal.pearl
        let written: String = "The moves ran out: \(budget) of \(budget) spent and the pearl is in "
            + "\(level.shellName(pearl.shell)), \(level.sectorName(pearl.sector)). " + Teaching.advice
        #expect(shown == written, "\(shown)")
        #expect(presenter.mirror.status.hasPrefix("Failed: "), "\(presenter.mirror.status)")
        let text: String = presenter.describe(failed)
        #expect(text.contains(explanation.text), "\(text)")

        // The hint of a failed play is the failed advice.
        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == AmethystEscapeHint.failedText)

        // Undo takes back the last turn: playing again, the explanation and the hint gone.
        let undone: ActionResult = presenter.undoMove(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(afterUndo.play.moves == budget - 1)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        // Fail again, then Retry in campaign is `level.select` of the level with zero moves.
        let again: ActionResult = Teaching.send(.rotate(0, budget % 2 == 0 ? -1 : 1), shell)
        #expect(again == .accepted, "\(again.code)")
        let failedAgain: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(failedAgain.play.stage == .failed)
        #expect(presenter.mirror.failureText != nil)
        let action: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(action.control == "level.select")
        #expect(action.values == [1])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(fresh.levelNumber == 1)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.stage == .playing)
        #expect(fresh.play.moves == 0)
        #expect(fresh.play.records.isEmpty, "Retry gives a fresh play")
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.moves == 0)
    }

    /// A locked level is refused with `r02-g07.locked` and shown; an impossible date is refused with `r02-g07.date`;
    /// the daily level of 2026-01-01 opens in daily mode and Retry keeps its date; Practice raises the budget to 60;
    /// Campaign returns.
    @Test func pickerRefusalAndModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: AmethystEscapePresenter = shell.presenter
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.pickedLevel == 1)
        let opening: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(presenter.mirror.budget == opening.play.level.budget)
        let digest: String = try AmethystEscapeTest.digest(shell)

        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(locked == .rejected(.rule(code: AmethystEscapeExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g07.locked"))
        let message: String = try #require(presenter.mirror.message, "the refusal is shown")
        #expect(!message.isEmpty)
        #expect(presenter.refusalLog.last == locked.code)
        let unchanged: String = try AmethystEscapeTest.digest(shell)
        #expect(unchanged == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 1)

        // An impossible date is refused.
        let impossible: DateComponents = DateComponents(year: 2027, month: 2, day: 29)
        #expect(AmethystEscapePresenter.dateValues(impossible) == [2027, 2, 29])
        let refused: ActionResult = presenter.playDaily(port: shell.port, date: impossible)
        #expect(refused == .rejected(.rule(code: AmethystEscapeExperienceRule.date)), "\(refused.code)")
        #expect(refused.code.contains("r02-g07.date"))
        #expect(presenter.mirror.message != nil, "the date refusal is shown")
        #expect(presenter.mirror.mode == .campaign)
        let afterRefusal: String = try AmethystEscapeTest.digest(shell)
        #expect(afterRefusal == digest, "a refused date changes nothing")

        // The daily level of 2026-01-01.
        let date: DateComponents = DateComponents(year: 2026, month: 1, day: 1)
        #expect(AmethystEscapePresenter.dateValues(date) == [2026, 1, 1])
        let dailyNumber: Int = try #require(AmethystEscapeProgress.dailyLevel(year: 2026, month: 1, day: 1))
        #expect(dailyNumber == 1, "day 0 × 61 mod 100 + 1")
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .daily(level: dailyNumber))
        #expect(presenter.mirror.levelNumber == dailyNumber)
        #expect(presenter.mirror.moves == 0)
        let dailyCore: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == dailyNumber)
        #expect(dailyCore.mode == .daily(level: dailyNumber))
        let later: DateComponents = DateComponents(year: 2026, month: 1, day: 5)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 1, 1], "Retry keeps the date that opened the daily level")

        // Practice: the budget is 60.
        let practice: ActionResult = presenter.send("mode.practice", [], port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        let practiceCore: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(practiceCore.mode == .practice)
        #expect(practiceCore.play.level.budget == 60)
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == 60)
        #expect(presenter.mirror.budget == AmethystEscapeExperienceCore.practiceBudget)
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)

        // Campaign returns.
        let campaign: ActionResult = presenter.send("mode.campaign", [], port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        #expect(presenter.mirror.mode == .campaign)
        let back: AmethystEscapeExperienceCore = try Teaching.core(shell)
        #expect(back.mode == .campaign)
        #expect(back.progress.isOpen(back.levelNumber))
        #expect(back.play.level.budget == opening.play.level.budget)
        #expect(presenter.mirror.budget == back.play.level.budget)
        #expect(presenter.mirror.frontier == 1, "neither daily nor practice opens a level")
    }
}
#endif
