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
}
