// FAPAccessibilityAuditUITests — feature 193 (UA-F07) T-U07-022: port of the standalone app's
// AccessibilityAuditUITests (feature 020 T-A02-213, paused state feature 023 T-A02-505; SC-A02-205; constitution A02
// accessibility) into the one app. The system accessibility audit (`XCUIApplication.performAccessibilityAudit`) runs
// with A02 open, once at the default text size and once at the largest accessibility text size, at a scroll stop
// for each section of its controls: Canvas, Palette, Brush, Motion, Quality, Edges, Simulation detail, Tuning and
// Capture with a made picture (the standalone playground, Adjust sheet and capture sheet), and once more with the
// simulation paused (Resume and an enabled Step). The standalone home and acknowledgements screens belong to the one
// app now and are audited by LauncherUITests and SettingsUITests at both sizes.
//
// Exclusions: none of A02's own. The audit goes through the shared `audit` of AppUITestSupport, which ignores, with
// a printed line for each, exactly the documented findings of the standalone apps: the contrast of the artwork
// inside the live canvas, navigation-bar chrome, contrast of a text the scroll position cuts at the screen edge,
// contrast of a control the controls' scroll view clips (audited whole at the stop that shows it), and findings
// without an element. At the default size it leaves out the two text-size audits, as the standalone apps did.
import XCTest

final class FAPAccessibilityAuditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        // Eleven scroll stops, each audited, take longer than the default 3 minutes at the largest text size; the
        // runs put each audit test in its own chunk under the 540 s limit.
        executionTimeAllowance = 420
    }

    /// One control of each section of A02's controls, top to bottom; the audit runs with each scrolled into view.
    private static let stops = ["splash", "palette.ink", "brush", "viscosity", "motionFade", "quality", "edges.walls",
                                "detail.high", "tuningReset", "capture.share"]

    @MainActor
    private func auditA02(largeText: Bool) throws {
        let app = FAP.open(largeText: largeText)
        // A made picture, so that the share control is audited too.
        FAP.tap(app, "capture")
        waitFor(FAP.control(app, "capture.share"), timeout: 30, "the share control after the capture")
        continueAfterFailure = true
        for stop in Self.stops {
            let target = FAP.control(app, stop)
            guard FAP.reveal(app, target) else { continue }
            // The drags of `reveal` leave the list decelerating; the audit's screenshot must show it at rest.
            usleep(800_000)
            try audit(app, "a02 \(stop)", largeText: largeText, visible: Self.visibleControls(app))
        }
        // The paused state (feature 023): Resume and an enabled Step.
        FAP.tap(app, "pause")
        let step = FAP.control(app, "step")
        XCTAssertTrue(FAP.waitForLabel(FAP.control(app, "pause")) { $0 == "Resume" }, "paused")
        if FAP.reveal(app, step) {
            usleep(800_000)
            XCTAssertTrue(step.isEnabled, "Step is enabled while paused")
            try audit(app, "a02 paused", largeText: largeText, visible: Self.visibleControls(app))
        }
    }

    /// The part of the controls a person sees: the list's frame, above the home indicator when the list reaches
    /// the bottom of the window (the indicator overlays the last 34 points of an iPhone without a home button).
    @MainActor
    private static func visibleControls(_ app: XCUIApplication) -> CGRect {
        var frame = FAP.controlsList(app).frame
        let window = app.windows.firstMatch.frame
        if !isTablet, frame.maxY >= window.maxY - 1 { frame.size.height = max(0, frame.height - 34) }
        return frame
    }

    @MainActor
    func testAuditDefaultTextSize() throws {
        try auditA02(largeText: false)
    }

    @MainActor
    func testAuditLargestAccessibilityTextSize() throws {
        try auditA02(largeText: true)
    }
}
