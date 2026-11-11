// vc/hash.glsl — VisualCore GLSL library: integer hashes (feature 012). Include as #include "vc/hash.glsl".
#ifndef VC_HASH_GLSL
#define VC_HASH_GLSL
uint vc_pcg(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}
// Uniform hash of a float in [0, 1).
float vc_hash11(float p) { return float(vc_pcg(floatBitsToUint(p))) / 4294967296.0; }
// Uniform hash of a 2D point in [0, 1).
float vc_hash21(vec2 p) {
    uvec2 q = floatBitsToUint(p);
    return float(vc_pcg(q.x ^ vc_pcg(q.y))) / 4294967296.0;
}
// Two uniform hashes of a 2D point in [0, 1).
vec2 vc_hash22(vec2 p) {
    uvec2 q = floatBitsToUint(p);
    uint a = vc_pcg(q.x ^ vc_pcg(q.y));
    return vec2(float(a), float(vc_pcg(a))) / 4294967296.0;
}
#endif
