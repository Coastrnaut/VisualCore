// vc/color.glsl — VisualCore GLSL library: exact sRGB transfer functions (feature 012; docs/rendering/color-space.md).
#ifndef VC_COLOR_GLSL
#define VC_COLOR_GLSL
vec3 vc_srgbEncode(vec3 linear) {
    vec3 c = clamp(linear, 0.0, 1.0);
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
vec3 vc_srgbDecode(vec3 encoded) {
    vec3 c = clamp(encoded, 0.0, 1.0);
    return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
#endif
