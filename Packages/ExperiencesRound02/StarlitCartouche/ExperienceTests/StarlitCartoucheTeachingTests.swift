// StarlitCartoucheTeachingTests — feature 455 (R02-G16-05) T-R02G1605-005 (FR-R02G1605-001 … 005; clarifications
// Q1–Q5). On the simulator, through the one app's session host: the presenter's teaching and progression surface,
// modelled on feature 445's Voxel Origami teaching tests. The mirror is read after `describe` (the tests describe the
// current core themselves after every action so the presenter's latest core is the current one). Tutorial: level 1
// (seed 0) opens with the `fly` instruction (`StarlitCartoucheTutorialStep.fly.text`, also written out word for word),
// which the description names; an accepted leg that neither wins nor fails advances it to `symbol`; Dismiss through
// the port hides it and leaves the digest alone (the tutorial step is never in the digest). Hints: `showHint()` shows
// `StarlitCartouchePresenter.searchingText` while the detached search runs (awaited by a bounded poll of `hintSearch`,
// at most 5 s), then reveals levels 1, 2, 3 with texts written out here from the plan's first leg
// (`StarlitCartoucheHints.plan`) and the corridor joining the ship's star and its destination ("The next leg flies
// corridor c, between star a and star b", "Fly to star j", "Fly to star j after waiting w beats", "1 beat" singular),
// also equal to `StarlitCartoucheHint.legText`; any change of the play hides the hint, and following the level-3 hints
// wins level 1. Failure: a leg the chart fails (found on a bare core of levels 1 … 20, at most one clear leg before it)
// fails the level; the explanation of `StarlitCartoucheFailureExplanation(play:)` is in `mirror.explanation` and the
// description; a failed play's hint is `StarlitCartoucheHint.failedText`; Undo returns to playing; Retry in campaign
// is `level.select` of the level and starts it fresh. Goal and progression: `mirror.goalLabel` names the certified leg
// count and band 1 of 5; `level.next` before a win is refused with `r02-g16.locked` in words; the certified (minimal)
// win records 3 stars and adds "; best 3 of 3 stars" to the goal; the picker's Play level (`level.select` of
// `mirror.pickedLevel`) opens the newly open level 2 and refuses a locked one. Modes: an impossible date (2026-02-30)
// reads the date refusal; Daily of 2026-01-02 opens level 38 (`StarlitCartoucheProgress.dailyLevel`) in daily mode;
// Practice raises the budget to 24; Campaign returns to the frontier. Retry's action is `level.select` in campaign,
// `mode.practice` in practice and `mode.daily` with the date that opened the daily level. Explicit dates (no clock),
// no wall-clock assertion; each test short. Explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CoreGraphics
import Foundation
import StarlitCartoucheCore
import Testing
@testable import StarlitCartoucheExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Starlit Cartouche teaching tests.
@MainActor
enum StarlitCartoucheTeaching {
    typealias Shell = StarlitCartoucheTest.Shell
    typealias Core = StarlitCartoucheExperienceCore

    /// The fixed calendar day of the daily tests and its daily level ((1 × 37) mod 100 + 1).
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 1, day: 2)
    static let dailyNumber: Int = 38
    /// A later day handed to Retry: the daily level keeps the date that opened it.
    static let laterDate: DateComponents = DateComponents(year: 2026, month: 3, day: 5)
    /// An impossible day.
    static let impossibleDate: DateComponents = DateComponents(year: 2026, month: 2, day: 30)

    /// How many times the hint search is polled, and the pause between polls (at most 5 s in all).
    static let pollLimit: Int = 500
    static let pollMilliseconds: Int = 10

    /// The levels searched for a failing leg.
    static let failureLevels: ClosedRange<Int> = 1...20

    /// The `fly` instruction of clarification Q2, written out word for word.
    static let flyText: String = "Tap a star to choose where to fly, set the wait on the slider (or Wait − and +) so "
        + "the star is in range at launch, then double-tap it (or press Fly): the trail draws a stroke of the symbol"

    /// The words of a refusal with reason `code`, as the mirror reads it.
    static func refusalWords(_ code: String) -> String {
        StarlitCartoucheMirror.refusalText(code: code)
    }

    /// The panel message of a refusal with reason `code` (since feature 456 the feedback plan's words).
    static func refusalMessage(_ code: String) -> String {
        refusalWords(code)
    }

    /// Opens level `number` (seed `number − 1`) at a small view (one frame drawn) and describes the opening.
    static func open(_ session: ExperienceSession, number: Int = 1) async throws -> Shell {
        let shell: Shell = try await StarlitCartoucheTest.open(session, seed: UInt64(number - 1),
                                                               size: CGSize(width: 360, height: 240))
        _ = try describe(shell)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try StarlitCartoucheTest.core(shell)
    }

    /// Describes the current core of `shell` and returns the description.
    @discardableResult
    static func describe(_ shell: Shell) throws -> String {
        let current: Core = try StarlitCartoucheTest.core(shell)
        return shell.presenter.describe(current)
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: StarlitCartouchePresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(for: .milliseconds(pollMilliseconds))
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: StarlitCartouchePresenter) async throws {
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
    static func send(_ action: StarlitCartoucheAction, _ shell: Shell) throws -> ActionResult {
        let entry: (control: String, values: [Double]) = StarlitCartoucheTest.control(action)
        return try send(entry.control, entry.values, shell)
    }

    /// Sends the certified (minimal) plan of the shell's current level through the presenter; returns the legs
    /// accepted.
    @discardableResult
    static func win(_ shell: Shell) throws -> Int {
        let number: Int = try core(shell).levelNumber
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(number)
        #expect(!legs.isEmpty, "level \(number) has a certified plan")
        var accepted: Int = 0
        for action in legs {
            let result: ActionResult = try send(action, shell)
            #expect(result == .accepted, "leg \(accepted + 1): \(result.code)")
            guard result == .accepted else { break }
            accepted += 1
        }
        return accepted
    }

    /// The first leg of `core` (stars in order, waits 0 … 8) the kernel accepts that leaves the play playing (neither
    /// a win nor a failure), or nil.
    static func clearLeg(_ core: Core) -> StarlitCartoucheAction? {
        let starCount: Int = core.play.level.stars.count
        for star in 0..<starCount where star != core.play.star {
            for wait in Core.waitRange {
                var copy: Core = core
                let action: StarlitCartoucheAction = .leg(star, wait)
                guard copy.apply(StarlitCartoucheTest.experienceAction(action)) == .accepted else { continue }
                if copy.play.stage == .playing { return action }
            }
        }
        return nil
    }

    /// The first set-up over ``failureLevels`` of at most one clear leg followed by a leg the kernel accepts and the
    /// chart fails (the play `failed`, not on the budget), searched on bare opening cores: the level, the set-up and
    /// the failing leg.
    static func failureCase() throws
        -> (number: Int, setUp: [StarlitCartoucheAction], failing: StarlitCartoucheAction)? {
        for number in failureLevels {
            let opening: Core = try Core.opening(number: number)
            var frontier: [(core: Core, actions: [StarlitCartoucheAction])] = [(opening, [])]
            for _ in 0..<2 {
                var next: [(core: Core, actions: [StarlitCartoucheAction])] = []
                for item in frontier {
                    let starCount: Int = item.core.play.level.stars.count
                    for star in 0..<starCount where star != item.core.play.star {
                        for wait in Core.waitRange {
                            var copy: Core = item.core
                            let action: StarlitCartoucheAction = .leg(star, wait)
                            let result: ActionResult = copy.apply(StarlitCartoucheTest.experienceAction(action))
                            guard result == .accepted else { continue }
                            if copy.play.stage == .failed, let failure = copy.play.failure, !isBudget(failure) {
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

    /// Whether `failure` is the spent budget.
    static func isBudget(_ failure: StarlitCartoucheFailure) -> Bool {
        if case .budget = failure { return true }
        return false
    }

    /// "w beats", or "1 beat", written out here.
    static func beats(_ wait: Int) -> String {
        wait == 1 ? "1 beat" : "\(wait) beats"
    }

    /// The three hint texts of a leg to star `star` after `wait` beats along corridor `corridor` joining stars `a`
    /// and `b`, written out here.
    static func expectedTexts(star: Int, wait: Int, corridor: Int, a: Int, b: Int) -> [String] {
        ["The next leg flies corridor \(corridor), between star \(a) and star \(b)",
         "Fly to star \(star)",
         "Fly to star \(star) after waiting \(beats(wait))"]
    }
}

@MainActor
@Suite(.serialized) struct StarlitCartoucheTeachingTests {
    typealias Teaching = StarlitCartoucheTeaching
    typealias Core = StarlitCartoucheExperienceCore

    /// Level 1 opens with the tutorial's `fly` instruction, which the description names; an accepted leg that
    /// neither wins nor fails advances it to `symbol`; Dismiss hides it and leaves the digest alone.
    @Test func levelOneTutorialShownAdvancedAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: StarlitCartouchePresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .fly)
        #expect(opening.play.stage == .playing)
        let first: String = StarlitCartoucheTutorialStep.fly.text
        #expect(first == Teaching.flyText, "the fly instruction word for word")
        #expect(presenter.mirror.instruction == first, "\(presenter.mirror.instruction ?? "nil")")
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.frontier == 1)
        #expect(presenter.mirror.stars.isEmpty)
        #expect(presenter.mirror.certifiedLegs == opening.certifiedLegs)
        #expect(presenter.mirror.pickedLevel == 1)
        #expect(presenter.mirror.explanation == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        let text: String = presenter.describe(opening)
        #expect(text.hasPrefix("Starlit Cartouche level 1. "), "\(text)")
        #expect(text.contains("Tutorial: " + first), "\(text)")

        // A clear leg (accepted, the play still playing) advances `fly` to `symbol`.
        let leg: StarlitCartoucheAction = try #require(Teaching.clearLeg(opening), "level 1 has a clear leg")
        let flown: ActionResult = try Teaching.send(leg, shell)
        #expect(flown == .accepted, "\(flown.code)")
        let after: Core = try Teaching.core(shell)
        #expect(after.play.stage == .playing)
        let want: StarlitCartoucheTutorialStep = StarlitCartoucheTutorialStep.fly.advanced(afterLeg: true, ended: false)
        #expect(want == .symbol)
        #expect(after.tutorial == want, "\(after.tutorial)")
        #expect(presenter.mirror.instruction == want.text, "\(presenter.mirror.instruction ?? "nil")")
        let flownText: String = try Teaching.describe(shell)
        #expect(flownText.contains("Tutorial: " + want.text), "\(flownText)")
        let digest: String = try StarlitCartoucheTest.digest(shell)

        presenter.dismissTutorial(port: shell.port)
        let dismissedText: String = try Teaching.describe(shell)
        let dismissed: Core = try Teaching.core(shell)
        #expect(dismissed.tutorial == .done)
        #expect(presenter.mirror.instruction == nil, "Dismiss hides the instruction")
        #expect(presenter.mirror.message == nil)
        #expect(!dismissedText.contains("Tutorial:"), "\(dismissedText)")
        #expect(try StarlitCartoucheTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// The searching text shows while the detached search runs; three hints reveal levels 1, 2, 3 with the exact
    /// texts for level 1's opening; the digest never changes; a change of the play hides the hint; following the
    /// level-3 hints wins level 1.
    @Test func hintLevelsRevealAndFollowingThemWins() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: StarlitCartouchePresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let digest: String = try StarlitCartoucheTest.digest(shell)

        // The expected texts, written out from the plan's first leg and the corridor it flies.
        let plan: StarlitCartoucheHintPlan = try #require(StarlitCartoucheHints.plan(opening.play))
        #expect(plan.legs.count == opening.certifiedLegs, "a minimal plan from the opening has the certified size")
        let firstLeg: StarlitCartoucheAction = try #require(plan.legs.first)
        var star: Int = 0
        var wait: Int = 0
        switch firstLeg {
        case let .leg(j, w):
            star = j
            wait = w
        }
        let level: StarlitCartoucheLevel = opening.play.level
        let index: Int = try #require(StarlitCartoucheChart.corridor(level, joining: opening.play.star, star),
                                      "the hinted leg flies a corridor")
        let corridor: StarlitCartoucheCorridor = level.corridors[index]
        let texts: [String] = Teaching.expectedTexts(star: star, wait: wait, corridor: index,
                                                     a: corridor.a, b: corridor.b)
        for hintLevel in 1...3 {
            let legText: String = StarlitCartoucheHint.legText(level: hintLevel, star: star, wait: wait,
                                                               corridor: index, a: corridor.a, b: corridor.b)
            #expect(legText == texts[hintLevel - 1], "legText level \(hintLevel): \(legText)")
        }
        let levels: [StarlitCartoucheHint?] = StarlitCartouchePresenter.hintLevels(opening.play)
        #expect(levels.count == 3)

        presenter.showHint()
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.hintSearch != nil, "the search runs off the main actor")
        #expect(presenter.mirror.hintText == StarlitCartouchePresenter.searchingText)
        #expect(StarlitCartouchePresenter.searchingText == "Finding a hint\u{2026}")
        let finished: Bool = try await Teaching.awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 5 s")

        for hintLevel in 1...3 {
            if hintLevel > 1 { try await Teaching.pressHint(presenter) }
            #expect(presenter.mirror.hintLevel == hintLevel)
            #expect(presenter.mirror.hintText == texts[hintLevel - 1],
                    "level \(hintLevel): \(presenter.mirror.hintText ?? "nil")")
            #expect(levels[hintLevel - 1]?.text == texts[hintLevel - 1])
            #expect(levels[hintLevel - 1]?.kind == .leg)
            #expect(levels[hintLevel - 1]?.action == firstLeg)
            #expect(try StarlitCartoucheTest.digest(shell) == digest, "hint \(hintLevel) leaves the state alone")
        }
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 3, "the hint stops at level 3")
        #expect(presenter.mirror.hintText == texts[2])
        let described: String = try Teaching.describe(shell)
        #expect(described.contains("Hint: " + texts[2]), "\(described)")

        // Any change of the play hides the hint: follow the hinted leg.
        let followed: ActionResult = try Teaching.send(firstLeg, shell)
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
            let hints: [StarlitCartoucheHint?] = StarlitCartouchePresenter.hintLevels(current.play)
            let third: StarlitCartoucheHint = try #require(hints[2], "round \(rounds + 1) has a hint")
            #expect(third.kind == .leg)
            #expect(presenter.mirror.hintLevel == 3)
            #expect(presenter.mirror.hintText == third.text, "\(presenter.mirror.hintText ?? "nil")")
            let action: StarlitCartoucheAction = try #require(third.action, "the hint names a leg")
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "\(result.code)")
            guard result == .accepted else { break }
            rounds += 1
        }
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won, "following the hints wins: \(won.play.stage)")
        #expect(StarlitCartouchePresenter.hintLevels(won.play)[0] == nil, "a won play has no hint")
    }

    /// A leg the chart fails fails the level: the explanation is in the panel and the description, the failed play's
    /// hint is the advice; Undo returns to playing; Retry starts the level fresh.
    @Test func failureExplainedUndoAndRetry() async throws {
        let found = try Teaching.failureCase()
        let failure = try #require(found, "a failing leg exists on levels 1 … 20")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: failure.number)
        let presenter: StarlitCartouchePresenter = shell.presenter
        #expect(presenter.mirror.explanation == nil)
        for action in failure.setUp {
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "set-up \(action): \(result.code)")
        }
        let failedLeg: ActionResult = try Teaching.send(failure.failing, shell)
        #expect(failedLeg == .accepted, "\(failedLeg.code)")
        let text: String = try Teaching.describe(shell)
        let failed: Core = try Teaching.core(shell)
        #expect(failed.play.stage == .failed, "\(failed.play.stage)")
        let explanation: String = try #require(StarlitCartoucheFailureExplanation(play: failed.play)?.text)
        #expect(presenter.mirror.explanation == explanation, "\(presenter.mirror.explanation ?? "nil")")
        var head: String = ""
        switch failure.failing {
        case let .leg(j, w):
            head = "Action \(failure.setUp.count + 1) (a leg to star \(j) after \(Teaching.beats(w)))"
        }
        #expect(explanation.hasPrefix(head), "\(explanation)")
        #expect(explanation.hasSuffix(" " + StarlitCartoucheFailureExplanation.advice), "\(explanation)")
        #expect(StarlitCartoucheFailureExplanation.advice == "Undo the last action or retry the level.")
        let reason: String = try #require(StarlitCartoucheMirror.failureText(failed.play.failure))
        #expect(presenter.mirror.failureText == reason, "\(presenter.mirror.failureText ?? "nil")")
        #expect(presenter.mirror.status == "Failed: " + reason, "\(presenter.mirror.status)")
        #expect(text.contains(explanation), "\(text)")

        // The failed play's hint is the advice.
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == StarlitCartoucheHint.failedText, "\(presenter.mirror.hintText ?? "nil")")

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
        let retryAction: (control: String, values: [Double]) = presenter.retryAction(date: Teaching.laterDate)
        #expect(retryAction.control == "level.select")
        #expect(retryAction.values == [Double(failure.number)])
        let retried: ActionResult = presenter.retry(port: shell.port, date: Teaching.laterDate)
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

    /// `level.next` before a win is refused with `r02-g16.locked` in words; the goal names the certified legs and band
    /// 1; the minimal win records 3 stars and the goal adds the best stars; the picker's Play level opens level 2,
    /// refuses a locked level and replays level 1.
    @Test func goalStarsLockedNextAndPicker() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: StarlitCartouchePresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let unit: String = opening.certifiedLegs == 1 ? "leg" : "legs"
        let goal: String = "Goal: draw the symbol in \(opening.certifiedLegs) \(unit); band 1 of 5"
        #expect(presenter.mirror.goalLabel == goal, "\(presenter.mirror.goalLabel)")
        let openingText: String = try Teaching.describe(shell)
        #expect(openingText.contains(" " + goal + "."), "\(openingText)")

        let digest: String = try StarlitCartoucheTest.digest(shell)
        let early: ActionResult = try Teaching.send("level.next", [], shell)
        #expect(early == .rejected(.rule(code: StarlitCartoucheExperienceRule.locked)), "\(early.code)")
        let lockedWords: String = Teaching.refusalWords(StarlitCartoucheExperienceRule.locked)
        #expect(lockedWords == "That level is not open yet.")
        #expect(presenter.mirror.message == Teaching.refusalMessage(StarlitCartoucheExperienceRule.locked),
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == StarlitCartoucheExperienceRule.locked)
        #expect(try StarlitCartoucheTest.digest(shell) == digest, "a refused level.next changes nothing")

        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(1)
        #expect(legs.count == opening.certifiedLegs)
        #expect(try Teaching.win(shell) == legs.count)
        let text: String = try Teaching.describe(shell)
        let won: Core = try Teaching.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.progress.solved[1]?.stars == 3)
        #expect(presenter.mirror.stars[1] == 3, "the minimal win earns every star")
        #expect(presenter.mirror.goalLabel == goal + "; best 3 of 3 stars", "\(presenter.mirror.goalLabel)")
        #expect(text.contains("Stars: 3 of 3."), "\(text)")
        #expect(text.contains(" " + goal + "; best 3 of 3 stars."), "\(text)")
        #expect(presenter.mirror.status == "Won")
        #expect(presenter.mirror.instruction == nil, "the end of the level ends the tutorial")
        #expect(presenter.mirror.frontier == 2)
        #expect(presenter.mirror.pickedLevel == 1)

        // The picker's Play level: level.select of the picked level, now open.
        presenter.mirror.pickedLevel = min(presenter.mirror.pickedLevel + 1, presenter.mirror.frontier)
        #expect(presenter.mirror.pickedLevel == 2)
        let picked: ActionResult = try Teaching.send("level.select", [Double(presenter.mirror.pickedLevel)], shell)
        #expect(picked == .accepted, "\(picked.code)")
        let second: Core = try Teaching.core(shell)
        #expect(second.levelNumber == 2)
        #expect(second.mode == .campaign)
        #expect(second.play.records.isEmpty)
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.pickedLevel == 2)
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.stars[1] == 3, "the stars of level 1 stay")
        #expect(!presenter.mirror.goalLabel.contains("best"), "level 2 is not won: \(presenter.mirror.goalLabel)")

        // A locked level is refused by the picker in words; nothing changes.
        let secondDigest: String = try StarlitCartoucheTest.digest(shell)
        let locked: ActionResult = try Teaching.send("level.select", [5], shell)
        #expect(locked == .rejected(.rule(code: StarlitCartoucheExperienceRule.locked)), "\(locked.code)")
        #expect(presenter.mirror.message == Teaching.refusalMessage(StarlitCartoucheExperienceRule.locked))
        #expect(try StarlitCartoucheTest.digest(shell) == secondDigest, "a refused pick changes nothing")
        #expect(presenter.mirror.levelNumber == 2)

        // Back to level 1 through the picker: a fresh play whose goal keeps its best stars.
        let back: ActionResult = try Teaching.send("level.select", [1], shell)
        #expect(back == .accepted, "\(back.code)")
        let replay: Core = try Teaching.core(shell)
        #expect(replay.levelNumber == 1)
        #expect(replay.play.stage == .playing)
        #expect(presenter.mirror.goalLabel == goal + "; best 3 of 3 stars", "\(presenter.mirror.goalLabel)")
    }

    /// An impossible date reads the date refusal; Daily of 2026-01-02 opens level 38 in daily mode; Practice raises
    /// the budget to 24; Campaign returns to the frontier.
    @Test func dailyPracticeAndCampaignModes() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: StarlitCartouchePresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(presenter.mirror.mode == .campaign)

        // An impossible date: refused with r02-g16.date, in words, nothing changed.
        let digest: String = try StarlitCartoucheTest.digest(shell)
        #expect(StarlitCartouchePresenter.dateValues(Teaching.impossibleDate) == [2026, 2, 30])
        let impossible: ActionResult = presenter.playDaily(port: shell.port, date: Teaching.impossibleDate)
        _ = try Teaching.describe(shell)
        #expect(impossible == .rejected(.rule(code: StarlitCartoucheExperienceRule.date)), "\(impossible.code)")
        let dateWords: String = Teaching.refusalWords(StarlitCartoucheExperienceRule.date)
        #expect(dateWords == "That date cannot be used.")
        #expect(presenter.mirror.message == Teaching.refusalMessage(StarlitCartoucheExperienceRule.date),
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == StarlitCartoucheExperienceRule.date)
        #expect(try StarlitCartoucheTest.digest(shell) == digest)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.dailyDate == nil, "a refused date is not kept")

        // Daily of 2026-01-02: level 38.
        let number: Int = try #require(StarlitCartoucheProgress.dailyLevel(year: 2026, month: 1, day: 2))
        #expect(number == Teaching.dailyNumber)
        #expect(StarlitCartouchePresenter.dateValues(Teaching.dailyDate) == [2026, 1, 2])
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
        let band: Int = StarlitCartoucheProgress.band(of: number)
        #expect(band == 2)
        #expect(presenter.mirror.goalLabel.hasSuffix("band \(band) of 5"), "\(presenter.mirror.goalLabel)")

        // Practice: the budget is the kernel's maximum, 24.
        let practice: ActionResult = try Teaching.send("mode.practice", [], shell)
        #expect(practice == .accepted, "\(practice.code)")
        let practiceCore: Core = try Teaching.core(shell)
        #expect(practiceCore.mode == .practice)
        #expect(practiceCore.levelNumber == number)
        #expect(Core.practiceBudget == 24)
        #expect(practiceCore.play.level.budget == 24)
        #expect(practiceCore.play.actionsLeft == 24)
        #expect(presenter.mirror.mode == .practice)
        #expect(presenter.mirror.budget == 24)
        #expect(presenter.mirror.actionsLeft == 24)

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
    }

    /// Retry's action follows the mode: `level.select` of the level in campaign, `mode.daily` with the date that opened
    /// the daily level (not a later one), `mode.practice` in practice; each Retry is accepted and keeps the mode.
    @Test func retryActionFollowsTheMode() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: StarlitCartouchePresenter = shell.presenter

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
