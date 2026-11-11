// GardenSmokeUITests — launch check (T-F801); the gameplay smoke scenario arrives in T-F807.
import XCTest

final class GardenSmokeUITests: XCTestCase {
    @MainActor func testLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["garden.title"].waitForExistence(timeout: 15))
    }
}
