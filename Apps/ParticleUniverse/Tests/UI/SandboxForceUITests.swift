// SandboxForceUITests — feature 034 A04-P02 T-A04-208 (FR-A04-204; US1 AC1–AC3; SC-A04-206; contracts/app-ui.md):
// tap to place, drag to move, Center, nudges, strength and kind, each read back from the force text.
import XCTest

final class SandboxForceUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func openSandbox() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestThermal", "nominal", "-uitestLowPower", "NO"]
        app.launch()
        let open = app.buttons["pu.home.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(app.staticTexts["pu.sandbox.force"].waitForExistence(timeout: 10))
        return app
    }

    private func canvas(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any)["pu.sandbox.canvas"] }

    /// (kind, x, y, strength) from "Force: Kind at (x, y), strength ×s", or nil for "Force: none".
    private func force(_ app: XCUIApplication) -> (String, Int, Int, Double)? {
        let text = app.staticTexts["pu.sandbox.force"].label
        guard text != "Force: none" else { return nil }
        let regex = try! NSRegularExpression(pattern: #"^Force: (.+) at \((-?\d+), (-?\d+)\), strength ×([0-9.]+)$"#)
        guard let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            XCTFail("unexpected force text: \(text)"); return nil
        }
        func g(_ i: Int) -> String { String(text[Range(m.range(at: i), in: text)!]) }
        return (g(1), Int(g(2))!, Int(g(3))!, Double(g(4))!)
    }

    /// Scrolls `e` into the middle of the window by dragging on the status texts (never on the canvas, which would
    /// place the force), checking its frame after each drag.
    private func reveal(_ e: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        for _ in 0..<8 where !(e.isHittable && e.frame.minY > window.minY + 100 && e.frame.maxY < window.maxY - 60) {
            let handle = app.staticTexts["pu.sandbox.force"].isHittable ? app.staticTexts["pu.sandbox.force"] : app.staticTexts["pu.sandbox.dropped"]
            let from = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let dy: CGFloat = e.frame.midY > window.midY ? -160 : 160
            from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: dy)))
        }
        XCTAssertTrue(e.isHittable, "\(e.identifier) frame \(e.frame) in \(window)")
    }

    private func chooseKind(_ title: String, in app: XCUIApplication) {
        let menu = app.buttons["pu.sandbox.forceKind"]
        reveal(menu, in: app)
        menu.tap()
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), title)
        item.tap()
    }

    func testTapPlacesTheForceWhereTapped() {
        let app = openSandbox()
        XCTAssertNil(force(app), "no force before the first tap")
        canvas(app).coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.25)).tap()
        let f = force(app)
        XCTAssertEqual(f?.0, "Attractor", "the default kind is Attractor (journey 1)")
        XCTAssertEqual(Double(f?.1 ?? 0), 250, accuracy: 20, "upper right quadrant: x ≈ 250")
        XCTAssertEqual(Double(f?.2 ?? 0), 250, accuracy: 20, "y up: y ≈ 250")
        XCTAssertTrue(canvas(app).label.contains("Attractor"), "the canvas description names the force")
    }

    func testDragMovesTheForce() {
        let app = openSandbox()
        let c = canvas(app)
        c.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let start = c.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: c.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.8)))
        let f = force(app)
        XCTAssertEqual(Double(f?.1 ?? 0), -300, accuracy: 25, "dragged left")
        XCTAssertEqual(Double(f?.2 ?? 0), -300, accuracy: 25, "dragged down")
    }

    func testCenterNudgesStrengthAndKindWithoutGestures() {
        let app = openSandbox()
        let center = app.buttons["pu.sandbox.center"]
        reveal(center, in: app)
        XCTAssertFalse(app.buttons["pu.sandbox.nudgeRight"].isEnabled, "nothing to move yet")
        center.tap()
        XCTAssertEqual(force(app)?.1, 0); XCTAssertEqual(force(app)?.2, 0)
        app.buttons["pu.sandbox.nudgeRight"].tap()
        app.buttons["pu.sandbox.nudgeUp"].tap()
        XCTAssertEqual(force(app)?.1, 50); XCTAssertEqual(force(app)?.2, 50)
        app.buttons["pu.sandbox.nudgeLeft"].tap()
        app.buttons["pu.sandbox.nudgeDown"].tap()
        app.buttons["pu.sandbox.nudgeDown"].tap()
        XCTAssertEqual(force(app)?.1, 0); XCTAssertEqual(force(app)?.2, -50)
        for _ in 0..<12 { app.buttons["pu.sandbox.nudgeDown"].tap() }
        XCTAssertEqual(force(app)?.2, -500, "clamped to the world square")

        let slider = app.sliders["pu.sandbox.strength"]
        reveal(slider, in: app)
        slider.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(force(app)?.3, 2.0)
        XCTAssertEqual(slider.value as? String, "×2.0")

        for kind in ["Repulsor", "Gravity well", "Wind", "Vortex"] {
            chooseKind(kind, in: app)
            XCTAssertEqual(force(app)?.0, kind)
            XCTAssertEqual(force(app)?.2, -500, "changing the kind keeps the position")
        }
        chooseKind("None", in: app)
        XCTAssertNil(force(app))
    }
}
