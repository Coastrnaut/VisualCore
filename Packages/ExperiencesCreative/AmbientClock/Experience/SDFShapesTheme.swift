// SDFShapesTheme — feature 133 (A18-P03) T-A18-304 (FR-A18-301, FR-A18-302; G-THEMES; clarification Q2). The fourth
// theme of Ambient Clock, "SDF Shapes": `u_count` slowly rotating shapes (8 at level-0, 4 at level-1), alternately
// circles (`vc_sdCircle`) and rounded boxes (`vc_sdBox2` minus a corner radius), from `vc/sdf.glsl`, over a ramp.
//
//   - Space: uv = (pixel − resolution ÷ 2) ÷ shorter side, so the shorter side spans −0.5…0.5.
//   - Shape i (the loop stops at the count, at most 16): its place is hashed (`vc_hash22((i + 1, 7))`) within 0.8 of
//     the canvas and sways by 0.04; its size is 0.05–0.12 (`vc_hash11`); it turns at 0.08–0.12 radians per second of
//     uniform time, alternate shapes the other way (`vc_rotate`). The edge is antialiased over 1.5 pixel blocks.
//   - Colour: each shape is its palette colour 1 + (i mod 3) mixed at most 0.75 over the background ramp; then the
//     centre is quietened and the result sRGB-encoded (`ThemeShaders`).
import AmbientClockCore
import Foundation

/// The "SDF Shapes" theme's fragment (see the file header).
enum SDFShapesTheme {
    /// The theme's index in `ThemeCatalog.themes`.
    static let index = 3
    /// The theme's id.
    static var id: String { ThemeCatalog.themes[index].id }

    /// GLSL ES 3.00 (the program adds the version line), with the VisualCore includes `vc/hash.glsl`, `vc/sdf.glsl`
    /// and `vc/color.glsl` and the shared `ThemeShaders.common`.
    static let fragment = """
    precision highp float;
    #include "vc/hash.glsl"
    #include "vc/sdf.glsl"
    #include "vc/color.glsl"
    \(ThemeShaders.common)

    void main() {
        vec2 pixel = vca_pixel();
        float side = max(min(u_resolution.x, u_resolution.y), 1.0);
        vec2 uv = (pixel - 0.5 * u_resolution) / side;
        vec2 extent = 0.5 * u_resolution / side;
        float y = pixel.y / max(u_resolution.y, 1.0);
        vec3 rgb = vca_ramp(y * 1.1 - 0.05 + 0.05 * sin(u_time * 0.04));
        int shapes = clamp(int(u_count + 0.5), 1, 16);
        float aa = 1.5 * max(floor(u_block + 0.5), 1.0) / side;
        for (int i = 0; i < 16; i++) {
            if (i >= shapes) { break; }
            float fi = float(i);
            vec2 h = vc_hash22(vec2(fi + 1.0, 7.0));
            vec2 centre = (h * 2.0 - 1.0) * extent * 0.8
                + 0.04 * vec2(sin(u_time * 0.13 + 1.7 * fi), cos(u_time * 0.11 + 2.3 * fi));
            float size = 0.05 + 0.07 * vc_hash11(fi + 0.5);
            bool isCircle = mod(fi, 2.0) < 1.0;
            float spin = u_time * (0.08 + 0.04 * h.x) * (isCircle ? 1.0 : -1.0) + fi;
            vec2 q = vc_rotate(spin) * (uv - centre);
            float d = isCircle ? vc_sdCircle(q, size) : vc_sdBox2(q, vec2(size, size * 0.65)) - size * 0.25;
            float fill = 1.0 - smoothstep(-aa, aa, d);
            rgb = mix(rgb, u_palette[1 + int(mod(fi, 3.0))], fill * 0.75);
        }
        vca_write(vca_quietCentre(rgb, pixel));
    }
    """
}
