// TWEditUITests — feature 094 (A12-P06) T-A12-609 (FR-A12-630): the editing, light and saved-world controls of Tiny
// Worlds (A12) inside the one app. Place puts the chosen prop (a tree) into the fresh island, which holds none: Place
// speaks "1 of 24 props" instead of "0 of 24 props", the answer line says "Placed a tree …" and the description counts
// the prop; the sun-direction stepper (`light-azimuth`, a stepper of 15° steps, not a slider) moves from 30 to 45
// degrees and the answer line says the new light; Save in slot 1 (`slot-0-save`) stores the world with its picture: the
// slot's status reads "Slot 1: Saved “Island, seed 1”." (the presenter reports the save over the "Holds “…”." it reads
// back; both are accepted, and neither may say "no picture"), Save speaks the stored name and the picture
// (`slot-0-picture`) appears. One journey per test, each well under 60 s. System accessibility audits wait for the
// device campaign (owner ruling of 2026-11-13).
import XCTest

final class TWEditUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Place adds one prop to the fresh island.
    @MainActor
    func testPlaceProp() {
        let app = TW.open()
        let place = TW.control(app, "place")

        waitFor(place, timeout: TW.shortWait, "Place is there")
        XCTAssertTrue(TW.waitForValue(place) { $0 == "0 of 24 props" },
                      "the fresh island holds no props (now \(TW.value(app, "place")))")

        TW.tap(app, "place")
        XCTAssertTrue(TW.waitForValue(place) { $0 == "1 of 24 props" },
                      "Place adds one prop (now \(TW.value(app, "place")))")
        let message = TW.control(app, "message")
        waitFor(message, timeout: TW.shortWait, "the answer line is there")
        XCTAssertTrue(TW.waitForLabel(message, timeout: TW.shortWait) { $0.hasPrefix("Placed a tree at x ") },
                      "the answer names the placed prop: \(message.label)")
        XCTAssertTrue(TW.waitForDescription(app) { $0.contains("; 1 prop, ") },
                      "the description counts the prop: \(TW.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The sun-direction stepper moves the light by one step.
    @MainActor
    func testChangeLight() {
        let app = TW.open()
        let name = "light-azimuth"
        let azimuth = TW.stepper(app, name)

        waitFor(azimuth, timeout: TW.shortWait, "the sun-direction stepper is there")
        TW.reveal(app, azimuth)
        let before = azimuth.value as? String ?? ""
        XCTAssertTrue(before.hasSuffix(" degrees"), "the stepper speaks the sun's direction (now \(before))")

        TW.increment(app, name)
        XCTAssertTrue(TW.waitForValue(TW.stepper(app, name)) { $0.hasSuffix(" degrees") && $0 != before },
                      "the sun's direction changed from \(before) (now \(TW.stepper(app, name).value as? String ?? ""))")
        let message = TW.control(app, "message")
        waitFor(message, timeout: TW.shortWait, "the answer line is there")
        XCTAssertTrue(TW.waitForLabel(message, timeout: TW.shortWait) { $0.hasPrefix("Light from ") },
                      "the answer says the new light: \(message.label)")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Save in slot 1 stores the world with its picture.
    @MainActor
    func testSaveWorld() {
        let app = TW.open()

        TW.tap(app, "slot-0-save")
        let status = TW.control(app, "slot-0-status")
        waitFor(status, timeout: TW.shortWait, "the slot's status is there")
        XCTAssertTrue(TW.waitForLabel(status, timeout: TW.shortWait) {
            ($0.hasPrefix("Slot 1: Saved “") || $0.hasPrefix("Slot 1: Holds “")) && !$0.contains("no picture")
        }, "the slot holds the world with its picture: \(status.label)")
        XCTAssertTrue(status.label.contains("“Island, seed 1”"), "the slot names the world: \(status.label)")
        XCTAssertTrue(TW.waitForValue(TW.control(app, "slot-0-save")) { $0 == "Island, seed 1" },
                      "Save speaks the stored name (now \(TW.value(app, "slot-0-save")))")
        waitFor(TW.control(app, "slot-0-picture"), timeout: TW.shortWait, "the slot shows its picture")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
