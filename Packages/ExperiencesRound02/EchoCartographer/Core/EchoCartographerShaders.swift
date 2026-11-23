// EchoCartographerShaders — feature 403 (R02-G11-03) T-R02G1103-003 (FR-R02G1103-001, 002, 004; clarifications Q1–Q4).
// The two GLSL ES 3.00 programs of Echo Cartographer held as source text (data: the core issues no GL call), with the
// names of every uniform they declare, their vertex attributes, the material codes shared with
// `EchoCartographerSceneGeometry`, the constants the sources are built from and the CPU references of what they
// compute.
//
// Chamber program: the abyss ground, the floor tiles, the entry diamond, the marker rings, the last pulse's rays, the
// pulse and echo ring field, the wall blocks' dark faces and mint edge strips, the beacon pillars and the lit and unlit
// gauge bars. Mesh layout (data model, "Mesh streams"): `a_normal` is the surface normal (except on wall edge strips,
// below), `a_uv.x` the material code (``ChamberMaterial``: 0 ground, 1 floor, 2 entry, 3 marker, 4 ray, 5 ring field, 6
// wall face, 7 wall edge, 8 pillar, 9 lit gauge bar, 10 unlit gauge bar) and `a_uv.y` the local edge coordinate d: on a
// fan (floor tile, entry diamond, gauge bar: one centre vertex and the outline's corners) d is 0 at the centre and 1 on
// every outline vertex, so its interpolation is the normalised Chebyshev distance to the outline; on a strip (marker
// ring, ray, wall edge face) d is -1 on one long side, +1 on the other and 0 on the centre line; on solids and the ring
// field (ground, wall face, pillar, ring field) d is 0. The signed-distance soft edge is
// 1 - smoothstep(1 - ``edgeFeather``, 1, |d|) (``edgeCoverage(local:)``), used as premultiplied coverage, so outlines
// are anti-aliased without textures. Wall edge strips (code 7) are emissive and carry the struck wall's distance in
// cells in `a_normal.x` (the ray's `distance` to that wall; 0 for a wall the last pulse did not strike), the won flag in
// `a_normal.y` (1 on a won level, lifting the edges toward the flare colour by ``wonLift`` at every tier; feature 403
// convergence, T-R02G1103-014) and 0 in `a_normal.z`. Lighting is ambient ``ambient`` plus Lambert ``diffuse`` from `u_lightDir` on the lit
// materials (floor, wall face); every other material is emissive at its palette colour, so the colour cues hold under
// any light.
//
// Time effects, all driven by uniforms (the geometry never moves): `u_time` is the presentation time in seconds since
// the last pulse. The ring field (code 5, a flat quad over the chamber at y = 0.02) draws the pulse ring centred on
// `u_emitter` (world x, z) whose radius grows by one cell (`u_cellSize`, the cell pitch s) every
// ``pulseSecondsPerCell`` (0.1 s) up to `u_maxRadius` (the longest ray in world units) and then fades over
// ``pulseFadeSeconds`` (``pulseRingRadius(time:cellSize:maxRadius:)``, ``pulseRingFade(time:cellSize:maxRadius:)``),
// and up to ``maxEchoes`` (4) echo rings from `u_echoDelays` (seconds; 24 ticks × 0.008333 s × the beacon distance; 0
// for an unused slot): echo ring i appears at the beacon's distance when the pulse ring passes it and shrinks back to
// the emitter at the pulse speed, reaching it at its delay (``echoRingRadius(delay:time:cellSize:)``). Each ring line
// is 2 × ``ringHalfWidth`` cells wide with soft edges. A struck wall's edge strips flare toward the flare colour when
// the pulse ring reaches the wall's face (``faceOffset`` cell before its centre), fading over ``flareSeconds`` (0.5 s);
// at level-0 a dimmer trail (``trailWeight``) fades over ``trailSeconds``
// (``flareWeight(strikeDistance:time:flags:)``). `u_tier` = (rings, flares, trails) flags (``tierFlags(for:)``):
// level-0 (1, 1, 1), level-1 (1, 1, 0), level-2 (0, 0, 0). `u_reduceMotion` = 1 draws the rings and flares at rest: no
// rings, the struck walls at their resting edge colour. The loop over the echo rings is bounded by the constant
// ``maxEchoes``.
//
// Glow program: the glow shells around edges and pillars, drawn additively. The colour is carried in `a_normal` (the
// mesh builder writes `EchoCartographerPalette.glow` there; a zero colour falls back to the same glow constant),
// `a_uv.x` is the glow factor 0 ... 1 and `a_uv.y` is 0. The glow is the colour lifted toward the flare colour by
// ``coreLift`` times the glow factor and the glow gain, with alpha ``glowWeight`` times the same; the glow gain is
// `u_glowGain` capped by `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing the presenter passes
// ``glowGainCap`` as the limit. The glow program has no time input: it never pulses.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1) from
// `Mesh.interleavedPositionNormal()` and `a_uv` (location 2) from `Mesh.uvs`. Every source starts with
// `#version 300 es` (VisualCoreShaderSource's `ShaderLibrary.versionLine`) and states one float precision. Plain
// uniforms in the default block (at most 16 vec4 slots per program; the chamber program uses 12, the glow program 6),
// no texture samplers, no image assets, no `discard` and one loop, bounded by a constant. Output is premultiplied
// alpha. Palette constants are written with six fixed decimals from `EchoCartographerPalette`, so the shader colours
// equal the CPU's within 1e-6.

import Foundation

/// The GLSL ES 3.00 sources of Echo Cartographer's chamber and glow programs, their uniform and attribute names, the
/// material codes, the constants they are built from and the CPU references of what they compute (FR-R02G1103-001,
/// 002, 004).
public enum EchoCartographerShaders {
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
    /// `vec3`: the direction toward the light in model units (chamber; normalised by the shader).
    public static let lightDirectionUniform = "u_lightDir"
    /// `float`: presentation time in seconds since the last pulse, the only time source of the rings and flares
    /// (chamber).
    public static let timeUniform = "u_time"
    /// `float`: the cell pitch s = 1.8 / max(W, H) in world units (chamber): one cell of ring travel.
    public static let cellSizeUniform = "u_cellSize"
    /// `vec2`: the last pulse's emitter centre as world (x, z) (chamber).
    public static let emitterUniform = "u_emitter"
    /// `float`: the longest ray of the last pulse in world units, (distance - 0.5) s; 0 without a pulse (chamber).
    public static let maxRadiusUniform = "u_maxRadius"
    /// `vec4`: the delays in seconds of up to ``maxEchoes`` beacon echoes, ascending, 0 for an unused slot (chamber);
    /// see ``echoDelays(_:)``.
    public static let echoDelaysUniform = "u_echoDelays"
    /// `vec3`: the tier's (rings, flares, trails) flags, each 0 or 1 (chamber); see ``tierFlags(for:)``.
    public static let tierUniform = "u_tier"
    /// `float`: 1 under Reduce Motion (rings and flares at rest), 0 otherwise (chamber).
    public static let reduceMotionUniform = "u_reduceMotion"
    /// `float`: the glow gain (glow); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (glow): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the chamber program declares, each once, in order of declaration (vertex stage first).
    public static let chamberUniforms: [String] = [mvpUniform, lightDirectionUniform, timeUniform, cellSizeUniform,
                                                   emitterUniform, maxRadiusUniform, echoDelaysUniform, tierUniform,
                                                   reduceMotionUniform]

    /// Every uniform the glow program declares, exactly as declared (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform]

    /// The uniform lists per program name (`chamber`, `glow`).
    public static let uniformNames: [String: [String]] = ["chamber": chamberUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Material codes

    /// The material code of the abyss ground plane (`a_uv.x` = 0; emissive; d = 0).
    public static let groundMaterial: Int = ChamberMaterial.ground.rawValue
    /// The material code of a known floor tile (`a_uv.x` = 1; lit; fan, d 0 at the centre, 1 on the outline).
    public static let floorMaterial: Int = ChamberMaterial.floor.rawValue
    /// The material code of the entry diamond (`a_uv.x` = 2; emissive; fan).
    public static let entryMaterial: Int = ChamberMaterial.entry.rawValue
    /// The material code of a marker ring (`a_uv.x` = 3; emissive; strip, d -1 inside, +1 outside).
    public static let markerMaterial: Int = ChamberMaterial.marker.rawValue
    /// The material code of a ray of the last pulse (`a_uv.x` = 4; emissive; strip across its width).
    public static let rayMaterial: Int = ChamberMaterial.ray.rawValue
    /// The material code of the ring field, the quad the pulse and echo rings are drawn on (`a_uv.x` = 5; d = 0).
    public static let ringMaterial: Int = ChamberMaterial.ring.rawValue
    /// The material code of a known wall block's dark face (`a_uv.x` = 6; lit; d = 0).
    public static let wallFaceMaterial: Int = ChamberMaterial.wallFace.rawValue
    /// The material code of a known wall block's edge strip (`a_uv.x` = 7; emissive; strip across its thickness;
    /// `a_normal.x` = the struck distance in cells, 0 when not struck).
    public static let wallEdgeMaterial: Int = ChamberMaterial.wallEdge.rawValue
    /// The material code of a located beacon's pillar (`a_uv.x` = 8; emissive; d = 0).
    public static let pillarMaterial: Int = ChamberMaterial.pillar.rawValue
    /// The material code of a lit gauge bar, energy left (`a_uv.x` = 9; emissive; fan).
    public static let gaugeLitMaterial: Int = ChamberMaterial.gaugeLit.rawValue
    /// The material code of an unlit gauge bar, energy spent (`a_uv.x` = 10; emissive; fan).
    public static let gaugeUnlitMaterial: Int = ChamberMaterial.gaugeUnlit.rawValue

    /// A chamber material code, written into `a_uv.x` of a chamber-program vertex (shared with the geometry).
    public enum ChamberMaterial: Int, Sendable, CaseIterable, Hashable {
        /// The abyss ground plane (emissive; d = 0).
        case ground = 0
        /// A known floor tile (lit; fan).
        case floor = 1
        /// The entry diamond (emissive; fan).
        case entry = 2
        /// A marker ring (emissive; strip).
        case marker = 3
        /// A ray of the last pulse (emissive; strip).
        case ray = 4
        /// The ring field the pulse and echo rings are drawn on (emissive, coverage from the rings; d = 0).
        case ring = 5
        /// A known wall block's dark face (lit; d = 0).
        case wallFace = 6
        /// A known wall block's edge strip (emissive; strip; flares when struck).
        case wallEdge = 7
        /// A located beacon's pillar (emissive; d = 0).
        case pillar = 8
        /// A lit gauge bar (emissive; fan).
        case gaugeLit = 9
        /// An unlit gauge bar (emissive; fan).
        case gaugeUnlit = 10

        /// The `a_uv.x` value of the material.
        public var code: Double { Double(rawValue) }

        /// The material's palette colour as the chamber vertex shader selects it (before light, rings and flares).
        public var colour: SIMD3<Double> {
            switch self {
            case .ground: EchoCartographerPalette.ground
            case .floor: EchoCartographerPalette.floor
            case .entry: EchoCartographerPalette.entry
            case .marker: EchoCartographerPalette.marker
            case .ray, .ring: EchoCartographerPalette.pulse
            case .wallFace: EchoCartographerPalette.wallFace
            case .wallEdge: EchoCartographerPalette.wallEdge
            case .pillar: EchoCartographerPalette.pillar
            case .gaugeLit: EchoCartographerPalette.gaugeLit
            case .gaugeUnlit: EchoCartographerPalette.gaugeUnlit
            }
        }

        /// Whether the material is lit (ambient plus Lambert) rather than emissive at its palette colour.
        public var isLit: Bool { self == .floor || self == .wallFace }

        /// How the geometry fills `a_uv.y` for the material: `fan` (0 at the centre, 1 on the outline), `strip`
        /// (-1 … +1 across, 0 on the centre line) or `none` (0 everywhere).
        public var localCoordinate: LocalCoordinate {
            switch self {
            case .floor, .entry, .gaugeLit, .gaugeUnlit: .fan
            case .marker, .ray, .wallEdge: .strip
            case .ground, .ring, .wallFace, .pillar: .none
            }
        }
    }

    /// How a material's `a_uv.y` local edge coordinate is laid out by the geometry.
    public enum LocalCoordinate: Sendable, Hashable {
        /// A fan from a centre vertex (d = 0) to the outline's corners (d = 1).
        case fan
        /// A strip: d = -1 on one long side, +1 on the other.
        case strip
        /// No edge: d = 0 everywhere.
        case none
    }

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), one per palette entry.
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = [
        (name: "EC_GROUND", colour: EchoCartographerPalette.ground),
        (name: "EC_FLOOR", colour: EchoCartographerPalette.floor),
        (name: "EC_WALL_FACE", colour: EchoCartographerPalette.wallFace),
        (name: "EC_WALL_EDGE", colour: EchoCartographerPalette.wallEdge),
        (name: "EC_FLARE", colour: EchoCartographerPalette.flare),
        (name: "EC_PULSE", colour: EchoCartographerPalette.pulse),
        (name: "EC_ENTRY", colour: EchoCartographerPalette.entry),
        (name: "EC_MARKER", colour: EchoCartographerPalette.marker),
        (name: "EC_PILLAR", colour: EchoCartographerPalette.pillar),
        (name: "EC_GLOW", colour: EchoCartographerPalette.glow),
        (name: "EC_GAUGE_LIT", colour: EchoCartographerPalette.gaugeLit),
        (name: "EC_GAUGE_UNLIT", colour: EchoCartographerPalette.gaugeUnlit),
    ]

    /// The chamber program's ambient term on the lit materials.
    public static let ambient: Double = 0.7
    /// The chamber program's Lambert weight on the lit materials (ambient + diffuse = 1).
    public static let diffuse: Double = 0.3
    /// The width of the soft edge as a share of the local coordinate: coverage falls from 1 at |d| = 1 - feather to 0
    /// at |d| = 1.
    public static let edgeFeather: Double = 0.15
    /// The seconds the pulse ring takes to grow by one cell (clarification Q1).
    public static let pulseSecondsPerCell: Double = 0.1
    /// The kernel's round-trip echo ticks per cell of distance (`EchoCartographerChamber.ticksPerCell`).
    public static let echoTicksPerCell: Int = EchoCartographerChamber.ticksPerCell
    /// The seconds of one echo tick.
    public static let tickSeconds: Double = 0.008333
    /// The echo delay in seconds per cell of distance: 24 ticks × 0.008333 s.
    public static let echoSecondsPerCell: Double = Double(echoTicksPerCell) * tickSeconds
    /// The most echo rings drawn (one per beacon; the loop bound).
    public static let maxEchoes: Int = 4
    /// The half width of a ring line in cells (the line is 0.06 s wide).
    public static let ringHalfWidth: Double = 0.03
    /// The seconds the pulse ring takes to fade after reaching `u_maxRadius`.
    public static let pulseFadeSeconds: Double = 0.5
    /// The cells between a struck wall's centre and its face: the pulse reaches the face at (distance - 0.5) cells.
    public static let faceOffset: Double = 0.5
    /// How far a won level lifts every known wall's edges toward the flare colour, at every tier and under Reduce Motion
    /// (the spec's edge case "the chamber's known walls brighten").
    public static let wonLift: Double = 0.5
    /// The seconds a struck wall's flare takes to fade (clarification Q1).
    public static let flareSeconds: Double = 0.5
    /// The level-0 flare trail's peak weight.
    public static let trailWeight: Double = 0.35
    /// The seconds the level-0 flare trail takes to fade.
    public static let trailSeconds: Double = 1.5

    /// The alpha weight of the glow, times the glow gain and the glow factor of the vertex.
    public static let glowWeight: Double = 0.5
    /// How far the glow lifts a colour toward the flare colour, times the glow gain and the glow factor.
    public static let coreLift: Double = 0.3

    /// The upper bound the glow shader clamps `u_glowGain` and `u_glowLimit` to.
    public static let maxGlowGain: Double = 1.5
    /// The glow gain per glow shell the presenter passes (level-0: 2 shells, level-1: 1), plus ``glowGainBase``.
    public static let glowGainPerShell: Double = 0.5
    /// The glow gain base added to ``glowGainPerShell`` times the shells at a tier with glow shells.
    public static let glowGainBase: Double = 0.5
    /// The glow limit the presenter passes normally (no cap below ``maxGlowGain``).
    public static let standardGlowLimit: Double = 1.5
    /// The Reduce Flashing cap on the glow gain: the limit the presenter passes under Reduce Flashing (the shared limit
    /// Hue Compass's `HueCompassShaders.reducedFlashingGainLimit` uses).
    public static let glowGainCap: Double = 0.5

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The chamber vertex shader. Uniform: `u_mvp`. Selects the material colour from `a_uv.x`, passes the normal (up on
    /// wall edge strips), the model position, the material code, the local edge coordinate `a_uv.y` and, on wall edge
    /// strips only, the struck distance `a_normal.x`.
    public static let chamberVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec3 v_normal;
    out vec3 v_base;
    out vec3 v_position;
    out float v_material;
    out float v_local;
    out float v_strike;
    out float v_won;
    const vec3 EC_GROUND = \(vec3Literal(EchoCartographerPalette.ground));
    const vec3 EC_FLOOR = \(vec3Literal(EchoCartographerPalette.floor));
    const vec3 EC_ENTRY = \(vec3Literal(EchoCartographerPalette.entry));
    const vec3 EC_MARKER = \(vec3Literal(EchoCartographerPalette.marker));
    const vec3 EC_PULSE = \(vec3Literal(EchoCartographerPalette.pulse));
    const vec3 EC_WALL_FACE = \(vec3Literal(EchoCartographerPalette.wallFace));
    const vec3 EC_WALL_EDGE = \(vec3Literal(EchoCartographerPalette.wallEdge));
    const vec3 EC_PILLAR = \(vec3Literal(EchoCartographerPalette.pillar));
    const vec3 EC_GAUGE_LIT = \(vec3Literal(EchoCartographerPalette.gaugeLit));
    const vec3 EC_GAUGE_UNLIT = \(vec3Literal(EchoCartographerPalette.gaugeUnlit));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, 10.0);
        vec3 base = mix(EC_GROUND, EC_FLOOR, isCode(m, 1.0));
        base = mix(base, EC_ENTRY, isCode(m, 2.0));
        base = mix(base, EC_MARKER, isCode(m, 3.0));
        base = mix(base, EC_PULSE, isCode(m, 4.0));
        base = mix(base, EC_PULSE, isCode(m, 5.0));
        base = mix(base, EC_WALL_FACE, isCode(m, 6.0));
        base = mix(base, EC_WALL_EDGE, isCode(m, 7.0));
        base = mix(base, EC_PILLAR, isCode(m, 8.0));
        base = mix(base, EC_GAUGE_LIT, isCode(m, 9.0));
        base = mix(base, EC_GAUGE_UNLIT, isCode(m, 10.0));
        float isEdge = isCode(m, 7.0);
        v_base = base;
        v_normal = mix(a_normal, vec3(0.0, 1.0, 0.0), isEdge);
        v_position = a_position;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0);
        v_strike = max(a_normal.x, 0.0) * isEdge;
        v_won = clamp(a_normal.y, 0.0, 1.0) * isEdge;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The chamber fragment shader. Uniforms: `u_lightDir`, `u_time`, `u_cellSize`, `u_emitter`, `u_maxRadius`,
    /// `u_echoDelays`, `u_tier`, `u_reduceMotion`. Ambient ``ambient`` plus Lambert ``diffuse`` on the lit materials,
    /// the palette colour on the others; soft edges from the local coordinate (``edgeCoverage(local:)``); the ring
    /// field's coverage is the pulse ring and up to ``maxEchoes`` echo rings; struck wall edges flare
    /// (``flareWeight(strikeDistance:time:flags:)``). Premultiplied.
    public static let chamberFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_base;
    in vec3 v_position;
    in float v_material;
    in float v_local;
    in float v_strike;
    in float v_won;
    uniform vec3 u_lightDir;
    uniform float u_time;
    uniform float u_cellSize;
    uniform vec2 u_emitter;
    uniform float u_maxRadius;
    uniform vec4 u_echoDelays;
    uniform vec3 u_tier;
    uniform float u_reduceMotion;
    out vec4 color;
    const vec3 EC_PULSE = \(vec3Literal(EchoCartographerPalette.pulse));
    const vec3 EC_FLARE = \(vec3Literal(EchoCartographerPalette.flare));
    const int EC_MAX_ECHOES = \(maxEchoes);
    const float EC_AMBIENT = \(fixed(ambient));
    const float EC_DIFFUSE = \(fixed(diffuse));
    const float EC_EDGE_FEATHER = \(fixed(edgeFeather));
    const float EC_PULSE_SECONDS_PER_CELL = \(fixed(pulseSecondsPerCell));
    const float EC_ECHO_SECONDS_PER_CELL = \(fixed(echoSecondsPerCell));
    const float EC_RING_HALF_WIDTH = \(fixed(ringHalfWidth));
    const float EC_PULSE_FADE_SECONDS = \(fixed(pulseFadeSeconds));
    const float EC_FACE_OFFSET = \(fixed(faceOffset));
    const float EC_FLARE_SECONDS = \(fixed(flareSeconds));
    const float EC_WON_LIFT = \(fixed(wonLift));
    const float EC_TRAIL_WEIGHT = \(fixed(trailWeight));
    const float EC_TRAIL_SECONDS = \(fixed(trailSeconds));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    float band(float gap, float halfWidth) {
        return 1.0 - smoothstep(halfWidth * (1.0 - EC_EDGE_FEATHER), halfWidth, gap);
    }
    void main() {
        float m = floor(v_material + 0.5);
        float isRing = isCode(m, 5.0);
        float isEdge = isCode(m, 7.0);
        float isLit = isCode(m, 1.0) + isCode(m, 6.0);
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 l = u_lightDir / max(length(u_lightDir), 0.0001);
        float lambert = max(dot(n, l), 0.0);
        float light = mix(1.0, EC_AMBIENT + EC_DIFFUSE * lambert, clamp(isLit, 0.0, 1.0));
        float soft = 1.0 - smoothstep(1.0 - EC_EDGE_FEATHER, 1.0, clamp(abs(v_local), 0.0, 1.0));
        float motion = 1.0 - clamp(u_reduceMotion, 0.0, 1.0);
        float time = max(u_time, 0.0);
        float cell = max(u_cellSize, 0.0001);
        float maxRadius = max(u_maxRadius, 0.0);
        float dist = length(v_position.xz - u_emitter);
        float halfWidth = EC_RING_HALF_WIDTH * cell;
        float pulseRadius = min(time / EC_PULSE_SECONDS_PER_CELL * cell, maxRadius);
        float reach = maxRadius / cell * EC_PULSE_SECONDS_PER_CELL;
        float pulseFade = 1.0 - clamp((time - reach) / EC_PULSE_FADE_SECONDS, 0.0, 1.0);
        float ring = step(0.0001, maxRadius) * pulseFade * band(abs(dist - pulseRadius), halfWidth);
        for (int i = 0; i < EC_MAX_ECHOES; i++) {
            float delay = u_echoDelays[i];
            float radius = (delay - time) / EC_PULSE_SECONDS_PER_CELL * cell;
            float start = delay / EC_ECHO_SECONDS_PER_CELL * cell;
            float on = step(0.0001, delay) * step(0.0, radius) * step(radius, start);
            ring = max(ring, on * band(abs(dist - radius), halfWidth));
        }
        ring *= clamp(u_tier.x, 0.0, 1.0) * motion;
        float age = time - max(v_strike - EC_FACE_OFFSET, 0.0) * EC_PULSE_SECONDS_PER_CELL;
        float struck = step(0.0001, v_strike) * step(0.0, age);
        float flare = 1.0 - clamp(age / EC_FLARE_SECONDS, 0.0, 1.0);
        float trail = EC_TRAIL_WEIGHT * (1.0 - clamp(age / EC_TRAIL_SECONDS, 0.0, 1.0)) * clamp(u_tier.z, 0.0, 1.0);
        float flash = isEdge * struck * max(flare, trail) * clamp(u_tier.y, 0.0, 1.0) * motion;
        vec3 rgb = clamp(v_base, 0.0, 1.0) * light;
        rgb = mix(rgb, EC_FLARE, clamp(flash, 0.0, 1.0));
        rgb = mix(rgb, EC_FLARE, EC_WON_LIFT * v_won);
        rgb = mix(rgb, EC_PULSE, isRing);
        rgb = clamp(rgb, 0.0, 1.0);
        float alpha = clamp(mix(soft, ring, isRing), 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`) and the glow factor (`a_uv.x`).
    public static let glowVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec3 v_colour;
    out float v_glow;
    void main() {
        v_colour = clamp(a_normal, 0.0, 1.0);
        v_glow = clamp(a_uv.x, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glow fragment shader. Uniforms: `u_glowGain`, `u_glowLimit`. Gain ``glowGain(gain:limit:)``, colour and
    /// alpha ``glowColour(colour:glow:gain:)`` (a zero colour counts as the glow colour); premultiplied RGBA in
    /// 0 ... 1, drawn with additive blending.
    public static let glowFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_glow;
    uniform float u_glowGain;
    uniform float u_glowLimit;
    out vec4 color;
    const vec3 EC_GLOW = \(vec3Literal(EchoCartographerPalette.glow));
    const vec3 EC_FLARE = \(vec3Literal(EchoCartographerPalette.flare));
    const float EC_GLOW_WEIGHT = \(fixed(glowWeight));
    const float EC_CORE = \(fixed(coreLift));
    const float EC_MAX_GAIN = \(fixed(maxGlowGain));
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, EC_MAX_GAIN), clamp(u_glowLimit, 0.0, EC_MAX_GAIN));
        vec3 colour = mix(EC_GLOW, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        vec3 rgb = mix(colour, EC_FLARE, clamp(EC_CORE * gain * v_glow, 0.0, 1.0));
        float alpha = clamp(EC_GLOW_WEIGHT * gain * v_glow, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: EchoCartographerTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 ... ``maxGlowGain`` (non-finite
    /// counts as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow for a vertex `colour` (zero counts as the glow colour), glow factor `glow` and the applied `gain`,
    /// before premultiplying: the colour lifted toward the flare colour by ``coreLift`` gain glow (rgb) and the alpha
    /// ``glowWeight`` gain glow, every component clamped to 0 ... 1.
    public static func glowColour(colour: SIMD3<Double>, glow: Double, gain: Double) -> SIMD4<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 { c = EchoCartographerPalette.glow }
        let g: Double = unit(glow)
        let k: Double = gain.isFinite ? gain : 0
        let lift: Double = unit(coreLift * k * g)
        let lifted: SIMD3<Double> = c + (EchoCartographerPalette.flare - c) * lift
        return SIMD4<Double>(unit(lifted.x), unit(lifted.y), unit(lifted.z), unit(glowWeight * k * g))
    }

    /// The value the presenter passes as `u_tier` at `tier`: (rings, flares, trails), each 0 or 1. Flares are on
    /// whenever rings are (level-0 and level-1), trails only with `flareTrails` (level-0); level-2 is (0, 0, 0).
    public static func tierFlags(for tier: EchoCartographerTier) -> SIMD3<Double> {
        SIMD3<Double>(tier.rings ? 1 : 0, tier.rings ? 1 : 0, tier.rings && tier.flareTrails ? 1 : 0)
    }

    /// The echo delay in seconds of a beacon `distance` cells away: 24 ticks × 0.008333 s × distance.
    public static func echoDelay(distance: Int) -> Double {
        Double(max(distance, 0)) * echoSecondsPerCell
    }

    /// The value the presenter passes as `u_echoDelays` for `echo`: the delays of its first ``maxEchoes`` beacon
    /// distances, ascending, 0 in unused slots (all 0 without a pulse).
    public static func echoDelays(_ echo: EchoCartographerEcho?) -> SIMD4<Double> {
        var result: SIMD4<Double> = SIMD4<Double>(0, 0, 0, 0)
        guard let echo else { return result }
        let distances: [Int] = echo.beaconDistances.sorted()
        for index in 0..<min(distances.count, maxEchoes) where distances[index] > 0 {
            result[index] = echoDelay(distance: distances[index])
        }
        return result
    }

    /// The soft-edge coverage of local coordinate `local`: 1 - smoothstep(1 - ``edgeFeather``, 1, |local|), |local|
    /// clamped to 0 ... 1 (non-finite counts as the outline, 0 coverage).
    public static func edgeCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(1 - edgeFeather, 1, min(abs(local), 1))
    }

    /// The radius in world units of the pulse ring at `time` seconds: time / ``pulseSecondsPerCell`` cells of
    /// `cellSize`, capped at `maxRadius` (non-finite or negative inputs count as 0).
    public static func pulseRingRadius(time: Double, cellSize: Double, maxRadius: Double) -> Double {
        let t: Double = time.isFinite ? max(time, 0) : 0
        let s: Double = cellSize.isFinite ? max(cellSize, 0.0001) : 0.0001
        let r: Double = maxRadius.isFinite ? max(maxRadius, 0) : 0
        return min(t / pulseSecondsPerCell * s, r)
    }

    /// The pulse ring's fade 0 ... 1 at `time`: 1 until it reaches `maxRadius`, then falling linearly to 0 over
    /// ``pulseFadeSeconds``; 0 without a pulse (`maxRadius` 0).
    public static func pulseRingFade(time: Double, cellSize: Double, maxRadius: Double) -> Double {
        let t: Double = time.isFinite ? max(time, 0) : 0
        let s: Double = cellSize.isFinite ? max(cellSize, 0.0001) : 0.0001
        let r: Double = maxRadius.isFinite ? max(maxRadius, 0) : 0
        guard r >= 0.0001 else { return 0 }
        let reach: Double = r / s * pulseSecondsPerCell
        return 1 - min(max((t - reach) / pulseFadeSeconds, 0), 1)
    }

    /// The radius in world units of the echo ring with `delay` seconds at `time`, nil while it is not drawn: it
    /// appears at the beacon's distance (delay / ``echoSecondsPerCell`` cells) when the pulse ring passes it and
    /// shrinks one cell per ``pulseSecondsPerCell``, reaching the emitter (0) at `time` = `delay`. Nil for `delay` ≤ 0.
    public static func echoRingRadius(delay: Double, time: Double, cellSize: Double) -> Double? {
        guard delay.isFinite, delay >= 0.0001, time.isFinite else { return nil }
        let s: Double = cellSize.isFinite ? max(cellSize, 0.0001) : 0.0001
        let t: Double = max(time, 0)
        let radius: Double = (delay - t) / pulseSecondsPerCell * s
        let start: Double = delay / echoSecondsPerCell * s
        guard radius >= 0, radius <= start else { return nil }
        return radius
    }

    /// The flare weight 0 ... 1 of a wall edge strip struck at `strikeDistance` cells (0: not struck) at `time`, with
    /// the tier `flags` (``tierFlags(for:)``; pass (0, 0, 0) under Reduce Motion): from the moment the pulse ring
    /// reaches the face ((distance - ``faceOffset``) × ``pulseSecondsPerCell``) the flare falls linearly from 1 to 0
    /// over ``flareSeconds``, and with trails the larger of that and ``trailWeight`` falling over ``trailSeconds``.
    public static func flareWeight(strikeDistance: Double, time: Double, flags: SIMD3<Double>) -> Double {
        guard strikeDistance.isFinite, strikeDistance >= 0.0001, time.isFinite else { return 0 }
        let age: Double = max(time, 0) - max(strikeDistance - faceOffset, 0) * pulseSecondsPerCell
        guard age >= 0 else { return 0 }
        let flare: Double = 1 - min(max(age / flareSeconds, 0), 1)
        let trails: Double = min(max(flags.z, 0), 1)
        let trail: Double = trailWeight * (1 - min(max(age / trailSeconds, 0), 1)) * trails
        return min(max(max(flare, trail) * min(max(flags.y, 0), 1), 0), 1)
    }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
