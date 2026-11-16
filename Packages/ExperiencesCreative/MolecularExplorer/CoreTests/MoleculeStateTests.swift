// MoleculeStateTests — feature 110 (A15-P01) T-A15-105 (FR-A15-131; clarification Q5; data-model "MoleculeState"). The
// saved Molecular Explorer state, host-free and short: the initial state selects water; `select(_:)` accepts only
// 0…4; `next()` and `previous()` step through the five molecules and refuse a step past either end; the sorted-key JSON
// round trip is exact; damaged, newer and out-of-range payloads are refused with their reason. Updated for schema 2 by
// feature 111 (A15-P02) T-A15-204 (FR-A15-221): the state now also writes the mode and camera, schema 1 is still read
// (and migrated), and the newer schema is 3. Updated for schema 3 by feature 112 (A15-P03) T-A15-304 (FR-A15-330): the
// camera JSON also holds the pan, schemas 1 and 2 are read, and the newer schema is 4. Updated for schema 4 by feature
// 114 (A15-P05) T-A15-502: states are written at schema 4 (no import and no pending import omitted), and the newer
// schema is 5.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct MoleculeStateTests {
    @Test func theInitialStateSelectsWater() {
        let state = MoleculeState.initial
        #expect(state.selection == 0 && state.molecule?.id == "water")
        #expect(MoleculeState.schemaVersion == 4 && MoleculeState.moleculeCount == 5)
        #expect(MoleculeState(selection: 42).selection == 4 && MoleculeState(selection: -3).selection == 0)
    }

    @Test func selectingAcceptsOnlyTheFiveMolecules() {
        var state = MoleculeState.initial
        var accepted = state.select(4)
        #expect(accepted && state.molecule?.id == "caffeine")
        let before = state
        let refused: [Int] = [5, -1, 100, Int.max, Int.min]
        for index in refused {
            accepted = state.select(index)
            #expect(!accepted, "index \(index)")
        }
        #expect(state == before)
        for index in 0..<5 {
            accepted = state.select(index)
            #expect(accepted && state.selection == index && state.molecule == MoleculeLibrary.molecules[index])
        }
    }

    @Test func nextAndPreviousStepAndStopAtTheEnds() {
        var state = MoleculeState.initial
        var accepted = state.previous()
        #expect(!accepted && state.selection == 0, "previous at water is refused")
        var visited: [String] = [state.molecule?.id ?? ""]
        for _ in 0..<4 {
            accepted = state.next()
            #expect(accepted)
            visited.append(state.molecule?.id ?? "")
        }
        #expect(visited == ["water", "methane", "ethanol", "benzene", "caffeine"])
        accepted = state.next()
        #expect(!accepted && state.selection == 4, "next at caffeine is refused")
        accepted = state.previous()
        #expect(accepted && state.molecule?.id == "benzene")
    }

    @Test func theJSONRoundTripIsExactAndSorted() {
        let state = MoleculeState(selection: 3)
        let data = state.encoded()
        let expected = #"{"camera":{"panX":0,"panY":0,"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":4,"selection":3}"#
        #expect(String(decoding: data, as: UTF8.self) == expected)
        #expect(MoleculeState.decode(data) == .success(state))
        #expect(MoleculeState.decode(MoleculeState.initial.encoded()) == .success(MoleculeState.initial))
        let decoded = try? JSONDecoder().decode(MoleculeState.self, from: data)
        #expect(decoded == state)
    }

    @Test func damagedNewerAndOutOfRangePayloadsAreRefused() {
        let damaged: [String] = [
            "not json",
            "",
            #"{"schema":1,"selection":3"#,
            #"{"selection":3}"#,
            #"{"schema":"1","selection":3}"#,
            #"{"schema":0,"selection":3}"#,
            #"{"schema":-1,"selection":3}"#,
            #"{"schema":1}"#,
            #"{"schema":1,"selection":"3"}"#,
            #"{"schema":1,"selection":2.5}"#,
            "[]",
        ]
        for payload in damaged {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.damaged), "\(payload)")
        }
        let newer: [String] = [#"{"schema":5,"selection":3}"#, #"{"schema":9}"#]
        for payload in newer {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.newerVersion), "\(payload)")
        }
        let outOfRange: [String] = [#"{"schema":1,"selection":5}"#, #"{"schema":1,"selection":-1}"#]
        for payload in outOfRange {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.outOfRange), "\(payload)")
        }
        let invalid = try? JSONDecoder().decode(MoleculeState.self, from: Data(#"{"schema":1,"selection":7}"#.utf8))
        #expect(invalid == nil)
        #expect(MoleculeStateRefusal.allCases.map(\.rawValue) == ["damaged", "newer-version", "out-of-range"])
    }
}
