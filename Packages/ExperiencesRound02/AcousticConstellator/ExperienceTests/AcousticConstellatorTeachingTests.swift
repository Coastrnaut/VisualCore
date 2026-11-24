// AcousticConstellatorTeachingTests — feature 425 (R02-G13-05) T-R02G1305-005 (FR-R02G1305-001 … 007)
// Clarifications Q1–Q5. On the simulator, through the one app's session host: the presenter's teaching and progression
// surface, modelled on feature 415's Harmonic Bridges teaching tests. The mirror is read after `describe` (the shell
// describes the core after every accepted action; the tests describe again themselves so the presenter's latest core is
// the current one). Tutorial: level 1 (seed 0) opens with the `link` instruction, which the description names; linking
// its one missing symbol pair completes the symbol, so the step goes straight on to `listen`; level 3 (seed 2) goes
// `link` → `complete` → `listen` as its missing symbol pairs are linked one by one; Dismiss through the port hides it
// and leaves the digest alone (the tutorial step is never in the digest). Hints: `showHint()` shows "Finding a hint…"
// while the detached search runs (awaited with `await hintSearch?.value`), then reveals levels 1, 2, 3 with the texts
// of `AcousticConstellatorHints.hint(level:play:)` of the current play; the digest never changes, the description names
// the hint, and any accepted action hides it. Failure: a listen from the opening of level 1 fails (its symbol is not
// linked); the explanation of `AcousticConstellatorFailureExplanation(play:)` is in `mirror.failureText` and the
// description; Undo returns to playing; Retry in campaign is `level.select` of the level and starts it fresh. Goal:
// "band 1 of 5"; after the certified win "best 3 of 3 stars" and "Stars: 3 of 3." in the description. Progression:
// `level.next` before a win is refused with `r02-g13.locked`, shown (since feature 426 in the feedback plan's words) as
// "That level is not open yet."; after the win it opens level 2; the picker plays an open level and refuses a
// locked one. Modes: Daily of 2026-11-23 opens `AcousticConstellatorProgress.dailyLevel(year: 2026, month: 11, day: 23)`
// and Retry keeps that date; an impossible date reads the date refusal; Practice raises the budget to 40; Campaign
// returns to the frontier. Synthetic data, no wall-clock assertion; each test short. Explicit types and plain loops (CI
// type-check rule).
#if os(iOS)
import AcousticConstellatorCore
import CoreGraphics
import Foundation
import Testing
@testable import AcousticConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Acoustic Constellator teaching tests.
@MainActor
enum AcousticConstellatorTeaching {
    typealias Shell = ExperienceShell<AcousticConstellatorPresenter>
    typealias Core = AcousticConstellatorExperienceCore

    /// The fixed calendar day of the daily test.
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 11, day: 23)

    /// What the panel shows for a locked level (since feature 426 exactly the feedback plan's words).
    static let lockedMessage: String = "That level is not open yet."

    /// What the panel shows for an impossible date (since feature 426 exactly the feedback plan's words).
    static let dateMessage: String = "That date cannot be used."

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn) and describes the opening so the presenter holds
    /// the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await AcousticConstellatorTest.open(session, seed: seed,
                                                                   size: CGSize(width: 360, height: 240))
        _ = try describe(shell)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try AcousticConstellatorTest.core(shell)
    }

    /// Describes the current core of `shell` (the shell's path after an accepted action) and returns the description.
    @discardableResult
    static func describe(_ shell: Shell) throws -> String {
        let current: Core = try AcousticConstellatorTest.core(shell)
        return shell.presenter.describe(current)
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: AcousticConstellatorPresenter) async {
        presenter.showHint()
        await presenter.hintSearch?.value
    }

    /// Sends the kernel action `action` through the presenter (the path of the controls), describes the result and
    /// returns it.
    @discardableResult
    static func send(_ action: AcousticConstellatorAction, _ shell: Shell) throws -> ActionResult {
        let entry: (control: String, values: [Double]) = AcousticConstellatorTest.control(action)
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

    /// The symbol pairs of `play`'s level not yet among its links (fixed links included), in symbol order.
    static func missingSymbolPairs(_ play: AcousticConstellatorPlay) -> [AcousticConstellatorLink] {
        let present: Set<AcousticConstellatorLink> = Set(play.links)
        var missing: [AcousticConstellatorLink] = []
        for pair in play.level.symbol where !present.contains(pair) { missing.append(pair) }
        return missing
    }

    /// Sends the certified solution of the shell's current level through the presenter; returns the actions accepted.
    @discardableResult
    static func win(_ shell: Shell) throws -> Int {
        let number: Int = try core(shell).levelNumber
        let actions: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedActions(number)
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
@Suite(.serialized) struct AcousticConstellatorTeachingTests {
    typealias Teaching = AcousticConstellatorTeaching
    typealias Core = AcousticConstellatorExperienceCore

    /// Level 1 opens with the tutorial's first instruction, which the description names; linking its one missing symbol
    /// pair completes the symbol and moves the step straight to `listen`; Dismiss hides it and leaves the digest alone.
    @Test func levelOneTutorialShownAdvancedAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .link)
        #expect(opening.play.stage == .playing)
        let first: String = AcousticConstellatorTutorialStep.link.text
        #expect(presenter.mirror.instruction == first, "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.certifiedActions == opening.certifiedActions)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let text: String = presenter.describe(opening)
        #expect(text.hasPrefix("Acoustic Constellator level 1. "), "\(text)")
        #expect(text.contains("Tutorial: " + first), "\(text)")

        let missing: [AcousticConstellatorLink] = Teaching.missingSymbolPairs(opening.play)
        #expect(missing.count == 1, "one link completes the symbol of level 1 (\(missing.count) missing)")
        let pair: AcousticConstellatorLink = try #require(missing.first)
        let linked: ActionResult = try Teaching.send(.link(pair.a, pair.b), shell)
        #expect(linked == .accepted, "\(linked.code)")
        let after: Core = try Teaching.core(shell)
        #expect(after.tutorial == .listen)
        let third: String = AcousticConstellatorTutorialStep.listen.text
        #expect(presenter.mirror.instruction == third, "\(presenter.mirror.instruction ?? "nil")")
        let linkedText: String = try Teaching.describe(shell)
        #expect(linkedText.contains("Tutorial: " + third), "\(linkedText)")
        let digest: String = try AcousticConstellatorTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let dismissedText: String = try Teaching.describe(shell)
        let dismissed: Core = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        #expect(!dismissedText.contains("Tutorial:"), "\(dismissedText)")
        #expect(try AcousticConstellatorTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// Level 3 goes link → complete → listen as its missing symbol pairs are linked one by one.
    @Test func levelThreeTutorialGoesThroughEveryStep() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 2)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 3)
        #expect(opening.tutorial == .link)
        #expect(presenter.mirror.instruction == AcousticConstellatorTutorialStep.link.text)
        let missing: [AcousticConstellatorLink] = Teaching.missingSymbolPairs(opening.play)
        try #require(missing.count >= 2, "level 3 needs more than one link (\(missing.count) missing)")

        var index: Int = 0
        for pair in missing {
            index += 1
            let result: ActionResult = try Teaching.send(.link(pair.a, pair.b), shell)
            #expect(result == .accepted, "link \(index): \(result.code)")
            let now: Core = try Teaching.core(shell)
            let want: AcousticConstellatorTutorialStep = index < missing.count ? .complete : .listen
            #expect(now.tutorial == want, "after link \(index): \(now.tutorial)")
            #expect(presenter.mirror.instruction == want.text, "\(presenter.mirror.instruction ?? "nil")")
        }
        let text: String = try Teaching.describe(shell)
        #expect(text.contains("Tutorial: " + AcousticConstellatorTutorialStep.listen.text), "\(text)")
    }

    /// "Finding a hint…" shows while the search runs; three hints reveal levels 1, 2, 3 with the texts of
    /// `AcousticConstellatorHints.hint(level:play:)`; the digest never changes; the description names the hint; an
    /// accepted action (the hinted one) hides it.
    @Test func hintLevelsOnTheCertifiedOpening() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let digest: String = try AcousticConstellatorTest.digest(shell)

        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 1)
        if presenter.hintSearch != nil {
            #expect(presenter.mirror.hintText == AcousticConstellatorPresenter.searchingText)
        }
        await presenter.hintSearch?.value
        #expect(presenter.hintSearch == nil, "the hint search has finished")

        for level in 1...3 {
            if level > 1 { await Teaching.pressHint(presenter) }
            let want: AcousticConstellatorHint = try #require(AcousticConstellatorHints.hint(level: level,
                                                                                             play: opening.play))
            #expect(want.kind != .stuck, "level 1 has a plan from its opening")
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(presenter.mirror.hintText != AcousticConstellatorPresenter.searchingText)
            #expect(try AcousticConstellatorTest.digest(shell) == digest, "hint \(level) leaves the state alone")
        }
        await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 3, "the hint stops at level 3")
        let third: AcousticConstellatorHint = try #require(AcousticConstellatorHints.hint(level: 3,
                                                                                          play: opening.play))
        let text: String = try Teaching.describe(shell)
        #expect(text.contains("Hint: " + third.text), "\(text)")

        // Any change of the play hides the hint: follow the hinted action.
        let action: AcousticConstellatorAction = try #require(third.action)
        let result: ActionResult = try Teaching.send(action, shell)
        #expect(result == .accepted, "\(result.code)")
        #expect(presenter.mirror.hintLevel == 0, "a change of the play hides the hint")
        #expect(presenter.mirror.hintText == nil)
        let after: String = try Teaching.describe(shell)
        #expect(!after.contains("Hint:"), "\(after)")
    }

    /// A listen from the opening of level 1 fails: the explanation is shown and named in the description; Undo returns
    /// to playing; Retry starts the level fresh.
    @Test func failedListenExplainedUndoAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        #expect(presenter.mirror.failureText == nil)
        let listened: ActionResult = try Teaching.send(.listen, shell)
        #expect(listened == .accepted, "\(listened.code)")
        let text: String = try Teaching.describe(shell)
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed || failed.play.stage == .result, "\(failed.play.stage)")
        #expect(failed.play.failure != nil, "the opening of level 1 does not ring")
        let explanation: String = try #require(AcousticConstellatorFailureExplanation(play: failed.play)?.text)
        #expect(presenter.mirror.failureText == explanation, "\(presenter.mirror.failureText ?? "nil")")
        #expect(explanation.hasPrefix("Action 1 (the listen)"), "\(explanation)")
        #expect(explanation.hasSuffix(" " + AcousticConstellatorFailureExplanation.advice), "\(explanation)")
        #expect(presenter.mirror.status == "Failed: " + explanation, "\(presenter.mirror.status)")
        #expect(text.contains(explanation), "\(text)")
        #expect(text.hasSuffix(" " + AcousticConstellatorPresenter.finishedMessage + "."), "\(text)")

        let undone: ActionResult = presenter.undoAction(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        _ = try Teaching.describe(shell)
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(presenter.mirror.failureText == nil)

        // Fail again, then Retry: level.select of the level in campaign, a fresh play.
        let again: ActionResult = try Teaching.send(.listen, shell)
        #expect(again == .accepted, "\(again.code)")
        #expect(presenter.mirror.failureText != nil)
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

    /// `level.next` before a win is refused with `r02-g13.locked` in words; the goal names band 1; the certified win
    /// records 3 stars, the goal adds the best stars, the description names them, and `level.next` then opens level 2.
    @Test func goalStarsAndNextLevel() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let goal: String = "Goal: link the symbol and hold it spending \(opening.certifiedActions) actions; band 1 of 5"
        #expect(presenter.mirror.goalLabel == goal, "\(presenter.mirror.goalLabel)")
        let openingText: String = try Teaching.describe(shell)
        #expect(openingText.contains(" " + goal + "."), "\(openingText)")

        let digest: String = try AcousticConstellatorTest.digest(shell)
        let early: ActionResult = try Teaching.send("level.next", [], shell)
        #expect(early == .rejected(.rule(code: AcousticConstellatorExperienceRule.locked)), "\(early.code)")
        #expect(presenter.mirror.message == Teaching.lockedMessage, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == early.code)
        #expect(try AcousticConstellatorTest.digest(shell) == digest, "a refused level.next changes nothing")

        let actions: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedActions(1)
        #expect(try Teaching.win(shell) == actions.count)
        let text: String = try Teaching.describe(shell)
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.progress.solved[1]?.stars == 3)
        #expect(presenter.mirror.stars[1] == 3)
        #expect(presenter.mirror.goalLabel == goal + "; best 3 of 3 stars", "\(presenter.mirror.goalLabel)")
        #expect(text.contains("The symbol rings together. Stars: 3 of 3."), "\(text)")
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
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.stars[1] == 3, "the stars of level 1 stay")
        #expect(!presenter.mirror.goalLabel.contains("best"), "level 2 is not won: \(presenter.mirror.goalLabel)")
    }

    /// The level picker plays an open level (level 3's opening opens levels 1 … 3) and refuses a locked one in words.
    @Test func levelPickerPlaysOpenAndRefusesLocked() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 2)
        let presenter: AcousticConstellatorPresenter = shell.presenter
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

        let digest: String = try AcousticConstellatorTest.digest(shell)
        let locked: ActionResult = try Teaching.send("level.select", [4], shell)
        #expect(locked == .rejected(.rule(code: AcousticConstellatorExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g13.locked"))
        #expect(presenter.mirror.message == Teaching.lockedMessage, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == locked.code)
        #expect(try AcousticConstellatorTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 2)
    }

    /// An impossible date reads the date refusal; Daily of 2026-11-23 opens its level in daily mode and Retry keeps the
    /// date; Practice raises the budget to 40; Campaign returns to the frontier.
    @Test func dailyPracticeAndCampaignModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.mode == .campaign)

        // An impossible date: refused with r02-g13.date, in words, nothing changed.
        let digest: String = try AcousticConstellatorTest.digest(shell)
        let impossible: ActionResult = presenter.playDaily(port: shell.port,
                                                           date: DateComponents(year: 2026, month: 2, day: 30))
        _ = try Teaching.describe(shell)
        #expect(impossible == .rejected(.rule(code: AcousticConstellatorExperienceRule.date)), "\(impossible.code)")
        #expect(presenter.mirror.message == Teaching.dateMessage, "\(presenter.mirror.message ?? "nil")")
        #expect(try AcousticConstellatorTest.digest(shell) == digest)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.dailyDate == nil, "a refused date is not kept")

        // Daily of 2026-11-23.
        let date: DateComponents = Teaching.dailyDate
        let number: Int = try #require(AcousticConstellatorProgress.dailyLevel(year: 2026, month: 11, day: 23))
        #expect(AcousticConstellatorPresenter.dateValues(date) == [2026, 11, 23])
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
        let band: Int = AcousticConstellatorProgress.band(of: number)
        #expect(presenter.mirror.goalLabel.contains("band \(band) of 5"), "\(presenter.mirror.goalLabel)")
        let later: DateComponents = DateComponents(year: 2026, month: 11, day: 25)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 11, 23], "Retry keeps the date that opened the daily level")
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
