// AcousticConstellatorShaders — feature 423 (R02-G13-03) T-R02G1303-003 (FR-R02G1303-001, 002, 004, 007;
// clarifications Q1–Q5). The two GLSL ES 3.00 programs of Acoustic Constellator held as source text (data: the core
// issues no GL call), with the names of every uniform they declare, their vertex attributes, the material codes shared
// with `AcousticConstellatorSceneGeometry`, the constants the sources are built from and the CPU references of what
// they compute. Presentation only: no rule is ever evaluated on these Doubles.
//
// Constellation program: the sky, the dashed guides, the links, the broken outline, the stars, the phase hands, the
// coherence gauge and its threshold mark, the hold pips and the moves gauge. Vertex streams (the geometry's header
// states the same contract): `a_uv.x` is the material code (``AcousticConstellatorMaterial``: 0 sky, 1 guide,
// 2 silver link, 3 teal link, 4 broken, 5 star, 6 hand, 7 coherence lit, 8 coherence unlit, 9 threshold mark,
// 10 hold lit, 11 hold unlit, 12 moves lit, 13 moves unlit, 14 won link) and `a_uv.y` the local coordinate d: on a
// strip (guide dash, silver, teal, broken and won link, hand, threshold mark, unlit hold pip outline) d is -1 on one
// long side, +1 on the other; on a fan (coherence bars, lit hold pip, moves bars: one centre vertex and the outline's
// corners) d is 0 at the centre and 1 on every outline vertex; on the sky d is 0; on a star `a_uv.y` is the star index
// 0 … 7 instead (an ellipsoid has no edge). The signed-distance soft edge is 1 - smoothstep(1 - ``edgeFeather``, 1, |d|)
// (``edgeCoverage(local:)``), used as premultiplied coverage, so every strip and fan is anti-aliased without textures.
//
// The normal slot `a_normal`: every flat material (0, 1, 0); a star vertex the unit-sphere direction s of the vertex
// (cos lat cos lon, sin lat, cos lat sin lon), not the ellipsoid normal: the vertex sits at centre + ``starRadii`` ⊙ s
// (``starOffset(direction:)``), drawn unpulsed by the geometry. The vertex shader recovers the offset from s, scales it
// by the pulse and shades the star with the true normal s ⊘ ``starRadii`` (ambient ``ambient`` plus Lambert ``diffuse``
// from the constant light ``lightDirection``); every other material is emissive at its palette colour, so the colour
// cues hold under any light. A won level draws every symbol link with the won-link code: teal lifted toward the glow
// colour by ``wonLift`` (``wonLinkColour``), at every tier, in place.
//
// The star pulse, driven by uniforms: `u_phasesLow` and `u_phasesHigh` (two vec4, not an array, so the shared
// `ShaderProgram` setters suffice) hold the phase 0 … 11 of stars 0 … 7 at the shown tick (lane i % 4 of row i / 4;
// ``phaseUniform(_:)``) and `u_pulse` is 1 when stars pulse, 0 at level-2 and under Reduce
// Motion (``pulse(for:reduceMotion:)``). A star vertex moves to centre + offset · (1 + ``pulseAmplitude`` · pulse ·
// cos(2π · phase / 12)) (``pulseScale(phase:pulse:)``): 1 ± 0.15; 0 leaves the geometry unchanged. The phase is read
// with constant indices only (no dynamic indexing).
//
// Glow program: the glow shells around teal links and stars and the radial wave shells, drawn additively. The colour is
// carried in `a_normal` (a zero colour falls back to the glow colour, or the shell colour for a wave shell), `a_uv.x`
// is 2 · kind + factor (``AcousticConstellatorGlowKind``: 0 glow shell, 1 won symbol link's glow shell, 2 wave shell;
// factor the glow factor 0 … 1; ``AcousticConstellatorGlowKind/code(factor:)``) and `a_uv.y` the wave shell's age
// 0 … 1 (0 on glow shells). The geometry places a wave shell at radius ``maxWaveShellRadius`` · age (0 → 0.12 over
// ``waveShellSeconds`` = 1 s; ``waveShellAge(seconds:index:count:)``, ``waveShellRadius(age:)``) and the shader fades
// it as it expands: alpha times 1 - age. The glow is the colour lifted toward the star colour by (``coreLift`` times
// the gain plus ``wonLift`` on a won link) times the factor, with alpha ``glowWeight`` times factor, gain and fade; the
// gain is `u_glowGain` capped by `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing the presenter
// passes ``glowGainCap`` as the limit, and the won lift never raises the alpha. The glow program has no time input.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1) from
// `Mesh.interleavedPositionNormal()` and `a_uv` (location 2) from `Mesh.uvs`. Every source starts with
// `#version 300 es` and states one float precision. Plain uniforms in the default block (at most 16 vec4 slots per
// program; the constellation program uses 7: u_mvp 4, u_phasesLow 1, u_phasesHigh 1, u_pulse 1; the glow program 6: u_mvp 4, u_glowGain
// and u_glowLimit 1 each), no texture samplers, no image assets, no `discard` and no loops. Output is premultiplied
// alpha. Palette constants are written with six fixed decimals from `AcousticConstellatorPalette`, so the shader
// colours equal the CPU's within 1e-6.

import Foundation

/// A constellation-program material code, written into `a_uv.x` of a constellation vertex (shared with
/// `AcousticConstellatorSceneGeometry`; feature 423, T-R02G1303-003).
public enum AcousticConstellatorMaterial: Int, Sendable, CaseIterable, Hashable {
    /// The night sky plane (emissive; d = 0).
    case sky = 0
    /// A dash of the guide of an unlinked symbol pair (emissive; strip).
    case guide = 1
    /// A link whose gap at the shown tick is above 1 (emissive; strip).
    case silverLink = 2
    /// A link whose gap at the shown tick is at most 1 (emissive; strip).
    case tealLink = 3
    /// The outline of a missing pair's guide or of a snapped link after a failure (emissive; strip).
    case broken = 4
    /// A star ellipsoid (lit; `a_uv.y` the star index 0 … 7; `a_normal` the unit-sphere direction; pulsed by uniforms).
    case star = 5
    /// A star's phase hand (emissive; strip).
    case hand = 6
    /// A lit coherence bar (emissive; fan).
    case coherenceLit = 7
    /// An unlit coherence bar (emissive; fan).
    case coherenceUnlit = 8
    /// The threshold mark over the coherence gauge (emissive; strip).
    case thresholdMark = 9
    /// A lit hold pip, part of the current coherent run (emissive; fan).
    case holdLit = 10
    /// An unlit hold pip: an outlined square (emissive; strip).
    case holdUnlit = 11
    /// A lit moves bar, an action left (emissive; fan).
    case movesLit = 12
    /// An unlit moves bar, an action spent (emissive; fan).
    case movesUnlit = 13
    /// A symbol link on a won level: teal lifted toward the glow colour (emissive; strip).
    case wonLink = 14

    /// How the geometry fills `a_uv.y` for a material.
    public enum LocalCoordinate: Sendable, Hashable {
        /// A fan from a centre vertex (d = 0) to the outline's corners (d = 1).
        case fan
        /// A strip or ring: d = -1 on one long side, +1 on the other.
        case strip
        /// No edge: d = 0 everywhere.
        case none
        /// Not a local coordinate: the star index 0 … ``AcousticConstellatorShaders/maxStars`` - 1.
        case starIndex
    }

    /// The `a_uv.x` value of the material.
    public var code: Double { Double(rawValue) }

    /// The material's colour as the constellation vertex shader selects it (before the star light).
    public var colour: SIMD3<Double> {
        switch self {
        case .sky: AcousticConstellatorPalette.sky
        case .guide: AcousticConstellatorPalette.guide
        case .silverLink: AcousticConstellatorPalette.silver
        case .tealLink: AcousticConstellatorPalette.teal
        case .broken: AcousticConstellatorPalette.broken
        case .star: AcousticConstellatorPalette.star
        case .hand: AcousticConstellatorPalette.hand
        case .coherenceLit: AcousticConstellatorPalette.coherenceLit
        case .coherenceUnlit: AcousticConstellatorPalette.coherenceUnlit
        case .thresholdMark: AcousticConstellatorPalette.thresholdMark
        case .holdLit: AcousticConstellatorPalette.holdLit
        case .holdUnlit: AcousticConstellatorPalette.holdUnlit
        case .movesLit: AcousticConstellatorPalette.movesLit
        case .movesUnlit: AcousticConstellatorPalette.movesUnlit
        case .wonLink: AcousticConstellatorShaders.wonLinkColour
        }
    }

    /// Whether the material is lit (ambient plus Lambert) rather than emissive at its colour.
    public var isLit: Bool { self == .star }

    /// Whether the material's vertices move with the star pulse.
    public var pulses: Bool { self == .star }

    /// How the geometry fills `a_uv.y` for the material.
    public var localCoordinate: LocalCoordinate {
        switch self {
        case .coherenceLit, .coherenceUnlit, .holdLit, .movesLit, .movesUnlit: .fan
        case .guide, .silverLink, .tealLink, .broken, .hand, .thresholdMark, .holdUnlit, .wonLink: .strip
        case .sky: .none
        case .star: .starIndex
        }
    }
}

/// A glow-program vertex kind, encoded with the glow factor into `a_uv.x` as 2 · kind + factor (feature 423,
/// T-R02G1303-003).
public enum AcousticConstellatorGlowKind: Int, Sendable, CaseIterable, Hashable {
    /// A glow shell around a teal link or a star.
    case glow = 0
    /// A glow shell around a symbol link on a won level: lifted toward the star colour by
    /// ``AcousticConstellatorShaders/wonLift``.
    case wonGlow = 1
    /// A radial wave shell: faded by its age in `a_uv.y` (alpha times 1 - age).
    case waveShell = 2

    /// The `a_uv.x` value of a vertex of this kind with glow factor `factor` (clamped to 0 … 1; non-finite counts as 0).
    public func code(factor: Double) -> Double {
        let f: Double = factor.isFinite ? min(max(factor, 0), 1) : 0
        return Double(2 * rawValue) + f
    }

    /// The (kind, factor) the glow vertex shader decodes from `a_uv.x`: kind ⌊x / 2⌋ clamped to 0 … 2, factor x - 2 ·
    /// kind clamped to 0 … 1 (x clamped to 0 … 5; non-finite counts as 0).
    public static func decode(_ x: Double) -> (kind: AcousticConstellatorGlowKind, factor: Double) {
        let v: Double = x.isFinite ? min(max(x, 0), 5) : 0
        let k: Int = min(max(Int((v * 0.5).rounded(.down)), 0), 2)
        let factor: Double = min(max(v - Double(2 * k), 0), 1)
        return (kind: AcousticConstellatorGlowKind(rawValue: k) ?? .glow, factor: factor)
    }
}

/// The GLSL ES 3.00 sources of Acoustic Constellator's constellation and glow programs, their uniform and attribute
/// names, the constants they are built from and the CPU references of what they compute (FR-R02G1303-001, 002, 004,
/// 007).
public enum AcousticConstellatorShaders {
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
    /// `vec4`: the phase 0 … 11 of stars 0 … 3 at the shown tick, star i in lane i, unused lanes 0 (constellation,
    /// vertex stage); row 0 of ``phaseUniform(_:)``.
    public static let phasesLowUniform = "u_phasesLow"
    /// `vec4`: the phase 0 … 11 of stars 4 … 7 at the shown tick, star i in lane i − 4, unused lanes 0
    /// (constellation, vertex stage); row 1 of ``phaseUniform(_:)``.
    public static let phasesHighUniform = "u_phasesHigh"
    /// The phase uniforms by row of ``phaseUniform(_:)``: ``phasesLowUniform``, ``phasesHighUniform``.
    public static let phaseRowUniforms: [String] = [phasesLowUniform, phasesHighUniform]
    /// `float`: 1 when stars pulse, 0 at level-2 and under Reduce Motion (constellation, vertex stage); see
    /// ``pulse(for:reduceMotion:)``.
    public static let pulseUniform = "u_pulse"
    /// `float`: the glow gain (glow); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (glow): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the constellation program declares, each once, in order of declaration (vertex stage first).
    public static let constellationUniforms: [String] = [mvpUniform, phasesLowUniform, phasesHighUniform, pulseUniform]

    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform]

    /// The uniform lists per program name (`constellation`, `glow`).
    public static let uniformNames: [String: [String]] = ["constellation": constellationUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), one per palette entry.
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = [
        (name: "AC_SKY", colour: AcousticConstellatorPalette.sky),
        (name: "AC_STAR", colour: AcousticConstellatorPalette.star),
        (name: "AC_HAND", colour: AcousticConstellatorPalette.hand),
        (name: "AC_SILVER", colour: AcousticConstellatorPalette.silver),
        (name: "AC_TEAL", colour: AcousticConstellatorPalette.teal),
        (name: "AC_GUIDE", colour: AcousticConstellatorPalette.guide),
        (name: "AC_BROKEN", colour: AcousticConstellatorPalette.broken),
        (name: "AC_COHERENCE_LIT", colour: AcousticConstellatorPalette.coherenceLit),
        (name: "AC_COHERENCE_UNLIT", colour: AcousticConstellatorPalette.coherenceUnlit),
        (name: "AC_THRESHOLD_MARK", colour: AcousticConstellatorPalette.thresholdMark),
        (name: "AC_HOLD_LIT", colour: AcousticConstellatorPalette.holdLit),
        (name: "AC_HOLD_UNLIT", colour: AcousticConstellatorPalette.holdUnlit),
        (name: "AC_MOVES_LIT", colour: AcousticConstellatorPalette.movesLit),
        (name: "AC_MOVES_UNLIT", colour: AcousticConstellatorPalette.movesUnlit),
        (name: "AC_SHELL", colour: AcousticConstellatorPalette.shell),
        (name: "AC_GLOW", colour: AcousticConstellatorPalette.glow),
    ]

    /// The most stars a level has (`AcousticConstellatorLevel.starCounts.upperBound`), the lanes of the phase uniforms.
    public static let maxStars: Int = 8
    /// The vec4 phase uniforms (``maxStars`` / 4): ``phaseRowUniforms``.
    public static let phaseRows: Int = 2
    /// The phase steps on the clock (`AcousticConstellatorClock.steps`).
    public static let clockSteps: Int = 12
    /// The pulse amplitude: a star is drawn at scale 1 + 0.15 · cos(2π · phase / 12) (clarification Q2).
    public static let pulseAmplitude: Double = 0.15
    /// A star ellipsoid's radii in world units (x, y, z) (clarification Q1).
    public static let starRadii: SIMD3<Double> = SIMD3<Double>(0.045, 0.035, 0.045)
    /// The constant direction toward the light on stars (normalised (0.3, 1, 0.5): above, right and toward the viewer),
    /// so the stars' shading never depends on a uniform.
    public static let lightDirection: SIMD3<Double> = {
        let v: SIMD3<Double> = SIMD3<Double>(0.3, 1.0, 0.5)
        let length: Double = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
        return v / length
    }()
    /// The constellation program's ambient term on stars.
    public static let ambient: Double = 0.8
    /// The constellation program's Lambert weight on stars (ambient + diffuse = 1).
    public static let diffuse: Double = 0.2
    /// The width of the soft edge as a share of the local coordinate: coverage falls from 1 at |d| = 1 - feather to 0
    /// at |d| = 1.
    public static let edgeFeather: Double = 0.15
    /// How far a won level lifts the symbol links toward the glow colour and their glow toward the star colour, at every
    /// tier and under Reduce Motion (the spec's edge case "every symbol link glows teal").
    public static let wonLift: Double = 0.4
    /// π with six decimals, as the sources write it.
    public static let pi: Double = 3.141593

    /// The seconds a wave shell takes to grow from radius 0 to ``maxWaveShellRadius`` (clarification Q2).
    public static let waveShellSeconds: Double = 1.0
    /// A wave shell's largest radius in world units (clarification Q2).
    public static let maxWaveShellRadius: Double = 0.12
    /// Half a wave shell's line width (the ring is 0.01 wide; clarification Q2).
    public static let waveShellHalfWidth: Double = 0.005

    /// The alpha weight of the glow, times the glow gain, the glow factor and the wave-shell fade.
    public static let glowWeight: Double = 0.5
    /// How far the glow lifts a colour toward the star colour, times the glow gain and the glow factor.
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
    /// 0.5 of Harmonic Bridges, Hue Compass and Echo Cartographer).
    public static let glowGainCap: Double = 0.5

    /// The won-link colour: teal lifted toward the glow colour by ``wonLift``, as the vertex shader mixes it.
    public static let wonLinkColour: SIMD3<Double> =
        AcousticConstellatorPalette.teal + (AcousticConstellatorPalette.glow - AcousticConstellatorPalette.teal) * wonLift

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The constellation vertex shader. Uniforms: `u_mvp`, `u_phasesLow`, `u_phasesHigh`, `u_pulse`. Selects the material colour from
    /// `a_uv.x` (the won link mixed from teal and glow); moves star vertices by the pulse of their star's phase
    /// (``pulseScale(phase:pulse:)``; nothing moves when `u_pulse` is 0); passes the normal (a star's true ellipsoid
    /// normal), the material code and the local coordinate (0 on stars).
    public static let constellationVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform vec4 u_phasesLow;
    uniform vec4 u_phasesHigh;
    uniform float u_pulse;
    out vec3 v_normal;
    out vec3 v_base;
    out float v_material;
    out float v_local;
    const vec3 AC_SKY = \(vec3Literal(AcousticConstellatorPalette.sky));
    const vec3 AC_GUIDE = \(vec3Literal(AcousticConstellatorPalette.guide));
    const vec3 AC_SILVER = \(vec3Literal(AcousticConstellatorPalette.silver));
    const vec3 AC_TEAL = \(vec3Literal(AcousticConstellatorPalette.teal));
    const vec3 AC_BROKEN = \(vec3Literal(AcousticConstellatorPalette.broken));
    const vec3 AC_STAR = \(vec3Literal(AcousticConstellatorPalette.star));
    const vec3 AC_HAND = \(vec3Literal(AcousticConstellatorPalette.hand));
    const vec3 AC_COHERENCE_LIT = \(vec3Literal(AcousticConstellatorPalette.coherenceLit));
    const vec3 AC_COHERENCE_UNLIT = \(vec3Literal(AcousticConstellatorPalette.coherenceUnlit));
    const vec3 AC_THRESHOLD_MARK = \(vec3Literal(AcousticConstellatorPalette.thresholdMark));
    const vec3 AC_HOLD_LIT = \(vec3Literal(AcousticConstellatorPalette.holdLit));
    const vec3 AC_HOLD_UNLIT = \(vec3Literal(AcousticConstellatorPalette.holdUnlit));
    const vec3 AC_MOVES_LIT = \(vec3Literal(AcousticConstellatorPalette.movesLit));
    const vec3 AC_MOVES_UNLIT = \(vec3Literal(AcousticConstellatorPalette.movesUnlit));
    const vec3 AC_GLOW = \(vec3Literal(AcousticConstellatorPalette.glow));
    const vec3 AC_STAR_RADII = \(vec3Literal(starRadii));
    const float AC_PI = \(fixed(pi));
    const float AC_STEPS = \(fixed(Double(clockSteps)));
    const float AC_PULSE = \(fixed(pulseAmplitude));
    const float AC_MAX_STAR = \(fixed(Double(maxStars - 1)));
    const float AC_WON_LIFT = \(fixed(wonLift));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, 14.0);
        vec3 base = mix(AC_SKY, AC_GUIDE, isCode(m, 1.0));
        base = mix(base, AC_SILVER, isCode(m, 2.0));
        base = mix(base, AC_TEAL, isCode(m, 3.0));
        base = mix(base, AC_BROKEN, isCode(m, 4.0));
        base = mix(base, AC_STAR, isCode(m, 5.0));
        base = mix(base, AC_HAND, isCode(m, 6.0));
        base = mix(base, AC_COHERENCE_LIT, isCode(m, 7.0));
        base = mix(base, AC_COHERENCE_UNLIT, isCode(m, 8.0));
        base = mix(base, AC_THRESHOLD_MARK, isCode(m, 9.0));
        base = mix(base, AC_HOLD_LIT, isCode(m, 10.0));
        base = mix(base, AC_HOLD_UNLIT, isCode(m, 11.0));
        base = mix(base, AC_MOVES_LIT, isCode(m, 12.0));
        base = mix(base, AC_MOVES_UNLIT, isCode(m, 13.0));
        base = mix(base, mix(AC_TEAL, AC_GLOW, AC_WON_LIFT), isCode(m, 14.0));
        float isStar = isCode(m, 5.0);
        float index = clamp(floor(a_uv.y + 0.5), 0.0, AC_MAX_STAR);
        float upper = step(3.5, index);
        vec4 row = mix(u_phasesLow, u_phasesHigh, upper);
        float lane = index - 4.0 * upper;
        vec4 pick = vec4(1.0) - step(vec4(0.5), abs(vec4(lane) - vec4(0.0, 1.0, 2.0, 3.0)));
        float phase = clamp(dot(row, pick), 0.0, AC_STEPS - 1.0);
        float pulse = clamp(u_pulse, 0.0, 1.0) * isStar;
        float scale = 1.0 + AC_PULSE * pulse * cos(2.0 * AC_PI * phase / AC_STEPS);
        vec3 offset = AC_STAR_RADII * a_normal * isStar;
        vec3 position = a_position + offset * (scale - 1.0);
        v_normal = mix(a_normal, a_normal / AC_STAR_RADII, isStar);
        v_base = base;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0) * (1.0 - isStar);
        gl_Position = u_mvp * vec4(position, 1.0);
    }
    """

    /// The constellation fragment shader. No uniforms. Ambient ``ambient`` plus Lambert ``diffuse`` from
    /// ``lightDirection`` on stars, the palette colour on the others; soft edges from the local coordinate
    /// (``edgeCoverage(local:)``). Premultiplied.
    public static let constellationFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_base;
    in float v_material;
    in float v_local;
    out vec4 color;
    const vec3 AC_LIGHT = \(vec3Literal(lightDirection));
    const float AC_AMBIENT = \(fixed(ambient));
    const float AC_DIFFUSE = \(fixed(diffuse));
    const float AC_EDGE_FEATHER = \(fixed(edgeFeather));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = floor(v_material + 0.5);
        float isLit = isCode(m, 5.0);
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        float lambert = max(dot(n, AC_LIGHT), 0.0);
        float light = mix(1.0, AC_AMBIENT + AC_DIFFUSE * lambert, isLit);
        float d = clamp(abs(v_local), 0.0, 1.0);
        float alpha = clamp(1.0 - smoothstep(1.0 - AC_EDGE_FEATHER, 1.0, d), 0.0, 1.0);
        vec3 rgb = clamp(clamp(v_base, 0.0, 1.0) * light, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`), the kind and glow factor decoded from
    /// `a_uv.x` (``AcousticConstellatorGlowKind/decode(_:)``) and the wave-shell age (`a_uv.y`).
    public static let glowVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    out vec3 v_colour;
    out float v_kind;
    out float v_factor;
    out float v_age;
    void main() {
        float x = clamp(a_uv.x, 0.0, 5.0);
        float kind = clamp(floor(x * 0.5), 0.0, 2.0);
        v_colour = clamp(a_normal, 0.0, 1.0);
        v_kind = kind;
        v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);
        v_age = clamp(a_uv.y, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glow fragment shader. Uniforms: `u_glowGain`, `u_glowLimit`. Gain ``glowGain(gain:limit:)``, colour and
    /// alpha ``glowColour(colour:kind:factor:age:gain:)`` (a zero colour counts as the glow colour, or the shell colour
    /// on a wave shell); premultiplied RGBA in 0 ... 1, drawn with additive blending.
    public static let glowFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_kind;
    in float v_factor;
    in float v_age;
    uniform float u_glowGain;
    uniform float u_glowLimit;
    out vec4 color;
    const vec3 AC_GLOW = \(vec3Literal(AcousticConstellatorPalette.glow));
    const vec3 AC_SHELL = \(vec3Literal(AcousticConstellatorPalette.shell));
    const vec3 AC_STAR = \(vec3Literal(AcousticConstellatorPalette.star));
    const float AC_GLOW_WEIGHT = \(fixed(glowWeight));
    const float AC_CORE = \(fixed(coreLift));
    const float AC_WON_LIFT = \(fixed(wonLift));
    const float AC_MAX_GAIN = \(fixed(maxGlowGain));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, AC_MAX_GAIN), clamp(u_glowLimit, 0.0, AC_MAX_GAIN));
        float kind = floor(v_kind + 0.5);
        float won = isCode(kind, 1.0);
        float isShell = isCode(kind, 2.0);
        float factor = clamp(v_factor, 0.0, 1.0);
        vec3 fallback = mix(AC_GLOW, AC_SHELL, isShell);
        vec3 colour = mix(fallback, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        vec3 rgb = mix(colour, AC_STAR, clamp((AC_CORE * gain + AC_WON_LIFT * won) * factor, 0.0, 1.0));
        float fade = mix(1.0, 1.0 - clamp(v_age, 0.0, 1.0), isShell);
        float alpha = clamp(AC_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The value the presenter passes as `u_pulse`: 1 when the tier pulses stars and Reduce Motion is off, else 0.
    public static func pulse(for tier: AcousticConstellatorTier, reduceMotion: Bool) -> Double {
        tier.pulse && !reduceMotion ? 1 : 0
    }

    /// The values the presenter passes as ``phaseRowUniforms`` (row r to uniform r): ``phaseRows`` vec4 rows with the phase of star i (reduced to
    /// 0 … 11) in lane i % 4 of row i / 4; stars past ``maxStars`` are ignored and unused lanes are 0.
    public static func phaseUniform(_ phases: [Int]) -> [SIMD4<Double>] {
        var lanes: [Double] = Array(repeating: 0, count: maxStars)
        for i in 0..<min(phases.count, maxStars) {
            let r: Int = phases[i] % clockSteps
            lanes[i] = Double(r < 0 ? r + clockSteps : r)
        }
        var rows: [SIMD4<Double>] = []
        for row in 0..<phaseRows {
            rows.append(SIMD4<Double>(lanes[4 * row], lanes[4 * row + 1], lanes[4 * row + 2], lanes[4 * row + 3]))
        }
        return rows
    }

    /// The scale the vertex shader draws a star at for `phase` (rounded and clamped to 0 … 11 as the shader reads it)
    /// and `pulse` (clamped to 0 … 1; non-finite counts as 0): 1 + ``pulseAmplitude`` · pulse · cos(2π · phase / 12),
    /// within 0.85 … 1.15; exactly 1 without pulse.
    public static func pulseScale(phase: Double, pulse: Double) -> Double {
        let p: Double = pulse.isFinite ? min(max(pulse, 0), 1) : 0
        let ph: Double = phase.isFinite ? min(max((phase + 0.5).rounded(.down), 0), Double(clockSteps - 1)) : 0
        return 1 + pulseAmplitude * p * cos(2 * Double.pi * ph / Double(clockSteps))
    }

    /// A star vertex's offset from its centre for unit-sphere direction `direction`: ``starRadii`` ⊙ direction. The
    /// geometry writes centre + this offset as the position and `direction` as the normal.
    public static func starOffset(direction: SIMD3<Double>) -> SIMD3<Double> { starRadii * direction }

    /// Where the vertex shader draws a star vertex written at `position` with unit-sphere direction `direction`:
    /// position + ``starOffset(direction:)`` · (``pulseScale(phase:pulse:)`` - 1), so the star scales about its centre.
    public static func pulsedStarVertex(position: SIMD3<Double>, direction: SIMD3<Double>, phase: Double,
                                        pulse: Double) -> SIMD3<Double> {
        position + starOffset(direction: direction) * (pulseScale(phase: phase, pulse: pulse) - 1)
    }

    /// The soft-edge coverage of local coordinate `local`: 1 - smoothstep(1 - ``edgeFeather``, 1, |local|), |local|
    /// clamped to 0 ... 1 (non-finite counts as the outline, 0 coverage).
    public static func edgeCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(1 - edgeFeather, 1, min(abs(local), 1))
    }

    /// The age 0 … 1 of wave shell `index` of `count` at `seconds` into a coherent shown tick: fract(seconds /
    /// ``waveShellSeconds`` + index / count), so the shells of one star are evenly staggered (non-finite or negative
    /// seconds count as 0; a count below 1 as 1).
    public static func waveShellAge(seconds: Double, index: Int, count: Int) -> Double {
        let s: Double = seconds.isFinite ? max(seconds, 0) : 0
        let n: Int = max(count, 1)
        let x: Double = s / waveShellSeconds + Double(min(max(index, 0), n - 1)) / Double(n)
        return x - x.rounded(.down)
    }

    /// A wave shell's radius at `age` (clamped to 0 … 1): ``maxWaveShellRadius`` · age, 0 → 0.12.
    public static func waveShellRadius(age: Double) -> Double {
        let a: Double = age.isFinite ? min(max(age, 0), 1) : 0
        return maxWaveShellRadius * a
    }

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: AcousticConstellatorTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 ... ``maxGlowGain`` (non-finite
    /// counts as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow of a vertex with `colour` (zero counts as the glow colour, or the shell colour for a wave shell),
    /// `kind`, glow factor `factor`, wave-shell `age` and the applied `gain`, before premultiplying: the colour lifted
    /// toward the star colour by (``coreLift`` gain + ``wonLift`` on a won glow) factor (rgb) and the alpha
    /// ``glowWeight`` gain factor, times 1 - age on a wave shell; every component clamped to 0 ... 1.
    public static func glowColour(colour: SIMD3<Double>, kind: AcousticConstellatorGlowKind, factor: Double,
                                  age: Double, gain: Double) -> SIMD4<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 {
            c = kind == .waveShell ? AcousticConstellatorPalette.shell : AcousticConstellatorPalette.glow
        }
        let f: Double = unit(factor)
        let k: Double = gain.isFinite ? gain : 0
        let lift: Double = unit((coreLift * k + (kind == .wonGlow ? wonLift : 0)) * f)
        let lifted: SIMD3<Double> = c + (AcousticConstellatorPalette.star - c) * lift
        let fade: Double = kind == .waveShell ? 1 - unit(age) : 1
        return SIMD4<Double>(unit(lifted.x), unit(lifted.y), unit(lifted.z), unit(glowWeight * k * f * fade))
    }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
