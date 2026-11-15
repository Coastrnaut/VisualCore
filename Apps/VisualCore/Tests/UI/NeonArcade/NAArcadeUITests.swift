// NAArcadeUITests — feature 078 (A10-P04) T-A10-404 (FR-A10-422; SC-A10-405): Neon Arcade opens on the title screen;
// Start begins a run (the canvas description says "playing") and the Steer right and Steer left buttons are held in turn
// without a failure; in a second test the Pause toggle pauses the run (the description says "paused") and resumes it;
// in a third the sensitivity control moves one step and speaks a new value; in a fourth the title screen shows the
// best-score text. One journey per test, each well under 60 s. System accessibility audits wait for the device
// campaign (owner ruling of 2026-11-13).
import XCTest

final class NAArcadeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Start, then hold Steer right and Steer left; the run keeps playing and steering returns to straight.
    @MainActor
    func testStartAndSteer() {
        let app = NA.openAndStart()

        NA.hold(app, "run.right")
        NA.hold(app, "run.left")
        XCTAssertTrue(NA.waitForValue(NA.control(app, "run.straight")) { $0 == "Straight" },
                      "releasing a steer button steers straight (now \(NA.value(app, "run.straight")))")
        XCTAssertTrue(NA.waitForValue(NA.control(app, "run.left")) { $0 == "Not steering" },
                      "Steer left is released (now \(NA.value(app, "run.left")))")
        XCTAssertTrue(NA.description(app).hasPrefix(NA.describedPrefix),
                      "the canvas is still described: \(NA.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Start, Pause (the description says paused), resume (playing again).
    @MainActor
    func testPauseAndResume() {
        let app = NA.openAndStart()

        XCTAssertEqual(NA.value(app, "run.pause"), "Playing", "a started run is not paused")
        NA.flip(app, "run.pause")
        XCTAssertEqual(NA.value(app, "run.pause"), "Paused", "the toggle says paused")
        XCTAssertTrue(NA.waitForDescription(app) { NA.isPaused($0) },
                      "the canvas says paused: \(NA.description(app))")

        NA.flip(app, "run.pause", upFirst: true)
        XCTAssertEqual(NA.value(app, "run.pause"), "Playing", "the toggle says playing")
        XCTAssertTrue(NA.waitForDescription(app) { NA.isPlaying($0) },
                      "the canvas says playing again: \(NA.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The sensitivity control moves one step and speaks a new value.
    @MainActor
    func testSensitivity() {
        let app = NA.open()

        let sensitivity = NA.control(app, "settings.sensitivity")
        waitFor(sensitivity, timeout: NA.shortWait, "the sensitivity control is there")
        let before = NA.changeSensitivity(app)
        XCTAssertTrue(NA.waitForValue(sensitivity) { !$0.isEmpty && $0 != before },
                      "the sensitivity changed from \(before) (now \(NA.value(app, "settings.sensitivity")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The title screen shows the best-score text.
    @MainActor
    func testTitleShowsBestScore() {
        let app = NA.open()

        XCTAssertTrue(NA.waitForDescription(app) { $0.contains("title screen") },
                      "a fresh start shows the title screen: \(NA.description(app))")
        let best = NA.control(app, "scores.best")
        waitFor(best, timeout: NA.shortWait, "the best-score text is there")
        NA.reveal(app, best, upFirst: true)
        XCTAssertTrue(NA.waitForLabel(best, timeout: NA.shortWait) { $0.localizedCaseInsensitiveContains("Best") },
                      "the best-score text names the best score: \(best.label)")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
