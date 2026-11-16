// InferenceDeterminismTests — feature 113 (A15-P04) T-A15-403 (research D5; clarification Q5). Bond inference does not
// depend on atom order: for each library molecule, five seeded shuffles (seeds 1…5, SplitMix64 written here, never the
// system generator) give inferred bonds that, mapped back through the permutation and sorted, equal the unshuffled
// inferred pairs and the molecule's recorded pairs; every inferred bond is single and marked inferred; two runs on the
// same input give identical lists. Host-free and short (five molecules of at most 24 atoms).
import Foundation
import Testing
@testable import MolecularExplorerCore

/// SplitMix64: a small deterministic generator for the fixture.
private struct SplitMix64: RandomNumberGenerator {
    /// The state.
    var state: UInt64

    /// The next 64-bit value.
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite struct InferenceDeterminismTests {
    /// The (a, b) pairs of `bonds`, each with a < b, sorted.
    private func sortedPairs(_ bonds: [Bond]) -> [[Int]] {
        var pairs: [[Int]] = []
        for bond in bonds { pairs.append([min(bond.a, bond.b), max(bond.a, bond.b)]) }
        return pairs.sorted { $0[0] != $1[0] ? $0[0] < $1[0] : $0[1] < $1[1] }
    }

    /// A Fisher–Yates permutation of 0..<count driven by `seed`: entry k is the original index of shuffled atom k.
    private func permutation(count: Int, seed: UInt64) -> [Int] {
        var generator = SplitMix64(state: seed)
        var order = Array(0..<count)
        var index = count - 1
        while index > 0 {
            let other = Int(generator.next() % UInt64(index + 1))
            order.swapAt(index, other)
            index -= 1
        }
        return order
    }

    @Test func theLibraryIsLoaded() {
        #expect(MoleculeLibrary.molecules.count == 5 && MoleculeLibrary.failures.isEmpty)
    }

    @Test func shuffledAtomsGiveTheSameBonds() {
        for molecule in MoleculeLibrary.molecules {
            let reference = BondInference.bonds(for: molecule.atoms)
            let referencePairs = sortedPairs(reference)
            #expect(referencePairs == sortedPairs(molecule.bonds), "\(molecule.id): inferred equals recorded")
            for seed in UInt64(1)...5 {
                let order = permutation(count: molecule.atoms.count, seed: seed)
                var shuffled: [Atom] = []
                for original in order { shuffled.append(molecule.atoms[original]) }
                let inferred = BondInference.bonds(for: shuffled)
                var mapped: [Bond] = []
                for bond in inferred {
                    #expect(bond.order == 1 && bond.origin == .inferred, "\(molecule.id) seed \(seed)")
                    mapped.append(Bond(a: order[bond.a], b: order[bond.b], order: bond.order, origin: bond.origin))
                }
                #expect(sortedPairs(mapped) == referencePairs, "\(molecule.id) seed \(seed)")
            }
        }
    }

    @Test func everyInferredBondIsSingleAndTwoRunsAgree() {
        for molecule in MoleculeLibrary.molecules {
            let first = BondInference.bonds(for: molecule.atoms)
            let second = BondInference.bonds(for: molecule.atoms)
            #expect(first == second, "\(molecule.id)")
            #expect(!first.isEmpty, "\(molecule.id)")
            for bond in first {
                #expect(bond.order == 1 && bond.origin == .inferred && bond.a < bond.b, "\(molecule.id)")
            }
            let order = permutation(count: molecule.atoms.count, seed: 3)
            var shuffled: [Atom] = []
            for original in order { shuffled.append(molecule.atoms[original]) }
            #expect(BondInference.bonds(for: shuffled) == BondInference.bonds(for: shuffled), "\(molecule.id)")
        }
    }

    @Test func theGeneratorIsDeterministic() {
        #expect(permutation(count: 24, seed: 1) == permutation(count: 24, seed: 1))
        #expect(permutation(count: 24, seed: 1) != permutation(count: 24, seed: 2))
        #expect(permutation(count: 24, seed: 4).sorted() == Array(0..<24))
    }
}
