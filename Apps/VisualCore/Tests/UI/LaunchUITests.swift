// LaunchUITests — feature 190 T-U04-001: the app launches to its first route.
import XCTest

final class LaunchUITests: XCTestCase {
    @MainActor
    func testTheAppLaunchesToTheCatalogRoute() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["vc.route.catalog"].waitForExistence(timeout: 20))
    }
}
