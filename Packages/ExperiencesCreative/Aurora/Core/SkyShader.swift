// SkyShader — feature 152 (A21-P01) T-A21-105 (FR-A21-104, FR-A21-105; clarification Q2). The sky's one fragment
// shader, `aurora-sky.frag`, held as source text (data: the core issues no GL call), and `SkyUniforms`, the values it
// is drawn with. The shader composites, in order, hashed stars with a bounded twinkle (±30 % of each star's base over
// the loop, one star per reference pixel cell, so a star is at most one pixel at 64 × 48), fbm clouds and up to four
// ribbons as slowly advected fbm colour bands mixed with additive light. The phase moves every noise sample along a
// circle in noise space and the twinkle by whole cycles, so phase 0 and phase 1 give the same picture (a seamless
// 600 s loop). A final soft knee keeps every pixel's Rec. 709 luminance at most 0.72 (linear light, before the sRGB
// encode). Level 0 uses 5 octaves and level 1 uses 3. `SkyReference` evaluates the same formulas in `Float`.
//
// Feature 153 (A21-P02) T-A21-205 (FR-A21-203; clarification Q2): the brightness limit `u_limit` (0.2…0.72). The soft
// knee starts at ``SkyShader/kneeRatio`` (5/6, about 0.83) × limit and approaches the limit, after compositing and
// before the sRGB encode, so every pixel's luminance is at most the limit. The default limit 0.72 gives the A21-P01
// knee (start 0.6, ceiling 0.72) unchanged.
//
// Feature 155 (A21-P04) T-A21-407, T-A21-408 (FR-A21-402, FR-A21-403; clarifications Q2, Q4): the reduced-flash switch
// `u_twinkleOff` (0 by default, which GL gives an unset uniform, so the default picture is unchanged: the factor
// `1 − 0` is exactly 1) sets the twinkle amplitude to 0 when 1; it is not one of ``SkyShader/uniformNames`` (the
// experience binds it, ``SkyShader/twinkleOffParameter``). ``SkyShader/fallbackSource`` is the minimal still sky for a
// device that cannot run `aurora-sky.frag`: the sky colour at the top to 0.6 × at the horizon, under the limit.
import Foundation

/// The values `aurora-sky.frag` is drawn with. The palette is in **linear light** (as `FullScreenShaderScene.palette`
/// expects); ``init(scene:phase:level:)`` decodes a scene's sRGB colours.
public struct SkyUniforms: Equatable, Sendable {
    /// Palette stops in linear light: the first is the sky, the rest colour the ribbons in turn (2…4 used; the shader
    /// takes at most 8).
    public var palette: [SIMD3<Float>]
    /// The number of ribbons drawn (the shader draws at most 4).
    public var ribbons: Int
    /// How strongly the ribbons fold (0…1).
    public var turbulence: Float
    /// How much of the sky the clouds cover (0…1).
    public var cloudiness: Float
    /// The star count at the reference size (0…400 stars over 64 × 48 cells).
    public var stars: Int
    /// The loop phase in 0…1; only its fractional part is used, so 0 and 1 draw the same picture.
    public var phase: Float
    /// The fbm octave count (``SkyShader/octaves(forLevel:)``).
    public var octaves: Int
    /// The brightness limit: the largest Rec. 709 luminance (linear light) a pixel reaches (feature 153; default
    /// ``SkyShader/luminanceCeiling``, 0.72, the A21-P01 knee).
    public var limit: Float

    /// Uniforms with the values as given (nothing is clamped; the shader bounds the loops); `limit` defaults to
    /// ``SkyShader/luminanceCeiling``.
    public init(palette: [SIMD3<Float>], ribbons: Int, turbulence: Float, cloudiness: Float, stars: Int,
                phase: Float, octaves: Int, limit: Float = SkyShader.luminanceCeiling) {
        self.palette = palette
        self.ribbons = ribbons
        self.turbulence = turbulence
        self.cloudiness = cloudiness
        self.stars = stars
        self.phase = phase
        self.octaves = octaves
        self.limit = limit
    }

    /// The uniforms of `scene` at `phase` (0…1, for example ``SkyClock/phase``) and quality `level`: the palette is
    /// decoded from sRGB to linear light and the octaves come from ``SkyShader/octaves(forLevel:)``; `limit` defaults
    /// to ``SkyShader/luminanceCeiling``.
    public init(scene: SkyScene, phase: Double, level: Int, limit: Double = Double(SkyShader.luminanceCeiling)) {
        self.init(palette: scene.palette.map { SkyShader.linear($0) }, ribbons: scene.ribbons,
                  turbulence: Float(scene.turbulence), cloudiness: Float(scene.cloudiness), stars: scene.stars,
                  phase: Float(phase), octaves: SkyShader.octaves(forLevel: level), limit: Float(limit))
    }

    /// The float parameters for `FullScreenShaderScene.parameters` (bound as `u_<name>`): `phase`, `ribbons`,
    /// `turbulence`, `cloudiness`, `stars`, `octaves` and `limit`. Every value converts back to the same `Float`.
    public var shaderParameters: [String: Double] {
        ["phase": Double(phase), "ribbons": Double(ribbons), "turbulence": Double(turbulence),
         "cloudiness": Double(cloudiness), "stars": Double(stars), "octaves": Double(octaves),
         "limit": Double(limit)]
    }
}

/// The sky's fragment shader as data, its uniforms and its quality levels.
public enum SkyShader {
    /// The shader's name in diagnostics.
    public static let fragmentName = "aurora-sky.frag"
    /// The quality levels: 0 (full) and 1 (reduced).
    public static let levels: ClosedRange<Int> = 0...1
    /// The reference size the star cells and the tests use (64 × 48 pixels).
    public static let referenceSize = (width: 64, height: 48)
    /// The largest Rec. 709 luminance (linear light) the soft knee reaches; below the declared 0.75 so that 8-bit
    /// rounding cannot cross it.
    public static let luminanceCeiling: Float = 0.72
    /// The luminance where the soft knee starts at the default limit (``kneeRatio`` × ``luminanceCeiling``).
    public static let kneeStart: Float = 0.6
    /// The knee's start as a share of the limit: 0.6 / 0.72 = 5/6 (about 0.83), so the default limit keeps the
    /// A21-P01 knee (feature 153).
    public static let kneeRatio: Float = 0.6 / 0.72
    /// The accepted brightness limits (feature 153): 0.2…0.72.
    public static let limitRange: ClosedRange<Double> = 0.2...0.72
    /// The twinkle amplitude: a star's brightness stays within ±30 % of its base.
    public static let twinkleAmplitude: Float = 0.3
    /// The sky-specific uniform names (besides `u_resolution`, `u_palette` and `u_paletteCount`).
    public static let uniformNames = ["u_phase", "u_ribbons", "u_turbulence", "u_cloudiness", "u_stars", "u_octaves",
                                      "u_limit"]

    /// The parameter name (bound as `u_twinkleOff`) that turns the twinkle off when 1 (feature 155, reduced flash);
    /// unset it is 0 and the picture is the default one.
    public static let twinkleOffParameter = "twinkleOff"
    /// The fallback shader's name in diagnostics (feature 155).
    public static let fallbackName = "aurora-fallback.frag"
    /// The fallback's darkening at the horizon: the sky colour × 0.6 (feature 155).
    public static let fallbackHorizon: Float = 0.6

    /// The fbm octaves of quality `level`: 0 (or below) → 5, 1 (or above) → 3.
    public static func octaves(forLevel level: Int) -> Int { level <= 0 ? 5 : 3 }

    /// An sRGB colour decoded to linear light (the exact sRGB transfer function).
    public static func linear(_ color: SkyColor) -> SIMD3<Float> {
        SIMD3(Float(decode(color.red)), Float(decode(color.green)), Float(decode(color.blue)))
    }

    private static func decode(_ c: Double) -> Double {
        let v = min(max(c, 0), 1)
        return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }

    /// The GLSL ES 3.00 source of `aurora-sky.frag` (the program adds the version line). It includes `vc/noise.glsl`
    /// and `vc/color.glsl` and draws in pixel centres (`gl_FragCoord`, origin bottom-left).
    public static let source = """
    precision highp float;
    #include "vc/noise.glsl"
    #include "vc/color.glsl"
    uniform vec2 u_resolution;
    uniform vec3 u_palette[8];
    uniform int u_paletteCount;
    uniform float u_phase;
    uniform float u_ribbons;
    uniform float u_turbulence;
    uniform float u_cloudiness;
    uniform float u_stars;
    uniform float u_octaves;
    uniform float u_limit;
    uniform float u_twinkleOff;
    out vec4 color;

    const float AU_TAU = 6.2831853;

    vec3 au_stop(int i) { return u_palette[clamp(i, 0, max(u_paletteCount, 1) - 1)]; }

    void main() {
        vec2 uv = gl_FragCoord.xy / u_resolution;
        int oct = int(u_octaves + 0.5);
        float ph = fract(u_phase);
        float ang = AU_TAU * ph;
        vec2 loop = vec2(cos(ang), sin(ang));
        float aspect = u_resolution.x / u_resolution.y;
        vec2 p = vec2(uv.x * aspect, uv.y);
        float h = 1.0 - uv.y;
        vec3 rgb = au_stop(0) * (0.5 + 0.9 * h) + au_stop(1) * (0.03 * h * h);

        // Stars: one hashed cell per reference pixel (48 rows); at most one star per cell.
        float cellScale = u_resolution.y / 48.0;
        vec2 q = gl_FragCoord.xy / cellScale;
        vec2 base = floor(q);
        vec2 cell = base + vec2(101.0, 211.0);
        vec2 hs = vc_hash22(cell);
        vec2 hj = vc_hash22(cell + vec2(37.0, 0.0));
        float present = hs.x * 3072.0 < u_stars ? 1.0 : 0.0;
        vec2 centre = base + 0.5 + (hj - 0.5) * 0.5;
        float shape = 1.0 - smoothstep(0.0, 0.75, length(q - centre));
        float cycles = floor(1.0 + hj.y * 3.0);
        float twinkle = 1.0 + 0.3 * (1.0 - u_twinkleOff) * sin(AU_TAU * (cycles * ph + hs.y));
        float bright = 0.25 + 0.5 * vc_hash21(cell + vec2(0.0, 59.0));
        float star = present * shape * bright * twinkle * smoothstep(0.0, 0.25, uv.y);

        // Clouds: fbm cover dims the sky and the stars and adds a faint tint.
        vec2 cp = p * vec2(2.5, 3.0) + vec2(23.0, 41.0) + loop * 0.8;
        float cn = vc_fbm(cp, oct, 2.0, 0.5) * 0.5 + 0.5;
        float cover = u_cloudiness * smoothstep(0.35, 0.75, cn);
        rgb += vec3(star) * (1.0 - cover);
        vec3 tint = mix(au_stop(0) * 4.0, vec3(0.6, 0.6, 0.65), 0.5);
        rgb = rgb * (1.0 - 0.6 * cover) + tint * (0.1 * cover);

        // Ribbons: slowly advected fbm bands with a sharp lower edge, curtains rising above and fbm rays; additive.
        int colours = max(u_paletteCount - 1, 1);
        for (int i = 0; i < 4; i++) {
            if (float(i) >= u_ribbons) break;
            float fi = float(i);
            vec2 rp = vec2(p.x * 1.3 + fi * 7.3 + 31.0, fi * 3.1 + 53.0) + loop * 0.35;
            float bend = vc_fbm(rp, oct, 2.0, 0.5);
            float centreY = 0.78 - 0.13 * fi + bend * (0.08 + 0.14 * u_turbulence);
            float dy = uv.y - centreY;
            float width = dy > 0.0 ? 0.16 : 0.035;
            float r = dy / width;
            float t = clamp(1.0 - r * r, 0.0, 1.0);
            vec2 sp = vec2(p.x * 9.0 + fi * 11.0 + 7.0, uv.y * 1.5 + 13.0) + loop * 0.6;
            float rays = 0.55 + 0.45 * vc_fbm(sp, oct, 2.0, 0.5);
            float k = t * t * rays * 0.55;
            rgb += au_stop(1 + i % colours) * (k * (1.0 - 0.5 * cover));
        }

        // Soft knee: luminance never exceeds the limit in linear light (start 5/6 of the limit).
        rgb = clamp(rgb, 0.0, 1.0);
        float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
        float knee = 0.8333333 * u_limit;
        float room = u_limit - knee;
        if (lum > knee) {
            float x = lum - knee;
            rgb *= (knee + room * x / (x + room)) / lum;
        }
        color = vec4(vc_srgbEncode(rgb), 1.0);
    }
    """
}

extension SkyShader {
    /// The minimal fallback sky (feature 155, GLSL ES 3.00 with `mediump` only, no include): the sky colour
    /// (`u_palette[0]`, linear light) at the top to ``fallbackHorizon`` × that colour at the horizon, scaled down when
    /// its Rec. 709 luminance would pass `u_limit`, then sRGB-encoded. It needs no `highp` and draws a still picture.
    public static let fallbackSource = """
    precision mediump float;
    uniform vec2 u_resolution;
    uniform vec3 u_palette[8];
    uniform float u_limit;
    out vec4 color;

    vec3 au_encode(vec3 c) {
        vec3 lo = c * 12.92;
        vec3 hi = 1.055 * pow(max(c, vec3(0.0031308)), vec3(1.0 / 2.4)) - 0.055;
        return mix(hi, lo, vec3(lessThanEqual(c, vec3(0.0031308))));
    }

    void main() {
        float y = gl_FragCoord.y / u_resolution.y;
        vec3 rgb = clamp(u_palette[0] * mix(0.6, 1.0, y), 0.0, 1.0);
        float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
        float cap = max(u_limit, 0.0);
        if (lum > cap) rgb *= cap / max(lum, 1e-4);
        color = vec4(au_encode(rgb), 1.0);
    }
    """
}
