// GBLRunUITests — feature 177 (A24-P05) T-A24-507 (FR-A24-505, SC-A24-504; clarifications "What does 'About these
// numbers' say" and the background fact; contracts/review.md "Interface", chunk `f3`, serial): the first interface
// tests of Graphics Benchmark Lab (A24) inside the one app.
//
//   1. A fresh start (`GBL.fresh`) selects the quads case (`case-quads`) and starts a run (`run-start`); the status
//      passes "Warm-up" and "Measuring" and reads "Finished" (the plan is 3 + 10 + 5 s, so at most 25 s are waited);
//      the run's `qualification` is shown. The result is saved (`result-save`), the saved results are shown
//      (`results`), `result-row-1` is listed and opened (`result-open-1`, `result-opened`); `explain` opens the
//      explanation (`explanation`), which holds the headings "What is measured" and "Simulator numbers", and
//      `explanation-done` closes it.
//   2. A run in warm-up or measurement is left for the home screen (`XCUIDevice.shared.press(.home)`) for at least
//      2.5 s, longer than the 1,000 ms sample cap: the render host pauses, and the first frame after `activate()`
//      carries the whole gap, so the recorder ends the run as "Interrupted" and its `qualification` reads "Invalid".
//
// Every wait is bounded (`GBL.shortWait`, `VC.wait`, `VC.firstWait`, the named limits below) and each journey, timed
// from the Start run tap (the app launch and case selection are setup), stays under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

/// The A24-P05 interface journeys: a quads run to its explanation, and a run interrupted by leaving the app.
final class GBLRunUITests: XCTestCase {
    /// The longest a journey may take from the Start run tap (SC-A24-504).
    static let journeyLimit: TimeInterval = 60
    /// The longest the warm-up and measurement words are waited for (the warm-up lasts 3 s).
    static let phaseWait: TimeInterval = 10
    /// The longest "Finished" is waited for after the run started (the plan is 3 + 10 + 5 = 18 s).
    static let finishWait: TimeInterval = 25
    /// How long the app stays in the background (longer than the 1,000 ms sample cap, at least 2 s).
    static let backgroundTime: TimeInterval = 2.5
    /// The longest "Interrupted" is waited for after the app is active again.
    static let interruptedWait: TimeInterval = 10

    /// Stops a journey at its first failed check.
    override func setUp() { continueAfterFailure = false }

    /// A quads run finishes with a qualification; its saved result opens and explains its numbers.
    @MainActor
    func testAQuadsRunFinishesAndItsResultOpensWithItsExplanation() {
        let app = GBL.open()
        XCTAssertTrue(GBL.tap(app, GBL.control(app, "case-quads"), "the quads case"), "quads is selected")
        let started = Date()
        XCTAssertTrue(GBL.tap(app, GBL.control(app, "run-start"), "the Start run button"), "the run is started")
        XCTAssertTrue(GBL.waitForStatus(app, timeout: Self.phaseWait) { $0 == "Warm-up" || $0 == "Measuring" },
                      "the run warms up: \(GBL.status(app))")
        XCTAssertTrue(GBL.waitForStatus(app, timeout: Self.phaseWait) { $0 == "Measuring" || $0 == "Finished" },
                      "the run measures: \(GBL.status(app))")
        XCTAssertTrue(GBL.waitForStatus(app, timeout: Self.finishWait) { $0 == "Finished" },
                      "the run finishes: \(GBL.status(app))")
        let qualification = GBL.control(app, "qualification")
        XCTAssertTrue(qualification.waitForExistence(timeout: GBL.shortWait),
                      "the finished run shows its qualification")

        XCTAssertTrue(GBL.tap(app, GBL.control(app, "result-save"), "the Save result button"), "the result is saved")
        XCTAssertTrue(GBL.tap(app, GBL.control(app, "results"), "the Saved results button"), "the results are shown")
        let row = GBL.control(app, "result-row-1")
        XCTAssertTrue(row.waitForExistence(timeout: GBL.shortWait), "the saved result is listed as result-row-1")
        XCTAssertTrue(GBL.tap(app, GBL.control(app, "result-open-1"), "the Open button of result 1"),
                      "result 1 is opened")
        let opened = GBL.control(app, "result-opened")
        XCTAssertTrue(opened.waitForExistence(timeout: GBL.shortWait), "the opened result is shown")

        XCTAssertTrue(GBL.tap(app, GBL.control(app, "explain"), "the explain button"), "the explanation is asked for")
        let explanation = GBL.control(app, "explanation")
        XCTAssertTrue(explanation.waitForExistence(timeout: GBL.shortWait), "the explanation is shown")
        for heading in ["What is measured", "Simulator numbers"] {
            XCTAssertTrue(GBL.holds(explanation, heading), "the explanation holds the heading \"\(heading)\"")
        }
        XCTAssertTrue(GBL.tap(app, GBL.control(app, "explanation-done"), "the explanation's Done button"),
                      "the explanation is closed")
        XCTAssertTrue(waitUntilGone(explanation, timeout: GBL.shortWait), "the explanation is gone")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, Self.journeyLimit, "the journey took \(elapsed) s")
    }

    /// A run left for the home screen mid-run ends as Interrupted, and its qualification is Invalid.
    @MainActor
    func testLeavingTheAppMidRunEndsItAsInterrupted() {
        let app = GBL.open()
        XCTAssertTrue(GBL.tap(app, GBL.control(app, "case-quads"), "the quads case"), "quads is selected")
        let started = Date()
        XCTAssertTrue(GBL.tap(app, GBL.control(app, "run-start"), "the Start run button"), "the run is started")
        XCTAssertTrue(GBL.waitForStatus(app, timeout: Self.phaseWait) { $0 == "Warm-up" || $0 == "Measuring" },
                      "the run is in progress: \(GBL.status(app))")

        let left = Date()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(GBL.waitForBackground(app), "the app is in the background: \(app.state.rawValue)")
        GBL.pause(Self.backgroundTime - Date().timeIntervalSince(left))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: VC.wait), "the app is active again")
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(left), 2, "the app was away for at least 2 s")

        XCTAssertTrue(GBL.waitForStatus(app, timeout: Self.interruptedWait) { $0 == "Interrupted" },
                      "the run ends as Interrupted: \(GBL.status(app))")
        let qualification = GBL.control(app, "qualification")
        XCTAssertTrue(GBL.waitForSpoken(qualification) { $0.contains("Invalid") },
                      "the interrupted run is Invalid: \(GBL.spoken(qualification))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, Self.journeyLimit, "the journey took \(elapsed) s")
    }
}
