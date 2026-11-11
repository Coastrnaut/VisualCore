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

    // Feature 027 T-A03-208 (FR-A03-202, FR-A03-203, FR-A03-206; SC-A03-204): zoom controls, palette, animation and
    // the precision banner reached through the zoom controls.
    func testZoomControlsPaletteAnimateAndPrecisionBanner() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["fe.home.open"].tap()
        let canvas = app.descendants(matching: .any)["fe.canvas"]
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        let zoomIn = app.buttons["fe.zoomIn"], zoomOut = app.buttons["fe.zoomOut"], reset = app.buttons["fe.resetView"]
        zoomIn.tap()
        XCTAssertTrue(canvas.label.hasSuffix("zoom 2×"), canvas.label)
        zoomOut.tap(); zoomOut.tap()
        XCTAssertTrue(canvas.label.hasSuffix("zoom 0.5×") || canvas.label.contains("zoom 0.5"), canvas.label)
        reset.tap()
        XCTAssertTrue(canvas.label.hasSuffix("zoom 1×"), canvas.label)

        let palette = app.buttons["fe.palette"]
        XCTAssertTrue(palette.waitForExistence(timeout: 5))
        XCTAssertTrue(palette.label.contains("Sunset") || (palette.value as? String ?? "").contains("Sunset"), palette.label)
        palette.tap()
        let ocean = app.buttons["Ocean"].firstMatch
        XCTAssertTrue(ocean.waitForExistence(timeout: 5))
        ocean.tap()
        XCTAssertTrue(palette.label.contains("Ocean") || (palette.value as? String ?? "").contains("Ocean"), palette.label)

        let animate = app.switches["fe.animate"]
        XCTAssertTrue(animate.exists)
        let before = animate.value as? String
        animate.switches.firstMatch.exists ? animate.switches.firstMatch.tap() : animate.tap()
        XCTAssertNotEqual(animate.value as? String, before)

        let banner = app.descendants(matching: .any)["fe.precision"]
        var sawNear = false
        for _ in 0..<40 {
            zoomIn.tap()
            if banner.exists, banner.label.contains("Near precision limit") { sawNear = true }
            if banner.exists, banner.label.contains("Precision limit reached") { break }
        }
        XCTAssertTrue(sawNear, "the near-limit notice comes first")
        XCTAssertTrue(banner.label.contains("Precision limit reached — zoom stops here"), banner.label)
        XCTAssertTrue(canvas.label.hasSuffix("Precision limit reached — zoom stops here"), canvas.label)
        let atLimit = canvas.label
        zoomIn.tap()
        XCTAssertEqual(canvas.label, atLimit, "zoom stops at the limit")
        reset.tap()
        XCTAssertFalse(banner.exists)
    }
}
