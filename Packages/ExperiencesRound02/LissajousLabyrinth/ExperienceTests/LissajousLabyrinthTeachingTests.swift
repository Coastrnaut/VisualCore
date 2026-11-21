// LissajousLabyrinthTeachingTests — feature 315 (R02-G02-05) T-R02G0205-005 (FR-R02G0205-001 … 005;
// SC-R02G0205-001 … 004).
// On the simulator, through the one app's session host: the presenter's teaching and progression surface. Hints:
// `showHint(port:)` reveals "Turn <Title>.", "Raise/Lower <Title>.", "Set <Title> to <v>." in that order (texts written
// out here from the core's `hint(level:)` dial, direction and value), each announced, a fourth reveal stays at level 3,
// the state's digest never changes, an accepted action hides the hint, and following the level-3 hint's action shortens
// the shortest remaining solution by one or wins. Tutorial: level 1 (seed 0) shows the turn instruction naming the
// level-1 hint's dial and Dismiss clears it; on level 3 (seed 2) a non-winning action advances to the checkpoints
// instruction, a hint to the hints instruction, undo never moves it back, and the win clears it. Failure: level 1
// driven to `failed` through the port shows the core's explanation (checked against the kernel's verdict with
// ⌊100 · tick / 4,096⌋ written out here), no hint is offered, Undo returns to playing and Retry restarts the level in
// campaign. Picker: a locked level is refused ("That level is not open yet.", feature 316) and changes nothing; a
// certified win of level 1 opens level 2 with 3 stars, described as "3 of 3 stars.". Modes: the daily level of
// 2026-01-02 is 42 (days 1 × 41 mod 100 + 1), a daily win records stars without opening levels, 2026-02-30 is refused
// with `r02-g02.date`, practice raises the allowance to 64 and records nothing, campaign returns to an open level;
// `retryAction` per mode. Announcements go to a feedback route with VoiceOver off (the presenter's own `announcements`
// log is read). Synthetic data, no sleep, no wall-clock assertion; each test well under 10 s. Test data uses explicit
// types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the teaching tests.
@MainActor
enum LissajousLabyrinthTeaching {
    typealias Shell = ExperienceShell<LissajousLabyrinthPresenter>

    /// Opens level `seed % 100 + 1` with a feedback route that posts nothing (VoiceOver off; the presenter still logs
    /// every announcement).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        let shell: Shell = try await LissajousLabyrinthTest.open(session, seed: seed,
                                                                 size: CGSize(width: 360, height: 240))
        shell.presenter.feedback = ExperienceFeedback(voiceOverRunning: { false })
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> LissajousLabyrinthExperienceCore {
        try #require(shell.engine.core)
    }

    /// The dial titles, written out independently of the presenter and the core.
    static func title(_ dial: LissajousLabyrinthDial) -> String {
        switch dial {
        case .frequencyA: "Frequency A"
        case .frequencyB: "Frequency B"
        case .phaseA: "Phase A"
        case .phaseC: "Phase C"
        }
    }

    /// The expected hint text of `level` for the first action (`dial`, `value`) of a shortest remaining solution from
    /// `dials` (clarification Q1).
    static func hintText(level: Int, dial: LissajousLabyrinthDial, value: Int,
                         dials: LissajousLabyrinthDials) -> String {
        let name: String = title(dial)
        switch level {
        case 1: return "Turn \(name)."
        case 2: return (value > dials[dial] ? "Raise " : "Lower ") + name + "."
        default: return "Set \(name) to \(value)."
        }
    }

    /// The expected failure text of `verdict` (clarification Q5), the percentage ⌊100 · tick / 4,096⌋.
    static func failureText(_ verdict: LissajousLabyrinthVerdict) -> String? {
        let advice: String = " Undo the last change or retry the level."
        switch verdict {
        case .contact(let obstacle, let tick):
            let percent: Int = (100 * tick) / 4_096
            return "The path touches obstacle \(obstacle + 1) at \(percent) % of the lap." + advice
        case .missed(let checkpoint):
            return "Checkpoint \(checkpoint + 1) is not reached in order." + advice
        case .won:
            return nil
        }
    }

    /// A phase C value that, alternated with the start value from `opening`, spends the whole allowance without a win
    /// and fails the play on the last action (checked by trial on copies of the play); nil when none.
    static func losingPhase(from opening: LissajousLabyrinthPlay) -> Int? {
        let allowance: Int = opening.level.allowance
        let start: Int = opening.dials.phaseC
        for candidate in 0..<16 where candidate != start {
            var trial: LissajousLabyrinthPlay = opening
            var fine: Bool = true
            for index in 0..<allowance {
                let value: Int = index % 2 == 0 ? candidate : start
                do {
                    try trial.apply(LissajousLabyrinthAction(dial: .phaseC, value: value), expecting: trial.fingerprint)
                } catch {
                    fine = false
                    break
                }
                let last: Bool = index == allowance - 1
                if trial.stage != (last ? LissajousLabyrinthStage.failed : .playing) {
                    fine = false
                    break
                }
            }
            if fine { return candidate }
        }
        return nil
    }

    /// An accepted action of `core`'s play that keeps it playing with a shortest remaining solution within the actions
    /// left (checked by trial on a copy); the level-3 hint's action is tried first. nil when none.
    static func nonWinningAction(_ core: LissajousLabyrinthExperienceCore) -> LissajousLabyrinthAction? {
        var candidates: [LissajousLabyrinthAction] = []
        if let hint = core.hint(level: 3), let value = hint.value {
            candidates.append(LissajousLabyrinthAction(dial: hint.dial, value: value))
        }
        for dial in LissajousLabyrinthDial.allCases {
            for value in dial.range where value != core.play.dials[dial] {
                candidates.append(LissajousLabyrinthAction(dial: dial, value: value))
            }
        }
        for action in candidates {
            var trial: LissajousLabyrinthPlay = core.play
            do {
                try trial.apply(action, expecting: trial.fingerprint)
            } catch {
                continue
            }
            guard trial.stage == .playing else { continue }
            guard let next = LissajousLabyrinthHints.hint(level: 3, play: trial, winning: core.winning),
                  next.withinActions else { continue }
            return action
        }
        return nil
    }

    /// Follows the level-3 hint through the presenter until the play is won (at most the allowance); returns the
    /// number of actions sent.
    @discardableResult
    static func winByHints(_ shell: Shell) throws -> Int {
        var sent: Int = 0
        let limit: Int = try core(shell).play.level.allowance
        while try core(shell).play.stage == .playing && sent < limit {
            let hint: LissajousLabyrinthHint = try #require(try core(shell).hint(level: 3))
            #expect(hint.withinActions, "the hint fits in the actions left")
            let value: Int = try #require(hint.value)
            let result: ActionResult = shell.presenter.send(LissajousLabyrinthAction(dial: hint.dial, value: value),
                                                            port: shell.port)
            #expect(result == .accepted, "\(result.code)")
            sent += 1
        }
        return sent
    }
}

@MainActor
@Suite(.serialized) struct LissajousLabyrinthTeachingTests {
    typealias Teaching = LissajousLabyrinthTeaching

    /// Three hints reveal the dial, the direction and the value, each announced; a fourth stays at level 3; the digest
    /// never changes; an accepted action hides the hint; following the level-3 hint shortens the remaining solution.
    @Test func hintLevelsThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        let opening: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try LissajousLabyrinthTest.digest(shell)
        let third: LissajousLabyrinthHint = try #require(opening.hint(level: 3))
        let value: Int = try #require(third.value)
        #expect(third.withinActions)

        for level in 1...3 {
            let count: Int = presenter.announcements.count
            presenter.showHint(port: shell.port)
            let want: String = Teaching.hintText(level: level, dial: third.dial, value: value,
                                                 dials: opening.play.dials)
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(presenter.announcements.count == count + 1)
            #expect(presenter.announcements.last == want, "the hint is announced")
            #expect(try LissajousLabyrinthTest.digest(shell) == digest, "hint \(level) leaves the state alone")
        }
        presenter.showHint(port: shell.port)
        #expect(presenter.mirror.hintLevel == 3, "a fourth reveal stays at level 3")
        #expect(presenter.mirror.hintText == "Set \(Teaching.title(third.dial)) to \(value).")
        #expect(try LissajousLabyrinthTest.digest(shell) == digest)

        // Following the level-3 hint through the port: accepted, the hint is hidden, the remaining solution shrinks.
        let result: ActionResult = presenter.send(LissajousLabyrinthAction(dial: third.dial, value: value),
                                                  port: shell.port)
        #expect(result == .accepted, "\(result.code)")
        let after: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
        #expect(after.play.spent == 1)
        #expect(after.play.dials[third.dial] == value)
        #expect(presenter.mirror.hintLevel == 0, "a change of the play hides the hint")
        #expect(presenter.mirror.hintText == nil)
        if after.play.stage == .playing {
            let next: LissajousLabyrinthHint = try #require(after.hint(level: 3))
            #expect(next.remaining == third.remaining - 1)
            presenter.showHint(port: shell.port)
            #expect(presenter.mirror.hintLevel == 1, "a new play starts at level 1")
            #expect(presenter.mirror.hintText == "Turn \(Teaching.title(next.dial)).")
        } else {
            #expect(after.play.stage == .won)
            #expect(third.remaining == 1)
            presenter.showHint(port: shell.port)
            #expect(presenter.mirror.hintLevel == 0, "no hint once the play has ended")
            #expect(presenter.mirror.hintText == nil)
        }
    }

    /// Level 1 shows the turn instruction of the level-1 hint's dial and Dismiss clears it; on level 3 a non-winning
    /// action advances to the checkpoints instruction, a hint to the hints instruction, and the win clears it.
    @Test func tutorialOnLevelsOneAndThree() async throws {
        do {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Teaching.open(session, seed: 0)
            let presenter: LissajousLabyrinthPresenter = shell.presenter
            let opening: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
            #expect(opening.levelNumber == 1)
            let first: LissajousLabyrinthHint = try #require(opening.hint(level: 1))
            let want: String = "Turn the \(Teaching.title(first.dial)) ring to change the path."
            #expect(presenter.mirror.instruction == want, "\(presenter.mirror.instruction ?? "nil")")
            presenter.dismissTutorial(port: shell.port)
            #expect(try Teaching.core(shell).tutorial == .done)
            #expect(presenter.mirror.instruction == nil, "Dismiss clears the instruction")
            #expect(presenter.mirror.message == nil)
        }

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 2)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        let opening: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 3)
        let first: LissajousLabyrinthHint = try #require(opening.hint(level: 1))
        #expect(presenter.mirror.instruction == "Turn the \(Teaching.title(first.dial)) ring to change the path.")

        // A non-winning action advances to the checkpoints instruction.
        let action: LissajousLabyrinthAction = try #require(Teaching.nonWinningAction(opening),
                                                            "a non-winning action on level 3")
        let moved: ActionResult = presenter.send(action, port: shell.port)
        #expect(moved == .accepted, "\(moved.code)")
        #expect(try Teaching.core(shell).play.stage == .playing)
        let checkpoints: String = "Copper checkpoints light up when the lap reaches them in order; "
            + "keep the path off the violet spheres."
        #expect(presenter.mirror.instruction == checkpoints, "\(presenter.mirror.instruction ?? "nil")")

        // Undo never moves the tutorial back.
        let undo: ActionResult = presenter.send("play.undo", port: shell.port)
        #expect(undo == .accepted, "\(undo.code)")
        #expect(presenter.mirror.instruction == checkpoints, "undo keeps the step")

        // A hint advances to the hints instruction.
        presenter.showHint(port: shell.port)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.instruction == "Ask for a hint whenever you are stuck.",
                "\(presenter.mirror.instruction ?? "nil")")

        // Winning clears it.
        try Teaching.winByHints(shell)
        #expect(try Teaching.core(shell).play.stage == .won)
        #expect(try Teaching.core(shell).tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "the win ends the tutorial")
    }

    /// Spending the allowance without a win shows the kernel's explanation; no hint; Undo returns to playing; Retry
    /// restarts the level in campaign.
    @Test func failureExplanationUndoAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        let opening: LissajousLabyrinthPlay = try Teaching.core(shell).play
        let allowance: Int = opening.level.allowance
        try #require(allowance >= 2)
        let start: Int = opening.dials.phaseC
        let losing: Int = try #require(Teaching.losingPhase(from: opening), "a losing alternation for phase C")
        #expect(presenter.mirror.failureText == nil)
        for index in 0..<allowance {
            let value: Int = index % 2 == 0 ? losing : start
            let result: ActionResult = presenter.send(LissajousLabyrinthAction(dial: .phaseC, value: value),
                                                      port: shell.port)
            #expect(result == .accepted, "action \(index): \(result.code)")
        }
        let failed: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let verdict: LissajousLabyrinthVerdict = try #require(failed.play.failure)
        #expect(LissajousLabyrinthLap.ticks == 4_096)
        let want: String = try #require(Teaching.failureText(verdict), "a failing verdict: \(verdict)")
        #expect(failed.failureExplanation?.text == want)
        #expect(presenter.mirror.failureText == want, "\(presenter.mirror.failureText ?? "nil")")
        #expect(presenter.mirror.stage == .failed)
        let summary: String = shell.accessibilitySummary
        #expect(summary.contains("Out of actions. " + want), "\(summary)")

        // No hint once the play has ended.
        presenter.showHint(port: shell.port)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        // Undo through the port rewinds the failing action.
        let undo: ActionResult = presenter.send("play.undo", port: shell.port)
        #expect(undo == .accepted, "\(undo.code)")
        let rewound: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
        #expect(rewound.play.stage == .playing)
        #expect(rewound.play.spent == allowance - 1)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.stage == .playing)

        // Retry in campaign is `level.select` of the level and gives a fresh play.
        let retryAction: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(retryAction.control == "level.select")
        #expect(retryAction.values == [1])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
        #expect(fresh.levelNumber == 1)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.records.isEmpty)
        #expect(fresh.play.spent == 0)
        #expect(fresh.play.stage == .playing)
        #expect(fresh.play.dials == opening.dials)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.spent == 0)
        #expect(presenter.mirror.mode == .campaign)
    }

    /// A locked level is refused with its reason and changes nothing; a certified win of level 1 opens level 2 with
    /// 3 stars, described as "3 of 3 stars.".
    @Test func pickerRefusesLockedLevelsAndProgressOpensTheNext() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        let digest: String = try LissajousLabyrinthTest.digest(shell)

        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(locked == .rejected(.rule(code: LissajousLabyrinthExperienceRule.locked)), "\(locked.code)")
        let message: String = try #require(presenter.mirror.message, "the refusal is shown")
        // Feature 316: refusals are announced in words (LissajousLabyrinthFeedbackPlan.refused).
        #expect(locked.code.contains("r02-g02.locked"))
        #expect(message == "That level is not open yet.", "\(message)")
        #expect(presenter.announcements.last == message, "the refusal is announced")
        #expect(try LissajousLabyrinthTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(try Teaching.core(shell).levelNumber == 1)
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.frontier == 1)

        let certified: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: 1)
        #expect(presenter.mirror.shortest == certified.solution.shortest)
        for action in certified.solution.actions {
            let result: ActionResult = presenter.send(action, port: shell.port)
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(try Teaching.core(shell).play.stage == .won)
        #expect(presenter.mirror.stage == .won)
        #expect(presenter.mirror.message == nil, "an accepted action clears the refusal")
        #expect(presenter.mirror.frontier == 2)
        #expect(presenter.mirror.stars[1] == 3)
        let summary: String = shell.accessibilitySummary
        #expect(summary.contains("The path is safe. 3 of 3 stars."), "\(summary)")

        let picked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(picked == .accepted, "\(picked.code)")
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.stage == .playing)
        #expect(presenter.mirror.frontier == 2)
        #expect(presenter.mirror.stars[1] == 3)
    }

    /// Daily, practice and campaign through the port, with the retry action of each mode.
    @Test func dailyPracticeAndCampaignThroughThePort() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        #expect(presenter.mirror.mode == .campaign)
        let campaignRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(campaignRetry.control == "level.select")
        #expect(campaignRetry.values == [1])

        // The daily level of 2026-01-02: one day after 2026-01-01, (1 × 41) mod 100 + 1 = 42.
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let epoch: Date = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let date: DateComponents = DateComponents(year: 2026, month: 1, day: 2)
        let day: Date = try #require(calendar.date(from: date))
        let days: Int = try #require(calendar.dateComponents([.day], from: epoch, to: day).day)
        let dailyNumber: Int = ((days * 41) % 100 + 100) % 100 + 1
        #expect(dailyNumber == 42)
        #expect(LissajousLabyrinthPresenter.dateValues(date) == [2026, 1, 2])

        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.levelNumber == dailyNumber)
        #expect(presenter.mirror.mode == .daily(level: dailyNumber))
        #expect(presenter.mirror.spent == 0)
        #expect(presenter.mirror.frontier == 1)
        let dailyRetry: (control: String, values: [Double]) = presenter.retryAction(date: date)
        #expect(dailyRetry.control == "mode.daily")
        #expect(dailyRetry.values == [2026, 1, 2])

        // A daily win records the result but opens nothing.
        let certified: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: dailyNumber)
        for action in certified.solution.actions {
            let result: ActionResult = presenter.send(action, port: shell.port)
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(presenter.mirror.stage == .won)
        #expect(presenter.mirror.stars[dailyNumber] == 3)
        #expect(presenter.mirror.frontier == 1, "a daily win opens no level")
        #expect(shell.accessibilitySummary.contains("3 of 3 stars."))

        // An impossible date is refused and changes nothing.
        let digest: String = try LissajousLabyrinthTest.digest(shell)
        let refused: ActionResult = presenter.playDaily(port: shell.port,
                                                        date: DateComponents(year: 2026, month: 2, day: 30))
        #expect(refused == .rejected(.rule(code: LissajousLabyrinthExperienceRule.date)), "\(refused.code)")
        #expect(refused.code.contains("r02-g02.date"))
        #expect(presenter.mirror.message == "That date cannot be used.")
        #expect(try LissajousLabyrinthTest.digest(shell) == digest, "a refused date changes nothing")
        #expect(presenter.mirror.mode == .daily(level: dailyNumber))

        // Practice: the allowance is 64 and a win records nothing.
        let progress: LissajousLabyrinthProgress = try Teaching.core(shell).progress
        let practice: ActionResult = presenter.send("mode.practice", port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.allowance == 64)
        #expect(presenter.mirror.allowance == LissajousLabyrinthExperienceCore.practiceAllowance)
        #expect(presenter.mirror.levelNumber == dailyNumber)
        #expect(presenter.mirror.spent == 0)
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: date)
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)
        // A detour, then the hints to a win: the practice win records nothing.
        let opening: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
        let detour: LissajousLabyrinthAction = try #require(Teaching.nonWinningAction(opening), "a practice detour")
        #expect(presenter.send(detour, port: shell.port) == .accepted)
        try Teaching.winByHints(shell)
        let won: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.progress == progress, "practice records nothing")
        #expect(presenter.mirror.stars[dailyNumber] == 3)
        #expect(presenter.mirror.frontier == 1)
        #expect(!shell.accessibilitySummary.contains("of 3 stars"), "practice shows no stars")
        let retried: ActionResult = presenter.retry(port: shell.port, date: date)
        #expect(retried == .accepted, "\(retried.code)")
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.spent == 0)

        // Campaign: level 42 is not open, so campaign returns to the frontier, level 1.
        let campaign: ActionResult = presenter.send("mode.campaign", port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        let back: LissajousLabyrinthExperienceCore = try Teaching.core(shell)
        #expect(back.mode == .campaign)
        #expect(back.progress.isOpen(back.levelNumber))
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.allowance == back.play.level.allowance)
        let backRetry: (control: String, values: [Double]) = presenter.retryAction(date: date)
        #expect(backRetry.control == "level.select")
        #expect(backRetry.values == [1])
    }
}
#endif
