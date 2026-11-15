// SolarStateTests — feature 103 (A14-P01) T-A14-102 (FR-A14-121; clarification Q5; data-model "SolarState"), adjusted
// for schema 2 by feature 104 (A14-P02) T-A14-206 (the schema-1 payloads below now migrate or stay refused). The saved
// Solar System Explorer state, host-free and short: the initial state selects the Sun; `select(_:)` accepts only 0…8;
// `next()` and `previous()` step through the nine bodies and refuse a step past either end; the selected body and its
// fact card follow the selection; the sorted-key JSON round trip is exact; damaged, newer and out-of-range payloads are
// refused with their reason.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct SolarStateTests {
    @Test func theInitialStateSelectsTheSun() {
        let state = SolarState.initial
        #expect(state.selection == 0 && state.body.id == "sun" && state.factCard.name == "Sun")
        #expect(SolarState.schemaVersion == 3 && SolarState.bodyCount == 9)
        #expect(SolarState(selection: 42).selection == 8 && SolarState(selection: -3).selection == 0)
    }

    @Test func selectingAcceptsOnlyTheNineBodies() {
        var state = SolarState.initial
        var accepted = state.select(5)
        #expect(accepted && state.body.id == "jupiter" && state.factCard.bodyID == "jupiter")
        let before = state
        let refused: [Int] = [9, -1, 100, Int.max, Int.min]
        for index in refused {
            accepted = state.select(index)
            #expect(!accepted, "index \(index)")
        }
        #expect(state == before)
        for index in 0..<9 {
            accepted = state.select(index)
            #expect(accepted && state.selection == index && state.body == BodyCatalog.bundled.bodies[index])
        }
    }

    @Test func nextAndPreviousStepAndStopAtTheEnds() {
        var state = SolarState.initial
        var accepted = state.previous()
        #expect(!accepted && state.selection == 0, "previous at the Sun is refused")
        var visited: [String] = [state.body.id]
        for _ in 0..<8 {
            accepted = state.next()
            #expect(accepted)
            visited.append(state.body.id)
        }
        #expect(visited == BodyCatalog.bundled.bodies.map(\.id))
        accepted = state.next()
        #expect(!accepted && state.selection == 8, "next at Neptune is refused")
        accepted = state.previous()
        #expect(accepted && state.body.id == "uranus")
    }

    @Test func theJSONRoundTripIsExactAndSorted() {
        let state = SolarState(selection: 3)
        let data = state.encoded()
        #expect(String(decoding: data, as: UTF8.self)
                == #"{"dayOffset":0,"pitchDegrees":35,"scaleMode":0,"schema":3,"selection":3,"yawSteps":0,"zoomSteps":0}"#)
        #expect(SolarState.decode(data) == .success(state))
        #expect(SolarState.decode(SolarState.initial.encoded()) == .success(SolarState.initial))
    }

    @Test func damagedNewerAndOutOfRangePayloadsAreRefused() {
        let damaged: [String] = [
            "not json",
            #"{"schema":1,"selection":3"#,
            #"{"selection":3}"#,
            #"{"schema":"1","selection":3}"#,
            #"{"schema":0,"selection":3}"#,
            #"{"schema":1}"#,
            #"{"schema":1,"selection":"3"}"#,
            #"{"schema":1,"selection":2.5}"#,
            "[]",
        ]
        for payload in damaged {
            #expect(SolarState.decode(Data(payload.utf8)) == .failure(.damaged), "\(payload)")
        }
        let newer: [String] = [#"{"schema":4,"selection":3}"#, #"{"schema":9}"#]
        for payload in newer {
            #expect(SolarState.decode(Data(payload.utf8)) == .failure(.newerVersion), "\(payload)")
        }
        let outOfRange: [String] = [#"{"schema":1,"selection":9}"#, #"{"schema":1,"selection":-1}"#]
        for payload in outOfRange {
            #expect(SolarState.decode(Data(payload.utf8)) == .failure(.outOfRange), "\(payload)")
        }
        #expect(SolarStateRefusal.allCases.map(\.rawValue) == ["damaged", "newer-version", "out-of-range"])
    }
}
