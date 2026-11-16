// BondStyle — feature 112 (A15-P03) T-A15-303 (FR-A15-321; clarification Q4; data-model "BondStyle";
// contracts/selection.md). How a bond is drawn in ball-and-stick, so its order and provenance never depend on colour:
// - recorded single: 1 stick of radius 0.12 Å on the bond line (offset 0);
// - recorded double: 2 sticks of radius 0.07 Å, 0.09 Å either side of the bond line (offsets −0.09, +0.09);
// - recorded triple: 3 sticks of radius 0.06 Å, at 0 and 0.12 Å either side (offsets −0.12, 0, +0.12);
// - inferred (always single): 1 thinner stick of radius 0.06 Å on the bond line.
// An order outside 1…3 (never in a valid molecule) is drawn like a single bond.
//
// The side direction (along which the offsets are applied) is a unit vector perpendicular to the bond a → b and
// deterministic: it lies in the plane of another bond of atom a (the first bond in molecule order joining a to an atom
// other than b whose direction is not parallel to the bond), so a ring's double bonds lie in the ring's plane; failing
// that, in the plane of another bond of atom b (same rule); failing that, it is perpendicular to the bond and to the
// coordinate axis least aligned with it (ties: x before y before z). A degenerate bond (coincident atoms, never in a
// valid molecule) gets +x.
import Foundation
import VisualCoreMath

/// The sticks a bond is drawn with in ball-and-stick: their number, radius and offsets from the bond line.
public struct BondStyle: Equatable, Sendable {
    /// The number of parallel sticks (1, 2 or 3).
    public let sticks: Int
    /// The radius of each stick, ångström.
    public let radius: Double
    /// Each stick's offset from the bond line along the side direction, ångström (one per stick, ascending).
    public let offsets: [Double]

    /// Creates a style (no validation; ``style(order:origin:)`` gives the four styles of the file header).
    public init(sticks: Int, radius: Double, offsets: [Double]) {
        self.sticks = sticks; self.radius = radius; self.offsets = offsets
    }

    /// A recorded single bond: 1 × 0.12 Å.
    public static let single = BondStyle(sticks: 1, radius: 0.12, offsets: [0])
    /// A recorded double bond: 2 × 0.07 Å at ±0.09 Å.
    public static let double = BondStyle(sticks: 2, radius: 0.07, offsets: [-0.09, 0.09])
    /// A recorded triple bond: 3 × 0.06 Å at −0.12, 0 and +0.12 Å.
    public static let triple = BondStyle(sticks: 3, radius: 0.06, offsets: [-0.12, 0, 0.12])
    /// An inferred bond: 1 × 0.06 Å.
    public static let inferred = BondStyle(sticks: 1, radius: 0.06, offsets: [0])

    /// The style of a bond of `order` and `origin` (see the file header).
    public static func style(order: Int, origin: BondOrigin) -> BondStyle {
        if origin == .inferred { return inferred }
        switch order {
        case 2: return double
        case 3: return triple
        default: return single
        }
    }

    /// The tolerance below which a perpendicular component counts as zero (parallel bonds), ångström.
    static let parallelTolerance = 1e-9

    /// The side direction of `bond` among `atoms` joined by `bonds` (see the file header): a unit vector
    /// perpendicular to the bond a → b, deterministic.
    public static func sideDirection(bond: Bond, atoms: [Atom], bonds: [Bond]) -> Vec3 {
        guard atoms.indices.contains(bond.a), atoms.indices.contains(bond.b) else { return Vec3(1, 0, 0) }
        let pa = position(atoms[bond.a]), pb = position(atoms[bond.b])
        let axisVector = pb - pa
        guard axisVector.length > parallelTolerance else { return Vec3(1, 0, 0) }
        let axis = axisVector.normalized
        for (centre, other) in [(bond.a, bond.b), (bond.b, bond.a)] {
            let origin = position(atoms[centre])
            for candidate in bonds {
                let neighbour: Int
                if candidate.a == centre { neighbour = candidate.b } else if candidate.b == centre {
                    neighbour = candidate.a
                } else { continue }
                guard neighbour != other, atoms.indices.contains(neighbour) else { continue }
                let toNeighbour = position(atoms[neighbour]) - origin
                let perpendicular = toNeighbour - axis * toNeighbour.dot(axis)
                if perpendicular.length > parallelTolerance { return perpendicular.normalized }
            }
        }
        let components = [abs(axis.x), abs(axis.y), abs(axis.z)]
        var least = 0
        for index in 1..<3 where components[index] < components[least] { least = index }
        let unitAxes = [Vec3(1, 0, 0), Vec3(0, 1, 0), Vec3(0, 0, 1)]
        return axis.cross(unitAxes[least]).normalized
    }

    /// The position of `atom` as a vector, ångström.
    static func position(_ atom: Atom) -> Vec3 { Vec3(atom.x, atom.y, atom.z) }
}
