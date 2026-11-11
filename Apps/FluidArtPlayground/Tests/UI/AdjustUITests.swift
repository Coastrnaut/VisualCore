// AdjustUITests — feature 021 T-A02-307 (FR-A02-306; US3 AC1–AC3; SC-A02-305): every Adjust control changes the
// value shown and spoken, and Reset returns the defaults.
import XCTest

final class AdjustUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func openAdjust(_ app: XCUIApplication) {
        app.launch()
        app.buttons["fap.home.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["fap.canvas"].waitForExistence(timeout: 10))
        app.buttons["fap.adjust"].tap()
        XCTAssertTrue(app.sliders["fap.adjust.viscosity"].waitForExistence(timeout: 5))
    }

    private func slider(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let s = app.sliders[id]
        for _ in 0..<4 where !s.isHittable { app.swipeUp() }
        return s
    }

    func testControlsChangeAndReset() {
        let app = XCUIApplication()
        openAdjust(app)
        XCTAssertEqual(app.sliders["fap.adjust.quality"].value as? String, "20 iterations")
        XCTAssertEqual(app.sliders["fap.adjust.viscosity"].value as? String, "0.00")

        slider(app, "fap.adjust.viscosity").adjust(toNormalizedSliderPosition: 0.5)
        let viscosity = app.sliders["fap.adjust.viscosity"].value as? String ?? ""
        XCTAssertNotEqual(viscosity, "0.00", "viscosity changed")

        slider(app, "fap.adjust.dyeFade").adjust(toNormalizedSliderPosition: 0.9)
        XCTAssertTrue((app.sliders["fap.adjust.dyeFade"].value as? String ?? "").hasSuffix("per second"))

        // iOS 26's slider ignores a drag to exactly 0, so move near the start and check the count dropped.
        slider(app, "fap.adjust.quality").adjust(toNormalizedSliderPosition: 0.05)
        let quality = app.sliders["fap.adjust.quality"].value as? String ?? ""
        let count = Int(quality.split(separator: " ").first ?? "") ?? 99
        XCTAssertLessThan(count, 20, "fewer iterations, got '\(quality)'")
        XCTAssertTrue(quality.hasSuffix(count == 1 ? "iteration" : "iterations"))

        let edges = app.segmentedControls["fap.adjust.edges"]
        for _ in 0..<4 where !edges.isHittable { app.swipeUp() }
        edges.buttons["Open"].tap()
        XCTAssertTrue(edges.buttons["Open"].isSelected)
        XCTAssertTrue(app.staticTexts["fap.adjust.tier"].label.hasPrefix("Quality: "))

        let reset = app.buttons["fap.adjust.reset"]
        for _ in 0..<4 where !reset.isHittable { app.swipeUp() }
        reset.tap()
        XCTAssertEqual(slider(app, "fap.adjust.quality").value as? String, "20 iterations")
        XCTAssertEqual(slider(app, "fap.adjust.viscosity").value as? String, "0.00")
        XCTAssertTrue(app.segmentedControls["fap.adjust.edges"].buttons["Walls"].isSelected)
        app.buttons["fap.adjust.done"].tap()
        XCTAssertTrue(app.buttons["fap.splash"].waitForExistence(timeout: 5), "back on the canvas, picture kept")
    }
}
