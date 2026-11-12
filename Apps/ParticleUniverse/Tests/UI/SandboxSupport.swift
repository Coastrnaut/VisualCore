// SandboxSupport — shared UI-test helpers for the sandbox (feature 035 A04-P03).
import XCTest

extension XCTestCase {
    /// Launches with nominal heat (deterministic quality), opens the sandbox and waits for the counts.
    func launchSandbox(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestThermal", "nominal", "-uitestLowPower", "NO"] + extra
        app.launch()
        let open = app.buttons["pu.home.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.staticTexts["pu.sandbox.live"].waitForExistence(timeout: 10))
        return app
    }

    /// Scrolls `e` into the middle of the window by dragging on a status text (never on the canvas).
    func reveal(_ e: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        for _ in 0..<10 where !(e.exists && e.isHittable && e.frame.minY > window.minY + 100 && e.frame.maxY < window.maxY - 60) {
            let ids = ["pu.sandbox.description", "pu.sandbox.emitters", "pu.sandbox.force", "pu.sandbox.dropped",
                       "pu.sandbox.live", "pu.sandbox.effective", "pu.sandbox.renderer"]
            // Only drag from a handle well inside the screen: a drag starting near the bottom edge is the system
            // home gesture and sends the app to the background.
            let safe = window.insetBy(dx: 0, dy: 180)
            let handle = ids.map { app.staticTexts[$0] }
                .first { $0.exists && $0.isHittable && safe.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
            // Fallback: the right margin beside the stage (no system gesture there; the left edge is "back").
            let from = handle?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                ?? app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: window.maxX - 6, dy: window.midY))
            let dy: CGFloat = (!e.exists || e.frame.midY > window.midY) ? -160 : 160
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: dy)))
        }
        XCTAssertTrue(e.isHittable, "\(e.identifier) frame \(e.frame)")
    }

    /// Opens the menu picker `id` and taps `title`.
    func choose(_ title: String, in id: String, app: XCUIApplication) {
        let menu = app.buttons[id]
        reveal(menu, in: app)
        menu.tap()
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), title)
        item.tap()
    }
}
