// PUForceUITests — feature 193 (UA-F07) T-U07-028: port of the standalone app's SandboxForceUITests (feature 034
// A04-P02 T-A04-208; FR-A04-204; US1 AC1–AC3; SC-A04-206) into the one app. A tap on the canvas places the force where
// it was tapped, a drag moves it, and Center, the nudges, the strength and the kind work without gestures, each read
// back from the force text ("Force: <Kind> at <x>, <y>") and the strength slider ("×<s>").
//
// Differences from the standalone test, recorded in the test map: the canvas shows the world square fitted into it,
// so the test taps world points (`PU.world`) instead of fractions of the canvas; the force text carries no strength,
// which the strength slider speaks; the kind menu is one choice per kind (`force.none`, `force.<kind>`); the controls
// offer Left and Right nudges only (no Up and Down), so the clamp is checked at the right edge of the world square.
import XCTest

final class PUForceUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testTapPlacesTheForceWhereTapped() {
        let app = PU.open()
        XCTAssertNil(PU.force(app), "no force before the first tap: \(PU.control(app, "force").label)")
        XCTAssertTrue(PU.canvas(app).label.contains("no force placed"), PU.canvas(app).label)
        PU.world(app, x: 250, y: 250).tap()
        XCTAssertTrue(PU.waitForForce(app) { $0 != nil }, PU.control(app, "force").label)
        let f = PU.force(app)
        XCTAssertEqual(f?.kind, "Attractor", "the default kind is Attractor (journey 1)")
        XCTAssertEqual(Double(f?.x ?? 0), 250, accuracy: 25, "upper right quadrant: x ≈ 250")
        XCTAssertEqual(Double(f?.y ?? 0), 250, accuracy: 25, "y up: y ≈ 250")
        XCTAssertTrue(PU.waitForLabel(PU.canvas(app)) { $0.contains("Attractor at") },
                      "the canvas description names the force: \(PU.canvas(app).label)")
    }

    @MainActor
    func testDragMovesTheForce() {
        let app = PU.open()
        PU.world(app, x: 0, y: 0).tap()
        XCTAssertTrue(PU.waitForForce(app) { $0 != nil }, PU.control(app, "force").label)
        PU.world(app, x: 0, y: 0).press(forDuration: 0.2, thenDragTo: PU.world(app, x: -300, y: -300))
        XCTAssertTrue(PU.waitForForce(app) { f in
            guard let f else { return false }
            return abs(f.x + 300) <= 25 && abs(f.y + 300) <= 25
        }, "dragged left and down: \(PU.control(app, "force").label)")
    }

    @MainActor
    func testCenterNudgesStrengthAndKindWithoutGestures() {
        let app = PU.open()
        let right = PU.control(app, "force.right"), left = PU.control(app, "force.left")
        PU.reveal(app, right)
        XCTAssertFalse(right.isEnabled, "nothing to move yet")
        XCTAssertFalse(left.isEnabled)
        PU.tap(app, "force.center")
        XCTAssertTrue(PU.waitForForce(app) { $0?.x == 0 && $0?.y == 0 }, PU.control(app, "force").label)
        PU.reveal(app, right)
        XCTAssertTrue(right.isEnabled)
        right.tap()
        right.tap()
        XCTAssertTrue(PU.waitForForce(app) { $0?.x == 100 && $0?.y == 0 }, PU.control(app, "force").label)
        left.tap()
        XCTAssertTrue(PU.waitForForce(app) { $0?.x == 50 && $0?.y == 0 }, PU.control(app, "force").label)
        for _ in 0..<10 { right.tap() }
        XCTAssertTrue(PU.waitForForce(app) { $0?.x == 500 }, "clamped to the world square: \(PU.control(app, "force").label)")

        PU.adjust(app, "strength", to: 1)
        XCTAssertTrue(PU.waitForValue(app, "strength") { $0 == "×2.0" }, PU.value(app, "strength"))

        for (raw, title) in [("repulsor", "Repulsor"), ("gravityWell", "Gravity well"), ("wind", "Wind"),
                             ("vortex", "Vortex")] {
            PU.tap(app, "force." + raw)
            XCTAssertTrue(PU.waitForSelection(PU.control(app, "force." + raw)), title)
            XCTAssertTrue(PU.waitForForce(app) { $0?.kind == title }, PU.control(app, "force").label)
            XCTAssertEqual(PU.force(app)?.x, 500, "changing the kind keeps the position")
            XCTAssertEqual(PU.force(app)?.y, 0)
        }
        XCTAssertEqual(PU.value(app, "strength"), "×2.0", "the strength stays")
        PU.tap(app, "force.none")
        XCTAssertTrue(PU.waitForLabel(PU.control(app, "force")) { $0.hasPrefix("Force: none") },
                      PU.control(app, "force").label)
        XCTAssertTrue(PU.waitForLabel(PU.canvas(app)) { $0.contains("no force placed") }, PU.canvas(app).label)
    }
}
