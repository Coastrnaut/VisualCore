// ImportedMolecule — feature 114 (A15-P05) T-A15-502 (FR-A15-504, FR-A15-505; clarification Q1; data-model
// "ImportedMolecule"; contracts/import.md). The molecule a person imported from an XYZ file, as the engine holds it:
// the atoms (element symbol and x, y, z in ångström, in file order) and their inferred bonds, with no title (the
// engine's actions carry numbers only; the title stays beside the stored file, outside the engine).
//
// `make(atoms:)` is the single check of the import limits, used by the engine's `import.end` and by the fuzz test. It
// refuses with the parser's own reasons, checking in this order:
// - `bad-count` for no atom, `too-many-atoms` for more than 500;
// - per atom in order: `unknown-element` (a symbol outside `Elements`), `non-finite` (a NaN or infinite coordinate),
//   `out-of-range` (a coordinate magnitude above 1,000 Å);
// - `overlapping-atoms` for two atoms closer than 0.4 Å (0.4 Å itself is accepted);
// - `too-many-atoms` also when the inferred bonds would exceed `Molecule.maxBonds` (2,000; atoms packed so densely
//   that the molecule cannot be drawn).
// The bonds come from `BondInference` (single, marked inferred, sorted by a, b). The molecule's id is `imported`, its
// title "Imported molecule" and its source record "imported file" with the license `own-data` ("your own data"), units
// "Å" and the quantity `structure`.
//
// Codable as `{"atoms":[{"symbol":"O","x":0,"y":0,"z":0}, …]}`: only the atoms are written, since the bonds and the
// source follow from them; decoding runs `make(atoms:)` again and throws for atoms it refuses.
import Foundation

/// A molecule imported from a person's own XYZ file: validated atoms and inferred bonds, no title.
public struct ImportedMolecule: Codable, Equatable, Sendable {
    /// The id of every imported molecule.
    public static let id = "imported"
    /// The title the engine gives every imported molecule (the file's title is kept outside the engine).
    public static let title = "Imported molecule"
    /// The atomic numbers an imported atom may have: 1, 6, 7, 8, 9, 15, 16, 17, 35 and 53.
    public static let atomicNumbers: [Int] = Elements.all.map(\.atomicNumber)

    /// The structure's source record of an imported molecule: "imported file", your own data.
    public static let source = SourceRecord(key: id, quantity: SourceRecord.structureQuantity,
                                            title: SourceRecord.importedTitle,
                                            publisher: SourceRecord.importedPublisher, link: "",
                                            units: SourceRecord.angstrom, license: SourceRecord.ownDataLicense)

    /// The validated molecule: atoms in file order, inferred single bonds, the imported source record.
    public let molecule: Molecule

    /// Wraps an already validated molecule (only ``make(atoms:)`` calls it).
    init(molecule: Molecule) {
        self.molecule = molecule
    }

    /// The atom of an `import.atom` action: the element with atomic number `atomicNumber` at x, y, z; nil for an
    /// atomic number outside ``atomicNumbers`` (the coordinates are checked by ``make(atoms:)``).
    public static func atom(atomicNumber: Int, x: Double, y: Double, z: Double) -> Atom? {
        guard let element = Elements.all.first(where: { $0.atomicNumber == atomicNumber }) else { return nil }
        return Atom(symbol: element.symbol, x: x, y: y, z: z)
    }

    /// The reason one atom is refused (`unknown-element`, `non-finite`, `out-of-range`), or nil when it is within the
    /// limits.
    public static func refusal(for atom: Atom) -> XYZRefusal.Reason? {
        guard Elements.element(symbol: atom.symbol) != nil else { return .unknownElement }
        guard atom.isFinite else { return .nonFinite }
        guard atom.maxMagnitude <= Molecule.maxCoordinate else { return .outOfRange }
        return nil
    }

    /// The imported molecule of `atoms`, or the first refusal in the order of the file header.
    public static func make(atoms: [Atom]) -> Result<ImportedMolecule, XYZRefusal.Reason> {
        if atoms.isEmpty { return .failure(.badCount) }
        if atoms.count > Molecule.maxAtoms { return .failure(.tooManyAtoms) }
        for atom in atoms {
            if let reason = refusal(for: atom) { return .failure(reason) }
        }
        var normalised: [Atom] = []
        normalised.reserveCapacity(atoms.count)
        for atom in atoms {
            let symbol = Elements.element(symbol: atom.symbol)?.symbol ?? atom.symbol
            normalised.append(Atom(symbol: symbol, x: atom.x, y: atom.y, z: atom.z))
        }
        if Molecule.firstOverlap(normalised) != nil { return .failure(.overlappingAtoms) }
        let bonds = BondInference.bonds(for: normalised)
        if bonds.count > Molecule.maxBonds { return .failure(.tooManyAtoms) }
        switch Molecule.make(id: id, title: title, atoms: normalised, bonds: bonds, source: source) {
        case .success(let molecule):
            return .success(ImportedMolecule(molecule: molecule))
        case .failure(let refusal):
            return .failure(reason(for: refusal.reason))
        }
    }

    /// The parser reason of a `Molecule.make` refusal (unreachable after the checks above; kept total).
    static func reason(for refusal: MoleculeRefusalReason) -> XYZRefusal.Reason {
        switch refusal {
        case .atomCount, .bondCount: return .tooManyAtoms
        case .unknownElement: return .unknownElement
        case .nonFinite: return .nonFinite
        case .outOfRange: return .outOfRange
        case .overlappingAtoms: return .overlappingAtoms
        case .bondIndex, .selfBond, .bondOrder, .inferredOrder, .duplicateBond: return .malformedLine
        }
    }

    /// The coding keys.
    private enum CodingKeys: String, CodingKey { case atoms }

    /// Decodes the atoms and validates them with ``make(atoms:)``; throws for atoms it refuses.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let atoms = try c.decode([Atom].self, forKey: .atoms)
        switch Self.make(atoms: atoms) {
        case .success(let imported): self = imported
        case .failure(let reason):
            throw DecodingError.dataCorruptedError(forKey: .atoms, in: c, debugDescription: reason.rawValue)
        }
    }

    /// Encodes the atoms only (`{"atoms":[…]}`).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(molecule.atoms, forKey: .atoms)
    }
}
