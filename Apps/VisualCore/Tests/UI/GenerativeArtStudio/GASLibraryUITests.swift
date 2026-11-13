// GASLibraryUITests — feature 193 (UA-F07) T-U07-015: port of the standalone app's LibraryUITests (feature 014
// T-A01-305; FR-A01-301 to FR-A01-304; SC-A01-303) into the one app. Save with a name, find it again after the app
// ended, rename, remove only after a confirmation (cancel keeps it), and open a saved composition, which shows its
// family again and edits under its name. Inside the one app the library is A01's own section of controls and its
// files live in the experience's storage.
// Differences from the standalone test, recorded in the test map: the adapter lists the entries by name (the
// standalone library listed the newest first; in this test both orders are the same), and it has no favourites and
// no duplication: those stay in the standalone app until its retirement (GenerativeArtLibrary's header), so those
// steps are not ported.
import XCTest

final class GASLibraryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Opens the removal confirmation of `name`.
    @MainActor
    private func askToRemove(_ app: XCUIApplication, _ name: String, uuid: String) {
        let remove = GAS.control(app, "library.remove.\(uuid)")
        GAS.reveal(app, remove)
        XCTAssertEqual(remove.label, "Remove \(name)")
        remove.tap()
    }

    @MainActor
    func testSaveReopenAndOrganize() {
        var app = GAS.open()
        GAS.tap(app, "family.geometric-tiling")
        GAS.expectFamily(app, "Geometric Tiling")
        GAS.save(app, as: "My Stars")
        GAS.suspendAndEnd(app)

        // The saved composition survives the end of the app.
        app = GAS.open(arguments: GAS.again)
        let stars = GAS.renameButton(app, "My Stars")
        waitFor(stars, timeout: VC.wait, "the saved composition after the app ended")
        GAS.tap(app, "family.gradient-noise")
        GAS.expectFamily(app, "Gradient Noise")
        GAS.save(app, as: "Clouds")
        XCTAssertEqual(GAS.entryNames(app), ["Clouds", "My Stars"], "both entries, by name")

        // Rename.
        guard let cloudsID = GAS.entryID(app, "Clouds") else { return XCTFail("no id for Clouds") }
        GAS.tap(app, "library.rename.\(cloudsID)")
        let alert = app.alerts["Rename"]
        waitFor(alert, timeout: VC.wait, "the rename alert")
        let field = alert.textFields.firstMatch
        waitFor(field, timeout: VC.wait)
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 40) + "Renamed")
        alert.buttons.matching(NSPredicate(format: "identifier == %@ OR label == 'Rename'",
                                           GAS.id("library.rename.confirm"))).firstMatch.tap()
        waitFor(GAS.renameButton(app, "Renamed"), timeout: VC.wait, "the renamed entry")
        XCTAssertTrue(waitUntilGone(GAS.renameButton(app, "Clouds")), "the old name is gone")

        // Remove asks first; cancel keeps the entry.
        guard let renamedID = GAS.entryID(app, "Renamed") else { return XCTFail("no id for Renamed") }
        askToRemove(app, "Renamed", uuid: renamedID)
        // Alert and dialog buttons do not always carry their identifier through to XCUITest: match the label too.
        let confirm = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == 'Remove'",
                                                       GAS.id("library.remove.confirm"))).firstMatch
        waitFor(confirm, timeout: VC.wait, "the removal asks for a confirmation")
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists {
            cancel.tap()
        } else {
            // On a tablet the confirmation is a popover without a Cancel button: a tap outside it dismisses it.
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        }
        XCTAssertTrue(waitUntilGone(confirm), "the confirmation closes")
        XCTAssertTrue(GAS.renameButton(app, "Renamed").exists, "cancel keeps it")
        askToRemove(app, "Renamed", uuid: renamedID)
        waitFor(confirm, timeout: VC.wait)
        confirm.tap()
        XCTAssertTrue(waitUntilGone(GAS.renameButton(app, "Renamed")), "the confirmed removal removes it")
        XCTAssertEqual(GAS.entryNames(app), ["My Stars"])

        // Opening an entry shows its family again and edits it under its name.
        guard let starsID = GAS.entryID(app, "My Stars") else { return XCTFail("no id for My Stars") }
        GAS.tap(app, "library.open.\(starsID)")
        GAS.expectFamily(app, "Geometric Tiling")
        let name = GAS.control(app, "library.name")
        GAS.reveal(app, name)
        XCTAssertEqual(name.value as? String, "My Stars", "the opened entry's name is in the name field")
        GAS.attachScreenshot(app, named: "a01-library-entry", to: self)
    }
}
