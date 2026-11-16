// SLLibraryUITests — feature 122 (A16-P06) T-A16-608 (clarification Q4; FR-A16-630, FR-A16-622): saving an experiment
// of Simulation Lab (A16) inside the one app and finding it again after the experience is opened anew. A fresh start
// erases the data (`-vcResetData` removes the experience's storage), so the library lists no saved experiment and no
// "My spots"; the test still counts the "My spots" buttons before saving, so a left-over one would not hide a failed
// save. Typing "My spots" in the experiment name (`preset-name`) and tapping Save experiment (`preset-save`) adds one
// saved-experiment button (`saved-<uuid>`) titled "My spots"; after the app is ended and A16 opened again without the
// reset (`SL.reopen`, as the persistence tests relaunch), it is still listed, read from its `preset-<uuid>.json`. One
// journey, well under 60 s. Capture is never tapped, so the share sheet is never presented. System accessibility
// audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class SLLibraryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The name of the saved experiment.
    static let name = "My spots"

    /// "My spots" saved: its button appears and is still listed after the experience is opened again.
    @MainActor
    func testSavedExperimentSurvivesReopen() {
        let app = SL.open()

        let field = SL.control(app, "preset-name")
        waitFor(field, timeout: SL.shortWait, "the experiment name is there")
        XCTAssertEqual(field.label, "Experiment name", "the text field is labelled Experiment name")
        let before = SL.saved(app, named: Self.name).count
        XCTAssertEqual(before, 0, "a fresh start lists no \(Self.name)")

        XCTAssertTrue(SL.tap(app, element: field, "the experiment name"), "the experiment name takes the focus")
        // The return key ends the editing and dismisses the keyboard, so it covers no control.
        field.typeText(Self.name + "\n")
        XCTAssertTrue(SL.tap(app, "preset-save"), "Save experiment is tapped")

        let saved = SL.saved(app, named: Self.name)
        let appeared = saved.element(boundBy: before)
        XCTAssertTrue(appeared.waitForExistence(timeout: SL.shortWait),
                      "a \(Self.name) button appears (preset message: \(SL.value(app, "preset-message")))")
        XCTAssertEqual(saved.count, before + 1, "one \(Self.name) more")
        XCTAssertFalse(SL.control(app, "preset-message").exists,
                       "the experiment was saved (now \(SL.value(app, "preset-message")))")

        let second = SL.reopen(app)
        let again = SL.saved(second, named: Self.name)
        XCTAssertTrue(again.firstMatch.waitForExistence(timeout: SL.shortWait),
                      "\(Self.name) is still listed after opening again")
        XCTAssertEqual(again.count, before + 1, "the same number of \(Self.name) after opening again")
        XCTAssertFalse(element(second, "session.failure").exists, "no failure")
    }
}
