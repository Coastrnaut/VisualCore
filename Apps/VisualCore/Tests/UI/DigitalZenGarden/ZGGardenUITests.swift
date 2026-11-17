// ZGGardenUITests — feature 149 (A20-P05) T-A20-505 (FR-A20-504; SC-A20-502): the garden of Digital Zen Garden (A20)
// inside the one app. A fresh start (erased data) opens A20 with an empty garden ("…, 0 strokes, 0 stones, No stone
// selected"). The first journey rakes the rows pattern (`pattern-rows`): the canvas description (`GardenPresenter.
// describe`) names one stroke; Undo (`undo`) takes it back and the description names 0 strokes. The second journey
// switches to the Stones tool (`tool`), keeps River pebble as the kind (`stone-kind`), taps Place (`stone-place`):
// the description names one stone and the selection (`selection`) reads "River pebble selected, 1 of 1, …"; Remove
// (`stone-remove`) leaves 0 stones and no selection; Undo restores the pebble: the description names one stone again.
// Short bounded waits, no sleeps; each journey well under 60 s. System accessibility audits wait for the device
// campaign (owner ruling of 2026-11-13).
import XCTest

final class ZGGardenUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Raking the rows pattern adds one stroke to the description, and Undo empties the stroke count.
    @MainActor
    func testRakingRowsAddsAStrokeAndUndoTakesItBack() {
        let app = ZG.open()
        XCTAssertEqual(ZG.strokes(ZG.description(app)), 0, "a fresh garden has no stroke: \(ZG.description(app))")

        XCTAssertTrue(ZG.tap(app, "pattern-rows"), "Rake rows is tapped")
        XCTAssertTrue(ZG.waitForDescription(app) { (ZG.strokes($0) ?? 0) >= 1 },
                      "the description names a stroke: \(ZG.description(app))")

        XCTAssertTrue(ZG.tap(app, "undo"), "Undo is tapped")
        XCTAssertTrue(ZG.waitForDescription(app) { ZG.strokes($0) == 0 },
                      "after Undo the description names 0 strokes: \(ZG.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// A river pebble placed with the Stones tool is removed, and Undo restores it.
    @MainActor
    func testAPlacedPebbleIsRemovedAndUndoRestoresIt() {
        let app = ZG.open()
        XCTAssertEqual(ZG.stones(ZG.description(app)), 0, "a fresh garden has no stone: \(ZG.description(app))")

        XCTAssertTrue(ZG.chooseTool(app, "Stones", index: 1), "the Stones tool is chosen")
        XCTAssertTrue(ZG.choose(app, "stone-kind", ZG.riverPebble), "the kind is River pebble")
        XCTAssertTrue(ZG.tap(app, "stone-place"), "Place is tapped")
        XCTAssertTrue(ZG.waitForDescription(app) { ZG.stones($0) == 1 && $0.contains(ZG.riverPebble + " selected") },
                      "the description names one selected river pebble: \(ZG.description(app))")
        let selection = ZG.control(app, "selection")
        XCTAssertTrue(ZG.waitForValue(selection) { $0.hasPrefix(ZG.riverPebble + " selected, 1 of 1") },
                      "the selection reads the pebble: \(selection.value as? String ?? "")")

        XCTAssertTrue(ZG.tap(app, "stone-remove"), "Remove is tapped")
        XCTAssertTrue(ZG.waitForDescription(app) { ZG.stones($0) == 0 && $0.hasSuffix("No stone selected") },
                      "after Remove the description names no stone: \(ZG.description(app))")

        XCTAssertTrue(ZG.tap(app, "undo"), "Undo is tapped")
        XCTAssertTrue(ZG.waitForDescription(app) { ZG.stones($0) == 1 },
                      "after Undo the description names one stone again: \(ZG.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
