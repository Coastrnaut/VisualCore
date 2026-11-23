// BackwardsAuroraReplayTests — feature 397 (R02-G10-07) T-R02G1007-005 (FR-R02G1007-003, 004, 007; SC-R02G1007-003,
// 004; clarifications Q2, Q4, Q5). On the simulator, through the one app's session host, the twin of Nocturne Garden's
// feature-387 replay tests. Replay (Q4): level 1 (seed 0) is won in campaign with its certified solution
// (`BackwardsAuroraExperienceCore.generated(number: 1).solution.actions`) sent through `presenter.send` (the shell's
// port); the stored result is verified, its trace is the solution and the mirror offers a replay; `startReplay` opens
// mode `replay(level: 1)` on a fresh play ("Replay: reversal 0 of n"); every `stepReplay` is accepted and reproduces
// the fingerprint of a fresh play of level 1 applying the solution one reversal at a time; the replay ends won; the
// progress never changes; a reversal, an undo and a level choice during replay are refused with `r02-g10.replay` ("Stop
// the replay first.", shown and kept in `refusalLog`) and change nothing; one step past the end is refused ("The replay
// is over."); `stopReplay` returns to the campaign at level 1. Without a stored solution `startReplay` is refused
// ("There is no saved solution to replay for this level."). Dropped results (Q2): a payload whose verified level-2
// result claims fewer reversals made than its trace holds restores with one result dropped; the session host restores
// only digest-checked envelopes, so the edited payload is restored with
// `BackwardsAuroraExperienceCore.restore(payload:seed:)` and handed to the shell's presenter's `describe(_:)`, which
// announces "1 saved result could not be checked and was removed." exactly once (kind `state`), however often it
// describes again. Sound (Q5): a fresh presenter describing a core restored from a payload with `"sound": true` applies
// the choice at its first describe (and leaves it off for `"sound": false`); `saveSound(on:port:)` sends
// `settings.sound [1/0]` and sets the core's and the mirror's choice without changing the digest (the controls are off
// screen, so no audio starts). Synthetic data, explicit types, plain loops, no sleep, no wall-clock assertion; each
// test short.
#if os(iOS)
import BackwardsAuroraCore
import Foundation
import Testing
@testable import BackwardsAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the replay tests.
@MainActor
enum BackwardsAuroraReplayScript {
    typealias Shell = ExperienceShell<BackwardsAuroraPresenter>
    typealias Core = BackwardsAuroraExperienceCore
    typealias Action = BackwardsAuroraAction

    /// The certified solution reversals of level `number` (never empty).
    static func solution(_ number: Int) throws -> [Action] {
        let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
        let actions: [Action] = generated.solution.actions
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The fingerprints of a fresh play of level `number` (outside any host) before the first of `actions` and after
    /// each one; the last action wins.
    static func reference(number: Int, actions: [Action]) throws -> [String] {
        let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
        var play: BackwardsAuroraPlay = try Core.freshPlay(of: generated.level)
        var fingerprints: [String] = [play.fingerprint]
        for action in actions {
            try play.apply(action, expecting: play.fingerprint)
            fingerprints.append(play.fingerprint)
        }
        #expect(play.stage == .won, "the solution wins level \(number)")
        return fingerprints
    }

    /// Wins the current level of `shell` with `actions` through `presenter.send` (the path of the controls); returns
    /// the play fingerprints before the first action and after each one.
    static func win(_ shell: Shell, actions: [Action]) throws -> [String] {
        let first: Core = try BackwardsAuroraTest.core(shell)
        var fingerprints: [String] = [first.play.fingerprint]
        for action in actions {
            let sent: (control: String, values: [Double]) = BackwardsAuroraTest.control(action)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            let core: Core = try BackwardsAuroraTest.core(shell)
            fingerprints.append(core.play.fingerprint)
        }
        let won: Core = try BackwardsAuroraTest.core(shell)
        #expect(won.play.stage == .won)
        return fingerprints
    }

    /// `payload` with its `progress` replaced by `progress` (sorted keys).
    static func payload(_ payload: Data, progress: BackwardsAuroraProgress) throws -> Data {
        let decoded: Any = try JSONSerialization.jsonObject(with: payload)
        var object: [String: Any] = try #require(decoded as? [String: Any])
        let encoded: Data = try progress.encoded()
        let progressObject: Any = try JSONSerialization.jsonObject(with: encoded)
        object["progress"] = progressObject
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// `payload` with its `sound` set to `on` (sorted keys).
    static func payload(_ payload: Data, sound on: Bool) throws -> Data {
        let decoded: Any = try JSONSerialization.jsonObject(with: payload)
        var object: [String: Any] = try #require(decoded as? [String: Any])
        object["sound"] = on
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// Progress with the levels up to 7 open and one verified level-2 result with the real `trace` and
    /// `reversalsMade` reversals made (the shape of the core test `editedResultsAreDroppedOnRestore`).
    static func progress(trace: [Action], reversalsMade: Int) throws -> BackwardsAuroraProgress {
        let smallest: Int = try Core.generated(number: 2).solution.smallest
        var progress: BackwardsAuroraProgress = BackwardsAuroraProgress()
        progress.open(through: 7)
        progress.record(level: 2, reversalsMade: reversalsMade, smallest: smallest, trace: trace)
        return progress
    }

    /// How many times `text` appears in `texts`.
    static func count(_ text: String, in texts: [String]) -> Int {
        var found: Int = 0
        for entry in texts where entry == text { found += 1 }
        return found
    }

    /// The texts of the presenter's feedback log, in order.
    static func logTexts(_ presenter: BackwardsAuroraPresenter) -> [String] {
        var texts: [String] = []
        for plan in presenter.feedbackLog {
            if let text = plan.text { texts.append(text) }
        }
        return texts
    }

    /// The latest core the presenter described.
    static func latest(_ presenter: BackwardsAuroraPresenter) throws -> Core {
        try #require(presenter.latestCore)
    }
}

@MainActor
@Suite(.serialized) struct BackwardsAuroraReplayTests {
    typealias Access = BackwardsAuroraA11y
    typealias Script = BackwardsAuroraReplayScript
    typealias Core = BackwardsAuroraExperienceCore
    typealias Action = BackwardsAuroraAction
    typealias Rule = BackwardsAuroraExperienceRule

    // MARK: Replay through the port (clarification Q4, SC-R02G1007-004)

    /// Level 1 won in campaign with its certified solution, then replayed reversal by reversal: every step accepted
    /// with the fingerprint of a fresh play applying the same reversals, a won end, the progress unchanged; other
    /// actions during replay and a step past the end are refused in the replay words; stop returns to the campaign at
    /// level 1.
    @Test func replayReproducesTheWinReversalByReversal() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: BackwardsAuroraPresenter = shell.presenter
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        let actions: [Action] = try Script.solution(1)
        let length: Int = actions.count
        let reference: [String] = try Script.reference(number: 1, actions: actions)
        let fingerprints: [String] = try Script.win(shell, actions: actions)
        #expect(fingerprints == reference, "the shell's win plays like a fresh play")
        let won: Core = try Access.core(shell)
        let stored: BackwardsAuroraProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == actions, "the trace is the winning reversals")
        #expect(stored.reversalsMade == length)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)

        // Start: a fresh play of level 1 in replay mode.
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let opened: Core = try Access.core(shell)
        #expect(opened.mode == .replay(level: 1))
        #expect(opened.levelNumber == 1)
        #expect(opened.play.records.isEmpty)
        #expect(opened.play.fingerprint == reference[0], "the replay starts where the win started")
        #expect(opened.progress == won.progress)
        #expect(presenter.mirror.mode == .replay(level: 1))
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayAvailable == false, "no replay is offered during a replay")
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == length)
        #expect(BackwardsAuroraControls.replayPositionText(presenter.mirror) == "Replay: reversal 0 of \(length)")

        // A reversal, an undo and a level choice during replay are refused and change nothing.
        let digest: String = try BackwardsAuroraTest.digest(shell)
        let reversal: (control: String, values: [Double]) = BackwardsAuroraTest.control(actions[0])
        let others: [(control: String, values: [Double])] = [reversal, ("play.undo", []), ("level.select", [1])]
        for other in others {
            let logged: Int = presenter.refusalLog.count
            let refused: ActionResult = presenter.send(other.control, other.values, port: shell.port)
            #expect(refused == .rejected(.rule(code: Rule.replay)), "\(other.control): \(refused.code)")
            #expect(presenter.mirror.message == "Stop the replay first.", "\(presenter.mirror.message ?? "nil")")
            #expect(presenter.refusalLog.count == min(logged + 1, BackwardsAuroraPresenter.refusalLogLimit))
            #expect(presenter.refusalLog.last == refused.code)
            let refusedCore: Core = try Access.core(shell)
            #expect(refusedCore == opened, "a refused \(other.control) changes nothing")
            let refusedDigest: String = try BackwardsAuroraTest.digest(shell)
            #expect(refusedDigest == digest)
            #expect(presenter.mirror.replayPosition == 0)
        }
        #expect(BackwardsAuroraFeedbackPlan.refusalText(code: Rule.replay) == "Stop the replay first.")

        // Every step reproduces the fresh play's fingerprint.
        for k in 1...length {
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: Core = try Access.core(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(core.play.records.count == k)
            #expect(core.play.fingerprint == reference[k], "step \(k): the fresh play's fingerprint")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            let latest: Core = try Script.latest(presenter)
            #expect(latest.progress == won.progress, "step \(k): the described progress is unchanged")
            let wantStage: BackwardsAuroraStage = k < length ? .playing : .won
            #expect(core.play.stage == wantStage, "step \(k)")
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == k)
            #expect(presenter.mirror.replayLength == length)
            #expect(BackwardsAuroraControls.replayPositionText(presenter.mirror)
                    == "Replay: reversal \(k) of \(length)")
            #expect(presenter.mirror.message == nil)
        }
        try BackwardsAuroraTest.draw(session)
        let finished: Core = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")

        // One step past the end is refused.
        let endDigest: String = try BackwardsAuroraTest.digest(shell)
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        #expect(presenter.mirror.message == "The replay is over.", "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == past.code)
        let pastCore: Core = try Access.core(shell)
        #expect(pastCore == finished)
        let pastDigest: String = try BackwardsAuroraTest.digest(shell)
        #expect(pastDigest == endDigest)
        #expect(presenter.mirror.replayPosition == length)

        // Stop: back to the campaign at level 1, the replay offered again, the progress unchanged.
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: Core = try Access.core(shell)
        #expect(campaign.mode == .campaign)
        #expect(campaign.levelNumber == 1)
        #expect(campaign.play.records.isEmpty)
        #expect(campaign.progress == won.progress)
        let described: Core = try Script.latest(presenter)
        #expect(described.progress == won.progress)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)
        #expect(presenter.mirror.message == nil)

        // Outside replay, a step is refused in the replay words.
        let outside: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(outside == .rejected(.rule(code: Rule.noReplay)), "\(outside.code)")
        #expect(presenter.mirror.message == "There is no saved solution to replay for this level.",
                "\(presenter.mirror.message ?? "nil")")
    }

    /// Without a stored solution the replay cannot start: refused with `r02-g10.no-replay` in words, kept in
    /// `refusalLog`, and nothing changes.
    @Test func replayWithoutASavedSolutionIsRefused() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: BackwardsAuroraPresenter = shell.presenter
        let opening: Core = try Access.core(shell)
        #expect(opening.progress.solved[opening.levelNumber] == nil)
        #expect(presenter.mirror.replayAvailable == false)
        let digest: String = try BackwardsAuroraTest.digest(shell)

        let refused: ActionResult = presenter.startReplay(port: shell.port)
        #expect(refused == .rejected(.rule(code: Rule.noReplay)), "\(refused.code)")
        #expect(presenter.mirror.message == "There is no saved solution to replay for this level.",
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == refused.code)
        #expect(refused.code.contains(Rule.noReplay))
        let after: Core = try Access.core(shell)
        #expect(after == opening, "a refused start changes nothing")
        #expect(after.mode == .campaign)
        let afterDigest: String = try BackwardsAuroraTest.digest(shell)
        #expect(afterDigest == digest)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable == false)
        #expect(BackwardsAuroraFeedbackPlan.refusalText(code: Rule.noReplay)
                == "There is no saved solution to replay for this level.")
    }

    // MARK: Dropped results (clarification Q2, SC-R02G1007-003)

    /// A restored core whose edited verified result was dropped is announced once by the presenter that describes it,
    /// however often it describes it again.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: BackwardsAuroraPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)

        // Level 2's real trace recorded as verified, once honestly and once with fewer reversals made than it holds.
        let trace: [Action] = try Script.solution(2)
        let honestProgress: BackwardsAuroraProgress = try Script.progress(trace: trace, reversalsMade: trace.count)
        let editedProgress: BackwardsAuroraProgress = try Script.progress(trace: trace,
                                                                           reversalsMade: trace.count - 1)
        let edited: BackwardsAuroraProgress.Result = try #require(editedProgress.solved[2])
        #expect(edited.verified)
        #expect(edited.reversalsMade < edited.trace.count)

        let payload: Data = try opening.snapshotPayload()
        let honestPayload: Data = try Script.payload(payload, progress: honestProgress)
        let honest: Core = try Core.restore(payload: honestPayload, seed: 0)
        #expect(honest.reconciliationDropped == 0)
        #expect(honest.progress.solved[2] != nil, "the honest result is kept")
        let tampered: Data = try Script.payload(payload, progress: editedProgress)
        let restored: Core = try Core.restore(payload: tampered, seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[2] == nil, "the edited result is dropped")
        #expect(restored.progress.frontier == editedProgress.frontier, "the frontier is restored as saved")
        #expect(restored.levelNumber == 1)

        let expected: String = "1 saved result could not be checked and was removed."
        #expect(BackwardsAuroraPresenter.droppedText(1) == expected)
        #expect(BackwardsAuroraPresenter.droppedText(2) == "2 saved results could not be checked and were removed.")
        let before: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(before == 0)
        recorder.clock.advance()
        _ = presenter.describe(restored)
        let logged: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(logged == 1, "\(Script.logTexts(presenter))")
        var kinds: [AnnouncementKind?] = []
        for plan in presenter.feedbackLog where plan.text == expected { kinds.append(plan.kind) }
        #expect(kinds == [.state], "announced as state")
        let said: Int = Script.count(expected, in: recorder.announcements.announced)
        #expect(said == 1, "\(recorder.announcements.announced)")
        #expect(presenter.mirror.replayAvailable == false)

        // Describing again (the same core and the honest one) never repeats the announcement.
        let followers: [Core] = [restored, honest, restored]
        for follower in followers {
            recorder.clock.advance()
            _ = presenter.describe(follower)
        }
        recorder.clock.advance()
        presenter.feedback.flush()
        let loggedAfter: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(loggedAfter == 1, "\(Script.logTexts(presenter))")
        let saidAfter: Int = Script.count(expected, in: recorder.announcements.announced)
        #expect(saidAfter == 1, "\(recorder.announcements.announced)")
    }

    // MARK: Sound choice (clarification Q5, FR-R02G1007-007)

    /// A fresh presenter describing a core restored with `"sound": true` applies the choice at its first describe,
    /// and one restored with `"sound": false` leaves it off; `saveSound(on:port:)` sets and clears the core's and the
    /// mirror's choice without changing the digest (the controls are off screen, so nothing plays).
    @Test func soundChoiceIsAppliedOnOpenAndSaved() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: BackwardsAuroraPresenter = shell.presenter
        presenter.controlsDisappeared()
        #expect(presenter.sound.onScreen == false, "the controls are off screen")
        let before: Core = try Access.core(shell)
        #expect(before.soundOn == false, "the sound is off by default")
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try BackwardsAuroraTest.digest(shell)

        // Restored cores: `"sound": true` is applied at a fresh presenter's first describe, `"sound": false` is not.
        let payload: Data = try before.snapshotPayload()
        let choices: [Bool] = [true, false]
        for choice in choices {
            let edited: Data = try Script.payload(payload, sound: choice)
            let restored: Core = try Core.restore(payload: edited, seed: 0)
            #expect(restored.soundOn == choice, "sound \(choice)")
            let fresh: BackwardsAuroraPresenter = BackwardsAuroraPresenter(reduceMotion: false, reduceFlashing: false)
            fresh.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(),
                                                announcementSink: RecordingAnnouncementSink(),
                                                voiceOverRunning: { false })
            fresh.controlsDisappeared()
            #expect(fresh.mirror.soundOn == false)
            #expect(fresh.sound.wanted == false)
            _ = fresh.describe(restored)
            #expect(fresh.mirror.soundOn == choice, "sound \(choice): the restored choice is applied")
            #expect(fresh.sound.wanted == choice, "sound \(choice)")
            #expect(fresh.sound.shouldPlay == false, "off screen, nothing plays")
            #expect(fresh.sound.playersMade == 0)
        }

        // On through the port: `settings.sound [1]`.
        let saved: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(saved == .accepted, "\(saved.code)")
        let on: Core = try Access.core(shell)
        #expect(on.soundOn)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        let onDigest: String = try BackwardsAuroraTest.digest(shell)
        #expect(onDigest == digest, "the sound choice is not in the digest")
        #expect(on.play.fingerprint == before.play.fingerprint)
        #expect(on.progress == before.progress)
        let onPayload: Data = try on.snapshotPayload()
        let reopened: Core = try Core.restore(payload: onPayload, seed: 0)
        #expect(reopened.soundOn, "the saved choice is in the snapshot")

        // Off again through the port: `settings.sound [0]`.
        let cleared: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(cleared == .accepted, "\(cleared.code)")
        let off: Core = try Access.core(shell)
        #expect(off.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
        let offDigest: String = try BackwardsAuroraTest.digest(shell)
        #expect(offDigest == digest)
    }
}
#endif
