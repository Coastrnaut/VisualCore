// TWWorldUITests — feature 094 (A12-P06) T-A12-609 (FR-A12-630): the world and view controls of Tiny Worlds (A12)
// inside the one app. The segmented pack picker chooses Asteroid garden and Open pack opens it (the canvas
// description, the status line and the answer line name the asteroid garden, seed 7); Turn left changes the spoken
// direction (the default view looks from the north-east at yaw 45°, so the second 15° turn reaches the north), Zoom in
// changes the spoken distance (18 → 14 metres) and Reset view returns to the view from the north-east, 35 degrees up,
// 18 metres away. One journey per test, each well under 60 s. System accessibility audits wait for the device campaign
// (owner ruling of 2026-11-13).
import XCTest

final class TWWorldUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The pack picker chooses Asteroid garden and Open pack opens it.
    @MainActor
    func testOpenPack() {
        let app = TW.open()

        XCTAssertTrue(TW.waitForDescription(app) { $0.hasPrefix("Tiny Worlds: Island, seed 1;") },
                      "a fresh start is the island, seed 1: \(TW.description(app))")
        XCTAssertTrue(TW.chooseSegment(app, "pack", "Asteroid garden", index: 1, of: 3),
                      "the pack picker speaks Asteroid garden (now \(TW.value(app, "pack")))")
        XCTAssertTrue(TW.waitForValue(TW.control(app, "open-pack")) { $0 == "Asteroid garden" },
                      "Open pack names the chosen pack (now \(TW.value(app, "open-pack")))")

        TW.tap(app, "open-pack")
        XCTAssertTrue(TW.waitForDescription(app) { $0.hasPrefix("Tiny Worlds: Asteroid garden, seed 7;") },
                      "the description names the asteroid garden: \(TW.description(app))")
        let message = TW.control(app, "message")
        waitFor(message, timeout: TW.shortWait, "the answer line is there")
        XCTAssertTrue(TW.waitForLabel(message, timeout: TW.shortWait) { $0 == "Opened the asteroid garden pack." },
                      "the answer names the pack: \(message.label)")
        let status = TW.control(app, "status")
        XCTAssertTrue(TW.waitForLabel(status, timeout: TW.shortWait) { $0.hasPrefix("Asteroid garden, seed 7;") },
                      "the status line names the asteroid garden: \(status.label)")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Turn left and Zoom in change their spoken values; Reset view returns to the default view.
    @MainActor
    func testTurnAndZoom() {
        let app = TW.open()
        let defaultView = "view from the north-east, 35 degrees up, 18 metres away"

        let turn = TW.control(app, "turn-left")
        waitFor(turn, timeout: TW.shortWait, "Turn left is there")
        XCTAssertEqual(TW.value(app, "turn-left"), "view from the north-east", "the view starts from the north-east")
        // 45° − 15° still rounds to the north-east; the second turn (15°) looks from the north.
        XCTAssertTrue(TW.tapUntilChanged(app, "turn-left", from: "view from the north-east", times: 3),
                      "turning left changes the direction (now \(TW.value(app, "turn-left")))")
        XCTAssertTrue(TW.value(app, "turn-left").hasPrefix("view from the "),
                      "the direction is spoken in words: \(TW.value(app, "turn-left"))")
        XCTAssertTrue(TW.waitForDescription(app) { $0.contains("; \(TW.value(app, "turn-left")), ") },
                      "the description follows the turn: \(TW.description(app))")

        XCTAssertEqual(TW.value(app, "zoom-in"), "18 metres away", "the view starts 18 metres away")
        TW.tap(app, "zoom-in")
        XCTAssertTrue(TW.waitForValue(TW.control(app, "zoom-in")) { $0 == "14 metres away" },
                      "zooming in moves closer (now \(TW.value(app, "zoom-in")))")
        XCTAssertTrue(TW.waitForDescription(app) { $0.contains(", 14 metres away") },
                      "the description follows the zoom: \(TW.description(app))")

        TW.tap(app, "reset-view")
        XCTAssertTrue(TW.waitForValue(TW.control(app, "reset-view")) { $0 == defaultView },
                      "Reset view returns to the default view (now \(TW.value(app, "reset-view")))")
        XCTAssertTrue(TW.waitForDescription(app) { $0.contains("; \(defaultView)") },
                      "the description says the default view: \(TW.description(app))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
