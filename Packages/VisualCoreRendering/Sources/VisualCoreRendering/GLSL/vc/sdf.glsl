// vc/sdf.glsl — VisualCore GLSL library: signed distance functions and smooth operators (feature 012).
#ifndef VC_SDF_GLSL
#define VC_SDF_GLSL
float vc_sdSphere(vec3 p, float r) { return length(p) - r; }
float vc_sdBox(vec3 p, vec3 b) { vec3 q = abs(p) - b; return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0); }
float vc_sdTorus(vec3 p, vec2 t) { vec2 q = vec2(length(p.xz) - t.x, p.y); return length(q) - t.y; }
float vc_smoothUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}
mat2 vc_rotate(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }
#endif
