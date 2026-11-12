// RoutesUITests — feature 190 T-U04-008 (US3; FR-U04-030 to FR-U04-035; SC-U04-004, SC-U04-009): the four routes
// show their root at the default and the largest accessibility text size and pass the audit; a tile opens the
// experience and back returns; the last route, experience and search text come back after a termination; on a
// tablet in landscape the catalog and the content are visible together.
import UIKit
import XCTest

final class RoutesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    private static let fresh = [VC.reset, VC.fixture, VC.skipWelcome]
    private static let again = [VC.fixture, VC.skipWelcome]

    /// Opens the first free fixture experience from the catalog and waits for its canvas.
    @MainActor
    private func openFirstFree(_ app: XCUIApplication) {
        waitFor(element(app, "vc.route.catalog"))
        let free = firstTile(app, tier: "Free")
        // In a short window (a phone in landscape) the tiles start below the search field and the navigation rows.
        var swipes = 0
        while !free.waitForExistence(timeout: 2), swipes < 4 {
            scrollCatalog(app)
            swipes += 1
        }
        waitFor(free, timeout: VC.wait)
        revealAndTap(app, free)
        waitFor(element(app, "vc.route.experience"), timeout: VC.wait)
        waitFor(element(app, VC.canvas), timeout: VC.firstWait)
    }

    // MARK: The four routes at two text sizes

    @MainActor
    private func walk(route: String, largeText: Bool) throws {
        let app = launchApp(arguments: Self.fresh, largeText: largeText)
        waitFor(element(app, "vc.route.catalog"))
        switch route {
        case "catalog": waitFor(tile(app).firstMatch, timeout: VC.wait)
        case "experience": openFirstFree(app)
        case "settings": openSettings(app)
        default: openAbout(app)
        }
        waitFor(element(app, "vc.route.\(route)"), timeout: VC.wait)
        continueAfterFailure = true
        try audit(app, route, largeText: largeText)
    }

    @MainActor func testCatalogRouteAtTheDefaultTextSize() throws { try walk(route: "catalog", largeText: false) }
    @MainActor func testCatalogRouteAtTheLargestTextSize() throws { try walk(route: "catalog", largeText: true) }
    @MainActor func testExperienceRouteAtTheDefaultTextSize() throws { try walk(route: "experience", largeText: false) }
    @MainActor func testExperienceRouteAtTheLargestTextSize() throws { try walk(route: "experience", largeText: true) }
    @MainActor func testSettingsRouteAtTheDefaultTextSize() throws { try walk(route: "settings", largeText: false) }
    @MainActor func testSettingsRouteAtTheLargestTextSize() throws { try walk(route: "settings", largeText: true) }
    @MainActor func testAboutRouteAtTheDefaultTextSize() throws { try walk(route: "about", largeText: false) }
    @MainActor func testAboutRouteAtTheLargestTextSize() throws { try walk(route: "about", largeText: true) }

    // MARK: Opening and leaving an experience

    @MainActor
    func testATileOpensTheExperienceAndBackReturnsToTheCatalog() {
        let app = launchApp(arguments: Self.fresh)
        openFirstFree(app)
        let back = element(app, "vc.experience.back")
        waitFor(back, timeout: VC.wait)
        back.tap()
        XCTAssertTrue(waitUntilGone(element(app, VC.canvas)), "returning closes the experience")
        XCTAssertFalse(element(app, "vc.route.experience").exists)
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        waitFor(tile(app).firstMatch, timeout: VC.wait)
    }

    // MARK: Restoration (SC-U04-009: three cases, and the unavailable experience)

    @MainActor
    func testTheLastRouteIsRestored() {
        let app = launchApp(arguments: Self.fresh)
        waitFor(element(app, "vc.route.catalog"))
        openSettings(app)
        let second = relaunch(app, arguments: Self.again)
        waitFor(element(second, "vc.route.settings"))
        XCTAssertFalse(element(second, "vc.welcome").exists)
    }

    @MainActor
    func testTheLastExperienceIsRestored() {
        let app = launchApp(arguments: Self.fresh)
        openFirstFree(app)
        let second = relaunch(app, arguments: Self.again)
        waitFor(element(second, "vc.route.experience"))
        waitFor(element(second, VC.canvas), timeout: VC.firstWait)
    }

    @MainActor
    func testTheLastSearchTextIsRestored() {
        let app = launchApp(arguments: Self.fresh)
        waitFor(element(app, "vc.route.catalog"))
        let search = element(app, "vc.search")
        waitFor(search, timeout: VC.wait)
        search.tap()
        search.typeText("zzqqxxzz")
        waitFor(element(app, "vc.nomatch"), timeout: VC.wait)
        let second = relaunch(app, arguments: Self.again)
        waitFor(element(second, "vc.route.catalog"))
        let restored = element(second, "vc.search")
        waitFor(restored, timeout: VC.wait)
        XCTAssertEqual(restored.value as? String, "zzqqxxzz")
        waitFor(element(second, "vc.nomatch"), timeout: VC.wait)
    }

    @MainActor
    func testAnExperienceThatIsNoLongerAvailableLeadsToTheCatalog() {
        let app = launchApp(arguments: Self.fresh)
        openFirstFree(app)
        // Without the fixture the real catalog has no available experience: the stored experience cannot open.
        let second = relaunch(app, arguments: [VC.skipWelcome])
        waitFor(element(second, "vc.route.catalog"))
        waitFor(element(second, "vc.empty"), timeout: VC.wait)
        XCTAssertFalse(element(second, "vc.route.experience").exists)
        XCTAssertFalse(element(second, VC.canvas).exists)
    }

    // MARK: Failure, rotation and touch targets (T-U04-040 to T-U04-042)

    /// Edge case: an experience that fails to open shows the failure view with Retry and Back; Back leads to
    /// the catalog and the app stays usable.
    @MainActor
    func testAFailingExperienceShowsRetryAndBackAndTheAppStaysUsable() {
        let app = launchApp(arguments: Self.fresh + [VC.failingExperience])
        waitFor(element(app, "vc.route.catalog"))
        revealAndTap(app, firstTile(app, tier: "Free"))
        waitFor(element(app, "session.failure"), timeout: VC.firstWait)
        XCTAssertTrue(element(app, "vc.route.experience").exists)
        XCTAssertFalse(element(app, VC.canvas).exists)
        let retry = element(app, "session.retry")
        waitFor(retry, timeout: VC.wait)
        retry.tap()
        waitFor(element(app, "session.failure"), timeout: VC.firstWait, "a retry fails again and shows the view again")
        let back = element(app, "session.back")
        waitFor(back, timeout: VC.wait)
        back.tap()
        XCTAssertTrue(waitUntilGone(element(app, "session.failure")))
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        XCTAssertFalse(element(app, "vc.route.experience").exists)
        openSettings(app)
    }

    /// FR-U04-032, edge case rotation: a running experience survives rotations, on a phone and on a tablet.
    @MainActor
    func testARunningExperienceSurvivesRotations() {
        addTeardownBlock { @MainActor in XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp(arguments: Self.fresh)
        openFirstFree(app)
        let canvas = element(app, VC.canvas)
        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            usleep(1_500_000)
            XCTAssertTrue(element(app, "vc.route.experience").exists, "route after rotation \(orientation.rawValue)")
            XCTAssertTrue(canvas.exists, "canvas after rotation \(orientation.rawValue)")
            XCTAssertFalse(element(app, "session.failure").exists)
            XCTAssertFalse(element(app, "session.message").exists)
        }
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.height, window.width, "portrait again")
    }

    /// The buttons, switches and text fields of the app on what is shown, with their frames.
    @MainActor
    private func assertTouchTargets(_ app: XCUIApplication, _ screen: String, atLeast expected: Int,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        var checked: [String] = []
        for type in [XCUIElement.ElementType.button, .switch, .textField, .textView] {
            for item in app.descendants(matching: type).allElementsBoundByIndex {
                let id = item.identifier
                guard id.hasPrefix("vc.") || id.hasPrefix("session.") || id.hasPrefix("experience."),
                      item.exists, window.contains(item.frame) else { continue }
                let frame = item.frame
                XCTAssertGreaterThanOrEqual(frame.width, 44, "\(screen): \(id) is \(frame.size)", file: file, line: line)
                XCTAssertGreaterThanOrEqual(frame.height, 44, "\(screen): \(id) is \(frame.size)", file: file, line: line)
                checked.append(id)
            }
        }
        print("TOUCH-TARGETS \(screen): \(checked.count) controls of at least 44 by 44: \(checked)")
        XCTAssertGreaterThanOrEqual(checked.count, expected, "\(screen): \(checked)", file: file, line: line)
    }

    /// FR-U04-035: at the largest text size every control that is fully on screen is at least 44 by 44 points,
    /// on each route; the Back and Done controls of the navigation bar are among them.
    @MainActor
    func testTouchTargetsAreAtLeast44PointsAtTheLargestTextSize() {
        continueAfterFailure = true
        let app = launchApp(arguments: Self.fresh, largeText: true)
        waitFor(element(app, "vc.route.catalog"))
        assertTouchTargets(app, "catalog", atLeast: 2)
        openFirstFree(app)
        waitFor(element(app, "vc.experience.back"), timeout: VC.wait)
        assertTouchTargets(app, "experience", atLeast: 1)
        XCTAssertGreaterThanOrEqual(element(app, "vc.experience.back").frame.height, 44)
        element(app, "vc.experience.back").tap()
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        openSettings(app)
        waitFor(element(app, "vc.nav.done"), timeout: VC.wait)
        assertTouchTargets(app, "settings", atLeast: 2)
        XCTAssertGreaterThanOrEqual(element(app, "vc.nav.done").frame.height, 44)
        element(app, "vc.nav.done").tap()
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        openAbout(app)
        waitFor(element(app, "vc.nav.done"), timeout: VC.wait)
        assertTouchTargets(app, "about", atLeast: 1)
    }

    // MARK: Regular width

    @MainActor
    func testCatalogAndContentTogetherOnATabletInLandscape() {
        // Side by side is required for the tablet's regular width (FR-U04-032); a phone keeps its portrait stack here.
        if isTablet { XCUIDevice.shared.orientation = .landscapeLeft }
        let app = launchApp(arguments: Self.fresh)
        openFirstFree(app)
        if isTablet {
            let catalog = element(app, "vc.route.catalog")
            XCTAssertTrue(catalog.exists, "the catalog stays beside the content")
            let aTile = tile(app).firstMatch
            XCTAssertTrue(aTile.exists && aTile.isHittable, "a tile is still on screen beside the experience")
            let window = app.windows.firstMatch.frame
            XCTAssertGreaterThan(window.width, window.height, "landscape")
            XCTAssertTrue(window.intersects(element(app, VC.canvas).frame))
        } else {
            // On a phone the routes follow one another: the experience is shown and back leads to the catalog.
            let back = element(app, "vc.experience.back")
            waitFor(back, timeout: VC.wait)
            back.tap()
            waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
            XCTAssertTrue(waitUntilGone(element(app, VC.canvas)))
        }
    }
}
