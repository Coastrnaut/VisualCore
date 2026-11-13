// GASRecoveryUITests — feature 193 (UA-F07) T-U07-015: port of the standalone app's RecoveryUITests (feature 013
// T-A01-209; FR-A01-205; SC-A01-204) into the one app. The standalone app read a composition from the launch
// argument `-gasComposition`; the one app has no such import, and the data A01 reads when it opens is its stored
// state. So the counterparts are: a damaged stored state (`-vcDamageState garbage`) and a stored state of a newer
// version (`-vcDamageState newer`) give the one app's notice, nothing runs behind it, and Reset (the counterpart of
// "Use default") continues with a working canvas at a fresh composition; a readable stored state opens without a
// notice and with the composition it held (the counterpart of correctable data that opens; the clamping of values
// out of range is the core's `CompositionEditor` validation, covered by the adapter's unit tests).
import XCTest

final class GASRecoveryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Opens A01 on erased data, switches to Geometric Tiling with the Monochrome palette (a state that differs
    /// from a fresh one) and ends the app after a suspension, which stores the state.
    @MainActor
    private func storeTilingState() {
        let app = GAS.open()
        GAS.tap(app, "family.geometric-tiling")
        GAS.expectFamily(app, "Geometric Tiling")
        GAS.tap(app, "palette.mono")
        let described = GAS.waitForLabel(GAS.canvas(app)) { $0.contains("Monochrome palette") }
        XCTAssertTrue(described, "the palette is chosen: \(GAS.canvas(app).label)")
        GAS.suspendAndEnd(app)
    }

    /// Starts A01 with its stored state damaged as `kind`; returns the app showing the notice.
    @MainActor
    private func startDamaged(_ kind: String) -> XCUIApplication {
        storeTilingState()
        let app = launchApp(arguments: GAS.again + [GAS.damageState, kind])
        waitFor(element(app, "vc.route.experience"))
        waitFor(element(app, "vc.unreadable"), timeout: VC.firstWait, "\(kind): the notice")
        XCTAssertFalse(GAS.canvas(app).exists, "\(kind): nothing runs behind the notice")
        return app
    }

    /// Reset of the notice: a working canvas at a fresh composition (the Particles family), no failure.
    @MainActor
    private func resetToDefault(_ app: XCUIApplication, _ kind: String) {
        let reset = element(app, "vc.unreadable.reset")
        scrollRoute(app, "vc.route.experience", to: reset)
        reset.tap()
        waitFor(GAS.canvas(app), timeout: VC.firstWait, "\(kind): running after Reset")
        XCTAssertTrue(waitUntilGone(element(app, "vc.unreadable")), "\(kind): the notice is gone")
        GAS.expectFamily(app, "Particles")
        sleep(1)
        XCTAssertFalse(element(app, "session.failure").exists, "\(kind): draws without a failure")
    }

    @MainActor
    func testCorruptDataIsRecoverable() {
        let app = startDamaged("garbage")
        let message = element(app, "vc.unreadable").label
        XCTAssertFalse(message.isEmpty, "the notice says what happened")
        XCTAssertFalse(message.contains("newer version"), "damaged data is not called newer: \(message)")
        resetToDefault(app, "garbage")
    }

    @MainActor
    func testFutureVersionIsRecoverable() {
        let app = startDamaged("newer")
        let message = element(app, "vc.unreadable").label
        XCTAssertTrue(message.contains("newer version"), "the notice names the newer version: \(message)")
        resetToDefault(app, "newer")
    }

    @MainActor
    func testCorrectableDataOpensWithNotes() {
        storeTilingState()
        let app = GAS.open(arguments: GAS.again)
        GAS.expectFamily(app, "Geometric Tiling")
        XCTAssertTrue(GAS.canvas(app).label.contains("Monochrome palette"), GAS.canvas(app).label)
        XCTAssertFalse(element(app, "vc.unreadable").exists, "a readable state gives no notice")
        XCTAssertFalse(element(app, "session.failure").exists)
    }
}
