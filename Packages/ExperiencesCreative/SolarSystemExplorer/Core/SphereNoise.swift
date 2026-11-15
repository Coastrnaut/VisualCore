// SphereNoise — feature 105 (A14-P03) T-A14-302 (FR-A14-301; SC-A14-301; clarification Q1; research D1; data-model
// "SphereNoise"). App-local seeded 3D value noise for seam-free body surfaces: the value of every integer lattice corner
// is a SplitMix64 hash of (seed, ix, iy, iz) mapped to [0, 1]; a sample is the smoothstep-weighted trilinear
// interpolation of its cell's eight corners; four octaves (lacunarity 2, gain 0.5) are summed and divided by the sum
// of their amplitudes (1.875), so every value lies in [0, 1].
//
// The noise is sampled at a direction, never at longitude and latitude, so it has no seam and no pinch at the poles.
// Before sampling, a direction is normalised to unit length and each component is rounded to a grid of 2^-30 (exact
// in binary floating point). The rounding absorbs the last-bit differences between the duplicated seam vertices of a
// UV sphere (sin 2π ≈ −2.4e-16 instead of 0) and between the vertices of a pole row, so equal directions give exactly
// equal values. A non-finite or zero-length input gives 0.5, the middle of the range.
//
// VisualCore has only 2D gradient noise; a VisualCore 3D noise is deferred while this experience is its one consumer
// (contract, principle II-a not triggered).
import Foundation
import VisualCoreMath

/// Seeded, deterministic 3D fractal value noise sampled at unit directions, in [0, 1].
public struct SphereNoise: Equatable, Sendable {
    /// Number of summed octaves.
    public static let octaves = 4
    /// Frequency factor between successive octaves.
    public static let lacunarity: Double = 2
    /// Amplitude factor between successive octaves.
    public static let gain: Double = 0.5
    /// The value returned for a non-finite or zero-length input.
    public static let fallbackValue: Double = 0.5
    /// The grid that normalised direction components are rounded to (2^-30), so equal directions give equal values.
    public static let directionQuantum: Double = 1.0 / 1_073_741_824.0

    /// The seed of the lattice hash.
    public let seed: UInt64
    /// Lattice cells per unit length in the first octave (non-finite or non-positive values become 1).
    public let frequency: Double

    /// Creates noise with `seed` and the first octave's `frequency` (lattice cells per unit length).
    public init(seed: UInt64, frequency: Double = 1) {
        self.seed = seed
        self.frequency = frequency.isFinite && frequency > 0 ? frequency : 1
    }

    /// `point` normalised to unit length with components rounded to ``directionQuantum``; nil when non-finite or zero.
    public static func unitDirection(_ point: Vec3) -> Vec3? {
        guard point.isFinite else { return nil }
        let length = point.length
        guard length.isFinite, length > 0 else { return nil }
        let unit = point / length
        let scale = 1.0 / directionQuantum
        return Vec3((unit.x * scale).rounded() / scale, (unit.y * scale).rounded() / scale,
                    (unit.z * scale).rounded() / scale)
    }

    /// The fractal noise value in [0, 1] at the direction of `point` (any length); 0.5 for a non-finite or zero input.
    public func value(at point: Vec3) -> Double {
        guard let direction = SphereNoise.unitDirection(point) else { return SphereNoise.fallbackValue }
        var sum = 0.0
        var amplitude = 1.0
        var amplitudeSum = 0.0
        var octaveFrequency = frequency
        for octave in 0..<SphereNoise.octaves {
            let octaveSeed = SphereNoise.splitMix64(seed &+ UInt64(octave) &* 0x9E37_79B9_7F4A_7C15)
            sum += amplitude * SphereNoise.lattice(direction * octaveFrequency, seed: octaveSeed)
            amplitudeSum += amplitude
            amplitude *= SphereNoise.gain
            octaveFrequency *= SphereNoise.lacunarity
        }
        return min(max(sum / amplitudeSum, 0), 1)
    }

    /// One octave: smoothstep-weighted trilinear interpolation of the eight hashed corners of `p`'s cell, in [0, 1].
    static func lattice(_ p: Vec3, seed: UInt64) -> Double {
        let fx = p.x.rounded(.down), fy = p.y.rounded(.down), fz = p.z.rounded(.down)
        let ix = Int64(fx), iy = Int64(fy), iz = Int64(fz)
        let tx = smoothstep(p.x - fx), ty = smoothstep(p.y - fy), tz = smoothstep(p.z - fz)
        var corners: [Double] = []
        corners.reserveCapacity(8)
        for dz in Int64(0)...1 {
            for dy in Int64(0)...1 {
                for dx in Int64(0)...1 {
                    corners.append(cornerValue(seed: seed, ix &+ dx, iy &+ dy, iz &+ dz))
                }
            }
        }
        let x00 = mix(corners[0], corners[1], tx), x10 = mix(corners[2], corners[3], tx)
        let x01 = mix(corners[4], corners[5], tx), x11 = mix(corners[6], corners[7], tx)
        return mix(mix(x00, x10, ty), mix(x01, x11, ty), tz)
    }

    /// The value in [0, 1] of the lattice corner (ix, iy, iz): the top 53 bits of a chained SplitMix64 hash.
    static func cornerValue(seed: UInt64, _ ix: Int64, _ iy: Int64, _ iz: Int64) -> Double {
        var h = splitMix64(seed)
        h = splitMix64(h ^ UInt64(bitPattern: ix))
        h = splitMix64(h ^ UInt64(bitPattern: iy))
        h = splitMix64(h ^ UInt64(bitPattern: iz))
        return Double(h >> 11) / Double(UInt64(1) << 53)
    }

    /// The SplitMix64 finaliser of `x` (Steele, Lea and Flood 2014): one step of state increment and mixing.
    static func splitMix64(_ x: UInt64) -> UInt64 {
        var z = x &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    private static func smoothstep(_ t: Double) -> Double { t * t * (3 - 2 * t) }
    private static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
}
