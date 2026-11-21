// WaveKnotKeeperTeachingTests — feature 325 (R02-G03-05) T-R02G0305-005 (FR-R02G0305-001 … 005;
// SC-R02G0305-001 … 004).
// On the simulator, through the one app's session host: the presenter's teaching and progression surface. Hints:
// `showHint(port:)` reveals levels 1, 2, 3 in that order with the core's `hint(level:)` texts ("Move point n",
// "… along a", "… <direction>"), a fourth press stays at level 3, the state's digest never changes, and an accepted move
// hides the hint once the presenter describes the new play. Tutorial: level 1 (seed 0) shows "Drag point n one step (or
// use the panel)" for the level-1 hint's point, a non-winning move advances it to the signature instruction, a hint
// sends `tutorial.hint` (the hints instruction) and Dismiss hides the instruction. Failure: the core's
// `allowanceEntries` spend level 1's allowance; the failure text is the core's explanation and ends with "Undo the last
// move or retry the level.", Undo clears it and Retry in campaign is `level.select` of the level. Picker: a locked level
// is refused with `r02-g03.locked`, shown in the mirror's message, and changes nothing. Modes: the daily level of
// 2026-01-01 is 1 (day 0 × 43 mod 100 + 1), `retryAction` keeps that date, 2026-02-30 is refused with `r02-g03.date`;
// practice raises the allowance to 64; the goal line and the picker titles are formatted as the controls show them.
// Wave Knot Keeper's presenter has no announcement route, so no announcement is checked. Synthetic data, no sleep, no
// wall-clock assertion; each test well under 10 s. Test data uses explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the teaching tests.
@MainActor
enum WaveKnotKeeperTeaching {
    typealias Shell = ExperienceShell<WaveKnotKeeperPresenter>

    /// The advice every failure text ends with (clarification Q5).
    static let advice: String = "Undo the last move or retry the level."

    /// Opens level `seed % 100 + 1` at a small view (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await WaveKnotKeeperTest.open(session, seed: seed, size: CGSize(width: 360, height: 240))
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> WaveKnotKeeperExperienceCore {
        try #require(shell.engine.core)
    }

    /// The index of `direction` in the control's direction order (the second value of `point.move`).
    static func directionIndex(_ direction: WaveKnotKeeperDirection) -> Int {
        let order: [WaveKnotKeeperDirection] = WaveKnotKeeperExperienceCore.directionOrder
        for index in 0..<order.count where order[index] == direction { return index }
        return -1
    }

    /// The values of the `point.move` action of `move`: point, direction index.
    static func values(_ move: WaveKnotKeeperMove) -> [Double] {
        [Double(move.point), Double(directionIndex(move.direction))]
    }

    /// Sends `move` through the presenter and the shell's port.
    @discardableResult
    static func send(_ move: WaveKnotKeeperMove, _ shell: Shell) -> ActionResult {
        shell.presenter.send("point.move", values(move), port: shell.port)
    }

    /// A legal move of `core`'s play that keeps it playing (checked by trial on a copy); nil when none.
    static func nonWinningMove(_ core: WaveKnotKeeperExperienceCore) -> WaveKnotKeeperMove? {
        let play: WaveKnotKeeperPlay = core.play
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperExperienceCore.directionOrder
        for point in 0..<play.points.count {
            for direction in directions {
                let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                var trial: WaveKnotKeeperPlay = play
                do {
                    try trial.apply(move, expecting: trial.fingerprint)
                } catch {
                    continue
                }
                if trial.stage == .playing { return move }
            }
        }
        return nil
    }

    /// Plays the certified solution of level `number` through the presenter; every move must be accepted.
    static func playCertified(_ number: Int, _ shell: Shell) throws {
        let certified: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: number)
        for move in certified.solution.moves {
            let result: ActionResult = send(move, shell)
            #expect(result == .accepted, "\(result.code)")
        }
    }
}

@MainActor
@Suite(.serialized) struct WaveKnotKeeperTeachingTests {
    typealias Teaching = WaveKnotKeeperTeaching

    /// Three hints reveal the point, the axis and the direction with the core's texts; a fourth stays at level 3; the
    /// digest never changes; an accepted move hides the hint.
    @Test func hintLevelsThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        let opening: WaveKnotKeeperExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let digest: String = try WaveKnotKeeperTest.digest(shell)
        let third: WaveKnotKeeperHint = try #require(opening.hint(level: 3))
        #expect(third.withinMoves)
        let direction: WaveKnotKeeperDirection = try #require(third.direction)

        for level in 1...3 {
            presenter.showHint(port: shell.port)
            let want: WaveKnotKeeperHint = try #require(opening.hint(level: level))
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == want.text, "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(try WaveKnotKeeperTest.digest(shell) == digest, "hint \(level) leaves the state alone")
        }
        #expect(presenter.mirror.hintText == "Move point \(third.point + 1) "
            + WaveKnotKeeperHint.directionName(direction))
        presenter.showHint(port: shell.port)
        #expect(presenter.mirror.hintLevel == 3, "a fourth press stays at level 3")
        #expect(presenter.mirror.hintText == third.text)
        #expect(try WaveKnotKeeperTest.digest(shell) == digest)

        // Following the level-3 hint: accepted, and the description of the new play hides the hint.
        let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: third.point, direction: direction)
        let result: ActionResult = Teaching.send(move, shell)
        #expect(result == .accepted, "\(result.code)")
        #expect(try Teaching.core(shell).play.spent == 1)
        #expect(presenter.mirror.hintLevel == 0, "an accepted move hides the hint")
        #expect(presenter.mirror.hintText == nil)
    }

    /// Level 1 shows the move instruction for the level-1 hint's point; a move advances it to the signature, a hint to
    /// the hints instruction (`tutorial.hint`), and Dismiss hides it.
    @Test func tutorialOnLevelOne() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: 0)
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        let opening: WaveKnotKeeperExperienceCore = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        let first: WaveKnotKeeperHint = try #require(opening.hint(level: 1))
        #expect(opening.tutorial == .move(first.point))
        let want: String = "Drag point \(first.point + 1) one step (or use the panel)"
        #expect(presenter.mirror.instruction == want, "\(presenter.mirror.instruction ?? "nil")")

        // A non-winning move advances to the signature instruction.
        let move: WaveKnotKeeperMove = try #require(Teaching.nonWinningMove(opening), "a non-winning move on level 1")
        let moved: ActionResult = Teaching.send(move, shell)
        #expect(moved == .accepted, "\(moved.code)")
        #expect(try Teaching.core(shell).play.stage == .playing)
        #expect(try Teaching.core(shell).tutorial == .signature)
        let signature: String = "Match the target's crossings and twist (writhe); strands pass through each other only "
            + "inside the blue gates"
        #expect(presenter.mirror.instruction == signature, "\(presenter.mirror.instruction ?? "nil")")

        // A hint sends `tutorial.hint`: the tutorial moves to the hints instruction and the hint stays shown.
        presenter.showHint(port: shell.port)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(try Teaching.core(shell).tutorial == .hints)
        #expect(presenter.mirror.instruction == "Ask for a hint whenever you are stuck",
                "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.hintLevel == 1, "telling the core about the hint keeps the hint")

        // Dismiss hides the instruction.
        presenter.dismissTutorial(port: shell.port)
        #expect(try Teaching.core(shell).tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
    }

    /// Spending the allowance shows the core's explanation; Undo clears it; Retry in campaign is `level.select` of the
    /// level and gives a fresh play.
    @Test func failureExplanationUndoAndRetry() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, seed: WaveKnotKeeperExperienceCore.manifestSeed)
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        let entries: [ScenarioStep] = WaveKnotKeeperExperienceCore.allowanceEntries
        try #require(!entries.isEmpty, "an allowance-spending alternation exists")
        let allowance: Int = try Teaching.core(shell).play.level.allowance
        #expect(entries.count == allowance)
        #expect(presenter.mirror.failureText == nil)
        for index in 0..<entries.count {
            let action: ScriptedAction = try #require(entries[index].action)
            let result: ActionResult = presenter.send(action.control, action.values, port: shell.port)
            #expect(result == .accepted, "move \(index): \(result.code)")
        }
        let failed: WaveKnotKeeperExperienceCore = try Teaching.core(shell)
        #expect(failed.play.stage == .failed)
        let want: String = try #require(failed.failureExplanation?.text)
        let shown: String = try #require(presenter.mirror.failureText, "the failure is explained")
        #expect(shown == want)
        #expect(shown.hasSuffix(Teaching.advice), "\(shown)")
        #expect(presenter.mirror.stage == .failed)
        #expect(shell.accessibilitySummary.contains("Out of moves. " + want))

        // Undo rewinds the failing move and clears the explanation.
        let undo: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(undo == .accepted, "\(undo.code)")
        #expect(try Teaching.core(shell).play.stage == .playing)
        #expect(presenter.mirror.spent == allowance - 1)
        #expect(presenter.mirror.failureText == nil)

        // Retry in campaign is `level.select` of the level.
        let action: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(action.control == "level.select")
        #expect(action.values == [1])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        let fresh: WaveKnotKeeperExperienceCore = try Teaching.core(shell)
        #expect(fresh.levelNumber == 1)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.spent == 0)
        #expect(fresh.play.stage == .playing)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.spent == 0)
    }

    /// A locked level is refused with `r02-g03.locked`, shown in the mirror's message, and changes nothing.
    @Test func pickerRefusesALockedLevel() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        let digest: String = try WaveKnotKeeperTest.digest(shell)

        let locked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(locked == .rejected(.rule(code: WaveKnotKeeperExperienceRule.locked)), "\(locked.code)")
        #expect(locked.code.contains("r02-g03.locked"))
        let message: String = try #require(presenter.mirror.message, "the refusal is shown")
        #expect(message.contains("r02-g03.locked"), "\(message)")
        #expect(try WaveKnotKeeperTest.digest(shell) == digest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.frontier == 1)

        // An accepted action clears the refusal.
        let open: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(open == .accepted, "\(open.code)")
        #expect(presenter.mirror.message == nil)
    }

    /// The daily level of 2026-01-01 is 1 and Retry keeps that date; an impossible date is refused with
    /// `r02-g03.date` and changes nothing.
    @Test func dailyThroughThePort() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        #expect(presenter.mirror.mode == .campaign)
        #expect(!WaveKnotKeeperControls.isDaily(presenter.mirror.mode))

        // Day 0 after 2026-01-01: (0 × 43) mod 100 + 1 = 1.
        let date: DateComponents = DateComponents(year: 2026, month: 1, day: 1)
        #expect(WaveKnotKeeperPresenter.dateValues(date) == [2026, 1, 1])
        #expect(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        #expect(presenter.mirror.mode == .daily(level: 1))
        #expect(WaveKnotKeeperControls.isDaily(presenter.mirror.mode))
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.spent == 0)
        #expect(try Teaching.core(shell).tutorial == .done, "the tutorial is campaign-only")

        // Retry keeps the date that opened the daily level, even when asked on another day.
        let later: DateComponents = DateComponents(year: 2026, month: 1, day: 5)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(retry.control == "mode.daily")
        #expect(retry.values == [2026, 1, 1])

        // An impossible date is refused and changes nothing.
        let digest: String = try WaveKnotKeeperTest.digest(shell)
        let refused: ActionResult = presenter.playDaily(port: shell.port,
                                                        date: DateComponents(year: 2026, month: 2, day: 30))
        #expect(refused == .rejected(.rule(code: WaveKnotKeeperExperienceRule.date)), "\(refused.code)")
        #expect(refused.code.contains("r02-g03.date"))
        let message: String = try #require(presenter.mirror.message)
        #expect(message.contains("r02-g03.date"), "\(message)")
        #expect(try WaveKnotKeeperTest.digest(shell) == digest, "a refused date changes nothing")
        #expect(presenter.mirror.mode == .daily(level: 1))
        let kept: (control: String, values: [Double]) = presenter.retryAction(date: later)
        #expect(kept.values == [2026, 1, 1], "a refused date does not replace the daily date")
    }

    /// Practice raises the allowance to 64; the goal line names the mode, the allowance and the certified shortest;
    /// a campaign win shows 3 stars, and the picker titles are formatted with them.
    @Test func practiceGoalLineAndStars() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session)
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        let certified: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: 1)
        let allowance: Int = presenter.mirror.allowance
        #expect(presenter.mirror.shortest == certified.solution.shortest)
        #expect(WaveKnotKeeperControls.goal(presenter.mirror)
            == "Campaign · goal: \(allowance) moves allowed, best possible \(certified.solution.shortest)")

        // Practice: the allowance is the kernel maximum.
        let practice: ActionResult = presenter.send("mode.practice", [], port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.allowance == 64)
        #expect(presenter.mirror.allowance == WaveKnotKeeperExperienceCore.practiceAllowance)
        #expect(presenter.mirror.shortest == certified.solution.shortest)
        #expect(WaveKnotKeeperControls.goal(presenter.mirror)
            == "Practice · goal: 64 moves allowed, best possible \(certified.solution.shortest)")
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)

        // Daily goal line.
        let daily: ActionResult = presenter.playDaily(port: shell.port,
                                                      date: DateComponents(year: 2026, month: 1, day: 1))
        #expect(daily == .accepted, "\(daily.code)")
        #expect(WaveKnotKeeperControls.goal(presenter.mirror)
            == "Daily level · goal: \(allowance) moves allowed, best possible \(certified.solution.shortest)")

        // Back to campaign; the certified solution wins with 3 stars and opens level 2.
        let campaign: ActionResult = presenter.send("mode.campaign", [], port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.allowance == allowance)
        try Teaching.playCertified(1, shell)
        #expect(presenter.mirror.stage == .won)
        #expect(presenter.mirror.stars[1] == 3)
        #expect(presenter.mirror.frontier == 2)
        let summary: String = shell.accessibilitySummary
        #expect(summary.contains("The knot matches. 3 of 3 stars."), "\(summary)")

        // Picker titles.
        #expect(WaveKnotKeeperControls.levelTitle(1, stars: presenter.mirror.stars[1]) == "Level 1 · 3 stars")
        #expect(WaveKnotKeeperControls.levelTitle(2, stars: presenter.mirror.stars[2]) == "Level 2")
        #expect(WaveKnotKeeperControls.levelTitle(7, stars: 1) == "Level 7 · 1 star")
        #expect(WaveKnotKeeperControls.levelTitle(9, stars: 2) == "Level 9 · 2 stars")
    }
}
#endif
