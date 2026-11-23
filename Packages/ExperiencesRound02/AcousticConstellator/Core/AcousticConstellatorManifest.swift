// AcousticConstellatorManifest — feature 422 (R02-G13-02) T-R02G1302-002 (FR-R02G1302-001; clarification Q1). The 100
// planned levels of Acoustic Constellator, copied from the project's own archived design (docs/archive/planning/rounds/
// round2.md, the R02-G13 level table; `python3 scripts/planning_index.py levels --experience R02-G13`): number, planned
// seed, band and moves budget (the table's "Moves budget").

/// One planned level: its number, planned seed, band and moves budget.
public struct AcousticConstellatorManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The moves budget, which becomes the level's action budget (8 … 19).
    public let budget: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
    }
}

/// The 100 planned levels of Acoustic Constellator in order.
public enum AcousticConstellatorManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G13 level table)"
    /// The provenance of the entries in words.
    public static let provenance =
        "The project's own archived design, R02-G13 level table (planning_index.py levels --experience R02-G13)."

    /// The 100 entries, in manifest order.
    public static let entries: [AcousticConstellatorManifestEntry] = [
        AcousticConstellatorManifestEntry(number: 1, seed: 0xb98894a847e5ace7, band: 1, budget: 9),
        AcousticConstellatorManifestEntry(number: 2, seed: 0x7c5cadd4b86f451a, band: 1, budget: 10),
        AcousticConstellatorManifestEntry(number: 3, seed: 0xcc09ae0abd27a204, band: 1, budget: 11),
        AcousticConstellatorManifestEntry(number: 4, seed: 0x0019e32e1bdb39a9, band: 1, budget: 8),
        AcousticConstellatorManifestEntry(number: 5, seed: 0xfdc7c1be951067cc, band: 1, budget: 9),
        AcousticConstellatorManifestEntry(number: 6, seed: 0x69b4570fb5a5822c, band: 1, budget: 10),
        AcousticConstellatorManifestEntry(number: 7, seed: 0xbc3dde39e1342d1c, band: 1, budget: 11),
        AcousticConstellatorManifestEntry(number: 8, seed: 0x5fc79f786447ec5b, band: 1, budget: 8),
        AcousticConstellatorManifestEntry(number: 9, seed: 0xc858e98aab1181da, band: 1, budget: 9),
        AcousticConstellatorManifestEntry(number: 10, seed: 0x36416979bcd2b6e9, band: 1, budget: 10),
        AcousticConstellatorManifestEntry(number: 11, seed: 0xe14aeff2b74b3dd2, band: 1, budget: 11),
        AcousticConstellatorManifestEntry(number: 12, seed: 0x63910545ea0d86ed, band: 1, budget: 8),
        AcousticConstellatorManifestEntry(number: 13, seed: 0x4cee9d9535088e97, band: 1, budget: 9),
        AcousticConstellatorManifestEntry(number: 14, seed: 0x089f6642e15dbc5d, band: 1, budget: 10),
        AcousticConstellatorManifestEntry(number: 15, seed: 0x777827f21597e91e, band: 1, budget: 11),
        AcousticConstellatorManifestEntry(number: 16, seed: 0x407b8ce8d7c68c3f, band: 1, budget: 8),
        AcousticConstellatorManifestEntry(number: 17, seed: 0x72ac97e724e1f5d3, band: 1, budget: 9),
        AcousticConstellatorManifestEntry(number: 18, seed: 0xe525307c2245ad68, band: 1, budget: 10),
        AcousticConstellatorManifestEntry(number: 19, seed: 0xdf933c18d8ae976a, band: 1, budget: 11),
        AcousticConstellatorManifestEntry(number: 20, seed: 0x762b5e216c566a07, band: 1, budget: 8),
        AcousticConstellatorManifestEntry(number: 21, seed: 0x8a8b7f0e98f863eb, band: 2, budget: 11),
        AcousticConstellatorManifestEntry(number: 22, seed: 0x82505dbef218467c, band: 2, budget: 12),
        AcousticConstellatorManifestEntry(number: 23, seed: 0x3ed82cd65cbc8ba7, band: 2, budget: 13),
        AcousticConstellatorManifestEntry(number: 24, seed: 0xde732602ccef3181, band: 2, budget: 10),
        AcousticConstellatorManifestEntry(number: 25, seed: 0x27c391e440036751, band: 2, budget: 11),
        AcousticConstellatorManifestEntry(number: 26, seed: 0x3f228834612dd3a6, band: 2, budget: 12),
        AcousticConstellatorManifestEntry(number: 27, seed: 0xf116f9b11a9efc7a, band: 2, budget: 13),
        AcousticConstellatorManifestEntry(number: 28, seed: 0xa03bb5a7277be1fb, band: 2, budget: 10),
        AcousticConstellatorManifestEntry(number: 29, seed: 0xceee8d5c41dd1789, band: 2, budget: 11),
        AcousticConstellatorManifestEntry(number: 30, seed: 0x81dc13b55db84eaa, band: 2, budget: 12),
        AcousticConstellatorManifestEntry(number: 31, seed: 0xad081e474328e0c4, band: 2, budget: 13),
        AcousticConstellatorManifestEntry(number: 32, seed: 0x108bcf26d6ca5e91, band: 2, budget: 10),
        AcousticConstellatorManifestEntry(number: 33, seed: 0x9bfe8cf229ba4b84, band: 2, budget: 11),
        AcousticConstellatorManifestEntry(number: 34, seed: 0x15d87fe32858c005, band: 2, budget: 12),
        AcousticConstellatorManifestEntry(number: 35, seed: 0x07526b51cb37b2b3, band: 2, budget: 13),
        AcousticConstellatorManifestEntry(number: 36, seed: 0x4e4afc0c6120d95b, band: 2, budget: 10),
        AcousticConstellatorManifestEntry(number: 37, seed: 0x1b4a7c6c45de29d7, band: 2, budget: 11),
        AcousticConstellatorManifestEntry(number: 38, seed: 0x9031b27765a0fb3e, band: 2, budget: 12),
        AcousticConstellatorManifestEntry(number: 39, seed: 0xb44496855fa86796, band: 2, budget: 13),
        AcousticConstellatorManifestEntry(number: 40, seed: 0x430b865bf2548ff8, band: 2, budget: 10),
        AcousticConstellatorManifestEntry(number: 41, seed: 0xb6b2ebfdb1c70d69, band: 3, budget: 13),
        AcousticConstellatorManifestEntry(number: 42, seed: 0xcfa7e8d07592d4da, band: 3, budget: 14),
        AcousticConstellatorManifestEntry(number: 43, seed: 0x319b9910d3c33768, band: 3, budget: 15),
        AcousticConstellatorManifestEntry(number: 44, seed: 0x132faa8100d0efb4, band: 3, budget: 12),
        AcousticConstellatorManifestEntry(number: 45, seed: 0xd55a0eb1cc106d78, band: 3, budget: 13),
        AcousticConstellatorManifestEntry(number: 46, seed: 0xdf750989aa641461, band: 3, budget: 14),
        AcousticConstellatorManifestEntry(number: 47, seed: 0x123d75557443848c, band: 3, budget: 15),
        AcousticConstellatorManifestEntry(number: 48, seed: 0xffeefb0b5524ff1b, band: 3, budget: 12),
        AcousticConstellatorManifestEntry(number: 49, seed: 0xd01c3598f3680b77, band: 3, budget: 13),
        AcousticConstellatorManifestEntry(number: 50, seed: 0x6882d76cbfa1a612, band: 3, budget: 14),
        AcousticConstellatorManifestEntry(number: 51, seed: 0xabb7efdc61a20441, band: 3, budget: 15),
        AcousticConstellatorManifestEntry(number: 52, seed: 0xb46c2ee1f8606021, band: 3, budget: 12),
        AcousticConstellatorManifestEntry(number: 53, seed: 0x1c7ec17ffbbe1bee, band: 3, budget: 13),
        AcousticConstellatorManifestEntry(number: 54, seed: 0x3f371ff0609bcc15, band: 3, budget: 14),
        AcousticConstellatorManifestEntry(number: 55, seed: 0x10ae02c477eb15d5, band: 3, budget: 15),
        AcousticConstellatorManifestEntry(number: 56, seed: 0xd99075503b62e143, band: 3, budget: 12),
        AcousticConstellatorManifestEntry(number: 57, seed: 0x11b919be67ca02e0, band: 3, budget: 13),
        AcousticConstellatorManifestEntry(number: 58, seed: 0x9fb39d1e44ac7079, band: 3, budget: 14),
        AcousticConstellatorManifestEntry(number: 59, seed: 0x80ae19095c7aa1d6, band: 3, budget: 15),
        AcousticConstellatorManifestEntry(number: 60, seed: 0x1bb539c811723fd3, band: 3, budget: 12),
        AcousticConstellatorManifestEntry(number: 61, seed: 0xeb6d8b785dda0aee, band: 4, budget: 15),
        AcousticConstellatorManifestEntry(number: 62, seed: 0x8e615508afe79802, band: 4, budget: 16),
        AcousticConstellatorManifestEntry(number: 63, seed: 0x40e2e8ad9b7818e3, band: 4, budget: 17),
        AcousticConstellatorManifestEntry(number: 64, seed: 0x2f926799f8a58bca, band: 4, budget: 14),
        AcousticConstellatorManifestEntry(number: 65, seed: 0xe1a66248e58a3138, band: 4, budget: 15),
        AcousticConstellatorManifestEntry(number: 66, seed: 0x3854656b37cdbe18, band: 4, budget: 16),
        AcousticConstellatorManifestEntry(number: 67, seed: 0xf69a91e4bd80744e, band: 4, budget: 17),
        AcousticConstellatorManifestEntry(number: 68, seed: 0x73056db49cc0a36a, band: 4, budget: 14),
        AcousticConstellatorManifestEntry(number: 69, seed: 0xcfce68fc103c8152, band: 4, budget: 15),
        AcousticConstellatorManifestEntry(number: 70, seed: 0xe1d5de0d3f8c822b, band: 4, budget: 16),
        AcousticConstellatorManifestEntry(number: 71, seed: 0x8176ff640464d98a, band: 4, budget: 17),
        AcousticConstellatorManifestEntry(number: 72, seed: 0xe79a40c982ac84e5, band: 4, budget: 14),
        AcousticConstellatorManifestEntry(number: 73, seed: 0x6572d950ebf9b813, band: 4, budget: 15),
        AcousticConstellatorManifestEntry(number: 74, seed: 0x9548583ae54aabe8, band: 4, budget: 16),
        AcousticConstellatorManifestEntry(number: 75, seed: 0x2a2b64dab30febac, band: 4, budget: 17),
        AcousticConstellatorManifestEntry(number: 76, seed: 0x8d23b0731a1baabd, band: 4, budget: 14),
        AcousticConstellatorManifestEntry(number: 77, seed: 0x302f27f667860294, band: 4, budget: 15),
        AcousticConstellatorManifestEntry(number: 78, seed: 0xd9c4beb485adf374, band: 4, budget: 16),
        AcousticConstellatorManifestEntry(number: 79, seed: 0x565758cae2360e5c, band: 4, budget: 17),
        AcousticConstellatorManifestEntry(number: 80, seed: 0x2be5d201d05cd5a3, band: 4, budget: 14),
        AcousticConstellatorManifestEntry(number: 81, seed: 0x39bf36676a5a2afe, band: 5, budget: 17),
        AcousticConstellatorManifestEntry(number: 82, seed: 0xc923f06a3581c775, band: 5, budget: 18),
        AcousticConstellatorManifestEntry(number: 83, seed: 0xa001d7b3cf98c13c, band: 5, budget: 19),
        AcousticConstellatorManifestEntry(number: 84, seed: 0x5e981f6fb899c320, band: 5, budget: 16),
        AcousticConstellatorManifestEntry(number: 85, seed: 0x84f6cce2beba0c31, band: 5, budget: 17),
        AcousticConstellatorManifestEntry(number: 86, seed: 0xc2059a2176ba7bb6, band: 5, budget: 18),
        AcousticConstellatorManifestEntry(number: 87, seed: 0xae192dae885574b6, band: 5, budget: 19),
        AcousticConstellatorManifestEntry(number: 88, seed: 0x727b676c38cba4f1, band: 5, budget: 16),
        AcousticConstellatorManifestEntry(number: 89, seed: 0x39f7893bf59b42ec, band: 5, budget: 17),
        AcousticConstellatorManifestEntry(number: 90, seed: 0xb9e19cbb2b6d11fc, band: 5, budget: 18),
        AcousticConstellatorManifestEntry(number: 91, seed: 0xe7cf500b8869a668, band: 5, budget: 19),
        AcousticConstellatorManifestEntry(number: 92, seed: 0xa1aa68974a241509, band: 5, budget: 16),
        AcousticConstellatorManifestEntry(number: 93, seed: 0x416b9a4b2e10ab5c, band: 5, budget: 17),
        AcousticConstellatorManifestEntry(number: 94, seed: 0xa318e4433ef9c340, band: 5, budget: 18),
        AcousticConstellatorManifestEntry(number: 95, seed: 0x71a69cd7f75e3095, band: 5, budget: 19),
        AcousticConstellatorManifestEntry(number: 96, seed: 0x745bcb9d85ca3ee4, band: 5, budget: 16),
        AcousticConstellatorManifestEntry(number: 97, seed: 0x943ecc8774d1eb1e, band: 5, budget: 17),
        AcousticConstellatorManifestEntry(number: 98, seed: 0x4020763a5000db3f, band: 5, budget: 18),
        AcousticConstellatorManifestEntry(number: 99, seed: 0xfe30e2223cbcbee4, band: 5, budget: 19),
        AcousticConstellatorManifestEntry(number: 100, seed: 0x6a79205b204dd0c7, band: 5, budget: 16),
    ]
}
