// SkyNoise — feature 152 (A21-P01) T-A21-105 (FR-A21-104; clarification Q2). A bit-exact Swift port of VisualCore's
// GLSL hash and noise library (`vc/hash.glsl`, `vc/noise.glsl`): `vc_pcg`, `vc_hash21`, `vc_hash22`,
// `vc_gradientNoise` and `vc_fbm`. The hashes act on the IEEE bit patterns of `Float`, as `floatBitsToUint` does on
// the GPU, so the same input gives the same integer; the noise is polynomial, so the port agrees with the GPU to
// rounding. `SkyReference` evaluates the sky with it. Pure Swift; no GPU and no clock.

/// The Swift port of the `vc/` GLSL hashes and noise used by `aurora-sky.frag`.
public enum SkyNoise {
    /// `vc_pcg`: the PCG integer hash of one 32-bit word (wrapping arithmetic, as GLSL `uint`).
    public static func pcg(_ v: UInt32) -> UInt32 {
        let state = v &* 747_796_405 &+ 2_891_336_453
        let word = ((state >> ((state >> 28) &+ 4)) ^ state) &* 277_803_737
        return (word >> 22) ^ word
    }

    /// `vc_hash21`: a uniform hash of a 2D point in [0, 1), from the bit patterns of its coordinates.
    public static func hash21(_ p: SIMD2<Float>) -> Float {
        Float(pcg(p.x.bitPattern ^ pcg(p.y.bitPattern))) / 4_294_967_296.0
    }

    /// `vc_hash22`: two uniform hashes of a 2D point in [0, 1).
    public static func hash22(_ p: SIMD2<Float>) -> SIMD2<Float> {
        let a = pcg(p.x.bitPattern ^ pcg(p.y.bitPattern))
        return SIMD2(Float(a), Float(pcg(a))) / 4_294_967_296.0
    }

    /// `vc_gradientNoise`: gradient noise in about [-1, 1] with the quintic fade of the GLSL library.
    public static func gradientNoise(_ p: SIMD2<Float>) -> Float {
        let i = SIMD2(p.x.rounded(.down), p.y.rounded(.down))
        let f = p - i
        let u = f * f * f * (f * (f * 6 - 15) + 10)
        let ga = hash22(i) * 2 - 1, gb = hash22(i + SIMD2(1, 0)) * 2 - 1
        let gc = hash22(i + SIMD2(0, 1)) * 2 - 1, gd = hash22(i + SIMD2(1, 1)) * 2 - 1
        let a = dot(ga, f), b = dot(gb, f - SIMD2(1, 0))
        let c = dot(gc, f - SIMD2(0, 1)), d = dot(gd, f - SIMD2(1, 1))
        return 1.4142 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y)
    }

    /// `vc_fbm`: fractal Brownian motion of gradient noise over 1…8 octaves (others are clamped by the loop as in
    /// GLSL: at most 8, none below 1 gives 0), normalised to about [-1, 1].
    public static func fbm(_ p: SIMD2<Float>, octaves: Int, lacunarity: Float = 2, gain: Float = 0.5) -> Float {
        var sum: Float = 0, amp: Float = 0.5, norm: Float = 0
        var q = p
        for i in 0..<8 {
            if i >= octaves { break }
            sum += amp * gradientNoise(q)
            norm += amp
            q *= lacunarity
            amp *= gain
        }
        return norm > 0 ? sum / norm : 0
    }

    /// GLSL `mix`: `a + (b - a) × t`, written as GLSL defines it (`a × (1 − t) + b × t`).
    @inline(__always) static func mix(_ a: Float, _ b: Float, _ t: Float) -> Float { a * (1 - t) + b * t }

    /// GLSL `dot` of two 2D vectors.
    @inline(__always) static func dot(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float { a.x * b.x + a.y * b.y }
}
