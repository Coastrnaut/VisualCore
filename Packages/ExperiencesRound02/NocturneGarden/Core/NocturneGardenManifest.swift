// NocturneGardenManifest — feature 382 (R02-G09-02) T-R02G0902-002 (FR-R02G0902-001; clarification Q1). The 100 planned
// levels of Nocturne Garden, copied from the project's own archived design (docs/archive/planning/rounds/round2.md, the
// R02-G09 level table; `python3 scripts/planning_index.py levels --experience R02-G09`): number, planned seed, band and
// move budget.

/// One planned level: its number, planned seed, band and move budget.
public struct NocturneGardenManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The move budget, which becomes the level's budget (8 … 19).
    public let budget: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
    }
}

/// The 100 planned levels of Nocturne Garden in order.
public enum NocturneGardenManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G09 level table)"
    /// The provenance of the entries in words.
    public static let provenance =
        "The project's own archived design, R02-G09 level table (planning_index.py levels --experience R02-G09)."

    /// The 100 entries, in manifest order.
    public static let entries: [NocturneGardenManifestEntry] = [
        NocturneGardenManifestEntry(number: 1, seed: 0x5674e2b4cafcef9e, band: 1, budget: 9),
        NocturneGardenManifestEntry(number: 2, seed: 0x55708ab9f27603a9, band: 1, budget: 10),
        NocturneGardenManifestEntry(number: 3, seed: 0x1c16e8b6e50b250b, band: 1, budget: 11),
        NocturneGardenManifestEntry(number: 4, seed: 0x4e2937b85f75e1b0, band: 1, budget: 8),
        NocturneGardenManifestEntry(number: 5, seed: 0xcea99d49b49882d2, band: 1, budget: 9),
        NocturneGardenManifestEntry(number: 6, seed: 0xbebe8068b3656600, band: 1, budget: 10),
        NocturneGardenManifestEntry(number: 7, seed: 0x78affa3e2b53b270, band: 1, budget: 11),
        NocturneGardenManifestEntry(number: 8, seed: 0x949b594ee527f88f, band: 1, budget: 8),
        NocturneGardenManifestEntry(number: 9, seed: 0xaf67a4997738728f, band: 1, budget: 9),
        NocturneGardenManifestEntry(number: 10, seed: 0x5590aa75a185465b, band: 1, budget: 10),
        NocturneGardenManifestEntry(number: 11, seed: 0xb4eaafe27bee433c, band: 1, budget: 11),
        NocturneGardenManifestEntry(number: 12, seed: 0xd327c189ff415735, band: 1, budget: 8),
        NocturneGardenManifestEntry(number: 13, seed: 0x5dd865df272b3829, band: 1, budget: 9),
        NocturneGardenManifestEntry(number: 14, seed: 0xaf0012b522f46fc6, band: 1, budget: 10),
        NocturneGardenManifestEntry(number: 15, seed: 0x048cdd3048a86e31, band: 1, budget: 11),
        NocturneGardenManifestEntry(number: 16, seed: 0x27a1e0e9dfef13b6, band: 1, budget: 8),
        NocturneGardenManifestEntry(number: 17, seed: 0xc1abe55ee3bb2208, band: 1, budget: 9),
        NocturneGardenManifestEntry(number: 18, seed: 0x4389edb5275297e0, band: 1, budget: 10),
        NocturneGardenManifestEntry(number: 19, seed: 0xcfd5b60a7e563277, band: 1, budget: 11),
        NocturneGardenManifestEntry(number: 20, seed: 0x61695fe31d15e377, band: 1, budget: 8),
        NocturneGardenManifestEntry(number: 21, seed: 0x220bc40511225a36, band: 2, budget: 11),
        NocturneGardenManifestEntry(number: 22, seed: 0x12062487fde194d7, band: 2, budget: 12),
        NocturneGardenManifestEntry(number: 23, seed: 0x1b1ffb3c65de8beb, band: 2, budget: 13),
        NocturneGardenManifestEntry(number: 24, seed: 0xa3b3607ed4d24fd7, band: 2, budget: 10),
        NocturneGardenManifestEntry(number: 25, seed: 0x86cfe6f2859cb7dd, band: 2, budget: 11),
        NocturneGardenManifestEntry(number: 26, seed: 0x1eebd5a917870a47, band: 2, budget: 12),
        NocturneGardenManifestEntry(number: 27, seed: 0x703f9ef0ef6cef5d, band: 2, budget: 13),
        NocturneGardenManifestEntry(number: 28, seed: 0x9a208d0e0f4b3478, band: 2, budget: 10),
        NocturneGardenManifestEntry(number: 29, seed: 0x0864360e326a339c, band: 2, budget: 11),
        NocturneGardenManifestEntry(number: 30, seed: 0xa9f494f05f2484be, band: 2, budget: 12),
        NocturneGardenManifestEntry(number: 31, seed: 0xe603b494928a0d05, band: 2, budget: 13),
        NocturneGardenManifestEntry(number: 32, seed: 0x31e4a4983d39481f, band: 2, budget: 10),
        NocturneGardenManifestEntry(number: 33, seed: 0x55b1f234fed97fbb, band: 2, budget: 11),
        NocturneGardenManifestEntry(number: 34, seed: 0xef09adcc0fef14c0, band: 2, budget: 12),
        NocturneGardenManifestEntry(number: 35, seed: 0x862423c5e8a574b3, band: 2, budget: 13),
        NocturneGardenManifestEntry(number: 36, seed: 0xa4073a4d37e65b5b, band: 2, budget: 10),
        NocturneGardenManifestEntry(number: 37, seed: 0x3b10db793d881a02, band: 2, budget: 11),
        NocturneGardenManifestEntry(number: 38, seed: 0xc9fd5cc75e3ad2c1, band: 2, budget: 12),
        NocturneGardenManifestEntry(number: 39, seed: 0x499d947c60bf83c0, band: 2, budget: 13),
        NocturneGardenManifestEntry(number: 40, seed: 0xe09bf9425e305c70, band: 2, budget: 10),
        NocturneGardenManifestEntry(number: 41, seed: 0x214c3e3a76a2fb2c, band: 3, budget: 13),
        NocturneGardenManifestEntry(number: 42, seed: 0xd659d7420eb1b61b, band: 3, budget: 14),
        NocturneGardenManifestEntry(number: 43, seed: 0x6632c3565c06e924, band: 3, budget: 15),
        NocturneGardenManifestEntry(number: 44, seed: 0x88d67e71eb62277b, band: 3, budget: 12),
        NocturneGardenManifestEntry(number: 45, seed: 0xa8b123c18a5add22, band: 3, budget: 13),
        NocturneGardenManifestEntry(number: 46, seed: 0x35ffd562bba89e71, band: 3, budget: 14),
        NocturneGardenManifestEntry(number: 47, seed: 0x228c81a245504864, band: 3, budget: 15),
        NocturneGardenManifestEntry(number: 48, seed: 0xf35ec4f79800b2d4, band: 3, budget: 12),
        NocturneGardenManifestEntry(number: 49, seed: 0x10039f9f07ea6c90, band: 3, budget: 13),
        NocturneGardenManifestEntry(number: 50, seed: 0x769ed7c929d13fc6, band: 3, budget: 14),
        NocturneGardenManifestEntry(number: 51, seed: 0xc5b860a5a80244da, band: 3, budget: 15),
        NocturneGardenManifestEntry(number: 52, seed: 0xcf11cf35653b7ed8, band: 3, budget: 12),
        NocturneGardenManifestEntry(number: 53, seed: 0x9e93475d0bc26a7a, band: 3, budget: 13),
        NocturneGardenManifestEntry(number: 54, seed: 0x00400beeeb1f3e80, band: 3, budget: 14),
        NocturneGardenManifestEntry(number: 55, seed: 0x21872d4a31dafb77, band: 3, budget: 15),
        NocturneGardenManifestEntry(number: 56, seed: 0x35412750b2f0034d, band: 3, budget: 12),
        NocturneGardenManifestEntry(number: 57, seed: 0x2a6fb7e61b9f807b, band: 3, budget: 13),
        NocturneGardenManifestEntry(number: 58, seed: 0x5c1bba22d1c9d4f8, band: 3, budget: 14),
        NocturneGardenManifestEntry(number: 59, seed: 0xe4cff67a7be9e78f, band: 3, budget: 15),
        NocturneGardenManifestEntry(number: 60, seed: 0x9ae69190ca5220e5, band: 3, budget: 12),
        NocturneGardenManifestEntry(number: 61, seed: 0x7a5dcc47451eb95e, band: 4, budget: 15),
        NocturneGardenManifestEntry(number: 62, seed: 0x7c650a5ed98724f7, band: 4, budget: 16),
        NocturneGardenManifestEntry(number: 63, seed: 0x076dd0ba7ef869bc, band: 4, budget: 17),
        NocturneGardenManifestEntry(number: 64, seed: 0x282fb5c9fd5ccf05, band: 4, budget: 14),
        NocturneGardenManifestEntry(number: 65, seed: 0x1ea83bc8b91edd4b, band: 4, budget: 15),
        NocturneGardenManifestEntry(number: 66, seed: 0x5da1b5f7c050f509, band: 4, budget: 16),
        NocturneGardenManifestEntry(number: 67, seed: 0xfa523b597de57b79, band: 4, budget: 17),
        NocturneGardenManifestEntry(number: 68, seed: 0xe34d5d616fa3b778, band: 4, budget: 14),
        NocturneGardenManifestEntry(number: 69, seed: 0xaf1bf9f59d2421d0, band: 4, budget: 15),
        NocturneGardenManifestEntry(number: 70, seed: 0xf875e808cae454a5, band: 4, budget: 16),
        NocturneGardenManifestEntry(number: 71, seed: 0x49a517825c6711ba, band: 4, budget: 17),
        NocturneGardenManifestEntry(number: 72, seed: 0x58cc2c8e027dc970, band: 4, budget: 14),
        NocturneGardenManifestEntry(number: 73, seed: 0xe0caf5c432fec4a2, band: 4, budget: 15),
        NocturneGardenManifestEntry(number: 74, seed: 0x41ebbf8e8d733fad, band: 4, budget: 16),
        NocturneGardenManifestEntry(number: 75, seed: 0xe30b93709f011cc9, band: 4, budget: 17),
        NocturneGardenManifestEntry(number: 76, seed: 0xc9a2c059baae8fff, band: 4, budget: 14),
        NocturneGardenManifestEntry(number: 77, seed: 0xdcf541f2fe6fb01f, band: 4, budget: 15),
        NocturneGardenManifestEntry(number: 78, seed: 0x34cf47b5352a0714, band: 4, budget: 16),
        NocturneGardenManifestEntry(number: 79, seed: 0x8e7e0075a6dff57a, band: 4, budget: 17),
        NocturneGardenManifestEntry(number: 80, seed: 0xabaa0dc80b1c89b7, band: 4, budget: 14),
        NocturneGardenManifestEntry(number: 81, seed: 0x9516859b7030dc00, band: 5, budget: 17),
        NocturneGardenManifestEntry(number: 82, seed: 0x99ea2806227d72d7, band: 5, budget: 18),
        NocturneGardenManifestEntry(number: 83, seed: 0xa4c2de7464d2943b, band: 5, budget: 19),
        NocturneGardenManifestEntry(number: 84, seed: 0x1f730d2c9d4be1e6, band: 5, budget: 16),
        NocturneGardenManifestEntry(number: 85, seed: 0x52b24872fc3ca60d, band: 5, budget: 17),
        NocturneGardenManifestEntry(number: 86, seed: 0xa55148b5379795d0, band: 5, budget: 18),
        NocturneGardenManifestEntry(number: 87, seed: 0x89b42b9f39709061, band: 5, budget: 19),
        NocturneGardenManifestEntry(number: 88, seed: 0x54ca4d2bb0152db3, band: 5, budget: 16),
        NocturneGardenManifestEntry(number: 89, seed: 0xf59ed1f9dec38722, band: 5, budget: 17),
        NocturneGardenManifestEntry(number: 90, seed: 0x318d7017c4629143, band: 5, budget: 18),
        NocturneGardenManifestEntry(number: 91, seed: 0xa9fc16798afb6061, band: 5, budget: 19),
        NocturneGardenManifestEntry(number: 92, seed: 0xddc832e588f60e2d, band: 5, budget: 16),
        NocturneGardenManifestEntry(number: 93, seed: 0xd12492e5300793fe, band: 5, budget: 17),
        NocturneGardenManifestEntry(number: 94, seed: 0xbf66ba3ffc914502, band: 5, budget: 18),
        NocturneGardenManifestEntry(number: 95, seed: 0xc4eaf6d67c5e4c77, band: 5, budget: 19),
        NocturneGardenManifestEntry(number: 96, seed: 0xe40c21ff10b23ece, band: 5, budget: 16),
        NocturneGardenManifestEntry(number: 97, seed: 0x5b7c7ae7d69f72c3, band: 5, budget: 17),
        NocturneGardenManifestEntry(number: 98, seed: 0x903af7b46e9740a2, band: 5, budget: 18),
        NocturneGardenManifestEntry(number: 99, seed: 0x84fd1d6cea0fe53c, band: 5, budget: 19),
        NocturneGardenManifestEntry(number: 100, seed: 0xe711f4235f53a349, band: 5, budget: 16),
    ]
}
