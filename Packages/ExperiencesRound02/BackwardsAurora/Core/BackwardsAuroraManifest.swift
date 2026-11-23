// BackwardsAuroraManifest — feature 392 (R02-G10-02) T-R02G1002-002 (FR-R02G1002-001; clarification Q1). The 100
// planned levels of Backwards Aurora, copied from the project's own archived design (docs/archive/planning/rounds/
// round2.md, the R02-G10 level table; `python3 scripts/planning_index.py levels --experience R02-G10`): number, planned
// seed, band and reversal budget.

/// One planned level: its number, planned seed, band and reversal budget.
public struct BackwardsAuroraManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The reversal budget, which becomes the level's budget (8 … 19).
    public let budget: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
    }
}

/// The 100 planned levels of Backwards Aurora in order.
public enum BackwardsAuroraManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G10 level table)"
    /// The provenance of the entries in words.
    public static let provenance =
        "The project's own archived design, R02-G10 level table (planning_index.py levels --experience R02-G10)."

    /// The 100 entries, in manifest order.
    public static let entries: [BackwardsAuroraManifestEntry] = [
        BackwardsAuroraManifestEntry(number: 1, seed: 0xe72f66a4b871c4f6, band: 1, budget: 9),
        BackwardsAuroraManifestEntry(number: 2, seed: 0x6bb68ed587bd24d3, band: 1, budget: 10),
        BackwardsAuroraManifestEntry(number: 3, seed: 0xde6144b2d3527a69, band: 1, budget: 11),
        BackwardsAuroraManifestEntry(number: 4, seed: 0x5453dd7e286c08e1, band: 1, budget: 8),
        BackwardsAuroraManifestEntry(number: 5, seed: 0x662129dc57daf671, band: 1, budget: 9),
        BackwardsAuroraManifestEntry(number: 6, seed: 0xece1bef8bed10a39, band: 1, budget: 10),
        BackwardsAuroraManifestEntry(number: 7, seed: 0x003fa0b6b0ab6300, band: 1, budget: 11),
        BackwardsAuroraManifestEntry(number: 8, seed: 0x2558574355226fd0, band: 1, budget: 8),
        BackwardsAuroraManifestEntry(number: 9, seed: 0xc3cd170b73d83b1e, band: 1, budget: 9),
        BackwardsAuroraManifestEntry(number: 10, seed: 0xe3487d5755b32b40, band: 1, budget: 10),
        BackwardsAuroraManifestEntry(number: 11, seed: 0xd91aa519b95ed05f, band: 1, budget: 11),
        BackwardsAuroraManifestEntry(number: 12, seed: 0x4de2139a024af283, band: 1, budget: 8),
        BackwardsAuroraManifestEntry(number: 13, seed: 0x5841267038dfb2bc, band: 1, budget: 9),
        BackwardsAuroraManifestEntry(number: 14, seed: 0xecdd40a0f1946905, band: 1, budget: 10),
        BackwardsAuroraManifestEntry(number: 15, seed: 0x5af9ca452a66060c, band: 1, budget: 11),
        BackwardsAuroraManifestEntry(number: 16, seed: 0x10e6260e96f29523, band: 1, budget: 8),
        BackwardsAuroraManifestEntry(number: 17, seed: 0x4de00bae591b341a, band: 1, budget: 9),
        BackwardsAuroraManifestEntry(number: 18, seed: 0x6355353349a604fe, band: 1, budget: 10),
        BackwardsAuroraManifestEntry(number: 19, seed: 0x6df5b9af82cfc1b6, band: 1, budget: 11),
        BackwardsAuroraManifestEntry(number: 20, seed: 0x2ff233f9cdc5e769, band: 1, budget: 8),
        BackwardsAuroraManifestEntry(number: 21, seed: 0xbf16be47323bc019, band: 2, budget: 11),
        BackwardsAuroraManifestEntry(number: 22, seed: 0xab446dc90db91949, band: 2, budget: 12),
        BackwardsAuroraManifestEntry(number: 23, seed: 0x901fa97aa61dfc0a, band: 2, budget: 13),
        BackwardsAuroraManifestEntry(number: 24, seed: 0x15d0c2bc17bf16a4, band: 2, budget: 10),
        BackwardsAuroraManifestEntry(number: 25, seed: 0xcd47eecf6a6ccbc1, band: 2, budget: 11),
        BackwardsAuroraManifestEntry(number: 26, seed: 0xb01a22bb9b8af54a, band: 2, budget: 12),
        BackwardsAuroraManifestEntry(number: 27, seed: 0x657eba89221707cd, band: 2, budget: 13),
        BackwardsAuroraManifestEntry(number: 28, seed: 0xbcf1217c8f1315f7, band: 2, budget: 10),
        BackwardsAuroraManifestEntry(number: 29, seed: 0xf2d760ccc20f26c9, band: 2, budget: 11),
        BackwardsAuroraManifestEntry(number: 30, seed: 0x52cebc3e12fc2d67, band: 2, budget: 12),
        BackwardsAuroraManifestEntry(number: 31, seed: 0xf44fff9a328f8572, band: 2, budget: 13),
        BackwardsAuroraManifestEntry(number: 32, seed: 0x7c8e34fa30ccec53, band: 2, budget: 10),
        BackwardsAuroraManifestEntry(number: 33, seed: 0x1167f0a5b3f436b8, band: 2, budget: 11),
        BackwardsAuroraManifestEntry(number: 34, seed: 0x79b34ba42c23b34b, band: 2, budget: 12),
        BackwardsAuroraManifestEntry(number: 35, seed: 0xfc9f598f88cb36c2, band: 2, budget: 13),
        BackwardsAuroraManifestEntry(number: 36, seed: 0xc93dcd95710ac74a, band: 2, budget: 10),
        BackwardsAuroraManifestEntry(number: 37, seed: 0x14aa0f26205b029d, band: 2, budget: 11),
        BackwardsAuroraManifestEntry(number: 38, seed: 0xf394561fc845593e, band: 2, budget: 12),
        BackwardsAuroraManifestEntry(number: 39, seed: 0x6cf3c7e75fa7496b, band: 2, budget: 13),
        BackwardsAuroraManifestEntry(number: 40, seed: 0xe37d99c7a0480689, band: 2, budget: 10),
        BackwardsAuroraManifestEntry(number: 41, seed: 0x60a3401d8e5f1032, band: 3, budget: 13),
        BackwardsAuroraManifestEntry(number: 42, seed: 0x332f699db8a0bc30, band: 3, budget: 14),
        BackwardsAuroraManifestEntry(number: 43, seed: 0xe0dfdd9777bbdcbe, band: 3, budget: 15),
        BackwardsAuroraManifestEntry(number: 44, seed: 0x8eb14bd5ba3fa121, band: 3, budget: 12),
        BackwardsAuroraManifestEntry(number: 45, seed: 0xc775a8038aa10633, band: 3, budget: 13),
        BackwardsAuroraManifestEntry(number: 46, seed: 0xa0d90e84fad7eefb, band: 3, budget: 14),
        BackwardsAuroraManifestEntry(number: 47, seed: 0xf9a3e40ef678c5a8, band: 3, budget: 15),
        BackwardsAuroraManifestEntry(number: 48, seed: 0x8f5a6ae240551101, band: 3, budget: 12),
        BackwardsAuroraManifestEntry(number: 49, seed: 0xe05989e54581aef6, band: 3, budget: 13),
        BackwardsAuroraManifestEntry(number: 50, seed: 0xc76bfc8bdb0ffc39, band: 3, budget: 14),
        BackwardsAuroraManifestEntry(number: 51, seed: 0x3c2b21328547248b, band: 3, budget: 15),
        BackwardsAuroraManifestEntry(number: 52, seed: 0x8f629e81fc8e06f7, band: 3, budget: 12),
        BackwardsAuroraManifestEntry(number: 53, seed: 0x0ff953318a7f1081, band: 3, budget: 13),
        BackwardsAuroraManifestEntry(number: 54, seed: 0x6d4edff12431aefc, band: 3, budget: 14),
        BackwardsAuroraManifestEntry(number: 55, seed: 0x130f1c2be2a7426d, band: 3, budget: 15),
        BackwardsAuroraManifestEntry(number: 56, seed: 0x62cba8fbb2bde131, band: 3, budget: 12),
        BackwardsAuroraManifestEntry(number: 57, seed: 0x0263e6e2b72e3514, band: 3, budget: 13),
        BackwardsAuroraManifestEntry(number: 58, seed: 0xe53aa940a7e42405, band: 3, budget: 14),
        BackwardsAuroraManifestEntry(number: 59, seed: 0xb7ddcdf9945088c0, band: 3, budget: 15),
        BackwardsAuroraManifestEntry(number: 60, seed: 0xe8499c882d1a1583, band: 3, budget: 12),
        BackwardsAuroraManifestEntry(number: 61, seed: 0xc197d4f0a84d5fe6, band: 4, budget: 15),
        BackwardsAuroraManifestEntry(number: 62, seed: 0x0a201f773f1d721d, band: 4, budget: 16),
        BackwardsAuroraManifestEntry(number: 63, seed: 0x3ff5b7c9305fcc06, band: 4, budget: 17),
        BackwardsAuroraManifestEntry(number: 64, seed: 0x8a6dc0c11845be50, band: 4, budget: 14),
        BackwardsAuroraManifestEntry(number: 65, seed: 0x44f528dd32414dd3, band: 4, budget: 15),
        BackwardsAuroraManifestEntry(number: 66, seed: 0x1f696967dd28a480, band: 4, budget: 16),
        BackwardsAuroraManifestEntry(number: 67, seed: 0x98039d5265307b71, band: 4, budget: 17),
        BackwardsAuroraManifestEntry(number: 68, seed: 0xb96ad3880fd7b5bc, band: 4, budget: 14),
        BackwardsAuroraManifestEntry(number: 69, seed: 0xb62eec8ce333b597, band: 4, budget: 15),
        BackwardsAuroraManifestEntry(number: 70, seed: 0x5989a7ccc5993220, band: 4, budget: 16),
        BackwardsAuroraManifestEntry(number: 71, seed: 0xaf9c4f1fa1d12a6d, band: 4, budget: 17),
        BackwardsAuroraManifestEntry(number: 72, seed: 0x8f314f8aff14b7f8, band: 4, budget: 14),
        BackwardsAuroraManifestEntry(number: 73, seed: 0x00bc3cb0e0d51ae5, band: 4, budget: 15),
        BackwardsAuroraManifestEntry(number: 74, seed: 0xf44b75c5db7dc47f, band: 4, budget: 16),
        BackwardsAuroraManifestEntry(number: 75, seed: 0xd3feb104a1e7944d, band: 4, budget: 17),
        BackwardsAuroraManifestEntry(number: 76, seed: 0x60083c0e47744c54, band: 4, budget: 14),
        BackwardsAuroraManifestEntry(number: 77, seed: 0x614d3124f8b19eac, band: 4, budget: 15),
        BackwardsAuroraManifestEntry(number: 78, seed: 0xda825fd9ea24f1f7, band: 4, budget: 16),
        BackwardsAuroraManifestEntry(number: 79, seed: 0x96305be99433a2d9, band: 4, budget: 17),
        BackwardsAuroraManifestEntry(number: 80, seed: 0xfab1d94c612dab68, band: 4, budget: 14),
        BackwardsAuroraManifestEntry(number: 81, seed: 0xb9c6c1ae58104efc, band: 5, budget: 17),
        BackwardsAuroraManifestEntry(number: 82, seed: 0x08b742703967b23b, band: 5, budget: 18),
        BackwardsAuroraManifestEntry(number: 83, seed: 0xdaa96fdddba40f0f, band: 5, budget: 19),
        BackwardsAuroraManifestEntry(number: 84, seed: 0xa053edea1979ca05, band: 5, budget: 16),
        BackwardsAuroraManifestEntry(number: 85, seed: 0xb1ffe30e2c4e15c7, band: 5, budget: 17),
        BackwardsAuroraManifestEntry(number: 86, seed: 0x8b2dbf8d2d34044b, band: 5, budget: 18),
        BackwardsAuroraManifestEntry(number: 87, seed: 0xcac4a9c461cdad66, band: 5, budget: 19),
        BackwardsAuroraManifestEntry(number: 88, seed: 0x4aa7e979f5aff624, band: 5, budget: 16),
        BackwardsAuroraManifestEntry(number: 89, seed: 0x34c540b9f415125f, band: 5, budget: 17),
        BackwardsAuroraManifestEntry(number: 90, seed: 0x1111424f9cb5ceb2, band: 5, budget: 18),
        BackwardsAuroraManifestEntry(number: 91, seed: 0x1d94d9263ddb711b, band: 5, budget: 19),
        BackwardsAuroraManifestEntry(number: 92, seed: 0xb12adc4c3bb30af5, band: 5, budget: 16),
        BackwardsAuroraManifestEntry(number: 93, seed: 0x6781c72d394fe528, band: 5, budget: 17),
        BackwardsAuroraManifestEntry(number: 94, seed: 0x42188c96f33ac85a, band: 5, budget: 18),
        BackwardsAuroraManifestEntry(number: 95, seed: 0x98477771aa382b69, band: 5, budget: 19),
        BackwardsAuroraManifestEntry(number: 96, seed: 0xbe8b714aef36eb98, band: 5, budget: 16),
        BackwardsAuroraManifestEntry(number: 97, seed: 0x2f6f1633b78074d0, band: 5, budget: 17),
        BackwardsAuroraManifestEntry(number: 98, seed: 0x0682bc32349da248, band: 5, budget: 18),
        BackwardsAuroraManifestEntry(number: 99, seed: 0x284f99b683dd68fb, band: 5, budget: 19),
        BackwardsAuroraManifestEntry(number: 100, seed: 0x50adb643e4f2e84f, band: 5, budget: 16),
    ]
}
