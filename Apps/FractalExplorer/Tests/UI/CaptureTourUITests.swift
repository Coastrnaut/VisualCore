// CaptureTourUITests — feature 029 T-A03-410 (FR-A03-404–406; US1–US3; SC-A03-405): the cap control and cost line,
// capture with the share button, and a tour with its caption and Stop.
import XCTest

final class CaptureTourUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestTemporaryBookmarks"]
        app.launch()
        app.buttons["fe.home.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["fe.canvas"].waitForExistence(timeout: 10))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !(element.exists && element.isHittable) { app.swipeUp() }
    }

    func testCapAndCostThenCapture() {
        let app = launch()
        let cost = app.staticTexts["fe.cost"]
        reveal(cost, in: app)
        XCTAssertEqual(cost.label, "Render cost: 1× the default view (light)")
        app.buttons["fe.cap.up"].tap()
        XCTAssertEqual(cost.label, "Render cost: 2× the default view (light)")
        XCTAssertEqual(app.sliders["fe.cap"].value as? String, "400 iterations")
        app.buttons["fe.cap.down"].tap()
        XCTAssertEqual(cost.label, "Render cost: 1× the default view (light)")

        let capture = app.buttons["fe.capture"]
        reveal(capture, in: app)
        capture.tap()
        XCTAssertTrue(app.descendants(matching: .any)["fe.capture.share"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["fe.capture.message"].label.hasPrefix("Captured at "), app.staticTexts["fe.capture.message"].label)
    }

    func testTourShowsCaptionsAndStops() {
        let app = launch()
        app.buttons["fe.tours"].tap()
        let seahorse = app.descendants(matching: .any)["fe.tour.seahorse"]
        XCTAssertTrue(seahorse.waitForExistence(timeout: 5))
        seahorse.tap()
        let stop = app.buttons["fe.tour.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        let caption = app.descendants(matching: .any)["fe.tour.caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10), "the first stop is reached after its 4 s flight")
        XCTAssertTrue(caption.label.contains("Seahorse Valley"), caption.label)
        reveal(stop, in: app)
        stop.tap()
        XCTAssertTrue(stop.waitForNonExistence(timeout: 5))
        XCTAssertTrue(caption.exists, "Stop keeps the caption")
    }
}
