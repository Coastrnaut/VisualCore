// RecoveryUITests — feature 013 T-A01-209 (US3; FR-A01-205; SC-A01-204): corrupt and future-version launch data show a
// recoverable message; "Use default" continues with a working canvas; correctable data opens with notes.
import XCTest

final class RecoveryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(with json: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-gasComposition", Data(json.utf8).base64EncodedString()]
        app.launch()
        return app
    }

    private static let future = #"{"familyID":"geometric-tiling","id":"00000000-0000-0000-0000-0000000000AA","paletteID":"neon","parameters":{},"previewTime":0,"schemaVersion":7,"seed":"5"}"#
    private static let correctable = #"{"familyID":"geometric-tiling","id":"00000000-0000-0000-0000-0000000000AA","paletteID":"nope","parameters":{"cells":999},"previewTime":0,"schemaVersion":1,"seed":"5"}"#

    func testCorruptDataIsRecoverable() {
        let app = launch(with: "{ this is not a composition")
        let banner = app.descendants(matching: .any)["gas.recovery.message"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Couldn’t read this composition"].exists)
        app.buttons["gas.recovery.useDefault"].tap()
        XCTAssertFalse(banner.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["gas.scene.canvas"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["gas.scene.error"].exists)
    }

    func testFutureVersionIsRecoverable() {
        let app = launch(with: Self.future)
        XCTAssertTrue(app.descendants(matching: .any)["gas.recovery.message"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Made with a newer version"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'version 7'")).firstMatch.exists)
        app.buttons["gas.recovery.useDefault"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["gas.scene.canvas"].waitForExistence(timeout: 5))
    }

    func testCorrectableDataOpensWithNotes() {
        let app = launch(with: Self.correctable)
        XCTAssertTrue(app.staticTexts["gas.open.notes"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["gas.scene.title"].label, "Geometric Tiling")
        XCTAssertFalse(app.descendants(matching: .any)["gas.recovery.message"].exists)
    }
}
