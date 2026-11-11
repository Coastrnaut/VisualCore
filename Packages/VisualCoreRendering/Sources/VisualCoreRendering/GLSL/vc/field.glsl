// vc/field.glsl — VisualCore GLSL library: exact field sampling for GPU simulations (feature 020 T-A02-204;
// FR-A02-202; research R1). Hardware LINEAR filtering uses reduced sub-texel precision, so passes that must match a
// CPU reference (FieldGrid.sampleBilinear) fetch the four cells and weight them in highp float with the same formula.
#ifndef VC_FIELD_GLSL
#define VC_FIELD_GLSL
// The cell at integer index `cell`, with the index clamped to the field's edge.
vec4 vc_fieldTexel(sampler2D f, highp ivec2 cell) {
    highp ivec2 size = textureSize(f, 0);
    return texelFetch(f, clamp(cell, ivec2(0), size - 1), 0);
}
// Bilinear sample at a continuous cell coordinate (cell centers at i + 0.5), clamped to the edge:
// p = coord - 0.5, i0 = floor(p), t = p - i0, then a + (b - a) * t along x and then along y.
vec4 vc_fieldBilinear(sampler2D f, highp vec2 cellCoord) {
    highp vec2 size = vec2(textureSize(f, 0));
    highp vec2 p = clamp(cellCoord - 0.5, vec2(-1.0), size);
    highp vec2 fl = floor(p);
    highp vec2 t = p - fl;
    highp ivec2 i0 = ivec2(fl);
    vec4 a = vc_fieldTexel(f, i0);
    vec4 b = vc_fieldTexel(f, i0 + ivec2(1, 0));
    vec4 c = vc_fieldTexel(f, i0 + ivec2(0, 1));
    vec4 d = vc_fieldTexel(f, i0 + ivec2(1, 1));
    vec4 bottom = a + (b - a) * t.x;
    vec4 top = c + (d - c) * t.x;
    return bottom + (top - bottom) * t.y;
}
#endif
