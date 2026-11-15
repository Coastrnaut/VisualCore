// SolarStateSchema3Tests — feature 105 (A14-P03) T-A14-305 (FR-A14-310, FR-A14-330; clarification Q3). The scale mode
// in the saved state: the initial mode is enhanced; switching keeps everything else; reset keeps the mode; the schema-3
// round trip; schema 2 and schema 1 migrate with the enhanced mode; a mode other than 0 or 1 is refused.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct SolarStateSchema3Tests {
    @Test func theInitialModeIsEnhancedAndSwitchingKeepsTheRest() {
        var state = SolarState.initial
        #expect(state.scaleMode == .enhanced)
        let accepted = state.stepDate(by: 30)
        #expect(accepted == nil)
        state.setScaleMode(.trueRelative)
        #expect(state.scaleMode == .trueRelative && state.dayOffset == 30 && state.selection == 0)
        state.resetView()
        #expect(state.scaleMode == .trueRelative, "reset keeps the scale mode")
    }

    @Test func theScaleModeRoundTripsWithSortedKeys() {
        let state = SolarState(selection: 6, dayOffset: 365, yawSteps: 2, pitchDegrees: 45, zoomSteps: 3,
                               scaleMode: .trueRelative)!
        let text = String(decoding: state.encoded(), as: UTF8.self)
        #expect(text.contains(#""scaleMode":1,"schema":4,"selection":6,"#), "schema 4 writes the scale mode (A14-P04)")
        #expect(SolarState.decode(state.encoded()) == .success(state))
        let decoded = try? JSONDecoder().decode(SolarState.self, from: state.encoded())
        #expect(decoded == state)
    }

    @Test func schema2And1MigrateWithTheEnhancedMode() {
        let v2 = Data(#"{"dayOffset":30,"pitchDegrees":45,"schema":2,"selection":4,"yawSteps":1,"zoomSteps":2}"#.utf8)
        let expected = SolarState(selection: 4, dayOffset: 30, yawSteps: 1, pitchDegrees: 45, zoomSteps: 2)!
        #expect(SolarState.decode(v2) == .success(expected))
        #expect(expected.scaleMode == .enhanced)
        let viaCodable = try? JSONDecoder().decode(SolarState.self, from: v2)
        #expect(viaCodable == expected)
        let v1 = Data(#"{"schema":1,"selection":2}"#.utf8)
        #expect(SolarState.decode(v1) == .success(SolarState(selection: 2)))
    }

    @Test func anUnknownModeIsRefused() {
        let bad = Data(#"{"dayOffset":0,"pitchDegrees":35,"scaleMode":2,"schema":3,"selection":1,"yawSteps":0,"zoomSteps":0}"#.utf8)
        #expect(SolarState.decode(bad) == .failure(.outOfRange))
        let missing = Data(#"{"dayOffset":0,"pitchDegrees":35,"schema":3,"selection":1,"yawSteps":0,"zoomSteps":0}"#.utf8)
        #expect(SolarState.decode(missing) == .failure(.damaged))
        let newer = Data(#"{"schema":5,"selection":1}"#.utf8)
        #expect(SolarState.decode(newer) == .failure(.newerVersion))
        #expect((try? JSONDecoder().decode(SolarState.self, from: bad)) == nil)
    }
}
