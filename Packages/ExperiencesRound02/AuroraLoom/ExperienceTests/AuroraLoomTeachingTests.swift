// AuroraLoomTeachingTests — feature 305 (R02-G01-05) T-R02G0105-005 (FR-R02G0105-001 … 005). On the simulator, through
// the one app's session host: the presenter's teaching surface. Hints: `showHint()` reveals levels 1, 2, 3 of the
// current play (texts equal the core's `hint(level:)`), stays at 3, never changes the digest, is hidden by a change of
// the play and starts again at level 1; following the level-3 hint's move is accepted. Tutorial: level 1 shows the
// core's tutorial instruction in the mirror and the description, a wave move advances it, `tutorial.dismiss` removes
// it (a second dismissal is accepted and changes nothing). Failure: a level driven to `failed` through the port shows
// the core's failure explanation in the mirror and the description, hides any hint, `play.undo` rewinds the failing
// move (playing again with one move left), and Retry (`level.select` of the level in campaign)
// gives a fresh play. Picker: a closed level is refused with `r02-g01.locked` and changes nothing; a certified win of
// level 1 opens level 2 with 3 stars. Modes: the daily level of 2026-01-02 is 38, an invalid date is refused with
// `r02-g01.date`, practice raises the allowance to 64 and retries with `mode.practice`, campaign returns to an open
// level; `dateValues` of an empty date is [0, 0, 0]. The native controls send every declared action, every gesture
// action among them. Synthetic data, no sleep, no wall-clock assertion; each test well under 10 s. Test data uses
// explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the teaching tests.
@MainActor
enum AuroraLoomTeaching {
    typealias Shell = ExperienceShell<AuroraLoomPresenter>

    /// Opens Aurora Loom with `seed` (seed 0 is level 1, the only open level).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await AuroraLoomTest.open(session, seed: seed, size: CGSize(width: 360, height: 240))
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> AuroraLoomExperienceCore {
        try #require(shell.engine.core)
    }

    /// Sends `move` as `ribbon.move` through the shell's port, as the steppers do.
    @discardableResult
    static func send(_ shell: Shell, _ move: AuroraLoomMove) -> ActionResult {
        let control: Double = move.control == .wave ? 0 : 1
        return shell.port.send("ribbon.move", [Double(move.ribbon), control, Double(move.step)])
    }

    /// A wave step for ribbon 0 that, alternated with the start step from `opening`, spends the whole allowance
    /// without a win and fails the play on the last move (checked by trial on copies of the play); nil when none.
    static func losingWave(from opening: AuroraLoomPlay) -> Int? {
        let allowance: Int = opening.level.allowance
        let start: Int = opening.steps.wave[0]
        for candidate in 0..<16 where candidate != start {
            var trial: AuroraLoomPlay = opening
            var fine: Bool = true
            for index in 0..<allowance {
                let step: Int = index % 2 == 0 ? candidate : start
                do {
                    try trial.apply(AuroraLoomMove(ribbon: 0, control: .wave, step: step), expecting: trial.fingerprint)
                } catch {
                    fine = false
                    break
                }
                let last: Bool = index == allowance - 1
                if trial.stage != (last ? .failed : .playing) {
                    fine = false
                    break
                }
            }
            if fine { return candidate }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct AuroraLoomTeachingTests {
    typealias Teaching = AuroraLoomTeaching

    /// The Hint button reveals levels 1, 2, 3 of the current play with the core's texts, stays at 3, never changes the
    /// state; a move hides the hint and the next reveal is level 1 again; the level-3 hint's move is accepted.
    @Test func hintLevelsThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let opening: AuroraLoomExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try AuroraLoomTest.digest(shell)

        for level in 1...3 {
            presenter.showHint()
            let expected: AuroraLoomHint = try #require(opening.hint(level: level))
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == expected.text)
            #expect(try AuroraLoomTest.digest(shell) == digest, "showHint level \(level) leaves the state unchanged")
        }
        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 3, "a fourth reveal stays at level 3")
        #expect(presenter.mirror.hintText == opening.hint(level: 3)?.text)
        #expect(try AuroraLoomTest.digest(shell) == digest)
        let summary: String = shell.accessibilitySummary
        let third: AuroraLoomHint = try #require(opening.hint(level: 3))
        #expect(summary.contains("Hint: \(third.text)"), "\(summary)")
        #expect(try AuroraLoomTest.digest(shell) == digest, "describing leaves the state unchanged")

        // Following the level-3 hint is accepted and leaves a shortest remaining solution one move shorter.
        let control: AuroraLoomControl = try #require(third.control)
        let step: Int = try #require(third.step)
        let result: ActionResult = Teaching.send(shell, AuroraLoomMove(ribbon: third.ribbon, control: control, step: step))
        #expect(result == .accepted, "\(result.code)")
        let after: AuroraLoomExperienceCore = try Teaching.core(shell)
        #expect(after.play.spent == 1)
        // The shell described the new state: the hint of the earlier play is hidden.
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        if after.play.stage == .playing {
            let next: AuroraLoomHint = try #require(after.hint(level: 1))
            #expect(next.remaining == third.remaining - 1)
            presenter.showHint()
            #expect(presenter.mirror.hintLevel == 1, "a new play starts at level 1")
            #expect(presenter.mirror.hintText == next.text)
        } else {
            #expect(after.play.stage == .won)
            #expect(third.remaining == 1)
            presenter.showHint()
            #expect(presenter.mirror.hintLevel == 0, "no hint once the play has ended")
        }
    }

    /// Level 1 shows the core's tutorial instruction in the mirror and the description; a wave move advances it;
    /// `tutorial.dismiss` removes it, and a second dismissal is accepted and changes nothing.
    @Test func tutorialInstructionAndDismissal() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let opening: AuroraLoomExperienceCore = try Teaching.core(shell)
        #expect(opening.tutorial != .done, "level 1 has a tutorial")
        let first: String = try #require(presenter.mirror.instruction)
        #expect(first == opening.tutorial.text)
        #expect(!first.isEmpty)
        #expect(shell.accessibilitySummary.contains(first))

        // A wave move of the named ribbon advances the instruction (to the phase step unless it won the level).
        guard case .wave(let ribbon) = opening.tutorial else {
            Issue.record("level 1's first step is a wave step: \(opening.tutorial)")
            return
        }
        let wave: Int = opening.play.steps.wave[ribbon]
        let target: Int = (wave + 1) % 16
        let moved: ActionResult = Teaching.send(shell, AuroraLoomMove(ribbon: ribbon, control: .wave, step: target))
        #expect(moved == .accepted, "\(moved.code)")
        let advanced: AuroraLoomExperienceCore = try Teaching.core(shell)
        if advanced.play.stage == .playing {
            if case .phase = advanced.tutorial {} else { Issue.record("expected the phase step: \(advanced.tutorial)") }
            let second: String = try #require(presenter.mirror.instruction)
            #expect(second == advanced.tutorial.text)
            #expect(second != first)
            #expect(shell.accessibilitySummary.contains(second))
        }

        // Dismissal.
        let before: String = shell.accessibilitySummary
        let instruction: String? = presenter.mirror.instruction
        let dismissed: ActionResult = shell.port.send("tutorial.dismiss")
        #expect(dismissed == .accepted, "\(dismissed.code)")
        #expect(try Teaching.core(shell).tutorial == .done)
        #expect(presenter.mirror.instruction == nil)
        let summary: String = shell.accessibilitySummary
        if let instruction {
            #expect(before.contains(instruction))
            #expect(!summary.contains(instruction), "\(summary)")
        }
        let digest: String = try AuroraLoomTest.digest(shell)
        let again: ActionResult = shell.port.send("tutorial.dismiss")
        #expect(again == .accepted, "\(again.code)")
        #expect(try AuroraLoomTest.digest(shell) == digest, "a second dismissal changes nothing")
    }

    /// A level driven to `failed` through the port shows the core's explanation; no hint is shown; `play.undo`
    /// rewinds the failing move; Retry gives a fresh play.
    @Test func failureExplanationUndoAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let opening: AuroraLoomPlay = try Teaching.core(shell).play
        let allowance: Int = opening.level.allowance
        try #require(allowance >= 2)
        let start: Int = opening.steps.wave[0]
        let losing: Int = try #require(Teaching.losingWave(from: opening), "a losing alternation for ribbon 0")
        #expect(presenter.mirror.failureText == nil)
        for index in 0..<allowance {
            let step: Int = index % 2 == 0 ? losing : start
            let result: ActionResult = Teaching.send(shell, AuroraLoomMove(ribbon: 0, control: .wave, step: step))
            #expect(result == .accepted, "move \(index): \(result.code)")
        }
        let failed: AuroraLoomExperienceCore = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let explanation: AuroraLoomFailureExplanation = try #require(failed.failureExplanation)
        #expect(presenter.mirror.failureText == explanation.text)
        #expect(presenter.mirror.stage == .failed)
        let summary: String = shell.accessibilitySummary
        #expect(summary.contains(explanation.text), "\(summary)")
        #expect(summary.contains("Out of moves."))

        // No hint once the play has ended.
        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        // Undo after the failure rewinds the failing move: playing again with one move left and no explanation.
        let failedAllowance: Int = try AuroraLoomTeaching.core(shell).play.level.allowance
        let undo: ActionResult = shell.port.send("play.undo")
        #expect(undo == .accepted, "\(undo.code)")
        let rewound: AuroraLoomExperienceCore = try AuroraLoomTeaching.core(shell)
        #expect(rewound.play.stage == .playing && rewound.play.spent == failedAllowance - 1)
        #expect(presenter.mirror.failureText == nil)

        // Retry in campaign is `level.select` of the level and gives a fresh play.
        let action: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(action.control == "level.select")
        #expect(action.values == [1])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: AuroraLoomExperienceCore = try Teaching.core(shell)
        #expect(fresh.levelNumber == 1)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.spent == 0)
        #expect(fresh.play.stage == .playing)
        #expect(fresh.play.steps == opening.steps)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.stage == .playing)
        #expect(presenter.mirror.spent == 0)
    }

    /// A closed level is refused with `r02-g01.locked` and changes nothing; a certified win of level 1 opens level 2
    /// with 3 stars, and level 2 can then be picked.
    @Test func pickerRefusesClosedLevelsAndOpensAfterAWin() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars == nil)
        let digest: String = try AuroraLoomTest.digest(shell)
        let locked: ActionResult = shell.port.send("level.select", [2])
        #expect(locked == .rejected(.rule(code: AuroraLoomExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g01.locked"))
        #expect(try AuroraLoomTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 1)

        let certified: AuroraLoomGenerated = try AuroraLoomExperienceCore.generated(number: 1)
        #expect(presenter.mirror.shortest == certified.solution.shortest)
        for move in certified.solution.moves {
            let result: ActionResult = Teaching.send(shell, move)
            #expect(result == .accepted, "\(result.code)")
        }
        let won: AuroraLoomExperienceCore = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(presenter.mirror.stage == .won)
        #expect(presenter.mirror.frontier == 2)
        #expect(presenter.mirror.stars == 3)
        #expect(shell.accessibilitySummary.contains("3 of 3 stars"))

        let picked: ActionResult = shell.port.send("level.select", [2])
        #expect(picked == .accepted, "\(picked.code)")
        let second: AuroraLoomExperienceCore = try Teaching.core(shell)
        #expect(second.levelNumber == 2)
        #expect(second.play.stage == .playing)
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.stars == nil)
        #expect(presenter.mirror.frontier == 2)
    }

    /// Daily and practice through the port: 2026-01-02 is level 38, 30 February is refused, practice raises the
    /// allowance to 64 and retries with `mode.practice`, campaign returns to an open level.
    @Test func dailyPracticeAndCampaignThroughThePort() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        #expect(presenter.mirror.mode == .campaign)

        let date: DateComponents = DateComponents(year: 2026, month: 1, day: 2)
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.levelNumber == 38)
        #expect(presenter.mirror.mode == .daily(level: 38))
        #expect(presenter.mirror.band == 2)
        #expect(presenter.mirror.spent == 0)
        #expect(shell.accessibilitySummary.contains("Daily level."))
        let dailyRetry: (control: String, values: [Double]) = presenter.retryAction(date: date)
        #expect(dailyRetry.control == "mode.daily")
        #expect(dailyRetry.values == [2026, 1, 2])

        let digest: String = try AuroraLoomTest.digest(shell)
        let invalid: DateComponents = DateComponents(year: 2026, month: 2, day: 30)
        let refused: ActionResult = presenter.playDaily(port: shell.port, date: invalid)
        #expect(refused == .rejected(.rule(code: AuroraLoomExperienceRule.date)), "\(refused.code)")
        #expect(refused.code.contains("r02-g01.date"))
        #expect(try AuroraLoomTest.digest(shell) == digest, "a refused date changes nothing")
        #expect(presenter.mirror.mode == .daily(level: 38))

        let practice: ActionResult = shell.port.send("mode.practice")
        #expect(practice == .accepted, "\(practice.code)")
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.allowance == AuroraLoomExperienceCore.practiceAllowance)
        #expect(presenter.mirror.allowance == 64)
        #expect(presenter.mirror.levelNumber == 38)
        #expect(shell.accessibilitySummary.contains("Practice."))
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: date)
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)
        let retried: ActionResult = presenter.retry(port: shell.port, date: date)
        #expect(retried == .accepted, "\(retried.code)")
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.spent == 0)

        // Level 38 is not open in the campaign (only level 1 is), so campaign returns to the highest open level.
        let campaign: ActionResult = shell.port.send("mode.campaign")
        #expect(campaign == .accepted, "\(campaign.code)")
        let back: AuroraLoomExperienceCore = try Teaching.core(shell)
        #expect(back.mode == .campaign)
        #expect(back.progress.isOpen(back.levelNumber))
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.allowance == back.play.level.allowance)
    }

    /// The daily values of a date: year, month, day, 0 for a missing part.
    @Test func dateValuesOfADate() {
        let empty: [Double] = AuroraLoomPresenter.dateValues(DateComponents())
        #expect(empty == [0, 0, 0])
        let full: [Double] = AuroraLoomPresenter.dateValues(DateComponents(year: 2026, month: 11, day: 20))
        #expect(full == [2026, 11, 20])
        let partial: [Double] = AuroraLoomPresenter.dateValues(DateComponents(year: 2026, day: 5))
        #expect(partial == [2026, 0, 5])
    }

    /// The native controls send every declared action, and every action a gesture can send.
    @Test func nativeActionsCoverEveryAction() {
        let presenter = AuroraLoomPresenter(reduceMotion: false, reduceFlashing: false)
        let declared: Set<String> = Set(AuroraLoomExperienceCore.actionIDs)
        #expect(presenter.nativeActions == declared)
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions))
        for control in AuroraLoomExperienceCore.controls {
            #expect(presenter.nativeActions.contains(control.id), "\(control.id)")
        }
        let teaching: [String] = ["level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"]
        for id in teaching {
            #expect(presenter.nativeActions.contains(id), "\(id)")
        }
    }
}
#endif
