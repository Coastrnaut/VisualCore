// SkyReference — feature 152 (A21-P01) T-A21-105 (FR-A21-104, FR-A21-105; clarifications Q2, Q3). The sky computed
// without the GPU: the formulas of `aurora-sky.frag` evaluated per pixel in `Float` with `SkyNoise`, the Swift port of
// the `vc/` hash and noise. It follows the GPU's conventions: pixel centres (`gl_FragCoord` = x + 0.5, y + 0.5, origin
// bottom-left), the exact sRGB encode of `vc/color.glsl` and round-to-nearest 8-bit conversion; the result is RGBA8
// with rows top-down, the orientation of `StillImage` from `RenderHost.renderOffscreen`. Pure Swift; no GPU, no clock.
import Foundation

/// The CPU reference of `aurora-sky.frag`.
public enum SkyReference {
    private static let tau: Float = 6.2831853

    /// The drawing of `uniforms` at `width` × `height` as RGBA8 bytes (alpha 255), rows top-down; empty for a
    /// non-positive size.
    public static func render(_ uniforms: SkyUniforms, width: Int, height: Int) -> [UInt8] {
        guard width > 0, height > 0 else { return [] }
        var out = [UInt8](repeating: 255, count: width * height * 4)
        let resolution = SIMD2(Float(width), Float(height))
        for row in 0..<height {
            let glY = height - 1 - row
            for x in 0..<width {
                let rgb = linearColor(uniforms, fragCoord: SIMD2(Float(x) + 0.5, Float(glY) + 0.5),
                                      resolution: resolution)
                let i = (row * width + x) * 4
                out[i] = quantize(srgbEncode(rgb.x))
                out[i + 1] = quantize(srgbEncode(rgb.y))
                out[i + 2] = quantize(srgbEncode(rgb.z))
            }
        }
        return out
    }

    /// A star's twinkle multiplier for its hashed `cell` at `phase`: `1 + 0.3 × sin(2π × (cycles × phase + offset))`
    /// with 1…3 whole cycles per loop, so it stays within ±30 % of the base and phase 0 and 1 agree.
    public static func twinkle(cell: SIMD2<Float>, phase: Float) -> Float {
        let hs = SkyNoise.hash22(cell)
        let hj = SkyNoise.hash22(cell + SIMD2(37, 0))
        let cycles = (1 + hj.y * 3).rounded(.down)
        let ph = phase - phase.rounded(.down)
        return 1 + SkyShader.twinkleAmplitude * sin(tau * (cycles * ph + hs.y))
    }

    /// The colour of one pixel in linear light, after the soft knee and before the sRGB encode, at `fragCoord`
    /// (pixel centre, origin bottom-left) of a drawing of `resolution` pixels.
    public static func linearColor(_ u: SkyUniforms, fragCoord: SIMD2<Float>, resolution: SIMD2<Float>) -> SIMD3<Float> {
        let palette = Array(u.palette.prefix(8))
        let count = max(palette.count, 1)
        func stop(_ i: Int) -> SIMD3<Float> {
            palette.isEmpty ? .zero : palette[min(max(i, 0), count - 1)]
        }
        let uv = fragCoord / resolution
        let oct = Int((Float(u.octaves) + 0.5).rounded(.down))
        let ph = u.phase - u.phase.rounded(.down)
        let ang = tau * ph
        let loop = SIMD2(cos(ang), sin(ang))
        let aspect = resolution.x / resolution.y
        let p = SIMD2(uv.x * aspect, uv.y)
        let h = 1 - uv.y
        var rgb = stop(0) * (0.5 + 0.9 * h) + stop(1) * (0.03 * h * h)

        // Stars.
        let cellScale = resolution.y / 48
        let q = fragCoord / cellScale
        let base = SIMD2(q.x.rounded(.down), q.y.rounded(.down))
        let cell = base + SIMD2(101, 211)
        let hs = SkyNoise.hash22(cell)
        let hj = SkyNoise.hash22(cell + SIMD2(37, 0))
        let present: Float = hs.x * 3072 < Float(u.stars) ? 1 : 0
        let centre = base + 0.5 + (hj - 0.5) * 0.5
        let d = q - centre
        let shape = 1 - smoothstep(0, 0.75, (d.x * d.x + d.y * d.y).squareRoot())
        let cycles = (1 + hj.y * 3).rounded(.down)
        let twinkle = 1 + 0.3 * sin(tau * (cycles * ph + hs.y))
        let bright = 0.25 + 0.5 * SkyNoise.hash21(cell + SIMD2(0, 59))
        let star = present * shape * bright * twinkle * smoothstep(0, 0.25, uv.y)

        // Clouds.
        let cp = p * SIMD2(2.5, 3.0) + SIMD2(23, 41) + loop * 0.8
        let cn = SkyNoise.fbm(cp, octaves: oct) * 0.5 + 0.5
        let cover = u.cloudiness * smoothstep(0.35, 0.75, cn)
        rgb += SIMD3(repeating: star) * (1 - cover)
        let tint = mix(stop(0) * 4, SIMD3(0.6, 0.6, 0.65), 0.5)
        rgb = rgb * (1 - 0.6 * cover) + tint * (0.1 * cover)

        // Ribbons.
        let colours = max(palette.count - 1, 1)
        for i in 0..<4 {
            let fi = Float(i)
            if fi >= Float(u.ribbons) { break }
            let rp = SIMD2(p.x * 1.3 + fi * 7.3 + 31, fi * 3.1 + 53) + loop * 0.35
            let bend = SkyNoise.fbm(rp, octaves: oct)
            let centreY = 0.78 - 0.13 * fi + bend * (0.08 + 0.14 * u.turbulence)
            let dy = uv.y - centreY
            let width: Float = dy > 0 ? 0.16 : 0.035
            let r = dy / width
            let t = min(max(1 - r * r, 0), 1)
            let sp = SIMD2(p.x * 9 + fi * 11 + 7, uv.y * 1.5 + 13) + loop * 0.6
            let rays = 0.55 + 0.45 * SkyNoise.fbm(sp, octaves: oct)
            let k = t * t * rays * 0.55
            rgb += stop(1 + i % colours) * (k * (1 - 0.5 * cover))
        }

        // Soft knee.
        rgb = SIMD3(min(max(rgb.x, 0), 1), min(max(rgb.y, 0), 1), min(max(rgb.z, 0), 1))
        let lum = luminance(rgb)
        if lum > SkyShader.kneeStart {
            let x = lum - 0.6
            rgb *= (0.6 + 0.12 * x / (x + 0.12)) / lum
        }
        return rgb
    }

    /// The Rec. 709 luminance of a linear-light colour.
    public static func luminance(_ rgb: SIMD3<Float>) -> Float { 0.2126 * rgb.x + 0.7152 * rgb.y + 0.0722 * rgb.z }

    /// The Rec. 709 luminance of one RGBA8 pixel at byte offset `index` of `rgba`, after the sRGB decode.
    public static func luminance(rgba: [UInt8], index: Int) -> Float {
        func dec(_ b: UInt8) -> Float {
            let c = Float(b) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return luminance(SIMD3(dec(rgba[index]), dec(rgba[index + 1]), dec(rgba[index + 2])))
    }

    /// `vc_srgbEncode` for one channel.
    static func srgbEncode(_ linear: Float) -> Float {
        let c = min(max(linear, 0), 1)
        return c < 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    /// Unsigned-normalised 8-bit conversion with round to nearest.
    static func quantize(_ v: Float) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }

    /// GLSL `smoothstep`.
    static func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
        let t = min(max((x - e0) / (e1 - e0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// GLSL `mix` of two colours.
    static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a * (1 - t) + b * t }
}
