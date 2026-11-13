// FECaptureTourUITests — feature 193 (UA-F07) T-U07-025: port of the standalone app's CaptureTourUITests (feature
// 029 T-A03-410; FR-A03-404 to FR-A03-406; US1–US3; SC-A03-405) into the one app. The iteration buttons double and
// halve the cap, and the cap and the render-cost line follow; Capture renders the view through the session's still
// renderer and offers it to the system share interface ("Share picture"); a tour shows its caption once its first
// stop is reached, and Stop ends it and keeps the caption. The cap, capture and tours are A03's native controls below
// the canvas (the standalone app had a cap slider and a tours sheet).
//
// Differences from the standalone test, recorded in the test map: the cap is a number with Halve and Double buttons
// (no slider), spoken as "<n> iterations"; the standalone capture message "Captured at <size>" has no counterpart
// (A03 shows `capture.message` only when the picture is limited or fails), so the port checks that no failure
// message appears; and a tour advances by the core's fixed steps (FractalCore difference 3), so the caption's wait is
// longer than the standalone 10 s.
import XCTest

final class FECaptureTourUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testCapAndCostThenCapture() {
        let app = FE.open()
        let cost = FE.control(app, "cost"), cap = FE.control(app, "cap")
        FE.reveal(app, cost)
        XCTAssertTrue(FE.waitForLabel(cost) { $0 == FE.defaultCost }, cost.label)
        XCTAssertEqual(cap.label, "200 iterations")
        FE.tap(app, "cap.up")
        XCTAssertTrue(FE.waitForLabel(cap) { $0 == "400 iterations" }, cap.label)
        XCTAssertTrue(FE.waitForLabel(cost) { $0 == "Render cost: 2× the default view (light)" }, cost.label)
        FE.expectCanvas(app, "the description names a cap other than 200") { $0.hasSuffix(", 400 iterations") }
        FE.tap(app, "cap.down")
        XCTAssertTrue(FE.waitForLabel(cap) { $0 == "200 iterations" }, cap.label)
        XCTAssertTrue(FE.waitForLabel(cost) { $0 == FE.defaultCost }, cost.label)

        let capture = FE.control(app, "capture")
        FE.reveal(app, capture)
        XCTAssertEqual(capture.label, "Capture")
        capture.tap()
        let share = FE.control(app, "capture.share")
        waitFor(share, timeout: 30, "the share control after the capture")
        XCTAssertEqual(share.label, "Share picture")
        let message = FE.control(app, "capture.message")
        XCTAssertFalse(message.exists && !message.label.hasPrefix("The picture is smaller here"),
                       "no capture failure: \(message.exists ? message.label : "")")
        FE.reveal(app, share)
        XCTAssertTrue(share.isHittable)
        FE.attachScreenshot(app, named: "a03-capture", to: self)
        share.tap()
        // The system share sheet presents.
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10)
                      || app.buttons["Copy"].waitForExistence(timeout: 2), "system share sheet")
    }

    @MainActor
    func testTourShowsCaptionsAndStops() {
        let app = FE.open()
        let seahorse = FE.control(app, "tour.seahorse")
        FE.reveal(app, seahorse)
        XCTAssertEqual(seahorse.label, "Seahorse Valley")
        seahorse.tap()
        let stop = FE.control(app, "tour.stop")
        waitFor(stop, timeout: VC.wait, "Stop tour while the tour plays")
        XCTAssertTrue(FE.waitForSelection(seahorse), "the playing tour is marked")
        let caption = FE.control(app, "tour.caption")
        XCTAssertTrue(caption.waitForExistence(timeout: 30), "the first stop is reached after its 4 s flight")
        XCTAssertTrue(caption.label.contains("Seahorse Valley"), caption.label)
        FE.expectCanvas(app, "the tour moved the view") { !$0.contains("centered at −0.5 + 0i") }
        FE.reveal(app, stop)
        stop.tap()
        XCTAssertTrue(waitUntilGone(stop), "Stop ends the tour")
        XCTAssertTrue(caption.exists, "Stop keeps the caption")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
