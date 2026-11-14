// JourneyAnnouncerTests — feature 058 (A07-P05) T-A07-503 (FR-A07-520; SC-A07-504). The announcer speaks the first
// text at once, never repeats the last text, holds a changed text offered inside the 1.5 s interval and announces it
// by `tick(at:)` once the interval has passed (only the latest pending text survives), ignores empty text and
// non-finite times, and forgets everything on `reset()`.
import Foundation
import Testing
import AudioOdysseyCore

@Suite struct JourneyAnnouncerTests {
    @Test func theIntervalIsOneAndAHalfSeconds() {
        #expect(JourneyAnnouncer.interval == 1.5)
    }

    @Test func theFirstOfferAnnounces() {
        var announcer = JourneyAnnouncer()
        #expect(announcer.offer("World: Tunnel", at: 0) == "World: Tunnel")
        #expect(announcer.lastAnnounced == "World: Tunnel")
        #expect(announcer.pending == nil)
    }

    @Test func theSameTextIsNotRepeated() {
        var announcer = JourneyAnnouncer()
        _ = announcer.offer("Paused", at: 0)
        #expect(announcer.offer("Paused", at: 0.5) == nil)
        #expect(announcer.offer("Paused", at: 10) == nil)
        #expect(announcer.tick(at: 20) == nil)
    }

    @Test func aChangeInsideTheIntervalWaitsForTheTick() {
        var announcer = JourneyAnnouncer()
        _ = announcer.offer("World: Tunnel", at: 0)
        #expect(announcer.offer("World: Landscape", at: 0.4) == nil)
        #expect(announcer.pending == "World: Landscape")
        #expect(announcer.tick(at: 1.0) == nil)              // 1.0 s < 1.5 s
        #expect(announcer.tick(at: 1.5) == "World: Landscape")
        #expect(announcer.pending == nil)
        #expect(announcer.tick(at: 5) == nil)                // nothing left
        #expect(announcer.offer("World: Star corridor", at: 2.0) == nil)   // 0.5 s after the tick's announcement
        #expect(announcer.offer("World: Star corridor", at: 3.0) == "World: Star corridor")
    }

    @Test func onlyTheLatestPendingTextSurvives() {
        var announcer = JourneyAnnouncer()
        _ = announcer.offer("World: Tunnel", at: 0)
        #expect(announcer.offer("Source: Microphone", at: 0.2) == nil)
        #expect(announcer.offer("Source: Demo", at: 0.6) == nil)
        #expect(announcer.offer("Preset applied: Calm", at: 1.0) == nil)
        #expect(announcer.pending == "Preset applied: Calm")
        #expect(announcer.tick(at: 1.6) == "Preset applied: Calm")
        #expect(announcer.tick(at: 4) == nil)
    }

    @Test func returningToTheLastTextDropsThePending() {
        var announcer = JourneyAnnouncer()
        _ = announcer.offer("Paused", at: 0)
        #expect(announcer.offer("Playing", at: 0.3) == nil)
        #expect(announcer.offer("Paused", at: 0.6) == nil)
        #expect(announcer.pending == nil)
        #expect(announcer.tick(at: 3) == nil)
    }

    @Test func emptyTextAndNonFiniteTimesAreIgnored() {
        var announcer = JourneyAnnouncer()
        #expect(announcer.offer("", at: 0) == nil)
        #expect(announcer.offer("World: Tunnel", at: .nan) == nil)
        #expect(announcer.offer("World: Tunnel", at: .infinity) == nil)
        #expect(announcer == JourneyAnnouncer())
        _ = announcer.offer("World: Tunnel", at: 0)
        _ = announcer.offer("World: Landscape", at: 0.1)
        #expect(announcer.tick(at: .nan) == nil)
        #expect(announcer.pending == "World: Landscape")
    }

    @Test func resetForgetsEverything() {
        var announcer = JourneyAnnouncer()
        _ = announcer.offer("World: Tunnel", at: 0)
        _ = announcer.offer("World: Landscape", at: 0.1)
        announcer.reset()
        #expect(announcer == JourneyAnnouncer())
        #expect(announcer.offer("World: Tunnel", at: 0.2) == "World: Tunnel")
    }
}
