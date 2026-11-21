// HueCompassManifest — feature 332 (R02-G04-02) T-R02G0402-002 (FR-R02G0402-001; clarification Q1). The 100 planned
// levels of Hue Compass, copied from the project's own archived design (docs/archive/planning/rounds/round2.md, the
// R02-G04 level table; `python3 scripts/planning_index.py levels --experience R02-G04`): number, planned seed, band and
// move budget.

/// One planned level: its number, planned seed, band and move budget.
public struct HueCompassManifestEntry: Sendable, Equatable, Hashable, Codable {
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

/// The 100 planned levels of Hue Compass in order.
public enum HueCompassManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G04 level table)"

    /// The entries, numbers 1 … 100 in order, 20 in each band.
    public static let entries: [HueCompassManifestEntry] = [
        e(1, 0x447ee2e2cd7c508e, 1, 9), e(2, 0x101141af374d8f2b, 1, 10),
        e(3, 0x0f69e270ad320436, 1, 11), e(4, 0xb608a971bae49b58, 1, 8),
        e(5, 0xd8744e16bcc35972, 1, 9), e(6, 0x5cb8de344ca43666, 1, 10),
        e(7, 0x01cf66cb028829dc, 1, 11), e(8, 0xdb2bede3a3e547a2, 1, 8),
        e(9, 0x4fb15d7324da4d65, 1, 9), e(10, 0xc4e8f85be1524406, 1, 10),
        e(11, 0x35cd9f2c34e3828b, 1, 11), e(12, 0xa5420c2d529f4224, 1, 8),
        e(13, 0x143a8a8836ab31f6, 1, 9), e(14, 0x8f4a2421c8da07a4, 1, 10),
        e(15, 0x0ddeb06371724be6, 1, 11), e(16, 0x208781b9bb157f23, 1, 8),
        e(17, 0x8d5c4e5cc9b13f92, 1, 9), e(18, 0x6c01deec00241289, 1, 10),
        e(19, 0x63456e898f4652bf, 1, 11), e(20, 0x63ff7d739a15894c, 1, 8),
        e(21, 0xfda810a0beba5d88, 2, 11), e(22, 0x1cd0300c6af74073, 2, 12),
        e(23, 0x5988811275fb37a0, 2, 13), e(24, 0x3fdc7dd1a8228524, 2, 10),
        e(25, 0xe7888dbb0860b95f, 2, 11), e(26, 0x7a11f279eb8f350e, 2, 12),
        e(27, 0x41305ea489c5fec4, 2, 13), e(28, 0x19d74c5c13da4f96, 2, 10),
        e(29, 0x883ceb9f386bcc7a, 2, 11), e(30, 0x4fe2f22d3c17c52f, 2, 12),
        e(31, 0xe454871acf945841, 2, 13), e(32, 0x5c4731564f2e5a86, 2, 10),
        e(33, 0xa23abb35dfced868, 2, 11), e(34, 0x9dfbe348d13b39ae, 2, 12),
        e(35, 0x78bad324cb8e76f2, 2, 13), e(36, 0x68a1d3b6d6ae4416, 2, 10),
        e(37, 0x0e380286d30ea603, 2, 11), e(38, 0x82c6d662f429651a, 2, 12),
        e(39, 0x7cb89d585cd0453a, 2, 13), e(40, 0xd88be01f29075515, 2, 10),
        e(41, 0x546c8546215417af, 3, 13), e(42, 0xf9ae965441360422, 3, 14),
        e(43, 0x5774adba0dc1899c, 3, 15), e(44, 0x089513bfdfb35193, 3, 12),
        e(45, 0xebe80984e1a74252, 3, 13), e(46, 0x061834b9597452fb, 3, 14),
        e(47, 0xe595be96e5e20448, 3, 15), e(48, 0x139d2a3e008f2bae, 3, 12),
        e(49, 0x94144d6beef1988d, 3, 13), e(50, 0x98fac226e6d155b7, 3, 14),
        e(51, 0xe15d52f26561d680, 3, 15), e(52, 0x57096377b9c3659f, 3, 12),
        e(53, 0xaae9950c518149ba, 3, 13), e(54, 0xa8ad04e761b4f2fa, 3, 14),
        e(55, 0x2074881e9fdc47f7, 3, 15), e(56, 0x0463585f426332fe, 3, 12),
        e(57, 0x8d905fb1fa2ea0ba, 3, 13), e(58, 0x69e7a1437f2531eb, 3, 14),
        e(59, 0xc2f854ca5e65228f, 3, 15), e(60, 0xf81040117a656080, 3, 12),
        e(61, 0x8b96bcd1a9ba6d6c, 4, 15), e(62, 0x335db3a8e9c69630, 4, 16),
        e(63, 0x3e9b46860d9bc5b5, 4, 17), e(64, 0x7886232b2b12e8b7, 4, 14),
        e(65, 0x8543afb9d8539bc1, 4, 15), e(66, 0xbf187b4df7ecc070, 4, 16),
        e(67, 0x1ce4d38b25530423, 4, 17), e(68, 0x4dac479dca4d4ff7, 4, 14),
        e(69, 0xc1b00474537961e3, 4, 15), e(70, 0x521289c66df860fa, 4, 16),
        e(71, 0x233a9d64033f1bf4, 4, 17), e(72, 0x32b8f8f677553183, 4, 14),
        e(73, 0x358bbf1ee2bb824d, 4, 15), e(74, 0xdbc5b902766d3f67, 4, 16),
        e(75, 0x264016696cdd3e23, 4, 17), e(76, 0x70df7e70a805b85c, 4, 14),
        e(77, 0x605cd98fd567a9a0, 4, 15), e(78, 0x70feaf7487ef00a8, 4, 16),
        e(79, 0x6d4a7c64c012976d, 4, 17), e(80, 0x71056eaba40b0633, 4, 14),
        e(81, 0x304b768d38595593, 5, 17), e(82, 0x08f0b11a3abec5a6, 5, 18),
        e(83, 0xf1a9cbbe0a87a1a6, 5, 19), e(84, 0x68ee20f681db17c7, 5, 16),
        e(85, 0x626a05b944de19de, 5, 17), e(86, 0x2aee54ee5a516538, 5, 18),
        e(87, 0x9226a4a7757c9f70, 5, 19), e(88, 0xcb1b449f95d77dcf, 5, 16),
        e(89, 0xd5f592ccd9eda78f, 5, 17), e(90, 0x267df2c1e01ec377, 5, 18),
        e(91, 0xf2ba51e532586737, 5, 19), e(92, 0x87a7946ea50b8cda, 5, 16),
        e(93, 0x2b2428d53fd847df, 5, 17), e(94, 0x43c7f1d4d21c97e1, 5, 18),
        e(95, 0xc3a7ebd88bf7c9dd, 5, 19), e(96, 0x3e93cdbf8932b01c, 5, 16),
        e(97, 0x41db9c0647369f11, 5, 17), e(98, 0x62ab6c7e55c3f627, 5, 18),
        e(99, 0x385a68697a4b7bfa, 5, 19), e(100, 0xcbdf94f4c1e82807, 5, 16),
    ]

    /// One entry (a short name keeps the table readable).
    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int) -> HueCompassManifestEntry {
        HueCompassManifestEntry(number: number, seed: seed, band: band, budget: budget)
    }
}
