// LibraryUITests — feature 014 T-A01-305 (US1, US2; FR-A01-301–FR-A01-304; SC-A01-303): save with a name, reopen
// after relaunch, favorites first, duplicate, rename, delete with confirmation (cancel keeps it).
import XCTest

final class LibraryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ dir: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-gasLibraryDir", dir]
        app.launch()
        return app
    }

    private func save(_ app: XCUIApplication, family: String, as name: String) {
        app.buttons["gas.family.\(family)"].tap()
        let save = app.buttons["gas.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        // SwiftUI alert fields don't carry identifiers through to XCUITest; address them through the alert.
        let alert = app.alerts["Save composition"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let field = alert.textFields.firstMatch
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + name)
        alert.buttons.matching(NSPredicate(format: "identifier == 'gas.save.confirm' OR label == 'Save'")).firstMatch.tap()
        XCTAssertEqual(app.buttons["gas.save"].label, "Save changes", "the scene now edits the saved entry")
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    private func rowLabels(_ app: XCUIApplication) -> [String] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'gas.library.row.'")).allElementsBoundByIndex.map { $0.label }
    }

    private func row(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'gas.library.row.' AND label == %@", name)).firstMatch
    }

    private func more(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let id = row(app, name).identifier.replacingOccurrences(of: "gas.library.row.", with: "")
        return app.buttons["gas.library.more.\(id)"]
    }

    func testSaveReopenAndOrganize() {
        let dir = "uitest-library-\(UUID().uuidString)"
        var app = launch(dir)
        save(app, family: "geometric-tiling", as: "My Stars")
        app.terminate()

        app = launch(dir)
        app.buttons["gas.library.open"].tap()
        XCTAssertTrue(row(app, "My Stars").waitForExistence(timeout: 5), "saved composition survives a relaunch")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        save(app, family: "gradient-noise", as: "Clouds")
        app.buttons["gas.library.open"].tap()
        XCTAssertTrue(row(app, "Clouds").waitForExistence(timeout: 5))
        XCTAssertEqual(rowLabels(app), ["Clouds", "My Stars"], "most recent first")

        let starID = row(app, "My Stars").identifier.replacingOccurrences(of: "gas.library.row.", with: "")
        app.buttons["gas.library.favorite.\(starID)"].tap()
        XCTAssertEqual(rowLabels(app).first, "My Stars", "favorites first")

        more(app, "My Stars").tap()
        app.buttons.matching(identifier: "gas.library.duplicate").firstMatch.tap()
        XCTAssertTrue(row(app, "My Stars copy").waitForExistence(timeout: 5))

        more(app, "My Stars copy").tap()
        app.buttons.matching(identifier: "gas.library.rename").firstMatch.tap()
        let alert = app.alerts["Rename"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let field = alert.textFields.firstMatch
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + "Renamed")
        alert.buttons.matching(NSPredicate(format: "identifier == 'gas.library.renameConfirm' OR label == 'Rename'")).firstMatch.tap()
        XCTAssertTrue(row(app, "Renamed").waitForExistence(timeout: 5))

        more(app, "Renamed").tap()
        app.buttons.matching(identifier: "gas.library.delete").firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "gas.library.confirmDelete").firstMatch.waitForExistence(timeout: 3))
        app.alerts.firstMatch.buttons.matching(NSPredicate(format: "identifier == 'gas.library.cancelDelete' OR label == 'Cancel'")).firstMatch.tap()
        XCTAssertFalse(app.buttons.matching(identifier: "gas.library.confirmDelete").firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(row(app, "Renamed").exists, "cancel keeps it")
        more(app, "Renamed").tap()
        app.buttons.matching(identifier: "gas.library.delete").firstMatch.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "identifier == 'gas.library.confirmDelete'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertFalse(row(app, "Renamed").waitForExistence(timeout: 2))

        row(app, "My Stars").tap()
        XCTAssertTrue(app.buttons["gas.save"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["gas.scene.title"].label, "Geometric Tiling")
        XCTAssertEqual(app.buttons["gas.save"].label, "Save changes", "opening an entry edits it in place")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "library-entry"; shot.lifetime = .keepAlways; add(shot)
    }
}
