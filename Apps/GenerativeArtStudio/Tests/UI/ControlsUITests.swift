// ControlsUITests — feature 013 T-A01-208 (US1, US2; FR-A01-201, FR-A01-203, FR-A01-204, FR-A01-207).
import XCTest

final class ControlsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func openControls(_ app: XCUIApplication, family: String) {
        app.launch()
        let row = app.buttons["gas.family.\(family)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let open = app.buttons["gas.controls.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.buttons["gas.time.playPause"].waitForExistence(timeout: 5))
    }

    func testTimeControls() {
        let app = XCUIApplication()
        openControls(app, family: "gradient-noise")
        let play = app.buttons["gas.time.playPause"]
        XCTAssertEqual(play.label, "Pause")
        play.tap()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 3), "label switches to Play when paused")
        let scrub = app.sliders["gas.time.scrub"]
        XCTAssertEqual(scrub.label, "Time")
        scrub.adjust(toNormalizedSliderPosition: 0.5)
        let value = app.staticTexts["gas.time.value"]
        let deadline = Date().addingTimeInterval(5)
        while !(value.label.hasPrefix("5") || value.label.hasPrefix("6")), Date() < deadline { usleep(200_000) }
        XCTAssertTrue(value.label.hasPrefix("5") || value.label.hasPrefix("6"), "scrubbed to about 60 s: \(value.label)")
        let paused = value.label
        sleep(1)
        XCTAssertEqual(value.label, paused, "time stays put while paused")
    }

    func testPresetPaletteSeedAndParameters() {
        let app = XCUIApplication()
        openControls(app, family: "gradient-noise")
        app.swipeUp()
        let tide = app.buttons["gas.preset.noise-tide"]
        XCTAssertTrue(tide.waitForExistence(timeout: 5))
        tide.tap()
        XCTAssertEqual(app.staticTexts["gas.seed.value"].label, "Seed 2024")
        let neon = app.buttons["gas.palette.neon"]
        if !neon.isHittable { app.swipeUp() }
        neon.tap()
        XCTAssertTrue(neon.isSelected)
        let shuffle = app.buttons["gas.seed.shuffle"]
        if !shuffle.isHittable { app.swipeUp() }
        shuffle.tap()
        XCTAssertNotEqual(app.staticTexts["gas.seed.value"].label, "Seed 2024")
        let warp = app.sliders["vc.param.warp"]
        for _ in 0..<4 where !warp.isHittable { app.swipeUp() }
        XCTAssertEqual(warp.label, "Warp")
        let before = warp.value as? String
        warp.adjust(toNormalizedSliderPosition: 0.95)
        XCTAssertNotEqual(warp.value as? String, before, "value text follows the slider")
        let reset = app.buttons["vc.param.warp.reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 3))
        XCTAssertEqual(reset.label, "Reset Warp")
        reset.tap()
        XCTAssertEqual(warp.value as? String, before)
        XCTAssertFalse(reset.exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "controls-sheet"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
