// BondInferenceTests — feature 110 (A15-P01) T-A15-104 (FR-A15-111; clarification Q4; SC-A15-103). The distance-based
// bond estimate, host-free and short: water gets its two O–H bonds, single and inferred; an isolated atom gets none;
// the threshold is the sum of the covalent radii plus 0.4 Å; atoms closer than 0.4 Å or of an unknown element are never
// bonded; the result is sorted by (a, b) and the same in every run.
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct BondInferenceTests {
    /// Water's atoms (O, H, H) from its PubChem record.
    private let water: [Atom] = [Atom(symbol: "O", x: 0, y: 0, z: 0),
                                 Atom(symbol: "H", x: 0.2774, y: 0.8929, z: 0.2544),
                                 Atom(symbol: "H", x: 0.6068, y: -0.2383, z: -0.7169)]

    @Test func waterHasTwoSingleInferredOxygenHydrogenBonds() {
        #expect(BondInference.tolerance == 0.4)
        let bonds = BondInference.bonds(for: water)
        #expect(bonds == [Bond(a: 0, b: 1, order: 1, origin: .inferred), Bond(a: 0, b: 2, order: 1, origin: .inferred)])
    }

    @Test func anIsolatedAtomHasNoBond() {
        #expect(BondInference.bonds(for: [Atom(symbol: "I", x: 0, y: 0, z: 0)]).isEmpty)
        #expect(BondInference.bonds(for: []).isEmpty)
        let isolated = water + [Atom(symbol: "Cl", x: 10, y: 10, z: 10)]
        #expect(BondInference.bonds(for: isolated).count == 2)
    }

    @Test func theThresholdIsTheRadiiSumPlusTheTolerance() {
        // C–C: 0.76 + 0.76 + 0.4 = 1.92 Å.
        let near: [Atom] = [Atom(symbol: "C", x: 0, y: 0, z: 0), Atom(symbol: "C", x: 1.91, y: 0, z: 0)]
        #expect(BondInference.bonds(for: near).count == 1)
        let far: [Atom] = [Atom(symbol: "C", x: 0, y: 0, z: 0), Atom(symbol: "C", x: 1.93, y: 0, z: 0)]
        #expect(BondInference.bonds(for: far).isEmpty)
        let overlapping: [Atom] = [Atom(symbol: "C", x: 0, y: 0, z: 0), Atom(symbol: "C", x: 0.39, y: 0, z: 0)]
        #expect(BondInference.bonds(for: overlapping).isEmpty, "below the 0.4 Å overlap limit")
        let unknown: [Atom] = [Atom(symbol: "Xx", x: 0, y: 0, z: 0), Atom(symbol: "C", x: 1, y: 0, z: 0)]
        #expect(BondInference.bonds(for: unknown).isEmpty)
        let lowerCase: [Atom] = [Atom(symbol: "c", x: 0, y: 0, z: 0), Atom(symbol: "cl", x: 1.77, y: 0, z: 0)]
        #expect(BondInference.bonds(for: lowerCase).count == 1)
    }

    @Test func theResultIsSortedSingleInferredAndDeterministic() {
        var chain: [Atom] = []
        for index in 0..<12 {
            chain.append(Atom(symbol: "C", x: Double(index) * 1.5, y: index % 2 == 0 ? 0 : 0.3, z: 0))
        }
        let first = BondInference.bonds(for: chain)
        #expect(!first.isEmpty)
        for _ in 0..<5 { #expect(BondInference.bonds(for: chain) == first) }
        let pairs: [[Int]] = first.map { [$0.a, $0.b] }
        let sorted: [[Int]] = pairs.sorted { $0[0] != $1[0] ? $0[0] < $1[0] : $0[1] < $1[1] }
        #expect(pairs == sorted)
        #expect(first.allSatisfy { $0.order == 1 && $0.origin == .inferred && $0.a < $0.b })
    }
}
