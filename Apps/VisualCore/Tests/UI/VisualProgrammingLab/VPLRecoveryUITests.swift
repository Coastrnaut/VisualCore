// VPLRecoveryUITests — feature 170 (A23-P05) T-A23-505 (FR-A23-504, SC-A23-504; clarification Q4; User Story 4;
// contracts/tests.md "Interface", chunk `e3`): a Visual Programming Lab (A23) graph saved in the library survives a
// relaunch of the one app. A fresh start (erased data, so the library is empty) opens A23 on the starter graph; it is
// saved as "Clouds" (`library` → `library-name` → `library-save`), the first file `graph-1`. The app is ended and
// started again without `-vcResetData` (`VPL.reopen`); the library lists the row `library-row-graph-1` labelled with
// "Clouds", and opening it (`library-open-graph-1`; a replace confirmation, when one is asked, is confirmed) closes the
// sheet and the status reads "Ready". Short bounded waits; the journey stays well under 60 s. System accessibility
// audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class VPLRecoveryUITests: XCTestCase {
    /// The name the graph is saved under.
    static let graphName = "Clouds"
    /// The file stem of the first saved graph.
    static let file = "graph-1"

    override func setUp() { continueAfterFailure = false }

    /// A graph saved as "Clouds" is listed and opens, Ready, after the app was ended and started again.
    @MainActor
    func testASavedGraphSurvivesARelaunch() {
        let app = VPL.open()
        XCTAssertTrue(VPL.tap(app, VPL.libraryButton(app), "the Library button"), "the library is opened")
        let name = VPL.control(app, "library-name")
        XCTAssertTrue(name.waitForExistence(timeout: VPL.shortWait), "the name field is there")
        XCTAssertTrue(VPL.waitForHittable(name), "the name field can be tapped")
        name.tap()
        name.typeText(Self.graphName)
        XCTAssertTrue(VPL.tapInSheet(app, "library-save"), "the graph is saved")
        let row = VPL.control(app, "library-row-" + Self.file)
        XCTAssertTrue(VPL.waitForLabel(row) { $0.contains(Self.graphName) },
                      "the library lists \(Self.graphName) as \(Self.file): \(row.label)")

        let second = VPL.reopen(app)
        XCTAssertTrue(VPL.tap(second, VPL.libraryButton(second), "the Library button"),
                      "the library is opened after the relaunch")
        let kept = VPL.control(second, "library-row-" + Self.file)
        XCTAssertTrue(VPL.waitForLabel(kept) { $0.contains(Self.graphName) },
                      "the library still lists \(Self.graphName) after the relaunch: \(kept.label)")
        XCTAssertTrue(VPL.tapInSheet(second, "library-open-" + Self.file), "\(Self.graphName) is opened")
        let confirm = VPL.control(second, "library-replace-confirm")
        if confirm.waitForExistence(timeout: 1) { confirm.tap() }

        XCTAssertTrue(waitUntilGone(VPL.control(second, "library-name"), timeout: VPL.shortWait),
                      "the library sheet closes once the graph is opened")
        XCTAssertTrue(VPL.waitForStatus(second) { $0 == "Ready" }, "the opened graph is Ready: \(VPL.status(second))")
        XCTAssertTrue(VPL.description(second).hasSuffix("Ready"), "the canvas reads Ready: \(VPL.description(second))")
        XCTAssertFalse(element(second, "session.failure").exists, "no failure")
    }
}
