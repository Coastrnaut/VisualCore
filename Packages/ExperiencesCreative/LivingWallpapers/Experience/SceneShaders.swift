// SceneShaders — feature 139 (A19-P02) T-A19-207 (FR-A19-203; G-SCENES; clarification Q3; research D4). The four
// curated scenes of `SceneCatalog`, drawn in code: one inline GLSL ES 3.00 fragment each on VisualCore's
// `FullScreenShaderScene`, over the GLSL library (`vc/hash`, `vc/noise`, `vc/palette`, `vc/sdf`, `vc/color`).
//
//   - aurora-bands: vertical light bands, their phase warped by fractal noise, brightest towards the top
//     (parameters: band count, drift, softness).
//   - ink-flow: domain-warped fractal noise, like ink spreading in water (warp, scale, flow speed).
//   - soft-cells: a Voronoi pattern with soft edges, each cell one tone of the preset (cell count, edge softness).
//   - ripple-dunes: layered sine dunes under a soft sun drawn with `vc_sdCircle` (layers, amplitude, wavelength).
//
// Uniforms: `u_time` (seconds, bound through the scene's `fixedTime`), `u_resolution` (pixels), `u_palette` with
// `u_paletteCount` (the preset's four colours in linear light, `vc_palette` blends them in order), `u_p0`, `u_p1` and
// `u_p2` (the scene's parameters in catalog order; an unused one is 0), `u_seed` (four offsets from the seed,
// `seedOffsets(seed:)`) and `u_level` (the quality tier: 0 full detail; 1 fewer octaves, cells or layers and one
// sample per 2 × 2 pixels). The helpers `lw_pixel()` (the sample point of the fragment's block) and `lw_write(rgb)`
// (the corner shade, then the sRGB encoding with `vc_srgbEncode`) are shared.
//
// Corner shade: within the last few percent of the half diagonal the colour fades to a quarter of the preset's
// deepest colour (linear light), so the canvas corners are `dark` for every preset; that is the presenter's frame
// probe. Equal uniforms give identical pixels: there is no other input.
import Foundation
import LivingWallpapersCore
import VisualCoreRendering

/// The fragment sources, uniforms and scene factory of the four scenes (see the file header).
enum SceneShaders {
    /// The number of scenes (`SceneCatalog.scenes`).
    static var sceneCount: Int { SceneCatalog.scenes.count }

    /// The uniform declarations and helpers every scene fragment shares (after the includes).
    static let common = """
    uniform vec2 u_resolution;
    uniform float u_time;
    uniform vec4 u_seed;
    uniform float u_p0;
    uniform float u_p1;
    uniform float u_p2;
    uniform float u_level;
    out vec4 color;

    vec2 lw_pixel() {
        float block = u_level > 0.5 ? 2.0 : 1.0;
        return (floor(gl_FragCoord.xy / block) + 0.5) * block;
    }

    void lw_write(vec3 rgb) {
        vec2 q = gl_FragCoord.xy / max(u_resolution, vec2(1.0)) * 2.0 - 1.0;
        float corner = smoothstep(0.93, 0.985, length(q) * 0.70710678);
        vec3 shaded = mix(clamp(rgb, 0.0, 1.0), u_palette[0] * 0.25, corner);
        color = vec4(clamp(vc_srgbEncode(shaded), 0.0, 1.0), 1.0);
    }
    """

    /// The includes of every scene fragment.
    static let includes = """
    precision highp float;
    #include "vc/hash.glsl"
    #include "vc/noise.glsl"
    #include "vc/palette.glsl"
    #include "vc/sdf.glsl"
    #include "vc/color.glsl"
    """

    /// Aurora bands: `u_p0` bands (2…8), `u_p1` drift (0…1), `u_p2` softness (0.1…1).
    static let auroraBands = """
    \(includes)
    \(common)

    void main() {
        vec2 pixel = lw_pixel();
        float x = pixel.x / max(u_resolution.x, 1.0);
        float y = pixel.y / max(u_resolution.y, 1.0);
        int octaves = u_level > 0.5 ? 2 : 4;
        float t = u_time * (0.02 + 0.12 * u_p1);
        float warp = vc_fbm(vec2(x * 2.0, y * 0.7) + u_seed.xy + vec2(0.0, t), octaves, 2.0, 0.5);
        float phase = x * max(u_p0, 1.0) + 1.6 * warp + t;
        float band = 0.5 + 0.5 * cos(6.2831853 * phase);
        band = pow(band, mix(9.0, 1.2, clamp(u_p2, 0.0, 1.0)));
        float rise = smoothstep(0.05, 0.95, y);
        vec3 sky = vc_palette(0.18 * y);
        vec3 glow = vc_palette(0.4 + 0.6 * band);
        lw_write(mix(sky, glow, band * rise * 0.95));
    }
    """

    /// Ink flow: `u_p0` warp (0…2), `u_p1` scale (0.5…4), `u_p2` flow speed (0…1).
    static let inkFlow = """
    \(includes)
    \(common)

    void main() {
        vec2 pixel = lw_pixel();
        vec2 p = pixel / max(min(u_resolution.x, u_resolution.y), 1.0) * max(u_p1, 0.1) + u_seed.zw;
        int octaves = u_level > 0.5 ? 3 : 5;
        float t = u_time * (0.02 + 0.2 * u_p2);
        vec2 q = vec2(vc_fbm(p + vec2(0.0, t), octaves, 2.0, 0.5),
                      vc_fbm(p + vec2(5.2, 1.3) - vec2(t, 0.0), octaves, 2.0, 0.5));
        float n = vc_fbm(p + 2.0 * u_p0 * q, octaves, 2.0, 0.5);
        float v = clamp(0.5 + 0.9 * n, 0.0, 1.0);
        vec3 rgb = vc_palette(v);
        float vein = 1.0 - smoothstep(0.0, 0.035, abs(n - 0.1));
        lw_write(mix(rgb, vc_palette(0.0), 0.55 * vein));
    }
    """

    /// Soft cells: `u_p0` cells along the short edge (4…40), `u_p1` edge softness (0…1).
    static let softCells = """
    \(includes)
    \(common)

    void main() {
        vec2 pixel = lw_pixel();
        float cells = u_level > 0.5 ? max(2.0, floor(u_p0 * 0.5 + 0.5)) : max(u_p0, 1.0);
        vec2 p = pixel / max(min(u_resolution.x, u_resolution.y), 1.0) * cells;
        vec2 g = floor(p);
        vec2 f = fract(p);
        float d1 = 8.0;
        float d2 = 8.0;
        float tone = 0.0;
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                vec2 o = vec2(float(i), float(j));
                vec2 h = vc_hash22(g + o + u_seed.xy);
                vec2 c = o + 0.5 + 0.38 * sin(u_time * 0.25 + 6.2831853 * h);
                float d = length(c - f);
                if (d < d1) {
                    d2 = d1;
                    d1 = d;
                    tone = vc_hash21(g + o + u_seed.zw);
                } else if (d < d2) {
                    d2 = d;
                }
            }
        }
        float edge = smoothstep(0.0, mix(0.03, 0.4, clamp(u_p1, 0.0, 1.0)), d2 - d1);
        float core = 1.0 - smoothstep(0.0, 0.6, d1);
        vec3 fill = vc_palette(0.3 + 0.6 * tone + 0.1 * core);
        float rim = vc_smoothUnion(d1, d2, 0.2);
        lw_write(mix(vc_palette(0.04 + 0.05 * rim), fill, edge));
    }
    """

    /// Ripple dunes: `u_p0` layers (2…7), `u_p1` amplitude (0.05…0.5), `u_p2` wavelength (0.2…2).
    static let rippleDunes = """
    \(includes)
    \(common)

    void main() {
        vec2 pixel = lw_pixel();
        float aspect = u_resolution.x / max(u_resolution.y, 1.0);
        float x = pixel.x / max(u_resolution.y, 1.0);
        float y = pixel.y / max(u_resolution.y, 1.0);
        float layers = clamp(floor(u_p0 + 0.5), 2.0, 7.0);
        if (u_level > 0.5) { layers = max(2.0, floor(layers * 0.5 + 0.5)); }
        int octaves = u_level > 0.5 ? 1 : 3;
        vec3 rgb = vc_palette(0.75 + 0.25 * y);
        float sun = vc_sdCircle(vec2(x, y) - vec2(aspect * (0.3 + 0.4 * fract(u_seed.x * 0.37)), 0.82), 0.07);
        rgb = mix(rgb, vc_palette(1.0), 1.0 - smoothstep(0.0, 0.05, sun));
        float wavelength = max(u_p2, 0.05);
        for (int i = 0; i < 7; i++) {
            if (float(i) >= layers) { break; }
            float k = float(i) / max(layers - 1.0, 1.0);
            float ph = u_seed.y + float(i) * 1.7;
            float speed = 0.04 * (1.0 + k);
            float wave = sin(x / wavelength * 6.2831853 + ph + u_time * speed);
            float grain = vc_fbm(vec2(x * 3.0 + ph, float(i) * 3.1 + u_time * 0.01), octaves, 2.0, 0.5);
            float ridge = 0.72 - 0.58 * k + u_p1 * 0.3 * (0.75 * wave + 0.25 * grain);
            if (y < ridge) {
                float depth = smoothstep(0.0, 0.12, ridge - y);
                vec3 tone = vc_palette(0.7 - 0.62 * k);
                rgb = mix(vc_palette(min(0.98, 0.85 - 0.55 * k)), tone, depth);
            }
        }
        lw_write(rgb);
    }
    """

    /// The fragment of scene `index` (clamped to 0–3): GLSL ES 3.00 (the program adds the version line).
    static func fragment(scene index: Int) -> String {
        switch clamped(index) {
        case 1: return inkFlow
        case 2: return softCells
        case 3: return rippleDunes
        default: return auroraBands
        }
    }

    /// The fragment's name in diagnostics for scene `index` (clamped): `wallpaper-<id>.frag`.
    static func fragmentName(scene index: Int) -> String {
        "wallpaper-" + SceneCatalog.scenes[clamped(index)].id + ".frag"
    }

    /// `index` clamped to the catalog (0–3).
    static func clamped(_ index: Int) -> Int { min(max(index, 0), sceneCount - 1) }

    /// The `u_<name>` float uniforms of `parameters` (three values; a missing one is 0) at quality tier `tier`:
    /// `p0`, `p1`, `p2` and `level` (0 or 1).
    static func parameters(_ parameters: [Double], tier: Int) -> [String: Double] {
        func value(_ index: Int) -> Double {
            index < parameters.count && parameters[index].isFinite ? parameters[index] : 0
        }
        return ["p0": value(0), "p1": value(1), "p2": value(2), "level": tier > 0 ? 1 : 0]
    }

    /// The four colours of `preset` decoded to linear light, as `u_palette` receives them.
    static func palette(_ preset: ColorPreset) -> [SIMD3<Float>] {
        preset.colors.map { SIMD3(Float(srgbDecode($0.r)), Float(srgbDecode($0.g)), Float(srgbDecode($0.b))) }
    }

    /// The sRGB transfer function's decode of one encoded channel (0…1), as `vc_srgbDecode`.
    static func srgbDecode(_ encoded: Double) -> Double {
        let c = min(max(encoded, 0), 1)
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// Four offsets in 0…64 from `seed` (SplitMix64, deterministic across runs), as `u_seed` receives them.
    static func seedOffsets(seed: UInt64) -> SIMD4<Float> {
        var state = seed
        func next() -> Float {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Float(Double(z >> 11) / Double(1 << 53) * 64)
        }
        return SIMD4(next(), next(), next(), next())
    }

    /// A scene running scene `index`'s fragment with the VisualCore includes, preset 0, the default parameters at
    /// level-0, the offsets of seed 1 and the time fixed at 0.
    @MainActor
    static func makeScene(scene index: Int) -> FullScreenShaderScene {
        let clampedIndex = clamped(index)
        let made = FullScreenShaderScene(fragment: fragment(scene: clampedIndex),
                                         fragmentName: fragmentName(scene: clampedIndex),
                                         bundle: ShaderBundle(files: [:]))
        let definition = SceneCatalog.scenes[clampedIndex]
        made.palette = palette(definition.presets[0])
        made.parameters = parameters(definition.parameters.map(\.defaultValue), tier: 0)
        made.seedOffsets = seedOffsets(seed: 1)
        made.fixedTime = 0
        return made
    }
}

/// A scene's shader did not compile or link on this device: the session's setup fails with this message.
struct SceneShaderError: Error, CustomStringConvertible, Equatable {
    /// The scene's index (0–3).
    let scene: Int
    /// The first diagnostic, `file:line: message`.
    let message: String
    /// "The <name> shader failed: <message>".
    var description: String {
        "The \(SceneCatalog.scenes[SceneShaders.clamped(scene)].name) shader failed: \(message)"
    }
}
