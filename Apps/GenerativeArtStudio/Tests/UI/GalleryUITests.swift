// GalleryUITests — feature 012 T-A01-111 (US1, FR-A01-101, FR-A01-112): four labelled families; each opens a live,
// described canvas without a shader error.
import XCTest

final class GalleryUITests: XCTestCase {
    static let families = [("gradient-noise", "Gradient Noise"), ("raymarched-shapes", "Raymarched Shapes"),
                           ("geometric-tiling", "Geometric Tiling"), ("particles", "Particles")]

    override func setUp() { continueAfterFailure = false }

    func testGalleryListsFourFamiliesAndEachOpensACanvas() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["gas.home.title"].waitForExistence(timeout: 10))
        for (id, title) in Self.families {
            let row = app.buttons["gas.family.\(id)"]
            XCTAssertTrue(row.waitForExistence(timeout: 5), id)
            XCTAssertEqual(row.label, title)
        }
        for (id, title) in Self.families {
            app.buttons["gas.family.\(id)"].tap()
            let canvas = app.descendants(matching: .any)["gas.scene.canvas"]
            XCTAssertTrue(canvas.waitForExistence(timeout: 10), "\(id) canvas")
            XCTAssertFalse(canvas.label.isEmpty, "\(id) canvas is described")
            XCTAssertTrue(app.staticTexts["gas.scene.title"].label == title)
            sleep(1)
            XCTAssertFalse(app.descendants(matching: .any)["gas.scene.error"].exists, "\(id) has no shader error")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "scene-\(id)"
            shot.lifetime = .keepAlways
            add(shot)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["gas.family.\(id)"].waitForExistence(timeout: 5))
        }
    }
}
