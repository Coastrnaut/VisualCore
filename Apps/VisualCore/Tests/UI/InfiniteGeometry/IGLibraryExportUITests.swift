// IGLibraryExportUITests — feature 045 (A05-P06) T-A05-610 (US4 scenarios 3 and 4; FR-A05-630, FR-A05-632): a
// composition saved under a name is listed, another preset is chosen, and opening the saved composition gives back
// the description recorded at save time; "Export picture" offers the share control (the share sheet is not opened).
// System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class IGLibraryExportUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Save, choose another preset, open the saved composition: the description is the saved one (US4 scenario 3).
    @MainActor
    func testSaveChooseAnotherPresetAndOpen() {
        let app = IG.open()
        IG.choosePreset(app, IG.kaleidoscopePreset, kind: "Kaleidoscope")
        let saved = IG.description(app)

        IG.type(app, "library.name", "Rosette")
        IG.tap(app, "library.save")
        XCTAssertEqual(IG.text(app, "library.entry.0"), "Rosette", "the saved composition is listed")

        IG.choosePreset(app, IG.solidPreset, kind: "3D composition")
        XCTAssertNotEqual(IG.description(app), saved, "the composition changed")

        IG.tap(app, "library.open.0")
        XCTAssertTrue(IG.waitForDescription(app) { $0 == saved },
                      "opening restores the saved composition: \(IG.description(app)) vs \(saved)")
        XCTAssertFalse(IG.control(app, "library.message").exists, "no error after opening")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// "Export picture" makes the picture and shows "Share picture" (US4 scenario 4).
    @MainActor
    func testExportShowsTheShareControl() {
        let app = IG.open()
        IG.tap(app, "export")
        let share = IG.control(app, "export.share")
        XCTAssertTrue(share.waitForExistence(timeout: VC.wait),
                      "the share control appears; message: \(IG.control(app, "export.message").exists ? IG.text(app, "export.message") : "none")")
        XCTAssertEqual(share.label, "Share picture")
        XCTAssertFalse(IG.control(app, "export.message").exists, "no export message")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
