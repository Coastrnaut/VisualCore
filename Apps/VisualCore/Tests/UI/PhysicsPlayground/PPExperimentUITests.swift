// PPExperimentUITests — feature 087 (A11-P06) T-A11-608 (FR-A11-630): the experiment controls of Physics Playground
// (A11) inside the one app. The preset menu picker opens Pendulum (the experiment line, the picker's value and the
// canvas description name it); the Force arrows toggle turns the overlay on and off (its value, the description's
// "force arrows on" / "arrows off") beside the state panel and its note that contact and drag forces are not drawn; the
// tutorial "Controlling time" starts (its progress and step appear, Stop is enabled) and stops; the tutorial "Springs
// and energy" advances as the spring chain is opened and the force arrows are shown. One journey per test, each well
// under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class PPExperimentUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The preset picker opens Pendulum: the experiment line, the picker and the description name it.
    @MainActor
    func testOpenPreset() {
        let app = PP.open()

        XCTAssertTrue(PP.waitForDescription(app) { $0.contains("Experiment: Free play.") },
                      "a fresh start is free play: \(PP.description(app))")
        XCTAssertTrue(PP.pick(app, "preset", "Pendulum"),
                      "the preset picker shows Pendulum (now \(PP.value(app, "preset")))")
        XCTAssertTrue(PP.waitForDescription(app) { $0.contains("Experiment: Pendulum.") },
                      "the description names the opened preset: \(PP.description(app))")
        let experiment = PP.control(app, "experiment")
        XCTAssertTrue(PP.waitForLabel(experiment, timeout: PP.shortWait) { $0 == "Experiment: Pendulum." },
                      "the experiment line names it: \(experiment.label)")
        XCTAssertTrue(PP.waitForDescription(app) { PP.isRunning($0) }, "the preset runs: \(PP.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The Force arrows toggle turns the overlay on and off; the state panel and the arrow note are shown beside it.
    @MainActor
    func testForceArrows() {
        let app = PP.open()
        let name = "force-arrows"

        XCTAssertTrue(PP.waitForDescription(app) { $0.contains(", arrows off.") },
                      "a fresh start draws no arrows: \(PP.description(app))")
        waitFor(PP.control(app, name), timeout: PP.shortWait, "the Force arrows toggle is there")
        XCTAssertEqual(PP.value(app, name), "Off", "the toggle starts off")

        PP.flip(app, name)
        XCTAssertEqual(PP.value(app, name), "On", "the toggle says on")
        XCTAssertTrue(PP.waitForDescription(app) { $0.contains(", force arrows on.") },
                      "the description names the force arrows: \(PP.description(app))")

        let panel = PP.control(app, "panel"), note = PP.control(app, "arrow-note")
        waitFor(panel, timeout: PP.shortWait, "the state panel is there")
        XCTAssertEqual(panel.label, "Educational approximation", "the panel's note")
        waitFor(note, timeout: PP.shortWait, "the arrow note is there")
        PP.reveal(app, note)
        XCTAssertTrue(note.label.contains("contact and drag forces are not drawn"),
                      "the arrow note says what the arrows leave out: \(note.label)")

        PP.flip(app, name)
        XCTAssertEqual(PP.value(app, name), "Off", "the toggle says off again")
        XCTAssertTrue(PP.waitForDescription(app) { $0.contains(", arrows off.") },
                      "the arrows are off again: \(PP.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Start "Controlling time": its progress and first step appear and Stop is enabled; Stop ends it.
    @MainActor
    func testStartTutorial() {
        let app = PP.open()
        let stop = PP.control(app, "tutorial-stop")

        XCTAssertFalse(PP.control(app, "tutorial-step").exists, "no tutorial runs at the start")
        XCTAssertTrue(PP.waitForEnabled(stop, false), "Stop is disabled without a tutorial")

        PP.tap(app, "tutorial-0-start")
        let progress = PP.control(app, "tutorial-progress"), step = PP.control(app, "tutorial-step")
        waitFor(progress, timeout: PP.shortWait, "the tutorial's progress appears")
        XCTAssertTrue(PP.waitForLabel(progress, timeout: PP.shortWait) { $0 == "Controlling time, step 1 of 4" },
                      "the progress names the tutorial and its step: \(progress.label)")
        waitFor(step, timeout: PP.shortWait, "the tutorial's step appears")
        XCTAssertTrue(PP.waitForValue(step) { $0 == "Pause the world." } || step.label.contains("Pause the world."),
                      "the step says what to do (value \(step.value as? String ?? ""), label \(step.label))")
        XCTAssertTrue(PP.waitForValue(PP.control(app, "tutorial-0-start")) { $0 == "Running" },
                      "the Start button says running (now \(PP.value(app, "tutorial-0-start")))")
        XCTAssertTrue(PP.waitForDescription(app) {
            $0.contains("Tutorial: Controlling time, step 1 of 4: Pause the world.")
        }, "the description names the tutorial: \(PP.description(app))")
        XCTAssertTrue(PP.waitForEnabled(stop, true), "Stop is enabled while the tutorial runs")

        PP.tap(app, "tutorial-stop")
        XCTAssertTrue(waitUntilGone(step, timeout: PP.shortWait), "Stop ends the tutorial")
        XCTAssertFalse(PP.description(app).contains("Tutorial:"), "the description no longer names a tutorial")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// "Springs and energy" advances as the spring chain is opened and the force arrows are shown.
    @MainActor
    func testTutorialAdvances() {
        let app = PP.open()

        PP.tap(app, "tutorial-1-start")
        XCTAssertTrue(PP.waitForDescription(app) {
            $0.contains("Tutorial: Springs and energy, step 1 of 3: Open the spring chain.")
        }, "the tutorial starts: \(PP.description(app))")

        XCTAssertTrue(PP.pick(app, "preset", "Spring chain"),
                      "the preset picker shows Spring chain (now \(PP.value(app, "preset")))")
        XCTAssertTrue(PP.waitForDescription(app) {
            $0.contains("Experiment: Spring chain.")
                && $0.contains("Springs and energy, step 2 of 3: Show the force arrows.")
        }, "opening the spring chain completes the first step: \(PP.description(app))")

        // The last step completes after 3 s of running and ends the tutorial; a description read after that no longer
        // names a tutorial, which also proves the second step was completed (it was seen running just above).
        PP.flip(app, "force-arrows")
        XCTAssertTrue(PP.waitForDescription(app) {
            $0.contains("force arrows on.")
                && ($0.contains("Springs and energy, step 3 of 3: Let it run for 3 seconds.")
                    || !$0.contains("Tutorial:"))
        }, "showing the force arrows completes the second step: \(PP.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
