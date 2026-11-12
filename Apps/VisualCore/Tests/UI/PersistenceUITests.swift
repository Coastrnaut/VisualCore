// PersistenceUITests — feature 191 (UA-F05) T-U05-016, T-U05-018, T-U05-023 (US1, US2, US6; FR-U05-021,
// FR-U05-031, FR-U05-033, FR-U05-062; SC-U05-002, SC-U05-008): the state of an experience comes back after the
// app ended and after leaving the experience; a damaged stored state gives the notice with Reset and Back and
// never a running experience; after a scripted use the container holds nothing the inventory does not list.
// Two classes, so that each is one chunk of the app test runs: `PersistenceUITests` (chunk `-e`: restore and
// inventory) and `PersistenceDamageUITests` (chunk `-f`: damaged states and the notice). The debug experience shows its state as "… <n> taps." under its Tap button.
import UIKit
import XCTest

private enum Args {
    static let fresh = [VC.reset, VC.fixture, VC.skipWelcome]
    static let again = [VC.fixture, VC.skipWelcome]
    static let damage = "-vcDamageState"
    static let stray = "-vcStrayItems"
}

// MARK: - Helpers shared by the two classes

@MainActor
private func openFirstFree(_ app: XCUIApplication, expectCanvas: Bool = true) {
    waitFor(element(app, "vc.route.catalog"))
    let free = firstTile(app, tier: "Free")
    var swipes = 0
    while !free.waitForExistence(timeout: 2), swipes < 4 {
        scrollCatalog(app)
        swipes += 1
    }
    waitFor(free, timeout: VC.wait)
    revealAndTap(app, free)
    waitFor(element(app, "vc.route.experience"), timeout: VC.wait)
    if expectCanvas { waitFor(element(app, VC.canvas), timeout: VC.firstWait) }
}

@MainActor
private func ending(_ app: XCUIApplication, _ suffix: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "identifier ENDSWITH %@", suffix)).firstMatch
}

/// Taps the debug experience's button `count` times.
@MainActor
private func tap(_ app: XCUIApplication, _ count: Int) {
    let button = ending(app, ".tap")
    waitFor(button, timeout: VC.wait)
    for _ in 0..<count { button.tap() }
}

/// Waits until the debug experience's summary names `count` taps.
@MainActor
private func expectTaps(_ app: XCUIApplication, _ count: Int, _ note: String,
                        file: StaticString = #filePath, line: UInt = #line) {
    let summary = ending(app, ".tap.summary")
    waitFor(summary, timeout: VC.firstWait, file: file, line: line)
    let wanted = " \(count) taps"
    let deadline = Date().addingTimeInterval(VC.wait)
    while !summary.label.contains(wanted), Date() < deadline { usleep(200_000) }
    XCTAssertTrue(summary.label.contains(wanted), "\(note): \(summary.label)", file: file, line: line)
}

/// Sends the app to the background (which saves the open experience's state) and ends it.
@MainActor
private func suspendAndEnd(_ app: XCUIApplication) {
    XCUIDevice.shared.press(.home)
    _ = app.wait(for: .runningBackground, timeout: VC.wait)
    usleep(1_000_000)
    app.terminate()
}

/// Leaves the experience route for the catalog.
@MainActor
private func back(_ app: XCUIApplication) {
    let back = element(app, "vc.experience.back")
    waitFor(back, timeout: VC.wait)
    back.tap()
    waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
}

/// Leaves the settings route for the catalog (`vc.nav.done`, the first row of the route).
@MainActor
private func leaveSettings(_ app: XCUIApplication) {
    let done = element(app, "vc.nav.done")
    var swipes = 0
    while !(done.exists && done.isHittable), swipes < 8 {
        element(app, "vc.route.settings").swipeDown()
        swipes += 1
    }
    waitFor(done, timeout: VC.wait)
    done.tap()
    waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
}

/// The inventory text of the settings diagnostics; the settings route must be reachable from the catalog.
@MainActor
private func inventory(_ app: XCUIApplication) -> String {
    openSettings(app)
    let line = element(app, "vc.inventory")
    scrollRoute(app, "vc.route.settings", to: line)
    return line.label
}

final class PersistenceUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    // MARK: Restore (T-U05-016; SC-U05-002)

    @MainActor
    func testTapsRouteAndSearchTextComeBackAfterTheAppEnded() {
        let app = launchApp(arguments: Args.fresh)
        waitFor(element(app, "vc.route.catalog"))
        let search = element(app, "vc.search")
        waitFor(search, timeout: VC.wait)
        search.tap()
        search.typeText("a")
        openFirstFree(app)
        tap(app, 3)
        expectTaps(app, 3, "before the end")
        suspendAndEnd(app)

        let second = launchApp(arguments: Args.again)
        waitFor(element(second, "vc.route.experience"))
        waitFor(element(second, VC.canvas), timeout: VC.firstWait)
        expectTaps(second, 3, "restored after the app ended")
        XCTAssertFalse(element(second, "vc.unreadable").exists)
        back(second)
        let restored = element(second, "vc.search")
        waitFor(restored, timeout: VC.wait)
        XCTAssertEqual(restored.value as? String, "a", "the search text is restored")
    }

    /// The checkpoint five seconds after an accepted action is what survives an end without a suspension.
    @MainActor
    func testTapsComeBackWhenTheAppEndsWithoutASuspension() {
        let app = launchApp(arguments: Args.fresh)
        openFirstFree(app)
        tap(app, 2)
        expectTaps(app, 2, "before the end")
        usleep(7_000_000)   // the checkpoint follows the last accepted action by 5 seconds
        app.terminate()
        let second = launchApp(arguments: Args.again)
        waitFor(element(second, "vc.route.experience"))
        expectTaps(second, 2, "restored from the checkpoint")
    }

    @MainActor
    func testLeavingAndOpeningAgainKeepsTheTaps() {
        let app = launchApp(arguments: Args.fresh)
        openFirstFree(app)
        tap(app, 4)
        expectTaps(app, 4, "before leaving")
        back(app)
        XCTAssertTrue(waitUntilGone(element(app, VC.canvas)))
        openFirstFree(app)
        expectTaps(app, 4, "after opening again")
    }

    // MARK: Inventory (T-U05-023; FR-U05-062; SC-U05-008)

    @MainActor
    func testAfterAScriptedUseTheContainerHoldsOnlyListedItems() {
        // Open, taps, background and back, end.
        let app = launchApp(arguments: [VC.reset, VC.fixture, VC.skipWelcome, VC.seedData])
        openFirstFree(app)
        tap(app, 3)
        XCUIDevice.shared.press(.home)
        _ = app.wait(for: .runningBackground, timeout: VC.wait)
        app.activate()
        expectTaps(app, 3, "after the background")
        suspendAndEnd(app)

        // A damaged start and Reset (which leaves a quarantined copy).
        let second = launchApp(arguments: Args.again + [Args.damage, "garbage"])
        waitFor(element(second, "vc.unreadable"), timeout: VC.firstWait)
        let reset = element(second, "vc.unreadable.reset")
        scrollRoute(second, "vc.route.experience", to: reset)
        reset.tap()
        waitFor(element(second, VC.canvas), timeout: VC.firstWait)
        tap(second, 1)
        back(second)
        let filled = inventory(second)
        XCTAssertTrue(filled.hasSuffix("unlisted: none"), "after open, taps, background, end, damage, Reset: \(filled)")
        XCTAssertFalse(filled.contains(" 0 files"), filled)
        print("INVENTORY filled: \(filled)")

        // Reset of one experience, then of all.
        let fixed = ["vc.settings.reset.all", "vc.settings.reset.confirm", "vc.settings.reset.cancel"]
        // The inventory is the last row; the settings are opened again so that they start at their top.
        leaveSettings(second)
        openSettings(second)
        scrollRoute(second, "vc.route.settings", to: element(second, "vc.settings.reset.all"))
        let rows = elements(second, prefix: "vc.settings.reset.").allElementsBoundByIndex.map(\.identifier)
            .filter { !fixed.contains($0) }.sorted()
        let one = element(second, rows.first ?? "vc.settings.reset.none")
        scrollRoute(second, "vc.route.settings", to: one)
        one.tap()
        let confirm = element(second, "vc.settings.reset.confirm")
        waitFor(confirm, timeout: VC.wait)
        confirm.tap()
        XCTAssertTrue(waitUntilGone(one))
        let all = element(second, "vc.settings.reset.all")
        scrollRoute(second, "vc.route.settings", to: all)
        all.tap()
        waitFor(confirm, timeout: VC.wait)
        confirm.tap()

        // The app is as after a first start: the welcome opens the first experience again.
        let start = element(second, "vc.welcome.start")
        waitFor(start, timeout: VC.wait)
        start.tap()
        waitFor(element(second, VC.canvas), timeout: VC.firstWait)
        expectTaps(second, 0, "after the reset of all")
        tap(second, 1)
        back(second)
        let after = inventory(second)
        XCTAssertTrue(after.hasSuffix("unlisted: none"), "after the resets and a new open: \(after)")
        print("INVENTORY after resets: \(after)")
    }

    @MainActor
    func testStrayItemsAreNamedByTheInventory() {
        let app = launchApp(arguments: Args.fresh + [Args.stray])
        waitFor(element(app, "vc.route.catalog"))
        let found = inventory(app)
        XCTAssertTrue(found.contains("file:Library/Application Support/stray.txt"), found)
        XCTAssertTrue(found.contains("key:stray.key"), found)
        // The next start without the argument still names them: nothing hides an unknown item.
        let second = relaunch(app, arguments: Args.again)
        waitFor(element(second, "vc.route.settings"))
        let line = element(second, "vc.inventory")
        scrollRoute(second, "vc.route.settings", to: line)
        XCTAssertTrue(line.label.contains("key:stray.key"), line.label)
        XCTAssertTrue(line.label.contains("file:Library/Application Support/stray.txt"), line.label)
    }
}

final class PersistenceDamageUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    // MARK: Damaged states (T-U05-018; FR-U05-031, FR-U05-033)

    /// Stores a state with two taps, ends the app and starts it with the stored state damaged as `kind`.
    @MainActor
    private func startDamaged(_ kind: String, largeText: Bool = false) -> XCUIApplication {
        let app = launchApp(arguments: Args.fresh)
        openFirstFree(app)
        tap(app, 2)
        expectTaps(app, 2, "before the damage")
        suspendAndEnd(app)
        let second = launchApp(arguments: Args.again + [Args.damage, kind], largeText: largeText)
        waitFor(element(second, "vc.route.experience"))
        waitFor(element(second, "vc.unreadable"), timeout: VC.firstWait, "\(kind): the notice")
        XCTAssertFalse(element(second, VC.canvas).exists, "\(kind): nothing runs behind the notice")
        return second
    }

    @MainActor
    private func walkDamaged(_ kind: String) {
        let app = startDamaged(kind)
        let message = element(app, "vc.unreadable").label
        XCTAssertEqual(message.contains("newer version"), kind == "newer", "\(kind): \(message)")

        // Back shows the catalog and changes nothing: the same notice comes at the next open and the next start.
        let backButton = element(app, "vc.unreadable.back")
        scrollRoute(app, "vc.route.experience", to: backButton)
        backButton.tap()
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        XCTAssertFalse(element(app, "vc.unreadable").exists)
        openFirstFree(app, expectCanvas: false)
        waitFor(element(app, "vc.unreadable"), timeout: VC.wait, "\(kind): the notice again")
        let third = relaunch(app, arguments: Args.again)
        waitFor(element(third, "vc.route.experience"))
        waitFor(element(third, "vc.unreadable"), timeout: VC.firstWait, "\(kind): the notice after a further start")
        XCTAssertFalse(element(third, VC.canvas).exists)

        // Reset shows a running experience with zero taps.
        let reset = element(third, "vc.unreadable.reset")
        scrollRoute(third, "vc.route.experience", to: reset)
        reset.tap()
        waitFor(element(third, VC.canvas), timeout: VC.firstWait, "\(kind): running after Reset")
        XCTAssertTrue(waitUntilGone(element(third, "vc.unreadable")))
        expectTaps(third, 0, "\(kind): a fresh state")
    }

    @MainActor func testATruncatedStateGivesTheNoticeWithBackAndReset() { walkDamaged("truncated") }
    @MainActor func testAGarbageStateGivesTheNoticeWithBackAndReset() { walkDamaged("garbage") }
    @MainActor func testAStateOfANewerVersionGivesTheNoticeWithBackAndReset() { walkDamaged("newer") }
    @MainActor func testAStateOfAnotherExperienceGivesTheNoticeWithBackAndReset() { walkDamaged("other") }

    @MainActor
    private func auditNotice(largeText: Bool) throws {
        let app = startDamaged("garbage", largeText: largeText)
        for id in ["vc.unreadable.reset", "vc.unreadable.back"] {
            let button = element(app, id)
            scrollRoute(app, "vc.route.experience", to: button)
            XCTAssertGreaterThanOrEqual(button.frame.width, 44, "\(id) is \(button.frame.size)")
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "\(id) is \(button.frame.size)")
        }
        continueAfterFailure = true
        try audit(app, "unreadable", largeText: largeText)
    }

    @MainActor func testTheNoticePassesTheAuditAtTheDefaultTextSize() throws { try auditNotice(largeText: false) }
    @MainActor func testTheNoticePassesTheAuditAtTheLargestTextSize() throws { try auditNotice(largeText: true) }
}
