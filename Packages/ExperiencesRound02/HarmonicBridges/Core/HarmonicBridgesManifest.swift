// HarmonicBridgesManifest — feature 412 (R02-G12-02) T-R02G1202-002 (FR-R02G1202-001; clarification Q1). The 100
// planned levels of Harmonic Bridges, copied from the project's own archived design (docs/archive/planning/rounds/
// round2.md, the R02-G12 level table; `python3 scripts/planning_index.py levels --experience R02-G12`): number, planned
// seed, band and moves budget (the table's "Moves budget").

/// One planned level: its number, planned seed, band and moves budget.
public struct HarmonicBridgesManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The moves budget, which becomes the level's action budget (8 … 19).
    public let budget: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, budget: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.budget = budget
    }
}

/// The 100 planned levels of Harmonic Bridges in order.
public enum HarmonicBridgesManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G12 level table)"
    /// The provenance of the entries in words.
    public static let provenance =
        "The project's own archived design, R02-G12 level table (planning_index.py levels --experience R02-G12)."

    /// The 100 entries, in manifest order.
    public static let entries: [HarmonicBridgesManifestEntry] = [
        HarmonicBridgesManifestEntry(number: 1, seed: 0x2fed66950e84a850, band: 1, budget: 9),
        HarmonicBridgesManifestEntry(number: 2, seed: 0x6c23ea0c26d1025d, band: 1, budget: 10),
        HarmonicBridgesManifestEntry(number: 3, seed: 0x1095f7a5aad7755d, band: 1, budget: 11),
        HarmonicBridgesManifestEntry(number: 4, seed: 0xc1c037de558a6a6a, band: 1, budget: 8),
        HarmonicBridgesManifestEntry(number: 5, seed: 0xfee2acf06f524c87, band: 1, budget: 9),
        HarmonicBridgesManifestEntry(number: 6, seed: 0x3268cac9fdc0a089, band: 1, budget: 10),
        HarmonicBridgesManifestEntry(number: 7, seed: 0x16ebb428f4c443ab, band: 1, budget: 11),
        HarmonicBridgesManifestEntry(number: 8, seed: 0xbcbb6a9c36a3f906, band: 1, budget: 8),
        HarmonicBridgesManifestEntry(number: 9, seed: 0x002dd9aafa6fb5fd, band: 1, budget: 9),
        HarmonicBridgesManifestEntry(number: 10, seed: 0xe92cab3242469874, band: 1, budget: 10),
        HarmonicBridgesManifestEntry(number: 11, seed: 0xc265b22d53402dcc, band: 1, budget: 11),
        HarmonicBridgesManifestEntry(number: 12, seed: 0x2e7303c4d1795a44, band: 1, budget: 8),
        HarmonicBridgesManifestEntry(number: 13, seed: 0x95c8b06b72a609d8, band: 1, budget: 9),
        HarmonicBridgesManifestEntry(number: 14, seed: 0xc938d8f587d48ce9, band: 1, budget: 10),
        HarmonicBridgesManifestEntry(number: 15, seed: 0x86f6c37279e5e217, band: 1, budget: 11),
        HarmonicBridgesManifestEntry(number: 16, seed: 0xda914e09bd976687, band: 1, budget: 8),
        HarmonicBridgesManifestEntry(number: 17, seed: 0x9f835b18f2052136, band: 1, budget: 9),
        HarmonicBridgesManifestEntry(number: 18, seed: 0x6bf6b12f1a375e58, band: 1, budget: 10),
        HarmonicBridgesManifestEntry(number: 19, seed: 0x4cfb60a7401ebd9c, band: 1, budget: 11),
        HarmonicBridgesManifestEntry(number: 20, seed: 0x72195c364084c988, band: 1, budget: 8),
        HarmonicBridgesManifestEntry(number: 21, seed: 0x307aac010f743dc2, band: 2, budget: 11),
        HarmonicBridgesManifestEntry(number: 22, seed: 0x82692da108d6e6b4, band: 2, budget: 12),
        HarmonicBridgesManifestEntry(number: 23, seed: 0xf7c364aca39b3cd1, band: 2, budget: 13),
        HarmonicBridgesManifestEntry(number: 24, seed: 0x136b57929fe12774, band: 2, budget: 10),
        HarmonicBridgesManifestEntry(number: 25, seed: 0xf74b7296e77d5b72, band: 2, budget: 11),
        HarmonicBridgesManifestEntry(number: 26, seed: 0x518b9f3116a23be3, band: 2, budget: 12),
        HarmonicBridgesManifestEntry(number: 27, seed: 0x17a0bf1fdd26d865, band: 2, budget: 13),
        HarmonicBridgesManifestEntry(number: 28, seed: 0xe393cab17a4cf3ba, band: 2, budget: 10),
        HarmonicBridgesManifestEntry(number: 29, seed: 0x27853c68bc72f04d, band: 2, budget: 11),
        HarmonicBridgesManifestEntry(number: 30, seed: 0xff9246871f363554, band: 2, budget: 12),
        HarmonicBridgesManifestEntry(number: 31, seed: 0x7a0618d6a023690f, band: 2, budget: 13),
        HarmonicBridgesManifestEntry(number: 32, seed: 0x3d34bf7086cb0364, band: 2, budget: 10),
        HarmonicBridgesManifestEntry(number: 33, seed: 0x60491b371c479a6d, band: 2, budget: 11),
        HarmonicBridgesManifestEntry(number: 34, seed: 0xb61f2e9a51c6e099, band: 2, budget: 12),
        HarmonicBridgesManifestEntry(number: 35, seed: 0xb6b43ead18dfe5c8, band: 2, budget: 13),
        HarmonicBridgesManifestEntry(number: 36, seed: 0xd1c3f6c271e5523c, band: 2, budget: 10),
        HarmonicBridgesManifestEntry(number: 37, seed: 0xc923131c117529ce, band: 2, budget: 11),
        HarmonicBridgesManifestEntry(number: 38, seed: 0x76a291dab1a875d2, band: 2, budget: 12),
        HarmonicBridgesManifestEntry(number: 39, seed: 0x0f301ec922056a9e, band: 2, budget: 13),
        HarmonicBridgesManifestEntry(number: 40, seed: 0xa8345641dfaf17e2, band: 2, budget: 10),
        HarmonicBridgesManifestEntry(number: 41, seed: 0xccf9a083c9632fbc, band: 3, budget: 13),
        HarmonicBridgesManifestEntry(number: 42, seed: 0xd50cf8b95815a764, band: 3, budget: 14),
        HarmonicBridgesManifestEntry(number: 43, seed: 0x5997cf3f98333c56, band: 3, budget: 15),
        HarmonicBridgesManifestEntry(number: 44, seed: 0xe783bfdfac7db351, band: 3, budget: 12),
        HarmonicBridgesManifestEntry(number: 45, seed: 0x6ac29f6183527df5, band: 3, budget: 13),
        HarmonicBridgesManifestEntry(number: 46, seed: 0xdc2ccee223d04823, band: 3, budget: 14),
        HarmonicBridgesManifestEntry(number: 47, seed: 0xe5df1b8a25343c7e, band: 3, budget: 15),
        HarmonicBridgesManifestEntry(number: 48, seed: 0x0596a3093a0adea7, band: 3, budget: 12),
        HarmonicBridgesManifestEntry(number: 49, seed: 0x28ed14b9d380c787, band: 3, budget: 13),
        HarmonicBridgesManifestEntry(number: 50, seed: 0x065899e00431ef83, band: 3, budget: 14),
        HarmonicBridgesManifestEntry(number: 51, seed: 0xe3b0d0100e41a39d, band: 3, budget: 15),
        HarmonicBridgesManifestEntry(number: 52, seed: 0x206fa63398e83dc3, band: 3, budget: 12),
        HarmonicBridgesManifestEntry(number: 53, seed: 0xdd6945582f20c9c3, band: 3, budget: 13),
        HarmonicBridgesManifestEntry(number: 54, seed: 0x5526bda4b05508b4, band: 3, budget: 14),
        HarmonicBridgesManifestEntry(number: 55, seed: 0x2e8d7b960a948892, band: 3, budget: 15),
        HarmonicBridgesManifestEntry(number: 56, seed: 0x8555fd84ec019725, band: 3, budget: 12),
        HarmonicBridgesManifestEntry(number: 57, seed: 0xf7a9e8c30575e7a0, band: 3, budget: 13),
        HarmonicBridgesManifestEntry(number: 58, seed: 0x40c4d02ae201f004, band: 3, budget: 14),
        HarmonicBridgesManifestEntry(number: 59, seed: 0x5bc1c497f7386476, band: 3, budget: 15),
        HarmonicBridgesManifestEntry(number: 60, seed: 0xdd2d1ad7670089b8, band: 3, budget: 12),
        HarmonicBridgesManifestEntry(number: 61, seed: 0xb0508ede5aec47d5, band: 4, budget: 15),
        HarmonicBridgesManifestEntry(number: 62, seed: 0x390087fe86bd8f14, band: 4, budget: 16),
        HarmonicBridgesManifestEntry(number: 63, seed: 0xc1dbff648f286f61, band: 4, budget: 17),
        HarmonicBridgesManifestEntry(number: 64, seed: 0xa3796b9796c58a8b, band: 4, budget: 14),
        HarmonicBridgesManifestEntry(number: 65, seed: 0xf37127e34e48bd96, band: 4, budget: 15),
        HarmonicBridgesManifestEntry(number: 66, seed: 0xad9f775107dd8843, band: 4, budget: 16),
        HarmonicBridgesManifestEntry(number: 67, seed: 0x6a7fcdcb10b96e68, band: 4, budget: 17),
        HarmonicBridgesManifestEntry(number: 68, seed: 0xc9c349b32444c11b, band: 4, budget: 14),
        HarmonicBridgesManifestEntry(number: 69, seed: 0xa0c90efb13beb291, band: 4, budget: 15),
        HarmonicBridgesManifestEntry(number: 70, seed: 0x4d65ec9b466cc8fd, band: 4, budget: 16),
        HarmonicBridgesManifestEntry(number: 71, seed: 0x9dca64d163327a97, band: 4, budget: 17),
        HarmonicBridgesManifestEntry(number: 72, seed: 0xd74f8ccfee19213c, band: 4, budget: 14),
        HarmonicBridgesManifestEntry(number: 73, seed: 0x567ebc5232ee7625, band: 4, budget: 15),
        HarmonicBridgesManifestEntry(number: 74, seed: 0xa3fb298563040f67, band: 4, budget: 16),
        HarmonicBridgesManifestEntry(number: 75, seed: 0x4fd7c1ec90c18c55, band: 4, budget: 17),
        HarmonicBridgesManifestEntry(number: 76, seed: 0x7d41f4edeeb1e550, band: 4, budget: 14),
        HarmonicBridgesManifestEntry(number: 77, seed: 0x50cda95c2076bf79, band: 4, budget: 15),
        HarmonicBridgesManifestEntry(number: 78, seed: 0x4708e02eb8987310, band: 4, budget: 16),
        HarmonicBridgesManifestEntry(number: 79, seed: 0x63c40b4f2704a562, band: 4, budget: 17),
        HarmonicBridgesManifestEntry(number: 80, seed: 0x58a3545e87511b4e, band: 4, budget: 14),
        HarmonicBridgesManifestEntry(number: 81, seed: 0x6f5b9067040897f3, band: 5, budget: 17),
        HarmonicBridgesManifestEntry(number: 82, seed: 0xa77a763d4dfe202b, band: 5, budget: 18),
        HarmonicBridgesManifestEntry(number: 83, seed: 0x4190d67fa3374629, band: 5, budget: 19),
        HarmonicBridgesManifestEntry(number: 84, seed: 0x3368d011fae3da00, band: 5, budget: 16),
        HarmonicBridgesManifestEntry(number: 85, seed: 0xdf6bc91ab28d9b1a, band: 5, budget: 17),
        HarmonicBridgesManifestEntry(number: 86, seed: 0x40ec19fb0cc8eb94, band: 5, budget: 18),
        HarmonicBridgesManifestEntry(number: 87, seed: 0x07f52c1f89452010, band: 5, budget: 19),
        HarmonicBridgesManifestEntry(number: 88, seed: 0xf6201e4fd01dbb2c, band: 5, budget: 16),
        HarmonicBridgesManifestEntry(number: 89, seed: 0x06233ec6624db0f0, band: 5, budget: 17),
        HarmonicBridgesManifestEntry(number: 90, seed: 0x6e90b4a78b5b4258, band: 5, budget: 18),
        HarmonicBridgesManifestEntry(number: 91, seed: 0x801013e7a2fe0ec7, band: 5, budget: 19),
        HarmonicBridgesManifestEntry(number: 92, seed: 0xe3eee32f3619d921, band: 5, budget: 16),
        HarmonicBridgesManifestEntry(number: 93, seed: 0x464cdf4089b6ccaf, band: 5, budget: 17),
        HarmonicBridgesManifestEntry(number: 94, seed: 0x29457839c00f5bfd, band: 5, budget: 18),
        HarmonicBridgesManifestEntry(number: 95, seed: 0xc50dfaeff961ffb1, band: 5, budget: 19),
        HarmonicBridgesManifestEntry(number: 96, seed: 0x089a86258242394e, band: 5, budget: 16),
        HarmonicBridgesManifestEntry(number: 97, seed: 0xd39cc7400679c664, band: 5, budget: 17),
        HarmonicBridgesManifestEntry(number: 98, seed: 0xdfcd274b38db7c60, band: 5, budget: 18),
        HarmonicBridgesManifestEntry(number: 99, seed: 0x3cc019d61cc2a67a, band: 5, budget: 19),
        HarmonicBridgesManifestEntry(number: 100, seed: 0x8d969473f3e112c5, band: 5, budget: 16),
    ]
}
