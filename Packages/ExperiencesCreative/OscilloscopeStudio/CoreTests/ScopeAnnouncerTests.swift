// ScopeAnnouncerTests — feature 065 (A08-P05) T-A08-503 (FR-A08-520; SC-A08-503). The announcer speaks only while
// VoiceOver runs, never twice within 1.5 s (injected times, no sleeping), never repeats the last text, holds the latest
// text offered inside the interval for `tick(at:)`, and its text builders use plain words.
import Foundation
import Testing
import OscilloscopeStudioCore

@Suite struct ScopeAnnouncerTests {
    @Test func theIntervalIsOneAndAHalfSeconds() {
        #expect(ScopeAnnouncer.interval == 1.5)
    }

    @Test func nothingWithoutVoiceOver() {
        var announcer = ScopeAnnouncer(voiceOverRunning: false)
        #expect(announcer.announce("Frozen", at: 0) == false)
        #expect(announcer.announce("XY view", at: 10) == false)
        #expect(announcer.tick(at: 20) == nil)
        #expect(announcer.lastAnnounced == nil)
        #expect(announcer.pending == nil)
    }

    @Test func turningVoiceOverOffDropsThePendingText() {
        var announcer = ScopeAnnouncer(voiceOverRunning: true)
        #expect(announcer.announce("Frozen", at: 0) == true)
        #expect(announcer.announce("Live again", at: 0.5) == false)
        #expect(announcer.pending == "Live again")
        announcer.voiceOverRunning = false
        #expect(announcer.pending == nil)
        #expect(announcer.tick(at: 5) == nil)
    }

    @Test func theFirstOfferAnnounces() {
        var announcer = ScopeAnnouncer(voiceOverRunning: true)
        #expect(announcer.announce("Waveform view", at: 3) == true)
        #expect(announcer.lastAnnounced == "Waveform view")
        #expect(announcer.lastTime == 3)
    }

    @Test func announcementsAreNeverCloserThanTheInterval() {
        var announcer = ScopeAnnouncer(voiceOverRunning: true)
        var times: [Double] = []
        let texts = ["Clipping", "Clipping ended", "Trigger lost", "Trigger found", "XY view", "Frozen", "Live again"]
        // Rapid changes every 0.1 s for 6 s, ticking every frame-ish step.
        for step in 0..<60 {
            let time = Double(step) * 0.1
            if announcer.announce(texts[step % texts.count], at: time) { times.append(time) }
            if announcer.tick(at: time + 0.05) != nil { times.append(time + 0.05) }
        }
        #expect(times.count >= 3)
        for (a, b) in zip(times, times.dropFirst()) {
            #expect(b - a >= ScopeAnnouncer.interval - 1e-9)
        }
    }

    @Test func aTextInsideTheIntervalWaitsForTick() {
        var announcer = ScopeAnnouncer(voiceOverRunning: true)
        #expect(announcer.announce("Frozen", at: 0) == true)
        #expect(announcer.announce("Clipping", at: 0.4) == false)
        #expect(announcer.announce("Trigger lost", at: 0.8) == false)
        #expect(announcer.pending == "Trigger lost")
        #expect(announcer.tick(at: 1.4) == nil)
        #expect(announcer.tick(at: 1.5) == "Trigger lost")
        #expect(announcer.lastAnnounced == "Trigger lost")
        #expect(announcer.pending == nil)
    }

    @Test func theLastTextIsNotRepeated() {
        var announcer = ScopeAnnouncer(voiceOverRunning: true)
        #expect(announcer.announce("Frozen", at: 0) == true)
        #expect(announcer.announce("Frozen", at: 5) == false)
        #expect(announcer.announce("Live again", at: 5.5) == true)
        #expect(announcer.announce("Live again", at: 5.6) == false)
        #expect(announcer.announce("Frozen", at: 5.7) == false)
        #expect(announcer.pending == "Frozen")
        #expect(announcer.announce("Live again", at: 5.8) == false)
        #expect(announcer.pending == nil)
    }

    @Test func emptyTextAndNonFiniteTimesAreIgnored() {
        var announcer = ScopeAnnouncer(voiceOverRunning: true)
        #expect(announcer.announce("", at: 0) == false)
        #expect(announcer.announce("Frozen", at: .nan) == false)
        #expect(announcer.announce("Frozen", at: .infinity) == false)
        #expect(announcer.lastAnnounced == nil)
    }

    @Test func resetForgetsEverything() {
        var announcer = ScopeAnnouncer(voiceOverRunning: true)
        #expect(announcer.announce("Frozen", at: 0) == true)
        #expect(announcer.announce("Clipping", at: 0.2) == false)
        announcer.reset()
        #expect(announcer.lastAnnounced == nil && announcer.lastTime == nil && announcer.pending == nil)
        #expect(announcer.voiceOverRunning)
        #expect(announcer.announce("Frozen", at: 0.3) == true)
    }

    @Test func textBuildersUsePlainWords() {
        #expect(ScopeAnnouncer.viewChanged(.waveform) == "Waveform view")
        #expect(ScopeAnnouncer.viewChanged(.xy) == "XY view")
        #expect(ScopeAnnouncer.viewChanged(.spectrum) == "Spectrum view")
        #expect(ScopeAnnouncer.freeze(true) == "Frozen")
        #expect(ScopeAnnouncer.freeze(false) == "Live again")
        #expect(ScopeAnnouncer.trigger(locked: false) == "Trigger lost")
        #expect(ScopeAnnouncer.trigger(locked: true) == "Trigger found")
        #expect(ScopeAnnouncer.clipping(true) == "Clipping")
        #expect(ScopeAnnouncer.clipping(false) == "Clipping ended")
        #expect(ScopeAnnouncer.channels(0) == "No input channels")
        #expect(ScopeAnnouncer.channels(1).contains("XY needs two channels"))
        #expect(ScopeAnnouncer.channels(2) == "Input has two channels")
        #expect(ScopeAnnouncer.channels(4) == "Input has 4 channels")
    }
}
