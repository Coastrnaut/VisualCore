// AuroraLoomManifest — feature 302 (R02-G01-02) T-R02G0102-002 (FR-R02G0102-001; clarification Q1). The 100 planned
// levels of Aurora Loom, copied from the project's own archived design (docs/archive/planning/rounds/round2.md, the R02-G01 level table;
// `python3 scripts/planning_index.py levels --experience R02-G01`): number, planned seed, band and move budget.

/// One planned level: its number, planned seed, band and move budget.
public struct AuroraLoomManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The move budget, which becomes the level's allowance.
    public let budget: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
    }
}

/// The 100 planned levels of Aurora Loom in order.
public enum AuroraLoomManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G01 level table)"

    /// The entries, numbers 1 … 100 in order, 20 in each band.
    public static let entries: [AuroraLoomManifestEntry] = [
        e(1, 0x5120dc77933d0034, 1, 9),
        e(2, 0x7f3fd681ad78023c, 1, 10),
        e(3, 0xc8bbdd42b2494d5f, 1, 11),
        e(4, 0x9163384f3b012c13, 1, 8),
        e(5, 0xdeda994d7d77a004, 1, 9),
        e(6, 0xcbc3859d46cc811c, 1, 10),
        e(7, 0x2cbd3779c1ac8ab3, 1, 11),
        e(8, 0x4fb8339abf67d8e3, 1, 8),
        e(9, 0xc54228bfc772ba8b, 1, 9),
        e(10, 0xe19532ed185ed4a1, 1, 10),
        e(11, 0x25dc81a8e2ecfd08, 1, 11),
        e(12, 0x264c4f3cd98c1017, 1, 8),
        e(13, 0xaa72ba5f30d1e98c, 1, 9),
        e(14, 0x3478dd7af807a4be, 1, 10),
        e(15, 0x95ae73c45d1a32ff, 1, 11),
        e(16, 0xa8b82a8758c71586, 1, 8),
        e(17, 0x4e971a134f4b4fc6, 1, 9),
        e(18, 0xeb7095f6fdcfb06e, 1, 10),
        e(19, 0x5f0cc1d5ee76b9df, 1, 11),
        e(20, 0xdfcdd1dd687eecbb, 1, 8),
        e(21, 0xdda5122ddde9379c, 2, 11),
        e(22, 0xc3312910ae36dde0, 2, 12),
        e(23, 0xb29caa129b11fdff, 2, 13),
        e(24, 0x6eb5a4960ec66825, 2, 10),
        e(25, 0xe4a41f0ee3fcd3c0, 2, 11),
        e(26, 0xdcf640afd9ea665d, 2, 12),
        e(27, 0x7f72cdaca51a1822, 2, 13),
        e(28, 0x8943a6730ce3887c, 2, 10),
        e(29, 0x0c649c335940369b, 2, 11),
        e(30, 0x65570f1111518d06, 2, 12),
        e(31, 0x1b3960e23d02a181, 2, 13),
        e(32, 0x472f58de37dbea18, 2, 10),
        e(33, 0xc073226705689c5b, 2, 11),
        e(34, 0xec6a5aa7339bf0d4, 2, 12),
        e(35, 0x0a87d1eea5a8aa0a, 2, 13),
        e(36, 0x802b24f11ba1d4ec, 2, 10),
        e(37, 0x4c0dafa249b8a5e9, 2, 11),
        e(38, 0xaafadde42a69f8fc, 2, 12),
        e(39, 0xcceb33e19c29aa8b, 2, 13),
        e(40, 0x7ad0bd3c01391f21, 2, 10),
        e(41, 0x30b4f6d9087c71f2, 3, 13),
        e(42, 0x2b5701066ec7f9c0, 3, 14),
        e(43, 0x0d0a7705391a8749, 3, 15),
        e(44, 0xb4b0fde591973d2c, 3, 12),
        e(45, 0xbb53dd4b97bc2b1e, 3, 13),
        e(46, 0x9c300803112219a9, 3, 14),
        e(47, 0xd8c7154d68b218b2, 3, 15),
        e(48, 0xcc45867268e6962f, 3, 12),
        e(49, 0x98e68c28cc9bc4c0, 3, 13),
        e(50, 0x9f81bf94e220277a, 3, 14),
        e(51, 0x62c494daf3fa3df1, 3, 15),
        e(52, 0x102b0068a56f85ed, 3, 12),
        e(53, 0x39b1320ea1359851, 3, 13),
        e(54, 0x76981fed42344c92, 3, 14),
        e(55, 0xd9d14858410e0a8e, 3, 15),
        e(56, 0x1eb6348b3bb8837c, 3, 12),
        e(57, 0x0d0fac7dd5c34979, 3, 13),
        e(58, 0x8034927718a8909e, 3, 14),
        e(59, 0x66b8cd50ffd9b333, 3, 15),
        e(60, 0x95fe7099ee1680e7, 3, 12),
        e(61, 0xcd4548237766a360, 4, 15),
        e(62, 0x0f31d88e26c38cac, 4, 16),
        e(63, 0x199faebf860a3b8e, 4, 17),
        e(64, 0x2c9a6d88f4bc397f, 4, 14),
        e(65, 0x3f94407518fc57f2, 4, 15),
        e(66, 0x405095337fedf3c2, 4, 16),
        e(67, 0xe16c4ba1492e2f79, 4, 17),
        e(68, 0x7ae827948880f03e, 4, 14),
        e(69, 0x8d0db74deceb1718, 4, 15),
        e(70, 0x349597ff12adad41, 4, 16),
        e(71, 0x1705572768222136, 4, 17),
        e(72, 0x4c9466cf2f039d21, 4, 14),
        e(73, 0xac973114bf19b573, 4, 15),
        e(74, 0x62c306314f4aa2ab, 4, 16),
        e(75, 0x09e061daf11296fe, 4, 17),
        e(76, 0x05dc8a03c2c7b06d, 4, 14),
        e(77, 0x91e8586180ef10d7, 4, 15),
        e(78, 0x7e9bb8c2b7a1894e, 4, 16),
        e(79, 0x6f8c026399fde152, 4, 17),
        e(80, 0x728e26bff0fc7e6a, 4, 14),
        e(81, 0xaf50e099f9e1ff1b, 5, 17),
        e(82, 0xea84069d66202e3d, 5, 18),
        e(83, 0xbef2252466c535ad, 5, 19),
        e(84, 0x58fe50e4d3dba17e, 5, 16),
        e(85, 0x59a0035e966d5d68, 5, 17),
        e(86, 0x4ebfbddb8d1987f9, 5, 18),
        e(87, 0x9721163e347f9e36, 5, 19),
        e(88, 0xde1b1ba8323ce17d, 5, 16),
        e(89, 0xb42352f92edd8c93, 5, 17),
        e(90, 0x70e5a0f006e76b4e, 5, 18),
        e(91, 0x445b3371ddc65689, 5, 19),
        e(92, 0x6e8e6dd87b4dabe2, 5, 16),
        e(93, 0x16749dbcfe0e8a36, 5, 17),
        e(94, 0xf03d7de6d4875662, 5, 18),
        e(95, 0x6b9532b513f0dc79, 5, 19),
        e(96, 0x5a51dfcc32d4ab09, 5, 16),
        e(97, 0x31e28fbb09221961, 5, 17),
        e(98, 0x358cf930227e48a5, 5, 18),
        e(99, 0x417a24bce8082e21, 5, 19),
        e(100, 0xad0494c1c7ea281c, 5, 16),
    ]

    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int) -> AuroraLoomManifestEntry {
        AuroraLoomManifestEntry(number: number, seed: seed, band: band, budget: budget)
    }
}
