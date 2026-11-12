// LaunchUITests — feature 190 T-U04-001, T-U04-035: the app launches to its first screen. The test erases the app's
// data first, so that it does not depend on what an earlier test left: a first start shows the welcome.
import XCTest

final class LaunchUITests: XCTestCase {
    @MainActor
    func testAFirstLaunchShowsTheWelcome() {
        let app = launchApp(arguments: [VC.reset])
        waitFor(element(app, "vc.welcome"))
        waitFor(element(app, "vc.welcome.start"), timeout: VC.wait)
        XCTAssertFalse(element(app, "vc.route.experience").exists)
    }
}
