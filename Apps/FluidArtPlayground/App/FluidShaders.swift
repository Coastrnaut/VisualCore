// FluidShaders.swift — GLSL ES 3.00 fragments of the playground (feature 019 T-A02-110).
// Original work for VisualCore, Copyright (c) 2026 Coastrnaut, MIT License (repository LICENSE); no third-party code.
// Every fragment runs through VisualCore's FieldPass and receives `v_uv` from the full-screen vertex shader.

enum FluidShaders {
    /// Multiplies a field by `uFactor` = 1 / (1 + d·Δt). Phase 01's dissipation pass, which the scene no longer
    /// uses since feature 020 folded dissipation into `advect` (kept for the guard test and as a reference). With `uEncoded` = 1, the RG channels hold signed velocity
    /// encoded as v / uRange · 0.5 + uCenter (RGBA8 fallback, uCenter = 128/255): decode, scale, re-encode, so zero stays
    /// exactly zero.
    static let dissipate = """
    precision highp float;
    uniform sampler2D uField;
    uniform float uFactor;
    uniform int uEncoded;
    uniform float uRange;
    uniform float uCenter;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec4 v = texture(uField, v_uv);
        if (uEncoded == 1) {
            vec2 s = (v.xy - uCenter) * 2.0 * uRange * uFactor;
            color = vec4(clamp(s / uRange * 0.5 + uCenter, 0.0, 1.0), v.zw);
        } else {
            color = v * uFactor;
        }
    }
    """

    /// Semi-Lagrangian advection (feature 020; spec clarifications 1 and 5; research R1): each cell samples
    /// `uSource` at `gl_FragCoord − uDt·v` with VisualCore's exact `vc_fieldBilinear` (clamp-to-edge), where `v` is
    /// the cell's own velocity in cells per second (decoded with `uCenter`/`uRange` in 8-bit storage), and multiplies
    /// by the dissipation factor. Encoded velocity sources are decoded, scaled and re-encoded. It matches
    /// `Advection.advect` (Core) operation for operation.
    static let advect = """
    precision highp float;
    #include "vc/field.glsl"
    uniform sampler2D uVelocity;
    uniform sampler2D uSource;
    uniform float uDt;
    uniform float uFactor;
    uniform int uEncodedVelocity;
    uniform int uSourceIsVelocity;
    uniform float uRange;
    uniform float uCenter;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec4 vel = texelFetch(uVelocity, ivec2(gl_FragCoord.xy), 0);
        vec2 v = uEncodedVelocity == 1 ? (vel.xy - uCenter) * 2.0 * uRange : vel.xy;
        vec2 src = gl_FragCoord.xy - uDt * v;
        vec4 s = vc_fieldBilinear(uSource, src);
        if (uSourceIsVelocity == 1 && uEncodedVelocity == 1) {
            vec2 sv = (s.xy - uCenter) * 2.0 * uRange * uFactor;
            color = vec4(clamp(sv / uRange * 0.5 + uCenter, 0.0, 1.0), s.zw);
        } else {
            color = s * uFactor;
        }
    }
    """

    /// Adds one Gaussian splat `exp(−d²/r²)` (d, r in cells; cell centers from `gl_FragCoord`). With `uVelocity` = 1
    /// it adds `uValue.xy` to the RG velocity (decoded, added and re-encoded with clamping when `uEncoded` = 1);
    /// otherwise it adds `uValue.rgb` to the dye RGB and keeps alpha (feature 020; spec clarification 2).
    static let splat = """
    precision highp float;
    uniform sampler2D uField;
    uniform vec2 uPoint;
    uniform float uRadius;
    uniform vec4 uValue;
    uniform int uEncoded;
    uniform float uRange;
    uniform float uCenter;
    uniform int uVelocity;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec4 base = texelFetch(uField, ivec2(gl_FragCoord.xy), 0);
        vec2 d = gl_FragCoord.xy - uPoint;
        float w = exp(-(d.x * d.x + d.y * d.y) / (uRadius * uRadius));
        if (uVelocity == 1) {
            if (uEncoded == 1) {
                vec2 v = (base.xy - uCenter) * 2.0 * uRange + uValue.xy * w;
                color = vec4(clamp(v / uRange * 0.5 + uCenter, 0.0, 1.0), base.zw);
            } else {
                color = vec4(base.xy + uValue.xy * w, base.zw);
            }
        } else {
            color = vec4(base.rgb + uValue.rgb * w, base.a);
        }
    }
    """

    /// Shows the dye over a near-black background.
    static let display = """
    precision highp float;
    uniform sampler2D uDye;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec3 dye = clamp(texture(uDye, v_uv).rgb, 0.0, 1.0);
        color = vec4(max(dye, vec3(0.02, 0.02, 0.04)), 1.0);
    }
    """
}
