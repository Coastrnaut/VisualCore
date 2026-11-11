// LaunchSmokeUITests — feature 018 T-A02-005 (FR-A02-005, SC-A02-003): the shell launches to a titled, labelled home.
import XCTest

final class LaunchSmokeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLaunchShowsTitle() {
        let app = XCUIApplication()
        app.launch()
        let title = app.staticTexts["fap.home.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Fluid Art Playground")
    }
}
