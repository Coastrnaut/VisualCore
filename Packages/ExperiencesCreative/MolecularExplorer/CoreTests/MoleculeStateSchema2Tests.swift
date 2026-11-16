// MoleculeStateSchema2Tests — feature 111 (A15-P02) T-A15-204 (FR-A15-221; clarification Q4; SC-A15-204). The state at
// schema 2, host-free and short: a state with a mode and a changed camera round-trips exactly; a schema-1 payload opens
// as ball-and-stick with the default camera; a newer schema is refused; damaged and out-of-range schema-2 payloads are
// refused with their reason; choosing a molecule resets the camera and keeps the mode; mode and camera changes keep the
// selection. Updated by feature 112 (A15-P03) T-A15-304 (FR-A15-330): states are written at schema 3 (camera with the
// pan), a schema-2 payload is still read, and the newer schema is 4.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct MoleculeStateSchema2Tests {
    @Test func aChangedStateRoundTrips() {
        var state = MoleculeState(selection: 3)
        state.setMode(.spaceFilling)
        state.turn(3)
        _ = state.tilt(1)
        _ = state.zoom(2)
        let data = state.encoded()
        let expected = #"{"camera":{"panX":0,"panY":0,"tilt":3,"turn":5,"zoom":2},"mode":1,"schema":3,"selection":3}"#
        #expect(String(decoding: data, as: UTF8.self) == expected)
        let v2 = Data(#"{"camera":{"tilt":3,"turn":5,"zoom":2},"mode":1,"schema":2,"selection":3}"#.utf8)
        #expect(MoleculeState.decode(v2) == .success(state))
        #expect(MoleculeState.decode(data) == .success(state))
        #expect((try? JSONDecoder().decode(MoleculeState.self, from: data)) == state)
    }

    @Test func aSchemaOnePayloadMigrates() {
        for index in 0..<5 {
            let data = Data(#"{"schema":1,"selection":\#(index)}"#.utf8)
            let expected = MoleculeState(selection: index, mode: .ballAndStick, camera: .default)
            #expect(MoleculeState.decode(data) == .success(expected))
            #expect((try? JSONDecoder().decode(MoleculeState.self, from: data)) == expected)
            #expect(MoleculeState.migrateV1(selection: index) == expected)
        }
        #expect(MoleculeState.migrateV1(selection: 5) == nil)
    }

    @Test func newerDamagedAndOutOfRangePayloadsAreRefused() {
        let newer: [String] = [#"{"schema":4,"selection":0,"mode":0,"camera":{"tilt":0,"turn":0,"zoom":0}}"#,
                               #"{"schema":42}"#]
        for payload in newer {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.newerVersion), "\(payload)")
        }
        let damaged: [String] = [
            #"{"schema":2,"selection":0}"#,
            #"{"schema":2,"selection":0,"mode":0}"#,
            #"{"schema":2,"selection":0,"camera":{"tilt":0,"turn":0,"zoom":0}}"#,
            #"{"schema":2,"selection":0,"mode":"0","camera":{"tilt":0,"turn":0,"zoom":0}}"#,
            #"{"schema":2,"selection":0,"mode":0,"camera":{"tilt":0,"turn":0}}"#,
            #"{"schema":2,"selection":0,"mode":0,"camera":{"tilt":0.5,"turn":0,"zoom":0}}"#,
            #"{"schema":2,"selection":0,"mode":0,"camera":[]}"#,
        ]
        for payload in damaged {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.damaged), "\(payload)")
        }
        let outOfRange: [String] = [
            #"{"schema":2,"selection":5,"mode":0,"camera":{"tilt":0,"turn":0,"zoom":0}}"#,
            #"{"schema":2,"selection":0,"mode":2,"camera":{"tilt":0,"turn":0,"zoom":0}}"#,
            #"{"schema":2,"selection":0,"mode":0,"camera":{"tilt":9,"turn":0,"zoom":0}}"#,
            #"{"schema":2,"selection":0,"mode":0,"camera":{"tilt":0,"turn":24,"zoom":0}}"#,
            #"{"schema":2,"selection":0,"mode":0,"camera":{"tilt":0,"turn":0,"zoom":-5}}"#,
        ]
        for payload in outOfRange {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.outOfRange), "\(payload)")
            #expect((try? JSONDecoder().decode(MoleculeState.self, from: Data(payload.utf8))) == nil)
        }
    }

    @Test func choosingAMoleculeResetsTheCameraAndKeepsTheMode() {
        var state = MoleculeState.initial
        state.setMode(.spaceFilling)
        state.turn(5)
        var accepted = state.tilt(-3)
        #expect(accepted && state.selection == 0 && state.mode == .spaceFilling)
        accepted = state.next()
        #expect(accepted && state.camera == .default && state.mode == .spaceFilling && state.selection == 1)
        _ = state.zoom(1)
        accepted = state.select(4)
        #expect(accepted && state.camera == .default && state.mode == .spaceFilling)
        _ = state.zoom(-1)
        accepted = state.previous()
        #expect(accepted && state.camera == .default && state.selection == 3)
        let before = state
        _ = state.zoom(1)
        let changed = state
        accepted = state.select(9)
        #expect(!accepted && state == changed && changed != before, "a refused choice changes nothing")
    }

    @Test func modeAndCameraChangesKeepTheSelection() {
        var state = MoleculeState(selection: 2)
        state.setMode(.spaceFilling)
        state.turn(-3)
        #expect(state.selection == 2 && state.camera.turnSteps == 23)
        var accepted = state.zoom(4)
        #expect(accepted)
        accepted = state.zoom(1)
        #expect(!accepted && state.camera.zoomSteps == 4)
        accepted = state.tilt(7)
        #expect(!accepted && state.camera.tiltSteps == 2)
        state.resetCamera()
        #expect(state.camera == .default && state.mode == .spaceFilling && state.selection == 2)
        #expect(state.scene == MoleculeScene(molecule: MoleculeLibrary.molecules[2], mode: .spaceFilling))
    }
}
