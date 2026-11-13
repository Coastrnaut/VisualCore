// SeedDerivation.swift — named sub-seeds from a seed and a label or index (feature 203 R02-F03 T-R02F03-003;
// FR-R02F03-010..012; data-model "Sub-seed derivation"). The SplitMix64 finalizer (Sebastiano Vigna) and FNV-1a
// (Fowler, Noll, Vo) are public-domain algorithms, re-implemented here with integer arithmetic only, so a derived
// seed is identical on every platform.

/// Derives independent, reproducible sub-seeds from one seed, by text label or by unsigned index.
public enum SeedDerivation {
    /// The SplitMix64 finalizer: a bijective 64-bit mix (`mix(0x9E3779B97F4A7C15)` is SplitMix64's first output for state 0).
    public static func mix(_ z: UInt64) -> UInt64 {
        var z = z
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// FNV-1a 64-bit hash of the label's UTF-8 bytes (offset basis `0xcbf29ce484222325`, prime `0x100000001b3`).
    public static func fnv1a64(_ label: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in label.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    /// Sub-seed for a named stream: `mix(seed ^ fnv1a64(label))`.
    public static func derive(_ seed: UInt64, label: String) -> UInt64 {
        mix(seed ^ fnv1a64(label))
    }

    /// Sub-seed for a numbered stream: `mix(seed ^ mix(index &+ 1))`.
    public static func derive(_ seed: UInt64, index: UInt64) -> UInt64 {
        mix(seed ^ mix(index &+ 1))
    }
}

extension SeededRandom {
    /// Creates the generator for the stream named `label` of `seed` (seeded with `SeedDerivation.derive(seed, label:)`).
    public init(seed: UInt64, label: String) {
        self.init(seed: SeedDerivation.derive(seed, label: label))
    }

    /// Creates the generator for stream number `index` of `seed` (seeded with `SeedDerivation.derive(seed, index:)`).
    public init(seed: UInt64, index: UInt64) {
        self.init(seed: SeedDerivation.derive(seed, index: index))
    }
}
