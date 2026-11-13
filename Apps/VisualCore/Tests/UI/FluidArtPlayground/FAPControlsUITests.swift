// FAPControlsUITests — feature 193 (UA-F07) T-U07-022: port of the standalone app's ControlsUITests (feature 023
// T-A02-505; FR-A02-501, FR-A02-503; US1 AC1, AC2, AC4, AC5; SC-A02-501) into the one app. Pause turns into Resume
// and enables Step, the canvas description says it is paused, Step keeps the pause, Reset keeps the pause, Resume
// disables Step again. The controls are A02's native controls below the canvas (`pause`, `step`, `reset`).
import XCTest

final class FAPControlsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testPauseStepResetResume() {
        let app = FAP.open()
        let pause = FAP.control(app, "pause"), step = FAP.control(app, "step"), reset = FAP.control(app, "reset")
        FAP.reveal(app, pause)
        XCTAssertEqual(pause.label, "Pause")
        XCTAssertFalse(step.isEnabled, "Step is disabled while running")
        XCTAssertTrue(reset.isEnabled)

        pause.tap()
        XCTAssertTrue(FAP.waitForLabel(pause) { $0 == "Resume" }, "Pause becomes Resume: \(pause.label)")
        XCTAssertTrue(step.isEnabled, "Step is enabled while paused")
        let canvas = FAP.canvas(app)
        XCTAssertTrue(FAP.waitForLabel(canvas) { $0.contains("paused") },
                      "the canvas says it is paused: '\(canvas.label)'")

        FAP.reveal(app, step)
        for _ in 0..<3 { step.tap() }
        XCTAssertEqual(pause.label, "Resume", "Step keeps the pause")
        FAP.reveal(app, reset)
        reset.tap()
        XCTAssertTrue(FAP.waitForLabel(pause) { $0 == "Resume" }, "Reset keeps the pause")
        XCTAssertTrue(step.isEnabled)
        XCTAssertFalse(element(app, "session.failure").exists)

        FAP.reveal(app, pause)
        pause.tap()
        XCTAssertTrue(FAP.waitForLabel(pause) { $0 == "Pause" }, "Resume becomes Pause: \(pause.label)")
        XCTAssertFalse(step.isEnabled, "Step is disabled again while running")
        XCTAssertTrue(FAP.waitForLabel(canvas) { !$0.contains("paused") }, "the canvas runs: '\(canvas.label)'")
    }
}
