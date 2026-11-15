// PlaygroundSessionTests — feature 082 (A11-P01) T-A11-104 (FR-A11-112, FR-A11-120, FR-A11-121; clarification 5;
// SC-A11-101, SC-A11-104). The A11 adapter inside the one app's session host on the simulator, short runs only (each
// test well under 10 s, no wall-clock assertion): the first frame draws the starting scene and describes it in words;
// each drawn frame of 1/60 s advances two ticks at 1× and pause stops the world; a suspension of any wall-clock length
// does not advance the world and the resume continues from the same tick (no catch-up); frames of 1/30, 1/60 and
// 1/120 s give the same world after the same steps as the bare replay; the state saved by the shell restores
// identically in a new session; newer and damaged saved states are refused and the starting scene opens; reopening
// keeps the drawing resources steady.
//
// Feature 083 (A11-P02) T-A11-204 (FR-A11-212, FR-A11-220; SC-A11-206): the starting scene holds ten bodies and two
// springs, both drawn; the description adds the springs and the levels; a level picked in a session survives the
// saved state; a schema-3 state is the newer one refused; the stored schema-1 example opens through the migration.
//
// Feature 084 (A11-P03) T-A11-303 (FR-A11-303, FR-A11-320; SC-A11-301, SC-A11-305): the description adds the pins,
// the selection and the overlays; the seven edit actions are the gesture actions, each with a native alternative;
// pins, selection, grab and overlays survive the saved state (schema 3); a schema-4 state is the newer one refused;
// the stored schema-2 example opens through the migration 2 → 3.
//
// Feature 085 (A11-P04) T-A11-403 (FR-A11-402, FR-A11-410, FR-A11-430; SC-A11-403): the description ends with the
// experiment ("Experiment: Free play.") and, while a tutorial runs, its step; the mirror carries the experiment and the
// tutorial; the origin, starting world and tutorial survive the saved state (schema 4); a schema-5 state is the newer
// one refused; the stored schema-3 example opens through the migration 3 → 4; a tutorial runs through the shell.
import Foundation
import XCTest
import VisualCoreDiagnostics
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
final class PlaygroundSessionTests: XCTestCase {
    func testTheFirstFrameDrawsTheStartingSceneAndDescribesIt() async throws {
        XCTAssertEqual(PhysicsPlaygroundExperience.id?.rawValue, "a11.physics-playground")
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        XCTAssertGreaterThan(presenter.lastScale, 0)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        let core = try PlaygroundTest.core(shell)
        XCTAssertEqual(core.world.bodies.count, 10)
        XCTAssertEqual(presenter.lastBodiesDrawn, 10)
        XCTAssertEqual(presenter.lastStaticDrawn, 1, "the ledge is hatched")
        XCTAssertEqual(presenter.lastSpringsDrawn, 2, "the hanging box's and the joined circles' springs")
        let summary = shell.accessibilitySummary
        XCTAssertEqual(summary, "Physics Playground: 10 bodies, running, normal speed (time scale 1×); "
                       + "2 springs, stiffness medium, gravity Earth, drag low; none pinned, no selection, arrows off. "
                       + "Experiment: Free play.")
        XCTAssertTrue(presenter.mirror.ready)
        XCTAssertEqual(presenter.mirror.bodyCount, 10)
        XCTAssertEqual(presenter.nativeActions, Set(PlaygroundCore.actionIDs))
        XCTAssertEqual(presenter.gestureActions, PlaygroundCore.gestureActionIDs)
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])

        XCTAssertTrue(shell.handle(control: "world.pause", values: [1]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.contains("paused"), shell.accessibilitySummary)
        XCTAssertTrue(presenter.mirror.paused)
        XCTAssertTrue(shell.handle(control: "world.timeScale", values: [3]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.drop", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.stiffness", values: [2]).isAccepted)
        XCTAssertEqual(shell.accessibilitySummary,
                       "Physics Playground: 11 bodies, paused, double speed (time scale 2×); "
                       + "2 springs, stiffness stiff, gravity Earth, drag low; none pinned, no selection, arrows off. "
                       + "Experiment: Free play.")
        XCTAssertTrue(shell.handle(control: "edit.pin", values: [8]).isAccepted)
        XCTAssertTrue(shell.handle(control: "edit.select", values: [7]).isAccepted)
        XCTAssertTrue(shell.handle(control: "edit.grab", values: [7, 7.5, 6.2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "overlay.velocity", values: [1]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix(
            "; 1 pinned, body 7 selected (a box), body 7 held, velocity arrows on. Experiment: Free play."),
            shell.accessibilitySummary)
        XCTAssertEqual(presenter.mirror.pinnedCount, 1)
        XCTAssertEqual(presenter.mirror.selectedId, 7)
        XCTAssertEqual(presenter.mirror.grabbedId, 7)
        XCTAssertTrue(presenter.mirror.showVelocity)
        XCTAssertEqual(presenter.mirror.timeScaleIndex, 3)
        XCTAssertEqual(presenter.mirror.bodyCount, 11)
        XCTAssertEqual(presenter.mirror.stiffnessLevel, 2)

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertFalse(presenter.isLive)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testFramesAdvanceTheWorldAndPauseStopsIt() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session)
        let before = try PlaygroundTest.core(shell)
        try PlaygroundTest.frames(session, 30)
        let after = try PlaygroundTest.core(shell)
        XCTAssertGreaterThan(after.world.tick, before.world.tick)
        XCTAssertLessThanOrEqual(after.world.tick - before.world.tick, 62, "about two ticks per 1/60 s frame")
        let falling = after.world.bodies.filter { !$0.isStatic }
        let start = before.world.bodies.filter { !$0.isStatic }
        XCTAssertTrue(zip(falling, start).allSatisfy { $0.position.y < $1.position.y }, "the bodies fall")

        XCTAssertTrue(shell.handle(control: "world.pause", values: [1]).isAccepted)
        let paused = try PlaygroundTest.core(shell)
        try PlaygroundTest.frames(session, 30)
        XCTAssertEqual(try PlaygroundTest.core(shell), paused, "nothing moves while paused")
        XCTAssertTrue(shell.handle(control: "world.step").isAccepted)
        XCTAssertEqual(try PlaygroundTest.core(shell).world.tick, paused.world.tick + 1, "one tick")

        XCTAssertTrue(shell.handle(control: "world.pause", values: [0]).isAccepted)
        try PlaygroundTest.frames(session, 5)
        XCTAssertGreaterThan(try PlaygroundTest.core(shell).world.tick, paused.world.tick + 1)
        session.close()
    }

    func testASuspensionDoesNotAdvanceTheWorld() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session)
        try PlaygroundTest.frames(session, 45)
        let before = try PlaygroundTest.core(shell)
        let stepIndex = shell.engine.stepIndex
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        for _ in 0..<10 { _ = session.renderHost?.renderOneFrame(present: false) }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(try PlaygroundTest.core(shell), before, "nothing moves while suspended")
        XCTAssertEqual(shell.engine.stepIndex, stepIndex)

        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try PlaygroundTest.core(shell), before, "the resume continues from the same tick")
        try PlaygroundTest.frames(session, 1)
        let resumed = try PlaygroundTest.core(shell)
        XCTAssertLessThanOrEqual(resumed.world.tick - before.world.tick, 4,
                                 "one frame's steps, never the suspended time")
        session.close()
    }

    /// Actions at steps that are multiples of 4, so frames of 1/30 s (four host steps each) reach every one of them.
    private static let pacedInputs: [(step: Int, control: String, values: [Double])] = [
        (0, "world.drop", [0]), (40, "world.drop", [1]), (80, "world.timeScale", [3]), (160, "world.timeScale", [0]),
        (240, "world.pause", [1]), (240, "world.step", []), (240, "world.pause", [0]), (280, "world.timeScale", [2]),
        (320, "world.drop", [0]),
    ]
    private static let pacedSteps = 400

    func testFramePacingGivesTheSameWorldAfterTheSameSteps() async throws {
        let id = PlaygroundTest.id
        // The bare replay: the inputs applied at their steps, the steps run one by one.
        var reference = PlaygroundCore(seed: 7)
        for step in 0..<Self.pacedSteps {
            for input in Self.pacedInputs where input.step == step {
                XCTAssertEqual(reference.apply(ExperienceAction(control: input.control, values: input.values,
                                                                step: step)), .accepted)
            }
            reference.update(step: step)
        }
        XCTAssertEqual(reference.world.bodies.count, 13)

        var digests: [String] = []
        for delta in [1.0 / 30, 1.0 / 60, 1.0 / 120] {
            var engine = ExperienceEngine<PlaygroundCore>(id: id)
            try await engine.prepare(seed: 7)
            try engine.activate()
            var pending = Self.pacedInputs
            var frames = 0
            while engine.stepIndex < Self.pacedSteps, frames < 4 * Self.pacedSteps {
                while let next = pending.first, next.step == engine.stepIndex {
                    XCTAssertEqual(engine.handle(control: next.control, values: next.values), .accepted)
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
            XCTAssertEqual(core.world.tick, reference.world.tick, "frames of \(delta) s")
            XCTAssertEqual(core, reference, "frames of \(delta) s")
            digests.append(try engine.digest().hex)
        }
        XCTAssertEqual(Set(digests).count, 1, "the same digest at 1/30, 1/60 and 1/120 s")
    }

    func testTheSavedStateRestoresIdenticallyInANewSession() async throws {
        let first = ExperienceSession()
        let shell = try await PlaygroundTest.open(first)
        XCTAssertTrue(shell.handle(control: "world.drop", values: [1]).isAccepted)
        try PlaygroundTest.frames(first, 60)
        XCTAssertTrue(shell.handle(control: "world.timeScale", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.gravity", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.drag", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.stiffness", values: [3]).isAccepted)
        try PlaygroundTest.frames(first, 3)
        XCTAssertTrue(shell.handle(control: "edit.pin", values: [9]).isAccepted)
        XCTAssertTrue(shell.handle(control: "edit.select", values: [8]).isAccepted)
        XCTAssertTrue(shell.handle(control: "edit.grab", values: [7, 7.5, 6.2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "edit.move", values: [6, 5]).isAccepted)
        XCTAssertTrue(shell.handle(control: "overlay.forces", values: [1]).isAccepted)
        try PlaygroundTest.frames(first, 2)
        let snapshot = try shell.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 4)
        let saved = try PlaygroundTest.core(shell)
        XCTAssertGreaterThan(saved.world.tick, 0, "a world in motion")
        first.close()

        let second = ExperienceSession()
        let restored = try await PlaygroundTest.open(second, seed: 3)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let core = try PlaygroundTest.core(restored)
        XCTAssertEqual(core.state, saved.state,
                       "bodies, tick, flags, time scale, remainder, springs, levels, cache and generator are identical")
        XCTAssertEqual(core.world.gravityLevel, 1)
        XCTAssertEqual(core.world.dragLevel, 2)
        XCTAssertEqual(core.world.stiffnessLevel, 3)
        XCTAssertTrue(try XCTUnwrap(core.world.bodies.first { $0.id == 9 }).pinned)
        XCTAssertEqual(core.world.selectedId, 8)
        XCTAssertEqual(core.world.grab?.target, Vec2(6, 5))
        XCTAssertTrue(core.world.showForces)
        try PlaygroundTest.frames(second, 1)
        XCTAssertEqual(restored.presenter.mirror.stiffnessLevel, 3, "the controls show the restored levels")
        XCTAssertEqual(restored.presenter.mirror.gravityLevel, 1)
        XCTAssertEqual(restored.presenter.mirror.dragLevel, 2)
        second.close()
    }

    func testTheStoredSchemaOneExampleOpensThroughTheMigration() async throws {
        let example = try XCTUnwrap(PlaygroundCore.schemaOneExample())
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 1)
        let session = ExperienceSession()
        let opened = try await PlaygroundTest.open(session, seed: 3, snapshot: snapshot)
        XCTAssertNil(session.lastRestoreRefusal, "the Phase 01 state is migrated, not refused")
        let core = try PlaygroundTest.core(opened)
        XCTAssertEqual(core.world.springs, [])
        XCTAssertEqual(core.world.bodies.count, 9)
        XCTAssertEqual(core.world.validate(), [])
        XCTAssertTrue(core.world.paused, "saved paused, so the first frame changes nothing")
        XCTAssertEqual(opened.presenter.lastSpringsDrawn, 0)
        XCTAssertTrue(opened.accessibilitySummary.contains("9 bodies, paused, half speed"),
                      opened.accessibilitySummary)
        XCTAssertTrue(opened.accessibilitySummary.contains("no springs, stiffness medium, gravity Earth, drag low"))
        XCTAssertTrue(opened.accessibilitySummary.hasSuffix("none pinned, no selection, arrows off. "
                                                            + "Experiment: Free play."))
        session.close()
    }

    /// T-A11-303 (FR-A11-320; SC-A11-305): the stored Phase 02 payload opens in a session through the migration 2 → 3
    /// with its springs and levels, nothing pinned, nothing selected, nothing held and the overlays off.
    func testTheStoredSchemaTwoExampleOpensThroughTheMigration() async throws {
        let example = try XCTUnwrap(PlaygroundCore.schemaTwoExample())
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 2)
        let session = ExperienceSession()
        let opened = try await PlaygroundTest.open(session, seed: 3, snapshot: snapshot)
        XCTAssertNil(session.lastRestoreRefusal, "the Phase 02 state is migrated, not refused")
        let core = try PlaygroundTest.core(opened)
        XCTAssertEqual(core.world.bodies.count, 12)
        XCTAssertEqual(core.world.springs.count, 2)
        XCTAssertEqual(core.world.validate(), [])
        XCTAssertTrue(core.world.paused)
        XCTAssertEqual(opened.presenter.lastSpringsDrawn, 2)
        XCTAssertEqual(opened.accessibilitySummary,
                       "Physics Playground: 12 bodies, paused, half speed (time scale ½×); "
                       + "2 springs, stiffness stiff, gravity Moon, drag high; none pinned, no selection, arrows off. "
                       + "Experiment: Free play.")
        XCTAssertEqual(opened.presenter.mirror.pinnedCount, 0)
        XCTAssertNil(opened.presenter.mirror.selectedId)
        session.close()
    }

    func testANewerSavedStateIsRefusedAndTheStartingSceneOpens() async throws {
        let first = ExperienceSession()
        let shell = try await PlaygroundTest.open(first)
        XCTAssertTrue(shell.handle(control: "world.drop", values: [0]).isAccepted)
        try PlaygroundTest.frames(first, 60)
        let saved = try shell.snapshot()
        first.close()
        let newer = try ExperienceSnapshot(experience: PlaygroundTest.id, schemaVersion: 5, seed: saved.seed,
                                           stepIndex: saved.stepIndex, digest: saved.digest,
                                           payload: Data(saved.payload.utf8))

        let second = ExperienceSession()
        let opened = try await PlaygroundTest.open(second, snapshot: newer)
        XCTAssertNotNil(second.lastRestoreRefusal, "the newer state is refused")
        let core = try PlaygroundTest.core(opened)
        XCTAssertLessThanOrEqual(core.world.tick, 2, "the starting scene opens")
        XCTAssertEqual(core.world.bodies.count, 10)
        XCTAssertThrowsError(try opened.restore(newer))
        second.close()
    }

    func testADamagedSavedStateIsRefusedAndTheStartingSceneOpens() async throws {
        let first = ExperienceSession()
        let shell = try await PlaygroundTest.open(first)
        try PlaygroundTest.frames(first, 60)
        let saved = try shell.snapshot()
        first.close()
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(saved.payload.utf8)) as? [String: Any])
        var world = try XCTUnwrap(object["world"] as? [String: Any])
        world["timeScaleIndex"] = 7
        object["world"] = world
        let payload = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let damaged = try ExperienceSnapshot(experience: PlaygroundTest.id, schemaVersion: saved.schemaVersion,
                                             seed: saved.seed, stepIndex: saved.stepIndex, digest: saved.digest,
                                             payload: payload)

        let second = ExperienceSession()
        let opened = try await PlaygroundTest.open(second, snapshot: damaged)
        XCTAssertNotNil(second.lastRestoreRefusal, "an invalid world is refused")
        let core = try PlaygroundTest.core(opened)
        XCTAssertLessThanOrEqual(core.world.tick, 2, "the starting scene opens")
        XCTAssertEqual(core.world.timeScaleIndex, PhysicsWorld.normalTimeScaleIndex)
        XCTAssertThrowsError(try opened.restore(damaged))
        second.close()
    }

    func testReopeningFiveTimesKeepsTheDrawingResourcesSteady() async throws {
        var reference: ResourceLedger.Snapshot?
        for cycle in 1...5 {
            let session = ExperienceSession()
            let shell = try await PlaygroundTest.open(session)
            XCTAssertTrue(shell.handle(control: "world.drop", values: [0]).isAccepted)
            try PlaygroundTest.frames(session, 30)
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

    /// T-A11-403 (FR-A11-430): the stored Phase 03 payload opens in a session through the migration 3 → 4 with its
    /// world, free play as the origin and the world without grab and selection as the starting world.
    func testTheStoredSchemaThreeExampleOpensThroughTheMigration() async throws {
        let example = try XCTUnwrap(PlaygroundCore.schemaThreeExample())
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 3)
        let session = ExperienceSession()
        let opened = try await PlaygroundTest.open(session, seed: 3, snapshot: snapshot)
        XCTAssertNil(session.lastRestoreRefusal, "the Phase 03 state is migrated, not refused")
        let core = try PlaygroundTest.core(opened)
        XCTAssertEqual(core.world, PlaygroundCore.schemaThreeExampleState().world)
        XCTAssertEqual(core.origin, .freePlay)
        XCTAssertEqual(core.startingWorld, ExperimentDocument.withoutEditing(core.world))
        XCTAssertNil(core.tutorial)
        XCTAssertTrue(opened.accessibilitySummary.hasSuffix("velocity arrows on. Experiment: Free play."),
                      opened.accessibilitySummary)
        session.close()
    }

    /// T-A11-403 (FR-A11-401, FR-A11-410; SC-A11-403): a preset and a tutorial through the shell: the description and
    /// the mirror name the experiment and the step; the experiment and the progress survive the saved state.
    func testAPresetAndATutorialRunThroughTheShell() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.mirror.experiment, "Experiment: Free play.")
        XCTAssertEqual(presenter.mirror.presetIndex, 0)
        XCTAssertTrue(shell.handle(control: "tutorial.start", values: [1]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix(
            "Experiment: Free play. Tutorial: Springs and energy, step 1 of 3: Open the spring chain."),
            shell.accessibilitySummary)
        XCTAssertEqual(presenter.mirror.tutorialId, 1)
        XCTAssertEqual(presenter.mirror.tutorialStep, "Springs and energy, step 1 of 3")
        XCTAssertEqual(presenter.mirror.tutorialText, "Open the spring chain.")
        XCTAssertTrue(shell.handle(control: "experiment.preset", values: [2]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix(
            "Experiment: Spring chain. Tutorial: Springs and energy, step 2 of 3: Show the force arrows."),
            shell.accessibilitySummary)
        XCTAssertEqual(presenter.mirror.presetIndex, 2)
        XCTAssertTrue(shell.handle(control: "overlay.forces", values: [1]).isAccepted)
        try PlaygroundTest.frames(session, 10)
        let snapshot = try shell.snapshot()
        let saved = try PlaygroundTest.core(shell)
        XCTAssertEqual(saved.tutorial?.step, 2)
        session.close()

        let second = ExperienceSession()
        let restored = try await PlaygroundTest.open(second, seed: 3)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let core = try PlaygroundTest.core(restored)
        XCTAssertEqual(core.state, saved.state, "origin, starting world and tutorial included")
        XCTAssertEqual(core.origin, .preset(2))
        XCTAssertTrue(restored.handle(control: "tutorial.stop").isAccepted)
        XCTAssertNil(try PlaygroundTest.core(restored).tutorial)
        XCTAssertTrue(restored.accessibilitySummary.hasSuffix("Experiment: Spring chain."))
        XCTAssertNil(restored.presenter.mirror.tutorialText, "the tutorial card hides")
        XCTAssertEqual(restored.handle(control: "tutorial.stop"), .rejected(.rule(code: PlaygroundRule.noTutorial)))
        second.close()
    }
}
