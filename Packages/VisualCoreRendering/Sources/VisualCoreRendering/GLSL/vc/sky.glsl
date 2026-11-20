// vc/sky.glsl — VisualCore GLSL library: the analytic sky (feature 218 (R02-F18) T-R02F18-005; FR-R02F18-005, 006;
// SC-R02F18-004, 005; clarification Q4; research R5, R6). The port of SkyModel (VisualCoreScenes): the same
// expression in the same order, in float. With d the unit view direction, s the unit sun direction and e = d.y:
// day = e >= 0 ? mix(horizon, zenith, sqrt(e)) : mix(horizon, ground, smoothstep(0, 0.1, -e)); a dusk tint
// dusk * w * max(d.s, 0)^4 * (1 - max(e, 0)) with w = clamp(1 - |s.y| / 0.25, 0, 1); the day factor
// f = smoothstep(-0.15, 0.05, s.y) scales by mix(night, 1, f); for e >= -r the sun adds
// sunColour * f * (smoothstep(cos(r + 0.004), cos r, d.s) + g * max(d.s, 0)^k); the result is clamped to 0...1 (linear).
// sunShape = (r disc angular radius in radians, g glow strength, k glow exponent). Needs no other include.
#ifndef VC_SKY_GLSL
#define VC_SKY_GLSL
highp vec3 vc_sky(highp vec3 d, highp vec3 s, highp vec3 zenith, highp vec3 horizon, highp vec3 ground,
                  highp vec3 dusk, highp vec3 night, highp vec3 sunColour, highp vec3 sunShape) {
    d = normalize(d);
    s = normalize(s);
    highp float e = d.y;
    highp vec3 day;
    if (e >= 0.0) {
        day = mix(horizon, zenith, sqrt(e));
    } else {
        day = mix(horizon, ground, smoothstep(0.0, 0.1, -e));
    }
    highp float w = clamp(1.0 - abs(s.y) / 0.25, 0.0, 1.0);
    highp float ds = dot(d, s);
    highp float toward = max(ds, 0.0);
    highp float toward2 = toward * toward;
    highp vec3 c = day + dusk * (w * (toward2 * toward2) * (1.0 - max(e, 0.0)));
    highp float f = smoothstep(-0.15, 0.05, s.y);
    c = c * mix(night, vec3(1.0), f);
    highp float r = sunShape.x;
    if (e >= -r) {
        highp float disc = smoothstep(cos(r + 0.004), cos(r), ds);
        highp float glow = toward > 0.0 ? pow(toward, sunShape.z) : 0.0;
        c += sunColour * (f * (disc + sunShape.y * glow));
    }
    return clamp(c, 0.0, 1.0);
}
#endif
