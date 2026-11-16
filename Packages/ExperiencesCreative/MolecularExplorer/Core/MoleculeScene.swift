// MoleculeScene — feature 111 (A15-P02) T-A15-202 (FR-A15-201, FR-A15-202, FR-A15-210; clarifications Q2, Q5;
// data-model "AtomItem", "BondHalf", "MoleculeScene"; contracts/renderer.md). What is drawn for a molecule in a display
// mode, computed without drawing:
// - one atom item per atom: its position, symbol and display radius (the mode's factor × the van der Waals radius);
// - in ball-and-stick, two halves per bond, in bond order: from atom a's centre to the bond midpoint (coloured by a),
//   then from atom b's centre to the midpoint (coloured by b), each of radius `DisplayMode.stickRadius`; none in
//   space-filling;
// - the centre (the mean of the atom positions) and the bounding radius (the largest distance from the centre to an
//   atom plus that atom's display radius, so a single atom's bounding radius is its display radius).
// The scene is pure: the same molecule and mode give the same scene. The draw budget is 1,500 items; the library needs
// at most 74 (caffeine: 24 atoms and 50 halves).
import Foundation
import VisualCoreMath

/// The drawable items of a molecule in one display mode.
public struct MoleculeScene: Equatable, Sendable {
    /// One drawn atom.
    public struct AtomItem: Equatable, Sendable {
        /// The atom's centre, ångström.
        public let position: Vec3
        /// The element symbol (selects the colour).
        public let symbol: String
        /// The display radius, ångström.
        public let radius: Double

        /// Creates an atom item.
        public init(position: Vec3, symbol: String, radius: Double) {
            self.position = position; self.symbol = symbol; self.radius = radius
        }
    }

    /// One half of a bond stick, from an atom's centre to the bond midpoint.
    public struct BondHalf: Equatable, Sendable {
        /// The start: the atom's centre, ångström.
        public let from: Vec3
        /// The end: the bond midpoint, ångström.
        public let to: Vec3
        /// The element symbol of the atom the half starts at (selects the colour).
        public let symbol: String
        /// The stick radius, ångström.
        public let radius: Double

        /// Creates a bond half.
        public init(from: Vec3, to: Vec3, symbol: String, radius: Double) {
            self.from = from; self.to = to; self.symbol = symbol; self.radius = radius
        }

        /// The half's length, ångström.
        public var length: Double { (to - from).length }
    }

    /// The most items (atoms plus halves) a scene may draw.
    public static let drawBudget = 1_500

    /// The atom items, in atom order.
    public let atoms: [AtomItem]
    /// The bond halves, two per bond in bond order (empty in space-filling).
    public let bondHalves: [BondHalf]
    /// The mean of the atom positions, ångström.
    public let centre: Vec3
    /// The radius of the sphere around `centre` holding every drawn atom, ångström.
    public let boundingRadius: Double
    /// The display mode the scene was made for.
    public let mode: DisplayMode

    /// The scene of `molecule` in `mode` (see the file header).
    public init(molecule: Molecule, mode: DisplayMode) {
        self.mode = mode
        var atoms: [AtomItem] = []
        atoms.reserveCapacity(molecule.atoms.count)
        var sum = Vec3.zero
        for atom in molecule.atoms {
            let vdw = Elements.element(symbol: atom.symbol)?.vanDerWaalsRadius ?? 0
            let position = Vec3(atom.x, atom.y, atom.z)
            atoms.append(AtomItem(position: position, symbol: atom.symbol, radius: mode.atomRadiusFactor * vdw))
            sum += position
        }
        let centre = atoms.isEmpty ? Vec3.zero : sum / Double(atoms.count)
        var bounding = 0.0
        for item in atoms {
            bounding = max(bounding, (item.position - centre).length + item.radius)
        }
        var halves: [BondHalf] = []
        if mode.showsBonds {
            halves.reserveCapacity(molecule.bonds.count * 2)
            for bond in molecule.bonds where atoms.indices.contains(bond.a) && atoms.indices.contains(bond.b) {
                let a = atoms[bond.a], b = atoms[bond.b]
                let middle = (a.position + b.position) * 0.5
                halves.append(BondHalf(from: a.position, to: middle, symbol: a.symbol, radius: DisplayMode.stickRadius))
                halves.append(BondHalf(from: b.position, to: middle, symbol: b.symbol, radius: DisplayMode.stickRadius))
            }
        }
        self.atoms = atoms
        self.bondHalves = halves
        self.centre = centre
        self.boundingRadius = bounding
    }

    /// The number of drawn items: atoms plus bond halves.
    public var itemCount: Int { atoms.count + bondHalves.count }

    /// True when the scene fits the draw budget.
    public var isWithinBudget: Bool { itemCount <= Self.drawBudget }
}
