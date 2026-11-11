// ripple.frag — touch-driven radial ripple over the content texture (Showcase scene 3, FR-F606).
precision mediump float;
#include "common.glsl"
in vec2 v_uv;
uniform sampler2D u_content;
uniform vec2 u_center;     // uv of the finger
uniform float u_strength;  // 0 = identity
uniform float u_time;
uniform float u_aspect;
out vec4 color;
void main() {
    vec2 d = v_uv - u_center;
    d.x *= u_aspect;
    float r = length(d);
    // Bounded: no displacement beyond r = 0.5 (aspect-corrected uv), so far pixels are untouched.
    float wave = sin(r * 60.0 - u_time * 8.0) * exp(-r * 5.0) * (1.0 - smoothstep(0.35, 0.5, r)) * u_strength;
    vec2 dir = r > 0.0001 ? d / r : vec2(0.0);
    dir.x /= u_aspect;
    color = texture(u_content, clamp(v_uv + dir * wave * 0.035, 0.0, 1.0));
}
