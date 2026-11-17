// WaveFieldTheme — feature 133 (A18-P03) T-A18-304 (FR-A18-301, FR-A18-302; G-THEMES; clarification Q2). The third
// theme of Ambient Clock, "Wave Field": the sum of `u_count` plane sine waves (6 at level-0, 3 at level-1), each
// turned by the golden angle from the last, with rising spatial frequency and its own slow phase speed.
//
//   - Waves: s = mean over i < count of sin(dot(uv, (cos a_i, sin a_i)) × (3 + 1.7 i) + time × (0.25 + 0.06 i) + 1.3 i)
//     with a_i = 0.4 + 2.39996 i and uv = pixel ÷ height; the loop stops at the count (at most 16).
//   - Colour: x = 0.5 + 0.5 s + 0.5 (y − 0.5), clamped to 0…1, through `vca_ramp`, so the four palette colours appear
//     as slow bands; then the centre is quietened and the result sRGB-encoded (`ThemeShaders`).
import AmbientClockCore
import Foundation

/// The "Wave Field" theme's fragment (see the file header).
enum WaveFieldTheme {
    /// The theme's index in `ThemeCatalog.themes`.
    static let index = 2
    /// The theme's id.
    static var id: String { ThemeCatalog.themes[index].id }

    /// GLSL ES 3.00 (the program adds the version line), with the VisualCore include `vc/color.glsl` and the shared
    /// `ThemeShaders.common`.
    static let fragment = """
    precision highp float;
    #include "vc/color.glsl"
    \(ThemeShaders.common)

    void main() {
        vec2 pixel = vca_pixel();
        float height = max(u_resolution.y, 1.0);
        vec2 uv = pixel / height;
        int waves = clamp(int(u_count + 0.5), 1, 16);
        float s = 0.0;
        for (int i = 0; i < 16; i++) {
            if (i >= waves) { break; }
            float fi = float(i);
            float angle = 0.4 + 2.3999632 * fi;
            vec2 direction = vec2(cos(angle), sin(angle));
            s += sin(dot(uv, direction) * (3.0 + 1.7 * fi) + u_time * (0.25 + 0.06 * fi) + 1.3 * fi);
        }
        s /= float(waves);
        float y = pixel.y / height;
        vec3 rgb = vca_ramp(0.5 + 0.5 * s + 0.5 * (y - 0.5));
        vca_write(vca_quietCentre(rgb, pixel));
    }
    """
}
