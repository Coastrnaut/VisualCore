// PaletteCaptureUITests — feature 022 T-A02-407 (FR-A02-402, FR-A02-404, FR-A02-405; SC-A02-405; US1–US3).
import XCTest

final class PaletteCaptureUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func waitFor(_ element: XCUIElement, labelContaining text: String, timeout: TimeInterval = 5) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if element.label.contains(text) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.label.contains(text)
    }

    func testPaletteBrushAndCapture() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["fap.home.open"].tap()
        let canvas = app.descendants(matching: .any)["fap.canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertTrue(canvas.label.contains("glowing dye palette"))

        // Palette and brush (US1, US2) in the Adjust panel.
        app.buttons["fap.adjust"].tap()
        let palette = app.segmentedControls["fap.adjust.palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 5))
        palette.buttons["Ink"].tap()
        XCTAssertTrue(palette.buttons["Ink"].isSelected)
        let brush = app.sliders["fap.adjust.brush"]
        XCTAssertEqual(brush.value as? String, "4% of the canvas")
        brush.adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertNotEqual(brush.value as? String, "4% of the canvas")
        XCTAssertTrue((brush.value as? String ?? "").hasSuffix("% of the canvas"))
        app.buttons["fap.adjust.done"].tap()
        XCTAssertTrue(waitFor(canvas, labelContaining: "ink palette"), "the spoken description names the palette")

        // Capture (US3): the share control appears with the picture size.
        app.buttons["fap.capture"].tap()
        let share = app.buttons["fap.capture.share"]
        XCTAssertTrue(share.waitForExistence(timeout: 30), "share control after capture")
        XCTAssertTrue(share.isHittable)
        XCTAssertTrue(app.staticTexts["fap.capture.message"].label.hasPrefix("Captured "))
        share.tap()
        // The system share sheet presents; dismissing it returns to the capture sheet.
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10)
                      || app.buttons["Copy"].waitForExistence(timeout: 2), "system share sheet")
    }
}
