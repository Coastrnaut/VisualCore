// SeedOffsets.swift — maps a 64-bit seed to shader-friendly offsets (feature 012 T-A01-107; clarification 2).
import VisualCoreSimulation

/// Four values in [0, 1) derived from a seed: the first four outputs of `SeededRandom(seed:)`. Shaders receive these as
/// `u_seed`; they never see the raw 64-bit seed.
public enum SeedOffsets {
    /// Offsets for `seed`.
    public static func of(_ seed: UInt64) -> SIMD4<Double> {
        var rng = SeededRandom(seed: seed)
        return SIMD4(rng.double(), rng.double(), rng.double(), rng.double())
    }
}
