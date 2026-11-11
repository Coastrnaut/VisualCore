// geometric-tiling.frag — Generative Art Studio family "Geometric Tiling": kaleidoscopic star tiles with crisp lines.
precision highp float;
#include "vc/hash.glsl"
#include "vc/palette.glsl"
#include "vc/color.glsl"
in vec2 v_uv;
uniform float u_time;
uniform vec2 u_resolution;
uniform vec4 u_seed;
uniform float u_cells;
uniform float u_symmetry;
uniform float u_lineWidth;
uniform float u_twist;
uniform float u_speed;
out vec4 color;
void main() {
    vec2 aspect = vec2(u_resolution.x / u_resolution.y, 1.0);
    vec2 p = (v_uv - 0.5) * aspect * u_cells;
    vec2 cell = floor(p);
    vec2 local = fract(p) - 0.5;
    float h = vc_hash21(cell + u_seed.xy * 131.0);
    float folds = floor(u_symmetry + 0.5);
    float sector = 6.2831853 / folds;
    float angle = atan(local.y, local.x) + u_twist * (h - 0.5) * 2.0 + u_time * u_speed * (h < 0.5 ? 1.0 : -1.0);
    angle = mod(angle, sector) - 0.5 * sector;
    float r = length(local);
    vec2 q = vec2(cos(angle), abs(sin(angle))) * r;
    float star = q.x * 0.9 + q.y * 1.8 - 0.32;
    float lines = smoothstep(u_lineWidth, u_lineWidth * 0.5, abs(star)) + smoothstep(u_lineWidth, u_lineWidth * 0.5, abs(r - 0.42));
    float fill = step(star, 0.0);
    vec3 base = vc_palette(fract(h + 0.13 * fill));
    vec3 ink = vc_palette(1.0 - h * 0.3);
    vec3 c = mix(base * (0.35 + 0.65 * fill), ink, clamp(lines, 0.0, 1.0));
    color = vec4(vc_srgbEncode(c), 1.0);
}
