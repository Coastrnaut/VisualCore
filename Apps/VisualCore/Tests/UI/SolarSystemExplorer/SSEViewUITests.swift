// SSEViewUITests — feature 108 (A14-P06) T-A14-609 (FR-A14-630; clarification Q4): focusing a planet, a date step with
// play and the scale switch of Solar System Explorer (A14) inside the one app. On a fresh start (erased data) the Sun
// is selected at 2000-01-01 in the enhanced scale, paused at 1 day/s. Choosing Earth from the Body menu makes the
// status line name Earth ("Earth selected, body 4 of 9"); "+365 days" (`date-plus-365`) moves the date; Play runs
// simulated time until the date moves again and Pause stops it ("Paused"); switching Scale to True relative makes the
// legend say "Distances and sizes to one scale; small bodies marked" and the canvas description end with it. One
// journey per test, well under 60 s. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class SSEViewUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The Body menu focuses Earth, a year step and Play move the date, Pause stops the clock.
    @MainActor
    func testFocusEarthStepAYearAndPlay() {
        let app = SSE.open()

        XCTAssertTrue(SSE.waitForStatus(app) { SSE.names($0, "Sun") },
                      "a fresh start selects the Sun (now \(SSE.value(app, "status")))")
        XCTAssertTrue(SSE.chooseBody(app, "Earth"), "the Body menu focuses Earth")

        let date = SSE.control(app, "date")
        waitFor(date, timeout: SSE.shortWait, "the date is there")
        let start = SSE.value(app, "date")
        XCTAssertFalse(start.isEmpty, "the date has a value")

        SSE.tap(app, "date-plus-365")
        XCTAssertTrue(SSE.waitForValue(date) { !$0.isEmpty && $0 != start },
                      "+365 days moves the date from \(start) (now \(SSE.value(app, "date")))")
        let stepped = SSE.value(app, "date")

        SSE.tap(app, "play-pause")
        XCTAssertTrue(SSE.waitForValue(SSE.control(app, "play-pause")) { $0.hasPrefix("Playing at") },
                      "Play runs the clock (now \(SSE.value(app, "play-pause")))")
        XCTAssertTrue(SSE.waitForValue(date) { !$0.isEmpty && $0 != stepped },
                      "playing moves the date from \(stepped) (now \(SSE.value(app, "date")))")
        SSE.tap(app, "play-pause")
        XCTAssertTrue(SSE.waitForValue(SSE.control(app, "play-pause")) { $0 == "Paused" },
                      "Pause stops the clock (now \(SSE.value(app, "play-pause")))")
        XCTAssertNotEqual(SSE.value(app, "date"), start, "the date stays moved from the start")
        XCTAssertTrue(SSE.names(SSE.value(app, "status"), "Earth"), "Earth stays in focus")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The Scale picker switches to True relative; the legend and the canvas description say "to one scale".
    @MainActor
    func testScaleSwitchToTrueRelative() {
        let app = SSE.open()

        let legend = SSE.control(app, "legend")
        waitFor(legend, timeout: SSE.shortWait, "the legend is there")
        XCTAssertTrue(SSE.waitForValue(legend) { $0.contains("not to scale") },
                      "a fresh start is the enhanced scale (now \(SSE.value(app, "legend")))")

        XCTAssertTrue(SSE.chooseScale(app, "True relative"), "the Scale picker offers True relative")
        XCTAssertTrue(SSE.waitForValue(legend) { $0.contains("to one scale") },
                      "the legend says to one scale (now \(SSE.value(app, "legend")))")
        XCTAssertTrue(SSE.waitForValue(SSE.control(app, "scale")) { $0.hasPrefix("True relative") },
                      "the picker's value names True relative (now \(SSE.value(app, "scale")))")
        XCTAssertTrue(SSE.waitForLabel(SSE.canvas(app)) { $0.contains("to one scale") },
                      "the canvas description names the scale (now \(SSE.description(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
