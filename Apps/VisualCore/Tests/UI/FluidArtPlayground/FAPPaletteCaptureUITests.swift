// FAPPaletteCaptureUITests — feature 193 (UA-F07) T-U07-022: port of the standalone app's PaletteCaptureUITests
// (feature 022 T-A02-407; FR-A02-402, FR-A02-404, FR-A02-405; SC-A02-405; US1–US3) into the one app. The palette
// choice becomes selected and the canvas description names it; the brush slider speaks its size as a share of the
// canvas and follows a drag; Capture renders the picture through the session's still renderer and offers it to the
// system share interface ("Share picture"). The palette and brush are A02's controls below the canvas (the
// standalone app showed them in its Adjust sheet). The standalone capture sheet's message "Captured <size>" has no
// counterpart: A02 shows `capture.message` only when a capture fails, so the port checks that no message appears.
import XCTest

final class FAPPaletteCaptureUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testPaletteBrushAndCapture() {
        let app = FAP.open()
        let canvas = FAP.canvas(app)
        XCTAssertTrue(FAP.waitForLabel(canvas) { $0.contains("glowing dye palette") }, canvas.label)

        // Palette and brush (US1, US2).
        let ink = FAP.control(app, "palette.ink")
        FAP.reveal(app, ink)
        XCTAssertTrue(FAP.control(app, "palette.glow").isSelected, "Glowing dye is the default palette")
        ink.tap()
        XCTAssertTrue(FAP.waitForSelection(ink), "Ink is chosen")
        XCTAssertTrue(FAP.waitForLabel(canvas) { $0.contains("ink palette") },
                      "the spoken description names the palette: \(canvas.label)")

        let brush = FAP.slider(app, "brush")
        FAP.reveal(app, brush)
        XCTAssertEqual(brush.label, "Brush size")
        XCTAssertEqual(FAP.value(app, "brush"), FAP.defaultBrush)
        FAP.adjust(app, "brush", to: 0.5)
        XCTAssertTrue(FAP.waitForValue(app, "brush") { $0 != FAP.defaultBrush }, FAP.value(app, "brush"))
        XCTAssertTrue(FAP.value(app, "brush").hasSuffix("% of the canvas"), FAP.value(app, "brush"))

        // Capture (US3): the share control appears once the picture is made.
        let capture = FAP.control(app, "capture")
        FAP.reveal(app, capture)
        XCTAssertEqual(capture.label, "Capture")
        capture.tap()
        let share = FAP.control(app, "capture.share")
        waitFor(share, timeout: 30, "share control after capture")
        XCTAssertEqual(share.label, "Share picture")
        XCTAssertFalse(FAP.control(app, "capture.message").exists, "no capture error")
        FAP.reveal(app, share)
        XCTAssertTrue(share.isHittable)
        FAP.attachScreenshot(app, named: "a02-capture", to: self)
        share.tap()
        // The system share sheet presents.
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10)
                      || app.buttons["Copy"].waitForExistence(timeout: 2), "system share sheet")
    }
}
