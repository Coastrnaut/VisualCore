// MoleculeScene — feature 111 (A15-P02) T-A15-202 (FR-A15-201, FR-A15-202, FR-A15-210; clarifications Q2, Q5;
// data-model "AtomItem", "BondHalf", "MoleculeScene"; contracts/renderer.md). What is drawn for a molecule in a display
// mode, computed without drawing:
// - one atom item per atom: its position, symbol and display radius (the mode's factor × the van der Waals radius);
// - in ball-and-stick, two halves per bond, in bond order: from atom a's centre to the bond midpoint (coloured by a),
//   then from atom b's centre to the midpoint (coloured by b), each of its bond style's stick radius (feature 112;
//   `DisplayMode.stickRadius` for a recorded single bond); none in space-filling;
// - the centre (the mean of the atom positions) and the bounding radius (the largest distance from the centre to an
//   atom plus that atom's display radius, so a single atom's bounding radius is its display radius).
// The scene is pure: the same molecule and mode give the same scene.
//
// Feature 112 (A15-P03) T-A15-303 (FR-A15-321; clarification Q4; contracts/selection.md): each bond half carries its
// styled sticks (`BondStyle`): the bond's order and origin, one stick per style offset, each moved by its offset along
// the bond's side direction (`BondStyle.sideDirection`) at both ends, with the style's radius and the half's symbol; the
// half's `radius` is the style's stick radius (0.12 Å for a recorded single bond). `sticks` lists every stick of every
// half in half order (a's sticks, then b's, bond by bond); none in space-filling. The drawn item count is the atoms
// plus the sticks; the draw budget is 1,500 items and the library needs at most 82 (caffeine: 24 atoms and 58 sticks,
// its four double bonds giving two sticks per half).
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

    /// One drawn stick: a cylinder from `from` to `to` (feature 112, T-A15-303).
    public struct Stick: Equatable, Sendable {
        /// The start, ångström (the atom's centre moved by the stick's offset).
        public let from: Vec3
        /// The end, ångström (the bond midpoint moved by the stick's offset).
        public let to: Vec3
        /// The element symbol of the atom the half starts at (selects the colour).
        public let symbol: String
        /// The stick radius, ångström.
        public let radius: Double

        /// Creates a stick.
        public init(from: Vec3, to: Vec3, symbol: String, radius: Double) {
            self.from = from; self.to = to; self.symbol = symbol; self.radius = radius
        }

        /// The stick's length, ångström.
        public var length: Double { (to - from).length }
    }

    /// One half of a bond, from an atom's centre to the bond midpoint, with its styled sticks.
    public struct BondHalf: Equatable, Sendable {
        /// The start: the atom's centre, ångström.
        public let from: Vec3
        /// The end: the bond midpoint, ångström.
        public let to: Vec3
        /// The element symbol of the atom the half starts at (selects the colour).
        public let symbol: String
        /// The stick radius of the half's style, ångström.
        public let radius: Double
        /// The bond order (1…3).
        public let order: Int
        /// Where the bond comes from.
        public let origin: BondOrigin
        /// The styled sticks of this half (one per style offset).
        public let sticks: [Stick]

        /// Creates a bond half; with `sticks` nil it carries one stick on its line (`from` → `to`, `radius`).
        public init(from: Vec3, to: Vec3, symbol: String, radius: Double, order: Int = 1,
                    origin: BondOrigin = .recorded, sticks: [Stick]? = nil) {
            self.from = from; self.to = to; self.symbol = symbol; self.radius = radius
            self.order = order; self.origin = origin
            self.sticks = sticks ?? [Stick(from: from, to: to, symbol: symbol, radius: radius)]
        }

        /// The half's length, ångström.
        public var length: Double { (to - from).length }
    }

    /// The most items (atoms plus sticks) a scene may draw.
    public static let drawBudget = 1_500

    /// The atom items, in atom order.
    public let atoms: [AtomItem]
    /// The bond halves, two per bond in bond order (empty in space-filling).
    public let bondHalves: [BondHalf]
    /// Every stick of every half, in half order (empty in space-filling).
    public let sticks: [Stick]
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
        var sticks: [Stick] = []
        if mode.showsBonds {
            halves.reserveCapacity(molecule.bonds.count * 2)
            for bond in molecule.bonds where atoms.indices.contains(bond.a) && atoms.indices.contains(bond.b) {
                let a = atoms[bond.a], b = atoms[bond.b]
                let middle = (a.position + b.position) * 0.5
                let style = BondStyle.style(order: bond.order, origin: bond.origin)
                let side = style.sticks > 1
                    ? BondStyle.sideDirection(bond: bond, atoms: molecule.atoms, bonds: molecule.bonds) : Vec3.zero
                for end in [a, b] {
                    var halfSticks: [Stick] = []
                    for offset in style.offsets {
                        let shift = side * offset
                        halfSticks.append(Stick(from: end.position + shift, to: middle + shift, symbol: end.symbol,
                                                radius: style.radius))
                    }
                    halves.append(BondHalf(from: end.position, to: middle, symbol: end.symbol, radius: style.radius,
                                           order: bond.order, origin: bond.origin, sticks: halfSticks))
                    sticks += halfSticks
                }
            }
        }
        self.atoms = atoms
        self.bondHalves = halves
        self.sticks = sticks
        self.centre = centre
        self.boundingRadius = bounding
    }

    /// The number of drawn items: atoms plus sticks.
    public var itemCount: Int { atoms.count + sticks.count }

    /// True when the scene fits the draw budget.
    public var isWithinBudget: Bool { itemCount <= Self.drawBudget }
}
