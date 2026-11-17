// IAExploreUITests — feature 129 (A17-P06) T-A17-608 (clarification Q4; FR-A17-607): the structure list, the "About
// this model" row and the layer toggles of Interactive Anatomy (A17) inside the one app. A fresh start (erased data)
// shows every layer and selects nothing. Choosing Femur (`structure-0`) selects it, and the panel shows "Femur", a
// citation (Gray's "Anatomy of the Human Body") and "Not reviewed by a clinician."; the About row is valued with the
// model statement; switching off the bones layer marks the Femur row "Hidden" and disables it. One journey per test,
// well under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class IAExploreUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Femur chosen from the list: it is selected, and the panel names it, cites its source and gives the review line.
    @MainActor
    func testChoosingFemurShowsItsPanel() {
        let app = IA.open()

        let femur = IA.row(app, IA.femurIndex)
        XCTAssertTrue(femur.label.hasPrefix("Femur"), "structure-\(IA.femurIndex) is Femur (now \(femur.label))")
        XCTAssertTrue(IA.select(app, IA.femurIndex), "Femur is selected")

        XCTAssertTrue(IA.waitForPanel(app) { $0.contains("Femur") },
                      "the panel names Femur (now \(IA.panelText(app)))")
        let text = IA.panelText(app)
        XCTAssertTrue(text.contains(IA.citationFragment), "the panel cites \(IA.citationFragment) (now \(text))")
        XCTAssertTrue(text.contains(IA.notReviewed), "the panel says \(IA.notReviewed) (now \(text))")
        XCTAssertTrue(IA.waitForLabel(IA.canvas(app)) { $0.contains("selected: Femur") },
                      "the canvas description names Femur (now \(IA.description(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The "About this model" row is valued with the model statement.
    @MainActor
    func testAboutRowShowsTheModelStatement() {
        let app = IA.open()

        let about = IA.control(app, "about-model")
        waitFor(about, timeout: IA.shortWait, "the About this model row is there")
        XCTAssertEqual(about.label, "About this model", "the row is spoken as About this model")
        XCTAssertTrue(IA.waitForValue(about) { $0 == IA.modelStatement },
                      "the row gives the model statement (now \(IA.value(app, "about-model")))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Bones switched off: the toggle says Hidden, and the Femur row says Hidden and cannot be chosen.
    @MainActor
    func testSwitchingOffBonesMarksTheFemurRowHidden() {
        let app = IA.open()

        let bones = IA.control(app, "layer-bones")
        waitFor(bones, timeout: IA.shortWait, "the Bones toggle is there")
        XCTAssertEqual(IA.value(app, "layer-bones"), "Shown", "a fresh start shows the bones")
        XCTAssertTrue(IA.flip(app, "layer-bones"), "the Bones toggle is flipped")
        XCTAssertTrue(IA.waitForValue(bones) { $0 == "Hidden" },
                      "the Bones toggle says Hidden (now \(IA.value(app, "layer-bones")))")

        let femur = IA.row(app, IA.femurIndex)
        XCTAssertTrue(IA.waitForValue(femur) { $0 == "Hidden" },
                      "the Femur row says Hidden (now \(IA.value(app, "structure-\(IA.femurIndex)")))")
        XCTAssertFalse(femur.isEnabled, "the Femur row is disabled")
        XCTAssertTrue(IA.waitForLabel(IA.canvas(app)) { !$0.contains("bones") },
                      "the canvas description no longer names the bones (now \(IA.description(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
