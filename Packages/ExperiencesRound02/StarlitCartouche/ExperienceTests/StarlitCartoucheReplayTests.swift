// StarlitCartoucheReplayTests — feature 457 (R02-G16-07) T-R02G1607-005 (clarifications Q2, Q4, Q5). On the
// simulator, through the one app's session host, the twin of Voxel Origami's feature-447 replay tests with hinge turns
// translated to Starlit legs. Replay (Q4): level 1 (seed 0) is won in campaign with its certified legs
// (`StarlitCartoucheExperienceCore.generated(number:).plan.legs`, each sent as `route.fly [star, wait]`) through
// `presenter.send` (the shell's port); the stored result is verified, its trace is those legs and the mirror offers
// "Replay best solution" (`replayAvailable`); `startReplay` opens mode `replay(level: 1)` on a fresh play with the
// tutorial done (the panel reads "Replay: leg 0 of n", Step "Leg 0 of n", Stop "n legs") and is announced as
// `after(old:new:)` names it; every `stepReplay` is accepted, reproduces the play fingerprint of a bare core (no host)
// applying the same legs one at a time and routes exactly `after(old:new:)` (the last one the win without stars), the
// mirror's `replaying`, `replayPosition` and `replayLength` following; the replay ends won; the progress never changes;
// one step past the end is refused (`r02-g16.replay-end`, "The replay is over.", shown and announced); `stopReplay`
// returns to the campaign at level 1. During replay `route.fly`, `play.undo`, `level.next` and `mode.practice` are
// refused with `r02-g16.replay` ("Stop the replay first."), while `settings.sound` stays allowed. Dropped results
// (Q2): a payload whose verified result carries edited stars is restored with
// `StarlitCartoucheExperienceCore.restore(payload:seed:)` (`reconciliationDropped` 1) and described twice; the feedback
// log holds "1 saved result could not be checked and was removed." exactly once. Sound (Q5): a fresh presenter
// describing a core restored with `"sound": true` applies the choice at its first describe (`mirror.soundOn`), and
// `saveSound(on:port:)` sends `settings.sound [1]` / `[0]` (the core's choice follows, the digest does not change).
// The controls are off screen, so no audio starts. Synthetic data, explicit types, plain loops, no nested closure
// literals, no sleep, no wall-clock assertion; each test short.
#if os(iOS)
import CoreGraphics
import Foundation
import StarlitCartoucheCore
import Testing
@testable import StarlitCartoucheExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the Starlit Cartouche replay tests.
@MainActor
enum StarlitCartoucheReplayScript {
    typealias Shell = StarlitCartoucheTest.Shell
    typealias Core = StarlitCartoucheExperienceCore
    typealias Progress = StarlitCartoucheProgress
    typealias Plan = StarlitCartoucheFeedbackPlan

    /// The certified legs of level `number` (never empty; they win the level).
    static func solution(_ number: Int) throws -> [StarlitCartoucheAction] {
        let legs: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(number)
        try #require(!legs.isEmpty, "level \(number)")
        return legs
    }

    /// The play fingerprints of a bare core opening level `number` (no host) before the first of `legs` and after
    /// each one; the last leg wins.
    static func reference(number: Int, legs: [StarlitCartoucheAction]) throws -> [String] {
        var core: Core = try Core.opening(number: number)
        var fingerprints: [String] = [core.play.fingerprint]
        for leg in legs {
            let result: ActionResult = core.apply(StarlitCartoucheTest.experienceAction(leg))
            #expect(result == .accepted, "\(leg): \(result.code)")
            fingerprints.append(core.play.fingerprint)
        }
        #expect(core.play.stage == .won, "the certified legs win level \(number)")
        return fingerprints
    }

    /// Describes the current core of `shell` again (describing the same state twice routes nothing) so the mirror
    /// reads the current state; returns that core.
    @discardableResult
    static func describe(_ shell: Shell) throws -> Core {
        let core: Core = try StarlitCartoucheTest.core(shell)
        _ = shell.presenter.describe(core)
        return core
    }

    /// Wins the current level of `shell` with `legs` through `presenter.send` (the path of the controls); returns the
    /// play fingerprints before the first leg and after each one.
    static func win(_ shell: Shell, legs: [StarlitCartoucheAction]) throws -> [String] {
        let first: Core = try StarlitCartoucheTest.core(shell)
        var fingerprints: [String] = [first.play.fingerprint]
        for leg in legs {
            let sent: (control: String, values: [Double]) = StarlitCartoucheTest.control(leg)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            let core: Core = try describe(shell)
            fingerprints.append(core.play.fingerprint)
        }
        let won: Core = try StarlitCartoucheTest.core(shell)
        #expect(won.play.stage == .won)
        return fingerprints
    }

    /// The verified result of level `number` with the certified legs as its trace and their count spent, its stars by
    /// rule against the certified plan's size, or `stars` when given (an edited result).
    static func result(_ number: Int, stars edited: Int? = nil) throws -> Progress.Result {
        let trace: [StarlitCartoucheAction] = try StarlitCartoucheTest.certifiedLegs(number)
        let certified: Int = try Core.generated(number: number).plan.size
        let spent: Int = trace.count
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
    static func freshPresenter(_ announcements: RecordingAnnouncementSink) -> StarlitCartouchePresenter {
        let presenter: StarlitCartouchePresenter = StarlitCartouchePresenter(reduceMotion: false,
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
    static func logTexts(_ presenter: StarlitCartouchePresenter) -> [String] {
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

    /// Expects the mirror's replay position and length and the panel's position line and Step and Stop values for
    /// position `position` of `length`.
    static func expectPanel(_ mirror: StarlitCartoucheMirror, position: Int, length: Int,
                            sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(mirror.replaying, sourceLocation: sourceLocation)
        #expect(mirror.replayPosition == position, sourceLocation: sourceLocation)
        #expect(mirror.replayLength == length, sourceLocation: sourceLocation)
        #expect(StarlitCartoucheControls.replayPositionText(mirror) == "Replay: leg \(position) of \(length)",
                sourceLocation: sourceLocation)
        #expect(StarlitCartoucheControls.replayStepValue(mirror) == "Leg \(position) of \(length)",
                sourceLocation: sourceLocation)
        let legs: String = length == 1 ? "1 leg" : "\(length) legs"
        #expect(StarlitCartoucheControls.replayStopValue(mirror) == legs, sourceLocation: sourceLocation)
    }
}

@MainActor
@Suite(.serialized) struct StarlitCartoucheReplayTests {
    typealias Access = StarlitCartoucheA11y
    typealias Script = StarlitCartoucheReplayScript
    typealias Core = StarlitCartoucheExperienceCore
    typealias Plan = StarlitCartoucheFeedbackPlan
    typealias Rule = StarlitCartoucheExperienceRule

    // MARK: Replay through the port (clarification Q4)

    /// Level 1 won in campaign with its certified legs, then replayed leg by leg: every step accepted with the
    /// fingerprint of a bare core applying the same legs, announced as `after(old:new:)` names it and the mirror's
    /// position following, a won end without stars, the progress unchanged; a step past the end is refused in words;
    /// stop returns to the campaign at level 1.
    @Test func replayReproducesTheWinLegByLeg() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: StarlitCartouchePresenter = shell.presenter
        Access.quiet(presenter)
        presenter.controlsDisappeared()
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        let legs: [StarlitCartoucheAction] = try Script.solution(1)
        let reference: [String] = try Script.reference(number: 1, legs: legs)
        let fingerprints: [String] = try Script.win(shell, legs: legs)
        #expect(fingerprints == reference, "the shell's win plays like a bare core")
        let won: Core = try Access.core(shell)
        #expect(won.levelNumber == 1, "a campaign win stays on the level won")
        #expect(won.mode == .campaign)
        let stored: StarlitCartoucheProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == legs, "the trace is the winning legs")
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
        let band: Int = StarlitCartoucheProgress.band(of: 1)
        #expect(startPlan.text == "Level 1, band \(band), replay.", "\(startPlan.text ?? "nil")")
        #expect(presenter.feedbackLog.count == logBeforeStart + 1, "the start routes one plan")
        #expect(presenter.feedbackLog.last == startPlan)
        #expect(recorder.announcements.announced.last == startPlan.text)
        #expect(presenter.mirror.replayAvailable == false, "no replay is offered during a replay")
        Script.expectPanel(presenter.mirror, position: 0, length: length)
        #expect(StarlitCartoucheControls.modeName(opened.mode) == "replay")
        #expect(presenter.mirror.mode == .replay(level: 1))

        // Every step reproduces the bare core's fingerprint and is announced like the leg it applies.
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
            #expect(core.play.fingerprint == fingerprints[k], "step \(k): the campaign play's fingerprint")
            #expect(core.progress == won.progress, "step \(k): replay never records")
            let plan: Plan = Plan.after(old: previous, new: core)
            #expect(plan.text != nil, "step \(k) is announced")
            #expect(presenter.feedbackLog.count == logBefore + 1, "step \(k) routes one plan")
            #expect(presenter.feedbackLog.last == plan, "step \(k): the plan of the leg applied")
            #expect(recorder.announcements.announced.last == plan.text, "step \(k)")
            if k < length {
                #expect(core.play.stage != .won, "step \(k): not won before the last leg")
                #expect(plan.kind == .state, "step \(k)")
            } else {
                #expect(core.play.stage == .won, "step \(k): the last leg wins")
                let spent: Int = StarlitCartoucheProgress.actionsSpent(core.play)
                #expect(plan.text == Script.replayWinText(spent: spent), "\(plan.text ?? "nil")")
                #expect(plan.text?.contains("stars") == false, "a replayed win claims no stars")
                #expect(plan.kind == .outcome)
                #expect(plan.haptic == .success)
            }
            Script.expectPanel(presenter.mirror, position: k, length: length)
            #expect(presenter.mirror.message == nil)
            previous = core
        }
        try StarlitCartoucheTest.draw(session)
        let finished: Core = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")
        #expect(presenter.mirror.stars == starsBefore, "the replayed win claims no stars")

        // One step past the end is refused, shown and announced.
        let endDigest: String = try StarlitCartoucheTest.digest(shell)
        recorder.clock.advance()
        let past: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(past == .rejected(.rule(code: Rule.replayEnd)), "\(past.code)")
        #expect(presenter.mirror.message == "The replay is over.", "\(presenter.mirror.message ?? "nil")")
        #expect(recorder.announcements.announced.last == "The replay is over.")
        #expect(recorder.haptics.played.last == .error)
        #expect(presenter.refusalLog.last == Rule.replayEnd)
        let pastDigest: String = try StarlitCartoucheTest.digest(shell)
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

    /// During replay `route.fly`, `play.undo`, `level.next` and `mode.practice` are refused with `r02-g16.replay`
    /// ("Stop the replay first.", a rejection with an error haptic) and change nothing, the progress included;
    /// `settings.sound` stays allowed.
    @Test func playActionsAreRefusedDuringReplay() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: StarlitCartouchePresenter = shell.presenter
        Access.quiet(presenter)
        presenter.controlsDisappeared()
        let legs: [StarlitCartoucheAction] = try Script.solution(1)
        _ = try Script.win(shell, legs: legs)
        let won: Core = try Access.core(shell)
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let stepped: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(stepped == .accepted, "\(stepped.code)")
        let before: Core = try Script.describe(shell)
        #expect(before.mode == .replay(level: 1))
        #expect(before.play.records.count == 1)

        // Every play action is refused in the replay words.
        let recorder: Access.Recorder = Access.record(shell)
        let next: StarlitCartoucheAction = legs.count > 1 ? legs[1] : legs[0]
        let sent: (control: String, values: [Double]) = StarlitCartoucheTest.control(next)
        var refusals: [(control: String, values: [Double])] = [sent]
        refusals.append(("play.undo", []))
        refusals.append(("level.next", []))
        refusals.append(("mode.practice", []))
        for refusal in refusals {
            let plan: Plan = try Access.refused(shell, recorder, refusal.control, refusal.values)
            #expect(plan.text == "Stop the replay first.", "\(refusal.control)")
            let code: String = try #require(presenter.refusalLog.last)
            #expect(code == Rule.replay, "\(refusal.control): \(code)")
        }
        #expect(Plan.refusalText(code: Rule.replay) == "Stop the replay first.")
        let after: Core = try Access.core(shell)
        #expect(after == before, "a refused action changes nothing")
        #expect(after.progress == won.progress, "the replay never changes progress")
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayPosition == 1)
        #expect(presenter.mirror.replayLength == legs.count)

        // The sound setting stays allowed and is not in the digest.
        let digest: String = try StarlitCartoucheTest.digest(shell)
        let soundOn: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(soundOn == .accepted, "\(soundOn.code)")
        let sounding: Core = try Script.describe(shell)
        #expect(sounding.soundOn)
        #expect(sounding.mode == .replay(level: 1))
        #expect(sounding.play.records.count == 1)
        #expect(presenter.mirror.soundOn)
        let soundOff: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(soundOff == .accepted, "\(soundOff.code)")
        let quiet: Core = try Script.describe(shell)
        #expect(quiet.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        let allowedDigest: String = try StarlitCartoucheTest.digest(shell)
        #expect(allowedDigest == digest, "the sound choice is not in the digest")
        #expect(quiet.progress == won.progress)
    }

    // MARK: Dropped results (clarification Q2)

    /// A restored core whose verified result with edited stars was dropped is announced once by the presenter that
    /// describes it, however often it describes again.
    @Test func droppedResultAnnouncedOnce() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: StarlitCartouchePresenter = shell.presenter
        presenter.controlsDisappeared()
        let recorder: Access.Recorder = Access.record(shell)
        let opening: Core = try Access.core(shell)

        // Level 2's certified win recorded as verified, once honestly and once with edited stars.
        let honestResult: StarlitCartoucheProgress.Result = try Script.result(2)
        let editedStars: Int = honestResult.stars == 3 ? 2 : 3
        let editedResult: StarlitCartoucheProgress.Result = try Script.result(2, stars: editedStars)
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
        #expect(StarlitCartouchePresenter.droppedText(1) == expected)
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
        let fresh: StarlitCartouchePresenter = Script.freshPresenter(RecordingAnnouncementSink())
        #expect(fresh.mirror.soundOn == false)
        _ = fresh.describe(restored)
        #expect(fresh.mirror.soundOn, "the restored choice is applied")
        #expect(fresh.sound.wanted)
        #expect(fresh.sound.shouldPlay == false, "off screen, nothing plays")
        #expect(fresh.sound.playersMade == 0)

        // The Sound toggle's path through the shell's port.
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, seed: 0)
        let presenter: StarlitCartouchePresenter = shell.presenter
        Access.quiet(presenter)
        presenter.controlsDisappeared()
        let before: Core = try Access.core(shell)
        #expect(before.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try StarlitCartoucheTest.digest(shell)

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
        let onDigest: String = try StarlitCartoucheTest.digest(shell)
        #expect(onDigest == digest, "the sound choice is not in the digest")
        #expect(on.play.fingerprint == before.play.fingerprint)
        #expect(on.progress == before.progress)
        let reopened: Core = try Core.restore(payload: try on.snapshotPayload(), seed: 0)
        #expect(reopened.soundOn, "the saved choice is in the snapshot")

        let cleared: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(cleared == .accepted, "\(cleared.code)")
        let off: Core = try Script.describe(shell)
        #expect(off.soundOn == false, "saveSound sends settings.sound [0]")
        #expect(off == before)
        #expect(presenter.mirror.soundOn == false)
        #expect(presenter.sound.wanted == false)
        let offDigest: String = try StarlitCartoucheTest.digest(shell)
        #expect(offDigest == digest)
    }
}
#endif
