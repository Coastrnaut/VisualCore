// ShaderHash.swift — feature 203 T-R02F03-012 (FR-R02F03-040, research D4): the CPU twin of the GLSL library file
// vc/hash.glsl (Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/hash.glsl). The integer hash is the
// PCG hash (permuted congruential generator, M. E. O'Neill; the public-domain RXS-M-XS hash variant popularised by
// Jarzynski and Olano, "Hash Functions for GPU Rendering", 2020). Every line mirrors the shader: wrapping UInt32
// arithmetic, float inputs taken by IEEE-754 bit pattern, and float(uint) rounded to Float then divided by 2^32.

/// A CPU twin of the shader hashes in `vc/hash.glsl`: each function returns exactly what the shader computes.
public enum ShaderHash {
    /// `vc_pcg`: the PCG integer hash of `v`, with 32-bit wrapping arithmetic.
    public static func pcg(_ v: UInt32) -> UInt32 {
        let state = v &* 747_796_405 &+ 2_891_336_453
        let word = ((state >> ((state >> 28) &+ 4)) ^ state) &* 277_803_737
        return (word >> 22) ^ word
    }

    /// `vc_hash11`: a uniform hash of the bit pattern of `p` in [0, 1]. As in the shader, `Float(UInt32)` rounds to
    /// the nearest Float, so the few largest hash words give exactly 1.
    public static func hash11(_ p: Float) -> Float {
        unit(pcg(p.bitPattern))
    }

    /// `vc_hash21`: a uniform hash of the point (`x`, `y`), taken by bit pattern, in [0, 1] (see ``hash11(_:)``).
    public static func hash21(_ x: Float, _ y: Float) -> Float {
        unit(pcg(x.bitPattern ^ pcg(y.bitPattern)))
    }

    /// `vc_hash22`: two uniform hashes of the point (`x`, `y`), taken by bit pattern; the first equals
    /// ``hash21(_:_:)``, the second hashes the first's integer word again.
    public static func hash22(_ x: Float, _ y: Float) -> (Float, Float) {
        let a = pcg(x.bitPattern ^ pcg(y.bitPattern))
        return (unit(a), unit(pcg(a)))
    }

    /// `float(u) / 4294967296.0` with the shader's float rounding.
    private static func unit(_ u: UInt32) -> Float { Float(u) / 4_294_967_296.0 }
}
