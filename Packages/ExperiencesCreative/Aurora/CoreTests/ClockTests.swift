// ClockTests — feature 152 (A21-P01) T-A21-108 (FR-A21-106; SC-A21-103; clarification Q4). The sky clock advances
// only by frame deltas, each step at most 0.25 s × speed, so a one-hour gap never jumps; it holds under Reduce Motion
// and at speed 0; the phase is time / 600 and stays in 0…1.
import XCTest
import AuroraCore
import VisualCoreSimulation

final class ClockTests: XCTestCase {
    func testOneHourGapMovesTimeByAtMostOneBoundedStep() {
        for speed in [0.5, 1.0, 2.0] {
            var clock = SkyClock(speed: speed)
            clock.advance(by: 3_600)
            XCTAssertLessThanOrEqual(clock.time, SceneClock.maxDelta * speed + 1e-12, "speed \(speed)")
            XCTAssertGreaterThan(clock.time, 0)
        }
    }

    func testHeldUnderReducedMotionAndAtSpeedZero() {
        var still = SkyClock(speed: 1, reducedMotion: true)
        still.scrub(to: 12)
        for _ in 0..<10 { still.advance(by: 1.0 / 60) }
        XCTAssertEqual(still.time, 12)
        var stopped = SkyClock(scene: SkyPresets.polarNight.scene)
        stopped.speed = 0
        for _ in 0..<10 { stopped.advance(by: 0.1) }
        XCTAssertEqual(stopped.time, 0)
        stopped.reducedMotion = false
        stopped.speed = 1
        stopped.advance(by: 0.1)
        XCTAssertEqual(stopped.time, 0.1, accuracy: 1e-12, "full rate once motion is allowed")
    }

    func testSpeedIsClampedAndTheSceneSpeedIsUsed() {
        var clock = SkyClock(speed: 5)
        XCTAssertEqual(clock.speed, 2)
        clock.speed = .nan
        XCTAssertEqual(clock.speed, 2)
        clock.speed = -1
        XCTAssertEqual(clock.speed, 0)
        XCTAssertEqual(SkyClock(scene: SkyPresets.dawnHaze.scene).speed, SkyPresets.dawnHaze.scene.speed)
        XCTAssertEqual(SkyClock.period, 600)
    }

    func testPhaseWrapsWithinZeroToOne() {
        var clock = SkyClock(speed: 2)
        clock.scrub(to: 599.9)
        let before = clock.phase
        XCTAssertEqual(before, 599.9 / 600, accuracy: 1e-12)
        clock.advance(by: 0.25)
        XCTAssertGreaterThanOrEqual(clock.phase, 0)
        XCTAssertLessThan(clock.phase, 1)
        XCTAssertLessThan(clock.phase, before, "wrapped at the period")
        XCTAssertEqual(clock.time, 0.4, accuracy: 1e-9, "0.25 s × speed 2 past 599.9")
        clock.advance(by: .infinity)
        XCTAssertEqual(clock.time, 0.4, accuracy: 1e-9, "a non-finite delta is ignored")
    }
}
