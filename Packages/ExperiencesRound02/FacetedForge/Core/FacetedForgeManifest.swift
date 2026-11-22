// FacetedForgeManifest — feature 372 (R02-G08-02) T-R02G0802-002 (FR-R02G0802-001; clarification Q1). The 100 planned
// levels of Faceted Forge, copied from the project's own archived design (docs/archive/planning/rounds/round2.md, the
// R02-G08 level table; `python3 scripts/planning_index.py levels --experience R02-G08`): number, planned seed, band and
// move budget. The catalog is these 100 levels; the chapter header's "84 solver-certified stages" is a milestone figure
// only.

/// One planned level: its number, planned seed, band and move budget.
public struct FacetedForgeManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The move budget, which becomes the level's cut budget (8 … 19).
    public let budget: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
    }
}

/// The 100 planned levels of Faceted Forge in order.
public enum FacetedForgeManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G08 level table)"
    /// The provenance of the entries in words.
    public static let provenance =
        "The project's own archived design, R02-G08 level table (planning_index.py levels --experience R02-G08)."

    /// The 100 entries, in manifest order.
    public static let entries: [FacetedForgeManifestEntry] = [
        FacetedForgeManifestEntry(number: 1, seed: 0x84906690be4d2b00, band: 1, budget: 9),
        FacetedForgeManifestEntry(number: 2, seed: 0x66d96841d490cbcb, band: 1, budget: 10),
        FacetedForgeManifestEntry(number: 3, seed: 0xeae5d8b66a9bb232, band: 1, budget: 11),
        FacetedForgeManifestEntry(number: 4, seed: 0x727b353f0fa4f37d, band: 1, budget: 8),
        FacetedForgeManifestEntry(number: 5, seed: 0xb1b181abefe1f5f4, band: 1, budget: 9),
        FacetedForgeManifestEntry(number: 6, seed: 0x40ecadd2b67d7eca, band: 1, budget: 10),
        FacetedForgeManifestEntry(number: 7, seed: 0x3b925aec36ebdc25, band: 1, budget: 11),
        FacetedForgeManifestEntry(number: 8, seed: 0x66c2a233d6e0d298, band: 1, budget: 8),
        FacetedForgeManifestEntry(number: 9, seed: 0xab54f4c44d3c01fb, band: 1, budget: 9),
        FacetedForgeManifestEntry(number: 10, seed: 0x31c55e55066a49db, band: 1, budget: 10),
        FacetedForgeManifestEntry(number: 11, seed: 0x14a61ba68e981dc8, band: 1, budget: 11),
        FacetedForgeManifestEntry(number: 12, seed: 0x99c890951558c14c, band: 1, budget: 8),
        FacetedForgeManifestEntry(number: 13, seed: 0xd1a1f8fdb2f08a5e, band: 1, budget: 9),
        FacetedForgeManifestEntry(number: 14, seed: 0x25ab5e8e18b092ef, band: 1, budget: 10),
        FacetedForgeManifestEntry(number: 15, seed: 0x69c011ad4bf8a7f1, band: 1, budget: 11),
        FacetedForgeManifestEntry(number: 16, seed: 0x7635bfac390d17fd, band: 1, budget: 8),
        FacetedForgeManifestEntry(number: 17, seed: 0x4fe75a6e4c21b2ed, band: 1, budget: 9),
        FacetedForgeManifestEntry(number: 18, seed: 0x4eee9b424abb454c, band: 1, budget: 10),
        FacetedForgeManifestEntry(number: 19, seed: 0xc127089fc0c967de, band: 1, budget: 11),
        FacetedForgeManifestEntry(number: 20, seed: 0xdc5e8a6e0d975c20, band: 1, budget: 8),
        FacetedForgeManifestEntry(number: 21, seed: 0x75edc4464170bf62, band: 2, budget: 11),
        FacetedForgeManifestEntry(number: 22, seed: 0x2258f60cb7ec3e85, band: 2, budget: 12),
        FacetedForgeManifestEntry(number: 23, seed: 0x7dd4c98646028f97, band: 2, budget: 13),
        FacetedForgeManifestEntry(number: 24, seed: 0xd5cf8ae490eaf84d, band: 2, budget: 10),
        FacetedForgeManifestEntry(number: 25, seed: 0x35ac6e34fd124155, band: 2, budget: 11),
        FacetedForgeManifestEntry(number: 26, seed: 0xa896352fbbd2cb4d, band: 2, budget: 12),
        FacetedForgeManifestEntry(number: 27, seed: 0x1e49af5aebca4e11, band: 2, budget: 13),
        FacetedForgeManifestEntry(number: 28, seed: 0xcf86943e75033e74, band: 2, budget: 10),
        FacetedForgeManifestEntry(number: 29, seed: 0xafc6f48da563121d, band: 2, budget: 11),
        FacetedForgeManifestEntry(number: 30, seed: 0x38dc313b1498f995, band: 2, budget: 12),
        FacetedForgeManifestEntry(number: 31, seed: 0x1564b2a504a5cc50, band: 2, budget: 13),
        FacetedForgeManifestEntry(number: 32, seed: 0x0f4e1d879ff114a7, band: 2, budget: 10),
        FacetedForgeManifestEntry(number: 33, seed: 0xe2d5de6d92e67beb, band: 2, budget: 11),
        FacetedForgeManifestEntry(number: 34, seed: 0x1c4e2a692de1ddb6, band: 2, budget: 12),
        FacetedForgeManifestEntry(number: 35, seed: 0xbab423a63a1c9f38, band: 2, budget: 13),
        FacetedForgeManifestEntry(number: 36, seed: 0x97ba4d25de1a45d8, band: 2, budget: 10),
        FacetedForgeManifestEntry(number: 37, seed: 0x48aac7bbb30734e1, band: 2, budget: 11),
        FacetedForgeManifestEntry(number: 38, seed: 0x34e602b18d4a1bd8, band: 2, budget: 12),
        FacetedForgeManifestEntry(number: 39, seed: 0xf16e7efae3a502a1, band: 2, budget: 13),
        FacetedForgeManifestEntry(number: 40, seed: 0xfae6756bf8884943, band: 2, budget: 10),
        FacetedForgeManifestEntry(number: 41, seed: 0xbbf0449cec1223e4, band: 3, budget: 13),
        FacetedForgeManifestEntry(number: 42, seed: 0x9242c36a3ec7e6b2, band: 3, budget: 14),
        FacetedForgeManifestEntry(number: 43, seed: 0xe8b0b28254988e6d, band: 3, budget: 15),
        FacetedForgeManifestEntry(number: 44, seed: 0xae327621cf630451, band: 3, budget: 12),
        FacetedForgeManifestEntry(number: 45, seed: 0x6dbad6cab1101bf0, band: 3, budget: 13),
        FacetedForgeManifestEntry(number: 46, seed: 0xeb2edf8f5662225c, band: 3, budget: 14),
        FacetedForgeManifestEntry(number: 47, seed: 0x88098becdd713cfe, band: 3, budget: 15),
        FacetedForgeManifestEntry(number: 48, seed: 0x125ca9fa09a7dd28, band: 3, budget: 12),
        FacetedForgeManifestEntry(number: 49, seed: 0xc0f347adb6fb6c45, band: 3, budget: 13),
        FacetedForgeManifestEntry(number: 50, seed: 0x3cd6870fcbd64403, band: 3, budget: 14),
        FacetedForgeManifestEntry(number: 51, seed: 0xb31818b19c5fe874, band: 3, budget: 15),
        FacetedForgeManifestEntry(number: 52, seed: 0x60fcf154feb02abc, band: 3, budget: 12),
        FacetedForgeManifestEntry(number: 53, seed: 0x2a519516becccbb7, band: 3, budget: 13),
        FacetedForgeManifestEntry(number: 54, seed: 0x6953694da256ca99, band: 3, budget: 14),
        FacetedForgeManifestEntry(number: 55, seed: 0x6c61b18c18eba884, band: 3, budget: 15),
        FacetedForgeManifestEntry(number: 56, seed: 0x4d6cba81003eaf66, band: 3, budget: 12),
        FacetedForgeManifestEntry(number: 57, seed: 0x1f938be6bba4c1e3, band: 3, budget: 13),
        FacetedForgeManifestEntry(number: 58, seed: 0xa2dc95acef6c5ff6, band: 3, budget: 14),
        FacetedForgeManifestEntry(number: 59, seed: 0xb09eee88999377f2, band: 3, budget: 15),
        FacetedForgeManifestEntry(number: 60, seed: 0x6d05868285cd23bb, band: 3, budget: 12),
        FacetedForgeManifestEntry(number: 61, seed: 0x890d5b2483be612d, band: 4, budget: 15),
        FacetedForgeManifestEntry(number: 62, seed: 0xe4ce99afedc2f3b7, band: 4, budget: 16),
        FacetedForgeManifestEntry(number: 63, seed: 0xddebd71ede331fe4, band: 4, budget: 17),
        FacetedForgeManifestEntry(number: 64, seed: 0x236639f6d94f6734, band: 4, budget: 14),
        FacetedForgeManifestEntry(number: 65, seed: 0xd0bd18bdb0dd3ef5, band: 4, budget: 15),
        FacetedForgeManifestEntry(number: 66, seed: 0x80a1a75d023724a9, band: 4, budget: 16),
        FacetedForgeManifestEntry(number: 67, seed: 0xb442e350bce5d716, band: 4, budget: 17),
        FacetedForgeManifestEntry(number: 68, seed: 0x7fc6fb4f50e67f80, band: 4, budget: 14),
        FacetedForgeManifestEntry(number: 69, seed: 0xbfc9857880fb1401, band: 4, budget: 15),
        FacetedForgeManifestEntry(number: 70, seed: 0x11453a6199ae43a5, band: 4, budget: 16),
        FacetedForgeManifestEntry(number: 71, seed: 0x8d2e516a76d3d3ed, band: 4, budget: 17),
        FacetedForgeManifestEntry(number: 72, seed: 0x47704b4ea41eedd5, band: 4, budget: 14),
        FacetedForgeManifestEntry(number: 73, seed: 0xffa502c286432e70, band: 4, budget: 15),
        FacetedForgeManifestEntry(number: 74, seed: 0xcf6840a6a892efa0, band: 4, budget: 16),
        FacetedForgeManifestEntry(number: 75, seed: 0x0b5d4e91ba2d3ac5, band: 4, budget: 17),
        FacetedForgeManifestEntry(number: 76, seed: 0x348c6db63f042906, band: 4, budget: 14),
        FacetedForgeManifestEntry(number: 77, seed: 0xd53402d29aa9cdb1, band: 4, budget: 15),
        FacetedForgeManifestEntry(number: 78, seed: 0x53476a3ecd03f41e, band: 4, budget: 16),
        FacetedForgeManifestEntry(number: 79, seed: 0x2daf5736aa3d320f, band: 4, budget: 17),
        FacetedForgeManifestEntry(number: 80, seed: 0xda849b012ce2837e, band: 4, budget: 14),
        FacetedForgeManifestEntry(number: 81, seed: 0x6bcef1c658973e15, band: 5, budget: 17),
        FacetedForgeManifestEntry(number: 82, seed: 0x1af507350bdc262e, band: 5, budget: 18),
        FacetedForgeManifestEntry(number: 83, seed: 0x3f0722067d68cb54, band: 5, budget: 19),
        FacetedForgeManifestEntry(number: 84, seed: 0xd8c05ea5ed47d3ee, band: 5, budget: 16),
        FacetedForgeManifestEntry(number: 85, seed: 0xf2c05c8a1b253b7a, band: 5, budget: 17),
        FacetedForgeManifestEntry(number: 86, seed: 0xf5fe0a635ffdc063, band: 5, budget: 18),
        FacetedForgeManifestEntry(number: 87, seed: 0x2cd46c545ad1c8bd, band: 5, budget: 19),
        FacetedForgeManifestEntry(number: 88, seed: 0xfa1274d1f4b6abed, band: 5, budget: 16),
        FacetedForgeManifestEntry(number: 89, seed: 0xa63d7c71c4d7ac65, band: 5, budget: 17),
        FacetedForgeManifestEntry(number: 90, seed: 0xc3a97bacbce0e219, band: 5, budget: 18),
        FacetedForgeManifestEntry(number: 91, seed: 0x73aa6f009c70746d, band: 5, budget: 19),
        FacetedForgeManifestEntry(number: 92, seed: 0x8598846a68b35e68, band: 5, budget: 16),
        FacetedForgeManifestEntry(number: 93, seed: 0x7c1a49df2eb5a6ad, band: 5, budget: 17),
        FacetedForgeManifestEntry(number: 94, seed: 0xb678dd81412b886c, band: 5, budget: 18),
        FacetedForgeManifestEntry(number: 95, seed: 0xa807e83b35ba6653, band: 5, budget: 19),
        FacetedForgeManifestEntry(number: 96, seed: 0xa87b52139455cd7a, band: 5, budget: 16),
        FacetedForgeManifestEntry(number: 97, seed: 0x3fd1a7e063f4defb, band: 5, budget: 17),
        FacetedForgeManifestEntry(number: 98, seed: 0x79d319fadd224eee, band: 5, budget: 18),
        FacetedForgeManifestEntry(number: 99, seed: 0x9239616380e0deaa, band: 5, budget: 19),
        FacetedForgeManifestEntry(number: 100, seed: 0xb3852ae10fba01f7, band: 5, budget: 16),
    ]
}
