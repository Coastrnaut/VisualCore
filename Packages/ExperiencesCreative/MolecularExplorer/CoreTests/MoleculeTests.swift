// MoleculeTests — feature 110 (A15-P01) T-A15-103 (FR-A15-110, FR-A15-112; data-model "Atom", "Bond", "Molecule").
// The atom/bond domain, host-free and short: bonds keep a < b; a valid molecule is made with its symbols normalised;
// every refusal of `Molecule.make` (atom and bond caps, unknown element, non-finite and out-of-range positions,
// overlapping atoms, bond index, self-bond, bond order, an inferred bond that is not single, a duplicate pair) is named
// with its index; the limits are inclusive (500 atoms, 2,000 bonds, 1,000 Å, 0.4 Å); the Hill-order formula of water,
// methane, ethanol, benzene, caffeine and molecules without carbon.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct MoleculeTests {
    /// A record for test molecules.
    private let source = MoleculeLibrary.source(id: "test", cid: 1)

    /// `Molecule.make` with the test id, title and source.
    private func make(_ atoms: [Atom], _ bonds: [Bond] = []) -> Result<Molecule, MoleculeRefusal> {
        Molecule.make(id: "test", title: "Test", atoms: atoms, bonds: bonds, source: source)
    }

    /// The refusal of `result`, or nil when it succeeded.
    private func refusal(_ result: Result<Molecule, MoleculeRefusal>) -> MoleculeRefusal? {
        if case .failure(let refusal) = result { return refusal }
        return nil
    }

    /// `count` hydrogen atoms on a 1 Å grid (10 × 10 × n).
    private func grid(_ count: Int) -> [Atom] {
        var atoms: [Atom] = []
        for index in 0..<count {
            atoms.append(Atom(symbol: "H", x: Double(index % 10), y: Double((index / 10) % 10), z: Double(index / 100)))
        }
        return atoms
    }

    /// Water's three atoms (O, H, H) from its PubChem record.
    private let water: [Atom] = [Atom(symbol: "O", x: 0, y: 0, z: 0), Atom(symbol: "H", x: 0.2774, y: 0.8929, z: 0.2544),
                                 Atom(symbol: "H", x: 0.6068, y: -0.2383, z: -0.7169)]

    @Test func bondsKeepTheLowerIndexFirst() {
        let bond = Bond(a: 5, b: 2, order: 2, origin: .recorded)
        #expect(bond.a == 2 && bond.b == 5 && bond.order == 2 && bond.origin == .recorded)
        let decoded = try? JSONDecoder().decode(Bond.self, from: Data(#"{"a":4,"b":1,"order":1,"origin":"inferred"}"#.utf8))
        #expect(decoded == Bond(a: 1, b: 4, order: 1, origin: .inferred))
        #expect(BondOrigin.allCases.map(\.rawValue) == ["recorded", "inferred"])
    }

    @Test func aValidMoleculeIsMadeWithNormalisedSymbols() throws {
        let atoms: [Atom] = [Atom(symbol: "c", x: 0, y: 0, z: 0), Atom(symbol: "cl", x: 1.77, y: 0, z: 0)]
        let molecule = try make(atoms, [Bond(a: 0, b: 1, order: 1, origin: .recorded)]).get()
        #expect(molecule.atoms.map(\.symbol) == ["C", "Cl"])
        #expect(molecule.atoms[1].x == 1.77 && molecule.bonds.count == 1 && molecule.formula == "CCl")
        #expect(molecule.id == "test" && molecule.title == "Test" && molecule.source == source)
        let single = try make([Atom(symbol: "I", x: 0, y: 0, z: 0)]).get()
        #expect(single.bonds.isEmpty && single.formula == "I", "a single isolated atom is valid")
    }

    @Test func atomAndBondCapsAreInclusive() {
        #expect(refusal(make([])) == MoleculeRefusal(.atomCount))
        #expect(refusal(make(grid(500))) == nil)
        #expect(refusal(make(grid(501))) == MoleculeRefusal(.atomCount))
        let atoms = grid(100)
        var bonds: [Bond] = []
        for a in 0..<100 {
            for b in (a + 1)..<100 where bonds.count < 2_001 {
                bonds.append(Bond(a: a, b: b, order: 1, origin: .recorded))
            }
        }
        #expect(refusal(make(atoms, Array(bonds.prefix(2_000)))) == nil)
        #expect(refusal(make(atoms, bonds)) == MoleculeRefusal(.bondCount))
    }

    @Test func eachAtomRefusalNamesTheAtom() {
        var atoms = water
        atoms[1] = Atom(symbol: "Xx", x: 1, y: 1, z: 1)
        #expect(refusal(make(atoms)) == MoleculeRefusal(.unknownElement, index: 1))
        let nonFinite: [Double] = [.nan, .infinity, -.infinity]
        for value in nonFinite {
            atoms = water
            atoms[2] = Atom(symbol: "H", x: 1, y: value, z: 1)
            #expect(refusal(make(atoms)) == MoleculeRefusal(.nonFinite, index: 2), "\(value)")
        }
        atoms = water
        atoms[2] = Atom(symbol: "H", x: 0, y: 0, z: 1_000.001)
        #expect(refusal(make(atoms)) == MoleculeRefusal(.outOfRange, index: 2))
        atoms[2] = Atom(symbol: "H", x: 0, y: -1_000, z: 1_000)
        #expect(refusal(make(atoms)) == nil, "1,000 Å is inside the limit")
        atoms = water + [Atom(symbol: "H", x: 0.2774, y: 0.8929, z: 0.5)]
        #expect(refusal(make(atoms)) == MoleculeRefusal(.overlappingAtoms, index: 3))
        let pair: [Atom] = [Atom(symbol: "H", x: 0, y: 0, z: 0), Atom(symbol: "H", x: 0.4, y: 0, z: 0)]
        #expect(refusal(make(pair)) == nil, "0.4 Å is inside the limit")
        let close: [Atom] = [Atom(symbol: "H", x: 0, y: 0, z: 0), Atom(symbol: "H", x: 0.399, y: 0, z: 0)]
        #expect(refusal(make(close)) == MoleculeRefusal(.overlappingAtoms, index: 1))
    }

    @Test func eachBondRefusalNamesTheBond() {
        let good = Bond(a: 0, b: 1, order: 1, origin: .recorded)
        #expect(refusal(make(water, [good, Bond(a: 0, b: 3, order: 1, origin: .recorded)]))
                == MoleculeRefusal(.bondIndex, index: 1))
        #expect(refusal(make(water, [Bond(a: -1, b: 0, order: 1, origin: .recorded)]))
                == MoleculeRefusal(.bondIndex, index: 0))
        #expect(refusal(make(water, [good, Bond(a: 2, b: 2, order: 1, origin: .recorded)]))
                == MoleculeRefusal(.selfBond, index: 1))
        let badOrders: [Int] = [0, 4, -1]
        for order in badOrders {
            #expect(refusal(make(water, [Bond(a: 0, b: 2, order: order, origin: .recorded)]))
                    == MoleculeRefusal(.bondOrder, index: 0), "order \(order)")
        }
        #expect(refusal(make(water, [Bond(a: 0, b: 2, order: 3, origin: .recorded)])) == nil)
        #expect(refusal(make(water, [Bond(a: 0, b: 2, order: 2, origin: .inferred)]))
                == MoleculeRefusal(.inferredOrder, index: 0))
        #expect(refusal(make(water, [good, Bond(a: 1, b: 0, order: 2, origin: .recorded)]))
                == MoleculeRefusal(.duplicateBond, index: 1))
        #expect(MoleculeRefusal(.selfBond, index: 1).description == "self-bond at 1")
        #expect(MoleculeRefusal(.atomCount).description == "atom-count")
    }

    @Test func theFormulaIsInHillOrder() {
        #expect(Molecule.formula(of: water) == "H2O")
        let cases: [(symbols: [String], formula: String)] = [
            (["C", "H", "H", "H", "H"], "CH4"),
            (["O", "C", "C", "H", "H", "H", "H", "H", "H"], "C2H6O"),
            (["C", "C", "C", "C", "C", "C", "H", "H", "H", "H", "H", "H"], "C6H6"),
            (["H", "H", "S", "O", "O", "O", "O"], "H2O4S"),
            (["Cl", "H"], "ClH"),
            (["N", "H", "H", "H"], "H3N"),
            (["Cl", "C", "Cl", "Br", "F"], "CBrCl2F"),
            (["O", "C", "O"], "CO2"),
        ]
        for entry in cases {
            var atoms: [Atom] = []
            for (index, symbol) in entry.symbols.enumerated() {
                atoms.append(Atom(symbol: symbol, x: Double(index), y: 0, z: 0))
            }
            #expect(Molecule.formula(of: atoms) == entry.formula, "\(entry.symbols)")
        }
        var caffeine: [Atom] = []
        let counts: [(String, Int)] = [("O", 2), ("N", 4), ("C", 8), ("H", 10)]
        for (symbol, count) in counts {
            for _ in 0..<count { caffeine.append(Atom(symbol: symbol, x: 0, y: 0, z: 0)) }
        }
        #expect(Molecule.formula(of: caffeine) == "C8H10N4O2")
    }
}
