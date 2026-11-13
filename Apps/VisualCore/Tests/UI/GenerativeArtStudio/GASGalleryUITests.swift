// GASGalleryUITests — feature 193 (UA-F07) T-U07-015: port of the standalone app's GalleryUITests (feature 012
// T-A01-111; FR-A01-101, FR-A01-112) into the one app. The standalone gallery of four labelled families is, inside
// the one app, the `family` control of A01: each of the four is labelled with its title, and choosing it shows a
// live, described canvas of that family without a failure (a shader that does not compile ends the session in its
// failure view, `session.failure`, where the standalone app showed `gas.scene.error`).
import XCTest

final class GASGalleryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testGalleryListsFourFamiliesAndEachOpensACanvas() {
        let app = GAS.open()
        // The route carries the experience's title, where the standalone gallery had its home title.
        let title = app.navigationBars.matching(identifier: "Generative Art Studio").firstMatch
        XCTAssertTrue(title.exists || app.staticTexts["Generative Art Studio"].exists, "the experience's title")
        for (id, name) in GAS.families {
            let choice = GAS.control(app, "family.\(id)")
            waitFor(choice, timeout: VC.wait, id)
            XCTAssertEqual(choice.label, name)
        }
        for (id, name) in GAS.families {
            let choice = GAS.control(app, "family.\(id)")
            GAS.reveal(app, choice)
            choice.tap()
            GAS.expectFamily(app, name)
            let deadline = Date().addingTimeInterval(VC.wait)
            while !choice.isSelected, Date() < deadline { usleep(200_000) }
            XCTAssertTrue(choice.isSelected, "\(id) is the chosen family")
            let canvas = GAS.canvas(app)
            XCTAssertTrue(canvas.exists, "\(id) canvas")
            XCTAssertFalse(canvas.label.isEmpty, "\(id) canvas is described")
            sleep(1)
            XCTAssertFalse(element(app, "session.failure").exists, "\(id) draws without a failure")
            XCTAssertTrue(GAS.canvas(app).exists, "\(id) still runs after a second")
            GAS.attachScreenshot(app, named: "a01-family-\(id)", to: self)
        }
    }
}
