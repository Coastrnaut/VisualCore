// NocturneGardenTeachingTests — feature 385 (R02-G09-05) T-R02G0905-005 (FR-R02G0905-001 … 005; clarifications Q1–Q5).
// On the simulator, through the one app's session host: the presenter's teaching and progression surface, modelled on
// feature 375's Faceted Forge teaching tests. The mirror is read after `describe` (the shell describes the core after
// every accepted action). Tutorial: level 1 (seed 0) opens with the `plant` instruction, which the description names;
// Dismiss hides it and leaves the digest alone (the tutorial step is never in the digest). Hints: `showHint()` reveals
// levels 1, 2, 3 in that order with the texts of `NocturneGardenHints.hint(level:play:)` of the current play (the search
// runs off the main actor: the test awaits `hintSearch`), the digest never changes, the description names the hint, any
// change of the play hides it, and following the level-3 hint's move through the port again and again wins level 1
// within its budget. Failure: a budget failure (sun moves alternating between two allowed elevations on an empty bed
// until the budget is spent, on the first level of seeds 0 … 29 with two elevations) shows the Q5 explanation in
// `mirror.failureText`, which the description names; the hint of a failed play is the failed text; Undo returns to
// playing and hides it; Retry in campaign is `level.select` of the level and starts it again with no moves. Win: the
// certified solution of level 1 records its stars in the mirror and opens level 2; Play level selects it; a locked
// level is refused with `r02-g09.locked`, shown in the panel and kept in `refusalLog`. Modes: Practice raises the budget
// to 40 and a practice win records nothing; Daily of 2026-05-17 opens `NocturneGardenProgress.dailyLevel` of that day
// and Retry keeps that date; Campaign returns to the frontier. Synthetic data, no sleep, no wall-clock assertion; each
// test short. Test data uses explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import NocturneGardenCore
import Testing
@testable import NocturneGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Nocturne Garden teaching tests.
@MainActor
enum NocturneGardenTeaching {
    typealias Shell = ExperienceShell<NocturneGardenPresenter>
    typealias Core = NocturneGardenExperienceCore

    /// The seeds searched for a level with a wanted property (seed = level − 1).
    static let searchedSeeds: Int = 30

    /// The fixed calendar day of the daily test.
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 5, day: 17)

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn) and describes the opening so the presenter holds
    /// the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await NocturneGardenTest.open(session, seed: seed, size: CGSize(width: 360, height: 240))
        let opening: Core = try NocturneGardenTest.core(shell)
        _ = shell.presenter.describe(opening)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try NocturneGardenTest.core(shell)
    }

    /// Presses Hint and waits for the search it started (the search runs off the main actor; a cached play reveals at
    /// once).
    static func pressHint(_ presenter: NocturneGardenPresenter) async {
        presenter.showHint()
        await presenter.hintSearch?.value
    }

    /// Sends the kernel action `action` through the presenter (the path of the controls) and returns the result.
    @discardableResult
    static func send(_ action: NocturneGardenAction, _ shell: Shell) -> ActionResult {
        let entry: (control: String, values: [Double]) = NocturneGardenTest.control(action)
        return shell.presenter.send(entry.control, entry.values, port: shell.port)
    }

    /// The first level of seeds 0 … ``searchedSeeds`` − 1 with at least two allowed sun elevations, with sun moves
    /// alternating between two of them on its empty bed that spend the whole budget and fail it by budget (checked on a
    /// bare core: every move accepted, the play `playing` until the last); nil when none.
    static func budgetFailure() throws -> (level: Int, actions: [NocturneGardenAction])? {
        for seed in 0..<UInt64(searchedSeeds) {
            let number: Int = Core.levelNumber(forSeed: seed)
            let level: NocturneGardenLevel = try Core.level(number: number)
            let allowed: [Int] = level.elevations.sorted()
            guard allowed.count >= 2 else { continue }
            var actions: [NocturneGardenAction] = []
            var current: Int = level.sun
            for _ in 0..<level.budget {
                var next: Int = allowed[0]
                for elevation in allowed where elevation != current {
                    next = elevation
                    break
                }
                actions.append(.sun(next))
                current = next
            }
            var core: Core = try Core.opening(number: number)
            var fits: Bool = true
            for (index, action) in actions.enumerated() {
                let result: ActionResult = core.apply(NocturneGardenTest.experienceAction(action))
                let last: Bool = index == actions.count - 1
                if result != .accepted || (!last && core.play.stage != .playing) {
                    fits = false
                    break
                }
            }
            guard fits, core.play.stage == .failed, case .budget? = core.play.failure else { continue }
            return (number, actions)
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct NocturneGardenTeachingTests {
    typealias Teaching = NocturneGardenTeaching
    typealias Core = NocturneGardenExperienceCore

    /// Level 1 opens with the `plant` instruction, which the description names; Dismiss hides it and leaves the digest
    /// unchanged.
    @Test func tutorialShownAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: NocturneGardenPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .plant)
        #expect(opening.play.stage == .playing)
        let plant: String = NocturneGardenTutorialStep.plant.text
        #expect(presenter.mirror.instruction == plant, "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.smallest == opening.certifiedSmallest)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.failureText == nil)
        let text: String = presenter.describe(opening)
        #expect(text.contains("Tutorial: " + plant), "\(text)")
        let digest: String = try NocturneGardenTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let dismissed: Core = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        #expect(!presenter.describe(dismissed).contains("Tutorial:"))
        let after: String = try NocturneGardenTest.digest(shell)
        #expect(after == digest, "the tutorial step is not in the digest")
    }

    /// Three hints reveal levels 1, 2, 3 with the texts of `NocturneGardenHints.hint(level:play:)`; the digest never
    /// changes; the description names the hint; a move hides it; following the level-3 hint's move again and again
    /// wins level 1 within its budget.
    @Test func hintLevelsAndFollowingHintsWins() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: NocturneGardenPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try NocturneGardenTest.digest(shell)

        // The three levels on the opening play.
        for level in 1...3 {
            await Teaching.pressHint(presenter)
            let want: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: level, play: opening.play))
            #expect(want.kind == .move, "level 1 has a plan from its opening")
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(presenter.mirror.hintText != NocturneGardenPresenter.searchingText)
            let now: String = try NocturneGardenTest.digest(shell)
            #expect(now == digest, "hint \(level) leaves the state alone")
        }
        let third: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: 3, play: opening.play))
        let text: String = presenter.describe(opening)
        #expect(text.contains("Hint: " + third.text), "\(text)")

        // Follow the level-3 hint's move until the play is won, within the budget.
        let budget: Int = opening.play.level.budget
        var followed: Int = 0
        while followed < budget {
            let current: Core = try Teaching.core(shell)
            guard current.play.stage == .playing else { break }
            if followed > 0 {
                for _ in 1...3 { await Teaching.pressHint(presenter) }
            }
            let hint: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: 3, play: current.play))
            #expect(hint.kind == .move, "move \(followed + 1): \(hint.text)")
            #expect(presenter.mirror.hintLevel == 3)
            #expect(presenter.mirror.hintText == hint.text, "move \(followed + 1): \(presenter.mirror.hintText ?? "nil")")
            let action: NocturneGardenAction = try #require(hint.action)
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "move \(followed + 1): \(result.code)")
            followed += 1
            #expect(presenter.mirror.hintLevel == 0, "a change of the play hides the hint")
            #expect(presenter.mirror.hintText == nil)
            let changed: String = try NocturneGardenTest.digest(shell)
            #expect(changed != digest)
        }
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won, "following hints wins level 1 within \(budget) moves (\(followed) made)")
        #expect(won.play.moves <= budget)
        await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 0, "a won play has no hint")
        #expect(presenter.mirror.hintText == nil)
    }

    /// Spending the budget with sun moves on an empty bed fails with the Q5 budget text, named in the description; the
    /// failed hint is the advice; Undo returns to playing; Retry starts the level again.
    @Test func budgetFailureExplainedUndoAndRetry() async throws {
        let found = try #require(try Teaching.budgetFailure(), "a budget failure within the searched seeds")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: UInt64(found.level - 1))
        let presenter: NocturneGardenPresenter = shell.presenter
        #expect(try Teaching.core(shell).levelNumber == found.level)
        #expect(presenter.mirror.failureText == nil)
        let budget: Int = try Teaching.core(shell).play.level.budget
        #expect(found.actions.count == budget)
        for (index, action) in found.actions.enumerated() {
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "sun move \(index + 1): \(result.code)")
        }
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let explanation: NocturneGardenFailureExplanation = try #require(NocturneGardenFailureExplanation(
            play: failed.play))
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == explanation.text)
        #expect(shown.hasPrefix("The moves ran out: \(budget) of \(budget) spent with a match of "), "\(shown)")
        #expect(shown.hasSuffix(" " + NocturneGardenFailureExplanation.advice), "\(shown)")
        #expect(presenter.mirror.status.hasPrefix("Failed: "), "\(presenter.mirror.status)")
        let text: String = presenter.describe(failed)
        #expect(text.contains(explanation.text), "\(text)")

        await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == NocturneGardenHint.failedText)

        let undone: ActionResult = presenter.undoMove(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(afterUndo.play.moves == budget - 1)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        let last: NocturneGardenAction = try #require(found.actions.last)
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
        #expect(fresh.play.moves == 0)
        #expect(fresh.play.records.isEmpty, "Retry gives a fresh play")
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.moves == 0)
    }

    /// The certified solution of level 1 wins in the campaign: its stars are in the mirror and the description, and
    /// level 2 opens; Play level picks it; a locked level is refused with `r02-g09.locked`, shown and logged.
    @Test func campaignWinRecordsStarsAndOpensTheNextLevel() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: NocturneGardenPresenter = shell.presenter
        let actions: [NocturneGardenAction] = try NocturneGardenTest.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        for (index, action) in actions.enumerated() {
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "move \(index + 1): \(result.code)")
        }
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "the instruction is gone after the win")
        let stars: Int = NocturneGardenProgress.stars(movesMade: NocturneGardenProgress.movesMade(won.play),
                                                      smallest: won.certifiedSmallest)
        #expect(won.progress.solved[1]?.stars == stars)
        #expect(presenter.mirror.stars[1] == stars)
        let text: String = presenter.describe(won)
        #expect(text.contains("Stars: \(stars) of 3."), "\(text)")
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
        #expect(presenter.mirror.moves == 0)
        #expect(presenter.mirror.stars[1] == stars, "the stars of level 1 stay")
        #expect(presenter.mirror.instruction == NocturneGardenTutorialStep.plant.text, "level 2 carries the tutorial")
        #expect(presenter.refusalLog.isEmpty)

        // Level 3 is locked.
        let digest: String = try NocturneGardenTest.digest(shell)
        let locked: ActionResult = presenter.send("level.select", [3], port: shell.port)
        #expect(locked == .rejected(.rule(code: NocturneGardenExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g09.locked"))
        #expect(presenter.mirror.message?.contains("r02-g09.locked") == true,
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == locked.code)
        #expect(presenter.refusalLog.count == 1)
        #expect(try NocturneGardenTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 2)

        // An accepted pick clears the shown refusal.
        let back: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(back == .accepted, "\(back.code)")
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.levelNumber == 1)
    }

    /// Practice raises the budget to 40 and a practice win records nothing; Daily of 2026-05-17 opens that day's level
    /// and Retry keeps the date; Campaign returns to the frontier.
    @Test func practiceDailyAndCampaignModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: NocturneGardenPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.budget == opening.play.level.budget)

        // Practice: the budget is 40; a win records nothing.
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
        let actions: [NocturneGardenAction] = try NocturneGardenTest.certifiedActions(1)
        for (index, action) in actions.enumerated() {
            let result: ActionResult = Teaching.send(action, shell)
            #expect(result == .accepted, "practice move \(index + 1): \(result.code)")
        }
        let practiceWon: Core = try Teaching.core(shell)
        #expect(practiceWon.play.stage == .won)
        #expect(practiceWon.progress.solved.isEmpty, "practice records nothing")
        #expect(practiceWon.progress.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.frontier == 1)

        // Daily of 2026-05-17.
        let date: DateComponents = Teaching.dailyDate
        #expect(NocturneGardenPresenter.dateValues(date) == [2026, 5, 17])
        let dailyNumber: Int = try #require(NocturneGardenProgress.dailyLevel(year: 2026, month: 5, day: 17))
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .daily(level: dailyNumber))
        #expect(presenter.mirror.levelNumber == dailyNumber)
        #expect(presenter.mirror.moves == 0)
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == dailyNumber)
        #expect(dailyCore.mode == .daily(level: dailyNumber))
        #expect(dailyCore.play.level.budget == (try Core.level(number: dailyNumber)).budget)
        #expect(presenter.mirror.smallest == dailyCore.certifiedSmallest)
        let later: DateComponents = DateComponents(year: 2026, month: 5, day: 20)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 5, 17], "Retry keeps the date that opened the daily level")
        let retried: ActionResult = presenter.retry(port: shell.port, date: later)
        #expect(retried == .accepted, "\(retried.code)")
        #expect(presenter.mirror.levelNumber == dailyNumber)
        #expect(presenter.mirror.mode == .daily(level: dailyNumber))

        // Campaign returns (the daily level is open only when it is level 1; otherwise the frontier).
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
