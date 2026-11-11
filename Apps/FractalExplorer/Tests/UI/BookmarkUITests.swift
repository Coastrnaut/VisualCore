// BookmarkUITests — feature 028 T-A03-310 (FR-A03-304, FR-A03-305; US1–US4; SC-A03-305; analyze G1): the bookmark
// sheet's empty state, save with a name, list, open after the view changed, rename, favorite and delete; Go to with
// a valid and an invalid entry. Each launch uses a fresh bookmark folder (-uitestTemporaryBookmarks).
import XCTest

final class BookmarkUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestTemporaryBookmarks"]
        app.launch()
        app.buttons["fe.home.open"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["fe.canvas"].waitForExistence(timeout: 10))
        return app
    }

    private func row(_ app: XCUIApplication, _ index: Int) -> XCUIElement {
        app.descendants(matching: .any)["fe.bookmark.row.\(index)"]
    }

    func testSaveListOpenRenameFavoriteDelete() {
        let app = launch()
        let canvas = app.descendants(matching: .any)["fe.canvas"]
        app.buttons["fe.zoomIn"].tap(); app.buttons["fe.zoomIn"].tap()
        XCTAssertTrue(canvas.label.hasSuffix("zoom 4×"), canvas.label)

        app.buttons["fe.bookmarks"].tap()
        XCTAssertTrue(app.staticTexts["fe.bookmarks.empty"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["fe.bookmarks.empty"].label, "No bookmarks yet. Save the current view to come back to it later.")
        app.buttons["fe.bookmark.save"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Valley")
        app.alerts.buttons["Save"].firstMatch.tap()
        let first = row(app, 0)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.label, "Valley, −0.5 + 0i · zoom 4×")
        app.buttons["fe.bookmarks.done"].tap()

        // Change the view, then return through the bookmark.
        app.buttons["fe.resetView"].tap()
        XCTAssertTrue(canvas.label.hasSuffix("zoom 1×"), canvas.label)
        app.buttons["fe.bookmarks"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(app.descendants(matching: .any)["fe.bookmarks.list"].waitForNonExistence(timeout: 5), "the sheet closes")
        let restored = expectation(for: NSPredicate(format: "label ENDSWITH %@", "zoom 4×"), evaluatedWith: canvas)
        wait(for: [restored], timeout: 5)

        // Rename and favorite through the swipe actions, then delete.
        app.buttons["fe.bookmarks"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.swipeLeft()
        app.buttons["Rename"].tap()
        let rename = app.alerts.textFields.firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        rename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "Seahorse")
        app.alerts.buttons["Rename"].firstMatch.tap()
        XCTAssertTrue(row(app, 0).label.hasPrefix("Seahorse"), row(app, 0).label)
        row(app, 0).swipeRight()
        app.buttons["Favorite"].tap()
        XCTAssertTrue(row(app, 0).label.hasSuffix("favorite"), row(app, 0).label)
        row(app, 0).swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["fe.bookmarks.empty"].waitForExistence(timeout: 5))
    }

    func testGoToValidAndInvalid() {
        let app = launch()
        let canvas = app.descendants(matching: .any)["fe.canvas"]
        app.buttons["fe.goto"].tap()
        let real = app.textFields["fe.goto.real"]
        XCTAssertTrue(real.waitForExistence(timeout: 5))
        real.tap(); real.typeText("9")
        app.textFields["fe.goto.imaginary"].tap(); app.textFields["fe.goto.imaginary"].typeText("0")
        app.textFields["fe.goto.zoom"].tap(); app.textFields["fe.goto.zoom"].typeText("10")
        app.buttons["fe.goto.go"].tap()
        let error = app.staticTexts["fe.goto.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(error.label, "Real part: Use a value between −4 and 4")

        real.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()   // the cursor after the text
        real.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "-0.75")
        app.buttons["fe.goto.go"].tap()
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertEqual(canvas.label, "Mandelbrot set, centered at −0.75 + 0i, zoom 10×")
    }
}
