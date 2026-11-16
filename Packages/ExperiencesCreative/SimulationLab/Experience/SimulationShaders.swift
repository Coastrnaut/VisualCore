// SimulationShaders — feature 118 (A16-P02) T-A16-202 (FR-A16-201, FR-A16-204; clarification Q3; contracts/gpu.md).
// The GLSL ES 3.00 fragments of Simulation Lab's display and automaton passes, all run through VisualCore's
// `FieldPass` with the full-screen vertex shader. The Gray-Scott step of the Phase 02 fixture lives in
// `GrayScottGPU.swift` (one writer per file).
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
}
