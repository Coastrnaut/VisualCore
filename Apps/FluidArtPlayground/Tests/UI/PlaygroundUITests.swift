// PlaygroundUITests — feature 019 T-A02-113 (FR-A02-106; US3 acceptance 1): home → canvas with a spoken description.
import XCTest

final class PlaygroundUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testOpenPlaygroundShowsDescribedCanvas() {
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["fap.home.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCTAssertTrue(open.isHittable)
        open.tap()
        let canvas = app.descendants(matching: .any)["fap.canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertTrue(canvas.label.hasPrefix("Dye pattern"), "spoken description, got '\(canvas.label)'")
        XCTAssertTrue(canvas.label.contains("128 by 128 grid"))
        XCTAssertTrue(app.navigationBars["Playground"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["fap.canvas.failure"].exists)
        // Back to home closes the canvas and its render host.
        app.navigationBars["Playground"].buttons.firstMatch.tap()
        XCTAssertTrue(open.waitForExistence(timeout: 5))
    }

    /// Feature 020 T-A02-213 (US3 AC1, FR-A02-208): the splash control works without a gesture, and swiping keeps
    /// the app responsive.
    func testSplashControlAndSwipe() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["fap.home.open"].tap()
        let canvas = app.descendants(matching: .any)["fap.canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        let splash = app.buttons["fap.splash"]
        XCTAssertTrue(splash.waitForExistence(timeout: 5))
        XCTAssertTrue(splash.isHittable)
        XCTAssertEqual(splash.label, "Add splash")
        XCTAssertGreaterThanOrEqual(splash.frame.height, 44)
        splash.tap()
        XCTAssertTrue(waitFor(canvas, labelContaining: "1 splash added"), "got '\(canvas.label)'")
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.4)))
        XCTAssertTrue(splash.isHittable, "the app stays responsive after a swipe")
        splash.tap()
        XCTAssertTrue(waitFor(canvas, labelContaining: "2 splashes added"), "got '\(canvas.label)'")
    }

    /// Polls the element's label (the canvas updates on the next SwiftUI pass).
    private func waitFor(_ element: XCUIElement, labelContaining text: String, timeout: TimeInterval = 5) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if element.label.contains(text) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.label.contains(text)
    }
}
