// HarmonicBridgesTeachingTests — feature 415 (R02-G12-05) T-R02G1205-005 (FR-R02G1205-001 … 005)
// Clarifications Q1–Q5. On the simulator, through the one app's session host: the presenter's teaching and progression
// surface, modelled on feature 405's Echo Cartographer teaching tests. The mirror is read after `describe` (the shell
// describes the core after every accepted action; the tests describe again themselves so the presenter's latest core is
// the current one). Tutorial: level 1 (seed 0) opens with the `tune` instruction, which the description names; the
// certified tunings move it to `test` (they bridge every step, so level 1 goes straight on from `tune` to `test` per the
// Core); Dismiss through the port hides it and leaves the digest alone (the tutorial step is never in the digest).
// Hints: `showHint()` shows "Finding a hint…" while the detached search runs (awaited by a bounded poll of
// `hintSearch`, at most 5 s), then reveals levels 1, 2, 3 in that order with the texts of
// `HarmonicBridgesHints.hint(level:play:)` of the current play; the digest never changes, the description names the
// hint, any accepted action hides it on the next describe, and following the level-3 hint's action through the port
// again and again wins level 1. Failure: a test from the opening pegs breaks the crossing, and tunings until the budget
// is spent fail on the last move; both show the explanation of `HarmonicBridgesFailureExplanation` in
// `mirror.failureText`, which the description names; Undo returns to playing and hides it; Retry in campaign is
// `level.select` of the level and starts it fresh. Win: the certified solution of level 1 records 3 stars in the mirror,
// the goal names band 1 and the best stars, and level 2 opens; Play level selects it; a locked level 3 is refused with
// `r02-g12.locked`, shown in words in the panel. Modes: Daily of 2026-11-23 opens
// `HarmonicBridgesProgress.dailyLevel(year: 2026, month: 11, day: 23)` and Retry keeps that date; an impossible date is
// refused with `r02-g12.date` in words; Practice raises the budget to 60; Campaign returns to the frontier. Synthetic
// data, no wall-clock assertion; each test short. Test data uses explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import HarmonicBridgesCore
import Testing
@testable import HarmonicBridgesExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Harmonic Bridges teaching tests.
@MainActor
enum HarmonicBridgesTeaching {
    typealias Shell = ExperienceShell<HarmonicBridgesPresenter>
    typealias Core = HarmonicBridgesExperienceCore

    /// The fixed calendar day of the daily test.
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 11, day: 23)

    /// The longest wait for a hint search, in polls of ``pollMilliseconds``.
    static let pollLimit: Int = 500
    static let pollMilliseconds: Int = 10

    /// The most hinted actions followed before giving up on a win (bounded by the budget, at most 60).
    static let followLimit: Int = 64

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn) and describes the opening so the presenter holds
    /// the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await HarmonicBridgesTest.open(session, seed: seed,
                                                              size: CGSize(width: 360, height: 240))
        _ = try describe(shell)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try HarmonicBridgesTest.core(shell)
    }

    /// Describes the current core of `shell` (the shell's path after an accepted action) and returns the description.
    @discardableResult
    static func describe(_ shell: Shell) throws -> String {
        let current: Core = try HarmonicBridgesTest.core(shell)
        return shell.presenter.describe(current)
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: HarmonicBridgesPresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(for: .milliseconds(pollMilliseconds))
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: HarmonicBridgesPresenter) async throws {
        presenter.showHint()
        let finished: Bool = try await awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")
    }

    /// Sends the kernel action `action` through the presenter (the path of the controls), describes the result and
    /// returns it.
    @discardableResult
    static func send(_ action: HarmonicBridgesAction, _ shell: Shell) throws -> ActionResult {
        let entry: (control: String, values: [Double]) = HarmonicBridgesTest.control(action)
        let result: ActionResult = shell.presenter.send(entry.control, entry.values, port: shell.port)
        _ = try describe(shell)
        return result
    }

    /// Sends `control` with `values` through the presenter, describes the result and returns it.
    @discardableResult
    static func send(_ control: String, _ values: [Double], _ shell: Shell) throws -> ActionResult {
        let result: ActionResult = shell.presenter.send(control, values, port: shell.port)
        _ = try describe(shell)
        return result
    }

    /// The first string of `play` that is not locked.
    static func freeString(_ play: HarmonicBridgesPlay) -> Int? {
        for index in 0..<play.level.strings.count where !play.level.strings[index].locked { return index }
        return nil
    }

    /// Tunes the first free string back and forth between two pegs other than its current one until the budget is
    /// spent; returns the tunings accepted.
    static func tuneUntilSpent(_ shell: Shell) throws -> Int {
        let opening: Core = try core(shell)
        guard let string = freeString(opening.play) else { return 0 }
        let current: Int = opening.play.pegs[string]
        let first: Int = current % 12 + 1
        let second: Int = (current + 1) % 12 + 1
        var made: Int = 0
        while made < 60 {
            let now: Core = try core(shell)
            guard now.play.stage == .playing else { break }
            let peg: Int = made % 2 == 0 ? first : second
            let result: ActionResult = try send(.tune(string, peg), shell)
            #expect(result == .accepted, "tuning \(made + 1): \(result.code)")
            guard result == .accepted else { break }
            made += 1
        }
        return made
    }
}

@MainActor
@Suite(.serialized) struct HarmonicBridgesTeachingTests {
    typealias Teaching = HarmonicBridgesTeaching
    typealias Core = HarmonicBridgesExperienceCore

    /// Level 1 opens with the tutorial's first instruction, which the description names; the certified tunings move it
    /// to the test step; Dismiss through the port hides it and leaves the digest unchanged.
    @Test func tutorialShownAdvancedAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: HarmonicBridgesPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .tune)
        #expect(opening.play.stage == .playing)
        let first: String = HarmonicBridgesTutorialStep.tune.text
        #expect(presenter.mirror.instruction == first, "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.certifiedActions == opening.certifiedActions)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let text: String = presenter.describe(opening)
        #expect(text.contains("Tutorial: " + first), "\(text)")

        // The certified tunings bridge every step: level 1 goes straight on to the test step.
        let tunings: [HarmonicBridgesAction] = try HarmonicBridgesTest.certifiedTunings(1)
        #expect(!tunings.isEmpty, "level 1 has certified tunings")
        var index: Int = 0
        for action in tunings {
            index += 1
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "tuning \(index): \(result.code)")
        }
        let tuned: Core = try Teaching.core(shell)
        #expect(tuned.play.report.goalReachedInEveryStep)
        #expect(tuned.tutorial == .test)
        let third: String = HarmonicBridgesTutorialStep.test.text
        #expect(presenter.mirror.instruction == third, "\(presenter.mirror.instruction ?? "nil")")
        let tunedText: String = try Teaching.describe(shell)
        #expect(tunedText.contains("Tutorial: " + third), "\(tunedText)")
        let digest: String = try HarmonicBridgesTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let after: String = try Teaching.describe(shell)
        let dismissed: Core = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        #expect(!after.contains("Tutorial:"), "\(after)")
        #expect(try HarmonicBridgesTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// "Finding a hint…" shows while the search runs; three hints reveal levels 1, 2, 3 with the texts of
    /// `HarmonicBridgesHints.hint(level:play:)`; the digest never changes; the description names the hint; an accepted
    /// action hides it; following the level-3 hint's action again and again wins level 1.
    @Test func hintLevelsAndFollowingHintsWins() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: HarmonicBridgesPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try HarmonicBridgesTest.digest(shell)

        // The first press starts the search: the panel reads "Finding a hint…" until it ends.
        presenter.showHint()
        #expect(presenter.hintSearch != nil, "the search runs off the main actor")
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == HarmonicBridgesPresenter.searchingText)
        let finished: Bool = try await Teaching.awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")

        // The three levels on the opening play.
        for level in 1...3 {
            if level > 1 { try await Teaching.pressHint(presenter) }
            let want: HarmonicBridgesHint = try #require(HarmonicBridgesHints.hint(level: level, play: opening.play))
            #expect(want.kind != .stuck, "level 1 has a plan from its opening")
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(presenter.mirror.hintText != HarmonicBridgesPresenter.searchingText)
            let now: String = try HarmonicBridgesTest.digest(shell)
            #expect(now == digest, "hint \(level) leaves the state alone")
        }
        // The exact texts of clarification Q1 for the opening's first action.
        let opener: HarmonicBridgesHint = try #require(HarmonicBridgesHints.hint(level: 1, play: opening.play))
        if case .tune(let string, let peg)? = opener.action {
            #expect(opener.at(level: 1).text == HarmonicBridgesHint.tuneText)
            #expect(opener.at(level: 2).text == "Tune string \(string)")
            #expect(opener.at(level: 3).text == "Tune string \(string) to peg \(peg)")
        } else {
            #expect(opener.at(level: 1).text == HarmonicBridgesHint.testText)
            #expect(opener.at(level: 3).text == HarmonicBridgesHint.testDetailText)
        }
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 3, "the hint stops at level 3")
        let third: HarmonicBridgesHint = try #require(HarmonicBridgesHints.hint(level: 3, play: opening.play))
        let text: String = try Teaching.describe(shell)
        #expect(text.contains("Hint: " + third.text), "\(text)")

        // Follow the level-3 hint's action until the play is won.
        var followed: Int = 0
        while followed < Teaching.followLimit {
            let current: Core = try Teaching.core(shell)
            guard current.play.stage == .playing else { break }
            if followed > 0 {
                for _ in 1...3 { try await Teaching.pressHint(presenter) }
            }
            let hint: HarmonicBridgesHint = try #require(HarmonicBridgesHints.hint(level: 3, play: current.play))
            #expect(hint.kind != .stuck, "action \(followed + 1): \(hint.text)")
            #expect(presenter.mirror.hintLevel == 3)
            #expect(presenter.mirror.hintText == hint.text,
                    "action \(followed + 1): \(presenter.mirror.hintText ?? "nil")")
            let action: HarmonicBridgesAction = try #require(hint.action)
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "action \(followed + 1): \(result.code)")
            guard result == .accepted else { break }
            followed += 1
            #expect(presenter.mirror.hintLevel == 0, "a change of the play hides the hint")
            #expect(presenter.mirror.hintText == nil)
        }
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won, "following hints wins level 1 (\(followed) actions made)")
        #expect(try HarmonicBridgesTest.digest(shell) != digest)
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 0, "a won play has no hint")
        #expect(presenter.mirror.hintText == nil)
    }

    /// A test from the opening pegs breaks the crossing: the explanation is shown and named in the description; the
    /// failed hint is the advice; Undo returns to playing; Retry starts the level fresh.
    @Test func brokenTestExplainedUndoAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: HarmonicBridgesPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(!opening.play.report.goalReachedInEveryStep, "level 1 does not open bridged")
        #expect(presenter.mirror.failureText == nil)
        let tested: ActionResult = try Teaching.send(.test, shell)
        #expect(tested == .accepted, "\(tested.code)")
        let text: String = try Teaching.describe(shell)
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let explanation: HarmonicBridgesFailureExplanation = try #require(HarmonicBridgesFailureExplanation(
            play: failed.play))
        if case .broken = explanation.failure {} else { Issue.record("a broken test: \(explanation.failure)") }
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == explanation.text)
        #expect(shown.hasPrefix("Action 1 (the test) broke the crossing in step "), "\(shown)")
        #expect(shown.hasSuffix(" " + HarmonicBridgesFailureExplanation.advice), "\(shown)")
        #expect(presenter.mirror.status.hasPrefix("Failed: "), "\(presenter.mirror.status)")
        #expect(text.contains(explanation.text), "\(text)")

        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == HarmonicBridgesHint.failedText)

        let undone: ActionResult = presenter.undoAction(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        _ = try Teaching.describe(shell)
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        let retryAction: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(retryAction.control == "level.select")
        #expect(retryAction.values == [1])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        _ = try Teaching.describe(shell)
        let fresh: Core = try Teaching.core(shell)
        #expect(fresh.levelNumber == 1)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.stage == .playing)
        #expect(fresh.play.records.isEmpty, "Retry gives a fresh play")
        #expect(fresh.play.actionsLeft == fresh.play.level.budget)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.actionsLeft == presenter.mirror.budget)
    }

    /// Tunings until the budget is spent fail on the last move with the budget explanation, shown and described.
    @Test func budgetFailureExplained() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: HarmonicBridgesPresenter = shell.presenter
        let budget: Int = try Teaching.core(shell).play.level.budget
        let made: Int = try Teaching.tuneUntilSpent(shell)
        #expect(made == budget, "every move is a tuning (\(made) of \(budget))")
        let text: String = try Teaching.describe(shell)
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let explanation: HarmonicBridgesFailureExplanation = try #require(HarmonicBridgesFailureExplanation(
            play: failed.play))
        if case .budget = explanation.failure {} else { Issue.record("the budget: \(explanation.failure)") }
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == explanation.text)
        #expect(shown.hasPrefix("Action \(budget) (a tuning of string "), "\(shown)")
        #expect(shown.contains("spent the last move without a win"), "\(shown)")
        #expect(shown.hasSuffix(" " + HarmonicBridgesFailureExplanation.advice), "\(shown)")
        #expect(text.contains(explanation.text), "\(text)")
        #expect(presenter.mirror.actionsLeft == 0)
    }

    /// The certified solution of level 1 wins in the campaign: 3 stars in the mirror, the goal and the description, and
    /// level 2 opens; Play level picks it; a locked level is refused with `r02-g12.locked`, shown in words.
    @Test func campaignWinRecordsStarsAndOpensTheNextLevel() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: HarmonicBridgesPresenter = shell.presenter
        #expect(presenter.mirror.goalLabel.contains("band 1 of 5"), "\(presenter.mirror.goalLabel)")
        #expect(!presenter.mirror.goalLabel.contains("best"), "\(presenter.mirror.goalLabel)")
        let actions: [HarmonicBridgesAction] = try HarmonicBridgesTest.certifiedActions(1)
        #expect(!actions.isEmpty, "level 1 has a certified solution")
        var index: Int = 0
        for action in actions {
            index += 1
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "action \(index): \(result.code)")
        }
        let text: String = try Teaching.describe(shell)
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.progress.solved[1]?.stars == 3)
        #expect(presenter.mirror.stars[1] == 3)
        #expect(presenter.mirror.goalLabel.contains("band 1 of 5"), "\(presenter.mirror.goalLabel)")
        #expect(presenter.mirror.goalLabel.contains("best 3 of 3 stars"), "\(presenter.mirror.goalLabel)")
        #expect(text.contains("Stars: 3 of 3."), "\(text)")
        #expect(text.contains(presenter.mirror.goalLabel), "\(text)")
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.instruction == nil, "the end of the level ends the tutorial")
        #expect(won.progress.frontier == 2)
        #expect(presenter.mirror.frontier == 2)

        // Play level: level 2 is open.
        presenter.mirror.pickedLevel = 2
        let pick: ActionResult = try Teaching.send("level.select", [Double(presenter.mirror.pickedLevel)], shell)
        #expect(pick == .accepted, "\(pick.code)")
        let picked: Core = try Teaching.core(shell)
        #expect(picked.levelNumber == 2)
        #expect(picked.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.pickedLevel == 2)
        #expect(presenter.mirror.stars[1] == 3, "the stars of level 1 stay")
        #expect(!presenter.mirror.goalLabel.contains("best"), "level 2 is not won: \(presenter.mirror.goalLabel)")

        // Level 3 is locked: refused, and the panel says so in words.
        let digest: String = try HarmonicBridgesTest.digest(shell)
        let locked: ActionResult = try Teaching.send("level.select", [3], shell)
        #expect(locked == .rejected(.rule(code: HarmonicBridgesExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g12.locked"))
        let words: String = HarmonicBridgesMirror.refusalText(code: locked.code)
        #expect(words != HarmonicBridgesMirror.refusalText(code: "r02-g12.unknown"),
                "the locked level has its own words: \(words)")
        #expect(!words.contains("r02-g12"), "\(words)")
        #expect(presenter.mirror.message == "That change was refused: \(words).",
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == locked.code)
        #expect(try HarmonicBridgesTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 2)
    }

    /// Daily of 2026-11-23 opens its level in daily mode and Retry keeps the date; an impossible date is refused in
    /// words; Practice raises the budget to 60; Campaign returns to the frontier.
    @Test func dailyPracticeAndCampaignModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: HarmonicBridgesPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.mode == .campaign)

        // An impossible date: refused with r02-g12.date, in words, nothing changed.
        let digest: String = try HarmonicBridgesTest.digest(shell)
        let impossible: ActionResult = presenter.playDaily(port: shell.port,
                                                           date: DateComponents(year: 2026, month: 2, day: 30))
        _ = try Teaching.describe(shell)
        #expect(impossible == .rejected(.rule(code: HarmonicBridgesExperienceRule.date)), "\(impossible.code)")
        let dateWords: String = HarmonicBridgesMirror.refusalText(code: impossible.code)
        #expect(dateWords != HarmonicBridgesMirror.refusalText(code: "r02-g12.unknown"),
                "an impossible date has its own words: \(dateWords)")
        #expect(presenter.mirror.message == "That change was refused: \(dateWords).",
                "\(presenter.mirror.message ?? "nil")")
        #expect(try HarmonicBridgesTest.digest(shell) == digest)
        #expect(presenter.mirror.mode == .campaign)

        // Daily of 2026-11-23.
        let date: DateComponents = Teaching.dailyDate
        let number: Int = try #require(HarmonicBridgesProgress.dailyLevel(year: 2026, month: 11, day: 23))
        #expect(HarmonicBridgesPresenter.dateValues(date) == [2026, 11, 23])
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        _ = try Teaching.describe(shell)
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .daily(level: number))
        #expect(presenter.mirror.levelNumber == number)
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == number)
        #expect(dailyCore.mode == .daily(level: number))
        #expect(dailyCore.play.records.isEmpty)
        let band: Int = HarmonicBridgesProgress.band(of: number)
        #expect(presenter.mirror.goalLabel.contains("band \(band) of 5"), "\(presenter.mirror.goalLabel)")
        let later: DateComponents = DateComponents(year: 2026, month: 11, day: 25)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 11, 23], "Retry keeps the date that opened the daily level")
        let retried: ActionResult = presenter.retry(port: shell.port, date: later)
        #expect(retried == .accepted, "\(retried.code)")
        _ = try Teaching.describe(shell)
        #expect(presenter.mirror.levelNumber == number)
        #expect(presenter.mirror.mode == .daily(level: number))

        // Practice: the budget is 60.
        let practice: ActionResult = try Teaching.send("mode.practice", [], shell)
        #expect(practice == .accepted, "\(practice.code)")
        let practiceCore: Core = try Teaching.core(shell)
        #expect(practiceCore.mode == .practice)
        #expect(practiceCore.play.level.budget == 60)
        #expect(practiceCore.play.actionsLeft == 60)
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == 60)
        #expect(presenter.mirror.budget == Core.practiceBudget)
        #expect(presenter.mirror.actionsLeft == 60)
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)

        // Campaign returns: the daily level is not open, so the frontier (level 1).
        let campaign: ActionResult = try Teaching.send("mode.campaign", [], shell)
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
