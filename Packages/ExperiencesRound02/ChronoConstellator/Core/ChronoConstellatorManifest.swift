// ChronoConstellatorManifest — feature 352 (R02-G06-02) T-R02G0602-002 (FR-R02G0602-001; clarification Q1). The 100
// planned levels of Chrono Constellator, copied from the project's own archived design
// (docs/archive/planning/rounds/round2.md, the R02-G06 level table; `python3 scripts/planning_index.py levels --experience
// R02-G06`): number, planned seed, band and move budget. The catalog is these 100 levels; the chapter header's "78
// solver-certified stages" is a milestone figure only (Auto-Creator.md, R02-G06 chapter).

/// One planned level: its number, planned seed, band and move budget.
public struct ChronoConstellatorManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The move budget, which becomes the level's edit budget (8 … 19).
    public let budget: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
    }
}

/// The 100 planned levels of Chrono Constellator in order.
public enum ChronoConstellatorManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G06 level table)"

    /// The entries in manifest order.
    public static let entries: [ChronoConstellatorManifestEntry] = [
        e(1, 0x99994f80a5c46202, 1, 9), e(2, 0xd830d9c039e47132, 1, 10),
        e(3, 0xc3f119a9cc2533f8, 1, 11), e(4, 0x1b15abacedb5ea8f, 1, 8),
        e(5, 0x0bf677c8956594b9, 1, 9), e(6, 0x850cce1bfffcd01a, 1, 10),
        e(7, 0xc23ae388700b29c7, 1, 11), e(8, 0x052c5b5a3e786056, 1, 8),
        e(9, 0xdc09d16c60d01812, 1, 9), e(10, 0x7266658a105bd254, 1, 10),
        e(11, 0xa6096ce3b3464c12, 1, 11), e(12, 0x756d22594a180f9b, 1, 8),
        e(13, 0x25fdc984d29f1c77, 1, 9), e(14, 0x3c20b6daf4e03208, 1, 10),
        e(15, 0x5615dd046de14c0e, 1, 11), e(16, 0x60c743d78edd96b5, 1, 8),
        e(17, 0x607734b84332be73, 1, 9), e(18, 0x15f683f71e5eb53c, 1, 10),
        e(19, 0x5e413a832c2d0136, 1, 11), e(20, 0x45943b312634554d, 1, 8),
        e(21, 0x47fdffd9f816a9fb, 2, 11), e(22, 0xf812db1799695fbc, 2, 12),
        e(23, 0x24e63112de4f0f9d, 2, 13), e(24, 0xe777b37b3f003507, 2, 10),
        e(25, 0xb7dd0b2957082c7b, 2, 11), e(26, 0x5d709f4e821a1e97, 2, 12),
        e(27, 0xf40cb6f5e0b2475e, 2, 13), e(28, 0xaf55cef59254c112, 2, 10),
        e(29, 0x312a2450efa71594, 2, 11), e(30, 0x91e7beb61e7284ff, 2, 12),
        e(31, 0x2b42869186b75c3d, 2, 13), e(32, 0xdfc47e72607ee63c, 2, 10),
        e(33, 0x0bc803e7630292f5, 2, 11), e(34, 0x7aa29e6e1bbc1596, 2, 12),
        e(35, 0x6f52590ae59ebfd9, 2, 13), e(36, 0x4cbe3747dbbf08dc, 2, 10),
        e(37, 0xbe7d4bf5e142f9a8, 2, 11), e(38, 0x8a340ca54f72ce7e, 2, 12),
        e(39, 0xb5551699ac9f2b46, 2, 13), e(40, 0xe7355903eae38536, 2, 10),
        e(41, 0xdea149a40561f4e8, 3, 13), e(42, 0x8414e0f1b23b714b, 3, 14),
        e(43, 0x1ae62f2689cdff22, 3, 15), e(44, 0x8392a6c36c1ef0a6, 3, 12),
        e(45, 0xb2d674468bf15a5a, 3, 13), e(46, 0xd417af6ddbb3fd60, 3, 14),
        e(47, 0x99be391480dcc40c, 3, 15), e(48, 0x6c24cab959347637, 3, 12),
        e(49, 0xd1d661ca64798a06, 3, 13), e(50, 0xb384230c45aa0c52, 3, 14),
        e(51, 0x1c13151ee8d0e23e, 3, 15), e(52, 0xede807e6ec751fb3, 3, 12),
        e(53, 0xa8a646b998fcbb3b, 3, 13), e(54, 0x1c895ad405093f69, 3, 14),
        e(55, 0xdb4aa7270e9d147b, 3, 15), e(56, 0xd710706ff08dce24, 3, 12),
        e(57, 0x9fdcd585e6ac7fd0, 3, 13), e(58, 0x6bc4461e0cc45a60, 3, 14),
        e(59, 0x8c306b07e986068c, 3, 15), e(60, 0xa258dbb26cbac856, 3, 12),
        e(61, 0x6633915ce090c55f, 4, 15), e(62, 0xd27bfe5ab4a98fa1, 4, 16),
        e(63, 0x568b4224e2026252, 4, 17), e(64, 0xc83a2b70ec023b1f, 4, 14),
        e(65, 0xd936490cee59b749, 4, 15), e(66, 0x7003ed48e38e7362, 4, 16),
        e(67, 0x7e001e134c7abe35, 4, 17), e(68, 0x10094586ffd82783, 4, 14),
        e(69, 0x551ce57b00899b54, 4, 15), e(70, 0x4104e0f97fd2983d, 4, 16),
        e(71, 0x5c836649ea43842b, 4, 17), e(72, 0x5520983847a25001, 4, 14),
        e(73, 0x914cbd098cddc96c, 4, 15), e(74, 0x3672e1cd67053b79, 4, 16),
        e(75, 0x76023da27b91b5aa, 4, 17), e(76, 0x15bccced74a172c4, 4, 14),
        e(77, 0x0f6fcfdb5833dfbf, 4, 15), e(78, 0xd48c266cbb9798fd, 4, 16),
        e(79, 0xf309da923b87f624, 4, 17), e(80, 0x5832145a7cfaf782, 4, 14),
        e(81, 0xa6d85146f2e545d3, 5, 17), e(82, 0xee7869be2454689c, 5, 18),
        e(83, 0xf1318a67fe9ae0a9, 5, 19), e(84, 0x3be3b2dd74b3662c, 5, 16),
        e(85, 0xc5ef5952658570c8, 5, 17), e(86, 0x092a124c66a8b336, 5, 18),
        e(87, 0x49d07d17b723ce06, 5, 19), e(88, 0x9e80aed2def4568b, 5, 16),
        e(89, 0x8878216fb9ec9a3e, 5, 17), e(90, 0xd400e9b0b627b0b8, 5, 18),
        e(91, 0xa694e54c72b279ec, 5, 19), e(92, 0x770789ebf32cac40, 5, 16),
        e(93, 0xee681e9e36759211, 5, 17), e(94, 0xeecab1120b4a9883, 5, 18),
        e(95, 0x67a4f9be97acbba3, 5, 19), e(96, 0xcf152b6edeb1930e, 5, 16),
        e(97, 0x453f965e12ef9f7b, 5, 17), e(98, 0x3aba3d38d7de2be4, 5, 18),
        e(99, 0xceadb55c67a72b2a, 5, 19), e(100, 0x2ae560a5f12d9b1b, 5, 16),
    ]

    /// One entry (a short name keeps the table readable).
    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int) -> ChronoConstellatorManifestEntry {
        ChronoConstellatorManifestEntry(number: number, seed: seed, band: band, budget: budget)
    }
}
