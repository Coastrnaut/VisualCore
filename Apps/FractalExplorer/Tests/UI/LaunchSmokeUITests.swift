// LaunchSmokeUITests — feature 025 T-A03-005 (FR-A03-005, SC-A03-003): the shell launches to a titled, labelled home.
import XCTest

final class LaunchSmokeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLaunchShowsTitle() {
        let app = XCUIApplication()
        app.launch()
        let title = app.staticTexts["fe.home.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Fractal Explorer")
    }
}
