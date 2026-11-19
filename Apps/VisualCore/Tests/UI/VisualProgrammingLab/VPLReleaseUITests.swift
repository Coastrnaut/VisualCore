// VPLReleaseUITests — feature 171 (A23-P06) T-A23-608 (FR-A23-607; clarification "Which interface journey runs?"):
// the first-session defaults of Visual Programming Lab (A23) inside the one app, at the release gate. A fresh start
// (erased data, `VPL.fresh`) opens A23 on the starter graph, Noise 1 → Output 2; `VPL.open` waits until the canvas
// and the status line are there. The status reads "Ready", the list form shows the rows `node-row-1` and `node-row-2`
// and no `node-row-3`, no refusal is shown (no `feedback`), and the library (`library`) is empty (no
// `library-row-graph-1`); the sheet is closed again with `library-done`. One journey, well under 60 s, every wait
// bounded (`VPL.shortWait`, `VC.wait`, `VC.firstWait`). System accessibility audits wait for the device campaign
// (owner ruling of 2026-11-13).
import XCTest

/// The release-gate interface journey of A23: a fresh start is Ready on the starter graph with an empty library.
final class VPLReleaseUITests: XCTestCase {
    /// How long the empty library is watched for a row that should never appear.
    static let emptyLibraryWait: TimeInterval = 2
    /// The file stem the first saved graph would take.
    static let firstFile = "graph-1"

    /// Stops a journey at its first failed check.
    override func setUp() { continueAfterFailure = false }

    /// A fresh start is Ready on the two-node starter graph, without a refusal, and its library is empty.
    @MainActor
    func testAFreshStartIsReadyWithTwoNodesAndAnEmptyLibrary() {
        let app = VPL.open(arguments: VPL.fresh)
        XCTAssertTrue(VPL.waitForStatus(app) { $0 == "Ready" }, "a fresh start is Ready: \(VPL.status(app))")
        XCTAssertTrue(VPL.description(app).hasSuffix("Ready"), "the canvas reads Ready: \(VPL.description(app))")

        let first = VPL.control(app, "node-row-1")
        waitFor(first, timeout: VPL.shortWait, "Noise 1 is listed")
        XCTAssertTrue(VPL.control(app, "node-row-2").waitForExistence(timeout: VPL.shortWait), "Output 2 is listed")
        XCTAssertFalse(VPL.control(app, "node-row-3").exists, "the starter graph has two nodes only")
        XCTAssertFalse(VPL.control(app, "feedback").exists, "a fresh start shows no refusal: \(VPL.feedback(app))")

        XCTAssertTrue(VPL.tap(app, VPL.libraryButton(app), "the Library button"), "the library is opened")
        XCTAssertTrue(VPL.control(app, "library-done").waitForExistence(timeout: VPL.shortWait),
                      "the library sheet is shown")
        let row = VPL.control(app, "library-row-" + Self.firstFile)
        XCTAssertFalse(row.waitForExistence(timeout: Self.emptyLibraryWait),
                       "a fresh library lists no graph: \(row.label)")
        XCTAssertTrue(VPL.tapInSheet(app, "library-done"), "the library is closed")
        XCTAssertTrue(waitUntilGone(VPL.control(app, "library-done"), timeout: VPL.shortWait),
                      "the library sheet is gone")
        XCTAssertTrue(VPL.waitForStatus(app) { $0 == "Ready" }, "still Ready after the library: \(VPL.status(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
