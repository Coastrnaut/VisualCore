// MoleculeStateSchema3Tests — feature 112 (A15-P03) T-A15-304 (FR-A15-302, FR-A15-311, FR-A15-330; clarifications Q2,
// Q3, Q5; SC-A15-304). The state at schema 3, host-free and short: a panned state with a selected atom round-trips
// exactly (the `atom` key only when an atom is selected; null reads as none); schema-1 and schema-2 payloads open with no
// selected atom and no pan, and the migration steps for the adapter write the schema-2 and schema-3 JSON; a newer schema
// is refused; an atom outside the molecule or a pan outside −10…10 is out of range; next, previous and clear follow
// their rules; choosing a molecule clears the atom and the pan and keeps the mode; changing the mode keeps both.
// Updated by feature 114 (A15-P05) T-A15-502: states are written at schema 4 (schema-3 payloads are still read), the
// step 2 → 3 writes the schema-3 JSON, and the newer schema is 5.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct MoleculeStateSchema3Tests {
    @Test func aPannedStateWithAnAtomRoundTrips() {
        var state = MoleculeState(selection: 4)
        state.setMode(.spaceFilling)
        var accepted = state.pan(dx: 1, dy: 0)
        accepted = accepted && state.pan(dx: 1, dy: 1)
        accepted = accepted && state.selectAtom(3)
        #expect(accepted && state.selectedAtom == 3 && state.camera.panX == 2 && state.camera.panY == 1)
        let data = state.encoded()
        let expected = #"{"atom":3,"camera":{"panX":2,"panY":1,"tilt":2,"turn":2,"zoom":0},"mode":1,"schema":4,"selection":4}"#
        #expect(String(decoding: data, as: UTF8.self) == expected)
        #expect(MoleculeState.decode(data) == .success(state))
        #expect((try? JSONDecoder().decode(MoleculeState.self, from: data)) == state)
        let none = #"{"camera":{"panX":0,"panY":0,"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":4,"selection":0}"#
        #expect(String(decoding: MoleculeState.initial.encoded(), as: UTF8.self) == none)
        let null = #"{"atom":null,"camera":{"panX":0,"panY":0,"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":3,"selection":0}"#
        #expect(MoleculeState.decode(Data(null.utf8)) == .success(MoleculeState.initial))
        #expect(MoleculeState.schemaVersion == 4 && MoleculeState.oldestSchemaVersion == 1)
    }

    @Test func olderPayloadsOpenWithNoAtomAndNoPan() {
        let v1 = Data(#"{"schema":1,"selection":4}"#.utf8)
        let v2 = Data(#"{"camera":{"panX":4,"tilt":3,"turn":5,"zoom":2},"mode":1,"schema":2,"selection":4}"#.utf8)
        let fromV2 = MoleculeState(selection: 4, mode: .spaceFilling,
                                   camera: CameraSettings(turnSteps: 5, tiltSteps: 3, zoomSteps: 2))
        #expect(MoleculeState.decode(v1) == .success(MoleculeState(selection: 4)))
        #expect(MoleculeState.decode(v2) == .success(fromV2))
        #expect((try? JSONDecoder().decode(MoleculeState.self, from: v2)) == fromV2)
        for state in [MoleculeState(selection: 4), fromV2] {
            #expect(state.selectedAtom == nil && state.camera.panX == 0 && state.camera.panY == 0)
        }
        #expect(MoleculeState.migrateV2(selection: 4, mode: 1, camera: (5, 3, 2)) == fromV2)
        #expect(MoleculeState.migrateV2(selection: 4, mode: 2, camera: (5, 3, 2)) == nil)
        let step1 = MoleculeState.upgradePayload(v1, from: 1).map { String(decoding: $0, as: UTF8.self) }
        #expect(step1 == .success(#"{"camera":{"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":2,"selection":4}"#))
        #expect(MoleculeState.upgradePayload(v2, from: 2).map { String(decoding: $0, as: UTF8.self) }
                == .success(#"{"camera":{"panX":0,"panY":0,"tilt":3,"turn":5,"zoom":2},"mode":1,"schema":3,"selection":4}"#))
        #expect(MoleculeState.upgradePayload(v1, from: 2) == .failure(.damaged))
        #expect(MoleculeState.upgradePayload(fromV2.encoded(), from: 3) == .failure(.damaged), "a schema-4 payload")
        #expect(MoleculeState.upgradePayload(Data(#"{"schema":1,"selection":5}"#.utf8), from: 1) == .failure(.outOfRange))
        #expect(MoleculeState.upgradePayload(Data(#"{"schema":2,"selection":1}"#.utf8), from: 2) == .failure(.damaged))
    }

    @Test func newerDamagedAndOutOfRangePayloadsAreRefused() {
        let camera = #""camera":{"panX":0,"panY":0,"tilt":2,"turn":2,"zoom":0}"#
        let newer: [String] = [#"{"atom":0,\#(camera),"mode":0,"schema":5,"selection":0}"#, #"{"schema":5}"#]
        for payload in newer {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.newerVersion), "\(payload)")
        }
        let damaged: [String] = [
            #"{"schema":3,"selection":0,"mode":0}"#,
            #"{"schema":3,"selection":0,"mode":0,"camera":{"tilt":2,"turn":2,"zoom":0}}"#,
            #"{"schema":3,"selection":0,"mode":0,"camera":{"panX":0,"tilt":2,"turn":2,"zoom":0}}"#,
            #"{"atom":"3",\#(camera),"mode":0,"schema":3,"selection":4}"#,
            #"{"atom":2.5,\#(camera),"mode":0,"schema":3,"selection":4}"#,
            #"{"camera":{"panX":0.5,"panY":0,"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":3,"selection":4}"#,
        ]
        for payload in damaged {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.damaged), "\(payload)")
        }
        let outOfRange: [String] = [
            #"{"atom":24,\#(camera),"mode":0,"schema":3,"selection":4}"#,
            #"{"atom":3,\#(camera),"mode":0,"schema":3,"selection":0}"#,
            #"{"atom":-1,\#(camera),"mode":0,"schema":3,"selection":4}"#,
            #"{"camera":{"panX":11,"panY":0,"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":3,"selection":4}"#,
            #"{"camera":{"panX":0,"panY":-11,"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":3,"selection":4}"#,
            #"{\#(camera),"mode":0,"schema":3,"selection":5}"#,
        ]
        for payload in outOfRange {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.outOfRange), "\(payload)")
            #expect((try? JSONDecoder().decode(MoleculeState.self, from: Data(payload.utf8))) == nil)
        }
        #expect(MoleculeState(selection: 0, selectedAtom: 3).selectedAtom == nil)
        #expect(MoleculeState(selection: 4, selectedAtom: 23).selectedAtom == 23)
    }

    @Test func atomStepsFollowTheirRules() {
        var state = MoleculeState(selection: 0)
        #expect(state.atomCount == 3)
        var accepted = state.clearAtom()
        #expect(!accepted && state.selectedAtom == nil, "clear with nothing selected is refused")
        accepted = state.nextAtom()
        #expect(accepted && state.selectedAtom == 0, "next with none selects the first")
        accepted = state.previousAtom()
        #expect(!accepted && state.selectedAtom == 0, "previous at atom 0 is refused")
        accepted = state.nextAtom() && state.nextAtom()
        #expect(accepted && state.selectedAtom == 2)
        accepted = state.nextAtom()
        #expect(!accepted && state.selectedAtom == 2, "next at the last atom is refused")
        accepted = state.clearAtom()
        #expect(accepted && state.selectedAtom == nil)
        accepted = state.previousAtom()
        #expect(accepted && state.selectedAtom == 2, "previous with none selects the last")
        let before = state
        let refused: [Int] = [3, -1, 499, Int.max, Int.min]
        for index in refused {
            accepted = state.selectAtom(index)
            #expect(!accepted, "atom \(index)")
        }
        #expect(state == before)
        accepted = state.selectAtom(1)
        #expect(accepted && state.selectedAtom == 1)
    }

    @Test func choosingAMoleculeClearsTheAtomAndPanButKeepsTheMode() {
        var state = MoleculeState(selection: 3)
        state.setMode(.spaceFilling)
        var accepted = state.selectAtom(5) && state.pan(dx: -1, dy: 1)
        #expect(accepted)
        state.setMode(.ballAndStick)
        #expect(state.selectedAtom == 5 && state.camera.panX == -1 && state.camera.panY == 1, "mode keeps both")
        state.resetCamera()
        #expect(state.camera == .default && state.selectedAtom == 5, "reset view zeroes the pan, keeps the atom")
        _ = state.pan(dx: 1, dy: 0)
        accepted = state.next()
        #expect(accepted && state.selectedAtom == nil && state.camera == .default && state.mode == .ballAndStick)
        _ = state.selectAtom(0)
        _ = state.pan(dx: 0, dy: -1)
        accepted = state.previous()
        #expect(accepted && state.selectedAtom == nil && state.camera == .default)
        _ = state.selectAtom(0)
        accepted = state.select(state.selection)
        #expect(accepted && state.selectedAtom == nil, "choosing the same molecule again clears too")
        _ = state.selectAtom(1)
        let kept = state
        accepted = state.select(7)
        #expect(!accepted && state == kept)
    }

    @Test func panStepsAreCheckedByTheState() {
        var state = MoleculeState.initial
        let refused: [(Int, Int)] = [(0, 0), (2, 0), (0, -2), (Int.max, 0)]
        for (dx, dy) in refused {
            let accepted = state.pan(dx: dx, dy: dy)
            #expect(!accepted && state == MoleculeState.initial, "pan \(dx), \(dy)")
        }
        for _ in 0..<10 { _ = state.pan(dx: 1, dy: -1) }
        let edge = state
        var accepted = state.pan(dx: 1, dy: 0)
        #expect(!accepted && state == edge && state.camera.panX == 10 && state.camera.panY == -10)
        accepted = state.pan(dx: 0, dy: -1)
        #expect(!accepted && state == edge)
        accepted = state.pan(dx: -1, dy: 1)
        #expect(accepted && state.camera.panX == 9 && state.camera.panY == -9)
    }
}
