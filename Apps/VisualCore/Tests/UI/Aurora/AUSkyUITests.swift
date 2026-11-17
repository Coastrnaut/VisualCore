// AUSkyUITests — feature 156 (A21-P05) T-A21-506 (FR-A21-506; SC-A21-503): the sky of Aurora (A21) inside the one
// app. A fresh start (erased data) opens A21 on Polar night. The first journey picks Violet veil on the segmented
// `preset` picker: the canvas description (`AuroraPresenter.describe`) names it. The second turns on Still sky
// (`still`) and Reduced flashing (`reduced-flash`): both read On. The third hides the controls (`hide-controls`): only
// the line `show-controls` remains; a tap on the sky brings the controls back. Short bounded waits, no sleeps; each
// journey well under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class AUSkyUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Picking Violet veil names it on the canvas.
    @MainActor
    func testPickingVioletVeilNamesItOnTheCanvas() {
        let app = AU.open()
        XCTAssertTrue(AU.description(app).contains(AU.presets[0]),
                      "a fresh sky is Polar night: \(AU.description(app))")

        XCTAssertTrue(AU.choosePreset(app, AU.presets[1]), "Violet veil is picked")
        XCTAssertTrue(AU.waitForDescription(app) { $0.contains(AU.presets[1]) },
                      "the canvas names Violet veil: \(AU.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Still sky and Reduced flashing turned on both read on.
    @MainActor
    func testStillSkyAndReducedFlashingTurnOn() {
        let app = AU.open()
        waitFor(AU.control(app, "still"), timeout: AU.shortWait, "the Still sky toggle is there")
        XCTAssertTrue(AU.isOff(AU.value(app, "still")), "a fresh start has Still sky off (\(AU.value(app, "still")))")
        XCTAssertTrue(AU.isOff(AU.value(app, "reduced-flash")),
                      "a fresh start has Reduced flashing off (\(AU.value(app, "reduced-flash")))")

        XCTAssertTrue(AU.turnOn(app, "still"), "Still sky is turned on")
        XCTAssertTrue(AU.turnOn(app, "reduced-flash"), "Reduced flashing is turned on")
        XCTAssertTrue(AU.isOn(AU.value(app, "still")), "Still sky stays on (\(AU.value(app, "still")))")
        XCTAssertTrue(AU.isOn(AU.value(app, "reduced-flash")),
                      "Reduced flashing reads on (\(AU.value(app, "reduced-flash")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Hidden controls come back with a tap on the sky.
    @MainActor
    func testHiddenControlsComeBackWithATapOnTheSky() {
        let app = AU.open()
        XCTAssertTrue(AU.tap(app, "hide-controls"), "Hide controls is tapped")
        XCTAssertTrue(AU.control(app, "show-controls").waitForExistence(timeout: AU.shortWait),
                      "the hidden line is there")
        XCTAssertTrue(waitUntilGone(AU.control(app, "preset"), timeout: AU.shortWait), "the preset picker is hidden")

        AU.canvas(app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(AU.control(app, "hide-controls").waitForExistence(timeout: AU.shortWait),
                      "the controls are back after a tap on the sky")
        XCTAssertTrue(AU.control(app, "preset").exists, "the preset picker is back")
        XCTAssertTrue(waitUntilGone(AU.control(app, "show-controls"), timeout: AU.shortWait),
                      "the hidden line is gone")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
