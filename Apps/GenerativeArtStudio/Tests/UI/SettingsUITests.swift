// SettingsUITests — feature 016 T-A01-505 (FR-A01-501; SC-A01-501: choices persist across relaunch).
import XCTest

final class SettingsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func openSettings(_ app: XCUIApplication) {
        let open = app.buttons["gas.settings.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.tap()
        XCTAssertTrue(element(app, "gas.settings.reduceMotion").waitForExistence(timeout: 5))
    }

    /// Opens a picker menu and taps the option whose label starts with `prefix`, then waits for the value.
    private func choose(_ app: XCUIApplication, _ picker: XCUIElement, prefix: String) {
        picker.tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), prefix)
        option.tap()
        let want = prefix
        let deadline = Date().addingTimeInterval(5)
        while (picker.value as? String) != want, Date() < deadline { usleep(200_000) }
    }

    func testChoicesPersistAndFooterExplainsOverride() {
        let app = XCUIApplication()
        app.launch()
        openSettings(app)
        let motion = element(app, "gas.settings.reduceMotion")
        if (motion.value as? String) != "System" { choose(app, motion, prefix: "System") }   // leftover from an earlier run
        XCTAssertEqual(motion.value as? String, "System")
        XCTAssertEqual(element(app, "gas.settings.reduceFlashing").value as? String, "System")
        XCTAssertTrue(element(app, "gas.settings.footer").label.contains("Off overrides the system setting"))
        XCTAssertTrue(element(app, "gas.settings.about").exists)
        choose(app, motion, prefix: "On")
        XCTAssertEqual(motion.value as? String, "On")
        app.buttons["gas.settings.done"].tap()

        // Relaunch without overriding arguments: the stored choice is kept.
        app.terminate()
        let again = XCUIApplication()
        again.launch()
        openSettings(again)
        XCTAssertEqual(element(again, "gas.settings.reduceMotion").value as? String, "On")
        choose(again, element(again, "gas.settings.reduceMotion"), prefix: "System")   // reset for other tests
        again.buttons["gas.settings.done"].tap()
    }

    // T-A01-610: the bundled licenses are shown; ANGLE's full BSD text opens from the list.
    func testAcknowledgementsShowBundledLicenses() {
        let app = XCUIApplication()
        app.launch()
        openSettings(app)
        let link = element(app, "gas.settings.acknowledgements")
        for _ in 0..<3 where !link.isHittable { app.swipeUp() }
        link.tap()
        let angle = element(app, "gas.acknowledgements.angle")
        XCTAssertTrue(angle.waitForExistence(timeout: 5), "ANGLE row")
        XCTAssertTrue(angle.label.contains("BSD-3-Clause"), angle.label)
        XCTAssertTrue(element(app, "gas.acknowledgements.visualcore").exists)
        angle.tap()
        let text = element(app, "gas.acknowledgements.text")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("ANGLE Project Authors") || text.label.contains("Redistribution"), String(text.label.prefix(120)))
    }
}
