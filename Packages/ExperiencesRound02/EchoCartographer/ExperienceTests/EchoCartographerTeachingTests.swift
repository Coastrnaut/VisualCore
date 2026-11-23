// EchoCartographerTeachingTests — feature 405 (R02-G11-05) T-R02G1105-005 (FR-R02G1105-001 … 005; clarifications
// Q1–Q5). On the simulator, through the one app's session host: the presenter's teaching and progression surface,
// modelled on feature 395's Backwards Aurora teaching tests. The mirror is read after `describe` (the shell describes
// the core after every accepted action; the tests describe again themselves so the presenter's latest core is the
// current one). Tutorial: level 1 (seed 0) opens with the `pulse` instruction, which the description names; Dismiss
// through the port hides it and leaves the digest alone (the tutorial step is never in the digest). Hints:
// `showHint()` shows "Finding a hint…" while the detached search runs (awaited by a bounded poll of `hintSearch`, at
// most 5 s), then reveals levels 1, 2, 3 in that order with the texts of `EchoCartographerHints.hint(level:play:)` of
// the current play; the digest never changes, the description names the hint, any accepted action hides it on the next
// describe, and following the level-3 hint's action through the port again and again wins level 1. Failure: pulses from
// the entry until the energy runs out show the failure explanation in `mirror.failureText`, which the description
// names; Undo returns to playing and hides it; Retry in campaign is `level.select` of the level and starts it fresh.
// Win: the certified solution of level 1 records 3 stars in the mirror, the goal names band 1 and the best stars, and
// level 2 opens; Play level selects it; a locked level 3 is refused with `r02-g11.locked`, shown in the panel. Modes:
// Daily of 2026-11-23 opens `EchoCartographerProgress.dailyLevel(year: 2026, month: 11, day: 23)` and Retry keeps
// that date; Practice raises the energy to 60; Campaign returns to the frontier. Synthetic data, no wall-clock
// assertion; each test short. Test data uses explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import EchoCartographerCore
import Foundation
import Testing
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Echo Cartographer teaching tests.
@MainActor
enum EchoCartographerTeaching {
    typealias Shell = ExperienceShell<EchoCartographerPresenter>
    typealias Core = EchoCartographerExperienceCore

    /// The fixed calendar day of the daily test.
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 11, day: 23)

    /// The longest wait for a hint search, in polls of ``pollMilliseconds``.
    static let pollLimit: Int = 500
    static let pollMilliseconds: Int = 10

    /// The most hinted actions followed before giving up on a win (pulses are bounded by the energy, claims by the
    /// beacons; both well under this).
    static let followLimit: Int = 80

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn) and describes the opening so the presenter holds
    /// the latest core.
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await EchoCartographerTest.open(session, seed: seed,
                                                               size: CGSize(width: 360, height: 240))
        _ = try describe(shell)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try EchoCartographerTest.core(shell)
    }

    /// Describes the current core of `shell` (the shell's path after an accepted action) and returns the description.
    @discardableResult
    static func describe(_ shell: Shell) throws -> String {
        let current: Core = try EchoCartographerTest.core(shell)
        return shell.presenter.describe(current)
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: EchoCartographerPresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(for: .milliseconds(pollMilliseconds))
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: EchoCartographerPresenter) async throws {
        presenter.showHint()
        let finished: Bool = try await awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")
    }

    /// Sends the kernel action `action` through the presenter (the path of the controls), describes the result and
    /// returns it.
    @discardableResult
    static func send(_ action: EchoCartographerAction, _ shell: Shell) throws -> ActionResult {
        let entry: (control: String, values: [Double]) = EchoCartographerTest.control(action)
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
}

@MainActor
@Suite(.serialized) struct EchoCartographerTeachingTests {
    typealias Teaching = EchoCartographerTeaching
    typealias Core = EchoCartographerExperienceCore

    /// Level 1 opens with the tutorial's first instruction, which the description names; Dismiss through the port
    /// hides it and leaves the digest unchanged.
    @Test func tutorialShownAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: EchoCartographerPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .pulse)
        #expect(opening.play.stage == .playing)
        let first: String = EchoCartographerTutorialStep.pulse.text
        #expect(presenter.mirror.instruction == first, "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.certifiedPulses == opening.certifiedPulses)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let text: String = presenter.describe(opening)
        #expect(text.contains("Tutorial: " + first), "\(text)")
        let digest: String = try EchoCartographerTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let after: String = try Teaching.describe(shell)
        let dismissed: Core = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        #expect(!after.contains("Tutorial:"), "\(after)")
        #expect(try EchoCartographerTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// "Finding a hint…" shows while the search runs; three hints reveal levels 1, 2, 3 with the texts of
    /// `EchoCartographerHints.hint(level:play:)`; the digest never changes; the description names the hint; an accepted
    /// action hides it; following the level-3 hint's action again and again wins level 1.
    @Test func hintLevelsAndFollowingHintsWins() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: EchoCartographerPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try EchoCartographerTest.digest(shell)

        // The first press starts the search: the panel reads "Finding a hint…" until it ends.
        presenter.showHint()
        #expect(presenter.hintSearch != nil, "the search runs off the main actor")
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == EchoCartographerPresenter.searchingText)
        let finished: Bool = try await Teaching.awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")

        // The three levels on the opening play.
        for level in 1...3 {
            if level > 1 { try await Teaching.pressHint(presenter) }
            let want: EchoCartographerHint = try #require(EchoCartographerHints.hint(level: level, play: opening.play))
            #expect(want.kind != .stuck, "level 1 has a plan from its opening")
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(presenter.mirror.hintText != EchoCartographerPresenter.searchingText)
            let now: String = try EchoCartographerTest.digest(shell)
            #expect(now == digest, "hint \(level) leaves the state alone")
        }
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 3, "the hint stops at level 3")
        let third: EchoCartographerHint = try #require(EchoCartographerHints.hint(level: 3, play: opening.play))
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
            let hint: EchoCartographerHint = try #require(EchoCartographerHints.hint(level: 3, play: current.play))
            #expect(hint.kind != .stuck, "action \(followed + 1): \(hint.text)")
            #expect(presenter.mirror.hintLevel == 3)
            #expect(presenter.mirror.hintText == hint.text,
                    "action \(followed + 1): \(presenter.mirror.hintText ?? "nil")")
            let action: EchoCartographerAction = try #require(hint.action)
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "action \(followed + 1): \(result.code)")
            guard result == .accepted else { break }
            followed += 1
            #expect(presenter.mirror.hintLevel == 0, "a change of the play hides the hint")
            #expect(presenter.mirror.hintText == nil)
        }
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won, "following hints wins level 1 (\(followed) actions made)")
        #expect(try EchoCartographerTest.digest(shell) != digest)
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 0, "a won play has no hint")
        #expect(presenter.mirror.hintText == nil)
    }

    /// Pulsing from the entry until the energy runs out fails with the explanation, named in the description; the
    /// failed hint is the advice; Undo returns to playing; Retry starts the level fresh.
    @Test func energyFailureExplainedUndoAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: EchoCartographerPresenter = shell.presenter
        #expect(presenter.mirror.failureText == nil)
        let pulses: Int = try EchoCartographerTest.pulseUntilEmpty(shell)
        #expect(pulses >= 1)
        let text: String = try Teaching.describe(shell)
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let explanation: EchoCartographerFailureExplanation = try #require(EchoCartographerFailureExplanation(
            play: failed.play))
        #expect(explanation.isPulse)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == explanation.text)
        #expect(shown.hasSuffix(" " + EchoCartographerFailureExplanation.advice), "\(shown)")
        #expect(presenter.mirror.status.hasPrefix("Failed: "), "\(presenter.mirror.status)")
        #expect(text.contains(explanation.text), "\(text)")

        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == EchoCartographerHint.failedText)

        let undone: ActionResult = presenter.undoAction(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        _ = try Teaching.describe(shell)
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(afterUndo.play.energy >= 1)
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
        #expect(fresh.play.energy == fresh.play.level.energy)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.energy == presenter.mirror.budget)
    }

    /// The certified solution of level 1 wins in the campaign: 3 stars in the mirror, the goal and the description, and
    /// level 2 opens; Play level picks it; a locked level is refused with `r02-g11.locked` and shown.
    @Test func campaignWinRecordsStarsAndOpensTheNextLevel() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: EchoCartographerPresenter = shell.presenter
        #expect(presenter.mirror.goalLabel.contains("band 1 of 5"), "\(presenter.mirror.goalLabel)")
        #expect(!presenter.mirror.goalLabel.contains("best"), "\(presenter.mirror.goalLabel)")
        let actions: [EchoCartographerAction] = try EchoCartographerTest.certifiedActions(1)
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

        // Level 3 is locked.
        let digest: String = try EchoCartographerTest.digest(shell)
        let locked: ActionResult = try Teaching.send("level.select", [3], shell)
        #expect(locked == .rejected(.rule(code: EchoCartographerExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g11.locked"))
        // Since feature 406 the refusal is shown in words.
        #expect(presenter.mirror.message == EchoCartographerFeedbackPlan.refusalText(code: locked.code),
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == locked.code)
        #expect(try EchoCartographerTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 2)
    }

    /// Daily of 2026-11-23 opens its level in daily mode and Retry keeps the date; Practice raises the energy to 60;
    /// Campaign returns to the frontier.
    @Test func dailyPracticeAndCampaignModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: EchoCartographerPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.mode == .campaign)

        // Daily of 2026-11-23.
        let date: DateComponents = Teaching.dailyDate
        let number: Int = try #require(EchoCartographerProgress.dailyLevel(year: 2026, month: 11, day: 23))
        #expect(EchoCartographerPresenter.dateValues(date) == [2026, 11, 23])
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
        let band: Int = EchoCartographerProgress.band(of: number)
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

        // Practice: the energy is 60.
        let practice: ActionResult = try Teaching.send("mode.practice", [], shell)
        #expect(practice == .accepted, "\(practice.code)")
        let practiceCore: Core = try Teaching.core(shell)
        #expect(practiceCore.mode == .practice)
        #expect(practiceCore.play.level.energy == 60)
        #expect(practiceCore.play.energy == 60)
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == 60)
        #expect(presenter.mirror.energy == Core.practiceEnergy)
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
        #expect(back.play.level.energy == opening.play.level.energy)
        #expect(presenter.mirror.budget == back.play.level.energy)
        #expect(presenter.mirror.frontier == 1, "neither daily nor practice opens a level")
        #expect(back.progress.solved.isEmpty)
    }
}
#endif
