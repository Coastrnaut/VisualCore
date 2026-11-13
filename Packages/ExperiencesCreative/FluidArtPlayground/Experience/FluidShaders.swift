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
    uniform float uDyeMax;
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
                color = vec4(clamp(base.xy + uValue.xy * w, -uRange, uRange), base.zw);
            }
        } else {
            color = vec4(clamp(base.rgb + uValue.rgb * w, 0.0, uDyeMax), base.a);
        }
    }
    """

    // Shared by the solver passes (feature 021; spec 021 clarifications 1–3). Same arithmetic order as FluidSolver.
    // uEnc*: 1 when the field is 8-bit encoded (zero at uCenter); ranges in cells/s (velocity), ×2 (divergence),
    // ×4 (pressure). Neighbors outside the grid are never fetched: velocity takes the center cell (normal component
    // negated with walls) and scalars take the center value.
    static let solverCommon = """
    precision highp float;
    precision highp int;
    uniform int uWalls;
    uniform int uEncoded;
    uniform float uCenter;
    uniform float uRangeV;
    uniform float uRangeD;
    uniform float uRangeP;
    float dec(float u, float range) { return uEncoded == 1 ? (u - uCenter) * 2.0 * range : u; }
    float enc(float v, float range) { return uEncoded == 1 ? clamp(v / range * 0.5 + uCenter, 0.0, 1.0) : v; }
    float encZero() { return uEncoded == 1 ? uCenter : 0.0; }
    bool inside(ivec2 c, ivec2 size) { return c.x >= 0 && c.y >= 0 && c.x < size.x && c.y < size.y; }
    vec2 velAt(sampler2D f, ivec2 c, ivec2 center) {
        ivec2 size = textureSize(f, 0);
        bool ok = inside(c, size);
        vec4 t = texelFetch(f, ok ? c : center, 0);
        vec2 v = vec2(dec(t.x, uRangeV), dec(t.y, uRangeV));
        if (!ok && uWalls == 1) {
            if (c.x < 0 || c.x >= size.x) { v.x = -v.x; }
            if (c.y < 0 || c.y >= size.y) { v.y = -v.y; }
        }
        return v;
    }
    float scalarAt(sampler2D f, ivec2 c, ivec2 center, float range) {
        ivec2 size = textureSize(f, 0);
        return dec(texelFetch(f, inside(c, size) ? c : center, 0).x, range);
    }
    in vec2 v_uv;
    out vec4 color;
    """

    /// `d = 0.5·((u_R − u_L) + (v_T − v_B))` into R; G, B = stored zero, A = 1.
    static let divergence = solverCommon + """
    uniform sampler2D uVelocity;
    void main() {
        ivec2 c = ivec2(gl_FragCoord.xy);
        vec2 l = velAt(uVelocity, c + ivec2(-1, 0), c);
        vec2 r = velAt(uVelocity, c + ivec2(1, 0), c);
        vec2 b = velAt(uVelocity, c + ivec2(0, -1), c);
        vec2 t = velAt(uVelocity, c + ivec2(0, 1), c);
        float d = 0.5 * ((r.x - l.x) + (t.y - b.y));
        color = vec4(enc(d, uRangeD), encZero(), encZero(), 1.0);
    }
    """

    /// Fills a field with stored zero (and A = 1): the pressure starts at 0 every step.
    static let fill = solverCommon + """
    void main() { color = vec4(encZero(), encZero(), encZero(), 1.0); }
    """

    /// One Jacobi step `p' = (p_L + p_R + p_B + p_T − d) · 0.25`; G, B, A kept.
    static let pressure = solverCommon + """
    uniform sampler2D uPressure;
    uniform sampler2D uDivergence;
    void main() {
        ivec2 c = ivec2(gl_FragCoord.xy);
        float pl = scalarAt(uPressure, c + ivec2(-1, 0), c, uRangeP);
        float pr = scalarAt(uPressure, c + ivec2(1, 0), c, uRangeP);
        float pb = scalarAt(uPressure, c + ivec2(0, -1), c, uRangeP);
        float pt = scalarAt(uPressure, c + ivec2(0, 1), c, uRangeP);
        float d = scalarAt(uDivergence, c, c, uRangeD);
        vec4 base = texelFetch(uPressure, c, 0);
        color = vec4(enc((pl + pr + pb + pt - d) * 0.25, uRangeP), base.yzw);
    }
    """

    /// Subtracts the pressure gradient; with walls, the normal component of edge cells becomes 0. B, A kept.
    static let gradient = solverCommon + """
    uniform sampler2D uVelocity;
    uniform sampler2D uPressure;
    void main() {
        ivec2 c = ivec2(gl_FragCoord.xy);
        ivec2 size = textureSize(uVelocity, 0);
        float pl = scalarAt(uPressure, c + ivec2(-1, 0), c, uRangeP);
        float pr = scalarAt(uPressure, c + ivec2(1, 0), c, uRangeP);
        float pb = scalarAt(uPressure, c + ivec2(0, -1), c, uRangeP);
        float pt = scalarAt(uPressure, c + ivec2(0, 1), c, uRangeP);
        vec2 v = velAt(uVelocity, c, c);
        float u = v.x - 0.5 * (pr - pl);
        float w = v.y - 0.5 * (pt - pb);
        if (uWalls == 1) {
            if (c.x == 0 || c.x == size.x - 1) { u = 0.0; }
            if (c.y == 0 || c.y == size.y - 1) { w = 0.0; }
        }
        vec4 base = texelFetch(uVelocity, c, 0);
        color = vec4(enc(u, uRangeV), enc(w, uRangeV), base.zw);
    }
    """

    /// One implicit viscosity step `x' = (x_L + x_R + x_B + x_T + α·b) / (4 + α)`; B, A kept.
    static let diffuse = solverCommon + """
    uniform sampler2D uX;
    uniform sampler2D uB;
    uniform float uAlpha;
    void main() {
        ivec2 c = ivec2(gl_FragCoord.xy);
        vec2 l = velAt(uX, c + ivec2(-1, 0), c);
        vec2 r = velAt(uX, c + ivec2(1, 0), c);
        vec2 b = velAt(uX, c + ivec2(0, -1), c);
        vec2 t = velAt(uX, c + ivec2(0, 1), c);
        vec2 bc = velAt(uB, c, c);
        vec2 n = (l + r + b + t + uAlpha * bc) / (4.0 + uAlpha);
        vec4 base = texelFetch(uX, c, 0);
        color = vec4(enc(n.x, uRangeV), enc(n.y, uRangeV), base.zw);
    }
    """

    /// Copies a field (keeps the velocity before viscosity for the implicit solve).
    static let copy = """
    precision highp float;
    uniform sampler2D uField;
    in vec2 v_uv;
    out vec4 color;
    void main() { color = texelFetch(uField, ivec2(gl_FragCoord.xy), 0); }
    """

    /// Shows the dye in the active palette (feature 022; spec 022 clarification 1). `uMode` 0 ink:
    /// `paper·exp(−2·dye)`; 1 smoke: background toward 0.92 by `1 − exp(−1.5·luma)`; 2 glow: clamped dye on black
    /// (the bloom is VisualCore's effect graph). Matches FluidPalette.displayColor.
    static let display = """
    precision highp float;
    uniform sampler2D uDye;
    uniform int uMode;
    uniform vec4 uBackground;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec3 d = max(texture(uDye, v_uv).rgb, vec3(0.0));
        vec3 c;
        if (uMode == 0) {
            c = uBackground.rgb * exp(-2.0 * d);
        } else if (uMode == 1) {
            float l = 0.2126 * d.r + 0.7152 * d.g + 0.0722 * d.b;
            c = uBackground.rgb + (vec3(0.92) - uBackground.rgb) * (1.0 - exp(-1.5 * l));
        } else {
            c = min(d, vec3(1.0));
        }
        color = vec4(c, 1.0);
    }
    """
}
