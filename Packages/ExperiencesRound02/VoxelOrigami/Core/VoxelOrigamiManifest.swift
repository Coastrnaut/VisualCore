// VoxelOrigamiManifest — feature 442 (R02-G15-02) T-R02G1502-002 (FR-R02G1502-001; clarification Q1). The 100 planned
// levels of Voxel Origami, copied from the project's own archived design (docs/archive/planning/rounds/round2.md, the
// R02-G15 level table; `python3 scripts/planning_index.py levels --experience R02-G15`): number, planned seed, band,
// moves budget (the table's "Moves budget") and control emphasis (the table's "Distinct control emphasis"), which
// chooses the orientations a level's match allows. Modelled on `MoonlitMechanismManifest` (feature 432).

/// One planned level: its number, planned seed, band, moves budget and control emphasis.
public struct VoxelOrigamiManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The moves budget, which becomes the level's action budget (8 … 19).
    public let budget: Int
    /// The control emphasis of the archived table ("inspect collision", "lock shape", "fold hinge", "select voxel" or
    /// "rotate assembly").
    public let emphasis: String

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int, emphasis: String) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
        self.emphasis = emphasis
    }

    /// The orientations the level's match allows (clarification Q1): `rotate assembly` → `any`, `lock shape` →
    /// `fixed`, every other emphasis → `upright`.
    public var orientations: VoxelOrigamiOrientations {
        switch emphasis {
        case "rotate assembly": .any
        case "lock shape": .fixed
        default: .upright
        }
    }
}

/// The 100 planned levels of Voxel Origami in order.
public enum VoxelOrigamiManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G15 level table)"
    /// The provenance of the entries in words.
    public static let provenance =
        "The project's own archived design, R02-G15 level table (planning_index.py levels --experience R02-G15)."

    /// The 100 entries, in manifest order.
    public static let entries: [VoxelOrigamiManifestEntry] = [
        VoxelOrigamiManifestEntry(number: 1, seed: 0xd042e35e0fc92293, band: 1, budget: 9,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 2, seed: 0x1022ee376114413c, band: 1, budget: 10,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 3, seed: 0x1c77ae9a47efd748, band: 1, budget: 11,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 4, seed: 0xecb307e9ca293d98, band: 1, budget: 8,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 5, seed: 0x2b9159e7fce3b3f0, band: 1, budget: 9,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 6, seed: 0xad71030c14274082, band: 1, budget: 10,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 7, seed: 0xa1f228895bfe9f52, band: 1, budget: 11,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 8, seed: 0x2f38313dd4e565b6, band: 1, budget: 8,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 9, seed: 0xc01d15abd05dcb7d, band: 1, budget: 9,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 10, seed: 0x4d5117bd2f1cac52, band: 1, budget: 10,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 11, seed: 0x9daec6ce3eeb999d, band: 1, budget: 11,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 12, seed: 0x24dfeef9c2e28164, band: 1, budget: 8,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 13, seed: 0xe463b1edb99ee4dd, band: 1, budget: 9,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 14, seed: 0xa6461cf9c91f54a7, band: 1, budget: 10,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 15, seed: 0xab9448baad3e9113, band: 1, budget: 11,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 16, seed: 0x5bcdc5e905f62510, band: 1, budget: 8,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 17, seed: 0x216549249bf72dfc, band: 1, budget: 9,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 18, seed: 0x81c6e9eeedc882d5, band: 1, budget: 10,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 19, seed: 0xb468339b8e726c4b, band: 1, budget: 11,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 20, seed: 0x6d14de2331bade24, band: 1, budget: 8,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 21, seed: 0x63cdf32dbb180973, band: 2, budget: 11,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 22, seed: 0x9be6558399953d82, band: 2, budget: 12,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 23, seed: 0x0f1b1c093aab6e98, band: 2, budget: 13,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 24, seed: 0x6f3597dc64cc2d05, band: 2, budget: 10,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 25, seed: 0x4659bd1b66fbcd2a, band: 2, budget: 11,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 26, seed: 0xd73dcfc7366a738e, band: 2, budget: 12,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 27, seed: 0x25c0071d1bc4f2a3, band: 2, budget: 13,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 28, seed: 0xb06e9fb6ba111206, band: 2, budget: 10,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 29, seed: 0x89764a47773ce088, band: 2, budget: 11,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 30, seed: 0xaf10d22097bc3c85, band: 2, budget: 12,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 31, seed: 0xae7ef06fec9ed62f, band: 2, budget: 13,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 32, seed: 0x1b132929c711b6ff, band: 2, budget: 10,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 33, seed: 0x044aa55e74184008, band: 2, budget: 11,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 34, seed: 0x92e238f6de557798, band: 2, budget: 12,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 35, seed: 0x3acc8821b0aa13ad, band: 2, budget: 13,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 36, seed: 0x1e696f5f1fe2bcd2, band: 2, budget: 10,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 37, seed: 0x5e848b7457287468, band: 2, budget: 11,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 38, seed: 0xdb79fa0053f3b85e, band: 2, budget: 12,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 39, seed: 0xadb84587a938570a, band: 2, budget: 13,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 40, seed: 0xd7402a39f689cad1, band: 2, budget: 10,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 41, seed: 0xb7b16284212e59af, band: 3, budget: 13,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 42, seed: 0xba777538e66dbadb, band: 3, budget: 14,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 43, seed: 0xcc52bc6c4ec84cbf, band: 3, budget: 15,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 44, seed: 0x2adc515c1dd685f5, band: 3, budget: 12,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 45, seed: 0x32772f00a71e1d78, band: 3, budget: 13,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 46, seed: 0xe87fcff79ca7e9a6, band: 3, budget: 14,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 47, seed: 0x56913282b00efe49, band: 3, budget: 15,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 48, seed: 0x3bf575bc9a8838ff, band: 3, budget: 12,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 49, seed: 0xcf5698124a76e645, band: 3, budget: 13,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 50, seed: 0x5630017552f62226, band: 3, budget: 14,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 51, seed: 0x11be4a115ef930a2, band: 3, budget: 15,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 52, seed: 0x5f33d20d0bf14ffc, band: 3, budget: 12,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 53, seed: 0x3a7df1e83e3f68dc, band: 3, budget: 13,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 54, seed: 0x6d9d5745c9e250b1, band: 3, budget: 14,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 55, seed: 0x4807fd80d6d3f1e8, band: 3, budget: 15,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 56, seed: 0x78563c4eb3018c72, band: 3, budget: 12,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 57, seed: 0xd9825480d4db66b8, band: 3, budget: 13,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 58, seed: 0x5d8105e7255c7bf3, band: 3, budget: 14,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 59, seed: 0x3190ea617562d1b2, band: 3, budget: 15,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 60, seed: 0x19b55ce0c9044d83, band: 3, budget: 12,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 61, seed: 0xcc414bdf7713f22d, band: 4, budget: 15,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 62, seed: 0xba245e5b876510b9, band: 4, budget: 16,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 63, seed: 0x3822836bb03f1848, band: 4, budget: 17,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 64, seed: 0x9d64aee09dc4a075, band: 4, budget: 14,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 65, seed: 0x986ef85d83d3c750, band: 4, budget: 15,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 66, seed: 0x73980cf4f6a706fe, band: 4, budget: 16,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 67, seed: 0x7f540fb8960198da, band: 4, budget: 17,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 68, seed: 0x85a10214156fa736, band: 4, budget: 14,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 69, seed: 0x58dfe72408ab7e95, band: 4, budget: 15,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 70, seed: 0x008189cc1bc960da, band: 4, budget: 16,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 71, seed: 0x360aadba4d062e3e, band: 4, budget: 17,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 72, seed: 0x0331054fb41a15b2, band: 4, budget: 14,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 73, seed: 0xc3d62d2d131f160b, band: 4, budget: 15,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 74, seed: 0x315d759336179104, band: 4, budget: 16,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 75, seed: 0x3c67fca28078b087, band: 4, budget: 17,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 76, seed: 0x87bd77c02d5460a0, band: 4, budget: 14,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 77, seed: 0xeb35e475405ce586, band: 4, budget: 15,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 78, seed: 0xb49fcd22b84c1ec2, band: 4, budget: 16,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 79, seed: 0x0bf69ec377b76ef1, band: 4, budget: 17,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 80, seed: 0x2d0833ac02c76130, band: 4, budget: 14,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 81, seed: 0x8bbedde3e8bf379a, band: 5, budget: 17,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 82, seed: 0xe24e1396847c5f8d, band: 5, budget: 18,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 83, seed: 0x48aecc480a76a30d, band: 5, budget: 19,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 84, seed: 0x45677f552632da5a, band: 5, budget: 16,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 85, seed: 0x8cf0e4e9876ce533, band: 5, budget: 17,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 86, seed: 0x54c0d7220b1b5840, band: 5, budget: 18,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 87, seed: 0xe9ee5ab6783d8e98, band: 5, budget: 19,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 88, seed: 0xdd84ae2648e7de9a, band: 5, budget: 16,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 89, seed: 0xd35a4cbf43c5d16d, band: 5, budget: 17,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 90, seed: 0xacf0add86b0736aa, band: 5, budget: 18,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 91, seed: 0x647e5516a30f53d7, band: 5, budget: 19,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 92, seed: 0x91c76f429341674d, band: 5, budget: 16,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 93, seed: 0xce9ea9cb598fddb1, band: 5, budget: 17,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 94, seed: 0xf1f217de00955488, band: 5, budget: 18,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 95, seed: 0x6f31bc4278a78ccc, band: 5, budget: 19,
                                  emphasis: "rotate assembly"),
        VoxelOrigamiManifestEntry(number: 96, seed: 0xb4547c32f6c97512, band: 5, budget: 16,
                                  emphasis: "inspect collision"),
        VoxelOrigamiManifestEntry(number: 97, seed: 0x61b149a33066b8f7, band: 5, budget: 17,
                                  emphasis: "lock shape"),
        VoxelOrigamiManifestEntry(number: 98, seed: 0xbcd69938fe277049, band: 5, budget: 18,
                                  emphasis: "fold hinge"),
        VoxelOrigamiManifestEntry(number: 99, seed: 0x7934a187e1bb1520, band: 5, budget: 19,
                                  emphasis: "select voxel"),
        VoxelOrigamiManifestEntry(number: 100, seed: 0x53e5c9cdb56caac8, band: 5, budget: 16,
                                  emphasis: "rotate assembly"),
    ]
}
