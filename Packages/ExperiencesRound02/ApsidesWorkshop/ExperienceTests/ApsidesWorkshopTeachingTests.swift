// ApsidesWorkshopTeachingTests — feature 475 (R02-G18-05) T-R02G1805-005 (FR-R02G1805-001 … 005, 007; clarifications
// Q1 … Q5). On the simulator, through the one app's session host: the presenter's teaching and progression surface,
// modelled on feature 465's Celestial Eclipse Lab teaching tests. The mirror is read after `describe` (the tests
// describe the current core themselves after every action so the presenter's latest core is the current one).
// Tutorial: level 1 (seed 0) opens with the `knob` instruction (`ApsidesWorkshopTutorialStep.knob.text`), which the
// description names; an accepted tuning advances it to `order`; Dismiss through the port hides it and leaves the digest
// alone (the tutorial step is never in the digest). Hints: `showHint()` shows `ApsidesWorkshopPresenter.searchingText`
// while the detached search runs (awaited by a bounded poll of `hintSearch`, at most 10 s), then reveals levels 1, 2, 3
// whose texts equal `ApsidesWorkshopHints.hint(level:play:)` computed directly; the digest never changes; any change of
// the play hides the hint, and a search started before the change never owns the hint afterwards; following the
// level-3 hints and then the play hint wins level 1 with 3 stars ("Best: 3 of 3 stars"), opens level 2 for the level
// picker, and a won play has no hint (`noHintText`, level 0). Failure: playing the revolution at level 1's opening (a
// starting orbit never wins) fails it; `mirror.explanation` equals `ApsidesWorkshopFailureExplanation(play:)?.text`,
// the description names it, and the failed play's hint is `ApsidesWorkshopHint.failedText`. Progression: the band
// label of levels 1 and 21, the goal label; the modes (Practice raises the budget to 24, Daily of 2026-01-02 opens its
// daily level 24 in daily mode although it is locked in the campaign, Campaign returns to the frontier); a locked
// level, `level.next` on the last open level and an impossible date (2026-02-30) are refused in words and change
// nothing. Explicit dates (no clock), no wall-clock assertion; each test short. Explicit types and plain loops (CI
// type-check rule). Synthetic data only. Since feature 476 (R02-G18-06) the refusal lines are the feedback plan's
// sentences ("That level is not open yet.", "That date cannot be used.").
#if os(iOS)
import ApsidesWorkshopCore
import CoreGraphics
import Foundation
import Testing
@testable import ApsidesWorkshopExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Apsides Workshop teaching tests.
@MainActor
enum ApsidesWorkshopTeaching {
    typealias Shell = ApsidesWorkshopTest.Shell
    typealias Core = ApsidesWorkshopExperienceCore

    /// The fixed calendar day of the daily test and its daily level ((1 × 23) mod 100 + 1).
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 1, day: 2)
    static let dailyNumber: Int = 24
    /// An impossible day.
    static let impossibleDate: DateComponents = DateComponents(year: 2026, month: 2, day: 30)
    /// The practice budget (the kernel's maximum).
    static let practiceBudget: Int = 24
    /// The level the mode test opens (its opening opens levels 1 … 5).
    static let modeLevel: Int = 5

    /// How many times the hint search is polled, and the pause between polls (at most 10 s in all).
    static let pollLimit: Int = 1_000
    static let pollMilliseconds: Int = 10
    /// The most hint-guided steps tried when following the hints (at most 2 tunings, then the play).
    static let followLimit: Int = 4

    /// The panel message of a refusal with reason `code` (since feature 476 the feedback plan's sentence).
    static func refusalMessage(_ code: String) -> String {
        ApsidesWorkshopMirror.refusalMessage(code: code)
    }

    /// Opens level `number` (seed `number − 1`) at a small view (one frame drawn, tick 0 shown) and describes the
    /// opening.
    static func open(_ session: ExperienceSession, number: Int = 1) async throws -> Shell {
        let shell: Shell = try await ApsidesWorkshopTest.open(session, seed: UInt64(number - 1),
                                                              size: CGSize(width: 360, height: 240), atHalf: false)
        _ = try describe(shell)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try ApsidesWorkshopTest.core(shell)
    }

    /// Describes the current core of `shell` and returns the description.
    @discardableResult
    static func describe(_ shell: Shell) throws -> String {
        let current: Core = try ApsidesWorkshopTest.core(shell)
        return shell.presenter.describe(current)
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: ApsidesWorkshopPresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(for: .milliseconds(pollMilliseconds))
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: ApsidesWorkshopPresenter) async throws {
        presenter.showHint()
        let finished: Bool = try await awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 10 s")
    }

    /// Sends `action` through the presenter (the path of the controls), describes the result and returns it.
    @discardableResult
    static func send(_ action: ApsidesWorkshopAction, _ shell: Shell) throws -> ActionResult {
        let entry: (control: String, values: [Double]) = ApsidesWorkshopTest.control(action)
        let result: ActionResult = shell.presenter.send(entry.control, entry.values, port: shell.port)
        _ = try describe(shell)
        return result
    }

    /// The hint texts of levels 1 … 3 for `play`, computed directly by the Core.
    nonisolated static func expectedTexts(_ play: ApsidesWorkshopPlay) -> [String?] {
        var texts: [String?] = []
        for level in 1...3 {
            texts.append(ApsidesWorkshopHints.hint(level: level, play: play)?.text)
        }
        return texts
    }

    /// Whether `result` is a refusal with the kernel reason `code` (read with or without the engine's prefix).
    static func isRefusal(_ result: ActionResult, _ code: String) -> Bool {
        !result.isAccepted && ApsidesWorkshopMirror.bareCode(result.code) == code
    }
}

@MainActor
@Suite(.serialized) struct ApsidesWorkshopTeachingTests {
    typealias Teaching = ApsidesWorkshopTeaching
    typealias Core = ApsidesWorkshopExperienceCore
    typealias Step = ApsidesWorkshopTutorialStep

    /// Level 1 opens with the tutorial's `knob` instruction, which the panel and the description name; an accepted
    /// tuning advances it to `order`; Dismiss hides it and leaves the digest alone.
    @Test func levelOneTutorialShownAdvancedAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .knob)
        #expect(opening.play.stage == .playing)
        let first: String = Step.knob.text
        #expect(first.hasPrefix("Drag the periapsis knob"), "\(first)")
        #expect(presenter.mirror.tutorialText == first, "\(presenter.mirror.tutorialText ?? "nil")")
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        #expect(presenter.mirror.explanation == nil)
        let text: String = try Teaching.describe(shell)
        #expect(text.hasPrefix("Apsides Workshop level 1. "), "\(text)")
        #expect(text.contains("Tutorial: " + first + "."), "\(text)")

        // An accepted tuning (the certified plan's first) advances `knob` to `order`.
        let plan: [ApsidesWorkshopAction] = try ApsidesWorkshopTest.certifiedPlan(1)
        let tuning: ApsidesWorkshopAction = try #require(plan.first, "level 1 has a certified tuning")
        let tuned: ActionResult = try Teaching.send(tuning, shell)
        #expect(tuned == .accepted, "\(tuned.code)")
        let after: Core = try Teaching.core(shell)
        let want: Step = Step.knob.advanced(afterTuning: true, ended: after.play.stage != .playing)
        #expect(want == .order)
        #expect(after.tutorial == want, "\(after.tutorial)")
        #expect(presenter.mirror.tutorialText == want.text, "\(presenter.mirror.tutorialText ?? "nil")")
        let tunedText: String = try Teaching.describe(shell)
        #expect(tunedText.contains("Tutorial: " + want.text), "\(tunedText)")

        // Dismiss hides the tutorial; the digest stays (the tutorial step is never in it).
        let digest: String = try ApsidesWorkshopTest.digest(shell)
        let dismissed: ActionResult = presenter.dismissTutorial(port: shell.port)
        #expect(dismissed == .accepted, "\(dismissed.code)")
        let dismissedText: String = try Teaching.describe(shell)
        #expect(try Teaching.core(shell).tutorial == .done)
        #expect(presenter.mirror.tutorialText == nil)
        #expect(!dismissedText.contains("Tutorial: "), "\(dismissedText)")
        #expect(try ApsidesWorkshopTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// Hint presses show the searching text, then levels 1, 2, 3 whose texts equal the Core's hints computed directly;
    /// hints leave the state alone, and a change of the play hides the hint.
    @Test func hintLevelsInTurnThenHiddenByAPlayChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let expected: [String?] = Teaching.expectedTexts(opening.play)
        let digest: String = try ApsidesWorkshopTest.digest(shell)

        // The first press starts the search off the main actor and reads the searching text meanwhile.
        presenter.showHint()
        #expect(presenter.hintSearch != nil, "the search runs off the main actor")
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == ApsidesWorkshopPresenter.searchingText)
        let finished: Bool = try await Teaching.awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 10 s")
        for hintLevel in 1...3 {
            if hintLevel > 1 { try await Teaching.pressHint(presenter) }
            let want: String = try #require(expected[hintLevel - 1], "level 1's opening has hint \(hintLevel)")
            #expect(presenter.mirror.hintLevel == hintLevel)
            #expect(presenter.mirror.hintText == want, "\(presenter.mirror.hintText ?? "nil")")
            let text: String = try Teaching.describe(shell)
            #expect(text.contains("Hint \(hintLevel) of 3: " + want), "\(text)")
            #expect(try ApsidesWorkshopTest.digest(shell) == digest, "hint \(hintLevel) leaves the state alone")
        }
        let lever: String = expected[0] ?? "nil"
        #expect(lever == "Turn the periapsis knob next" || lever == "Change the size next", "\(lever)")
        #expect(expected[1]?.isEmpty == false && expected[1] != expected[0], "\(expected[1] ?? "nil")")
        #expect(expected[2]?.hasPrefix("Set the ") == true, "\(expected[2] ?? "nil")")

        // A change of the play hides the hint on the next describe.
        let hint: ApsidesWorkshopHint = try #require(ApsidesWorkshopHints.hint(level: 3, play: opening.play))
        #expect(hint.kind == .tune)
        let action: ApsidesWorkshopAction = try #require(hint.action)
        let followed: ActionResult = try Teaching.send(action, shell)
        #expect(followed == .accepted, "\(followed.code)")
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        #expect(presenter.hintSearch == nil)
    }

    /// A search started before a change of the play never owns the hint: the change hides it and drops the search,
    /// and the next press searches the new play and shows its level-1 hint.
    @Test func staleSearchNeverOwnsTheHint() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let tuning: ApsidesWorkshopAction = try #require(try ApsidesWorkshopTest.certifiedPlan(1).first)

        presenter.showHint()
        let generation: Int = presenter.hintGeneration
        #expect(presenter.mirror.hintText == ApsidesWorkshopPresenter.searchingText)
        let tuned: ActionResult = try Teaching.send(tuning, shell)
        #expect(tuned == .accepted, "\(tuned.code)")
        #expect(presenter.hintGeneration > generation, "the change retires the running search")
        #expect(presenter.hintSearch == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        let changed: Core = try Teaching.core(shell)
        #expect(changed.play != opening.play)
        let want: String? = Teaching.expectedTexts(changed.play)[0]
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == want, "\(presenter.mirror.hintText ?? "nil")")
        // The retired search may finish later; it changes nothing.
        try await Task.sleep(for: .milliseconds(50))
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == want, "\(presenter.mirror.hintText ?? "nil")")
    }

    /// Following the level-3 hints, then the play hint, wins level 1 within the certified tunings: the stars line reads
    /// "Best: 3 of 3 stars", the picker offers level 2 and Play level opens it, and a won play has no hint.
    @Test func followingLevelThreeHintsWinsWithThreeStars() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        #expect(presenter.mirror.starsLabel == "Best: not won yet")
        var tunings: Int = 0
        var played: Bool = false
        for _ in 0..<Teaching.followLimit {
            let play: ApsidesWorkshopPlay = try Teaching.core(shell).play
            guard play.stage == .playing else { break }
            let direct: ApsidesWorkshopHint = try #require(ApsidesWorkshopHints.hint(level: 3, play: play))
            for _ in 0..<3 { try await Teaching.pressHint(presenter) }
            #expect(presenter.mirror.hintLevel == 3)
            #expect(presenter.mirror.hintText == direct.text, "\(presenter.mirror.hintText ?? "nil")")
            let action: ApsidesWorkshopAction = try #require(direct.action, "\(direct.text)")
            if direct.kind == .play {
                #expect(direct.text == ApsidesWorkshopHint.playText)
                played = true
            } else {
                #expect(direct.kind == .tune, "\(direct.text)")
                tunings += 1
            }
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "\(direct.text): \(result.code)")
            guard result == .accepted else { break }
        }
        let won: Core = try Teaching.core(shell)
        #expect(played, "the hints end with the play")
        #expect(won.play.stage == .won, "\(won.play.stage)")
        #expect(tunings <= won.certifiedTunings, "\(tunings) tunings, certified \(won.certifiedTunings)")
        #expect(won.progress.stars(of: 1) == 3)
        #expect(presenter.mirror.bestStars == 3)
        #expect(presenter.mirror.starsLabel == "Best: 3 of 3 stars")
        let text: String = try Teaching.describe(shell)
        #expect(text.contains("Best: 3 of 3 stars."), "\(text)")

        // A won play has no hint.
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == ApsidesWorkshopPresenter.noHintText)

        // The campaign win opened level 2: the picker reaches it and Play level opens it.
        #expect(won.progress.frontier == 2)
        #expect(presenter.mirror.frontier == 2)
        #expect(presenter.mirror.levelLabel(1) == "Level 1, band 1, 3 of 3 stars")
        #expect(presenter.mirror.levelLabel(2) == "Level 2, band 1")
        let picked: ActionResult = presenter.selectLevel(2, port: shell.port)
        #expect(picked == .accepted, "\(picked.code)")
        _ = try Teaching.describe(shell)
        #expect(try Teaching.core(shell).levelNumber == 2)
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.starsLabel == "Best: not won yet")
    }

    /// Playing the revolution at level 1's opening fails it: the panel's explanation equals the Core's failure
    /// explanation, the description names it, and the failed play's hint is the undo-or-retry advice.
    @Test func failedPlayShowsTheExplanation() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        #expect(presenter.mirror.explanation == nil)
        let ran: ActionResult = try Teaching.send(.play, shell)
        #expect(ran == .accepted, "\(ran.code)")
        let failed: Core = try Teaching.core(shell)
        try #require(failed.play.stage == .failed, "the opening's play fails: \(failed.play.stage)")
        let want: String = try #require(ApsidesWorkshopFailureExplanation(play: failed.play)?.text)
        #expect(want.hasSuffix(" " + ApsidesWorkshopFailureExplanation.advice), "\(want)")
        #expect(presenter.mirror.explanation == want, "\(presenter.mirror.explanation ?? "nil")")
        #expect(presenter.mirror.failureText != nil, "the short failure words stay the status line")
        let text: String = try Teaching.describe(shell)
        #expect(text.contains(want), "\(text)")

        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == ApsidesWorkshopHint.failedText)
    }

    /// Level 1 is band 1 and level 21 band 2; the goal label is the level's goal with its certified tuning count.
    @Test func bandAndGoalLabels() async throws {
        let cases: [(number: Int, band: String)] = [(1, "Band 1 of 5"), (21, "Band 2 of 5")]
        for entry in cases {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Teaching.open(session, number: entry.number)
            let core: Core = try Teaching.core(shell)
            let mirror: ApsidesWorkshopMirror = shell.presenter.mirror
            #expect(core.levelNumber == entry.number)
            #expect(mirror.bandLabel == entry.band, "level \(entry.number): \(mirror.bandLabel)")
            let goal: String = ApsidesWorkshopMirror.goalText(core.play.level, certified: core.certifiedTunings)
            #expect(mirror.goalLabel == goal, "\(mirror.goalLabel)")
            #expect(goal.hasPrefix("Goal: target 1, "), "\(goal)")
            #expect(goal.contains("in order without striking a planet, then play the revolution. 3 stars within "),
                    "\(goal)")
            let unit: String = core.certifiedTunings == 1 ? "tuning" : "tunings"
            #expect(goal.hasSuffix("3 stars within \(core.certifiedTunings) \(unit)"), "\(goal)")
            #expect(mirror.modeLabel == "Mode: campaign")
            let text: String = try Teaching.describe(shell)
            #expect(text.contains(entry.band + "."), "\(text)")
            #expect(text.contains(goal + "."), "\(text)")
        }
    }

    /// Practice replays the current level with the budget raised to 24; Daily of 2026-01-02 opens its daily level 24
    /// in daily mode (locked in the campaign, still playable); Campaign returns to the campaign's frontier.
    @Test func modeButtonsPracticeDailyCampaign() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: Teaching.modeLevel)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        #expect(presenter.mirror.modeLabel == "Mode: campaign")
        #expect(try Teaching.core(shell).progress.frontier == Teaching.modeLevel)

        let practice: ActionResult = presenter.playPractice(port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        _ = try Teaching.describe(shell)
        let practised: Core = try Teaching.core(shell)
        #expect(practised.levelNumber == Teaching.modeLevel)
        #expect(practised.mode == .practice)
        #expect(ApsidesWorkshopMode.practiceBudget == Teaching.practiceBudget)
        #expect(practised.play.level.budget == Teaching.practiceBudget)
        #expect(presenter.mirror.budget == Teaching.practiceBudget)
        #expect(presenter.mirror.modeLabel == "Mode: practice")

        let date: DateComponents = Teaching.dailyDate
        let dailyNumber: Int? = ApsidesWorkshopProgress.dailyLevel(year: date.year ?? 0, month: date.month ?? 0,
                                                                    day: date.day ?? 0)
        #expect(dailyNumber == Teaching.dailyNumber)
        #expect(ApsidesWorkshopPresenter.dateValues(date) == [2026, 1, 2])
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        _ = try Teaching.describe(shell)
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == Teaching.dailyNumber)
        #expect(dailyCore.mode == .daily(level: Teaching.dailyNumber))
        #expect(dailyCore.progress.frontier == Teaching.modeLevel, "a daily level is not opened")
        #expect(presenter.mirror.levelNumber == Teaching.dailyNumber)
        #expect(presenter.mirror.modeLabel == "Mode: daily")
        #expect(presenter.mirror.bandLabel == "Band 2 of 5")

        let campaign: ActionResult = presenter.playCampaign(port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        _ = try Teaching.describe(shell)
        let back: Core = try Teaching.core(shell)
        #expect(back.mode == .campaign)
        #expect(back.levelNumber == Teaching.modeLevel, "level 24 is not open, so Campaign goes to the frontier")
        #expect(presenter.mirror.modeLabel == "Mode: campaign")
        #expect(presenter.mirror.message == nil)
    }

    /// Selecting a locked level is refused in words and changes nothing.
    @Test func lockedLevelRefusedInWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        let before: Core = try Teaching.core(shell)
        #expect(before.progress.frontier == 1)
        let digest: String = try ApsidesWorkshopTest.digest(shell)
        let locked: ActionResult = presenter.selectLevel(2, port: shell.port)
        _ = try Teaching.describe(shell)
        let code: String = ApsidesWorkshopExperienceRule.locked
        #expect(Teaching.isRefusal(locked, code), "\(locked.code)")
        let message: String = Teaching.refusalMessage(code)
        #expect(message == "That level is not open yet.")
        #expect(presenter.mirror.message == message, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == code)
        #expect(try Teaching.core(shell) == before, "a refused pick changes nothing")
        #expect(try ApsidesWorkshopTest.digest(shell) == digest)
        #expect(presenter.mirror.levelNumber == 1)
    }

    /// Next level on the last open level (level 1, nothing won) is refused as locked, in words, and changes nothing.
    @Test func nextLevelOnTheLastOpenLevelRefusedInWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        let before: Core = try Teaching.core(shell)
        #expect(before.progress.nextOpen(after: 1) == nil)
        let digest: String = try ApsidesWorkshopTest.digest(shell)
        let refused: ActionResult = presenter.send("level.next", [], port: shell.port)
        _ = try Teaching.describe(shell)
        let code: String = ApsidesWorkshopExperienceRule.locked
        #expect(Teaching.isRefusal(refused, code), "\(refused.code)")
        let message: String = try #require(presenter.mirror.message)
        #expect(message == Teaching.refusalMessage(code))
        #expect(message == "That level is not open yet.", "\(message)")
        #expect(presenter.refusalLog.last == code)
        #expect(try Teaching.core(shell) == before, "a refused next level changes nothing")
        #expect(try ApsidesWorkshopTest.digest(shell) == digest)
        #expect(presenter.mirror.levelNumber == 1)
    }

    /// An impossible date (2026-02-30) is refused in words and changes nothing.
    @Test func impossibleDateRefusedInWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: ApsidesWorkshopPresenter = shell.presenter
        let before: Core = try Teaching.core(shell)
        let digest: String = try ApsidesWorkshopTest.digest(shell)
        let refused: ActionResult = presenter.playDaily(port: shell.port, date: Teaching.impossibleDate)
        _ = try Teaching.describe(shell)
        let code: String = ApsidesWorkshopExperienceRule.date
        #expect(Teaching.isRefusal(refused, code), "\(refused.code)")
        let message: String = Teaching.refusalMessage(code)
        #expect(message == "That date cannot be used.")
        #expect(presenter.mirror.message == message, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == code)
        #expect(try Teaching.core(shell) == before, "a refused date changes nothing")
        #expect(try ApsidesWorkshopTest.digest(shell) == digest)
        #expect(presenter.mirror.modeLabel == "Mode: campaign")
    }
}
#endif
