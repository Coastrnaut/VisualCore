// ParticleDriftTheme — feature 133 (A18-P03) T-A18-304 (FR-A18-301, FR-A18-302; G-THEMES; clarification Q2). The
// second theme of Ambient Clock, "Particle Drift": a field of hashed cells (`vc/hash.glsl`), `u_count` of them along
// the shorter side (48 at level-0, 24 at level-1), each holding one soft disc that wanders inside its cell while the
// whole field drifts slowly up and to the right.
//
//   - Background: `vca_ramp` along the height (bottom palette colour 0, top colour 3) with a slight slow sway.
//   - Cells: p = pixel ÷ shorter side × count + time × (0.11, 0.04); each cell's hash (`vc_hash22`, `vc_hash21`) gives
//     its disc's radius (0.08–0.25 of the cell), colour (palette 1–3), wandering phase and rate; the disc's centre
//     stays within 0.18 of the cell's middle, so a disc never crosses into its neighbour.
//   - Each disc is mixed over the background at most 0.9 (soft edge from 0.35 of its radius), then the centre is
//     quietened and the result sRGB-encoded (`ThemeShaders`).
import AmbientClockCore
import Foundation

/// The "Particle Drift" theme's fragment (see the file header).
enum ParticleDriftTheme {
    /// The theme's index in `ThemeCatalog.themes`.
    static let index = 1
    /// The theme's id.
    static var id: String { ThemeCatalog.themes[index].id }

    /// GLSL ES 3.00 (the program adds the version line), with the VisualCore includes `vc/hash.glsl` and
    /// `vc/color.glsl` and the shared `ThemeShaders.common`.
    static let fragment = """
    precision highp float;
    #include "vc/hash.glsl"
    #include "vc/color.glsl"
    \(ThemeShaders.common)

    void main() {
        vec2 pixel = vca_pixel();
        float side = max(min(u_resolution.x, u_resolution.y), 1.0);
        float y = pixel.y / max(u_resolution.y, 1.0);
        vec2 uv = pixel / side;
        vec3 rgb = vca_ramp(y * 1.1 - 0.05 + 0.05 * sin(u_time * 0.05 + uv.x * 3.0));
        float cells = clamp(floor(u_count + 0.5), 1.0, 256.0);
        vec2 p = uv * cells + vec2(0.11, 0.04) * u_time;
        vec2 cell = floor(p);
        vec2 f = fract(p);
        vec2 h = vc_hash22(cell);
        float phase = 6.2831853 * vc_hash21(cell + vec2(31.0, 17.0));
        vec2 centre = 0.5 + 0.18 * vec2(sin(u_time * (0.2 + 0.3 * h.x) + phase),
                                        cos(u_time * (0.17 + 0.3 * h.y) + phase));
        float radius = 0.08 + 0.17 * h.x;
        float disc = 1.0 - smoothstep(radius * 0.35, radius, length(f - centre));
        int tint = clamp(1 + int(h.y * 3.0), 1, 3);
        rgb = mix(rgb, u_palette[tint], disc * 0.9);
        vca_write(vca_quietCentre(rgb, pixel));
    }
    """
}
