// vc/noise.glsl — VisualCore GLSL library: value noise, gradient noise and fractal Brownian motion (feature 012).
#ifndef VC_NOISE_GLSL
#define VC_NOISE_GLSL
#include "vc/hash.glsl"
// Value noise in [0, 1].
float vc_valueNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = vc_hash21(i), b = vc_hash21(i + vec2(1.0, 0.0));
    float c = vc_hash21(i + vec2(0.0, 1.0)), d = vc_hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
// Gradient noise in about [-1, 1].
float vc_gradientNoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    vec2 ga = vc_hash22(i) * 2.0 - 1.0, gb = vc_hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
    vec2 gc = vc_hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0, gd = vc_hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0;
    float a = dot(ga, f), b = dot(gb, f - vec2(1.0, 0.0)), c = dot(gc, f - vec2(0.0, 1.0)), d = dot(gd, f - vec2(1.0, 1.0));
    return 1.4142 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
// Fractal Brownian motion of gradient noise, 1–8 octaves, in about [-1, 1].
float vc_fbm(vec2 p, int octaves, float lacunarity, float gain) {
    float sum = 0.0, amp = 0.5, norm = 0.0;
    for (int i = 0; i < 8; i++) {
        if (i >= octaves) break;
        sum += amp * vc_gradientNoise(p);
        norm += amp;
        p *= lacunarity;
        amp *= gain;
    }
    return norm > 0.0 ? sum / norm : 0.0;
}
#endif
