// HueCompassTeachingTests — feature 335 (R02-G04-05) T-R02G0405-005 (FR-R02G0405-001 … 005;
// SC-R02G0405-001 … 004; clarifications Q1–Q5).
// On the simulator, through the one app's session host: the presenter's teaching and progression surface. Hints:
// `showHint(port:)` reveals levels 1, 2, 3 in that order with the core's `hint(level:)` texts, a fourth press stays at
// level 3, the state's digest never changes, and an accepted turn hides the hint once the presenter describes the new
// play. Tutorial: level 1 (seed 0) shows the aim instruction, an accepted turn advances it to the probe instruction, an
// accepted probe to the select instruction, and Dismiss hides it. Failure: a selection half the compass away from the
// target and the opposite band fails with the core's selection explanation; spending the allowance on probes fails with
// the probe explanation; both end with "Retry the level." (no Undo: probes and selections cannot be undone), and Retry
// in campaign is `level.select` of the level and gives a fresh play. Picker: a locked level (and `level.next` with no
// open next level) is refused with `r02-g04.locked`, shown in the mirror's message, and changes nothing. Modes: the
// daily level of 2026-01-01 is 1 ((0 × 47) mod 100 + 1), of 2026-01-02 is 48 (playable while locked, not opened),
// `retryAction` keeps the date, 2026-02-30 is refused with `r02-g04.date`; practice raises the allowance to 24; the goal
// line and the picker titles are formatted as the controls show them; a direct selection of the target wins level 1
// with 3 stars and opens level 2. Synthetic data, no sleep, no wall-clock assertion; each test well under 10 s. Test
// data uses explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import HueCompassCore
import Testing
@testable import HueCompassExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the teaching tests.
@MainActor
enum HueCompassTeaching {
    typealias Shell = ExperienceShell<HueCompassPresenter>

    /// The advice every failure text ends with (clarification Q5).
    static let advice: String = "Retry the level."

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await HueCompassTest.open(session, seed: seed, size: CGSize(width: 360, height: 240))
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> HueCompassExperienceCore {
        try HueCompassTest.core(shell)
    }

    /// The values of a selection that misses the target of `level`: half the compass away and the opposite band.
    static func missValues(_ level: HueCompassLevel) -> [Double] {
        let bearing: Int = (level.target + HueCompassWheel.bearings / 2) % HueCompassWheel.bearings
        let band: Int = (level.targetBand + HueCompassWheel.bands / 2) % HueCompassWheel.bands
        return [Double(bearing), Double(band)]
    }

    /// The values of a selection of the target of `level` (its bearing and band).
    static func targetValues(_ level: HueCompassLevel) -> [Double] {
        [Double(level.target), Double(level.targetBand)]
    }
}

@MainActor
@Suite(.serialized) struct HueCompassTeachingTests {
    typealias Teaching = HueCompassTeaching

    /// Three hints reveal what, where and exactly with the core's texts; a fourth stays at level 3; the digest never
    /// changes; an accepted turn hides the hint, and the next press starts again at level 1.
    @Test func hintLevelsThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: HueCompassPresenter = shell.presenter
        let opening: HueCompassExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try HueCompassTest.digest(shell)
        let third: HueCompassHint = try #require(opening.hint(level: 3))

        for level in 1...3 {
            presenter.showHint(port: shell.port)
            let want: HueCompassHint = try #require(opening.hint(level: level))
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(try HueCompassTest.digest(shell) == digest, "hint \(level) leaves the state alone")
        }
        presenter.showHint(port: shell.port)
        #expect(presenter.mirror.hintLevel == 3, "a fourth press stays at level 3")
        #expect(presenter.mirror.hintText == third.text)
        #expect(try HueCompassTest.digest(shell) == digest)

        // A turn changes the play: the description of the new play hides the hint.
        let turned: ActionResult = presenter.send("compass.turn", [1], port: shell.port)
        #expect(turned == .accepted, "\(turned.code)")
        #expect(presenter.mirror.hintLevel == 0, "an accepted turn hides the hint")
        #expect(presenter.mirror.hintText == nil)

        // The next press starts again at level 1 of the new play.
        presenter.showHint(port: shell.port)
        let after: HueCompassHint = try #require(try Teaching.core(shell).hint(level: 1))
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == after.text)
    }

    /// Level 1 shows the aim instruction; a turn advances it to probe, a probe to select, and Dismiss hides it.
    @Test func tutorialOnLevelOne() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: HueCompassPresenter = shell.presenter
        let opening: HueCompassExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        try #require(opening.play.level.allowance >= 2, "a probe leaves level 1 playing")
        #expect(opening.tutorial == .aim)
        #expect(presenter.mirror.instruction == HueCompassTutorialStep.aim.text,
                "\(presenter.mirror.instruction ?? "nil")")

        let turned: ActionResult = presenter.send("compass.turn", [1], port: shell.port)
        #expect(turned == .accepted, "\(turned.code)")
        #expect(try Teaching.core(shell).tutorial == .probe)
        #expect(presenter.mirror.instruction == HueCompassTutorialStep.probe.text,
                "\(presenter.mirror.instruction ?? "nil")")

        let probed: ActionResult = presenter.send("compass.probe", [], port: shell.port)
        #expect(probed == .accepted, "\(probed.code)")
        #expect(try Teaching.core(shell).play.stage == .playing)
        #expect(try Teaching.core(shell).tutorial == .select)
        #expect(presenter.mirror.instruction == HueCompassTutorialStep.select.text,
                "\(presenter.mirror.instruction ?? "nil")")

        presenter.dismissTutorial(port: shell.port)
        #expect(try Teaching.core(shell).tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
    }

    /// A wrong selection fails with the selection explanation; Retry in campaign is `level.select` of the level and
    /// gives a fresh play.
    @Test func failureAfterAWrongSelectionAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: HueCompassPresenter = shell.presenter
        let level: HueCompassLevel = try Teaching.core(shell).play.level
        #expect(presenter.mirror.failureText == nil)

        let selected: ActionResult = presenter.send("compass.select", Teaching.missValues(level), port: shell.port)
        #expect(selected == .accepted, "\(selected.code)")
        let failed: HueCompassExperienceCore = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        #expect(failed.play.failure == .selection)
        let want: String = try #require(failed.failureExplanation?.text)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == want)
        #expect(shown.hasPrefix("The target was bearing \(level.target) (band \(level.targetBand + 1))."), "\(shown)")
        #expect(shown.hasSuffix(Teaching.advice), "\(shown)")
        #expect(presenter.mirror.stage == .failed)
        #expect(shell.accessibilitySummary.contains("The search failed. " + want))

        // No hint once the play has ended.
        presenter.showHint(port: shell.port)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        // Retry in campaign is `level.select` of the level.
        let action: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(action.control == "level.select")
        #expect(action.values == [1])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: HueCompassExperienceCore = try Teaching.core(shell)
        #expect(fresh.levelNumber == 1)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.spent == 0)
        #expect(fresh.play.stage == .playing)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.spent == 0)
    }

    /// Spending the allowance on probes fails with the probe explanation; Retry restores a fresh play.
    @Test func failureAfterProbeExhaustionAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: HueCompassPresenter = shell.presenter
        let allowance: Int = try Teaching.core(shell).play.level.allowance
        for index in 0..<allowance {
            let result: ActionResult = presenter.send("compass.probe", [], port: shell.port)
            #expect(result == .accepted, "probe \(index): \(result.code)")
        }
        let failed: HueCompassExperienceCore = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        #expect(failed.play.failure == .probes)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == failed.failureExplanation?.text)
        #expect(shown == "The last unit went to a probe; keep one for the selection. Retry the level.", "\(shown)")
        #expect(presenter.mirror.spent == allowance)

        // Nothing can be undone after the failure; Retry gives a fresh play.
        let undo: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(!undo.isAccepted)
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: HueCompassExperienceCore = try Teaching.core(shell)
        #expect(fresh.levelNumber == 1)
        #expect(fresh.play.spent == 0)
        #expect(fresh.play.clues.isEmpty)
        #expect(fresh.play.stage == .playing)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.message == nil)
    }

    /// A locked level and `level.next` without an open next level are refused with `r02-g04.locked`, shown in the
    /// mirror's message, and change nothing.
    @Test func pickerRefusesALockedLevel() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: HueCompassPresenter = shell.presenter
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        let digest: String = try HueCompassTest.digest(shell)

        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(locked == .rejected(.rule(code: HueCompassExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g04.locked"))
        let message: String = try #require(presenter.mirror.message, "the refusal is shown")
        #expect(message.contains("r02-g04.locked"), "\(message)")
        #expect(try HueCompassTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.frontier == 1)

        let next: ActionResult = presenter.send("level.next", [], port: shell.port)
        #expect(next == .rejected(.rule(code: HueCompassExperienceRule.locked)), "\(next.code)")
        #expect(try HueCompassTest.digest(shell) == digest)

        // An accepted action clears the refusal.
        let open: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(open == .accepted, "\(open.code)")
        #expect(presenter.mirror.message == nil)
    }

    /// The daily level of 2026-01-01 is 1 and Retry keeps that date; 2026-01-02 plays locked level 48 without opening
    /// it; an impossible date is refused with `r02-g04.date` and changes nothing.
    @Test func dailyThroughThePort() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: HueCompassPresenter = shell.presenter
        #expect(presenter.mirror.mode == .campaign)
        #expect(!HueCompassControls.isDaily(presenter.mirror.mode))

        // Day 0 after 2026-01-01: (0 × 47) mod 100 + 1 = 1.
        let date: DateComponents = DateComponents(year: 2026, month: 1, day: 1)
        #expect(HueCompassPresenter.dateValues(date) == [2026, 1, 1])
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.mode == .daily(level: 1))
        #expect(HueCompassControls.isDaily(presenter.mirror.mode))
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.spent == 0)
        #expect(try Teaching.core(shell).tutorial == .aim, "the tutorial shows on levels 1 … 3 in every mode")

        // Retry keeps the date that opened the daily level, even when asked on another day.
        let later: DateComponents = DateComponents(year: 2026, month: 1, day: 5)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 1, 1])

        // An impossible date is refused and changes nothing.
        let digest: String = try HueCompassTest.digest(shell)
        let refused: ActionResult = presenter.playDaily(port: shell.port,
                                                        date: DateComponents(year: 2026, month: 2, day: 30))
        #expect(refused == .rejected(.rule(code: HueCompassExperienceRule.date)), "\(refused.code)")
        #expect(refused.code.contains("r02-g04.date"))
        let message: String = try #require(presenter.mirror.message)
        #expect(message.contains("r02-g04.date"), "\(message)")
        #expect(try HueCompassTest.digest(shell) == digest, "a refused date changes nothing")
        #expect(presenter.mirror.mode == .daily(level: 1))
        let kept: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(kept.values == [2026, 1, 1], "a refused date does not replace the daily date")

        // Day 1: (1 × 47) mod 100 + 1 = 48, locked in the campaign, playable as the daily level and not opened.
        #expect(HueCompassProgress.dailyLevel(year: 2026, month: 1, day: 2) == 48)
        let second: ActionResult = presenter.playDaily(port: shell.port,
                                                       date: DateComponents(year: 2026, month: 1, day: 2))
        #expect(second == .accepted, "\(second.code)")
        #expect(presenter.mirror.mode == .daily(level: 48))
        #expect(presenter.mirror.levelNumber == 48)
        #expect(presenter.mirror.frontier == 1, "a daily level is not opened")

        // Campaign returns to the frontier, since level 48 is not open.
        let campaign: ActionResult = presenter.send("mode.campaign", [], port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 1)
    }

    /// Practice raises the allowance to 24; the goal line names the mode, the allowance and the fewest probes; a
    /// campaign win shows 3 stars and opens level 2, and the picker titles are formatted with them.
    @Test func practiceGoalLineAndStars() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: HueCompassPresenter = shell.presenter
        let certified: HueCompassGenerated = try HueCompassExperienceCore.generated(number: 1)
        let smallest: Int = certified.solution.smallest
        let allowance: Int = presenter.mirror.allowance
        #expect(presenter.mirror.smallest == smallest)
        #expect(HueCompassControls.goal(presenter.mirror)
            == "Campaign · goal: \(allowance) units allowed, fewest probes \(smallest)")

        // Practice: the allowance is the kernel maximum.
        let practice: ActionResult = presenter.send("mode.practice", [], port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.allowance == 24)
        #expect(presenter.mirror.allowance == HueCompassExperienceCore.practiceAllowance)
        #expect(presenter.mirror.smallest == smallest)
        #expect(HueCompassControls.goal(presenter.mirror)
            == "Practice · goal: 24 units allowed, fewest probes \(smallest)")
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)

        // Daily goal line.
        let daily: ActionResult = presenter.playDaily(port: shell.port,
                                                      date: DateComponents(year: 2026, month: 1, day: 1))
        #expect(daily == .accepted, "\(daily.code)")
        #expect(HueCompassControls.goal(presenter.mirror)
            == "Daily level · goal: \(allowance) units allowed, fewest probes \(smallest)")

        // Back to campaign; selecting the target at once wins with 3 stars and opens level 2.
        let campaign: ActionResult = presenter.send("mode.campaign", [], port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.allowance == allowance)
        let level: HueCompassLevel = try Teaching.core(shell).play.level
        let won: ActionResult = presenter.send("compass.select", Teaching.targetValues(level), port: shell.port)
        #expect(won == .accepted, "\(won.code)")
        #expect(presenter.mirror.stage == .won)
        #expect(presenter.mirror.stars[1] == 3)
        #expect(presenter.mirror.frontier == 2)
        let summary: String = shell.accessibilitySummary
        #expect(summary.contains("The bearing and hue match. 3 of 3 stars."), "\(summary)")

        // Picker titles and bands.
        #expect(HueCompassControls.levelTitle(1, stars: presenter.mirror.stars[1]) == "Level 1 · 3 stars")
        #expect(HueCompassControls.levelTitle(2, stars: presenter.mirror.stars[2]) == "Level 2")
        #expect(HueCompassControls.levelTitle(7, stars: 1) == "Level 7 · 1 star")
        #expect(HueCompassControls.levelTitle(9, stars: 2) == "Level 9 · 2 stars")
        #expect(HueCompassControls.levels(inBand: 0).first == 1)
        #expect(HueCompassControls.levels(inBand: 0).last == 20)
        #expect(HueCompassControls.levels(inBand: 4).first == 81)
        #expect(HueCompassControls.levels(inBand: 4).last == 100)
    }
}
#endif
