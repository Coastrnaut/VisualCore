// FAPPlaygroundUITests — feature 193 (UA-F07) T-U07-022: port of the standalone app's PlaygroundUITests (feature 019
// T-A02-113, feature 020 T-A02-213; FR-A02-106, FR-A02-208; US3 AC1) into the one app. The standalone home's Open
// button is A02's tile in the one app's catalog: it opens the experience route with a live canvas whose spoken
// description is `FluidCanvasDescription.text` ("Dye pattern …, 128 by 128 grid, …"), and the route's back control
// closes it and returns to the catalog. The splash control works without a gesture and is counted in the
// description; a swipe on the canvas (a stroke) leaves the app responsive. The standalone splash label "Add splash"
// is A02's "Splash" control. A two-finger pinch on the canvas resizes the brush, as the standalone canvas did.
import XCTest

final class FAPPlaygroundUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testOpenPlaygroundShowsDescribedCanvas() {
        // From the catalog, as the standalone test went from its home screen.
        let app = launchApp(arguments: [VC.reset, VC.skipWelcome, FAP.candidates])
        waitFor(element(app, "vc.route.catalog"))
        let tile = element(app, VC.tilePrefix + FAP.experienceID)
        _ = tile.waitForExistence(timeout: VC.wait)
        for _ in 0..<8 where !(tile.exists && tile.isHittable) { scrollCatalog(app) }
        XCTAssertTrue(tile.exists && tile.isHittable, "A02's tile in the catalog")
        tile.tap()

        waitFor(element(app, "vc.route.experience"), timeout: VC.wait)
        let canvas = FAP.canvas(app)
        waitFor(canvas, timeout: VC.firstWait)
        XCTAssertTrue(FAP.waitForLabel(canvas) { $0.hasPrefix("Dye pattern") }, "spoken description: \(canvas.label)")
        XCTAssertTrue(canvas.label.contains("128 by 128 grid"), canvas.label)
        XCTAssertTrue(canvas.label.contains("glowing dye palette"), canvas.label)
        let title = app.navigationBars.matching(identifier: FAP.title).firstMatch
        XCTAssertTrue(title.exists || app.staticTexts[FAP.title].exists, "the experience's title")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")

        // Back to the catalog closes the canvas and its render host.
        let back = element(app, "vc.experience.back")
        waitFor(back, timeout: VC.wait)
        back.tap()
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        XCTAssertTrue(waitUntilGone(FAP.canvas(app)), "the canvas is gone after leaving")
    }

    /// The splash control works without a gesture, and a swipe on the canvas keeps the app responsive.
    @MainActor
    func testSplashControlAndSwipe() {
        let app = FAP.open()
        let canvas = FAP.canvas(app)
        let splash = FAP.control(app, "splash")
        FAP.reveal(app, splash)
        XCTAssertEqual(splash.label, "Splash")
        XCTAssertGreaterThanOrEqual(splash.frame.height, 44)
        splash.tap()
        XCTAssertTrue(FAP.waitForLabel(canvas) { $0.contains("1 splash added") }, "got '\(canvas.label)'")

        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.4)))
        canvas.swipeLeft()
        XCTAssertFalse(element(app, "session.failure").exists, "the strokes end no session")

        FAP.reveal(app, splash)
        XCTAssertTrue(splash.isHittable, "the app stays responsive after a swipe")
        splash.tap()
        XCTAssertTrue(FAP.waitForLabel(canvas) { $0.contains("2 splashes added") }, "got '\(canvas.label)'")
        FAP.attachScreenshot(app, named: "a02-splash-swipe", to: self)
    }

    /// A two-finger pinch on the canvas resizes the brush (the presenter's `PinchRecognizer`); the brush slider
    /// speaks the new size.
    @MainActor
    func testPinchOnTheCanvasResizesTheBrush() {
        let app = FAP.open()
        let brush = FAP.slider(app, "brush")
        FAP.reveal(app, brush)
        XCTAssertEqual(FAP.value(app, "brush"), FAP.defaultBrush)
        FAP.canvas(app).pinch(withScale: 2.5, velocity: 1)
        XCTAssertTrue(FAP.waitForValue(app, "brush") { $0 != FAP.defaultBrush && $0.hasSuffix("% of the canvas") },
                      "the pinch made the brush larger: \(FAP.value(app, "brush"))")
        let grown = Int(FAP.value(app, "brush").split(separator: "%").first ?? "") ?? 0
        XCTAssertGreaterThan(grown, 4, "a pinch outwards grows the brush")
        XCTAssertFalse(element(app, "session.failure").exists)
    }
}
