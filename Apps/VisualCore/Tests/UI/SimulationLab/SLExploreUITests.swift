// SLExploreUITests — feature 122 (A16-P06) T-A16-608 (clarification Q4; FR-A16-630, FR-A16-622): Run / Pause, Step,
// the bundled preset Spots and the Seed button of Simulation Lab (A16) inside the one app. A fresh start (erased data)
// runs the cellular automaton Life. Pause makes the status start "Paused" and Run / Pause's title Run; Step while
// paused raises the step count in the status by one; the bundled preset Spots (`bundled-3`) makes the status name
// time step 1 and the approximation label the explicit Euler step ("Approximation: 64 × 64 cells, half-precision
// values, wrap boundary, explicit Euler step.", the method and limits of FR-A16-622); Seed while paused leaves the
// step count unchanged. One journey per test, well under 60 s. Capture is never tapped, so the share sheet is never
// presented. System accessibility audits wait for the device campaign (owner ruling of 2026-11-13).
import XCTest

final class SLExploreUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Pause, then Step: the status starts Paused and its step count rises by one.
    @MainActor
    func testPauseThenStepRisesByOne() {
        let app = SL.open()

        let runPause = SL.control(app, "run-pause")
        waitFor(runPause, timeout: SL.shortWait, "Run / Pause is there")
        XCTAssertTrue(SL.waitForStatus(app) { $0.hasPrefix("Running") },
                      "a fresh start runs (now \(SL.status(app)))")
        XCTAssertTrue(SL.waitForLabel(runPause, timeout: SL.shortWait) { $0 == "Pause" },
                      "Run / Pause is titled Pause while running (now \(runPause.label))")

        SL.tap(app, "run-pause")
        XCTAssertTrue(SL.waitForStatus(app) { $0.hasPrefix("Paused") },
                      "the status starts Paused (now \(SL.status(app)))")
        XCTAssertTrue(SL.waitForLabel(runPause, timeout: SL.shortWait) { $0 == "Run" },
                      "Run / Pause is titled Run while paused (now \(runPause.label))")

        guard let before = SL.stepCount(SL.status(app)) else {
            return XCTFail("the status names a step count (now \(SL.status(app)))")
        }
        SL.tap(app, "step")
        XCTAssertTrue(SL.waitForStatus(app) { SL.stepCount($0) == before + 1 },
                      "Step raises the step count from \(before) by one (now \(SL.status(app)))")
        XCTAssertTrue(SL.status(app).hasPrefix("Paused"), "still paused (now \(SL.status(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// The bundled preset Spots: the status names time step 1 and the approximation label the Euler step.
    @MainActor
    func testSpotsNamesEulerStep() {
        let app = SL.open()

        let spots = SL.control(app, "bundled-\(SL.spotsIndex)")
        waitFor(spots, timeout: SL.shortWait, "the bundled preset Spots is there")
        XCTAssertEqual(spots.label, "Spots", "bundled-\(SL.spotsIndex) is Spots")

        SL.tap(app, "bundled-\(SL.spotsIndex)")
        XCTAssertTrue(SL.waitForStatus(app) { $0.hasSuffix(", time step 1") },
                      "the status names time step 1 (now \(SL.status(app)))")
        let approximation = SL.control(app, "approximation")
        waitFor(approximation, timeout: SL.shortWait, "the approximation label is there")
        XCTAssertTrue(SL.waitForValue(approximation) { $0 == SL.eulerApproximation },
                      "the approximation label names the Euler step (now \(SL.value(app, "approximation")))")
        XCTAssertEqual(approximation.label, "Approximation", "the approximation label is spoken as Approximation")
        XCTAssertTrue(SL.waitForLabel(SL.canvas(app)) { $0.contains("preset Spots") },
                      "the canvas description names Spots (now \(SL.description(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }

    /// Seed while paused: the step count is unchanged.
    @MainActor
    func testSeedKeepsStepCount() {
        let app = SL.open()

        guard SL.pause(app), let before = SL.stepCount(SL.status(app)) else {
            return XCTFail("paused with a step count (now \(SL.status(app)))")
        }
        let seed = SL.control(app, "seed")
        waitFor(seed, timeout: SL.shortWait, "the Seed button is there")
        XCTAssertEqual(seed.label, "Seed", "the Seed button is titled Seed")

        SL.tap(app, "seed")
        // A step that would wrongly be taken arrives within a moment; wait for it, then read the status again.
        XCTAssertFalse(SL.waitForStatus(app, timeout: 1.5) { SL.stepCount($0) != before },
                       "Seed leaves the step count at \(before) (now \(SL.status(app)))")
        XCTAssertEqual(SL.stepCount(SL.status(app)), before, "the step count is unchanged")
        XCTAssertTrue(SL.status(app).hasPrefix("Paused"), "still paused (now \(SL.status(app)))")
        XCTAssertFalse(element(app, "session.failure").exists, "no failure")
    }
}
