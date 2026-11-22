// AmethystEscapeManifest — feature 362 (R02-G07-02) T-R02G0702-002 (FR-R02G0702-001; clarification Q1). The 100
// planned levels of Amethyst Escape, copied from the project's own archived design
// (docs/archive/planning/rounds/round2.md, the R02-G07 level table; `python3 scripts/planning_index.py levels --experience
// R02-G07`): number, planned seed, band and move budget. The catalog is these 100 levels; the chapter header's "80
// solver-certified stages" is a milestone figure only (Auto-Creator.md, R02-G07 chapter).

/// One planned level: its number, planned seed, band and move budget.
public struct AmethystEscapeManifestEntry: Sendable, Equatable, Hashable, Codable {
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

/// The 100 planned levels of Amethyst Escape in order.
public enum AmethystEscapeManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G07 level table)"
    /// The provenance of the entries in words.
    public static let provenance = "The project's own archived design, R02-G07 level table (planning_index.py levels --experience R02-G07)."

    /// The 100 entries, in manifest order.
    public static let entries: [AmethystEscapeManifestEntry] = [
        AmethystEscapeManifestEntry(number: 1, seed: 0x3a12398d70a2912d, band: 1, budget: 9),
        AmethystEscapeManifestEntry(number: 2, seed: 0xbe62ea1894973d0b, band: 1, budget: 10),
        AmethystEscapeManifestEntry(number: 3, seed: 0x7d8b2dd9b533f60b, band: 1, budget: 11),
        AmethystEscapeManifestEntry(number: 4, seed: 0x28f41790f8db85cd, band: 1, budget: 8),
        AmethystEscapeManifestEntry(number: 5, seed: 0xe5b67d96aad8f597, band: 1, budget: 9),
        AmethystEscapeManifestEntry(number: 6, seed: 0x678dba6531c6ef18, band: 1, budget: 10),
        AmethystEscapeManifestEntry(number: 7, seed: 0xaab8836642c3b117, band: 1, budget: 11),
        AmethystEscapeManifestEntry(number: 8, seed: 0x79785c12f0fe04b9, band: 1, budget: 8),
        AmethystEscapeManifestEntry(number: 9, seed: 0xce28cc5f08574dbd, band: 1, budget: 9),
        AmethystEscapeManifestEntry(number: 10, seed: 0x3d9229e15022ce79, band: 1, budget: 10),
        AmethystEscapeManifestEntry(number: 11, seed: 0xd0f4cc5eb29ae8fe, band: 1, budget: 11),
        AmethystEscapeManifestEntry(number: 12, seed: 0x3c7ab3c380ce0dbd, band: 1, budget: 8),
        AmethystEscapeManifestEntry(number: 13, seed: 0x5722eb6861e44df6, band: 1, budget: 9),
        AmethystEscapeManifestEntry(number: 14, seed: 0x557bd8227c013c28, band: 1, budget: 10),
        AmethystEscapeManifestEntry(number: 15, seed: 0x2432b690cf2e1a1a, band: 1, budget: 11),
        AmethystEscapeManifestEntry(number: 16, seed: 0x995468dc74beb26f, band: 1, budget: 8),
        AmethystEscapeManifestEntry(number: 17, seed: 0xbd1a05a4e51b9f8c, band: 1, budget: 9),
        AmethystEscapeManifestEntry(number: 18, seed: 0xec6f5cc48115c508, band: 1, budget: 10),
        AmethystEscapeManifestEntry(number: 19, seed: 0xd7637e3b101e183f, band: 1, budget: 11),
        AmethystEscapeManifestEntry(number: 20, seed: 0x51869aef4e01a9b0, band: 1, budget: 8),
        AmethystEscapeManifestEntry(number: 21, seed: 0xea00bbea4c596daf, band: 2, budget: 11),
        AmethystEscapeManifestEntry(number: 22, seed: 0x193c019ed37f3f93, band: 2, budget: 12),
        AmethystEscapeManifestEntry(number: 23, seed: 0xed4381ef704e8f95, band: 2, budget: 13),
        AmethystEscapeManifestEntry(number: 24, seed: 0x5b0a0184e5d94446, band: 2, budget: 10),
        AmethystEscapeManifestEntry(number: 25, seed: 0x9d201b71e3af3c46, band: 2, budget: 11),
        AmethystEscapeManifestEntry(number: 26, seed: 0x49fe24584f106205, band: 2, budget: 12),
        AmethystEscapeManifestEntry(number: 27, seed: 0xd2b5afd04de6323a, band: 2, budget: 13),
        AmethystEscapeManifestEntry(number: 28, seed: 0x70bfcc9e9173a050, band: 2, budget: 10),
        AmethystEscapeManifestEntry(number: 29, seed: 0xdc9152f59150ddf0, band: 2, budget: 11),
        AmethystEscapeManifestEntry(number: 30, seed: 0xa19615f7c4d53862, band: 2, budget: 12),
        AmethystEscapeManifestEntry(number: 31, seed: 0xe1448d110662c5c3, band: 2, budget: 13),
        AmethystEscapeManifestEntry(number: 32, seed: 0xdc516e89b78b0153, band: 2, budget: 10),
        AmethystEscapeManifestEntry(number: 33, seed: 0x4031a30a7faaff82, band: 2, budget: 11),
        AmethystEscapeManifestEntry(number: 34, seed: 0x545eb577b95e2661, band: 2, budget: 12),
        AmethystEscapeManifestEntry(number: 35, seed: 0x8cd460acdc7d1b7c, band: 2, budget: 13),
        AmethystEscapeManifestEntry(number: 36, seed: 0xb662a3cec2bad100, band: 2, budget: 10),
        AmethystEscapeManifestEntry(number: 37, seed: 0x1f60522fe8331cc0, band: 2, budget: 11),
        AmethystEscapeManifestEntry(number: 38, seed: 0xa4731a2e1fdf4a46, band: 2, budget: 12),
        AmethystEscapeManifestEntry(number: 39, seed: 0xa17354a13479e04f, band: 2, budget: 13),
        AmethystEscapeManifestEntry(number: 40, seed: 0x6006b34b657eb162, band: 2, budget: 10),
        AmethystEscapeManifestEntry(number: 41, seed: 0x69c6f98a331d1370, band: 3, budget: 13),
        AmethystEscapeManifestEntry(number: 42, seed: 0xa5e6b2a5a07bfa84, band: 3, budget: 14),
        AmethystEscapeManifestEntry(number: 43, seed: 0xe758e6b34de0e76d, band: 3, budget: 15),
        AmethystEscapeManifestEntry(number: 44, seed: 0x87f2118b650ac16d, band: 3, budget: 12),
        AmethystEscapeManifestEntry(number: 45, seed: 0x2f85dc3e0f343f4d, band: 3, budget: 13),
        AmethystEscapeManifestEntry(number: 46, seed: 0x484c08ae7be9cf6b, band: 3, budget: 14),
        AmethystEscapeManifestEntry(number: 47, seed: 0xe930196926053efb, band: 3, budget: 15),
        AmethystEscapeManifestEntry(number: 48, seed: 0xa6fa2cd4a6afd127, band: 3, budget: 12),
        AmethystEscapeManifestEntry(number: 49, seed: 0x6f7b0255f6cff2c1, band: 3, budget: 13),
        AmethystEscapeManifestEntry(number: 50, seed: 0x6a57f35bf8008d9f, band: 3, budget: 14),
        AmethystEscapeManifestEntry(number: 51, seed: 0xe24ebf52ff2c03c4, band: 3, budget: 15),
        AmethystEscapeManifestEntry(number: 52, seed: 0xf872d08976c77fb1, band: 3, budget: 12),
        AmethystEscapeManifestEntry(number: 53, seed: 0x39faf0b495f0e8ca, band: 3, budget: 13),
        AmethystEscapeManifestEntry(number: 54, seed: 0x77b39c5eba9ead9a, band: 3, budget: 14),
        AmethystEscapeManifestEntry(number: 55, seed: 0xf4cd5bdde239d4e6, band: 3, budget: 15),
        AmethystEscapeManifestEntry(number: 56, seed: 0x21b39f38e788538e, band: 3, budget: 12),
        AmethystEscapeManifestEntry(number: 57, seed: 0xbff6ad7d4153aae8, band: 3, budget: 13),
        AmethystEscapeManifestEntry(number: 58, seed: 0xfef1c618c7fc43c3, band: 3, budget: 14),
        AmethystEscapeManifestEntry(number: 59, seed: 0x1fe8c047d68cb8f3, band: 3, budget: 15),
        AmethystEscapeManifestEntry(number: 60, seed: 0x18dfb4e4dd8c631a, band: 3, budget: 12),
        AmethystEscapeManifestEntry(number: 61, seed: 0xa915dc0ddb3880e2, band: 4, budget: 15),
        AmethystEscapeManifestEntry(number: 62, seed: 0x99e16ac7e0210be0, band: 4, budget: 16),
        AmethystEscapeManifestEntry(number: 63, seed: 0xdbfc47ea55ff9d33, band: 4, budget: 17),
        AmethystEscapeManifestEntry(number: 64, seed: 0xdbed5d54a8b89bbd, band: 4, budget: 14),
        AmethystEscapeManifestEntry(number: 65, seed: 0x5917632421db4030, band: 4, budget: 15),
        AmethystEscapeManifestEntry(number: 66, seed: 0xfa6c78fc8585f0b7, band: 4, budget: 16),
        AmethystEscapeManifestEntry(number: 67, seed: 0x8c2051f72b54be32, band: 4, budget: 17),
        AmethystEscapeManifestEntry(number: 68, seed: 0xc488e29882b56d18, band: 4, budget: 14),
        AmethystEscapeManifestEntry(number: 69, seed: 0xd42a7e8c05a0121f, band: 4, budget: 15),
        AmethystEscapeManifestEntry(number: 70, seed: 0x127bf736d171f562, band: 4, budget: 16),
        AmethystEscapeManifestEntry(number: 71, seed: 0xe6a4cb1c7e379b36, band: 4, budget: 17),
        AmethystEscapeManifestEntry(number: 72, seed: 0xcf007bb2022ac5cb, band: 4, budget: 14),
        AmethystEscapeManifestEntry(number: 73, seed: 0x70f854dd3b6a53f0, band: 4, budget: 15),
        AmethystEscapeManifestEntry(number: 74, seed: 0xb7bc0ce5499f3f50, band: 4, budget: 16),
        AmethystEscapeManifestEntry(number: 75, seed: 0xe22c01f10fa9f344, band: 4, budget: 17),
        AmethystEscapeManifestEntry(number: 76, seed: 0x8279ae89acdfba74, band: 4, budget: 14),
        AmethystEscapeManifestEntry(number: 77, seed: 0x7e1bf6e68ff88408, band: 4, budget: 15),
        AmethystEscapeManifestEntry(number: 78, seed: 0x386e4d4332ca5e77, band: 4, budget: 16),
        AmethystEscapeManifestEntry(number: 79, seed: 0x5e99375eaf0aaee0, band: 4, budget: 17),
        AmethystEscapeManifestEntry(number: 80, seed: 0x4e8b53ed25076917, band: 4, budget: 14),
        AmethystEscapeManifestEntry(number: 81, seed: 0xc8e3dceffd26c898, band: 5, budget: 17),
        AmethystEscapeManifestEntry(number: 82, seed: 0x86be49fe99b8dc1a, band: 5, budget: 18),
        AmethystEscapeManifestEntry(number: 83, seed: 0xc2ee263ccc49e8eb, band: 5, budget: 19),
        AmethystEscapeManifestEntry(number: 84, seed: 0xa742b6421d264d37, band: 5, budget: 16),
        AmethystEscapeManifestEntry(number: 85, seed: 0xa1ee29812d71c977, band: 5, budget: 17),
        AmethystEscapeManifestEntry(number: 86, seed: 0xce89f0fa097bcbc4, band: 5, budget: 18),
        AmethystEscapeManifestEntry(number: 87, seed: 0x566dd7ae7b2c5942, band: 5, budget: 19),
        AmethystEscapeManifestEntry(number: 88, seed: 0x00f69b9258039111, band: 5, budget: 16),
        AmethystEscapeManifestEntry(number: 89, seed: 0x2ba4c276e9ac70b3, band: 5, budget: 17),
        AmethystEscapeManifestEntry(number: 90, seed: 0x09dddcb750fc32ae, band: 5, budget: 18),
        AmethystEscapeManifestEntry(number: 91, seed: 0x110acff7ce6e0281, band: 5, budget: 19),
        AmethystEscapeManifestEntry(number: 92, seed: 0xb22a1389a1303f60, band: 5, budget: 16),
        AmethystEscapeManifestEntry(number: 93, seed: 0x803ffc13b38c2a24, band: 5, budget: 17),
        AmethystEscapeManifestEntry(number: 94, seed: 0x78134f7e94ec9df1, band: 5, budget: 18),
        AmethystEscapeManifestEntry(number: 95, seed: 0x3903663c583247b6, band: 5, budget: 19),
        AmethystEscapeManifestEntry(number: 96, seed: 0x58d8ecdd46b2e1d6, band: 5, budget: 16),
        AmethystEscapeManifestEntry(number: 97, seed: 0xbd4481251c8e187a, band: 5, budget: 17),
        AmethystEscapeManifestEntry(number: 98, seed: 0x58e2cc9add49b1f3, band: 5, budget: 18),
        AmethystEscapeManifestEntry(number: 99, seed: 0xd8268aa77606ee4a, band: 5, budget: 19),
        AmethystEscapeManifestEntry(number: 100, seed: 0x7d5a962ba537d5b4, band: 5, budget: 16),
    ]
}
