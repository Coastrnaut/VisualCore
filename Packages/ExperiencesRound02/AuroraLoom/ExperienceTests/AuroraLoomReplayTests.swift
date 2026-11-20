// AuroraLoomReplayTests — feature 307 (R02-G01-07) T-R02G0107-005 (FR-R02G0107-003, 004; clarification Q4;
// contracts/api.md). On the simulator, through the one app's session host and the presenter's recording feedback route
// (a `RecordingHapticSink`, a `RecordingAnnouncementSink`, the test's clock advanced 1 s before every action so nothing
// is rate-limited, VoiceOver reported running): level 1 is won with its certified solution, after which the mirror
// offers a replay as long as the stored trace; `startReplay` opens it ("Level 1, band 1, Replay."), every `stepReplay`
// plays the next stored move ("Replay move k of n: …", the last "Replay complete in n moves.") and advances the
// mirror's position and the description's "Replay, move k of n."; one more step is refused with
// `r02-g01.replay-end`; `stopReplay` returns to the campaign. While replaying, `level.next`, `ribbon.move` and
// `play.undo` are refused with `r02-g01.replay` ("Stop the replay first."); `startReplay` of an unsolved level is
// refused with `r02-g01.no-replay` ("No replay is stored for that level."). Dropped results: the payload of a core that
// won level 1, with its stars edited from 3 to 2, restores with one dropped result; a presenter describing that core
// announces "1 saved result could not be verified and was removed." exactly once, however many cores it describes
// after it. (The host restores envelopes whose digest must match, so the edited payload is restored with
// `AuroraLoomExperienceCore.restore(payload:seed:)` and handed to a presenter's `describe(_:)`.)
// Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import CoreGraphics
import Foundation
import Testing
import UIKit
import AuroraLoomCore
@testable import AuroraLoomExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the replay tests.
@MainActor
enum AuroraLoomReplayScript {
    typealias Shell = ExperienceShell<AuroraLoomPresenter>

    /// Wins the current level 1 of `shell` with its certified solution through `presenter.send`, the clock advanced
    /// before every move; returns the number of moves sent.
    static func winLevelOne(_ shell: Shell, recorder: AuroraLoomAccess.Recorder) throws -> Int {
        let certified: AuroraLoomGenerated = try AuroraLoomExperienceCore.generated(number: 1)
        var sent: Int = 0
        for move in certified.solution.moves {
            recorder.clock.advance()
            let control: Double = move.control == .wave ? 0 : 1
            let result: ActionResult = shell.presenter.send("ribbon.move",
                                                            [Double(move.ribbon), control, Double(move.step)],
                                                            port: shell.port)
            #expect(result == .accepted, "\(result.code)")
            sent += 1
        }
        let core: AuroraLoomExperienceCore = try AuroraLoomAccess.core(shell)
        #expect(core.levelNumber == 1)
        #expect(core.play.stage == .won)
        return sent
    }

    /// How many times `text` was announced in `announced`.
    static func count(_ text: String, in announced: [String]) -> Int {
        var found: Int = 0
        for entry in announced where entry == text { found += 1 }
        return found
    }

    /// How many of `announced` start with `prefix`.
    static func countPrefixed(_ prefix: String, in announced: [String]) -> Int {
        var found: Int = 0
        for entry in announced where entry.hasPrefix(prefix) { found += 1 }
        return found
    }
}

@MainActor
@Suite(.serialized) struct AuroraLoomReplayTests {
    typealias Access = AuroraLoomAccess
    typealias Script = AuroraLoomReplayScript

    // MARK: Replay through the port and the presenter (FR-R02G0107-003)

    /// Level 1 won with its certified solution, then replayed move by move through the presenter: the mirror, the
    /// description and the recorded announcements follow every step; a step past the end is refused; stop returns to
    /// the campaign.
    @Test func replayThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let recorder: AuroraLoomAccess.Recorder = Access.record(shell)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replayLength == 0)

        let certified: AuroraLoomGenerated = try AuroraLoomExperienceCore.generated(number: 1)
        let length: Int = certified.solution.moves.count
        try #require(length > 0)
        let sent: Int = try Script.winLevelOne(shell, recorder: recorder)
        #expect(sent == length)
        try AuroraLoomTest.draw(session)
        let won: AuroraLoomExperienceCore = try Access.core(shell)
        let stored: AuroraLoomProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace.count == length)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayLength == length)
        #expect(presenter.mirror.replayPosition == 0)

        // Start: a fresh play of level 1 in replay mode, announced as a level change.
        recorder.clock.advance()
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let opened: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(opened.mode == .replay(level: 1))
        #expect(opened.play.spent == 0)
        #expect(opened.play.stage == .playing)
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayAvailable == false, "no replay is offered while one runs")
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == length)
        #expect(recorder.announcements.announced.last == "Level 1, band 1, Replay.",
                "\(recorder.announcements.announced.last ?? "nil")")
        #expect(shell.accessibilitySummary.contains("Replay, move 0 of \(length)."))

        // Every step plays the next stored move.
        for k in 1...length {
            recorder.clock.advance()
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: AuroraLoomExperienceCore = try Access.core(shell)
            #expect(core.play.spent == k)
            #expect(core.play.records.last?.ribbon == stored.trace[k - 1].ribbon)
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == k)
            #expect(presenter.mirror.replayLength == length)
            let said: String = recorder.announcements.announced.last ?? "nil"
            if k < length {
                #expect(core.play.stage == .playing)
                #expect(said.hasPrefix("Replay move \(k) of \(length): Ribbon "), "\(said)")
            } else {
                #expect(core.play.stage == .won, "the last stored move wins")
                #expect(said == "Replay complete in \(length) moves.", "\(said)")
                #expect(presenter.feedbackLog.last?.haptic == .success)
            }
            #expect(shell.accessibilitySummary.contains("Replay, move \(k) of \(length)."))
        }
        try AuroraLoomTest.draw(session)
        let finished: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(finished.progress == won.progress, "replay never records")

        // One step past the end is refused and announced.
        recorder.clock.advance()
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(!past.isAccepted)
        #expect(past.code.contains(AuroraLoomExperienceRule.replayEnd), "\(past.code)")
        #expect(recorder.announcements.announced.last == "The replay is over.")
        #expect(presenter.feedbackLog.last?.kind == .rejection)
        #expect(try Access.core(shell).play.spent == length)

        // Stop: back to the campaign at level 1, the replay offered again.
        recorder.clock.advance()
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(campaign.mode == .campaign)
        #expect(campaign.levelNumber == 1)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replayPosition == 0)
        let stopSaid: String = recorder.announcements.announced.last ?? "nil"
        #expect(stopSaid.hasPrefix("Level 1, band 1, Campaign."), "\(stopSaid)")

        let announced: [String] = recorder.announcements.announced
        #expect(Script.count("Level 1, band 1, Replay.", in: announced) == 1)
        #expect(Script.countPrefixed("Replay move 1 of \(length): ", in: announced) == (length > 1 ? 1 : 0))
        #expect(Script.countPrefixed("Replay move ", in: announced) == length - 1)
        #expect(Script.count("Replay complete in \(length) moves.", in: announced) == 1)
        #expect(announced == Access.texts(presenter.feedbackLog), "the sink and the log agree")
    }

    // MARK: Refusals (FR-R02G0107-003, 004)

    /// While replaying, other actions are refused with `r02-g01.replay` and announced "Stop the replay first."; a
    /// replay of a level without a stored result is refused with `r02-g01.no-replay`.
    @Test func refusalsAroundTheReplay() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: AuroraLoomPresenter = shell.presenter
        let recorder: AuroraLoomAccess.Recorder = Access.record(shell)

        // Level 1 is not solved yet: no replay, no step outside a replay.
        recorder.clock.advance()
        let unsolved: ActionResult = presenter.startReplay(port: shell.port)
        #expect(!unsolved.isAccepted)
        #expect(unsolved.code.contains(AuroraLoomExperienceRule.noReplay), "\(unsolved.code)")
        #expect(recorder.announcements.announced.last == "No replay is stored for that level.")
        recorder.clock.advance()
        let outside: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(!outside.isAccepted)
        #expect(outside.code.contains(AuroraLoomExperienceRule.noReplay), "\(outside.code)")
        #expect(recorder.announcements.announced.last == "No replay is stored for that level.")
        #expect(try Access.core(shell).mode == .campaign)

        _ = try Script.winLevelOne(shell, recorder: recorder)
        recorder.clock.advance()
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let replaying: AuroraLoomExperienceCore = try Access.core(shell)
        #expect(replaying.mode == .replay(level: 1))

        // Other actions are refused during the replay and change nothing.
        let refusedControls: [(control: String, values: [Double])] = [
            ("level.next", []),
            ("ribbon.move", [0, 0, 1]),
            ("play.undo", []),
        ]
        for refused in refusedControls {
            recorder.clock.advance()
            let result: ActionResult = presenter.send(refused.control, refused.values, port: shell.port)
            #expect(!result.isAccepted, "\(refused.control)")
            #expect(result.code.contains(AuroraLoomExperienceRule.replay), "\(refused.control): \(result.code)")
            #expect(!result.code.contains(AuroraLoomExperienceRule.replayEnd), "\(refused.control): \(result.code)")
            #expect(recorder.announcements.announced.last == "Stop the replay first.", "\(refused.control)")
            #expect(presenter.feedbackLog.last?.kind == .rejection)
            #expect(presenter.feedbackLog.last?.haptic == .error)
            #expect(try Access.core(shell) == replaying, "\(refused.control) changed nothing")
            #expect(presenter.mirror.replaying)
        }
        #expect(Script.count("Stop the replay first.", in: recorder.announcements.announced) == refusedControls.count)

        // After stopping, level 2 (open, unsolved) has no replay.
        recorder.clock.advance()
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        recorder.clock.advance()
        let second: ActionResult = presenter.send("level.select", [2], port: shell.port)
        #expect(second == .accepted, "\(second.code)")
        #expect(presenter.mirror.levelNumber == 2)
        #expect(presenter.mirror.replayAvailable == false)
        recorder.clock.advance()
        let none: ActionResult = presenter.startReplay(port: shell.port)
        #expect(!none.isAccepted)
        #expect(none.code.contains(AuroraLoomExperienceRule.noReplay), "\(none.code)")
        #expect(recorder.announcements.announced.last == "No replay is stored for that level.")
        #expect(try Access.core(shell).mode == .campaign)
        #expect(Script.count("No replay is stored for that level.", in: recorder.announcements.announced) == 3)
    }

    // MARK: Dropped results (FR-R02G0107-004; clarification Q4)

    /// A restored core with one result dropped is announced once by the presenter that describes it, never again for
    /// later cores.
    @Test func droppedResultsAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let recorder: AuroraLoomAccess.Recorder = Access.record(shell)
        _ = try Script.winLevelOne(shell, recorder: recorder)
        let won: AuroraLoomExperienceCore = try Access.core(shell)
        let payload: Data = try won.snapshotPayload()
        let honest: AuroraLoomExperienceCore = try AuroraLoomExperienceCore.restore(payload: payload, seed: 0)
        #expect(honest.reconciliationDropped == 0)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        let tampered: String = text.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":2")
        try #require(tampered != text, "the payload holds a 3-star result")
        let restored: AuroraLoomExperienceCore = try AuroraLoomExperienceCore.restore(payload: Data(tampered.utf8),
                                                                                      seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[1] == nil)

        let expected: String = "1 saved result could not be verified and was removed."
        let plan: AuroraLoomFeedbackPlan = AuroraLoomFeedbackPlan.dropped(count: 1)
        #expect(plan.text == expected)
        #expect(plan.kind == .state)
        #expect(plan.haptic == nil)

        // A presenter that has described nothing yet, with a recording route.
        let presenter: AuroraLoomPresenter = AuroraLoomPresenter(reduceMotion: false, reduceFlashing: false)
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: AuroraLoomTestClock = AuroraLoomTestClock()
        presenter.feedback = ExperienceFeedback(hapticSink: haptics, announcementSink: announcements,
                                                clock: { clock.now }, voiceOverRunning: { true })
        #expect(presenter.droppedAnnounced == false)

        clock.advance()
        _ = presenter.describe(restored)
        #expect(presenter.droppedAnnounced)
        #expect(announcements.announced == [expected], "\(announcements.announced)")
        #expect(presenter.feedbackLog == [Access.entry(plan)])
        #expect(haptics.played.isEmpty)
        #expect(presenter.mirror.replayAvailable == false, "the dropped result offers no replay")

        // Further cores, the same restored one among them, never repeat the announcement.
        let again: AuroraLoomExperienceCore = try AuroraLoomExperienceCore.restore(payload: Data(tampered.utf8), seed: 0)
        let followers: [AuroraLoomExperienceCore] = [restored, again, honest, restored]
        for follower in followers {
            clock.advance()
            _ = presenter.describe(follower)
        }
        clock.advance()
        presenter.feedback.flush()
        #expect(Script.count(expected, in: announcements.announced) == 1, "\(announcements.announced)")
        var logged: Int = 0
        for entry in presenter.feedbackLog where entry.text == expected { logged += 1 }
        #expect(logged == 1)

        // The session's own presenter never saw a dropped result.
        #expect(shell.presenter.droppedAnnounced == false)
        #expect(Script.count(expected, in: recorder.announcements.announced) == 0)
    }
}
#endif
