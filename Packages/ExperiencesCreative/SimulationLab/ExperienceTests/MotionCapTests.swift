// MotionCapTests — feature 120 (A16-P04) T-A16-406 (FR-A16-412; clarification Q3). The speed caps: with neither setting
// every speed is allowed; under Reduce Motion ×1 is the fastest, and ×2 is refused with `a16.reduced-motion` and its
// sentence; under Reduce Flashing the automaton runs at ×0.25 at most and the other families at ×1; a restored or
// changed family above the cap is lowered to it.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class MotionCapTests: XCTestCase {
    func testTheCapsPerSettingAndFamily() {
        let presenter = SimulationPresenter(experienceID: SimulationTest.id)
        XCTAssertEqual(presenter.speedCap(kind: .automaton), 4)
        presenter.reduceMotion = true
        XCTAssertEqual(SimulationKind.allCases.map { presenter.speedCap(kind: $0) }, [2, 2, 2])
        presenter.reduceMotion = false
        presenter.reduceFlashing = true
        XCTAssertEqual(SimulationKind.allCases.map { presenter.speedCap(kind: $0) }, [0, 2, 2])
    }

    func testAFasterSpeedIsRefusedAndAFamilyChangeLowersIt() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        XCTAssertTrue(presenter.send("sim.family", [1], through: shell.port).isAccepted)
        XCTAssertTrue(presenter.send("sim.speed", [4], through: shell.port).isAccepted, "no setting: ×4")
        presenter.reduceFlashing = true
        try SimulationTest.frames(session, 1)
        let refused = presenter.send("sim.speed", [3], through: shell.port)
        XCTAssertEqual(refused, .rejected(.rule(code: SimulationRule.reducedMotion)))
        XCTAssertEqual(presenter.mirror.message, SimulationPresenter.reducedMotionSentence)
        XCTAssertTrue(presenter.send("sim.family", [0], through: shell.port).isAccepted)
        XCTAssertEqual(try SimulationTest.core(shell).speedIndex, 0, "the automaton is lowered to ×0.25")
        XCTAssertEqual(presenter.mirror.speedCap, 0)
        session.close()
    }

    func testActivationLowersARestoredSpeed() async throws {
        let id = SimulationTest.id
        var made: SimulationExperience?
        let first = ExperienceSession()
        let saving = try await SimulationTest.open(first)
        XCTAssertTrue(saving.handle(control: "sim.speed", values: [4]).isAccepted)
        let snapshot = try saving.snapshot()
        first.close()
        let session = ExperienceSession()
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: snapshot, refusedSnapshotFails: false) {
            let experience = SimulationExperience(shell: SimulationLabExperience.make(id: id), reduceMotion: true,
                                                  reduceFlashing: false)
            made = experience
            return experience
        }
        _ = await session.open(request)
        let experience = try XCTUnwrap(made)
        XCTAssertLessThanOrEqual(try XCTUnwrap(experience.shell.engine.core).speedIndex, 2, "lowered to ×1")
        session.close()
    }

    /// T-A16-613 (feature 122; constitution VII): the registry's factory hands both settings to the presenter's caps,
    /// and with Reduce Motion the experience opens paused.
    func testTheRegistryFactoryPassesBothSettingsToTheCaps() async throws {
        let temporary = TemporarySimulationStorage()
        defer { temporary.remove() }
        let id = SimulationTest.id
        let cases: [(motion: Bool, flashing: Bool, caps: [Int])] = [(false, false, [4, 4]), (true, false, [2, 2]),
                                                                   (false, true, [0, 2])]
        for setting in cases {
            let name = "reduceMotion \(setting.motion), reduceFlashing \(setting.flashing)"
            var made: SimulationExperience?
            let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
                let experience = SimulationLabExperience.make(id: id, storage: temporary.storage,
                                                              reduceMotion: setting.motion,
                                                              reduceFlashing: setting.flashing)
                made = experience as? SimulationExperience
                return experience
            }
            let session = ExperienceSession()
            let opened = await session.open(request)
            XCTAssertEqual(opened, .running, name)
            let experience = try XCTUnwrap(made, name + ": the factory gives the wrapper")
            let presenter = experience.presenter
            XCTAssertEqual([presenter.speedCap(kind: .automaton), presenter.speedCap(kind: .reactionDiffusion)],
                           setting.caps, name)
            XCTAssertNotNil(presenter.presets, name + ": the factory hands the storage to the presenter")
            let core = try XCTUnwrap(experience.shell.engine.core)
            XCTAssertEqual(core.isRunning, !setting.motion, name + ": paused under Reduce Motion")
            session.close()
        }
    }
}
