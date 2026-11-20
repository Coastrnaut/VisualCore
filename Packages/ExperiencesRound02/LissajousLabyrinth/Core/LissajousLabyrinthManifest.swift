// LissajousLabyrinthManifest — feature 312 (R02-G02-02) T-R02G0202-002 (FR-R02G0202-001; clarification Q1). The 100
// planned levels of Lissajous Labyrinth, copied from the project's own archived design
// (docs/archive/planning/rounds/round2.md, the R02-G02 level table; `python3 scripts/planning_index.py levels --experience
// R02-G02`): number, planned seed, band and move budget.

/// One planned level: its number, planned seed, band and move budget.
public struct LissajousLabyrinthManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The move budget, which becomes the level's allowance (8 … 19).
    public let budget: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
    }
}

/// The 100 planned levels of Lissajous Labyrinth in order.
public enum LissajousLabyrinthManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G02 level table)"

    /// The entries, numbers 1 … 100 in order, 20 in each band.
    public static let entries: [LissajousLabyrinthManifestEntry] = [
        e(1, 0x85800cda80a90937, 1, 9),
        e(2, 0xfac4a7e34bb4c735, 1, 10),
        e(3, 0xe48953325a9ac27c, 1, 11),
        e(4, 0x77ae172b04a5794d, 1, 8),
        e(5, 0x9056d0361e385787, 1, 9),
        e(6, 0xd3170413047637cc, 1, 10),
        e(7, 0xa65736cf3a5a71d2, 1, 11),
        e(8, 0xb901c6ae4f7e3eb0, 1, 8),
        e(9, 0x8fdd17ccf77da980, 1, 9),
        e(10, 0x1862fe429eea8a95, 1, 10),
        e(11, 0x9400cce3cb5d2a62, 1, 11),
        e(12, 0x220c5023e0d34f97, 1, 8),
        e(13, 0xf3303a0b951f908c, 1, 9),
        e(14, 0xbae26510808c5a0d, 1, 10),
        e(15, 0x70ebd0d07926be13, 1, 11),
        e(16, 0xcd42807ff496abf6, 1, 8),
        e(17, 0x85d7b3ee3de98326, 1, 9),
        e(18, 0x44820309b679b9f1, 1, 10),
        e(19, 0x8f9eb93248bc4074, 1, 11),
        e(20, 0xf43e087c3f3bab0f, 1, 8),
        e(21, 0xd615377b8ddadec8, 2, 11),
        e(22, 0xe188ee47b19688a6, 2, 12),
        e(23, 0x52e5c74f0d49fbc6, 2, 13),
        e(24, 0x6d6a7d041331ab06, 2, 10),
        e(25, 0x7137e9b4feedd003, 2, 11),
        e(26, 0x6425802c98546400, 2, 12),
        e(27, 0x911a4afed1c050be, 2, 13),
        e(28, 0xa6848347a2cdc478, 2, 10),
        e(29, 0xf86c0e59ccfda7e1, 2, 11),
        e(30, 0x6de017d2fe2ef51b, 2, 12),
        e(31, 0x11a8f8f268b60068, 2, 13),
        e(32, 0xfabf9b45c1788538, 2, 10),
        e(33, 0x4b4caded3209f4a2, 2, 11),
        e(34, 0xf99c37e1d334180e, 2, 12),
        e(35, 0x641ef486d0a2b075, 2, 13),
        e(36, 0xf043c2c01aa9a7a3, 2, 10),
        e(37, 0xa904681d53e53a7b, 2, 11),
        e(38, 0x021e399c94256a09, 2, 12),
        e(39, 0xc6d5b1b8f1ec65b4, 2, 13),
        e(40, 0x439461c692a16fa3, 2, 10),
        e(41, 0x099cd2d75e9ee992, 3, 13),
        e(42, 0xf3007b42ba57591e, 3, 14),
        e(43, 0x67b34252d2deb3a0, 3, 15),
        e(44, 0xa07e05fac41235f4, 3, 12),
        e(45, 0xeb24dd9956a8095c, 3, 13),
        e(46, 0x623bcf5fcc58bcf1, 3, 14),
        e(47, 0x872aa33a8267c59b, 3, 15),
        e(48, 0x549fa422d4c0ab2f, 3, 12),
        e(49, 0xf0e19410fcd49e56, 3, 13),
        e(50, 0x9daa171eda246b31, 3, 14),
        e(51, 0xa0b54eada2e194d2, 3, 15),
        e(52, 0xd3f55da36c4bca8f, 3, 12),
        e(53, 0x3be3a520ad70f4d2, 3, 13),
        e(54, 0xc53cc0fdf135413a, 3, 14),
        e(55, 0xc265378b0cd94edf, 3, 15),
        e(56, 0x2b42a3064b931933, 3, 12),
        e(57, 0x829694b470d7cefe, 3, 13),
        e(58, 0x236fe9427667a190, 3, 14),
        e(59, 0xef4beb72e7fe76f3, 3, 15),
        e(60, 0xd3f1e5d70f9252e0, 3, 12),
        e(61, 0x375ad332ecad6993, 4, 15),
        e(62, 0x1195844a1e099862, 4, 16),
        e(63, 0x0a226b29fa386a3e, 4, 17),
        e(64, 0xbc8f0efda95ccb96, 4, 14),
        e(65, 0x7a15004a19b9e505, 4, 15),
        e(66, 0xd67404d29fe7042e, 4, 16),
        e(67, 0xd3e29ba842c23b17, 4, 17),
        e(68, 0xc1c2a05a8f364fbe, 4, 14),
        e(69, 0xbc0fbacb2c79a513, 4, 15),
        e(70, 0x3230ff30eb84ee05, 4, 16),
        e(71, 0x6fa584265dd66ea2, 4, 17),
        e(72, 0xb504a0fb963255f6, 4, 14),
        e(73, 0x00a2dfd022fc1791, 4, 15),
        e(74, 0x69f676a21dc1d1ec, 4, 16),
        e(75, 0x64c516b41cc7ef6e, 4, 17),
        e(76, 0x61d2cd1f2fc3e8ce, 4, 14),
        e(77, 0x71cbb22740984a90, 4, 15),
        e(78, 0xd5d001396db83ee3, 4, 16),
        e(79, 0x3fe56b7e8432ca81, 4, 17),
        e(80, 0xb8a654150f10c40d, 4, 14),
        e(81, 0x18106c2acca77ac8, 5, 17),
        e(82, 0x1ce095bbdc658df5, 5, 18),
        e(83, 0x7d8cb587cbf79c3f, 5, 19),
        e(84, 0x0a6d0884431420a3, 5, 16),
        e(85, 0x64d980230301343d, 5, 17),
        e(86, 0x140cc7a8132230b0, 5, 18),
        e(87, 0x6bcb1c7ce110e0f8, 5, 19),
        e(88, 0x806fb9073e85440d, 5, 16),
        e(89, 0x279bacb10098d7e1, 5, 17),
        e(90, 0x31b8c68b65794c19, 5, 18),
        e(91, 0x5c5c640f2ba4ca18, 5, 19),
        e(92, 0x1ba17613f936343d, 5, 16),
        e(93, 0x2d8a2d865721db91, 5, 17),
        e(94, 0xc3e8e1f00e496042, 5, 18),
        e(95, 0x39718b5ffd7acb46, 5, 19),
        e(96, 0xd848ce3a476a47c2, 5, 16),
        e(97, 0x87cea796ca31c4c1, 5, 17),
        e(98, 0xb5d28901568996cd, 5, 18),
        e(99, 0xeebb0400ee402351, 5, 19),
        e(100, 0xef820edb7be4f3b3, 5, 16),
    ]

    /// One entry (a short name keeps the table readable).
    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int) -> LissajousLabyrinthManifestEntry {
        LissajousLabyrinthManifestEntry(number: number, seed: seed, band: band, budget: budget)
    }
}
