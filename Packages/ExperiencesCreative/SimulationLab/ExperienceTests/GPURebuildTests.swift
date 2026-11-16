// GPURebuildTests — feature 118 (A16-P02) T-A16-203 (FR-A16-202, FR-A16-204; SC-A16-204; clarification Q2; spec edge
// cases). The presenter's GPU automaton field inside the one app's session host on the simulator, short runs only
// (each test well under 10 s, no wall-clock assertion): while running it steps in lockstep with the engine and equals
// the CPU field after every frame without a reload; after `recreateContext` and after a resize it is loaded again and
// equals the reference; a refused action leaves it unchanged; a single step steps it once; reset, a family change and
// a restore load it from the CPU state; drawing never changes the digest; and an invalid step program fails the
// session through the host's failure state (`experience.setup-failed`) with nothing left alive. The GPU field is read
// right after a frame, while the host's context is still current on the main thread.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreSimulation

/// The GPU automaton field of Simulation Lab across rebuilds and non-step changes.
@MainActor
final class GPURebuildTests: XCTestCase {
    override func tearDown() {
        MainActor.assumeIsolated { SimulationPresenter.stepFragmentOverride = nil }
        super.tearDown()
    }

    /// Draws one frame and returns the presenter's GPU automaton field, read back right after it.
    private func gpuField(_ session: ExperienceSession, _ shell: ExperienceShell<SimulationPresenter>) throws
        -> FieldGrid {
        try SimulationTest.frames(session, 1)
        let automaton = try XCTUnwrap(shell.presenter.automaton, "the automaton pair exists")
        return automaton.readBack()
    }

    /// Checks that a fresh frame's GPU field equals the core's CPU field.
    private func assertMirrors(_ session: ExperienceSession, _ shell: ExperienceShell<SimulationPresenter>,
                               _ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let gpu = try gpuField(session, shell)
        let cpu = try SimulationTest.core(shell).model.field.current
        XCTAssertEqual(gpu, cpu, "\(name): the GPU field equals the CPU field", file: file, line: line)
    }

    func testRunningFramesStepInLockstepWithoutAReload() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "sim.speed", values: [4]).isAccepted, "×4: about 2 steps in 3 frames")
        try assertMirrors(session, shell, "open")
        let loads = presenter.gpuLoadCount
        let steps = presenter.gpuStepCount
        let start = try SimulationTest.core(shell).stepCount
        for frame in 0..<20 { try assertMirrors(session, shell, "frame \(frame)") }
        let ran = try SimulationTest.core(shell).stepCount - start
        XCTAssertGreaterThan(ran, 0, "the engine ran iterations")
        XCTAssertEqual(presenter.gpuStepCount - steps, ran, "exactly the iterations the engine ran")
        XCTAssertEqual(presenter.gpuLoadCount, loads, "stepping never reloads")
        XCTAssertEqual(presenter.mirroredStep, try SimulationTest.core(shell).stepCount)
        session.close()
        XCTAssertNil(presenter.automaton, "the pair is released with the rest")
    }

    func testAfterAContextRecreationAndAResizeTheFieldEqualsTheReference() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        try SimulationTest.frames(session, 12)
        try SimulationTest.pause(shell)
        try assertMirrors(session, shell, "before")
        let digest = try shell.engine.digest()
        let state = try SimulationTest.core(shell)
        let builds = presenter.resourceBuildCount
        var loads = presenter.gpuLoadCount

        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        try assertMirrors(session, shell, "after the context recreation")
        XCTAssertEqual(presenter.resourceBuildCount, builds + 1, "the pair is made again with the passes")
        XCTAssertEqual(presenter.gpuLoadCount, loads + 1, "loaded from the CPU state")
        XCTAssertEqual(try SimulationTest.core(shell), state, "the CPU state is kept")
        XCTAssertEqual(try shell.engine.digest(), digest)
        loads = presenter.gpuLoadCount

        let view = try XCTUnwrap(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: CGSize(width: 300, height: 220))
        view.layoutIfNeeded()
        try assertMirrors(session, shell, "after the resize")
        XCTAssertEqual(presenter.gpuLoadCount, loads + 1, "a resize loads from the CPU state")

        XCTAssertTrue(shell.handle(control: "sim.run").isAccepted)
        for frame in 0..<6 { try assertMirrors(session, shell, "running after the rebuilds, frame \(frame)") }
        try SimulationTest.pause(shell)
        let paused = try SimulationTest.core(shell)
        let pausedDigest = try shell.engine.digest()
        try SimulationTest.frames(session, 3)
        XCTAssertEqual(try SimulationTest.core(shell), paused, "drawing reads the core only")
        XCTAssertEqual(try shell.engine.digest(), pausedDigest, "drawing never changes the digest")
        session.close()
    }

    func testARefusedActionLeavesTheFieldAndAStepStepsIt() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        try SimulationTest.pause(shell)
        let before = try gpuField(session, shell)
        let loads = presenter.gpuLoadCount, steps = presenter.gpuStepCount
        let digest = try shell.engine.digest()

        XCTAssertFalse(shell.handle(control: "sim.pause").isAccepted, "already paused")
        XCTAssertFalse(shell.handle(control: "sim.preset", values: [2.5]).isAccepted, "not a whole index")
        try SimulationTest.frames(session, 3)
        XCTAssertEqual(try gpuField(session, shell), before, "a refused action leaves the GPU field")
        XCTAssertEqual(presenter.gpuLoadCount, loads)
        XCTAssertEqual(presenter.gpuStepCount, steps)
        XCTAssertEqual(try shell.engine.digest(), digest)

        XCTAssertTrue(shell.handle(control: "sim.step").isAccepted)
        try assertMirrors(session, shell, "one single step")
        XCTAssertEqual(presenter.gpuStepCount, steps + 1, "one GPU step")
        XCTAssertEqual(presenter.gpuLoadCount, loads, "a step is not a reload")
        session.close()
    }

    func testResetAFamilyChangeAndARestoreLoadTheField() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        try SimulationTest.frames(session, 12)
        try SimulationTest.pause(shell)
        for _ in 0..<3 { XCTAssertTrue(shell.handle(control: "sim.step").isAccepted) }
        try assertMirrors(session, shell, "stepped")
        var loads = presenter.gpuLoadCount

        XCTAssertTrue(shell.handle(control: "sim.reset").isAccepted)
        XCTAssertEqual(try SimulationTest.core(shell).stepCount, 0)
        try assertMirrors(session, shell, "after reset")
        XCTAssertEqual(presenter.gpuLoadCount, loads + 1, "reset loads the seeded start")
        loads = presenter.gpuLoadCount

        XCTAssertTrue(shell.handle(control: "sim.preset", values: [1]).isAccepted, "HighLife")
        try assertMirrors(session, shell, "after the preset change")
        XCTAssertEqual(presenter.gpuLoadCount, loads + 1, "a preset change loads")
        XCTAssertTrue(shell.handle(control: "sim.step").isAccepted)
        try assertMirrors(session, shell, "a HighLife step")
        loads = presenter.gpuLoadCount

        XCTAssertTrue(shell.handle(control: "sim.family", values: [2]).isAccepted)
        try SimulationTest.frames(session, 1)
        // From feature 119 (A16-P03) the wave has its own GPU mirror, so the mirror now holds the wave's spec.
        XCTAssertEqual(presenter.mirroredSpec?.kind, .wave, "another family mirrors its own field")
        XCTAssertTrue(shell.handle(control: "sim.family", values: [0]).isAccepted)
        try assertMirrors(session, shell, "back to the automaton")
        XCTAssertEqual(presenter.gpuLoadCount, loads + 1, "a family change loads")

        XCTAssertTrue(shell.handle(control: "sim.run").isAccepted)
        try SimulationTest.frames(session, 9)
        try SimulationTest.pause(shell)
        let snapshot = try shell.snapshot()
        let saved = try SimulationTest.core(shell)
        session.close()

        let second = ExperienceSession()
        let restored = try await SimulationTest.open(second, seed: 3)
        try SimulationTest.pause(restored)
        let restoredLoads = restored.presenter.gpuLoadCount
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        XCTAssertEqual(try SimulationTest.core(restored).model, saved.model)
        try assertMirrors(second, restored, "after the restore")
        XCTAssertEqual(restored.presenter.gpuLoadCount, restoredLoads + 1, "a restore loads the saved field")
        second.close()
    }

    func testAnInvalidStepProgramFailsTheSession() async throws {
        SimulationPresenter.stepFragmentOverride = "this is not GLSL"
        let session = ExperienceSession()
        let id = SimulationTest.id
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            SimulationExperience(shell: SimulationLabExperience.make(id: id), reduceMotion: false)
        }
        let result = await session.open(request)
        guard case .failed(let failure) = result else { return XCTFail("got \(result)") }
        XCTAssertEqual(failure.stage, .setup)
        XCTAssertEqual(failure.code, "experience.setup-failed")
        XCTAssertEqual(session.state, .failed)
        XCTAssertNil(session.renderHost, "nothing is drawn from a half-made pair")
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.leaked, 0, "nothing leaked")
        session.close()

        SimulationPresenter.stepFragmentOverride = nil
        let healthy = ExperienceSession()
        let shell = try await SimulationTest.open(healthy)
        XCTAssertNotNil(shell.presenter.automaton, "the shipped program opens")
        healthy.close()
    }
}
