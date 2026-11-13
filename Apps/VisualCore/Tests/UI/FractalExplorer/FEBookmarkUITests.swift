// FEBookmarkUITests — feature 193 (UA-F07) T-U07-025: port of the standalone app's BookmarkUITests (feature 028
// T-A03-310; FR-A03-304, FR-A03-305; US1–US4; SC-A03-305) into the one app. With no saved view there is no row;
// save the view under a name, find it again after the app ended, open it after the view changed, rename it, remove
// it only after a confirmation (cancel keeps it); and Go to with an invalid and then a valid entry. Inside the one app
// the bookmarks and Go to are A03's own sections of controls below the canvas (the standalone app showed them in
// sheets), and the bookmark files live in the experience's storage, so they survive a relaunch without
// `-vcResetData` (the standalone test used a fresh folder per launch, `-uitestTemporaryBookmarks`).
//
// Differences from the standalone test, recorded in the test map: the adapter keeps no favourites (they stay in the
// standalone app until its retirement, FractalBookmarks' header), so that step is not ported; rename and remove are
// buttons on the row instead of swipe actions; the empty state has no sentence, only no row; the row shows the name
// and the summary ("−0.5 + 0i · zoom 4×") as two texts; and the go-to error names the field as "Real" (the field's
// raw value) instead of "Real part".
import XCTest

final class FEBookmarkUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testSaveListOpenRenameRemove() {
        var app = FE.open()
        XCTAssertEqual(FE.bookmarkRows(app).count, 0, "no saved view on erased data")
        FE.tap(app, "zoomIn")
        FE.tap(app, "zoomIn")
        FE.expectCanvas(app, "two zoom steps") { $0.hasSuffix("zoom 4×") }

        FE.saveBookmark(app, as: "Valley")
        XCTAssertFalse(FE.control(app, "bookmark.error").exists, "no save error")
        XCTAssertTrue(app.staticTexts["−0.5 + 0i · zoom 4×"].exists, "the row's summary")
        FE.suspendAndEnd(app)

        // The saved view survives the end of the app.
        app = FE.open(arguments: FE.again)
        guard let valleyID = FE.bookmarkID(app, "Valley") else { return XCTFail("no saved view Valley after relaunch") }
        XCTAssertEqual(FE.bookmarkRows(app).count, 1)

        // Change the view, then return through the bookmark.
        FE.tap(app, "resetView")
        FE.expectCanvas(app, "reset view") { $0.hasSuffix("zoom 1×") }
        let open = FE.control(app, "bookmark.open.\(valleyID)")
        FE.reveal(app, open)
        XCTAssertEqual(open.label, "Open")
        open.tap()
        FE.expectCanvas(app, "the bookmark restores the view") { $0 == "Mandelbrot set, centered at −0.5 + 0i, zoom 4×" }

        // Rename.
        FE.tap(app, "bookmark.rename.\(valleyID)")
        let alert = app.alerts["Rename"]
        waitFor(alert, timeout: VC.wait, "the rename alert")
        let field = alert.textFields.firstMatch
        waitFor(field, timeout: VC.wait)
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "Seahorse")
        let renameConfirm = alert.buttons.matching(NSPredicate(format: "identifier == %@ OR label == 'Rename'",
                                                               FE.id("bookmark.renameConfirm"))).firstMatch
        renameConfirm.tap()
        // With the keyboard's suggestions showing, the first tap can be taken by the keyboard; tap once more while
        // the alert is still there.
        if !waitUntilGone(alert, timeout: 2), renameConfirm.exists { renameConfirm.tap() }
        waitFor(FE.renameButton(app, "Seahorse"), timeout: VC.wait, "the renamed bookmark")
        XCTAssertTrue(waitUntilGone(FE.renameButton(app, "Valley")), "the old name is gone")

        // Remove asks first; cancel keeps the bookmark.
        let remove = FE.control(app, "bookmark.remove.\(valleyID)")
        FE.reveal(app, remove)
        XCTAssertEqual(remove.label, "Remove Seahorse")
        remove.tap()
        // Dialog buttons do not always carry their identifier through to XCUITest: match the label too.
        let confirm = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == 'Remove'",
                                                       FE.id("bookmark.removeConfirm"))).firstMatch
        waitFor(confirm, timeout: VC.wait, "the removal asks for a confirmation")
        FE.dismissConfirmation(app)
        XCTAssertTrue(waitUntilGone(confirm), "the confirmation closes")
        XCTAssertTrue(FE.renameButton(app, "Seahorse").exists, "cancel keeps it")
        FE.reveal(app, remove)
        remove.tap()
        waitFor(confirm, timeout: VC.wait)
        confirm.tap()
        XCTAssertTrue(waitUntilGone(FE.renameButton(app, "Seahorse")), "the confirmed removal removes it")
        XCTAssertEqual(FE.bookmarkRows(app).count, 0, "no saved view is left")
        XCTAssertFalse(FE.control(app, "bookmark.error").exists, "no removal error")
        FE.attachScreenshot(app, named: "a03-bookmarks-empty", to: self)
    }

    @MainActor
    func testGoToValidAndInvalid() {
        let app = FE.open()
        FE.type(app, "goto.real", "9")
        FE.type(app, "goto.imaginary", "0")
        FE.type(app, "goto.zoom", "10")
        FE.tap(app, "goto.go")
        let error = FE.control(app, "goto.error")
        waitFor(error, timeout: VC.wait, "the go-to error")
        XCTAssertEqual(error.label, "Real: Use a value between −4 and 4")
        FE.expectCanvas(app, "an invalid entry leaves the view") { $0 == FE.defaultMandelbrot }

        FE.type(app, "goto.real", "-0.75")
        FE.tap(app, "goto.go")
        FE.expectCanvas(app, "the valid entry moves the view") { $0 == "Mandelbrot set, centered at −0.75 + 0i, zoom 10×" }
        XCTAssertTrue(waitUntilGone(FE.control(app, "goto.error")), "the error goes with a valid entry")
    }
}
