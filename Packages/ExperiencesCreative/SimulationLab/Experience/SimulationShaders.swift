// SimulationShaders — feature 118 (A16-P02) T-A16-202 (FR-A16-201, FR-A16-204; clarification Q3; contracts/gpu.md);
// feature 119 (A16-P03) T-A16-303 (FR-A16-301, FR-A16-302; clarification Q1; contracts/gpu.md) added the two float
// displays. The GLSL ES 3.00 fragments of Simulation Lab's display and automaton passes, all run through VisualCore's
// `FieldPass` with the full-screen vertex shader. The Gray-Scott step lives in `GrayScottGPU.swift` and the wave step
// in `WaveGPU.swift` (one writer per file).
//
// - `display` (moved unchanged from `SimulationPresenter`, feature 117): the colour-mapped CPU field in a centred
//   square with crisp cells, the background around it.
// - `automatonDisplay`: the same square and cell lookup over the GPU automaton field, alive (red ≥ 0.5) in `uAlive`
//   and dead in `uDead`, so the automaton is drawn from the GPU field in the palette's exact colours.
// - `automatonStep`: one generation of an outer-totalistic rule on the Moore neighbourhood. The field is RGBA8, alive
//   = red 255 and dead = 0, read with `texelFetch` and thresholded at 0.5; neighbours wrap by index modulo the grid
//   size (`(cell + offset + n) % n`), so the registry's CLAMP_TO_EDGE sampling is never relied on. The birth and
//   survival sets arrive as two 9-bit integer masks (`uBirth`, `uSurvival`: bit k set when a neighbour count of k is
//   in the set); a live cell with n neighbours stays alive when bit n of `uSurvival` is set, a dead one is born when
//   bit n of `uBirth` is set. The result is written as exact 0 or 1 in red, 0 in green and blue, 1 in alpha.
// - `reactionDisplay`: the same square and cell lookup over the RGBA16F Gray-Scott field, coloured like
//   `SimulationPalette.reactionColor(v:)` from the inhibitor v in green: t = clamp(v / `uScale`, 0, 1) (NaN counts as
//   0), mixed from `uStop0` to `uStop1` for t ≤ 0.5 and from `uStop1` to `uStop2` above, each channel rounded to the
//   nearest byte (floor(c · 255 + 0.5) / 255).
// - `waveDisplay`: the same over the RGBA16F wave field, coloured like `SimulationPalette.waveColor(_:)` from the height
//   in red: h = clamp(height, −1, 1) (NaN counts as 0), mixed from `uZero` toward `uPositive` for h ≥ 0 and toward
//   `uNegative` for h < 0, rounded to bytes the same way. The stops arrive as `vec4` (`FieldUniform` has no `vec3`),
//   RGB floats 0…1 (byte / 255) with alpha ignored.
// Original work for VisualCore, Copyright (c) 2026 Coastrnaut, MIT License (repository LICENSE); no third-party code.

/// The fragment programs of Simulation Lab.
enum SimulationShaders {
    /// The display program: the grid in a centred square with crisp cells, the background around it.
    static let display = """
    precision highp float;
    uniform highp sampler2D uField;
    uniform vec2 uOrigin;
    uniform float uSide;
    uniform int uGrid;
    uniform vec4 uBackground;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec2 p = (gl_FragCoord.xy - uOrigin) / uSide;
        if (p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) {
            color = uBackground;
            return;
        }
        ivec2 cell = clamp(ivec2(floor(p * float(uGrid))), ivec2(0), ivec2(uGrid - 1));
        color = vec4(texelFetch(uField, cell, 0).rgb, 1.0);
    }
    """

    /// The automaton display program: the GPU field in the same centred square, alive cells (red ≥ 0.5) in
    /// `uAlive`, dead cells in `uDead`, the background around it.
    static let automatonDisplay = """
    precision highp float;
    uniform highp sampler2D uField;
    uniform vec2 uOrigin;
    uniform float uSide;
    uniform int uGrid;
    uniform vec4 uBackground;
    uniform vec4 uAlive;
    uniform vec4 uDead;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        vec2 p = (gl_FragCoord.xy - uOrigin) / uSide;
        if (p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) {
            color = uBackground;
            return;
        }
        ivec2 cell = clamp(ivec2(floor(p * float(uGrid))), ivec2(0), ivec2(uGrid - 1));
        color = texelFetch(uField, cell, 0).r >= 0.5 ? uAlive : uDead;
    }
    """

    /// The automaton step program: one generation with the rule as two 9-bit masks and wrap by index modulo.
    static let automatonStep = """
    precision highp float;
    precision highp int;
    uniform highp sampler2D uField;
    uniform int uGrid;
    uniform int uBirth;
    uniform int uSurvival;
    out vec4 color;
    int aliveAt(ivec2 cell) {
        return texelFetch(uField, (cell + ivec2(uGrid)) % uGrid, 0).r >= 0.5 ? 1 : 0;
    }
    void main() {
        ivec2 cell = ivec2(gl_FragCoord.xy);
        int n = 0;
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                if (dx != 0 || dy != 0) {
                    n += aliveAt(cell + ivec2(dx, dy));
                }
            }
        }
        int mask = aliveAt(cell) == 1 ? uSurvival : uBirth;
        float next = ((mask >> n) & 1) == 1 ? 1.0 : 0.0;
        color = vec4(next, 0.0, 0.0, 1.0);
    }
    """

    /// The reaction-diffusion display program: the RGBA16F field in the same centred square, coloured from v (green)
    /// through `uStop0`, `uStop1` and `uStop2` at t = 0, 0.5 and 1 with t = clamp(v / `uScale`, 0, 1), the background
    /// around it.
    static let reactionDisplay = """
    precision highp float;
    uniform highp sampler2D uField;
    uniform vec2 uOrigin;
    uniform float uSide;
    uniform int uGrid;
    uniform vec4 uBackground;
    uniform float uScale;
    uniform vec4 uStop0;
    uniform vec4 uStop1;
    uniform vec4 uStop2;
    in vec2 v_uv;
    out vec4 color;
    vec3 toBytes(vec3 c) {
        return floor(c * 255.0 + 0.5) / 255.0;
    }
    void main() {
        vec2 p = (gl_FragCoord.xy - uOrigin) / uSide;
        if (p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) {
            color = uBackground;
            return;
        }
        ivec2 cell = clamp(ivec2(floor(p * float(uGrid))), ivec2(0), ivec2(uGrid - 1));
        float v = texelFetch(uField, cell, 0).g;
        if (v != v) {
            v = 0.0;
        }
        float t = clamp(v / uScale, 0.0, 1.0);
        vec3 rgb = t <= 0.5 ? mix(uStop0.rgb, uStop1.rgb, t * 2.0) : mix(uStop1.rgb, uStop2.rgb, (t - 0.5) * 2.0);
        color = vec4(toBytes(rgb), 1.0);
    }
    """

    /// The wave display program: the RGBA16F field in the same centred square, coloured from the height (red),
    /// clamped to −1…1, from `uZero` toward `uPositive` (h ≥ 0) or `uNegative` (h < 0), the background around it.
    static let waveDisplay = """
    precision highp float;
    uniform highp sampler2D uField;
    uniform vec2 uOrigin;
    uniform float uSide;
    uniform int uGrid;
    uniform vec4 uBackground;
    uniform vec4 uZero;
    uniform vec4 uPositive;
    uniform vec4 uNegative;
    in vec2 v_uv;
    out vec4 color;
    vec3 toBytes(vec3 c) {
        return floor(c * 255.0 + 0.5) / 255.0;
    }
    void main() {
        vec2 p = (gl_FragCoord.xy - uOrigin) / uSide;
        if (p.x < 0.0 || p.y < 0.0 || p.x >= 1.0 || p.y >= 1.0) {
            color = uBackground;
            return;
        }
        ivec2 cell = clamp(ivec2(floor(p * float(uGrid))), ivec2(0), ivec2(uGrid - 1));
        float h = texelFetch(uField, cell, 0).r;
        if (h != h) {
            h = 0.0;
        }
        h = clamp(h, -1.0, 1.0);
        vec3 rgb = h >= 0.0 ? mix(uZero.rgb, uPositive.rgb, h) : mix(uZero.rgb, uNegative.rgb, -h);
        color = vec4(toBytes(rgb), 1.0);
    }
    """
}
