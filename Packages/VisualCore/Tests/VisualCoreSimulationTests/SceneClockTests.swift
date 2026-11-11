// SceneClockTests — feature 013 T-A01-201 (FR-A01-204, FR-A01-206; US2/AC3–AC4; edge cases).
import Testing
@testable import VisualCoreSimulation

@Test func advancesWhilePlayingAndFreezesWhenPaused() {
    var c = SceneClock()
    c.advance(by: 0.1)
    #expect(abs(c.time - 0.1) < 1e-12)
    c.pause()
    c.advance(by: 0.1)
    #expect(abs(c.time - 0.1) < 1e-12)
    c.toggle()
    #expect(c.isPlaying)
    c.advance(by: 0.05)
    #expect(abs(c.time - 0.15) < 1e-12)
}

@Test func capsDeltasAndIgnoresBadInput() {
    var c = SceneClock()
    c.advance(by: 30)          // back from the background
    #expect(c.time == SceneClock.maxDelta)
    c.advance(by: -1)
    #expect(c.time == SceneClock.maxDelta)
    c.advance(by: .nan); c.advance(by: .infinity)
    #expect(c.time == SceneClock.maxDelta)
    c.scrub(to: .nan)
    #expect(c.time == SceneClock.maxDelta)
}

@Test func scrubClampsAndWrapPlaybackStaysInRange() {
    var c = SceneClock(duration: 10)
    c.scrub(to: -5); #expect(c.time == 0)
    c.scrub(to: 50); #expect(c.time < 10 && c.time > 9.99)
    c.scrub(to: 9.9)
    c.advance(by: 0.2)
    #expect(abs(c.time - 0.1) < 1e-9, "wraps at duration")
    #expect(SceneClock(duration: -3).duration == 120)
}

@Test func speedIsClampedAndScalesTime() {
    var c = SceneClock(speed: 10)
    #expect(c.speed == 4)
    c.speed = -1; #expect(c.speed == 0)
    c.speed = .nan; #expect(c.speed == 0)
    c.speed = 2
    c.advance(by: 0.1)
    #expect(abs(c.time - 0.2) < 1e-12)
}

@Test func reducedMotionHalvesPlaybackOnly() {
    var c = SceneClock()
    c.reducedMotion = true
    c.advance(by: 0.2)
    #expect(abs(c.time - 0.1) < 1e-12)
    c.scrub(to: 5)
    #expect(c.time == 5, "scrubbing is not slowed")
    c.pause(); c.advance(by: 0.2)
    #expect(c.time == 5, "paused time is unaffected")
}

@Test func deterministicForTheSameDeltas() {
    let deltas = [0.016, 0.017, 0.4, 0.016, 0.033, 0.0]
    var a = SceneClock(speed: 1.5), b = SceneClock(speed: 1.5)
    for d in deltas { a.advance(by: d); b.advance(by: d) }
    #expect(a == b)
}
