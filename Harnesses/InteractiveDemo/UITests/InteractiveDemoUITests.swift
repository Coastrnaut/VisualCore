// InteractiveDemoUITests — feature 006 T-F520 (FR-F510; spec US5 AC1–AC3; SC-F505). Real touches through
// XCUITest into RenderView → PointerEvents → recognizers; results read from the demo's accessibility diagnostics.
import XCTest

final class InteractiveDemoUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor private func launch(reduceMotion: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestReduceMotion", reduceMotion ? "YES" : "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["demo.diagnostics"].waitForExistence(timeout: 15))
        return app
    }

    /// Parses `particles=<n> zoom=<z> state=<s>`.
    @MainActor private func diagnostics(_ app: XCUIApplication) -> (particles: Int, zoom: Double, state: String) {
        let label = app.staticTexts["demo.diagnostics"].label
        var values: [String: String] = [:]
        for part in label.split(separator: " ") {
            let kv = part.split(separator: "=", maxSplits: 1)
            if kv.count == 2 { values[String(kv[0])] = String(kv[1]) }
        }
        return (Int(values["particles"] ?? "") ?? -1, Double(values["zoom"] ?? "") ?? -1, values["state"] ?? "")
    }

    @MainActor private func canvas(_ app: XCUIApplication) -> XCUIElement {
        let c = app.otherElements["demo.canvas"]
        return c.exists ? c : app.windows.firstMatch
    }

    @MainActor func testDragSpawnsParticles() {
        // AC1
        let app = launch()
        XCTAssertEqual(diagnostics(app).particles, 0)
        let c = canvas(app)
        let start = c.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.65))
        let end = c.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
        let rose = NSPredicate { _, _ in self.diagnostics(app).particles > 0 }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: rose, evaluatedWith: nil)], timeout: 3), .completed,
                       "particles after drag: \(diagnostics(app).particles)")
    }

    @MainActor func testPinchZoomsTheCamera() {
        // AC2
        let app = launch(reduceMotion: true)   // no inertia: the zoom reflects the pinch itself
        XCTAssertEqual(diagnostics(app).zoom, 1, accuracy: 0.001)
        canvas(app).pinch(withScale: 2.5, velocity: 2)
        let zoomed = NSPredicate { _, _ in self.diagnostics(app).zoom > 1.2 }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: zoomed, evaluatedWith: nil)], timeout: 3), .completed,
                       "zoom after pinch: \(diagnostics(app).zoom)")
        XCTAssertTrue(app.staticTexts["Reduce Motion: animations shortened"].exists)
    }

    @MainActor func testBackgroundAndForegroundDoNotBurst() {
        // AC3: after returning, no frame runs more than the 8-step cap and the demo keeps running.
        let app = launch()
        let c = canvas(app)
        c.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.6))
            .press(forDuration: 0.1, thenDragTo: c.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.6)), withVelocity: .slow, thenHoldForDuration: 0.1)
        XCUIDevice.shared.press(.home)
        sleep(3)
        app.activate()
        XCTAssertTrue(app.staticTexts["demo.steps"].waitForExistence(timeout: 10))
        sleep(1)
        let steps = Int(app.staticTexts["demo.steps"].label.split(separator: "=").last ?? "") ?? -1
        XCTAssertGreaterThanOrEqual(steps, 0)
        XCTAssertLessThanOrEqual(steps, 8, "a 3 s absence is not replayed as a catch-up burst")
        let d = diagnostics(app)
        XCTAssertEqual(d.state, "running")
        XCTAssertLessThanOrEqual(d.particles, 10_000)
    }

    @MainActor func testPauseAndResume() {
        let app = launch()
        let toggle = app.buttons["demo.toggle"]
        XCTAssertEqual(toggle.label, "Pause simulation")
        toggle.tap()
        XCTAssertEqual(diagnostics(app).state, "paused")
        XCTAssertEqual(toggle.label, "Resume simulation")
        toggle.tap()
        XCTAssertEqual(diagnostics(app).state, "running")
        XCTAssertEqual(app.buttons["demo.reset"].label, "Reset particles and camera")
    }
}
