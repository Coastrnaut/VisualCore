// SimulationControlTests — feature 023 T-A02-503 (FR-A02-501; US1 AC1, AC5).
import FluidArtPlaygroundCore
import XCTest

final class SimulationControlTests: XCTestCase {
    func testRunningState() {
        let c = SimulationControl()
        XCTAssertFalse(c.paused)
        XCTAssertFalse(c.stepEnabled)
        XCTAssertEqual(c.pauseLabel, "Pause")
        XCTAssertEqual(c.stepHint, "Pause first to step one frame")
    }

    func testPausedState() {
        var c = SimulationControl()
        XCTAssertEqual(c.toggle(), .paused)
        XCTAssertTrue(c.paused)
        XCTAssertTrue(c.stepEnabled)
        XCTAssertEqual(c.pauseLabel, "Resume")
        XCTAssertEqual(c.stepHint, "Advances the fluid by one frame")
        XCTAssertEqual(c.toggle(), .resumed)
        XCTAssertFalse(c.paused)
    }

    func testAnnouncements() {
        XCTAssertEqual(SimulationControl.Announcement.paused.text, "Paused")
        XCTAssertEqual(SimulationControl.Announcement.resumed.text, "Resumed")
        XCTAssertEqual(SimulationControl.Announcement.stepped.text, "Stepped one frame")
        XCTAssertEqual(SimulationControl.Announcement.reset.text, "Reset to the starting picture")
    }
}
