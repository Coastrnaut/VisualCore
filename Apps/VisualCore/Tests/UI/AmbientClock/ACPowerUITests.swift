// ACPowerUITests — feature 135 (A18-P05) T-A18-505 (FR-A18-505; SC-A18-504): the clock, night mode and reduced
// motion of Ambient Clock (A18) inside the one app. A fresh start (erased data) shows the canvas labelled with the
// spoken time, night mode "Off" and reduced motion "Off"; choosing On in the night-mode menu and switching reduced
// motion on change their values; after the app was sent to the background and ended, a start without the reset
// restores both from the experience's snapshot (schema 3). One journey per test, well under 60 s. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class ACPowerUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The clock opens: the canvas is there and labelled with a time (digits around a ":").
    @MainActor
    func testTheClockOpensWithItsTime() {
        let app = AC.open()

        let canvas = AC.canvas(app)
        XCTAssertTrue(canvas.exists, "the canvas is there")
        XCTAssertTrue(AC.isTime(AC.description(app)), "the canvas is labelled with a time (now \(AC.description(app)))")
        XCTAssertNotEqual(AC.description(app), AC.fallbackDescription, "the canvas is past its first instant")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Night mode chosen On and reduced motion switched on: both controls say so.
    @MainActor
    func testNightModeOnAndReduceMotionOnChangeTheirValues() {
        let app = AC.open()

        XCTAssertEqual(AC.value(app, "night-mode"), "Off", "a fresh start has night mode off")
        XCTAssertTrue(AC.choose(app, "night-mode", "On"), "night mode is chosen On")

        waitFor(AC.control(app, "reduce-motion"), timeout: AC.shortWait, "the Reduce motion toggle is there")
        XCTAssertEqual(AC.value(app, "reduce-motion"), "Off", "a fresh start has reduced motion off")
        XCTAssertTrue(AC.flip(app, "reduce-motion"), "the Reduce motion toggle is flipped")
        XCTAssertTrue(AC.waitForValue(AC.control(app, "reduce-motion")) { $0 == "On" },
                      "reduced motion says On (now \(AC.value(app, "reduce-motion")))")
        XCTAssertEqual(AC.value(app, "night-mode"), "On", "night mode stays On")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Night mode On and reduced motion on survive the end of the app: a start without the reset restores both.
    @MainActor
    func testNightModeAndReduceMotionComeBackAfterARelaunch() {
        let app = AC.open()
        XCTAssertTrue(AC.choose(app, "night-mode", "On"), "night mode is chosen On")
        XCTAssertTrue(AC.flip(app, "reduce-motion"), "the Reduce motion toggle is flipped")
        XCTAssertTrue(AC.waitForValue(AC.control(app, "reduce-motion")) { $0 == "On" },
                      "reduced motion says On (now \(AC.value(app, "reduce-motion")))")

        let second = AC.reopen(app)
        XCTAssertTrue(AC.waitForValue(AC.control(second, "night-mode")) { $0 == "On" },
                      "night mode is still On (now \(AC.value(second, "night-mode")))")
        XCTAssertTrue(AC.waitForValue(AC.control(second, "reduce-motion")) { $0 == "On" },
                      "reduced motion is still On (now \(AC.value(second, "reduce-motion")))")
        XCTAssertFalse(element(second, "vc.unreadable").exists, "the stored state was read")
        XCTAssertFalse(element(second, "session.failure").exists, "no failure")
    }
}
