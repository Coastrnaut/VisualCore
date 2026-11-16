// MoleculeLibraryTests — feature 110 (A15-P01) T-A15-105 (FR-A15-111, FR-A15-130; clarification Q2; SC-A15-103). The
// curated library, host-free and short: five molecules in order (water, methane, ethanol, benzene, caffeine) with atom
// and bond counts 3/2, 5/4, 9/8, 12/12, 24/25 and formulas H2O, CH4, C2H6O, C6H6, C8H10N4O2; no record fails to load;
// every molecule parses with `XYZParser` and validates again with `Molecule.make`; every structure record is PubChem's
// 3D conformer (public domain, Å) and passes `ElementAudit.problems(molecules:)`; recorded bonds keep their orders
// (benzene alternates); on all five the inferred connections equal the recorded connections.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct MoleculeLibraryTests {
    @Test func fiveMoleculesLoadInOrderWithTheirCountsAndFormulas() {
        let molecules = MoleculeLibrary.molecules
        #expect(MoleculeLibrary.failures.isEmpty, "\(MoleculeLibrary.failures)")
        #expect(molecules.map(\.id) == ["water", "methane", "ethanol", "benzene", "caffeine"])
        #expect(molecules.map(\.title) == ["Water", "Methane", "Ethanol", "Benzene", "Caffeine"])
        #expect(molecules.map(\.atoms.count) == [3, 5, 9, 12, 24])
        #expect(molecules.map(\.bonds.count) == [2, 4, 8, 12, 25])
        #expect(molecules.map(\.formula) == ["H2O", "CH4", "C2H6O", "C6H6", "C8H10N4O2"])
    }

    @Test func everyMoleculeParsesAndValidates() throws {
        let records = MoleculeLibraryData.records
        #expect(records.count == MoleculeLibrary.molecules.count)
        for (index, record) in records.enumerated() where index < MoleculeLibrary.molecules.count {
            let molecule = MoleculeLibrary.molecules[index]
            let parsed = try XYZParser.parse(record.xyz).get()
            #expect(parsed.atoms == molecule.atoms, "\(record.id)")
            #expect(parsed.comment == "PubChem CID \(record.pubChemCID) 3D conformer")
            let remade = Molecule.make(id: molecule.id, title: molecule.title, atoms: molecule.atoms,
                                       bonds: molecule.bonds, source: molecule.source)
            #expect(remade == .success(molecule), "\(record.id)")
            #expect(molecule.bonds.allSatisfy { $0.origin == .recorded }, "\(record.id)")
            #expect(MoleculeLibrary.molecule(from: record) == .success(molecule))
        }
    }

    @Test func everyStructureRecordIsPubChemPublicDomain() {
        let cids: [Int] = [962, 297, 702, 241, 2519]
        for (index, molecule) in MoleculeLibrary.molecules.enumerated() where index < cids.count {
            let cid = cids[index]
            #expect(MoleculeLibrary.pubChemCID(id: molecule.id) == cid)
            let source = molecule.source
            #expect(source.key == molecule.id && source.quantity == "structure")
            #expect(source.title == "PubChem Compound CID \(cid), 3D conformer")
            #expect(source.publisher == "National Library of Medicine (NCBI)")
            #expect(source.link == "pubchem.ncbi.nlm.nih.gov/compound/\(cid)")
            #expect(source.units == "Å" && source.license == "public-domain")
        }
        #expect(ElementAudit.problems(molecules: MoleculeLibrary.molecules).isEmpty)
        #expect(MoleculeLibrary.pubChemCID(id: "aspirin") == nil)
    }

    @Test func recordedBondOrdersAreKept() {
        let molecules = MoleculeLibrary.molecules
        #expect(molecules.count == 5)
        guard molecules.count == 5 else { return }
        let benzeneOrders: [Int] = molecules[3].bonds.filter { molecules[3].atoms[$0.b].symbol == "C" }.map(\.order)
        #expect(benzeneOrders == [2, 1, 1, 2, 2, 1], "benzene's alternating orders as recorded")
        #expect(molecules[4].bonds.filter { $0.order == 2 }.count == 4, "caffeine has four double bonds")
        #expect(molecules[0].bonds.allSatisfy { $0.order == 1 })
    }

    @Test func inferredConnectionsEqualRecordedConnections() {
        for molecule in MoleculeLibrary.molecules {
            var recorded: Set<[Int]> = []
            for bond in molecule.bonds { recorded.insert([bond.a, bond.b]) }
            var inferred: Set<[Int]> = []
            for bond in BondInference.bonds(for: molecule.atoms) { inferred.insert([bond.a, bond.b]) }
            #expect(inferred == recorded, "\(molecule.id)")
        }
    }

    @Test func aDamagedRecordIsReportedNotTrapped() {
        let damaged = LibraryRecord(id: "damaged", title: "Damaged", pubChemCID: 1, xyz: "-3\nc\nH 0 0 0\n", bonds: [])
        #expect(MoleculeLibrary.molecule(from: damaged)
                == .failure(LibraryLoadFailure(id: "damaged", reason: "bad-count on line 1")))
        let shortBond = LibraryRecord(id: "short", title: "Short", pubChemCID: 1, xyz: "1\nc\nH 0 0 0\n", bonds: [[0, 1]])
        #expect(MoleculeLibrary.molecule(from: shortBond)
                == .failure(LibraryLoadFailure(id: "short", reason: "bond entry 0 is not [a, b, order]")))
        let badBond = LibraryRecord(id: "bad", title: "Bad", pubChemCID: 1, xyz: "1\nc\nH 0 0 0\n", bonds: [[0, 0, 1]])
        #expect(MoleculeLibrary.molecule(from: badBond)
                == .failure(LibraryLoadFailure(id: "bad", reason: "self-bond at 0")))
    }
}
