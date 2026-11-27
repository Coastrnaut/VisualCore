// MushroomWeatherReplayTests — feature 497 (R02-G20-07) T-R02G2007-006 (FR-R02G2007-003, 004, 007; clarifications
// Q2, Q4, Q5). On the simulator, through the one app's session host, ported from Microscopic Aurora's feature-487
// replay tests with the actions translated to Mushroom Weather's pod, vent and moonlight actions and the run. Replay
// (Q4): before any win `replay.start` is refused (`r02-g20.no-replay`, "There is no saved solution to replay for this
// level."), as are `replay.step` and `replay.stop` outside replay; level 1 (seed 0) is then won in campaign with its
// certified witness (`MushroomWeatherTest.certifiedPlan(1)`, each action sent as its control, then `weather.run`)
// through `presenter.send` (the shell's port); the stored result is verified, its trace is those actions then the run,
// and the mirror offers "Replay best solution" (`replayAvailable`); `startReplay` opens mode `replay(level: 1)` on a
// fresh play with the tutorial done (the panel reads "Replay: action 0 of n", Step "Action 0 of n", Stop "n actions";
// the position counts only pod, vent, moonlight and run records, a fresh play also holds its begin record) and is
// announced as `after(old:new:)` names it ("Level 1, band 1, replay."); every `stepReplay` is accepted, reproduces the
// play fingerprint of the campaign play and of a bare core (no host) applying the same actions one at a time and routes
// exactly `after(old:new:)` (the last one the win without stars), the mirror's `replaying`, `replayPosition` and
// `replayLength` following; the replay ends won; the progress never changes; one step past the end is refused
// (`r02-g20.replay-end`, "The replay is over.", shown and announced); `stopReplay` returns to the campaign at level 1.
// During replay `pod.place`, `pod.remove`, `vent.set`, `moon.set`, `weather.run`, `play.undo`, `play.redo`,
// `level.next`, `level.select`, `mode.practice`, `mode.campaign` and `mode.daily` are refused with `r02-g20.replay`
// ("Stop the replay first."), while `settings.sound` stays allowed. Dropped results (Q2): a payload whose verified
// result carries edited stars is restored with `MushroomWeatherExperienceCore.restore(payload:seed:)`
// (`reconciliationDropped` 1) and described twice; the feedback log holds "1 saved result could not be checked and was
// removed." exactly once, as `state`. Sound (Q5): a fresh presenter describing a core restored with `"sound": true`
// applies the choice at its first describe (`mirror.soundOn`, `sound.wanted`), and the Sound toggle's path
// `saveSound(on:port:)` sends `settings.sound [1]` / `[0]` (the core's choice follows, the digest does not change). The
// controls are off screen, so no audio starts. Synthetic data, explicit timestamps (the recorder's hand-moved clock),
// explicit types, plain loops, no nested closure literals, no sleep, no wall-clock assertion; each test short (well
// under 10 s).
#if os(iOS)
import Foundation
import MushroomWeatherCore
import Testing
@testable import MushroomWeatherExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the Mushroom Weather replay tests (feature 497).
@MainActor
enum MushroomWeatherReplayScript {
    /// The shell of the tests.
    typealias Shell = MushroomWeatherTest.Shell
    /// The experience core.
    typealias Core = MushroomWeatherExperienceCore
    /// The saved progress.
    typealias Progress = MushroomWeatherProgress
    /// The feedback plan.
    typealias Plan = MushroomWeatherFeedbackPlan

    /// The year of the daily date sent during replay (any valid date; the core refuses it before reading it).
    nonisolated static let dailyYear: Double = 2026

    /// The winning actions of level `number`: its certified pod, vent and moonlight actions, then the run (never
    /// empty).
    static func solution(_ number: Int) throws -> [MushroomWeatherAction] {
        let plan: [MushroomWeatherAction] = try MushroomWeatherTest.certifiedPlan(number)
        try #require(!plan.isEmpty, "level \(number) has a certified plan")
        return plan + [.run]
    }

    /// The play fingerprints of a bare core opening level `number` (no host) before the first of `actions` and after
    /// each one; the last action (the run) wins.
    static func reference(number: Int, actions: [MushroomWeatherAction]) throws -> [String] {
        var core: Core = try Core.opening(number: number)
        var fingerprints: [String] = [core.play.fingerprint]
        for action in actions {
            let result: ActionResult = core.apply(MushroomWeatherTest.experienceAction(action))
            #expect(result == .accepted, "\(action): \(result.code)")
            fingerprints.append(core.play.fingerprint)
        }
        #expect(core.play.stage == .won, "the certified plan and the run win level \(number)")
        return fingerprints
    }

    /// Describes the current core of `shell` again (describing the same state twice routes nothing) so the mirror
    /// reads the current state; returns that core.
    @discardableResult
    static func describe(_ shell: Shell) throws -> Core {
        let core: Core = try MushroomWeatherTest.core(shell)
        _ = shell.presenter.describe(core)
        return core
    }

    /// Wins the current level of `shell` with `actions` through `presenter.send` (the path of the controls); returns
    /// the play fingerprints before the first action and after each one.
    static func win(_ shell: Shell, actions: [MushroomWeatherAction]) throws -> [String] {
        let first: Core = try MushroomWeatherTest.core(shell)
        var fingerprints: [String] = [first.play.fingerprint]
        for action in actions {
            let sent: (control: String, values: [Double]) = MushroomWeatherTest.control(action)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            let core: Core = try describe(shell)
            fingerprints.append(core.play.fingerprint)
        }
        let won: Core = try MushroomWeatherTest.core(shell)
        #expect(won.play.stage == .won, "\(won.play.stage)")
        return fingerprints
    }

    /// The verified result of level `number` with its certified actions and the run as its trace and those actions
    /// spent, its stars by rule against the certified plan's action count, or `stars` when given (an edited result).
    static func result(_ number: Int, stars edited: Int? = nil) throws -> Progress.Result {
        let trace: [MushroomWeatherAction] = try solution(number)
        let certified: Int = try Core.generated(number: number).plan.size
        let spent: Int = trace.count - 1
        let stars: Int = edited ?? Progress.stars(actionsSpent: spent, certified: certified)
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
    static func freshPresenter(_ announcements: RecordingAnnouncementSink) -> MushroomWeatherPresenter {
        let presenter: MushroomWeatherPresenter = MushroomWeatherPresenter(reduceMotion: false, reduceFlashing: false)
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
    static func logTexts(_ presenter: MushroomWeatherPresenter) -> [String] {
        var texts: [String] = []
        for plan in presenter.feedbackLog {
            if let text = plan.text { texts.append(text) }
        }
        return texts
    }

    /// The pod, vent, moonlight and run records of `play`: the trace actions it applied (begin, tutorial, undo, redo
    /// and pause records left out).
    static func applied(_ play: MushroomWeatherPlay) -> Int {
        var count: Int = 0
        for record in play.records {
            switch record.kind {
            case .place, .remove, .vent, .moonlight, .run: count += 1
            case .undo, .redo, .begin, .dismissTutorial, .pause, .resume: break
            }
        }
        return count
    }

    /// The win announcement of a replayed play that spent `spent` actions: the win without stars.
    static func replayWinText(spent: Int) -> String {
        let words: String = spent == 1 ? "1 action" : "\(spent) actions"
        return Plan.wonText + " Level won spending " + words + "."
    }

    /// Expects the mirror's replay position and length and the panel's position line and Step and Stop values for
    /// position `position` of `length`.
    static func expectPanel(_ mirror: MushroomWeatherMirror, position: Int, length: Int,
                            sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(mirror.replaying, sourceLocation: sourceLocation)
        #expect(mirror.replayPosition == position, sourceLocation: sourceLocation)
        #expect(mirror.replayLength == length, sourceLocation: sourceLocation)
        #expect(MushroomWeatherControls.replayPositionText(mirror) == "Replay: action \(position) of \(length)",
                sourceLocation: sourceLocation)
        #expect(MushroomWeatherControls.replayStepValue(mirror) == "Action \(position) of \(length)",
                sourceLocation: sourceLocation)
        let actions: String = length == 1 ? "1 action" : "\(length) actions"
        #expect(MushroomWeatherControls.replayStopValue(mirror) == actions, sourceLocation: sourceLocation)
    }
}

@MainActor
@Suite(.serialized) struct MushroomWeatherReplayTests {
    typealias Access = MushroomWeatherA11y
    typealias Script = MushroomWeatherReplayScript
    typealias Core = MushroomWeatherExperienceCore
    typealias Plan = MushroomWeatherFeedbackPlan
    typealias Rule = MushroomWeatherExperienceRule
    typealias Presenter = MushroomWeatherPresenter
    typealias Mirror = MushroomWeatherMirror

    // MARK: Replay through the port (clarification Q4)

    /// Level 1 won in campaign with its certified witness and the run, then replayed action by action: every step
    /// accepted with the fingerprint of the campaign play and of a bare core applying the same actions, announced as
    /// `after(old:new:)` names it and the mirror's position following, a won end without stars, the progress
    /// unchanged; a step past the end is refused in words; stop returns to the campaign at level 1. Before the win
    /// there is nothing to replay.
    @Test func replayReproducesTheWinActionByAction() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        presenter.controlsDisappeared()
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        // Nothing to replay yet: Replay, Step and Stop are refused in words.
        let early: Access.Recorder = Access.record(shell)
        let none: (plan: Plan, code: String) = try Access.refused(shell, early, "replay.start", [1])
        #expect(none.code == Rule.noReplay, "\(none.code)")
        #expect(none.plan.text == "There is no saved solution to replay for this level.")
        #expect(Plan.refusalText(code: Rule.noReplay) == "There is no saved solution to replay for this level.")
        let stray: (plan: Plan, code: String) = try Access.refused(shell, early, "replay.step", [])
        #expect(stray.code == Rule.noReplay, "\(stray.code)")
        let strayStop: (plan: Plan, code: String) = try Access.refused(shell, early, "replay.stop", [])
        #expect(strayStop.code == Rule.noReplay, "\(strayStop.code)")
        Access.quiet(presenter)

        let actions: [MushroomWeatherAction] = try Script.solution(1)
        let reference: [String] = try Script.reference(number: 1, actions: actions)
        let fingerprints: [String] = try Script.win(shell, actions: actions)
        #expect(fingerprints == reference, "the shell's win plays like a bare core")
        let won: Core = try Access.core(shell)
        #expect(won.levelNumber == 1, "a campaign win stays on the level won")
        #expect(won.mode == .campaign)
        let stored: MushroomWeatherProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == actions, "the trace is the winning pod, vent and moonlight actions, then the run")
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
        #expect(Script.applied(opened.play) == 0, "a fresh play holds no pod, vent, moonlight or run record")
        #expect(opened.tutorial == .done, "the tutorial is done in replay")
        #expect(opened.play.fingerprint == reference[0], "the replay starts where the win started")
        #expect(opened.progress == won.progress)
        let startPlan: Plan = Plan.after(old: won, new: opened)
        let band: Int = MushroomWeatherProgress.band(of: 1)
        #expect(startPlan.text == "Level 1, band \(band), replay.", "\(startPlan.text ?? "nil")")
        #expect(presenter.feedbackLog.count == logBeforeStart + 1, "the start routes one plan")
        #expect(presenter.feedbackLog.last == startPlan)
        #expect(recorder.announcements.announced.last == startPlan.text)
        #expect(presenter.mirror.replayAvailable == false, "no replay is offered during a replay")
        Script.expectPanel(presenter.mirror, position: 0, length: length)
        #expect(presenter.mirror.mode == .replay(level: 1))
        #expect(presenter.mirror.modeLabel == "Mode: replay")
        #expect(Mirror.modeName(.replay(level: 1)) == Plan.modeName(.replay(level: 1)))

        // Every step reproduces the campaign play's fingerprint and is announced like the action it applies.
        var previous: Core = opened
        for k in 1...length {
            recorder.clock.advance()
            let logBefore: Int = presenter.feedbackLog.count
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: Core = try Script.describe(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(Script.applied(core.play) == k, "step \(k): one pod, vent, moonlight or run record per step")
            #expect(core.play.fingerprint == reference[k], "step \(k): the bare core's fingerprint")
            #expect(core.play.fingerprint == fingerprints[k], "step \(k): the campaign play's fingerprint")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            let plan: Plan = Plan.after(old: previous, new: core)
            #expect(plan.text != nil, "step \(k) is announced")
            #expect(presenter.feedbackLog.count == logBefore + 1, "step \(k) routes one plan")
            #expect(presenter.feedbackLog.last == plan, "step \(k): the plan of the action applied")
            #expect(recorder.announcements.announced.last == plan.text, "step \(k)")
            if k < length {
                #expect(core.play.stage != .won, "step \(k): not won before the run")
            } else {
                #expect(core.play.stage == .won, "step \(k): the run wins")
                let spent: Int = MushroomWeatherProgress.actionsSpent(core.play)
                #expect(spent == length - 1, "the replay spends the trace's pod, vent and moonlight actions")
                #expect(plan.text == Script.replayWinText(spent: spent), "\(plan.text ?? "nil")")
                #expect(plan.text?.contains("stars") == false, "a replayed win claims no stars")
                #expect(plan.kind == .outcome)
                #expect(plan.haptic == .success)
            }
            Script.expectPanel(presenter.mirror, position: k, length: length)
            #expect(presenter.mirror.message == nil)
            previous = core
        }
        try MushroomWeatherTest.draw(session)
        let finished: Core = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")
        #expect(presenter.mirror.stars == starsBefore, "the replayed win claims no stars")

        // One step past the end is refused, shown and announced.
        let endDigest: String = try MushroomWeatherTest.digest(shell)
        recorder.clock.advance()
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(!past.isAccepted, "\(past.code)")
        #expect(Mirror.bareCode(past.code) == Rule.replayEnd, "\(past.code)")
        #expect(presenter.mirror.message == "The replay is over.", "\(presenter.mirror.message ?? "nil")")
        #expect(recorder.announcements.announced.last == "The replay is over.")
        #expect(recorder.haptics.played.last == .error)
        #expect(presenter.refusalLog.last == Rule.replayEnd)
        let pastDigest: String = try MushroomWeatherTest.digest(shell)
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
        #expect(Script.applied(campaign.play) == 0)
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

    /// During replay `pod.place`, `pod.remove`, `vent.set`, `moon.set`, `weather.run`, `play.undo`, `play.redo`,
    /// `level.next`, `level.select`, `mode.practice`, `mode.campaign` and `mode.daily` are refused with
    /// `r02-g20.replay` ("Stop the replay first.", shown and announced, a rejection with an error haptic) and change
    /// nothing, the progress included; `settings.sound` stays allowed.
    @Test func playActionsAreRefusedDuringReplay() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        Access.quiet(presenter)
        presenter.controlsDisappeared()
        let actions: [MushroomWeatherAction] = try Script.solution(1)
        _ = try Script.win(shell, actions: actions)
        let won: Core = try Access.core(shell)
        _ = try Script.describe(shell)
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let stepped: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(stepped == .accepted, "\(stepped.code)")
        let before: Core = try Script.describe(shell)
        #expect(before.mode == .replay(level: 1))
        #expect(Script.applied(before.play) == 1)

        // Every play action is refused in the replay words.
        let recorder: Access.Recorder = Access.record(shell)
        // The next action of the trace (before the run), or the first one again when the trace has a single action.
        let change: MushroomWeatherAction = actions.count > 2 ? actions[1] : actions[0]
        let next: (control: String, values: [Double]) = MushroomWeatherTest.control(change)
        var refusals: [(control: String, values: [Double])] = [next]
        refusals.append(("pod.place", [Double(Access.levelOneSlot), Double(Access.levelOneCell.row),
                                       Double(Access.levelOneCell.column)]))
        refusals.append(("pod.remove", [0]))
        refusals.append(("vent.set", [Double(Access.levelOneVent), 1]))
        refusals.append(("moon.set", [1]))
        refusals.append(("weather.run", []))
        refusals.append(("play.undo", []))
        refusals.append(("play.redo", []))
        refusals.append(("level.next", []))
        refusals.append(("level.select", [1]))
        refusals.append(("mode.practice", []))
        refusals.append(("mode.campaign", []))
        refusals.append(("mode.daily", [Script.dailyYear, 3, 1]))
        for refusal in refusals {
            let refused: (plan: Plan, code: String) = try Access.refused(shell, recorder, refusal.control,
                                                                         refusal.values)
            #expect(refused.plan.text == "Stop the replay first.", "\(refusal.control)")
            #expect(refused.code == Rule.replay, "\(refusal.control): \(refused.code)")
            let logged: String = try #require(presenter.refusalLog.last)
            #expect(logged == Rule.replay, "\(refusal.control): \(logged)")
            #expect(recorder.announcements.announced.last == "Stop the replay first.", "\(refusal.control)")
        }
        #expect(Plan.refusalText(code: Rule.replay) == "Stop the replay first.")
        let after: Core = try Access.core(shell)
        #expect(after == before, "a refused action changes nothing")
        #expect(after.progress == won.progress, "the replay never changes progress")
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayPosition == 1)
        #expect(presenter.mirror.replayLength == actions.count)

        // The sound setting stays allowed and is not in the digest.
        let digest: String = try MushroomWeatherTest.digest(shell)
        let soundOn: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(soundOn == .accepted, "\(soundOn.code)")
        let sounding: Core = try Script.describe(shell)
        #expect(sounding.soundOn)
        #expect(sounding.mode == .replay(level: 1))
        #expect(Script.applied(sounding.play) == 1)
        #expect(presenter.mirror.soundOn)
        let soundOff: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(soundOff == .accepted, "\(soundOff.code)")
        let quiet: Core = try Script.describe(shell)
        #expect(quiet.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        let allowedDigest: String = try MushroomWeatherTest.digest(shell)
        #expect(allowedDigest == digest, "the sound choice is not in the digest")
        #expect(quiet.progress == won.progress)
    }

    // MARK: Dropped results (clarification Q2)

    /// A restored core whose verified result with edited stars was dropped is announced once by the presenter that
    /// describes it, however often it describes again.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        presenter.controlsDisappeared()
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)

        // Level 2's certified win recorded as verified, once honestly and once with edited stars.
        let honestResult: MushroomWeatherProgress.Result = try Script.result(2)
        let editedStars: Int = honestResult.stars == 3 ? 2 : 3
        let editedResult: MushroomWeatherProgress.Result = try Script.result(2, stars: editedStars)
        #expect(editedResult.stars != honestResult.stars)
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
        #expect(Presenter.droppedText(1) == expected)
        #expect(Presenter.droppedText(2) == "2 saved results could not be checked and were removed.")
        let before: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(before == 0)
        recorder.clock.advance()
        _ = presenter.describe(restored)
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

        // Describing again (the honest core and the restored one) never repeats the announcement.
        let followers: [Core] = [honest, restored]
        for follower in followers {
            recorder.clock.advance()
            _ = presenter.describe(follower)
        }
        let loggedAfter: Int = Script.count(expected, in: Script.logTexts(presenter))
        #expect(loggedAfter == 1, "\(Script.logTexts(presenter))")
        let saidAfter: Int = Script.count(expected, in: recorder.announcements.announced)
        #expect(saidAfter == 1, "\(recorder.announcements.announced)")
    }

    // MARK: Sound choice (clarification Q5)

    /// A fresh presenter describing a core restored with `"sound": true` applies the choice at its first describe
    /// (off screen, nothing plays); the Sound toggle's path `saveSound(on:port:)` sends `settings.sound [1]` and
    /// `[0]`: the core's and the mirror's choice follow (as a bare core applying the same action) and the digest does
    /// not change.
    @Test func soundChoiceAppliedOnOpenAndSavedThroughSettingsSound() async throws {
        // The saved choice applied on open.
        let base: Core = try Core.opening(number: 1)
        #expect(base.soundOn == false, "the sound is off by default")
        let edited: Data = try Script.payload(try base.snapshotPayload(), sound: true)
        let restored: Core = try Core.restore(payload: edited, seed: 0)
        #expect(restored.soundOn)
        let fresh: Presenter = Script.freshPresenter(RecordingAnnouncementSink())
        #expect(fresh.mirror.soundOn == false)
        #expect(fresh.sound.wanted == false)
        _ = fresh.describe(restored)
        #expect(fresh.mirror.soundOn, "the restored choice is applied")
        #expect(fresh.sound.wanted)
        #expect(fresh.sound.shouldPlay == false, "off screen, nothing plays")
        #expect(fresh.sound.playersMade == 0)

        // The Sound toggle's path through the shell's port.
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        Access.quiet(presenter)
        presenter.controlsDisappeared()
        let before: Core = try Access.core(shell)
        #expect(before.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try MushroomWeatherTest.digest(shell)

        let saved: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(saved == .accepted, "\(saved.code)")
        let on: Core = try Script.describe(shell)
        var bare: Core = before
        let bareResult: ActionResult = bare.apply(ExperienceAction(control: "settings.sound", values: [1], step: 0))
        #expect(bareResult == .accepted, "\(bareResult.code)")
        #expect(on == bare, "saveSound sends settings.sound [1]")
        #expect(on.soundOn)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(presenter.sound.shouldPlay == false, "off screen, nothing plays")
        let onDigest: String = try MushroomWeatherTest.digest(shell)
        #expect(onDigest == digest, "the sound choice is not in the digest")
        #expect(on.play.fingerprint == before.play.fingerprint)
        #expect(on.progress == before.progress)
        let reopened: Core = try Core.restore(payload: try on.snapshotPayload(), seed: 0)
        #expect(reopened.soundOn, "the saved choice is in the snapshot")
        let second: Presenter = Script.freshPresenter(RecordingAnnouncementSink())
        _ = second.describe(reopened)
        #expect(second.mirror.soundOn, "the saved choice is applied when the experience opens again")
        #expect(second.sound.wanted)

        let cleared: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(cleared == .accepted, "\(cleared.code)")
        let off: Core = try Script.describe(shell)
        #expect(off.soundOn == false, "saveSound sends settings.sound [0]")
        #expect(off == before)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
        let offDigest: String = try MushroomWeatherTest.digest(shell)
        #expect(offDigest == digest)
    }
}
#endif
