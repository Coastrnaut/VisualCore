// ChronoConstellatorTeachingTests — feature 355 (R02-G06-05) T-R02G0605-005 (FR-R02G0605-001 … 005; clarifications
// Q1–Q5).
// On the simulator, through the one app's session host: the presenter's teaching and progression surface. Tutorial:
// level 1 (seed 0) shows the shift instruction; Dismiss through the presenter hides it and leaves the digest alone (the
// tutorial step is never in the digest). Hints: `showHint()` reveals levels 1, 2, 3 in that order with the core's
// `hint(level:)` texts, a fourth press stays at level 3, the digest never changes, and any change of the play (a step)
// hides the hint once the presenter describes the new play. Failure: stepping an unedited level to its tick limit
// fails; the mirror shows the core's explanation, which ends with "Undo the last change, rewind or retry the level.",
// the hint of a failed play is the failed advice, and the description carries the explanation; Undo and Rewind each
// return the play to playing, and Retry in campaign is `level.select` of the level and gives a fresh play. Picker and
// modes: a locked level is refused with `r02-g06.locked` and the refusal is shown in the mirror's message; the daily
// level of 2026-11-21 is `ChronoConstellatorProgress.dailyLevel(2026, 11, 21)` and `retryAction` keeps that date; the
// impossible date 2027-02-29 is refused with `r02-g06.date`; practice raises the budget to 20; campaign returns.
// Synthetic data, no sleep, no wall-clock assertion; each test short. Test data uses explicit types and plain loops
// (CI type-check rule).
#if os(iOS)
import ChronoConstellatorCore
import CoreGraphics
import Foundation
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the teaching tests.
@MainActor
enum ChronoConstellatorTeaching {
    typealias Shell = ExperienceShell<ChronoConstellatorPresenter>

    /// The advice every failure text ends with (clarification Q5).
    static let advice: String = ChronoConstellatorFailureExplanation.advice

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn) and describes the opening so the presenter
    /// holds the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await ChronoConstellatorTest.open(session, seed: seed,
                                                                 size: CGSize(width: 360, height: 240))
        let opening: ChronoConstellatorExperienceCore = try ChronoConstellatorTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> ChronoConstellatorExperienceCore {
        try ChronoConstellatorTest.core(shell)
    }

    /// Whether level `number`, stepped to its tick limit with no edits on a bare core, fails.
    static func failsWithoutEdits(_ number: Int) throws -> Bool {
        var core: ChronoConstellatorExperienceCore = try ChronoConstellatorExperienceCore.opening(number: number)
        let limit: Int = core.play.level.tickLimit
        _ = core.apply(ExperienceAction(control: "time.step", values: [Double(limit)], step: 0))
        return core.play.stage == .failed
    }

    /// The first seed of 0 … 9 whose level fails when stepped out unedited (level 1 first); nil when none does.
    static func failingSeed() throws -> UInt64? {
        for seed in 0..<UInt64(10) {
            let number: Int = ChronoConstellatorExperienceCore.levelNumber(forSeed: seed)
            let fails: Bool = try failsWithoutEdits(number)
            if fails { return seed }
        }
        return nil
    }

    /// Steps the level of `shell` to its tick limit through the presenter (one `time.step`; it stops at the first
    /// deciding tick).
    static func runOut(_ shell: Shell) throws {
        let limit: Int = try core(shell).play.level.tickLimit
        let result: ActionResult = shell.presenter.send("time.step", [Double(limit)], port: shell.port)
        #expect(result == .accepted, "step \(limit): \(result.code)")
    }
}

@MainActor
@Suite(.serialized) struct ChronoConstellatorTeachingTests {
    typealias Teaching = ChronoConstellatorTeaching

    /// Level 1 opens with the shift instruction; Dismiss hides it and leaves the digest unchanged.
    @Test func tutorialOnLevelOneAndDismiss() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: ChronoConstellatorPresenter = shell.presenter
        let opening: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .shift)
        #expect(presenter.mirror.instruction == ChronoConstellatorTutorialStep.shift.text,
                "\(presenter.mirror.instruction ?? "nil")")
        let digest: String = try ChronoConstellatorTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let dismissed: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        let after: String = try ChronoConstellatorTest.digest(shell)
        #expect(after == digest, "the tutorial step is not in the digest")
    }

    /// Three hints reveal what, where and exactly with the core's texts; a fourth stays at level 3; the digest never
    /// changes; a change of the play hides the hint.
    @Test func hintLevelsThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: ChronoConstellatorPresenter = shell.presenter
        let opening: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(opening.play.stage == .playing)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try ChronoConstellatorTest.digest(shell)
        let third: ChronoConstellatorHint = try #require(opening.hint(level: 3))

        for level in 1...3 {
            presenter.showHint()
            let want: ChronoConstellatorHint = try #require(opening.hint(level: level))
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            let now: String = try ChronoConstellatorTest.digest(shell)
            #expect(now == digest, "hint \(level) leaves the state alone")
        }
        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 3, "a fourth press stays at level 3")
        #expect(presenter.mirror.hintText == third.text)
        let still: String = try ChronoConstellatorTest.digest(shell)
        #expect(still == digest)

        // A change of the play (one tick replayed): the description of the new play hides the hint.
        let step: ActionResult = presenter.send("time.step", [1], port: shell.port)
        #expect(step == .accepted, "\(step.code)")
        let changed: String = try ChronoConstellatorTest.digest(shell)
        #expect(changed != digest)
        #expect(presenter.mirror.hintLevel == 0, "a change of the play hides the hint")
        #expect(presenter.mirror.hintText == nil)

        // The next press starts again at level 1 for the new play.
        let moved: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        presenter.showHint()
        let first: ChronoConstellatorHint = try #require(moved.hint(level: 1))
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == first.text)
    }

    /// Stepping an unedited level out fails with the core's explanation; Undo and Rewind return to playing; Retry in
    /// campaign is `level.select` of the level and gives a fresh play.
    @Test func failureUndoRewindAndRetry() async throws {
        let found: UInt64? = try Teaching.failingSeed()
        let seed: UInt64 = try #require(found, "some level of 1 … 10 fails when stepped out without edits")
        let number: Int = ChronoConstellatorExperienceCore.levelNumber(forSeed: seed)

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: seed)
        let presenter: ChronoConstellatorPresenter = shell.presenter
        #expect(presenter.mirror.failureText == nil)
        try Teaching.runOut(shell)

        let failed: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let want: String = try #require(failed.failureExplanation?.text)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == want)
        #expect(shown.hasSuffix(Teaching.advice), "\(shown)")
        #expect(presenter.mirror.status.hasPrefix("Failed: "), "\(presenter.mirror.status)")

        // The hint of a failed play is the failed advice.
        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == ChronoConstellatorHint.failedText)

        // The description carries the explanation.
        let text: String = presenter.describe(failed)
        #expect(text.contains(want), "\(text)")

        // Undo takes back the step: the play is playing again and the explanation and the hint are gone.
        let undone: ActionResult = presenter.undo(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(afterUndo.play.tick == 0)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        // Fail again, then Rewind returns to tick 0 with the timeline kept.
        try Teaching.runOut(shell)
        let failedAgain: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(failedAgain.play.stage == .failed)
        #expect(presenter.mirror.failureText != nil)
        let rewound: ActionResult = presenter.rewind(port: shell.port)
        #expect(rewound == .accepted, "\(rewound.code)")
        let afterRewind: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(afterRewind.play.stage == .playing)
        #expect(afterRewind.play.tick == 0)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.tick == 0)

        // Fail a third time, then Retry in campaign is `level.select` of the level.
        try Teaching.runOut(shell)
        let failedThird: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(failedThird.play.stage == .failed)
        let action: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(action.control == "level.select")
        #expect(action.values == [Double(number)])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(fresh.levelNumber == number)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.stage == .playing)
        #expect(fresh.play.spent == 0)
        #expect(fresh.play.records.isEmpty, "Retry gives a fresh play")
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.spent == 0)
        #expect(presenter.mirror.tick == 0)
    }

    /// A locked level is refused with `r02-g06.locked` and shown; the daily level of 2026-11-21 opens in daily mode and
    /// Retry keeps its date; an impossible date is refused with `r02-g06.date`; practice raises the budget to 20;
    /// campaign returns.
    @Test func pickerRefusalAndModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: ChronoConstellatorPresenter = shell.presenter
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.pickedLevel == 1)
        #expect(presenter.mirror.stars.isEmpty)
        let opening: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(presenter.mirror.budget == opening.play.level.budget)
        #expect(presenter.mirror.smallest == opening.certifiedSmallest)
        #expect(presenter.mirror.spent == 0)
        let digest: String = try ChronoConstellatorTest.digest(shell)

        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(locked == .rejected(.rule(code: ChronoConstellatorExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g06.locked"))
        let message: String = try #require(presenter.mirror.message, "the refusal is shown")
        // Feature 356: refusals are shown in words.
        #expect(message == ChronoConstellatorFeedbackPlan.refusalText(code: locked.code), "\(message)")
        #expect(message == "That level is not open yet.")
        let unchanged: String = try ChronoConstellatorTest.digest(shell)
        #expect(unchanged == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 1)

        // An impossible date is refused.
        let impossible: DateComponents = DateComponents(year: 2027, month: 2, day: 29)
        #expect(ChronoConstellatorPresenter.dateValues(impossible) == [2027, 2, 29])
        let refused: ActionResult = presenter.playDaily(port: shell.port, date: impossible)
        #expect(refused == .rejected(.rule(code: ChronoConstellatorExperienceRule.date)), "\(refused.code)")
        #expect(refused.code.contains("r02-g06.date"))
        let dateMessage: String = try #require(presenter.mirror.message, "the date refusal is shown")
        #expect(dateMessage == "That date cannot be used.", "\(dateMessage)")
        #expect(presenter.mirror.mode == .campaign)
        let afterRefusal: String = try ChronoConstellatorTest.digest(shell)
        #expect(afterRefusal == digest, "a refused date changes nothing")

        // The daily level of 2026-11-21.
        let date: DateComponents = DateComponents(year: 2026, month: 11, day: 21)
        #expect(ChronoConstellatorPresenter.dateValues(date) == [2026, 11, 21])
        let dailyNumber: Int = try #require(ChronoConstellatorProgress.dailyLevel(year: 2026, month: 11, day: 21))
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .daily(level: dailyNumber))
        #expect(presenter.mirror.levelNumber == dailyNumber)
        #expect(presenter.mirror.spent == 0)
        let dailyCore: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == dailyNumber)
        #expect(dailyCore.mode == .daily(level: dailyNumber))
        let later: DateComponents = DateComponents(year: 2026, month: 11, day: 25)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 11, 21], "Retry keeps the date that opened the daily level")

        // Practice: the budget is 20.
        let practice: ActionResult = presenter.send("mode.practice", [], port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == 20)
        #expect(presenter.mirror.budget == ChronoConstellatorExperienceCore.practiceBudget)
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)

        // Campaign returns.
        let campaign: ActionResult = presenter.send("mode.campaign", [], port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        #expect(presenter.mirror.mode == .campaign)
        let back: ChronoConstellatorExperienceCore = try Teaching.core(shell)
        #expect(back.progress.isOpen(back.levelNumber))
        #expect(presenter.mirror.budget == back.play.level.budget)
        #expect(presenter.mirror.frontier == 1, "neither daily nor practice opens a level")
    }
}
#endif
