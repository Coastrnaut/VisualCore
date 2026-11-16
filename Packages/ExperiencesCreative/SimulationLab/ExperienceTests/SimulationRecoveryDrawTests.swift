// SimulationRecoveryDrawTests — feature 122 (A16-P06) T-A16-604 (FR-A16-610; clarification Q5). Short runs only (well
// under 10 s, no wall-clock assertion). Through the one app's session host on the simulator, with a temporary
// experience storage: an experiment (reaction-diffusion at Δt 0.75) is saved through the presenter's library as
// `preset-00000000-0000-4000-8000-0000000000b1.json`; a drawing failure injected with the presenter's seam
// (`failNextDraw`, which throws `SimulationDrawError.injected` once) fails the session and leaves the preset file byte
// for byte, also after the session is closed. A new session over the same storage lists the experiment, and opening it
// through `sim.spec` (`SimulationCore.specValues`) gives the same spec at step 0 and draws.
import Foundation
import UIKit
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class SimulationRecoveryDrawTests: XCTestCase {
    /// The experience's temporary storage.
    private var temporary: TemporarySimulationStorage!

    /// The synthetic id of the saved experiment.
    private static let presetID = UUID(uuidString: "00000000-0000-4000-8000-0000000000b1")!

    override func setUp() async throws {
        temporary = TemporarySimulationStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
        temporary = nil
    }

    /// Opens Simulation Lab in `session` with a presenter over the temporary storage, lays the view out and returns the
    /// shell (the `PresetStoreTests` pattern).
    private func open(_ session: ExperienceSession) async throws -> ExperienceShell<SimulationPresenter> {
        let id = SimulationTest.id
        var made: ExperienceShell<SimulationPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = SimulationLabExperience.make(id: id, storage: self.temporary.storage)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 240, height: 160)
            view.layoutIfNeeded()
        }
        return try XCTUnwrap(made)
    }

    func testAFailedDrawLeavesTheSavedExperimentAndANewSessionOpensIt() async throws {
        let fileName = SimulationPresetStore.fileName(for: Self.presetID)

        let first = ExperienceSession()
        let saving = try await open(first)
        XCTAssertTrue(saving.presenter.send("sim.family", [1], through: saving.port).isAccepted)
        XCTAssertTrue(saving.presenter.send("sim.timestep", [0.75], through: saving.port).isAccepted)
        try SimulationTest.frames(first, 1)
        XCTAssertEqual(first.state, .running)
        let spec = try SimulationTest.core(saving).model.spec
        let store = try XCTUnwrap(saving.presenter.presets)
        let preset = ExperimentPreset(name: "Slow spots", spec: spec, annotation: "A test experiment.",
                                      source: "Saved by you", license: "original")
        XCTAssertNil(store.save(preset, id: Self.presetID))
        let bytes = try temporary.storage.read(fileName)
        XCTAssertEqual(bytes, preset.encoded(), "the file holds exactly the preset's bytes")

        saving.presenter.failNextDraw = true
        _ = first.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(first.state, .failed, "a drawing failure fails the session (FR-A16-610)")
        XCTAssertNotNil(first.failure)
        XCTAssertFalse(saving.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try temporary.storage.read(fileName), bytes, "the preset file is unchanged by the failure")
        first.close()
        XCTAssertEqual(first.hostsAlive, 0)
        XCTAssertEqual(try temporary.storage.read(fileName), bytes, "the preset file is unchanged after close")

        let second = ExperienceSession()
        defer { second.close() }
        let reopened = try await open(second)
        XCTAssertNil(second.failure)
        let entry = try XCTUnwrap(reopened.presenter.presets?.entries.first { $0.id == Self.presetID },
                                  "the new session lists the saved experiment")
        XCTAssertEqual(entry.preset, preset)
        XCTAssertEqual(reopened.presenter.presets?.problems, [])
        XCTAssertTrue(reopened.presenter.send("sim.spec", SimulationCore.specValues(entry.preset.spec),
                                              through: reopened.port).isAccepted)
        let core = try SimulationTest.core(reopened)
        XCTAssertEqual(core.model.spec, spec, "the same spec")
        XCTAssertEqual(core.stepCount, 0)
        try SimulationTest.frames(second, 1)
        XCTAssertEqual(second.state, .running, "the new session draws")
        XCTAssertEqual(try temporary.storage.read(fileName), bytes, "opening the experiment rewrites nothing")
    }
}
