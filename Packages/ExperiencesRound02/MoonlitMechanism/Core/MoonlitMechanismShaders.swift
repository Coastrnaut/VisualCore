// MoonlitMechanismShaders — feature 433 (R02-G14-03) T-R02G1403-003 (FR-R02G1403-001, 002; clarifications Q1–Q4).
// The two GLSL ES 3.00 programs of Moonlit Mechanism held as source text (data: the core issues no GL call), with the
// names of every uniform they declare, their vertex attributes, the material codes shared with
// `MoonlitMechanismSceneGeometry`, the constants the sources are built from and the CPU references of what they compute.
// Presentation only: no rule is ever evaluated on these values, and nothing drawn is consulted by the rules.
//
// Clockwork program: the night backdrop, the paper wall, the ink shadow squares and their feather quads, the target
// outline, the dotted missing cells, the hatched stray cells, the crossed forbidden marks, the gears (translucent gold
// body, toothed rim, tooth-zero notch), the blade spokes, the lamp and its height ladder, the key-frame cards and their
// borders, the alignment pips, the moves bars and the broken outline. Vertex streams (the geometry states the same
// contract): `a_uv.x` is the material code (``Material``, raw values 0 … 21 in declaration order) and `a_uv.y` the
// local coordinate d, whose meaning ``Material/localCoordinate`` states per material: on a strip (outlines, marks,
// rim, notch, spokes, ladder rungs, card borders, unlit pips, broken outline) d is -1 on one long side and +1 on the
// other; on a fan (ink square, stray square, gear body, lamp disc, lit cards, unlit cards, lit pips, moves bars: one
// centre vertex and the outline's corners) d is 0 at the centre and 1 on every outline vertex; on a feather quad d is
// 0 on the ink square's edge and 1 on the quad's outer edge; on the backdrop and the paper d is 0. `a_normal` is
// declared for the shared attribute layout but not read by the clockwork program: every material is emissive at its
// palette colour, so the colour cues hold whatever normal the geometry writes.
//
// Signed-distance shading from d: the soft outline coverage 1 - smoothstep(1 - ``edgeFeather``, 1, |d|)
// (``edgeCoverage(local:)``) on strips and fans; the feather 1 - smoothstep(0, 1, d) (``featherCoverage(local:)``) so a
// feather quad fades the ink to the paper beneath it (the geometry emits feather quads at level-0 and level-1 only, so
// level-2 draws hard-edged squares); the dotted missing cells and the hatched stray cells are patterns of the wall
// position (`a_position.xy`, the wall is the plane z = -0.6): dots on (x + y) / ``dotPeriod`` with duty ``dotDuty``,
// diagonal hatching on (x - y) / ``hatchPeriod`` with duty ``hatchDuty`` (``dotCoverage(x:y:)``,
// ``hatchCoverage(x:y:)``). The gear body is translucent gold (alpha ``MoonlitMechanismPalette/gearAlpha``) with a
// fresnel-like rim highlight: d⁴ lifts the colour toward the rim colour by ``rimLift`` and the alpha toward 1 by
// ``rimAlpha`` (``gearBodyShade(local:)``); the toothed rim is bevelled (brightness 1 - ``rimBevel`` |d|); a blade spoke
// (alpha ``MoonlitMechanismPalette/bladeAlpha``) has a sheen 1 - |d| toward the rim colour times ``bladeSheen``; the
// lamp disc runs from the lamp-glow colour at its centre to the lamp colour at its edge. A won level (`u_won`, 0 … 1)
// lifts the paper toward the glow colour by ``wonLift`` times `u_won` (``paperColour(won:)``) at every tier.
//
// Glow program: the glow shells around the lamp and the lit key-frame cards and, on a won level, around the wall, drawn
// additively and last. The colour is carried in `a_normal` (a zero colour falls back to the lamp-glow colour on a lamp
// shell and to the glow colour otherwise), `a_uv.x` is 2 · kind + factor (``GlowKind``: 0 lamp, 1 card, 2 wall; factor
// the glow factor 0 … 1, a card's lit fraction; ``GlowKind/code(factor:)``) and `a_uv.y` the shell's radial coordinate
// r, 0 on its inner edge and 1 on its outer edge. The alpha is ``glowWeight`` times the gain, the factor and the fade
// (1 - r)², and a wall shell's alpha is also times `u_won`, so the wall glows only on a won level; the gain is
// `u_glowGain` capped by `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing the presenter passes
// ``glowGainCap`` as the limit, so no glow, the won wall's included, exceeds the cap. The glow program has no time input.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1) and
// `a_uv` (location 2). Every source starts with `#version 300 es` and states one float precision. Plain uniforms in the
// default block (at most 16 vec4 slots per program; the clockwork program uses 5: u_mvp 4, u_won 1; the glow program 7:
// u_mvp 4, u_glowGain, u_glowLimit and u_won 1 each), no texture samplers, no image assets, no `discard` and no loops.
// Output is premultiplied alpha. Palette constants are written with six fixed decimals from `MoonlitMechanismPalette`,
// so the shader colours equal the CPU's within 1e-6.

import Foundation

/// The GLSL ES 3.00 sources of Moonlit Mechanism's clockwork and glow programs, their uniform and attribute names, the
/// material codes, the constants they are built from and the CPU references of what they compute (FR-R02G1403-001,
/// 002).
public enum MoonlitMechanismShaders {
    /// A clockwork-program material code, written into `a_uv.x` of a clockwork vertex (shared with
    /// `MoonlitMechanismSceneGeometry`; raw values 0 … 21 in declaration order).
    public enum Material: Float, Sendable, CaseIterable, Hashable {
        /// The night backdrop plane (d = 0).
        case backdrop = 0
        /// The paper wall (d = 0); lifted toward the glow colour on a won level.
        case paper = 1
        /// A cast cell's ink square (fan).
        case ink = 2
        /// A cast cell's feather quad, fading the ink to the paper (d 0 on the square's edge, 1 outside; level-0 and
        /// level-1 only).
        case inkFeather = 3
        /// A target cell's border (strip).
        case targetOutline = 4
        /// A missing target cell's dotted border (strip; dots from the wall position).
        case missingDotted = 5
        /// A stray cell's hatched square (fan; diagonal hatching from the wall position).
        case strayHatch = 6
        /// A stroke of a forbidden cell's crossed mark (strip; two per cell).
        case forbiddenMark = 7
        /// A gear's translucent gold body (fan; fresnel-like rim highlight).
        case gearBody = 8
        /// A gear's toothed rim outline (strip; bevelled).
        case gearRim = 9
        /// A gear's tooth-zero notch (strip).
        case gearNotch = 10
        /// A blade's translucent spoke along its slot ray (strip; sheen along the centre line).
        case blade = 11
        /// The lamp disc (fan; lamp-glow centre, lamp edge).
        case lamp = 12
        /// A rung of the lamp's height ladder (strip).
        case ladder = 13
        /// A lit key-frame card (fan).
        case cardLit = 14
        /// An unlit key-frame card (fan).
        case cardUnlit = 15
        /// A required card's gold border (strip).
        case cardBorder = 16
        /// A lit alignment pip, an aligned mesh (fan).
        case alignLit = 17
        /// An unlit alignment pip: an outlined square (strip).
        case alignUnlit = 18
        /// A lit moves bar, an action left (fan).
        case movesLit = 19
        /// An unlit moves bar, an action spent (fan).
        case movesUnlit = 20
        /// The outline of what a failure names: the jammed teeth, the forbidden cell or the failing card (strip).
        case broken = 21

        /// How the geometry fills `a_uv.y` for a material.
        public enum LocalCoordinate: Sendable, Hashable {
            /// No edge: d = 0 everywhere.
            case none
            /// A fan from a centre vertex (d = 0) to the outline's corners (d = 1).
            case fan
            /// A strip or ring: d = -1 on one long side, +1 on the other.
            case strip
            /// A feather quad: d = 0 on the ink square's edge, 1 on the quad's outer edge.
            case feather
        }

        /// The `a_uv.x` value of the material.
        public var code: Float { rawValue }

        /// The material's colour as the clockwork vertex shader selects it (the paper unlifted).
        public var colour: SIMD3<Double> {
            switch self {
            case .backdrop: MoonlitMechanismPalette.night
            case .paper: MoonlitMechanismPalette.paper
            case .ink, .inkFeather, .gearNotch: MoonlitMechanismPalette.ink
            case .targetOutline, .missingDotted: MoonlitMechanismPalette.target
            case .strayHatch: MoonlitMechanismPalette.stray
            case .forbiddenMark: MoonlitMechanismPalette.forbidden
            case .gearBody: MoonlitMechanismPalette.gear
            case .gearRim, .cardBorder: MoonlitMechanismPalette.rim
            case .blade: MoonlitMechanismPalette.blade
            case .lamp, .ladder: MoonlitMechanismPalette.lamp
            case .cardLit: MoonlitMechanismPalette.cardLit
            case .cardUnlit: MoonlitMechanismPalette.cardUnlit
            case .alignLit: MoonlitMechanismPalette.alignLit
            case .alignUnlit: MoonlitMechanismPalette.alignUnlit
            case .movesLit: MoonlitMechanismPalette.movesLit
            case .movesUnlit: MoonlitMechanismPalette.movesUnlit
            case .broken: MoonlitMechanismPalette.broken
            }
        }

        /// The material's base opacity: ``MoonlitMechanismPalette/gearAlpha`` on the gear body,
        /// ``MoonlitMechanismPalette/bladeAlpha`` on a blade, 1 otherwise.
        public var alpha: Double {
            switch self {
            case .gearBody: MoonlitMechanismPalette.gearAlpha
            case .blade: MoonlitMechanismPalette.bladeAlpha
            default: 1
            }
        }

        /// How the geometry fills `a_uv.y` for the material.
        public var localCoordinate: LocalCoordinate {
            switch self {
            case .backdrop, .paper: .none
            case .inkFeather: .feather
            case .ink, .strayHatch, .gearBody, .lamp, .cardLit, .cardUnlit, .alignLit, .movesLit, .movesUnlit: .fan
            case .targetOutline, .missingDotted, .forbiddenMark, .gearRim, .gearNotch, .blade, .ladder, .cardBorder,
                 .alignUnlit, .broken: .strip
            }
        }
    }

    /// A glow-program vertex kind, encoded with the glow factor into `a_uv.x` as 2 · kind + factor.
    public enum GlowKind: Int, Sendable, CaseIterable, Hashable {
        /// A glow shell around the lamp (a zero colour counts as the lamp-glow colour).
        case lamp = 0
        /// A glow shell around a lit key-frame card (factor its lit fraction).
        case card = 1
        /// A glow shell around the wall: its alpha is also times `u_won`, so it shows only on a won level.
        case wall = 2

        /// The `a_uv.x` value of a vertex of this kind with glow factor `factor` (clamped to 0 … 1; non-finite counts
        /// as 0).
        public func code(factor: Double) -> Double {
            let f: Double = factor.isFinite ? min(max(factor, 0), 1) : 0
            return Double(2 * rawValue) + f
        }

        /// The (kind, factor) the glow vertex shader decodes from `a_uv.x`: kind ⌊x / 2⌋ clamped to 0 … 2, factor
        /// x - 2 · kind clamped to 0 … 1 (x clamped to 0 … 5; non-finite counts as 0).
        public static func decode(_ x: Double) -> (kind: GlowKind, factor: Double) {
            let v: Double = x.isFinite ? min(max(x, 0), 5) : 0
            let k: Int = min(max(Int((v * 0.5).rounded(.down)), 0), 2)
            let factor: Double = min(max(v - Double(2 * k), 0), 1)
            return (kind: GlowKind(rawValue: k) ?? .lamp, factor: factor)
        }
    }

    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine = "#version 300 es"

    /// The vertex attributes as (name, location), in location order: `a_position` (vec3, 0), `a_normal` (vec3, 1) and
    /// `a_uv` (vec2, 2), as `ShaderMeshRenderer` binds them.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    // MARK: Uniform names

    /// `mat4`: projection x view x model (both programs, vertex stage).
    public static let mvpUniform = "u_mvp"
    /// `float`: the won level's light, 0 … 1 (clockwork vertex stage: lifts the paper toward the glow colour; glow
    /// fragment stage: shows the wall's glow shells); 0 on a level not won.
    public static let wonUniform = "u_won"
    /// `float`: the glow gain (glow fragment stage); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (glow fragment stage): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the clockwork program declares, each once, in order of declaration (vertex stage first).
    public static let clockworkUniforms: [String] = [mvpUniform, wonUniform]

    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, wonUniform]

    /// The uniform lists per program name (`clockwork`, `glow`).
    public static let uniformNames: [String: [String]] = ["clockwork": clockworkUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), one per palette colour.
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = [
        (name: "MM_NIGHT", colour: MoonlitMechanismPalette.night),
        (name: "MM_PAPER", colour: MoonlitMechanismPalette.paper),
        (name: "MM_INK", colour: MoonlitMechanismPalette.ink),
        (name: "MM_GEAR", colour: MoonlitMechanismPalette.gear),
        (name: "MM_RIM", colour: MoonlitMechanismPalette.rim),
        (name: "MM_BLADE", colour: MoonlitMechanismPalette.blade),
        (name: "MM_LAMP", colour: MoonlitMechanismPalette.lamp),
        (name: "MM_LAMP_GLOW", colour: MoonlitMechanismPalette.lampGlow),
        (name: "MM_TARGET", colour: MoonlitMechanismPalette.target),
        (name: "MM_FORBIDDEN", colour: MoonlitMechanismPalette.forbidden),
        (name: "MM_STRAY", colour: MoonlitMechanismPalette.stray),
        (name: "MM_BROKEN", colour: MoonlitMechanismPalette.broken),
        (name: "MM_CARD_LIT", colour: MoonlitMechanismPalette.cardLit),
        (name: "MM_CARD_UNLIT", colour: MoonlitMechanismPalette.cardUnlit),
        (name: "MM_ALIGN_LIT", colour: MoonlitMechanismPalette.alignLit),
        (name: "MM_ALIGN_UNLIT", colour: MoonlitMechanismPalette.alignUnlit),
        (name: "MM_MOVES_LIT", colour: MoonlitMechanismPalette.movesLit),
        (name: "MM_MOVES_UNLIT", colour: MoonlitMechanismPalette.movesUnlit),
        (name: "MM_GLOW", colour: MoonlitMechanismPalette.glow),
    ]

    /// The width of the soft outline as a share of the local coordinate: coverage falls from 1 at |d| = 1 - feather to
    /// 0 at |d| = 1.
    public static let edgeFeather: Double = 0.15
    /// The period of the missing cells' dots along x + y, in world units.
    public static let dotPeriod: Double = 0.03
    /// The share of a dot period left empty (the dot is the rest).
    public static let dotDuty: Double = 0.5
    /// The period of the stray cells' diagonal hatching along x - y, in world units.
    public static let hatchPeriod: Double = 0.025
    /// The share of a hatch period that is inked.
    public static let hatchDuty: Double = 0.4
    /// How far the gear body's fresnel-like rim (d⁴) lifts the gold toward the rim colour.
    public static let rimLift: Double = 0.6
    /// How far the gear body's fresnel-like rim (d⁴) lifts the body's alpha toward 1.
    public static let rimAlpha: Double = 0.5
    /// The toothed rim's bevel: brightness 1 - rimBevel · |d| across the strip.
    public static let rimBevel: Double = 0.25
    /// How far a blade spoke's centre line (1 - |d|) lifts it toward the rim colour.
    public static let bladeSheen: Double = 0.3
    /// How far a won level lifts the paper toward the glow colour, times `u_won`.
    public static let wonLift: Double = 0.35

    /// The alpha weight of the glow, times the glow gain, the glow factor and the fade.
    public static let glowWeight: Double = 0.5
    /// The upper bound the glow shader clamps `u_glowGain` and `u_glowLimit` to.
    public static let maxGlowGain: Double = 1.5
    /// The glow gain per glow shell the presenter passes (level-0: 2 shells, level-1: 1), plus ``glowGainBase``.
    public static let glowGainPerShell: Double = 0.5
    /// The glow gain base added to ``glowGainPerShell`` times the shells at a tier with glow shells.
    public static let glowGainBase: Double = 0.5
    /// The glow limit the presenter passes normally (no cap below ``maxGlowGain``).
    public static let standardGlowLimit: Double = 1.5
    /// The Reduce Flashing cap on the glow gain: the limit the presenter passes under Reduce Flashing (the shared
    /// limit 0.5 of the round-two games).
    public static let glowGainCap: Double = 0.5

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The clockwork vertex shader. Uniforms: `u_mvp`, `u_won`. Selects the material colour and base alpha from
    /// `a_uv.x` (the paper lifted toward the glow colour by ``wonLift`` times `u_won`); passes the material code, the
    /// local coordinate and the wall position for the fragment patterns.
    public static let clockworkVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_won;
    out vec3 v_base;
    out float v_alpha;
    out float v_material;
    out float v_local;
    out vec2 v_wall;
    const vec3 MM_NIGHT = \(vec3Literal(MoonlitMechanismPalette.night));
    const vec3 MM_PAPER = \(vec3Literal(MoonlitMechanismPalette.paper));
    const vec3 MM_INK = \(vec3Literal(MoonlitMechanismPalette.ink));
    const vec3 MM_TARGET = \(vec3Literal(MoonlitMechanismPalette.target));
    const vec3 MM_STRAY = \(vec3Literal(MoonlitMechanismPalette.stray));
    const vec3 MM_FORBIDDEN = \(vec3Literal(MoonlitMechanismPalette.forbidden));
    const vec3 MM_GEAR = \(vec3Literal(MoonlitMechanismPalette.gear));
    const vec3 MM_RIM = \(vec3Literal(MoonlitMechanismPalette.rim));
    const vec3 MM_BLADE = \(vec3Literal(MoonlitMechanismPalette.blade));
    const vec3 MM_LAMP = \(vec3Literal(MoonlitMechanismPalette.lamp));
    const vec3 MM_CARD_LIT = \(vec3Literal(MoonlitMechanismPalette.cardLit));
    const vec3 MM_CARD_UNLIT = \(vec3Literal(MoonlitMechanismPalette.cardUnlit));
    const vec3 MM_ALIGN_LIT = \(vec3Literal(MoonlitMechanismPalette.alignLit));
    const vec3 MM_ALIGN_UNLIT = \(vec3Literal(MoonlitMechanismPalette.alignUnlit));
    const vec3 MM_MOVES_LIT = \(vec3Literal(MoonlitMechanismPalette.movesLit));
    const vec3 MM_MOVES_UNLIT = \(vec3Literal(MoonlitMechanismPalette.movesUnlit));
    const vec3 MM_BROKEN = \(vec3Literal(MoonlitMechanismPalette.broken));
    const vec3 MM_GLOW = \(vec3Literal(MoonlitMechanismPalette.glow));
    const float MM_GEAR_ALPHA = \(fixed(MoonlitMechanismPalette.gearAlpha));
    const float MM_BLADE_ALPHA = \(fixed(MoonlitMechanismPalette.bladeAlpha));
    const float MM_WON_LIFT = \(fixed(wonLift));
    const float MM_MAX_MATERIAL = \(fixed(Double(Material.allCases.count - 1)));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, MM_MAX_MATERIAL);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 base = mix(MM_NIGHT, mix(MM_PAPER, MM_GLOW, MM_WON_LIFT * won), isCode(m, 1.0));
        base = mix(base, MM_INK, isCode(m, 2.0));
        base = mix(base, MM_INK, isCode(m, 3.0));
        base = mix(base, MM_TARGET, isCode(m, 4.0));
        base = mix(base, MM_TARGET, isCode(m, 5.0));
        base = mix(base, MM_STRAY, isCode(m, 6.0));
        base = mix(base, MM_FORBIDDEN, isCode(m, 7.0));
        base = mix(base, MM_GEAR, isCode(m, 8.0));
        base = mix(base, MM_RIM, isCode(m, 9.0));
        base = mix(base, MM_INK, isCode(m, 10.0));
        base = mix(base, MM_BLADE, isCode(m, 11.0));
        base = mix(base, MM_LAMP, isCode(m, 12.0));
        base = mix(base, MM_LAMP, isCode(m, 13.0));
        base = mix(base, MM_CARD_LIT, isCode(m, 14.0));
        base = mix(base, MM_CARD_UNLIT, isCode(m, 15.0));
        base = mix(base, MM_RIM, isCode(m, 16.0));
        base = mix(base, MM_ALIGN_LIT, isCode(m, 17.0));
        base = mix(base, MM_ALIGN_UNLIT, isCode(m, 18.0));
        base = mix(base, MM_MOVES_LIT, isCode(m, 19.0));
        base = mix(base, MM_MOVES_UNLIT, isCode(m, 20.0));
        base = mix(base, MM_BROKEN, isCode(m, 21.0));
        float alpha = mix(1.0, MM_GEAR_ALPHA, isCode(m, 8.0));
        alpha = mix(alpha, MM_BLADE_ALPHA, isCode(m, 11.0));
        float plain = isCode(m, 0.0) + isCode(m, 1.0);
        v_base = base;
        v_alpha = alpha;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0) * (1.0 - plain);
        v_wall = a_position.xy;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The clockwork fragment shader. No uniforms. Signed-distance coverage from the local coordinate
    /// (``edgeCoverage(local:)``, ``featherCoverage(local:)``), the dotted and hatched patterns of the wall position
    /// (``dotCoverage(x:y:)``, ``hatchCoverage(x:y:)``), the gear body's fresnel-like rim (``gearBodyShade(local:)``),
    /// the rim's bevel, the blade's sheen and the lamp's radial colour. Premultiplied.
    public static let clockworkFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_base;
    in float v_alpha;
    in float v_material;
    in float v_local;
    in vec2 v_wall;
    out vec4 color;
    const vec3 MM_RIM = \(vec3Literal(MoonlitMechanismPalette.rim));
    const vec3 MM_LAMP_GLOW = \(vec3Literal(MoonlitMechanismPalette.lampGlow));
    const float MM_EDGE_FEATHER = \(fixed(edgeFeather));
    const float MM_DOT_PERIOD = \(fixed(dotPeriod));
    const float MM_DOT_DUTY = \(fixed(dotDuty));
    const float MM_HATCH_PERIOD = \(fixed(hatchPeriod));
    const float MM_HATCH_DUTY = \(fixed(hatchDuty));
    const float MM_RIM_LIFT = \(fixed(rimLift));
    const float MM_RIM_ALPHA = \(fixed(rimAlpha));
    const float MM_RIM_BEVEL = \(fixed(rimBevel));
    const float MM_BLADE_SHEEN = \(fixed(bladeSheen));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = floor(v_material + 0.5);
        float d = clamp(abs(v_local), 0.0, 1.0);
        float plain = isCode(m, 0.0) + isCode(m, 1.0);
        float isFeather = isCode(m, 3.0);
        float edge = 1.0 - smoothstep(1.0 - MM_EDGE_FEATHER, 1.0, d);
        float feather = 1.0 - smoothstep(0.0, 1.0, d);
        float coverage = mix(mix(edge, feather, isFeather), 1.0, plain);
        float dots = step(MM_DOT_DUTY, fract((v_wall.x + v_wall.y) / MM_DOT_PERIOD));
        coverage *= mix(1.0, dots, isCode(m, 5.0));
        float hatch = 1.0 - step(MM_HATCH_DUTY, fract((v_wall.x - v_wall.y) / MM_HATCH_PERIOD));
        coverage *= mix(1.0, hatch, isCode(m, 6.0));
        float isBody = isCode(m, 8.0);
        float d2 = d * d;
        float fresnel = d2 * d2 * isBody;
        vec3 rgb = mix(v_base, MM_RIM, MM_RIM_LIFT * fresnel);
        float base = clamp(v_alpha, 0.0, 1.0);
        base = base + (1.0 - base) * MM_RIM_ALPHA * fresnel;
        rgb = rgb * mix(1.0, 1.0 - MM_RIM_BEVEL * d, isCode(m, 9.0));
        rgb = mix(rgb, MM_RIM, MM_BLADE_SHEEN * (1.0 - d) * isCode(m, 11.0));
        rgb = mix(rgb, mix(MM_LAMP_GLOW, v_base, d), isCode(m, 12.0));
        float alpha = clamp(base * coverage, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`), the kind and glow factor decoded from
    /// `a_uv.x` (``GlowKind/decode(_:)``) and the shell's radial coordinate (`a_uv.y`).
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
    out float v_radius;
    void main() {
        float x = clamp(a_uv.x, 0.0, 5.0);
        float kind = clamp(floor(x * 0.5), 0.0, 2.0);
        v_colour = clamp(a_normal, 0.0, 1.0);
        v_kind = kind;
        v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);
        v_radius = clamp(a_uv.y, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glow fragment shader. Uniforms: `u_glowGain`, `u_glowLimit`, `u_won`. Gain ``glowGain(gain:limit:)``,
    /// colour and alpha ``glowColour(colour:kind:factor:radius:gain:won:)``; premultiplied RGBA in 0 … 1, drawn with
    /// additive blending.
    public static let glowFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_kind;
    in float v_factor;
    in float v_radius;
    uniform float u_glowGain;
    uniform float u_glowLimit;
    uniform float u_won;
    out vec4 color;
    const vec3 MM_LAMP_GLOW = \(vec3Literal(MoonlitMechanismPalette.lampGlow));
    const vec3 MM_GLOW = \(vec3Literal(MoonlitMechanismPalette.glow));
    const float MM_GLOW_WEIGHT = \(fixed(glowWeight));
    const float MM_MAX_GAIN = \(fixed(maxGlowGain));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, MM_MAX_GAIN), clamp(u_glowLimit, 0.0, MM_MAX_GAIN));
        float kind = floor(v_kind + 0.5);
        float isWall = isCode(kind, 2.0);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 fallback = mix(MM_GLOW, MM_LAMP_GLOW, isCode(kind, 0.0));
        vec3 rgb = mix(fallback, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        float factor = clamp(v_factor, 0.0, 1.0);
        float r = 1.0 - clamp(v_radius, 0.0, 1.0);
        float fade = r * r * mix(1.0, won, isWall);
        float alpha = clamp(MM_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The soft-outline coverage of local coordinate `local`: 1 - smoothstep(1 - ``edgeFeather``, 1, |local|), |local|
    /// clamped to 0 … 1 (non-finite counts as the outline, 0 coverage).
    public static func edgeCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(1 - edgeFeather, 1, min(abs(local), 1))
    }

    /// A feather quad's coverage at local coordinate `local`: 1 - smoothstep(0, 1, |local|), so the ink is opaque on
    /// the square's edge and gone (the paper shows) on the quad's outer edge (non-finite counts as 0 coverage).
    public static func featherCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(0, 1, min(abs(local), 1))
    }

    /// The dotted pattern at wall position (`x`, `y`): 1 where fract((x + y) / ``dotPeriod``) ≥ ``dotDuty``, else 0.
    public static func dotCoverage(x: Double, y: Double) -> Double {
        let t: Double = (x + y) / dotPeriod
        return t - t.rounded(.down) >= dotDuty ? 1 : 0
    }

    /// The hatching at wall position (`x`, `y`): 1 where fract((x - y) / ``hatchPeriod``) < ``hatchDuty``, else 0.
    public static func hatchCoverage(x: Double, y: Double) -> Double {
        let t: Double = (x - y) / hatchPeriod
        return t - t.rounded(.down) < hatchDuty ? 1 : 0
    }

    /// The gear body's colour and alpha at local coordinate `local` (|local| clamped to 0 … 1), before the outline
    /// coverage: the fresnel-like term f = d⁴ lifts the gold toward the rim colour by ``rimLift`` f and the alpha
    /// ``MoonlitMechanismPalette/gearAlpha`` toward 1 by ``rimAlpha`` f.
    public static func gearBodyShade(local: Double) -> (colour: SIMD3<Double>, alpha: Double) {
        let d: Double = local.isFinite ? min(abs(local), 1) : 1
        let f: Double = d * d * d * d
        let colour: SIMD3<Double> = MoonlitMechanismPalette.gear
            + (MoonlitMechanismPalette.rim - MoonlitMechanismPalette.gear) * (rimLift * f)
        let a: Double = MoonlitMechanismPalette.gearAlpha
        return (colour: colour, alpha: a + (1 - a) * rimAlpha * f)
    }

    /// The paper colour at won light `won` (clamped to 0 … 1; non-finite counts as 0): the paper lifted toward the glow
    /// colour by ``wonLift`` times `won`.
    public static func paperColour(won: Double) -> SIMD3<Double> {
        let w: Double = won.isFinite ? min(max(won, 0), 1) : 0
        return MoonlitMechanismPalette.paper + (MoonlitMechanismPalette.glow - MoonlitMechanismPalette.paper) * (wonLift * w)
    }

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: MoonlitMechanismTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 … ``maxGlowGain`` (non-finite counts
    /// as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow of a vertex with `colour` (zero counts as the lamp-glow colour on a lamp shell, the glow colour
    /// otherwise), `kind`, glow factor `factor`, radial coordinate `radius`, the applied `gain` and won light `won`,
    /// before premultiplying: the colour, with alpha ``glowWeight`` · gain · factor · (1 - radius)², times `won` on a
    /// wall shell; every component clamped to 0 … 1.
    public static func glowColour(colour: SIMD3<Double>, kind: GlowKind, factor: Double, radius: Double, gain: Double,
                                  won: Double) -> SIMD4<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 {
            c = kind == .lamp ? MoonlitMechanismPalette.lampGlow : MoonlitMechanismPalette.glow
        }
        let r: Double = 1 - unit(radius)
        let fade: Double = r * r * (kind == .wall ? unit(won) : 1)
        let k: Double = gain.isFinite ? gain : 0
        return SIMD4<Double>(c.x, c.y, c.z, unit(glowWeight * k * unit(factor) * fade))
    }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
