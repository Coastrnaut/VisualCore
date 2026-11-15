// NASettingsUITests — feature 080 (A10-P06) T-A10-608 (FR-A10-630; SC-A10-604): the settings of Neon Arcade (A10)
// inside the one app. The Sound toggle (`settings.sound`) and the Haptics toggle (`settings.haptics`) speak "On" or
// "Off"; flipping one changes its value and flipping it again restores it. The sensitivity stepper
// (`settings.sensitivity`, five steps, value "Step 3 of 5, normal") moves one step and speaks a new step, then moves
// back. One journey per test, each well under 60 s. System accessibility audits wait for the device campaign (owner
// ruling of 2026-11-13).
import XCTest

final class NASettingsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Flips the toggle `name` twice: the value moves between "On" and "Off" and returns to where it started.
    @MainActor
    private func checkToggle(_ app: XCUIApplication, _ name: String, file: StaticString = #filePath,
                             line: UInt = #line) {
        let toggle = NA.control(app, name)
        waitFor(toggle, timeout: NA.shortWait, "\(name) is there", file: file, line: line)
        NA.reveal(app, toggle, file: file, line: line)
        let before = NA.value(app, name)
        XCTAssertTrue(["On", "Off"].contains(before), "\(name) speaks On or Off (now \(before))", file: file, line: line)

        NA.flip(app, name, file: file, line: line)
        let flipped = NA.value(app, name)
        XCTAssertEqual(flipped, before == "On" ? "Off" : "On", "\(name) changed its value", file: file, line: line)

        NA.flip(app, name, file: file, line: line)
        XCTAssertEqual(NA.value(app, name), before, "\(name) flipped back", file: file, line: line)
    }

    /// The Sound toggle changes its value when flipped and flips back.
    @MainActor
    func testSoundToggle() {
        let app = NA.open()
        checkToggle(app, "settings.sound")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The Haptics toggle changes its value when flipped and flips back.
    @MainActor
    func testHapticsToggle() {
        let app = NA.open()
        checkToggle(app, "settings.haptics")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The sensitivity stepper speaks its step, moves one step to a new step and moves on again.
    @MainActor
    func testSensitivityStepper() {
        let app = NA.open()
        let name = "settings.sensitivity"
        let sensitivity = NA.control(app, name)
        waitFor(sensitivity, timeout: NA.shortWait, "the sensitivity stepper is there")
        NA.reveal(app, sensitivity)
        let isStep: (String) -> Bool = { $0.hasPrefix("Step ") && $0.contains(" of 5, ") }
        XCTAssertTrue(NA.waitForValue(sensitivity) { isStep($0) },
                      "the stepper speaks its step (now \(NA.value(app, name)))")

        let first = NA.changeSensitivity(app)
        XCTAssertTrue(NA.waitForValue(sensitivity) { isStep($0) && $0 != first },
                      "the sensitivity changed from \(first) (now \(NA.value(app, name)))")

        let second = NA.changeSensitivity(app)
        XCTAssertTrue(NA.waitForValue(sensitivity) { isStep($0) && $0 != second },
                      "the sensitivity changed again from \(second) (now \(NA.value(app, name)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
