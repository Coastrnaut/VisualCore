// ColorfallCanyonsManifest — feature 342 (R02-G05-02) T-R02G0502-002 (FR-R02G0502-001; clarification Q1). The 100 planned
// levels of Colorfall Canyons, copied from the project's own archived design (docs/archive/planning/rounds/round2.md, the
// R02-G05 level table; `python3 scripts/planning_index.py levels --experience R02-G05`): number, planned seed, band and
// move budget.

/// One planned level: its number, planned seed, band and move budget.
public struct ColorfallCanyonsManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The move budget, which becomes the level's action budget (8 … 19).
    public let budget: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
    }
}

/// The 100 planned levels of Colorfall Canyons in order.
public enum ColorfallCanyonsManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G05 level table)"

    /// The entries, numbers 1 … 100 in order, 20 in each band.
    public static let entries: [ColorfallCanyonsManifestEntry] = [
        e(1, 0xc65bc117d84efa83, 1, 9), e(2, 0xdecc9abd39a0d03b, 1, 10),
        e(3, 0xcb782fc9bab3619d, 1, 11), e(4, 0x0bcfa38ac34eec3d, 1, 8),
        e(5, 0x3a484674410e88f7, 1, 9), e(6, 0x1bf8539446d00635, 1, 10),
        e(7, 0xa3b11133dc64731c, 1, 11), e(8, 0x2fd789d034e64880, 1, 8),
        e(9, 0x257edd2c576e59c9, 1, 9), e(10, 0xcc3d601ca085ab41, 1, 10),
        e(11, 0xdafcf3296ac5f4b7, 1, 11), e(12, 0x67e97d2720cc929b, 1, 8),
        e(13, 0xdb1a11c7dd701365, 1, 9), e(14, 0xbd3ba66a2aeb0268, 1, 10),
        e(15, 0x8d1d788dd5ad9d7e, 1, 11), e(16, 0x4ddd818783f99da5, 1, 8),
        e(17, 0x9c338364c36cb7d2, 1, 9), e(18, 0x7837850f1f32e2e1, 1, 10),
        e(19, 0x4050ecf156475cc5, 1, 11), e(20, 0x3396d4dbeac1b5bc, 1, 8),
        e(21, 0xdf828a7a509d442e, 2, 11), e(22, 0x7e57a8bc7b1e39f8, 2, 12),
        e(23, 0x8caf66f7024d9c9a, 2, 13), e(24, 0x9fa88e7764314b8c, 2, 10),
        e(25, 0xaa13c85eece1a894, 2, 11), e(26, 0xb0216b38470c25a2, 2, 12),
        e(27, 0x9131409e083d14b2, 2, 13), e(28, 0xdae57cf3c5646eb8, 2, 10),
        e(29, 0x262b10b5ff9467e7, 2, 11), e(30, 0x238ac4af74656180, 2, 12),
        e(31, 0x8590d92b3ac5b948, 2, 13), e(32, 0x2f50700cef2b8853, 2, 10),
        e(33, 0xa2f14e9a836efde7, 2, 11), e(34, 0x3471cad1823c02bc, 2, 12),
        e(35, 0x6ae5c906791b4a0c, 2, 13), e(36, 0xa3c00738653ba4b1, 2, 10),
        e(37, 0xccab47a60998cf72, 2, 11), e(38, 0x6b0154c87a796f62, 2, 12),
        e(39, 0x40eeaf203b050ddb, 2, 13), e(40, 0xd2555e977305a81d, 2, 10),
        e(41, 0xd1c576bb8c62643f, 3, 13), e(42, 0x04bc7e46e8e96dc8, 3, 14),
        e(43, 0x467cd3a5b8a5d1dd, 3, 15), e(44, 0xf50a50fb26a25f72, 3, 12),
        e(45, 0x9c2c95a57261f557, 3, 13), e(46, 0x70858dd6673e5cd0, 3, 14),
        e(47, 0x55f407d28f9897da, 3, 15), e(48, 0x79147b188afe4d0c, 3, 12),
        e(49, 0xaeb3860a661e55c9, 3, 13), e(50, 0xa0dbc5c913191617, 3, 14),
        e(51, 0x159b471f54da4c1b, 3, 15), e(52, 0xd0ad2f668cd43148, 3, 12),
        e(53, 0x63a0ff76fa49ab68, 3, 13), e(54, 0x9c481aa37f37c7d9, 3, 14),
        e(55, 0x3b315b657314492d, 3, 15), e(56, 0xf36d9d47e2d1c4b1, 3, 12),
        e(57, 0xa552b50e392b4aec, 3, 13), e(58, 0xfb4ed95f07e82422, 3, 14),
        e(59, 0x204cf9f4d86e2a04, 3, 15), e(60, 0xba04d8fe4221272b, 3, 12),
        e(61, 0xccc610ab037dc747, 4, 15), e(62, 0x452dc914fb63b1bd, 4, 16),
        e(63, 0xcf003d1ad4b514a8, 4, 17), e(64, 0x9eb59f8892cf3ff9, 4, 14),
        e(65, 0xa50864ed79c75d3e, 4, 15), e(66, 0x501d2bab80217868, 4, 16),
        e(67, 0xd5c3f83a5e82e589, 4, 17), e(68, 0xab090a430ab0c9f5, 4, 14),
        e(69, 0x94b68cf8a842b7bb, 4, 15), e(70, 0x41ba63961d73924b, 4, 16),
        e(71, 0x66397c9fe3546b3b, 4, 17), e(72, 0xe6032431ac9178e4, 4, 14),
        e(73, 0x8e8a4086c482b12a, 4, 15), e(74, 0x1f2f12be2f80a222, 4, 16),
        e(75, 0xc6e4bb30a452a51a, 4, 17), e(76, 0x9710e368de913546, 4, 14),
        e(77, 0x8f9964006aa3f4e4, 4, 15), e(78, 0x0a3ee0e9b2724eaa, 4, 16),
        e(79, 0xa56ac44d36853ae6, 4, 17), e(80, 0xe94e258482f96b24, 4, 14),
        e(81, 0xca9acb8df29029fe, 5, 17), e(82, 0xf3ae9a561edc8ea7, 5, 18),
        e(83, 0x638cc4418c5bd627, 5, 19), e(84, 0xfb300a14a8fee2bc, 5, 16),
        e(85, 0x3d55c86374369fbd, 5, 17), e(86, 0xcbe847dee79129d9, 5, 18),
        e(87, 0x641d13e6f0d70340, 5, 19), e(88, 0x9147a105cdb62149, 5, 16),
        e(89, 0x0f3f077062cedcd5, 5, 17), e(90, 0xf14ca9fd25e18724, 5, 18),
        e(91, 0xfedafc4d17193a46, 5, 19), e(92, 0x8778a606637f1ba9, 5, 16),
        e(93, 0x8613e3eaadb870f4, 5, 17), e(94, 0x7568c8dba6382d72, 5, 18),
        e(95, 0x1df7b86b40ee6f68, 5, 19), e(96, 0xe4dc70555381b3b9, 5, 16),
        e(97, 0x41781a66a084c52a, 5, 17), e(98, 0x5c603281ca02ba55, 5, 18),
        e(99, 0x11aa398d38ec0de1, 5, 19), e(100, 0x9f8462018fb76764, 5, 16),
    ]

    /// One entry (a short name keeps the table readable).
    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int) -> ColorfallCanyonsManifestEntry {
        ColorfallCanyonsManifestEntry(number: number, seed: seed, band: band, budget: budget)
    }
}
