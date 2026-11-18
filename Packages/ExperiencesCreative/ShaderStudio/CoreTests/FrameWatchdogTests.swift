// FrameWatchdogTests — feature 162 (A22-P04) T-A22-403 (FR-A22-403; SC-A22-402; clarification Q2). Intervals are
// fed by hand; no slow frame is drawn: 8 slow intervals stop the watchdog; 7 slow then a normal one do not; a single
// long interval counts once; non-finite and non-positive intervals are ignored; the interval after `rearm` is
// skipped; `reset` returns to watching.
import Testing
@testable import ShaderStudioCore

@Suite struct FrameWatchdogTests {
    static let slow = 0.3
    static let normal = 1.0 / 30.0

    @Test func eightSlowIntervalsStop() {
        var watchdog = FrameWatchdog()
        for _ in 0..<7 { #expect(watchdog.record(Self.slow) == .watching) }
        #expect(watchdog.record(Self.slow) == .stopped)
        #expect(watchdog.record(Self.normal) == .stopped, "stays stopped until reset")
    }

    @Test func sevenSlowThenNormalDoNotStop() {
        var watchdog = FrameWatchdog()
        for _ in 0..<7 { watchdog.record(Self.slow) }
        #expect(watchdog.record(Self.normal) == .watching)
        #expect(watchdog.slowCount == 0)
        #expect(watchdog.record(FrameWatchdog.limit) == .watching, "the limit itself is not slow")
    }

    @Test func aSingleLongIntervalCountsOnce() {
        var watchdog = FrameWatchdog()
        #expect(watchdog.record(30.0) == .watching)
        #expect(watchdog.slowCount == 1)
    }

    @Test func nonFiniteAndNonPositiveAreIgnored() {
        var watchdog = FrameWatchdog()
        for _ in 0..<7 { watchdog.record(Self.slow) }
        for bad in [Double.nan, .infinity, -.infinity, 0, -1] { #expect(watchdog.record(bad) == .watching) }
        #expect(watchdog.slowCount == 7)
        #expect(watchdog.record(Self.slow) == .stopped)
    }

    @Test func intervalAfterRearmIsSkipped() {
        var watchdog = FrameWatchdog()
        for _ in 0..<7 { watchdog.record(Self.slow) }
        watchdog.rearm()
        watchdog.record(.nan)
        #expect(watchdog.record(5.0) == .watching, "skipped")
        #expect(watchdog.slowCount == 7)
        #expect(watchdog.record(Self.slow) == .stopped)
    }

    @Test func resetReturnsToWatching() {
        var watchdog = FrameWatchdog()
        for _ in 0..<8 { watchdog.record(Self.slow) }
        #expect(watchdog.state == .stopped)
        watchdog.reset()
        #expect(watchdog.state == .watching)
        #expect(watchdog.slowCount == 0)
        #expect(watchdog.record(Self.slow) == .watching, "the first interval after reset is skipped")
        #expect(watchdog.slowCount == 0)
        #expect(FrameWatchdog.limit == 0.25)
        #expect(FrameWatchdog.window == 8)
    }
}
