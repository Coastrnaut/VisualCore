// SolarStateSchema2Tests — feature 104 (A14-P02) T-A14-206 (FR-A14-211, FR-A14-221, FR-A14-222; clarifications Q3–Q5;
// data-model "SolarState (schema 2)"). Host-free and short: the initial camera and date; date steps accepted and
// refused with their codes; yaw, tilt and zoom within their ranges and refused beyond; reset keeps the selection and
// date; the schema-2 round trip; schema 1 migrates; schema-2 payloads with a value off its range are refused.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct SolarStateSchema2Tests {
    @Test func theInitialStateIsTheOverviewAtJ2000() {
        let state = SolarState.initial
        #expect(state.dayOffset == 0 && state.yawSteps == 0 && state.pitchDegrees == 35 && state.zoomSteps == 0)
        #expect(state.cameraDistance == 60 && state.yawDegrees == 0)
        #expect(state.date.label == "2000-01-01")
    }

    @Test func dateStepsAreAcceptedOrRefusedWithTheirCodes() {
        var state = SolarState.initial
        #expect(state.stepDate(by: 365) == nil && state.dayOffset == 365)
        #expect(state.stepDate(by: -30) == nil && state.dayOffset == 335)
        let before = state
        let invalid: [Int] = [0, 2, 7, -31, 366, 1000]
        for days in invalid {
            #expect(state.stepDate(by: days) == .invalidStep, "step \(days)")
        }
        #expect(state == before)
        #expect(DateStepRefusal.invalidStep.rawValue == "a14.invalid-step")
        var end = SolarState(selection: 3, dayOffset: 18_627.5, yawSteps: 0, pitchDegrees: 35, zoomSteps: 0)!
        #expect(end.stepDate(by: 1) == .outOfRange && end.dayOffset == 18_627.5)
        #expect(DateStepRefusal.outOfRange.rawValue == "a14.out-of-range")
        var start = SolarState(selection: 3, dayOffset: -18_262.5, yawSteps: 0, pitchDegrees: 35, zoomSteps: 0)!
        #expect(start.stepDate(by: -1) == .outOfRange)
        #expect(start.stepDate(by: 1) == nil && start.dayOffset == -18_261.5)
    }

    @Test func forwardThenBackIsExact() {
        var state = SolarState.initial
        for _ in 0..<40 { #expect(state.stepDate(by: 365) == nil) }
        for _ in 0..<40 { #expect(state.stepDate(by: -365) == nil) }
        #expect(state == SolarState.initial)
    }

    @Test func cameraStepsStayInTheirRanges() {
        var state = SolarState.initial
        #expect(state.orbit(1) && state.yawDegrees == 15)
        #expect(state.orbit(-1) && state.orbit(-1) && state.yawDegrees == 345)
        #expect(!state.orbit(2) && !state.tilt(0) && !state.zoom(3))
        for _ in 0..<5 { let ok = state.tilt(1); #expect(ok) }
        #expect(state.pitchDegrees == 85 && !state.tilt(1))
        for _ in 0..<8 { let ok = state.tilt(-1); #expect(ok) }
        #expect(state.pitchDegrees == 5 && !state.tilt(-1))
        for _ in 0..<12 { let ok = state.zoom(1); #expect(ok) }
        #expect(state.zoomSteps == 12 && !state.zoom(1))
        #expect(state.cameraDistance > 4.1 && state.cameraDistance < 4.2)
        for _ in 0..<13 { let ok = state.zoom(-1); #expect(ok) }
        #expect(state.zoomSteps == -1 && !state.zoom(-1) && state.cameraDistance == 75)
    }

    @Test func resetKeepsSelectionAndDate() {
        var state = SolarState(selection: 4, dayOffset: 30, yawSteps: 5, pitchDegrees: 65, zoomSteps: 3)!
        state.resetView()
        #expect(state == SolarState(selection: 4, dayOffset: 30, yawSteps: 0, pitchDegrees: 35, zoomSteps: 0)!)
    }

    @Test func schema2RoundTripsAndSchema1Migrates() {
        let state = SolarState(selection: 2, dayOffset: -395, yawSteps: -3, pitchDegrees: 15, zoomSteps: 7)!
        #expect(SolarState.decode(state.encoded()) == .success(state))
        let old = Data(#"{"schema":1,"selection":6}"#.utf8)
        #expect(SolarState.decode(old) == .success(SolarState(selection: 6)))
        let migrated = try? JSONDecoder().decode(SolarState.self, from: old)
        #expect(migrated == SolarState(selection: 6))
    }

    @Test func schema2PayloadsOffTheirRangesAreRefused() {
        let outOfRange: [String] = [
            #"{"dayOffset":0,"pitchDegrees":35,"schema":2,"selection":9,"yawSteps":0,"zoomSteps":0}"#,
            #"{"dayOffset":20000,"pitchDegrees":35,"schema":2,"selection":1,"yawSteps":0,"zoomSteps":0}"#,
            #"{"dayOffset":0,"pitchDegrees":40,"schema":2,"selection":1,"yawSteps":0,"zoomSteps":0}"#,
            #"{"dayOffset":0,"pitchDegrees":95,"schema":2,"selection":1,"yawSteps":0,"zoomSteps":0}"#,
            #"{"dayOffset":0,"pitchDegrees":35,"schema":2,"selection":1,"yawSteps":0,"zoomSteps":13}"#,
        ]
        for payload in outOfRange {
            #expect(SolarState.decode(Data(payload.utf8)) == .failure(.outOfRange), "\(payload)")
        }
        let damaged: [String] = [
            #"{"schema":2,"selection":1}"#,
            #"{"dayOffset":"0","pitchDegrees":35,"schema":2,"selection":1,"yawSteps":0,"zoomSteps":0}"#,
        ]
        for payload in damaged {
            #expect(SolarState.decode(Data(payload.utf8)) == .failure(.damaged), "\(payload)")
        }
    }
}
