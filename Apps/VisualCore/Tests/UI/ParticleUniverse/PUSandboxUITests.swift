// PUSandboxUITests — feature 193 (UA-F07) T-U07-028: port of the standalone app's SandboxUITests (feature 033
// T-A04-107 and T-A04-115, feature 034 T-A04-214 and T-A04-218; FR-A04-106, FR-A04-206; US1 AC1/AC2, US4 AC2;
// SC-A04-106) into the one app. Every family is selectable and named by the canvas description; the live count grows
// and stays within the limit; Pause, Step and New seed; a background round trip keeps the person's play or pause; the
// stage advances while playing and holds while paused, and taps on it place the force; under Reduce Motion the scene
// starts paused. It also opens A04 from its catalog tile (the standalone home's Open button and its title,
// LaunchSmokeUITests).
//
// Differences from the standalone test, recorded in the test map: the family is A04's Family choices (no segmented
// control) and the family description is the choice's hint, so the canvas description carries the check; there are
// no renderer and dropped-count texts and no CPU preview (adapter difference 3: a GPU failure fails the session);
// Reduce Motion is the one app's setting, and the controls pause the scene once after its preparation (adapter
// difference 4), so the held count is checked instead of a count of zero.
import XCTest

final class PUSandboxUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    @MainActor
    func testOpenFromTheCatalogShowsTheDescribedCanvas() {
        let app = launchApp(arguments: [VC.reset, VC.skipWelcome, PU.candidates])
        waitFor(element(app, "vc.route.catalog"))
        let tile = element(app, VC.tilePrefix + PU.experienceID)
        _ = tile.waitForExistence(timeout: VC.wait)
        for _ in 0..<8 where !(tile.exists && tile.isHittable) { scrollCatalog(app) }
        XCTAssertTrue(tile.exists && tile.isHittable, "A04's tile in the catalog")
        tile.tap()

        waitFor(element(app, "vc.route.experience"), timeout: VC.wait)
        let canvas = PU.canvas(app)
        waitFor(canvas, timeout: VC.firstWait)
        XCTAssertTrue(PU.waitForLabel(canvas) { $0 == "Particle scene: Fountain, no force placed, playing." },
                      "spoken description: \(canvas.label)")
        let title = app.navigationBars.matching(identifier: PU.title).firstMatch
        XCTAssertTrue(title.exists || app.staticTexts[PU.title].exists, "the experience's title")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")

        let back = element(app, "vc.experience.back")
        waitFor(back, timeout: VC.wait)
        back.tap()
        waitFor(element(app, "vc.route.catalog"), timeout: VC.wait)
        XCTAssertTrue(waitUntilGone(PU.canvas(app)), "the canvas is gone after leaving")
    }

    @MainActor
    func testEveryFamilyIsSelectableAndDescribed() {
        let app = PU.open()
        let families = ["fountain": "Fountain", "curtain": "Curtain", "halo": "Halo", "firework": "Firework"]
        XCTAssertTrue(PU.waitForSelection(PU.control(app, "family.fountain")), "Fountain is the first family")
        for (raw, title) in families.sorted(by: { $0.key < $1.key }) {
            let choice = PU.control(app, "family." + raw)
            PU.tap(app, "family." + raw)
            XCTAssertTrue(PU.waitForSelection(choice), title)
            XCTAssertEqual(choice.label, title)
            XCTAssertTrue(PU.waitForLabel(PU.canvas(app)) { $0.hasPrefix("Particle scene: \(title),") },
                          "the canvas names \(title): \(PU.canvas(app).label)")
            for other in families.keys where other != raw {
                XCTAssertFalse(PU.control(app, "family." + other).isSelected, "only \(title) is chosen")
            }
        }
    }

    @MainActor
    func testLiveCountGrowsAndStaysWithinTheLimit() {
        let app = PU.open()
        XCTAssertGreaterThan(PU.waitForLive(app) { $0 > 0 }, 0, "particles appear while playing")
        XCTAssertEqual(PU.counts(app)?.limit, PU.limit)
        for _ in 0..<8 {
            usleep(250_000)
            guard let (n, l) = PU.counts(app) else { return XCTFail(PU.control(app, "live").label) }
            XCTAssertLessThanOrEqual(n, l)
        }
    }

    @MainActor
    func testPauseStepAndNewSeed() {
        let app = PU.open()
        let play = PU.control(app, "play"), step = PU.control(app, "step")
        PU.reveal(app, play)
        XCTAssertEqual(play.label, "Pause")
        XCTAssertFalse(step.isEnabled, "Step is only for a paused scene")
        play.tap()
        XCTAssertTrue(PU.waitForLabel(play) { $0 == "Play" }, "paused: \(play.label)")
        XCTAssertTrue(step.isEnabled)
        let paused = PU.live(app)
        usleep(1_000_000)
        XCTAssertEqual(PU.live(app), paused, "a paused scene does not advance")
        for _ in 0..<12 { step.tap() }
        // At a steady state a step can retire more particles than it emits, so the count changes in either direction.
        XCTAssertNotEqual(PU.waitForLive(app) { $0 != paused }, paused, "Step advances a paused scene")
        PU.tap(app, "reseed")
        XCTAssertEqual(PU.waitForLive(app) { $0 == 0 }, 0, "a new seed restarts the scene")
        PU.tap(app, "step")
        XCTAssertGreaterThan(PU.waitForLive(app) { $0 > 0 }, 0, "Step after a new seed")
    }

    /// A playing scene plays again after the background; a paused scene stays paused.
    @MainActor
    func testBackgroundRoundTripKeepsThePersonsChoice() {
        let app = PU.open()
        let play = PU.control(app, "play")
        PU.backgroundAndReturn(app)
        XCTAssertTrue(PU.waitForLabel(play) { $0 == "Pause" }, "still playing after the background: \(play.label)")
        let before = PU.waitForLive(app) { $0 > 0 }
        XCTAssertNotEqual(PU.waitForLive(app, timeout: 5) { $0 != before }, before, "the scene advances again")

        PU.tap(app, "play")
        XCTAssertTrue(PU.waitForLabel(play) { $0 == "Play" }, "paused: \(play.label)")
        let paused = PU.live(app)
        PU.backgroundAndReturn(app)
        XCTAssertTrue(PU.waitForLabel(play) { $0 == "Play" }, "a paused scene stays paused: \(play.label)")
        usleep(1_000_000)
        XCTAssertEqual(PU.live(app), paused, "nothing advances while paused")
    }

    /// The stage draws the scene: it advances while playing and holds while paused; a tap on it places the force.
    @MainActor
    func testGPUStageAdvancesAndHolds() {
        let app = PU.open()
        let a = PU.waitForLive(app) { $0 > 0 }
        XCTAssertNotEqual(PU.waitForLive(app, timeout: 5) { $0 != a }, a, "the frames advance the simulation")
        PU.tap(app, "play")
        XCTAssertTrue(PU.waitForLabel(PU.canvas(app)) { $0.hasSuffix("paused.") }, PU.canvas(app).label)
        let held = PU.live(app)
        usleep(1_000_000)
        XCTAssertEqual(PU.live(app), held, "paused: the stage redraws the held state")
        PU.world(app, x: -250, y: -250).tap()
        XCTAssertTrue(PU.waitForForce(app) { $0?.kind == "Attractor" && ($0?.x ?? 0) < 0 && ($0?.y ?? 0) < 0 },
                      "taps work over the stage: \(PU.control(app, "force").label)")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Under the one app's Reduce Motion the scene starts paused and holds until the person presses Play.
    @MainActor
    func testReduceMotionStartsPaused() {
        let app = PU.openWithSettings(reduceMotion: true)
        let play = PU.control(app, "play")
        XCTAssertTrue(PU.waitForLabel(play) { $0 == "Play" }, "starts paused: \(play.label)")
        XCTAssertTrue(PU.waitForLabel(PU.canvas(app)) { $0.hasSuffix("paused.") }, PU.canvas(app).label)
        let held = PU.live(app)
        usleep(1_000_000)
        XCTAssertEqual(PU.live(app), held, "nothing advances while paused")
        PU.tap(app, "play")
        XCTAssertTrue(PU.waitForLabel(play) { $0 == "Pause" }, "Play starts the scene: \(play.label)")
        XCTAssertNotEqual(PU.waitForLive(app, timeout: 5) { $0 != held }, held, "the scene advances after Play")
    }
}
