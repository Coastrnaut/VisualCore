// LaunchSmokeUITests — feature 032 T-A04-005 (FR-A04-005, SC-A04-003): the shell launches to a titled, labelled home.
import XCTest

final class LaunchSmokeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testLaunchShowsTitle() {
        let app = XCUIApplication()
        app.launch()
        let title = app.staticTexts["pu.home.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "Particle Universe")
    }
}
