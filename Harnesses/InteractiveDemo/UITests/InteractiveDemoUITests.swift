// InteractiveDemoUITests — placeholder until T-F520 adds the drag / pinch / background tests.
import XCTest

final class InteractiveDemoUITests: XCTestCase {
    @MainActor func testLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["demo.diagnostics"].waitForExistence(timeout: 10))
    }
}
