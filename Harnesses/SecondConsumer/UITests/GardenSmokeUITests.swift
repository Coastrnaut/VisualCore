// GardenSmokeUITests — feature 009 T-F807 (US1 AC1–AC5, US3, SC-F801; edge cases rotation and Reduce Motion).
// Real taps and drags go through XCUITest → RenderView → PointerEvents → VisualCore recognizers → GardenKit.
import XCTest

final class GardenSmokeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    @MainActor private func launch(reduceMotion: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uitestReduceMotion", reduceMotion ? "YES" : "NO"]
        app.launch()
        XCTAssertTrue(app.staticTexts["garden.diagnostics"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor private func value(_ key: String, _ app: XCUIApplication) -> Int {
        for part in app.staticTexts["garden.diagnostics"].label.split(separator: " ") where part.hasPrefix("\(key)=") {
            return Int(part.dropFirst(key.count + 1)) ?? -1
        }
        return -1
    }

    @MainActor private func eventually(_ timeout: TimeInterval, _ message: @autoclosure () -> String, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertTrue(condition(), message())
    }

    /// A point on the canvas in view points from its top-left corner.
    @MainActor private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    @MainActor func testPlantBloomHarvestAndBreeze() {
        let app = launch(reduceMotion: false)
        // AC1: plant three seeds far apart.
        for (x, y) in [(100.0, 400.0), (250.0, 400.0), (175.0, 550.0)] { point(app, x, y).tap() }
        eventually(3, "planted=3: \(app.staticTexts["garden.diagnostics"].label)") { value("planted", app) == 3 }
        // AC5 / edge: a tap 35 pt from a growing seed neither harvests nor plants (too close).
        point(app, 135, 400).tap()
        point(app, 105, 405).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(value("planted", app), 3)
        XCTAssertEqual(value("score", app), 0)
        // AC2: bloom after 4 s of growth.
        eventually(8, "blooming: \(app.staticTexts["garden.diagnostics"].label)") { value("blooming", app) == 3 }
        eventually(3, "blooms shed particles") { value("particles", app) > 0 }
        // AC3: harvest one bloom.
        let before = value("particles", app)
        point(app, 102, 398).tap()
        eventually(3, "score=1: \(app.staticTexts["garden.diagnostics"].label)") { value("score", app) == 1 }
        XCTAssertEqual(value("planted", app), 2)
        XCTAssertGreaterThan(value("particles", app), before, "harvest burst")
        // AC4: a drag blows a breeze; particles keep flowing.
        point(app, 60, 300).press(forDuration: 0.05, thenDragTo: point(app, 300, 300), withVelocity: .fast, thenHoldForDuration: 0.1)
        XCTAssertEqual(value("score", app), 1, "a drag does not harvest")
        XCTAssertGreaterThan(value("particles", app), 0)
    }

    @MainActor func testRotationKeepsTapMapping() {
        let app = launch(reduceMotion: false)
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        point(app, 200, 200).tap()
        eventually(3, "planted after rotation") { value("planted", app) == 1 }
        point(app, 210, 205).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertEqual(value("planted", app), 1, "the same spot maps to the same world point (too close / not ready)")
    }

    @MainActor func testReduceMotionHarvestHasNoBurst() {
        let app = launch(reduceMotion: true)
        point(app, 180, 450).tap()
        eventually(3, "planted") { value("planted", app) == 1 }
        eventually(8, "bloom") { value("blooming", app) == 1 }
        point(app, 182, 452).tap()
        eventually(3, "score=1") { value("score", app) == 1 }
        XCTAssertLessThan(value("particles", app), 60, "no 80-particle burst under Reduce Motion")
    }
}
