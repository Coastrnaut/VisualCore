// vc/palette.glsl — VisualCore GLSL library: palette lookup (feature 012). FullScreenShaderScene binds u_palette (up to
// 8 linear-light stops) and u_paletteCount; vc_palette returns linear light — encode with vc_srgbEncode before output.
#ifndef VC_PALETTE_GLSL
#define VC_PALETTE_GLSL
uniform vec3 u_palette[8];
uniform int u_paletteCount;
vec3 vc_palette(float t) {
    int n = clamp(u_paletteCount, 1, 8);
    if (n == 1) return u_palette[0];
    float x = clamp(t, 0.0, 1.0) * float(n - 1);
    int i = min(int(floor(x)), n - 2);
    float f = x - float(i);
    vec3 a = u_palette[0], b = u_palette[1];
    for (int k = 0; k < 7; k++) {
        if (k == i) { a = u_palette[k]; b = u_palette[k + 1]; }
    }
    return mix(a, b, f);
}
#endif
