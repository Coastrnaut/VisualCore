// AcousticConstellatorReplayTests — feature 427 (R02-G13-07) T-R02G1307-005 (FR-R02G1307-003, 004, 007)
// (SC-R02G1307-003, 004; clarifications Q2, Q4, Q5). On the simulator, through the one app's session host, the twin of
// Harmonic Bridges's feature-417 replay tests. Replay (Q4): level 1 (seed 0) is won in campaign with its certified
// actions (`AcousticConstellatorTest.certifiedActions(1)`: the links and nudges of the certified plan, then the listen)
// sent through `presenter.send` (the shell's port); the stored result is verified, its trace is those actions and the
// mirror offers a replay; `startReplay` opens mode `replay(level: 1)` on a fresh play (the panel reads "Replay: action 0
// of n", Step "Action 0 of n", Stop "n actions"); every `stepReplay` is accepted and reproduces the fingerprint of a
// bare core (no host) applying the trace one action at a time, with the panel's position and values following; the
// replay ends won; the progress never changes; one step past the end is refused ("The replay is over."); `stopReplay`
// returns to the campaign at level 1. During replay play actions (`link.add`, `star.nudge`, `constellation.listen`,
// `play.undo`, `level.next`, `mode.practice`) are refused with `r02-g13.replay` ("Stop the replay first.", routed as a
// rejection with an error haptic) while `tutorial.dismiss` and `settings.sound` stay allowed, and Retry restarts the
// replay (`replay.start [1]`). Without a stored solution `startReplay` is refused ("There is no saved solution to replay
// for this level."). Dropped results (Q2): the session host restores only digest-checked envelopes, so a payload whose
// verified results claim fewer actions spent than their traces spend is restored with
// `AcousticConstellatorExperienceCore.restore(payload:seed:)` and handed to a presenter's `describe(_:)`, which
// announces "1 saved result could not be checked and was removed." (or "2 saved results could not be checked and were
// removed.") exactly once (kind `state`), however often it describes again. Sound (Q5): `saveSound(on:port:)` sends
// `settings.sound [1]` and sets the core's and the mirror's choice without changing the digest; a fresh presenter
// describing a core restored with `"sound": true` applies the choice at its first describe (`mirror.soundOn` and
// `sound.wanted`). The controls are off screen, so no audio starts and no player is made.
// Synthetic data, explicit types, plain loops, no nested closure literals, no sleep, no wall-clock assertion; each test
// short.
#if os(iOS)
import AcousticConstellatorCore
import CoreGraphics
import Foundation
import Testing
@testable import AcousticConstellatorExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the Acoustic Constellator replay tests.
@MainActor
enum AcousticConstellatorReplayScript {
    typealias Shell = ExperienceShell<AcousticConstellatorPresenter>
    typealias Core = AcousticConstellatorExperienceCore
    typealias Progress = AcousticConstellatorProgress

    /// The certified actions of level `number` (never empty; the last is the listen).
    static func solution(_ number: Int) throws -> [AcousticConstellatorAction] {
        let actions: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number)")
        #expect(actions.last == .listen, "level \(number)'s witness ends with its listen")
        return actions
    }

    /// The play fingerprints of a bare core opening level `number` (no host) before the first of `actions` and after
    /// each one; the last action wins.
    static func reference(number: Int, actions: [AcousticConstellatorAction]) throws -> [String] {
        var core: Core = try Core.opening(number: number)
        var fingerprints: [String] = [core.play.fingerprint]
        for action in actions {
            let result: ActionResult = core.apply(AcousticConstellatorTest.experienceAction(action))
            #expect(result == .accepted, "\(action): \(result.code)")
            fingerprints.append(core.play.fingerprint)
        }
        #expect(core.play.stage == .won, "the certified actions win level \(number)")
        return fingerprints
    }

    /// Describes the current core of `shell` again (the shell's path after an accepted action; describing the same
    /// state twice routes nothing) so the mirror reads the current state; returns that core.
    @discardableResult
    static func describe(_ shell: Shell) throws -> Core {
        let core: Core = try AcousticConstellatorTest.core(shell)
        _ = shell.presenter.describe(core)
        return core
    }

    /// Wins the current level of `shell` with `actions` through `presenter.send` (the path of the controls); returns
    /// the play fingerprints before the first action and after each one.
    static func win(_ shell: Shell, actions: [AcousticConstellatorAction]) throws -> [String] {
        let first: Core = try AcousticConstellatorTest.core(shell)
        var fingerprints: [String] = [first.play.fingerprint]
        for action in actions {
            let sent: (control: String, values: [Double]) = AcousticConstellatorTest.control(action)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            let core: Core = try describe(shell)
            fingerprints.append(core.play.fingerprint)
        }
        let won: Core = try AcousticConstellatorTest.core(shell)
        #expect(won.play.stage == .won)
        return fingerprints
    }

    /// The verified result of level `number` with the certified actions as its trace and `actionsSpent` actions spent
    /// (`nil`: the trace's length), its stars by rule for those actions against the certified witness's action count.
    static func result(_ number: Int, actionsSpent: Int? = nil) throws -> Progress.Result {
        let trace: [AcousticConstellatorAction] = try AcousticConstellatorTest.certifiedActions(number)
        let certified: Int = try Core.generated(number: number).actions.count
        let spent: Int = actionsSpent ?? trace.count
        let stars: Int = Progress.stars(actionsSpent: spent, certified: certified)
        return Progress.Result(actionsSpent: spent, stars: stars, trace: trace, verified: true)
    }

    /// `payload` with its `progress` replaced by frontier `frontier` and the results `results` (level and result, in
    /// level order; sorted keys).
    static func payload(_ payload: Data, frontier: Int,
                        results: [(level: Int, result: Progress.Result)]) throws -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var solved: [Any] = []
        for entry in results {
            let resultData: Data = try encoder.encode(entry.result)
            let resultAny: Any = try JSONSerialization.jsonObject(with: resultData)
            var object: [String: Any] = try #require(resultAny as? [String: Any])
            object["level"] = entry.level
            solved.append(object)
        }
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

    /// A presenter outside any shell with a throwaway feedback route recording into `announcements` (VoiceOver
    /// running) and the controls off screen (no player is made).
    static func freshPresenter(_ announcements: RecordingAnnouncementSink) -> AcousticConstellatorPresenter {
        let presenter: AcousticConstellatorPresenter = AcousticConstellatorPresenter(reduceMotion: false,
                                                                                     reduceFlashing: false)
        presenter.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(), announcementSink: announcements,
                                                voiceOverRunning: { true })
        presenter.controlsDisappeared()
        return presenter
    }

    /// How many times `text` appears in `texts`.
    static func count(_ text: String, in texts: [String]) -> Int {
        var found: Int = 0
        for entry in texts where entry == text { found += 1 }
        return found
    }

    /// The texts of the presenter's feedback log, in order.
    static func logTexts(_ presenter: AcousticConstellatorPresenter) -> [String] {
        var texts: [String] = []
        for plan in presenter.feedbackLog {
            if let text = plan.text { texts.append(text) }
        }
        return texts
    }

    /// Expects the panel's replay position line and Step and Stop values for position `position` of `length`.
    static func expectPanel(_ mirror: AcousticConstellatorMirror, position: Int, length: Int,
                            sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(mirror.replayPosition == position, sourceLocation: sourceLocation)
        #expect(mirror.replayLength == length, sourceLocation: sourceLocation)
        #expect(AcousticConstellatorControls.replayPositionText(mirror) == "Replay: action \(position) of \(length)",
                sourceLocation: sourceLocation)
        #expect(AcousticConstellatorControls.replayStepValue(mirror) == "Action \(position) of \(length)",
                sourceLocation: sourceLocation)
        let actions: String = length == 1 ? "1 action" : "\(length) actions"
        #expect(AcousticConstellatorControls.replayStopValue(mirror) == actions, sourceLocation: sourceLocation)
    }
}

@MainActor
@Suite(.serialized) struct AcousticConstellatorReplayTests {
    typealias Access = AcousticConstellatorA11y
    typealias Script = AcousticConstellatorReplayScript
    typealias Core = AcousticConstellatorExperienceCore
    typealias Plan = AcousticConstellatorFeedbackPlan
    typealias Rule = AcousticConstellatorExperienceRule

    // MARK: Replay through the port (clarification Q4, SC-R02G1307-004)

    /// Level 1 won in campaign with its certified actions, then replayed action by action: every step accepted with
    /// the fingerprint of a bare core applying the same trace and the panel's position and values following, a won
    /// end, the progress unchanged; a step past the end is refused in the replay words; stop returns to the campaign at
    /// level 1.
    @Test func replayReproducesTheWinActionByAction() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        let actions: [AcousticConstellatorAction] = try Script.solution(1)
        let reference: [String] = try Script.reference(number: 1, actions: actions)
        let fingerprints: [String] = try Script.win(shell, actions: actions)
        #expect(fingerprints == reference, "the shell's win plays like a bare core")
        let won: Core = try Access.core(shell)
        #expect(won.levelNumber == 1, "a campaign win stays on the level won")
        let stored: AcousticConstellatorProgress.Result = try #require(won.progress.solved[1])
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
        let opened: Core = try Script.describe(shell)
        #expect(opened.mode == .replay(level: 1))
        #expect(opened.levelNumber == 1)
        #expect(opened.play.records.isEmpty)
        #expect(opened.tutorial == .done, "the tutorial is done in replay")
        #expect(opened.play.fingerprint == reference[0], "the replay starts where the win started")
        #expect(opened.progress == won.progress)
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayAvailable == false, "no replay is offered during a replay")
        Script.expectPanel(presenter.mirror, position: 0, length: length)
        #expect(AcousticConstellatorControls.modeName(opened.mode) == "replay")

        // Every step reproduces the bare core's fingerprint.
        for k in 1...length {
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: Core = try Script.describe(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(core.play.records.count == k)
            #expect(core.play.fingerprint == reference[k], "step \(k): the bare core's fingerprint")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            if k < length {
                #expect(core.play.stage != .won, "step \(k): not won before the listen")
            } else {
                #expect(core.play.stage == .won, "step \(k): the listen wins")
            }
            Script.expectPanel(presenter.mirror, position: k, length: length)
            #expect(presenter.mirror.message == nil)
        }
        try AcousticConstellatorTest.draw(session)
        let finished: Core = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")

        // One step past the end is refused.
        let endDigest: String = try AcousticConstellatorTest.digest(shell)
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        #expect(presenter.mirror.message == "The replay is over.", "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == past.code)
        let pastDigest: String = try AcousticConstellatorTest.digest(shell)
        #expect(pastDigest == endDigest)
        Script.expectPanel(presenter.mirror, position: length, length: length)
        #expect(Plan.refusalText(code: Rule.replayEnd) == "The replay is over.")

        // Stop: back to the campaign at level 1, the replay offered again, the progress unchanged.
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: Core = try Script.describe(shell)
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

    /// During replay play actions are refused with `r02-g13.replay` ("Stop the replay first.", a rejection with an
    /// error haptic) and change nothing; `tutorial.dismiss` and `settings.sound` stay allowed; Retry restarts the
    /// replay (`replay.start [1]`).
    @Test func playActionsAreRefusedDuringReplay() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        presenter.controlsDisappeared()
        let actions: [AcousticConstellatorAction] = try Script.solution(1)
        _ = try Script.win(shell, actions: actions)
        let won: Core = try Access.core(shell)
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let stepped: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(stepped == .accepted, "\(stepped.code)")
        let before: Core = try Script.describe(shell)
        #expect(before.mode == .replay(level: 1))

        // Every play action is refused in the replay words.
        let recorder: Access.Recorder = Access.record(shell)
        let next: AcousticConstellatorAction = actions.count > 1 ? actions[1] : actions[0]
        let sent: (control: String, values: [Double]) = AcousticConstellatorTest.control(next)
        var refusals: [(control: String, values: [Double])] = [sent]
        refusals.append(("star.nudge", [0, 1]))
        refusals.append(("constellation.listen", []))
        refusals.append(("play.undo", []))
        refusals.append(("level.next", []))
        refusals.append(("mode.practice", []))
        for refusal in refusals {
            let plan: Plan = try Access.refused(shell, recorder, refusal.control, refusal.values)
            #expect(plan.text == "Stop the replay first.", "\(refusal.control)")
            let code: String = try #require(presenter.refusalLog.last)
            #expect(code.contains(Rule.replay), "\(refusal.control): \(code)")
        }
        #expect(Plan.refusalText(code: Rule.replay) == "Stop the replay first.")
        let after: Core = try Access.core(shell)
        #expect(after == before, "a refused action changes nothing")
        #expect(presenter.mirror.replayPosition == 1)

        // The tutorial dismissal and the sound setting stay allowed (neither changes the digest).
        let digest: String = try AcousticConstellatorTest.digest(shell)
        let dismissed: ActionResult = presenter.send("tutorial.dismiss", [], port: shell.port)
        #expect(dismissed == .accepted, "\(dismissed.code)")
        #expect(presenter.mirror.message == nil)
        let soundOn: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(soundOn == .accepted, "\(soundOn.code)")
        let sounding: Core = try Script.describe(shell)
        #expect(sounding.soundOn)
        #expect(sounding.mode == .replay(level: 1))
        #expect(sounding.play.records.count == 1)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        let soundOff: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(soundOff == .accepted, "\(soundOff.code)")
        let quiet: Core = try Script.describe(shell)
        #expect(quiet.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        let allowedDigest: String = try AcousticConstellatorTest.digest(shell)
        #expect(allowedDigest == digest, "the dismissal and the sound choice are not in the digest")
        #expect(presenter.mirror.replayPosition == 1)
        #expect(quiet.progress == won.progress)

        var date: DateComponents = DateComponents()
        date.year = 2026
        date.month = 11
        date.day = 24
        let retry: (control: String, values: [Double]) = presenter.retryAction(date: date)
        #expect(retry.control == "replay.start")
        #expect(retry.values == [1])
        let retried: ActionResult = presenter.retry(port: shell.port, date: date)
        #expect(retried == .accepted, "\(retried.code)")
        let restarted: Core = try Script.describe(shell)
        #expect(restarted.mode == .replay(level: 1))
        #expect(restarted.play.records.isEmpty, "Retry starts the replay again")
        #expect(presenter.mirror.replayPosition == 0)
        #expect(restarted.progress == won.progress)
    }

    /// Without a stored solution the replay cannot start: refused with `r02-g13.no-replay` in words, kept in
    /// `refusalLog`, and nothing changes.
    @Test func replayWithoutASavedSolutionIsRefused() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        let opening: Core = try Access.core(shell)
        #expect(opening.progress.solved[opening.levelNumber] == nil)
        #expect(presenter.mirror.replayAvailable == false)
        let digest: String = try AcousticConstellatorTest.digest(shell)

        let refused: ActionResult = presenter.startReplay(port: shell.port)
        #expect(refused == .rejected(.rule(code: Rule.noReplay)), "\(refused.code)")
        #expect(presenter.mirror.message == "There is no saved solution to replay for this level.",
                "\(presenter.mirror.message ?? "nil")")
        #expect(presenter.refusalLog.last == refused.code)
        let after: Core = try Access.core(shell)
        #expect(after == opening, "a refused start changes nothing")
        #expect(after.mode == .campaign)
        let afterDigest: String = try AcousticConstellatorTest.digest(shell)
        #expect(afterDigest == digest)
        #expect(presenter.mirror.replaying == false)
        #expect(Plan.refusalText(code: Rule.noReplay) == "There is no saved solution to replay for this level.")
    }

    // MARK: Dropped results (clarification Q2, SC-R02G1307-003)

    /// A restored core whose edited verified result was dropped is announced once by the presenter that describes it,
    /// however often it describes again.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)

        // Level 2's certified win recorded as verified, once honestly and once claiming fewer actions than its trace
        // spends.
        let honestResult: AcousticConstellatorProgress.Result = try Script.result(2)
        let spent: Int = honestResult.trace.count
        try #require(spent >= 2, "level 2's trace spends at least two actions")
        let editedResult: AcousticConstellatorProgress.Result = try Script.result(2, actionsSpent: spent - 1)
        let payload: Data = try opening.snapshotPayload()
        let honestPayload: Data = try Script.payload(payload, frontier: 3, results: [(2, honestResult)])
        let honest: Core = try Core.restore(payload: honestPayload, seed: 0)
        #expect(honest.reconciliationDropped == 0)
        #expect(honest.progress.solved[2] != nil, "the honest result is kept")
        let tampered: Data = try Script.payload(payload, frontier: 3, results: [(2, editedResult)])
        let restored: Core = try Core.restore(payload: tampered, seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[2] == nil, "the edited result is dropped")
        #expect(restored.progress.frontier == 3, "the frontier is restored as saved")
        #expect(restored.levelNumber == 1)

        let expected: String = "1 saved result could not be checked and was removed."
        #expect(AcousticConstellatorPresenter.droppedText(1) == expected)
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

    /// Two edited verified results dropped by one restore are announced once, in the plural, by a fresh presenter,
    /// however often it describes again.
    @Test func twoDroppedResultsAnnouncedOnceInThePlural() throws {
        let opening: Core = try Core.opening(number: 1)
        let second: AcousticConstellatorProgress.Result = try Script.result(2)
        let third: AcousticConstellatorProgress.Result = try Script.result(3)
        try #require(second.trace.count >= 2 && third.trace.count >= 2)
        let editedSecond: AcousticConstellatorProgress.Result = try Script.result(2,
                                                                                  actionsSpent: second.trace.count - 1)
        let editedThird: AcousticConstellatorProgress.Result = try Script.result(3, actionsSpent: third.trace.count - 1)
        let payload: Data = try opening.snapshotPayload()
        let tampered: Data = try Script.payload(payload, frontier: 4, results: [(2, editedSecond), (3, editedThird)])
        let restored: Core = try Core.restore(payload: tampered, seed: 0)
        #expect(restored.reconciliationDropped == 2)
        #expect(restored.progress.solved.isEmpty, "both edited results are dropped")
        #expect(restored.progress.frontier == 4, "the frontier is restored as saved")

        let expected: String = "2 saved results could not be checked and were removed."
        #expect(AcousticConstellatorPresenter.droppedText(2) == expected)
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let presenter: AcousticConstellatorPresenter = Script.freshPresenter(announcements)
        for _ in 0..<3 { _ = presenter.describe(restored) }
        let logged: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(logged == 1, "\(Script.logTexts(presenter))")
        let singular: Int = Script.count(AcousticConstellatorPresenter.droppedText(1), in: Script.logTexts(presenter))
        #expect(singular == 0)
        let said: Int = Script.count(expected, in: announcements.announced)
        #expect(said == 1, "\(announcements.announced)")
    }

    // MARK: Sound choice (clarification Q5, FR-R02G1307-007)

    /// `saveSound(on:port:)` sets the core's and the mirror's choice through `settings.sound` without changing the
    /// digest; a fresh presenter describing a core restored with `"sound": true` applies the choice at its first
    /// describe (off screen, nothing plays).
    @Test func soundChoiceIsSavedAndAppliedOnOpen() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: AcousticConstellatorPresenter = shell.presenter
        presenter.controlsDisappeared()
        let before: Core = try Access.core(shell)
        #expect(before.soundOn == false, "the sound is off by default")
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try AcousticConstellatorTest.digest(shell)

        let saved: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(saved == .accepted, "\(saved.code)")
        let on: Core = try Script.describe(shell)
        #expect(on.soundOn)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        let onDigest: String = try AcousticConstellatorTest.digest(shell)
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
        let fresh: AcousticConstellatorPresenter = Script.freshPresenter(RecordingAnnouncementSink())
        #expect(fresh.mirror.soundOn == false)
        #expect(fresh.sound.wanted == false)
        _ = fresh.describe(restored)
        #expect(fresh.mirror.soundOn, "the restored choice is applied")
        #expect(fresh.sound.wanted)
        #expect(fresh.sound.shouldPlay == false, "off screen, nothing plays")
        #expect(fresh.sound.playersMade == 0)

        let cleared: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(cleared == .accepted, "\(cleared.code)")
        let off: Core = try Script.describe(shell)
        #expect(off.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
        let offDigest: String = try AcousticConstellatorTest.digest(shell)
        #expect(offDigest == digest)
    }
}
#endif
