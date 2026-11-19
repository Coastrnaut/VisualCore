// GBLReleaseUITests — feature 178 (A24-P06) T-A24-608 (FR-A24-607; clarification "Which interface journey runs?";
// contracts/release.md "Interface", chunk `f3`): the first-session defaults of Graphics Benchmark Lab (A24) inside the
// one app, at the release gate. A fresh start (erased data, `GBL.fresh`) opens A24; `GBL.open` waits until the canvas,
// the Start run button and the status line are there and the status reads "Ready". The status reads "Ready", the
// quads case (`case-quads`) is the selected case (the selected trait, spoken value "Selected"), no run has a
// `qualification`, and the saved results (`results`) show "No saved results." without a `result-row-1`; the list is
// closed again with `results-done`. One journey, timed from after the launch, well under 60 s; every wait is bounded
// (`GBL.shortWait`, `VC.wait`, `VC.firstWait`, ``emptyResultsWait``). System accessibility audits wait for the device
// campaign (owner ruling of 2026-11-13).
import XCTest

/// The release-gate interface journey of A24: a fresh start is Ready on the quads case with no saved results.
final class GBLReleaseUITests: XCTestCase {
    /// The longest the journey may take after the launch (SC-A24-504).
    static let journeyLimit: TimeInterval = 60
    /// How long the empty results are watched for a row that should never appear.
    static let emptyResultsWait: TimeInterval = 2
    /// The text the results show when nothing is saved (`ResultsView`).
    static let emptyText = "No saved results."

    /// Stops a journey at its first failed check.
    override func setUp() { continueAfterFailure = false }

    /// A fresh start is Ready with the quads case selected, no qualification, and no saved results.
    @MainActor
    func testAFreshStartIsReadyOnQuadsWithNoResults() {
        let app = GBL.open(arguments: GBL.fresh)
        let started = Date()
        XCTAssertTrue(GBL.waitForStatus(app) { $0 == "Ready" }, "a fresh start is Ready: \(GBL.status(app))")

        let quads = GBL.control(app, "case-quads")
        waitFor(quads, timeout: GBL.shortWait, "the quads case is there")
        XCTAssertTrue(isSelectedCase(quads), "quads is the selected case: \(GBL.spoken(quads))")
        XCTAssertFalse(GBL.control(app, "qualification").exists, "a fresh start shows no qualification")

        XCTAssertTrue(GBL.tap(app, GBL.control(app, "results"), "the Saved results button"), "the results are shown")
        let empty = app.staticTexts[Self.emptyText]
        XCTAssertTrue(empty.waitForExistence(timeout: GBL.shortWait), "the results read \"\(Self.emptyText)\"")
        let row = GBL.control(app, "result-row-1")
        XCTAssertFalse(row.waitForExistence(timeout: Self.emptyResultsWait),
                       "a fresh start lists no result: \(row.label)")

        let done = GBL.control(app, "results-done")
        if done.waitForExistence(timeout: GBL.shortWait) {
            XCTAssertTrue(GBL.tap(app, done, "the results' Done button"), "the results are closed")
            XCTAssertTrue(waitUntilGone(done, timeout: GBL.shortWait), "the results are gone")
        }
        XCTAssertTrue(GBL.waitForStatus(app) { $0 == "Ready" }, "still Ready after the results: \(GBL.status(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, Self.journeyLimit, "the journey took \(elapsed) s")
    }

    /// Whether the case button `target` is the selected case: the selected trait, or its spoken value "Selected"
    /// (both are set together by `GBLControls.caseButton`), waited for at most ``GBL/shortWait``.
    @MainActor
    private func isSelectedCase(_ target: XCUIElement) -> Bool {
        let deadline = Date().addingTimeInterval(GBL.shortWait)
        func selected() -> Bool { target.exists && (target.isSelected || (target.value as? String) == "Selected") }
        while !selected(), Date() < deadline { usleep(200_000) }
        return selected()
    }
}
