// MoonlitMechanismManifest — feature 432 (R02-G14-02) T-R02G1402-002 (FR-R02G1402-001; clarification Q1). The 100
// planned levels of Moonlit Mechanism, copied from the project's own archived design (docs/archive/planning/rounds/
// round2.md, the R02-G14 level table; `python3 scripts/planning_index.py levels --experience R02-G14`): number, planned
// seed, band and moves budget (the table's "Moves budget").

/// One planned level: its number, planned seed, band and moves budget.
public struct MoonlitMechanismManifestEntry: Sendable, Equatable, Hashable, Codable {
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

/// The 100 planned levels of Moonlit Mechanism in order.
public enum MoonlitMechanismManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G14 level table)"
    /// The provenance of the entries in words.
    public static let provenance =
        "The project's own archived design, R02-G14 level table (planning_index.py levels --experience R02-G14)."

    /// The 100 entries, in manifest order.
    public static let entries: [MoonlitMechanismManifestEntry] = [
        MoonlitMechanismManifestEntry(number: 1, seed: 0x4432d843347584e1, band: 1, budget: 9),
        MoonlitMechanismManifestEntry(number: 2, seed: 0x10945e013285f9e0, band: 1, budget: 10),
        MoonlitMechanismManifestEntry(number: 3, seed: 0x871353665d0522c8, band: 1, budget: 11),
        MoonlitMechanismManifestEntry(number: 4, seed: 0x489947571f47993e, band: 1, budget: 8),
        MoonlitMechanismManifestEntry(number: 5, seed: 0x30151b9005d055da, band: 1, budget: 9),
        MoonlitMechanismManifestEntry(number: 6, seed: 0x85fbc1e7121b2c49, band: 1, budget: 10),
        MoonlitMechanismManifestEntry(number: 7, seed: 0x1c96fc96f71e9aac, band: 1, budget: 11),
        MoonlitMechanismManifestEntry(number: 8, seed: 0x5e828261d760e354, band: 1, budget: 8),
        MoonlitMechanismManifestEntry(number: 9, seed: 0xeef44f05b6e7e76c, band: 1, budget: 9),
        MoonlitMechanismManifestEntry(number: 10, seed: 0xdb88027ff87ba670, band: 1, budget: 10),
        MoonlitMechanismManifestEntry(number: 11, seed: 0x182678f628d7d5f4, band: 1, budget: 11),
        MoonlitMechanismManifestEntry(number: 12, seed: 0x772353d73804fa66, band: 1, budget: 8),
        MoonlitMechanismManifestEntry(number: 13, seed: 0xca1309b5f277a532, band: 1, budget: 9),
        MoonlitMechanismManifestEntry(number: 14, seed: 0x6c052a517111858a, band: 1, budget: 10),
        MoonlitMechanismManifestEntry(number: 15, seed: 0x673a8d7daffe52fd, band: 1, budget: 11),
        MoonlitMechanismManifestEntry(number: 16, seed: 0x2050349aaad1f2b8, band: 1, budget: 8),
        MoonlitMechanismManifestEntry(number: 17, seed: 0x6965d11136430a23, band: 1, budget: 9),
        MoonlitMechanismManifestEntry(number: 18, seed: 0xca49dd7c0774e98a, band: 1, budget: 10),
        MoonlitMechanismManifestEntry(number: 19, seed: 0x4d838462ed7dcebe, band: 1, budget: 11),
        MoonlitMechanismManifestEntry(number: 20, seed: 0x2ed03b0c52ff6a0d, band: 1, budget: 8),
        MoonlitMechanismManifestEntry(number: 21, seed: 0xb8dbb057069fc16f, band: 2, budget: 11),
        MoonlitMechanismManifestEntry(number: 22, seed: 0xe4f54230a1b24569, band: 2, budget: 12),
        MoonlitMechanismManifestEntry(number: 23, seed: 0x161cdd1fb1930dbe, band: 2, budget: 13),
        MoonlitMechanismManifestEntry(number: 24, seed: 0x56d8954e68cf45e1, band: 2, budget: 10),
        MoonlitMechanismManifestEntry(number: 25, seed: 0x4c27469bcf210c77, band: 2, budget: 11),
        MoonlitMechanismManifestEntry(number: 26, seed: 0x340fa93c279fee80, band: 2, budget: 12),
        MoonlitMechanismManifestEntry(number: 27, seed: 0x7d73fa2e95408bef, band: 2, budget: 13),
        MoonlitMechanismManifestEntry(number: 28, seed: 0x17fad35d43ad5a24, band: 2, budget: 10),
        MoonlitMechanismManifestEntry(number: 29, seed: 0x2df08e82f02a9798, band: 2, budget: 11),
        MoonlitMechanismManifestEntry(number: 30, seed: 0xdeffc0844684b1e2, band: 2, budget: 12),
        MoonlitMechanismManifestEntry(number: 31, seed: 0xf1070ac2ae481e8b, band: 2, budget: 13),
        MoonlitMechanismManifestEntry(number: 32, seed: 0x447fad2d43f51609, band: 2, budget: 10),
        MoonlitMechanismManifestEntry(number: 33, seed: 0x966a825fc9d4d0a4, band: 2, budget: 11),
        MoonlitMechanismManifestEntry(number: 34, seed: 0xf9e26b3f10da4381, band: 2, budget: 12),
        MoonlitMechanismManifestEntry(number: 35, seed: 0xcff4e0842abcc675, band: 2, budget: 13),
        MoonlitMechanismManifestEntry(number: 36, seed: 0x961a2bf33be97dac, band: 2, budget: 10),
        MoonlitMechanismManifestEntry(number: 37, seed: 0x553cf620cdf3bbb5, band: 2, budget: 11),
        MoonlitMechanismManifestEntry(number: 38, seed: 0x070f982b029f28b5, band: 2, budget: 12),
        MoonlitMechanismManifestEntry(number: 39, seed: 0x8a9971552bd6ebe1, band: 2, budget: 13),
        MoonlitMechanismManifestEntry(number: 40, seed: 0xe1dfa093a4045571, band: 2, budget: 10),
        MoonlitMechanismManifestEntry(number: 41, seed: 0x97aae355b310824d, band: 3, budget: 13),
        MoonlitMechanismManifestEntry(number: 42, seed: 0x45f7e2c01191de30, band: 3, budget: 14),
        MoonlitMechanismManifestEntry(number: 43, seed: 0xbf6857bbfaa60f93, band: 3, budget: 15),
        MoonlitMechanismManifestEntry(number: 44, seed: 0xa073bc3f5d6db539, band: 3, budget: 12),
        MoonlitMechanismManifestEntry(number: 45, seed: 0x757bffbe78de49b5, band: 3, budget: 13),
        MoonlitMechanismManifestEntry(number: 46, seed: 0x42ff6c42b15cbbd5, band: 3, budget: 14),
        MoonlitMechanismManifestEntry(number: 47, seed: 0x447c8b71332ba345, band: 3, budget: 15),
        MoonlitMechanismManifestEntry(number: 48, seed: 0xbf608cb6e5a4cd82, band: 3, budget: 12),
        MoonlitMechanismManifestEntry(number: 49, seed: 0xef3c8883b1cd1572, band: 3, budget: 13),
        MoonlitMechanismManifestEntry(number: 50, seed: 0xb16b410636f49a57, band: 3, budget: 14),
        MoonlitMechanismManifestEntry(number: 51, seed: 0xc60625b91b3e457c, band: 3, budget: 15),
        MoonlitMechanismManifestEntry(number: 52, seed: 0x81357dd2885b2af6, band: 3, budget: 12),
        MoonlitMechanismManifestEntry(number: 53, seed: 0x59774b2e132a5e8d, band: 3, budget: 13),
        MoonlitMechanismManifestEntry(number: 54, seed: 0xd637c04683aeff27, band: 3, budget: 14),
        MoonlitMechanismManifestEntry(number: 55, seed: 0x6ed95c2d6fbd28ce, band: 3, budget: 15),
        MoonlitMechanismManifestEntry(number: 56, seed: 0x843b8fb5476ff545, band: 3, budget: 12),
        MoonlitMechanismManifestEntry(number: 57, seed: 0xa922a348747d386c, band: 3, budget: 13),
        MoonlitMechanismManifestEntry(number: 58, seed: 0x97b6cce02a141369, band: 3, budget: 14),
        MoonlitMechanismManifestEntry(number: 59, seed: 0x875e7149f8dce150, band: 3, budget: 15),
        MoonlitMechanismManifestEntry(number: 60, seed: 0x850e5314dc3eef50, band: 3, budget: 12),
        MoonlitMechanismManifestEntry(number: 61, seed: 0x1455ad91c4d680cf, band: 4, budget: 15),
        MoonlitMechanismManifestEntry(number: 62, seed: 0x1931fdb83aa174ed, band: 4, budget: 16),
        MoonlitMechanismManifestEntry(number: 63, seed: 0xcf226bf04c368829, band: 4, budget: 17),
        MoonlitMechanismManifestEntry(number: 64, seed: 0x2873b9ecb777aef6, band: 4, budget: 14),
        MoonlitMechanismManifestEntry(number: 65, seed: 0xf2fa51df38afa2ae, band: 4, budget: 15),
        MoonlitMechanismManifestEntry(number: 66, seed: 0x82f6d5f817e7c250, band: 4, budget: 16),
        MoonlitMechanismManifestEntry(number: 67, seed: 0x74fa815ca0fc7961, band: 4, budget: 17),
        MoonlitMechanismManifestEntry(number: 68, seed: 0x390f3d0a5a4cb092, band: 4, budget: 14),
        MoonlitMechanismManifestEntry(number: 69, seed: 0xd43c9c6a78660480, band: 4, budget: 15),
        MoonlitMechanismManifestEntry(number: 70, seed: 0xd351cabb46c9b7c8, band: 4, budget: 16),
        MoonlitMechanismManifestEntry(number: 71, seed: 0x20a1c012fc4916a7, band: 4, budget: 17),
        MoonlitMechanismManifestEntry(number: 72, seed: 0xc15c7be9aa065677, band: 4, budget: 14),
        MoonlitMechanismManifestEntry(number: 73, seed: 0x9b9e686ae08ab3fd, band: 4, budget: 15),
        MoonlitMechanismManifestEntry(number: 74, seed: 0xe3de333cc8a41093, band: 4, budget: 16),
        MoonlitMechanismManifestEntry(number: 75, seed: 0x278cc31e32cb194d, band: 4, budget: 17),
        MoonlitMechanismManifestEntry(number: 76, seed: 0xf3ac1aab189b825f, band: 4, budget: 14),
        MoonlitMechanismManifestEntry(number: 77, seed: 0x788e768b2b64f846, band: 4, budget: 15),
        MoonlitMechanismManifestEntry(number: 78, seed: 0x4f2c8b899ff2488b, band: 4, budget: 16),
        MoonlitMechanismManifestEntry(number: 79, seed: 0xf46b98f56ffac128, band: 4, budget: 17),
        MoonlitMechanismManifestEntry(number: 80, seed: 0xb594a5bb607f9f64, band: 4, budget: 14),
        MoonlitMechanismManifestEntry(number: 81, seed: 0xf165820e3e103bc9, band: 5, budget: 17),
        MoonlitMechanismManifestEntry(number: 82, seed: 0x4edd64d9656d4888, band: 5, budget: 18),
        MoonlitMechanismManifestEntry(number: 83, seed: 0x29a6bc793590fa90, band: 5, budget: 19),
        MoonlitMechanismManifestEntry(number: 84, seed: 0x07f0e087f6a9cd97, band: 5, budget: 16),
        MoonlitMechanismManifestEntry(number: 85, seed: 0x541a65f2156c5864, band: 5, budget: 17),
        MoonlitMechanismManifestEntry(number: 86, seed: 0x148a3f3c1001d26f, band: 5, budget: 18),
        MoonlitMechanismManifestEntry(number: 87, seed: 0x036dcfa120e445e1, band: 5, budget: 19),
        MoonlitMechanismManifestEntry(number: 88, seed: 0xc891ddf96b454451, band: 5, budget: 16),
        MoonlitMechanismManifestEntry(number: 89, seed: 0x26d466bd3fdc283f, band: 5, budget: 17),
        MoonlitMechanismManifestEntry(number: 90, seed: 0xc232e419d4142f8f, band: 5, budget: 18),
        MoonlitMechanismManifestEntry(number: 91, seed: 0xbed0da88700983ee, band: 5, budget: 19),
        MoonlitMechanismManifestEntry(number: 92, seed: 0xc427f10b76fc7333, band: 5, budget: 16),
        MoonlitMechanismManifestEntry(number: 93, seed: 0x3b49bc5f0a9a4d01, band: 5, budget: 17),
        MoonlitMechanismManifestEntry(number: 94, seed: 0xf9011a748ad7a0a1, band: 5, budget: 18),
        MoonlitMechanismManifestEntry(number: 95, seed: 0x10701c0b13447833, band: 5, budget: 19),
        MoonlitMechanismManifestEntry(number: 96, seed: 0x908a86c87125d342, band: 5, budget: 16),
        MoonlitMechanismManifestEntry(number: 97, seed: 0xa7519c0843f312ac, band: 5, budget: 17),
        MoonlitMechanismManifestEntry(number: 98, seed: 0xd70f2eedd62bda28, band: 5, budget: 18),
        MoonlitMechanismManifestEntry(number: 99, seed: 0xb104f120cf56c783, band: 5, budget: 19),
        MoonlitMechanismManifestEntry(number: 100, seed: 0xd704d88b30bad013, band: 5, budget: 16),
    ]
}
