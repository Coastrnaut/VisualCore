// BackwardsAuroraTeachingTests — feature 395 (R02-G10-05) T-R02G1005-005 (FR-R02G1005-001 … 005; SC-R02G1005-001 … 004;
// clarifications Q1–Q5). On the simulator, through the one app's session host: the presenter's teaching and progression
// surface, modelled on feature 385's Nocturne Garden teaching tests. The mirror is read after `describe` (the shell
// describes the core after every accepted action). Tutorial: level 1 (seed 0) opens with the `mark` instruction, which
// the description names; Dismiss through the port hides it and leaves the digest alone (the tutorial step is never in
// the digest). Hints: `showHint()` shows "Finding a hint…" while the detached search runs (awaited here by a bounded
// poll of `hintSearch`, at most 5 s), then reveals levels 1, 2, 3 in that order with the texts of
// `BackwardsAuroraHints.hint(level:play:)` of the current play; the digest never changes, the description names the
// hint, any change of the play hides it, and following the level-3 hint's reversal through the port again and again
// wins level 1 within its budget. Failure: a budget failure (one section of the first level of 1 … 10 whose repeated
// reversal spends the whole budget without a tear or a win, checked on a bare core) shows the Q5 explanation in
// `mirror.failureText`, which the description names; the hint of a failed play is the failed text; Undo returns to
// playing and hides it; Retry in campaign is `level.select` of the level and starts it again with no reversals. Win:
// the certified solution of level 1 records 3 stars in the mirror, the goal names band 1 and the best stars, and level 2
// opens; Play level selects it; a locked level is refused with `r02-g10.locked`, shown in the panel and kept in
// `refusalLog`. Modes: Practice raises the budget to 40; Daily of 2026-01-02 opens level 74 (days 1 × 73 mod 100 + 1)
// and Retry keeps that date; the impossible 2027-02-29 is refused with `r02-g10.date`; Campaign returns to the frontier.
// Synthetic data, no wall-clock assertion; each test short. Test data uses explicit types and plain loops (CI
// type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import BackwardsAuroraCore
import Testing
@testable import BackwardsAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Backwards Aurora teaching tests.
@MainActor
enum BackwardsAuroraTeaching {
    typealias Shell = ExperienceShell<BackwardsAuroraPresenter>
    typealias Core = BackwardsAuroraExperienceCore

    /// The levels searched for a budget failure.
    static let searchedLevels: ClosedRange<Int> = 1...10

    /// The fixed calendar day of the daily test and its level: (1 × 73) mod 100 + 1 = 74.
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 1, day: 2)
    static let dailyNumber: Int = 74

    /// The longest wait for a hint search, in polls of ``pollNanoseconds``.
    static let pollLimit: Int = 500
    static let pollNanoseconds: UInt64 = 10_000_000

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn) and describes the opening so the presenter holds
    /// the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await BackwardsAuroraTest.open(session, seed: seed, size: CGSize(width: 360, height: 240))
        let opening: Core = try BackwardsAuroraTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try BackwardsAuroraTest.core(shell)
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: BackwardsAuroraPresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(nanoseconds: pollNanoseconds)
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: BackwardsAuroraPresenter) async throws {
        presenter.showHint()
        let finished: Bool = try await awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")
    }

    /// Sends the kernel action `action` through the presenter (the path of the controls) and returns the result.
    @discardableResult
    static func send(_ action: BackwardsAuroraAction, _ shell: Shell) -> ActionResult {
        let entry: (control: String, values: [Double]) = BackwardsAuroraTest.control(action)
        return shell.presenter.send(entry.control, entry.values, port: shell.port)
    }

    /// The first level of ``searchedLevels`` with a section whose reversal, repeated budget times from the opening
    /// (the wave alternating between two states), is accepted every time, keeps the play `playing` until the last and
    /// fails it by budget on the last (checked on a bare core: sections by start ascending, then length ascending); nil
    /// when none.
    static func budgetFailure() throws -> (level: Int, action: BackwardsAuroraAction, budget: Int)? {
        for number in searchedLevels {
            let opening: Core = try Core.opening(number: number)
            let n: Int = opening.play.wave.count
            let lengths: ClosedRange<Int> = opening.play.level.sectionLengths
            let budget: Int = opening.play.level.budget
            for start in 0..<n {
                for length in lengths {
                    let end: Int = start + length - 1
                    guard end < n else { continue }
                    let action: BackwardsAuroraAction = .reverse(start, end)
                    var core: Core = opening
                    var fits: Bool = true
                    for index in 0..<budget {
                        let result: ActionResult = core.apply(BackwardsAuroraTest.experienceAction(action))
                        let last: Bool = index == budget - 1
                        if result != .accepted || (!last && core.play.stage != .playing) {
                            fits = false
                            break
                        }
                    }
                    guard fits, core.play.stage == .failed, case .budget? = core.play.failure else { continue }
                    return (number, action, budget)
                }
            }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct BackwardsAuroraTeachingTests {
    typealias Teaching = BackwardsAuroraTeaching
    typealias Core = BackwardsAuroraExperienceCore

    /// Level 1 opens with the `mark` instruction, which the description names; Dismiss through the port hides it and
    /// leaves the digest unchanged.
    @Test func tutorialShownAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: BackwardsAuroraPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .mark)
        #expect(opening.play.stage == .playing)
        let mark: String = BackwardsAuroraTutorialStep.mark.text
        #expect(presenter.mirror.instruction == mark, "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.smallest == opening.certifiedSmallest)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let text: String = presenter.describe(opening)
        #expect(text.contains("Tutorial: " + mark), "\(text)")
        let digest: String = try BackwardsAuroraTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let dismissed: Core = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        let after: String = presenter.describe(dismissed)
        #expect(!after.contains("Tutorial:"), "\(after)")
        #expect(try BackwardsAuroraTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// "Finding a hint…" shows while the search runs; three hints reveal levels 1, 2, 3 with the texts of
    /// `BackwardsAuroraHints.hint(level:play:)`; the digest never changes; the description names the hint; a reversal
    /// hides it; following the level-3 hint's reversal again and again wins level 1 within its budget.
    @Test func hintLevelsAndFollowingHintsWins() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: BackwardsAuroraPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try BackwardsAuroraTest.digest(shell)

        // The first press starts the search: the panel reads "Finding a hint…" until it ends.
        presenter.showHint()
        #expect(presenter.hintSearch != nil, "the search runs off the main actor")
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == BackwardsAuroraPresenter.searchingText)
        let finished: Bool = try await Teaching.awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")

        // The three levels on the opening play.
        for level in 1...3 {
            if level > 1 { try await Teaching.pressHint(presenter) }
            let want: BackwardsAuroraHint = try #require(BackwardsAuroraHints.hint(level: level, play: opening.play))
            #expect(want.kind == .reverse, "level 1 has a plan from its opening")
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(presenter.mirror.hintText != BackwardsAuroraPresenter.searchingText)
            let now: String = try BackwardsAuroraTest.digest(shell)
            #expect(now == digest, "hint \(level) leaves the state alone")
        }
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 3, "the hint stops at level 3")
        let third: BackwardsAuroraHint = try #require(BackwardsAuroraHints.hint(level: 3, play: opening.play))
        let text: String = presenter.describe(opening)
        #expect(text.contains("Hint: " + third.text), "\(text)")

        // Follow the level-3 hint's reversal until the play is won, within the budget.
        let budget: Int = opening.play.level.budget
        var followed: Int = 0
        while followed < budget {
            let current: Core = try Teaching.core(shell)
            guard current.play.stage == .playing else { break }
            if followed > 0 {
                for _ in 1...3 { try await Teaching.pressHint(presenter) }
            }
            let hint: BackwardsAuroraHint = try #require(BackwardsAuroraHints.hint(level: 3, play: current.play))
            #expect(hint.kind == .reverse, "reversal \(followed + 1): \(hint.text)")
            #expect(presenter.mirror.hintLevel == 3)
            #expect(presenter.mirror.hintText == hint.text,
                    "reversal \(followed + 1): \(presenter.mirror.hintText ?? "nil")")
            let action: BackwardsAuroraAction = try #require(hint.action)
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "reversal \(followed + 1): \(result.code)")
            followed += 1
            #expect(presenter.mirror.hintLevel == 0, "a change of the play hides the hint")
            #expect(presenter.mirror.hintText == nil)
            let changed: String = try BackwardsAuroraTest.digest(shell)
            #expect(changed != digest)
        }
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won, "following hints wins level 1 within \(budget) reversals (\(followed) made)")
        #expect(won.play.spent <= budget)
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 0, "a won play has no hint")
        #expect(presenter.mirror.hintText == nil)
    }

    /// Spending the budget with one repeated reversal fails with the Q5 budget text, named in the description; the
    /// failed hint is the advice; Undo returns to playing; Retry starts the level again.
    @Test func budgetFailureExplainedUndoAndRetry() async throws {
        let found = try #require(try Teaching.budgetFailure(), "a budget failure within the searched levels")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: UInt64(found.level - 1))
        let presenter: BackwardsAuroraPresenter = shell.presenter
        #expect(try Teaching.core(shell).levelNumber == found.level)
        #expect(presenter.mirror.failureText == nil)
        let budget: Int = try Teaching.core(shell).play.level.budget
        #expect(budget == found.budget)
        for index in 0..<budget {
            let result: ActionResult = Teaching.send(found.action, shell)
            #expect(result == .accepted, "reversal \(index + 1): \(result.code)")
        }
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let explanation: BackwardsAuroraFailureExplanation = try #require(BackwardsAuroraFailureExplanation(
            play: failed.play))
        #expect(explanation.failure == .budget)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == explanation.text)
        #expect(shown.hasPrefix("The reversals ran out: \(budget) of \(budget) spent with "), "\(shown)")
        #expect(shown.hasSuffix(" " + BackwardsAuroraFailureExplanation.advice), "\(shown)")
        #expect(presenter.mirror.status.hasPrefix("Failed: "), "\(presenter.mirror.status)")
        let text: String = presenter.describe(failed)
        #expect(text.contains(explanation.text), "\(text)")

        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == BackwardsAuroraHint.failedText)

        let undone: ActionResult = presenter.undoReversal(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(afterUndo.play.spent == budget - 1)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        let again: ActionResult = Teaching.send(found.action, shell)
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
        #expect(fresh.play.spent == 0)
        #expect(fresh.play.records.isEmpty, "Retry gives a fresh play")
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.spent == 0)
    }

    /// The certified solution of level 1 wins in the campaign: 3 stars in the mirror, the goal and the description, and
    /// level 2 opens; Play level picks it; a locked level is refused with `r02-g10.locked`, shown and logged.
    @Test func campaignWinRecordsStarsAndOpensTheNextLevel() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: BackwardsAuroraPresenter = shell.presenter
        #expect(presenter.mirror.goalLabel
                    == "Goal: fold the aurora back in \(presenter.mirror.smallest) reversals; band 1 of 5",
                "\(presenter.mirror.goalLabel)")
        let actions: [BackwardsAuroraAction] = try BackwardsAuroraTest.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        for (index, action) in actions.enumerated() {
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "reversal \(index + 1): \(result.code)")
        }
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "the instruction is gone after the win")
        let stars: Int = BackwardsAuroraProgress.stars(reversalsMade: BackwardsAuroraProgress.reversalsMade(won.play),
                                                       smallest: won.certifiedSmallest)
        #expect(stars == 3, "the certified solution makes the smallest reversal count")
        #expect(won.progress.solved[1]?.stars == 3)
        #expect(presenter.mirror.stars[1] == 3)
        #expect(presenter.mirror.goalLabel.contains("band 1 of 5"), "\(presenter.mirror.goalLabel)")
        #expect(presenter.mirror.goalLabel.contains("best 3 of 3 stars"), "\(presenter.mirror.goalLabel)")
        let text: String = presenter.describe(won)
        #expect(text.contains("Stars: 3 of 3."), "\(text)")
        #expect(text.contains(presenter.mirror.goalLabel), "\(text)")
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.failureText == nil)
        #expect(won.progress.frontier == 2)
        #expect(presenter.mirror.frontier == 2)

        // Play level: level 2 is open.
        presenter.mirror.pickedLevel = 2
        let pick: ActionResult = presenter.send("level.select", [Double(presenter.mirror.pickedLevel)],
                                                port: shell.port)
        #expect(pick == .accepted, "\(pick.code)")
        let picked: Core = try Teaching.core(shell)
        #expect(picked.levelNumber == 2)
        #expect(picked.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.pickedLevel == 2)
        #expect(presenter.mirror.spent == 0)
        #expect(presenter.mirror.stars[1] == 3, "the stars of level 1 stay")
        #expect(presenter.mirror.goalLabel.contains("band 1 of 5"), "\(presenter.mirror.goalLabel)")
        #expect(!presenter.mirror.goalLabel.contains("best"), "level 2 is not won: \(presenter.mirror.goalLabel)")
        #expect(presenter.mirror.instruction == BackwardsAuroraTutorialStep.mark.text, "level 2 carries the tutorial")
        #expect(presenter.refusalLog.isEmpty)

        // Level 3 is locked.
        let digest: String = try BackwardsAuroraTest.digest(shell)
        let locked: ActionResult = presenter.send("level.select", [3], port: shell.port)
        #expect(locked == .rejected(.rule(code: BackwardsAuroraExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g10.locked"))
        #expect(presenter.mirror.message?.contains("r02-g10.locked") == true,
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == locked.code)
        #expect(presenter.refusalLog.count == 1)
        #expect(try BackwardsAuroraTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 2)

        // An accepted pick clears the shown refusal.
        let back: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(back == .accepted, "\(back.code)")
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.goalLabel.contains("best 3 of 3 stars"), "\(presenter.mirror.goalLabel)")
    }

    /// Practice raises the budget to 40; Daily of 2026-01-02 opens level 74 and Retry keeps the date; an impossible
    /// date is refused with `r02-g10.date`; Campaign returns to the frontier.
    @Test func practiceDailyAndCampaignModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: BackwardsAuroraPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.budget == opening.play.level.budget)

        // Practice: the budget is 40.
        let practice: ActionResult = presenter.send("mode.practice", [], port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        let practiceCore: Core = try Teaching.core(shell)
        #expect(practiceCore.mode == .practice)
        #expect(practiceCore.levelNumber == 1)
        #expect(practiceCore.play.level.budget == 40)
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == 40)
        #expect(presenter.mirror.budget == Core.practiceBudget)
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)

        // Daily of 2026-01-02: level 74, still locked in the campaign, playable.
        let date: DateComponents = Teaching.dailyDate
        #expect(BackwardsAuroraPresenter.dateValues(date) == [2026, 1, 2])
        #expect(BackwardsAuroraProgress.dailyLevel(year: 2026, month: 1, day: 2) == Teaching.dailyNumber)
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .daily(level: Teaching.dailyNumber))
        #expect(presenter.mirror.levelNumber == Teaching.dailyNumber)
        #expect(presenter.mirror.spent == 0)
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == Teaching.dailyNumber)
        #expect(dailyCore.mode == .daily(level: Teaching.dailyNumber))
        #expect(dailyCore.play.level.budget == (try Core.level(number: Teaching.dailyNumber)).budget)
        #expect(presenter.mirror.smallest == dailyCore.certifiedSmallest)
        #expect(presenter.mirror.goalLabel.contains("band 4 of 5"), "\(presenter.mirror.goalLabel)")
        let later: DateComponents = DateComponents(year: 2026, month: 1, day: 5)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 1, 2], "Retry keeps the date that opened the daily level")
        let retried: ActionResult = presenter.retry(port: shell.port, date: later)
        #expect(retried == .accepted, "\(retried.code)")
        #expect(presenter.mirror.levelNumber == Teaching.dailyNumber)
        #expect(presenter.mirror.mode == .daily(level: Teaching.dailyNumber))

        // An impossible date is refused, shown and logged; the daily level stays.
        let impossible: DateComponents = DateComponents(year: 2027, month: 2, day: 29)
        let refused: ActionResult = presenter.playDaily(port: shell.port, date: impossible)
        #expect(refused == .rejected(.rule(code: BackwardsAuroraExperienceRule.date)), "\(refused.code)")
        #expect(refused.code.contains("r02-g10.date"))
        #expect(presenter.mirror.message?.contains("r02-g10.date") == true, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == refused.code)
        #expect(try Teaching.core(shell).levelNumber == Teaching.dailyNumber)
        let kept: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(kept.values == [2026, 1, 2], "a refused daily keeps the date of the daily level")

        // Campaign returns: level 74 is not open, so the frontier (level 1).
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
        #expect(back.progress.solved.isEmpty)
    }
}
#endif
