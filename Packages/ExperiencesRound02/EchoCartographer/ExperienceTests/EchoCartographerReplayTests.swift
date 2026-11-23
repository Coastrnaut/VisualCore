// EchoCartographerReplayTests — feature 407 (R02-G11-07) T-R02G1107-005 (FR-R02G1107-003, 004, 007; SC-R02G1107-003,
// 004; clarifications Q2, Q4, Q5). On the simulator, through the one app's session host, the twin of Backwards Aurora's
// feature-397 replay tests. Replay (Q4): level 1 (seed 0) is won in campaign with its certified actions
// (`EchoCartographerExperienceCore.generated(number: 1).actions`) sent through `presenter.send` (the shell's port); the
// stored result is verified, its trace is those actions and the mirror offers a replay; `startReplay` opens mode
// `replay(level: 1)` on a fresh play ("Replay: action 0 of n"); every `stepReplay` is accepted and reproduces the
// fingerprint of a bare core (no host) applying the trace one action at a time; the replay ends won; the progress never
// changes; one step past the end is refused ("The replay is over."); `stopReplay` returns to the campaign at level 1.
// During replay a play action (`cell.mark`) is refused with `r02-g11.replay` ("Stop the replay first.", routed as a
// rejection with an error haptic) and Retry restarts the replay (`replay.start [level]`). Without a stored solution
// `startReplay` is refused ("There is no saved solution to replay for this level."). Dropped results (Q2): the session
// host restores only digest-checked envelopes, so a payload whose verified level-2 result claims less energy spent than
// its trace spends is restored with `EchoCartographerExperienceCore.restore(payload:seed:)` and handed to the shell's
// presenter's `describe(_:)`, which announces "1 saved result could not be checked and was removed." exactly once (kind
// `state`), however often it describes again. Sound (Q5): `saveSound(on:port:)` sends `settings.sound [1]` and sets the
// core's and the mirror's choice without changing the digest; a fresh presenter describing a core restored with
// `"sound": true` applies the choice at its first describe. The controls are off screen, so no audio starts.
// Synthetic data, explicit types, plain loops, no nested closure literals, no sleep, no wall-clock assertion.
#if os(iOS)
import EchoCartographerCore
import Foundation
import Testing
@testable import EchoCartographerExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the replay tests.
@MainActor
enum EchoCartographerReplayScript {
    typealias Shell = ExperienceShell<EchoCartographerPresenter>
    typealias Core = EchoCartographerExperienceCore
    typealias Progress = EchoCartographerProgress

    /// The certified actions of level `number` (never empty).
    static func solution(_ number: Int) throws -> [EchoCartographerAction] {
        let actions: [EchoCartographerAction] = try EchoCartographerTest.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The play fingerprints of a bare core opening level `number` (no host) before the first of `actions` and after
    /// each one; the last action wins.
    static func reference(number: Int, actions: [EchoCartographerAction]) throws -> [String] {
        var core: Core = try Core.opening(number: number)
        var fingerprints: [String] = [core.play.fingerprint]
        for action in actions {
            let result: ActionResult = core.apply(EchoCartographerTest.experienceAction(action))
            #expect(result == .accepted, "\(action): \(result.code)")
            fingerprints.append(core.play.fingerprint)
        }
        #expect(core.play.stage == .won, "the certified actions win level \(number)")
        return fingerprints
    }

    /// Wins the current level of `shell` with `actions` through `presenter.send` (the path of the controls); returns
    /// the play fingerprints before the first action and after each one.
    static func win(_ shell: Shell, actions: [EchoCartographerAction]) throws -> [String] {
        let first: Core = try EchoCartographerTest.core(shell)
        var fingerprints: [String] = [first.play.fingerprint]
        for action in actions {
            let sent: (control: String, values: [Double]) = EchoCartographerTest.control(action)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            let core: Core = try EchoCartographerTest.core(shell)
            fingerprints.append(core.play.fingerprint)
        }
        let won: Core = try EchoCartographerTest.core(shell)
        #expect(won.play.stage == .won)
        return fingerprints
    }

    /// The witness result of level `number` with `energySpent` energy spent (stars by rule for it against the certified
    /// plan's pulse count), the certified actions as the trace, marked verified.
    static func result(_ number: Int, energySpent: Int) throws -> Progress.Result {
        let certified: EchoCartographerGenerated = try Core.generated(number: number)
        let pulses: Int = certified.plan.pulses.count
        let stars: Int = Progress.stars(energySpent: energySpent, certified: pulses)
        return Progress.Result(energySpent: energySpent, stars: stars, trace: certified.actions, verified: true)
    }

    /// `payload` with its `progress` replaced by frontier `frontier` and the single result `result` of `level`
    /// (sorted keys).
    static func payload(_ payload: Data, frontier: Int, level: Int, result: Progress.Result) throws -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let resultData: Data = try encoder.encode(result)
        let resultAny: Any = try JSONSerialization.jsonObject(with: resultData)
        var entry: [String: Any] = try #require(resultAny as? [String: Any])
        entry["level"] = level
        let solved: [Any] = [entry]
        var progress: [String: Any] = [:]
        progress["frontier"] = frontier
        progress["solved"] = solved
        let decoded: Any = try JSONSerialization.jsonObject(with: payload)
        var object: [String: Any] = try #require(decoded as? [String: Any])
        object["progress"] = progress
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// `payload` with its `sound` set to `on` (sorted keys).
    static func payload(_ payload: Data, sound on: Bool) throws -> Data {
        let decoded: Any = try JSONSerialization.jsonObject(with: payload)
        var object: [String: Any] = try #require(decoded as? [String: Any])
        object["sound"] = on
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// How many times `text` appears in `texts`.
    static func count(_ text: String, in texts: [String]) -> Int {
        var found: Int = 0
        for entry in texts where entry == text { found += 1 }
        return found
    }

    /// The texts of the presenter's feedback log, in order.
    static func logTexts(_ presenter: EchoCartographerPresenter) -> [String] {
        var texts: [String] = []
        for plan in presenter.feedbackLog {
            if let text = plan.text { texts.append(text) }
        }
        return texts
    }
}

@MainActor
@Suite(.serialized) struct EchoCartographerReplayTests {
    typealias Access = EchoCartographerA11y
    typealias Script = EchoCartographerReplayScript
    typealias Core = EchoCartographerExperienceCore
    typealias Plan = EchoCartographerFeedbackPlan
    typealias Rule = EchoCartographerExperienceRule

    // MARK: Replay through the port (clarification Q4, SC-R02G1107-004)

    /// Level 1 won in campaign with its certified actions, then replayed action by action: every step accepted with
    /// the fingerprint of a bare core applying the same trace, a won end, the progress unchanged; a step past the end
    /// is refused in the replay words; stop returns to the campaign at level 1.
    @Test func replayReproducesTheWinActionByAction() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: EchoCartographerPresenter = shell.presenter
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        let actions: [EchoCartographerAction] = try Script.solution(1)
        let reference: [String] = try Script.reference(number: 1, actions: actions)
        let fingerprints: [String] = try Script.win(shell, actions: actions)
        #expect(fingerprints == reference, "the shell's win plays like a bare core")
        let won: Core = try Access.core(shell)
        let stored: EchoCartographerProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == actions, "the trace is the winning actions")
        let length: Int = stored.trace.count
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
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayAvailable == false, "no replay is offered during a replay")
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == length)
        #expect(EchoCartographerControls.replayPositionText(presenter.mirror) == "Replay: action 0 of \(length)")

        // Every step reproduces the bare core's fingerprint.
        for k in 1...length {
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: Core = try Access.core(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(core.play.records.count == k)
            #expect(core.play.fingerprint == reference[k], "step \(k): the bare core's fingerprint")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            let wantStage: EchoCartographerStage = k < length ? .playing : .won
            #expect(core.play.stage == wantStage, "step \(k)")
            #expect(presenter.mirror.replayPosition == k)
            #expect(presenter.mirror.replayLength == length)
            #expect(presenter.mirror.message == nil)
        }
        try EchoCartographerTest.draw(session)
        let finished: Core = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")

        // One step past the end is refused.
        let endDigest: String = try EchoCartographerTest.digest(shell)
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        #expect(presenter.mirror.message == "The replay is over.", "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == past.code)
        let pastDigest: String = try EchoCartographerTest.digest(shell)
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
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)
        #expect(presenter.mirror.message == nil)
    }

    /// During replay a play action is refused with `r02-g11.replay` ("Stop the replay first.", a rejection with an
    /// error haptic) and changes nothing; Retry restarts the replay (`replay.start [1]`).
    @Test func playActionsAreRefusedDuringReplay() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: EchoCartographerPresenter = shell.presenter
        let actions: [EchoCartographerAction] = try Script.solution(1)
        _ = try Script.win(shell, actions: actions)
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let stepped: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(stepped == .accepted, "\(stepped.code)")
        let before: Core = try Access.core(shell)
        #expect(before.mode == .replay(level: 1))

        let recorder: Access.Recorder = Access.record(shell)
        let entry: EchoCartographerCell = try Core.level(number: 1).entry
        let plan: Plan = try Access.refused(shell, recorder, "cell.mark", [Double(entry.x), Double(entry.y)])
        #expect(plan.text == "Stop the replay first.")
        let code: String = try #require(presenter.refusalLog.last)
        #expect(code.contains(Rule.replay))
        #expect(Plan.refusalText(code: Rule.replay) == "Stop the replay first.")
        let after: Core = try Access.core(shell)
        #expect(after == before, "a refused mark changes nothing")
        #expect(presenter.mirror.replayPosition == 1)

        var date: DateComponents = DateComponents()
        date.year = 2026
        date.month = 11
        date.day = 23
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: date)
        #expect(retry.control == "replay.start")
        #expect(retry.values == [1])
        let retried: ActionResult = presenter.retry(port: shell.port, date: date)
        #expect(retried == .accepted, "\(retried.code)")
        let restarted: Core = try Access.core(shell)
        #expect(restarted.mode == .replay(level: 1))
        #expect(restarted.play.records.isEmpty, "Retry starts the replay again")
        #expect(presenter.mirror.replayPosition == 0)
    }

    /// Without a stored solution the replay cannot start: refused with `r02-g11.no-replay` in words, kept in
    /// `refusalLog`, and nothing changes.
    @Test func replayWithoutASavedSolutionIsRefused() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: EchoCartographerPresenter = shell.presenter
        let opening: Core = try Access.core(shell)
        #expect(opening.progress.solved[opening.levelNumber] == nil)
        #expect(presenter.mirror.replayAvailable == false)
        let digest: String = try EchoCartographerTest.digest(shell)

        let refused: ActionResult = presenter.startReplay(port: shell.port)
        #expect(refused == .rejected(.rule(code: Rule.noReplay)), "\(refused.code)")
        #expect(presenter.mirror.message == "There is no saved solution to replay for this level.",
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == refused.code)
        let after: Core = try Access.core(shell)
        #expect(after == opening, "a refused start changes nothing")
        #expect(after.mode == .campaign)
        let afterDigest: String = try EchoCartographerTest.digest(shell)
        #expect(afterDigest == digest)
        #expect(presenter.mirror.replaying == false)
        #expect(Plan.refusalText(code: Rule.noReplay) == "There is no saved solution to replay for this level.")
    }

    // MARK: Dropped results (clarification Q2, SC-R02G1107-003)

    /// A restored core whose edited verified result was dropped is announced once by the presenter that describes it,
    /// however often it describes again.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: EchoCartographerPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)

        // Level 2's witness recorded as verified, once honestly and once claiming less energy than its trace spends.
        let pulses: Int = try Core.generated(number: 2).plan.pulses.count
        #expect(pulses >= 1)
        let honestResult: EchoCartographerProgress.Result = try Script.result(2, energySpent: pulses)
        let editedResult: EchoCartographerProgress.Result = try Script.result(2, energySpent: pulses - 1)
        let payload: Data = try opening.snapshotPayload()
        let honestPayload: Data = try Script.payload(payload, frontier: 3, level: 2, result: honestResult)
        let honest: Core = try Core.restore(payload: honestPayload, seed: 0)
        #expect(honest.reconciliationDropped == 0)
        #expect(honest.progress.solved[2] != nil, "the honest result is kept")
        let tampered: Data = try Script.payload(payload, frontier: 3, level: 2, result: editedResult)
        let restored: Core = try Core.restore(payload: tampered, seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[2] == nil, "the edited result is dropped")
        #expect(restored.progress.frontier == 3, "the frontier is restored as saved")
        #expect(restored.levelNumber == 1)

        let expected: String = "1 saved result could not be checked and was removed."
        #expect(EchoCartographerPresenter.droppedText(1) == expected)
        #expect(EchoCartographerPresenter.droppedText(2)
                == "2 saved results could not be checked and were removed.")
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

        // Describing again (the same core and the honest one) never repeats the announcement.
        let followers: [Core] = [restored, honest, restored]
        for follower in followers {
            recorder.clock.advance()
            _ = presenter.describe(follower)
        }
        let loggedAfter: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(loggedAfter == 1, "\(Script.logTexts(presenter))")
        let saidAfter: Int = Script.count(expected, in: recorder.announcements.announced)
        #expect(saidAfter == 1, "\(recorder.announcements.announced)")
    }

    // MARK: Sound choice (clarification Q5, FR-R02G1107-007)

    /// `saveSound(on:port:)` sets the core's and the mirror's choice without changing the digest; a fresh presenter
    /// describing a core restored with `"sound": true` applies the choice at its first describe (off screen, nothing
    /// plays).
    @Test func soundChoiceIsSavedAndAppliedOnOpen() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: EchoCartographerPresenter = shell.presenter
        presenter.controlsDisappeared()
        let before: Core = try Access.core(shell)
        #expect(before.soundOn == false, "the sound is off by default")
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try EchoCartographerTest.digest(shell)

        let saved: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(saved == .accepted, "\(saved.code)")
        let on: Core = try Access.core(shell)
        #expect(on.soundOn)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        let onDigest: String = try EchoCartographerTest.digest(shell)
        #expect(onDigest == digest, "the sound choice is not in the digest")
        #expect(on.play.fingerprint == before.play.fingerprint)
        #expect(on.progress == before.progress)
        let onPayload: Data = try on.snapshotPayload()
        let reopened: Core = try Core.restore(payload: onPayload, seed: 0)
        #expect(reopened.soundOn, "the saved choice is in the snapshot")

        // A fresh presenter applies a restored `"sound": true` at its first describe.
        let offPayload: Data = try before.snapshotPayload()
        let edited: Data = try Script.payload(offPayload, sound: true)
        let restored: Core = try Core.restore(payload: edited, seed: 0)
        #expect(restored.soundOn)
        let fresh: EchoCartographerPresenter = EchoCartographerPresenter(reduceMotion: false, reduceFlashing: false)
        fresh.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(),
                                            announcementSink: RecordingAnnouncementSink(),
                                            voiceOverRunning: { false })
        fresh.controlsDisappeared()
        #expect(fresh.mirror.soundOn == false)
        #expect(fresh.sound.wanted == false)
        _ = fresh.describe(restored)
        #expect(fresh.mirror.soundOn, "the restored choice is applied")
        #expect(fresh.sound.wanted)
        #expect(fresh.sound.shouldPlay == false, "off screen, nothing plays")
        #expect(fresh.sound.playersMade == 0)

        let cleared: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(cleared == .accepted, "\(cleared.code)")
        let off: Core = try Access.core(shell)
        #expect(off.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
    }
}
#endif
