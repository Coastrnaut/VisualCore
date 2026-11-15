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
// continues from the same step; the description names the wave; schema 3 is the newer saved state.
import Foundation
import XCTest
import VisualCoreDiagnostics
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

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

    func testASuspensionDoesNotAdvanceTheGame() async throws {
        let session = ExperienceSession()
        let shell = try await ArcadeTest.open(session)
        try ArcadeTest.frames(session, 45)
        let before = try ArcadeTest.core(shell)
        let stepIndex = shell.engine.stepIndex
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        for _ in 0..<10 { _ = session.renderHost?.renderOneFrame(present: false) }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(try ArcadeTest.core(shell), before, "nothing moves while suspended")
        XCTAssertEqual(shell.engine.stepIndex, stepIndex)

        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try ArcadeTest.core(shell), before, "the resume continues from the same step")
        try ArcadeTest.frames(session, 1)
        let resumed = try ArcadeTest.core(shell)
        XCTAssertLessThanOrEqual(resumed.run.step - before.run.step, 2, "one frame's steps, never the suspended time")
        session.close()
    }

    /// The saved state of seed 7 after the wave fixture's inputs to step 1,300: wave 3 (`wall`), alive.
    private func waveThreeSnapshot() async throws -> ExperienceSnapshot {
        var engine = ExperienceEngine<ArcadeCore>(id: ArcadeTest.id)
        try await engine.prepare(seed: 7)
        try engine.activate()
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
            XCTAssertEqual(held, before, "\(milliseconds) ms: nothing moves while suspended")
            XCTAssertEqual(shell.engine.stepIndex, stepIndex)

            session.setScenePhase(.active)
            XCTAssertEqual(shell.state, .active)
            XCTAssertEqual(try ArcadeTest.core(shell), before, "the resume continues from the same step")
            try ArcadeTest.frames(session, 1)
            let resumed = try ArcadeTest.core(shell)
            XCTAssertLessThanOrEqual(resumed.run.step - before.run.step, 2,
                                     "one frame's steps, never the suspended time")
            XCTAssertEqual(resumed.run.wave, 3)
        }
        session.close()
    }

    /// Steering inputs at even steps, so frames of 1/30 s (two steps each) reach every one of them.
    private static let pacedInputs: [(step: Int, value: Double)] = [
        (0, 0.6), (44, -0.3), (120, -1.0), (210, 0.25), (300, 1.0), (390, 0.0), (480, -0.75), (600, 0.5),
    ]
    private static let pacedSteps = 720

    func testFramePacingGivesTheSameRunAfterTheSameSteps() async throws {
        let id = ArcadeTest.id
        // The bare replay: the inputs applied at their steps, the steps run one by one.
        var reference = ArcadeCore(seed: 7)
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
        let newer = try ExperienceSnapshot(experience: ArcadeTest.id, schemaVersion: 3, seed: saved.seed,
                                           stepIndex: saved.stepIndex, digest: saved.digest,
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
}
