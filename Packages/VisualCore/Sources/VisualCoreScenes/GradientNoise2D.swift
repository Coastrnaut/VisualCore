// GradientNoise2D.swift — feature 089 (A12-P01) T-A12-102 (FR-A12-101, FR-A12-102; research D1).
// Seeded 2D gradient noise and its fractal sum. Lattice corners are hashed with the SplitMix64 finalizer (no
// permutation table) and every value is made from +, −, × and floor on binary64 only, so a value is bit-identical on
// every supported device and simulator.

/// Seeded two-dimensional gradient noise with values in −1…1.
///
/// The lattice cell of (x, y) is found with `floor`. Each corner (i, j) is hashed as
/// `mix(seed ^ (i · 0x9E3779B97F4A7C15) ^ (j · 0xC2B2AE3D27D4EB4F))` with wrapping 64-bit arithmetic on the two's
/// complement bit patterns of i and j, where `mix` is the SplitMix64 finalizer. The top three bits of the hash pick
/// one of eight gradients (the axis directions and the diagonals, the diagonals as the literal 0.7071067811865476),
/// whose dot product with the offset from the corner is blended with the quintic fade 6t⁵ − 15t⁴ + 10t³, scaled by
/// √2 (the literal 1.4142135623730951) and clamped to −1…1. The value is exactly 0 at every lattice point.
///
/// Only addition, subtraction, multiplication and `floor` are used, so results are bit-identical on every device.
public struct GradientNoise2D: Sendable, Equatable {
    /// The seed that selects the gradient at every lattice corner.
    public let seed: UInt64

    /// Noise with the given seed; equal seeds give equal noise.
    public init(seed: UInt64) { self.seed = seed }

    /// Noise at (x, y) in −1…1; deterministic and bit-identical on every supported device.
    ///
    /// Returns 0 when x or y is not finite, or when its magnitude is 2⁶² or more (outside the lattice index range).
    public func value(x: Double, y: Double) -> Double {
        guard x.isFinite, y.isFinite, abs(x) < Self.limit, abs(y) < Self.limit else { return 0 }
        let fx = x.rounded(.down), fy = y.rounded(.down)
        let i = Int64(fx), j = Int64(fy)
        let dx = x - fx, dy = y - fy
        let n00 = gradientDot(i, j, dx, dy)
        let n10 = gradientDot(i &+ 1, j, dx - 1, dy)
        let n01 = gradientDot(i, j &+ 1, dx, dy - 1)
        let n11 = gradientDot(i &+ 1, j &+ 1, dx - 1, dy - 1)
        let u = Self.fade(dx), v = Self.fade(dy)
        let bottom = n00 + (n10 - n00) * u
        let top = n01 + (n11 - n01) * u
        let blended = (bottom + (top - bottom) * v) * 1.4142135623730951
        return min(max(blended, -1), 1)
    }

    /// Largest coordinate magnitude (exclusive) that is mapped to the lattice: 2⁶².
    private static let limit = 4_611_686_018_427_387_904.0

    /// Quintic fade 6t⁵ − 15t⁴ + 10t³ in Horner form.
    private static func fade(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }

    /// Dot product of the gradient at corner (i, j) with the offset (dx, dy) from that corner.
    private func gradientDot(_ i: Int64, _ j: Int64, _ dx: Double, _ dy: Double) -> Double {
        var z = seed ^ (UInt64(bitPattern: i) &* 0x9E37_79B9_7F4A_7C15)
            ^ (UInt64(bitPattern: j) &* 0xC2B2_AE3D_27D4_EB4F)
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        let d = 0.7071067811865476
        switch z >> 61 {
        case 0: return dx
        case 1: return -dx
        case 2: return dy
        case 3: return -dy
        case 4: return d * dx + d * dy
        case 5: return -d * dx + d * dy
        case 6: return d * dx - d * dy
        default: return -d * dx - d * dy
        }
    }
}

/// A fractal sum of `GradientNoise2D` octaves with values in −1…1.
///
/// Octave k (0-based) uses the seed `seed &+ k`, the frequency `frequency · lacunarityᵏ` and the amplitude `gainᵏ`,
/// both powers formed by repeated multiplication. The sum is divided by the sum of the amplitudes and clamped to
/// −1…1. Like `GradientNoise2D` it uses only +, −, × and `floor`, so it is bit-identical on every supported device.
public struct FractalNoise2D: Sendable, Equatable {
    /// Seed of the first octave; octave k uses `seed &+ k`.
    public let seed: UInt64
    /// Number of octaves summed, 1…8.
    public let octaves: Int
    /// Frequency of the first octave (lattice cells per unit), finite and positive.
    public let frequency: Double
    /// Frequency factor from one octave to the next, 1…4.
    public let lacunarity: Double
    /// Amplitude factor from one octave to the next, 0…1.
    public let gain: Double

    /// Allowed octave counts.
    private static let octaveRange = 1...8
    /// Allowed lacunarity values.
    private static let lacunarityRange = 1.0...4.0
    /// Allowed gain values.
    private static let gainRange = 0.0...1.0

    /// nil for octaves outside 1…8, non-positive or non-finite frequency, lacunarity outside 1…4 or gain outside
    /// 0…1.
    ///
    /// A non-finite lacunarity or gain is refused as well.
    public init?(seed: UInt64, octaves: Int, frequency: Double, lacunarity: Double = 2, gain: Double = 0.5) {
        guard Self.octaveRange.contains(octaves), frequency.isFinite, frequency > 0,
              lacunarity.isFinite, Self.lacunarityRange.contains(lacunarity),
              gain.isFinite, Self.gainRange.contains(gain) else { return nil }
        self.seed = seed
        self.octaves = octaves
        self.frequency = frequency
        self.lacunarity = lacunarity
        self.gain = gain
    }

    /// Sum of octaves normalised by the amplitude sum, in −1…1.
    ///
    /// Returns 0 when x or y is not finite.
    public func value(x: Double, y: Double) -> Double {
        guard x.isFinite, y.isFinite else { return 0 }
        var sum = 0.0, amplitudeSum = 0.0
        var f = frequency, amplitude = 1.0
        for k in 0..<octaves {
            let noise = GradientNoise2D(seed: seed &+ UInt64(k))
            sum += amplitude * noise.value(x: x * f, y: y * f)
            amplitudeSum += amplitude
            f *= lacunarity
            amplitude *= gain
        }
        return min(max(sum / amplitudeSum, -1), 1)
    }
}
