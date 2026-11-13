// FEAccessibilityAuditUITests — feature 193 (UA-F07) T-U07-025: port of the standalone app's
// AccessibilityAuditUITests (feature 026 T-A03-105, feature 027 T-A03-208, features 028–029 T-A03-310 and T-A03-410,
// feature 031 T-A03-604; SC-A03-103; constitution A03 accessibility) into the one app. The system accessibility audit
// (`XCUIApplication.performAccessibilityAudit`) runs with A03 open, once at the default text size and once at the
// largest accessibility text size, at a scroll stop for each section of its controls: Family, View, Go to with its
// error, Iterations with the cost line, Palette with the animation toggle, Bookmarks with a saved view, and Capture
// with a made picture, then in the Julia family at the seed controls. Tours and the precision notice use the same
// text styles and are left out to keep the test short (owner rule of 2026-11-13: tests are short). The standalone home and acknowledgements screens belong to the one app now and are audited by
// LauncherUITests and SettingsUITests at both sizes.
//
// Exclusions: none of A03's own. The audit goes through the shared `audit` of AppUITestSupport, which ignores, with a
// printed line for each, exactly the documented findings of the standalone apps: the contrast of the artwork inside
// the live canvas, navigation-bar chrome, contrast of a text the scroll position cuts at the screen edge, contrast of
// a control the controls' scroll view clips (audited whole at the stop that shows it), and findings without an
// element. At the default size it leaves out the two text-size audits, as the standalone apps did.
import XCTest

final class FEAccessibilityAuditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        // Seven scroll stops, each audited, take longer than the default 3 minutes at the largest text size; each
        // audit test runs in its own chunk under the 540 s limit.
        executionTimeAllowance = 420
    }

    /// Scrolls `target` into view, lets the list come to rest and audits.
    @MainActor
    private func auditAt(_ app: XCUIApplication, _ target: XCUIElement, _ name: String, largeText: Bool) throws {
        guard FE.reveal(app, target) else { return }
        // The drags of `reveal` leave the list decelerating; the audit's screenshot must show it at rest.
        usleep(800_000)
        try audit(app, "a03 \(name)", largeText: largeText, visible: FE.visibleControls(app))
    }

    @MainActor
    private func auditA03(largeText: Bool) throws {
        let app = FE.open(largeText: largeText)
        // A saved view, a go-to error, a made picture and a stopped tour with its caption, so that every part of the
        // controls is shown.
        FE.saveBookmark(app, as: "Audit")
        guard let auditID = FE.bookmarkID(app, "Audit") else { return XCTFail("no saved view Audit") }
        FE.type(app, "goto.real", "9")
        FE.tap(app, "goto.go")
        waitFor(FE.control(app, "goto.error"), timeout: VC.wait, "the go-to error")
        FE.tap(app, "capture")
        waitFor(FE.control(app, "capture.share"), timeout: 30, "the share control after the capture")
        continueAfterFailure = true
        let stops: [(String, String)] = [
            ("mode.mandelbrot", "family"), ("goto.error", "go to"), ("cost", "iterations"), ("animate", "palette"),
            ("bookmark.rename.\(auditID)", "bookmarks"), ("capture.share", "capture"),
        ]
        for (control, name) in stops {
            try auditAt(app, FE.control(app, control), name, largeText: largeText)
        }

        // The Julia family's seed controls.
        FE.tap(app, "mode.julia")
        let seedImaginary = FE.control(app, "seed.imaginary")
        waitFor(seedImaginary, timeout: VC.wait, "the seed controls")
        try auditAt(app, seedImaginary, "julia seed", largeText: largeText)
    }

    @MainActor
    func testAuditDefaultTextSize() throws {
        try auditA03(largeText: false)
    }

    @MainActor
    func testAuditLargestAccessibilityTextSize() throws {
        try auditA03(largeText: true)
    }
}
