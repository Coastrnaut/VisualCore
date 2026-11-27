// MushroomWeatherManifest — feature 492 (R02-G20-02) T-R02G2002-002 (FR-R02G2002-001; clarification Q1). The 100
// planned levels of Mushroom Weather's archived design: number, planned seed, band 1 … 5, moves budget 8 … 19 and
// control emphasis (route humidity, commit season, place fungus, adjust mist vent, open canopy; 20 each), 20 per band,
// copied from `python3 scripts/planning_index.py levels --experience R02-G20`.

/// One planned level of the manifest.
public struct MushroomWeatherManifestEntry: Sendable, Hashable, Codable {
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
public enum MushroomWeatherManifest {
    /// Where the entries come from.
    public static let provenance: String =
        "docs/archive/planning/rounds/round2.md, section 6.20.18 "
        + "(python3 scripts/planning_index.py levels --experience R02-G20)"

    /// The entries, levels 1 … 100.
    public static let entries: [MushroomWeatherManifestEntry] = [
        e(1, 0x05808a10d0e502e8, 1, 9, "route humidity"),
        e(2, 0x5092d2143a1a8a3d, 1, 10, "commit season"),
        e(3, 0x3d1ed621dac5d55d, 1, 11, "place fungus"),
        e(4, 0x60af0f00a03079d3, 1, 8, "adjust mist vent"),
        e(5, 0x881e4d78c34987d9, 1, 9, "open canopy"),
        e(6, 0xd927e6e82ecc6b8a, 1, 10, "route humidity"),
        e(7, 0xf9dfe9a177daed07, 1, 11, "commit season"),
        e(8, 0x4a18d9bd42eaa1ac, 1, 8, "place fungus"),
        e(9, 0x569f11bf14aec587, 1, 9, "adjust mist vent"),
        e(10, 0x1146d91b081751c1, 1, 10, "open canopy"),
        e(11, 0x29adfe2aa725d362, 1, 11, "route humidity"),
        e(12, 0x9dae0b7e3f4c2443, 1, 8, "commit season"),
        e(13, 0x79acd755cff35d9f, 1, 9, "place fungus"),
        e(14, 0x55f331f9e9977111, 1, 10, "adjust mist vent"),
        e(15, 0x22a0d46a0b287160, 1, 11, "open canopy"),
        e(16, 0x4b392248c5784d14, 1, 8, "route humidity"),
        e(17, 0x0878dbc76991c5bd, 1, 9, "commit season"),
        e(18, 0xed3c5053aca39150, 1, 10, "place fungus"),
        e(19, 0x8f74786178e2e018, 1, 11, "adjust mist vent"),
        e(20, 0x193dfc74280c5b87, 1, 8, "open canopy"),
        e(21, 0x66008f2cdbf75f3d, 2, 11, "route humidity"),
        e(22, 0xaa841d035af1d65f, 2, 12, "commit season"),
        e(23, 0x9a8c0c43c9d88773, 2, 13, "place fungus"),
        e(24, 0xe262b96ee6c94e4a, 2, 10, "adjust mist vent"),
        e(25, 0xc314dccd767f3b79, 2, 11, "open canopy"),
        e(26, 0x47c500fe29fe9642, 2, 12, "route humidity"),
        e(27, 0xf226e3a2e5f0f3a5, 2, 13, "commit season"),
        e(28, 0xa1925a94a505bc1d, 2, 10, "place fungus"),
        e(29, 0x3372949cc3c1def4, 2, 11, "adjust mist vent"),
        e(30, 0xbe3f12ed6b39fc7c, 2, 12, "open canopy"),
        e(31, 0x4124150a6fefd2ec, 2, 13, "route humidity"),
        e(32, 0x8e94d0920e26fd46, 2, 10, "commit season"),
        e(33, 0x26ddcfbdd31bd528, 2, 11, "place fungus"),
        e(34, 0xcd0a3fb54cf123b4, 2, 12, "adjust mist vent"),
        e(35, 0xdea4b69f4dd5b986, 2, 13, "open canopy"),
        e(36, 0xd37f43dd8e12a71c, 2, 10, "route humidity"),
        e(37, 0x3a71e68b1c104704, 2, 11, "commit season"),
        e(38, 0xd863b4ad04666c87, 2, 12, "place fungus"),
        e(39, 0xfdcb8fc83603f6f8, 2, 13, "adjust mist vent"),
        e(40, 0xf13ceb942d7bdb2a, 2, 10, "open canopy"),
        e(41, 0xd1ada18c699c01ba, 3, 13, "route humidity"),
        e(42, 0xda15654376e103e5, 3, 14, "commit season"),
        e(43, 0x15b76c0e42683448, 3, 15, "place fungus"),
        e(44, 0xe08ed8319d0527d3, 3, 12, "adjust mist vent"),
        e(45, 0x93a8a89c96090c04, 3, 13, "open canopy"),
        e(46, 0x24012f0d6e8703e4, 3, 14, "route humidity"),
        e(47, 0x5c762545e2fef1a0, 3, 15, "commit season"),
        e(48, 0x8372c22b898e6fac, 3, 12, "place fungus"),
        e(49, 0x4b0d4c870b7ef9bc, 3, 13, "adjust mist vent"),
        e(50, 0x8974d029ea49c85c, 3, 14, "open canopy"),
        e(51, 0xbbc0c4f6751fe24c, 3, 15, "route humidity"),
        e(52, 0xe5c90184f44bc0d6, 3, 12, "commit season"),
        e(53, 0xa74af67c71aec235, 3, 13, "place fungus"),
        e(54, 0xa74d48ac2d33c187, 3, 14, "adjust mist vent"),
        e(55, 0xdad8017e45a812a1, 3, 15, "open canopy"),
        e(56, 0x484833e883cf6f8b, 3, 12, "route humidity"),
        e(57, 0x7267a898aae25522, 3, 13, "commit season"),
        e(58, 0xa444d6eea8321ae7, 3, 14, "place fungus"),
        e(59, 0x27573bfd2ce3d91f, 3, 15, "adjust mist vent"),
        e(60, 0x8240fa23f6a20df2, 3, 12, "open canopy"),
        e(61, 0x9f50cb1add15979d, 4, 15, "route humidity"),
        e(62, 0xc1d690815bf33365, 4, 16, "commit season"),
        e(63, 0x0e5f9e40cfa0d105, 4, 17, "place fungus"),
        e(64, 0x9bd582e6bd7414a5, 4, 14, "adjust mist vent"),
        e(65, 0x9f650fb374fd13f4, 4, 15, "open canopy"),
        e(66, 0x3663cde819248f79, 4, 16, "route humidity"),
        e(67, 0x47e50bf9255f84b5, 4, 17, "commit season"),
        e(68, 0x6e17148abde732ea, 4, 14, "place fungus"),
        e(69, 0xac930ac41d7911b4, 4, 15, "adjust mist vent"),
        e(70, 0xe12db74ca68b4074, 4, 16, "open canopy"),
        e(71, 0x102864cf9caa4d8c, 4, 17, "route humidity"),
        e(72, 0x8b679096bd34e239, 4, 14, "commit season"),
        e(73, 0x0ad91e946dcbb9a6, 4, 15, "place fungus"),
        e(74, 0x0da1ac5d443f6110, 4, 16, "adjust mist vent"),
        e(75, 0xd02dbc2555016e69, 4, 17, "open canopy"),
        e(76, 0xc23528a0c8dcda8e, 4, 14, "route humidity"),
        e(77, 0xe93c1ea8abcc87a9, 4, 15, "commit season"),
        e(78, 0xeec5705bf8e02133, 4, 16, "place fungus"),
        e(79, 0xb466bd0fa01c2a3d, 4, 17, "adjust mist vent"),
        e(80, 0x89981ceff37ae70d, 4, 14, "open canopy"),
        e(81, 0x2fcc936c39dd81a2, 5, 17, "route humidity"),
        e(82, 0xba919650d1ea7cbd, 5, 18, "commit season"),
        e(83, 0x45b37293997b5510, 5, 19, "place fungus"),
        e(84, 0x6e730f41ad732d38, 5, 16, "adjust mist vent"),
        e(85, 0x2beeb31d5f77b801, 5, 17, "open canopy"),
        e(86, 0xce713cfbea4ae72d, 5, 18, "route humidity"),
        e(87, 0xc068cc92012a6ff1, 5, 19, "commit season"),
        e(88, 0xdeeac45f4aab1433, 5, 16, "place fungus"),
        e(89, 0xb37b45186c895922, 5, 17, "adjust mist vent"),
        e(90, 0xff970645daa63b3b, 5, 18, "open canopy"),
        e(91, 0x4f1598dcd81f68e5, 5, 19, "route humidity"),
        e(92, 0x35dba833977338ce, 5, 16, "commit season"),
        e(93, 0xa34a8dbca6b052d3, 5, 17, "place fungus"),
        e(94, 0x74c2eddb9b7a6580, 5, 18, "adjust mist vent"),
        e(95, 0xffd7c4ea39dfbcea, 5, 19, "open canopy"),
        e(96, 0xfd4b0c718a0b760a, 5, 16, "route humidity"),
        e(97, 0x34b31361fe40f7f4, 5, 17, "commit season"),
        e(98, 0xd13aa1d1d60c53bb, 5, 18, "place fungus"),
        e(99, 0x0477910ddabcd939, 5, 19, "adjust mist vent"),
        e(100, 0x9773b836cb85bc1b, 5, 16, "open canopy"),
    ]

    /// An entry of the table.
    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int,
                          _ emphasis: String) -> MushroomWeatherManifestEntry {
        MushroomWeatherManifestEntry(number: number, seed: seed, band: band, budget: budget, emphasis: emphasis)
    }
}
