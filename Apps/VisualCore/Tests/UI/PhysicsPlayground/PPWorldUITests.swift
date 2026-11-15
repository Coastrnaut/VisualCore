// PPWorldUITests — feature 087 (A11-P06) T-A11-608 (FR-A11-630): the world controls of Physics Playground (A11) inside
// the one app. Drop circle and Drop box each add one body (the canvas description and the buttons' value count them);
// Pause holds the world (the description says "paused", the button becomes Run and Step is enabled) and Run lets it go
// again (Step disabled); Step advances a paused world by exactly one tick, which the tutorial "Controlling time"
// observes (its step "Step forward one tick." completes only on tick start + 1); the time-scale picker moves to half
// and double speed (the description and the status line say so). One journey per test, each well under 60 s. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class PPWorldUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Drop circle and Drop box each add one body.
    @MainActor
    func testDropBody() {
        let app = PP.open()

        XCTAssertTrue(PP.waitForDescription(app) { PP.bodyCount(in: $0) != nil },
                      "the description counts the bodies: \(PP.description(app))")
        let before = PP.bodyCount(app) ?? 0
        PP.tap(app, "drop-circle")
        XCTAssertTrue(PP.waitForDescription(app) { PP.bodyCount(in: $0) == before + 1 },
                      "Drop circle adds one body to \(before): \(PP.description(app))")
        PP.tap(app, "drop-box")
        XCTAssertTrue(PP.waitForDescription(app) { PP.bodyCount(in: $0) == before + 2 },
                      "Drop box adds one more body: \(PP.description(app))")
        XCTAssertTrue(PP.waitForValue(PP.control(app, "drop-circle")) { $0 == "\(before + 2) bodies" },
                      "Drop circle speaks the new count (now \(PP.value(app, "drop-circle")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Pause holds the world and enables Step; Run lets it go again and disables Step.
    @MainActor
    func testPauseAndRun() {
        let app = PP.open()
        let pause = PP.control(app, "pause"), step = PP.control(app, "step")

        XCTAssertTrue(PP.waitForDescription(app) { PP.isRunning($0) }, "a fresh world runs: \(PP.description(app))")
        XCTAssertEqual(PP.value(app, "pause"), "Running", "the Pause button says running")
        XCTAssertTrue(PP.waitForEnabled(step, false), "Step is disabled while the world runs")

        PP.tap(app, "pause")
        XCTAssertTrue(PP.waitForDescription(app) { PP.isPaused($0) }, "the world is paused: \(PP.description(app))")
        XCTAssertTrue(PP.waitForValue(pause) { $0 == "Paused" },
                      "the button says paused (now \(PP.value(app, "pause")))")
        XCTAssertTrue(PP.waitForLabel(pause, timeout: PP.shortWait) { $0 == "Run" },
                      "the button becomes Run: \(pause.label)")
        XCTAssertTrue(PP.waitForEnabled(step, true), "Step is enabled while paused")

        PP.tap(app, "pause")
        XCTAssertTrue(PP.waitForDescription(app) { PP.isRunning($0) }, "the world runs again: \(PP.description(app))")
        XCTAssertTrue(PP.waitForLabel(pause, timeout: PP.shortWait) { $0 == "Pause" },
                      "the button says Pause: \(pause.label)")
        XCTAssertTrue(PP.waitForEnabled(step, false), "Step is disabled again")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Step advances a paused world by one tick: the tutorial "Controlling time" moves from "Step forward one tick." to
    /// "Choose half speed.", and the world stays paused.
    @MainActor
    func testSingleStep() {
        let app = PP.open()

        PP.tap(app, "tutorial-0-start")
        XCTAssertTrue(PP.waitForDescription(app) {
            $0.contains("Tutorial: Controlling time, step 1 of 4: Pause the world.")
        }, "the tutorial starts: \(PP.description(app))")
        PP.tap(app, "pause")
        XCTAssertTrue(PP.waitForDescription(app) {
            PP.isPaused($0) && $0.contains("Controlling time, step 2 of 4: Step forward one tick.")
        }, "pausing completes the first step: \(PP.description(app))")

        let step = PP.control(app, "step")
        XCTAssertTrue(PP.waitForEnabled(step, true), "Step is enabled while paused")
        PP.tap(app, "step")
        XCTAssertTrue(PP.waitForDescription(app) { $0.contains("Controlling time, step 3 of 4: Choose half speed.") },
                      "one step advances exactly one tick: \(PP.description(app))")
        XCTAssertTrue(PP.isPaused(PP.description(app)), "the world stays paused: \(PP.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The time-scale picker moves to half speed and to double speed; the description and the status line follow.
    @MainActor
    func testTimeScale() {
        let app = PP.open()

        XCTAssertTrue(PP.waitForDescription(app) { $0.contains(", normal speed (time scale 1×)") },
                      "a fresh world runs at normal speed: \(PP.description(app))")
        PP.chooseSegment(app, "time-scale", "half speed", index: 1, of: 4)
        XCTAssertTrue(PP.waitForDescription(app) { $0.contains(", half speed (time scale ½×)") },
                      "the half-speed segment halves the time scale: \(PP.description(app))")
        PP.chooseSegment(app, "time-scale", "double speed", index: 3, of: 4)
        XCTAssertTrue(PP.waitForDescription(app) { $0.contains(", double speed (time scale 2×)") },
                      "the double-speed segment doubles it: \(PP.description(app))")

        let status = PP.control(app, "status")
        waitFor(status, timeout: PP.shortWait, "the status line is there")
        PP.reveal(app, status)
        XCTAssertTrue(PP.waitForLabel(status, timeout: PP.shortWait) { $0.hasSuffix(", running, double speed") },
                      "the status line names the speed: \(status.label)")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
