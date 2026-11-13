// GASExportUITests — feature 193 (UA-F07) T-U07-015: port of the standalone app's ExportUITests (feature 015
// T-A01-407; FR-A01-401, FR-A01-403, FR-A01-407, FR-A01-409) into the one app. Inside the one app export is one
// control of A01, "Make image", which draws the current picture off screen at 2048 by 2048 pixels and then offers
// it to the system share interface ("Share image"); no error is shown and the experience stays interactive. The
// standalone export sheet's size and aspect pickers, its dimension text and its crop preview have no counterpart:
// the adapter exports one square size (GenerativeArtControls.exportEdge), so those steps are not ported.
import XCTest

final class GASExportUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testExportSheetFlow() {
        let app = GAS.open()
        GAS.tap(app, "family.gradient-noise")
        GAS.expectFamily(app, "Gradient Noise")

        let make = GAS.control(app, "export.make")
        GAS.reveal(app, make)
        XCTAssertEqual(make.label, "Make image")
        make.tap()
        let share = GAS.control(app, "export.share")
        waitFor(share, timeout: 30, "the share control after the image was made")
        XCTAssertEqual(share.label, "Share image")
        XCTAssertFalse(GAS.control(app, "export.error").exists, "no export error")

        // The experience stays interactive after the export: the canvas runs and the time control answers.
        XCTAssertTrue(GAS.canvas(app).exists)
        XCTAssertFalse(element(app, "session.failure").exists)
        let play = GAS.control(app, "time.playPause")
        GAS.reveal(app, play)
        XCTAssertEqual(play.label, "Pause")
        play.tap()
        XCTAssertTrue(GAS.waitForLabel(play) { $0 == "Play" }, "the controls still answer: \(play.label)")
        GAS.attachScreenshot(app, named: "a01-export", to: self)
    }
}
