// EchoCartographerManifest — feature 402 (R02-G11-02) T-R02G1102-002 (FR-R02G1102-001; clarification Q1). The 100
// planned levels of Echo Cartographer, copied from the project's own archived design (docs/archive/planning/rounds/
// round2.md, the R02-G11 level table; `python3 scripts/planning_index.py levels --experience R02-G11`): number, planned
// seed, band and energy budget (the table's "Moves budget").

/// One planned level: its number, planned seed, band and energy budget.
public struct EchoCartographerManifestEntry: Sendable, Equatable, Hashable, Codable {
    /// The level number, 1 … 100.
    public let number: Int
    /// The planned seed the level's candidates derive from.
    public let seed: UInt64
    /// The band, 1 … 5.
    public let band: Int
    /// The energy budget, which becomes the level's energy (8 … 19).
    public let energy: Int

    /// An entry of the given values.
    public init(number: Int, seed: UInt64, band: Int, energy: Int) {
        self.number = number
        self.seed = seed
        self.band = band
        self.energy = energy
    }
}

/// The 100 planned levels of Echo Cartographer in order.
public enum EchoCartographerManifest {
    /// Where the entries were copied from.
    public static let source = "docs/archive/planning/rounds/round2.md (R02-G11 level table)"
    /// The provenance of the entries in words.
    public static let provenance =
        "The project's own archived design, R02-G11 level table (planning_index.py levels --experience R02-G11)."

    /// The 100 entries, in manifest order.
    public static let entries: [EchoCartographerManifestEntry] = [
        EchoCartographerManifestEntry(number: 1, seed: 0x3cfb16de6f757496, band: 1, energy: 9),
        EchoCartographerManifestEntry(number: 2, seed: 0x7d3bd7d1e5a0f39c, band: 1, energy: 10),
        EchoCartographerManifestEntry(number: 3, seed: 0x7770116c93daf2bf, band: 1, energy: 11),
        EchoCartographerManifestEntry(number: 4, seed: 0xf61dc54536c78565, band: 1, energy: 8),
        EchoCartographerManifestEntry(number: 5, seed: 0xcb7d27fdcfafb165, band: 1, energy: 9),
        EchoCartographerManifestEntry(number: 6, seed: 0xadddbd75a72dd079, band: 1, energy: 10),
        EchoCartographerManifestEntry(number: 7, seed: 0xf8ba59e5c1d843e8, band: 1, energy: 11),
        EchoCartographerManifestEntry(number: 8, seed: 0xbe5befd93a0b7d9a, band: 1, energy: 8),
        EchoCartographerManifestEntry(number: 9, seed: 0xb7344c27628be9b9, band: 1, energy: 9),
        EchoCartographerManifestEntry(number: 10, seed: 0x4fe07964873af67e, band: 1, energy: 10),
        EchoCartographerManifestEntry(number: 11, seed: 0xac8c34ec55cf4b6a, band: 1, energy: 11),
        EchoCartographerManifestEntry(number: 12, seed: 0x32a0f205cb0229e5, band: 1, energy: 8),
        EchoCartographerManifestEntry(number: 13, seed: 0xd32c976617f641eb, band: 1, energy: 9),
        EchoCartographerManifestEntry(number: 14, seed: 0xcc851733f818d1c8, band: 1, energy: 10),
        EchoCartographerManifestEntry(number: 15, seed: 0x67e18940cbb2719a, band: 1, energy: 11),
        EchoCartographerManifestEntry(number: 16, seed: 0x79f84d5ea5ce9a44, band: 1, energy: 8),
        EchoCartographerManifestEntry(number: 17, seed: 0x23376752c44402e7, band: 1, energy: 9),
        EchoCartographerManifestEntry(number: 18, seed: 0x83d4816fb90efc4f, band: 1, energy: 10),
        EchoCartographerManifestEntry(number: 19, seed: 0xf1e8d32ed6821b98, band: 1, energy: 11),
        EchoCartographerManifestEntry(number: 20, seed: 0x1e54e5e820943fdb, band: 1, energy: 8),
        EchoCartographerManifestEntry(number: 21, seed: 0x8e24fafe6e4321df, band: 2, energy: 11),
        EchoCartographerManifestEntry(number: 22, seed: 0x87f9a3098c50b01c, band: 2, energy: 12),
        EchoCartographerManifestEntry(number: 23, seed: 0x1776aa5bf90ee608, band: 2, energy: 13),
        EchoCartographerManifestEntry(number: 24, seed: 0x667caeff5818742b, band: 2, energy: 10),
        EchoCartographerManifestEntry(number: 25, seed: 0xfb995b2fd013b3db, band: 2, energy: 11),
        EchoCartographerManifestEntry(number: 26, seed: 0x72183fa08c68dca2, band: 2, energy: 12),
        EchoCartographerManifestEntry(number: 27, seed: 0xb48768819d2c1006, band: 2, energy: 13),
        EchoCartographerManifestEntry(number: 28, seed: 0xcec482df0c7d5989, band: 2, energy: 10),
        EchoCartographerManifestEntry(number: 29, seed: 0x5eca0943090c919e, band: 2, energy: 11),
        EchoCartographerManifestEntry(number: 30, seed: 0x454aaac451cf5f53, band: 2, energy: 12),
        EchoCartographerManifestEntry(number: 31, seed: 0xade9d4ade9f7eeb7, band: 2, energy: 13),
        EchoCartographerManifestEntry(number: 32, seed: 0x7d916799ea52b3eb, band: 2, energy: 10),
        EchoCartographerManifestEntry(number: 33, seed: 0xc31284114a85c075, band: 2, energy: 11),
        EchoCartographerManifestEntry(number: 34, seed: 0x2acb71d23471e041, band: 2, energy: 12),
        EchoCartographerManifestEntry(number: 35, seed: 0x4bcf9c94119b65eb, band: 2, energy: 13),
        EchoCartographerManifestEntry(number: 36, seed: 0xaf61f5b01f0c3212, band: 2, energy: 10),
        EchoCartographerManifestEntry(number: 37, seed: 0x56d45f094db5611e, band: 2, energy: 11),
        EchoCartographerManifestEntry(number: 38, seed: 0xbdeffad4b64967cd, band: 2, energy: 12),
        EchoCartographerManifestEntry(number: 39, seed: 0x7d2c5578313745e3, band: 2, energy: 13),
        EchoCartographerManifestEntry(number: 40, seed: 0x51233f216bb78548, band: 2, energy: 10),
        EchoCartographerManifestEntry(number: 41, seed: 0x4f511801916accf4, band: 3, energy: 13),
        EchoCartographerManifestEntry(number: 42, seed: 0xe119bb782f20fbe4, band: 3, energy: 14),
        EchoCartographerManifestEntry(number: 43, seed: 0xe2d1b25e397ff46b, band: 3, energy: 15),
        EchoCartographerManifestEntry(number: 44, seed: 0x6c000726a14dd4d8, band: 3, energy: 12),
        EchoCartographerManifestEntry(number: 45, seed: 0x05937b29e4ef648f, band: 3, energy: 13),
        EchoCartographerManifestEntry(number: 46, seed: 0x21bc42bab77d25d9, band: 3, energy: 14),
        EchoCartographerManifestEntry(number: 47, seed: 0x43436cbf1a09a018, band: 3, energy: 15),
        EchoCartographerManifestEntry(number: 48, seed: 0x377f200f6b4bd5db, band: 3, energy: 12),
        EchoCartographerManifestEntry(number: 49, seed: 0x79d13add8087d663, band: 3, energy: 13),
        EchoCartographerManifestEntry(number: 50, seed: 0x4c83ba1269f63f57, band: 3, energy: 14),
        EchoCartographerManifestEntry(number: 51, seed: 0x4d0e8e9016c02eb4, band: 3, energy: 15),
        EchoCartographerManifestEntry(number: 52, seed: 0xf21861d5c80980d4, band: 3, energy: 12),
        EchoCartographerManifestEntry(number: 53, seed: 0x8112c8033eb9874a, band: 3, energy: 13),
        EchoCartographerManifestEntry(number: 54, seed: 0x6611356e7b1d8ff9, band: 3, energy: 14),
        EchoCartographerManifestEntry(number: 55, seed: 0x173b692f52a84a9e, band: 3, energy: 15),
        EchoCartographerManifestEntry(number: 56, seed: 0x2d871c2131c8fc36, band: 3, energy: 12),
        EchoCartographerManifestEntry(number: 57, seed: 0xc8bfc1f3e90bffa5, band: 3, energy: 13),
        EchoCartographerManifestEntry(number: 58, seed: 0xd308a0f44b9585fc, band: 3, energy: 14),
        EchoCartographerManifestEntry(number: 59, seed: 0xa68cb165e8060704, band: 3, energy: 15),
        EchoCartographerManifestEntry(number: 60, seed: 0x5584fae259af69c1, band: 3, energy: 12),
        EchoCartographerManifestEntry(number: 61, seed: 0x995051a82b664419, band: 4, energy: 15),
        EchoCartographerManifestEntry(number: 62, seed: 0xae31651e435e0377, band: 4, energy: 16),
        EchoCartographerManifestEntry(number: 63, seed: 0x3f04d87b2513f47a, band: 4, energy: 17),
        EchoCartographerManifestEntry(number: 64, seed: 0xaf4d5eca98e52477, band: 4, energy: 14),
        EchoCartographerManifestEntry(number: 65, seed: 0xa9617d198319f390, band: 4, energy: 15),
        EchoCartographerManifestEntry(number: 66, seed: 0x35cea9516db3e749, band: 4, energy: 16),
        EchoCartographerManifestEntry(number: 67, seed: 0xd12e10827c1e707a, band: 4, energy: 17),
        EchoCartographerManifestEntry(number: 68, seed: 0xeab9b9696e03f786, band: 4, energy: 14),
        EchoCartographerManifestEntry(number: 69, seed: 0x35bd08b16e439e26, band: 4, energy: 15),
        EchoCartographerManifestEntry(number: 70, seed: 0x642bd6ea8b907ecd, band: 4, energy: 16),
        EchoCartographerManifestEntry(number: 71, seed: 0x616d3b133f690810, band: 4, energy: 17),
        EchoCartographerManifestEntry(number: 72, seed: 0x01834e5a7ea0bb8f, band: 4, energy: 14),
        EchoCartographerManifestEntry(number: 73, seed: 0x8e7cd3bb4b540745, band: 4, energy: 15),
        EchoCartographerManifestEntry(number: 74, seed: 0xf4f57e30ca48858c, band: 4, energy: 16),
        EchoCartographerManifestEntry(number: 75, seed: 0x4ec31c833695fe1f, band: 4, energy: 17),
        EchoCartographerManifestEntry(number: 76, seed: 0x6f34f85472a8218c, band: 4, energy: 14),
        EchoCartographerManifestEntry(number: 77, seed: 0xdcd3f72161df40c4, band: 4, energy: 15),
        EchoCartographerManifestEntry(number: 78, seed: 0xf8ff6d48c44457e2, band: 4, energy: 16),
        EchoCartographerManifestEntry(number: 79, seed: 0x38f06401d73901ff, band: 4, energy: 17),
        EchoCartographerManifestEntry(number: 80, seed: 0x94690091d18ea388, band: 4, energy: 14),
        EchoCartographerManifestEntry(number: 81, seed: 0xade6e75111bb5648, band: 5, energy: 17),
        EchoCartographerManifestEntry(number: 82, seed: 0x4ee9db22697819c4, band: 5, energy: 18),
        EchoCartographerManifestEntry(number: 83, seed: 0x6a63c59eeb6a913a, band: 5, energy: 19),
        EchoCartographerManifestEntry(number: 84, seed: 0x0aead6b16ceb5a8b, band: 5, energy: 16),
        EchoCartographerManifestEntry(number: 85, seed: 0x337dda401da9d44b, band: 5, energy: 17),
        EchoCartographerManifestEntry(number: 86, seed: 0x3144be629c348c77, band: 5, energy: 18),
        EchoCartographerManifestEntry(number: 87, seed: 0x2c5669ce6962a438, band: 5, energy: 19),
        EchoCartographerManifestEntry(number: 88, seed: 0xfed54f622bd635ec, band: 5, energy: 16),
        EchoCartographerManifestEntry(number: 89, seed: 0x51c0aec9487ac455, band: 5, energy: 17),
        EchoCartographerManifestEntry(number: 90, seed: 0x8240b6623a3cfb06, band: 5, energy: 18),
        EchoCartographerManifestEntry(number: 91, seed: 0xbcc34d44cfd42d52, band: 5, energy: 19),
        EchoCartographerManifestEntry(number: 92, seed: 0xd3d408cdb7013d44, band: 5, energy: 16),
        EchoCartographerManifestEntry(number: 93, seed: 0xde09d51fcd15c9d3, band: 5, energy: 17),
        EchoCartographerManifestEntry(number: 94, seed: 0xa3a6ec46faf3ac23, band: 5, energy: 18),
        EchoCartographerManifestEntry(number: 95, seed: 0xeac2450d8918d59e, band: 5, energy: 19),
        EchoCartographerManifestEntry(number: 96, seed: 0xe194569fb3495210, band: 5, energy: 16),
        EchoCartographerManifestEntry(number: 97, seed: 0x81bedf471dae3861, band: 5, energy: 17),
        EchoCartographerManifestEntry(number: 98, seed: 0x65b9b40d8def2fb3, band: 5, energy: 18),
        EchoCartographerManifestEntry(number: 99, seed: 0x28ae31128ac2a405, band: 5, energy: 19),
        EchoCartographerManifestEntry(number: 100, seed: 0xd4d926cf1bba1115, band: 5, energy: 16),
    ]
}
