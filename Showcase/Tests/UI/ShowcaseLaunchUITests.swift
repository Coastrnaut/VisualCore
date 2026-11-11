// ShowcaseLaunchUITests — feature 007 T-F601: the app launches (replaced by the smoke test in T-F610).
import XCTest

final class ShowcaseLaunchUITests: XCTestCase {
    @MainActor func testLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["VisualCore"].waitForExistence(timeout: 15))
    }
}
