// MLScenesUITests — feature 052 (A06-P06) T-A06-609 (US4 scenarios 1 and 2; FR-A06-630): Music Lab opens on the demo
// signal; the 1 kHz tone is chosen, the scenes Rings, Geometry and Bars are switched by identifier (each becomes
// selected and the canvas names it), the palette changes, and the "Sound metrics (approximate)" text carries a value.
// The microphone is never chosen. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import XCTest

final class MLScenesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The tone and the three scenes (US4 scenario 1).
    @MainActor
    func testScenes() {
        let app = ML.open()
        ML.choose(app, "demo.mode.2")                   // 1 kHz tone

        for (index, name) in [(1, "Rings"), (2, "Geometry"), (0, "Bars")] {
            ML.choose(app, "scene.\(index)")
            XCTAssertTrue(ML.waitForLabel(ML.canvas(app), timeout: ML.shortWait) {
                $0.hasPrefix(ML.describedPrefix + name + " scene")
            }, "the canvas names \(name): \(ML.description(app))")
        }

        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// One palette change and the metrics text (US4 scenario 1); its own test keeps each under the 60 s limit (every
    /// palette is drawn in MusicLabMetricsTests).
    @MainActor
    func testPaletteAndMetrics() {
        let app = ML.open()
        ML.choose(app, "demo.mode.2")                   // 1 kHz tone
        ML.choose(app, "palette.1")
        XCTAssertTrue(ML.waitForSelection(ML.control(app, "palette.0"), false), "only one palette is selected")

        let metrics = ML.control(app, "metrics")
        XCTAssertTrue(ML.reveal(app, metrics), "the metrics text is shown")
        XCTAssertTrue(ML.waitForValue(metrics, timeout: 3) { !$0.isEmpty && $0 != "–" },
                      "the metrics text has a value: \(metrics.value as? String ?? "nil")")
        XCTAssertFalse(ML.control(app, "source.microphone").isSelected, "the microphone is not chosen")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
