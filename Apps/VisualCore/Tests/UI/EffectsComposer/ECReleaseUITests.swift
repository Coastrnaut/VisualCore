// ECReleaseUITests — feature 185 (A25-P06) T-A25-608 (contracts/release.md "Interface", chunk `h3`): the
// first-session defaults of Effects Composer (A25) inside the one app, at the release gate. A fresh start erases the
// data (`-vcResetData`), skips the welcome, makes the candidates available (`-vcCandidates`, DebugLaunch: A25 is
// registered before its X gate) and opens A25 directly (`-openExperience a25.effects-composer`). The controls are
// found by the identifiers of `ECControls` (`port.identifier(name)`, that is `experience.a25.effects-composer.<name>`).
// The status reads "Ready" (spoken "Status, Ready"); the chain is empty (no `node-0`, no `remove-0`); `export-png`,
// `export-jpeg`, `export-heic` and `test-picture` are there, `export-png` spoken "Export as PNG" and `test-picture`
// "Use the test picture" (`ComposerLabels`); no `share` (no export was written) and no saved look (no
// `preset-row-1`, no `preset-open-1`). The presets list has no empty-state text of its own: an empty library shows
// only the name field and `preset-save`. One journey, timed from after the launch (the A24-P05 lesson), well under
// 60 s; every wait is bounded (``shortWait``, ``absentWait``, `VC.wait`, `VC.firstWait`) and waits on predicate
// expectations, never on `usleep` polling. System accessibility audits wait for the device campaign (owner ruling of
// 2026-11-13).
import Foundation
import XCTest

/// The release-gate interface journey of A25: a fresh start is Ready with an empty chain, the export and picture
/// controls, no share link and no saved look.
final class ECReleaseUITests: XCTestCase {
    /// The experience's id in the catalog.
    static let experienceID = "a25.effects-composer"
    /// The prefix of every identifier of the experience's controls.
    static let prefix = "experience.a25.effects-composer."
    /// A first start with erased data, straight into A25.
    static let fresh = [VC.reset, VC.skipWelcome, "-vcCandidates", VC.openExperience, experienceID]
    /// The longest the journey may take after the launch.
    static let journeyLimit: TimeInterval = 60
    /// The longest a single check waits.
    static let shortWait: TimeInterval = 5
    /// How long a control that should never appear is watched.
    static let absentWait: TimeInterval = 2

    /// Stops a journey at its first failed check.
    override func setUp() { continueAfterFailure = false }

    /// A fresh start is Ready with no effect, the export and picture controls, no share link and no saved look.
    @MainActor
    func testAFreshStartIsReadyWithNoEffectNoShareAndNoSavedLook() {
        let app = launchApp(arguments: Self.fresh)
        let started = Date()
        waitFor(element(app, "vc.route.experience"), timeout: VC.firstWait, "the experience route is shown")
        waitFor(element(app, VC.canvas), timeout: VC.firstWait, "the live canvas is there")
        let status = control(app, "status")
        waitFor(status, timeout: VC.wait, "the status line is there")
        XCTAssertTrue(waitForLabel(status, "Status, Ready"), "a fresh start is Ready: \(status.label)")

        for name in ["node-0", "remove-0", "enable-0"] {
            XCTAssertFalse(control(app, name).waitForExistence(timeout: name == "node-0" ? Self.absentWait : 0),
                           "a fresh chain has no effect row: \(name)")
        }

        for name in ["export-png", "export-jpeg", "export-heic", "test-picture"] {
            waitFor(control(app, name), timeout: Self.shortWait, "\(name) is there")
        }
        XCTAssertEqual(control(app, "export-png").label, "Export as PNG")
        XCTAssertEqual(control(app, "export-jpeg").label, "Export as JPEG")
        XCTAssertEqual(control(app, "export-heic").label, "Export as HEIC")
        XCTAssertEqual(control(app, "test-picture").label, "Use the test picture")

        XCTAssertFalse(control(app, "share").waitForExistence(timeout: Self.absentWait),
                       "no share link before an export")
        waitFor(control(app, "presets"), timeout: Self.shortWait, "the presets section is there")
        XCTAssertFalse(control(app, "preset-row-1").waitForExistence(timeout: Self.absentWait),
                       "a fresh start lists no saved look")
        XCTAssertFalse(control(app, "preset-open-1").exists, "a fresh start has no look to open")

        XCTAssertEqual(status.label, "Status, Ready", "still Ready at the end")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, Self.journeyLimit, "the journey took \(elapsed) s")
    }

    /// The control `name` of A25, of any element type.
    @MainActor
    private func control(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        element(app, Self.prefix + name)
    }

    /// Waits at most ``shortWait`` until `target` exists with the label `label`; true when it does. A predicate
    /// expectation, so the accessibility snapshot is refreshed between checks (no `usleep` polling).
    @MainActor
    private func waitForLabel(_ target: XCUIElement, _ label: String) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        return XCTWaiter.wait(for: [expectation], timeout: Self.shortWait) == .completed
    }
}
