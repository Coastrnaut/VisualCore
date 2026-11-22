// FacetedForgeReplayTests — feature 377 (R02-G08-07) T-R02G0807-005 (clarifications Q2, Q4, Q5). On the simulator,
// through the one app's session host, the twin of Amethyst Escape's feature-367 replay tests. Replay (Q4): level 1
// (seed 0) is won in campaign with its certified solution (`FacetedForgeExperienceCore.generated(number: 1)
// .solution.actions`) sent through `presenter.send`; the stored result is verified, its trace is the solution and the
// mirror offers a replay; `startReplay` opens mode `replay(level: 1)` on a fresh play ("Replay: cut 0 of n"); every
// `stepReplay` is accepted and reproduces the fingerprint of a fresh play of level 1 applying the solution one cut at a
// time; the replay ends won; the progress never changes; a `piece.cut` during replay is refused ("Stop the replay
// first.") and changes nothing; one step past the end is refused ("The replay is over."); `stopReplay` returns to the
// campaign at level 1. Dropped results (Q2): a payload whose verified level-1 result claims fewer cuts made than its
// trace holds restores with one result dropped; the session host restores only digest-checked envelopes, so the edited
// payload is restored with `FacetedForgeExperienceCore.restore(payload:seed:)` and handed to the shell's presenter's
// `describe(_:)`, which announces "1 saved result could not be checked and was removed." exactly once (kind `state`),
// however often it describes again. Sound (Q5): a fresh presenter describing a restored core with the sound on applies
// the choice at its first describe; `saveSound(on:port:)` sends `settings.sound [1/0]` and sets the core's and the
// mirror's choice without changing the digest (the controls are off screen, so no audio starts). Synthetic data,
// explicit types, plain loops, no sleep, no wall-clock assertion; each test short.
#if os(iOS)
import FacetedForgeCore
import Foundation
import Testing
@testable import FacetedForgeExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the replay tests.
@MainActor
enum FacetedForgeReplayScript {
    typealias Shell = ExperienceShell<FacetedForgePresenter>
    typealias Core = FacetedForgeExperienceCore
    typealias Action = FacetedForgeAction

    /// The certified solution cuts of level `number` (never empty).
    static func solution(_ number: Int) throws -> [Action] {
        let generated: FacetedForgeGenerated = try Core.generated(number: number)
        let actions: [Action] = generated.solution.actions
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The fingerprints of a fresh play of level `number` (outside any host) before the first of `actions` and after
    /// each one; the last action wins.
    static func reference(number: Int, actions: [Action]) throws -> [String] {
        let generated: FacetedForgeGenerated = try Core.generated(number: number)
        var play: FacetedForgePlay = try Core.freshPlay(of: generated.level)
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
        let first: Core = try FacetedForgeTest.core(shell)
        var fingerprints: [String] = [first.play.fingerprint]
        for action in actions {
            let sent: (control: String, values: [Double]) = FacetedForgeTest.control(action)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            let core: Core = try FacetedForgeTest.core(shell)
            fingerprints.append(core.play.fingerprint)
        }
        let won: Core = try FacetedForgeTest.core(shell)
        #expect(won.play.stage == .won)
        return fingerprints
    }

    /// `payload` with its `progress` replaced by `progress` (sorted keys).
    static func payload(_ payload: Data, progress: FacetedForgeProgress) throws -> Data {
        let decoded: Any = try JSONSerialization.jsonObject(with: payload)
        var object: [String: Any] = try #require(decoded as? [String: Any])
        let encoded: Data = try progress.encoded()
        let progressObject: Any = try JSONSerialization.jsonObject(with: encoded)
        object["progress"] = progressObject
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// Progress holding one verified level-1 result with the real `trace` and `cutsMade` cuts made.
    static func progress(trace: [Action], cutsMade: Int) throws -> FacetedForgeProgress {
        let smallest: Int = try Core.generated(number: 1).solution.smallest
        var progress: FacetedForgeProgress = FacetedForgeProgress()
        progress.drop(level: 1)
        progress.record(level: 1, cutsMade: cutsMade, smallest: smallest, mode: .campaign, trace: trace)
        return progress
    }

    /// How many times `text` appears in `texts`.
    static func count(_ text: String, in texts: [String]) -> Int {
        var found: Int = 0
        for entry in texts where entry == text { found += 1 }
        return found
    }

    /// The texts of the presenter's feedback log, in order.
    static func logTexts(_ presenter: FacetedForgePresenter) -> [String] {
        var texts: [String] = []
        for plan in presenter.feedbackLog {
            if let text = plan.text { texts.append(text) }
        }
        return texts
    }

    /// The latest core the presenter described.
    static func latest(_ presenter: FacetedForgePresenter) throws -> Core {
        try #require(presenter.latestCore)
    }
}

@MainActor
@Suite(.serialized) struct FacetedForgeReplayTests {
    typealias Access = FacetedForgeA11y
    typealias Script = FacetedForgeReplayScript
    typealias Core = FacetedForgeExperienceCore
    typealias Action = FacetedForgeAction
    typealias Rule = FacetedForgeExperienceRule

    // MARK: Replay through the port (clarification Q4)

    /// Level 1 won in campaign with its certified solution, then replayed cut by cut: every step accepted with the
    /// fingerprint of a fresh play applying the same cuts, a won end, the progress unchanged; a cut during replay and a
    /// step past the end are refused in the replay words; stop returns to the campaign at level 1.
    @Test func replayReproducesTheWinCutByCut() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: FacetedForgePresenter = shell.presenter
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
        let stored: FacetedForgeProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == actions, "the trace is the winning cuts")
        #expect(stored.cutsMade == length)
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
        #expect(FacetedForgeControls.replayPositionText(presenter.mirror) == "Replay: cut 0 of \(length)")
        #expect(FacetedForgeControls.modeName(presenter.mirror.mode) == "replay")

        // A cut during replay is refused and changes nothing.
        let digest: String = try FacetedForgeTest.digest(shell)
        let cut: (control: String, values: [Double]) = FacetedForgeTest.control(actions[0])
        let refused: ActionResult = presenter.send(cut.control, cut.values, port: shell.port)
        #expect(refused == .rejected(.rule(code: Rule.replay)), "\(refused.code)")
        #expect(presenter.mirror.message == "Stop the replay first.", "\(presenter.mirror.message ?? "nil")")
        #expect(FacetedForgeFeedbackPlan.refusalText(code: Rule.replay) == "Stop the replay first.")
        let refusedCore: Core = try Access.core(shell)
        #expect(refusedCore == opened, "a refused cut changes nothing")
        let refusedDigest: String = try FacetedForgeTest.digest(shell)
        #expect(refusedDigest == digest)
        #expect(presenter.mirror.replayPosition == 0)

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
            let wantStage: FacetedForgeStage = k < length ? .playing : .won
            #expect(core.play.stage == wantStage, "step \(k)")
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == k)
            #expect(presenter.mirror.replayLength == length)
            #expect(FacetedForgeControls.replayPositionText(presenter.mirror) == "Replay: cut \(k) of \(length)")
            #expect(presenter.mirror.message == nil)
        }
        try FacetedForgeTest.draw(session)
        let finished: Core = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")

        // One step past the end is refused.
        let endDigest: String = try FacetedForgeTest.digest(shell)
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        #expect(presenter.mirror.message == "The replay is over.", "\(presenter.mirror.message ?? "nil")")
        let pastCore: Core = try Access.core(shell)
        #expect(pastCore == finished)
        let pastDigest: String = try FacetedForgeTest.digest(shell)
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

    // MARK: Dropped results (clarification Q2)

    /// A restored core whose edited verified result was dropped is announced once by the presenter that describes it,
    /// however often it describes it again.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: FacetedForgePresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)

        // Level 1's real trace recorded as verified, once honestly and once with fewer cuts made than it holds.
        let trace: [Action] = try Script.solution(1)
        let honestProgress: FacetedForgeProgress = try Script.progress(trace: trace, cutsMade: trace.count)
        let editedProgress: FacetedForgeProgress = try Script.progress(trace: trace, cutsMade: trace.count - 1)
        let edited: FacetedForgeProgress.Result = try #require(editedProgress.solved[1])
        #expect(edited.verified)
        #expect(edited.cutsMade < edited.trace.count)

        let payload: Data = try opening.snapshotPayload()
        let honestPayload: Data = try Script.payload(payload, progress: honestProgress)
        let honest: Core = try Core.restore(payload: honestPayload, seed: 0)
        #expect(honest.reconciliationDropped == 0)
        #expect(honest.progress.solved[1] != nil, "the honest result is kept")
        let tampered: Data = try Script.payload(payload, progress: editedProgress)
        let restored: Core = try Core.restore(payload: tampered, seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[1] == nil, "the edited result is dropped")
        #expect(restored.levelNumber == 1)

        let expected: String = "1 saved result could not be checked and was removed."
        #expect(FacetedForgePresenter.droppedText(1) == expected)
        #expect(FacetedForgePresenter.droppedText(2) == "2 saved results could not be checked and were removed.")
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

    // MARK: Sound choice (clarification Q5)

    /// A fresh presenter describing a restored core with the sound on applies the choice at its first describe;
    /// `saveSound(on:port:)` sets and clears the core's and the mirror's choice without changing the digest (the
    /// controls are off screen, so nothing plays).
    @Test func soundChoiceIsAppliedOnOpenAndSaved() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: FacetedForgePresenter = shell.presenter
        presenter.controlsDisappeared()
        #expect(presenter.sound.onScreen == false, "the controls are off screen")
        let before: Core = try Access.core(shell)
        #expect(before.soundOn == false, "the sound is off by default")
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try FacetedForgeTest.digest(shell)

        // A restored core with the sound on: a fresh presenter applies the choice at its first describe.
        var chosen: Core = before
        let chose: ActionResult = chosen.apply(ExperienceAction(control: "settings.sound", values: [1], step: 0))
        #expect(chose == .accepted, "\(chose.code)")
        let payload: Data = try chosen.snapshotPayload()
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored.soundOn)
        let fresh: FacetedForgePresenter = FacetedForgePresenter(reduceMotion: false, reduceFlashing: false)
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

        // On through the port.
        let saved: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(saved == .accepted, "\(saved.code)")
        let on: Core = try Access.core(shell)
        #expect(on.soundOn)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        let onDigest: String = try FacetedForgeTest.digest(shell)
        #expect(onDigest == digest, "the sound choice is not in the digest")
        #expect(on.play.fingerprint == before.play.fingerprint)
        #expect(on.progress == before.progress)

        // Off again through the port: `settings.sound [0]`.
        let cleared: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(cleared == .accepted, "\(cleared.code)")
        let off: Core = try Access.core(shell)
        #expect(off.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
        let offDigest: String = try FacetedForgeTest.digest(shell)
        #expect(offDigest == digest)
    }
}
#endif
