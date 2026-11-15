// SolarStateSchema4Tests — feature 106 (A14-P04) T-A14-405 (FR-A14-401, FR-A14-402, FR-A14-411, FR-A14-430;
// clarifications Q1, Q2, Q5). The clock and the tour in the saved state: playing advances the date exactly by
// rate × steps / 120 and stops at the range end with the reason; a tour visits its stops and ends; pause, next and stop;
// a saved view applies and stops the tour; the schema-4 round trip; schema 3 migrates paused with no tour; invalid
// clock or tour values are refused.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct SolarStateSchema4Tests {
    @Test func theInitialStateIsPausedWithoutATour() {
        let state = SolarState.initial
        #expect(!state.playing && state.rateIndex == 0 && state.stopReason.isEmpty)
        #expect(state.tourIndex == -1 && state.tour == nil && state.tourCaption == nil)
    }

    @Test func playingAdvancesExactlyAndPausedDoesNot() {
        var state = SolarState.initial
        for _ in 0..<120 { state.advance() }
        #expect(state.dayOffset == 0, "paused: no motion")
        let rateSet = state.setRate(3)
        #expect(rateSet)
        state.setPlaying(true)
        for _ in 0..<120 { state.advance() }
        #expect(abs(state.dayOffset - 365) < 1e-9)
        let refused = state.setRate(4)
        #expect(!refused && state.rateIndex == 3)
    }

    @Test func playingStopsAtTheRangeEndWithTheReason() {
        var state = SolarState.initial
        let dateSet = state.setDate(18_627.0)
        #expect(dateSet)
        state.setRate(3)
        state.setPlaying(true)
        for _ in 0..<10 { state.advance() }
        #expect(state.dayOffset == 18_627.5 && !state.playing && state.stopReason == "end-of-range")
        state.setPlaying(true)
        #expect(state.stopReason.isEmpty, "playing clears the reason")
        let outside = state.setDate(20_000)
        #expect(!outside && state.dayOffset == 18_627.5)
    }

    @Test func aTourVisitsItsStopsAndEnds() {
        var state = SolarState.initial
        let started = state.startTour(0)
        let tour = Tour.bundled[0]
        #expect(started && state.tourIndex == 0 && state.selection == tour.stops[0].bodyIndex)
        #expect(state.tourCaption == tour.stops[0].caption)
        var visited: [Int] = [state.selection]
        for _ in 0..<tour.totalSteps {
            let before = state.tourStop
            state.advance()
            if state.tourIndex == 0 && state.tourStop != before { visited.append(state.selection) }
        }
        #expect(visited == tour.stops.map(\.bodyIndex))
        #expect(state.tourIndex == -1, "the tour ends by itself after its last stop")
    }

    @Test func pauseNextAndStop() {
        var state = SolarState.initial
        #expect(!state.nextTourStop() && !state.pauseTour(true), "no tour: refused")
        state.startTour(1)
        state.pauseTour(true)
        for _ in 0..<1_000 { state.advance() }
        #expect(state.tourStop == 0 && state.tourStep == 0, "a paused tour holds")
        state.pauseTour(false)
        state.nextTourStop()
        #expect(state.tourStop == 1 && state.selection == Tour.bundled[1].stops[1].bodyIndex)
        let restarted = state.startTour(0)
        #expect(restarted && state.tourIndex == 0 && state.tourStop == 0, "starting restarts")
        state.stopTour()
        #expect(state.tourIndex == -1 && state.selection == Tour.bundled[0].stops[0].bodyIndex)
    }

    @Test func aSavedViewAppliesAndStopsTheTour() throws {
        var state = SolarState.initial
        state.startTour(0)
        state.setPlaying(true)
        let view = try #require(SavedView(selection: 6, dayOffset: 400, rateIndex: 2, yawSteps: 3, pitchDegrees: 55,
                                          zoomSteps: 4, scaleMode: 1))
        state.apply(view)
        #expect(state.selection == 6 && state.dayOffset == 400 && state.rateIndex == 2 && state.yawSteps == 3)
        #expect(state.pitchDegrees == 55 && state.zoomSteps == 4 && state.scaleMode == .trueRelative)
        #expect(!state.playing && state.tourIndex == -1)
        #expect(state.savedView == view)
    }

    @Test func schema4RoundTripsAndSchema3Migrates() {
        var state = SolarState.initial
        state.startTour(1)
        state.setRate(2)
        state.setPlaying(true)
        for _ in 0..<5 { state.advance() }
        #expect(SolarState.decode(state.encoded()) == .success(state))
        let decoded = try? JSONDecoder().decode(SolarState.self, from: state.encoded())
        #expect(decoded == state)
        let v3 = Data(#"{"dayOffset":30,"pitchDegrees":45,"scaleMode":1,"schema":3,"selection":4,"yawSteps":1,"zoomSteps":2}"#.utf8)
        let expected = SolarState(selection: 4, dayOffset: 30, yawSteps: 1, pitchDegrees: 45, zoomSteps: 2,
                                  scaleMode: .trueRelative)!
        #expect(SolarState.decode(v3) == .success(expected))
        #expect(expected.tourIndex == -1 && !expected.playing)
    }

    @Test func invalidClockAndTourValuesAreRefused() {
        let base = SolarState.initial.encoded()
        let text = String(decoding: base, as: UTF8.self)
        let changes: [(String, String)] = [
            (#""rateIndex":0"#, #""rateIndex":4"#),
            (#""stopReason":"""#, #""stopReason":"bored""#),
            (#""tourIndex":-1"#, #""tourIndex":2"#),
            (#""tourStep":0"#, #""tourStep":3"#),
        ]
        for (from, to) in changes {
            let bad = Data(text.replacingOccurrences(of: from, with: to).utf8)
            #expect(SolarState.decode(bad) == .failure(.outOfRange), "\(to)")
        }
        let missing = Data(text.replacingOccurrences(of: #""playing":false,"#, with: "").utf8)
        #expect(SolarState.decode(missing) == .failure(.damaged))
    }
}
