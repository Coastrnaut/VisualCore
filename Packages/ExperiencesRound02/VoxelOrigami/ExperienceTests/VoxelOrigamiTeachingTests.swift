// VoxelOrigamiTeachingTests — feature 445 (R02-G15-05) T-R02G1505-005 (FR-R02G1505-001 … 005; clarifications Q1–Q5).
// On the simulator, through the one app's session host: the presenter's teaching and progression surface, modelled on
// feature 435's Moonlit Mechanism teaching tests. The mirror is read after `describe` (the tests describe the current
// core themselves after every action so the presenter's latest core is the current one). Tutorial: level 1 (seed 0)
// opens with the `turn` instruction (`VoxelOrigamiTutorialStep.turn.text`), which the description names; an accepted
// turn that neither wins nor fails advances it to `compare`; Dismiss through the port hides it and leaves the digest
// alone (the tutorial step is never in the digest). Hints: `showHint()` shows `VoxelOrigamiPresenter.searchingText`
// while the detached search runs (awaited by a bounded poll of `hintSearch`, at most 5 s), then reveals levels 1, 2, 3
// with the texts of `VoxelOrigamiPresenter.hintLevels(_:)`, which are checked word for word against
// `VoxelOrigamiHint.turnText` ("The next turn swings cube k", "Turn hinge h", "Turn hinge h forward (+1)" / "Turn hinge
// h back (−1)", U+2212) for the hinge's tracked cube (`VoxelOrigamiPicker.trackedCube`); any change of the play hides
// the hint, and following the level-3 hints wins level 1. Failure: a turn that collides or sweeps (found on a bare core
// of levels 1 … 20, at most one clear turn before it) fails the level; the explanation of
// `VoxelOrigamiFailureExplanation(play:)` is in `mirror.explanation` and the description; a failed play's hint is
// `VoxelOrigamiHint.failedText`; Undo returns to playing; Retry in campaign is `level.select` of the level and starts
// it fresh. Goal and progression: `mirror.goalLabel` names the certified turn count and band 1 of 5; `level.next`
// before a win is refused with `r02-g15.locked` in words; the certified (minimal) win records 3 stars, adds "; best 3
// of 3 stars" to the goal, opens level 2, and `level.next` then plays it. Modes: an impossible date (2026-02-30) reads
// the date refusal; Daily of 2026-01-02 opens level 32 (`VoxelOrigamiProgress.dailyLevel`) in daily mode; Practice
// raises the budget to 40; Campaign returns to the frontier; a locked level is refused by the picker. Retry's action is
// `level.select` in campaign, `mode.practice` in practice and `mode.daily` with the date that opened the daily level.
// Synthetic data, no wall-clock assertion; each test short. Explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
@testable import VoxelOrigamiExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VoxelOrigamiCore

/// Helpers of the Voxel Origami teaching tests.
@MainActor
enum VoxelOrigamiTeaching {
    typealias Shell = VoxelOrigamiTest.Shell
    typealias Core = VoxelOrigamiExperienceCore

    /// The fixed calendar day of the daily tests and its daily level ((1 × 31) mod 100 + 1).
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 1, day: 2)
    static let dailyNumber: Int = 32
    /// A later day handed to Retry: the daily level keeps the date that opened it.
    static let laterDate: DateComponents = DateComponents(year: 2026, month: 3, day: 5)
    /// An impossible day.
    static let impossibleDate: DateComponents = DateComponents(year: 2026, month: 2, day: 30)

    /// How many times the hint search is polled, and the pause between polls (at most 5 s in all).
    static let pollLimit: Int = 500
    static let pollMilliseconds: Int = 10

    /// The levels searched for a colliding or sweeping turn.
    static let failureLevels: ClosedRange<Int> = 1...20

    /// The words of a refusal with reason `code`, as the mirror reads it.
    static func refusalWords(_ code: String) -> String {
        VoxelOrigamiMirror.refusalText(code: code)
    }

    /// Opens level `number` (seed `number − 1`) at a small view (one frame drawn) and describes the opening.
    static func open(_ session: ExperienceSession, number: Int = 1) async throws -> Shell {
        let shell: Shell = try await VoxelOrigamiTest.open(session, seed: UInt64(number - 1),
                                                           size: CGSize(width: 360, height: 240))
        _ = try describe(shell)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try VoxelOrigamiTest.core(shell)
    }

    /// Describes the current core of `shell` and returns the description.
    @discardableResult
    static func describe(_ shell: Shell) throws -> String {
        let current: Core = try VoxelOrigamiTest.core(shell)
        return shell.presenter.describe(current)
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: VoxelOrigamiPresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(for: .milliseconds(pollMilliseconds))
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: VoxelOrigamiPresenter) async throws {
        presenter.showHint()
        let finished: Bool = try await awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")
    }

    /// Sends `control` with `values` through the presenter (the path of the controls), describes the result and
    /// returns it.
    @discardableResult
    static func send(_ control: String, _ values: [Double], _ shell: Shell) throws -> ActionResult {
        let result: ActionResult = shell.presenter.send(control, values, port: shell.port)
        _ = try describe(shell)
        return result
    }

    /// Sends the kernel action `action` through the presenter, describes the result and returns it.
    @discardableResult
    static func send(_ action: VoxelOrigamiAction, _ shell: Shell) throws -> ActionResult {
        let entry: (control: String, values: [Double]) = VoxelOrigamiTest.control(action)
        return try send(entry.control, entry.values, shell)
    }

    /// Sends the certified (minimal) plan of the shell's current level through the presenter; returns the turns
    /// accepted.
    @discardableResult
    static func win(_ shell: Shell) throws -> Int {
        let number: Int = try core(shell).levelNumber
        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(number)
        #expect(!turns.isEmpty, "level \(number) has a certified plan")
        var accepted: Int = 0
        for action in turns {
            let result: ActionResult = try send(action, shell)
            #expect(result == .accepted, "turn \(accepted + 1): \(result.code)")
            guard result == .accepted else { break }
            accepted += 1
        }
        return accepted
    }

    /// The first turn of `core` (turnable hinges in order, `+1` before `−1`) the kernel accepts that leaves the play
    /// playing (neither a win nor a failure), or nil.
    static func clearTurn(_ core: Core) -> VoxelOrigamiAction? {
        let steps: [Int] = [1, -1]
        for hinge in core.snapshot(time: 0).turnable {
            for step in steps {
                var copy: Core = core
                let action: VoxelOrigamiAction = .turn(hinge, step)
                guard copy.apply(VoxelOrigamiTest.experienceAction(action)) == .accepted else { continue }
                if copy.play.stage == .playing { return action }
            }
        }
        return nil
    }

    /// The first set-up over ``failureLevels`` of at most one clear turn followed by a turn the kernel refuses with a
    /// collision or a sweep, searched on bare opening cores: the level, the set-up and the failing turn.
    static func failureCase() throws -> (number: Int, setUp: [VoxelOrigamiAction], failing: VoxelOrigamiAction)? {
        let steps: [Int] = [1, -1]
        for number in failureLevels {
            let opening: Core = try Core.opening(number: number)
            var frontier: [(core: Core, actions: [VoxelOrigamiAction])] = [(opening, [])]
            for _ in 0..<2 {
                var next: [(core: Core, actions: [VoxelOrigamiAction])] = []
                for item in frontier {
                    for hinge in item.core.snapshot(time: 0).turnable {
                        for step in steps {
                            var copy: Core = item.core
                            let action: VoxelOrigamiAction = .turn(hinge, step)
                            guard copy.apply(VoxelOrigamiTest.experienceAction(action)) == .accepted else { continue }
                            if copy.play.stage == .failed, VoxelOrigamiTest.isTurnFailure(copy.play.failure) {
                                return (number, item.actions, action)
                            }
                            if copy.play.stage == .playing, next.count < 64 {
                                next.append((copy, item.actions + [action]))
                            }
                        }
                    }
                }
                frontier = next
            }
        }
        return nil
    }

    /// The three hint texts of a turn hint of hinge `hinge` by `step` with tracked cube `cube`, written out here.
    static func expectedTexts(hinge: Int, step: Int, cube: Int) -> [String] {
        let way: String = step < 0 ? "back (\u{2212}1)" : "forward (+1)"
        return ["The next turn swings cube \(cube)", "Turn hinge \(hinge)", "Turn hinge \(hinge) \(way)"]
    }
}

@MainActor
@Suite(.serialized) struct VoxelOrigamiTeachingTests {
    typealias Teaching = VoxelOrigamiTeaching
    typealias Core = VoxelOrigamiExperienceCore

    /// Level 1 opens with the tutorial's `turn` instruction, which the description names; an accepted turn that
    /// neither wins nor fails advances it to `compare`; Dismiss hides it and leaves the digest alone.
    @Test func levelOneTutorialShownAdvancedAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: VoxelOrigamiPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .turn)
        #expect(opening.play.stage == .playing)
        let first: String = VoxelOrigamiTutorialStep.turn.text
        #expect(!first.isEmpty)
        #expect(presenter.mirror.instruction == first, "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.certifiedTurns == opening.certifiedTurns)
        #expect(presenter.mirror.pickedLevel == 1)
        #expect(presenter.mirror.explanation == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let text: String = presenter.describe(opening)
        #expect(text.hasPrefix("Voxel Origami level 1. "), "\(text)")
        #expect(text.contains("Tutorial: " + first), "\(text)")

        // A clear turn (accepted, the play still playing) advances `turn` to `compare`.
        let turn: VoxelOrigamiAction = try #require(Teaching.clearTurn(opening), "level 1 has a clear turn")
        let turned: ActionResult = try Teaching.send(turn, shell)
        #expect(turned == .accepted, "\(turned.code)")
        let after: Core = try Teaching.core(shell)
        #expect(after.play.stage == .playing)
        let want: VoxelOrigamiTutorialStep = VoxelOrigamiTutorialStep.turn.advanced(afterTurn: true, ended: false)
        #expect(want == .compare)
        #expect(after.tutorial == want, "\(after.tutorial)")
        #expect(presenter.mirror.instruction == want.text, "\(presenter.mirror.instruction ?? "nil")")
        let turnedText: String = try Teaching.describe(shell)
        #expect(turnedText.contains("Tutorial: " + want.text), "\(turnedText)")
        let digest: String = try VoxelOrigamiTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let dismissedText: String = try Teaching.describe(shell)
        let dismissed: Core = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        #expect(!dismissedText.contains("Tutorial:"), "\(dismissedText)")
        #expect(try VoxelOrigamiTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// The searching text shows while the detached search runs; three hints reveal levels 1, 2, 3 with the exact
    /// texts for level 1's opening; the digest never changes; a change of the play hides the hint; following the
    /// level-3 hints wins level 1.
    @Test func hintLevelsRevealAndFollowingThemWins() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: VoxelOrigamiPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let digest: String = try VoxelOrigamiTest.digest(shell)

        // The expected texts, written out from the plan's first turn and the hinge's tracked cube.
        let plan: VoxelOrigamiHintPlan = try #require(VoxelOrigamiHints.plan(opening.play))
        #expect(plan.turns.count == opening.certifiedTurns, "a minimal plan from the opening has the certified size")
        let firstTurn: VoxelOrigamiAction = try #require(plan.turns.first)
        var hinge: Int = 0
        var step: Int = 0
        switch firstTurn {
        case let .turn(h, s):
            hinge = h
            step = s
        }
        let cubes: [VoxelOrigamiCube] = opening.play.level.cubes
        let moving: [Int] = VoxelOrigamiLattice.swinging(cubes, pose: opening.play.pose, hinge: hinge)
        let cube: Int = VoxelOrigamiPicker.trackedCube(hinge, cubes: cubes, pose: opening.play.pose, moving: moving)
        let texts: [String] = Teaching.expectedTexts(hinge: hinge, step: step, cube: cube)
        let levels: [VoxelOrigamiHint?] = VoxelOrigamiPresenter.hintLevels(opening.play)
        #expect(levels.count == 3)

        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.hintSearch != nil, "the search runs off the main actor")
        #expect(presenter.mirror.hintText == VoxelOrigamiPresenter.searchingText)
        #expect(VoxelOrigamiPresenter.searchingText == "Finding a hint\u{2026}")
        let finished: Bool = try await Teaching.awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")

        for level in 1...3 {
            if level > 1 { try await Teaching.pressHint(presenter) }
            #expect(presenter.mirror.hintLevel == level)
            #expect(presenter.mirror.hintText == texts[level - 1],
                    "level \(level): \(presenter.mirror.hintText ?? "nil")")
            #expect(levels[level - 1]?.text == texts[level - 1])
            #expect(levels[level - 1]?.kind == .turn)
            #expect(try VoxelOrigamiTest.digest(shell) == digest, "hint \(level) leaves the state alone")
        }
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 3, "the hint stops at level 3")
        let described: String = try Teaching.describe(shell)
        #expect(described.contains("Hint: " + texts[2]), "\(described)")

        // Any change of the play hides the hint: follow the hinted turn.
        let followed: ActionResult = try Teaching.send(firstTurn, shell)
        #expect(followed == .accepted, "\(followed.code)")
        #expect(presenter.mirror.hintLevel == 0, "a change of the play hides the hint")
        #expect(presenter.mirror.hintText == nil)
        #expect(presenter.hintSearch == nil)
        let afterText: String = try Teaching.describe(shell)
        #expect(!afterText.contains("Hint:"), "\(afterText)")

        // Following the level-3 hints wins level 1 within the budget.
        let budget: Int = opening.play.level.budget
        var rounds: Int = 0
        while try Teaching.core(shell).play.stage == .playing && rounds < budget {
            for _ in 1...3 { try await Teaching.pressHint(presenter) }
            let current: Core = try Teaching.core(shell)
            let hints: [VoxelOrigamiHint?] = VoxelOrigamiPresenter.hintLevels(current.play)
            let third: VoxelOrigamiHint = try #require(hints[2], "round \(rounds + 1) has a hint")
            #expect(presenter.mirror.hintLevel == 3)
            #expect(presenter.mirror.hintText == third.text, "\(presenter.mirror.hintText ?? "nil")")
            let action: VoxelOrigamiAction = try #require(third.action, "the hint names a turn")
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "\(result.code)")
            guard result == .accepted else { break }
            rounds += 1
        }
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won, "following the hints wins: \(won.play.stage)")
        #expect(VoxelOrigamiPresenter.hintLevels(won.play)[0] == nil, "a won play has no hint")
    }

    /// A colliding or sweeping turn fails the level: the explanation is in the panel and the description, the failed
    /// play's hint is the advice; Undo returns to playing; Retry starts the level fresh.
    @Test func failureExplainedUndoAndRetry() async throws {
        let found = try Teaching.failureCase()
        let failure = try #require(found, "a colliding or sweeping turn exists on levels 1 … 20")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: failure.number)
        let presenter: VoxelOrigamiPresenter = shell.presenter
        #expect(presenter.mirror.explanation == nil)
        for action in failure.setUp {
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "set-up \(action): \(result.code)")
        }
        let failedTurn: ActionResult = try Teaching.send(failure.failing, shell)
        #expect(failedTurn == .accepted, "\(failedTurn.code)")
        let text: String = try Teaching.describe(shell)
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed, "\(failed.play.stage)")
        #expect(VoxelOrigamiTest.isTurnFailure(failed.play.failure))
        let explanation: String = try #require(VoxelOrigamiFailureExplanation(play: failed.play)?.text)
        #expect(presenter.mirror.explanation == explanation, "\(presenter.mirror.explanation ?? "nil")")
        var head: String = ""
        switch failure.failing {
        case let .turn(h, s):
            head = "Action \(failure.setUp.count + 1) (a turn of hinge \(h) by \(VoxelOrigamiHint.stepText(s)))"
        }
        #expect(explanation.hasPrefix(head), "\(explanation)")
        #expect(explanation.hasSuffix(" " + VoxelOrigamiFailureExplanation.advice), "\(explanation)")
        let reason: String = try #require(VoxelOrigamiMirror.failureText(failed.play.failure))
        #expect(presenter.mirror.failureText == reason, "\(presenter.mirror.failureText ?? "nil")")
        #expect(presenter.mirror.status == "Failed: " + reason, "\(presenter.mirror.status)")
        #expect(text.contains(explanation), "\(text)")

        // The failed play's hint is the advice.
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == VoxelOrigamiHint.failedText, "\(presenter.mirror.hintText ?? "nil")")

        let undone: ActionResult = presenter.undoAction(port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        _ = try Teaching.describe(shell)
        let afterUndo: Core = try Teaching.core(shell)
        #expect(afterUndo.play.stage == .playing)
        #expect(presenter.mirror.explanation == nil)
        #expect(presenter.mirror.failureText == nil)
        #expect(presenter.mirror.hintText == nil, "undo changes the play and hides the hint")

        // Fail again, then Retry: level.select of the level in campaign, a fresh play.
        let again: ActionResult = try Teaching.send(failure.failing, shell)
        #expect(again == .accepted, "\(again.code)")
        #expect(presenter.mirror.explanation != nil)
        let retryAction: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(retryAction.control == "level.select")
        #expect(retryAction.values == [Double(failure.number)])
        let retried: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(retried == .accepted, "\(retried.code)")
        _ = try Teaching.describe(shell)
        let fresh: Core = try Teaching.core(shell)
        #expect(fresh.levelNumber == failure.number)
        #expect(fresh.mode == .campaign)
        #expect(fresh.play.stage == .playing)
        #expect(fresh.play.records.isEmpty, "Retry gives a fresh play")
        #expect(fresh.play.actionsLeft == fresh.play.level.budget)
        #expect(presenter.mirror.explanation == nil)
        #expect(presenter.mirror.actionsLeft == presenter.mirror.budget)
    }

    /// `level.next` before a win is refused with `r02-g15.locked` in words; the goal names the certified turns and band
    /// 1; the minimal win records 3 stars, the goal adds the best stars, level 2 opens and `level.next` plays it.
    @Test func goalStarsAndNextLevel() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: VoxelOrigamiPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let unit: String = opening.certifiedTurns == 1 ? "turn" : "turns"
        let goal: String = "Goal: match the target in \(opening.certifiedTurns) \(unit); band 1 of 5"
        #expect(presenter.mirror.goalLabel == goal, "\(presenter.mirror.goalLabel)")
        let openingText: String = try Teaching.describe(shell)
        #expect(openingText.contains(" " + goal + "."), "\(openingText)")

        let digest: String = try VoxelOrigamiTest.digest(shell)
        let early: ActionResult = try Teaching.send("level.next", [], shell)
        #expect(early == .rejected(.rule(code: VoxelOrigamiExperienceRule.locked)), "\(early.code)")
        let lockedWords: String = Teaching.refusalWords(VoxelOrigamiExperienceRule.locked)
        #expect(lockedWords == "That level is not open yet.")   // feature 446's refusal sentence
        let message: String = presenter.mirror.message ?? ""
        #expect(message.contains(lockedWords), "\(message)")
        #expect(presenter.refusalLog.last == VoxelOrigamiExperienceRule.locked)
        #expect(try VoxelOrigamiTest.digest(shell) == digest, "a refused level.next changes nothing")

        let turns: [VoxelOrigamiAction] = try VoxelOrigamiTest.certifiedTurns(1)
        #expect(turns.count == opening.certifiedTurns)
        #expect(try Teaching.win(shell) == turns.count)
        let text: String = try Teaching.describe(shell)
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.progress.solved[1]?.stars == 3)
        #expect(presenter.mirror.stars[1] == 3, "the minimal win earns every star")
        #expect(presenter.mirror.goalLabel == goal + "; best 3 of 3 stars", "\(presenter.mirror.goalLabel)")
        #expect(presenter.mirror.goalLabel.hasSuffix("best 3 of 3 stars"))
        #expect(text.contains("Stars: 3 of 3."), "\(text)")
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
        #expect(presenter.mirror.stars[1] == 3, "the stars of level 1 stay")
        #expect(!presenter.mirror.goalLabel.contains("best"), "level 2 is not won: \(presenter.mirror.goalLabel)")
    }

    /// An impossible date reads the date refusal; Daily of 2026-01-02 opens level 32 in daily mode; Practice raises the
    /// budget to 40; Campaign returns to the frontier; the picker refuses a locked level in words.
    @Test func dailyPracticeAndCampaignModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: VoxelOrigamiPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.mode == .campaign)

        // An impossible date: refused with r02-g15.date, in words, nothing changed.
        let digest: String = try VoxelOrigamiTest.digest(shell)
        let impossible: ActionResult = presenter.playDaily(port: shell.port, date: Teaching.impossibleDate)
        _ = try Teaching.describe(shell)
        #expect(impossible == .rejected(.rule(code: VoxelOrigamiExperienceRule.date)), "\(impossible.code)")
        let dateWords: String = Teaching.refusalWords(VoxelOrigamiExperienceRule.date)
        #expect(dateWords == "That date cannot be used.")   // feature 446's refusal sentence
        let dateMessage: String = presenter.mirror.message ?? ""
        #expect(dateMessage.contains(dateWords), "\(dateMessage)")
        #expect(presenter.refusalLog.last == VoxelOrigamiExperienceRule.date)
        #expect(try VoxelOrigamiTest.digest(shell) == digest)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.dailyDate == nil, "a refused date is not kept")

        // Daily of 2026-01-02: level 32.
        let number: Int = try #require(VoxelOrigamiProgress.dailyLevel(year: 2026, month: 1, day: 2))
        #expect(number == Teaching.dailyNumber)
        #expect(VoxelOrigamiPresenter.dateValues(Teaching.dailyDate) == [2026, 1, 2])
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: Teaching.dailyDate)
        #expect(daily == .accepted, "\(daily.code)")
        _ = try Teaching.describe(shell)
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .daily(level: number))
        #expect(presenter.mirror.levelNumber == number)
        #expect(presenter.mirror.pickedLevel == number)
        #expect(presenter.dailyDate == Teaching.dailyDate)
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == number)
        #expect(dailyCore.mode == .daily(level: number))
        #expect(dailyCore.play.records.isEmpty)
        #expect(dailyCore.progress.frontier == 1, "a daily level is played without being opened")
        let band: Int = VoxelOrigamiProgress.band(of: number)
        #expect(band == 2)
        #expect(presenter.mirror.goalLabel.hasSuffix("band \(band) of 5"), "\(presenter.mirror.goalLabel)")

        // Practice: the budget is the kernel's maximum, 40.
        let practice: ActionResult = try Teaching.send("mode.practice", [], shell)
        #expect(practice == .accepted, "\(practice.code)")
        let practiceCore: Core = try Teaching.core(shell)
        #expect(practiceCore.mode == .practice)
        #expect(practiceCore.levelNumber == number)
        #expect(Core.practiceBudget == 40)
        #expect(practiceCore.play.level.budget == 40)
        #expect(practiceCore.play.actionsLeft == 40)
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == 40)

        // Campaign returns: only level 1 is open, so the frontier (level 1).
        let campaign: ActionResult = try Teaching.send("mode.campaign", [], shell)
        #expect(campaign == .accepted, "\(campaign.code)")
        let back: Core = try Teaching.core(shell)
        #expect(back.mode == .campaign)
        #expect(back.levelNumber == 1)
        #expect(back.play.level.budget == opening.play.level.budget)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.frontier == 1, "neither daily nor practice opens a level")
        #expect(back.progress.solved.isEmpty)

        // The picker refuses a locked level in words; nothing changes.
        let backDigest: String = try VoxelOrigamiTest.digest(shell)
        let locked: ActionResult = try Teaching.send("level.select", [5], shell)
        #expect(locked == .rejected(.rule(code: VoxelOrigamiExperienceRule.locked)), "\(locked.code)")
        let lockedMessage: String = presenter.mirror.message ?? ""
        #expect(lockedMessage.contains(Teaching.refusalWords(VoxelOrigamiExperienceRule.locked)), "\(lockedMessage)")
        #expect(presenter.refusalLog.last == VoxelOrigamiExperienceRule.locked)
        #expect(try VoxelOrigamiTest.digest(shell) == backDigest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 1)
    }

    /// Retry's action follows the mode: `level.select` of the level in campaign, `mode.daily` with the date that opened
    /// the daily level (not a later one), `mode.practice` in practice; each Retry is accepted and keeps the mode.
    @Test func retryActionFollowsTheMode() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: VoxelOrigamiPresenter = shell.presenter

        let campaignRetry: (control: String, values: [Double]) = presenter.retryAction(date: Teaching.laterDate)
        #expect(campaignRetry.control == "level.select")
        #expect(campaignRetry.values == [1])

        let daily: ActionResult = presenter.playDaily(port: shell.port, date: Teaching.dailyDate)
        #expect(daily == .accepted, "\(daily.code)")
        _ = try Teaching.describe(shell)
        let dailyRetry: (control: String, values: [Double]) = presenter.retryAction(date: Teaching.laterDate)
        #expect(dailyRetry.control == "mode.daily")
        #expect(dailyRetry.values == [2026, 1, 2], "Retry keeps the date that opened the daily level")
        let retriedDaily: ActionResult = presenter.retry(port: shell.port, date: Teaching.laterDate)
        #expect(retriedDaily == .accepted, "\(retriedDaily.code)")
        _ = try Teaching.describe(shell)
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.mode == .daily(level: Teaching.dailyNumber))
        #expect(dailyCore.levelNumber == Teaching.dailyNumber)

        let practice: ActionResult = try Teaching.send("mode.practice", [], shell)
        #expect(practice == .accepted, "\(practice.code)")
        let practiceRetry: (control: String, values: [Double]) = presenter.retryAction(date: Teaching.laterDate)
        #expect(practiceRetry.control == "mode.practice")
        #expect(practiceRetry.values.isEmpty)
        let retriedPractice: ActionResult = presenter.retry(port: shell.port, date: Teaching.laterDate)
        #expect(retriedPractice == .accepted, "\(retriedPractice.code)")
        _ = try Teaching.describe(shell)
        let practiceCore: Core = try Teaching.core(shell)
        #expect(practiceCore.mode == .practice)
        #expect(practiceCore.levelNumber == Teaching.dailyNumber)
        #expect(practiceCore.play.records.isEmpty)
    }
}
#endif
