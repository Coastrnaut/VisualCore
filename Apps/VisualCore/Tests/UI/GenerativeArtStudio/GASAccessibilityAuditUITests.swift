// GASAccessibilityAuditUITests — feature 193 (UA-F07) T-U07-015: port of the standalone app's
// AccessibilityAuditUITests (feature 016 T-A01-507; FR-A01-503, FR-A01-504; SC-A01-503) into the one app. The system
// accessibility audit (`XCUIApplication.performAccessibilityAudit`) runs with A01 open, once at the default text
// size and once at the largest accessibility text size, at every part of its controls: the families (the
// standalone gallery), time, presets and palettes, seed, parameters, the library with a saved entry and export with
// a made image (the standalone library and export screens). The standalone settings and acknowledgements screens
// belong to the one app now and are audited by SettingsUITests at both sizes. The canvas description follows the
// composition and the play state.
//
// Exclusions: none of A01's own. The audit goes through the shared `audit` of AppUITestSupport, which ignores, with
// a printed line for each, exactly the documented findings of the standalone apps: the contrast of the artwork
// inside the live canvas (generated pixels, not text), navigation-bar chrome (sized and styled by iOS, which offers
// the Large Content Viewer instead), contrast of a text the scroll position cuts at the screen edge (audited whole
// at another scroll position), contrast of a control the controls' scroll view clips (measured on the canvas drawn
// over it; audited whole at the stop that shows it; added 2026-11-13 after the first run), and findings without an
// element. At the default size it leaves out the two
// text-size audits, which only predict at that size what the run at the largest size checks on the real rendering.
import XCTest

final class GASAccessibilityAuditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        // Nine scroll stops, each audited, take longer than the default 3 minutes at the largest text size; the
        // runs put each audit test in its own chunk under the 540 s limit.
        executionTimeAllowance = 420
    }

    /// One control of each part of A01's controls, top to bottom; the audit runs with each scrolled into view.
    private static let stops = ["family.gradient-noise", "time.playPause", "preset.particles-burst", "palette.mono",
                                "seed.shuffle", "parameter.count", "resetAll", "library.name", "export.share"]

    @MainActor
    private func auditA01(largeText: Bool) throws {
        let app = GAS.open(largeText: largeText)
        // A saved entry and a made image, so that the library row and the share control are audited too.
        GAS.save(app, as: "Audit")
        GAS.tap(app, "export.make")
        waitFor(GAS.control(app, "export.share"), timeout: 30, "the share control after the image was made")
        continueAfterFailure = true
        for stop in Self.stops {
            let target = GAS.control(app, stop)
            guard GAS.reveal(app, target) else { continue }
            // The drags of `reveal` leave the list decelerating; the audit's screenshot must show it at rest, or a
            // text is measured where it was a moment before (seen 2026-11-13: "Seed", black on white, failed).
            usleep(800_000)
            try audit(app, "a01 \(stop)", largeText: largeText, visible: Self.visibleControls(app))
        }
    }

    /// The part of the controls a person sees: the list's frame, above the home indicator when the list reaches
    /// the bottom of the window (the indicator overlays the last 34 points of an iPhone without a home button).
    @MainActor
    private static func visibleControls(_ app: XCUIApplication) -> CGRect {
        var frame = GAS.controlsList(app).frame
        let window = app.windows.firstMatch.frame
        if !isTablet, frame.maxY >= window.maxY - 1 { frame.size.height = max(0, frame.height - 34) }
        return frame
    }

    @MainActor
    func testAuditAtDefaultTextSize() throws {
        try auditA01(largeText: false)
    }

    @MainActor
    func testAuditAtLargestAccessibilityTextSize() throws {
        try auditA01(largeText: true)
    }

    // FR-A01-503: the canvas description follows the composition and the play state.
    @MainActor
    func testCanvasDescriptionFollowsEdits() {
        let app = GAS.open()
        let canvas = GAS.canvas(app)
        let fresh = "Particles, Fountain preset, Ember palette, seed 5, playing."
        XCTAssertTrue(GAS.waitForLabel(canvas) { $0 == fresh }, "a fresh start: \(canvas.label)")

        GAS.tap(app, "family.gradient-noise")
        let switched = GAS.waitForLabel(canvas) { $0.hasPrefix("Gradient Noise, ") }
        XCTAssertTrue(switched, canvas.label)
        XCTAssertTrue(canvas.label.contains("Dusk preset, Sunset palette, seed 7"), canvas.label)
        XCTAssertTrue(canvas.label.hasSuffix("playing."), canvas.label)

        GAS.tap(app, "time.playPause")
        GAS.tap(app, "palette.neon")
        let edited = GAS.waitForLabel(canvas) { $0.contains("Neon palette") && $0.hasSuffix("paused.") }
        XCTAssertTrue(edited, canvas.label)
        XCTAssertTrue(canvas.label.contains("Neon palette"), canvas.label)
        XCTAssertTrue(canvas.label.contains("custom preset"), canvas.label)
        XCTAssertTrue(canvas.label.hasSuffix("paused."), canvas.label)
    }
}
