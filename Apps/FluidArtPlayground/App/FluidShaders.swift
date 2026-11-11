// FluidShaders.swift — GLSL ES 3.00 fragments of the playground (feature 019 T-A02-110).
// Original work for VisualCore, Copyright (c) 2026 Coastrnaut, MIT License (repository LICENSE); no third-party code.
// Every fragment runs through VisualCore's FieldPass and receives `v_uv` from the full-screen vertex shader.

enum FluidShaders {
    /// Multiplies a field by `uFactor` = 1 / (1 + d·Δt). With `uEncoded` = 1, the RG channels hold signed velocity
    /// encoded as v / uRange · 0.5 + 0.5 (RGBA8 fallback): decode, scale, re-encode, so zero stays at 0.5.
    static let dissipate = """
    precision highp float;
    uniform sampler2D uField;
    uniform float uFactor;
    uniform int uEncoded;
    uniform float uRange;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec4 v = texture(uField, v_uv);
        if (uEncoded == 1) {
            vec2 s = (v.xy - 0.5) * 2.0 * uRange * uFactor;
            color = vec4(clamp(s / uRange * 0.5 + 0.5, 0.0, 1.0), v.zw);
        } else {
            color = v * uFactor;
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
