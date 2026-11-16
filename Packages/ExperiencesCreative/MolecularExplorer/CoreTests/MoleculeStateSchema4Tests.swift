// MoleculeStateSchema4Tests — feature 114 (A15-P05) T-A15-502 (FR-A15-504, FR-A15-505; clarification Q1; data-model
// "MoleculeState schema 4"). The state at schema 4, host-free and short: `ImportedMolecule.make(atoms:)` accepts water's
// atoms with inferred single bonds and refuses each limit with the parser's reason; the import steps begin, atom and
// end follow their rules and never select the import; selection 5 needs an import and `next`/`previous` stay within the
// library; a state with an import, with a pending import and with neither round-trips exactly (sorted keys, the
// optional keys omitted); schema-1, 2 and 3 payloads migrate with neither, and the step 3 → 4 writes the schema-4 JSON;
// damaged, newer and out-of-range schema-4 payloads are refused with their reason.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct MoleculeStateSchema4Tests {
    /// Water's atoms as the library holds them.
    private var waterAtoms: [Atom] { MoleculeLibrary.molecules[0].atoms }

    /// The camera JSON of the default camera.
    private let camera = #""camera":{"panX":0,"panY":0,"tilt":2,"turn":2,"zoom":0}"#

    /// The state after importing `atoms` through the three import steps (not selected).
    private func importing(_ atoms: [Atom], into start: MoleculeState = .initial) -> MoleculeState {
        var state = start
        _ = state.beginImport(count: atoms.count)
        for atom in atoms { _ = state.addImportedAtom(atom) }
        _ = state.endImport()
        return state
    }

    @Test func theImportRuleAcceptsWaterWithInferredSingleBonds() throws {
        let imported = try ImportedMolecule.make(atoms: waterAtoms).get()
        let molecule = imported.molecule
        #expect(molecule.id == "imported" && molecule.title == "Imported molecule" && molecule.formula == "H2O")
        #expect(molecule.atoms == waterAtoms && molecule.bonds.count == 2)
        for bond in molecule.bonds { #expect(bond.order == 1 && bond.origin == .inferred) }
        #expect(molecule.source.title == "imported file" && molecule.source.license == "own-data")
        #expect(molecule.source.units == "Å" && molecule.source.quantity == "structure")
        #expect(!ElementAudit.allowedLicenses.contains("own-data"), "the bundled licenses are unchanged")
        let lower = [Atom(symbol: "cl", x: 0, y: 0, z: 0), Atom(symbol: "h", x: 1.3, y: 0, z: 0)]
        #expect(try ImportedMolecule.make(atoms: lower).get().molecule.atoms.map(\.symbol) == ["Cl", "H"])
        #expect(ImportedMolecule.atom(atomicNumber: 17, x: 1, y: 2, z: 3) == Atom(symbol: "Cl", x: 1, y: 2, z: 3))
        #expect(ImportedMolecule.atom(atomicNumber: 2, x: 0, y: 0, z: 0) == nil)
        #expect(ImportedMolecule.atomicNumbers == [1, 6, 7, 8, 9, 15, 16, 17, 35, 53])
    }

    @Test func theImportRuleRefusesEachLimit() {
        let far = Atom(symbol: "H", x: 5, y: 5, z: 5)
        #expect(ImportedMolecule.make(atoms: []) == .failure(.badCount))
        var many: [Atom] = []
        for index in 0..<501 { many.append(Atom(symbol: "H", x: Double(index), y: 0, z: 0)) }
        #expect(ImportedMolecule.make(atoms: many) == .failure(.tooManyAtoms))
        #expect((try? ImportedMolecule.make(atoms: Array(many.prefix(500))).get())?.molecule.atoms.count == 500)
        #expect(ImportedMolecule.make(atoms: [far, Atom(symbol: "He", x: 0, y: 0, z: 0)]) == .failure(.unknownElement))
        #expect(ImportedMolecule.make(atoms: [far, Atom(symbol: "H", x: .nan, y: 0, z: 0)]) == .failure(.nonFinite))
        #expect(ImportedMolecule.make(atoms: [far, Atom(symbol: "H", x: 0, y: -.infinity, z: 0)])
                == .failure(.nonFinite))
        #expect(ImportedMolecule.make(atoms: [far, Atom(symbol: "H", x: 0, y: 0, z: 1_000.001)])
                == .failure(.outOfRange))
        #expect((try? ImportedMolecule.make(atoms: [far, Atom(symbol: "H", x: 0, y: 0, z: -1_000)]).get()) != nil)
        #expect(ImportedMolecule.make(atoms: [far, Atom(symbol: "H", x: 5.3, y: 5, z: 5)])
                == .failure(.overlappingAtoms))
        #expect((try? ImportedMolecule.make(atoms: [far, Atom(symbol: "H", x: 5.5, y: 5, z: 5)]).get()) != nil,
                "0.5 Å apart is accepted")
    }

    @Test func theImportStepsFollowTheirRules() throws {
        var state = MoleculeState(selection: 2)
        #expect(state.maxSelection == 4 && !state.select(5), "no import: selection 5 is refused")
        #expect(state.endImport() == .failure(.badCount) && state == MoleculeState(selection: 2))
        var accepted = state.addImportedAtom(waterAtoms[0])
        #expect(!accepted && state.pending == nil, "an atom without a begin is refused")
        let refusedCounts: [Int] = [0, -1, 501, Int.max]
        for count in refusedCounts {
            accepted = state.beginImport(count: count)
            #expect(!accepted && state.pending == nil, "count \(count)")
        }
        accepted = state.beginImport(count: 3)
        #expect(accepted && state.pending?.count == 3 && state.pending?.atoms.isEmpty == true)
        accepted = state.addImportedAtom(waterAtoms[0]) && state.addImportedAtom(waterAtoms[1])
        #expect(accepted)
        let twoAtoms = state
        #expect(state.endImport() == .failure(.countMismatch) && state == twoAtoms, "a short import changes nothing")
        let badAtoms = [Atom(symbol: "Xe", x: 0, y: 0, z: 0), Atom(symbol: "H", x: .nan, y: 0, z: 0),
                        Atom(symbol: "H", x: 0, y: 1_001, z: 0)]
        for atom in badAtoms {
            accepted = state.addImportedAtom(atom)
            #expect(!accepted && state == twoAtoms, "\(atom)")
        }
        accepted = state.addImportedAtom(Atom(symbol: "h", x: 0.6068, y: -0.2383, z: -0.7169))
        #expect(accepted && state.pending?.atoms.last?.symbol == "H")
        accepted = state.addImportedAtom(waterAtoms[2])
        #expect(!accepted, "the announced count is reached")
        let imported = try state.endImport().get()
        #expect(state.imported == imported && state.pending == nil && imported.molecule.atoms == waterAtoms)
        #expect(state.selection == 2 && state.molecule?.id == "ethanol", "the end does not select the import")
        #expect(state.maxSelection == 5)
        accepted = state.select(5)
        #expect(accepted && state.molecule == imported.molecule && state.atomCount == 3)
        #expect(!state.next() && !state.previous() && state.selection == 5, "next and previous stay in the library")
        accepted = state.selectAtom(2)
        #expect(accepted)
        // A begin while pending starts again; overlapping atoms are refused at the end with nothing changed.
        _ = state.beginImport(count: 2)
        _ = state.addImportedAtom(waterAtoms[0])
        accepted = state.beginImport(count: 2)
        #expect(accepted && state.pending?.atoms.isEmpty == true)
        _ = state.addImportedAtom(Atom(symbol: "C", x: 0, y: 0, z: 0))
        _ = state.addImportedAtom(Atom(symbol: "C", x: 0.39, y: 0, z: 0))
        let crowded = state
        #expect(state.endImport() == .failure(.overlappingAtoms) && state == crowded)
        // A second import replaces the first; shown at selection 5, the selected atom is cleared.
        let methane = MoleculeLibrary.molecules[1].atoms
        state = importing(methane, into: state)
        #expect(state.imported?.molecule.atoms == methane && state.selection == 5 && state.selectedAtom == nil)
        #expect(state.molecule?.formula == "CH4")
        accepted = state.select(0)
        #expect(accepted && state.molecule?.id == "water" && state.imported != nil)
    }

    @Test func statesWithAndWithoutAnImportRoundTrip() throws {
        let none = #"{\#(camera),"mode":0,"schema":4,"selection":0}"#
        #expect(String(decoding: MoleculeState.initial.encoded(), as: UTF8.self) == none)
        #expect(MoleculeState.decode(Data(none.utf8)) == .success(MoleculeState.initial))
        var state = importing([Atom(symbol: "O", x: 0, y: 0, z: 0), Atom(symbol: "H", x: 0.5, y: -1.25, z: 0)])
        _ = state.select(5)
        _ = state.selectAtom(1)
        state.setMode(.spaceFilling)
        let withImport = #"{"atom":1,\#(camera),"imported":{"atoms":[{"symbol":"O","x":0,"y":0,"z":0},"#
            + #"{"symbol":"H","x":0.5,"y":-1.25,"z":0}]},"mode":1,"schema":4,"selection":5}"#
        #expect(String(decoding: state.encoded(), as: UTF8.self) == withImport)
        #expect(MoleculeState.decode(state.encoded()) == .success(state))
        #expect((try? JSONDecoder().decode(MoleculeState.self, from: state.encoded())) == state)
        _ = state.beginImport(count: 2)
        _ = state.addImportedAtom(Atom(symbol: "n", x: 1, y: 2, z: 3))
        let pendingJSON = #""pending":{"atoms":[{"symbol":"N","x":1,"y":2,"z":3}],"count":2}"#
        #expect(String(decoding: state.encoded(), as: UTF8.self).contains(pendingJSON))
        #expect(MoleculeState.decode(state.encoded()) == .success(state))
        #expect((try? JSONDecoder().decode(MoleculeState.self, from: state.encoded())) == state)
        // Every library molecule imported round-trips with its atoms.
        for molecule in MoleculeLibrary.molecules {
            let imported = importing(molecule.atoms)
            #expect(imported.imported?.molecule.atoms == molecule.atoms, "\(molecule.id)")
            #expect(MoleculeState.decode(imported.encoded()) == .success(imported), "\(molecule.id)")
        }
        let nulls = #"{"atom":null,\#(camera),"imported":null,"mode":0,"pending":null,"schema":4,"selection":0}"#
        #expect(MoleculeState.decode(Data(nulls.utf8)) == .success(MoleculeState.initial))
        #expect(MoleculeState.schemaVersion == 4 && MoleculeState.importedSelection == 5)
        #expect(MoleculeState.moleculeCount == 5)
    }

    @Test func olderSchemasMigrateWithNoImport() {
        let v1 = Data(#"{"schema":1,"selection":4}"#.utf8)
        let v2 = Data(#"{"camera":{"tilt":3,"turn":5,"zoom":2},"mode":1,"schema":2,"selection":4}"#.utf8)
        let v3 = Data(#"{"atom":3,"camera":{"panX":2,"panY":1,"tilt":2,"turn":2,"zoom":0},"mode":1,"schema":3,"selection":4}"#.utf8)
        var fromV3 = MoleculeState(selection: 4, mode: .spaceFilling, camera: .default, selectedAtom: 3)
        _ = fromV3.pan(dx: 1, dy: 1)
        _ = fromV3.pan(dx: 1, dy: 0)
        let decoded: [(Data, MoleculeState)] = [
            (v1, MoleculeState(selection: 4)),
            (v2, MoleculeState(selection: 4, mode: .spaceFilling,
                               camera: CameraSettings(turnSteps: 5, tiltSteps: 3, zoomSteps: 2))),
            (v3, fromV3),
        ]
        for (data, expected) in decoded {
            let result = MoleculeState.decode(data)
            #expect(result == .success(expected), "\(String(decoding: data, as: UTF8.self))")
            #expect((try? result.get())?.imported == nil && (try? result.get())?.pending == nil)
            #expect((try? JSONDecoder().decode(MoleculeState.self, from: data)) == expected)
        }
        let step2 = MoleculeState.upgradePayload(v2, from: 2).map { String(decoding: $0, as: UTF8.self) }
        #expect(step2 == .success(#"{"camera":{"panX":0,"panY":0,"tilt":3,"turn":5,"zoom":2},"mode":1,"schema":3,"selection":4}"#))
        #expect(MoleculeState.upgradePayload(v3, from: 3) == .success(fromV3.encoded()))
        #expect(String(decoding: fromV3.encoded(), as: UTF8.self)
                == #"{"atom":3,"camera":{"panX":2,"panY":1,"tilt":2,"turn":2,"zoom":0},"mode":1,"schema":4,"selection":4}"#)
        #expect(MoleculeState.upgradePayload(v3, from: 2) == .failure(.damaged))
        #expect(MoleculeState.upgradePayload(fromV3.encoded(), from: 4) == .failure(.damaged))
        let v3Imported = Data(#"{\#(camera),"mode":0,"schema":3,"selection":5}"#.utf8)
        #expect(MoleculeState.upgradePayload(v3Imported, from: 3) == .failure(.outOfRange))
        let v3Extra = Data(#"{\#(camera),"imported":{"atoms":[]},"mode":0,"schema":3,"selection":1}"#.utf8)
        #expect(MoleculeState.decode(v3Extra) == .success(MoleculeState(selection: 1)), "schema 3 has no import")
    }

    @Test func damagedNewerAndOutOfRangeSchema4PayloadsAreRefused() {
        let o = #"{"symbol":"O","x":0,"y":0,"z":0}"#
        let h = #"{"symbol":"H","x":0.5,"y":-1.25,"z":0}"#
        let newer: [String] = [#"{\#(camera),"mode":0,"schema":5,"selection":0}"#, #"{"schema":5}"#]
        for payload in newer {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.newerVersion), "\(payload)")
        }
        let damaged: [String] = [
            #"{"schema":4,"selection":0,"mode":0}"#,
            #"{"camera":{"panX":0,"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":4,"selection":0}"#,
            #"{\#(camera),"imported":[],"mode":0,"schema":4,"selection":0}"#,
            #"{\#(camera),"imported":{"atoms":[{"symbol":"O","x":"0","y":0,"z":0}]},"mode":0,"schema":4,"selection":0}"#,
            #"{\#(camera),"imported":{"atoms":[{"x":0,"y":0,"z":0}]},"mode":0,"schema":4,"selection":0}"#,
            #"{\#(camera),"imported":{},"mode":0,"schema":4,"selection":0}"#,
            #"{\#(camera),"mode":0,"pending":{"atoms":[]},"schema":4,"selection":0}"#,
            #"{\#(camera),"mode":0,"pending":{"atoms":[],"count":1.5},"schema":4,"selection":0}"#,
        ]
        for payload in damaged {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.damaged), "\(payload)")
        }
        let outOfRange: [String] = [
            #"{\#(camera),"mode":0,"schema":4,"selection":5}"#,
            #"{\#(camera),"mode":0,"schema":4,"selection":6}"#,
            #"{\#(camera),"mode":0,"schema":4,"selection":-1}"#,
            #"{\#(camera),"imported":{"atoms":[]},"mode":0,"schema":4,"selection":5}"#,
            #"{\#(camera),"imported":{"atoms":[\#(o),{"symbol":"H","x":0,"y":1001,"z":0}]},"mode":0,"schema":4,"selection":5}"#,
            #"{\#(camera),"imported":{"atoms":[\#(o),{"symbol":"He","x":1,"y":0,"z":0}]},"mode":0,"schema":4,"selection":0}"#,
            #"{\#(camera),"imported":{"atoms":[\#(o),{"symbol":"H","x":0.1,"y":0,"z":0}]},"mode":0,"schema":4,"selection":5}"#,
            #"{"atom":2,\#(camera),"imported":{"atoms":[\#(o),\#(h)]},"mode":0,"schema":4,"selection":5}"#,
            #"{\#(camera),"mode":0,"pending":{"atoms":[],"count":0},"schema":4,"selection":0}"#,
            #"{\#(camera),"mode":0,"pending":{"atoms":[],"count":501},"schema":4,"selection":0}"#,
            #"{\#(camera),"mode":0,"pending":{"atoms":[\#(o),\#(h)],"count":1},"schema":4,"selection":0}"#,
            #"{\#(camera),"mode":0,"pending":{"atoms":[{"symbol":"Xe","x":0,"y":0,"z":0}],"count":2},"schema":4,"selection":0}"#,
            #"{"camera":{"panX":11,"panY":0,"tilt":2,"turn":2,"zoom":0},"mode":0,"schema":4,"selection":0}"#,
            #"{\#(camera),"mode":2,"schema":4,"selection":0}"#,
        ]
        for payload in outOfRange {
            #expect(MoleculeState.decode(Data(payload.utf8)) == .failure(.outOfRange), "\(payload)")
            #expect((try? JSONDecoder().decode(MoleculeState.self, from: Data(payload.utf8))) == nil, "\(payload)")
        }
        let valid = #"{"atom":1,\#(camera),"imported":{"atoms":[\#(o),\#(h)]},"mode":0,"schema":4,"selection":5}"#
        #expect((try? MoleculeState.decode(Data(valid.utf8)).get())?.selectedAtom == 1)
    }
}
