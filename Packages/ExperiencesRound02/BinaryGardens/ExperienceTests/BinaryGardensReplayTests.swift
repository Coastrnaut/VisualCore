// BinaryGardensReplayTests — feature 507 (R02-G21-07) T-R02G2107-006 (FR-R02G2107-004, 005, 007, 008, 009;
// clarifications Q2, Q4, Q5, Q6). On the simulator, through the one app's session host, ported from Mushroom Weather's
// feature-497 replay tests with the actions translated to Binary Gardens' ring, phase, luminosity and tilt actions and
// the run. Replay (Q4): before any win `replay.start` is refused (`r02-g21.no-replay`, "There is no saved solution to
// replay for this level."), as are `replay.step` and `replay.stop` outside replay; level 1 (seed 0) is then won in
// campaign with its certified witness (`BinaryGardensWitness.make` of the generated level: the certified plan, then
// the run), each action sent as its control through `presenter.send` (the shell's port), the play fingerprints equal
// to the witness's fingerprints (after `begin` and `dismissTutorial`, then after each action); the stored result is
// verified with exactly those actions as its trace, and the mirror offers "Replay best solution" (`replayAvailable`);
// `startReplay` opens mode `replay(level: 1)` on a fresh play with the tutorial done and tick 48 shown (the panel reads
// "Replay: action 0 of n", Step "Action 0 of n", Stop "n actions"), announced as `after(old:new:)` names it ("Level 1,
// band 1, replay."); every `stepReplay` is accepted, reproduces the witness fingerprint of that action, routes exactly
// `after(old:new:)` (the last one the win without stars) and moves the mirror's position; the replay ends won; one step
// past the end is refused ("The replay is over.", shown, announced and logged by bare code); `stopReplay` returns to
// the campaign at level 1. During replay `clock.show` scrubs the cycle at any step (the play, the digest and the
// position unchanged; the next step keeps the shown tick), `tutorial.dismiss` and `settings.sound` stay allowed, and
// `star.ring`, `star.phase`, `star.luminosity`, `orbit.tilt`, `light.run`, `play.undo`, `play.redo`, `level.next`,
// `level.select`, `mode.practice`, `mode.campaign` and `mode.daily` are refused with `r02-g21.replay` ("Stop the replay
// first."), each logged by bare code in `refusalLog`. The progress never changes during replay, a restart and a stop
// (its encoding included). Dropped results (Q2): a payload whose verified results carry edited stars is restored with
// `BinaryGardensExperienceCore.restore(payload:seed:)` (`reconciliationDropped` 1 or 2) and described repeatedly by a
// fresh presenter; the feedback log holds "1 saved result could not be checked and was removed." (or "2 saved results
// could not be checked and were removed.") exactly once, as `state`, and VoiceOver hears it once. Sound (Q5): a fresh
// presenter describing a core restored with `"sound": true` applies the choice at its first describe (`mirror.soundOn`,
// `sound.wanted`), and the Sound toggle's path `saveSound(on:port:)` sends `settings.sound [1]` / `[0]` (the core's
// choice follows, the digest does not change, a reopened save applies it again). The panel's Replay, Step and Stop
// carry a label and a value; the native actions cover the four new controls. The controls are off screen, so no audio
// starts. Synthetic data, explicit timestamps (the recorder's hand-moved clock), explicit types, plain loops, no
// nested closure literals, no sleep, no wall-clock assertion; each test short (well under 10 s).
#if os(iOS)
import BinaryGardensCore
import Foundation
import Testing
@testable import BinaryGardensExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreSimulation
import VisualCoreUI

/// Helpers of the Binary Gardens replay tests (feature 507).
@MainActor
enum BinaryGardensReplayScript {
    /// The shell of the tests.
    typealias Shell = BinaryGardensTest.Shell
    /// The experience core.
    typealias Core = BinaryGardensExperienceCore
    /// The saved progress.
    typealias Progress = BinaryGardensProgress
    /// The feedback plan.
    typealias Plan = BinaryGardensFeedbackPlan
    /// The accessibility helpers (open, record, refused).
    typealias Access = BinaryGardensA11y

    /// The year of the daily date sent during replay (any valid date; the core refuses it before reading it).
    nonisolated static let dailyYear: Double = 2026
    /// The ticks shown while scrubbing the cycle during replay.
    nonisolated static let scrubTicks: [Int] = [1, 24, 47]

    /// The certified witness of level `number`: its actions (the certified plan, then the run) and the play
    /// fingerprints of a fresh adapter play (after `begin` and, on a tutorial level, `dismissTutorial`) and after each
    /// action (`actions.count + 1` fingerprints).
    static func witness(_ number: Int) throws -> (actions: [BinaryGardensAction], fingerprints: [String]) {
        let made: BinaryGardensWitness = try BinaryGardensWitness.make(try Core.generated(number: number))
        let plan: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(number)
        try #require(!plan.isEmpty, "level \(number) has a certified plan")
        #expect(made.actions == plan + [.run], "the witness is the certified plan, then the run")
        try #require(made.fingerprints.count >= made.actions.count + 1)
        let prints: [String] = Array(made.fingerprints.suffix(made.actions.count + 1))
        return (made.actions, prints)
    }

    /// Describes the current core of `shell` again (describing the same state twice routes nothing) so the mirror
    /// reads the current state; returns that core.
    @discardableResult
    static func describe(_ shell: Shell) throws -> Core {
        let core: Core = try BinaryGardensTest.core(shell)
        _ = shell.presenter.describe(core)
        return core
    }

    /// Wins the current level of `shell` with `actions` through `presenter.send` (the path of the controls); returns
    /// the play fingerprints before the first action and after each one.
    static func win(_ shell: Shell, actions: [BinaryGardensAction]) throws -> [String] {
        let first: Core = try BinaryGardensTest.core(shell)
        var fingerprints: [String] = [first.play.fingerprint]
        for action in actions {
            let sent: (control: String, values: [Double]) = BinaryGardensTest.control(action)
            let result: ActionResult = shell.presenter.send(sent.control, sent.values, port: shell.port)
            #expect(result == .accepted, "\(sent.control) \(sent.values): \(result.code)")
            let core: Core = try describe(shell)
            fingerprints.append(core.play.fingerprint)
        }
        let won: Core = try BinaryGardensTest.core(shell)
        #expect(won.play.stage == .won, "\(won.play.stage)")
        return fingerprints
    }

    /// Opens level 1, wins it in campaign with its witness and starts its replay; returns the shell, the witness and
    /// the won core (the presenter's feedback route is quiet and the controls are off screen).
    static func replaying(_ session: ExperienceSession) async throws
        -> (shell: Shell, actions: [BinaryGardensAction], prints: [String], won: Core) {
        let shell: Shell = try await Access.open(session, number: 1)
        Access.quiet(shell.presenter)
        shell.presenter.controlsDisappeared()
        let made: (actions: [BinaryGardensAction], fingerprints: [String]) = try witness(1)
        _ = try win(shell, actions: made.actions)
        let won: Core = try BinaryGardensTest.core(shell)
        let started: ActionResult = shell.presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let opened: Core = try describe(shell)
        #expect(opened.mode == .replay(level: 1))
        return (shell, made.actions, made.fingerprints, won)
    }

    /// The verified result of level `number` with its certified actions and the run as its trace and those actions
    /// spent, its stars by rule against the certified plan's action count, or `stars` when given (an edited result).
    static func result(_ number: Int, stars edited: Int? = nil) throws -> Progress.Result {
        let trace: [BinaryGardensAction] = try BinaryGardensTest.certifiedPlan(number) + [.run]
        let certified: Int = try Core.generated(number: number).plan.size
        let spent: Int = trace.count - 1
        let stars: Int = edited ?? Progress.stars(actionsSpent: spent, certified: certified)
        return Progress.Result(actionsSpent: spent, stars: stars, trace: trace, verified: true)
    }

    /// The honest result of level `number` with its stars edited to another value (1 … 3).
    static func edited(_ number: Int) throws -> Progress.Result {
        let honest: Progress.Result = try result(number)
        return try result(number, stars: honest.stars == 3 ? 2 : 3)
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

    /// A presenter outside any shell with the controls off screen (no player is made) and a quiet feedback route.
    static func freshPresenter() -> BinaryGardensPresenter {
        let presenter: BinaryGardensPresenter = BinaryGardensPresenter(reduceMotion: false, reduceFlashing: false)
        Access.quiet(presenter)
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
    static func logTexts(_ presenter: BinaryGardensPresenter) -> [String] {
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

    /// Expects the mirror's replay state and the panel's position line and Step and Stop values for position
    /// `position` of `length`.
    static func expectPanel(_ mirror: BinaryGardensMirror, position: Int, length: Int,
                            sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(mirror.replaying, sourceLocation: sourceLocation)
        #expect(mirror.replayAvailable == false, "no replay is offered during a replay", sourceLocation: sourceLocation)
        #expect(mirror.replayPosition == position, sourceLocation: sourceLocation)
        #expect(mirror.replayLength == length, sourceLocation: sourceLocation)
        #expect(mirror.replayPositionLabel == "Replay: action \(position) of \(length)", sourceLocation: sourceLocation)
        #expect(mirror.replayStepValue == "Action \(position) of \(length)", sourceLocation: sourceLocation)
        let actions: String = length == 1 ? "1 action" : "\(length) actions"
        #expect(mirror.replayStopValue == actions, sourceLocation: sourceLocation)
    }
}

@MainActor
@Suite(.serialized) struct BinaryGardensReplayTests {
    typealias Access = BinaryGardensA11y
    typealias Script = BinaryGardensReplayScript
    typealias Core = BinaryGardensExperienceCore
    typealias Plan = BinaryGardensFeedbackPlan
    typealias Rule = BinaryGardensExperienceRule
    typealias Presenter = BinaryGardensPresenter
    typealias Mirror = BinaryGardensMirror

    // MARK: Replay through the port (clarification Q4)

    /// Level 1 won in campaign with its certified witness, then replayed action by action through the port: every step
    /// accepted with the witness's fingerprint, announced as `after(old:new:)` names it, the mirror's position
    /// following; a won end without stars; a step past the end refused in words and logged; stop returns to the
    /// campaign at level 1. Before the win there is nothing to replay.
    @Test func replayReproducesTheWitnessFingerprintsActionByAction() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        presenter.controlsDisappeared()
        let opening: Core = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.mode == .campaign)
        #expect(presenter.mirror.replayAvailable == false, "nothing is stored before the first win")
        #expect(presenter.mirror.replaying == false)

        // Nothing to replay yet: Replay, Step and Stop are refused in words and logged by bare code.
        let early: Access.Recorder = Access.record(presenter)
        let none: (plan: Plan, code: String) = try Access.refused(shell, early, "replay.start", [1])
        #expect(none.code == Rule.noReplay, "\(none.code)")
        #expect(none.plan.text == "There is no saved solution to replay for this level.")
        #expect(presenter.refusalLog.last == Rule.noReplay)
        let stray: (plan: Plan, code: String) = try Access.refused(shell, early, "replay.step", [])
        #expect(stray.code == Rule.noReplay, "\(stray.code)")
        let strayStop: (plan: Plan, code: String) = try Access.refused(shell, early, "replay.stop", [])
        #expect(strayStop.code == Rule.noReplay, "\(strayStop.code)")
        Access.quiet(presenter)

        let witness: (actions: [BinaryGardensAction], fingerprints: [String]) = try Script.witness(1)
        let actions: [BinaryGardensAction] = witness.actions
        #expect(opening.play.fingerprint == witness.fingerprints[0], "the opening is the witness's start")
        let fingerprints: [String] = try Script.win(shell, actions: actions)
        #expect(fingerprints == witness.fingerprints, "the campaign win plays like the witness")
        let won: Core = try Access.core(shell)
        #expect(won.levelNumber == 1, "a campaign win stays on the level won")
        #expect(won.mode == .campaign)
        let stored: BinaryGardensProgress.Result = try #require(won.progress.solved[1])
        #expect(stored.verified)
        #expect(stored.trace == actions, "the trace is the winning ring, phase, luminosity and tilt actions, the run")
        let length: Int = stored.trace.count
        let starsBefore: [Int: Int] = presenter.mirror.stars
        #expect(starsBefore[1] == stored.stars)
        #expect(won.canReplay(level: 1))
        #expect(presenter.mirror.replayAvailable, "the panel offers Replay best solution")
        #expect(presenter.mirror.replayValue == "level 1")
        #expect(presenter.mirror.replaying == false)
        #expect(presenter.mirror.replayPosition == 0)
        #expect(presenter.mirror.replayLength == 0)

        // From here every routed plan is recorded.
        let recorder: Access.Recorder = Access.record(presenter)

        // Start: a fresh play of level 1 in replay mode, announced as a level change.
        recorder.clock.advance()
        let logBeforeStart: Int = presenter.feedbackLog.count
        let started: ActionResult = presenter.startReplay(port: shell.port)
        #expect(started == .accepted, "\(started.code)")
        let opened: Core = try Script.describe(shell)
        #expect(opened.mode == .replay(level: 1))
        #expect(opened.isReplaying)
        #expect(opened.levelNumber == 1)
        #expect(opened.replayPosition == 0, "a fresh play holds no ring, phase, luminosity, tilt or run record")
        #expect(opened.replayLength == length)
        #expect(opened.tutorial == .done, "the tutorial is done in replay")
        #expect(opened.shownTick == Core.openingTick)
        #expect(opened.play.fingerprint == witness.fingerprints[0], "the replay starts where the witness starts")
        #expect(opened.progress == won.progress)
        let startPlan: Plan = Plan.after(old: won, new: opened)
        let band: Int = BinaryGardensProgress.band(of: 1)
        #expect(startPlan.text == "Level 1, band \(band), replay.", "\(startPlan.text ?? "nil")")
        #expect(presenter.feedbackLog.count == logBeforeStart + 1, "the start routes one plan")
        #expect(presenter.feedbackLog.last == startPlan)
        #expect(recorder.announcements.announced.last == startPlan.text)
        Script.expectPanel(presenter.mirror, position: 0, length: length)
        #expect(presenter.mirror.mode == .replay(level: 1))
        #expect(presenter.mirror.modeLabel == "Mode: replay")
        #expect(Mirror.modeName(.replay(level: 1)) == Plan.modeName(.replay(level: 1)))

        // Every step reproduces the witness's fingerprint and is announced like the action it applies.
        var previous: Core = opened
        for k in 1...length {
            recorder.clock.advance()
            let logBefore: Int = presenter.feedbackLog.count
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: Core = try Script.describe(shell)
            #expect(core.mode == .replay(level: 1))
            #expect(core.replayPosition == k, "step \(k): one ring, phase, luminosity, tilt or run record per step")
            #expect(core.play.fingerprint == witness.fingerprints[k], "step \(k): the witness's fingerprint")
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
                let spent: Int = BinaryGardensProgress.actionsSpent(core.play)
                #expect(spent == length - 1, "the replay spends the trace's arrangement actions")
                #expect(plan.text == Script.replayWinText(spent: spent), "\(plan.text ?? "nil")")
                #expect(plan.text?.contains("stars") == false, "a replayed win claims no stars")
                #expect(plan.kind == .outcome)
                #expect(plan.haptic == .success)
            }
            Script.expectPanel(presenter.mirror, position: k, length: length)
            #expect(presenter.mirror.message == nil)
            previous = core
        }
        try BinaryGardensTest.draw(session)
        let finished: Core = try Access.core(shell)
        #expect(finished.play.stage == .won, "the replay ends won")
        #expect(finished.play.fingerprint == won.play.fingerprint)
        #expect(finished.progress == won.progress, "replay never changes progress")
        #expect(presenter.mirror.stars == starsBefore, "the replayed win claims no stars")

        // One step past the end is refused, shown, announced and logged by bare code.
        let past: (plan: Plan, code: String) = try Access.refused(shell, recorder, "replay.step", [])
        #expect(past.code == Rule.replayEnd, "\(past.code)")
        #expect(past.plan.text == "The replay is over.")
        #expect(presenter.mirror.message == "The replay is over.")
        #expect(presenter.refusalLog.last == Rule.replayEnd)
        Script.expectPanel(presenter.mirror, position: length, length: length)

        // Stop: back to the campaign at level 1, the replay offered again, the progress unchanged.
        recorder.clock.advance()
        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: Core = try Script.describe(shell)
        #expect(campaign.mode == .campaign)
        #expect(campaign.levelNumber == 1)
        #expect(campaign.replayPosition == 0)
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

    /// During replay `clock.show` scrubs the cycle at any step (the play, the digest and the position unchanged; the
    /// next step keeps the shown tick), `tutorial.dismiss` and `settings.sound` stay allowed, and every other control
    /// is refused with `r02-g21.replay` ("Stop the replay first.", shown, announced, an error haptic, logged by bare
    /// code), changing nothing, the progress included.
    @Test func tickScrubbingAllowedAndOtherActionsRefusedDuringReplay() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let state = try await Script.replaying(session)
        let shell: Script.Shell = state.shell
        let presenter: Presenter = shell.presenter
        let stepped: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(stepped == .accepted, "\(stepped.code)")
        let before: Core = try Script.describe(shell)
        #expect(before.replayPosition == 1)
        #expect(before.play.fingerprint == state.prints[1])
        let digest: String = try BinaryGardensTest.digest(shell)

        // Scrubbing the cycle: accepted, presentation only.
        for tick in Script.scrubTicks {
            let shown: ActionResult = presenter.send("clock.show", [Double(tick)], port: shell.port)
            #expect(shown == .accepted, "clock.show [\(tick)]: \(shown.code)")
            let core: Core = try Script.describe(shell)
            #expect(core.shownTick == tick)
            #expect(core.play == before.play, "tick \(tick): the play is unchanged")
            #expect(core.replayPosition == 1, "tick \(tick): the position is unchanged")
            #expect(core.mode == .replay(level: 1))
            #expect(presenter.mirror.shownTick == tick)
            #expect(presenter.mirror.replayPosition == 1)
            #expect(presenter.mirror.message == nil)
            let shownDigest: String = try BinaryGardensTest.digest(shell)
            #expect(shownDigest == digest, "tick \(tick): the shown tick is not in the digest")
        }
        let dismissed: ActionResult = presenter.dismissTutorial(port: shell.port)
        #expect(dismissed == .accepted, "tutorial.dismiss stays allowed: \(dismissed.code)")

        // Every other control is refused in the replay words.
        let recorder: Access.Recorder = Access.record(presenter)
        let next: (control: String, values: [Double]) = BinaryGardensTest.control(state.actions[1])
        var refusals: [(control: String, values: [Double])] = [next]
        refusals.append(("star.ring", [1, 0]))
        refusals.append(("star.phase", [1, 0]))
        refusals.append(("star.luminosity", [1, 0]))
        refusals.append(("orbit.tilt", [0]))
        refusals.append(("light.run", []))
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
        }
        #expect(Plan.refusalText(code: Rule.replay) == "Stop the replay first.")
        let after: Core = try Access.core(shell)
        #expect(after == before, "a refused action changes nothing")
        #expect(after.progress == state.won.progress, "the replay never changes progress")
        #expect(presenter.mirror.replaying)
        #expect(presenter.mirror.replayPosition == 1)
        #expect(presenter.mirror.replayLength == state.actions.count)

        // The sound setting stays allowed during replay and is not in the digest.
        let soundOn: ActionResult = presenter.saveSound(on: true, port: shell.port)
        #expect(soundOn == .accepted, "\(soundOn.code)")
        let sounding: Core = try Script.describe(shell)
        #expect(sounding.soundOn)
        #expect(sounding.mode == .replay(level: 1))
        #expect(presenter.mirror.soundOn)
        let soundOff: ActionResult = presenter.saveSound(on: false, port: shell.port)
        #expect(soundOff == .accepted, "\(soundOff.code)")
        let quiet: Core = try Script.describe(shell)
        #expect(quiet.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        let allowedDigest: String = try BinaryGardensTest.digest(shell)
        #expect(allowedDigest == digest, "the sound choice is not in the digest")

        // The next step after scrubbing still reproduces the witness and keeps the shown tick.
        let shownTick: Int = quiet.shownTick
        #expect(shownTick == Script.scrubTicks[Script.scrubTicks.count - 1])
        let second: ActionResult = presenter.stepReplay(port: shell.port)
        #expect(second == .accepted, "\(second.code)")
        let stepTwo: Core = try Script.describe(shell)
        #expect(stepTwo.replayPosition == 2)
        #expect(stepTwo.play.fingerprint == state.prints[2], "the second step is the witness's")
        #expect(stepTwo.shownTick == shownTick, "a step keeps the shown tick")
        #expect(presenter.mirror.shownTick == shownTick)
        #expect(stepTwo.progress == state.won.progress)
    }

    /// Replay never changes progress: through every step, a restart (`replay.start` during a replay) and a stop, the
    /// progress, its encoding, the frontier and the stars stay those of the campaign win.
    @Test func replayLeavesProgressUnchanged() async throws {
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let state = try await Script.replaying(session)
        let shell: Script.Shell = state.shell
        let presenter: Presenter = shell.presenter
        let encoded: Data = try state.won.progress.encoded()
        let stars: [Int: Int] = presenter.mirror.stars
        for k in 1...state.actions.count {
            let stepped: ActionResult = presenter.stepReplay(port: shell.port)
            #expect(stepped == .accepted, "step \(k): \(stepped.code)")
            let core: Core = try Script.describe(shell)
            #expect(core.progress == state.won.progress, "step \(k)")
            #expect(try core.progress.encoded() == encoded, "step \(k): the encoding is unchanged")
        }
        let ended: Core = try Access.core(shell)
        #expect(ended.play.stage == .won)

        // A restart replays from the start; the progress stays.
        let restarted: ActionResult = presenter.startReplay(port: shell.port)
        #expect(restarted == .accepted, "\(restarted.code)")
        let fresh: Core = try Script.describe(shell)
        #expect(fresh.mode == .replay(level: 1))
        #expect(fresh.replayPosition == 0)
        #expect(fresh.play.fingerprint == state.prints[0])
        #expect(try fresh.progress.encoded() == encoded)
        Script.expectPanel(presenter.mirror, position: 0, length: state.actions.count)

        let stopped: ActionResult = presenter.stopReplay(port: shell.port)
        #expect(stopped == .accepted, "\(stopped.code)")
        let campaign: Core = try Script.describe(shell)
        #expect(campaign.mode == .campaign)
        #expect(try campaign.progress.encoded() == encoded, "stopping the replay keeps the progress")
        #expect(campaign.progress.frontier == state.won.progress.frontier)
        #expect(presenter.mirror.stars == stars)
        #expect(presenter.mirror.frontier == state.won.progress.frontier)
    }

    // MARK: Dropped results (clarification Q2)

    /// A restored core whose verified result with edited stars was dropped is announced once, as `state`, by the
    /// presenter that describes it, however often it describes again; two dropped results read in the plural.
    @Test func droppedResultsAnnouncedOnce() throws {
        let opening: Core = try Core.opening(number: 1)
        let payload: Data = try opening.snapshotPayload()

        // Level 2's certified win recorded as verified, once honestly and once with edited stars.
        let honestResult: BinaryGardensProgress.Result = try Script.result(2)
        let editedResult: BinaryGardensProgress.Result = try Script.edited(2)
        #expect(editedResult.stars != honestResult.stars)
        let honest: Core = try Core.restore(payload: try Script.payload(payload, frontier: 3,
                                                                        results: [(2, honestResult)]), seed: 0)
        #expect(honest.reconciliationDropped == 0)
        #expect(honest.progress.solved[2] != nil, "the honest result is kept")
        let restored: Core = try Core.restore(payload: try Script.payload(payload, frontier: 3,
                                                                          results: [(2, editedResult)]), seed: 0)
        #expect(restored.reconciliationDropped == 1)
        #expect(restored.progress.solved[2] == nil, "the edited result is dropped")
        #expect(restored.progress.frontier == 3, "the frontier is restored as saved")
        #expect(restored.levelNumber == 1)

        let expected: String = "1 saved result could not be checked and was removed."
        #expect(Presenter.droppedText(1) == expected)
        #expect(Presenter.droppedText(2) == "2 saved results could not be checked and were removed.")
        let presenter: Presenter = Script.freshPresenter()
        let recorder: Access.Recorder = Access.record(presenter)
        recorder.clock.advance()
        _ = presenter.describe(restored)
        recorder.clock.advance()
        _ = presenter.describe(restored)
        #expect(presenter.droppedAnnounced)
        #expect(Script.count(expected, in: Script.logTexts(presenter)) == 1, "\(Script.logTexts(presenter))")
        var stateKinds: Int = 0
        var otherKinds: Int = 0
        for plan in presenter.feedbackLog where plan.text == expected {
            if plan.kind == .state && plan.haptic == nil && plan.trigger == Presenter.droppedTrigger {
                stateKinds += 1
            } else {
                otherKinds += 1
            }
        }
        #expect(stateKinds == 1, "announced as state, without a haptic")
        #expect(otherKinds == 0)

        // Describing again (the honest core and the restored one) never repeats the announcement.
        let followers: [Core] = [honest, restored]
        for follower in followers {
            recorder.clock.advance()
            _ = presenter.describe(follower)
        }
        recorder.clock.advance()
        presenter.feedback.flush()
        #expect(Script.count(expected, in: Script.logTexts(presenter)) == 1, "\(Script.logTexts(presenter))")
        let said: Int = Script.count(expected, in: recorder.announcements.announced)
        #expect(said == 1, "\(recorder.announcements.announced)")

        // Two dropped results (levels 2 and 3 edited) read in the plural, once.
        let two: Core = try Core.restore(payload: try Script.payload(payload, frontier: 4,
                                                                     results: [(2, editedResult),
                                                                               (3, try Script.edited(3))]), seed: 0)
        #expect(two.reconciliationDropped == 2)
        let plural: Presenter = Script.freshPresenter()
        _ = plural.describe(two)
        _ = plural.describe(two)
        let pluralText: String = "2 saved results could not be checked and were removed."
        #expect(Script.count(pluralText, in: Script.logTexts(plural)) == 1, "\(Script.logTexts(plural))")
        #expect(plural.feedbackLog.contains(Presenter.droppedPlan(2)))

        // A core with nothing dropped announces nothing.
        let clean: Presenter = Script.freshPresenter()
        _ = clean.describe(honest)
        #expect(clean.droppedAnnounced == false)
        #expect(clean.feedbackLog.isEmpty, "\(Script.logTexts(clean))")
    }

    // MARK: Sound choice (clarification Q5)

    /// A fresh presenter describing a core restored with `"sound": true` applies the choice at its first describe (off
    /// screen, nothing plays); the Sound toggle's path `saveSound(on:port:)` sends `settings.sound [1]` and `[0]`: the
    /// core's and the mirror's choice follow (as a bare core applying the same action), the digest does not change and
    /// a reopened save applies the choice again.
    @Test func savedSoundChoiceAppliedOnOpen() async throws {
        // The saved choice applied on open.
        let base: Core = try Core.opening(number: 1)
        #expect(base.soundOn == false, "the sound is off by default")
        let edited: Data = try Script.payload(try base.snapshotPayload(), sound: true)
        let restored: Core = try Core.restore(payload: edited, seed: 0)
        #expect(restored.soundOn)
        let fresh: Presenter = Script.freshPresenter()
        #expect(fresh.mirror.soundOn == false)
        #expect(fresh.sound.wanted == false)
        _ = fresh.describe(restored)
        #expect(fresh.mirror.soundOn, "the restored choice is applied")
        #expect(fresh.sound.wanted)
        #expect(fresh.sound.recipe == Presenter.recipe(restored), "the loop holds the opened play's recipe")
        #expect(fresh.sound.shouldPlay == false, "off screen, nothing plays")
        #expect(fresh.sound.playersMade == 0)
        #expect(fresh.feedbackLog.isEmpty, "applying the saved choice is not announced")

        // A saved choice of off is applied on open too (a presenter-held choice does not survive the state).
        let offPresenter: Presenter = Script.freshPresenter()
        offPresenter.setSound(on: true)
        _ = offPresenter.describe(base)
        #expect(offPresenter.mirror.soundOn == false, "the state's choice wins at the first describe")
        #expect(offPresenter.sound.wanted == false)

        // The Sound toggle's path through the shell's port.
        let session: ExperienceSession = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Access.open(session, number: 1)
        let presenter: Presenter = shell.presenter
        Access.quiet(presenter)
        presenter.controlsDisappeared()
        let before: Core = try Access.core(shell)
        #expect(before.soundOn == false)
        #expect(presenter.mirror.soundOn == false)
        let digest: String = try BinaryGardensTest.digest(shell)

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
        let onDigest: String = try BinaryGardensTest.digest(shell)
        #expect(onDigest == digest, "the sound choice is not in the digest")
        #expect(on.play.fingerprint == before.play.fingerprint)
        #expect(on.progress == before.progress)
        let reopened: Core = try Core.restore(payload: try on.snapshotPayload(), seed: 0)
        #expect(reopened.soundOn, "the saved choice is in the snapshot")
        let second: Presenter = Script.freshPresenter()
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
        let offDigest: String = try BinaryGardensTest.digest(shell)
        #expect(offDigest == digest)
    }

    // MARK: The panel (FR-R02G2107-008)

    /// Replay, Step and Stop carry a label and a value in the panel's source; the Sound toggle saves through
    /// `settings.sound`; the native actions cover the four new controls.
    @Test func replayControlsHaveLabelsValuesAndNativeActions() throws {
        let source: String = try Access.panelSource()
        let names: [String] = ["replay", "replay-step", "replay-stop"]
        for name in names {
            let run: Substring? = Access.modifierRun(name, in: source)
            #expect(run != nil, "\(name) has its identifier")
            #expect(run?.contains(".accessibilityLabel(") == true, "\(name) has a label")
            #expect(run?.contains(".accessibilityValue(") == true, "\(name) has a value")
        }
        #expect(Access.modifierRun("replay", in: source)?.contains("mirror.replayValue") == true)
        #expect(Access.modifierRun("replay-step", in: source)?.contains("mirror.replayStepValue") == true)
        #expect(Access.modifierRun("replay-stop", in: source)?.contains("mirror.replayStopValue") == true)
        #expect(source.contains(".accessibilityIdentifier(port.identifier(\"replay-position\"))"))
        #expect(source.contains("Text(mirror.replayPositionLabel)"))
        #expect(source.contains("presenter.saveSound(on: on, port: port)"))
        let presenter: Presenter = Presenter(reduceMotion: false, reduceFlashing: false)
        let added: Set<String> = ["replay.start", "replay.step", "replay.stop", "settings.sound"]
        #expect(added.isSubset(of: presenter.nativeActions))
        #expect(presenter.nativeActions == Set(Core.actionIDs))
        let mirror: Mirror = presenter.mirror
        mirror.replayPosition = 1
        mirror.replayLength = 1
        #expect(mirror.replayPositionLabel == "Replay: action 1 of 1")
        #expect(mirror.replayStepValue == "Action 1 of 1")
        #expect(mirror.replayStopValue == "1 action")
    }
}
#endif
