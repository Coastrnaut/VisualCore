// vc/sdf.glsl — VisualCore GLSL library: signed distance functions and smooth operators (feature 012); 2D distance
// helpers and the dihedral fold matching PointGroup.dihedral(n).fold (feature 041, FR-A05-220).
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
float vc_sdCircle(vec2 p, float r) { return length(p) - r; }
float vc_sdBox2(vec2 p, vec2 b) { vec2 q = abs(p) - b; return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0); }
float vc_sdSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}
// Same steps as PointGroup.dihedral(n).fold: reduce the angle into the 2π/n wedge, mirror above π/n, keep the radius.
vec2 vc_foldDihedral(vec2 p, float n) {
    float r = length(p);
    if (r == 0.0) { return vec2(0.0); }
    float theta = atan(p.y, p.x);
    float wedge = 6.283185307179586 / n;
    float t = theta - floor(theta / wedge) * wedge;
    if (t < 0.0) { t = 0.0; }
    if (t >= wedge) { t = 0.0; }
    if (t > wedge * 0.5) { t = wedge - t; }
    return r * vec2(cos(t), sin(t));
}
#endif
