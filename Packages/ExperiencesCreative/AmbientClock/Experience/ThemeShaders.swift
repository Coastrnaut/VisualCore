// ThemeShaders — feature 133 (A18-P03) T-A18-304 (FR-A18-301, FR-A18-302, FR-A18-306; G-THEMES; clarification Q2;
// research D3). The shared plumbing of the four ambient themes: one full-screen fragment each on VisualCore's
// `FullScreenShaderScene` over the GLSL library (`vc/`), with the same uniforms and helpers.
//
//   - Uniforms: `u_resolution` (pixels), `u_time` (the effective time, `NoiseGradientTheme.effectiveTime`, bound
//     through the scene's `fixedTime`), `u_count` (the theme's element count at the tier,
//     `ThemeCatalog.budget(theme:tier:)`: octaves, cells, waves or shapes), `u_block` (the pixel block edge,
//     `AmbientCore.pixelBlock(forTier:)`: one sample per block, 1 at level-0 and 2 at level-1) and `u_palette[4]` (the
//     theme's chosen palette in linear light, `palette(theme:palette:)`).
//   - Helpers: `vca_pixel()` (the centre of the fragment's block), `vca_ramp(x)` (the four palette colours blended in
//     order along 0…1, linear light), `vca_darkest()` (the palette colour of the lowest luminance),
//     `vca_quietCentre(rgb, pixel)` (holds the middle of the canvas, where the clock's text sits, towards the darkest
//     colour: weight 0.6 at the centre, fading to 0 at 0.45 of the shorter side) and `vca_write(rgb)` (sRGB-encodes
//     with `vc_srgbEncode`, as the noise gradient does).
//   - Colour rule: every theme draws only blends of its four dark palette colours (never black, never brighter than
//     its brightest colour) over a background ramp that runs through all four, so a frame's luma spread is the
//     palette's (at least 10 of 255, above `FrameChecks.minimumLumaSpread`), and the centre probe stays `dark` even
//     for the two palette colours above luma 40 (Storm's and Graphite's lightest) because of the quiet centre.
//   - Budgets: the loops of the wave field and the SDF shapes stop at `u_count` (at most 16); the particle drift has
//     `u_count` cells along the shorter side with one disc each; the noise gradient has `u_count` octaves. Each theme
//     is one full-screen draw.
import AmbientClockCore
import Foundation
import VisualCoreRendering

/// The shared fragment plumbing, uniforms and scene factory of the four ambient themes (see the file header).
enum ThemeShaders {
    /// The number of themes (`ThemeCatalog.themes`).
    static var themeCount: Int { ThemeCatalog.themes.count }

    /// The uniform declarations and helpers every theme fragment shares (after its `#include` lines). Needs
    /// `vc/color.glsl` for `vc_srgbEncode`.
    static let common = """
    uniform vec2 u_resolution;
    uniform float u_time;
    uniform float u_count;
    uniform float u_block;
    uniform vec3 u_palette[4];
    out vec4 color;

    vec2 vca_pixel() {
        float block = max(floor(u_block + 0.5), 1.0);
        return (floor(gl_FragCoord.xy / block) + 0.5) * block;
    }

    vec3 vca_ramp(float t) {
        float x = clamp(t, 0.0, 1.0) * 3.0;
        vec3 rgb = mix(u_palette[0], u_palette[1], clamp(x, 0.0, 1.0));
        rgb = mix(rgb, u_palette[2], clamp(x - 1.0, 0.0, 1.0));
        return mix(rgb, u_palette[3], clamp(x - 2.0, 0.0, 1.0));
    }

    vec3 vca_darkest() {
        const vec3 w = vec3(0.2126, 0.7152, 0.0722);
        vec3 d = u_palette[0];
        for (int i = 1; i < 4; i++) {
            if (dot(u_palette[i], w) < dot(d, w)) { d = u_palette[i]; }
        }
        return d;
    }

    vec3 vca_quietCentre(vec3 rgb, vec2 pixel) {
        float side = max(min(u_resolution.x, u_resolution.y), 1.0);
        float r = length((pixel - 0.5 * u_resolution) / side);
        return mix(rgb, vca_darkest(), 0.6 * (1.0 - smoothstep(0.1, 0.45, r)));
    }

    void vca_write(vec3 rgb) {
        color = vec4(vc_srgbEncode(clamp(rgb, 0.0, 1.0)), 1.0);
    }
    """

    /// The fragment that never compiles (the test-only seam `AmbientPresenter.failNextThemeCompile`).
    static let brokenFragment = """
    precision highp float;
    out vec4 color;
    void main() { color = vec4(undeclaredValue, 1.0); }
    """

    /// The fragment of theme `themeIndex` (clamped to 0–3): GLSL ES 3.00 (the program adds the version line).
    static func fragment(themeIndex: Int) -> String {
        switch clamped(themeIndex) {
        case 1: return ParticleDriftTheme.fragment
        case 2: return WaveFieldTheme.fragment
        case 3: return SDFShapesTheme.fragment
        default: return NoiseGradientTheme.fragment
        }
    }

    /// The fragment's name in diagnostics for theme `themeIndex` (clamped): `ambient-<id>.frag`.
    static func fragmentName(themeIndex: Int) -> String {
        "ambient-" + ThemeCatalog.themes[clamped(themeIndex)].id + ".frag"
    }

    /// `themeIndex` clamped to the catalog (0–3).
    static func clamped(_ themeIndex: Int) -> Int { min(max(themeIndex, 0), themeCount - 1) }

    /// The `u_<name>` float uniforms of theme `theme` at quality tier `tier`: `count` (the theme's budget) and
    /// `block` (the pixel block edge).
    static func parameters(theme: Int, tier: Int) -> [String: Double] {
        ["count": Double(ThemeCatalog.budget(theme: theme, tier: tier)),
         "block": Double(AmbientCore.pixelBlock(forTier: tier))]
    }

    /// The palette `palette` of theme `theme` (both clamped) in linear light, as `u_palette` receives it.
    static func palette(theme: Int, palette: Int) -> [SIMD3<Float>] {
        ThemeCatalog.palette(theme: theme, palette: palette).colors.map {
            SIMD3(Float(NoiseGradientTheme.srgbDecode($0.x)), Float(NoiseGradientTheme.srgbDecode($0.y)),
                  Float(NoiseGradientTheme.srgbDecode($0.z)))
        }
    }

    /// A scene running theme `themeIndex`'s fragment (or, with `broken`, ``brokenFragment``) with the VisualCore
    /// includes, its palette 0, the level-0 parameters and the time fixed at 0.
    @MainActor
    static func makeScene(themeIndex: Int, broken: Bool = false) -> FullScreenShaderScene {
        let index = clamped(themeIndex)
        let scene = FullScreenShaderScene(fragment: broken ? brokenFragment : fragment(themeIndex: index),
                                          fragmentName: fragmentName(themeIndex: index),
                                          bundle: ShaderBundle(files: [:]))
        scene.palette = palette(theme: index, palette: 0)
        scene.parameters = parameters(theme: index, tier: 0)
        scene.fixedTime = 0
        return scene
    }
}

/// A theme's shader did not compile or link on this device: the presenter keeps the previous theme and records this.
struct ThemeShaderError: Error, CustomStringConvertible, Equatable {
    /// The theme's index (0–3).
    let theme: Int
    /// The first diagnostic, `file:line: message`.
    let message: String
    /// "The <name> shader failed: <message>".
    var description: String {
        "The \(ThemeCatalog.themes[ThemeShaders.clamped(theme)].name) shader failed: \(message)"
    }
}
