// BinaryGardensManifest — feature 502 (R02-G21-02) T-R02G2102-003 (FR-R02G2102-001; clarification Q1). The 100 planned
// levels of Binary Gardens' archived design: number, planned seed, band 1 … 5, moves budget 8 … 19 (8 … 11, 10 … 13,
// 12 … 15, 14 … 17, 16 … 19 by band) and control emphasis (adjust orbit, phase twin stars, set luminosity, watch world,
// commit light window; 20 each), 20 per band, copied from `python3 scripts/planning_index.py levels --experience
// R02-G21`. The emphasis is provenance: `adjust orbit`, `phase twin stars` and `set luminosity` name the control the
// generator makes adjustable first; `watch world` and `commit light window` name none. Modelled on
// `MushroomWeatherManifest` (feature 492).

/// One planned level of the manifest.
public struct BinaryGardensManifestEntry: Sendable, Hashable, Codable {
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
public enum BinaryGardensManifest {
    /// Where the entries come from.
    public static let provenance: String =
        "docs/archive/planning/rounds/round2.md, section 6.21.18 "
        + "(python3 scripts/planning_index.py levels --experience R02-G21)"

    /// The entries, levels 1 … 100.
    public static let entries: [BinaryGardensManifestEntry] = [
        e(1, 0xb483df8eac48b035, 1, 9, "watch world"),
        e(2, 0x73e15edc9caee5a7, 1, 10, "commit light window"),
        e(3, 0x27e60a5ab8c940b4, 1, 11, "phase twin stars"),
        e(4, 0xc5f5d1e99169ed4a, 1, 8, "adjust orbit"),
        e(5, 0xca7960c9e7e655e0, 1, 9, "set luminosity"),
        e(6, 0x3b870647def8c283, 1, 10, "watch world"),
        e(7, 0x37c3448db343eaeb, 1, 11, "commit light window"),
        e(8, 0x75e6c23f8f849923, 1, 8, "phase twin stars"),
        e(9, 0x5a7485614c68588b, 1, 9, "adjust orbit"),
        e(10, 0x8edee28816d34f2b, 1, 10, "set luminosity"),
        e(11, 0xf827eeaeb0571021, 1, 11, "watch world"),
        e(12, 0xe8920bb25507c65d, 1, 8, "commit light window"),
        e(13, 0x8095553138187cdf, 1, 9, "phase twin stars"),
        e(14, 0x69fe925c996565fe, 1, 10, "adjust orbit"),
        e(15, 0x003d1940923948a4, 1, 11, "set luminosity"),
        e(16, 0xbc4c70dda161163d, 1, 8, "watch world"),
        e(17, 0xc5d51eb486232ee3, 1, 9, "commit light window"),
        e(18, 0x255000457ccd3a9b, 1, 10, "phase twin stars"),
        e(19, 0x09dc9120b4277ade, 1, 11, "adjust orbit"),
        e(20, 0xad4f1689586eb094, 1, 8, "set luminosity"),
        e(21, 0x98c54daab978f003, 2, 11, "watch world"),
        e(22, 0x1405c702ef3b442e, 2, 12, "commit light window"),
        e(23, 0xf507b9f49477a493, 2, 13, "phase twin stars"),
        e(24, 0x5037808e31057c6c, 2, 10, "adjust orbit"),
        e(25, 0x8934f989d6d581a1, 2, 11, "set luminosity"),
        e(26, 0xe531396f71e5c414, 2, 12, "watch world"),
        e(27, 0xc8cc0106ecd4024d, 2, 13, "commit light window"),
        e(28, 0xcb8deaddf29c455e, 2, 10, "phase twin stars"),
        e(29, 0x2bc946d7d6ba4595, 2, 11, "adjust orbit"),
        e(30, 0x08b77e491c0b6fe9, 2, 12, "set luminosity"),
        e(31, 0x3996c8f45b1272a2, 2, 13, "watch world"),
        e(32, 0xddfe042af6b2236e, 2, 10, "commit light window"),
        e(33, 0xe050a9becbeaf876, 2, 11, "phase twin stars"),
        e(34, 0x18d1224471414383, 2, 12, "adjust orbit"),
        e(35, 0x448e2c4a485e1090, 2, 13, "set luminosity"),
        e(36, 0xb371dee80eebb128, 2, 10, "watch world"),
        e(37, 0x8578cfc68cffd72e, 2, 11, "commit light window"),
        e(38, 0xf0b83802efe1fbe1, 2, 12, "phase twin stars"),
        e(39, 0x4c95f0431da14878, 2, 13, "adjust orbit"),
        e(40, 0x3498958a45ddc67c, 2, 10, "set luminosity"),
        e(41, 0x8786d6196ba3074d, 3, 13, "watch world"),
        e(42, 0x5f8d55b3b3d45c6b, 3, 14, "commit light window"),
        e(43, 0x34962a7ad6e2bf59, 3, 15, "phase twin stars"),
        e(44, 0x41230c3e90e90e5f, 3, 12, "adjust orbit"),
        e(45, 0x4ab03970fc230df5, 3, 13, "set luminosity"),
        e(46, 0x5b2b897d7a084c61, 3, 14, "watch world"),
        e(47, 0xe017607a4fc04178, 3, 15, "commit light window"),
        e(48, 0xb85708414ef7faad, 3, 12, "phase twin stars"),
        e(49, 0xdf72ab9fa670f28e, 3, 13, "adjust orbit"),
        e(50, 0xd5b93518ae62f2f8, 3, 14, "set luminosity"),
        e(51, 0xbdff1b866c7ea2a5, 3, 15, "watch world"),
        e(52, 0xa715272fed8f5e43, 3, 12, "commit light window"),
        e(53, 0x203cc146f0ad3b7d, 3, 13, "phase twin stars"),
        e(54, 0xe20b3b96e11e733b, 3, 14, "adjust orbit"),
        e(55, 0x5034146cfb5c14f2, 3, 15, "set luminosity"),
        e(56, 0x749ee98d2402585a, 3, 12, "watch world"),
        e(57, 0xed677adcbf49c55a, 3, 13, "commit light window"),
        e(58, 0xf2d3145493e07e60, 3, 14, "phase twin stars"),
        e(59, 0x6bd9e4844e9112b6, 3, 15, "adjust orbit"),
        e(60, 0x5c2e26dc9c16310a, 3, 12, "set luminosity"),
        e(61, 0xf8491b660af65d10, 4, 15, "watch world"),
        e(62, 0x2dfa7776676fa2c9, 4, 16, "commit light window"),
        e(63, 0x434a4269460e7ded, 4, 17, "phase twin stars"),
        e(64, 0x5f6fd51a6848b59f, 4, 14, "adjust orbit"),
        e(65, 0x7135876dee398cd7, 4, 15, "set luminosity"),
        e(66, 0x113b446b4840fe53, 4, 16, "watch world"),
        e(67, 0xb92868f45bbb38f0, 4, 17, "commit light window"),
        e(68, 0x17cb28081b0a64ee, 4, 14, "phase twin stars"),
        e(69, 0xe13482d23852acd1, 4, 15, "adjust orbit"),
        e(70, 0x5caabb4cb98ad786, 4, 16, "set luminosity"),
        e(71, 0x1c0f1593adeab538, 4, 17, "watch world"),
        e(72, 0x2ee096878f81af1d, 4, 14, "commit light window"),
        e(73, 0x50a550eb89188612, 4, 15, "phase twin stars"),
        e(74, 0x52f883af1c025aee, 4, 16, "adjust orbit"),
        e(75, 0x31dfea44312c6877, 4, 17, "set luminosity"),
        e(76, 0x6e2d87151b24a130, 4, 14, "watch world"),
        e(77, 0xeb313d8d3663fc77, 4, 15, "commit light window"),
        e(78, 0xa79c695c4888d80b, 4, 16, "phase twin stars"),
        e(79, 0x4f5358593f1324a7, 4, 17, "adjust orbit"),
        e(80, 0x721d875787434608, 4, 14, "set luminosity"),
        e(81, 0xbaafd50f29e51b6e, 5, 17, "watch world"),
        e(82, 0xeb0cc83138ddb0dc, 5, 18, "commit light window"),
        e(83, 0xc6063adc9973a037, 5, 19, "phase twin stars"),
        e(84, 0x0bd6eba7bcd082c8, 5, 16, "adjust orbit"),
        e(85, 0xbc7d2dc73815cd72, 5, 17, "set luminosity"),
        e(86, 0x4e2e0487e263f1d8, 5, 18, "watch world"),
        e(87, 0x466b71621a58908b, 5, 19, "commit light window"),
        e(88, 0xaee664e2b2c51210, 5, 16, "phase twin stars"),
        e(89, 0x1075528915543220, 5, 17, "adjust orbit"),
        e(90, 0x95c84d547eb0e4b5, 5, 18, "set luminosity"),
        e(91, 0x68856d0933ceead0, 5, 19, "watch world"),
        e(92, 0x0ee8f19ed7418145, 5, 16, "commit light window"),
        e(93, 0xf19df94338c2e528, 5, 17, "phase twin stars"),
        e(94, 0x9fffa5bab1e72b0d, 5, 18, "adjust orbit"),
        e(95, 0x162243ff095f9654, 5, 19, "set luminosity"),
        e(96, 0xf33bdcb877f295e9, 5, 16, "watch world"),
        e(97, 0xb7f6a39005bfd50e, 5, 17, "commit light window"),
        e(98, 0x4875f18fc1d9c5ae, 5, 18, "phase twin stars"),
        e(99, 0x7391fe8d449dd3a3, 5, 19, "adjust orbit"),
        e(100, 0x7fc44ee7061f946e, 5, 16, "set luminosity"),
    ]

    /// An entry of the table.
    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int,
                          _ emphasis: String) -> BinaryGardensManifestEntry {
        BinaryGardensManifestEntry(number: number, seed: seed, band: band, budget: budget, emphasis: emphasis)
    }
}
