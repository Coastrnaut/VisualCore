// MoonlitMechanismTeachingTests — feature 435 (R02-G14-05) T-R02G1405-005 (FR-R02G1405-001 … 005)
// Clarifications Q1–Q5. On the simulator, through the one app's session host: the presenter's teaching and progression
// surface, modelled on feature 425's Acoustic Constellator teaching tests. The mirror is read after `describe` (the
// tests describe the current core themselves after every action so the presenter's latest core is the current one).
// Tutorial: level 1 (seed 0) opens with the `change` instruction (`MoonlitMechanismTutorialStep.change.text`), which the
// description names; an accepted change advances it as `advanced(afterChange:aligned:ended:)` says; Dismiss through the
// port hides it and leaves the digest alone (the tutorial step is never in the digest). Hints: `showHint()` shows
// `MoonlitMechanismPresenter.searchingText` while the detached search runs (awaited by a bounded poll of `hintSearch`,
// at most 5 s), then reveals levels 1, 2, 3 with the texts of `MoonlitMechanismHints.hint(level:play:)` of the current
// play; the digest never changes, the description names the hint, and any accepted action hides it; a won play has no
// hint; a failed play's hint is `MoonlitMechanismHint.failedText`. Failure: a run from the opening of level 1 fails (a
// certified level never wins from its start); the explanation of `MoonlitMechanismFailureExplanation(play:)` is in
// `mirror.explanation` and the description, the short reason in `mirror.failureText`; Undo returns to playing; Retry in
// campaign is `level.select` of the level and starts it fresh; spending the whole budget with turns fails `budget` and
// is explained too. Goal: `mirror.goalLabel` names the certified action count and band 1 of 5; after the certified win
// it adds the best stars (`MoonlitMechanismProgress.stars(actionsSpent:certified:)`). Progression: `level.next` before
// a win is refused with `r02-g14.locked`, shown as `refusalText(code:)` (since feature 436 the feedback plan's words); after the
// win it opens level 2; the picker plays an open level and refuses a locked one. Modes: Daily of 2026-11-23 opens
// `MoonlitMechanismProgress.dailyLevel(year: 2026, month: 11, day: 23)` and Retry keeps that date; an impossible date
// reads the date refusal; Practice raises the budget to 40; Campaign returns to the frontier. Synthetic data, no
// wall-clock assertion; each test short. Explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import MoonlitMechanismCore
import Testing
@testable import MoonlitMechanismExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Moonlit Mechanism teaching tests.
@MainActor
enum MoonlitMechanismTeaching {
    typealias Shell = ExperienceShell<MoonlitMechanismPresenter>
    typealias Core = MoonlitMechanismExperienceCore

    /// The fixed calendar day of the daily test.
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 11, day: 23)

    /// How many times the hint search is polled, and the pause between polls (at most 5 s in all).
    static let pollLimit: Int = 500
    static let pollMilliseconds: Int = 10

    /// What the panel shows for a refusal with reason `code`, from the mirror's own words.
    static func refusalMessage(_ code: String) -> String {
        MoonlitMechanismMirror.refusalText(code: code)   // since feature 436 the feedback plan's words exactly
    }

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn) and describes the opening so the presenter holds
    /// the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await MoonlitMechanismTest.open(session, seed: seed,
                                                               size: CGSize(width: 360, height: 240))
        _ = try describe(shell)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try MoonlitMechanismTest.core(shell)
    }

    /// Describes the current core of `shell` and returns the description.
    @discardableResult
    static func describe(_ shell: Shell) throws -> String {
        let current: Core = try MoonlitMechanismTest.core(shell)
        return shell.presenter.describe(current)
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: MoonlitMechanismPresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(for: .milliseconds(pollMilliseconds))
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: MoonlitMechanismPresenter) async throws {
        presenter.showHint()
        let finished: Bool = try await awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")
    }

    /// Sends the kernel action `action` through the presenter (the path of the controls), describes the result and
    /// returns it.
    @discardableResult
    static func send(_ action: MoonlitMechanismAction, _ shell: Shell) throws -> ActionResult {
        let entry: (control: String, values: [Double]) = MoonlitMechanismTest.control(action)
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

    /// Sends the certified solution of the shell's current level through the presenter; returns the actions accepted.
    @discardableResult
    static func win(_ shell: Shell) throws -> Int {
        let number: Int = try core(shell).levelNumber
        let actions: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedActions(number)
        #expect(!actions.isEmpty, "level \(number) has a certified solution")
        var accepted: Int = 0
        for action in actions {
            let result: ActionResult = try send(action, shell)
            #expect(result == .accepted, "action \(accepted + 1): \(result.code)")
            guard result == .accepted else { break }
            accepted += 1
        }
        return accepted
    }
}

@MainActor
@Suite(.serialized) struct MoonlitMechanismTeachingTests {
    typealias Teaching = MoonlitMechanismTeaching
    typealias Core = MoonlitMechanismExperienceCore

    /// Level 1 opens with the tutorial's first instruction, which the description names; an accepted change advances
    /// it as the Core's step function says; Dismiss hides it and leaves the digest alone.
    @Test func levelOneTutorialShownAdvancedAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .change)
        #expect(opening.play.stage == .playing)
        let first: String = MoonlitMechanismTutorialStep.change.text
        #expect(!first.isEmpty)
        #expect(presenter.mirror.instruction == first, "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.certifiedActions == opening.certifiedActions)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.explanation == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let text: String = presenter.describe(opening)
        #expect(text.hasPrefix("Moonlit Mechanism level 1. "), "\(text)")
        #expect(text.contains("Tutorial: " + first), "\(text)")

        // The first certified move is a change: the step advances as `advanced(afterChange:aligned:ended:)` says.
        let moves: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedMoves(1)
        let move: MoonlitMechanismAction = try #require(moves.first, "level 1 needs at least one change")
        let changed: ActionResult = try Teaching.send(move, shell)
        #expect(changed == .accepted, "\(changed.code)")
        let after: Core = try Teaching.core(shell)
        let want: MoonlitMechanismTutorialStep = MoonlitMechanismTutorialStep.change.advanced(
            afterChange: true, aligned: MoonlitMechanismTutorialStep.isAligned(after.play), ended: false)
        #expect(want != .change && want != .done, "\(want)")
        #expect(after.tutorial == want, "\(after.tutorial)")
        #expect(presenter.mirror.instruction == want.text, "\(presenter.mirror.instruction ?? "nil")")
        let changedText: String = try Teaching.describe(shell)
        #expect(changedText.contains("Tutorial: " + want.text), "\(changedText)")
        let digest: String = try MoonlitMechanismTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let dismissedText: String = try Teaching.describe(shell)
        let dismissed: Core = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        #expect(!dismissedText.contains("Tutorial:"), "\(dismissedText)")
        #expect(try MoonlitMechanismTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// The searching text shows while the detached search runs; three hints reveal levels 1, 2, 3 with the texts of
    /// `MoonlitMechanismHints.hint(level:play:)`; the digest never changes; the description names the hint; an accepted
    /// action (the hinted one) hides it.
    @Test func hintLevelsOnTheCertifiedOpening() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let digest: String = try MoonlitMechanismTest.digest(shell)

        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.hintSearch != nil, "the search runs off the main actor")
        #expect(presenter.mirror.hintText == MoonlitMechanismPresenter.searchingText)
        let finished: Bool = try await Teaching.awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")

        for level in 1...3 {
            if level > 1 { try await Teaching.pressHint(presenter) }
            let want: MoonlitMechanismHint = try #require(MoonlitMechanismHints.hint(level: level, play: opening.play))
            #expect(want.kind != .stuck, "level 1 has a plan from its opening")
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(presenter.mirror.hintText != MoonlitMechanismPresenter.searchingText)
            #expect(try MoonlitMechanismTest.digest(shell) == digest, "hint \(level) leaves the state alone")
        }
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 3, "the hint stops at level 3")
        let third: MoonlitMechanismHint = try #require(MoonlitMechanismHints.hint(level: 3, play: opening.play))
        let text: String = try Teaching.describe(shell)
        #expect(text.contains("Hint: " + third.text), "\(text)")

        // Any change of the play hides the hint: follow the hinted action.
        let action: MoonlitMechanismAction = try #require(third.action)
        let result: ActionResult = try Teaching.send(action, shell)
        #expect(result == .accepted, "\(result.code)")
        #expect(presenter.mirror.hintLevel == 0, "a change of the play hides the hint")
        #expect(presenter.mirror.hintText == nil)
        #expect(presenter.hintSearch == nil)
        let after: String = try Teaching.describe(shell)
        #expect(!after.contains("Hint:"), "\(after)")

        // The next press starts again at level 1 for the new play.
        try await Teaching.pressHint(presenter)
        let current: Core = try Teaching.core(shell)
        let fresh: MoonlitMechanismHint = try #require(MoonlitMechanismHints.hint(level: 1, play: current.play))
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == fresh.text, "\(presenter.mirror.hintText ?? "nil")")
    }

    /// A won play has no hint: after the certified win, Hint shows nothing.
    @Test func wonPlayHasNoHint() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        let actions: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedActions(1)
        #expect(try Teaching.win(shell) == actions.count)
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(MoonlitMechanismHints.hint(level: 1, play: won.play) == nil)
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 0, "a won play has no hint")
        #expect(presenter.mirror.hintText == nil)
        let text: String = try Teaching.describe(shell)
        #expect(!text.contains("Hint:"), "\(text)")
    }

    /// A run from the opening of level 1 fails: the explanation is shown and named in the description, the failed
    /// play's hint is the advice; Undo returns to playing; Retry starts the level fresh.
    @Test func failedRunExplainedUndoAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        #expect(presenter.mirror.explanation == nil)
        let ran: ActionResult = try Teaching.send(.run, shell)
        #expect(ran == .accepted, "\(ran.code)")
        let text: String = try Teaching.describe(shell)
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed, "\(failed.play.stage)")
        #expect(failed.play.failure != nil, "a certified level never wins from its start")
        let explanation: String = try #require(MoonlitMechanismFailureExplanation(play: failed.play)?.text)
        #expect(presenter.mirror.explanation == explanation, "\(presenter.mirror.explanation ?? "nil")")
        #expect(explanation.hasPrefix("Action 1 (the run)"), "\(explanation)")
        #expect(explanation.hasSuffix(" " + MoonlitMechanismFailureExplanation.advice), "\(explanation)")
        let reason: String = try #require(MoonlitMechanismMirror.failureText(failed.play.failure))
        #expect(presenter.mirror.failureText == reason, "\(presenter.mirror.failureText ?? "nil")")
        #expect(presenter.mirror.status == "Failed: " + reason, "\(presenter.mirror.status)")
        #expect(text.contains(explanation), "\(text)")
        #expect(text.hasSuffix(" " + MoonlitMechanismPresenter.finishedMessage + "."), "\(text)")
        #expect(presenter.mirror.instruction == nil, "the end of the level ends the tutorial")

        // The failed play's hint is the advice.
        try await Teaching.pressHint(presenter)
        let advice: MoonlitMechanismHint = try #require(MoonlitMechanismHints.hint(level: 1, play: failed.play))
        #expect(advice.kind == .stuck)
        #expect(advice.text == MoonlitMechanismHint.failedText)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == advice.text, "\(presenter.mirror.hintText ?? "nil")")

        let undone: ActionResult = presenter.undoAction(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        _ = try Teaching.describe(shell)
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(presenter.mirror.explanation == nil)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintText == nil, "undo changes the play and hides the hint")

        // Fail again, then Retry: level.select of the level in campaign, a fresh play.
        let again: ActionResult = try Teaching.send(.run, shell)
        #expect(again == .accepted, "\(again.code)")
        #expect(presenter.mirror.explanation != nil)
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
        #expect(fresh.tutorial == .change, "a fresh level 1 shows the tutorial again")
        #expect(presenter.mirror.explanation == nil)
        #expect(presenter.mirror.actionsLeft == presenter.mirror.budget)
    }

    /// Spending the whole budget with turns fails `budget`; the explanation names the last action; Undo returns to
    /// playing with one action left; Retry restarts the level.
    @Test func spentBudgetExplainedUndoAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        let budget: Int = try Teaching.core(shell).play.level.budget
        #expect(budget >= 1)
        var accepted: Int = 0
        for index in 0..<budget {
            let result: ActionResult = try Teaching.send(.turn(1), shell)
            #expect(result == .accepted, "turn \(index + 1): \(result.code)")
            guard result == .accepted else { break }
            accepted += 1
        }
        #expect(accepted == budget)
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        #expect(failed.play.failure == .budget(budget - 1), "\(String(describing: failed.play.failure))")
        let explanation: String = try #require(MoonlitMechanismFailureExplanation(play: failed.play)?.text)
        #expect(presenter.mirror.explanation == explanation, "\(presenter.mirror.explanation ?? "nil")")
        #expect(explanation.hasPrefix("Action \(budget) ("
                                      + MoonlitMechanismFailureExplanation.describe(.turn(1)) + ")"), "\(explanation)")
        #expect(explanation.hasSuffix(" " + MoonlitMechanismFailureExplanation.advice), "\(explanation)")
        let text: String = try Teaching.describe(shell)
        #expect(text.contains(explanation), "\(text)")

        let undone: ActionResult = presenter.undoAction(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        _ = try Teaching.describe(shell)
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(afterUndo.play.actionsLeft == 1)
        #expect(presenter.mirror.explanation == nil)

        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        _ = try Teaching.describe(shell)
        let fresh: Core = try Teaching.core(shell)
        #expect(fresh.levelNumber == 1)
        #expect(fresh.play.records.isEmpty)
        #expect(fresh.play.actionsLeft == budget)
        #expect(presenter.mirror.explanation == nil)
    }

    /// `level.next` before a win is refused with `r02-g14.locked` in words; the goal names band 1; the certified win
    /// records its stars, the goal adds the best stars, the description names them, and `level.next` then opens level 2.
    @Test func goalStarsAndNextLevel() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let goal: String = presenter.mirror.goalLabel
        #expect(goal.contains(" \(opening.certifiedActions) actions"), "\(goal)")
        #expect(goal.hasSuffix("band \(MoonlitMechanismProgress.band(of: 1)) of 5"), "\(goal)")
        #expect(!goal.contains("best"), "\(goal)")
        let openingText: String = try Teaching.describe(shell)
        #expect(openingText.contains(" " + goal + "."), "\(openingText)")

        let digest: String = try MoonlitMechanismTest.digest(shell)
        let early: ActionResult = try Teaching.send("level.next", [], shell)
        #expect(early == .rejected(.rule(code: MoonlitMechanismExperienceRule.locked)), "\(early.code)")
        let locked: String = Teaching.refusalMessage(MoonlitMechanismExperienceRule.locked)
        #expect(presenter.mirror.message == locked, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.mirror.message == Teaching.refusalMessage(early.code), "read with the engine's prefix too")
        #expect(presenter.refusalLog.last == MoonlitMechanismExperienceRule.locked)
        #expect(try MoonlitMechanismTest.digest(shell) == digest, "a refused level.next changes nothing")

        let actions: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedActions(1)
        #expect(try Teaching.win(shell) == actions.count)
        let text: String = try Teaching.describe(shell)
        let won: Core = try Teaching.core(shell)
        let stars: Int = MoonlitMechanismProgress.stars(actionsSpent: actions.count, certified: opening.certifiedActions)
        #expect(stars == 3, "the certified solution earns every star")
        #expect(won.play.stage == .won)
        #expect(won.progress.solved[1]?.stars == stars)
        #expect(presenter.mirror.stars[1] == stars)
        #expect(presenter.mirror.goalLabel == goal + "; best \(stars) of 3 stars", "\(presenter.mirror.goalLabel)")
        #expect(text.contains("Stars: \(stars) of 3."), "\(text)")
        #expect(text.contains(" " + presenter.mirror.goalLabel + "."), "\(text)")
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.instruction == nil, "the end of the level ends the tutorial")
        #expect(presenter.mirror.frontier == 2)

        let next: ActionResult = try Teaching.send("level.next", [], shell)
        #expect(next == .accepted, "\(next.code)")
        let second: Core = try Teaching.core(shell)
        #expect(second.levelNumber == 2)
        #expect(second.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.pickedLevel == 2)
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.stars[1] == stars, "the stars of level 1 stay")
        #expect(!presenter.mirror.goalLabel.contains("best"), "level 2 is not won: \(presenter.mirror.goalLabel)")
    }

    /// The level picker plays an open level (level 3's opening opens levels 1 … 3) and refuses a locked one in words.
    @Test func levelPickerPlaysOpenAndRefusesLocked() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 2)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        #expect(presenter.mirror.pickedLevel == 3)
        #expect(presenter.mirror.frontier == 3)

        presenter.mirror.pickedLevel = 2
        let pick: ActionResult = try Teaching.send("level.select", [Double(presenter.mirror.pickedLevel)], shell)
        #expect(pick == .accepted, "\(pick.code)")
        let picked: Core = try Teaching.core(shell)
        #expect(picked.levelNumber == 2)
        #expect(picked.mode == .campaign)
        #expect(picked.play.records.isEmpty)
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.pickedLevel == 2)
        #expect(presenter.mirror.message == nil)

        let digest: String = try MoonlitMechanismTest.digest(shell)
        let locked: ActionResult = try Teaching.send("level.select", [4], shell)
        #expect(locked == .rejected(.rule(code: MoonlitMechanismExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains(MoonlitMechanismExperienceRule.locked))
        #expect(presenter.mirror.message == Teaching.refusalMessage(MoonlitMechanismExperienceRule.locked),
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == MoonlitMechanismExperienceRule.locked)
        #expect(try MoonlitMechanismTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 2)
    }

    /// An impossible date reads the date refusal; Daily of 2026-11-23 opens its level in daily mode and Retry keeps the
    /// date; Practice raises the budget to 40; Campaign returns to the frontier.
    @Test func dailyPracticeAndCampaignModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.mode == .campaign)

        // An impossible date: refused with r02-g14.date, in words, nothing changed.
        let digest: String = try MoonlitMechanismTest.digest(shell)
        let impossible: ActionResult = presenter.playDaily(port: shell.port,
                                                           date: DateComponents(year: 2026, month: 2, day: 30))
        _ = try Teaching.describe(shell)
        #expect(impossible == .rejected(.rule(code: MoonlitMechanismExperienceRule.date)), "\(impossible.code)")
        #expect(presenter.mirror.message == Teaching.refusalMessage(MoonlitMechanismExperienceRule.date),
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == MoonlitMechanismExperienceRule.date)
        #expect(try MoonlitMechanismTest.digest(shell) == digest)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.dailyDate == nil, "a refused date is not kept")

        // Daily of 2026-11-23.
        let date: DateComponents = Teaching.dailyDate
        let number: Int = try #require(MoonlitMechanismProgress.dailyLevel(year: 2026, month: 11, day: 23))
        #expect(MoonlitMechanismPresenter.dateValues(date) == [2026, 11, 23])
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        _ = try Teaching.describe(shell)
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .daily(level: number))
        #expect(presenter.mirror.levelNumber == number)
        #expect(presenter.dailyDate == date)
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == number)
        #expect(dailyCore.mode == .daily(level: number))
        #expect(dailyCore.play.records.isEmpty)
        let band: Int = MoonlitMechanismProgress.band(of: number)
        #expect(presenter.mirror.goalLabel.hasSuffix("band \(band) of 5"), "\(presenter.mirror.goalLabel)")
        let later: DateComponents = DateComponents(year: 2026, month: 11, day: 25)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == MoonlitMechanismPresenter.dateValues(date),
                "Retry keeps the date that opened the daily level")
        let retried: ActionResult = presenter.retry(port: shell.port, date: later)
        #expect(retried == .accepted, "\(retried.code)")
        _ = try Teaching.describe(shell)
        #expect(presenter.mirror.levelNumber == number)
        #expect(try Teaching.core(shell).mode == .daily(level: number))

        // Practice: the budget is the kernel's maximum.
        let practice: ActionResult = try Teaching.send("mode.practice", [], shell)
        #expect(practice == .accepted, "\(practice.code)")
        let practiceCore: Core = try Teaching.core(shell)
        #expect(practiceCore.mode == .practice)
        #expect(practiceCore.levelNumber == number)
        #expect(practiceCore.play.level.budget == Core.practiceBudget)
        #expect(practiceCore.play.actionsLeft == Core.practiceBudget)
        #expect(Core.practiceBudget == 40)
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == Core.practiceBudget)
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)

        // Campaign returns: only level 1 is open, so the frontier (level 1).
        let campaign: ActionResult = try Teaching.send("mode.campaign", [], shell)
        #expect(campaign == .accepted, "\(campaign.code)")
        let back: Core = try Teaching.core(shell)
        #expect(back.mode == .campaign)
        #expect(back.levelNumber == 1)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 1)
        #expect(back.play.level.budget == opening.play.level.budget)
        #expect(presenter.mirror.frontier == 1, "neither daily nor practice opens a level")
        #expect(back.progress.solved.isEmpty)
    }
}
#endif
