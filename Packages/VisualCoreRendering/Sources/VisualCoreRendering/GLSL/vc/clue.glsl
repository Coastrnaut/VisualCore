// vc/clue.glsl — VisualCore GLSL library: non-colour clues (feature 210 (R02-F10) T-R02F10-005; FR-R02F10-007,
// FR-R02F10-013; research R6). The shape and pattern of a coded state drawn in a unit cell −1…1 (y up), the exact port of
// ClueReference (VisualCoreParameters/CodedState.swift): same constants, same formulas. Shapes: 0 circle, 1 square,
// 2 triangle, 3 diamond, 4 hexagon, 5 plus, 6 ring, 7 star. Patterns: 0 solid, 1 stripes, 2 dots, 3 crosshatch.
// The shape distances follow the exact 2D distance functions documented by Inigo Quilez (MIT licence).
#ifndef VC_CLUE_GLSL
#define VC_CLUE_GLSL
#include "vc/sdf.glsl"
float vc_clueTriangle(vec2 p0, float r) {
    float k = 1.7320508075688772;
    vec2 p = vec2(abs(p0.x) - r, p0.y + r / k);
    if (p.x + k * p.y > 0.0) { p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0; }
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}
float vc_clueHexagon(vec2 p0, float r) {
    vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
    vec2 p = abs(p0);
    p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
    p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
    return length(p) * sign(p.y);
}
float vc_clueStar5(vec2 p0, float r, float rf) {
    vec2 k1 = vec2(0.809016994375, -0.587785252292);
    vec2 k2 = vec2(-k1.x, k1.y);
    vec2 p = vec2(abs(p0.x), p0.y);
    p -= 2.0 * max(dot(k1, p), 0.0) * k1;
    p -= 2.0 * max(dot(k2, p), 0.0) * k2;
    p.x = abs(p.x);
    p.y -= r;
    vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
    float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
    return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}
// Signed distance to the edge of `shape` (negative inside), in cell units.
float vc_clueShape(vec2 p, int shape) {
    if (shape == 0) { return length(p) - 0.8; }
    if (shape == 1) { return vc_sdBox2(p, vec2(0.7, 0.7)); }
    if (shape == 2) { return vc_clueTriangle(p, 0.85); }
    if (shape == 3) { return (abs(p.x) + abs(p.y) - 0.9) / 1.4142135623730951; }
    if (shape == 4) { return vc_clueHexagon(p, 0.75); }
    if (shape == 5) { return min(vc_sdBox2(p, vec2(0.8, 0.25)), vc_sdBox2(p, vec2(0.25, 0.8))); }
    if (shape == 6) { return abs(length(p) - 0.6) - 0.2; }
    return vc_clueStar5(p, 0.9, 0.45);
}
// Distance to the ink of stripes of period 1 and half the period wide, in stripe units.
float vc_clueStripe(float u) { return abs(fract(u) - 0.5) - 0.25; }
// Signed distance to the edge of `pattern`'s ink (negative on ink), in cell units; solid is −1 everywhere.
float vc_cluePattern(vec2 p, int pattern) {
    float frequency = 3.0;
    float u = (p.x + p.y) / 1.4142135623730951 * frequency;
    float v = (p.x - p.y) / 1.4142135623730951 * frequency;
    if (pattern == 0) { return -1.0; }
    if (pattern == 1) { return vc_clueStripe(u) / frequency; }
    if (pattern == 2) {
        vec2 q = vec2(fract(p.x * frequency) - 0.5, fract(p.y * frequency) - 0.5);
        return (length(q) - 0.3) / frequency;
    }
    return min(vc_clueStripe(u), vc_clueStripe(v)) / frequency;
}
// Antialiased coverage of the clue (shape × pattern ink), 0…1; `aa` is the half width of the soft edge in cell units.
float vc_clueCoverage(vec2 p, int shape, int pattern, float aa) {
    float inside = 1.0 - smoothstep(-aa, aa, vc_clueShape(p, shape));
    float ink = 1.0 - smoothstep(-aa, aa, vc_cluePattern(p, pattern));
    return inside * ink;
}
// Antialiased coverage of the outline band of `shape`: a band of `width` cell units centred on the edge.
float vc_clueOutline(vec2 p, int shape, float width, float aa) {
    return 1.0 - smoothstep(-aa, aa, abs(vc_clueShape(p, shape)) - width / 2.0);
}
#endif
