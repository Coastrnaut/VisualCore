// ArcadeAnnouncementsTests — feature 078 (A10-P04) T-A10-402 (FR-A10-420; clarification 4; research D4; edge case
// "VoiceOver announcements during a burst of events"). The announcement texts and their rate limit, host-free and
// short: "Hit, n lives left" (singular for one life), "Wave n", "Game over, score s", none for pickups, game over
// replaced by "New high score s", texts in cue order; the announcer posts at most one announcement per second over a
// simulated 600-step run with an event on every step and over a real simulated run, collapses a burst into its latest
// text (posted once the second has passed), and posts and holds nothing with VoiceOver off.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import NeonArcadeCore

@Suite struct ArcadeAnnouncementsTests {
    /// A cue of `kind` (position and caps do not matter to announcements).
    private func cue(_ kind: EffectCue.Kind) -> EffectCue {
        EffectCue(kind: kind, position: Vec2(0, 0), visual: true, sound: EffectCue.sound(for: kind))
    }

    /// A run with the given lives, wave and score.
    private func run(lives: Int = 2, wave: Int = 3, score: Int = 1_234, over: Bool = false) -> GameRun {
        var run = GameRun.new()
        run.lives = lives; run.wave = wave; run.score = score; run.over = over
        return run
    }

    @Test func textsForHitWaveAndGameOver() {
        #expect(ArcadeAnnouncements.texts(for: [cue(.hit)], run: run(lives: 2), newHighScore: false)
                == ["Hit, 2 lives left"])
        #expect(ArcadeAnnouncements.texts(for: [cue(.hit)], run: run(lives: 1), newHighScore: false)
                == ["Hit, 1 life left"])
        #expect(ArcadeAnnouncements.texts(for: [cue(.wave)], run: run(wave: 4), newHighScore: false) == ["Wave 4"])
        #expect(ArcadeAnnouncements.texts(for: [cue(.over)], run: run(lives: 0, score: 870, over: true),
                                          newHighScore: false) == ["Game over, score 870"])
    }

    @Test func pickupsAreNeverAnnounced() {
        #expect(ArcadeAnnouncements.texts(for: [cue(.pickup), cue(.pickup)], run: run(), newHighScore: true).isEmpty)
        #expect(ArcadeAnnouncements.text(for: .pickup, run: run(), newHighScore: false) == nil)
        #expect(ArcadeAnnouncements.announcementKind(for: .pickup) == nil)
    }

    @Test func aNewHighScoreReplacesGameOverAndCueOrderIsKept() {
        let final = run(lives: 0, wave: 5, score: 4_200, over: true)
        let cues = [cue(.pickup), cue(.hit), cue(.wave), cue(.over)]
        #expect(ArcadeAnnouncements.texts(for: cues, run: final, newHighScore: true)
                == ["Hit, 0 lives left", "Wave 5", "New high score 4200"])
        #expect(ArcadeAnnouncements.texts(for: cues, run: final, newHighScore: false)
                == ["Hit, 0 lives left", "Wave 5", "Game over, score 4200"])
        #expect(ArcadeAnnouncements.texts(for: [cue(.hit)], run: final, newHighScore: true) == ["Hit, 0 lives left"])
    }

    @Test func atMostOnePerSecondOverASixHundredStepBurst() {
        var announcer = ArcadeAnnouncer()
        var posted: [Announcement] = []
        for step in 0..<600 {
            let time = Double(step) / 60
            let kinds: [EffectCue.Kind] = step % 2 == 0 ? [.pickup, .hit, .wave] : [.hit]
            let current = run(lives: 1 + step % 3, wave: 1 + step / 60)
            if let announcement = announcer.update(cues: kinds.map(cue), run: current, newHighScore: false,
                                                   time: time) {
                posted.append(announcement)
            }
        }
        #expect(posted.count == 10)                              // 600 steps = 10 s
        for (earlier, later) in zip(posted, posted.dropFirst()) {
            #expect(later.time - earlier.time >= ArcadeAnnouncer.minimumInterval - 1e-9)
        }
        #expect(posted.first?.text == "Wave 1" && posted.first?.kind == .level)
        #expect(announcer.pending != nil)                         // the burst's latest text is held
    }

    @Test func aBurstCollapsesIntoItsLatestText() {
        var announcer = ArcadeAnnouncer()
        #expect(announcer.update(cues: [cue(.hit)], run: run(lives: 2), newHighScore: false, time: 0)?.text
                == "Hit, 2 lives left")
        #expect(announcer.update(cues: [cue(.hit)], run: run(lives: 1), newHighScore: false, time: 0.2) == nil)
        #expect(announcer.update(cues: [cue(.hit), cue(.over)], run: run(lives: 0, score: 90, over: true),
                                 newHighScore: true, time: 0.4) == nil)
        #expect(announcer.update(cues: [], run: run(), newHighScore: false, time: 0.9) == nil)
        let flushed = announcer.update(cues: [], run: run(), newHighScore: false, time: 1.0)
        #expect(flushed?.text == "New high score 90" && flushed?.kind == .outcome)
        #expect(announcer.update(cues: [], run: run(), newHighScore: false, time: 3) == nil)
        #expect(announcer.update(cues: [cue(.pickup)], run: run(), newHighScore: false, time: 4) == nil)
    }

    @Test func nothingIsPostedWithVoiceOverOff() {
        var announcer = ArcadeAnnouncer()
        announcer.enabled = false
        for step in 0..<120 {
            #expect(announcer.update(cues: [cue(.hit)], run: run(), newHighScore: false, time: Double(step) / 60) == nil)
        }
        #expect(announcer.pending == nil)
    }

    @Test func aRealSimulatedRunStaysWithinTheRate() {
        var game = GameRun.new()
        var random = SeededRandom(seed: 78)
        var announcer = ArcadeAnnouncer()
        var times: [Double] = []
        for step in 0..<600 {
            let previous = game
            GameSimulation.steer(&game, value: step % 120 < 60 ? -1 : 1)
            GameSimulation.advance(&game, catalog: .bundled, random: &random)
            let cues = ArcadeEffects.plan(previous: previous, current: game)
            if let announcement = announcer.update(cues: cues, run: game, newHighScore: false,
                                                   time: Double(step) / 60) {
                #expect(!announcement.text.isEmpty)
                times.append(announcement.time)
            }
        }
        #expect(times.count <= 10)
        for (earlier, later) in zip(times, times.dropFirst()) {
            #expect(later - earlier >= ArcadeAnnouncer.minimumInterval - 1e-9)
        }
    }
}
