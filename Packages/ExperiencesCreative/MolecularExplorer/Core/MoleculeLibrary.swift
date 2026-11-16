// MoleculeLibrary — feature 110 (A15-P01) T-A15-105 (FR-A15-130; clarification Q2; data-model "MoleculeLibrary";
// research D2). The curated library of Molecular Explorer: water, methane, ethanol, benzene and caffeine, in this order,
// built from `MoleculeLibraryData.records`. Each record's XYZ text goes through `XYZParser` and its recorded bonds
// (zero-based a, b and the order, origin `recorded`) through `Molecule.make`, so the library passes the same checks as
// an imported file. The structure's source record is "PubChem Compound CID <n>, 3D conformer", publisher "National
// Library of Medicine (NCBI)", link "pubchem.ncbi.nlm.nih.gov/compound/<n>", quantity `structure`, units "Å", license
// `public-domain`.
//
// Building never traps: a record that fails is left out of `molecules` and named in `failures` (a programming error in
// the generated data, which the library tests catch: they require five molecules and no failure).
import Foundation

/// Why one bundled record did not load.
public struct LibraryLoadFailure: Error, Equatable, Sendable, CustomStringConvertible {
    /// The record's id.
    public let id: String
    /// What failed (a parser or molecule refusal, or a malformed bond entry).
    public let reason: String

    /// Creates a failure.
    public init(id: String, reason: String) {
        self.id = id; self.reason = reason
    }

    /// `<id>: <reason>`.
    public var description: String { "\(id): \(reason)" }
}

/// The curated molecule library.
public enum MoleculeLibrary {
    /// The results of loading every record, in record order.
    static let loaded: [Result<Molecule, LibraryLoadFailure>] = MoleculeLibraryData.records.map(molecule(from:))

    /// The library's molecules in order: water, methane, ethanol, benzene, caffeine.
    public static let molecules: [Molecule] = loaded.compactMap { try? $0.get() }

    /// The records that failed to load (empty for the bundled data).
    public static let failures: [LibraryLoadFailure] = loaded.compactMap { result in
        if case .failure(let failure) = result { return failure }
        return nil
    }

    /// The structure's source record for PubChem compound `cid`, keyed by the molecule `id`.
    public static func source(id: String, cid: Int) -> SourceRecord {
        SourceRecord(key: id, quantity: SourceRecord.structureQuantity,
                     title: "PubChem Compound CID \(cid), 3D conformer", publisher: SourceRecord.pubChemPublisher,
                     link: "pubchem.ncbi.nlm.nih.gov/compound/\(cid)", units: SourceRecord.angstrom,
                     license: "public-domain")
    }

    /// The PubChem compound id of the library molecule `id`, or nil for an id outside the library.
    public static func pubChemCID(id: String) -> Int? {
        MoleculeLibraryData.records.first { $0.id == id }?.pubChemCID
    }

    /// The molecule of one record: its XYZ text parsed, its recorded bonds attached and the whole validated.
    public static func molecule(from record: LibraryRecord) -> Result<Molecule, LibraryLoadFailure> {
        let parsed: ParsedXYZ
        switch XYZParser.parse(record.xyz) {
        case .success(let value): parsed = value
        case .failure(let refusal): return .failure(LibraryLoadFailure(id: record.id, reason: refusal.description))
        }
        var bonds: [Bond] = []
        for (index, entry) in record.bonds.enumerated() {
            guard entry.count == 3 else {
                return .failure(LibraryLoadFailure(id: record.id, reason: "bond entry \(index) is not [a, b, order]"))
            }
            bonds.append(Bond(a: entry[0], b: entry[1], order: entry[2], origin: .recorded))
        }
        let made = Molecule.make(id: record.id, title: record.title, atoms: parsed.atoms, bonds: bonds,
                                 source: source(id: record.id, cid: record.pubChemCID))
        return made.mapError { LibraryLoadFailure(id: record.id, reason: $0.description) }
    }
}
