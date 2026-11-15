// DALibraryUITests — feature 073 (A09-P06) T-A09-608 (FR-A09-630): the "Saved aquariums" section. A fresh launch erases
// the data, so the library starts empty; the Reef is saved under the name "Calm reef" (a row with that label appears),
// the habitat is changed to Kelp, and a tap on the saved row opens the Reef again (the canvas description names it).
// One journey, well under 60 s. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class DALibraryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Save under a name, change the habitat, open the saved aquarium.
    @MainActor
    func testSaveAndOpen() {
        let app = DA.open()
        let name = "Calm reef"

        XCTAssertEqual(DA.value(app, "habitat.select"), DA.reef, "a fresh start shows the Reef")
        XCTAssertFalse(DA.control(app, "library.0").exists, "a fresh start has no saved aquarium")

        DA.type(app, "library.name", name)
        DA.tap(app, "library.save")
        let row = DA.control(app, "library.0")
        XCTAssertTrue(row.waitForExistence(timeout: DA.shortWait), "the saved aquarium is listed")
        XCTAssertEqual(row.label, name, "the saved aquarium carries its name")
        XCTAssertFalse(DA.control(app, "library.failure").exists, "no store failure after saving")

        XCTAssertTrue(DA.pick(app, "habitat.select", DA.kelp, upFirst: true),
                      "the habitat is Kelp (now \(DA.value(app, "habitat.select")))")
        XCTAssertTrue(DA.waitForDescription(app) { $0.hasPrefix(DA.describedPrefix + DA.kelp) },
                      "the canvas names the Kelp: \(DA.description(app))")

        DA.tap(app, "library.0")
        XCTAssertTrue(DA.waitForDescription(app) { $0.hasPrefix(DA.describedPrefix + DA.reef) },
                      "the saved Reef is open again: \(DA.description(app))")
        XCTAssertEqual(DA.value(app, "habitat.select"), DA.reef, "the habitat picker follows the saved aquarium")
        XCTAssertFalse(DA.control(app, "library.failure").exists, "no store failure after opening")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
