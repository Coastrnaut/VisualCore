// particles-background.frag — Generative Art Studio family "Particles": dark palette gradient behind the fountain.
precision highp float;
#include "vc/noise.glsl"
#include "vc/palette.glsl"
#include "vc/color.glsl"
in vec2 v_uv;
uniform float u_time;
uniform vec4 u_seed;
out vec4 color;
void main() {
    float n = vc_valueNoise(v_uv * 3.0 + u_seed.zw * 50.0 + vec2(0.0, u_time * 0.02));
    vec3 c = vc_palette(0.04 + 0.16 * (1.0 - v_uv.y) + 0.05 * n) * (0.35 + 0.4 * v_uv.y);
    color = vec4(vc_srgbEncode(c), 1.0);
}
