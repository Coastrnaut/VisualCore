// DAAquariumUITests — feature 073 (A09-P06) T-A09-608 (FR-A09-630): Digital Aquarium opens on the Reef with no food;
// Feed drops pellets (the canvas description names them); Add decoration adds one piece, the last piece is chosen and
// moved right, and Remove takes it away again (the description's decoration count rises by one and falls back); in a
// third test the habitat picker chooses Kelp and the Ambient toggle turns ambient mode on (the description names the
// habitat and says "ambient"). One journey per test, each well under 60 s. System accessibility audits wait for the
// device campaign (owner ruling of 2026-11-13).
import XCTest

final class DAAquariumUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Feed (Feeding section): "no food" becomes food pellets.
    @MainActor
    func testFeeding() {
        let app = DA.open()

        XCTAssertTrue(DA.waitForDescription(app) { $0.contains(", no food,") },
                      "a fresh start has no food: \(DA.description(app))")
        DA.tap(app, "food.feed")
        XCTAssertTrue(DA.waitForDescription(app) { $0.contains(" food pellet") },
                      "the canvas names the dropped pellets: \(DA.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Add decoration, choose the last piece, Move right, Remove (Decorations section).
    @MainActor
    func testDecorations() {
        let app = DA.open()

        guard let before = DA.decorCount(app) else {
            return XCTFail("the canvas names the decorations: \(DA.description(app))")
        }
        DA.tap(app, "decor.add")
        XCTAssertTrue(DA.waitForDescription(app) { DA.decorCount(in: $0) == before + 1 },
                      "one decoration more than \(before): \(DA.description(app))")

        // The new piece is the last one: "Piece <n> (<kind>)".
        let last = before + 1
        XCTAssertTrue(DA.pick(app, "decor.piece", matching: NSPredicate(format: "label BEGINSWITH %@", "Piece \(last) (")),
                      "piece \(last) is chosen (now \(DA.value(app, "decor.piece")))")
        DA.tap(app, "decor.right")
        XCTAssertEqual(DA.decorCount(app), last, "moving keeps the pieces: \(DA.description(app))")
        XCTAssertTrue(DA.value(app, "decor.piece").hasPrefix("Piece \(last) ("),
                      "the moved piece stays chosen: \(DA.value(app, "decor.piece"))")

        DA.tap(app, "decor.remove")
        XCTAssertTrue(DA.waitForDescription(app) { DA.decorCount(in: $0) == before },
                      "back to \(before) decorations: \(DA.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Habitat Kelp, Ambient on (Aquarium section).
    @MainActor
    func testHabitatAndAmbient() {
        let app = DA.open()

        XCTAssertEqual(DA.value(app, "habitat.select"), DA.reef, "a fresh start shows the Reef")
        XCTAssertTrue(DA.pick(app, "habitat.select", DA.kelp, upFirst: true),
                      "the habitat is Kelp (now \(DA.value(app, "habitat.select")))")
        XCTAssertTrue(DA.waitForDescription(app) { $0.hasPrefix(DA.describedPrefix + DA.kelp) },
                      "the canvas names the Kelp: \(DA.description(app))")

        XCTAssertEqual(DA.value(app, "ambient.mode"), "Off", "a fresh start is not ambient")
        DA.flip(app, "ambient.mode", upFirst: true)
        XCTAssertEqual(DA.value(app, "ambient.mode"), "On", "ambient mode is on")
        XCTAssertTrue(DA.waitForDescription(app) { $0.contains(", ambient, ") },
                      "the canvas says ambient: \(DA.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
