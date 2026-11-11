// common.glsl — shared helpers for the Showcase shaders (included with #include "common.glsl").
const float PI = 3.14159265;

// Full-screen triangle corner for gl_VertexID 0..2 (uv in 0..2, covers the viewport).
vec2 fullscreenCorner(int id) { return vec2(float((id << 1) & 2), float(id & 2)); }

// Smooth hue → RGB (sRGB-encoded output).
vec3 hue(float h) {
    vec3 k = vec3(1.0, 2.0 / 3.0, 1.0 / 3.0);
    return clamp(abs(fract(vec3(h) + k) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}
