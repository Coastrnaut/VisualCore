// Molecule — feature 110 (A15-P01) T-A15-103 (FR-A15-110, FR-A15-112; data-model "Atom", "BondOrigin", "Bond",
// "Molecule"; contracts/domain.md). The atom/bond domain of Molecular Explorer:
// - `Atom`: an element symbol and a position x, y, z in ångström;
// - `Bond`: two atom indices kept as a < b (the initialiser and the decoder order them), an order and an origin
//   (`recorded` from a source record, or `inferred` from distances, which is always single);
// - `Molecule`: id, title, atoms, bonds and the structure's source record, with the formula derived in Hill order
//   (carbon first, then hydrogen, then the other symbols alphabetically; all symbols alphabetically when there is no
//   carbon; a count of 1 is omitted: H2O, CH4, C2H6O, C8H10N4O2).
//
// `Molecule.make(...)` is the only public way to build a molecule. It refuses, checking in this order and naming the
// zero-based atom or bond index where one applies:
// - `atom-count`: fewer than 1 or more than 500 atoms; `bond-count`: more than 2,000 bonds;
// - per atom in order: `unknown-element` (a symbol outside `Elements`), `non-finite` (a NaN or infinite coordinate),
//   `out-of-range` (a coordinate magnitude above 1,000 Å);
// - `overlapping-atoms`: two atoms closer than 0.4 Å (the index of the later atom; 0.4 Å itself is accepted);
// - per bond in order: `bond-index` (an index outside the atoms), `self-bond` (a == b), `bond-order` (an order outside
//   1…3), `inferred-order` (an inferred bond that is not single), `duplicate-bond` (a pair already bonded).
// Symbols are stored normalised (`cl` → `Cl`). All limits are inclusive.
import Foundation

/// One atom: an element symbol and a position in ångström.
public struct Atom: Codable, Equatable, Hashable, Sendable {
    /// The element symbol (normalised once the atom is in a molecule or a parse result).
    public let symbol: String
    /// The x coordinate, ångström.
    public let x: Double
    /// The y coordinate, ångström.
    public let y: Double
    /// The z coordinate, ångström.
    public let z: Double

    /// Creates an atom (no validation; ``Molecule/make(id:title:atoms:bonds:source:)`` validates).
    public init(symbol: String, x: Double, y: Double, z: Double) {
        self.symbol = symbol; self.x = x; self.y = y; self.z = z
    }

    /// The distance to `other`, ångström.
    public func distance(to other: Atom) -> Double {
        let dx = x - other.x, dy = y - other.y, dz = z - other.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    /// True when every coordinate is finite.
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }

    /// The largest coordinate magnitude, ångström.
    var maxMagnitude: Double { max(abs(x), abs(y), abs(z)) }
}

/// Where a bond comes from.
public enum BondOrigin: String, CaseIterable, Codable, Sendable {
    /// Taken from the structure's source record.
    case recorded = "recorded"
    /// Estimated from the distance and the covalent radii (always single, never presented as measured).
    case inferred = "inferred"
}

/// A bond between two atoms of a molecule, with a < b.
public struct Bond: Codable, Equatable, Hashable, Sendable {
    /// The lower atom index (zero-based).
    public let a: Int
    /// The higher atom index (zero-based).
    public let b: Int
    /// The bond order, 1…3 in a valid molecule.
    public let order: Int
    /// Where the bond comes from.
    public let origin: BondOrigin

    /// Creates a bond between atoms `a` and `b`, stored in ascending order (no other validation).
    public init(a: Int, b: Int, order: Int, origin: BondOrigin) {
        self.a = min(a, b); self.b = max(a, b); self.order = order; self.origin = origin
    }

    /// The coding keys.
    private enum CodingKeys: String, CodingKey { case a, b, order, origin }

    /// Decodes a bond and orders its indices like ``init(a:b:order:origin:)``.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(a: try c.decode(Int.self, forKey: .a), b: try c.decode(Int.self, forKey: .b),
                  order: try c.decode(Int.self, forKey: .order), origin: try c.decode(BondOrigin.self, forKey: .origin))
    }
}

/// Why `Molecule.make` refused its input.
public enum MoleculeRefusalReason: String, CaseIterable, Codable, Sendable {
    /// Fewer than 1 or more than 500 atoms.
    case atomCount = "atom-count"
    /// More than 2,000 bonds.
    case bondCount = "bond-count"
    /// A symbol outside the element catalog.
    case unknownElement = "unknown-element"
    /// A NaN or infinite coordinate.
    case nonFinite = "non-finite"
    /// A coordinate magnitude above 1,000 Å.
    case outOfRange = "out-of-range"
    /// Two atoms closer than 0.4 Å.
    case overlappingAtoms = "overlapping-atoms"
    /// A bond index outside the atoms.
    case bondIndex = "bond-index"
    /// A bond from an atom to itself.
    case selfBond = "self-bond"
    /// A bond order outside 1…3.
    case bondOrder = "bond-order"
    /// An inferred bond that is not single.
    case inferredOrder = "inferred-order"
    /// A second bond between the same two atoms.
    case duplicateBond = "duplicate-bond"
}

/// A refusal of `Molecule.make`: the reason and the zero-based atom or bond index where one applies.
public struct MoleculeRefusal: Error, Equatable, Sendable, CustomStringConvertible {
    /// The reason.
    public let reason: MoleculeRefusalReason
    /// The zero-based index of the atom (atom reasons) or bond (bond reasons) at fault, nil for a count reason.
    public let index: Int?

    /// Creates a refusal.
    public init(_ reason: MoleculeRefusalReason, index: Int? = nil) {
        self.reason = reason; self.index = index
    }

    /// The reason's raw value, followed by the index when there is one (`overlapping-atoms at 3`).
    public var description: String {
        index.map { "\(reason.rawValue) at \($0)" } ?? reason.rawValue
    }
}

/// A validated molecule: id, title, atoms, bonds and the source of its structure.
public struct Molecule: Codable, Equatable, Sendable {
    /// The most atoms a molecule may have.
    public static let maxAtoms = 500
    /// The most bonds a molecule may have.
    public static let maxBonds = 2_000
    /// The largest coordinate magnitude, ångström.
    public static let maxCoordinate = 1_000.0
    /// The smallest distance between two atoms, ångström.
    public static let minDistance = 0.4
    /// The bond orders a bond may have.
    public static let bondOrders = 1...3

    /// The molecule's id (`water`).
    public let id: String
    /// The title shown to the person (`Water`).
    public let title: String
    /// The atoms, symbols normalised.
    public let atoms: [Atom]
    /// The bonds, each with a < b.
    public let bonds: [Bond]
    /// The source record of the structure.
    public let source: SourceRecord

    /// Creates a molecule without validation (only ``make(id:title:atoms:bonds:source:)`` calls it).
    init(id: String, title: String, atoms: [Atom], bonds: [Bond], source: SourceRecord) {
        self.id = id; self.title = title; self.atoms = atoms; self.bonds = bonds; self.source = source
    }

    /// The formula in Hill order (``formula(of:)``).
    public var formula: String { Self.formula(of: atoms) }

    /// The Hill-order formula of `atoms`: carbon first, then hydrogen, then the other symbols alphabetically, or every
    /// symbol alphabetically when there is no carbon; a count of 1 is omitted (`C8H10N4O2`, `H2O`).
    public static func formula(of atoms: [Atom]) -> String {
        var counts: [String: Int] = [:]
        for atom in atoms { counts[atom.symbol, default: 0] += 1 }
        var order: [String]
        if counts["C"] != nil {
            order = ["C"]
            if counts["H"] != nil { order.append("H") }
            order += counts.keys.filter { $0 != "C" && $0 != "H" }.sorted()
        } else {
            order = counts.keys.sorted()
        }
        var text = ""
        for symbol in order {
            let count = counts[symbol] ?? 0
            text += count == 1 ? symbol : "\(symbol)\(count)"
        }
        return text
    }

    /// The molecule from its parts, or the first refusal in the order of the file header.
    public static func make(id: String, title: String, atoms: [Atom], bonds: [Bond],
                            source: SourceRecord) -> Result<Molecule, MoleculeRefusal> {
        guard (1...maxAtoms).contains(atoms.count) else { return .failure(MoleculeRefusal(.atomCount)) }
        guard bonds.count <= maxBonds else { return .failure(MoleculeRefusal(.bondCount)) }
        var normalised: [Atom] = []
        normalised.reserveCapacity(atoms.count)
        for (index, atom) in atoms.enumerated() {
            guard let element = Elements.element(symbol: atom.symbol) else {
                return .failure(MoleculeRefusal(.unknownElement, index: index))
            }
            guard atom.isFinite else { return .failure(MoleculeRefusal(.nonFinite, index: index)) }
            guard atom.maxMagnitude <= maxCoordinate else { return .failure(MoleculeRefusal(.outOfRange, index: index)) }
            normalised.append(Atom(symbol: element.symbol, x: atom.x, y: atom.y, z: atom.z))
        }
        if let later = firstOverlap(normalised) {
            return .failure(MoleculeRefusal(.overlappingAtoms, index: later))
        }
        var pairs: Set<[Int]> = []
        for (index, bond) in bonds.enumerated() {
            guard normalised.indices.contains(bond.a), normalised.indices.contains(bond.b) else {
                return .failure(MoleculeRefusal(.bondIndex, index: index))
            }
            guard bond.a != bond.b else { return .failure(MoleculeRefusal(.selfBond, index: index)) }
            guard bondOrders.contains(bond.order) else { return .failure(MoleculeRefusal(.bondOrder, index: index)) }
            guard bond.origin == .recorded || bond.order == 1 else {
                return .failure(MoleculeRefusal(.inferredOrder, index: index))
            }
            guard pairs.insert([bond.a, bond.b]).inserted else {
                return .failure(MoleculeRefusal(.duplicateBond, index: index))
            }
        }
        return .success(Molecule(id: id, title: title, atoms: normalised, bonds: bonds, source: source))
    }

    /// The index of the first atom (in order) closer than ``minDistance`` to an earlier atom, or nil when none is;
    /// all pairs are checked (at most 124,750 at 500 atoms).
    static func firstOverlap(_ atoms: [Atom]) -> Int? {
        for j in atoms.indices {
            for i in 0..<j where atoms[i].distance(to: atoms[j]) < minDistance {
                return j
            }
        }
        return nil
    }
}
