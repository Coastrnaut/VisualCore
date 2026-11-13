// PUEmitterUITests — feature 193 (UA-F07) T-U07-028: port of the standalone app's SandboxEmitterUITests (feature 035
// A04-P03 T-A04-311 and T-A04-317; US1, US2; FR-A04-304, FR-A04-305; SC-A04-306) into the one app. Emitters are added,
// selected and removed; a family change edits the selected emitter only and keeps its size override; removing the
// selected last emitter selects the previous one; size, lifetime and gradient controls speak their values.
//
// Differences from the standalone test, recorded in the test map: the emitter menu is one choice per emitter
// (`emitter.<index>`, "Emitter <n>"), the gradient menu is one choice per gradient (`gradient.<palette id>` and
// `gradient.family`), and Remove emitter stays on screen but disabled while one emitter is left (the standalone app
// hid it).
import XCTest

final class PUEmitterUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Waits until the scene has `n` emitters; fails at the caller's line when it never does.
    @MainActor
    private func expectEmitters(_ app: XCUIApplication, _ n: Int, _ message: String = "",
                                file: StaticString = #filePath, line: UInt = #line) {
        let ok = PU.waitForLabel(PU.control(app, "emitters")) { PU.numbers($0).first == n }
        XCTAssertTrue(ok, "\(n) emitters \(message): \(PU.control(app, "emitters").label)", file: file, line: line)
    }

    @MainActor
    func testAddSelectAndRemoveEmitters() {
        let app = PU.open()
        expectEmitters(app, 1)
        let remove = PU.control(app, "emitter.remove")
        PU.reveal(app, remove)
        XCTAssertFalse(remove.isEnabled, "a scene always keeps one emitter, so Remove is not available")
        PU.tap(app, "emitter.add")
        PU.tap(app, "emitter.add")
        expectEmitters(app, 3)
        XCTAssertTrue(PU.waitForSelection(PU.control(app, "emitter.2")), "the new Emitter 3 is selected")
        XCTAssertEqual(PU.control(app, "emitter.2").label, "Emitter 3")
        PU.tap(app, "emitter.0")
        XCTAssertTrue(PU.waitForSelection(PU.control(app, "emitter.0")), "Emitter 1 is selected")
        XCTAssertFalse(PU.control(app, "emitter.2").isSelected)
        PU.tap(app, "family.halo")   // the family choice edits the selected emitter only
        XCTAssertTrue(PU.waitForSelection(PU.control(app, "family.halo")))
        expectEmitters(app, 3, "after a family change")
        PU.reveal(app, remove)
        XCTAssertTrue(remove.isEnabled)
        remove.tap()
        expectEmitters(app, 2)
        PU.tap(app, "emitter.remove")
        expectEmitters(app, 1)
        PU.reveal(app, remove)
        XCTAssertFalse(remove.isEnabled, "the last emitter cannot be removed")
    }

    @MainActor
    func testSizeLifetimeAndGradientControls() {
        let app = PU.open()
        PU.adjust(app, "size", to: 1)
        XCTAssertTrue(PU.waitForValue(app, "size") { $0 == "48 points" }, PU.value(app, "size"))
        PU.adjust(app, "size", to: 0)
        XCTAssertTrue(PU.waitForValue(app, "size") { $0 == "1 points" }, PU.value(app, "size"))
        PU.adjust(app, "lifetime", to: 1)
        XCTAssertTrue(PU.waitForValue(app, "lifetime") { $0 == "8.0 seconds" }, PU.value(app, "lifetime"))

        let family = PU.control(app, "gradient.family"), ocean = PU.control(app, "gradient.ocean")
        PU.reveal(app, family)
        XCTAssertTrue(PU.waitForSelection(family), "the family's colours are the first gradient")
        PU.tap(app, "gradient.ocean")
        XCTAssertTrue(PU.waitForSelection(ocean), "Ocean is chosen")
        XCTAssertEqual(ocean.label, "Ocean")
        XCTAssertFalse(family.isSelected)
        PU.tap(app, "gradient.family")
        XCTAssertTrue(PU.waitForSelection(family), "Family colors again")
        XCTAssertEqual(family.label, "Family colors")
        XCTAssertFalse(ocean.isSelected)
    }

    /// A family change keeps the selected emitter's size override, and removing the selected Emitter 3 selects
    /// Emitter 2.
    @MainActor
    func testFamilyChangeKeepsOverridesAndRemovalSelectsThePrevious() {
        let app = PU.open()
        PU.adjust(app, "size", to: 1)
        XCTAssertTrue(PU.waitForValue(app, "size") { $0 == "48 points" }, PU.value(app, "size"))
        PU.tap(app, "family.curtain")
        XCTAssertTrue(PU.waitForSelection(PU.control(app, "family.curtain")))
        PU.reveal(app, PU.slider(app, "size"))
        XCTAssertEqual(PU.value(app, "size"), "48 points", "the family change keeps the size override")
        PU.tap(app, "emitter.add")
        PU.tap(app, "emitter.add")
        XCTAssertTrue(PU.waitForSelection(PU.control(app, "emitter.2")), "Emitter 3 is selected")
        PU.tap(app, "emitter.remove")
        XCTAssertTrue(PU.waitForSelection(PU.control(app, "emitter.1")), "removing Emitter 3 selects Emitter 2")
        XCTAssertEqual(PU.control(app, "emitter.1").label, "Emitter 2")
        XCTAssertTrue(waitUntilGone(PU.control(app, "emitter.2")), "Emitter 3 is gone")
    }
}
