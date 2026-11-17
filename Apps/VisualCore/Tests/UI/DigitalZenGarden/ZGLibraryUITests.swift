// ZGLibraryUITests — feature 149 (A20-P05) T-A20-506 (FR-A20-504; SC-A20-502): the library of saved gardens of
// Digital Zen Garden (A20) inside the one app. A fresh start (erased data, so the library is empty) opens A20; the rows
// pattern (`pattern-rows`) is raked, so the canvas description names one stroke; the name field (`library-name`) is
// given "Evening" and Save (`library-save`) saves it ("Saved Evening." in `library-message`); Undo (`undo`) resets
// the garden to 0 strokes; the saved garden's Open button (a `library-open-<n>` labelled "Open Evening") opens it
// ("Opened Evening."), and the description names one stroke again. One journey, short bounded waits, no sleeps, well
// under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class ZGLibraryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// A garden saved as "Evening" and emptied through Undo comes back with its stroke when "Evening" is opened.
    @MainActor
    func testAGardenSavedAsEveningOpensWithItsStroke() {
        let app = ZG.open()
        XCTAssertFalse(ZG.openButton(app, named: "Evening").exists, "a fresh start lists no saved garden")

        XCTAssertTrue(ZG.tap(app, "pattern-rows"), "Rake rows is tapped")
        XCTAssertTrue(ZG.waitForDescription(app) { ZG.strokes($0) == 1 },
                      "the description names one stroke: \(ZG.description(app))")

        XCTAssertTrue(ZG.tap(app, "library-name"), "the name field is tapped")
        ZG.control(app, "library-name").typeText("Evening\n")
        XCTAssertTrue(ZG.tap(app, "library-save"), "Save is tapped")
        let message = ZG.control(app, "library-message")
        XCTAssertTrue(ZG.waitForLabel(message) { $0 == "Saved Evening." }, "the garden is saved: \(message)")
        let open = ZG.openButton(app, named: "Evening")
        XCTAssertTrue(open.waitForExistence(timeout: ZG.shortWait), "the library lists Evening")

        XCTAssertTrue(ZG.tap(app, "undo"), "Undo is tapped")
        XCTAssertTrue(ZG.waitForDescription(app) { ZG.strokes($0) == 0 },
                      "after Undo the description names 0 strokes: \(ZG.description(app))")

        XCTAssertTrue(ZG.tap(app, open, "Open Evening"), "Open Evening is tapped")
        XCTAssertTrue(ZG.waitForLabel(message) { $0 == "Opened Evening." }, "Evening is opened: \(message)")
        XCTAssertTrue(ZG.waitForDescription(app) { ZG.strokes($0) == 1 },
                      "the opened garden names one stroke again: \(ZG.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
