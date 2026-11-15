// SSETourUITests — feature 108 (A14-P06) T-A14-609 (FR-A14-630; clarification Q4): a tour start and stop and a
// saved-view restore of Solar System Explorer (A14) inside the one app. Starting "Inner planets" from the Tour menu
// selects its first stop, the Sun, and the canvas description carries "Tour Inner planets, stop 1 of 5: …"; the tour
// is then held with Pause tour, because a running tour moves on by itself after 5 s per stop (600 host steps), so that
// Next stop selects the following stop's body deterministically (Mercury after stop 1); Stop tour ends it ("No tour").
// Save view with Earth in focus, then Mars, then Restore view brings Earth back ("View restored."). One journey per
// test, well under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class SSETourUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The Inner planets tour starts at the Sun, Next stop focuses Mercury and Stop tour ends it.
    @MainActor
    func testInnerPlanetsTourStartNextAndStop() {
        let app = SSE.open()

        XCTAssertTrue(SSE.choose(app, menu: "tour", item: "Inner planets"), "the Tour menu offers Inner planets")
        XCTAssertTrue(SSE.waitForStatus(app) { SSE.names($0, "Sun") },
                      "the tour starts at the Sun (now \(SSE.value(app, "status")))")
        XCTAssertTrue(SSE.waitForLabel(SSE.canvas(app)) { $0.contains("Tour Inner planets") },
                      "the canvas description names the tour (now \(SSE.description(app)))")

        // Hold the tour, so that it does not move on by itself, and read the stop it holds (stop 1 unless the
        // test was slower than one 5 s stop).
        SSE.tap(app, "tour-pause")
        let tour = SSE.control(app, "tour")
        XCTAssertTrue(SSE.waitForValue(tour) { $0.hasPrefix("Inner planets, stop ") && $0.hasSuffix(", paused") },
                      "Pause tour holds the tour (now \(SSE.value(app, "tour")))")
        let held = SSE.tourStop(SSE.value(app, "tour")) ?? 1
        XCTAssertLessThan(held, 5, "the tour holds a stop before its last (stop \(held))")
        // Stop k (1-based) of Inner planets shows body k − 1, so the next stop shows body k.
        let next = SSE.bodies[min(held, SSE.bodies.count - 1)]
        if held == 1 { XCTAssertEqual(next, "Mercury") }

        SSE.tap(app, "tour-next")
        XCTAssertTrue(SSE.waitForStatus(app) { SSE.names($0, next) },
                      "Next stop focuses \(next) (now \(SSE.value(app, "status")))")

        SSE.tap(app, "tour-stop")
        XCTAssertTrue(SSE.waitForValue(tour) { $0 == "No tour" },
                      "Stop tour ends the tour (now \(SSE.value(app, "tour")))")
        XCTAssertTrue(SSE.waitForLabel(SSE.canvas(app)) { !$0.contains("Tour Inner planets") },
                      "the canvas description no longer names the tour (now \(SSE.description(app)))")
        XCTAssertTrue(SSE.names(SSE.value(app, "status"), next), "the body stays in focus after the tour")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Save view keeps Earth; after choosing Mars, Restore view brings Earth back.
    @MainActor
    func testSaveViewThenRestoreBringsEarthBack() {
        let app = SSE.open()

        XCTAssertTrue(SSE.chooseBody(app, "Earth"), "the Body menu focuses Earth")
        SSE.tap(app, "save-view")
        let answer = SSE.control(app, "view-message")
        waitFor(answer, timeout: SSE.shortWait, "the saved-view answer is there")
        XCTAssertTrue(SSE.waitForValue(answer) { $0 == "View saved." },
                      "Save view answers (now \(SSE.value(app, "view-message")))")

        XCTAssertTrue(SSE.chooseBody(app, "Mars"), "the Body menu focuses Mars")

        SSE.tap(app, "restore-view")
        XCTAssertTrue(SSE.waitForStatus(app) { SSE.names($0, "Earth") },
                      "Restore view brings Earth back (now \(SSE.value(app, "status")))")
        XCTAssertTrue(SSE.waitForValue(SSE.control(app, "view-message")) { $0 == "View restored." },
                      "Restore view answers (now \(SSE.value(app, "view-message")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
