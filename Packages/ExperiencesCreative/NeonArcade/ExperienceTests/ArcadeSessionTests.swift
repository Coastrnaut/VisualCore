// ArcadeSessionTests — feature 075 (A10-P01) T-A10-104 (FR-A10-112, FR-A10-120, FR-A10-121, FR-A10-122; story 1
// scenario 1; story 2 scenario 2; story 4 scenarios 1–4; SC-A10-101, SC-A10-102, SC-A10-105). The A10 adapter inside
// the one app's session host on the simulator, short runs only (each test well under 10 s, no wall-clock assertion):
// the first frame draws a new run and describes it in words; each drawn frame advances one step and objects begin to
// fall; pause stops the run; a suspension of any wall-clock length does not advance the step count and the resume
// continues from the same step (no catch-up); frames of 1/30, 1/60 and 1/120 s give the same run after the same steps
// as the bare replay; the state saved by the shell restores identically in a new session; newer and damaged saved
// states are refused and a new run opens; Reduce Motion halves the glow pulse and the background drift but never
// changes the state; reopening keeps the drawing resources steady.
// Feature 076 (A10-P02) T-A10-203 (FR-A10-211; SC-A10-204): a session restored in wave 3 and suspended for several
// lengths (with frames requested meanwhile) keeps wave, wave step, step, objects and score identical, and the resume
// continues from the same step; the description names the wave.
// Feature 077 (A10-P03) T-A10-304 (FR-A10-310, FR-A10-320, FR-A10-321; SC-A10-301, SC-A10-304; edge cases "leaving
// the app while playing", "pausing during a burst", "restoring a saved game in the title or game-over screen"): a new
// experience shows the title screen, says so and advances nothing until Start; a suspension while playing records
// `run.pause [1]` (the paused screen returns, nothing advanced) and stops the sounds, while a suspension on the title
// screen sends nothing; the digests are identical with reduced flashing, with the effects drawn or not, and the run
// identical with sound and haptics on or off; the injected sound and haptic sinks receive the cues only while their
// setting is on; the effects freeze while paused; a saved title or game-over screen restores to the same screen;
// schema 4 was the newer saved state (since feature 078 the schema after the current one is).
// Feature 078 (A10-P04) T-A10-403 (FR-A10-401, FR-A10-402, FR-A10-411–413, FR-A10-420, FR-A10-421; SC-A10-401–404):
// a run played to game over in a session is entered into the high-score table in a temporary storage once, marked,
// announced as a new high score and named in the description, and restoring its game-over screen in a new session
// enters nothing again; announcements are at most one per second over a run with many events and name the hits and
// the game over; the same finger offset gives a different, bounded steering value for each sensitivity step, in a
// session too, and every gesture keeps a native alternative; every control is labelled with a value or hint, and the
// controls grow with Dynamic Type.
// Feature 079 (A10-P05) T-A10-503 (FR-A10-501, FR-A10-503; SC-A10-501; edge case "Low Power Mode and the host's
// level"): the experience shows the core's three-level profile to the session; a pinned level reaches the presenter
// (level 0 the best → budget level 2) and a level changed mid-run keeps the shapes, the state and the digest of the
// same run drawn without changes; Low Power Mode draws level 0 whatever the host's level, also when it turns on and
// off mid-run, and never changes the state.
import Foundation
import SwiftUI
import UIKit
import XCTest
import VisualCoreDiagnostics
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation

@MainActor
final class ArcadeSessionTests: XCTestCase {
    func testTheFirstFrameDrawsANewRunAndDescribesIt() async throws {
        XCTAssertEqual(NeonArcadeExperience.id?.rawValue, "a10.neon-arcade")
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        XCTAssertGreaterThan(presenter.lastScale, 0)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        let core = try ArcadeTest.core(shell)
        XCTAssertEqual(core.run.score, 0)
        XCTAssertEqual(core.run.lives, 3)
        XCTAssertEqual(presenter.lastScoreText, "0")
        XCTAssertEqual(presenter.lastLivesLit, 3)
        let summary = shell.accessibilitySummary
        XCTAssertTrue(summary.hasPrefix("Neon Arcade: Neon Dodge, wave 1, score 0, 3 lives, "), summary)
        XCTAssertTrue(summary.hasSuffix("playing."), summary)
        XCTAssertTrue(presenter.mirror.ready)
        XCTAssertEqual(presenter.nativeActions, Set(ArcadeCore.actionIDs))
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])

        XCTAssertTrue(shell.handle(control: "run.pause", values: [1]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("paused."), shell.accessibilitySummary)
        XCTAssertTrue(presenter.mirror.paused)
        XCTAssertTrue(presenter.mirror.status.hasSuffix("paused"), presenter.mirror.status)

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertFalse(presenter.isLive)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testFramesAdvanceTheRunAndPauseStopsIt() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session)
        let before = try ArcadeTest.core(shell)
        XCTAssertTrue(shell.handle(control: "run.steer", values: [1]).isAccepted)
        try ArcadeTest.frames(session, 60)
        let after = try ArcadeTest.core(shell)
        XCTAssertGreaterThan(after.run.step, before.run.step)
        XCTAssertLessThanOrEqual(after.run.step - before.run.step, 62, "about one step per 1/60 s frame")
        XCTAssertGreaterThan(after.run.player.x, before.run.player.x, "steering right moves the player right")
        XCTAssertGreaterThan(after.run.nextObjectId, 0, "objects fall within the first second of game time")
        XCTAssertGreaterThan(shell.presenter.lastObjectsDrawn, 0)

        XCTAssertTrue(shell.handle(control: "run.pause", values: [1]).isAccepted)
        let paused = try ArcadeTest.core(shell)
        try ArcadeTest.frames(session, 30)
        XCTAssertEqual(try ArcadeTest.core(shell), paused, "nothing moves while paused")

        XCTAssertTrue(shell.handle(control: "run.pause", values: [0]).isAccepted)
        try ArcadeTest.frames(session, 5)
        XCTAssertGreaterThan(try ArcadeTest.core(shell).run.step, paused.run.step)
        session.close()
    }

    /// T-A10-304 (edge case "leaving the app while playing"): a suspension while playing records `run.pause [1]`
    /// through the port and stops the sounds; nothing advances while away; the paused screen returns and resuming
    /// continues from the same step.
    func testASuspensionWhilePlayingRecordsAPauseAndAdvancesNothing() async throws {
        let session = ExperienceSession()
        let sound = RecordingSoundSink()
        let experience = try await ArcadeTest.openExperience(session, soundSink: sound)
        let shell = experience.shell
        try ArcadeTest.frames(session, 45)
        let before = try ArcadeTest.core(shell)
        XCTAssertEqual(before.screen, .playing)
        let stepIndex = shell.engine.stepIndex
        let accepted = shell.engine.acceptedActions
        let stops = sound.stops
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        XCTAssertEqual(shell.engine.acceptedActions, accepted + 1, "one recorded action")
        XCTAssertGreaterThan(sound.stops, stops, "the sounds stop on suspension")
        let paused = try ArcadeTest.core(shell)
        XCTAssertEqual(paused.screen, .paused, "the game moved to the paused screen")
        XCTAssertTrue(paused.run.paused)
        XCTAssertEqual(paused.run.step, before.run.step)
        XCTAssertEqual(paused.run.objects, before.run.objects)
        for _ in 0..<10 { _ = session.renderHost?.renderOneFrame(present: false) }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(try ArcadeTest.core(shell), paused, "nothing moves while suspended")
        XCTAssertEqual(shell.engine.stepIndex, stepIndex)

        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        try ArcadeTest.frames(session, 5)
        XCTAssertEqual(try ArcadeTest.core(shell), paused, "the paused screen returns; nothing fast-forwards")
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("paused."), shell.accessibilitySummary)
        XCTAssertTrue(shell.handle(control: "run.pause", values: [0]).isAccepted)
        try ArcadeTest.frames(session, 1)
        let resumed = try ArcadeTest.core(shell)
        XCTAssertLessThanOrEqual(resumed.run.step - before.run.step, 2, "one frame's steps, never the suspended time")
        XCTAssertGreaterThan(resumed.run.step, before.run.step)
        session.close()
    }

    /// T-A10-304: a suspension on the title screen sends nothing (the digest stays) and the title returns.
    func testASuspensionOnTheTitleScreenSendsNothing() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, start: false)
        let digest = try shell.engine.digest()
        session.setScenePhase(.background)
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.setScenePhase(.active)
        try ArcadeTest.frames(session, 10)
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertEqual(try ArcadeTest.core(shell).screen, .title)
        session.close()
    }

    /// The saved state of seed 7 after the wave fixture's inputs to step 1,300: wave 3 (`wall`), alive.
    private func waveThreeSnapshot() async throws -> ExperienceSnapshot {
        var engine = ExperienceEngine<ArcadeCore>(id: ArcadeTest.id)
        try await engine.prepare(seed: 7)
        try engine.activate()
        XCTAssertEqual(engine.handle(control: "run.start"), .accepted)
        for input in ArcadeCore.waveInputs where input.step < ArcadeCore.waveThreeSteps {
            try engine.run(steps: input.step - engine.stepIndex)
            XCTAssertEqual(engine.handle(control: "run.steer", values: [input.value]), .accepted)
        }
        try engine.run(steps: ArcadeCore.waveThreeSteps - engine.stepIndex)
        let run = try XCTUnwrap(engine.core).run
        XCTAssertEqual(run.wave, 3)
        XCTAssertFalse(run.over)
        return try engine.snapshot()
    }

    /// T-A10-203 (SC-A10-204): suspensions of 0, 50 and 250 ms in wave 3, with 1, 10 and 60 frames requested while
    /// suspended, leave wave, wave step, step, objects and score identical; each resume continues from the same step.
    /// Since feature 077 the first suspension pauses the game (the later ones find it paused), so the resume shows the
    /// paused screen and the game continues after `run.pause [0]`.
    func testASuspensionOfAnyLengthInWaveThreeChangesNothing() async throws {
        let snapshot = try await waveThreeSnapshot()
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, snapshot: snapshot)
        XCTAssertNil(session.lastRestoreRefusal)
        XCTAssertEqual(try ArcadeTest.core(shell).run.wave, 3)
        XCTAssertTrue(shell.accessibilitySummary.contains("wave 3"), shell.accessibilitySummary)
        for (milliseconds, frames) in [(0, 1), (50, 10), (250, 60)] {
            let before = try ArcadeTest.core(shell)
            let stepIndex = shell.engine.stepIndex
            session.setScenePhase(.background)
            XCTAssertEqual(shell.state, .suspended)
            for _ in 0..<frames { _ = session.renderHost?.renderOneFrame(present: false) }
            if milliseconds > 0 { try await Task.sleep(for: .milliseconds(milliseconds)) }
            let held = try ArcadeTest.core(shell)
            XCTAssertEqual(held.run.wave, before.run.wave, "\(milliseconds) ms")
            XCTAssertEqual(held.run.waveStep, before.run.waveStep, "\(milliseconds) ms")
            XCTAssertEqual(held.run.step, before.run.step, "\(milliseconds) ms")
            XCTAssertEqual(held.run.objects, before.run.objects, "\(milliseconds) ms")
            XCTAssertEqual(held.run.score, before.run.score, "\(milliseconds) ms")
            XCTAssertEqual(held.screen, .paused, "\(milliseconds) ms: the suspension paused the game")
            XCTAssertEqual(shell.engine.stepIndex, stepIndex)

            session.setScenePhase(.active)
            XCTAssertEqual(shell.state, .active)
            XCTAssertEqual(try ArcadeTest.core(shell), held, "the resume continues from the same step")
            try ArcadeTest.frames(session, 1)
            let resumed = try ArcadeTest.core(shell)
            XCTAssertLessThanOrEqual(resumed.run.step - before.run.step, 2,
                                     "one frame's steps, never the suspended time")
            XCTAssertEqual(resumed.run.wave, 3)
        }
        XCTAssertTrue(shell.handle(control: "run.pause", values: [0]).isAccepted)
        let paused = try ArcadeTest.core(shell)
        try ArcadeTest.frames(session, 1)
        let playing = try ArcadeTest.core(shell)
        XCTAssertGreaterThan(playing.run.step, paused.run.step)
        XCTAssertLessThanOrEqual(playing.run.step - paused.run.step, 2)
        session.close()
    }

    /// Steering inputs at even steps, so frames of 1/30 s (two steps each) reach every one of them.
    private static let pacedInputs: [(step: Int, value: Double)] = [
        (0, 0.6), (44, -0.3), (120, -1.0), (210, 0.25), (300, 1.0), (390, 0.0), (480, -0.75), (600, 0.5),
    ]
    private static let pacedSteps = 720

    func testFramePacingGivesTheSameRunAfterTheSameSteps() async throws {
        let id = ArcadeTest.id
        // The bare replay: the start, the inputs applied at their steps, the steps run one by one.
        var reference = ArcadeCore(seed: 7)
        XCTAssertEqual(reference.apply(ExperienceAction(control: "run.start", values: [], step: 0)), .accepted)
        for step in 0..<Self.pacedSteps {
            for input in Self.pacedInputs where input.step == step {
                XCTAssertEqual(reference.apply(ExperienceAction(control: "run.steer", values: [input.value],
                                                                step: step)), .accepted)
            }
            reference.update(step: step)
        }
        XCTAssertGreaterThan(reference.run.nextObjectId, 0)

        var digests: [String] = []
        for delta in [1.0 / 30, 1.0 / 60, 1.0 / 120] {
            var engine = ExperienceEngine<ArcadeCore>(id: id)
            try await engine.prepare(seed: 7)
            try engine.activate()
            XCTAssertEqual(engine.handle(control: "run.start"), .accepted)
            var pending = Self.pacedInputs
            var frames = 0
            while engine.stepIndex < Self.pacedSteps, frames < 4 * Self.pacedSteps {
                while let next = pending.first, next.step == engine.stepIndex {
                    XCTAssertEqual(engine.handle(control: "run.steer", values: [next.value]), .accepted)
                    pending.removeFirst()
                }
                if let next = pending.first {
                    XCTAssertGreaterThan(next.step, engine.stepIndex, "frame \(delta): an input step was skipped")
                }
                try engine.advance(frame: delta)
                frames += 1
            }
            XCTAssertTrue(pending.isEmpty, "every input applied at \(delta)")
            XCTAssertEqual(engine.stepIndex, Self.pacedSteps, "frames of \(delta) s")
            let core = try XCTUnwrap(engine.core)
            XCTAssertEqual(core.run.score, reference.run.score, "frames of \(delta) s")
            XCTAssertEqual(core.run.lives, reference.run.lives, "frames of \(delta) s")
            XCTAssertEqual(core.run.events, reference.run.events, "frames of \(delta) s")
            XCTAssertEqual(core.run.eventCount, reference.run.eventCount, "frames of \(delta) s")
            XCTAssertEqual(core, reference, "frames of \(delta) s")
            digests.append(try engine.digest().hex)
        }
        XCTAssertEqual(Set(digests).count, 1, "the same digest at 1/30, 1/60 and 1/120 s")
    }

    func testTheSavedStateRestoresIdenticallyInANewSession() async throws {
        let first = ExperienceSession()
        let shell = try await ArcadeTest.open(first)
        XCTAssertTrue(shell.handle(control: "run.steer", values: [-0.6]).isAccepted)
        try ArcadeTest.frames(first, 90)
        let snapshot = try shell.snapshot()
        let saved = try ArcadeTest.core(shell)
        XCTAssertFalse(saved.run.objects.isEmpty, "a mid-run state with falling objects")
        first.close()

        let second = ExperienceSession()
        let restored = try await ArcadeTest.open(second, seed: 3)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let core = try ArcadeTest.core(restored)
        XCTAssertEqual(core.state, saved.state, "step, score, lives, player, objects and generator are identical")
        second.close()
    }

    func testANewerSavedStateIsRefusedAndANewRunOpens() async throws {
        let first = ExperienceSession()
        let shell = try await ArcadeTest.open(first)
        try ArcadeTest.frames(first, 60)
        let saved = try shell.snapshot()
        first.close()
        let newer = try ExperienceSnapshot(experience: ArcadeTest.id, schemaVersion: ArcadeCore.snapshotSchema + 1,
                                           seed: saved.seed, stepIndex: saved.stepIndex, digest: saved.digest,
                                           payload: Data(saved.payload.utf8))

        let second = ExperienceSession()
        let opened = try await ArcadeTest.open(second, snapshot: newer)
        XCTAssertNotNil(second.lastRestoreRefusal, "the newer state is refused")
        let core = try ArcadeTest.core(opened)
        XCTAssertLessThanOrEqual(core.run.step, 2, "a new run opens")
        XCTAssertEqual(core.run.score, 0)
        XCTAssertEqual(core.run.lives, 3)
        XCTAssertThrowsError(try opened.restore(newer))
        second.close()
    }

    func testADamagedSavedStateIsRefusedAndANewRunOpens() async throws {
        let first = ExperienceSession()
        let shell = try await ArcadeTest.open(first)
        try ArcadeTest.frames(first, 60)
        let saved = try shell.snapshot()
        first.close()
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(saved.payload.utf8)) as? [String: Any])
        var run = try XCTUnwrap(object["run"] as? [String: Any])
        run["lives"] = 7
        object["run"] = run
        let payload = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let damaged = try ExperienceSnapshot(experience: ArcadeTest.id, schemaVersion: saved.schemaVersion,
                                             seed: saved.seed, stepIndex: saved.stepIndex, digest: saved.digest,
                                             payload: payload)

        let second = ExperienceSession()
        let opened = try await ArcadeTest.open(second, snapshot: damaged)
        XCTAssertNotNil(second.lastRestoreRefusal, "an invalid run is refused")
        let core = try ArcadeTest.core(opened)
        XCTAssertLessThanOrEqual(core.run.step, 2, "a new run opens")
        XCTAssertEqual(core.run.lives, 3)
        XCTAssertThrowsError(try opened.restore(damaged))
        second.close()
    }

    func testReduceMotionHalvesPulseAndDriftButNeverChangesTheState() async throws {
        let full = ExperienceSession()
        let fullShell = try await ArcadeTest.open(full)
        try ArcadeTest.frames(full, 40)
        let reduced = ExperienceSession()
        let reducedShell = try await ArcadeTest.open(reduced, reduceMotion: true)
        try ArcadeTest.frames(reduced, 40)
        XCTAssertEqual(fullShell.presenter.lastPulseAmount, ArcadePresenter.glowPulse)
        XCTAssertEqual(reducedShell.presenter.lastPulseAmount, ArcadePresenter.glowPulse / 2)
        XCTAssertEqual(fullShell.presenter.lastDriftAmount, ArcadePresenter.driftSpeed)
        XCTAssertEqual(reducedShell.presenter.lastDriftAmount, ArcadePresenter.driftSpeed / 2)
        let a = try ArcadeTest.core(fullShell), b = try ArcadeTest.core(reducedShell)
        XCTAssertEqual(a.state, b.state, "the preference is presentation only")
        XCTAssertEqual(try fullShell.engine.digest(), try reducedShell.engine.digest())
        full.close()
        reduced.close()
    }

    func testReopeningFiveTimesKeepsTheDrawingResourcesSteady() async throws {
        var reference: ResourceLedger.Snapshot?
        for cycle in 1...5 {
            let session = ExperienceSession()
            let shell = try await ArcadeTest.open(session)
            XCTAssertTrue(shell.handle(control: "run.steer", values: [0.5]).isAccepted)
            try ArcadeTest.frames(session, 40)
            let stats = try XCTUnwrap(session.renderHost).resources.stats
            XCTAssertEqual(stats.leaked, 0, "cycle \(cycle)")
            if let reference {
                XCTAssertEqual(stats.liveCount, reference.liveCount, "cycle \(cycle): the same live objects per kind")
                XCTAssertEqual(stats.liveBytes, reference.liveBytes, "cycle \(cycle): the same live bytes per kind")
            } else {
                reference = stats
            }
            session.close()
        }
    }

    // MARK: Feature 077 (A10-P03)

    /// An active engine of seed `seed`, started unless `start` is false, with `settings` applied.
    private func engine(seed: UInt64 = 7, start: Bool = true,
                        settings: [(String, Double)] = []) async throws -> ExperienceEngine<ArcadeCore> {
        var engine = ExperienceEngine<ArcadeCore>(id: ArcadeTest.id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        if start { XCTAssertEqual(engine.handle(control: "run.start"), .accepted) }
        for (control, value) in settings { XCTAssertEqual(engine.handle(control: control, values: [value]), .accepted) }
        return engine
    }

    /// Plays `steps` steps of `engine` one by one, handing every state to `presenter` as a drawn frame of 1/60 s.
    private func play(_ engine: inout ExperienceEngine<ArcadeCore>, steps: Int, presenter: ArcadePresenter) throws {
        for _ in 0..<steps {
            try engine.run(steps: 1)
            presenter.advancePresentation(try XCTUnwrap(engine.core), seconds: 1.0 / 60)
        }
    }

    /// T-A10-304 (story 1 scenario 1; FR-A10-310): a new experience shows the title screen, says so and advances
    /// nothing until Start; Start plays.
    func testANewExperienceOpensOnTheTitleScreen() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, start: false)
        let presenter = shell.presenter
        let first = try ArcadeTest.core(shell)
        XCTAssertEqual(first.screen, .title)
        try ArcadeTest.frames(session, 60)
        XCTAssertEqual(try ArcadeTest.core(shell), first, "nothing falls until the person starts")
        XCTAssertEqual(shell.accessibilitySummary,
                       "Neon Arcade: Neon Dodge, wave 1, score 0, 3 lives, no objects falling, best score none, title screen.")
        XCTAssertEqual(presenter.mirror.screen, .title)
        XCTAssertTrue(presenter.mirror.status.hasSuffix("title screen"), presenter.mirror.status)
        XCTAssertEqual(presenter.lastStateMark, "title")
        XCTAssertEqual(ArcadeControls.startTitle(presenter.mirror.screen), "Start")
        XCTAssertFalse(ArcadeControls.canPause(.title))
        XCTAssertFalse(ArcadeControls.canRestart(.title))
        XCTAssertEqual(shell.port.send("run.pause", [1]), .rejected(.rule(code: ArcadeRule.wrongScreen)))
        XCTAssertTrue(shell.port.send("run.start").isAccepted)
        try ArcadeTest.frames(session, 30)
        let playing = try ArcadeTest.core(shell)
        XCTAssertEqual(playing.screen, .playing)
        XCTAssertGreaterThan(playing.run.step, 0)
        XCTAssertEqual(presenter.mirror.screen, .playing)
        XCTAssertNil(ArcadeControls.startTitle(.playing))
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("playing."), shell.accessibilitySummary)
        XCTAssertEqual(presenter.nativeActions, Set(ArcadeCore.actionIDs))
        session.close()
    }

    /// T-A10-304 (edge case "restoring a saved game in the title or game-over screen"; story 1 scenario 3): a saved
    /// title screen and a saved game-over screen restore to the same screen in a new session, which speaks it and
    /// draws the game over with the run's score and wave; Play again starts a new run in wave 1.
    func testASavedTitleOrGameOverScreenRestoresToTheSameScreen() async throws {
        let first = ExperienceSession()
        let title = try await ArcadeTest.open(first, start: false)
        let titleSnapshot = try title.snapshot()
        first.close()
        let second = ExperienceSession()
        let restoredTitle = try await ArcadeTest.open(second, snapshot: titleSnapshot, start: false)
        XCTAssertNil(second.lastRestoreRefusal)
        XCTAssertEqual(try ArcadeTest.core(restoredTitle).screen, .title)
        XCTAssertTrue(restoredTitle.accessibilitySummary.hasSuffix("title screen."))
        second.close()

        var over = GameRun.new()
        over.lives = 0
        over.over = true
        over.step = 1_400
        over.score = 88
        over.wave = 3
        over.waveStep = 200
        over.patternId = "wall"
        over.freeLane = 1
        let core = try ArcadeCore.restore(payload: ArcadeCore.encode(ArcadeState(
            run: over, random: SeededRandom(seed: 7).state, screen: .over)), seed: 7)
        var builder = DigestBuilder(domain: ArcadeTest.id.rawValue)
        try core.writeDigest(into: &builder)
        let overSnapshot = try ExperienceSnapshot(experience: ArcadeTest.id, schemaVersion: ArcadeCore.snapshotSchema,
                                                  seed: 7, stepIndex: 1_400, digest: builder.finish(),
                                                  payload: core.snapshotPayload())
        let third = ExperienceSession()
        let restoredOver = try await ArcadeTest.open(third, snapshot: overSnapshot)
        XCTAssertNil(third.lastRestoreRefusal)
        XCTAssertEqual(try ArcadeTest.core(restoredOver).screen, .over)
        try ArcadeTest.frames(third, 30)
        XCTAssertEqual(try ArcadeTest.core(restoredOver).state, core.state, "nothing advances on the game over")
        XCTAssertEqual(restoredOver.accessibilitySummary,
                       "Neon Arcade: Neon Dodge, wave 3, score 88, no lives, no objects falling, best score 88, over.")
        XCTAssertEqual(restoredOver.presenter.lastStateMark, "over")
        XCTAssertEqual(restoredOver.presenter.lastOverScoreText, "88")
        XCTAssertEqual(restoredOver.presenter.lastOverWaveText, "3")
        XCTAssertEqual(ArcadeControls.startTitle(.over), "Play again")
        XCTAssertTrue(restoredOver.port.send("run.start").isAccepted)
        let again = try ArcadeTest.core(restoredOver)
        XCTAssertEqual(again.screen, .playing)
        XCTAssertEqual(again.run, GameRun.new(), "a new run in wave 1")
        third.close()
    }

    /// T-A10-304 (SC-A10-304; story 2 scenario 3): the effects never change the game. Sessions with and without
    /// reduced flashing (effects drawn either way) give identical digests; with sound and haptics off the run and the
    /// generator are identical too (the settings themselves are saved in the state).
    func testDigestsAreIdenticalWithEffectsSoundAndHapticsOnOrOff() async throws {
        var digests: [String] = []
        var states: [ArcadeState] = []
        var bursts: [Int] = []
        for (reduceFlashing, settingsOff) in [(false, false), (true, false), (false, true)] {
            let session = ExperienceSession()
            let shell = try await ArcadeTest.openExperience(session, reduceFlashing: reduceFlashing).shell
            XCTAssertEqual(shell.presenter.reduceFlashing, reduceFlashing)
            if settingsOff {
                XCTAssertTrue(shell.handle(control: "settings.sound", values: [0]).isAccepted)
                XCTAssertTrue(shell.handle(control: "settings.haptics", values: [0]).isAccepted)
            }
            XCTAssertTrue(shell.handle(control: "run.steer", values: [-1]).isAccepted)
            try ArcadeTest.frames(session, 400)
            let core = try ArcadeTest.core(shell)
            XCTAssertTrue(core.run.events.contains { $0.kind == .hit }, "a hit happened")
            bursts.append(shell.presenter.effects.burstCount)
            states.append(core.state)
            digests.append(try shell.engine.digest().hex)
            session.close()
        }
        XCTAssertTrue(bursts.allSatisfy { $0 > 0 }, "effects were started: \(bursts)")
        XCTAssertEqual(digests[0], digests[1], "reduced flashing changes the drawing only")
        XCTAssertEqual(states[0], states[1])
        XCTAssertEqual(states[0].run, states[2].run, "the run is the same with sound and haptics off")
        XCTAssertEqual(states[0].random, states[2].random)
        XCTAssertFalse(states[2].sound || states[2].haptics)
        var settingsOn = states[2]
        settingsOn.sound = true
        settingsOn.haptics = true
        XCTAssertEqual(settingsOn, states[0])
        XCTAssertNotEqual(digests[0], digests[2], "the settings are saved in the digest")
    }

    /// T-A10-304 (FR-A10-321; story 2 scenarios 1, 2 and 4): the injected sound and haptic sinks receive the cues of
    /// pickups, hits and waves only while their setting is on.
    func testTheSoundAndHapticSinksReceiveCuesOnlyWhenEnabled() async throws {
        var results: [(sounds: [String], haptics: [HapticKind], bursts: Int)] = []
        let variants: [[(String, Double)]] = [[], [("settings.sound", 0)], [("settings.haptics", 0)]]
        for settings in variants {
            let sound = RecordingSoundSink()
            let haptics = RecordingHapticSink()
            let presenter = ArcadePresenter(experienceID: ArcadeTest.id, soundSink: sound,
                                            feedback: ArcadeTest.feedback(haptics))
            var engine = try await engine(settings: settings)
            presenter.advancePresentation(try XCTUnwrap(engine.core), seconds: 0)
            try play(&engine, steps: ArcadeCore.firstHitSteps, presenter: presenter)
            results.append((sound.played, haptics.played, presenter.effects.burstCount))
        }
        let all = results[0]
        XCTAssertTrue(all.sounds.contains("hit"), "\(all.sounds)")
        XCTAssertTrue(all.sounds.contains("wave"), "wave 2 starts at step 600: \(all.sounds)")
        XCTAssertTrue(all.haptics.contains(.impactHeavy))
        XCTAssertTrue(all.haptics.contains(.selection))
        XCTAssertEqual(all.sounds.count, all.haptics.count, "each sound with its haptic")
        XCTAssertEqual(results[1].sounds, [], "sound off: nothing plays")
        XCTAssertEqual(results[1].haptics, all.haptics, "haptics still play")
        XCTAssertEqual(results[2].haptics, [], "haptics off: nothing is felt")
        XCTAssertEqual(results[2].sounds, all.sounds, "sounds still play")
        XCTAssertEqual(Set(results.map(\.bursts)).count, 1, "the visual effects do not depend on the settings")
        XCTAssertEqual(ArcadeSoundPlayer.effect(.hit)?.waveform, .triangle)
        for sound in ArcadeSound.all { XCTAssertEqual(ArcadeSoundPlayer.effect(sound)?.isValid, true, sound.id) }
    }

    /// T-A10-304 (edge case "pausing during a burst"): the effects advance by game steps only, so they freeze while
    /// the game is paused and move again after the resume.
    func testTheEffectsFreezeWhilePaused() async throws {
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id, soundSink: RecordingSoundSink(),
                                        feedback: ArcadeTest.feedback(RecordingHapticSink()))
        var engine = try await engine()
        XCTAssertEqual(engine.handle(control: "run.steer", values: [-1]), .accepted)
        presenter.advancePresentation(try XCTUnwrap(engine.core), seconds: 0)
        var steps = 0
        while presenter.effects.rings.isEmpty, steps < 600 {
            try play(&engine, steps: 1, presenter: presenter)
            steps += 1
        }
        XCTAssertFalse(presenter.effects.rings.isEmpty, "a hit started its ring")
        try play(&engine, steps: 2, presenter: presenter)
        XCTAssertGreaterThan(presenter.effects.particles.aliveCount, 0, "a burst is alive")
        XCTAssertEqual(engine.handle(control: "run.pause", values: [1]), .accepted)
        let checksum = presenter.effects.particles.checksum()
        let radius = presenter.effects.ringRadius(start: presenter.effects.rings[0].start)
        try play(&engine, steps: 60, presenter: presenter)
        XCTAssertEqual(presenter.effects.particles.checksum(), checksum, "particles hold while paused")
        XCTAssertEqual(presenter.effects.ringRadius(start: presenter.effects.rings[0].start), radius)
        XCTAssertEqual(engine.handle(control: "run.pause", values: [0]), .accepted)
        try play(&engine, steps: 1, presenter: presenter)
        XCTAssertNotEqual(presenter.effects.particles.checksum(), checksum, "and move again after the resume")
    }

    /// T-A10-304 (FR-A10-310): every screen is spoken, and the controls follow it.
    func testEveryScreenIsSpoken() {
        var run = GameRun.new()
        XCTAssertTrue(ArcadePresenter.description(run, screen: .title).hasSuffix("no objects falling, title screen."))
        XCTAssertTrue(ArcadePresenter.description(run, screen: .playing).hasSuffix("playing."))
        run.paused = true
        XCTAssertTrue(ArcadePresenter.description(run, screen: .paused).hasSuffix("paused."))
        run.over = true
        run.lives = 0
        XCTAssertTrue(ArcadePresenter.description(run, screen: .over).hasSuffix("no lives, no objects falling, over."))
        XCTAssertEqual(ArcadePresenter.status(GameRun.new(), screen: .title), "score 0, 3 lives, title screen")
        XCTAssertEqual(ArcadeControls.startTitle(.paused), nil)
        XCTAssertTrue(ArcadeControls.canPause(.paused) && ArcadeControls.canPause(.playing))
        XCTAssertTrue(ArcadeControls.canRestart(.paused) && ArcadeControls.canRestart(.over))
        XCTAssertEqual(ArcadeControls.onOff(true), "On")
        XCTAssertEqual(ArcadeControls.onOff(false), "Off")
    }

    // MARK: Feature 078 (A10-P04)

    /// T-A10-403 (FR-A10-411–413, FR-A10-420; SC-A10-402, SC-A10-403): a run played to game over is entered once into
    /// the table in the experience's storage, drawn with its mark, announced as a new high score and described; a new
    /// session restoring the game-over screen enters nothing again.
    func testAFinishedRunIsEnteredOnceEvenAfterRestoringTheGameOverScreen() async throws {
        let temporary = TemporaryArcadeStorage()
        defer { temporary.remove() }
        let store = HighScoreStore(storage: temporary.storage)
        let spoken = RecordingAnnouncementSink()
        let session = ExperienceSession()
        let experience = try await ArcadeTest.openExperience(session, feedback: ArcadeTest.speakingFeedback(spoken),
                                                             highScores: store)
        let presenter = experience.presenter
        XCTAssertTrue(experience.handle(control: "run.steer", values: [ArcadeCore.gameOverSteering]).isAccepted)
        // The run ends before step 700; 90 more frames let an announcement held by the one-second limit go out.
        try ArcadeTest.frames(session, ArcadeCore.gameOverSteps + 90)
        let over = try ArcadeTest.core(experience.shell)
        XCTAssertEqual(over.screen, .over)
        XCTAssertGreaterThan(over.run.score, 0)
        let entry = HighScoreEntry(score: over.run.score, wave: over.run.wave, run: 1)
        XCTAssertEqual(store.table.entries, [entry])
        XCTAssertEqual(store.writes, 1)
        XCTAssertEqual(try HighScoreTable.decode(temporary.storage.read(HighScoreStore.fileName)).get(), store.table)
        XCTAssertEqual(presenter.lastBestTexts, [ArcadePresenter.scoreText(over.run.score)])
        XCTAssertEqual(presenter.lastBestMarkedRow, 0)
        let words = "New high score \(over.run.score)"
        XCTAssertEqual(presenter.announced.last?.text, words, "\(presenter.announced.map(\.text))")
        XCTAssertEqual(spoken.spoken.last, words)
        XCTAssertFalse(presenter.announced.map(\.text).contains { $0.hasPrefix("Game over") })
        XCTAssertTrue(experience.accessibilitySummary.contains("best score \(ArcadePresenter.grouped(over.run.score))"),
                      experience.accessibilitySummary)
        XCTAssertTrue(presenter.mirror.best.hasPrefix("Best score: \(ArcadePresenter.grouped(over.run.score))"),
                      presenter.mirror.best)
        let snapshot = try experience.snapshot()
        session.close()

        let reopenedStore = HighScoreStore(storage: temporary.storage)
        XCTAssertEqual(reopenedStore.table, store.table)
        let again = ExperienceSession()
        let restored = try await ArcadeTest.openExperience(again, snapshot: snapshot, highScores: reopenedStore,
                                                           start: false)
        try ArcadeTest.frames(again, 10)
        XCTAssertEqual(try ArcadeTest.core(restored.shell).screen, .over)
        XCTAssertEqual(reopenedStore.table, store.table, "the restored ending is not entered again")
        XCTAssertEqual(reopenedStore.writes, 0)
        XCTAssertNil(reopenedStore.newEntry, "and not marked as new")
        XCTAssertEqual(restored.presenter.lastBestTexts, [ArcadePresenter.scoreText(over.run.score)])
        XCTAssertNil(restored.presenter.lastBestMarkedRow)
        XCTAssertTrue(restored.presenter.announced.isEmpty, "a restored ending is not announced")
        again.close()
    }

    /// T-A10-403 (FR-A10-420; SC-A10-404): over a run with many events (hits, pickups, a wave, the game over) the
    /// announcements are at least a second apart, name the hits and end with the game over; pickups are never spoken.
    /// The game-over cue is announced even though the effect plan may drop it (the presenter detects the ending).
    func testAnnouncementsAreAtMostOnePerSecondOverARun() async throws {
        let spoken = RecordingAnnouncementSink()
        let presenter = ArcadePresenter(experienceID: ArcadeTest.id, soundSink: RecordingSoundSink(),
                                        feedback: ArcadeTest.speakingFeedback(spoken))
        var engine = ExperienceEngine<ArcadeCore>(id: ArcadeTest.id)
        try await engine.prepare(seed: ArcadeCore.manifestSeed)
        try engine.activate()
        XCTAssertEqual(engine.handle(control: "run.start"), .accepted)
        XCTAssertEqual(engine.handle(control: "run.steer", values: [ArcadeCore.gameOverSteering]), .accepted)
        presenter.advancePresentation(try XCTUnwrap(engine.core), seconds: 1.0 / 60)
        try play(&engine, steps: ArcadeCore.gameOverSteps + 120, presenter: presenter)
        let run = try XCTUnwrap(engine.core).run
        XCTAssertTrue(run.over)
        let times = presenter.announced.map(\.time)
        for (earlier, later) in zip(times, times.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later - earlier, ArcadeAnnouncer.minimumInterval - 1e-9)
        }
        XCTAssertLessThanOrEqual(times.count, Int(presenter.presentationTime / ArcadeAnnouncer.minimumInterval) + 1)
        let texts = presenter.announced.map(\.text)
        XCTAssertTrue(texts.contains { $0.hasPrefix("Hit, ") }, "\(texts)")
        XCTAssertEqual(texts.last, "New high score \(run.score)", "the first finished run enters the empty table")
        XCTAssertFalse(texts.contains { $0.lowercased().contains("orb") || $0.lowercased().contains("pickup") })
        XCTAssertEqual(spoken.spoken, texts, "every announcement goes to the host's feedback route")

        // The ending detection: watched from the playing screen a few steps earlier, not from a restored screen.
        var playing = ArcadeCore(seed: 7)
        _ = playing.apply(ExperienceAction(control: "run.start", values: [], step: 0))
        let ended = try XCTUnwrap(engine.core)
        XCTAssertFalse(ArcadePresenter.watchedEnding(from: nil, to: ended))
        XCTAssertFalse(ArcadePresenter.watchedEnding(from: playing, to: ended), "hundreds of steps apart")
        XCTAssertFalse(ArcadePresenter.watchedEnding(from: ended, to: ended), "already over")
    }

    /// T-A10-403 (FR-A10-401, FR-A10-402; SC-A10-401): the same finger offset gives a different steering value for each
    /// step, ordered gentle → sharp and within −1…1; in a session the drag uses the chosen step; the drag keeps its
    /// native alternative.
    func testTheDragReachFollowsTheSensitivityStep() async throws {
        let view = Vec2(90, 160)   // 10 points per unit; the player (x 4.5) is at view x 45
        for offset in [0.3, 0.5, -0.55] {   // below the sharpest reach (0.6), so no two steps clamp alike
            let values = Sensitivity.steps.map {
                ArcadeGestures.steeringValue(view: Vec2(45 + offset * 10, 140), playerX: 4.5, viewSize: view, step: $0)
            }.compactMap { $0 }
            XCTAssertEqual(values.count, Sensitivity.reaches.count)
            XCTAssertEqual(Set(values).count, values.count, "a different value per step for offset \(offset)")
            XCTAssertEqual(values, offset > 0 ? values.sorted() : values.sorted(by: >), "gentle → sharp")
            XCTAssertTrue(values.allSatisfy { (-1...1).contains($0) })
            for (step, value) in values.enumerated() {
                XCTAssertEqual(value, Sensitivity.steering(offset: offset, step: step), accuracy: 1e-9)
            }
        }
        XCTAssertEqual(ArcadeGestures.steerReach, 1.5, "the default step keeps the reach of A10-P01")

        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session)
        XCTAssertTrue(shell.handle(control: "run.pause", values: [1]).isAccepted, "the player holds still")
        func steering() throws -> Double { try ArcadeTest.core(shell).run.steering }
        func drag(to x: Double, at time: Double) {
            shell.handlePointer(ArcadeTest.touch(1, .began, 45, 140, at: time), viewSize: view)
            shell.handlePointer(ArcadeTest.touch(1, .moved, 60, 140, at: time + 0.05), viewSize: view)
            shell.handlePointer(ArcadeTest.touch(1, .moved, x, 140, at: time + 0.1), viewSize: view)
        }
        func release(at time: Double) {
            shell.handlePointer(ArcadeTest.touch(1, .ended, 45, 140, at: time), viewSize: view)
        }
        for (step, expected) in [(4, 0.5), (0, 0.12), (2, 0.2)] {
            XCTAssertTrue(shell.handle(control: "settings.sensitivity", values: [Double(step)]).isAccepted)
            try ArcadeTest.frames(session, 1)
            drag(to: 48, at: Double(step))   // 0.3 units right of the player
            XCTAssertEqual(try steering(), expected, accuracy: 1e-9, "step \(step)")
            release(at: Double(step) + 0.2)
            XCTAssertEqual(try steering(), 0)
        }
        let presenter = shell.presenter
        XCTAssertTrue(presenter.nativeActions.contains("settings.sensitivity"))
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])
        session.close()
    }

    /// T-A10-403 (FR-A10-421; SC-A10-405; analyze addition): every control has a label and a value or hint on every
    /// screen; the sensitivity speaks its step; the best-score text names the best score; the controls grow with the
    /// text size (text styles, wrapping).
    func testEveryControlIsLabelledAndTheControlsGrowWithDynamicType() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session, start: false)
        let presenter = shell.presenter
        for screen in ArcadeScreen.allCases {
            presenter.mirror.screen = screen
            let table = ArcadeControls.accessibility(presenter.mirror)
            for action in presenter.nativeActions {
                for name in ArcadeControls.controlNames(for: action) {
                    let entry = try XCTUnwrap(table[name], "\(name) on \(screen)")
                    XCTAssertFalse(entry.label.isEmpty, "\(name) on \(screen)")
                    XCTAssertFalse(entry.value.isEmpty && entry.hint.isEmpty, "\(name) on \(screen)")
                }
            }
            XCTAssertTrue(table["scores.best"]?.label.contains("Best") == true)
        }
        presenter.mirror.screen = .title
        let table = ArcadeControls.accessibility(presenter.mirror)
        XCTAssertEqual(table["settings.sensitivity"]?.label, "Steering sensitivity")
        XCTAssertEqual(table["settings.sensitivity"]?.value, "Step 3 of 5, normal")
        XCTAssertEqual(table["scores.best"]?.label, "Best score: none")
        XCTAssertEqual(ArcadeControls.sensitivityValue(0), "Step 1 of 5, gentle")
        XCTAssertEqual(ArcadeControls.sensitivityValue(4), "Step 5 of 5, sharp")
        XCTAssertTrue(shell.handle(control: "settings.sensitivity", values: [4]).isAccepted)
        try ArcadeTest.frames(session, 1)
        XCTAssertEqual(presenter.mirror.sensitivity, 4)
        XCTAssertEqual(ArcadeControls.accessibility(presenter.mirror)["settings.sensitivity"]?.value,
                       "Step 5 of 5, sharp")

        func height(_ size: DynamicTypeSize) -> CGFloat {
            let controller = UIHostingController(rootView: presenter.makeControls(shell.port)
                .environment(\.dynamicTypeSize, size))
            return controller.sizeThatFits(in: CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)).height
        }
        let small = height(.xSmall), large = height(.accessibility3)
        XCTAssertGreaterThan(small, 0)
        XCTAssertGreaterThan(large, small * 1.3, "the texts grow with Dynamic Type (\(small) → \(large))")
        session.close()
    }

    // MARK: Quality levels (feature 079)

    /// T-A10-503 (FR-A10-501): the session sees the core's profile (three levels named as the catalog), not the
    /// single level an experience declares by default.
    func testTheExperienceShowsTheCoresThreeLevels() {
        let experience = NeonArcadeExperience.make(id: ArcadeTest.id, lowPowerMode: { false })
        XCTAssertEqual(experience.qualityProfile, ArcadeCore.qualityProfile)
        XCTAssertEqual(experience.qualityProfile.count, ArcadePresenter.levelCount)
        XCTAssertEqual(QualityDeclaration.problems(profile: experience.qualityProfile,
                                                   tierCount: ArcadeCore.qualityTiers,
                                                   catalogNames: ["level-0", "level-1", "level-2"]), [])
    }

    /// T-A10-503 (FR-A10-503; SC-A10-501): pinning levels 2, 1 and 0 in turn mid-run draws budget levels 0, 1 and 2,
    /// with the collision shapes, the core and the digest equal to the same run drawn at the session's own level.
    func testALevelChangeMidRunKeepsTheShapesTheStateAndTheDigest() async throws {
        let plain = ExperienceSession()
        let plainShell = try await ArcadeTest.open(plain)
        plain.qualityPin = 0
        let tiered = ExperienceSession()
        let tieredShell = try await ArcadeTest.open(tiered)
        for shell in [plainShell, tieredShell] {
            XCTAssertTrue(shell.handle(control: "run.steer", values: [0.5]).isAccepted)
        }
        try ArcadeTest.frames(plain, 30)
        try ArcadeTest.frames(tiered, 30)
        for (pin, level) in [(2, 0), (1, 1), (0, 2)] {
            tiered.qualityPin = pin
            try ArcadeTest.frames(plain, 40)
            try ArcadeTest.frames(tiered, 40)
            let presenter = tieredShell.presenter
            XCTAssertEqual(presenter.lastHostTier, pin, "the pinned level reaches the presenter")
            XCTAssertEqual(presenter.budget.level, level)
            XCTAssertEqual(presenter.lastGlowFactor, ArcadeBudget.level(level).glowFactor)
            XCTAssertLessThanOrEqual(presenter.lastGlowAlpha, ArcadeBudget.level(level).glowOpacityCap)
            XCTAssertEqual(plainShell.presenter.budget.level, 2, "the plain session draws the full level")
            XCTAssertEqual(try ArcadeTest.core(tieredShell), try ArcadeTest.core(plainShell), "pin \(pin)")
            XCTAssertEqual(try tieredShell.engine.digest(), try plainShell.engine.digest(), "pin \(pin)")
            XCTAssertEqual(presenter.lastObjectsDrawn, plainShell.presenter.lastObjectsDrawn)
            XCTAssertEqual(presenter.bodyNodes.map(\.primitive), plainShell.presenter.bodyNodes.map(\.primitive),
                           "the collision shapes at their rule sizes at every level")
            XCTAssertEqual(presenter.playerRing.primitive, plainShell.presenter.playerRing.primitive)
            XCTAssertLessThanOrEqual(presenter.effects.instances.count, ArcadeBudget.level(level).particleCap)
        }
        plain.close()
        tiered.close()
    }

    /// T-A10-503 (FR-A10-503; edge case "Low Power Mode and the host's level"): with Low Power Mode on every frame
    /// draws level 0 whatever the host's level (no pulse, the 1.2 × glow, 48 particles at most); off again, the host's
    /// level returns; the state and the digest equal a run drawn without Low Power Mode.
    func testLowPowerModeDrawsLevelZeroAndNeverChangesTheState() async throws {
        let plain = ExperienceSession()
        let plainShell = try await ArcadeTest.open(plain)
        plain.qualityPin = 0
        let lowPower = TestSwitch(true)
        let saving = ExperienceSession()
        let savingShell = try await ArcadeTest.open(saving, lowPowerMode: { lowPower.on })
        saving.qualityPin = 0
        for shell in [plainShell, savingShell] {
            XCTAssertTrue(shell.handle(control: "run.steer", values: [-0.5]).isAccepted)
        }
        try ArcadeTest.frames(plain, 40)
        try ArcadeTest.frames(saving, 40)
        let presenter = savingShell.presenter
        XCTAssertTrue(presenter.lastLowPower)
        XCTAssertEqual(presenter.lastHostTier, 0)
        XCTAssertEqual(presenter.budget, ArcadeBudget.level(0), "Low Power Mode draws level 0")
        XCTAssertEqual(presenter.lastGlowFactor, 1.2)
        XCTAssertEqual(presenter.lastPulseApplied, 0, "no pulse at level 0")
        XCTAssertEqual(presenter.effects.particles.liveLimit, 48)
        XCTAssertEqual(try ArcadeTest.core(savingShell), try ArcadeTest.core(plainShell))
        XCTAssertEqual(try savingShell.engine.digest(), try plainShell.engine.digest())
        lowPower.on = false
        try ArcadeTest.frames(plain, 20)
        try ArcadeTest.frames(saving, 20)
        XCTAssertFalse(presenter.lastLowPower)
        XCTAssertEqual(presenter.budget.level, 2, "the host's level once Low Power Mode is off")
        XCTAssertEqual(try savingShell.engine.digest(), try plainShell.engine.digest())
        lowPower.on = true
        saving.qualityPin = 1
        try ArcadeTest.frames(plain, 20)
        try ArcadeTest.frames(saving, 20)
        XCTAssertEqual(presenter.lastHostTier, 1)
        XCTAssertEqual(presenter.budget.level, 0, "level 0 at any host level")
        XCTAssertEqual(try savingShell.engine.digest(), try plainShell.engine.digest())
        plain.close()
        saving.close()
    }
}
