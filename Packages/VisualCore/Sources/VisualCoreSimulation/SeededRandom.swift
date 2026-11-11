// SeededRandom.swift — xoshiro256** seeded through SplitMix64 (feature 006 T-F508; FR-F504; research R4).
// Algorithms by David Blackman and Sebastiano Vigna (public domain, prng.di.unimi.it), re-implemented here.
// Integer-only core, so a seed gives the same sequence on every platform.
import Foundation

/// SplitMix64, used to expand a 64-bit seed into xoshiro state.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    /// Current 64-bit state (advanced by the golden-ratio increment on each draw).
    public private(set) var state: UInt64
    /// Starts from `seed` as the initial state.
    public init(seed: UInt64) { state = seed }
    /// Next 64-bit output (SplitMix64 finalizer).
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Deterministic random numbers for simulations; conforms to `RandomNumberGenerator`.
public struct SeededRandom: RandomNumberGenerator, Sendable, Equatable {
    private var s0: UInt64, s1: UInt64, s2: UInt64, s3: UInt64
    /// The seed this generator was created with.
    public let seed: UInt64

    /// Seeds the four xoshiro256** state words from SplitMix64(`seed`); identical on every platform.
    public init(seed: UInt64) {
        self.seed = seed
        var sm = SplitMix64(seed: seed)
        s0 = sm.next(); s1 = sm.next(); s2 = sm.next(); s3 = sm.next()
    }

    @inline(__always) private static func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 { (x << k) | (x >> (64 - k)) }

    /// Next 64-bit xoshiro256** output.
    public mutating func next() -> UInt64 {
        let result = Self.rotl(s1 &* 5, 7) &* 9
        let t = s1 << 17
        s2 ^= s0; s3 ^= s1; s1 ^= s2; s0 ^= s3
        s2 ^= t
        s3 = Self.rotl(s3, 45)
        return result
    }

    /// Uniform in [0, 1) from the top 53 bits.
    public mutating func double() -> Double { Double(next() >> 11) * 0x1.0p-53 }
    /// Uniform in [0, 1) from the top 24 bits.
    public mutating func float() -> Float { Float(next() >> 40) * 0x1.0p-24 }
    /// Uniform in `range` (lower bound inclusive).
    public mutating func range(_ r: ClosedRange<Double>) -> Double { r.lowerBound + (r.upperBound - r.lowerBound) * double() }
    /// Uniform integer in `range`, unbiased (rejection sampling).
    public mutating func int(_ r: ClosedRange<Int>) -> Int {
        let span = UInt64(bitPattern: Int64(r.upperBound) &- Int64(r.lowerBound)) &+ 1
        if span == 0 { return Int(truncatingIfNeeded: next()) }   // full 64-bit range
        let limit = UInt64.max - UInt64.max % span
        var v = next()
        while v >= limit { v = next() }
        return r.lowerBound &+ Int(truncatingIfNeeded: v % span)
    }
    /// Standard normal (Box–Muller).
    public mutating func normal(mean: Double = 0, deviation: Double = 1) -> Double {
        let u1 = 1 - double(), u2 = double()   // u1 ∈ (0, 1] avoids log(0)
        return mean + deviation * (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}
