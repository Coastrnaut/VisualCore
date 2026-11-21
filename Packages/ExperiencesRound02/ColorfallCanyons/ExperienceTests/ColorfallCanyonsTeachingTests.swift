// ColorfallCanyonsTeachingTests — feature 345 (R02-G05-05) T-R02G0505-005 (FR-R02G0505-001 … 005; clarifications
// Q1–Q5).
// On the simulator, through the one app's session host: the presenter's teaching and progression surface. Tutorial:
// level 1 (seed 0) shows the steer instruction; Dismiss through the presenter hides it and leaves the digest alone (the
// tutorial step is never in the digest). Hints: `showHint()` reveals levels 1, 2, 3 in that order with the core's
// `hint(level:)` texts, a fourth press stays at level 3, the digest never changes, and following the exact hint (a carve,
// a valve or a run through the port) hides the hint once the presenter describes the new play. Failure: running a level
// out without edits fails; the mirror shows the core's explanation, which ends with "Undo the last change or retry the
// level."; Undo returns the play to playing, and Retry in campaign is `level.select` of the level and gives a fresh
// play. Picker and modes: a locked level is refused with `r02-g05.locked` and the refusal is shown in the mirror's
// message; the daily level of 2026-02-04 is `ColorfallCanyonsProgress.dailyLevel(2026, 2, 4)` and `retryAction` keeps
// that date; practice raises the budget to 30; campaign returns. Following the exact hints wins level 1, records its
// stars and opens level 2. Synthetic data, no sleep, no wall-clock assertion; each test short. Test data uses explicit
// types and plain loops (CI type-check rule).
#if os(iOS)
import ColorfallCanyonsCore
import CoreGraphics
import Foundation
import Testing
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the teaching tests.
@MainActor
enum ColorfallCanyonsTeaching {
    typealias Shell = ExperienceShell<ColorfallCanyonsPresenter>

    /// The advice every failure text ends with (clarification Q5).
    static let advice: String = "Undo the last change or retry the level."
    /// The most ticks one `time.step` runs.
    static let maxStep: Int = 600
    /// The most hint-following actions a win of a level may take (budget 30 plus a few runs).
    static let maxFollow: Int = 60

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await ColorfallCanyonsTest.open(session, seed: seed, size: CGSize(width: 360, height: 240))
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> ColorfallCanyonsExperienceCore {
        try ColorfallCanyonsTest.core(shell)
    }

    /// The control and values that carry out `hint` (level 3, exact): a carve, a valve, or a run of the ticks left
    /// (at most one `time.step` of 600); nil for `stuck`.
    static func action(for hint: ColorfallCanyonsHint) -> (control: String, values: [Double])? {
        switch hint.kind {
        case .carve:
            guard let cell = hint.cell else { return nil }
            return ("canyon.carve", [Double(cell)])
        case .valve:
            guard let spring = hint.spring else { return nil }
            return ("canyon.valve", [Double(spring)])
        case .run:
            let ticks: Int = min(max(hint.ticks, 1), maxStep)
            return ("time.step", [Double(ticks)])
        case .stuck:
            return nil
        }
    }

    /// Whether level `number`, run out with no edits on a bare core, fails.
    static func failsWithoutEdits(_ number: Int) throws -> Bool {
        var core: ColorfallCanyonsExperienceCore = try ColorfallCanyonsExperienceCore.opening(number: number)
        let rounds: Int = core.play.level.tickLimit / maxStep + 2
        for _ in 0..<rounds {
            guard core.play.stage == .playing else { break }
            _ = core.apply(ExperienceAction(control: "time.step", values: [Double(maxStep)], step: 0))
        }
        return core.play.stage == .failed
    }

    /// Runs the level of `shell` out through the presenter with no edits (steps of 600 ticks until the play ends).
    static func runOut(_ shell: Shell) throws {
        let rounds: Int = try core(shell).play.level.tickLimit / maxStep + 2
        for index in 0..<rounds {
            guard try core(shell).play.stage == .playing else { break }
            let result: ActionResult = shell.presenter.send("time.step", [Double(maxStep)], port: shell.port)
            #expect(result == .accepted, "step \(index): \(result.code)")
        }
    }
}

@MainActor
@Suite(.serialized) struct ColorfallCanyonsTeachingTests {
    typealias Teaching = ColorfallCanyonsTeaching

    /// Level 1 opens with the steer instruction; Dismiss hides it and leaves the digest unchanged.
    @Test func tutorialOnLevelOneAndDismiss() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        let opening: ColorfallCanyonsExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .steer)
        #expect(presenter.mirror.instruction == ColorfallCanyonsTutorialStep.steer.text,
                "\(presenter.mirror.instruction ?? "nil")")
        let digest: String = try ColorfallCanyonsTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        #expect(try Teaching.core(shell).tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        #expect(try ColorfallCanyonsTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// Three hints reveal what, where and exactly with the core's texts; a fourth stays at level 3; the digest never
    /// changes; following the exact hint hides it.
    @Test func hintLevelsThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        let opening: ColorfallCanyonsExperienceCore = try Teaching.core(shell)
        #expect(opening.play.stage == .playing)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try ColorfallCanyonsTest.digest(shell)
        let third: ColorfallCanyonsHint = try #require(opening.hint(level: 3))
        #expect(third.kind != .stuck, "level 1 can be won from its opening")

        for level in 1...3 {
            presenter.showHint()
            let want: ColorfallCanyonsHint = try #require(opening.hint(level: level))
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(try ColorfallCanyonsTest.digest(shell) == digest, "hint \(level) leaves the state alone")
        }
        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 3, "a fourth press stays at level 3")
        #expect(presenter.mirror.hintText == third.text)
        #expect(try ColorfallCanyonsTest.digest(shell) == digest)

        // Follow the exact hint: the description of the new play hides the hint.
        let follow: (control: String, values: [Double]) = try #require(Teaching.action(for: third))
        let result: ActionResult = presenter.send(follow.control, follow.values, port: shell.port)
        #expect(result == .accepted, "\(follow.control) \(follow.values): \(result.code)")
        #expect(try ColorfallCanyonsTest.digest(shell) != digest)
        #expect(presenter.mirror.hintLevel == 0, "an accepted action hides the hint")
        #expect(presenter.mirror.hintText == nil)
    }

    /// Running a level out without edits fails with the core's explanation; Undo returns to playing; Retry in campaign
    /// is `level.select` of the level and gives a fresh play.
    @Test func failureUndoAndRetry() async throws {
        var found: UInt64?
        for seed in 0..<UInt64(10) {
            let number: Int = ColorfallCanyonsExperienceCore.levelNumber(forSeed: seed)
            if try Teaching.failsWithoutEdits(number) {
                found = seed
                break
            }
        }
        let seed: UInt64 = try #require(found, "some level of 1 … 10 fails when run out without edits")
        let number: Int = ColorfallCanyonsExperienceCore.levelNumber(forSeed: seed)

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: seed)
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        #expect(presenter.mirror.failureText == nil)
        try Teaching.runOut(shell)

        let failed: ColorfallCanyonsExperienceCore = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let want: String = try #require(failed.failureExplanation?.text)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == want)
        #expect(shown.hasSuffix(Teaching.advice), "\(shown)")

        // Undo takes back the run: the play is playing again and the explanation is gone.
        let undone: ActionResult = presenter.undo(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        #expect(try Teaching.core(shell).play.stage == .playing)
        #expect(presenter.mirror.failureText == nil)

        // Fail again, then Retry in campaign is `level.select` of the level.
        try Teaching.runOut(shell)
        #expect(try Teaching.core(shell).play.stage == .failed)
        let action: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(action.control == "level.select")
        #expect(action.values == [Double(number)])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: ColorfallCanyonsExperienceCore = try Teaching.core(shell)
        #expect(fresh.levelNumber == number)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.stage == .playing)
        #expect(fresh.play.spent == 0)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.spent == 0)
        #expect(presenter.mirror.tick == 0)
    }

    /// A locked level is refused with `r02-g05.locked` and shown; the daily level of 2026-02-04 opens in daily mode and
    /// Retry keeps its date; practice raises the budget to 30; campaign returns.
    @Test func pickerRefusalAndModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.mode == .campaign)
        let digest: String = try ColorfallCanyonsTest.digest(shell)

        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(locked == .rejected(.rule(code: ColorfallCanyonsExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g05.locked"))
        let message: String = try #require(presenter.mirror.message, "the refusal is shown")
        #expect(message == "That change was refused: \(locked.code)", "\(message)")
        #expect(try ColorfallCanyonsTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 1)

        // The daily level of 2026-02-04.
        let date: DateComponents = DateComponents(year: 2026, month: 2, day: 4)
        #expect(ColorfallCanyonsPresenter.dateValues(date) == [2026, 2, 4])
        let dailyNumber: Int = try #require(ColorfallCanyonsProgress.dailyLevel(year: 2026, month: 2, day: 4))
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .daily(level: dailyNumber))
        #expect(presenter.mirror.levelNumber == dailyNumber)
        #expect(presenter.mirror.spent == 0)
        let later: DateComponents = DateComponents(year: 2026, month: 2, day: 9)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 2, 4], "Retry keeps the date that opened the daily level")

        // Practice: the budget is 30.
        let practice: ActionResult = presenter.send("mode.practice", [], port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == 30)
        #expect(presenter.mirror.budget == ColorfallCanyonsExperienceCore.practiceBudget)
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)

        // Campaign returns.
        let campaign: ActionResult = presenter.send("mode.campaign", [], port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        #expect(presenter.mirror.mode == .campaign)
        let back: ColorfallCanyonsExperienceCore = try Teaching.core(shell)
        #expect(back.progress.isOpen(back.levelNumber))
        #expect(presenter.mirror.budget == back.play.level.budget)
        #expect(presenter.mirror.frontier == 1, "neither daily nor practice opens a level")
    }

    /// Following the exact hints wins level 1, records its stars and opens level 2.
    @Test func winningLevelOneByHints() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.frontier == 1)

        for index in 0..<Teaching.maxFollow {
            let current: ColorfallCanyonsExperienceCore = try Teaching.core(shell)
            guard current.play.stage == .playing else { break }
            let hint: ColorfallCanyonsHint = try #require(current.hint(level: 3), "hint \(index)")
            let follow: (control: String, values: [Double]) = try #require(Teaching.action(for: hint),
                                                                           "hint \(index) is stuck")
            let result: ActionResult = presenter.send(follow.control, follow.values, port: shell.port)
            #expect(result == .accepted, "hint \(index) \(follow.control) \(follow.values): \(result.code)")
        }

        let won: ColorfallCanyonsExperienceCore = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        let stars: Int = try #require(presenter.mirror.stars[1], "the win is recorded")
        #expect(stars == ColorfallCanyonsProgress.stars(actions: won.play.spent, smallest: won.certifiedSmallest))
        #expect(stars >= 1 && stars <= 3)
        #expect(presenter.mirror.frontier == 2)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.instruction == nil, "the tutorial ends with the level")
    }
}
#endif
