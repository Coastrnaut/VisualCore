// ColorfallCanyonsShaders — feature 343 (R02-G05-03) T-R02G0503-003 (FR-R02G0503-002; clarifications Q1, Q2, Q4). The
// two GLSL ES 3.00 programs of Colorfall Canyons held as source text (data: the core issues no GL call), with the names
// of every uniform they declare, their vertex attributes, the constants the sources are built from and the CPU
// references of what they compute.
//
// Terrain program: the layered mesa blocks, rock slabs, basin rims and drain pits, lit from their generated normals.
// `u_model` places the mesh in the world (rotation, translation, uniform scale) and `u_mvp` is projection x view x
// model. The fragment stage shades the material colour with a soft ambient term plus Lambert from the light direction
// `u_lightDir`, darkens it slightly in horizontal strata (two per height step `u_unit`) and adds a rim lifted toward
// pearl from a fresnel term (1 - facing)^3 between the world normal and the direction to the eye `u_eye`.
//
// Fluid program: the emissive neon fluid sheets, the spring emitter columns and the basin rim arcs, unlit. The colour
// is the mass-weighted mix of the three palette colours, exactly `ColorfallCanyonsPalette.fluid`, times the brightness
// `ColorfallCanyonsPalette.brightness(volume:)`. Flow bands run along the cell's downhill direction: a cosine wave of
// `u_flowBands` cycles per cell whose phase moves with `u_time` only (the presenter holds `u_time` at 0 under Reduce
// Motion); a waterfall's bands move twice as fast. Every colour also carries its pattern (cyan stripes, coral dots,
// yellow chevrons), each darkening the sheet in proportion to that colour's share of the mass, so no information is
// carried by hue alone. The emissive glow is the base colour times the glow gain, which is `u_glowGain` capped by
// `u_glowLimit` (both bounded to `maxGlowGain`); under Reduce Flashing the presenter passes `glowGainCap` as the limit.
// A glow-shell pass reuses the program with `u_shell` = 1 on a wider mesh, drawn additively.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer` (ShaderMeshRenderer.swift: file header and `draw`, which
// binds `vcAttribute(0, 3 floats)`, `vcAttribute(1, 3 floats)` from `Mesh.interleavedPositionNormal()` and
// `vcAttribute(2, 2 floats)` from `Mesh.uvs`, a constant (0, 0) when the mesh has none): `a_position` (location 0),
// `a_normal` (location 1) and `a_uv` (location 2). There is no colour stream, so the programs encode their per-vertex
// data in these three:
// - terrain: `a_normal` is the real generated normal; `a_uv.x` the material code (0 sandstone, 1 rock, 2 pearl, 3 pit,
//   see `TerrainMaterial`), `a_uv.y` the vertex shade 0 ... 1 (1: full colour; lower values dim a closed spring's
//   emitter base or an occluded face).
// - fluid: `a_normal` carries the colour mass weights (cyan, coral, yellow; any non-negative values, the shader
//   normalises them), not a normal (the sheet is unlit); `a_uv.x` the brightness 0 ... 1, `a_uv.y` the flow code
//   (`flowCode(dx:dz:waterfall:)`: 0 none, 1 ... 4 the directions +x, -x, +z, -z, plus 4 for a waterfall). Pattern
//   and band coordinates are the vertex's model x and z divided by the cell size `u_cell`, so each cell's sheet must
//   have its own vertices (no vertex shared between cells with different codes).
// Every source starts with `#version 300 es` (VisualCoreShaderSource's `ShaderLibrary.versionLine`) and states one
// float precision. No texture samplers, no image assets, no loops and no `discard`. Output is premultiplied alpha.

import Foundation

/// The GLSL ES 3.00 sources of Colorfall Canyons's terrain and fluid programs, their uniform and attribute names, the
/// constants they are built from and the CPU references of what they compute (FR-R02G0503-002).
public enum ColorfallCanyonsShaders {
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
    /// `mat4`: model to world, rotation, translation and uniform scale (terrain).
    public static let modelUniform = "u_model"
    /// `vec3`: the eye position in world units (terrain).
    public static let eyeUniform = "u_eye"
    /// `float`: one height step in model units, for the strata (terrain).
    public static let unitUniform = "u_unit"
    /// `vec3`: the direction toward the light in world units (terrain; normalised by the shader).
    public static let lightDirectionUniform = "u_lightDir"
    /// `float`: the cell size in model units, for flow bands and patterns (fluid).
    public static let cellUniform = "u_cell"
    /// `float`: presentation time in seconds, the only time source of the flow phase (fluid); 0 under Reduce Motion.
    public static let timeUniform = "u_time"
    /// `float`: flow bands per cell, the tier's `flowBands`, clamped by the shader to 1 ... ``maxFlowBands`` (fluid).
    public static let flowBandsUniform = "u_flowBands"
    /// `float`: the glow gain (fluid); see ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (fluid): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"
    /// `float`: 0 for the fluid body, 1 for an additive glow-shell pass (fluid).
    public static let shellUniform = "u_shell"

    /// Every uniform the terrain program declares, exactly as declared (vertex stage first).
    public static let terrainUniforms: [String] = [mvpUniform, modelUniform, eyeUniform, unitUniform,
                                                   lightDirectionUniform]

    /// Every uniform the fluid program declares, exactly as declared (vertex stage first).
    public static let fluidUniforms: [String] = [mvpUniform, cellUniform, timeUniform, flowBandsUniform,
                                                 glowGainUniform, glowLimitUniform, shellUniform]

    /// The uniform lists per program name (`terrain`, `fluid`).
    public static let uniformNames: [String: [String]] = ["terrain": terrainUniforms, "fluid": fluidUniforms]

    // MARK: Constants

    /// Night, as written into the sources (`ColorfallCanyonsPalette.night`).
    public static let night: SIMD3<Double> = ColorfallCanyonsPalette.night
    /// Sandstone, as written into the sources (`ColorfallCanyonsPalette.sandstone`).
    public static let sandstone: SIMD3<Double> = ColorfallCanyonsPalette.sandstone
    /// Rock, as written into the sources (`ColorfallCanyonsPalette.rock`).
    public static let rock: SIMD3<Double> = ColorfallCanyonsPalette.rock
    /// Pearl, as written into the sources (`ColorfallCanyonsPalette.pearl`).
    public static let pearl: SIMD3<Double> = ColorfallCanyonsPalette.pearl
    /// Cyan, as written into the sources (`ColorfallCanyonsPalette.cyan`).
    public static let cyan: SIMD3<Double> = ColorfallCanyonsPalette.cyan
    /// Coral, as written into the sources (`ColorfallCanyonsPalette.coral`).
    public static let coral: SIMD3<Double> = ColorfallCanyonsPalette.coral
    /// Yellow, as written into the sources (`ColorfallCanyonsPalette.yellow`).
    public static let yellow: SIMD3<Double> = ColorfallCanyonsPalette.yellow

    /// How far a drain pit's colour goes from night toward rock (a dark pit, still apart from the background).
    public static let pitRockShare: Double = 0.35
    /// The terrain's ambient term.
    public static let ambient: Double = 0.3
    /// The terrain's Lambert weight (ambient + diffuse = 1).
    public static let diffuse: Double = 0.7
    /// The terrain rim strength, times the fresnel term.
    public static let rimStrength: Double = 0.35
    /// The exponent of the terrain fresnel term, (1 - facing)^3.
    public static let fresnelPower: Double = 3.0
    /// Strata per height step on the terrain.
    public static let strataPerStep: Double = 2.0
    /// The depth of the strata shading (the strata factor runs 1 - 2 depth ... 1).
    public static let strataDepth: Double = 0.04

    /// The most flow bands per cell (the richest tier's `flowBands`).
    public static let maxFlowBands: Double = 3.0
    /// The flow-band speed in cycles per second (a waterfall's is twice this).
    public static let flowHertz: Double = 0.5
    /// The depth of the flow-band modulation (the band factor runs 1 - depth ... 1).
    public static let bandDepth: Double = 0.35
    /// Pattern repeats per cell.
    public static let patternScale: Double = 3.0
    /// How much a full-strength pattern mark darkens the sheet.
    public static let patternDepth: Double = 0.45
    /// The alpha of a fluid sheet body.
    public static let sheetAlpha: Double = 0.92
    /// The emissive glow weight, times the glow gain.
    public static let glowWeight: Double = 0.25
    /// The glow-shell alpha weight, times the glow gain and brightness.
    public static let shellWeight: Double = 0.3

    /// The upper bound the fluid shader applies to `u_glowGain` and `u_glowLimit` (the same as Hue Compass's
    /// `HueCompassShaders.maxGain`).
    public static let maxGlowGain: Double = 2.0
    /// The glow gain the presenter passes at a tier with glow shells.
    public static let standardGlowGain: Double = 1.0
    /// The glow limit the presenter passes normally (no cap below ``maxGlowGain``).
    public static let standardGlowLimit: Double = 2.0
    /// The Reduce Flashing cap on the glow gain: the limit the presenter passes under Reduce Flashing, the glow at half
    /// strength (the same as Hue Compass's `HueCompassShaders.reducedFlashingGainLimit`).
    public static let glowGainCap: Double = 0.5

    /// A terrain material code, written into `a_uv.x`.
    public enum TerrainMaterial: Int, Sendable, CaseIterable, Hashable {
        /// Open ground (sandstone).
        case sandstone = 0
        /// Rock slabs.
        case rock = 1
        /// Basin rims and pearl marks.
        case pearl = 2
        /// Drain pits.
        case pit = 3

        /// The `a_uv.x` value of the material.
        public var code: Double { Double(rawValue) }

        /// The material's colour as the terrain vertex shader selects it (before shade, light and strata).
        public var colour: SIMD3<Double> {
            switch self {
            case .sandstone: ColorfallCanyonsShaders.sandstone
            case .rock: ColorfallCanyonsShaders.rock
            case .pearl: ColorfallCanyonsShaders.pearl
            case .pit: ColorfallCanyonsShaders.pitColour
            }
        }
    }

    /// A drain pit's colour: night moved ``pitRockShare`` of the way toward rock.
    public static var pitColour: SIMD3<Double> { night + (rock - night) * pitRockShare }

    // MARK: Sources

    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(v.x), \(v.y), \(v.z))" }

    /// The terrain vertex shader. Uniforms: `u_mvp`, `u_model`, `u_eye`, `u_unit`. Selects the material colour from
    /// `a_uv.x`, scales it by the shade `a_uv.y` and passes the world normal, the direction to the eye and the height in
    /// steps.
    public static let terrainVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform mat4 u_model;
    uniform vec3 u_eye;
    uniform float u_unit;
    out vec3 v_normal;
    out vec3 v_toEye;
    out vec3 v_base;
    out float v_steps;
    const vec3 CC_SANDSTONE = \(vec3Literal(sandstone));
    const vec3 CC_ROCK = \(vec3Literal(rock));
    const vec3 CC_PEARL = \(vec3Literal(pearl));
    const vec3 CC_NIGHT = \(vec3Literal(night));
    const float CC_PIT_ROCK = \(pitRockShare);
    void main() {
        vec4 world = u_model * vec4(a_position, 1.0);
        v_normal = mat3(u_model) * a_normal;
        v_toEye = u_eye - world.xyz;
        float m = floor(a_uv.x + 0.5);
        float isRock = 1.0 - step(0.5, abs(m - 1.0));
        float isPearl = 1.0 - step(0.5, abs(m - 2.0));
        float isPit = 1.0 - step(0.5, abs(m - 3.0));
        vec3 base = mix(CC_SANDSTONE, CC_ROCK, isRock);
        base = mix(base, CC_PEARL, isPearl);
        base = mix(base, mix(CC_NIGHT, CC_ROCK, CC_PIT_ROCK), isPit);
        v_base = base * clamp(a_uv.y, 0.0, 1.0);
        v_steps = a_position.y / max(u_unit, 0.0001);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The terrain fragment shader. Uniform: `u_lightDir`. Ambient ``ambient`` plus Lambert ``diffuse``, strata of
    /// depth ``strataDepth`` (``strataPerStep`` per step) and a pearl-lifted rim ``rimStrength`` times the fresnel term
    /// (see ``terrainShade(base:normalDotLight:facing:steps:)``). Opaque, premultiplied.
    public static let terrainFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_toEye;
    in vec3 v_base;
    in float v_steps;
    uniform vec3 u_lightDir;
    out vec4 color;
    const vec3 CC_PEARL = \(vec3Literal(pearl));
    const float CC_AMBIENT = \(ambient);
    const float CC_DIFFUSE = \(diffuse);
    const float CC_RIM = \(rimStrength);
    const float CC_STRATA = \(strataPerStep);
    const float CC_STRATA_DEPTH = \(strataDepth);
    void main() {
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 v = v_toEye / max(length(v_toEye), 0.0001);
        vec3 l = u_lightDir / max(length(u_lightDir), 0.0001);
        float lambert = max(dot(n, l), 0.0);
        float facing = clamp(abs(dot(n, v)), 0.0, 1.0);
        float fresnel = pow(1.0 - facing, \(fresnelPower));
        float strata = 1.0 - CC_STRATA_DEPTH + CC_STRATA_DEPTH * cos(6.283185307179586 * CC_STRATA * v_steps);
        vec3 base = clamp(v_base, 0.0, 1.0) * strata;
        vec3 lit = base * (CC_AMBIENT + CC_DIFFUSE * lambert);
        vec3 rim = mix(base, CC_PEARL, 0.5) * (CC_RIM * fresnel);
        vec3 rgb = clamp(lit + rim, 0.0, 1.0);
        float alpha = 1.0;
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The fluid vertex shader. Uniforms: `u_mvp`, `u_cell`. Passes the mass weights (`a_normal`), the brightness
    /// (`a_uv.x`), the decoded flow direction and waterfall flag (`a_uv.y`, see ``flowDirection(code:)``) and the
    /// position in cells.
    public static let fluidVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_cell;
    out vec3 v_weights;
    out float v_brightness;
    out vec2 v_dir;
    out float v_fall;
    out vec2 v_cell;
    void main() {
        v_weights = max(a_normal, vec3(0.0));
        v_brightness = clamp(a_uv.x, 0.0, 1.0);
        float code = clamp(floor(a_uv.y + 0.5), 0.0, 8.0);
        float fall = step(4.5, code);
        float d = code - 4.0 * fall;
        float px = 1.0 - step(0.5, abs(d - 1.0));
        float nx = 1.0 - step(0.5, abs(d - 2.0));
        float pz = 1.0 - step(0.5, abs(d - 3.0));
        float nz = 1.0 - step(0.5, abs(d - 4.0));
        v_dir = vec2(px - nx, pz - nz);
        v_fall = fall;
        v_cell = a_position.xz / max(u_cell, 0.0001);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The fluid fragment shader. Uniforms: `u_time`, `u_flowBands`, `u_glowGain`, `u_glowLimit`, `u_shell`. The base
    /// colour is the normalised weights times the cyan, coral and yellow constants (``fluidColour(weights:)``), the
    /// band factor ``flowBand(along:time:bands:waterfall:flowing:)``, the pattern mark the weighted sum of stripes, dots
    /// and chevrons, the glow ``glowGain(gain:limit:)``. Premultiplied RGBA with every component in 0 ... 1.
    public static let fluidFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_weights;
    in float v_brightness;
    in vec2 v_dir;
    in float v_fall;
    in vec2 v_cell;
    uniform float u_time;
    uniform float u_flowBands;
    uniform float u_glowGain;
    uniform float u_glowLimit;
    uniform float u_shell;
    out vec4 color;
    const vec3 CC_CYAN = \(vec3Literal(cyan));
    const vec3 CC_CORAL = \(vec3Literal(coral));
    const vec3 CC_YELLOW = \(vec3Literal(yellow));
    const float CC_MAX_BANDS = \(maxFlowBands);
    const float CC_FLOW_HERTZ = \(flowHertz);
    const float CC_BAND_DEPTH = \(bandDepth);
    const float CC_PATTERN_SCALE = \(patternScale);
    const float CC_PATTERN_DEPTH = \(patternDepth);
    const float CC_SHEET_ALPHA = \(sheetAlpha);
    const float CC_GLOW = \(glowWeight);
    const float CC_SHELL = \(shellWeight);
    const float CC_MAX_GAIN = \(maxGlowGain);
    void main() {
        vec3 w = v_weights / max(v_weights.x + v_weights.y + v_weights.z, 0.0001);
        vec3 base = clamp(w.x * CC_CYAN + w.y * CC_CORAL + w.z * CC_YELLOW, 0.0, 1.0);
        float level = clamp(v_brightness, 0.0, 1.0);
        float flowing = step(0.5, length(v_dir));
        float bands = clamp(floor(u_flowBands + 0.5), 1.0, CC_MAX_BANDS);
        float along = dot(v_cell, v_dir);
        float speed = CC_FLOW_HERTZ * (1.0 + step(0.5, v_fall));
        float wave = 0.5 + 0.5 * cos(6.283185307179586 * (bands * along - speed * u_time));
        float band = mix(1.0, 1.0 - CC_BAND_DEPTH + CC_BAND_DEPTH * wave, flowing);
        vec2 q = v_cell * CC_PATTERN_SCALE;
        float stripe = smoothstep(0.35, 0.65, 0.5 + 0.5 * cos(6.283185307179586 * (q.x + q.y)));
        float spot = 1.0 - smoothstep(0.18, 0.26, length(fract(q) - 0.5));
        float chevron = smoothstep(0.35, 0.65, 0.5 + 0.5 * cos(6.283185307179586 * (q.y + abs(fract(q.x) - 0.5))));
        float mark = clamp(w.x * stripe + w.y * spot + w.z * chevron, 0.0, 1.0);
        float gain = min(clamp(u_glowGain, 0.0, CC_MAX_GAIN), clamp(u_glowLimit, 0.0, CC_MAX_GAIN));
        vec3 body = base * level * band * (1.0 - CC_PATTERN_DEPTH * mark);
        vec3 glow = base * level * (CC_GLOW * gain);
        vec3 core = clamp(body + glow, 0.0, 1.0);
        float isShell = step(0.5, u_shell);
        float present = step(0.0001, level);
        float shellAlpha = clamp(CC_SHELL * gain * level, 0.0, 1.0);
        vec3 rgb = mix(core, base, isShell);
        float alpha = present * mix(CC_SHEET_ALPHA, shellAlpha, isShell);
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
    public static func glowGain(for tier: ColorfallCanyonsTier) -> Double {
        tier.glowShells > 0 ? standardGlowGain : 0
    }

    /// The glow gain the fluid shader applies: `gain` and `limit` each clamped to 0 ... ``maxGlowGain`` (non-finite
    /// counts as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The `a_normal` weights of a fluid vertex for `masses` (cyan, coral, yellow): the mass shares, (0, 0, 0) for an
    /// empty cell or a malformed list.
    public static func weights(masses: [Int]) -> SIMD3<Double> {
        guard masses.count == 3 else { return SIMD3<Double>(0, 0, 0) }
        let total: Int = masses.reduce(0, +)
        guard total > 0 else { return SIMD3<Double>(0, 0, 0) }
        return SIMD3<Double>(Double(masses[0]), Double(masses[1]), Double(masses[2])) / Double(total)
    }

    /// The fluid base colour the shader computes from `weights`: the normalised weights (negatives as 0) times cyan,
    /// coral and yellow; with zero weights the colour is black (the sheet is then absent: brightness 0).
    public static func fluidColour(weights: SIMD3<Double>) -> SIMD3<Double> {
        let w: SIMD3<Double> = SIMD3<Double>(max(weights.x, 0), max(weights.y, 0), max(weights.z, 0))
        let total: Double = max(w.x + w.y + w.z, 0.0001)
        let n: SIMD3<Double> = w / total
        return cyan * n.x + coral * n.y + yellow * n.z
    }

    /// The `a_uv.y` flow code of a cell whose downhill neighbour lies `dx`, `dz` steps away in model x and z (one of
    /// them ±1, the other 0): 1 (+x), 2 (-x), 3 (+z), 4 (-z), plus 4 for a waterfall (a drop of 2 or more steps); 0 for
    /// no downhill neighbour or any other step.
    public static func flowCode(dx: Int, dz: Int, waterfall: Bool) -> Double {
        let direction: Int
        switch (dx, dz) {
        case (1, 0): direction = 1
        case (-1, 0): direction = 2
        case (0, 1): direction = 3
        case (0, -1): direction = 4
        default: return 0
        }
        return Double(direction + (waterfall ? 4 : 0))
    }

    /// The flow direction (model x, z) and waterfall flag the fluid vertex shader decodes from `code` (rounded to the
    /// nearest integer and clamped to 0 ... 8).
    public static func flowDirection(code: Double) -> (direction: SIMD2<Double>, waterfall: Bool) {
        let c: Double = code.isFinite ? min(max((code + 0.5).rounded(.down), 0), 8) : 0
        let fall: Bool = c >= 4.5
        let d: Double = c - (fall ? 4 : 0)
        switch d {
        case 1: return (SIMD2<Double>(1, 0), fall)
        case 2: return (SIMD2<Double>(-1, 0), fall)
        case 3: return (SIMD2<Double>(0, 1), fall)
        case 4: return (SIMD2<Double>(0, -1), fall)
        default: return (SIMD2<Double>(0, 0), fall)
        }
    }

    /// The flow-band factor at `along` cells down the flow at `time` seconds with `bands` per cell (rounded, clamped to
    /// 1 ... ``maxFlowBands``): 1 - ``bandDepth`` + ``bandDepth`` (0.5 + 0.5 cos(2 pi (bands along - speed time))),
    /// speed ``flowHertz`` (twice for a waterfall); 1 where nothing flows or for a non-finite input.
    public static func flowBand(along: Double, time: Double, bands: Double, waterfall: Bool, flowing: Bool) -> Double {
        guard flowing, along.isFinite, time.isFinite, bands.isFinite else { return 1 }
        let b: Double = min(max((bands + 0.5).rounded(.down), 1), maxFlowBands)
        let speed: Double = flowHertz * (waterfall ? 2 : 1)
        let wave: Double = 0.5 + 0.5 * cos(2 * Double.pi * (b * along - speed * time))
        return 1 - bandDepth + bandDepth * wave
    }

    /// The terrain fragment colour for a material colour `base` (after shade), n . l `normalDotLight`, |n . v|
    /// `facing` and height `steps` (in height steps); every component in 0 ... 1.
    public static func terrainShade(base: SIMD3<Double>, normalDotLight: Double, facing: Double,
                                    steps: Double) -> SIMD3<Double> {
        func unit(_ x: Double) -> Double { min(max(x, 0), 1) }
        let lambert: Double = max(normalDotLight, 0)
        let f: Double = unit(abs(facing))
        let fresnel: Double = (1 - f) * (1 - f) * (1 - f)
        let strata: Double = 1 - strataDepth + strataDepth * cos(2 * Double.pi * strataPerStep * steps)
        let b: SIMD3<Double> = SIMD3<Double>(unit(base.x), unit(base.y), unit(base.z)) * strata
        let lit: SIMD3<Double> = b * (ambient + diffuse * lambert)
        let rim: SIMD3<Double> = (b + (pearl - b) * 0.5) * (rimStrength * fresnel)
        let sum: SIMD3<Double> = lit + rim
        return SIMD3<Double>(unit(sum.x), unit(sum.y), unit(sum.z))
    }
}
