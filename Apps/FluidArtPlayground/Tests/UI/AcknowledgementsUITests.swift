// AcknowledgementsUITests — feature 024 T-A02-606 (FR-A02-604; US2 AC3): the home screen opens the bundled licenses
// (VisualCoreUI AcknowledgementsView): ANGLE (BSD-3-Clause, with its full text) and VisualCore (this repository,
// which includes the app).
import XCTest

final class AcknowledgementsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }

    func testAcknowledgementsShowBundledLicenses() {
        let app = XCUIApplication()
        app.launch()
        let link = element(app, "fap.home.acknowledgements")
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        for _ in 0..<3 where !link.isHittable { app.swipeUp() }
        link.tap()
        let angle = element(app, "fap.acknowledgements.angle")
        XCTAssertTrue(angle.waitForExistence(timeout: 5), "ANGLE row")
        XCTAssertTrue(angle.label.contains("BSD-3-Clause"), angle.label)
        XCTAssertTrue(element(app, "fap.acknowledgements.visualcore").exists)
        angle.tap()
        let text = element(app, "fap.acknowledgements.text")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("ANGLE Project Authors") || text.label.contains("Redistribution"), String(text.label.prefix(120)))
    }
}
