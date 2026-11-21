// ColorfallCanyonsReplayTests — feature 347 (R02-G05-07) T-R02G0507-005 (FR-R02G0507-003, 004, 007; clarifications).
// On the simulator, through the one app's session host, modelled on Hue Compass's feature-337 replay tests. The
// presenter's route records (a `RecordingHapticSink`, a `RecordingAnnouncementSink`, the accessibility tests' clock
// moved 1 s before every action so nothing is rate-limited, VoiceOver reported running), or is quiet (VoiceOver off).
// Replay: level 1 (seed 0) is won in campaign with its certified actions
// (`ColorfallCanyonsExperienceCore.certifiedActions(1)`) through `presenter.send`, the play fingerprints recorded and
// compared with a fresh core of level 1 applying the same actions; the stored result is verified, its trace is those
// actions and the mirror offers a replay; `startReplay` opens mode `replay(level: 1)` on a fresh play; every
// `stepReplay` is accepted and reproduces the win's fingerprint; the replay ends won; the progress (solved, frontier)
// never changes; `stopReplay` returns to the campaign at level 1. During replay `canyon.carve`, `time.step` and
// `level.next` are refused with `r02-g05.replay` ("Stop the replay first."); one step past the end is refused with
// `r02-g05.replay-end` ("The replay is over."); without a verified result `replay.start` is refused with
// `r02-g05.no-replay` ("There is no saved solution to replay for this level."). Dropped results: a real core's payload
// with its stars edited restores with one result dropped; the session host restores only digest-checked envelopes, so
// the edited payload is restored with `ColorfallCanyonsExperienceCore.restore(payload:seed:)` and handed to a fresh
// presenter's `describe(_:)`, which announces "1 saved result could not be checked and was removed." exactly once.
// Sound (FR-R02G0507-007): `saveSound(on: true)` through the port sets the core's and the mirror's choice without
// changing the digest (the controls stay off screen, so no audio starts); a restore of the snapshot keeps it and a
// fresh presenter applies it at its first describe. Synthetic data, explicit types, plain loops, no sleep, no
// wall-clock assertion; each test short.
#if os(iOS)
import ColorfallCanyonsCore
import Foundation
import Testing
@testable import ColorfallCanyonsExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreUI

/// Helpers of the replay tests.
@MainActor
enum ColorfallCanyonsReplayScript {
    typealias Shell = ExperienceShell<ColorfallCanyonsPresenter>
    typealias Access = ColorfallCanyonsAccess

    /// The control and values that carry `action` through the port.
    static func control(_ action: ColorfallCanyonsAction) -> (control: String, values: [Double]) {
        switch action {
        case .carve(let cell): return ("canyon.carve", [Double(cell)])
        case .valve(let spring): return ("canyon.valve", [Double(spring)])
        case .step(let ticks): return ("time.step", [Double(ticks)])
        }
    }

    /// The certified actions of level `number` up to and including the one that wins a fresh play of it, and the
    /// fingerprints of that fresh core (opened outside any host) before the first action and after each one.
    static func reference(number: Int) throws -> (actions: [ColorfallCanyonsAction], fingerprints: [String]) {
        let certified: [ColorfallCanyonsAction] = ColorfallCanyonsExperienceCore.certifiedActions(number)
        var fresh: ColorfallCanyonsExperienceCore = try ColorfallCanyonsExperienceCore.opening(number: number)
        var actions: [ColorfallCanyonsAction] = []
        var fingerprints: [String] = [fresh.play.fingerprint]
        for action in certified {
            guard fresh.play.stage == .playing else { break }
            let sent: (control: String, values: [Double]) = control(action)
            let result: ActionResult = fresh.apply(ExperienceAction(control: sent.control, values: sent.values,
                                                                    step: 0))
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            actions.append(action)
            fingerprints.append(fresh.play.fingerprint)
        }
        #expect(fresh.play.stage == .won, "the certified actions win level \(number)")
        return (actions, fingerprints)
    }

    /// Wins the current level of `shell` (number `number`, a fresh campaign play) with `actions` through
    /// `presenter.send`, the clock advanced before every action; returns the play fingerprints before the first action
    /// and after each one.
    static func win(_ shell: Shell, number: Int, actions: [ColorfallCanyonsAction],
                    clock: ColorfallCanyonsAccessClock) throws -> [String] {
        var fingerprints: [String] = [try Access.core(shell).play.fingerprint]
        for action in actions {
            clock.advance()
            let sent: (control: String, values: [Double]) = control(action)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            fingerprints.append(try Access.core(shell).play.fingerprint)
        }
        let core: ColorfallCanyonsExperienceCore = try Access.core(shell)
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
}

@MainActor
@Suite(.serialized) struct ColorfallCanyonsReplayTests {
    typealias Access = ColorfallCanyonsAccess
    typealias Script = ColorfallCanyonsReplayScript
    typealias Plan = ColorfallCanyonsFeedbackPlan
    typealias Rule = ColorfallCanyonsExperienceRule

    // MARK: Replay through the port (FR-R02G0507-004)

    /// Level 1 won in campaign with its certified actions, then replayed step by step: every step accepted with the
    /// fingerprint of a fresh play applying the same actions, a won end, the progress unchanged; stop returns to the
    /// campaign at level 1.
    @Test func replayReproducesTheWinStepByStep() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        #expect(try Access.core(shell).levelNumber == 1)
        #expect(try Access.core(shell).mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        let reference: (actions: [ColorfallCanyonsAction], fingerprints: [String]) = try Script.reference(number: 1)
        let actions: [ColorfallCanyonsAction] = reference.actions
        let length: Int = actions.count
        try #require(length > 0)
        let fingerprints: [String] = try Script.win(shell, number: 1, actions: actions, clock: recorder.clock)
        #expect(fingerprints == reference.fingerprints, "the shell's win plays like a fresh core")
        let won: ColorfallCanyonsExperienceCore = try Access.core(shell)
        let stored: ColorfallCanyonsProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == actions, "the trace is the winning actions")
        #expect(stored.bestActions == won.play.spent)
        #expect(won.progress.frontier >= 2, "the campaign win opened level 2")
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)

        // Start: a fresh play of level 1 in replay mode, announced as a level change.
        recorder.clock.advance()
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let opened: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(opened.mode == .replay(level: 1))
        #expect(opened.levelNumber == 1)
        #expect(opened.tutorial == .done, "the tutorial is done during replay")
        #expect(opened.play.records.isEmpty)
        #expect(opened.play.fingerprint == fingerprints[0], "the replay starts where the win started")
        #expect(opened.progress == won.progress)
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayAvailable == false, "no replay is offered during a replay")
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == length)
        #expect(presenter.mirror.mode == .replay(level: 1))
        let startPlan: Plan = Plan.after(old: won, new: opened)
        #expect(startPlan.text != nil, "entering replay is announced")
        #expect(presenter.feedbackLog.last == startPlan)

        // Every step reproduces the fresh play's fingerprint and is announced.
        for k in 1...length {
            let before: ColorfallCanyonsExperienceCore = try Access.core(shell)
            recorder.clock.advance()
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: ColorfallCanyonsExperienceCore = try Access.core(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(core.play.records.count == k)
            #expect(core.play.fingerprint == reference.fingerprints[k], "step \(k): the fresh play's fingerprint")
            let record: ColorfallCanyonsRecord = try #require(core.play.records.last)
            #expect(record.action == actions[k - 1], "step \(k)")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            #expect(core.progress.solved == won.progress.solved)
            #expect(core.progress.frontier == won.progress.frontier)
            #expect(core.play.stage == (k < length ? ColorfallCanyonsStage.playing : .won), "step \(k)")
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == k)
            #expect(presenter.mirror.replayLength == length)
            #expect(presenter.mirror.message == nil)
            let plan: Plan = Plan.after(old: before, new: core)
            #expect(presenter.feedbackLog.last == plan, "step \(k)")
        }
        try ColorfallCanyonsTest.draw(session)
        let finished: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")
        let winSaid: String = recorder.announcements.announced.last ?? "nil"
        #expect(!winSaid.contains("stars"), "a replay win claims no stars: \(winSaid)")

        // Stop: back to the campaign at level 1, the replay offered again, the progress unchanged.
        recorder.clock.advance()
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(campaign.mode == .campaign)
        #expect(campaign.levelNumber == 1)
        #expect(campaign.play.records.isEmpty)
        #expect(campaign.play.stage == .playing)
        #expect(campaign.progress == won.progress)
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.levelNumber == 1)
        #expect(presenter.mirror.message == nil)
    }

    // MARK: Refusals (FR-R02G0507-004)

    /// Without a stored solution `replay.start` is refused; during replay carve, step and next are refused with "Stop
    /// the replay first." and change nothing; a step past the last is refused with "The replay is over.".
    @Test func replayRefusalsAreWorded() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)

        // No stored solution yet.
        let opening: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(opening.progress.solved[1] == nil)
        let openingDigest: String = try ColorfallCanyonsTest.digest(shell)
        let noReplayText: String = "There is no saved solution to replay for this level."
        recorder.clock.advance()
        let unsolved: ActionResult = presenter.startReplay(port: shell.port)
        #expect(unsolved == .rejected(.rule(code: Rule.noReplay)), "\(unsolved.code)")
        #expect(Plan.refused(code: unsolved.code).text == noReplayText)
        #expect(presenter.mirror.message == noReplayText, "\(presenter.mirror.message ?? "nil")")
        #expect(recorder.announcements.announced.last == noReplayText)
        #expect(try Access.core(shell) == opening, "a refused replay changes nothing")
        #expect(try ColorfallCanyonsTest.digest(shell) == openingDigest)
        #expect(presenter.mirror.replaying == false)

        // Win, then replay.
        let reference: (actions: [ColorfallCanyonsAction], fingerprints: [String]) = try Script.reference(number: 1)
        let length: Int = reference.actions.count
        try #require(length > 0)
        _ = try Script.win(shell, number: 1, actions: reference.actions, clock: recorder.clock)
        recorder.clock.advance()
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let opened: ColorfallCanyonsExperienceCore = try Access.core(shell)
        let carveCell: Int = presenter.mirror.carvable.first ?? 0
        let stopText: String = "Stop the replay first."
        let refusedControls: [(control: String, values: [Double])] = [
            ("canyon.carve", [Double(carveCell)]),
            ("time.step", [1]),
            ("level.next", []),
        ]
        for refused in refusedControls {
            let digest: String = try ColorfallCanyonsTest.digest(shell)
            recorder.clock.advance()
            let result: ActionResult = presenter.send(refused.control, refused.values, port: shell.port)
            #expect(result == .rejected(.rule(code: Rule.replay)), "\(refused.control): \(result.code)")
            let plan: Plan = Plan.refused(code: result.code)
            #expect(plan.text == stopText, "\(refused.control): \(plan.text ?? "nil")")
            #expect(presenter.mirror.message == stopText, "\(refused.control): \(presenter.mirror.message ?? "nil")")
            #expect(presenter.feedbackLog.last == plan)
            #expect(recorder.announcements.announced.last == stopText, "\(refused.control)")
            #expect(try Access.core(shell) == opened, "\(refused.control) changed nothing")
            #expect(try ColorfallCanyonsTest.digest(shell) == digest, "\(refused.control)")
            #expect(presenter.mirror.replaying)
            #expect(presenter.mirror.replayPosition == 0)
        }

        // Step to the end, then once more.
        for k in 1...length {
            recorder.clock.advance()
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
        }
        let finished: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(finished.play.stage == .won)
        let endDigest: String = try ColorfallCanyonsTest.digest(shell)
        let overText: String = "The replay is over."
        recorder.clock.advance()
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        #expect(Plan.refused(code: past.code).text == overText)
        #expect(presenter.mirror.message == overText, "\(presenter.mirror.message ?? "nil")")
        #expect(recorder.announcements.announced.last == overText)
        #expect(presenter.feedbackLog.last == Plan.refused(code: past.code))
        #expect(try Access.core(shell) == finished)
        #expect(try ColorfallCanyonsTest.digest(shell) == endDigest)
        #expect(presenter.mirror.replayPosition == length)
    }

    // MARK: Dropped results (FR-R02G0507-003)

    /// A restored core whose edited result was dropped is announced once by the presenter that describes it, however
    /// many cores it describes after it; the dropped result offers no replay.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let reference: (actions: [ColorfallCanyonsAction], fingerprints: [String]) = try Script.reference(number: 1)
        let clock: ColorfallCanyonsAccessClock = ColorfallCanyonsAccessClock()
        _ = try Script.win(shell, number: 1, actions: reference.actions, clock: clock)
        let won: ColorfallCanyonsExperienceCore = try Access.core(shell)
        let stars: Int = try #require(won.progress.solved[1]?.stars)
        let payload: Data = try won.snapshotPayload()
        let honest: ColorfallCanyonsExperienceCore = try ColorfallCanyonsExperienceCore.restore(payload: payload,
                                                                                                seed: 0)
        #expect(honest.reconciliationDropped == 0)
        #expect(honest.progress == won.progress)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        let edited: Int = stars == 1 ? 2 : stars - 1
        let tampered: String = text.replacingOccurrences(of: "\"stars\":\(stars)", with: "\"stars\":\(edited)")
        try #require(tampered != text, "the payload holds the stored stars")
        let restored: ColorfallCanyonsExperienceCore = try ColorfallCanyonsExperienceCore.restore(
            payload: Data(tampered.utf8), seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[1] == nil)
        #expect(restored.progress.frontier == won.progress.frontier, "the frontier is kept as saved")

        let expected: String = "1 saved result could not be checked and was removed."
        let presenter: ColorfallCanyonsPresenter = ColorfallCanyonsPresenter(reduceMotion: false,
                                                                             reduceFlashing: false)
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        presenter.feedback = ExperienceFeedback(hapticSink: haptics, announcementSink: announcements,
                                                clock: { clock.now }, voiceOverRunning: { true })
        clock.advance()
        _ = presenter.describe(restored)
        #expect(announcements.announced == [expected], "\(announcements.announced)")
        #expect(presenter.announcements == [expected])
        #expect(presenter.feedbackLog.last?.text == expected)
        #expect(presenter.feedbackLog.last?.kind == .state)
        #expect(presenter.feedbackLog.last?.haptic == nil)
        #expect(haptics.played.isEmpty)
        #expect(presenter.mirror.replayAvailable == false, "the dropped result offers no replay")

        // Further describes, of the same core and of others, never repeat the announcement.
        let again: ColorfallCanyonsExperienceCore = try ColorfallCanyonsExperienceCore.restore(
            payload: Data(tampered.utf8), seed: 0)
        let followers: [ColorfallCanyonsExperienceCore] = [restored, again, honest, restored]
        for follower in followers {
            clock.advance()
            _ = presenter.describe(follower)
        }
        clock.advance()
        presenter.feedback.flush()
        #expect(Script.count(expected, in: announcements.announced) == 1, "\(announcements.announced)")
        #expect(Script.count(expected, in: presenter.announcements) == 1)

        // A presenter that describes only the honest core announces nothing about dropped results.
        let clean: ColorfallCanyonsPresenter = ColorfallCanyonsPresenter(reduceMotion: false, reduceFlashing: false)
        let cleanAnnouncements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        clean.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(), announcementSink: cleanAnnouncements,
                                            clock: { clock.now }, voiceOverRunning: { true })
        clock.advance()
        _ = clean.describe(honest)
        #expect(cleanAnnouncements.announced.isEmpty, "\(cleanAnnouncements.announced)")
        #expect(clean.mirror.replayAvailable, "the honest result offers a replay")
    }

    // MARK: Sound choice (FR-R02G0507-007)

    /// `saveSound(on: true)` sets the core's and the mirror's choice without changing the digest (the controls are off
    /// screen, so no loop starts); the snapshot restores it and a fresh presenter applies it at its first describe.
    @Test func soundChoiceIsSavedAndApplied() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: ColorfallCanyonsPresenter = shell.presenter
        try #require(presenter.sound.onScreen == false, "the controls are off screen")
        let before: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(before.soundOn == false, "the sound is off by default")
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try ColorfallCanyonsTest.digest(shell)

        let saved: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(saved == .accepted, "\(saved.code)")
        let on: ColorfallCanyonsExperienceCore = try Access.core(shell)
        #expect(on.soundOn)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        #expect(presenter.sound.playersMade == 0)
        #expect(try ColorfallCanyonsTest.digest(shell) == digest, "the sound choice is not in the digest")
        #expect(on.play.fingerprint == before.play.fingerprint)
        #expect(on.progress == before.progress)

        // The snapshot keeps the choice; a fresh presenter applies it at its first describe.
        let payload: Data = try on.snapshotPayload()
        let restored: ColorfallCanyonsExperienceCore = try ColorfallCanyonsExperienceCore.restore(payload: payload,
                                                                                                  seed: 0)
        #expect(restored.soundOn)
        #expect(restored.play.fingerprint == on.play.fingerprint)
        #expect(restored.progress == on.progress)
        let fresh: ColorfallCanyonsPresenter = ColorfallCanyonsPresenter(reduceMotion: false, reduceFlashing: false)
        fresh.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(),
                                            announcementSink: RecordingAnnouncementSink(),
                                            voiceOverRunning: { false })
        #expect(fresh.mirror.soundOn == false)
        _ = fresh.describe(restored)
        #expect(fresh.mirror.soundOn, "the restored choice is applied")
        #expect(fresh.sound.wanted)
        #expect(fresh.sound.playersMade == 0, "off screen, nothing plays")

        // Off again through the port.
        let cleared: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(cleared == .accepted, "\(cleared.code)")
        #expect(try Access.core(shell).soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
        #expect(try ColorfallCanyonsTest.digest(shell) == digest)
    }
}
#endif
