// AquariumAnnouncerTests — feature 071 (A09-P04) T-A09-404 (FR-A09-421; SC-A09-405). The announcer: interval 3 s;
// the first offer speaks; an offer within 3 s is held and the latest held offer wins; `tick` releases it once the
// interval has passed, exactly once; a repeated sentence after the interval speaks again; with VoiceOver off nothing
// is spoken or held (and turning VoiceOver off drops the held text); `reset` forgets everything. Host-free and short.
import DigitalAquariumCore
import Testing

@Suite struct AquariumAnnouncerTests {
    @Test func theIntervalIsThreeSeconds() {
        #expect(AquariumAnnouncer.interval == 3.0)
    }

    @Test func theFirstAnnouncementSpeaksAndTheNextWithinTheIntervalWaits() {
        var announcer = AquariumAnnouncer(voiceOverRunning: true)
        let r1 = announcer.announce("Food dropped", at: 10)
        #expect(r1)
        #expect(announcer.lastAnnounced == "Food dropped" && announcer.lastTime == 10)
        let r2 = announcer.announce("Decoration added", at: 11)
        #expect(!r2)
        #expect(announcer.pending == "Decoration added")
        #expect(announcer.lastAnnounced == "Food dropped")
    }

    @Test func theLatestPendingTextWinsAndTickReleasesItOnce() {
        var announcer = AquariumAnnouncer(voiceOverRunning: true)
        let r3 = announcer.announce("Food dropped", at: 0)
        #expect(r3)
        let r4 = announcer.announce("Decoration added", at: 1)
        #expect(!r4)
        let r5 = announcer.announce("Paused", at: 2)
        #expect(!r5)
        #expect(announcer.pending == "Paused")
        let r6 = announcer.tick(at: 2.999)
        #expect(r6 == nil)
        let r7 = announcer.tick(at: 3)
        #expect(r7 == "Paused")
        #expect(announcer.lastAnnounced == "Paused" && announcer.lastTime == 3 && announcer.pending == nil)
        let r8 = announcer.tick(at: 10)
        #expect(r8 == nil)
    }

    @Test func anAnnouncementAfterTheIntervalSpeaksAgainEvenWhenRepeated() {
        var announcer = AquariumAnnouncer(voiceOverRunning: true)
        let r9 = announcer.announce("Food dropped", at: 0)
        #expect(r9)
        let r10 = announcer.announce("Food dropped", at: 3)
        #expect(r10)
        let r11 = announcer.announce("Food dropped", at: 4)
        #expect(!r11)
        let r12 = announcer.tick(at: 6)
        #expect(r12 == "Food dropped")
    }

    @Test func withVoiceOverOffNothingIsSpokenOrHeld() {
        var announcer = AquariumAnnouncer(voiceOverRunning: false)
        let r13 = announcer.announce("Food dropped", at: 0)
        #expect(!r13)
        #expect(announcer.lastAnnounced == nil && announcer.pending == nil)
        let r14 = announcer.tick(at: 10)
        #expect(r14 == nil)

        var running = AquariumAnnouncer(voiceOverRunning: true)
        let r15 = running.announce("Food dropped", at: 0)
        #expect(r15)
        let r16 = running.announce("Paused", at: 1)
        #expect(!r16)
        running.voiceOverRunning = false
        #expect(running.pending == nil)
        let r17 = running.tick(at: 5)
        #expect(r17 == nil)
    }

    @Test func emptyTextAndNonFiniteTimesAreIgnored() {
        var announcer = AquariumAnnouncer(voiceOverRunning: true)
        let r18 = announcer.announce("", at: 0)
        #expect(!r18)
        let r19 = announcer.announce("Paused", at: .nan)
        #expect(!r19)
        #expect(announcer.lastAnnounced == nil && announcer.pending == nil)
    }

    @Test func resetForgetsTheLastAndThePendingText() {
        var announcer = AquariumAnnouncer(voiceOverRunning: true)
        let r20 = announcer.announce("Food dropped", at: 0)
        #expect(r20)
        let r21 = announcer.announce("Paused", at: 1)
        #expect(!r21)
        announcer.reset()
        #expect(announcer == AquariumAnnouncer(voiceOverRunning: true))
        let r22 = announcer.tick(at: 5)
        #expect(r22 == nil)
        let r23 = announcer.announce("Swimming", at: 1.5)
        #expect(r23)
    }
}
