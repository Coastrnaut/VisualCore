// vc/sdfshape.glsl — VisualCore GLSL library: the constructive signed-distance primitives and operations that
// SDFShape.glslFunction(name:) emits (feature 211, R02-F11, T-R02F11-006; FR-R02F11-003; research R7). Each function
// reproduces the CPU formula of SDFShape.distance(at:) in float; formulas after Inigo Quilez, "3D distance functions"
// and "smooth minimum" (MIT). Includes vc/sdf.glsl (vc_sdBox); the library includes each file once.
#ifndef VC_SDFSHAPE_GLSL
#define VC_SDFSHAPE_GLSL
#include "vc/sdf.glsl"
// The half-space below the plane dot(n, p) = h (n of unit length; negative below).
float vc_sdPlane(vec3 p, vec3 n, float h) { return dot(n, p) - h; }
// A box with outer half extents b whose edges are rounded by r (r <= the smallest half extent).
float vc_sdRoundBox(vec3 p, vec3 b, float r) { return vc_sdBox(p, b - vec3(r)) - r; }
// The points within r of the segment from a to b.
float vc_sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * t) - r;
}
// Union (minimum).
float vc_opUnion(float a, float b) { return min(a, b); }
// Intersection (maximum).
float vc_opIntersect(float a, float b) { return max(a, b); }
// The first shape with the second removed: max(a, -b).
float vc_opSubtract(float a, float b) { return max(a, -b); }
// The polynomial smooth minimum of SDFShape.smoothMin: the plain minimum for k <= 0, never above it.
float vc_opSmoothUnion(float a, float b, float k) {
    if (k <= 0.0) { return min(a, b); }
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return b + (a - b) * h - k * h * (1.0 - h);
}
#endif
