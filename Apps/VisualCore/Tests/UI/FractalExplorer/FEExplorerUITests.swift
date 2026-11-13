// FEExplorerUITests — feature 193 (UA-F07) T-U07-025: port of the standalone app's ExplorerUITests (feature 026
// T-A03-105, feature 027 T-A03-208; FR-A03-101, FR-A03-202, FR-A03-203, FR-A03-206; US1 AC1–AC3; SC-A03-103,
// SC-A03-204) into the one app. A03 opens in the Mandelbrot family; the family control switches to Julia, and the
// explanation, the seed line and the canvas's spoken description follow. The zoom buttons, Reset view, the palette
// choice and the palette animation change the view, and zooming in stops at the precision limit with its notice.
// The family, view, palette and animation are A03's native controls below the canvas (the standalone app had a
// segmented control, a palette menu and a precision banner over the canvas). It also opens A03 from its catalog tile
// (the standalone home's Open button and its title, LaunchSmokeUITests) and moves the view with one-finger and
// two-finger gestures on the canvas, as the standalone canvas did.
//
// Differences from the standalone test, recorded in the test map: the adapter's precision limit uses fixed constants
// (FractalCore difference 2), so there is no separate "Near precision limit" notice, no shader-precision source line
// and no limit suffix in the canvas description; the limit notice is `precision` ("Precision limit reached — zoom
// stops here") and the description's zoom stays the same once it is reached.
import XCTest

final class FEExplorerUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testModesExplanationsAndSpokenCanvas() {
        let app = FE.open()
        let mandelbrot = FE.control(app, "mode.mandelbrot"), julia = FE.control(app, "mode.julia")
        FE.reveal(app, mandelbrot)
        XCTAssertTrue(FE.waitForSelection(mandelbrot), "Mandelbrot is the first family")
        XCTAssertFalse(julia.isSelected)
        let explanation = FE.control(app, "mode.explanation")
        XCTAssertTrue(FE.waitForLabel(explanation) { $0.contains("Mandelbrot set") }, explanation.label)
        FE.expectCanvas(app, "the default Mandelbrot view") { $0 == FE.defaultMandelbrot }
        XCTAssertFalse(FE.control(app, "seed").exists, "no seed line for Mandelbrot")

        FE.tap(app, "mode.julia")
        XCTAssertTrue(FE.waitForSelection(julia), "Julia is chosen")
        XCTAssertTrue(FE.waitForLabel(explanation) { $0.contains("seed") }, explanation.label)
        FE.expectCanvas(app, "the default Julia view") { $0 == FE.defaultJulia }
        let seed = FE.control(app, "seed")
        FE.reveal(app, seed)
        XCTAssertEqual(seed.label, "Seed: −0.8 + 0.156i")

        FE.tap(app, "mode.mandelbrot")
        XCTAssertTrue(FE.waitForSelection(mandelbrot), "Mandelbrot again")
        FE.expectCanvas(app, "Mandelbrot again") { $0.hasPrefix("Mandelbrot set") }
        XCTAssertTrue(waitUntilGone(FE.control(app, "seed")), "the seed line goes with Julia")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    @MainActor
    func testZoomControlsPaletteAnimateAndPrecisionBanner() {
        let app = FE.open()
        FE.tap(app, "zoomIn")
        FE.expectCanvas(app, "zoom in doubles the zoom") { $0.hasSuffix("zoom 2×") }
        FE.tap(app, "zoomOut")
        FE.tap(app, "zoomOut")
        FE.expectCanvas(app, "zoom out halves it") { $0.hasSuffix("zoom 0.5×") }
        FE.tap(app, "resetView")
        FE.expectCanvas(app, "reset view") { $0 == FE.defaultMandelbrot }

        // Palette: Sunset is the default, Ocean becomes the chosen one.
        let sunset = FE.control(app, "palette.sunset"), ocean = FE.control(app, "palette.ocean")
        FE.reveal(app, sunset)
        XCTAssertTrue(FE.waitForSelection(sunset), "Sunset is the default palette")
        FE.reveal(app, ocean)
        ocean.tap()
        XCTAssertTrue(FE.waitForSelection(ocean), "Ocean is chosen")
        XCTAssertTrue(FE.waitForSelection(sunset, false), "Sunset is no longer chosen")

        // Animation: the toggle changes its value.
        let animate = FE.control(app, "animate")
        FE.reveal(app, animate)
        let before = animate.value as? String
        let knob = animate.switches.firstMatch
        if knob.exists, knob.isHittable {
            knob.tap()
        } else {
            // The switch sits at the trailing edge of the toggle's row; its label does not toggle it.
            animate.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        let deadline = Date().addingTimeInterval(VC.wait)
        while animate.value as? String == before, Date() < deadline { usleep(200_000) }
        XCTAssertNotEqual(animate.value as? String, before, "the animation toggle changed")

        // The precision limit, reached through the zoom button (about fifteen doublings at −0.5).
        let banner = FE.control(app, "precision")
        let zoomIn = FE.control(app, "zoomIn")
        FE.reveal(app, zoomIn)
        for _ in 0..<40 where !banner.exists {
            if !zoomIn.isHittable { FE.reveal(app, zoomIn) }
            zoomIn.tap()
            _ = banner.waitForExistence(timeout: 0.5)
        }
        XCTAssertTrue(banner.exists, "the precision notice appears")
        XCTAssertEqual(banner.label, "Precision limit reached — zoom stops here")
        usleep(500_000)
        let atLimit = FE.canvas(app).label
        XCTAssertTrue(atLimit.hasPrefix("Mandelbrot set"), atLimit)
        FE.reveal(app, zoomIn)
        zoomIn.tap()
        usleep(800_000)
        XCTAssertEqual(FE.canvas(app).label, atLimit, "zoom stops at the limit")
        XCTAssertTrue(banner.exists, "the notice stays while the limit holds")
        FE.tap(app, "resetView")
        XCTAssertTrue(waitUntilGone(banner), "reset view clears the notice")
        FE.expectCanvas(app, "reset view after the limit") { $0 == FE.defaultMandelbrot }
        FE.attachScreenshot(app, named: "a03-ocean-reset", to: self)
    }

    /// The standalone home's Open button and title are A03's catalog tile and route title.
    @MainActor
    func testOpenFromTheCatalogShowsTheDescribedCanvas() {
        let app = launchApp(arguments: [VC.reset, VC.skipWelcome, FE.candidates])
        waitFor(element(app, "vc.route.catalog"))
        let tile = element(app, VC.tilePrefix + FE.experienceID)
        _ = tile.waitForExistence(timeout: VC.wait)
        for _ in 0..<8 where !(tile.exists && tile.isHittable) { scrollCatalog(app) }
        XCTAssertTrue(tile.exists && tile.isHittable, "A03's tile in the catalog")
        tile.tap()

        waitFor(element(app, "vc.route.experience"), timeout: VC.wait)
        waitFor(FE.canvas(app), timeout: VC.firstWait)
        FE.expectCanvas(app, "spoken description") { $0 == FE.defaultMandelbrot }
        let title = app.navigationBars.matching(identifier: FE.title).firstMatch
        XCTAssertTrue(title.exists || app.staticTexts[FE.title].exists, "the experience's title")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")

        let back = element(app, "vc.experience.back")
        waitFor(back, timeout: VC.wait)
        back.tap()
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        XCTAssertTrue(waitUntilGone(FE.canvas(app)), "the canvas is gone after leaving")
    }

    /// One finger pans the view; two fingers pinching outwards zoom in (the presenter's `pan` and `pinch`).
    @MainActor
    func testDragPansAndPinchZoomsTheCanvas() {
        let app = FE.open()
        let canvas = FE.canvas(app)
        FE.expectCanvas(app, "the default view") { $0 == FE.defaultMandelbrot }

        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        FE.expectCanvas(app, "a drag moves the centre") {
            $0.hasPrefix("Mandelbrot set, centered at ") && !$0.contains("centered at −0.5 + 0i") && $0.hasSuffix("zoom 1×")
        }

        canvas.pinch(withScale: 2.5, velocity: 1)
        let deadline = Date().addingTimeInterval(VC.wait)
        while (FE.zoom(app) ?? 0) <= 1.2, Date() < deadline { usleep(200_000) }
        XCTAssertGreaterThan(FE.zoom(app) ?? 0, 1.2, "a pinch outwards zooms in: \(canvas.label)")
        XCTAssertFalse(element(app, "session.failure").exists, "the gestures end no session")
    }
}
