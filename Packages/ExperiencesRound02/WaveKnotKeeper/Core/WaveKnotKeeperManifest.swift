// WaveKnotKeeperManifest — feature 322 (R02-G03-02) T-R02G0302-002 (FR-R02G0302-001; clarification Q1). The 100 planned
// levels of Wave Knot Keeper, copied from the project's own archived design (docs/archive/planning/rounds/round2.md, the
// R02-G03 level table; `python3 scripts/planning_index.py levels --experience R02-G03`): number, planned seed, band and
// move budget.

/// One planned level: its number, planned seed, band and move budget.
public struct WaveKnotKeeperManifestEntry: Sendable, Equatable, Hashable, Codable {
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

/// The 100 planned levels of Wave Knot Keeper in order.
public enum WaveKnotKeeperManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G03 level table)"

    /// The entries, numbers 1 … 100 in order, 20 in each band.
    public static let entries: [WaveKnotKeeperManifestEntry] = [
        e(1, 0xee7ead064cea0a86, 1, 9),
        e(2, 0xa5d080a2e24fb971, 1, 10),
        e(3, 0x876d157ab2ab2e87, 1, 11),
        e(4, 0x7fbe273b8b9584dd, 1, 8),
        e(5, 0xc7d193add0b7b23e, 1, 9),
        e(6, 0x5e1e9c4c72a8032d, 1, 10),
        e(7, 0xcea7ab587a0c9d1d, 1, 11),
        e(8, 0x5f49008c2f95777d, 1, 8),
        e(9, 0xab45a9426ff53e19, 1, 9),
        e(10, 0x3724c9cc2aab8212, 1, 10),
        e(11, 0x663905a1c8eaf7fd, 1, 11),
        e(12, 0x268a5664504ca7bf, 1, 8),
        e(13, 0x1da06de06fbdbfbd, 1, 9),
        e(14, 0xf92ae12bb21babb0, 1, 10),
        e(15, 0xd3e4a38e44d8bd88, 1, 11),
        e(16, 0xe356d2ceda604b9a, 1, 8),
        e(17, 0x1b235528a32a6e59, 1, 9),
        e(18, 0x2ff2c5c597217138, 1, 10),
        e(19, 0x08c033a4361ca5ba, 1, 11),
        e(20, 0x59ab26829bde02be, 1, 8),
        e(21, 0xdafb5a06f655ea0e, 2, 11),
        e(22, 0x78e829f6e5b0b4ba, 2, 12),
        e(23, 0xa8de543198032a4d, 2, 13),
        e(24, 0x9f40f8f659e7238d, 2, 10),
        e(25, 0x4305e44d5f6ff935, 2, 11),
        e(26, 0x01139e5a6fdae308, 2, 12),
        e(27, 0x4c7cdc4ea504880c, 2, 13),
        e(28, 0xc6c78c4eef49c9f1, 2, 10),
        e(29, 0xbbc9be1ec82287d6, 2, 11),
        e(30, 0xb67e55ef29acbbb5, 2, 12),
        e(31, 0xdf5b300cd9c987dc, 2, 13),
        e(32, 0x32262e8079aa252a, 2, 10),
        e(33, 0x2812c714beba4e6e, 2, 11),
        e(34, 0x699d3660aef456bc, 2, 12),
        e(35, 0xba9df6f589b30ecc, 2, 13),
        e(36, 0xad85b88824a0a7a8, 2, 10),
        e(37, 0x7ec8c36679321db5, 2, 11),
        e(38, 0xa4bd5b2efa6c4eeb, 2, 12),
        e(39, 0xae1282ff09c57ab2, 2, 13),
        e(40, 0xca540a1299ecf26e, 2, 10),
        e(41, 0xcfc97b6eb1a07658, 3, 13),
        e(42, 0x25c5e2aba2b1a430, 3, 14),
        e(43, 0xb5d9d410e286408b, 3, 15),
        e(44, 0xf84b74e6f42fd808, 3, 12),
        e(45, 0x85fbc705e71739c2, 3, 13),
        e(46, 0xfea2b04f5296329f, 3, 14),
        e(47, 0x2d3b89de7583580b, 3, 15),
        e(48, 0xe5e866f36966599a, 3, 12),
        e(49, 0x85eafd4cd5e643b5, 3, 13),
        e(50, 0xfc58b28f17b00e15, 3, 14),
        e(51, 0x93c285b9b3389a99, 3, 15),
        e(52, 0x66ac100fa0045b77, 3, 12),
        e(53, 0xd781b1ab872d6ad1, 3, 13),
        e(54, 0x0e9bb1a5055e6904, 3, 14),
        e(55, 0x527ca985aa223516, 3, 15),
        e(56, 0x608fa6ad1a3d2cae, 3, 12),
        e(57, 0x81a5e586dbb8b0e2, 3, 13),
        e(58, 0xcae5b78e3c9bf26d, 3, 14),
        e(59, 0x26ef0a2ffa6522cb, 3, 15),
        e(60, 0x33abbab1af411937, 3, 12),
        e(61, 0xc47c408787c001c6, 4, 15),
        e(62, 0xa385acba3107ca02, 4, 16),
        e(63, 0xaa3cb1237f282697, 4, 17),
        e(64, 0x0a763a639d1b0579, 4, 14),
        e(65, 0x1d7d11b9ecd4c1c6, 4, 15),
        e(66, 0x7d4e449bd90cad96, 4, 16),
        e(67, 0x2e212c93440c2d57, 4, 17),
        e(68, 0x34dbf5441bdc6523, 4, 14),
        e(69, 0x7e1e750a21c5d19d, 4, 15),
        e(70, 0xdccee2e5f7665c1a, 4, 16),
        e(71, 0x9279a0015c6b2aa0, 4, 17),
        e(72, 0x89e7cd9cd486ef2f, 4, 14),
        e(73, 0x20c713019ae2d13b, 4, 15),
        e(74, 0xcc8a79a8f6bb1727, 4, 16),
        e(75, 0xb2247ebb0185b673, 4, 17),
        e(76, 0xd480d74818c9983c, 4, 14),
        e(77, 0x1d507cb4ec10f21c, 4, 15),
        e(78, 0xa9c85e84cfa9149f, 4, 16),
        e(79, 0xcebbae53e51d527c, 4, 17),
        e(80, 0xd079e67638cde946, 4, 14),
        e(81, 0x50e50a183f7f1f9e, 5, 17),
        e(82, 0x1aea6da08fd37317, 5, 18),
        e(83, 0x086d437be81141c6, 5, 19),
        e(84, 0xd4766c5229a6df3e, 5, 16),
        e(85, 0x68022811779b5bae, 5, 17),
        e(86, 0xe1ea8862c5ff2d32, 5, 18),
        e(87, 0xc41e19b37410ddf0, 5, 19),
        e(88, 0x5939b318500cdb82, 5, 16),
        e(89, 0x6edb240bd0fec6af, 5, 17),
        e(90, 0xc45b9f06f404d7fd, 5, 18),
        e(91, 0x5f7b5864b91e8620, 5, 19),
        e(92, 0xcecb0240b9d4824e, 5, 16),
        e(93, 0x9e37247aa0226363, 5, 17),
        e(94, 0x644f5df7fd8ce087, 5, 18),
        e(95, 0xc9c4fe3e54caba0c, 5, 19),
        e(96, 0xcc01452be74fe2e8, 5, 16),
        e(97, 0x53870877567a6630, 5, 17),
        e(98, 0x2c2385b25f97a212, 5, 18),
        e(99, 0x7fc38844cceedfe3, 5, 19),
        e(100, 0x4108c3dc32abb7b1, 5, 16),
    ]

    /// One entry (a short name keeps the table readable).
    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int) -> WaveKnotKeeperManifestEntry {
        WaveKnotKeeperManifestEntry(number: number, seed: seed, band: band, budget: budget)
    }
}
