// SettingsUITests — feature 190 T-U04-010 (US5; FR-U04-050 to FR-U04-054; SC-U04-006): the two accessibility
// choices and the quality override survive a relaunch; the reset of all data asks first and then leads back to
// the welcome; the privacy statement says what it must; the about route shows name, version and the
// acknowledgements; settings and about pass the accessibility audit at both text sizes.
import XCTest

final class SettingsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private static let fresh = [VC.reset, VC.fixture, VC.skipWelcome]

    /// Opens a picker menu and taps the option that `predicate` selects, then waits until the value changed.
    @MainActor
    private func choose(_ app: XCUIApplication, _ picker: XCUIElement, option predicate: NSPredicate) {
        let before = picker.value as? String
        for _ in 0..<5 where !picker.isHittable { app.swipeUp() }
        picker.tap()
        let option = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "no option for \(predicate) in \(picker.identifier)")
        option.tap()
        let deadline = Date().addingTimeInterval(5)
        while (picker.value as? String) == before, Date() < deadline { usleep(200_000) }
    }

    @MainActor
    func testTheThreeSettingsSurviveARelaunch() {
        let app = launchApp(arguments: Self.fresh)
        waitFor(element(app, "vc.route.catalog"))
        openSettings(app)
        let motion = element(app, "vc.settings.reduceMotion")
        let flashing = element(app, "vc.settings.reduceFlashing")
        let quality = element(app, "vc.settings.quality")
        waitFor(motion, timeout: VC.wait)
        waitFor(flashing, timeout: VC.wait)
        waitFor(quality, timeout: VC.wait)
        XCTAssertEqual(motion.value as? String, "System")
        XCTAssertEqual(flashing.value as? String, "System")
        let automatic = quality.value as? String

        choose(app, motion, option: NSPredicate(format: "label BEGINSWITH %@", "On"))
        choose(app, flashing, option: NSPredicate(format: "label BEGINSWITH %@", "Off"))
        choose(app, quality, option: NSPredicate(format: "label CONTAINS %@", "3"))
        XCTAssertEqual(motion.value as? String, "On")
        XCTAssertEqual(flashing.value as? String, "Off")
        let chosen = quality.value as? String
        XCTAssertNotNil(chosen)
        XCTAssertNotEqual(chosen, automatic, "the quality override changed from automatic")
        XCTAssertTrue(chosen?.contains("3") ?? false, "tier 3 is shown: \(chosen ?? "nil")")

        // The settings route is the last route, so the second launch shows it again.
        let second = relaunch(app, arguments: [VC.fixture, VC.skipWelcome])
        if !element(second, "vc.route.settings").waitForExistence(timeout: VC.firstWait) { openSettings(second) }
        waitFor(element(second, "vc.settings.reduceMotion"), timeout: VC.wait)
        XCTAssertEqual(element(second, "vc.settings.reduceMotion").value as? String, "On")
        XCTAssertEqual(element(second, "vc.settings.reduceFlashing").value as? String, "Off")
        XCTAssertEqual(element(second, "vc.settings.quality").value as? String, chosen)
    }

    @MainActor
    func testResetOfAllDataAsksFirstAndThenShowsTheWelcomeAgain() {
        // No skip argument here: the welcome is finished by hand, so that its return is the reset's doing.
        let app = launchApp(arguments: [VC.reset, VC.fixture])
        let start = element(app, "vc.welcome.start")
        waitFor(start)
        start.tap()
        waitFor(element(app, VC.canvas), timeout: VC.firstWait)
        element(app, "vc.experience.back").tap()
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        XCTAssertTrue(waitUntilGone(element(app, "vc.welcome")))
        openSettings(app)

        revealAndTap(app, element(app, "vc.settings.reset.all"))
        let confirm = element(app, "vc.settings.reset.confirm")
        waitFor(confirm, timeout: VC.wait, "the reset asks for a confirmation")
        XCTAssertFalse(element(app, "vc.welcome").exists, "nothing is reset before the confirmation")
        confirm.tap()
        waitFor(element(app, "vc.welcome"), timeout: VC.wait, "after the reset the app is as after a first start")
        waitFor(element(app, "vc.welcome.start"), timeout: VC.wait)
    }

    @MainActor
    func testThePrivacyStatementSaysNoCollectionNoNetworkNoAdvertising() {
        let app = launchApp(arguments: Self.fresh)
        waitFor(element(app, "vc.route.catalog"))
        openSettings(app)
        let privacy = element(app, "vc.settings.privacy")
        waitFor(privacy, timeout: VC.wait)
        for _ in 0..<5 where !privacy.isHittable { app.swipeUp() }
        let statement = text(app, of: "vc.settings.privacy").lowercased()
        for word in ["collect", "network", "advertising"] {
            XCTAssertTrue(statement.contains(word), "the privacy statement lacks '\(word)': \(statement)")
        }
    }

    @MainActor
    func testAboutShowsNameVersionAndAcknowledgements() {
        let app = launchApp(arguments: Self.fresh)
        waitFor(element(app, "vc.route.catalog"))
        openAbout(app)
        let name = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "VisualCore")).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: VC.wait), "the app's name")
        let version = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", ".*[0-9]+\\.[0-9]+.*")).firstMatch
        XCTAssertTrue(version.exists, "the app's version")
        let acknowledgements = element(app, "vc.about.acknowledgements")
        waitFor(acknowledgements, timeout: VC.wait)
    }

    @MainActor
    private func auditSettingsAndAbout(largeText: Bool) throws {
        continueAfterFailure = true
        let app = launchApp(arguments: Self.fresh, largeText: largeText)
        waitFor(element(app, "vc.route.catalog"))
        openSettings(app)
        try audit(app, "settings", largeText: largeText)
        let second = relaunch(app, arguments: Self.fresh, largeText: largeText)
        waitFor(element(second, "vc.route.catalog"))
        openAbout(second)
        try audit(second, "about", largeText: largeText)
    }

    @MainActor
    func testAuditOfSettingsAndAboutAtTheDefaultTextSize() throws { try auditSettingsAndAbout(largeText: false) }

    @MainActor
    func testAuditOfSettingsAndAboutAtTheLargestTextSize() throws { try auditSettingsAndAbout(largeText: true) }
}
