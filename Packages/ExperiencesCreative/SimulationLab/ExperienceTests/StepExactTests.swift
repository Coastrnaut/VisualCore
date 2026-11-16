// StepExactTests — feature 120 (A16-P04) T-A16-404 (FR-A16-402; SC-A16-401; the phase's regression fixture). In every
// family, paused, Step through the presenter's controls path advances exactly one discrete iteration: the field equals
// one CPU `SimulationModel.step()` from the previous state and the step count rises by one; a second Step does the
// same.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class StepExactTests: XCTestCase {
    func testOneStepIsExactlyOneIterationInEveryFamily() async throws {
        for family in 0..<3 {
            let session = ExperienceSession()
            let shell = try await SimulationTest.open(session)
            let presenter = shell.presenter
            if family > 0 { XCTAssertTrue(presenter.send("sim.family", [Double(family)], through: shell.port).isAccepted) }
            try SimulationTest.frames(session, 3)
            XCTAssertTrue(presenter.send("sim.pause", through: shell.port).isAccepted)
            for round in 0..<2 {
                let before = try SimulationTest.core(shell)
                var reference = before.model
                reference.step()
                XCTAssertTrue(presenter.send("sim.step", through: shell.port).isAccepted)
                try SimulationTest.frames(session, 2)
                let after = try SimulationTest.core(shell)
                XCTAssertEqual(after.stepCount, before.stepCount + 1, "family \(family) round \(round)")
                XCTAssertEqual(after.model.field, reference.field, "family \(family) round \(round): one iteration")
            }
            session.close()
        }
    }
}
