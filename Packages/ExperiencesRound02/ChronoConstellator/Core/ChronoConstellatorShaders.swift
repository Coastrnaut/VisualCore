// ChronoConstellatorShaders — feature 353 (R02-G06-03) T-R02G0603-003 (FR-R02G0603-002, FR-R02G0603-007; clarification
// on Reduce Motion and Reduce Flashing). The two GLSL ES 3.00 programs of Chrono Constellator held as source text (data:
// the core issues no GL call), with the names of every uniform they declare, their vertex attributes, the constants the
// sources are built from and the CPU references of what they compute.
//
// Field program: the indigo night field with its faint grid, the silver loop tracks, the star nodes, the rose target
// rings and the amber collision marks, opaque and softly lit. `a_uv.x` selects the material (see `FieldMaterial`),
// `a_uv.y` is the vertex shade 0 ... 1. On the field material the fragment stage draws the grid procedurally: lines of
// width `gridLineWidth` cells at every cell boundary, the cell size given by `u_cell`, mixed from field toward grid.
// Lighting is an ambient term plus Lambert from `u_lightDir` on the generated normal (the field's normal is up).
//
// Glow program: the emissive history ribbons, the glowing star cores and the glow shells, drawn with blending. The
// colour is carried in `a_normal` (the mesh builder writes a `ChronoConstellatorPalette` colour there), `a_uv.x` is the
// vertex's age in ticks (0 for the newest ribbon point, a star or a ring), `a_uv.y` its glow weight 0 ... 1. The alpha
// fades with age, exactly 1 - age / R with R the tier's `ribbonTicks` (`u_ribbonTicks`, clamped to 1 ...
// `maxRibbonTicks`), clamped to 0 ... 1 (`ribbonAlpha(age:ticks:)`). A gentle shimmer scales the brightness by
// 1 + `shimmerAmplitude` sin(2 pi (`shimmerHertz` u_time + phase)), the phase from the model position; it is off when
// `u_reduceMotion` is 1 (the presenter also holds `u_time` at 0 then), so `u_time` is the only time source. The glow is
// the colour lifted by `glowWeight` times the glow gain, which is `u_glowGain` capped by `u_glowLimit` (both clamped to
// `maxGlowGain`); under Reduce Flashing the presenter passes `glowGainCap` as the limit. `u_shell` = 1 draws a glow
// shell (alpha `shellWeight` x gain x glow weight x age fade).
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1)
// from `Mesh.interleavedPositionNormal()` and `a_uv` (location 2) from `Mesh.uvs`. Every source starts with
// `#version 300 es` (VisualCoreShaderSource's `ShaderLibrary.versionLine`) and states one float precision. No texture
// samplers, no image assets, no loops and no `discard`. Output is premultiplied alpha. Palette constants are written
// with six fixed decimals from `ChronoConstellatorPalette`, so the shader colours equal the CPU's within 1/255.

import Foundation

/// The GLSL ES 3.00 sources of Chrono Constellator's field and glow programs, their uniform and attribute names, the
/// constants they are built from and the CPU references of what they compute (FR-R02G0603-002).
public enum ChronoConstellatorShaders {
    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine = "#version 300 es"

    /// The vertex attributes as (name, location), in location order: `a_position` (vec3, 0) and `a_normal` (vec3, 1)
    /// from `Mesh.interleavedPositionNormal()`, `a_uv` (vec2, 2) from `Mesh.uvs`, as `ShaderMeshRenderer` binds them.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    // MARK: Uniform names

    /// `mat4`: projection x view x model (both programs).
    public static let mvpUniform = "u_mvp"
    /// `float`: the cell size in model units, for the procedural grid lines (field).
    public static let cellUniform = "u_cell"
    /// `vec3`: the direction toward the light in model units (field; normalised by the shader).
    public static let lightDirectionUniform = "u_lightDir"
    /// `float`: presentation time in seconds, the only time source of the shimmer (glow); 0 under Reduce Motion.
    public static let timeUniform = "u_time"
    /// `float`: 1 under Reduce Motion (the shimmer stands still), 0 otherwise (glow).
    public static let reduceMotionUniform = "u_reduceMotion"
    /// `float`: the tier's `ribbonTicks` R, clamped by the shader to 1 ... ``maxRibbonTicks`` (glow).
    public static let ribbonTicksUniform = "u_ribbonTicks"
    /// `float`: the glow gain (glow); see ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (glow): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"
    /// `float`: 0 for the ribbon and star body, 1 for an additive glow-shell pass (glow).
    public static let shellUniform = "u_shell"

    /// Every uniform the field program declares, exactly as declared (vertex stage first).
    public static let fieldUniforms: [String] = [mvpUniform, cellUniform, lightDirectionUniform]

    /// Every uniform the glow program declares, exactly as declared (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, timeUniform, reduceMotionUniform, ribbonTicksUniform,
                                                glowGainUniform, glowLimitUniform, shellUniform]

    /// The uniform lists per program name (`field`, `glow`).
    public static let uniformNames: [String: [String]] = ["field": fieldUniforms, "glow": glowUniforms]

    // MARK: Constants

    /// The indigo night field, as written into the sources (`ChronoConstellatorPalette.field`).
    public static let field: SIMD3<Double> = ChronoConstellatorPalette.field
    /// The faint grid lines, as written into the sources (`ChronoConstellatorPalette.grid`).
    public static let grid: SIMD3<Double> = ChronoConstellatorPalette.grid
    /// The silver loop tracks, as written into the sources (`ChronoConstellatorPalette.silver`).
    public static let silver: SIMD3<Double> = ChronoConstellatorPalette.silver
    /// The star nodes and the hot glow core, as written into the sources (`ChronoConstellatorPalette.star`).
    public static let star: SIMD3<Double> = ChronoConstellatorPalette.star
    /// The target rings, as written into the sources (`ChronoConstellatorPalette.rose`).
    public static let rose: SIMD3<Double> = ChronoConstellatorPalette.rose
    /// The collision marks, as written into the sources (`ChronoConstellatorPalette.amber`).
    public static let amber: SIMD3<Double> = ChronoConstellatorPalette.amber

    /// The grid line width in cells (field material).
    public static let gridLineWidth: Double = 0.04
    /// The field program's ambient term.
    public static let ambient: Double = 0.55
    /// The field program's Lambert weight (ambient + diffuse = 1).
    public static let diffuse: Double = 0.45

    /// The longest ribbon in ticks (the richest tier's `ribbonTicks`, ``ChronoConstellatorTier/historyTicks``).
    public static let maxRibbonTicks: Double = Double(ChronoConstellatorTier.historyTicks)
    /// The shimmer amplitude: the brightness factor runs 1 - amplitude ... 1 + amplitude (bounded at 0.1).
    public static let shimmerAmplitude: Double = 0.08
    /// The shimmer frequency in cycles per second.
    public static let shimmerHertz: Double = 0.35
    /// The shimmer phase in cycles per model unit along x + z (so neighbouring ribbon points shimmer apart).
    public static let shimmerSpatial: Double = 1.5
    /// The emissive glow weight, times the glow gain and the glow weight of the vertex.
    public static let glowWeight: Double = 0.3
    /// How far the glow lifts a colour toward the star white, times the glow gain and the glow weight of the vertex.
    public static let coreLift: Double = 0.25
    /// The glow-shell alpha weight, times the glow gain, the glow weight and the age fade.
    public static let shellWeight: Double = 0.35

    /// The upper bound (the glow gain cap) the glow shader clamps `u_glowGain` and `u_glowLimit` to.
    public static let maxGlowGain: Double = 1.5
    /// The glow gain the presenter passes at a tier with glow shells.
    public static let standardGlowGain: Double = 1.0
    /// The glow limit the presenter passes normally (no cap below ``maxGlowGain``).
    public static let standardGlowLimit: Double = 1.5
    /// The Reduce Flashing cap on the glow gain: the limit the presenter passes under Reduce Flashing, the glow at half
    /// strength (the shared limit Hue Compass's `HueCompassShaders.reducedFlashingGainLimit` uses).
    public static let glowGainCap: Double = 0.5

    /// A field material code, written into `a_uv.x` of a field-program vertex.
    public enum FieldMaterial: Int, Sendable, CaseIterable, Hashable {
        /// The indigo night field, with the procedural grid lines.
        case field = 0
        /// Explicit grid line geometry.
        case grid = 1
        /// A silver loop track.
        case track = 2
        /// A star node.
        case star = 3
        /// A rose target ring.
        case rose = 4
        /// An amber collision mark.
        case amber = 5

        /// The `a_uv.x` value of the material.
        public var code: Double { Double(rawValue) }

        /// The material's colour as the field vertex shader selects it (before shade, grid lines and light).
        public var colour: SIMD3<Double> {
            switch self {
            case .field: ChronoConstellatorShaders.field
            case .grid: ChronoConstellatorShaders.grid
            case .track: ChronoConstellatorShaders.silver
            case .star: ChronoConstellatorShaders.star
            case .rose: ChronoConstellatorShaders.rose
            case .amber: ChronoConstellatorShaders.amber
            }
        }
    }

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The field vertex shader. Uniforms: `u_mvp`, `u_cell`. Selects the material colour from `a_uv.x`, scales it by
    /// the shade `a_uv.y` and passes the normal, the position in cells and the field flag.
    public static let fieldVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_cell;
    out vec3 v_normal;
    out vec3 v_base;
    out vec2 v_cells;
    out float v_isField;
    const vec3 CH_FIELD = \(vec3Literal(field));
    const vec3 CH_GRID = \(vec3Literal(grid));
    const vec3 CH_SILVER = \(vec3Literal(silver));
    const vec3 CH_STAR = \(vec3Literal(star));
    const vec3 CH_ROSE = \(vec3Literal(rose));
    const vec3 CH_AMBER = \(vec3Literal(amber));
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, 5.0);
        float isGrid = 1.0 - step(0.5, abs(m - 1.0));
        float isTrack = 1.0 - step(0.5, abs(m - 2.0));
        float isStar = 1.0 - step(0.5, abs(m - 3.0));
        float isRose = 1.0 - step(0.5, abs(m - 4.0));
        float isAmber = 1.0 - step(0.5, abs(m - 5.0));
        vec3 base = mix(CH_FIELD, CH_GRID, isGrid);
        base = mix(base, CH_SILVER, isTrack);
        base = mix(base, CH_STAR, isStar);
        base = mix(base, CH_ROSE, isRose);
        base = mix(base, CH_AMBER, isAmber);
        v_base = base * clamp(a_uv.y, 0.0, 1.0);
        v_normal = a_normal;
        v_cells = a_position.xz / max(u_cell, 0.0001);
        v_isField = 1.0 - step(0.5, m);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The field fragment shader. Uniform: `u_lightDir`. On the field material the grid lines of width
    /// ``gridLineWidth`` cells mix the colour toward grid (``gridLine(cellsX:cellsZ:)``); then ambient ``ambient``
    /// plus Lambert ``diffuse`` (``fieldShade(base:normalDotLight:)``). Opaque, premultiplied.
    public static let fieldFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_base;
    in vec2 v_cells;
    in float v_isField;
    uniform vec3 u_lightDir;
    out vec4 color;
    const vec3 CH_GRID = \(vec3Literal(grid));
    const float CH_LINE = \(fixed(gridLineWidth));
    const float CH_AMBIENT = \(fixed(ambient));
    const float CH_DIFFUSE = \(fixed(diffuse));
    void main() {
        vec2 d = abs(fract(v_cells + 0.5) - 0.5);
        float edge = min(d.x, d.y);
        float line = 1.0 - smoothstep(0.5 * CH_LINE, CH_LINE, edge);
        vec3 base = mix(clamp(v_base, 0.0, 1.0), CH_GRID, line * step(0.5, v_isField));
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 l = u_lightDir / max(length(u_lightDir), 0.0001);
        float lambert = max(dot(n, l), 0.0);
        vec3 rgb = clamp(base * (CH_AMBIENT + CH_DIFFUSE * lambert), 0.0, 1.0);
        float alpha = 1.0;
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`), the age in ticks (`a_uv.x`), the glow
    /// weight (`a_uv.y`) and the shimmer phase from the model position.
    public static let glowVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec3 v_colour;
    out float v_age;
    out float v_glow;
    out float v_phase;
    const float CH_SHIMMER_SPATIAL = \(fixed(shimmerSpatial));
    void main() {
        v_colour = clamp(a_normal, 0.0, 1.0);
        v_age = max(a_uv.x, 0.0);
        v_glow = clamp(a_uv.y, 0.0, 1.0);
        v_phase = CH_SHIMMER_SPATIAL * (a_position.x + a_position.z);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glow fragment shader. Uniforms: `u_time`, `u_reduceMotion`, `u_ribbonTicks`, `u_glowGain`, `u_glowLimit`,
    /// `u_shell`. Alpha ``ribbonAlpha(age:ticks:)``, shimmer ``shimmer(time:phase:reduceMotion:)``, glow
    /// ``glowGain(gain:limit:)``, colour ``glowColour(colour:glow:gain:shimmer:)``. Premultiplied RGBA in 0 ... 1.
    public static let glowFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_age;
    in float v_glow;
    in float v_phase;
    uniform float u_time;
    uniform float u_reduceMotion;
    uniform float u_ribbonTicks;
    uniform float u_glowGain;
    uniform float u_glowLimit;
    uniform float u_shell;
    out vec4 color;
    const vec3 CH_STAR = \(vec3Literal(star));
    const float CH_MAX_TICKS = \(fixed(maxRibbonTicks));
    const float CH_SHIMMER = \(fixed(shimmerAmplitude));
    const float CH_SHIMMER_HERTZ = \(fixed(shimmerHertz));
    const float CH_GLOW = \(fixed(glowWeight));
    const float CH_CORE = \(fixed(coreLift));
    const float CH_SHELL = \(fixed(shellWeight));
    const float CH_MAX_GAIN = \(fixed(maxGlowGain));
    void main() {
        float ticks = clamp(u_ribbonTicks, 1.0, CH_MAX_TICKS);
        float fade = clamp(1.0 - v_age / ticks, 0.0, 1.0);
        float motion = 1.0 - step(0.5, u_reduceMotion);
        float shimmer = 1.0 + CH_SHIMMER * motion * sin(6.283185307179586 * (CH_SHIMMER_HERTZ * u_time + v_phase));
        float gain = min(clamp(u_glowGain, 0.0, CH_MAX_GAIN), clamp(u_glowLimit, 0.0, CH_MAX_GAIN));
        vec3 lifted = mix(v_colour, CH_STAR, clamp(CH_CORE * gain * v_glow, 0.0, 1.0));
        vec3 core = clamp(lifted * (1.0 + CH_GLOW * gain * v_glow) * shimmer, 0.0, 1.0);
        float isShell = step(0.5, u_shell);
        float shellAlpha = clamp(CH_SHELL * gain * v_glow, 0.0, 1.0);
        vec3 rgb = mix(core, v_colour, isShell);
        float alpha = fade * mix(1.0, shellAlpha, isShell);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``standardGlowGain`` with glow shells, 0 without.
    public static func glowGain(for tier: ChronoConstellatorTier) -> Double {
        tier.glowShells > 0 ? standardGlowGain : 0
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 ... ``maxGlowGain`` (non-finite
    /// counts as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The ribbon alpha the glow shader computes for a vertex `age` ticks old with ribbon length `ticks` (clamped to
    /// 1 ... ``maxRibbonTicks``): 1 - age / ticks clamped to 0 ... 1 (a negative age counts as 0; non-finite gives 0).
    public static func ribbonAlpha(age: Double, ticks: Double) -> Double {
        guard age.isFinite, ticks.isFinite else { return 0 }
        let r: Double = min(max(ticks, 1), maxRibbonTicks)
        return min(max(1 - max(age, 0) / r, 0), 1)
    }

    /// The ribbon alpha for an integer `age` and a tier's `ribbonTicks` (see ``ribbonAlpha(age:ticks:)``).
    public static func ribbonAlpha(age: Int, ticks: Int) -> Double {
        ribbonAlpha(age: Double(age), ticks: Double(ticks))
    }

    /// The shimmer brightness factor at `time` seconds and `phase` cycles: 1 + ``shimmerAmplitude`` sin(2 pi
    /// (``shimmerHertz`` time + phase)), exactly 1 under Reduce Motion or for a non-finite input.
    public static func shimmer(time: Double, phase: Double, reduceMotion: Bool) -> Double {
        guard !reduceMotion, time.isFinite, phase.isFinite else { return 1 }
        return 1 + shimmerAmplitude * sin(2 * Double.pi * (shimmerHertz * time + phase))
    }

    /// The glow body colour for a vertex `colour`, glow weight `glow` and the applied `gain` and `shimmer` factor: the
    /// colour lifted toward star white by ``coreLift`` gain glow, times 1 + ``glowWeight`` gain glow and the shimmer,
    /// every component clamped to 0 ... 1.
    public static func glowColour(colour: SIMD3<Double>, glow: Double, gain: Double,
                                  shimmer: Double) -> SIMD3<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        let c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        let g: Double = unit(glow)
        let lift: Double = unit(coreLift * gain * g)
        let lifted: SIMD3<Double> = c + (star - c) * lift
        let scaled: SIMD3<Double> = lifted * ((1 + glowWeight * gain * g) * shimmer)
        return SIMD3<Double>(unit(scaled.x), unit(scaled.y), unit(scaled.z))
    }

    /// The grid-line weight (0 ... 1) the field shader mixes toward grid at a point `cellsX`, `cellsZ` cells from the
    /// origin: 1 on a cell boundary, 0 beyond ``gridLineWidth`` from it (smoothstep between half and full width).
    public static func gridLine(cellsX: Double, cellsZ: Double) -> Double {
        guard cellsX.isFinite, cellsZ.isFinite else { return 0 }
        func distance(_ x: Double) -> Double {
            let shifted: Double = x + 0.5
            return abs(shifted - shifted.rounded(.down) - 0.5)
        }
        let edge: Double = min(distance(cellsX), distance(cellsZ))
        let lo: Double = 0.5 * gridLineWidth
        let t: Double = min(max((edge - lo) / (gridLineWidth - lo), 0), 1)
        return 1 - t * t * (3 - 2 * t)
    }

    /// The field fragment colour for a material colour `base` (after shade and grid lines) and n . l
    /// `normalDotLight`: base x (``ambient`` + ``diffuse`` max(n . l, 0)), every component in 0 ... 1.
    public static func fieldShade(base: SIMD3<Double>, normalDotLight: Double) -> SIMD3<Double> {
        func unit(_ x: Double) -> Double { min(max(x, 0), 1) }
        let b: SIMD3<Double> = SIMD3<Double>(unit(base.x), unit(base.y), unit(base.z))
        let lit: SIMD3<Double> = b * (ambient + diffuse * max(normalDotLight, 0))
        return SIMD3<Double>(unit(lit.x), unit(lit.y), unit(lit.z))
    }
}
