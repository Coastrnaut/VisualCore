// RoutesUITests — feature 190 T-U04-008 (US3; FR-U04-030 to FR-U04-035; SC-U04-004, SC-U04-009): the four routes
// show their root at the default and the largest accessibility text size and pass the audit; a tile opens the
// experience and back returns; the last route, experience and search text come back after a termination; on a
// tablet in landscape the catalog and the content are visible together.
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
