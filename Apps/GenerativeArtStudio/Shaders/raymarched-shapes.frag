// raymarched-shapes.frag — Generative Art Studio family "Raymarched Shapes": smooth-blended SDF forms, lit and shaded.
precision highp float;
#include "vc/sdf.glsl"
#include "vc/palette.glsl"
#include "vc/color.glsl"
in vec2 v_uv;
uniform float u_time;
uniform vec2 u_resolution;
uniform vec4 u_seed;
uniform float u_blend;
uniform float u_rotation;
uniform float u_zoom;
uniform float u_glow;
out vec4 color;

float scene(vec3 p) {
    float a = u_time * u_rotation + u_seed.x * 6.2831;
    p.xz = vc_rotate(a) * p.xz;
    p.xy = vc_rotate(a * 0.6 + u_seed.y * 6.2831) * p.xy;
    float d = vc_sdSphere(p - vec3(0.55 * sin(a + u_seed.z * 6.0), 0.0, 0.0), 0.55);
    d = vc_smoothUnion(d, vc_sdSphere(p - vec3(-0.5, 0.35 * cos(a * 1.3), 0.2), 0.45), u_blend);
    d = vc_smoothUnion(d, vc_sdTorus(p - vec3(0.0, -0.3, 0.0), vec2(0.7, 0.16)), u_blend);
    d = vc_smoothUnion(d, vc_sdBox(p - vec3(0.0, 0.55, -0.2), vec3(0.22)), u_blend);
    return d;
}

vec3 normalAt(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(scene(p + e.xyy) - scene(p - e.xyy), scene(p + e.yxy) - scene(p - e.yxy), scene(p + e.yyx) - scene(p - e.yyx)));
}

void main() {
    // Normalize by the narrow axis so the composition fits portrait and landscape views alike.
    vec2 uv = (v_uv - 0.5) * u_resolution / min(u_resolution.x, u_resolution.y);
    vec3 ro = vec3(0.0, 0.0, 5.0 / u_zoom);
    vec3 rd = normalize(vec3(uv, -1.6));
    float t = 0.0, closest = 1e9;
    bool hit = false;
    for (int i = 0; i < 96; i++) {
        float d = scene(ro + rd * t);
        closest = min(closest, d);
        if (d < 0.001) { hit = true; break; }
        t += d;
        if (t > 8.0) break;
    }
    vec3 background = vc_palette(0.08 + 0.12 * v_uv.y);
    vec3 c = background;
    if (hit) {
        vec3 p = ro + rd * t, n = normalAt(p);
        vec3 light = normalize(vec3(0.6, 0.8, 0.5));
        float diffuse = max(dot(n, light), 0.0);
        float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
        float spec = pow(max(dot(reflect(-light, n), -rd), 0.0), 32.0);
        c = vc_palette(0.35 + 0.5 * diffuse) * (0.25 + 0.85 * diffuse) + fresnel * vc_palette(0.95) * 0.6 + spec * 0.5;
    }
    c += u_glow * vc_palette(0.9) * exp(-closest * 6.0) * 0.5;
    color = vec4(vc_srgbEncode(c), 1.0);
}
