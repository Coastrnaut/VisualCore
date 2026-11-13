// PUSceneLibraryUITests — feature 036 A04-P04 T-A04-409 (US1, US3; FR-A04-401 to 405, FR-A04-420, 421; SC-A04-401,
// SC-A04-404): save a scene under a name, change it, open the saved scene, open it again after a relaunch, rename and
// delete it; a moved emitter is kept. System accessibility audits wait for the device campaign (owner ruling).
import XCTest

final class PUSceneLibraryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    private func text(_ app: XCUIApplication, _ name: String) -> String {
        let target = PU.control(app, name)
        _ = target.waitForExistence(timeout: VC.wait)
        return target.label
    }

    @MainActor
    private func type(_ app: XCUIApplication, _ name: String, _ value: String) {
        let field = PU.control(app, name)
        guard PU.reveal(app, field) else { return }
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != "Scene name", current != "New name" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(value + "\n")                    // return dismisses the keyboard
    }

    /// Saves "Nebula" after moving an emitter, changes the scene and opens the saved scene again (US1, US3).
    @MainActor
    func testSaveChangeAndOpen() {
        let app = PU.open()
        let saved = text(app, "emitters")                // the scene as saved (the default has one emitter)
        PU.tap(app, "move.right")                       // a moved emitter is saved with the scene
        type(app, "library.name", "Nebula")
        PU.tap(app, "library.save")
        XCTAssertEqual(text(app, "library.entry.0"), "Nebula")
        PU.tap(app, "emitter.add")                       // change the scene after saving
        XCTAssertNotEqual(text(app, "emitters"), saved, "the scene changed")
        PU.tap(app, "library.open.0")
        XCTAssertEqual(text(app, "emitters"), saved, "opening restores the saved scene")
        XCTAssertFalse(PU.control(app, "library.message").exists, "no error after opening")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The library survives a relaunch; a saved scene is renamed and deleted (US1 scenarios 2 and 4).
    @MainActor
    func testRelaunchRenameAndDelete() {
        let app = PU.open()
        type(app, "library.name", "Nebula")
        PU.tap(app, "library.save")
        let again = relaunch(app, arguments: PU.again)
        PU.waitUntilRunning(again)
        XCTAssertEqual(text(again, "library.entry.0"), "Nebula", "the library survives a relaunch")
        PU.tap(again, "library.rename.0")
        type(again, "library.renameText.0", "Galaxy")
        PU.tap(again, "library.renameDone.0")
        XCTAssertEqual(text(again, "library.entry.0"), "Galaxy")
        PU.tap(again, "library.delete.0")
        XCTAssertFalse(PU.control(again, "library.entry.0").waitForExistence(timeout: 2), "the scene is deleted")
        XCTAssertFalse(element(again, "session.failure").exists, "no failure")
    }
}
