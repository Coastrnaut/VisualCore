// IGControlsUITests — feature 045 (A05-P06) T-A05-610 (US4 scenarios 1 and 2; FR-A05-630, FR-A05-632): Infinite
// Geometry opens with a described canvas; choosing the 3D composition, raising its symmetry order and using the camera
// buttons each show in the canvas description or the camera summary; Reset view restores the preset's camera. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class IGControlsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// A fresh start opens A05 with its canvas and description, and the experience's title (US4 scenario 1).
    @MainActor
    func testOpenShowsTheDescribedCanvas() {
        let app = IG.open()
        XCTAssertTrue(IG.description(app).hasPrefix(IG.describedPrefix + "Square tiling, square lattice symmetry p4m, "),
                      "the first preset is described: \(IG.description(app))")
        XCTAssertTrue(IG.waitForSelection(IG.control(app, "preset.0")), "the first preset is chosen")
        let title = app.navigationBars.matching(identifier: IG.title).firstMatch
        XCTAssertTrue(title.exists || app.staticTexts[IG.title].exists, "the experience's title")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The preset and the symmetry order change the description (US4 scenario 2).
    @MainActor
    func testPresetAndSymmetryOrderChangeTheDescription() {
        let app = IG.open()
        IG.choosePreset(app, IG.solidPreset, kind: "3D composition")
        XCTAssertTrue(IG.description(app).contains("6-fold rotational symmetry"), IG.description(app))
        XCTAssertTrue(IG.description(app).hasSuffix("field of view 60°."), IG.description(app))
        XCTAssertTrue(IG.waitForSelection(IG.control(app, "preset.\(IG.solidPreset)")), "the 3D composition is chosen")

        IG.step(app, "symmetry.order", up: true)
        XCTAssertTrue(IG.waitForDescription(app) { $0.contains("7-fold rotational symmetry") },
                      "the order is raised: \(IG.description(app))")
        XCTAssertEqual(IG.control(app, "symmetry.order").value as? String, "7-fold")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Zoom, orbit and "Wider" move the camera; Reset view restores it (US4 scenario 2).
    @MainActor
    func testCameraButtonsAndReset() {
        let app = IG.open()
        IG.choosePreset(app, IG.solidPreset, kind: "3D composition")
        let summary = IG.control(app, "camera.summary")
        IG.reveal(app, summary)
        let initial = summary.label
        XCTAssertTrue(initial.hasPrefix("Pitch "), "the camera summary: \(initial)")

        IG.tap(app, "camera.zoom.in")
        if !IG.waitForLabel(summary, timeout: 3, { $0 != initial }) { IG.tap(app, "camera.zoom.out") }
        XCTAssertTrue(IG.waitForLabel(summary) { $0 != initial }, "zoom moves the camera: \(summary.label)")

        let zoomed = summary.label
        IG.tap(app, "camera.orbit.up")
        XCTAssertTrue(IG.waitForLabel(summary) { $0 != zoomed }, "orbit moves the camera: \(summary.label)")

        IG.tap(app, "camera.fov.wider")
        XCTAssertTrue(IG.waitForDescription(app) { $0.hasSuffix("field of view 65°.") },
                      "Wider widens the field of view: \(IG.description(app))")

        IG.tap(app, "camera.reset")
        XCTAssertTrue(IG.waitForLabel(summary) { $0 == initial }, "Reset view restores the camera: \(summary.label)")
        XCTAssertTrue(IG.waitForDescription(app) { $0.hasSuffix("field of view 60°.") }, IG.description(app))
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
