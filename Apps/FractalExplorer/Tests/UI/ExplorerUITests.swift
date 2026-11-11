// ExplorerUITests — feature 026 T-A03-105 (FR-A03-101; US1 AC1–AC3; SC-A03-103): the explorer opens in Mandelbrot
// mode, the mode control switches to Julia, and the explanation and the canvas's spoken description follow.
import XCTest

final class ExplorerUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testModesExplanationsAndSpokenCanvas() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["fe.home.open"].tap()
        let mode = app.segmentedControls["fe.mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 10))
        XCTAssertTrue(mode.buttons["Mandelbrot"].isSelected)
        let explanation = app.staticTexts["fe.mode.explanation"]
        XCTAssertTrue(explanation.label.contains("Mandelbrot set"), explanation.label)
        let canvas = app.descendants(matching: .any)["fe.canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertEqual(canvas.label, "Mandelbrot set, centered at −0.5 + 0i, zoom 1×")
        XCTAssertFalse(app.staticTexts["fe.seed"].exists)

        mode.buttons["Julia"].tap()
        XCTAssertTrue(mode.buttons["Julia"].isSelected)
        XCTAssertTrue(app.staticTexts["fe.mode.explanation"].label.contains("seed"))
        XCTAssertEqual(canvas.label, "Julia set for seed −0.8 + 0.156i, centered at 0 + 0i, zoom 1×")
        XCTAssertEqual(app.staticTexts["fe.seed"].label, "Seed: −0.8 + 0.156i")

        mode.buttons["Mandelbrot"].tap()
        XCTAssertTrue(canvas.label.hasPrefix("Mandelbrot set"))
    }
}
