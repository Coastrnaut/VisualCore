// SSRecoveryUITests — feature 163 (A22-P05) T-A22-508 (FR-A22-504, FR-A22-506; contracts/recovery.md "Relaunch
// (`d3`)"): a Shader Studio (A22) project survives a relaunch of the one app. A fresh start (erased data, so the library
// is empty) opens A22 on Gradient; its source is saved as "Waves" (`library` → `save` → `project-name` →
// `save-confirm`). The app is ended and started again without `-vcResetData` (`SS.reopen`, which waits for the studio
// and the status "Compiled" as `SS.open` does); the library lists "Waves" first (`project-0`), and opening it
// (`project-0` → `open`) shows the saved source in the editor. Short bounded waits; the journey stays well under 60 s.
// System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class SSRecoveryUITests: XCTestCase {
    /// The name the project is saved under.
    static let projectName = "Waves"

    override func setUp() { continueAfterFailure = false }

    /// A project saved as "Waves" is listed and opens with its source after the app was ended and started again.
    @MainActor
    func testSavedProjectSurvivesRelaunch() {
        let app = SS.open()
        let saved = SS.source(app)
        XCTAssertTrue(saved.contains("uniform float u_speed;"), "the editor shows the Gradient source: \(saved)")

        XCTAssertTrue(SS.tapAnywhere(app, "library"), "the library is opened")
        XCTAssertTrue(SS.tapAnywhere(app, "save"), "Save is tapped")
        let name = SS.control(app, "project-name")
        XCTAssertTrue(name.waitForExistence(timeout: SS.shortWait), "the name field is there")
        name.tap()
        name.typeText(Self.projectName)
        XCTAssertTrue(SS.tapAnywhere(app, "save-confirm"), "the save is confirmed")
        XCTAssertTrue(SS.waitForLabel(SS.project(app, 0)) { $0.contains(Self.projectName) },
                      "the library lists \(Self.projectName) first: \(SS.project(app, 0).label)")

        let second = SS.reopen(app)
        XCTAssertTrue(SS.tapAnywhere(second, "library"), "the library is opened after the relaunch")
        XCTAssertTrue(SS.waitForLabel(SS.project(second, 0)) { $0.contains(Self.projectName) },
                      "the library still lists \(Self.projectName) after the relaunch: \(SS.project(second, 0).label)")
        XCTAssertTrue(SS.tapAnywhere(second, "project-0"), "\(Self.projectName) is selected")
        XCTAssertTrue(SS.tapAnywhere(second, "open"), "\(Self.projectName) is opened")

        SS.backToEditor(second)
        XCTAssertTrue(SS.waitForValue(SS.editor(second)) { $0 == saved },
                      "the editor shows the saved source after the relaunch: \(SS.source(second))")
        XCTAssertFalse(element(second, "session.failure").exists, "no failure")
    }
}
