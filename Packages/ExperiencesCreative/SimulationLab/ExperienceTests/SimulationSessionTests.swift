// SimulationSessionTests — feature 117 (A16-P01) T-A16-105 (FR-A16-120, FR-A16-130; SC-A16-105). The A16 adapter inside
// the one app's session host on the simulator, short runs only (each test well under 10 s, no wall-clock assertion):
// the session opens the running automaton, draws it through the host with its target and display pass made together
// and describes it in words; actions sent through the port change the state and a refused one is answered in the
// mirror; with Reduce Motion the simulation opens paused (the registry's factory included); a paused single step
// through the engine equals one model step in every family; a suspension changes nothing; the state saved by the shell
// restores to the same digest in a new session; and a damaged saved state is refused.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// Simulation Lab inside the session host.
@MainActor
final class SimulationSessionTests: XCTestCase {
    func testTheSessionOpensTheRunningAutomatonAndDrawsIt() async throws {
        XCTAssertEqual(SimulationLabExperience.id?.rawValue, "a16.simulation-lab")
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        let core = try SimulationTest.core(shell)
        XCTAssertEqual(core.kind, .automaton)
        XCTAssertTrue(core.isRunning)
        XCTAssertEqual(presenter.resourceBuildCount, 1, "the target and the pass made together, once")
        let target = try XCTUnwrap(presenter.target)
        XCTAssertEqual(target.width, 64)
        XCTAssertEqual(target.height, 64)
        XCTAssertEqual(target.format, .rgba8)
        XCTAssertNotNil(presenter.display)
        XCTAssertGreaterThanOrEqual(presenter.uploadCount, 1)
        XCTAssertEqual(presenter.lastKind, .automaton)
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix(
            "Simulation Lab: cellular automaton, rule Life (B3/S23); 64 × 64 grid; running at ×1; step "),
                      shell.accessibilitySummary)
        XCTAssertTrue(presenter.mirror.ready)
        XCTAssertEqual(presenter.mirror.family, 0)
        XCTAssertEqual(presenter.mirror.familyTitle, "Cellular automaton")
        XCTAssertEqual(presenter.mirror.presetTitles, ["Life (B3/S23)", "HighLife (B36/S23)", "Seeds (B2/S)"])
        XCTAssertEqual(presenter.mirror.preset, 0)
        XCTAssertTrue(presenter.mirror.running)
        XCTAssertEqual(presenter.nativeActions, Set(SimulationCore.actionIDs), "every action has a native control")
        XCTAssertEqual(shell.port.identifier("run-pause"), "experience.a16.simulation-lab.run-pause")

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertFalse(presenter.isLive)
        XCTAssertNil(presenter.target, "the target is released with the pass in teardown")
        XCTAssertNil(presenter.display)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testActionsThroughThePortAndARefusalIsAnswered() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        XCTAssertTrue(presenter.send("sim.pause", through: shell.port).isAccepted)
        let paused = try SimulationTest.core(shell).stepCount
        try SimulationTest.frames(session, 5)
        XCTAssertEqual(try SimulationTest.core(shell).stepCount, paused, "paused frames run nothing")
        XCTAssertFalse(presenter.mirror.running)
        XCTAssertEqual(presenter.mirror.status, "Paused, step \(paused)")
        XCTAssertTrue(presenter.send("sim.step", through: shell.port).isAccepted)
        XCTAssertEqual(try SimulationTest.core(shell).stepCount, paused + 1)
        XCTAssertTrue(presenter.send("sim.run", through: shell.port).isAccepted)
        let refused = presenter.send("sim.step", through: shell.port)
        XCTAssertEqual(refused.code, "action.rule.a16.invalid-choice")
        XCTAssertEqual(presenter.mirror.message, "Pause the simulation to step it one iteration at a time.")
        XCTAssertTrue(presenter.send("sim.family", [2], through: shell.port).isAccepted)
        XCTAssertEqual(presenter.mirror.message, "", "an accepted action clears the answer")
        XCTAssertEqual(presenter.send("sim.preset", [1], through: shell.port).code, "action.rule.a16.invalid-choice")
        XCTAssertEqual(presenter.mirror.message, "This family has no such preset.")
        XCTAssertEqual(try SimulationTest.core(shell).kind, .wave, "a refusal changes nothing")
        XCTAssertTrue(presenter.send("sim.speed", [0], through: shell.port).isAccepted)
        try SimulationTest.frames(session, 2)
        XCTAssertEqual(presenter.mirror.familyTitle, "Wave field")
        XCTAssertEqual(presenter.mirror.presetTitles, ["Pulse"])
        XCTAssertEqual(presenter.mirror.speedIndex, 0)
        XCTAssertEqual(presenter.lastKind, .wave)
        XCTAssertEqual(presenter.resourceBuildCount, 1, "changing the family never remakes the resources")
        session.close()
    }

    func testReduceMotionOpensPaused() async throws {
        let reduced = ExperienceSession()
        let shell = try await SimulationTest.open(reduced, reduceMotion: true)
        try SimulationTest.frames(reduced, 5)
        let core = try SimulationTest.core(shell)
        XCTAssertFalse(core.isRunning, "the person starts it")
        XCTAssertEqual(core.stepCount, 0)
        XCTAssertFalse(shell.presenter.mirror.running)
        XCTAssertTrue(shell.accessibilitySummary.contains("; paused; step 0; "), shell.accessibilitySummary)
        XCTAssertTrue(shell.handle(control: "sim.run").isAccepted, "the person can start it")
        reduced.close()

        let plain = ExperienceSession()
        let running = try await SimulationTest.open(plain, reduceMotion: false)
        XCTAssertTrue(try SimulationTest.core(running).isRunning, "without Reduce Motion it opens running")
        plain.close()

        // The registry's factory passes the setting to the wrapper.
        let id = SimulationTest.id
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("a16-" + UUID().uuidString)
        let storage = ExperienceStorage(id: id, root: root, defaults: .standard)
        let made = SimulationLabExperience.make(id: id, storage: storage, reduceMotion: true, reduceFlashing: false)
        let wrapper = try XCTUnwrap(made as? SimulationExperience)
        XCTAssertTrue(wrapper.reduceMotion)
        XCTAssertEqual(wrapper.id, id)
    }

    func testAPausedSingleStepThroughTheEngineEqualsOneModelStep() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        try SimulationTest.pause(shell)
        for index in 0..<3 {
            XCTAssertTrue(shell.handle(control: "sim.family", values: [Double(index)]).isAccepted)
            var expected = try SimulationTest.core(shell).model
            expected.step()
            XCTAssertTrue(shell.handle(control: "sim.step").isAccepted)
            XCTAssertEqual(try SimulationTest.core(shell).model, expected, "family \(index)")
            try SimulationTest.frames(session, 3)
            XCTAssertEqual(try SimulationTest.core(shell).model, expected, "frames while paused run nothing")
        }
        session.close()
    }

    func testASuspensionChangesNothing() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        XCTAssertTrue(shell.handle(control: "sim.family", values: [1]).isAccepted)
        try SimulationTest.frames(session, 5)
        let before = try SimulationTest.core(shell)
        let digest = try shell.engine.digest()
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        for _ in 0..<10 { _ = session.renderHost?.renderOneFrame(present: false) }
        XCTAssertEqual(try SimulationTest.core(shell), before, "nothing runs while suspended")
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try SimulationTest.core(shell), before, "the resume continues from the same state")
        session.close()
    }

    func testTheSavedStateRestoresToTheSameDigestInANewSession() async throws {
        let first = ExperienceSession()
        let shell = try await SimulationTest.open(first)
        XCTAssertTrue(shell.handle(control: "sim.family", values: [1]).isAccepted)
        try SimulationTest.frames(first, 4)
        try SimulationTest.pause(shell)
        XCTAssertTrue(shell.handle(control: "sim.step").isAccepted)
        let snapshot = try shell.snapshot()
        let saved = try SimulationTest.core(shell)
        let digest = try shell.engine.digest()
        first.close()

        let second = ExperienceSession()
        let restored = try await SimulationTest.open(second, seed: 3)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        XCTAssertEqual(try SimulationTest.core(restored).model, saved.model)
        XCTAssertEqual(try restored.engine.digest(), digest, "the same digest")
        try SimulationTest.frames(second, 2)
        XCTAssertEqual(try restored.engine.digest(), digest, "a paused restored state stays")
        XCTAssertEqual(restored.presenter.lastKind, .reactionDiffusion)
        XCTAssertEqual(restored.accessibilitySummary, saved.canvasDescription)
        second.close()
    }

    func testADamagedSavedStateIsRefusedAndTheStateStays() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        try SimulationTest.pause(shell)
        let saved = try shell.snapshot()
        let before = try SimulationTest.core(shell)
        let id = try XCTUnwrap(ExperienceID(rawValue: SimulationCore.experienceID))
        let damaged = try ExperienceSnapshot(experience: id, schemaVersion: saved.schemaVersion, seed: saved.seed,
                                             stepIndex: saved.stepIndex, digest: saved.digest,
                                             payload: Data("{\"schema\":1}".utf8))
        XCTAssertThrowsError(try shell.restore(damaged))
        XCTAssertEqual(try SimulationTest.core(shell), before, "a refused restore changes nothing")
        session.close()
    }
}
