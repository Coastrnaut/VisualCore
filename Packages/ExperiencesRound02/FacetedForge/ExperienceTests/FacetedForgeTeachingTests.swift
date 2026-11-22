// FacetedForgeTeachingTests — feature 375 (R02-G08-05) T-R02G0805-005 (FR-R02G0805-001 … 005; clarifications Q1–Q5).
// On the simulator, through the one app's session host: the presenter's teaching and progression surface, modelled on
// feature 365's Amethyst Escape teaching tests. The mirror is read after `describe` (the shell describes the core after
// every accepted action). Tutorial: level 1 (seed 0) opens with the `aim` instruction, which the description names;
// Dismiss hides it and leaves the digest alone (the tutorial step is never in the digest). Hints: `showHint()` reveals
// levels 1, 2, 3 in that order with the core's texts ("Cut the whole crystal", "… in direction x", "… at depth d"), a
// fourth press stays at level 3, the digest never changes, the description names the hint and a cut hides it (the
// level resets). Win: the certified solution of level 1 sent through the presenter moves the tutorial on (aim → match →
// finish → done) and wins with 3 stars, named in the description, and the frontier raised to level 2. Failure: a sliver
// failure (found by the deterministic search of `FacetedForgeTest.sliverFailure()`) and a budget failure (the first
// level of seeds 0 … 29 whose neutral cuts spend the whole budget, `FacetedForgeExperienceCore.neutralCuts`) show the
// Q5 explanation, which the description names; Undo returns to playing and hides it; Retry in campaign is
// `level.select` of the level and starts it again with no cuts. Modes: Practice raises the mirror's budget to 20; an
// impossible date is refused with `r02-g08.date`; Daily of 2026-01-02 opens level 68 ((1 × 67) mod 100 + 1) and Retry
// keeps that date; Campaign returns to the frontier. Picker: Play level sends `level.select` of the picked open level;
// a locked level is refused with `r02-g08.locked`, shown in the panel and kept in `refusalLog`. Synthetic data, no
// sleep, no wall-clock assertion; each test short. Test data uses explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import FacetedForgeCore
import Foundation
import Testing
@testable import FacetedForgeExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the teaching tests.
@MainActor
enum FacetedForgeTeaching {
    typealias Shell = ExperienceShell<FacetedForgePresenter>
    typealias Core = FacetedForgeExperienceCore

    /// Presses Hint and waits for the search it started (T-R02G0805-012: the search runs off the main actor).
    static func pressHint(_ presenter: FacetedForgePresenter) async {
        presenter.showHint()
        await presenter.hintSearch?.value
    }

    /// The seeds searched for a level with a wanted property (seed = level − 1).
    static let searchedSeeds: Int = 30

    /// The advice every failure text ends with (clarification Q5).
    static let advice: String = FacetedForgeFailureExplanation.advice

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn) and describes the opening so the presenter holds
    /// the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await FacetedForgeTest.open(session, seed: seed, size: CGSize(width: 360, height: 240))
        let opening: Core = try FacetedForgeTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try FacetedForgeTest.core(shell)
    }

    /// Sends the kernel action `action` through the presenter (the path of the controls) and returns the result.
    @discardableResult
    static func send(_ action: FacetedForgeAction, _ shell: Shell) -> ActionResult {
        let entry: (control: String, values: [Double]) = FacetedForgeTest.control(action)
        return shell.presenter.send(entry.control, entry.values, port: shell.port)
    }

    /// The hint text of clarification Q1 for `hint` on `play`, written out here independently of
    /// ``FacetedForgeHint/text``; nil for a stuck hint.
    static func expectedText(_ hint: FacetedForgeHint, play: FacetedForgePlay) -> String? {
        guard hint.kind == .cut, let piece = hint.piece, let direction = hint.direction, let depth = hint.depth else {
            return nil
        }
        let share: FacetedForgeFraction = play.shares[piece]
        var name: String = "the whole crystal"
        if share != FacetedForgeFraction.one {
            name = "piece \(piece + 1): \(FacetedForgeLevel.shareText(share)) of the crystal, "
                + "\(play.pieces[piece].faceCount) faces"
        }
        var text: String = "Cut " + name
        if hint.level >= 2 { text += " in direction " + FacetedForgeDirection.all[direction].name }
        if hint.level >= 3 { text += " at depth \(depth)" }
        return text
    }

    /// The first level of seeds 0 … ``searchedSeeds`` − 1 whose neutral cuts spend its whole budget (the last one
    /// failing it by budget), with those cuts; nil when none.
    static func budgetFailure() throws -> (level: Int, actions: [FacetedForgeAction])? {
        for seed in 0..<UInt64(searchedSeeds) {
            let number: Int = Core.levelNumber(forSeed: seed)
            let budget: Int = try Core.level(number: number).budget
            let actions: [FacetedForgeAction] = Core.neutralCuts(level: number, count: budget, endsInFailure: true)
            if actions.count == budget { return (number, actions) }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct FacetedForgeTeachingTests {
    typealias Teaching = FacetedForgeTeaching
    typealias Core = FacetedForgeExperienceCore

    /// Level 1 opens with the `aim` instruction, which the description names; Dismiss hides it and leaves the digest
    /// unchanged.
    @Test func tutorialShownAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: FacetedForgePresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .aim)
        let aim: String = FacetedForgeTutorialStep.aim.text
        #expect(presenter.mirror.instruction == aim, "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.smallest == opening.certifiedSmallest)
        #expect(presenter.mirror.mode == .campaign)
        let text: String = presenter.describe(opening)
        #expect(text.contains("Tutorial: " + aim), "\(text)")
        let digest: String = try FacetedForgeTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let dismissed: Core = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        #expect(!presenter.describe(dismissed).contains("Tutorial:"))
        let after: String = try FacetedForgeTest.digest(shell)
        #expect(after == digest, "the tutorial step is not in the digest")
    }

    /// Three hints reveal levels 1, 2, 3 with the core's texts; a fourth stays at level 3; the digest never changes;
    /// the description names the hint; a cut hides it and the next press starts again at level 1.
    @Test func hintLevelsAndACutHidesTheHint() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: FacetedForgePresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.play.stage == .playing)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try FacetedForgeTest.digest(shell)
        let third: FacetedForgeHint = try #require(opening.hint(level: 3))
        #expect(third.kind == .cut, "level 1 has a plan from its opening")

        for level in 1...3 {
            await Teaching.pressHint(presenter)
            let want: FacetedForgeHint = try #require(opening.hint(level: level))
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            let written: String? = Teaching.expectedText(want, play: opening.play)
            #expect(written != nil)
            #expect(presenter.mirror.hintText == written, "level \(level): Q1 text")
            let now: String = try FacetedForgeTest.digest(shell)
            #expect(now == digest, "hint \(level) leaves the state alone")
        }
        #expect(presenter.mirror.hintText?.hasPrefix("Cut the whole crystal in direction ") == true)
        await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 3, "a fourth press stays at level 3")
        #expect(presenter.mirror.hintText == third.text)
        let text: String = presenter.describe(opening)
        #expect(text.contains("Hint: " + third.text), "\(text)")
        let still: String = try FacetedForgeTest.digest(shell)
        #expect(still == digest)

        // A cut (the hinted one) hides the hint.
        let action: FacetedForgeAction = try #require(third.action)
        let cut: ActionResult = Teaching.send(action, shell)
        #expect(cut == .accepted, "\(cut.code)")
        let changed: String = try FacetedForgeTest.digest(shell)
        #expect(changed != digest)
        #expect(presenter.mirror.hintLevel == 0, "a cut hides the hint")
        #expect(presenter.mirror.hintText == nil)

        // The next press starts again at level 1 for the new play (when the play still has a hint).
        let after: Core = try Teaching.core(shell)
        await Teaching.pressHint(presenter)
        if let first = after.hint(level: 1) {
            #expect(presenter.mirror.hintLevel == 1)
            #expect(presenter.mirror.hintText == first.text)
        } else {
            #expect(presenter.mirror.hintLevel == 0, "a won play has no hint")
        }
    }

    /// The certified solution of level 1 sent through the presenter moves the tutorial on and wins with 3 stars, named
    /// in the description, and the frontier raised to level 2, which can then be picked.
    /// T-R02G0805-012: a press returns at once with "Finding a hint…"; a cut before the search ends discards its result
    /// (the hint belongs to the earlier play), and the next press searches the new play.
    @Test func aHintSearchNeverBlocksAndACutDiscardsIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: FacetedForgePresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        presenter.showHint()
        #expect(presenter.mirror.hintText == FacetedForgePresenter.searchingText || presenter.hintSearch == nil)
        let third: FacetedForgeHint = try #require(opening.hint(level: 3))
        let action: FacetedForgeAction = try #require(third.action)
        let cut: ActionResult = Teaching.send(action, shell)
        #expect(cut == .accepted, "\(cut.code)")
        await presenter.hintSearch?.value
        #expect(presenter.mirror.hintLevel == 0, "the earlier play's hint is not shown")
        #expect(presenter.mirror.hintText == nil)
        let after: Core = try Teaching.core(shell)
        await Teaching.pressHint(presenter)
        if let first = after.hint(level: 1) {
            #expect(presenter.mirror.hintText == first.text)
        } else {
            #expect(presenter.mirror.hintText == nil, "a won play has no hint")
        }
    }

    @Test func winningLevelOneGivesThreeStarsAndOpensLevelTwo() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: FacetedForgePresenter = shell.presenter
        let actions: [FacetedForgeAction] = Core.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        var expected: FacetedForgeTutorialStep = .aim
        for (index, action) in actions.enumerated() {
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "cut \(index + 1): \(result.code)")
            let now: Core = try Teaching.core(shell)
            let ended: Bool = now.play.stage == .won || now.play.stage == .failed
            expected = expected.advanced(afterCut: true, ended: ended)
            #expect(now.tutorial == expected, "cut \(index + 1): \(now.tutorial) != \(expected)")
            if expected == .done {
                #expect(presenter.mirror.instruction == nil)
            } else {
                #expect(presenter.mirror.instruction == expected.text)
            }
        }
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "the instruction is gone after the win")
        let stars: Int = FacetedForgeProgress.stars(cutsMade: FacetedForgeProgress.cutsMade(won.play),
                                                    smallest: won.certifiedSmallest)
        #expect(stars == 3, "the certified solution makes the smallest cut count")
        #expect(won.progress.solved[1]?.stars == 3)
        #expect(presenter.mirror.stars[1] == 3)
        let text: String = presenter.describe(won)
        #expect(text.contains("Stars: 3 of 3."), "\(text)")
        #expect(presenter.mirror.status == "Won")
        await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 0, "a won play has no hint")
        #expect(presenter.mirror.hintText == nil)
        #expect(presenter.mirror.failureText == nil)

        // The frontier rises after a campaign win, and the next level can be picked.
        #expect(won.progress.frontier == 2)
        #expect(presenter.mirror.frontier == 2)
        presenter.mirror.pickedLevel = 2
        let pick: ActionResult = presenter.send("level.select", [Double(presenter.mirror.pickedLevel)],
                                                port: shell.port)
        #expect(pick == .accepted, "\(pick.code)")
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.pickedLevel == 2)
        #expect(presenter.mirror.cuts == 0)
        #expect(presenter.mirror.stars[1] == 3, "the stars of level 1 stay")
    }

    /// A sliver failure shows the Q5 sliver text, named in the description; the failed hint is the advice; Undo
    /// returns to playing; Retry starts the level again.
    @Test func sliverFailureExplainedUndoAndRetry() async throws {
        let found = try #require(try FacetedForgeTest.sliverFailure(), "a sliver failure within levels 1 … 100")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: UInt64(found.level - 1))
        let presenter: FacetedForgePresenter = shell.presenter
        #expect(try Teaching.core(shell).levelNumber == found.level)
        #expect(presenter.mirror.failureText == nil)
        for (index, action) in found.actions.enumerated() {
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "cut \(index + 1): \(result.code)")
        }
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        #expect(failed.play.failure == .sliver(found.piece, found.cut))
        let explanation: FacetedForgeFailureExplanation = try #require(failed.failureExplanation)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == explanation.text)
        let share: FacetedForgeFraction = failed.play.shares[found.piece]
        let written: String = "Cut \(found.cut + 1) left piece \(found.piece + 1) at "
            + FacetedForgeLevel.shareText(share) + " of the crystal, thinner than the sliver limit of "
            + failed.play.level.sliver.text + ". " + Teaching.advice
        #expect(shown == written, "\(shown)")
        #expect(presenter.mirror.status.hasPrefix("Failed: "), "\(presenter.mirror.status)")
        let text: String = presenter.describe(failed)
        #expect(text.contains(explanation.text), "\(text)")

        await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == FacetedForgeHint.failedText)

        let undone: ActionResult = presenter.undoCut(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(afterUndo.play.cuts == found.actions.count - 1)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        let last: FacetedForgeAction = try #require(found.actions.last)
        let again: ActionResult = Teaching.send(last, shell)
        #expect(again == .accepted, "\(again.code)")
        #expect(try Teaching.core(shell).play.stage == .failed)
        #expect(presenter.mirror.failureText != nil)
        let action: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(action.control == "level.select")
        #expect(action.values == [Double(found.level)])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: Core = try Teaching.core(shell)
        #expect(fresh.levelNumber == found.level)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.stage == .playing)
        #expect(fresh.play.cuts == 0)
        #expect(fresh.play.records.isEmpty, "Retry gives a fresh play")
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.cuts == 0)
    }

    /// Spending the budget with neutral cuts fails with the Q5 budget text, named in the description; Undo returns to
    /// playing; Retry starts the level again.
    @Test func budgetFailureExplainedUndoAndRetry() async throws {
        let found = try #require(try Teaching.budgetFailure(), "a budget failure within the searched seeds")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: UInt64(found.level - 1))
        let presenter: FacetedForgePresenter = shell.presenter
        let budget: Int = try Teaching.core(shell).play.level.budget
        #expect(found.actions.count == budget)
        for (index, action) in found.actions.enumerated() {
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "cut \(index + 1): \(result.code)")
        }
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        #expect(failed.play.failure == .budget)
        let explanation: FacetedForgeFailureExplanation = try #require(failed.failureExplanation)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == explanation.text)
        let written: String = "The cuts ran out: \(budget) of \(budget) spent with \(failed.play.pieces.count) "
            + "pieces; the target has \(failed.play.level.target.count). " + Teaching.advice
        #expect(shown == written, "\(shown)")
        let text: String = presenter.describe(failed)
        #expect(text.contains(explanation.text), "\(text)")
        #expect(text.contains("The cut budget ran out"), "\(text)")

        let undone: ActionResult = presenter.undoCut(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(afterUndo.play.cuts == budget - 1)
        #expect(presenter.mirror.failureText == nil)

        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: Core = try Teaching.core(shell)
        #expect(fresh.levelNumber == found.level)
        #expect(fresh.play.stage == .playing)
        #expect(fresh.play.cuts == 0)
        #expect(fresh.play.records.isEmpty)
        #expect(presenter.mirror.failureText == nil)
    }

    /// Practice raises the budget to 20; an impossible date is refused; Daily of 2026-01-02 opens level 68 and Retry
    /// keeps that date; Campaign returns to the frontier.
    @Test func modeControlsReachTheAdapter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: FacetedForgePresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.budget == opening.play.level.budget)

        // Practice: the budget is 20.
        let practice: ActionResult = presenter.send("mode.practice", [], port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        let practiceCore: Core = try Teaching.core(shell)
        #expect(practiceCore.mode == .practice)
        #expect(practiceCore.play.level.budget == 20)
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == 20)
        #expect(presenter.mirror.budget == Core.practiceBudget)
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)

        // An impossible date is refused and shown.
        let digest: String = try FacetedForgeTest.digest(shell)
        let impossible: DateComponents = DateComponents(year: 2027, month: 2, day: 29)
        #expect(FacetedForgePresenter.dateValues(impossible) == [2027, 2, 29])
        let refused: ActionResult = presenter.playDaily(port: shell.port, date: impossible)
        #expect(refused == .rejected(.rule(code: FacetedForgeExperienceRule.date)), "\(refused.code)")
        #expect(refused.code.contains("r02-g08.date"))
        #expect(presenter.mirror.message != nil, "the date refusal is shown")
        #expect(presenter.refusalLog.last == refused.code)
        #expect(try FacetedForgeTest.digest(shell) == digest, "a refused date changes nothing")

        // Daily of 2026-01-02: level 68.
        let date: DateComponents = DateComponents(year: 2026, month: 1, day: 2)
        #expect(FacetedForgePresenter.dateValues(date) == [2026, 1, 2])
        let dailyNumber: Int = try #require(FacetedForgeProgress.dailyLevel(year: 2026, month: 1, day: 2))
        #expect(dailyNumber == 68, "(1 × 67) mod 100 + 1")
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .daily(level: 68))
        #expect(presenter.mirror.levelNumber == 68)
        #expect(presenter.mirror.cuts == 0)
        #expect(presenter.mirror.instruction == nil, "level 68 has no tutorial")
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == 68)
        #expect(dailyCore.mode == .daily(level: 68))
        #expect(presenter.mirror.smallest == dailyCore.certifiedSmallest)
        let later: DateComponents = DateComponents(year: 2026, month: 1, day: 5)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 1, 2], "Retry keeps the date that opened the daily level")
        let retried: ActionResult = presenter.retry(port: shell.port, date: later)
        #expect(retried == .accepted, "\(retried.code)")
        #expect(presenter.mirror.levelNumber == 68)
        #expect(presenter.mirror.mode == .daily(level: 68))

        // Campaign returns (level 68 is not open, so the frontier).
        let campaign: ActionResult = presenter.send("mode.campaign", [], port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        #expect(presenter.mirror.mode == .campaign)
        let back: Core = try Teaching.core(shell)
        #expect(back.mode == .campaign)
        #expect(back.levelNumber == 1)
        #expect(presenter.mirror.levelNumber == 1)
        #expect(back.play.level.budget == opening.play.level.budget)
        #expect(presenter.mirror.budget == back.play.level.budget)
        #expect(presenter.mirror.frontier == 1, "neither daily nor practice opens a level")
    }

    /// Play level sends `level.select` of the picked open level; a locked level is refused with `r02-g08.locked`,
    /// shown in the panel and logged, and changes nothing.
    @Test func playLevelPicksAnOpenLevelAndRefusesALockedOne() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 2)
        let presenter: FacetedForgePresenter = shell.presenter
        #expect(presenter.mirror.levelNumber == 3)
        #expect(presenter.mirror.frontier == 3, "the seed's level and those before it are open")
        #expect(presenter.mirror.pickedLevel == 3)

        presenter.mirror.pickedLevel = 2
        let pick: ActionResult = presenter.send("level.select", [Double(presenter.mirror.pickedLevel)],
                                                port: shell.port)
        #expect(pick == .accepted, "\(pick.code)")
        let picked: Core = try Teaching.core(shell)
        #expect(picked.levelNumber == 2)
        #expect(picked.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.pickedLevel == 2)
        #expect(presenter.mirror.instruction == FacetedForgeTutorialStep.aim.text, "level 2 carries the tutorial")
        #expect(presenter.refusalLog.isEmpty)

        let digest: String = try FacetedForgeTest.digest(shell)
        let locked: ActionResult = presenter.send("level.select", [4], port: shell.port)
        #expect(locked == .rejected(.rule(code: FacetedForgeExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g08.locked"))
        #expect(presenter.mirror.message == FacetedForgeFeedbackPlan.refusalText(code: locked.code), "the refusal is shown in words")
        #expect(presenter.refusalLog.last == locked.code)
        #expect(presenter.refusalLog.count == 1)
        #expect(try FacetedForgeTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 2)

        // An accepted pick clears the shown refusal.
        let back: ActionResult = presenter.send("level.select", [3], port: shell.port)
        #expect(back == .accepted, "\(back.code)")
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.levelNumber == 3)
    }
}
#endif
