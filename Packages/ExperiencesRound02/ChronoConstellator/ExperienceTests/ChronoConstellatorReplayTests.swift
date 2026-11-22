// ChronoConstellatorReplayTests — feature 357 (R02-G06-07) T-R02G0607-005 (FR-R02G0607-003, 004, 007; clarifications).
// On the simulator, through the one app's session host, modelled on Colorfall Canyons' feature-347 replay tests. The
// presenter's route records (`ChronoConstellatorA11y.record`: a `RecordingHapticSink`, a `RecordingAnnouncementSink`,
// a clock moved 1 s before every action so nothing is rate-limited, VoiceOver reported running), or is quiet.
// Replay: level 1 (seed 0) is won in campaign with its certified witness
// (`ChronoConstellatorWitness.actions(for:level:)` of `ChronoConstellatorExperienceCore.generated(number: 1)`: the
// phase changes, then one step of the tick limit) through `presenter.send`; the stored result is verified, its trace is
// the witness and the mirror offers a replay; `startReplay` opens mode `replay(level: 1)` on a fresh play; every
// `stepReplay` is accepted and reproduces the fingerprint of a fresh core of level 1 applying the witness one action at
// a time; the replay ends won; the progress never changes; one step past the end is refused ("The replay is over."); a
// `star.phase` during replay is refused ("Stop the replay first.") and changes nothing; `stopReplay` returns to the
// campaign at level 1. Dropped results: an opening payload given a verified level-2 result whose `bestEdits` is one
// more than its witness spends restores with one result dropped; the session host restores only digest-checked
// envelopes, so the edited payload is restored with `ChronoConstellatorExperienceCore.restore(payload:seed:)` and
// handed to the shell's presenter's `describe(_:)`, which announces "1 saved result could not be checked and was
// removed." exactly once, however often it describes it again. Sound (FR-R02G0607-007): `saveSound(on: true)` through the port
// sets the core's and the mirror's choice without changing the digest (the controls are off screen, so no audio
// starts); a fresh presenter describing a restored core with the sound on applies the choice. Synthetic data, explicit
// types, plain loops, no sleep, no wall-clock assertion; each test short.
#if os(iOS)
import ChronoConstellatorCore
import Foundation
import Testing
@testable import ChronoConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Helpers of the replay tests.
@MainActor
enum ChronoConstellatorReplayScript {
    typealias Shell = ExperienceShell<ChronoConstellatorPresenter>
    typealias Core = ChronoConstellatorExperienceCore
    typealias Action = ChronoConstellatorAction

    /// The control and values that carry `action` through the port.
    static func control(_ action: Action) -> (control: String, values: [Double]) {
        switch action {
        case .phase(let star, let offset): return ("star.phase", [Double(star), Double(offset)])
        case .hold(let star, let start, let length):
            return ("star.hold", [Double(star), Double(start), Double(length)])
        case .release(let star, let start): return ("star.release", [Double(star), Double(start)])
        case .step(let ticks): return ("time.step", [Double(ticks)])
        case .rewind: return ("time.rewind", [])
        }
    }

    /// The certified witness actions of level `number`.
    static func witness(_ number: Int) throws -> [Action] {
        let generated: ChronoConstellatorGenerated = try Core.generated(number: number)
        let actions: [Action] = ChronoConstellatorWitness.actions(for: generated.solution, level: generated.level)
        try #require(!actions.isEmpty, "level \(number)")
        return actions
    }

    /// The fingerprints of a fresh core of level `number` (outside any host) before the first of `actions` and after
    /// each one; the last action wins.
    static func reference(number: Int, actions: [Action]) throws -> [String] {
        var fresh: Core = try Core.opening(number: number)
        var fingerprints: [String] = [fresh.play.fingerprint]
        for action in actions {
            let sent: (control: String, values: [Double]) = control(action)
            let result: ActionResult = fresh.apply(ExperienceAction(control: sent.control, values: sent.values,
                                                                    step: 0))
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            fingerprints.append(fresh.play.fingerprint)
        }
        #expect(fresh.play.stage == .won, "the witness wins level \(number)")
        return fingerprints
    }

    /// Wins the current level of `shell` with `actions` through `presenter.send`, the clock advanced before every
    /// action; returns the play fingerprints before the first action and after each one.
    static func win(_ shell: Shell, actions: [Action], clock: ChronoConstellatorA11yClock) throws -> [String] {
        let first: Core = try ChronoConstellatorTest.core(shell)
        var fingerprints: [String] = [first.play.fingerprint]
        for action in actions {
            clock.advance()
            let sent: (control: String, values: [Double]) = control(action)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            let core: Core = try ChronoConstellatorTest.core(shell)
            fingerprints.append(core.play.fingerprint)
        }
        let won: Core = try ChronoConstellatorTest.core(shell)
        #expect(won.play.stage == .won)
        return fingerprints
    }

    /// The edits in use after `actions` on a fresh play of level `number`.
    static func spent(_ number: Int, _ actions: [Action]) throws -> Int {
        let generated: ChronoConstellatorGenerated = try Core.generated(number: number)
        var play: ChronoConstellatorPlay = try Core.freshPlay(of: generated.level)
        for action in actions { try play.apply(action, expecting: play.fingerprint) }
        return play.spent
    }

    /// `payload` with its `progress` replaced by `progress`.
    static func payload(_ payload: Data, progress: ChronoConstellatorProgress) throws -> Data {
        let decoded: Any = try JSONSerialization.jsonObject(with: payload)
        var object: [String: Any] = try #require(decoded as? [String: Any])
        let encoded: Data = try progress.encoded()
        let progressObject: Any = try JSONSerialization.jsonObject(with: encoded)
        object["progress"] = progressObject
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// How many times `text` appears in `texts`.
    static func count(_ text: String, in texts: [String]) -> Int {
        var found: Int = 0
        for entry in texts where entry == text { found += 1 }
        return found
    }

    /// The texts of the presenter's feedback log, in order.
    static func logTexts(_ presenter: ChronoConstellatorPresenter) -> [String] {
        var texts: [String] = []
        for plan in presenter.feedbackLog {
            if let text = plan.text { texts.append(text) }
        }
        return texts
    }
}

@MainActor
@Suite(.serialized) struct ChronoConstellatorReplayTests {
    typealias Access = ChronoConstellatorA11y
    typealias Script = ChronoConstellatorReplayScript
    typealias Core = ChronoConstellatorExperienceCore
    typealias Action = ChronoConstellatorAction
    typealias Rule = ChronoConstellatorExperienceRule

    // MARK: Replay through the port (FR-R02G0607-004)

    /// Level 1 won in campaign with its witness, then replayed step by step: every step accepted with the fingerprint
    /// of a fresh play applying the same actions, a won end, the progress unchanged; a step past the end and a phase
    /// change are refused; stop returns to the campaign at level 1.
    @Test func replayReproducesTheWinStepByStep() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: ChronoConstellatorPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        let actions: [Action] = try Script.witness(1)
        let length: Int = actions.count
        let reference: [String] = try Script.reference(number: 1, actions: actions)
        let fingerprints: [String] = try Script.win(shell, actions: actions, clock: recorder.clock)
        #expect(fingerprints == reference, "the shell's win plays like a fresh core")
        let won: Core = try Access.core(shell)
        let stored: ChronoConstellatorProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == actions, "the trace is the winning actions")
        #expect(stored.bestEdits == won.play.spent)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)

        // Start: a fresh play of level 1 in replay mode.
        recorder.clock.advance()
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

        // A phase change during replay is refused and changes nothing.
        let digest: String = try ChronoConstellatorTest.digest(shell)
        recorder.clock.advance()
        let phased: ActionResult = presenter.send("star.phase", [0, 1], port: shell.port)
        #expect(phased == .rejected(.rule(code: Rule.replay)), "\(phased.code)")
        #expect(presenter.mirror.message == "Stop the replay first.", "\(presenter.mirror.message ?? "nil")")
        let refusedCore: Core = try Access.core(shell)
        #expect(refusedCore == opened, "a refused phase change changes nothing")
        let refusedDigest: String = try ChronoConstellatorTest.digest(shell)
        #expect(refusedDigest == digest)
        #expect(presenter.mirror.replayPosition == 0)

        // Every step reproduces the fresh play's fingerprint.
        for k in 1...length {
            recorder.clock.advance()
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: Core = try Access.core(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(core.play.records.count == k)
            #expect(core.play.fingerprint == reference[k], "step \(k): the fresh play's fingerprint")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            let wantStage: ChronoConstellatorStage = k < length ? .playing : .won
            #expect(core.play.stage == wantStage, "step \(k)")
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == k)
            #expect(presenter.mirror.replayLength == length)
            #expect(presenter.mirror.message == nil)
        }
        try ChronoConstellatorTest.draw(session)
        let finished: Core = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")

        // One step past the end is refused.
        let endDigest: String = try ChronoConstellatorTest.digest(shell)
        recorder.clock.advance()
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        #expect(presenter.mirror.message == "The replay is over.", "\(presenter.mirror.message ?? "nil")")
        let pastCore: Core = try Access.core(shell)
        #expect(pastCore == finished)
        let pastDigest: String = try ChronoConstellatorTest.digest(shell)
        #expect(pastDigest == endDigest)
        #expect(presenter.mirror.replayPosition == length)

        // Stop: back to the campaign at level 1, the replay offered again, the progress unchanged.
        recorder.clock.advance()
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: Core = try Access.core(shell)
        #expect(campaign.mode == .campaign)
        #expect(campaign.levelNumber == 1)
        #expect(campaign.play.records.isEmpty)
        #expect(campaign.progress == won.progress)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)
        #expect(presenter.mirror.message == nil)
    }

    // MARK: Dropped results (FR-R02G0607-003)

    /// A restored core whose edited verified result was dropped is announced once by the presenter that describes it,
    /// however often it describes it again.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: ChronoConstellatorPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)

        // Level 2's witness recorded as verified with one edit more than it spends.
        let trace: [Action] = try Script.witness(2)
        let spent: Int = try Script.spent(2, trace)
        let smallest: Int = try Core.generated(number: 2).difficulty.smallest
        var progress: ChronoConstellatorProgress = ChronoConstellatorProgress()
        progress.record(level: 2, edits: spent + 1, smallest: smallest, mode: .campaign, trace: trace)
        let edited: ChronoConstellatorProgress.Result = try #require(progress.solved[2])
        #expect(edited.verified)
        #expect(edited.bestEdits == spent + 1)

        let payload: Data = try opening.snapshotPayload()
        let honest: Core = try Core.restore(payload: payload, seed: 0)
        #expect(honest.reconciliationDropped == 0)
        let tampered: Data = try Script.payload(payload, progress: progress)
        let restored: Core = try Core.restore(payload: tampered, seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[2] == nil, "the edited result is dropped")
        #expect(restored.levelNumber == 1)

        let expected: String = "1 saved result could not be checked and was removed."
        let before: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(before == 0)
        recorder.clock.advance()
        _ = presenter.describe(restored)
        let logged: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(logged == 1, "\(Script.logTexts(presenter))")
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

    // MARK: Sound choice (FR-R02G0607-007)

    /// `saveSound(on: true)` sets the core's and the mirror's choice without changing the digest (the controls are off
    /// screen, so nothing plays); a fresh presenter describing a restored core with the sound on applies the choice.
    @Test func soundChoiceIsSavedAndApplied() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: ChronoConstellatorPresenter = shell.presenter
        presenter.controlsDisappeared()
        #expect(presenter.sound.onScreen == false, "the controls are off screen")
        let before: Core = try Access.core(shell)
        #expect(before.soundOn == false, "the sound is off by default")
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try ChronoConstellatorTest.digest(shell)

        let saved: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(saved == .accepted, "\(saved.code)")
        let on: Core = try Access.core(shell)
        #expect(on.soundOn)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        let onDigest: String = try ChronoConstellatorTest.digest(shell)
        #expect(onDigest == digest, "the sound choice is not in the digest")
        #expect(on.play.fingerprint == before.play.fingerprint)
        #expect(on.progress == before.progress)

        // The snapshot keeps the choice; a fresh presenter applies it at its first describe.
        let payload: Data = try on.snapshotPayload()
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored.soundOn)
        let fresh: ChronoConstellatorPresenter = ChronoConstellatorPresenter(reduceMotion: false,
                                                                             reduceFlashing: false)
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

        // Off again through the port.
        let cleared: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(cleared == .accepted, "\(cleared.code)")
        let off: Core = try Access.core(shell)
        #expect(off.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
        let offDigest: String = try ChronoConstellatorTest.digest(shell)
        #expect(offDigest == digest)
    }
}
#endif
