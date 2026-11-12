// FirstRunUITests — feature 190 T-U04-009 (US4; FR-U04-040 to FR-U04-043; SC-U04-005): the first start shows the
// welcome and no prompt; its one action opens the first free fixture experience within two taps; the welcome is
// shown once; `-openExperience <id>` opens that experience and an unknown id shows the catalog.
import XCTest

final class FirstRunUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Alerts, sheets and sign-in fields of the app, and alerts of the system, counted together.
    @MainActor
    private func prompts(_ app: XCUIApplication) -> Int {
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        return app.alerts.count + app.sheets.count + app.secureTextFields.count + system.alerts.count
    }

    @MainActor
    func testTheWelcomeAppearsWithoutPromptAndStartsAFreeExperienceInTwoTaps() {
        let app = launchApp(arguments: [VC.reset, VC.fixture])
        var taps = 0
        waitFor(element(app, "vc.welcome"))
        XCTAssertEqual(prompts(app), 0, "no alert, sheet or sign-in at the first start")
        let start = element(app, "vc.welcome.start")
        waitFor(start, timeout: VC.wait)
        start.tap()
        taps += 1
        waitFor(element(app, VC.canvas), timeout: VC.firstWait, "a free experience runs after the welcome")
        XCTAssertLessThanOrEqual(taps, 2)
        XCTAssertTrue(element(app, "vc.route.experience").exists)
        XCTAssertFalse(element(app, "vc.welcome").exists)
        XCTAssertFalse(element(app, "vc.premium.notice").exists, "the first experience is a free one")
        XCTAssertEqual(prompts(app), 0, "no prompt on the way to the experience")
    }

    @MainActor
    func testASecondLaunchShowsNoWelcome() {
        let app = launchApp(arguments: [VC.reset, VC.fixture])
        let start = element(app, "vc.welcome.start")
        waitFor(start)
        start.tap()
        waitFor(element(app, VC.canvas), timeout: VC.firstWait)
        let second = relaunch(app, arguments: [VC.fixture])
        // The restored route is the experience that the welcome opened.
        waitFor(element(second, "vc.route.experience"))
        XCTAssertFalse(element(second, "vc.welcome").exists)
    }

    @MainActor
    func testTheWelcomeLeadsToTheLauncherWhenNothingIsAvailable() {
        let app = launchApp(arguments: [VC.reset])
        let start = element(app, "vc.welcome.start")
        waitFor(start)
        XCTAssertEqual(prompts(app), 0)
        start.tap()
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        waitFor(element(app, "vc.empty"), timeout: VC.wait)
        XCTAssertTrue(waitUntilGone(element(app, "vc.welcome")))
    }

    @MainActor
    func testOpenExperienceArgumentOpensThatExperience() {
        let first = launchApp(arguments: [VC.reset, VC.fixture, VC.skipWelcome])
        waitFor(element(first, "vc.route.catalog"))
        let free = firstTile(first, tier: "Free")
        waitFor(free, timeout: VC.wait)
        let id = String(free.identifier.dropFirst(VC.tilePrefix.count))
        XCTAssertFalse(id.isEmpty)
        first.terminate()

        let app = launchApp(arguments: [VC.reset, VC.fixture, VC.skipWelcome, VC.openExperience, id])
        waitFor(element(app, "vc.route.experience"))
        waitFor(element(app, VC.canvas), timeout: VC.firstWait)
        waitFor(element(app, "vc.exp.\(id).tap"), timeout: VC.wait, "the control of the experience \(id)")
    }

    @MainActor
    func testOpenExperienceWithAnUnknownIdShowsTheCatalog() {
        let unknown = "a99.no-such-experience"
        let app = launchApp(arguments: [VC.reset, VC.fixture, VC.skipWelcome, VC.openExperience, unknown])
        waitFor(element(app, "vc.route.catalog"))
        waitFor(tile(app).firstMatch, timeout: VC.wait)
        XCTAssertFalse(element(app, "vc.route.experience").exists)
        XCTAssertFalse(element(app, VC.canvas).exists)
    }
}
