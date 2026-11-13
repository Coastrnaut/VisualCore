// FractalShaders.swift — the escape-time fragment shader (feature 027 T-A03-203; FR-A03-201; research R3). Runs in
// VisualCore's FullScreenShaderScene (u_time, u_resolution, u_palette[8], u_paletteCount, u_<name> floats). The
// iteration matches FractalMath (the CPU reference): z ← z² + c, escape when |z|² > R² after step n, smooth value
// n + 1 − log2(log|zₙ|). The loop is bounded at 10,000 with an early break at u_cap (GLSL ES 3.00). Coordinates are
// float32 — the precision limit the app enforces through VisualCoreMath.PrecisionAdvisor.
enum FractalShaders {
    static let fragmentName = "fractal.frag"

    static let fragment = """
    precision highp float;
    #include "vc/palette.glsl"
    #include "vc/color.glsl"
    in vec2 v_uv;
    uniform float u_time;
    uniform vec2 u_resolution;
    uniform float u_centerX;
    uniform float u_centerY;
    uniform float u_step;
    uniform float u_mode;
    uniform float u_seedX;
    uniform float u_seedY;
    uniform float u_cap;
    uniform float u_radius;
    uniform float u_rate;
    out vec4 color;
    void main() {
        vec2 p = vec2(u_centerX, u_centerY) + (gl_FragCoord.xy - 0.5 * u_resolution) * u_step;
        bool julia = u_mode > 0.5;
        vec2 z = julia ? p : vec2(0.0);
        vec2 c = julia ? vec2(u_seedX, u_seedY) : p;
        int cap = int(u_cap + 0.5);
        float r2 = u_radius * u_radius;
        int n = 0;
        float m2 = 0.0;
        bool escaped = false;
        for (int i = 1; i <= 10000; i++) {
            if (i > cap) break;
            z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
            m2 = dot(z, z);
            if (m2 > r2) { n = i; escaped = true; break; }
        }
        if (!escaped) { color = vec4(0.0, 0.0, 0.0, 1.0); return; }
        float smoothValue = float(n) + 1.0 - log2(0.5 * log(m2));
        float t = fract(smoothValue * 0.05 + u_time * u_rate);
        color = vec4(vc_srgbEncode(vc_palette(t)), 1.0);
    }
    """
}
