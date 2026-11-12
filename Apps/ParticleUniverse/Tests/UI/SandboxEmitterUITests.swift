// SandboxEmitterUITests — feature 035 A04-P03 T-A04-311 (US1, US2; FR-A04-304, FR-A04-305; SC-A04-306;
// contracts/app-ui.md): add, select and remove emitters; size, lifetime and gradient controls.
import XCTest

final class SandboxEmitterUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func emitterCount(_ app: XCUIApplication) -> Int {
        let label = app.staticTexts["pu.sandbox.emitters"].label
        return Int(label.components(separatedBy: CharacterSet.decimalDigits.inverted).first { !$0.isEmpty } ?? "") ?? -1
    }

    func testAddSelectAndRemoveEmitters() {
        let app = launchSandbox()
        XCTAssertEqual(emitterCount(app), 1)
        let remove = app.buttons["pu.sandbox.removeEmitter"]
        XCTAssertFalse(remove.isEnabled, "a scene always keeps one emitter")
        let add = app.buttons["pu.sandbox.addEmitter"]
        add.tap(); add.tap()
        XCTAssertEqual(emitterCount(app), 3)
        XCTAssertTrue(app.buttons["pu.sandbox.emitter"].label.contains("Emitter 3"), "the new emitter is selected")
        choose("Emitter 1", in: "pu.sandbox.emitter", app: app)
        XCTAssertTrue(app.buttons["pu.sandbox.emitter"].label.contains("Emitter 1"))
        app.buttons["Halo"].tap()   // the family picker edits the selected emitter only
        XCTAssertEqual(emitterCount(app), 3, "changing a family keeps the count")
        XCTAssertTrue(remove.isEnabled)
        remove.tap()
        XCTAssertEqual(emitterCount(app), 2)
        remove.tap()
        XCTAssertEqual(emitterCount(app), 1)
        XCTAssertFalse(remove.isEnabled)
    }

    func testSizeLifetimeAndGradientControls() {
        let app = launchSandbox()
        let size = app.sliders["pu.sandbox.size"]
        reveal(size, in: app)
        size.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(size.value as? String, "48 points")
        size.adjust(toNormalizedSliderPosition: 0)
        XCTAssertEqual(size.value as? String, "1 points")
        let lifetime = app.sliders["pu.sandbox.lifetime"]
        reveal(lifetime, in: app)
        lifetime.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(lifetime.value as? String, "8.0 seconds")
        choose("Ocean", in: "pu.sandbox.gradient", app: app)
        XCTAssertTrue(app.buttons["pu.sandbox.gradient"].label.contains("Ocean"), app.buttons["pu.sandbox.gradient"].label)
        choose("Family colors", in: "pu.sandbox.gradient", app: app)
        XCTAssertTrue(app.buttons["pu.sandbox.gradient"].label.contains("Family colors"))
    }
}
