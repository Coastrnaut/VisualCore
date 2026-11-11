// ControlsUITests — feature 023 T-A02-505 (FR-A02-501, FR-A02-503; US1 AC1, AC2, AC4, AC5; SC-A02-501): Pause turns
// into Resume and enables Step, Step keeps the pause, Reset keeps the pause, Resume disables Step again.
import XCTest

final class ControlsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testPauseStepResetResume() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["fap.home.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["fap.canvas"].waitForExistence(timeout: 10))
        let pause = app.buttons["fap.pause"], step = app.buttons["fap.step"], reset = app.buttons["fap.reset"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        XCTAssertEqual(pause.label, "Pause")
        XCTAssertFalse(step.isEnabled, "Step is disabled while running")
        XCTAssertTrue(reset.isEnabled)

        pause.tap()
        XCTAssertEqual(pause.label, "Resume")
        XCTAssertTrue(step.isEnabled, "Step is enabled while paused")
        let paused = app.descendants(matching: .any)["fap.canvas"].label
        XCTAssertTrue(paused.contains("aused"), "the canvas says it is paused: '\(paused)'")

        for _ in 0..<3 { step.tap() }
        XCTAssertEqual(pause.label, "Resume", "Step keeps the pause")
        reset.tap()
        XCTAssertEqual(pause.label, "Resume", "Reset keeps the pause")
        XCTAssertTrue(step.isEnabled)

        pause.tap()
        XCTAssertEqual(pause.label, "Pause")
        XCTAssertFalse(step.isEnabled)
    }
}
