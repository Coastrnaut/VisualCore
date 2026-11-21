// WaveKnotKeeperReplayTests — feature 327 (R02-G03-07) T-R02G0307-005 (FR-R02G0307-003, 004; SC-R02G0307-004;
// clarifications Q2, Q4).
// On the simulator, through the one app's session host, modelled on Lissajous Labyrinth's feature-317 replay tests. The
// presenter's route records (a `RecordingHapticSink`, a `RecordingAnnouncementSink`, the accessibility tests' clock
// moved 1 s before every action so nothing is rate-limited, VoiceOver reported running). Replay (clarification Q4):
// level 1 (seed 0) is won in campaign with its certified solution through `presenter.send`, the play fingerprint
// recorded before and after every move; the stored result is verified and its trace is the solution; the mirror offers
// a replay; `startReplay` opens mode `replay(level: 1)` on a fresh play (fingerprint as before the win, position 0,
// length the trace count); every `stepReplay` reproduces the win's fingerprint and record of that move, moves the
// mirror's position and routes `WaveKnotKeeperFeedbackPlan.after(old:new:)`; the last step wins without stars; the
// progress never changes (SC-R02G0307-004). One step past the end is refused with `r02-g03.replay-end` ("The replay is
// over."); `stopReplay` returns to the campaign at level 1. During replay `point.move`, `play.undo`, `level.next`,
// `mode.practice` and `tutorial.hint` are refused with `r02-g03.replay` ("Stop the replay first.") and leave the digest
// unchanged; `point.select` and `tutorial.dismiss` are accepted; `retryAction` is `replay.start [1]`. Without a verified
// result `replay.start` is refused with `r02-g03.no-replay` ("There is no saved solution to replay for this level.").
// Dropped results (clarification Q2): a real core's payload with its stars edited from 3 to 2 restores with one result
// dropped; the session host restores only digest-checked envelopes, so the edited payload is restored with
// `WaveKnotKeeperExperienceCore.restore(payload:seed:)` and handed to a fresh presenter's `describe(_:)`, which announces
// "1 saved result could not be checked and was removed." exactly once across repeated describes. Synthetic data,
// explicit types, plain loops, no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import Foundation
import Testing
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the replay tests.
@MainActor
enum WaveKnotKeeperReplayScript {
    typealias Shell = ExperienceShell<WaveKnotKeeperPresenter>
    typealias Access = WaveKnotKeeperAccess

    /// Wins the current level of `shell` (number `number`, in a fresh play) with its certified solution through
    /// `presenter.send`, the clock advanced before every move; returns the play fingerprints before the first move and
    /// after each one.
    static func win(_ shell: Shell, number: Int, recorder: Access.Recorder) throws -> [String] {
        let certified: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: number)
        var fingerprints: [String] = [try Access.core(shell).play.fingerprint]
        for move in certified.solution.moves {
            recorder.clock.advance()
            let result: ActionResult = WaveKnotKeeperTeaching.send(move, shell)
            #expect(result == .accepted, "\(result.code)")
            fingerprints.append(try Access.core(shell).play.fingerprint)
        }
        let core: WaveKnotKeeperExperienceCore = try Access.core(shell)
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

    /// The values of a `point.move` that is legal on `core`'s play (the refusal during replay comes before the kernel,
    /// so legality only keeps the check honest); point 0 to the first direction when none is legal.
    static func legalMoveValues(_ core: WaveKnotKeeperExperienceCore) -> [Double] {
        if let legal = WaveKnotKeeperTest.legalMove(core) {
            return [Double(legal.point), Double(legal.direction)]
        }
        return [0, 0]
    }

    /// Opens level 1 (seed 0) with a recording route, wins it in campaign and starts its replay; returns the shell,
    /// the recorder, the won core, the win's fingerprints and the replay's opening core.
    static func startedReplay(_ session: ExperienceSession) async throws
        -> (shell: Shell, recorder: Access.Recorder, won: WaveKnotKeeperExperienceCore, fingerprints: [String],
            opened: WaveKnotKeeperExperienceCore) {
        let shell: Shell = try await Access.open(session)
        let recorder: Access.Recorder = Access.record(shell)
        let fingerprints: [String] = try win(shell, number: 1, recorder: recorder)
        let won: WaveKnotKeeperExperienceCore = try Access.core(shell)
        recorder.clock.advance()
        let started: ActionResult = shell.presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let opened: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(opened.mode == .replay(level: 1))
        return (shell, recorder, won, fingerprints, opened)
    }
}

@MainActor
@Suite(.serialized) struct WaveKnotKeeperReplayTests {
    typealias Access = WaveKnotKeeperAccess
    typealias Script = WaveKnotKeeperReplayScript
    typealias Plan = WaveKnotKeeperFeedbackPlan
    typealias Rule = WaveKnotKeeperExperienceRule

    // MARK: Replay through the port and the presenter (FR-R02G0307-004; SC-R02G0307-004)

    /// Level 1 won in campaign with its certified solution, then replayed move by move through the presenter: the
    /// same fingerprints and records, every step announced, a win at the end, the progress unchanged; a step past the
    /// end refused; stop returns to the campaign at level 1.
    @Test func replayReproducesTheWinMoveByMove() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        #expect(try Access.core(shell).levelNumber == 1)
        #expect(try Access.core(shell).mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        let certified: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: 1)
        let length: Int = certified.solution.moves.count
        try #require(length > 0)
        #expect(length == certified.solution.shortest)
        let fingerprints: [String] = try Script.win(shell, number: 1, recorder: recorder)
        #expect(fingerprints.count == length + 1)
        let won: WaveKnotKeeperExperienceCore = try Access.core(shell)
        let stored: WaveKnotKeeperProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == certified.solution.moves, "the trace is the winning moves")
        #expect(stored.bestMoves == length)
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
        let opened: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(opened.mode == .replay(level: 1))
        #expect(opened.levelNumber == 1)
        #expect(opened.tutorial == .done, "the tutorial is done during replay")
        #expect(opened.play.spent == 0)
        #expect(opened.play.records.isEmpty)
        #expect(opened.play.fingerprint == fingerprints[0], "the replay starts where the win started")
        #expect(opened.progress == won.progress)
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayAvailable == false, "no replay is offered during a replay")
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == stored.trace.count)
        #expect(presenter.mirror.replayLength == length)
        #expect(presenter.mirror.mode == .replay(level: 1))
        let startPlan: Plan = Plan.after(old: won, new: opened)
        #expect(startPlan.text == "Level 1, band 1, Replay.", "\(startPlan.text ?? "nil")")
        #expect(presenter.feedbackLog.last == startPlan)
        #expect(recorder.announcements.announced.last == startPlan.text)

        // Every step reproduces the win's fingerprint and record of that move and is announced.
        for k in 1...length {
            let before: WaveKnotKeeperExperienceCore = try Access.core(shell)
            let announcedBefore: Int = recorder.announcements.announced.count
            recorder.clock.advance()
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: WaveKnotKeeperExperienceCore = try Access.core(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(core.play.spent == k)
            #expect(core.play.fingerprint == fingerprints[k], "step \(k): the fingerprint of the win")
            let record: WaveKnotKeeperRecord = try #require(core.play.records.last)
            #expect(record.previous == fingerprints[k - 1])
            #expect(record.next == fingerprints[k])
            #expect(core.play.records == Array(won.play.records.prefix(k)), "step \(k): the win's records")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            #expect(core.play.stage == (k < length ? WaveKnotKeeperStage.playing : .won), "step \(k)")
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == k)
            #expect(presenter.mirror.replayLength == length)
            #expect(presenter.mirror.message == nil)
            let plan: Plan = Plan.after(old: before, new: core)
            let text: String = try #require(plan.text, "step \(k) is announced")
            #expect(presenter.feedbackLog.last == plan, "step \(k)")
            #expect(recorder.announcements.announced.count == announcedBefore + 1, "step \(k): one announcement")
            #expect(recorder.announcements.announced.last == text, "step \(k)")
        }
        try WaveKnotKeeperTest.draw(session)
        let finished: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")
        #expect(presenter.mirror.stage == .won)
        let winText: String = "The knot matches. Level won in \(Plan.moves(length))."
        #expect(recorder.announcements.announced.last == winText, "a replay win claims no stars")

        // One step past the end is refused and changes nothing.
        let endDigest: String = try WaveKnotKeeperTest.digest(shell)
        recorder.clock.advance()
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        #expect(presenter.mirror.message == "The replay is over.", "\(presenter.mirror.message ?? "nil")")
        #expect(recorder.announcements.announced.last == "The replay is over.")
        #expect(presenter.feedbackLog.last == Plan.refused(code: past.code))
        #expect(try Access.core(shell) == finished)
        #expect(try WaveKnotKeeperTest.digest(shell) == endDigest)
        #expect(presenter.mirror.replayPosition == length)

        // Stop: back to the campaign at level 1, the replay offered again, the progress unchanged.
        recorder.clock.advance()
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: WaveKnotKeeperExperienceCore = try Access.core(shell)
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
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.message == nil)
        let stopSaid: String = recorder.announcements.announced.last ?? "nil"
        #expect(stopSaid.hasPrefix("Level 1, band 1, Campaign."), "\(stopSaid)")
        #expect(Script.count("Level 1, band 1, Replay.", in: recorder.announcements.announced) == 1)
    }

    // MARK: Actions during replay (FR-R02G0307-004)

    /// During replay `point.move`, `play.undo`, `level.next`, `mode.practice` and `tutorial.hint` are refused with
    /// "Stop the replay first." and leave the digest unchanged; `point.select` and `tutorial.dismiss` are accepted.
    @Test func otherActionsAreRefusedDuringReplay() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let started = try await Script.startedReplay(session)
        let shell: WaveKnotKeeperReplayScript.Shell = started.shell
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        let recorder: Access.Recorder = started.recorder
        let opened: WaveKnotKeeperExperienceCore = started.opened
        let stopText: String = "Stop the replay first."

        let refusedControls: [(control: String, values: [Double])] = [
            ("point.move", Script.legalMoveValues(opened)),
            ("play.undo", []),
            ("level.next", []),
            ("mode.practice", []),
            ("tutorial.hint", []),
        ]
        for refused in refusedControls {
            let digest: String = try WaveKnotKeeperTest.digest(shell)
            recorder.clock.advance()
            let result: ActionResult = presenter.send(refused.control, refused.values, port: shell.port)
            #expect(result == .rejected(.rule(code: Rule.replay)), "\(refused.control): \(result.code)")
            #expect(!result.code.contains(Rule.replayEnd), "\(refused.control): \(result.code)")
            let plan: Plan = Plan.refused(code: result.code)
            #expect(plan.text == stopText, "\(refused.control): \(plan.text ?? "nil")")
            #expect(plan.kind == .rejection)
            #expect(plan.haptic == .error)
            #expect(presenter.mirror.message == stopText, "\(refused.control): \(presenter.mirror.message ?? "nil")")
            #expect(presenter.feedbackLog.last == plan)
            #expect(recorder.announcements.announced.last == stopText, "\(refused.control)")
            #expect(try Access.core(shell) == opened, "\(refused.control) changed nothing")
            #expect(try WaveKnotKeeperTest.digest(shell) == digest, "\(refused.control)")
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == 0)
        }

        // `point.select` is accepted: the selection moves, the play and the replay do not.
        recorder.clock.advance()
        let selected: ActionResult = presenter.send("point.select", [1], port: shell.port)
        #expect(selected == .accepted, "\(selected.code)")
        let afterSelect: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(afterSelect.mode == .replay(level: 1))
        #expect(afterSelect.play == opened.play)
        #expect(afterSelect.progress == opened.progress)
        #expect(presenter.mirror.selected == 1)
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(recorder.announcements.announced.last == "Point 2 selected.")

        // `tutorial.dismiss` is accepted and changes nothing here (the tutorial is already done).
        recorder.clock.advance()
        let dismissed: ActionResult = presenter.send("tutorial.dismiss", [], port: shell.port)
        #expect(dismissed == .accepted, "\(dismissed.code)")
        #expect(try Access.core(shell) == afterSelect)
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.message == nil)
    }

    /// `retryAction` during replay is `replay.start` of the replayed level, and retry starts that replay again.
    @Test func retryDuringReplayRestartsTheReplay() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let started = try await Script.startedReplay(session)
        let shell: WaveKnotKeeperReplayScript.Shell = started.shell
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(retry.control == "replay.start")
        #expect(retry.values == [1])

        started.recorder.clock.advance()
        let stepped: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(stepped == .accepted, "\(stepped.code)")
        #expect(presenter.mirror.replayPosition == 1)
        started.recorder.clock.advance()
        let again: ActionResult = presenter.retry(port: shell.port, date: DateComponents())
        #expect(again == .accepted, "\(again.code)")
        let core: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(core.mode == .replay(level: 1))
        #expect(core.play.spent == 0)
        #expect(core.play.fingerprint == started.fingerprints[0])
        #expect(core.progress == started.won.progress)
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayPosition == 0)

        // Outside the replay, retry is the campaign's `level.select` again.
        started.recorder.clock.advance()
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaignRetry: (control: String, values: [Double]) = presenter.retryAction(date: DateComponents())
        #expect(campaignRetry.control == "level.select")
        #expect(campaignRetry.values == [1])
    }

    // MARK: Refusals outside a replay (FR-R02G0307-004)

    /// Without a verified result `replay.start` is refused with "There is no saved solution to replay for this
    /// level." and changes nothing; `replay.step` and `replay.stop` outside a replay are refused too.
    @Test func replayWithoutAVerifiedResultIsRefused() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: WaveKnotKeeperPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let opening: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.progress.solved[1] == nil)
        #expect(presenter.mirror.replayAvailable == false)
        let digest: String = try WaveKnotKeeperTest.digest(shell)
        let noReplayText: String = "There is no saved solution to replay for this level."

        recorder.clock.advance()
        let unsolved: ActionResult = presenter.startReplay(port: shell.port)
        #expect(unsolved == .rejected(.rule(code: Rule.noReplay)), "\(unsolved.code)")
        #expect(Plan.refused(code: unsolved.code).text == noReplayText)
        #expect(presenter.mirror.message == noReplayText, "\(presenter.mirror.message ?? "nil")")
        #expect(recorder.announcements.announced.last == noReplayText)
        #expect(presenter.feedbackLog.last == Plan.refused(code: unsolved.code))
        #expect(try Access.core(shell) == opening, "a refused replay changes nothing")
        #expect(try WaveKnotKeeperTest.digest(shell) == digest)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable == false)
        #expect(presenter.mirror.mode == .campaign)

        let outside: [String] = ["replay.step", "replay.stop"]
        for control in outside {
            recorder.clock.advance()
            let result: ActionResult = presenter.send(control, [], port: shell.port)
            #expect(result == .rejected(.rule(code: Rule.noReplay)), "\(control): \(result.code)")
            #expect(try Access.core(shell) == opening, "\(control) changed nothing")
            #expect(try WaveKnotKeeperTest.digest(shell) == digest)
        }
    }

    // MARK: Dropped results (FR-R02G0307-003; clarification Q2)

    /// A restored core whose edited result was dropped is announced once by the presenter that describes it, however
    /// many cores it describes after it; the dropped result offers no replay.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let recorder: Access.Recorder = Access.record(shell)
        _ = try Script.win(shell, number: 1, recorder: recorder)
        let won: WaveKnotKeeperExperienceCore = try Access.core(shell)
        try #require(won.progress.solved[1]?.stars == 3)
        let payload: Data = try won.snapshotPayload()
        let honest: WaveKnotKeeperExperienceCore = try WaveKnotKeeperExperienceCore.restore(payload: payload, seed: 0)
        #expect(honest.reconciliationDropped == 0)
        #expect(honest.progress == won.progress)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        let tampered: String = text.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":2")
        try #require(tampered != text, "the payload holds a 3-star result")
        let restored: WaveKnotKeeperExperienceCore = try WaveKnotKeeperExperienceCore.restore(
            payload: Data(tampered.utf8), seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[1] == nil)
        #expect(restored.progress.frontier == won.progress.frontier, "the frontier is kept as saved")

        let expected: String = "1 saved result could not be checked and was removed."
        let presenter: WaveKnotKeeperPresenter = WaveKnotKeeperPresenter(reduceMotion: false, reduceFlashing: false)
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: WaveKnotKeeperAccessClock = WaveKnotKeeperAccessClock()
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

        // A second describe of the same core, and further restored cores, never repeat the announcement.
        let again: WaveKnotKeeperExperienceCore = try WaveKnotKeeperExperienceCore.restore(
            payload: Data(tampered.utf8), seed: 0)
        let followers: [WaveKnotKeeperExperienceCore] = [restored, again, honest, restored]
        for follower in followers {
            clock.advance()
            _ = presenter.describe(follower)
        }
        clock.advance()
        presenter.feedback.flush()
        #expect(Script.count(expected, in: announcements.announced) == 1, "\(announcements.announced)")
        #expect(Script.count(expected, in: presenter.announcements) == 1)

        // A presenter that describes only the honest core announces nothing about dropped results.
        let clean: WaveKnotKeeperPresenter = WaveKnotKeeperPresenter(reduceMotion: false, reduceFlashing: false)
        let cleanAnnouncements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        clean.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(), announcementSink: cleanAnnouncements,
                                            clock: { clock.now }, voiceOverRunning: { true })
        clock.advance()
        _ = clean.describe(honest)
        #expect(cleanAnnouncements.announced.isEmpty, "\(cleanAnnouncements.announced)")
        #expect(clean.mirror.replayAvailable, "the honest result offers a replay")

        // The session's own presenter never saw a dropped result.
        #expect(Script.count(expected, in: recorder.announcements.announced) == 0)
    }
}
#endif
