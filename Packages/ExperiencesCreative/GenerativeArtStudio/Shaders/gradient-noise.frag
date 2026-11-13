// gradient-noise.frag — Generative Art Studio family "Gradient Noise": domain-warped fBm through the palette.
precision highp float;
#include "vc/noise.glsl"
#include "vc/palette.glsl"
#include "vc/color.glsl"
in vec2 v_uv;
uniform float u_time;
uniform vec2 u_resolution;
uniform vec4 u_seed;
uniform float u_scale;
uniform float u_octaves;
uniform float u_warp;
uniform float u_speed;
uniform float u_contrast;
out vec4 color;
void main() {
    vec2 aspect = vec2(u_resolution.x / u_resolution.y, 1.0);
    vec2 p = (v_uv - 0.5) * aspect * u_scale + u_seed.xy * 97.0;
    float t = u_time * u_speed;
    int octaves = int(u_octaves + 0.5);
    vec2 q = vec2(vc_fbm(p + vec2(0.0, t), octaves, 2.0, 0.5), vc_fbm(p + vec2(5.2, 1.3) - vec2(t, 0.0), octaves, 2.0, 0.5));
    float n = vc_fbm(p + u_warp * 2.0 * q, octaves, 2.0, 0.5);
    float v = clamp(0.5 + 0.8 * n * u_contrast, 0.0, 1.0);
    color = vec4(vc_srgbEncode(vc_palette(v)), 1.0);
}
