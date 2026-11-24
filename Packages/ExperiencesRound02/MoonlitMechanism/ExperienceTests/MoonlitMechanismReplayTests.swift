// MoonlitMechanismReplayTests — feature 437 (R02-G14-07) T-R02G1407-005 (FR-R02G1407-003, 004, 007)
// (SC-R02G1407-003, 004; clarifications Q2, Q4, Q5). On the simulator, through the one app's session host, the twin of
// Acoustic Constellator's feature-427 replay tests. Replay (Q4): level 1 (seed 0) is won in campaign with its certified
// actions (`MoonlitMechanismTest.certifiedActions(1)`: the turns, re-seats and lamp steps of the certified plan, then
// the run) sent through `presenter.send` (the shell's port); the stored result is verified, its trace is those actions
// and the mirror offers "Replay best solution" (`replayAvailable`); `startReplay` opens mode `replay(level: 1)` on a
// fresh play (the panel reads "Replay: action 0 of n", Step "Action 0 of n", Stop "n actions") and is announced as the
// level plan `after(old:new:)` names; every `stepReplay` is accepted, reproduces the fingerprint of a bare core (no host)
// applying the trace one action at a time, routes exactly `after(old:new:)` of the cores before and after (the action's
// own words, the last one the win without stars) with the panel's position and values following; the replay ends won;
// the progress (and so the stars) never changes; one step past the end is refused ("The replay is over.", shown and
// announced); `stopReplay` returns to the campaign at level 1. During replay play actions (the next trace action,
// `handle.turn`, `lamp.step`, `machine.run`, `play.undo`, `play.redo`, `level.next`, `level.select`, `mode.practice`,
// `mode.campaign`) are refused with `r02-g14.replay` ("Stop the replay first.", routed as a rejection with an error
// haptic) while `tutorial.dismiss` and `settings.sound` stay allowed, and Retry restarts the replay
// (`replay.start [1]`). Without a verified stored solution `startReplay` is refused ("There is no saved solution to
// replay for this level."). Dropped results (Q2): the session host restores only digest-checked envelopes, so a payload
// whose verified result claims fewer actions spent than its trace spends is restored with
// `MoonlitMechanismExperienceCore.restore(payload:seed:)` and handed to a presenter's `describe(_:)`, which announces
// "1 saved result could not be checked and was removed." (or "2 saved results could not be checked and were
// removed.") exactly once (kind `state`), however often it describes again. Sound (Q5): `saveSound(on:port:)` sends
// `settings.sound [1]` and sets the core's and the mirror's choice without changing the digest; the choice survives the
// shell's snapshot and restore (and a restore into a newly opened experience applies it); a fresh presenter describing
// a core restored with `"sound": true` applies the choice at its first describe (`mirror.soundOn` and `sound.wanted`).
// The controls are off screen, so no audio starts and no player is made.
// Synthetic data, explicit types, plain loops, no nested closure literals, no sleep, no wall-clock assertion; each test
// short.
#if os(iOS)
import CoreGraphics
import Foundation
import MoonlitMechanismCore
import Testing
@testable import MoonlitMechanismExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the Moonlit Mechanism replay tests.
@MainActor
enum MoonlitMechanismReplayScript {
    typealias Shell = MoonlitMechanismTest.Shell
    typealias Core = MoonlitMechanismExperienceCore
    typealias Progress = MoonlitMechanismProgress
    typealias Plan = MoonlitMechanismFeedbackPlan

    /// The certified actions of level `number` (never empty; the last is the run).
    static func solution(_ number: Int) throws -> [MoonlitMechanismAction] {
        let actions: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number)")
        #expect(actions.last == .run, "level \(number)'s witness ends with its run")
        return actions
    }

    /// The play fingerprints of a bare core opening level `number` (no host) before the first of `actions` and after
    /// each one; the last action wins.
    static func reference(number: Int, actions: [MoonlitMechanismAction]) throws -> [String] {
        var core: Core = try Core.opening(number: number)
        var fingerprints: [String] = [core.play.fingerprint]
        for action in actions {
            let result: ActionResult = core.apply(MoonlitMechanismTest.experienceAction(action))
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
        let core: Core = try MoonlitMechanismTest.core(shell)
        _ = shell.presenter.describe(core)
        return core
    }

    /// Wins the current level of `shell` with `actions` through `presenter.send` (the path of the controls); returns
    /// the play fingerprints before the first action and after each one.
    static func win(_ shell: Shell, actions: [MoonlitMechanismAction]) throws -> [String] {
        let first: Core = try MoonlitMechanismTest.core(shell)
        var fingerprints: [String] = [first.play.fingerprint]
        for action in actions {
            let sent: (control: String, values: [Double]) = MoonlitMechanismTest.control(action)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            let core: Core = try describe(shell)
            fingerprints.append(core.play.fingerprint)
        }
        let won: Core = try MoonlitMechanismTest.core(shell)
        #expect(won.play.stage == .won)
        return fingerprints
    }

    /// The verified result of level `number` with the certified actions as its trace and `actionsSpent` actions spent
    /// (`nil`: the trace's length), its stars by rule for those actions against the certified witness's action count.
    static func result(_ number: Int, actionsSpent: Int? = nil) throws -> Progress.Result {
        let trace: [MoonlitMechanismAction] = try MoonlitMechanismTest.certifiedActions(number)
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
    static func freshPresenter(_ announcements: RecordingAnnouncementSink) -> MoonlitMechanismPresenter {
        let presenter: MoonlitMechanismPresenter = MoonlitMechanismPresenter(reduceMotion: false,
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
    static func logTexts(_ presenter: MoonlitMechanismPresenter) -> [String] {
        var texts: [String] = []
        for plan in presenter.feedbackLog {
            if let text = plan.text { texts.append(text) }
        }
        return texts
    }

    /// The win announcement of a replayed play that spent `spent` actions: the win without stars.
    static func replayWinText(spent: Int) -> String {
        let words: String = spent == 1 ? "1 action" : "\(spent) actions"
        return Plan.wonText + " Level won spending " + words + "."
    }

    /// Expects the panel's replay position line and Step and Stop values for position `position` of `length`.
    static func expectPanel(_ mirror: MoonlitMechanismMirror, position: Int, length: Int,
                            sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(mirror.replayPosition == position, sourceLocation: sourceLocation)
        #expect(mirror.replayLength == length, sourceLocation: sourceLocation)
        #expect(MoonlitMechanismControls.replayPositionText(mirror) == "Replay: action \(position) of \(length)",
                sourceLocation: sourceLocation)
        #expect(MoonlitMechanismControls.replayStepValue(mirror) == "Action \(position) of \(length)",
                sourceLocation: sourceLocation)
        let actions: String = length == 1 ? "1 action" : "\(length) actions"
        #expect(MoonlitMechanismControls.replayStopValue(mirror) == actions, sourceLocation: sourceLocation)
    }
}

@MainActor
@Suite(.serialized) struct MoonlitMechanismReplayTests {
    typealias Access = MoonlitMechanismA11y
    typealias Script = MoonlitMechanismReplayScript
    typealias Core = MoonlitMechanismExperienceCore
    typealias Plan = MoonlitMechanismFeedbackPlan
    typealias Rule = MoonlitMechanismExperienceRule

    // MARK: Replay through the port (clarification Q4, SC-R02G1407-004)

    /// Level 1 won in campaign with its certified actions, then replayed action by action: every step accepted with
    /// the fingerprint of a bare core applying the same trace, announced as `after(old:new:)` names it and the panel's
    /// position and values following, a won end without stars, the progress unchanged; a step past the end is refused
    /// in the replay words (shown and announced); stop returns to the campaign at level 1.
    @Test func replayReproducesTheWinActionByAction() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        presenter.controlsDisappeared()
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        let actions: [MoonlitMechanismAction] = try Script.solution(1)
        let reference: [String] = try Script.reference(number: 1, actions: actions)
        let fingerprints: [String] = try Script.win(shell, actions: actions)
        #expect(fingerprints == reference, "the shell's win plays like a bare core")
        let won: Core = try Access.core(shell)
        #expect(won.levelNumber == 1, "a campaign win stays on the level won")
        let stored: MoonlitMechanismProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == actions, "the trace is the winning actions")
        let length: Int = stored.trace.count
        let starsBefore: [Int: Int] = presenter.mirror.stars
        #expect(starsBefore[1] == stored.stars)
        #expect(presenter.mirror.replayAvailable, "the panel offers Replay best solution")
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)

        // From here every routed plan is recorded.
        let recorder: Access.Recorder = Access.record(shell)

        // Start: a fresh play of level 1 in replay mode, announced as a level change.
        recorder.clock.advance()
        let logBeforeStart: Int = presenter.feedbackLog.count
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let opened: Core = try Script.describe(shell)
        #expect(opened.mode == .replay(level: 1))
        #expect(opened.levelNumber == 1)
        #expect(opened.play.records.isEmpty)
        #expect(opened.tutorial == .done, "the tutorial is done in replay")
        #expect(opened.play.fingerprint == reference[0], "the replay starts where the win started")
        #expect(opened.progress == won.progress)
        let startPlan: Plan = Plan.after(old: won, new: opened)
        let band: Int = MoonlitMechanismProgress.band(of: 1)
        #expect(startPlan.text == "Level 1, band \(band), replay.", "\(startPlan.text ?? "nil")")
        #expect(presenter.feedbackLog.count == logBeforeStart + 1, "the start routes one plan")
        #expect(presenter.feedbackLog.last == startPlan)
        #expect(recorder.announcements.announced.last == startPlan.text)
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayAvailable == false, "no replay is offered during a replay")
        Script.expectPanel(presenter.mirror, position: 0, length: length)
        #expect(MoonlitMechanismControls.modeName(opened.mode) == "replay")
        #expect(presenter.mirror.mode == .replay(level: 1))

        // Every step reproduces the bare core's fingerprint and is announced like the action it applies.
        var previous: Core = opened
        for k in 1...length {
            recorder.clock.advance()
            let logBefore: Int = presenter.feedbackLog.count
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: Core = try Script.describe(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(core.play.records.count == k)
            #expect(core.play.fingerprint == reference[k], "step \(k): the bare core's fingerprint")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            let plan: Plan = Plan.after(old: previous, new: core)
            #expect(plan.text != nil, "step \(k) is announced")
            #expect(presenter.feedbackLog.count == logBefore + 1, "step \(k) routes one plan")
            #expect(presenter.feedbackLog.last == plan, "step \(k): the plan of the action applied")
            #expect(recorder.announcements.announced.last == plan.text, "step \(k)")
            if k < length {
                #expect(core.play.stage != .won, "step \(k): not won before the run")
                #expect(plan.kind == .state, "step \(k)")
                #expect(plan.haptic == .selection, "step \(k)")
            } else {
                #expect(core.play.stage == .won, "step \(k): the run wins")
                let spent: Int = MoonlitMechanismProgress.actionsSpent(core.play)
                #expect(plan.text == Script.replayWinText(spent: spent), "\(plan.text ?? "nil")")
                #expect(plan.text?.contains("stars") == false, "a replayed win claims no stars")
                #expect(plan.kind == .outcome)
                #expect(plan.haptic == .success)
            }
            Script.expectPanel(presenter.mirror, position: k, length: length)
            #expect(presenter.mirror.message == nil)
            previous = core
        }
        try MoonlitMechanismTest.draw(session)
        let finished: Core = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")
        #expect(presenter.mirror.stars == starsBefore, "the replayed win claims no stars")

        // One step past the end is refused, shown and announced.
        let endDigest: String = try MoonlitMechanismTest.digest(shell)
        recorder.clock.advance()
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        #expect(presenter.mirror.message == "The replay is over.", "\(presenter.mirror.message ?? "nil")")
        #expect(recorder.announcements.announced.last == "The replay is over.")
        #expect(recorder.haptics.played.last == .error)
        #expect(presenter.refusalLog.last == Rule.replayEnd)
        let pastDigest: String = try MoonlitMechanismTest.digest(shell)
        #expect(pastDigest == endDigest)
        Script.expectPanel(presenter.mirror, position: length, length: length)
        #expect(Plan.refusalText(code: Rule.replayEnd) == "The replay is over.")

        // Stop: back to the campaign at level 1, the replay offered again, the progress unchanged.
        recorder.clock.advance()
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: Core = try Script.describe(shell)
        #expect(campaign.mode == .campaign)
        #expect(campaign.levelNumber == 1)
        #expect(campaign.play.records.isEmpty)
        #expect(campaign.progress == won.progress)
        #expect(presenter.feedbackLog.last == Plan.after(old: finished, new: campaign))
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayAvailable)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)
        #expect(presenter.mirror.message == nil)
        #expect(presenter.mirror.mode == .campaign)
        #expect(presenter.mirror.stars == starsBefore)
    }

    /// During replay play actions are refused with `r02-g14.replay` ("Stop the replay first.", a rejection with an
    /// error haptic) and change nothing; `tutorial.dismiss` and `settings.sound` stay allowed; Retry restarts the
    /// replay (`replay.start [1]`).
    @Test func playActionsAreRefusedDuringReplay() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        presenter.controlsDisappeared()
        let actions: [MoonlitMechanismAction] = try Script.solution(1)
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
        let next: MoonlitMechanismAction = actions.count > 1 ? actions[1] : actions[0]
        let sent: (control: String, values: [Double]) = MoonlitMechanismTest.control(next)
        var refusals: [(control: String, values: [Double])] = [sent]
        refusals.append(("handle.turn", [1]))
        refusals.append(("lamp.step", [1]))
        refusals.append(("machine.run", []))
        refusals.append(("play.undo", []))
        refusals.append(("play.redo", []))
        refusals.append(("level.next", []))
        refusals.append(("level.select", [1]))
        refusals.append(("mode.practice", []))
        refusals.append(("mode.campaign", []))
        for refusal in refusals {
            let plan: Plan = try Access.refused(shell, recorder, refusal.control, refusal.values)
            #expect(plan.text == "Stop the replay first.", "\(refusal.control)")
            let code: String = try #require(presenter.refusalLog.last)
            #expect(code == Rule.replay, "\(refusal.control): \(code)")
        }
        #expect(Plan.refusalText(code: Rule.replay) == "Stop the replay first.")
        let after: Core = try Access.core(shell)
        #expect(after == before, "a refused action changes nothing")
        #expect(presenter.mirror.replayPosition == 1)
        #expect(presenter.mirror.replaying)

        // The tutorial dismissal and the sound setting stay allowed (neither changes the digest).
        let digest: String = try MoonlitMechanismTest.digest(shell)
        presenter.dismissTutorial(port: shell.port)
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
        let allowedDigest: String = try MoonlitMechanismTest.digest(shell)
        #expect(allowedDigest == digest, "the dismissal and the sound choice are not in the digest")
        #expect(presenter.mirror.replayPosition == 1)
        #expect(quiet.progress == won.progress)

        // Retry during replay starts the replay again.
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
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == actions.count)
        #expect(restarted.progress == won.progress)
    }

    /// Without a verified stored solution the replay cannot start: refused with `r02-g14.no-replay` in words (shown and
    /// announced), kept in `refusalLog`, and nothing changes; an unverified result (no trace) offers no replay either.
    @Test func replayWithoutASavedSolutionIsRefused() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        presenter.controlsDisappeared()
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)
        #expect(opening.progress.solved[opening.levelNumber] == nil)
        #expect(presenter.mirror.replayAvailable == false)
        let digest: String = try MoonlitMechanismTest.digest(shell)

        recorder.clock.advance()
        let refused: ActionResult = presenter.startReplay(port: shell.port)
        #expect(refused == .rejected(.rule(code: Rule.noReplay)), "\(refused.code)")
        let words: String = "There is no saved solution to replay for this level."
        #expect(presenter.mirror.message == words, "\(presenter.mirror.message ?? "nil")")
        #expect(recorder.announcements.announced.last == words)
        #expect(recorder.haptics.played.last == .error)
        #expect(presenter.refusalLog.last == Rule.noReplay)
        let after: Core = try Access.core(shell)
        #expect(after == opening, "a refused start changes nothing")
        #expect(after.mode == .campaign)
        let afterDigest: String = try MoonlitMechanismTest.digest(shell)
        #expect(afterDigest == digest)
        #expect(presenter.mirror.replaying == false)
        #expect(Plan.refusalText(code: Rule.noReplay) == words)

        // A result recorded without a trace (unverified) is kept but offers no replay.
        let unverified: MoonlitMechanismProgress.Result = MoonlitMechanismProgress.Result(actionsSpent: 9, stars: 1)
        let payload: Data = try opening.snapshotPayload()
        let edited: Data = try Script.payload(payload, frontier: 2, results: [(1, unverified)])
        var restored: Core = try Core.restore(payload: edited, seed: 0)
        #expect(restored.reconciliationDropped == 0, "an unverified result is not checked")
        #expect(restored.progress.solved[1] != nil, "the unverified result is kept")
        let fresh: MoonlitMechanismPresenter = Script.freshPresenter(RecordingAnnouncementSink())
        _ = fresh.describe(restored)
        #expect(fresh.mirror.replayAvailable == false, "no verified solution, no replay")
        let start: ActionResult = restored.apply(ExperienceAction(control: "replay.start", values: [1], step: 0))
        #expect(start == .rejected(.rule(code: Rule.noReplay)), "\(start.code)")
        #expect(restored.mode == .campaign)
    }

    // MARK: Dropped results (clarification Q2, SC-R02G1407-003)

    /// A restored core whose edited verified result was dropped is announced once by the presenter that describes it,
    /// however often it describes again.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        presenter.controlsDisappeared()
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)

        // Level 2's certified win recorded as verified, once honestly and once claiming fewer actions than its trace
        // spends.
        let honestResult: MoonlitMechanismProgress.Result = try Script.result(2)
        let spent: Int = honestResult.trace.count
        try #require(spent >= 2, "level 2's trace spends at least two actions")
        let editedResult: MoonlitMechanismProgress.Result = try Script.result(2, actionsSpent: spent - 1)
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
        #expect(MoonlitMechanismPresenter.droppedText(1) == expected)
        let before: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(before == 0)
        recorder.clock.advance()
        _ = presenter.describe(restored)
        let logged: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(logged == 1, "\(Script.logTexts(presenter))")
        var stateKinds: Int = 0
        var otherKinds: Int = 0
        for plan in presenter.feedbackLog where plan.text == expected {
            if plan.kind == .state { stateKinds += 1 } else { otherKinds += 1 }
        }
        #expect(stateKinds == 1, "announced as state")
        #expect(otherKinds == 0)
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
        let second: MoonlitMechanismProgress.Result = try Script.result(2)
        let third: MoonlitMechanismProgress.Result = try Script.result(3)
        try #require(second.trace.count >= 2 && third.trace.count >= 2)
        let editedSecond: MoonlitMechanismProgress.Result = try Script.result(2, actionsSpent: second.trace.count - 1)
        let editedThird: MoonlitMechanismProgress.Result = try Script.result(3, actionsSpent: third.trace.count - 1)
        let payload: Data = try opening.snapshotPayload()
        let tampered: Data = try Script.payload(payload, frontier: 4, results: [(2, editedSecond), (3, editedThird)])
        let restored: Core = try Core.restore(payload: tampered, seed: 0)
        #expect(restored.reconciliationDropped == 2)
        #expect(restored.progress.solved.isEmpty, "both edited results are dropped")
        #expect(restored.progress.frontier == 4, "the frontier is restored as saved")

        let expected: String = "2 saved results could not be checked and were removed."
        #expect(MoonlitMechanismPresenter.droppedText(2) == expected)
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let presenter: MoonlitMechanismPresenter = Script.freshPresenter(announcements)
        for _ in 0..<3 { _ = presenter.describe(restored) }
        let logged: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(logged == 1, "\(Script.logTexts(presenter))")
        let singular: Int = Script.count(MoonlitMechanismPresenter.droppedText(1), in: Script.logTexts(presenter))
        #expect(singular == 0)
        let said: Int = Script.count(expected, in: announcements.announced)
        #expect(said == 1, "\(announcements.announced)")
    }

    // MARK: Sound choice (clarification Q5, FR-R02G1407-007)

    /// `saveSound(on:port:)` sets the core's and the mirror's choice through `settings.sound` without changing the
    /// digest; the choice survives the shell's snapshot and restore; a fresh presenter describing a core restored with
    /// `"sound": true` applies the choice at its first describe (off screen, nothing plays).
    @Test func soundChoiceIsSavedAndAppliedOnOpen() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        Access.quiet(shell)
        let presenter: MoonlitMechanismPresenter = shell.presenter
        presenter.controlsDisappeared()
        let before: Core = try Access.core(shell)
        #expect(before.soundOn == false, "the sound is off by default")
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try MoonlitMechanismTest.digest(shell)

        let saved: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(saved == .accepted, "\(saved.code)")
        let on: Core = try Script.describe(shell)
        #expect(on.soundOn)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        let onDigest: String = try MoonlitMechanismTest.digest(shell)
        #expect(onDigest == digest, "the sound choice is not in the digest")
        #expect(on.play.fingerprint == before.play.fingerprint)
        #expect(on.progress == before.progress)
        let onPayload: Data = try on.snapshotPayload()
        let reopened: Core = try Core.restore(payload: onPayload, seed: 0)
        #expect(reopened.soundOn, "the saved choice is in the snapshot")

        // The shell's snapshot keeps the choice: turned off afterwards, a restore brings it back and applies it.
        let snapshot: ExperienceSnapshot = try shell.snapshot()
        let cleared: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(cleared == .accepted, "\(cleared.code)")
        let off: Core = try Script.describe(shell)
        #expect(off.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
        let offDigest: String = try MoonlitMechanismTest.digest(shell)
        #expect(offDigest == digest)
        try shell.restore(snapshot)
        let back: Core = try Script.describe(shell)
        #expect(back.soundOn, "the restored snapshot carries the saved choice")
        #expect(presenter.mirror.soundOn, "the restored choice is applied")
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")

        // A fresh presenter applies a restored `"sound": true` at its first describe (the experience opens).
        let offPayload: Data = try before.snapshotPayload()
        let edited: Data = try Script.payload(offPayload, sound: true)
        let restored: Core = try Core.restore(payload: edited, seed: 0)
        #expect(restored.soundOn)
        let fresh: MoonlitMechanismPresenter = Script.freshPresenter(RecordingAnnouncementSink())
        #expect(fresh.mirror.soundOn == false)
        #expect(fresh.sound.wanted == false)
        _ = fresh.describe(restored)
        #expect(fresh.mirror.soundOn, "the restored choice is applied")
        #expect(fresh.sound.wanted)
        #expect(fresh.sound.shouldPlay == false, "off screen, nothing plays")
        #expect(fresh.sound.playersMade == 0)

        let quiet: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(quiet.isAccepted, "\(quiet.code)")
        let silent: Core = try Script.describe(shell)
        #expect(silent.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
    }

    /// The choice saved in one opened experience is applied by a newly opened one restored from its snapshot.
    @Test func savedSoundChoiceAppliedWhenANewExperienceOpens() async throws {
        let first = ExperienceSession()
        let shell: Script.Shell = try await Access.open(first, seed: 0)
        Access.quiet(shell)
        shell.presenter.controlsDisappeared()
        let saved: ActionResult = shell.presenter.saveSound(on: true, port: shell.port)
        #expect(saved == .accepted, "\(saved.code)")
        let snapshot: ExperienceSnapshot = try shell.snapshot()
        first.close()

        let second = ExperienceSession()
        defer { second.close() }
        let reopened: Script.Shell = try await Access.open(second, seed: 0)
        Access.quiet(reopened)
        let presenter: MoonlitMechanismPresenter = reopened.presenter
        presenter.controlsDisappeared()
        #expect(presenter.mirror.soundOn == false, "a fresh opening has the sound off")
        try reopened.restore(snapshot)
        let core: Core = try Script.describe(reopened)
        #expect(core.soundOn)
        #expect(presenter.mirror.soundOn, "the saved choice is applied on open")
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        #expect(presenter.sound.playersMade == 0)
    }
}
#endif
