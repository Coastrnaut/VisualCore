// PlaybackStateTests — feature 033 T-A04-115 (spec edge cases: background, Reduce Motion; CHK017).
import Testing
@testable import VisualCoreSimulation

@Test func startsPlayingUnlessReduceMotionOrNoAutoplay() {
    #expect(PlaybackState(reduceMotion: false).isRunning)
    #expect(!PlaybackState(reduceMotion: true).isRunning)
    #expect(!PlaybackState(reduceMotion: false, autoplay: false).isRunning)
}

@Test func backgroundStopsAndForegroundResumesOnlyIfPlaying() {
    var playing = PlaybackState(reduceMotion: false)
    playing.enterBackground()
    #expect(!playing.isRunning && playing.wantsToPlay)
    playing.enterForeground()
    #expect(playing.isRunning)

    var paused = PlaybackState(reduceMotion: false)
    paused.pause()
    paused.enterBackground()
    paused.enterForeground()
    #expect(!paused.isRunning, "a paused scene stays paused after the background")
}

@Test func choicesInTheBackgroundApplyOnReturn() {
    var s = PlaybackState(reduceMotion: true)
    s.enterBackground()
    s.play()
    #expect(!s.isRunning, "nothing runs in the background")
    s.enterForeground()
    #expect(s.isRunning)
    s.toggle()
    #expect(!s.isRunning)
}
