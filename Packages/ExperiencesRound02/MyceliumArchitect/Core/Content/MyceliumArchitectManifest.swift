// MyceliumArchitectManifest — feature 512 (R02-G22-02) T-R02G2202-003 (FR-R02G2202-001; clarification Q2). The 100
// planned levels of Mycelium Architect, copied from the project's own archived design: number, planned seed, band,
// moves budget, control emphasis and required concept.

/// One planned level of the manifest.
public struct MyceliumArchitectManifestEntry: Sendable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed.
    public let plannedSeed: UInt64
    /// The difficulty band, 1 … 5.
    public let band: Int
    /// The moves budget, 8 … 19.
    public let budget: Int
    /// The control emphasis: steer growth, commit graph, place nutrient, seed filament or block toxin.
    public let emphasis: String
    /// The required concept named by the entry.
    public let concept: String

    /// An entry of the given values.
    public init(number: Int, plannedSeed: UInt64, band: Int, budget: Int, emphasis: String, concept: String) {
        self.number = number
        self.plannedSeed = plannedSeed
        self.band = band
        self.budget = budget
        self.emphasis = emphasis
        self.concept = concept
    }
}

/// The 100 planned levels in manifest order.
public enum MyceliumArchitectManifest {
    /// Where the entries come from.
    public static let provenance: String =
        "docs/archive/planning/rounds/round2.md, section 6.22.18 "
        + "(python3 scripts/planning_index.py levels --experience R02-G22)"

    /// One entry (a short name keeps the table readable).
    private static func e(_ number: Int, _ seed: UInt64, _ band: Int, _ budget: Int, _ emphasis: String,
                          _ concept: String) -> MyceliumArchitectManifestEntry {
        MyceliumArchitectManifestEntry(number: number, plannedSeed: seed, band: band, budget: budget,
                                       emphasis: emphasis, concept: concept)
    }

    /// The entries, levels 1 … 100.
    public static let entries: [MyceliumArchitectManifestEntry] = [
        e(1, 0x7d51769df89d448c, 1, 9, "steer growth", "bounded branching graph"),
        e(2, 0xa0bb988a8a5f9ef6, 1, 10, "commit graph", "shortest-path nutrients"),
        e(3, 0xc0953a7b1db8d5da, 1, 11, "place nutrient", "root terminal connectivity"),
        e(4, 0x3adff4fc0e45e896, 1, 8, "seed filament", "toxic-zone avoidance"),
        e(5, 0x5898d98c4796b173, 1, 9, "block toxin", "growth budget"),
        e(6, 0xb901f6681d9b298c, 1, 10, "steer growth", "bounded branching graph"),
        e(7, 0x53aa7f14c65e5b72, 1, 11, "commit graph", "shortest-path nutrients"),
        e(8, 0x1f1afdfb248857c9, 1, 8, "place nutrient", "root terminal connectivity"),
        e(9, 0x92a4cd364e5959fe, 1, 9, "seed filament", "toxic-zone avoidance"),
        e(10, 0xf43efb9df576b5b8, 1, 10, "block toxin", "growth budget"),
        e(11, 0x814c0724ffc31213, 1, 11, "steer growth", "bounded branching graph"),
        e(12, 0x9d2fbbce0cf96954, 1, 8, "commit graph", "shortest-path nutrients"),
        e(13, 0xa1f45ce15fb30ea9, 1, 9, "place nutrient", "root terminal connectivity"),
        e(14, 0xd6541fc8d12410d9, 1, 10, "seed filament", "toxic-zone avoidance"),
        e(15, 0x28c826f43225ae47, 1, 11, "block toxin", "growth budget"),
        e(16, 0x868090636341da5e, 1, 8, "steer growth", "bounded branching graph"),
        e(17, 0xfaf65591090155bf, 1, 9, "commit graph", "shortest-path nutrients"),
        e(18, 0x3a7cc4bb3d030ef8, 1, 10, "place nutrient", "root terminal connectivity"),
        e(19, 0xbd474095258f266a, 1, 11, "seed filament", "toxic-zone avoidance"),
        e(20, 0xb8fee6ccd2527de3, 1, 8, "block toxin", "growth budget"),
        e(21, 0x374e80dc9fc9a738, 2, 11, "steer growth", "bounded branching graph"),
        e(22, 0x1aa72fb7cf93ab26, 2, 12, "commit graph", "shortest-path nutrients"),
        e(23, 0xc77e8122931adb32, 2, 13, "place nutrient", "root terminal connectivity"),
        e(24, 0x8007a43f74341497, 2, 10, "seed filament", "toxic-zone avoidance"),
        e(25, 0x8ded918ad66defac, 2, 11, "block toxin", "growth budget"),
        e(26, 0xc6dd484b3370ec4c, 2, 12, "steer growth", "bounded branching graph"),
        e(27, 0x9703093e3a89f4ff, 2, 13, "commit graph", "shortest-path nutrients"),
        e(28, 0xafd8b87dbf0fc141, 2, 10, "place nutrient", "root terminal connectivity"),
        e(29, 0x73c29a24d345dd17, 2, 11, "seed filament", "toxic-zone avoidance"),
        e(30, 0xe952c6b47f090127, 2, 12, "block toxin", "growth budget"),
        e(31, 0x86b93269741c629c, 2, 13, "steer growth", "bounded branching graph"),
        e(32, 0x1f1beea8e3240227, 2, 10, "commit graph", "shortest-path nutrients"),
        e(33, 0x353f8fdd390ee4ae, 2, 11, "place nutrient", "root terminal connectivity"),
        e(34, 0xe2b7ef6e87bf561d, 2, 12, "seed filament", "toxic-zone avoidance"),
        e(35, 0xca8acc7d2f9593df, 2, 13, "block toxin", "growth budget"),
        e(36, 0x30bef6c7f7a18553, 2, 10, "steer growth", "bounded branching graph"),
        e(37, 0xa37756ba99cb465f, 2, 11, "commit graph", "shortest-path nutrients"),
        e(38, 0x2750db1d6823e7ce, 2, 12, "place nutrient", "root terminal connectivity"),
        e(39, 0x17407fa565acc930, 2, 13, "seed filament", "toxic-zone avoidance"),
        e(40, 0xa47b9de939fbe853, 2, 10, "block toxin", "growth budget"),
        e(41, 0x1894f454d162d61f, 3, 13, "steer growth", "bounded branching graph"),
        e(42, 0xd32f5aa0be5bb17b, 3, 14, "commit graph", "shortest-path nutrients"),
        e(43, 0xdb40ea5efb757d8d, 3, 15, "place nutrient", "root terminal connectivity"),
        e(44, 0x191773de5404d2ac, 3, 12, "seed filament", "toxic-zone avoidance"),
        e(45, 0xe8b260e342788956, 3, 13, "block toxin", "growth budget"),
        e(46, 0x423daa5282cbd093, 3, 14, "steer growth", "bounded branching graph"),
        e(47, 0x96dbb885e2f15b85, 3, 15, "commit graph", "shortest-path nutrients"),
        e(48, 0xd134ac5ae7340fe0, 3, 12, "place nutrient", "root terminal connectivity"),
        e(49, 0x74f6e95b6fe2b05d, 3, 13, "seed filament", "toxic-zone avoidance"),
        e(50, 0x5a0025573aea3e46, 3, 14, "block toxin", "growth budget"),
        e(51, 0x90850f620cf94c55, 3, 15, "steer growth", "bounded branching graph"),
        e(52, 0x739838102d1cb2c4, 3, 12, "commit graph", "shortest-path nutrients"),
        e(53, 0x016d516843aa3754, 3, 13, "place nutrient", "root terminal connectivity"),
        e(54, 0x0693a26bfae46ee1, 3, 14, "seed filament", "toxic-zone avoidance"),
        e(55, 0xaa9773a2734697a9, 3, 15, "block toxin", "growth budget"),
        e(56, 0x3b6edb6410874037, 3, 12, "steer growth", "bounded branching graph"),
        e(57, 0x8fbb6880f97437de, 3, 13, "commit graph", "shortest-path nutrients"),
        e(58, 0x11235c81d832d76f, 3, 14, "place nutrient", "root terminal connectivity"),
        e(59, 0xa303a1e41d12e1c9, 3, 15, "seed filament", "toxic-zone avoidance"),
        e(60, 0x569a668bb2211388, 3, 12, "block toxin", "growth budget"),
        e(61, 0x9eca1496e31aeec3, 4, 15, "steer growth", "bounded branching graph"),
        e(62, 0xc39da71603f32cef, 4, 16, "commit graph", "shortest-path nutrients"),
        e(63, 0x657dd740fa04d870, 4, 17, "place nutrient", "root terminal connectivity"),
        e(64, 0x066f0b3fbb2c54ca, 4, 14, "seed filament", "toxic-zone avoidance"),
        e(65, 0xde87abef64043db4, 4, 15, "block toxin", "growth budget"),
        e(66, 0x8d1d9271f31b1509, 4, 16, "steer growth", "bounded branching graph"),
        e(67, 0x804e842839a8a002, 4, 17, "commit graph", "shortest-path nutrients"),
        e(68, 0xda6b617c3486fa21, 4, 14, "place nutrient", "root terminal connectivity"),
        e(69, 0xcd22d3c2a47973c5, 4, 15, "seed filament", "toxic-zone avoidance"),
        e(70, 0xa1ebe42b0117dafd, 4, 16, "block toxin", "growth budget"),
        e(71, 0x635247becbaeb860, 4, 17, "steer growth", "bounded branching graph"),
        e(72, 0xf8fff516e91d8c36, 4, 14, "commit graph", "shortest-path nutrients"),
        e(73, 0xe51e795237e633a0, 4, 15, "place nutrient", "root terminal connectivity"),
        e(74, 0xd5c04ed13070bd55, 4, 16, "seed filament", "toxic-zone avoidance"),
        e(75, 0x5a99000e8fa6287d, 4, 17, "block toxin", "growth budget"),
        e(76, 0x37088ba22c21cdba, 4, 14, "steer growth", "bounded branching graph"),
        e(77, 0xec964703eff9959e, 4, 15, "commit graph", "shortest-path nutrients"),
        e(78, 0x6e7f67abeac64711, 4, 16, "place nutrient", "root terminal connectivity"),
        e(79, 0xa30ff599f9ae11fd, 4, 17, "seed filament", "toxic-zone avoidance"),
        e(80, 0xde425879bba962a5, 4, 14, "block toxin", "growth budget"),
        e(81, 0x7ce9d2c9c6e0cc77, 5, 17, "steer growth", "bounded branching graph"),
        e(82, 0xdcb8727565899827, 5, 18, "commit graph", "shortest-path nutrients"),
        e(83, 0xb1cacf8327f47ffb, 5, 19, "place nutrient", "root terminal connectivity"),
        e(84, 0x8e2445eb0ba49129, 5, 16, "seed filament", "toxic-zone avoidance"),
        e(85, 0x5bead2b6a0b4a059, 5, 17, "block toxin", "growth budget"),
        e(86, 0x6a7c721778ac90e6, 5, 18, "steer growth", "bounded branching graph"),
        e(87, 0xa74e15f82a5505ac, 5, 19, "commit graph", "shortest-path nutrients"),
        e(88, 0xfd7fc41017ff1dff, 5, 16, "place nutrient", "root terminal connectivity"),
        e(89, 0x9d7d1c45f4a5dd3a, 5, 17, "seed filament", "toxic-zone avoidance"),
        e(90, 0x1cc7dbefe295e555, 5, 18, "block toxin", "growth budget"),
        e(91, 0xa6d99dbaf490076a, 5, 19, "steer growth", "bounded branching graph"),
        e(92, 0x0dcc883fe8a4b2c4, 5, 16, "commit graph", "shortest-path nutrients"),
        e(93, 0xb4113db031e98fa7, 5, 17, "place nutrient", "root terminal connectivity"),
        e(94, 0xeb09ea3f5419aceb, 5, 18, "seed filament", "toxic-zone avoidance"),
        e(95, 0xb0066f6cdb73601e, 5, 19, "block toxin", "growth budget"),
        e(96, 0xa1e32315821918ae, 5, 16, "steer growth", "bounded branching graph"),
        e(97, 0xc743b9ad69105385, 5, 17, "commit graph", "shortest-path nutrients"),
        e(98, 0x4bb4fa3d3d05334a, 5, 18, "place nutrient", "root terminal connectivity"),
        e(99, 0x19184300d35ca786, 5, 19, "seed filament", "toxic-zone avoidance"),
        e(100, 0x2faac188a6aff6f4, 5, 16, "block toxin", "growth budget"),
    ]
}
