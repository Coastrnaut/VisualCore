// MoleculeLibraryData — feature 110 (A15-P01) T-A15-105 (FR-A15-130; clarification Q2). GENERATED, do not edit by
// hand: the five curated molecules exactly as their PubChem 3D conformer records give them (National Library of
// Medicine, NCBI; public domain): atoms with x y z in ångström, in record order, as XYZ text, and the recorded bonds as
// zero-based atom index pairs with their bond order (benzene's alternating orders as recorded). Generated on 2026-11-15
// from the SDF records of `https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/<cid>/record/SDF?record_type=3d`
// for CIDs 962, 297, 702, 241 and 2519 (fetched 2026-11-15). `MoleculeLibrary` parses each record with `XYZParser`
// and validates it with `Molecule.make`, so the library goes through the same checks as an imported file.

/// One bundled molecule as stored: its id, title, PubChem compound id, XYZ text and recorded bonds.
public struct LibraryRecord: Sendable, Equatable {
    /// The molecule's id (`water`, `methane`, `ethanol`, `benzene`, `caffeine`).
    public let id: String
    /// The title shown to the person.
    public let title: String
    /// The PubChem compound id the record came from.
    public let pubChemCID: Int
    /// The atoms as XYZ text (count line, comment line, one atom per line; ångström).
    public let xyz: String
    /// The recorded bonds: zero-based atom indices a, b and the bond order.
    public let bonds: [[Int]]
}

/// The raw records of the curated library, in library order.
public enum MoleculeLibraryData {
    /// Water, methane, ethanol, benzene and caffeine, as PubChem records them.
    public static let records: [LibraryRecord] = [
        LibraryRecord(id: "water", title: "Water", pubChemCID: 962,
                      xyz: "3\nPubChem CID 962 3D conformer\nO 0.0000 0.0000 0.0000\nH 0.2774 0.8929 0.2544\nH 0.6068 -0.2383 -0.7169\n",
                      bonds: [[0, 1, 1], [0, 2, 1]]),
        LibraryRecord(id: "methane", title: "Methane", pubChemCID: 297,
                      xyz: "5\nPubChem CID 297 3D conformer\nC 0.0000 0.0000 0.0000\nH 0.5541 0.7996 0.4965\nH 0.6833 -0.8134 -0.2536\nH -0.7782 -0.3735 0.6692\nH -0.4593 0.3874 -0.9121\n",
                      bonds: [[0, 1, 1], [0, 2, 1], [0, 3, 1], [0, 4, 1]]),
        LibraryRecord(id: "ethanol", title: "Ethanol", pubChemCID: 702,
                      xyz: "9\nPubChem CID 702 3D conformer\nO -1.1712 0.2997 0.0000\nC -0.0463 -0.5665 0.0000\nC 1.2175 0.2668 0.0000\nH -0.0958 -1.2120 0.8819\nH -0.0952 -1.1938 -0.8946\nH 2.1050 -0.3720 -0.0177\nH 1.2426 0.9307 -0.8704\nH 1.2616 0.9052 0.8886\nH -1.1291 0.8364 0.8099\n",
                      bonds: [[0, 1, 1], [0, 8, 1], [1, 2, 1], [1, 3, 1], [1, 4, 1], [2, 5, 1], [2, 6, 1], [2, 7, 1]]),
        LibraryRecord(id: "benzene", title: "Benzene", pubChemCID: 241,
                      xyz: "12\nPubChem CID 241 3D conformer\nC -1.2131 -0.6884 0.0000\nC -1.2028 0.7064 0.0001\nC -0.0103 -1.3948 0.0000\nC 0.0104 1.3948 -0.0001\nC 1.2028 -0.7063 0.0000\nC 1.2131 0.6884 0.0000\nH -2.1577 -1.2244 0.0000\nH -2.1393 1.2564 0.0001\nH -0.0184 -2.4809 -0.0001\nH 0.0184 2.4808 0.0000\nH 2.1394 -1.2563 0.0001\nH 2.1577 1.2245 0.0000\n",
                      bonds: [[0, 1, 2], [0, 2, 1], [0, 6, 1], [1, 3, 1], [1, 7, 1], [2, 4, 2], [2, 8, 1], [3, 5, 2], [3, 9, 1], [4, 5, 1], [4, 10, 1], [5, 11, 1]]),
        LibraryRecord(id: "caffeine", title: "Caffeine", pubChemCID: 2519,
                      xyz: "24\nPubChem CID 2519 3D conformer\nO 0.4700 2.5688 0.0006\nO -3.1271 -0.4436 -0.0003\nN -0.9686 -1.3125 0.0000\nN 2.2182 0.1412 -0.0003\nN -1.3477 1.0797 -0.0001\nN 1.4119 -1.9372 0.0002\nC 0.8579 0.2592 -0.0008\nC 0.3897 -1.0264 -0.0004\nC 0.0307 1.4220 -0.0006\nC -1.9061 -0.2495 -0.0004\nC 2.5032 -1.1998 0.0003\nC -1.4276 -2.6960 0.0008\nC 3.1926 1.2061 0.0003\nC -2.2969 2.1881 0.0007\nH 3.5163 -1.5787 0.0008\nH -1.0451 -3.1973 -0.8937\nH -2.5186 -2.7596 0.0011\nH -1.0447 -3.1963 0.8957\nH 4.1992 0.7801 0.0002\nH 3.0468 1.8092 -0.8992\nH 3.0466 1.8083 0.9004\nH -1.8087 3.1651 -0.0003\nH -2.9322 2.1027 0.8881\nH -2.9346 2.1021 -0.8849\n",
                      bonds: [[0, 8, 2], [1, 9, 2], [2, 7, 1], [2, 9, 1], [2, 11, 1], [3, 6, 1], [3, 10, 1], [3, 12, 1], [4, 8, 1], [4, 9, 1], [4, 13, 1], [5, 7, 1], [5, 10, 2], [6, 7, 2], [6, 8, 1], [10, 14, 1], [11, 15, 1], [11, 16, 1], [11, 17, 1], [12, 18, 1], [12, 19, 1], [12, 20, 1], [13, 21, 1], [13, 22, 1], [13, 23, 1]])
    ]
}
