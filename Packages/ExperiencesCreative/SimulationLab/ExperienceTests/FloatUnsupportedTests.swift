// FloatUnsupportedTests — feature 119 (A16-P03) T-A16-305 (FR-A16-310; SC-A16-303; clarification Q5). Without
// floating-point render targets (the presenter's seam `forceFloatUnsupported`): no Gray-Scott or wave pair is made
// (float or 8-bit), choosing either family through the controls' path is refused with `a16.unsupported` and the
// sentence in the message line, the controls' mirror marks them unavailable, and a restored reaction-diffusion state
// is drawn from the CPU upload with the sentence in the status line.
import Foundation
import XCTest
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class FloatUnsupportedTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated { SimulationPresenter.forceFloatUnsupported = true }
    }

    override func tearDown() {
        MainActor.assumeIsolated { SimulationPresenter.forceFloatUnsupported = false }
        super.tearDown()
    }

    func testTheFamiliesAreRefusedAndNoFieldIsMade() async throws {
        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.floatSupported, false)
        XCTAssertNil(presenter.grayScott, "no Gray-Scott pair")
        XCTAssertNil(presenter.wave, "no wave pair")
        XCTAssertNil(presenter.reactionDisplay)
        XCTAssertNil(presenter.waveDisplay)
        XCTAssertFalse(presenter.mirror.floatFamiliesAvailable)
        for family in [1.0, 2.0] {
            let result = presenter.send("sim.family", [family], through: shell.port)
            XCTAssertEqual(result, .rejected(.rule(code: SimulationRule.unsupported)))
            XCTAssertEqual(presenter.mirror.message, SimulationPresenter.unsupportedSentence)
            XCTAssertEqual(try SimulationTest.core(shell).kind, .automaton, "nothing changed")
        }
        XCTAssertTrue(presenter.send("sim.preset", [1], through: shell.port).isAccepted, "the automaton still works")
        session.close()
    }

    func testARestoredStateIsDrawnFromTheCPUWithTheSentence() async throws {
        SimulationPresenter.forceFloatUnsupported = false
        let first = ExperienceSession()
        let saving = try await SimulationTest.open(first)
        XCTAssertTrue(saving.handle(control: "sim.family", values: [1]).isAccepted)
        try SimulationTest.pause(saving)
        let snapshot = try saving.snapshot()
        first.close()
        SimulationPresenter.forceFloatUnsupported = true

        let session = ExperienceSession()
        let shell = try await SimulationTest.open(session)
        let presenter = shell.presenter
        let uploads = presenter.uploadCount
        try shell.restore(ExperienceSnapshot(data: snapshot.encoded()))
        XCTAssertEqual(try SimulationTest.core(shell).kind, .reactionDiffusion, "the state is kept")
        try SimulationTest.frames(session, 2)
        XCTAssertNil(presenter.grayScott)
        XCTAssertGreaterThan(presenter.uploadCount, uploads, "drawn from the CPU upload")
        XCTAssertTrue(presenter.mirror.status.hasSuffix(SimulationPresenter.unsupportedSentence))
        session.close()
    }
}
