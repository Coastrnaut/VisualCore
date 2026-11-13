// FAPAdjustUITests — feature 193 (UA-F07) T-U07-022: port of the standalone app's AdjustUITests (feature 021
// T-A02-307, detail picker feature 023 T-A02-509; FR-A02-306; US3 AC1–AC3; SC-A02-305) into the one app. Every
// tuning control changes the value it shows and speaks, the edges and the simulation detail are chosen, and Reset
// tuning returns the defaults. The standalone Adjust sheet is, inside the one app, the Motion, Quality, Edges,
// Simulation detail and Tuning sections of A02's controls below the canvas, so there is no Done button: the canvas
// simply keeps running. The standalone sheet's quality-tier row ("Quality: …", fap.adjust.tier) has no counterpart,
// because the quality level comes from the session host (FluidArtPresenter difference 2), and is not ported.
import XCTest

final class FAPAdjustUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testControlsChangeAndReset() {
        let app = FAP.open()
        FAP.reveal(app, FAP.slider(app, "quality"))
        XCTAssertEqual(FAP.value(app, "quality"), "20 iterations")
        FAP.reveal(app, FAP.slider(app, "viscosity"))
        XCTAssertEqual(FAP.value(app, "viscosity"), "0.00")

        FAP.adjust(app, "viscosity", to: 0.5)
        XCTAssertTrue(FAP.waitForValue(app, "viscosity") { $0 != "0.00" }, "viscosity changed")

        FAP.adjust(app, "dyeFade", to: 0.9)
        XCTAssertTrue(FAP.waitForValue(app, "dyeFade") { $0 != "1.0 per second" }, FAP.value(app, "dyeFade"))
        XCTAssertTrue(FAP.value(app, "dyeFade").hasSuffix("per second"))

        FAP.adjust(app, "motionFade", to: 0.6)
        XCTAssertTrue(FAP.waitForValue(app, "motionFade") { $0 != "0.2 per second" }, FAP.value(app, "motionFade"))
        XCTAssertTrue(FAP.value(app, "motionFade").hasSuffix("per second"))

        // iOS 26's slider ignores a drag to exactly 0, so move near the start and check the count dropped.
        FAP.adjust(app, "quality", to: 0.05)
        _ = FAP.waitForValue(app, "quality") { $0 != "20 iterations" }
        let quality = FAP.value(app, "quality")
        let count = Int(quality.split(separator: " ").first ?? "") ?? 99
        XCTAssertLessThan(count, 20, "fewer iterations, got '\(quality)'")
        XCTAssertTrue(quality.hasSuffix(count == 1 ? "iteration" : "iterations"), quality)

        let walls = FAP.control(app, "edges.walls"), open = FAP.control(app, "edges.open")
        FAP.reveal(app, open)
        XCTAssertTrue(walls.isSelected, "Walls is the default edge")
        open.tap()
        XCTAssertTrue(FAP.waitForSelection(open), "Open is chosen")
        XCTAssertFalse(walls.isSelected)

        // The Simulation detail choices (MVP-06): Medium is the default; Low rebuilds the grid at 64 by 64.
        let low = FAP.control(app, "detail.low"), medium = FAP.control(app, "detail.medium")
        FAP.reveal(app, medium)
        XCTAssertTrue(medium.isSelected, "Medium is the default detail")
        XCTAssertEqual(medium.label, "Medium, 128 by 128 cells")
        FAP.reveal(app, low)
        low.tap()
        XCTAssertTrue(FAP.waitForSelection(low), "Low is chosen")
        let canvas = FAP.canvas(app)
        XCTAssertTrue(FAP.waitForLabel(canvas) { $0.contains("64 by 64 grid") }, canvas.label)
        FAP.reveal(app, medium)
        medium.tap()
        XCTAssertTrue(FAP.waitForSelection(medium), "Medium is chosen again")
        XCTAssertTrue(FAP.waitForLabel(canvas) { $0.contains("128 by 128 grid") }, canvas.label)

        FAP.tap(app, "tuningReset")
        XCTAssertTrue(FAP.waitForValue(app, "quality") { $0 == "20 iterations" }, FAP.value(app, "quality"))
        XCTAssertEqual(FAP.value(app, "viscosity"), "0.00")
        XCTAssertEqual(FAP.value(app, "dyeFade"), "1.0 per second")
        XCTAssertEqual(FAP.value(app, "motionFade"), "0.2 per second")
        XCTAssertTrue(FAP.waitForSelection(FAP.control(app, "edges.walls")), "Walls again after Reset tuning")
        XCTAssertTrue(medium.isSelected, "Reset tuning keeps the detail")

        // Back on the canvas, picture kept: the session still runs.
        XCTAssertTrue(FAP.canvas(app).exists)
        XCTAssertFalse(element(app, "session.failure").exists)
        FAP.attachScreenshot(app, named: "a02-adjust", to: self)
    }
}
