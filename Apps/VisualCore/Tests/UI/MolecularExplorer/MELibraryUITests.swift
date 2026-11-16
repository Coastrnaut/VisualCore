// MELibraryUITests — feature 115 (A15-P06) T-A15-609 (clarification Q4): the recent molecules and the stored label
// setting of Molecular Explorer (A15) inside the one app. A fresh start erases the data, so the experience's storage
// holds no `recent.json` and no `settings.json`: the Recent menu holds only the molecule opened at start and Labels is
// All. Opening Caffeine, then Water from the Library makes the Recent menu's value begin "Water, Caffeine" (the recent
// titles newest first, `MoleculeControls.recentValue`); setting Labels to None makes the picker's value None, and
// after the app is ended and A15 opened again without the reset (`ME.reopen`, as the persistence tests relaunch),
// Labels is still None, read from `settings.json`. One journey per test, well under 60 s. The Import button is never
// tapped. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class MELibraryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Caffeine, then Water from the Library: the Recent menu lists Water, then Caffeine.
    @MainActor
    func testRecentListsNewestFirst() {
        let app = ME.open()

        let recent = ME.control(app, "recent")
        waitFor(recent, timeout: ME.shortWait, "the Recent menu is there")
        // The erased data leaves at most the molecule opened at start: never Caffeine before it is opened.
        XCTAssertFalse(ME.value(app, "recent").contains("Caffeine"),
                       "a fresh start has no Caffeine in Recent (now \(ME.value(app, "recent")))")

        XCTAssertTrue(ME.chooseFromLibrary(app, id: "caffeine", title: "Caffeine"), "the Library opens Caffeine")
        XCTAssertTrue(ME.waitForValue(recent) { $0.hasPrefix("Caffeine") },
                      "Caffeine is the newest recent molecule (now \(ME.value(app, "recent")))")

        XCTAssertTrue(ME.chooseFromLibrary(app, id: "water", title: "Water"), "the Library opens Water")
        XCTAssertTrue(ME.waitForValue(recent) { $0.hasPrefix("Water, Caffeine") },
                      "the Recent menu lists Water, then Caffeine (now \(ME.value(app, "recent")))")
        XCTAssertEqual(ME.value(app, "recent").components(separatedBy: "Water").count, 2,
                       "Water is listed once (now \(ME.value(app, "recent")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Labels set to None stays None after the experience is opened again.
    @MainActor
    func testLabelsNoneSurvivesReopen() {
        let app = ME.open()

        let labels = ME.control(app, "labels")
        waitFor(labels, timeout: ME.shortWait, "the Labels picker is there")
        XCTAssertTrue(ME.waitForValue(labels) { $0.hasPrefix("All") },
                      "a fresh start shows all labels (now \(ME.value(app, "labels")))")

        XCTAssertTrue(ME.chooseSegment(app, picker: "labels", "None"), "the Labels picker offers None")
        XCTAssertTrue(ME.waitForValue(labels) { $0.hasPrefix("None") },
                      "the picker's value is None (now \(ME.value(app, "labels")))")
        XCTAssertFalse(ME.control(app, "settings-message").exists,
                       "the setting was saved (now \(ME.value(app, "settings-message")))")

        let second = ME.reopen(app)
        let again = ME.control(second, "labels")
        waitFor(again, timeout: ME.shortWait, "the Labels picker is there again")
        XCTAssertTrue(ME.waitForValue(again) { $0.hasPrefix("None") },
                      "Labels is still None after opening again (now \(ME.value(second, "labels")))")
        XCTAssertFalse(element(second, "session.failure").exists, "no failure")
    }
}
