// TimeStepMessageTests — feature 119 (A16-P03) T-A16-311 (FR-A16-330; US4/AC1–2). The controls' path of a refused time
// step: in a session, `SimulationPresenter.send("sim.timestep", …)` beyond the wave's Courant limit is refused and the
// message line reads "The wave step is too large: the Courant number must stay at or below 0.707."; beyond the
// reaction-diffusion limit it reads the sentence naming 1.5625; the state is unchanged; an accepted time step clears
// the message and the status line states it. A few frames, no prompt.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class TimeStepMessageTests: XCTestCase {
    func testRefusedTimeStepsShowTheirSentenceAndAnAcceptedOneClearsIt() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter

        XCTAssertTrue(presenter.send("sim.family", [2], through: shell.port).isAccepted)
        try SimulationTest.frames(session, 1)
        try SimulationTest.pause(shell)
        let wave = try SimulationTest.core(shell)
        XCTAssertFalse(presenter.send("sim.timestep", [1.0], through: shell.port).isAccepted)
        XCTAssertEqual(presenter.mirror.message,
                       "The wave step is too large: the Courant number must stay at or below 0.707.")
        XCTAssertEqual(try SimulationTest.core(shell), wave, "a refusal changes nothing")

        XCTAssertTrue(presenter.send("sim.family", [1], through: shell.port).isAccepted)
        try SimulationTest.frames(session, 1)
        XCTAssertFalse(presenter.send("sim.timestep", [1.6], through: shell.port).isAccepted)
        XCTAssertEqual(presenter.mirror.message,
                       "The reaction-diffusion step is too large: the time step must stay at or below 1.5625.")

        XCTAssertTrue(presenter.send("sim.timestep", [0.75], through: shell.port).isAccepted)
        XCTAssertEqual(presenter.mirror.message, "", "an accepted step clears the message")
        try SimulationTest.frames(session, 1)
        XCTAssertTrue(presenter.mirror.status.hasSuffix("time step 0.75"))
        XCTAssertEqual(presenter.mirror.timeStep, 0.75)
        session.close()
    }
}
