// BondInference — feature 110 (A15-P01) T-A15-104 (FR-A15-111; clarification Q4; research D4; SC-A15-103). Bonds
// estimated from geometry: two atoms are bonded when their distance is at most the sum of their covalent radii
// (`Elements`) plus 0.4 Å, and not below the 0.4 Å overlap limit. Every pair i < j is checked (at most 124,750 pairs at
// 500 atoms, bounded by arithmetic, no spatial grid); every inferred bond is single and marked `inferred`, and the
// result is sorted by (a, b), so the same atoms give the same bonds in every run. An atom whose symbol is outside the
// catalog has no radius and gets no bond.
import Foundation

/// The distance-based bond estimate.
public enum BondInference {
    /// The tolerance added to the sum of the covalent radii, ångström.
    public static let tolerance = 0.4

    /// The inferred bonds of `atoms`: single, marked inferred, sorted by (a, b).
    public static func bonds(for atoms: [Atom]) -> [Bond] {
        let radii: [Double?] = atoms.map { Elements.element(symbol: $0.symbol)?.covalentRadius }
        var bonds: [Bond] = []
        for i in atoms.indices {
            guard let ri = radii[i] else { continue }
            for j in (i + 1)..<atoms.count {
                guard let rj = radii[j] else { continue }
                let distance = atoms[i].distance(to: atoms[j])
                if distance >= XYZParser.minDistance && distance <= ri + rj + tolerance {
                    bonds.append(Bond(a: i, b: j, order: 1, origin: .inferred))
                }
            }
        }
        return bonds
    }
}
