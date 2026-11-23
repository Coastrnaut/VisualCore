// HarmonicBridgesShaders — feature 413 (R02-G12-03) T-R02G1203-003 (FR-R02G1203-001, 002, 004, 007; clarifications
// Q1–Q4). The two GLSL ES 3.00 programs of Harmonic Bridges held as source text (data: the core issues no GL call),
// with the names of every uniform they declare, their vertex attributes, the material codes shared with
// `HarmonicBridgesSceneGeometry`, the constants the sources are built from and the CPU references of what they compute.
//
// Bridge program: the mist ground, the island prisms' copper faces and bright top edge strips, the start ring, the goal
// star, the strings, the bridge membranes, the sample marks, the reached islands' glow rings, the radial wave shells,
// the step pips, the broken outline and the moves gauge. Vertex streams (the geometry's header states the same
// contract): `a_uv.x` is the material code (``HarmonicBridgesMaterial``: 0 ground, 1 island face, 2 island edge,
// 3 start ring, 4 goal star, 5 string, 6 membrane, 7 filled mark, 8 hollow mark, 9 glow ring, 10 wave shell, 11 pip,
// 12 unlit pip, 13 broken outline, 14 gauge lit, 15 gauge unlit) and `a_uv.y` the local edge coordinate d: on a fan
// (goal star, filled mark, pip, gauge bars: one centre vertex and the outline's corners) d is 0 at the centre and 1 on
// every outline vertex; on a strip or ring (island edge, start ring, string, membrane, hollow mark, glow ring, wave
// shell, unlit pip, broken outline) d is -1 on one long side, +1 on the other; on solids (ground, island face) d is 0.
// The signed-distance soft edge is 1 - smoothstep(1 - ``edgeFeather``, 1, |d|) (``edgeCoverage(local:)``), used as
// premultiplied coverage, so outlines are anti-aliased without textures; membranes are translucent in the middle and
// opaque at the rim (``membraneAlpha(local:won:)``).
//
// The normal slot `a_normal`: flat layers, pips, gauge, start ring and goal star (0, 1, 0); membranes and glow rings
// (0, 1, won), won 1 on a won level; island faces the outward face normal (the only lit material: ambient ``ambient``
// plus Lambert ``diffuse`` from the constant light ``lightDirection``), edge strips the normal of their face; wave
// carriers (string, filled mark, hollow mark, broken outline) (u, packed, θ): u the position 0 … 1 along the string (a
// mark's vertices share u = k / 6, so it moves rigidly), θ the angle of the unit sideways direction (cos θ, 0, sin θ)
// and packed = m0 + 24 m1 + 576 m2 with mi = 4 ni + wi for up to ``maxModes`` (3) resonant modes ni (1 … 5) of tone
// strength wi (1 … 3) in the shown step, 0 for a missing mode (``packModes(_:)``, ``unpackModes(_:)``); wave shells
// (centre.x, phase, centre.z), the resonating string's midpoint and the shell's phase k / 2. Every material other than
// island faces is emissive at its palette colour, so the colour cues hold under any light.
//
// Time effects, all driven by uniforms: `u_time` is the presentation time wrapped to one wave period
// (``wrappedTime(_:)``; every term below has a period dividing ``wavePeriod`` = 1.6 s, so wrapping changes nothing but
// keeps float precision). A wave carrier is displaced along (cos θ, 0, sin θ) by Σ ``waveAmplitude`` (0.01) · wi ·
// sin(ni π u) · cos(2π ni t / 1.6) (``waveDisplacement(u:time:packed:motion:)``), decoded from packed in the vertex
// shader by integer-safe float arithmetic in one loop bounded by the constant ``maxModes``. A wave shell vertex is
// moved from the centre along its own direction to radius fract(t / 1.6 + phase) · ``maxShellRadius`` + d ·
// ``shellHalfWidth`` (0 → 0.15 over ``shellSeconds`` = 1.6 s; ``shellRadius(time:phase:)``) and fades as it grows
// (``shellFade(time:phase:)``). `u_motion` is 1 when strings swing and 0 at level-2 and under Reduce Motion
// (``motion(for:reduceMotion:)``): 0 multiplies every displacement away and hides the shells. On a won level (the won
// flag of the streams) membranes and glow rings are lifted toward the filled-mark colour by ``wonLift`` and membranes
// become more opaque, at every tier.
//
// Glow program: the glow shells around membranes and reached islands, drawn additively. The colour is carried in
// `a_normal` (a zero colour falls back to the glow constant), `a_uv.x` is the glow factor 0 ... 1 and `a_uv.y` the won
// flag. The glow is the colour lifted toward the filled-mark colour by (``coreLift`` times the gain plus ``wonLift``
// times won) times the glow factor, with alpha ``glowWeight`` times the glow factor and gain; the gain is `u_glowGain`
// capped by `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing the presenter passes ``glowGainCap``
// as the limit, and the won lift never raises the alpha. The glow program has no time input: it never pulses.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1) from
// `Mesh.interleavedPositionNormal()` and `a_uv` (location 2) from `Mesh.uvs`. Every source starts with
// `#version 300 es` and states one float precision. Plain uniforms in the default block (at most 16 vec4 slots per
// program; the bridge program uses 6: u_mvp 4, u_time and u_motion 1 each; the glow program 6: u_mvp 4, u_glowGain and
// u_glowLimit), no texture samplers, no image assets, no `discard` and one loop, bounded by a constant. Output is
// premultiplied alpha. Palette constants are written with six fixed decimals from `HarmonicBridgesPalette`, so the
// shader colours equal the CPU's within 1e-6.

import Foundation

/// A bridge-program material code, written into `a_uv.x` of a bridge vertex (shared with
/// `HarmonicBridgesSceneGeometry`; feature 413, T-R02G1203-003).
public enum HarmonicBridgesMaterial: Int, Sendable, CaseIterable, Hashable {
    /// The mist ground plane (emissive; d = 0).
    case ground = 0
    /// An island prism's copper face (lit; d = 0; `a_normal` the face normal).
    case islandFace = 1
    /// An island prism's bright top edge strip (emissive; strip).
    case islandEdge = 2
    /// The ring around the start island (emissive; strip).
    case startRing = 3
    /// The four-pointed star around the goal island (emissive; fan).
    case goalStar = 4
    /// A string (emissive; strip; wave carrier).
    case string = 5
    /// A bridge membrane beneath a string (emissive, translucent middle; strip; won flag in `a_normal.z`).
    case membrane = 6
    /// A sample mark whose swing reaches the threshold: a filled square (emissive; fan; wave carrier).
    case markFilled = 7
    /// A sample mark short of the threshold: a hollow ring (emissive; strip; wave carrier).
    case markHollow = 8
    /// The glow ring of an island the start reaches in the shown step (emissive; strip; won flag in `a_normal.z`).
    case glowRing = 9
    /// A radial wave shell around a resonating string's midpoint (emissive; strip; moved and faded by the shader).
    case waveShell = 10
    /// The shown step's pip: a filled square (emissive; fan).
    case pip = 11
    /// Another step's pip: an outlined square (emissive; strip).
    case pipUnlit = 12
    /// The outline of the broken string (a wave carrier) or the frame and cross of the broken step's pip (packed 0, at
    /// rest) (emissive; strip).
    case brokenOutline = 13
    /// A lit moves-gauge bar, an action left (emissive; fan).
    case gaugeLit = 14
    /// An unlit moves-gauge bar, an action spent (emissive; fan).
    case gaugeUnlit = 15

    /// How the geometry fills `a_uv.y` for a material.
    public enum LocalCoordinate: Sendable, Hashable {
        /// A fan from a centre vertex (d = 0) to the outline's corners (d = 1).
        case fan
        /// A strip or ring: d = -1 on one long side (a ring's inner edge), +1 on the other.
        case strip
        /// No edge: d = 0 everywhere.
        case none
    }

    /// The `a_uv.x` value of the material.
    public var code: Double { Double(rawValue) }

    /// The material's palette colour as the bridge vertex shader selects it (before light, membrane and won lift).
    public var colour: SIMD3<Double> {
        switch self {
        case .ground: HarmonicBridgesPalette.ground
        case .islandFace: HarmonicBridgesPalette.islandFace
        case .islandEdge: HarmonicBridgesPalette.islandEdge
        case .startRing: HarmonicBridgesPalette.start
        case .goalStar: HarmonicBridgesPalette.goal
        case .string: HarmonicBridgesPalette.string
        case .membrane: HarmonicBridgesPalette.membrane
        case .markFilled: HarmonicBridgesPalette.markFilled
        case .markHollow: HarmonicBridgesPalette.markHollow
        case .glowRing: HarmonicBridgesPalette.glow
        case .waveShell: HarmonicBridgesPalette.shell
        case .pip: HarmonicBridgesPalette.pip
        case .pipUnlit: HarmonicBridgesPalette.pipUnlit
        case .brokenOutline: HarmonicBridgesPalette.brokenOutline
        case .gaugeLit: HarmonicBridgesPalette.gaugeLit
        case .gaugeUnlit: HarmonicBridgesPalette.gaugeUnlit
        }
    }

    /// Whether the material is lit (ambient plus Lambert) rather than emissive at its palette colour.
    public var isLit: Bool { self == .islandFace }

    /// Whether the material carries a wave address (u, packed, θ) in `a_normal` and swings with its string.
    public var carriesWave: Bool {
        switch self {
        case .string, .markFilled, .markHollow, .brokenOutline: true
        default: false
        }
    }

    /// Whether the material carries the won flag in `a_normal.z` and is lifted on a won level.
    public var carriesWon: Bool { self == .membrane || self == .glowRing }

    /// How the geometry fills `a_uv.y` for the material.
    public var localCoordinate: LocalCoordinate {
        switch self {
        case .goalStar, .markFilled, .pip, .gaugeLit, .gaugeUnlit: .fan
        case .islandEdge, .startRing, .string, .membrane, .markHollow, .glowRing, .waveShell, .pipUnlit,
             .brokenOutline: .strip
        case .ground, .islandFace: .none
        }
    }
}

/// The GLSL ES 3.00 sources of Harmonic Bridges' bridge and glow programs, their uniform and attribute names, the
/// constants they are built from and the CPU references of what they compute (FR-R02G1203-001, 002, 004, 007).
public enum HarmonicBridgesShaders {
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
    /// `float`: the presentation time wrapped to one wave period, ``wrappedTime(_:)`` (bridge, vertex stage).
    public static let timeUniform = "u_time"
    /// `float`: 1 when strings swing and wave shells run, 0 at level-2 and under Reduce Motion (bridge, vertex stage);
    /// see ``motion(for:reduceMotion:)``.
    public static let motionUniform = "u_motion"
    /// `float`: the glow gain (glow); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (glow): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the bridge program declares, each once, in order of declaration (vertex stage first).
    public static let bridgeUniforms: [String] = [mvpUniform, timeUniform, motionUniform]

    /// Every uniform the glow program declares, exactly as declared (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform]

    /// The uniform lists per program name (`bridge`, `glow`).
    public static let uniformNames: [String: [String]] = ["bridge": bridgeUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), one per palette entry.
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = [
        (name: "HB_GROUND", colour: HarmonicBridgesPalette.ground),
        (name: "HB_ISLAND_FACE", colour: HarmonicBridgesPalette.islandFace),
        (name: "HB_ISLAND_EDGE", colour: HarmonicBridgesPalette.islandEdge),
        (name: "HB_STRING", colour: HarmonicBridgesPalette.string),
        (name: "HB_MEMBRANE", colour: HarmonicBridgesPalette.membrane),
        (name: "HB_MARK_FILLED", colour: HarmonicBridgesPalette.markFilled),
        (name: "HB_MARK_HOLLOW", colour: HarmonicBridgesPalette.markHollow),
        (name: "HB_START", colour: HarmonicBridgesPalette.start),
        (name: "HB_GOAL", colour: HarmonicBridgesPalette.goal),
        (name: "HB_GLOW", colour: HarmonicBridgesPalette.glow),
        (name: "HB_SHELL", colour: HarmonicBridgesPalette.shell),
        (name: "HB_PIP", colour: HarmonicBridgesPalette.pip),
        (name: "HB_PIP_UNLIT", colour: HarmonicBridgesPalette.pipUnlit),
        (name: "HB_BROKEN", colour: HarmonicBridgesPalette.brokenOutline),
        (name: "HB_GAUGE_LIT", colour: HarmonicBridgesPalette.gaugeLit),
        (name: "HB_GAUGE_UNLIT", colour: HarmonicBridgesPalette.gaugeUnlit),
    ]

    /// The constant direction toward the light on island faces (normalised (0.3, 1, 0.5): above, right and toward the
    /// viewer), so the faces' shading never depends on a uniform.
    public static let lightDirection: SIMD3<Double> = {
        let v: SIMD3<Double> = SIMD3<Double>(0.3, 1.0, 0.5)
        let length: Double = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
        return v / length
    }()
    /// The bridge program's ambient term on island faces.
    public static let ambient: Double = 0.7
    /// The bridge program's Lambert weight on island faces (ambient + diffuse = 1).
    public static let diffuse: Double = 0.3
    /// The width of the soft edge as a share of the local coordinate: coverage falls from 1 at |d| = 1 - feather to 0
    /// at |d| = 1.
    public static let edgeFeather: Double = 0.15
    /// The most resonant modes per string (one per tone; the loop bound).
    public static let maxModes: Int = 3
    /// The base of the packed modes: mi = 4 ni + wi < 24, packed = m0 + 24 m1 + 576 m2.
    public static let packBase: Int = 24
    /// The largest packed value: 23 + 24 · 23 + 576 · 23.
    public static let maxPacked: Int = 24 * 24 * 24 - 1
    /// The highest resonant mode (`HarmonicBridgesSwing.maxMode`).
    public static let maxModeNumber: Int = HarmonicBridgesSwing.maxMode
    /// The sideways amplitude per unit of tone strength and mode (spec correction: 0.01 · w).
    public static let waveAmplitude: Double = 0.01
    /// The period in seconds of the slowest wave term and of a wave shell (clarification Q1, Q2).
    public static let wavePeriod: Double = 1.6
    /// The seconds a wave shell takes to grow from radius 0 to ``maxShellRadius`` (clarification Q2).
    public static let shellSeconds: Double = 1.6
    /// A wave shell's largest radius in world units (clarification Q2).
    public static let maxShellRadius: Double = 0.15
    /// Half a wave shell's line width (the line is 0.01 wide; clarification Q2).
    public static let shellHalfWidth: Double = 0.005
    /// A membrane's opacity in its middle; it rises to 1 at the rim (the translucent walkway).
    public static let membraneCoreAlpha: Double = 0.55
    /// Where across a membrane (|d|) the opaque rim begins.
    public static let membraneRim: Double = 0.55
    /// How far a won level lifts membranes, glow rings and the glow toward the filled-mark colour, at every tier and
    /// under Reduce Motion (the spec's edge case "every bridge of the path glows and every reached island is lit").
    public static let wonLift: Double = 0.4
    /// π with six decimals, as the sources write it.
    public static let pi: Double = 3.141593

    /// The alpha weight of the glow, times the glow gain and the glow factor of the vertex.
    public static let glowWeight: Double = 0.5
    /// How far the glow lifts a colour toward the filled-mark colour, times the glow gain and the glow factor.
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
    /// 0.5 of Hue Compass and Echo Cartographer).
    public static let glowGainCap: Double = 0.5

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The bridge vertex shader. Uniforms: `u_mvp`, `u_time`, `u_motion`. Selects the material colour from `a_uv.x`;
    /// displaces wave carriers by their decoded presentation wave and moves wave shells out to their radius (both zero
    /// or hidden when `u_motion` is 0); passes the normal, the material code, the local edge coordinate, the shell fade
    /// and the won flag of membranes and glow rings.
    public static let bridgeVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_time;
    uniform float u_motion;
    out vec3 v_normal;
    out vec3 v_base;
    out float v_material;
    out float v_local;
    out float v_fade;
    out float v_won;
    const vec3 HB_GROUND = \(vec3Literal(HarmonicBridgesPalette.ground));
    const vec3 HB_ISLAND_FACE = \(vec3Literal(HarmonicBridgesPalette.islandFace));
    const vec3 HB_ISLAND_EDGE = \(vec3Literal(HarmonicBridgesPalette.islandEdge));
    const vec3 HB_START = \(vec3Literal(HarmonicBridgesPalette.start));
    const vec3 HB_GOAL = \(vec3Literal(HarmonicBridgesPalette.goal));
    const vec3 HB_STRING = \(vec3Literal(HarmonicBridgesPalette.string));
    const vec3 HB_MEMBRANE = \(vec3Literal(HarmonicBridgesPalette.membrane));
    const vec3 HB_MARK_FILLED = \(vec3Literal(HarmonicBridgesPalette.markFilled));
    const vec3 HB_MARK_HOLLOW = \(vec3Literal(HarmonicBridgesPalette.markHollow));
    const vec3 HB_GLOW = \(vec3Literal(HarmonicBridgesPalette.glow));
    const vec3 HB_SHELL = \(vec3Literal(HarmonicBridgesPalette.shell));
    const vec3 HB_PIP = \(vec3Literal(HarmonicBridgesPalette.pip));
    const vec3 HB_PIP_UNLIT = \(vec3Literal(HarmonicBridgesPalette.pipUnlit));
    const vec3 HB_BROKEN = \(vec3Literal(HarmonicBridgesPalette.brokenOutline));
    const vec3 HB_GAUGE_LIT = \(vec3Literal(HarmonicBridgesPalette.gaugeLit));
    const vec3 HB_GAUGE_UNLIT = \(vec3Literal(HarmonicBridgesPalette.gaugeUnlit));
    const int HB_MAX_MODES = \(maxModes);
    const float HB_PACK_BASE = \(fixed(Double(packBase)));
    const float HB_MAX_PACKED = \(fixed(Double(maxPacked)));
    const float HB_MAX_MODE = \(fixed(Double(maxModeNumber)));
    const float HB_PI = \(fixed(pi));
    const float HB_WAVE_AMPLITUDE = \(fixed(waveAmplitude));
    const float HB_WAVE_PERIOD = \(fixed(wavePeriod));
    const float HB_SHELL_SECONDS = \(fixed(shellSeconds));
    const float HB_SHELL_RADIUS = \(fixed(maxShellRadius));
    const float HB_SHELL_HALF_WIDTH = \(fixed(shellHalfWidth));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, 15.0);
        vec3 base = mix(HB_GROUND, HB_ISLAND_FACE, isCode(m, 1.0));
        base = mix(base, HB_ISLAND_EDGE, isCode(m, 2.0));
        base = mix(base, HB_START, isCode(m, 3.0));
        base = mix(base, HB_GOAL, isCode(m, 4.0));
        base = mix(base, HB_STRING, isCode(m, 5.0));
        base = mix(base, HB_MEMBRANE, isCode(m, 6.0));
        base = mix(base, HB_MARK_FILLED, isCode(m, 7.0));
        base = mix(base, HB_MARK_HOLLOW, isCode(m, 8.0));
        base = mix(base, HB_GLOW, isCode(m, 9.0));
        base = mix(base, HB_SHELL, isCode(m, 10.0));
        base = mix(base, HB_PIP, isCode(m, 11.0));
        base = mix(base, HB_PIP_UNLIT, isCode(m, 12.0));
        base = mix(base, HB_BROKEN, isCode(m, 13.0));
        base = mix(base, HB_GAUGE_LIT, isCode(m, 14.0));
        base = mix(base, HB_GAUGE_UNLIT, isCode(m, 15.0));
        float carrier = clamp(isCode(m, 5.0) + isCode(m, 7.0) + isCode(m, 8.0) + isCode(m, 13.0), 0.0, 1.0);
        float isShell = isCode(m, 10.0);
        float motion = clamp(u_motion, 0.0, 1.0);
        float t = max(u_time, 0.0);
        float u = clamp(a_normal.x, 0.0, 1.0);
        float packed = clamp(floor(a_normal.y + 0.5), 0.0, HB_MAX_PACKED) * carrier;
        float wave = 0.0;
        for (int k = 0; k < HB_MAX_MODES; k++) {
            float rest = floor((packed + 0.5) / HB_PACK_BASE);
            float mode = packed - rest * HB_PACK_BASE;
            packed = rest;
            float n = floor((mode + 0.5) / 4.0);
            float w = mode - n * 4.0;
            n = clamp(n, 0.0, HB_MAX_MODE);
            wave += HB_WAVE_AMPLITUDE * w * sin(n * HB_PI * u) * cos(2.0 * HB_PI * n * t / HB_WAVE_PERIOD);
        }
        vec3 side = vec3(cos(a_normal.z), 0.0, sin(a_normal.z));
        vec3 position = a_position + side * wave * carrier * motion;
        vec2 centre = vec2(a_normal.x, a_normal.z);
        vec2 away = a_position.xz - centre;
        vec2 direction = away / max(length(away), 0.0001);
        float progress = fract(t / HB_SHELL_SECONDS + clamp(a_normal.y, 0.0, 1.0));
        float radius = max(HB_SHELL_RADIUS * progress + clamp(a_uv.y, -1.0, 1.0) * HB_SHELL_HALF_WIDTH, 0.0);
        vec3 shell = vec3(centre.x + direction.x * radius, a_position.y, centre.y + direction.y * radius);
        position = mix(position, shell, isShell);
        v_base = base;
        v_normal = a_normal;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0);
        v_fade = mix(1.0, (1.0 - progress) * motion, isShell);
        v_won = clamp(a_normal.z, 0.0, 1.0) * clamp(isCode(m, 6.0) + isCode(m, 9.0), 0.0, 1.0);
        gl_Position = u_mvp * vec4(position, 1.0);
    }
    """

    /// The bridge fragment shader (no uniforms). Ambient ``ambient`` plus Lambert ``diffuse`` from ``lightDirection``
    /// on island faces, the palette colour on the others; soft edges from the local coordinate
    /// (``edgeCoverage(local:)``); translucent membranes (``membraneAlpha(local:won:)``); the won lift on membranes and
    /// glow rings; the shell fade. Premultiplied.
    public static let bridgeFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_base;
    in float v_material;
    in float v_local;
    in float v_fade;
    in float v_won;
    out vec4 color;
    const vec3 HB_MARK_FILLED = \(vec3Literal(HarmonicBridgesPalette.markFilled));
    const vec3 HB_LIGHT = \(vec3Literal(lightDirection));
    const float HB_AMBIENT = \(fixed(ambient));
    const float HB_DIFFUSE = \(fixed(diffuse));
    const float HB_EDGE_FEATHER = \(fixed(edgeFeather));
    const float HB_MEMBRANE_ALPHA = \(fixed(membraneCoreAlpha));
    const float HB_MEMBRANE_RIM = \(fixed(membraneRim));
    const float HB_WON_LIFT = \(fixed(wonLift));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = floor(v_material + 0.5);
        float isLit = isCode(m, 1.0);
        float isMembrane = isCode(m, 6.0);
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        float lambert = max(dot(n, HB_LIGHT), 0.0);
        float light = mix(1.0, HB_AMBIENT + HB_DIFFUSE * lambert, isLit);
        float d = clamp(abs(v_local), 0.0, 1.0);
        float soft = 1.0 - smoothstep(1.0 - HB_EDGE_FEATHER, 1.0, d);
        float won = clamp(v_won, 0.0, 1.0);
        float rim = smoothstep(HB_MEMBRANE_RIM, 1.0 - HB_EDGE_FEATHER, d);
        float membrane = mix(mix(HB_MEMBRANE_ALPHA, 1.0, rim), 1.0, HB_WON_LIFT * won);
        vec3 rgb = clamp(v_base, 0.0, 1.0) * light;
        rgb = mix(rgb, HB_MARK_FILLED, HB_WON_LIFT * won);
        rgb = clamp(rgb, 0.0, 1.0);
        float alpha = clamp(soft * mix(1.0, membrane, isMembrane) * clamp(v_fade, 0.0, 1.0), 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`), the glow factor (`a_uv.x`) and the won
    /// flag (`a_uv.y`).
    public static let glowVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec3 v_colour;
    out float v_glow;
    out float v_won;
    void main() {
        v_colour = clamp(a_normal, 0.0, 1.0);
        v_glow = clamp(a_uv.x, 0.0, 1.0);
        v_won = clamp(a_uv.y, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glow fragment shader. Uniforms: `u_glowGain`, `u_glowLimit`. Gain ``glowGain(gain:limit:)``, colour and
    /// alpha ``glowColour(colour:glow:gain:won:)`` (a zero colour counts as the glow colour); premultiplied RGBA in
    /// 0 ... 1, drawn with additive blending.
    public static let glowFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_glow;
    in float v_won;
    uniform float u_glowGain;
    uniform float u_glowLimit;
    out vec4 color;
    const vec3 HB_GLOW = \(vec3Literal(HarmonicBridgesPalette.glow));
    const vec3 HB_MARK_FILLED = \(vec3Literal(HarmonicBridgesPalette.markFilled));
    const float HB_GLOW_WEIGHT = \(fixed(glowWeight));
    const float HB_CORE = \(fixed(coreLift));
    const float HB_WON_LIFT = \(fixed(wonLift));
    const float HB_MAX_GAIN = \(fixed(maxGlowGain));
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, HB_MAX_GAIN), clamp(u_glowLimit, 0.0, HB_MAX_GAIN));
        float won = clamp(v_won, 0.0, 1.0);
        vec3 colour = mix(HB_GLOW, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        vec3 rgb = mix(colour, HB_MARK_FILLED, clamp((HB_CORE * gain + HB_WON_LIFT * won) * v_glow, 0.0, 1.0));
        float alpha = clamp(HB_GLOW_WEIGHT * gain * v_glow, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The value the presenter passes as `u_motion`: 1 when the tier swings strings and Reduce Motion is off, else 0.
    public static func motion(for tier: HarmonicBridgesTier, reduceMotion: Bool) -> Double {
        tier.motion && !reduceMotion ? 1 : 0
    }

    /// The value the presenter passes as `u_time`: `time` modulo ``wavePeriod`` (non-finite or negative counts as 0).
    /// Every wave term and shell has a period dividing 1.6 s, so the drawn image is unchanged.
    public static func wrappedTime(_ time: Double) -> Double {
        guard time.isFinite, time > 0 else { return 0 }
        let wrapped: Double = time.truncatingRemainder(dividingBy: wavePeriod)
        return wrapped >= 0 ? wrapped : 0
    }

    /// The packed modes of up to ``maxModes`` (mode, strength) pairs in tone order: m0 + 24 m1 + 576 m2 with
    /// mi = 4 ni + wi (ni clamped to 0 … 5, wi to 0 … 3), as the geometry's `packModes` writes them.
    public static func packModes(_ pairs: [(mode: Int, strength: Int)]) -> Double {
        var packed: Int = 0
        var scale: Int = 1
        for i in 0..<min(pairs.count, maxModes) {
            let n: Int = min(max(pairs[i].mode, 0), maxModeNumber)
            let w: Int = min(max(pairs[i].strength, 0), 3)
            packed += (4 * n + w) * scale
            scale *= packBase
        }
        return Double(packed)
    }

    /// The ``maxModes`` (mode, strength) pairs a packed value encodes, as the vertex shader decodes it (the value
    /// rounded to a whole number and clamped to 0 … ``maxPacked``; (0, 0) for a missing mode).
    public static func unpackModes(_ packed: Double) -> [(mode: Int, strength: Int)] {
        var rest: Int = packed.isFinite ? min(max(Int((packed + 0.5).rounded(.down)), 0), maxPacked) : 0
        var result: [(mode: Int, strength: Int)] = []
        for _ in 0..<maxModes {
            let m: Int = rest % packBase
            rest /= packBase
            result.append((mode: min(m / 4, maxModeNumber), strength: m % 4))
        }
        return result
    }

    /// The sideways displacement of a wave carrier at `u` (0 … 1 along its string) and wrapped time `time` for its
    /// packed modes: Σ ``waveAmplitude`` · w · sin(nπu) · cos(2π n t / ``wavePeriod``), times `motion` (0 … 1). Bounded
    /// by 0.01 · 9 = 0.09 in magnitude (three tones of strength 3).
    public static func waveDisplacement(u: Double, time: Double, packed: Double, motion: Double) -> Double {
        let uu: Double = u.isFinite ? min(max(u, 0), 1) : 0
        let t: Double = time.isFinite ? max(time, 0) : 0
        let m: Double = motion.isFinite ? min(max(motion, 0), 1) : 0
        var sum: Double = 0
        for pair in unpackModes(packed) {
            let n: Double = Double(pair.mode)
            let w: Double = Double(pair.strength)
            sum += waveAmplitude * w * sin(n * Double.pi * uu) * cos(2 * Double.pi * n * t / wavePeriod)
        }
        return sum * m
    }

    /// The radius of a wave shell with `phase` at wrapped time `time`: ``maxShellRadius`` times the fraction of its
    /// period elapsed (0 at the start of each period, approaching 0.15 at its end).
    public static func shellRadius(time: Double, phase: Double) -> Double {
        maxShellRadius * shellProgress(time: time, phase: phase)
    }

    /// The opacity of a wave shell with `phase` at wrapped time `time`: 1 minus its progress (it fades as it grows).
    public static func shellFade(time: Double, phase: Double) -> Double {
        1 - shellProgress(time: time, phase: phase)
    }

    /// Where the vertex shader draws a wave shell vertex at `vertex` with local coordinate `local` around `centre`
    /// (world x, z) at wrapped time `time`: moved from the centre along its own direction to
    /// ``shellRadius(time:phase:)`` + `local` · ``shellHalfWidth`` (never below 0), keeping its height.
    public static func shellPosition(vertex: SIMD3<Double>, centre: SIMD2<Double>, local: Double, time: Double,
                                     phase: Double) -> SIMD3<Double> {
        let away: SIMD2<Double> = SIMD2<Double>(vertex.x - centre.x, vertex.z - centre.y)
        let length: Double = max((away.x * away.x + away.y * away.y).squareRoot(), 0.0001)
        let d: Double = local.isFinite ? min(max(local, -1), 1) : 0
        let radius: Double = max(shellRadius(time: time, phase: phase) + d * shellHalfWidth, 0)
        return SIMD3<Double>(centre.x + away.x / length * radius, vertex.y, centre.y + away.y / length * radius)
    }

    /// fract(time / ``shellSeconds`` + phase), as the vertex shader computes it.
    static func shellProgress(time: Double, phase: Double) -> Double {
        let t: Double = time.isFinite ? max(time, 0) : 0
        let p: Double = phase.isFinite ? min(max(phase, 0), 1) : 0
        let x: Double = t / shellSeconds + p
        return x - x.rounded(.down)
    }

    /// The soft-edge coverage of local coordinate `local`: 1 - smoothstep(1 - ``edgeFeather``, 1, |local|), |local|
    /// clamped to 0 ... 1 (non-finite counts as the outline, 0 coverage).
    public static func edgeCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(1 - edgeFeather, 1, min(abs(local), 1))
    }

    /// A membrane's opacity before the soft edge at `local`: ``membraneCoreAlpha`` in the middle rising to 1 at the
    /// rim, then lifted toward 1 by ``wonLift`` on a won level.
    public static func membraneAlpha(local: Double, won: Bool) -> Double {
        let d: Double = local.isFinite ? min(abs(local), 1) : 1
        let rim: Double = smoothstep(membraneRim, 1 - edgeFeather, d)
        let alpha: Double = membraneCoreAlpha + (1 - membraneCoreAlpha) * rim
        return won ? alpha + (1 - alpha) * wonLift : alpha
    }

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: HarmonicBridgesTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 ... ``maxGlowGain`` (non-finite
    /// counts as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow for a vertex `colour` (zero counts as the glow colour), glow factor `glow`, the applied `gain` and the
    /// won flag, before premultiplying: the colour lifted toward the filled-mark colour by (``coreLift`` gain +
    /// ``wonLift`` won) glow (rgb) and the alpha ``glowWeight`` gain glow, every component clamped to 0 ... 1.
    public static func glowColour(colour: SIMD3<Double>, glow: Double, gain: Double, won: Bool) -> SIMD4<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 { c = HarmonicBridgesPalette.glow }
        let g: Double = unit(glow)
        let k: Double = gain.isFinite ? gain : 0
        let lift: Double = unit((coreLift * k + (won ? wonLift : 0)) * g)
        let lifted: SIMD3<Double> = c + (HarmonicBridgesPalette.markFilled - c) * lift
        return SIMD4<Double>(unit(lifted.x), unit(lifted.y), unit(lifted.z), unit(glowWeight * k * g))
    }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
