// BinaryGardensTeachingTests — feature 505 (R02-G21-05) T-R02G2105-005 (FR-R02G2105-001 … 005, 008, 009;
// SC-R02G2105-001 … 004; clarifications Q1 … Q5). On the simulator, through the one app's session host: the presenter's
// teaching and progression surface, ported from feature 495's Mushroom Weather teaching tests. The mirror is read after
// `describe` (the tests describe the current core themselves after every action so the presenter's latest core is the
// current one).
// Tutorial: level 1 (seed 0) opens with the `adjust` instruction (`BinaryGardensTutorialStep.adjust.text`), which the
// panel and the description name; an accepted arrangement action advances it to `balance`; Dismiss through the
// presenter hides it and leaves the digest alone (the tutorial step is never in the digest). Hints: `showHint()` shows
// `BinaryGardensPresenter.searchingText` while the detached search runs (awaited by a bounded poll of `hintSearch`, at
// most 10 s), then reveals levels 1, 2, 3 whose texts equal the adapter's `hint(level:)` (level 1 names the kind of
// change: "Move a star to another ring", "Shift a star's phase", "Change a star's brightness" or "Tilt the orbit
// plane"); the digest never changes; any change of the play hides the hint so the next press shows level 1, and a
// search started before the change never owns the hint afterwards; following the level-3 hints and then the run hint
// wins level 1 with 3 stars ("Best: 3 of 3 stars"), opens level 2 for the level picker, and a won play has no hint
// (`noHintText`, level 0). Failure: an immediate run at level 1 (the first of the support's set-ups whose run fails)
// shows the adapter's `failureExplanation` text as the panel's explanation, which replaces the short failure line in
// the panel (the short words stay the status line), the description names it, and the failed play's hint is
// `BinaryGardensHint.failedText`. Progression: the band ("Band b of 5"), goal ("Win in at most k actions for 3 stars")
// and stars lines and the description's mode, band, goal and stars sentences; the modes (Practice raises the budget
// to 24, Daily of 2026-12-03 opens its daily level 69 in daily mode although it is locked in the campaign, Campaign
// returns to the frontier); the Daily button's date is today's local date; a locked level, `level.next` on the last
// open level and an impossible date (2027-02-29) are refused in words ("that level is not open yet", "that date cannot
// be used") and change nothing. Fixed dates except the today check, no wall-clock assertion; each test short.
// Explicit types and plain loops (CI type-check rule). Synthetic data only. Since feature 506 (R02-G21-06,
// FR-R02G2106-009) the refusal lines are the feedback plan's sentences ("That level is not open yet.", "That date
// cannot be used.").
#if os(iOS)
import BinaryGardensCore
import CoreGraphics
import Foundation
import Testing
@testable import BinaryGardensExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// Helpers of the Binary Gardens teaching tests.
@MainActor
enum BinaryGardensTeaching {
    typealias Shell = BinaryGardensTest.Shell
    typealias Core = BinaryGardensExperienceCore

    /// The fixed calendar day of the daily test and its daily level: 336 days from 2026-01-01, (336 × 13) mod 100 + 1.
    nonisolated static let dailyDate: DateComponents = DateComponents(year: 2026, month: 12, day: 3)
    nonisolated static let dailyNumber: Int = 69
    /// The daily level's band (levels 61 … 80).
    nonisolated static let dailyBand: String = "Band 4 of 5"
    /// An impossible day (2027 is not a leap year).
    nonisolated static let impossibleDate: DateComponents = DateComponents(year: 2027, month: 2, day: 29)
    /// The practice budget (the kernel's maximum).
    nonisolated static let practiceBudget: Int = 24
    /// What level 1 of a ring, phase, luminosity or tilt hint says (clarification Q1).
    nonisolated static let kindTexts: [String] = ["Move a star to another ring", "Shift a star's phase",
                                                  "Change a star's brightness", "Tilt the orbit plane"]

    /// How many times the hint search is polled, and the pause between polls (at most 10 s in all).
    nonisolated static let pollLimit: Int = 1_000
    nonisolated static let pollMilliseconds: Int = 10
    /// The most hint-guided steps tried when following the hints (at most 4 certified actions, then the run).
    nonisolated static let followLimit: Int = 7

    /// The panel message of a refusal with reason `code` (since feature 506 the feedback plan's sentence).
    static func refusalMessage(_ code: String) -> String {
        BinaryGardensMirror.refusalMessage(code: code)
    }

    /// Opens level `number` (seed `number − 1`) at a small view (one frame drawn, tick 48 shown) and describes the
    /// opening.
    static func open(_ session: ExperienceSession, number: Int = 1) async throws -> Shell {
        let shell: Shell = try await BinaryGardensTest.open(session, seed: UInt64(number - 1),
                                                            size: CGSize(width: 360, height: 240),
                                                            atCheckTick: false)
        _ = try describe(shell)
        return shell
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> Core {
        try BinaryGardensTest.core(shell)
    }

    /// Describes the current core of `shell` and returns the description.
    @discardableResult
    static func describe(_ shell: Shell) throws -> String {
        let current: Core = try BinaryGardensTest.core(shell)
        return shell.presenter.describe(current)
    }

    /// Waits for the hint search under way (off the main actor) with a bounded poll; returns whether it finished.
    @discardableResult
    static func awaitSearch(_ presenter: BinaryGardensPresenter) async throws -> Bool {
        var polls: Int = 0
        while presenter.hintSearch != nil && polls < pollLimit {
            try await Task.sleep(for: .milliseconds(pollMilliseconds))
            polls += 1
        }
        return presenter.hintSearch == nil
    }

    /// Presses Hint and waits for the search it started (a cached play reveals at once).
    static func pressHint(_ presenter: BinaryGardensPresenter) async throws {
        presenter.showHint()
        let finished: Bool = try await awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 10 s")
    }

    /// Sends `action` through the presenter (the path of the controls), describes the result and returns it.
    @discardableResult
    static func send(_ action: BinaryGardensAction, _ shell: Shell) throws -> ActionResult {
        let entry: (control: String, values: [Double]) = BinaryGardensTest.control(action)
        let result: ActionResult = shell.presenter.send(entry.control, entry.values, port: shell.port)
        _ = try describe(shell)
        return result
    }

    /// The hint texts of levels 1 … 3 for `core`'s play, computed directly by the adapter (`hint(level:)`).
    nonisolated static func expectedTexts(_ core: BinaryGardensExperienceCore) -> [String?] {
        var texts: [String?] = []
        for level in 1...3 {
            let hint: BinaryGardensHint? = core.hint(level: level)
            texts.append(hint?.text)
        }
        return texts
    }

    /// Whether `result` is a refusal with the kernel reason `code` (read with or without the engine's prefix).
    static func isRefusal(_ result: ActionResult, _ code: String) -> Bool {
        !result.isAccepted && BinaryGardensMirror.bareCode(result.code) == code
    }

    /// The first of the support's set-ups of level 1 (none, then proper prefixes of its certified plan) whose run
    /// fails, found on a host-free core; nil when none does.
    static func failingSetUp() throws -> [BinaryGardensAction]? {
        for setUp in try BinaryGardensTest.setUps(1) {
            var core: Core = try Core.opening(number: 1)
            var accepted: Bool = true
            let actions: [BinaryGardensAction] = setUp + [.run]
            for action in actions where accepted {
                let result: ActionResult = core.apply(BinaryGardensTest.experienceAction(action))
                if result != .accepted { accepted = false }
            }
            if accepted && core.play.stage == .failed { return setUp }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct BinaryGardensTeachingTests {
    typealias Teaching = BinaryGardensTeaching
    typealias Core = BinaryGardensExperienceCore
    typealias Step = BinaryGardensTutorialStep

    /// Level 1 opens with the tutorial's `adjust` instruction, which the panel and the description name; an accepted
    /// arrangement action advances it to `balance`; Dismiss hides it and leaves the digest alone (FR-R02G2105-001,
    /// SC-R02G2105-001).
    @Test func levelOneTutorialShownAdvancedAndDismissed() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: BinaryGardensPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.tutorial == .adjust)
        #expect(opening.play.stage == .playing)
        let first: String = Step.adjust.text
        #expect(first.hasPrefix("Change a star: drag it along its orbit"), "\(first)")
        #expect(first != BinaryGardensPresenter.tutorial, "the step text replaces the single sentence")
        #expect(presenter.mirror.tutorialText == first, "\(presenter.mirror.tutorialText ?? "nil")")
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        #expect(presenter.mirror.explanation == nil)
        let text: String = try Teaching.describe(shell)
        #expect(text.hasPrefix("Binary Gardens level 1. "), "\(text)")
        #expect(text.contains("Tutorial: " + first + "."), "\(text)")

        // An accepted arrangement action (the certified plan's first action) advances `adjust` to `balance`.
        let action: BinaryGardensAction = try #require(try BinaryGardensTest.certifiedPlan(1).first,
                                                       "level 1's certified plan has an action")
        let adjusted: ActionResult = try Teaching.send(action, shell)
        #expect(adjusted == .accepted, "\(adjusted.code)")
        let after: Core = try Teaching.core(shell)
        #expect(after.tutorial == .balance, "\(after.tutorial)")
        #expect(presenter.mirror.tutorialText == Step.balance.text, "\(presenter.mirror.tutorialText ?? "nil")")
        let adjustedText: String = try Teaching.describe(shell)
        #expect(adjustedText.contains("Tutorial: " + Step.balance.text), "\(adjustedText)")

        // Dismiss hides the tutorial; the digest stays (the tutorial step is never in it).
        let digest: String = try BinaryGardensTest.digest(shell)
        let dismissed: ActionResult = presenter.dismissTutorial(port: shell.port)
        #expect(dismissed == .accepted, "\(dismissed.code)")
        let dismissedText: String = try Teaching.describe(shell)
        #expect(try Teaching.core(shell).tutorial == .done)
        #expect(presenter.mirror.tutorialText == nil)
        #expect(!dismissedText.contains("Tutorial: "), "\(dismissedText)")
        #expect(try BinaryGardensTest.digest(shell) == digest, "the tutorial step is not in the digest")
    }

    /// Hint presses show the searching text, then levels 1, 2, 3 whose texts equal the adapter's hints (level 1 names
    /// the kind of change); hints leave the state alone, and a change of the play hides the hint so the next press
    /// shows level 1 again (FR-R02G2105-002, SC-R02G2105-002).
    @Test func hintLevelsInTurnThenResetByAPlayChange() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: BinaryGardensPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let expected: [String?] = Teaching.expectedTexts(opening)
        let kindText: String = try #require(expected[0], "level 1's opening has a hint")
        #expect(Teaching.kindTexts.contains(kindText), "\(kindText)")
        let digest: String = try BinaryGardensTest.digest(shell)

        // The first press starts the search off the main actor and reads the searching text meanwhile.
        presenter.showHint()
        #expect(presenter.hintSearch != nil, "the search runs off the main actor")
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == BinaryGardensPresenter.searchingText)
        let finished: Bool = try await Teaching.awaitSearch(presenter)
        #expect(finished, "the hint search finishes within 10 s")
        for hintLevel in 1...3 {
            if hintLevel > 1 { try await Teaching.pressHint(presenter) }
            let want: String = try #require(expected[hintLevel - 1], "level 1's opening has hint \(hintLevel)")
            #expect(presenter.mirror.hintLevel == hintLevel)
            #expect(presenter.mirror.hintText == want, "\(presenter.mirror.hintText ?? "nil")")
            let text: String = try Teaching.describe(shell)
            #expect(text.contains("Hint \(hintLevel) of 3: " + want), "\(text)")
            #expect(try BinaryGardensTest.digest(shell) == digest, "hint \(hintLevel) leaves the state alone")
        }
        // A fourth press stays at level 3.
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 3)

        // Following the level-3 hint changes the play: the hint is hidden on the next describe.
        let hint: BinaryGardensHint = try #require(opening.hint(level: 3))
        let changing: [BinaryGardensHintKind] = [.ring, .phase, .luminosity, .tilt]
        #expect(changing.contains(hint.kind), "\(hint.kind)")
        let action: BinaryGardensAction = try #require(hint.action)
        let followed: ActionResult = try Teaching.send(action, shell)
        #expect(followed == .accepted, "\(followed.code)")
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)
        #expect(presenter.hintSearch == nil)

        // The next press starts again at level 1, for the new play.
        let changed: Core = try Teaching.core(shell)
        let wantAfter: String? = Teaching.expectedTexts(changed)[0]
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == wantAfter, "\(presenter.mirror.hintText ?? "nil")")
    }

    /// A search started before a change of the play never owns the hint: the change hides it and drops the search,
    /// and the next press searches the new play and shows its level-1 hint (FR-R02G2105-002, 009).
    @Test func staleSearchNeverOwnsTheHint() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: BinaryGardensPresenter = shell.presenter
        let opening: Core = try Teaching.core(shell)
        let first: BinaryGardensAction = try #require(try BinaryGardensTest.certifiedPlan(1).first)

        presenter.showHint()
        let generation: Int = presenter.hintGeneration
        #expect(presenter.mirror.hintText == BinaryGardensPresenter.searchingText)
        let changedResult: ActionResult = try Teaching.send(first, shell)
        #expect(changedResult == .accepted, "\(changedResult.code)")
        #expect(presenter.hintGeneration > generation, "the change retires the running search")
        #expect(presenter.hintSearch == nil)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == nil)

        let changed: Core = try Teaching.core(shell)
        #expect(changed.play != opening.play)
        let want: String? = Teaching.expectedTexts(changed)[0]
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == want, "\(presenter.mirror.hintText ?? "nil")")
        // The retired search may finish later; it changes nothing.
        try await Task.sleep(for: .milliseconds(50))
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == want, "\(presenter.mirror.hintText ?? "nil")")
    }

    /// Following the level-3 hints, then the run hint, wins level 1 within the certified action count: the stars line
    /// reads "Best: 3 of 3 stars", the picker offers level 2 and Play level opens it, and a won play has no hint
    /// (FR-R02G2105-002, 004; SC-R02G2105-002, 004).
    @Test func followingLevelThreeHintsWinsWithThreeStars() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: BinaryGardensPresenter = shell.presenter
        #expect(presenter.mirror.starsLabel == "Best: not won yet")
        #expect(presenter.mirror.bestStars == 0)
        var changes: Int = 0
        var ran: Bool = false
        for _ in 0..<Teaching.followLimit {
            let core: Core = try Teaching.core(shell)
            guard core.play.stage == .playing else { break }
            let direct: BinaryGardensHint = try #require(core.hint(level: 3))
            for _ in 0..<3 { try await Teaching.pressHint(presenter) }
            #expect(presenter.mirror.hintLevel == 3)
            #expect(presenter.mirror.hintText == direct.text, "\(presenter.mirror.hintText ?? "nil")")
            let action: BinaryGardensAction = try #require(direct.action, "\(direct.text)")
            if direct.kind == .run {
                #expect(direct.text == BinaryGardensHint.runText)
                ran = true
            } else {
                #expect(direct.kind != .stuck, "\(direct.text)")
                changes += 1
            }
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "\(direct.text): \(result.code)")
            guard result == .accepted else { break }
        }
        let won: Core = try Teaching.core(shell)
        #expect(ran, "the hints end with the run")
        #expect(won.play.stage == .won, "\(won.play.stage)")
        #expect(changes <= won.certifiedActionCount, "\(changes) changes, certified \(won.certifiedActionCount)")
        #expect(won.progress.stars(of: 1) == 3)
        #expect(presenter.mirror.bestStars == 3)
        #expect(presenter.mirror.starsLabel == "Best: 3 of 3 stars")
        #expect(presenter.mirror.tutorialText == nil, "the end of the level ends the tutorial")
        let text: String = try Teaching.describe(shell)
        #expect(text.contains("Best: 3 of 3 stars."), "\(text)")

        // A won play has no hint.
        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 0)
        #expect(presenter.mirror.hintText == BinaryGardensPresenter.noHintText)

        // The campaign win opened level 2: the picker reaches it and Play level opens it.
        #expect(won.progress.frontier == 2)
        #expect(presenter.mirror.frontier == 2)
        #expect(presenter.mirror.stars[1] == 3)
        #expect(presenter.mirror.levelLabel(1) == "Level 1, band 1, 3 of 3 stars")
        #expect(presenter.mirror.levelLabel(2) == "Level 2, band 1")
        let picked: ActionResult = presenter.selectLevel(2, port: shell.port)
        #expect(picked == .accepted, "\(picked.code)")
        _ = try Teaching.describe(shell)
        #expect(try Teaching.core(shell).levelNumber == 2)
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.pickedLevel == 2)
        #expect(presenter.mirror.starsLabel == "Best: not won yet")
        #expect(presenter.mirror.tutorialText == Step.adjust.text, "level 2 carries the tutorial")
    }

    /// A failing run at level 1: the panel's explanation equals the adapter's failure explanation and replaces the
    /// short failure line in the panel (the short words stay the status line), the description names it, and the
    /// failed play's hint is the undo-or-retry advice (FR-R02G2105-003, SC-R02G2105-003).
    @Test func failedRunShowsTheExplanation() async throws {
        let setUp: [BinaryGardensAction] = try #require(try Teaching.failingSetUp(),
                                                        "a set-up of level 1 whose run fails")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: BinaryGardensPresenter = shell.presenter
        #expect(presenter.mirror.explanation == nil)
        for action in setUp {
            let result: ActionResult = try Teaching.send(action, shell)
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(presenter.mirror.explanation == nil, "no explanation before the run fails")
        let ranResult: ActionResult = try Teaching.send(.run, shell)
        #expect(ranResult == .accepted, "\(ranResult.code)")
        let failed: Core = try Teaching.core(shell)
        try #require(failed.play.stage == .failed, "the run fails: \(failed.play.stage)")
        let want: String = try #require(failed.failureExplanation?.text)
        #expect(want.hasPrefix("World "), "\(want)")
        #expect(want.hasSuffix(" " + BinaryGardensFailureExplanation.advice), "\(want)")
        #expect(BinaryGardensFailureExplanation.advice == "Undo the last action or retry the level.")
        #expect(presenter.mirror.explanation == want, "\(presenter.mirror.explanation ?? "nil")")
        let short: String = try #require(presenter.mirror.failureText, "the short failure words stay the status line")
        #expect(short == BinaryGardensMirror.failureText(failed.play.failure, level: failed.play.level))
        #expect(presenter.mirror.status == "Failed: " + short)
        #expect(want != short, "the explanation is not the short line")
        let text: String = try Teaching.describe(shell)
        #expect(text.contains(want), "\(text)")

        try await Teaching.pressHint(presenter)
        #expect(presenter.mirror.hintLevel == 1)
        #expect(presenter.mirror.hintText == BinaryGardensHint.failedText)
    }

    /// Level 1 is band 1 and level 21 band 2; the goal line is "Win in at most k actions for 3 stars" with the
    /// certified action count; the stars line reads "Best: not won yet"; the description includes the mode, band, goal
    /// and stars sentences (FR-R02G2105-004, SC-R02G2105-004).
    @Test func bandGoalAndStarsLines() async throws {
        let numbers: [Int] = [1, 21]
        let bands: [String] = ["Band 1 of 5", "Band 2 of 5"]
        let goals: [String] = ["Win in at most 1 action for 3 stars", "Win in at most 2 actions for 3 stars"]
        for index in numbers.indices {
            let number: Int = numbers[index]
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Teaching.open(session, number: number)
            let core: Core = try Teaching.core(shell)
            let mirror: BinaryGardensMirror = shell.presenter.mirror
            #expect(core.levelNumber == number)
            #expect(mirror.band == core.band)
            #expect(mirror.bandLabel == bands[index], "level \(number): \(mirror.bandLabel)")
            let goal: String = BinaryGardensMirror.goalText(certified: core.certifiedActionCount)
            #expect(core.certifiedActionCount == index + 1, "the certified witnesses are 1 and 2 actions in bands 1, 2")
            #expect(goal == goals[index], "\(goal)")
            #expect(mirror.goalLabel == goal, "\(mirror.goalLabel)")
            #expect(mirror.modeLabel == "Mode: campaign")
            #expect(mirror.starsLabel == "Best: not won yet")
            let text: String = try Teaching.describe(shell)
            #expect(text.contains("Mode: campaign."), "\(text)")
            #expect(text.contains(bands[index] + "."), "\(text)")
            #expect(text.contains(goal + "."), "\(text)")
            #expect(text.contains("Best: not won yet."), "\(text)")
        }
    }

    /// Practice replays the current level with the budget raised to 24; Daily of 2026-12-03 opens its daily level 69
    /// in daily mode (locked in the campaign, still playable); Campaign returns to the campaign's frontier
    /// (FR-R02G2105-005, SC-R02G2105-004).
    @Test func modeButtonsPracticeDailyCampaign() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: BinaryGardensPresenter = shell.presenter
        #expect(presenter.mirror.modeLabel == "Mode: campaign")
        #expect(try Teaching.core(shell).progress.frontier == 1)
        let campaignBudget: Int = try Core.level(number: 1).budget
        #expect(campaignBudget < Teaching.practiceBudget)

        let practice: ActionResult = presenter.playPractice(port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        let practisedText: String = try Teaching.describe(shell)
        let practised: Core = try Teaching.core(shell)
        #expect(practised.levelNumber == 1)
        #expect(practised.mode == .practice)
        #expect(BinaryGardensMode.practiceBudget == Teaching.practiceBudget)
        #expect(practised.play.level.budget == Teaching.practiceBudget)
        #expect(practised.play.actionsLeft == Teaching.practiceBudget)
        #expect(presenter.mirror.budget == Teaching.practiceBudget)
        #expect(presenter.mirror.modeLabel == "Mode: practice")
        #expect(practisedText.contains("Mode: practice."), "\(practisedText)")

        let date: DateComponents = Teaching.dailyDate
        let dailyNumber: Int? = BinaryGardensProgress.dailyLevel(year: date.year ?? 0, month: date.month ?? 0,
                                                                 day: date.day ?? 0)
        #expect(dailyNumber == Teaching.dailyNumber)
        #expect(BinaryGardensPresenter.dateValues(date) == [2026, 12, 3])
        let daily: ActionResult = presenter.playDaily(port: shell.port, date: date)
        #expect(daily == .accepted, "\(daily.code)")
        let dailyText: String = try Teaching.describe(shell)
        let dailyCore: Core = try Teaching.core(shell)
        #expect(dailyCore.levelNumber == Teaching.dailyNumber)
        #expect(dailyCore.mode == .daily(level: Teaching.dailyNumber))
        #expect(dailyCore.progress.frontier == 1, "a daily level is not opened")
        #expect(presenter.mirror.levelNumber == Teaching.dailyNumber)
        #expect(presenter.mirror.modeLabel == "Mode: daily")
        #expect(presenter.mirror.bandLabel == Teaching.dailyBand)
        #expect(dailyText.hasPrefix("Binary Gardens level \(Teaching.dailyNumber). "), "\(dailyText)")
        #expect(dailyText.contains("Mode: daily."), "\(dailyText)")
        #expect(dailyText.contains(Teaching.dailyBand + "."), "\(dailyText)")

        let campaign: ActionResult = presenter.playCampaign(port: shell.port)
        #expect(campaign == .accepted, "\(campaign.code)")
        _ = try Teaching.describe(shell)
        let back: Core = try Teaching.core(shell)
        #expect(back.mode == .campaign)
        #expect(back.levelNumber == 1, "level 69 is not open, so Campaign goes to the frontier")
        #expect(back.play.level.budget == campaignBudget)
        #expect(presenter.mirror.modeLabel == "Mode: campaign")
        #expect(presenter.mirror.message == nil)
    }

    /// The local date the Daily button sends is today's Gregorian year, month and day (the presenter reads the clock;
    /// the core never does), and the adapter accepts it (FR-R02G2105-005).
    @Test func dailyButtonSendsTodaysLocalDate() async throws {
        let today: DateComponents = BinaryGardensPresenter.today()
        let values: [Double] = BinaryGardensPresenter.dateValues(today)
        #expect(values.count == 3)
        let year: Int = today.year ?? 0
        let month: Int = today.month ?? 0
        let day: Int = today.day ?? 0
        #expect(values == [Double(year), Double(month), Double(day)])
        let want: Int = try #require(BinaryGardensProgress.dailyLevel(year: year, month: month, day: day),
                                     "today is a valid date")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let sent: ActionResult = shell.presenter.playDaily(port: shell.port)
        _ = try Teaching.describe(shell)
        #expect(sent == .accepted, "\(sent.code)")
        // The day can roll over between the reads only at midnight: the level is today's before or after the send.
        let later: DateComponents = BinaryGardensPresenter.today()
        let wantLater: Int? = BinaryGardensProgress.dailyLevel(year: later.year ?? 0, month: later.month ?? 0,
                                                               day: later.day ?? 0)
        let core: Core = try Teaching.core(shell)
        #expect(core.levelNumber == want || core.levelNumber == wantLater, "\(core.levelNumber)")
        #expect(core.mode == .daily(level: core.levelNumber))
        #expect(shell.presenter.mirror.levelNumber == core.levelNumber)
        #expect(shell.presenter.mirror.modeLabel == "Mode: daily")
    }

    /// Selecting a locked level (the level picker's Play level) is refused in words and changes nothing
    /// (FR-R02G2105-004).
    @Test func lockedLevelRefusedInWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: BinaryGardensPresenter = shell.presenter
        let before: Core = try Teaching.core(shell)
        #expect(before.progress.frontier == 1)
        #expect(presenter.mirror.frontier == 1)
        let digest: String = try BinaryGardensTest.digest(shell)
        let locked: ActionResult = presenter.selectLevel(2, port: shell.port)
        _ = try Teaching.describe(shell)
        let code: String = BinaryGardensExperienceRule.locked
        #expect(code == "r02-g21.locked")
        #expect(Teaching.isRefusal(locked, code), "\(locked.code)")
        let message: String = Teaching.refusalMessage(code)
        #expect(message == "That level is not open yet.")
        #expect(presenter.mirror.message == message, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == code)
        #expect(try Teaching.core(shell) == before, "a refused pick changes nothing")
        #expect(try BinaryGardensTest.digest(shell) == digest)
        #expect(presenter.mirror.levelNumber == 1)
    }

    /// Next level on the last open level (level 1, nothing won) is refused as locked, in words, and changes nothing
    /// (FR-R02G2105-004).
    @Test func nextLevelOnTheLastOpenLevelRefusedInWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: BinaryGardensPresenter = shell.presenter
        let before: Core = try Teaching.core(shell)
        #expect(before.progress.nextOpen(after: 1) == nil)
        let digest: String = try BinaryGardensTest.digest(shell)
        let refused: ActionResult = presenter.send("level.next", [], port: shell.port)
        _ = try Teaching.describe(shell)
        let code: String = BinaryGardensExperienceRule.locked
        #expect(Teaching.isRefusal(refused, code), "\(refused.code)")
        let message: String = try #require(presenter.mirror.message)
        #expect(message == Teaching.refusalMessage(code))
        #expect(message.contains("not open yet"), "\(message)")
        #expect(presenter.refusalLog.last == code)
        #expect(try Teaching.core(shell) == before, "a refused next level changes nothing")
        #expect(try BinaryGardensTest.digest(shell) == digest)
        #expect(presenter.mirror.levelNumber == 1)
    }

    /// An impossible date (2027-02-29) is refused in words and changes nothing (FR-R02G2105-005).
    @Test func impossibleDateRefusedInWords() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Teaching.open(session, number: 1)
        let presenter: BinaryGardensPresenter = shell.presenter
        let before: Core = try Teaching.core(shell)
        let digest: String = try BinaryGardensTest.digest(shell)
        let refused: ActionResult = presenter.playDaily(port: shell.port, date: Teaching.impossibleDate)
        _ = try Teaching.describe(shell)
        let code: String = BinaryGardensExperienceRule.date
        #expect(code == "r02-g21.date")
        #expect(Teaching.isRefusal(refused, code), "\(refused.code)")
        let message: String = Teaching.refusalMessage(code)
        #expect(message == "That date cannot be used.")
        #expect(presenter.mirror.message == message, "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == code)
        #expect(try Teaching.core(shell) == before, "a refused date changes nothing")
        #expect(try BinaryGardensTest.digest(shell) == digest)
        #expect(presenter.mirror.modeLabel == "Mode: campaign")
    }
}
#endif
