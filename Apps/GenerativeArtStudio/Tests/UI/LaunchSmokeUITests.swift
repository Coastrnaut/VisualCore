// LaunchSmokeUITests — feature 011 T-A01-007 (FR-A01-005, SC-A01-003): the shell launches to a titled, labelled home.
import XCTest

final class LaunchSmokeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLaunchShowsTitle() {
        let app = XCUIApplication()
        app.launch()
        let title = app.staticTexts["gas.home.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Generative Art Studio")
    }
}
