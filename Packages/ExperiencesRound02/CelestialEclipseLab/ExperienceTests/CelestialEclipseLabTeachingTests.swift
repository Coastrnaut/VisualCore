// CelestialEclipseLabTeachingTests — feature 465 (R02-G17-05) T-R02G1705-005 (FR-R02G1705-001 … 005, 007;
// clarifications Q1 … Q5). On the simulator, through the one app's session host: the presenter's teaching and
// progression surface, modelled on feature 455's Starlit Cartouche teaching tests. The mirror is read after `describe`
// (the tests describe the current core themselves after every action so the presenter's latest core is the current
// one). Tutorial: level 1 (seed 0) opens with the `phase` instruction (`CelestialEclipseLabTutorialStep.phase.text`),
// which the description names; an accepted phase change advances it to `order`; Dismiss through the port hides it and
// leaves the digest alone (the tutorial step is never in the digest). Hints: `showHint()` shows
// `CelestialEclipseLabPresenter.searchingText` while the detached search runs (awaited by a bounded poll of
// `hintSearch`, at most 10 s), then reveals levels 1, 2, 3 whose texts equal
// `CelestialEclipseLabHints.hint(level:play:)` computed directly; the digest never changes; any change of the play
// hides the hint; following the level-3 hints and then the run hint wins level 1 with 3 stars ("Best: 3 of 3 stars"),
// and a won play has no hint
// (`noHintText`, level 0). Failure: running the clock at level 1's opening fails the run; `mirror.explanation` equals
// `CelestialEclipseLabFailureExplanation(play:)?.text` and the description names it; the failed play's hint is
// `CelestialEclipseLabHint.failedText`. Progression: the band label of levels 1 and 21, the goal label; the modes
// (Practice raises the budget to 24, Daily of 2026-01-01 opens level 1 in daily mode, Campaign returns); a locked level
// and an impossible date (2026-02-30) are refused in words and change nothing. Explicit dates (no clock), no wall-clock
// assertion; each test short. Explicit types and plain loops (CI type-check rule).
#if os(iOS)
import CelestialEclipseLabCore
import CoreGraphics
import Foundation
import Testing
@testable import CelestialEclipseLabExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Celestial Eclipse Lab teaching tests.
@MainActor
enum CelestialEclipseLabTeaching {
    typealias Shell = CelestialEclipseLabTest.Shell
    typealias Core = CelestialEclipseLabExperienceCore

    /// The fixed calendar day of the daily test and its daily level ((0 × 29) mod 100 + 1).
    static let dailyDate: DateComponents = DateComponents(year: 2026, month: 1, day: 1)
    static let dailyNumber: Int = 1
    /// An impossible day.
    static let impossibleDate: DateComponents = DateComponents(year: 2026, month: 2, day: 30)
    /// The practice budget (the kernel's maximum).
    static let practiceBudget: Int = 24

    /// How many times the hint search is polled, and the pause between polls (at most 10 s in all).
    static let pollLimit: Int = 1_000
    static let pollMilliseconds: Int = 10
    /// The most hint-guided phase changes tried when following the hints (the solver's plans have at most 5).
    static let followLimit: Int = 8

    /// The panel message of a refusal with reason `code`.
    static func refusalMessage(_ code: String) -> String {
        "That change was refused: " + CelestialEclipseLabMirror.refusalText(code: code) + "."
    }

    /// Opens level `number` (seed `number − 1`) at a small view (one frame drawn) and describes the opening.
    static func open(_ session: ExperienceSession, number: Int = 1) async throws -> Shell {
        let shell: Shell = try await CelestialEclipseLabTest.open(session, seed: UInt64(number - 1),
                                                                  size: CGSize(width: 360, height: 240))
        _ = try describe(shell)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try CelestialEclipseLabTest.core(shell)
    }

    /// Describes the current core of `shell` and returns the description.
    @discardableResult
    static func describe(_ shell: Shell) throws -> String {
        let current: Core = try CelestialEclipseLabTest.core(shell)
        return shell.presenter.describe(current)
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: CelestialEclipseLabPresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(for: .milliseconds(pollMilliseconds))
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: CelestialEclipseLabPresenter) async throws {
        presenter.showHint()
        let finished: Bool = try await awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 10 s")
    }

    /// Sends `action` through the presenter (the path of the controls), describes the result and returns it.
    @discardableResult
    static func send(_ action: CelestialEclipseLabAction, _ shell: Shell) throws -> ActionResult {
        let entry: (control: String, values: [Double]) = CelestialEclipseLabTest.control(action)
        let result: ActionResult = shell.presenter.send(entry.control, entry.values, port: shell.port)
        _ = try describe(shell)
        return result
    }

    /// The hint texts of levels 1 … 3 for `play`, computed directly by the Core.
    nonisolated static func expectedTexts(_ play: CelestialEclipseLabPlay) -> [String?] {
        var texts: [String?] = []
        for level in 1...3 {
            texts.append(CelestialEclipseLabHints.hint(level: level, play: play)?.text)
        }
        return texts
    }

    /// Whether `result` is a refusal with the kernel reason `code` (read with or without the engine's prefix).
    static func isRefusal(_ result: ActionResult, _ code: String) -> Bool {
        !result.isAccepted && CelestialEclipseLabMirror.bareCode(result.code) == code
    }
}

@MainActor
@Suite(.serialized) struct CelestialEclipseLabTeachingTests {
    typealias Teaching = CelestialEclipseLabTeaching
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Step = CelestialEclipseLabTutorialStep

    /// Level 1 opens with the tutorial's `phase` instruction, which the description names; an accepted phase change
    /// advances it to `order`; Dismiss hides it and leaves the digest alone.
    @Test func levelOneTutorialShownAdvancedAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: CelestialEclipseLabPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .phase)
        #expect(opening.play.stage == .playing)
        let first: String = Step.phase.text
        #expect(!first.isEmpty)
        #expect(presenter.mirror.tutorialText == first, "\(presenter.mirror.tutorialText ?? "nil")")
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        #expect(presenter.mirror.explanation == nil)
        let text: String = try Teaching.describe(shell)
        #expect(text.hasPrefix("Celestial Eclipse Lab level 1. "), "\(text)")
        #expect(text.contains("Tutorial: " + first), "\(text)")

        // An accepted phase change (the certified plan's first) advances `phase` to `order`.
        let plan: [CelestialEclipseLabAction] = try CelestialEclipseLabTest.certifiedPlan(1)
        let change: CelestialEclipseLabAction = try #require(plan.first, "level 1 has a certified phase change")
        let changed: ActionResult = try Teaching.send(change, shell)
        #expect(changed == .accepted, "\(changed.code)")
        let after: Core = try Teaching.core(shell)
        let want: Step = Step.phase.advanced(afterChange: true, ended: after.play.stage != .playing)
        #expect(want == .order)
        #expect(after.tutorial == want, "\(after.tutorial)")
        #expect(presenter.mirror.tutorialText == want.text, "\(presenter.mirror.tutorialText ?? "nil")")
        let changedText: String = try Teaching.describe(shell)
        #expect(changedText.contains("Tutorial: " + want.text), "\(changedText)")

        // Dismiss hides the tutorial; the digest stays (the tutorial step is never in it).
        let digest: String = try CelestialEclipseLabTest.digest(shell)
        let dismissed: ActionResult = presenter.dismissTutorial(port: shell.port)
        #expect(dismissed == .accepted, "\(dismissed.code)")
        let dismissedText: String = try Teaching.describe(shell)
        #expect(try Teaching.core(shell).tutorial == .done)
        #expect(presenter.mirror.tutorialText == nil)
        #expect(!dismissedText.contains("Tutorial: "), "\(dismissedText)")
        #expect(try CelestialEclipseLabTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// Hint presses show the searching text, then levels 1, 2, 3 whose texts equal the Core's hints computed directly;
    /// hints leave the state alone, and a change of the play hides the hint.
    @Test func hintLevelsInTurnThenHiddenByAPlayChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: CelestialEclipseLabPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let expected: [String?] = Teaching.expectedTexts(opening.play)
        let digest: String = try CelestialEclipseLabTest.digest(shell)

        // The first press starts the search off the main actor and reads the searching text meanwhile.
        presenter.showHint()
        #expect(presenter.hintSearch != nil, "the search runs off the main actor")
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == CelestialEclipseLabPresenter.searchingText)
        let finished: Bool = try await Teaching.awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 10 s")
        for hintLevel in 1...3 {
            if hintLevel > 1 { try await Teaching.pressHint(presenter) }
            let want: String = try #require(expected[hintLevel - 1], "level 1's opening has hint \(hintLevel)")
            #expect(presenter.mirror.hintLevel == hintLevel)
            #expect(presenter.mirror.hintText == want, "\(presenter.mirror.hintText ?? "nil")")
            let text: String = try Teaching.describe(shell)
            #expect(text.contains("Hint \(hintLevel) of 3: " + want), "\(text)")
            #expect(try CelestialEclipseLabTest.digest(shell) == digest, "hint \(hintLevel) leaves the state alone")
        }
        #expect(expected[0]?.hasPrefix("Move planet ") == true, "\(expected[0] ?? "nil")")
        #expect(expected[0]?.hasSuffix(" next") == true, "\(expected[0] ?? "nil")")
        #expect(expected[2]?.hasPrefix("Set planet ") == true, "\(expected[2] ?? "nil")")

        // A change of the play hides the hint on the next describe.
        let hint: CelestialEclipseLabHint = try #require(CelestialEclipseLabHints.hint(level: 3, play: opening.play))
        let action: CelestialEclipseLabAction = try #require(hint.action)
        let followed: ActionResult = try Teaching.send(action, shell)
        #expect(followed == .accepted, "\(followed.code)")
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        #expect(presenter.hintSearch == nil)
    }

    /// Following the level-3 hints, then the run hint, wins level 1 within the certified changes: the stars line reads
    /// "Best: 3 of 3 stars" and a won play has no hint.
    @Test func followingLevelThreeHintsWinsWithThreeStars() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: CelestialEclipseLabPresenter = shell.presenter
        #expect(presenter.mirror.starsLabel == "Best: not won yet")
        var changes: Int = 0
        var ran: Bool = false
        for _ in 0..<Teaching.followLimit {
            let play: CelestialEclipseLabPlay = try Teaching.core(shell).play
            guard play.stage == .playing else { break }
            let direct: CelestialEclipseLabHint = try #require(CelestialEclipseLabHints.hint(level: 3, play: play))
            for _ in 0..<3 { try await Teaching.pressHint(presenter) }
            #expect(presenter.mirror.hintLevel == 3)
            #expect(presenter.mirror.hintText == direct.text, "\(presenter.mirror.hintText ?? "nil")")
            let action: CelestialEclipseLabAction = try #require(direct.action, "\(direct.text)")
            if direct.kind == .run {
                #expect(direct.text == CelestialEclipseLabHint.runText)
                ran = true
            } else {
                #expect(direct.kind == .change, "\(direct.text)")
                changes += 1
            }
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "\(direct.text): \(result.code)")
            guard result == .accepted else { break }
        }
        let won: Core = try Teaching.core(shell)
        #expect(ran, "the hints end with the run")
        #expect(won.play.stage == .won, "\(won.play.stage)")
        #expect(changes <= won.certifiedChanges, "\(changes) changes, certified \(won.certifiedChanges)")
        #expect(won.progress.stars(of: 1) == 3)
        #expect(presenter.mirror.bestStars == 3)
        #expect(presenter.mirror.starsLabel == "Best: 3 of 3 stars")
        let text: String = try Teaching.describe(shell)
        #expect(text.contains("Best: 3 of 3 stars."), "\(text)")

        // A won play has no hint.
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == CelestialEclipseLabPresenter.noHintText)
    }

    /// Running the clock at level 1's opening fails the run: the explanation equals the Core's failure explanation,
    /// the description names it, and the failed play's hint is the undo-or-retry advice.
    @Test func failedRunShowsTheExplanation() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: CelestialEclipseLabPresenter = shell.presenter
        #expect(presenter.mirror.explanation == nil)
        let ran: ActionResult = try Teaching.send(.run, shell)
        #expect(ran == .accepted, "\(ran.code)")
        let failed: Core = try Teaching.core(shell)
        try #require(failed.play.stage == .failed, "the opening's run fails: \(failed.play.stage)")
        let want: String = try #require(CelestialEclipseLabFailureExplanation(play: failed.play)?.text)
        #expect(want.hasSuffix(CelestialEclipseLabFailureExplanation.advice), "\(want)")
        #expect(presenter.mirror.explanation == want, "\(presenter.mirror.explanation ?? "nil")")
        let text: String = try Teaching.describe(shell)
        #expect(text.contains(want), "\(text)")

        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == CelestialEclipseLabHint.failedText)
    }

    /// Level 1 is band 1 and level 21 band 2; the goal label is the level's goal with its certified change count.
    @Test func bandAndGoalLabels() async throws {
        let cases: [(number: Int, band: String)] = [(1, "Band 1 of 5"), (21, "Band 2 of 5")]
        for entry in cases {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Teaching.open(session, number: entry.number)
            let core: Core = try Teaching.core(shell)
            let mirror: CelestialEclipseLabMirror = shell.presenter.mirror
            #expect(core.levelNumber == entry.number)
            #expect(mirror.bandLabel == entry.band, "level \(entry.number): \(mirror.bandLabel)")
            let goal: String = CelestialEclipseLabMirror.goalText(core.play.level, certified: core.certifiedChanges)
            #expect(mirror.goalLabel == goal, "\(mirror.goalLabel)")
            #expect(goal.hasPrefix("Goal: target 1, planet "), "\(goal)")
            #expect(goal.contains("in order, then run the clock. 3 stars within "), "\(goal)")
            #expect(mirror.modeLabel == "Mode: campaign")
            let text: String = try Teaching.describe(shell)
            #expect(text.contains(entry.band + "."), "\(text)")
        }
    }

    /// Practice replays the current level with the budget raised to 24; Daily of 2026-01-01 opens level 1 in daily
    /// mode; Campaign returns to campaign mode.
    @Test func modeButtonsPracticeDailyCampaign() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 5)
        let presenter: CelestialEclipseLabPresenter = shell.presenter
        #expect(presenter.mirror.modeLabel == "Mode: campaign")

        let practice: ActionResult = presenter.playPractice(port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        _ = try Teaching.describe(shell)
        let practised: Core = try Teaching.core(shell)
        #expect(practised.levelNumber == 5)
        #expect(practised.mode == .practice)
        #expect(CelestialEclipseLabMode.practiceBudget == Teaching.practiceBudget)
        #expect(practised.play.level.budget == Teaching.practiceBudget)
        #expect(presenter.mirror.budget == Teaching.practiceBudget)
        #expect(presenter.mirror.modeLabel == "Mode: practice")

        let date: DateComponents = Teaching.dailyDate
        let dailyNumber: Int? = CelestialEclipseLabProgress.dailyLevel(year: date.year ?? 0, month: date.month ?? 0,
                                                                       day: date.day ?? 0)
        #expect(dailyNumber == Teaching.dailyNumber)
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        _ = try Teaching.describe(shell)
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == Teaching.dailyNumber)
        #expect(dailyCore.mode == .daily(level: Teaching.dailyNumber))
        #expect(presenter.mirror.levelNumber == Teaching.dailyNumber)
        #expect(presenter.mirror.modeLabel == "Mode: daily")

        let campaign: ActionResult = presenter.playCampaign(port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        _ = try Teaching.describe(shell)
        let back: Core = try Teaching.core(shell)
        #expect(back.mode == .campaign)
        #expect(back.levelNumber == Teaching.dailyNumber, "level 1 is open, so Campaign stays on it")
        #expect(presenter.mirror.modeLabel == "Mode: campaign")
        #expect(presenter.mirror.message == nil)
    }

    /// Selecting a locked level is refused in words and changes nothing.
    @Test func lockedLevelRefusedInWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: CelestialEclipseLabPresenter = shell.presenter
        let before: Core = try Teaching.core(shell)
        #expect(before.progress.frontier == 1)
        let digest: String = try CelestialEclipseLabTest.digest(shell)
        let locked: ActionResult = presenter.selectLevel(2, port: shell.port)
        _ = try Teaching.describe(shell)
        let code: String = CelestialEclipseLabExperienceRule.locked
        #expect(Teaching.isRefusal(locked, code), "\(locked.code)")
        let message: String = Teaching.refusalMessage(code)
        #expect(message == "That change was refused: that level is not open yet.")
        #expect(presenter.mirror.message == message, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == code)
        #expect(try Teaching.core(shell) == before, "a refused pick changes nothing")
        #expect(try CelestialEclipseLabTest.digest(shell) == digest)
        #expect(presenter.mirror.levelNumber == 1)
    }

    /// An impossible date (2026-02-30) is refused in words and changes nothing.
    @Test func impossibleDateRefusedInWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: CelestialEclipseLabPresenter = shell.presenter
        let before: Core = try Teaching.core(shell)
        let digest: String = try CelestialEclipseLabTest.digest(shell)
        let refused: ActionResult = presenter.playDaily(port: shell.port, date: Teaching.impossibleDate)
        _ = try Teaching.describe(shell)
        let code: String = CelestialEclipseLabExperienceRule.date
        #expect(Teaching.isRefusal(refused, code), "\(refused.code)")
        let message: String = Teaching.refusalMessage(code)
        #expect(message == "That change was refused: that is not a calendar date.")
        #expect(presenter.mirror.message == message, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == code)
        #expect(try Teaching.core(shell) == before, "a refused date changes nothing")
        #expect(try CelestialEclipseLabTest.digest(shell) == digest)
        #expect(presenter.mirror.modeLabel == "Mode: campaign")
    }
}
#endif
