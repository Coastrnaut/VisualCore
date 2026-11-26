// MicroscopicAuroraManifest — feature 482 (R02-G19-02) T-R02G1902-002 (FR-R02G1902-001; clarification Q1). The 100
// planned levels of Microscopic Aurora's archived design: number, planned seed, band 1 … 5, moves budget 8 … 19 and
// control emphasis, 20 per band, copied from `python3 scripts/planning_index.py levels --experience R02-G19`.

/// One planned level of the manifest.
public struct MicroscopicAuroraManifestEntry: Sendable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed.
    public let seed: UInt64
    /// The difficulty band, 1 … 5.
    public let band: Int
    /// The moves budget, 8 … 19.
    public let budget: Int
    /// The control emphasis.
    public let emphasis: String

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int, emphasis: String) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
        self.emphasis = emphasis
    }
}

/// The 100 planned levels in manifest order.
public enum MicroscopicAuroraManifest {
    /// Where the entries come from.
    public static let provenance: String =
        "docs/archive/planning/rounds/round2.md, section 6.19.5 "
        + "(python3 scripts/planning_index.py levels --experience R02-G19)"

    /// The entries, levels 1 … 100.
    public static let entries: [MicroscopicAuroraManifestEntry] = [
        e(1, 0xf27c55c194715c36, 1, 9, "record trail"),
        e(2, 0x1afaaf60bbbf5c3a, 1, 10, "commit organism shape"),
        e(3, 0x00ba0ef77b58f372, 1, 11, "place magnetic pole"),
        e(4, 0xb06059aec77605ef, 1, 8, "tune field"),
        e(5, 0x8ab595a581230ac0, 1, 9, "release swimmers"),
        e(6, 0x255c67072a2b9517, 1, 10, "record trail"),
        e(7, 0x83e5de28e53551fc, 1, 11, "commit organism shape"),
        e(8, 0x6ab3e7c38f9d6385, 1, 8, "place magnetic pole"),
        e(9, 0x8c763fab10072bce, 1, 9, "tune field"),
        e(10, 0x8dc9aa70f5ed038b, 1, 10, "release swimmers"),
        e(11, 0xfa182478c3141518, 1, 11, "record trail"),
        e(12, 0x8e964f0a0720c9ce, 1, 8, "commit organism shape"),
        e(13, 0x43dba3c27b7f34cb, 1, 9, "place magnetic pole"),
        e(14, 0xa1d90b6a507b5df6, 1, 10, "tune field"),
        e(15, 0x697eb168df0e014e, 1, 11, "release swimmers"),
        e(16, 0x5050d00b88aba04d, 1, 8, "record trail"),
        e(17, 0xe62d6ede94070637, 1, 9, "commit organism shape"),
        e(18, 0x4fa3c99e3f4d1aab, 1, 10, "place magnetic pole"),
        e(19, 0x143ffebb6a30d4da, 1, 11, "tune field"),
        e(20, 0x45af9774fb413fc3, 1, 8, "release swimmers"),
        e(21, 0x355335e2d6f88617, 2, 11, "record trail"),
        e(22, 0x969f1d888a3bb6a8, 2, 12, "commit organism shape"),
        e(23, 0x7f56addb0f514171, 2, 13, "place magnetic pole"),
        e(24, 0x36d62339492a8536, 2, 10, "tune field"),
        e(25, 0x01942e942381427a, 2, 11, "release swimmers"),
        e(26, 0xfceb3343e7b5b61b, 2, 12, "record trail"),
        e(27, 0x3a1c79c4c20e3689, 2, 13, "commit organism shape"),
        e(28, 0xfa1f763be93c54d9, 2, 10, "place magnetic pole"),
        e(29, 0x3fa2d5d5a39bda18, 2, 11, "tune field"),
        e(30, 0x1d4d3a54b7d9b9fc, 2, 12, "release swimmers"),
        e(31, 0x3fbc6ba6016b46ff, 2, 13, "record trail"),
        e(32, 0xacb70c50583782a1, 2, 10, "commit organism shape"),
        e(33, 0x7a9ea5f24e89bd35, 2, 11, "place magnetic pole"),
        e(34, 0xab8fd56274cd3077, 2, 12, "tune field"),
        e(35, 0x2f9cf6d2ccfa2aaa, 2, 13, "release swimmers"),
        e(36, 0xf707fc0b44b39521, 2, 10, "record trail"),
        e(37, 0x3896938b525b29ec, 2, 11, "commit organism shape"),
        e(38, 0xa411cc355541a228, 2, 12, "place magnetic pole"),
        e(39, 0xbfcecdaeac5c2422, 2, 13, "tune field"),
        e(40, 0xa41275473f4b6bd6, 2, 10, "release swimmers"),
        e(41, 0xc67135b4b8d9a828, 3, 13, "record trail"),
        e(42, 0xff54cfe99244f10c, 3, 14, "commit organism shape"),
        e(43, 0x16098e9ba988ae79, 3, 15, "place magnetic pole"),
        e(44, 0x09da4af2985faa23, 3, 12, "tune field"),
        e(45, 0xfc8d9c72d7f2cb1f, 3, 13, "release swimmers"),
        e(46, 0xfd34d0c5911abf46, 3, 14, "record trail"),
        e(47, 0x0bbb4479a91f30fc, 3, 15, "commit organism shape"),
        e(48, 0x98be82cef3bf0f77, 3, 12, "place magnetic pole"),
        e(49, 0x60f77281bf076417, 3, 13, "tune field"),
        e(50, 0xfd335024b0760d4e, 3, 14, "release swimmers"),
        e(51, 0x6f460f80a00d7697, 3, 15, "record trail"),
        e(52, 0x8c5c49f008318635, 3, 12, "commit organism shape"),
        e(53, 0x7d33e288750c4d74, 3, 13, "place magnetic pole"),
        e(54, 0x21c9cd249c6c3254, 3, 14, "tune field"),
        e(55, 0xe7b1a6dca24e602f, 3, 15, "release swimmers"),
        e(56, 0x2d9e76a420420bcc, 3, 12, "record trail"),
        e(57, 0x53d6ac33a1715f37, 3, 13, "commit organism shape"),
        e(58, 0xd66d6149396e0592, 3, 14, "place magnetic pole"),
        e(59, 0xf6779823a37eca4d, 3, 15, "tune field"),
        e(60, 0x9ab0f459f2a96cfd, 3, 12, "release swimmers"),
        e(61, 0x486d6e9e179228ca, 4, 15, "record trail"),
        e(62, 0x9f08b0f5f779cb7f, 4, 16, "commit organism shape"),
        e(63, 0xaa49a4e9e6f493c8, 4, 17, "place magnetic pole"),
        e(64, 0xba3fb004a6fd1a9b, 4, 14, "tune field"),
        e(65, 0xe075a0c7cf79e2c4, 4, 15, "release swimmers"),
        e(66, 0xf011b2db9957c731, 4, 16, "record trail"),
        e(67, 0xa38a9d8d2c455c32, 4, 17, "commit organism shape"),
        e(68, 0x9ea2ce2d9f963605, 4, 14, "place magnetic pole"),
        e(69, 0xd44ad96621d9c804, 4, 15, "tune field"),
        e(70, 0x22dfc433a6b99db7, 4, 16, "release swimmers"),
        e(71, 0x40bb5ef8649fc8cd, 4, 17, "record trail"),
        e(72, 0x75765c36d752c9d5, 4, 14, "commit organism shape"),
        e(73, 0x9c8d0a897793f28a, 4, 15, "place magnetic pole"),
        e(74, 0xd01d9734b3dbe10a, 4, 16, "tune field"),
        e(75, 0x83c832e322a1e86d, 4, 17, "release swimmers"),
        e(76, 0xec4276a5e14ffc01, 4, 14, "record trail"),
        e(77, 0xd03f73946e9eeea8, 4, 15, "commit organism shape"),
        e(78, 0x9319a778679323fb, 4, 16, "place magnetic pole"),
        e(79, 0x433f0e6af538eeac, 4, 17, "tune field"),
        e(80, 0x3ffa32413ba68612, 4, 14, "release swimmers"),
        e(81, 0x7f76278735bcd767, 5, 17, "record trail"),
        e(82, 0x661b65f85845661e, 5, 18, "commit organism shape"),
        e(83, 0x27c842b0d7ef8146, 5, 19, "place magnetic pole"),
        e(84, 0x3da3090ba0651c00, 5, 16, "tune field"),
        e(85, 0x376595ea2f5ef063, 5, 17, "release swimmers"),
        e(86, 0x25b95c11b7786da7, 5, 18, "record trail"),
        e(87, 0x9308504084dbe551, 5, 19, "commit organism shape"),
        e(88, 0x52fedcafe981e7d9, 5, 16, "place magnetic pole"),
        e(89, 0x10ce929206f3e299, 5, 17, "tune field"),
        e(90, 0x7b4677df9a7fe095, 5, 18, "release swimmers"),
        e(91, 0x1b1fc3403195a0e5, 5, 19, "record trail"),
        e(92, 0x69966b367a7dc071, 5, 16, "commit organism shape"),
        e(93, 0x8c6f9a93d0b74adc, 5, 17, "place magnetic pole"),
        e(94, 0x2c20392fcf7ec914, 5, 18, "tune field"),
        e(95, 0xf511e823cef2c2af, 5, 19, "release swimmers"),
        e(96, 0x31c2bafc1ae3d049, 5, 16, "record trail"),
        e(97, 0x0de294e1e1266406, 5, 17, "commit organism shape"),
        e(98, 0x85ec9896456967d9, 5, 18, "place magnetic pole"),
        e(99, 0x36f193ef7b3b8570, 5, 19, "tune field"),
        e(100, 0xd4122b70d1e4bab7, 5, 16, "release swimmers"),
    ]

    /// An entry of the table.
    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int,
                          _ emphasis: String) -> MicroscopicAuroraManifestEntry {
        MicroscopicAuroraManifestEntry(number: number, seed: seed, band: band, budget: budget, emphasis: emphasis)
    }
}
