// PUAccessibilityAuditUITests — feature 193 (UA-F07) T-U07-028: port of the standalone app's
// AccessibilityAuditUITests (feature 033 T-A04-107; SC-A04-106; constitution A04 accessibility) into the one app. The
// system accessibility audit (`XCUIApplication.performAccessibilityAudit`) runs with A04 open, once at the default
// text size and once at the largest accessibility text size, at a scroll stop for each section of its controls:
// Playback with the live count, Emitters with two emitters, Family, Particles (size and lifetime), the gradients,
// Force with a placed force, and Look with trails on (the trail strength) and the blend. The scene is paused first, as
// the standalone audit started paused, so that no text changes while the audit samples the screen. The standalone
// home and acknowledgements screens belong to the one app now and are audited by LauncherUITests and SettingsUITests
// at both sizes.
//
// Exclusions: none of A04's own. The audit goes through the shared `audit` of AppUITestSupport, which ignores, with a
// printed line for each, exactly the documented findings of the standalone apps: the contrast of the particles inside
// the live canvas, navigation-bar chrome, contrast of a text the scroll position cuts at the screen edge, contrast of
// a control the controls' scroll view clips (audited whole at the stop that shows it), and findings without an
// element. At the default size it leaves out the two text-size audits, as the standalone apps did.
import XCTest

final class PUAccessibilityAuditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        // Seven scroll stops, each audited, take longer than the default 3 minutes at the largest text size; each
        // audit test runs in its own chunk under the 540 s limit.
        executionTimeAllowance = 420
    }

    /// Scrolls `target` into view, lets the list come to rest and audits.
    @MainActor
    private func auditAt(_ app: XCUIApplication, _ target: XCUIElement, _ name: String, largeText: Bool) throws {
        guard PU.reveal(app, target) else { return }
        // The drags of `reveal` leave the list decelerating; the audit's screenshot must show it at rest.
        usleep(800_000)
        try audit(app, "a04 \(name)", largeText: largeText, visible: PU.visibleControls(app))
    }

    @MainActor
    private func auditA04(largeText: Bool) throws {
        let app = PU.open(largeText: largeText)
        // Paused, two emitters, a placed force and trails on, so that every part of the controls is shown.
        PU.tap(app, "play")
        XCTAssertTrue(PU.waitForLabel(PU.control(app, "play")) { $0 == "Play" }, "paused for a stable screen")
        PU.tap(app, "emitter.add")
        waitFor(PU.control(app, "emitter.1"), timeout: VC.wait, "the second emitter")
        PU.tap(app, "force.center")
        XCTAssertTrue(PU.waitForForce(app) { $0 != nil }, "a placed force")
        PU.flip(app, "trails")
        waitFor(PU.slider(app, "trailStrength"), timeout: VC.wait, "the trail strength")
        continueAfterFailure = true
        let stops: [(String, String)] = [
            ("play", "playback"), ("emitter.add", "emitters"), ("family.firework", "family"), ("lifetime", "particles"),
            ("gradient.ember", "gradients"), ("force.center", "force"), ("blend", "look"),
        ]
        for (control, name) in stops {
            try auditAt(app, PU.control(app, control), name, largeText: largeText)
        }
    }

    @MainActor
    func testAuditDefaultTextSize() throws {
        try auditA04(largeText: false)
    }

    @MainActor
    func testAuditLargestAccessibilityTextSize() throws {
        try auditA04(largeText: true)
    }
}
