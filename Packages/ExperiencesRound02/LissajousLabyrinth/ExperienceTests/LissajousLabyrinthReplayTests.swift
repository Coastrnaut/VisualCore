// LissajousLabyrinthReplayTests — feature 317 (R02-G02-07) T-R02G0207-005 (FR-R02G0207-003, 004;
// SC-R02G0207-004).
// On the simulator, through the one app's session host, modelled on Aurora Loom's feature-307 replay tests. The
// presenter's route records (a `RecordingHapticSink`, a `RecordingAnnouncementSink`, the accessibility tests' clock
// moved 1 s before every action so nothing is rate-limited, VoiceOver reported running). Replay (clarification Q4, user
// story 3): level 1 (seed 0) is won with its certified solution through `presenter.send`, the play fingerprint recorded
// before and after every action; the stored result is verified and its trace is the solution; the mirror offers a
// replay; `startReplay` opens mode `replay(1)` on a fresh play (fingerprint as before the win, position 0, length the
// certified solution length); every `stepReplay` reproduces the win's fingerprint and record of that action, moves the
// mirror's position and routes `LissajousLabyrinthFeedbackPlan.after(old:new:)`; the last step wins; the progress never
// changes (SC-R02G0207-004). During replay `dial.set`, `level.next` and `play.undo` are refused with `r02-g02.replay`
// (shown and announced as `refused(code:)`'s text) and change nothing, `tutorial.dismiss` is accepted, `retryAction` is
// `replay.start [1]`; one step past the end is refused with `r02-g02.replay-end`; `stopReplay` returns to the campaign
// at level 1. Refusals: `replay.start` of an unsolved level (level 1 before any win, level 2 after level 1 is won) and
// `replay.step` / `replay.stop` outside a replay are refused with `r02-g02.no-replay` and change nothing. Dropped
// results (clarification Q2): a real core's payload with its stars edited from 3 to 2 restores with one result dropped;
// the session host restores only digest-checked envelopes, so the edited payload is restored with
// `LissajousLabyrinthExperienceCore.restore(payload:seed:)` and handed to a fresh presenter's `describe(_:)`, which
// announces "1 saved result could not be checked and was removed." exactly once across repeated describes; two edited
// results give "2 saved results could not be checked and were removed." once. Synthetic data, explicit types, plain
// loops, no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import Foundation
import Testing
import LissajousLabyrinthCore
@testable import LissajousLabyrinthExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the replay tests.
@MainActor
enum LissajousLabyrinthReplayScript {
    typealias Shell = ExperienceShell<LissajousLabyrinthPresenter>
    typealias Access = LissajousLabyrinthAccess

    /// Wins the current level of `shell` (number `number`, in a fresh play) with its certified solution through
    /// `presenter.send`, the clock advanced before every action; returns the play fingerprints before the first action
    /// and after each one.
    static func win(_ shell: Shell, number: Int, recorder: Access.Recorder) throws -> [String] {
        let certified: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: number)
        var fingerprints: [String] = [try Access.core(shell).play.fingerprint]
        for action in certified.solution.actions {
            recorder.clock.advance()
            let result: ActionResult = shell.presenter.send(action, port: shell.port)
            #expect(result == .accepted, "\(result.code)")
            fingerprints.append(try Access.core(shell).play.fingerprint)
        }
        let core: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(core.levelNumber == number)
        #expect(core.play.stage == .won)
        return fingerprints
    }

    /// How many times `text` appears in `announced`.
    static func count(_ text: String, in announced: [String]) -> Int {
        var found: Int = 0
        for entry in announced where entry == text { found += 1 }
        return found
    }

    /// The `dial.set` values of an action that is legal on `dials`: frequency A moved to another value coprime with
    /// frequency B (the refusal during replay comes before the kernel, so legality only keeps the check honest).
    static func legalDialSet(_ dials: LissajousLabyrinthDials) -> [Double] {
        for value in LissajousLabyrinthDial.frequencyA.range where value != dials.frequencyA {
            var changed: LissajousLabyrinthDials = dials
            changed[.frequencyA] = value
            if changed.isValid { return [0, Double(value)] }
        }
        return [0, Double(dials.frequencyA == 1 ? 2 : 1)]
    }
}

@MainActor
@Suite(.serialized) struct LissajousLabyrinthReplayTests {
    typealias Access = LissajousLabyrinthAccess
    typealias Script = LissajousLabyrinthReplayScript
    typealias Plan = LissajousLabyrinthFeedbackPlan
    typealias Rule = LissajousLabyrinthExperienceRule

    // MARK: Replay through the port and the presenter (FR-R02G0207-004; SC-R02G0207-004)

    /// Level 1 won with its certified solution, then replayed action by action through the presenter: the same
    /// fingerprints and records, a win at the end, the progress unchanged; other actions refused; stop returns to the
    /// campaign.
    @Test func replayReproducesTheWinActionByAction() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        #expect(try Access.core(shell).levelNumber == 1)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        let certified: LissajousLabyrinthGenerated = try LissajousLabyrinthExperienceCore.generated(number: 1)
        let length: Int = certified.solution.actions.count
        try #require(length > 0)
        #expect(length == certified.solution.shortest)
        let fingerprints: [String] = try Script.win(shell, number: 1, recorder: recorder)
        #expect(fingerprints.count == length + 1)
        let won: LissajousLabyrinthExperienceCore = try Access.core(shell)
        let stored: LissajousLabyrinthProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == certified.solution.actions, "the trace is the winning actions")
        #expect(stored.bestActions == length)
        #expect(stored.stars == 3)
        #expect(won.play.records.count == length)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)

        // Start: a fresh play of level 1 in replay mode, announced as a level change.
        recorder.clock.advance()
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let opened: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(opened.mode == .replay(level: 1))
        #expect(opened.levelNumber == 1)
        #expect(opened.tutorial == .done, "the tutorial is done during replay")
        #expect(opened.play.spent == 0)
        #expect(opened.play.records.isEmpty)
        #expect(opened.play.stage == .playing)
        #expect(opened.play.fingerprint == fingerprints[0], "the replay starts where the win started")
        #expect(opened.progress == won.progress)
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == length)
        #expect(presenter.mirror.mode == .replay(level: 1))
        let startPlan: Plan = Plan.after(old: won, new: opened)
        #expect(startPlan.text == "Level 1, band 1, replay.", "\(startPlan.text ?? "nil")")
        #expect(presenter.feedbackLog.last == startPlan)
        #expect(recorder.announcements.announced.last == startPlan.text)
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(retry.control == "replay.start")
        #expect(retry.values == [1])

        // Other actions are refused during the replay, shown and announced, and change nothing.
        let refusedControls: [(control: String, values: [Double])] = [
            ("dial.set", Script.legalDialSet(opened.play.dials)),
            ("level.next", []),
            ("play.undo", []),
        ]
        for refused in refusedControls {
            let digest: String = try LissajousLabyrinthTest.digest(shell)
            recorder.clock.advance()
            let result: ActionResult = presenter.send(refused.control, refused.values, port: shell.port)
            #expect(result == .rejected(.rule(code: Rule.replay)), "\(refused.control): \(result.code)")
            #expect(!result.code.contains(Rule.replayEnd), "\(refused.control): \(result.code)")
            let plan: Plan = Plan.refused(code: result.code)
            let text: String = try #require(plan.text)
            #expect(presenter.mirror.message == text, "\(refused.control): \(presenter.mirror.message ?? "nil")")
            #expect(presenter.feedbackLog.last == plan)
            #expect(plan.kind == .rejection)
            #expect(plan.haptic == .error)
            #expect(recorder.announcements.announced.last == text, "\(refused.control)")
            #expect(try Access.core(shell) == opened, "\(refused.control) changed nothing")
            #expect(try LissajousLabyrinthTest.digest(shell) == digest)
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == 0)
        }

        // `tutorial.dismiss` is still accepted and changes nothing here (the tutorial is already done).
        recorder.clock.advance()
        presenter.dismissTutorial(port: shell.port)
        #expect(try Access.core(shell) == opened)
        #expect(presenter.mirror.replaying)

        // Every step reproduces the win's fingerprint and record of that action.
        for k in 1...length {
            let before: LissajousLabyrinthExperienceCore = try Access.core(shell)
            recorder.clock.advance()
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: LissajousLabyrinthExperienceCore = try Access.core(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(core.play.spent == k)
            #expect(core.play.fingerprint == fingerprints[k], "step \(k): the fingerprint of the win")
            let record: LissajousLabyrinthRecord = try #require(core.play.records.last)
            #expect(record.kind == .action)
            #expect(record.dial == stored.trace[k - 1].dial)
            #expect(record.value == stored.trace[k - 1].value)
            #expect(record.previous == fingerprints[k - 1])
            #expect(record.next == fingerprints[k])
            #expect(core.play.records == Array(won.play.records.prefix(k)), "step \(k): the win's records")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            #expect(core.play.stage == (k < length ? LissajousLabyrinthStage.playing : .won), "step \(k)")
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == k)
            #expect(presenter.mirror.replayLength == length)
            #expect(presenter.mirror.message == nil)
            let plan: Plan = Plan.after(old: before, new: core)
            #expect(presenter.feedbackLog.last == plan, "step \(k)")
            #expect(recorder.announcements.announced.last == plan.text, "step \(k)")
        }
        try LissajousLabyrinthTest.draw(session)
        let finished: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")
        #expect(presenter.mirror.stage == .won)

        // One step past the end is refused and changes nothing.
        let endDigest: String = try LissajousLabyrinthTest.digest(shell)
        recorder.clock.advance()
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        let endText: String = try #require(Plan.refused(code: past.code).text)
        #expect(presenter.mirror.message == endText)
        #expect(recorder.announcements.announced.last == endText)
        #expect(try Access.core(shell) == finished)
        #expect(try LissajousLabyrinthTest.digest(shell) == endDigest)
        #expect(presenter.mirror.replayPosition == length)

        // Stop: back to the campaign at level 1, the replay offered again, the progress unchanged.
        recorder.clock.advance()
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(campaign.mode == .campaign)
        #expect(campaign.levelNumber == 1)
        #expect(campaign.play.spent == 0)
        #expect(campaign.play.stage == .playing)
        #expect(campaign.progress == won.progress)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.message == nil)
        let stopSaid: String = recorder.announcements.announced.last ?? "nil"
        #expect(stopSaid.hasPrefix("Level 1, band 1, campaign."), "\(stopSaid)")
        let campaignRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(campaignRetry.control == "level.select")
        #expect(campaignRetry.values == [1])
        #expect(Script.count("Level 1, band 1, replay.", in: recorder.announcements.announced) == 1)
    }

    // MARK: Refusals outside a replay (FR-R02G0207-004)

    /// `replay.start` of an unsolved level is refused with `r02-g02.no-replay` and changes nothing; so are
    /// `replay.step` and `replay.stop` outside a replay.
    @Test func replayOfAnUnsolvedLevelIsRefused() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: LissajousLabyrinthPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let opening: LissajousLabyrinthExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.progress.solved[1] == nil)
        let digest: String = try LissajousLabyrinthTest.digest(shell)

        recorder.clock.advance()
        let unsolved: ActionResult = presenter.startReplay(port: shell.port)
        #expect(unsolved == .rejected(.rule(code: Rule.noReplay)), "\(unsolved.code)")
        let text: String = try #require(Plan.refused(code: unsolved.code).text)
        #expect(presenter.mirror.message == text, "\(presenter.mirror.message ?? "nil")")
        #expect(recorder.announcements.announced.last == text)
        #expect(presenter.feedbackLog.last == Plan.refused(code: unsolved.code))
        #expect(try Access.core(shell) == opening, "a refused replay changes nothing")
        #expect(try LissajousLabyrinthTest.digest(shell) == digest)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable == false)
        #expect(presenter.mirror.mode == .campaign)

        let outside: [String] = ["replay.step", "replay.stop"]
        for control in outside {
            recorder.clock.advance()
            let result: ActionResult = presenter.send(control, port: shell.port)
            #expect(result == .rejected(.rule(code: Rule.noReplay)), "\(control): \(result.code)")
            #expect(try Access.core(shell) == opening, "\(control) changed nothing")
            #expect(try LissajousLabyrinthTest.digest(shell) == digest)
        }

        // After a win of level 1, level 2 is open but unsolved: its replay is refused too.
        _ = try Script.win(shell, number: 1, recorder: recorder)
        recorder.clock.advance()
        let picked: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(picked == .accepted, "\(picked.code)")
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.replayAvailable == false)
        let second: LissajousLabyrinthExperienceCore = try Access.core(shell)
        let secondDigest: String = try LissajousLabyrinthTest.digest(shell)
        recorder.clock.advance()
        let none: ActionResult = presenter.startReplay(port: shell.port)
        #expect(none == .rejected(.rule(code: Rule.noReplay)), "\(none.code)")
        #expect(try Access.core(shell) == second)
        #expect(try LissajousLabyrinthTest.digest(shell) == secondDigest)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.mode == .campaign)
    }

    // MARK: Dropped results (FR-R02G0207-003; clarification Q2)

    /// A restored core whose edited result was dropped is announced once by the presenter that describes it, however
    /// many cores it describes after it; two dropped results use the plural text.
    @Test func droppedResultsAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let recorder: Access.Recorder = Access.record(shell)
        _ = try Script.win(shell, number: 1, recorder: recorder)
        let won: LissajousLabyrinthExperienceCore = try Access.core(shell)
        let payload: Data = try won.snapshotPayload()
        let honest: LissajousLabyrinthExperienceCore = try LissajousLabyrinthExperienceCore.restore(payload: payload,
                                                                                                     seed: 0)
        #expect(honest.reconciliationDropped == 0)
        #expect(honest.progress == won.progress)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        let tampered: String = text.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":2")
        try #require(tampered != text, "the payload holds a 3-star result")
        let restored: LissajousLabyrinthExperienceCore = try LissajousLabyrinthExperienceCore.restore(
            payload: Data(tampered.utf8), seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[1] == nil)
        #expect(restored.progress.frontier == won.progress.frontier, "the frontier is kept as saved")

        let expected: String = "1 saved result could not be checked and was removed."
        let presenter: LissajousLabyrinthPresenter = LissajousLabyrinthPresenter(reduceMotion: false,
                                                                                 reduceFlashing: false)
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: LissajousLabyrinthAccessClock = LissajousLabyrinthAccessClock()
        presenter.feedback = ExperienceFeedback(hapticSink: haptics, announcementSink: announcements,
                                                clock: { clock.now }, voiceOverRunning: { true })
        clock.advance()
        _ = presenter.describe(restored)
        #expect(announcements.announced == [expected], "\(announcements.announced)")
        #expect(presenter.announcements == [expected])
        #expect(presenter.feedbackLog == [Plan(text: expected, kind: .state, haptic: nil)])
        #expect(haptics.played.isEmpty)
        #expect(presenter.mirror.replayAvailable == false, "the dropped result offers no replay")
        #expect(presenter.mirror.stars[1] == nil)

        // Further describes, the same restored core among them, never repeat the announcement.
        let again: LissajousLabyrinthExperienceCore = try LissajousLabyrinthExperienceCore.restore(
            payload: Data(tampered.utf8), seed: 0)
        let followers: [LissajousLabyrinthExperienceCore] = [restored, again, honest, restored]
        for follower in followers {
            clock.advance()
            _ = presenter.describe(follower)
        }
        clock.advance()
        presenter.feedback.flush()
        #expect(Script.count(expected, in: announcements.announced) == 1, "\(announcements.announced)")
        #expect(Script.count(expected, in: presenter.announcements) == 1)

        // A presenter that describes only the honest core announces nothing about dropped results.
        let clean: LissajousLabyrinthPresenter = LissajousLabyrinthPresenter(reduceMotion: false, reduceFlashing: false)
        let cleanAnnouncements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        clean.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(), announcementSink: cleanAnnouncements,
                                            clock: { clock.now }, voiceOverRunning: { true })
        clock.advance()
        _ = clean.describe(honest)
        #expect(cleanAnnouncements.announced.isEmpty, "\(cleanAnnouncements.announced)")
        #expect(clean.mirror.replayAvailable, "the honest result offers a replay")

        // Two edited results: level 2 won as well, both stars edited, the plural text once.
        recorder.clock.advance()
        let picked: ActionResult = shell.presenter.send("level.select", [2], port: shell.port)
        #expect(picked == .accepted, "\(picked.code)")
        _ = try Script.win(shell, number: 2, recorder: recorder)
        let both: LissajousLabyrinthExperienceCore = try Access.core(shell)
        try #require(both.progress.solved[1]?.stars == 3)
        try #require(both.progress.solved[2]?.stars == 3)
        let bothText: String = try #require(String(data: try both.snapshotPayload(), encoding: .utf8))
        let bothTampered: String = bothText.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":2")
        let twice: LissajousLabyrinthExperienceCore = try LissajousLabyrinthExperienceCore.restore(
            payload: Data(bothTampered.utf8), seed: 0)
        #expect(twice.reconciliationDropped == 2)
        #expect(twice.progress.solved.isEmpty)
        let plural: String = "2 saved results could not be checked and were removed."
        let second: LissajousLabyrinthPresenter = LissajousLabyrinthPresenter(reduceMotion: false,
                                                                              reduceFlashing: false)
        let secondAnnouncements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        second.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(), announcementSink: secondAnnouncements,
                                             clock: { clock.now }, voiceOverRunning: { true })
        for _ in 0..<2 {
            clock.advance()
            _ = second.describe(twice)
        }
        #expect(secondAnnouncements.announced == [plural], "\(secondAnnouncements.announced)")

        // The session's own presenter never saw a dropped result.
        #expect(Script.count(expected, in: recorder.announcements.announced) == 0)
        #expect(Script.count(plural, in: recorder.announcements.announced) == 0)
    }
}
#endif
