// MEExploreUITests — feature 115 (A15-P06) T-A15-609 (clarification Q4): choosing a molecule from the Library, the
// display-mode switch and the atom step of Molecular Explorer (A15) inside the one app. On a fresh start (erased data)
// a library molecule is open in ball and stick with no atom selected. Tapping the Benzene Library button
// (`library-benzene`) makes the status line name Benzene ("Benzene selected, molecule 4 of 5"); switching Display to
// Space filling makes the legend start "Space filling" and the canvas description name the mode; Next atom with no
// selection selects the first atom, so the atom panel names atom 1 ("Oxygen (O), atom 1 of 3", the first line of
// `MoleculePresenter.atomPanel`). One journey per test, well under 60 s. The Import button is never tapped. System
// accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class MEExploreUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The Benzene Library button opens benzene; the status line names it.
    @MainActor
    func testLibraryOpensBenzene() {
        let app = ME.open()

        XCTAssertTrue(ME.chooseFromLibrary(app, id: "benzene", title: "Benzene"), "the Library opens Benzene")
        XCTAssertEqual(ME.value(app, "status"), "Benzene selected, molecule 4 of 5", "the status line")
        XCTAssertTrue(ME.waitForLabel(ME.canvas(app)) { $0.hasPrefix(ME.describedPrefix + "Benzene") },
                      "the canvas description names Benzene (now \(ME.description(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The Display picker switches to Space filling; the legend and the canvas description say so.
    @MainActor
    func testDisplayModeSpaceFilling() {
        let app = ME.open()

        let legend = ME.control(app, "legend")
        waitFor(legend, timeout: ME.shortWait, "the legend is there")
        XCTAssertTrue(ME.waitForValue(legend) { $0.hasPrefix("Ball and stick") },
                      "a fresh start is ball and stick (now \(ME.value(app, "legend")))")

        XCTAssertTrue(ME.chooseSegment(app, picker: "display-mode", "Space filling"),
                      "the Display picker offers Space filling")
        XCTAssertTrue(ME.waitForValue(legend) { $0.hasPrefix("Space filling") },
                      "the legend starts Space filling (now \(ME.value(app, "legend")))")
        XCTAssertTrue(ME.waitForValue(ME.control(app, "display-mode")) { $0.hasPrefix("Space filling") },
                      "the picker's value names Space filling (now \(ME.value(app, "display-mode")))")
        XCTAssertTrue(ME.waitForLabel(ME.canvas(app)) { $0.contains("; space-filling") },
                      "the canvas description names the mode (now \(ME.description(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Next atom with no selection selects atom 1; the atom panel and the button's value name it.
    @MainActor
    func testNextAtomSelectsAtomOne() {
        let app = ME.open()

        let panel = ME.control(app, "atom-panel")
        waitFor(panel, timeout: ME.shortWait, "the atom panel is there")
        XCTAssertTrue(ME.waitForValue(panel) { $0 == "No atom selected" },
                      "a fresh start selects no atom (now \(ME.value(app, "atom-panel")))")

        ME.tap(app, "next-atom")
        XCTAssertTrue(ME.waitForValue(panel) { $0.contains(", atom 1 of ") },
                      "the atom panel names atom 1 (now \(ME.value(app, "atom-panel")))")
        XCTAssertTrue(ME.waitForValue(ME.control(app, "next-atom")) { $0.contains(", atom 1 of ") },
                      "Next atom's value names atom 1 (now \(ME.value(app, "next-atom")))")
        XCTAssertTrue(ME.waitForLabel(ME.canvas(app)) { $0.contains(", atom 1.") },
                      "the canvas description names the selected atom (now \(ME.description(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
