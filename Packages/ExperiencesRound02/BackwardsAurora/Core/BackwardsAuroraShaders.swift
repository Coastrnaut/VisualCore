// BackwardsAuroraShaders — feature 393 (R02-G10-03) T-R02G1003-003 (FR-R02G1003-002, 004, 007; clarifications Q1–Q4).
// The two GLSL ES 3.00 programs of Backwards Aurora held as source text (data: the core issues no GL call), with the
// names of every uniform they declare, their vertex attributes, the material codes shared with
// `BackwardsAuroraSceneGeometry`, the constants the sources are built from and the CPU references of what they compute.
//
// Aurora program: the midnight ground, the section band, the trailing aurora layers, the pale lilac ghost trail, the
// checkpoint ticks, the deep-ocean-cyan ribbon, the checkpoint rings and matched discs, the kink and tear crosses and
// the spent and unspent bars of the reversal gauge. Mesh layout (data model, "Mesh streams"): `a_normal` is the surface
// normal, `a_uv.x` the material code (see `AuroraMaterial`: 0 ground, 1 band, 2 first trailing layer, 3 ghost, 4 tick,
// 5 ribbon, 6 ring, 7 disc, 8 kink cross, 9 tear cross, 10 spent bar, 11 unspent bar, 12 second trailing layer) and
// `a_uv.y` the signed timeline coordinate t in -1 ... 1: |t| is the position along the timeline, 0 at the left end and
// 1 at the right, and t is negative inside the chosen section, so the pulses there run right to left (the way a
// reversal will fold it). Lighting is an ambient term plus Lambert from `u_lightDir` on the lit materials (ground, band,
// unspent bar); every other material is mostly emissive (``emission``), so the colour cues hold under any light.
// Ribbon: the ribbon colour with a shimmer toward the highlight driven by `u_time` (``shimmer(t:time:)``) and a fresnel
// sheen (`u_eye` gives the view direction), plus up to ``maxPulses`` (2) bright pulse beads per unit of |t| travelling
// in the direction sign(t) (``pulseIntensity(t:time:pulses:)``); only the first `u_pulses` beads (the tier's `pulses`,
// clamped to 0 ... 2) count; the loop is bounded by the constant 2. Trailing layers: the plain ribbon colour, faded to
// ``firstLayerAlpha`` (code 2) and ``secondLayerAlpha`` (code 12), premultiplied. Everything else is opaque. Reduce
// Motion needs nothing here: the scene passes `u_time` = 0, so the shimmer and the pulses stand still.
//
// Glow program: the glow shells over the ribbon, drawn additively. The colour is carried in `a_normal` (the mesh builder
// writes `BackwardsAuroraPalette.glow` there), `a_uv.x` is the glow factor 0 ... 1 and `a_uv.y` is 0. The glow is the
// colour lifted toward the ribbon highlight by ``coreLift`` times the glow factor and the glow gain, with alpha
// ``glowWeight`` times the same; the glow gain is `u_glow` capped by `u_glowLimit` (both clamped to ``maxGlowGain``);
// under Reduce Flashing the presenter passes ``glowGainCap`` as the limit. The glow program has no time input: it never
// pulses.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1) from
// `Mesh.interleavedPositionNormal()` and `a_uv` (location 2) from `Mesh.uvs`. Every source starts with `#version 300 es`
// (VisualCoreShaderSource's `ShaderLibrary.versionLine`) and states one float precision. Plain uniforms (at most 16
// vec4 slots per program; the aurora program uses 8, the glow program 6), no texture samplers, no image assets, no
// `discard` and one loop, bounded by a constant. Output is premultiplied alpha. Palette constants are written with six
// fixed decimals from `BackwardsAuroraPalette`, so the shader colours equal the CPU's within 1/255.

import Foundation

/// The GLSL ES 3.00 sources of Backwards Aurora's aurora and glow programs, their uniform and attribute names, the
/// material codes, the constants they are built from and the CPU references of what they compute (FR-R02G1003-002).
public enum BackwardsAuroraShaders {
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
    /// `vec3`: the direction toward the light in model units (aurora; normalised by the shader).
    public static let lightDirectionUniform = "u_lightDir"
    /// `vec3`: the camera position in model units (aurora), for the view direction of the ribbon's sheen.
    public static let eyeUniform = "u_eye"
    /// `float`: presentation time in seconds, the only time source of the shimmer and the pulses (aurora); the scene
    /// passes 0 under Reduce Motion, so both stand still.
    public static let timeUniform = "u_time"
    /// `float`: the tier's pulse count 0, 1 or 2, clamped by the shader to 0 ... ``maxPulses`` (aurora); see
    /// ``pulses(for:)``.
    public static let pulsesUniform = "u_pulses"
    /// `float`: 1 on a won level (stage won, or the result after a win), 0 otherwise (aurora): the ribbon and its
    /// trailing layers brighten toward the highlight by ``wonLift`` (feature 393 convergence, T-R02G1003-014).
    public static let wonUniform = "u_won"
    /// How far a won level's ribbon moves toward ``ribbonHighlight``.
    public static let wonLift: Double = 0.35
    /// The value the scene passes as `u_won` for `stage` and `failure`: 1 on a won level, 0 otherwise.
    public static func won(stage: BackwardsAuroraStage, failure: BackwardsAuroraFailure?) -> Float {
        stage == .won || (stage == .result && failure == nil) ? 1 : 0
    }
    /// `float`: the glow gain (glow); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowUniform = "u_glow"
    /// `float`: the glow limit (glow): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the aurora program declares, each once, in order of declaration (vertex stage first).
    public static let auroraUniforms: [String] = [mvpUniform, lightDirectionUniform, eyeUniform, timeUniform,
                                                  pulsesUniform, wonUniform]

    /// Every uniform the glow program declares, exactly as declared (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowUniform, glowLimitUniform]

    /// The uniform lists per program name (`aurora`, `glow`).
    public static let uniformNames: [String: [String]] = ["aurora": auroraUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Material codes

    /// The material code of the midnight ground plane (`a_uv.x` = 0).
    public static let groundMaterial: Double = AuroraMaterial.ground.code
    /// The material code of the band behind the chosen section (`a_uv.x` = 1).
    public static let bandMaterial: Double = AuroraMaterial.band.code
    /// The material code of the first trailing aurora layer, faded to ``firstLayerAlpha`` (`a_uv.x` = 2).
    public static let trailingLayerMaterial: Double = AuroraMaterial.trailingLayer.code
    /// The material code of the pale lilac ghost trail of the target (`a_uv.x` = 3).
    public static let ghostMaterial: Double = AuroraMaterial.ghost.code
    /// The material code of a checkpoint's vertical tick (`a_uv.x` = 4).
    public static let tickMaterial: Double = AuroraMaterial.tick.code
    /// The material code of the aurora ribbon, with shimmer and pulse beads (`a_uv.x` = 5).
    public static let ribbonMaterial: Double = AuroraMaterial.ribbon.code
    /// The material code of a checkpoint's ring (`a_uv.x` = 6).
    public static let ringMaterial: Double = AuroraMaterial.ring.code
    /// The material code of a matched checkpoint's disc (`a_uv.x` = 7).
    public static let discMaterial: Double = AuroraMaterial.disc.code
    /// The material code of a kink cross on a bend above the limit (`a_uv.x` = 8).
    public static let kinkMaterial: Double = AuroraMaterial.kink.code
    /// The material code of the tear cross on a torn seam (`a_uv.x` = 9).
    public static let tearMaterial: Double = AuroraMaterial.tear.code
    /// The material code of a spent bar of the reversal gauge (`a_uv.x` = 10).
    public static let spentMaterial: Double = AuroraMaterial.spent.code
    /// The material code of an unspent bar of the reversal gauge (`a_uv.x` = 11).
    public static let unspentMaterial: Double = AuroraMaterial.unspent.code
    /// The material code of the second trailing aurora layer, faded to ``secondLayerAlpha`` (`a_uv.x` = 12).
    public static let secondTrailingLayerMaterial: Double = AuroraMaterial.secondTrailingLayer.code

    // MARK: Constants

    /// The midnight ground, as written into the sources (`BackwardsAuroraPalette.ground`).
    public static let ground: SIMD3<Double> = BackwardsAuroraPalette.ground
    /// The deep-ocean-cyan ribbon, as written into the sources (`BackwardsAuroraPalette.ribbon`).
    public static let ribbon: SIMD3<Double> = BackwardsAuroraPalette.ribbon
    /// The ribbon's shimmer and pulse highlight (`BackwardsAuroraPalette.ribbonHighlight`).
    public static let ribbonHighlight: SIMD3<Double> = BackwardsAuroraPalette.ribbonHighlight
    /// The glow around the ribbon (`BackwardsAuroraPalette.glow`), the colour the glow mesh carries.
    public static let glow: SIMD3<Double> = BackwardsAuroraPalette.glow
    /// The pale lilac ghost trail, as written into the sources (`BackwardsAuroraPalette.ghost`).
    public static let ghost: SIMD3<Double> = BackwardsAuroraPalette.ghost
    /// A checkpoint's tick and ring, as written into the sources (`BackwardsAuroraPalette.ring`).
    public static let ring: SIMD3<Double> = BackwardsAuroraPalette.ring
    /// A matched checkpoint's disc, as written into the sources (`BackwardsAuroraPalette.matched`).
    public static let matched: SIMD3<Double> = BackwardsAuroraPalette.matched
    /// The kink cross, as written into the sources (`BackwardsAuroraPalette.kink`).
    public static let kink: SIMD3<Double> = BackwardsAuroraPalette.kink
    /// The tear cross, as written into the sources (`BackwardsAuroraPalette.tear`).
    public static let tear: SIMD3<Double> = BackwardsAuroraPalette.tear
    /// The section band, as written into the sources (`BackwardsAuroraPalette.band`).
    public static let band: SIMD3<Double> = BackwardsAuroraPalette.band
    /// A spent gauge bar, as written into the sources (`BackwardsAuroraPalette.spent`).
    public static let spent: SIMD3<Double> = BackwardsAuroraPalette.spent
    /// An unspent gauge bar, as written into the sources (`BackwardsAuroraPalette.unspent`).
    public static let unspent: SIMD3<Double> = BackwardsAuroraPalette.unspent

    /// The aurora program's ambient term on the lit materials.
    public static let ambient: Double = 0.7
    /// The aurora program's Lambert weight on the lit materials (ambient + diffuse = 1).
    public static let diffuse: Double = 0.3
    /// The share of an emissive material's colour that is emission, independent of the light (the rest is Lambert).
    public static let emission: Double = 0.9
    /// The exponent of the fresnel term (1 - |n . v|) ^ power of the ribbon's sheen.
    public static let fresnelPower: Double = 3
    /// How far the fresnel term mixes the ribbon toward the highlight (the sheen).
    public static let sheenWeight: Double = 0.3
    /// How far the shimmer (0 ... 1) mixes the ribbon toward the highlight.
    public static let shimmerWeight: Double = 0.3
    /// The spatial frequency of the shimmer in radians per unit of |t|.
    public static let shimmerFrequency: Double = 18
    /// The shimmer rate in radians per second.
    public static let shimmerSpeed: Double = 1.6
    /// The most pulse beads per unit of |t| (the richest tier's `pulses`; the loop bound).
    public static let maxPulses: Int = 2
    /// The pulse travel rate in units of |t| per second.
    public static let pulseSpeed: Double = 0.12
    /// The half width of a pulse bead in units of |t|: the bead falls from 1 at its head to 0 at this distance.
    public static let pulseWidth: Double = 0.04
    /// The alpha of the first trailing layer (code 2).
    public static let firstLayerAlpha: Double = 0.45
    /// The alpha of the second trailing layer (code 12).
    public static let secondLayerAlpha: Double = 0.25

    /// The alpha weight of the glow, times the glow gain and the glow factor of the vertex.
    public static let glowWeight: Double = 0.5
    /// How far the glow lifts a colour toward the ribbon highlight, times the glow gain and the glow factor.
    public static let coreLift: Double = 0.3

    /// The upper bound (the glow gain cap) the glow shader clamps `u_glow` and `u_glowLimit` to.
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

    /// An aurora material code, written into `a_uv.x` of an aurora-program vertex (shared with the geometry).
    public enum AuroraMaterial: Int, Sendable, CaseIterable, Hashable {
        /// The midnight ground plane (lit).
        case ground = 0
        /// The band behind the chosen section (lit).
        case band = 1
        /// The first trailing aurora layer (emissive; alpha ``BackwardsAuroraShaders/firstLayerAlpha``).
        case trailingLayer = 2
        /// The ghost trail of the target (emissive).
        case ghost = 3
        /// A checkpoint's vertical tick (emissive).
        case tick = 4
        /// The aurora ribbon: shimmer, sheen and pulse beads (emissive).
        case ribbon = 5
        /// A checkpoint's ring (emissive).
        case ring = 6
        /// A matched checkpoint's disc (emissive).
        case disc = 7
        /// A kink cross (emissive).
        case kink = 8
        /// The tear cross (emissive).
        case tear = 9
        /// A spent gauge bar (emissive).
        case spent = 10
        /// An unspent gauge bar (lit).
        case unspent = 11
        /// The second trailing aurora layer (emissive; alpha ``BackwardsAuroraShaders/secondLayerAlpha``).
        case secondTrailingLayer = 12

        /// The `a_uv.x` value of the material.
        public var code: Double { Double(rawValue) }

        /// The material's colour as the aurora vertex shader selects it (before light, shimmer and pulses).
        public var colour: SIMD3<Double> {
            switch self {
            case .ground: BackwardsAuroraShaders.ground
            case .band: BackwardsAuroraShaders.band
            case .trailingLayer, .ribbon, .secondTrailingLayer: BackwardsAuroraShaders.ribbon
            case .ghost: BackwardsAuroraShaders.ghost
            case .tick, .ring: BackwardsAuroraShaders.ring
            case .disc: BackwardsAuroraShaders.matched
            case .kink: BackwardsAuroraShaders.kink
            case .tear: BackwardsAuroraShaders.tear
            case .spent: BackwardsAuroraShaders.spent
            case .unspent: BackwardsAuroraShaders.unspent
            }
        }

        /// Whether the material is lit (ambient plus Lambert) rather than mostly emissive.
        public var isLit: Bool {
            switch self {
            case .ground, .band, .unspent: true
            default: false
            }
        }

        /// The material's alpha: ``BackwardsAuroraShaders/firstLayerAlpha`` and
        /// ``BackwardsAuroraShaders/secondLayerAlpha`` for the trailing layers, 1 (opaque) for everything else.
        public var alpha: Double {
            switch self {
            case .trailingLayer: BackwardsAuroraShaders.firstLayerAlpha
            case .secondTrailingLayer: BackwardsAuroraShaders.secondLayerAlpha
            default: 1
            }
        }
    }

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The aurora vertex shader. Uniform: `u_mvp`. Selects the material colour from `a_uv.x` and passes the normal,
    /// the model position, the material code and the signed timeline coordinate `a_uv.y`.
    public static let auroraVertex = """
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
    out float v_t;
    const vec3 BA_GROUND = \(vec3Literal(ground));
    const vec3 BA_BAND = \(vec3Literal(band));
    const vec3 BA_RIBBON = \(vec3Literal(ribbon));
    const vec3 BA_GHOST = \(vec3Literal(ghost));
    const vec3 BA_RING = \(vec3Literal(ring));
    const vec3 BA_MATCHED = \(vec3Literal(matched));
    const vec3 BA_KINK = \(vec3Literal(kink));
    const vec3 BA_TEAR = \(vec3Literal(tear));
    const vec3 BA_SPENT = \(vec3Literal(spent));
    const vec3 BA_UNSPENT = \(vec3Literal(unspent));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, 12.0);
        vec3 base = mix(BA_GROUND, BA_BAND, isCode(m, 1.0));
        base = mix(base, BA_RIBBON, isCode(m, 2.0));
        base = mix(base, BA_GHOST, isCode(m, 3.0));
        base = mix(base, BA_RING, isCode(m, 4.0));
        base = mix(base, BA_RIBBON, isCode(m, 5.0));
        base = mix(base, BA_RING, isCode(m, 6.0));
        base = mix(base, BA_MATCHED, isCode(m, 7.0));
        base = mix(base, BA_KINK, isCode(m, 8.0));
        base = mix(base, BA_TEAR, isCode(m, 9.0));
        base = mix(base, BA_SPENT, isCode(m, 10.0));
        base = mix(base, BA_UNSPENT, isCode(m, 11.0));
        base = mix(base, BA_RIBBON, isCode(m, 12.0));
        v_base = base;
        v_normal = a_normal;
        v_position = a_position;
        v_material = m;
        v_t = clamp(a_uv.y, -1.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The aurora fragment shader. Uniforms: `u_lightDir`, `u_eye`, `u_time`, `u_pulses`. Ambient ``ambient`` plus
    /// Lambert ``diffuse`` on the lit materials, mostly ``emission`` on the others; the ribbon adds the shimmer
    /// (``shimmer(t:time:)``), the fresnel sheen (``fresnel(normalDotView:)``) and the first `u_pulses` of ``maxPulses``
    /// pulse beads (``pulseIntensity(t:time:pulses:)``); trailing layers fade to their alpha. Premultiplied.
    public static let auroraFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_base;
    in vec3 v_position;
    in float v_material;
    in float v_t;
    uniform vec3 u_lightDir;
    uniform vec3 u_eye;
    uniform float u_time;
    uniform float u_pulses;
    uniform float u_won;
    out vec4 color;
    const vec3 BA_RIBBON = \(vec3Literal(ribbon));
    const vec3 BA_HIGHLIGHT = \(vec3Literal(ribbonHighlight));
    const int BA_MAX_PULSES = \(maxPulses);
    const float BA_AMBIENT = \(fixed(ambient));
    const float BA_DIFFUSE = \(fixed(diffuse));
    const float BA_EMISSION = \(fixed(emission));
    const float BA_FRESNEL_POWER = \(fixed(fresnelPower));
    const float BA_SHEEN_WEIGHT = \(fixed(sheenWeight));
    const float BA_SHIMMER_WEIGHT = \(fixed(shimmerWeight));
    const float BA_SHIMMER_FREQUENCY = \(fixed(shimmerFrequency));
    const float BA_SHIMMER_SPEED = \(fixed(shimmerSpeed));
    const float BA_PULSE_SPEED = \(fixed(pulseSpeed));
    const float BA_PULSE_WIDTH = \(fixed(pulseWidth));
    const float BA_FIRST_LAYER_ALPHA = \(fixed(firstLayerAlpha));
    const float BA_SECOND_LAYER_ALPHA = \(fixed(secondLayerAlpha));
    const float BA_WON_LIFT = \(fixed(wonLift));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = floor(v_material + 0.5);
        float isRibbon = isCode(m, 5.0);
        float isFirstLayer = isCode(m, 2.0);
        float isSecondLayer = isCode(m, 12.0);
        float isLit = isCode(m, 0.0) + isCode(m, 1.0) + isCode(m, 11.0);
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 l = u_lightDir / max(length(u_lightDir), 0.0001);
        vec3 e = u_eye - v_position;
        vec3 v = e / max(length(e), 0.0001);
        float lambert = max(dot(n, l), 0.0);
        float facing = clamp(abs(dot(n, v)), 0.0, 1.0);
        float fresnel = pow(1.0 - facing, BA_FRESNEL_POWER);
        float light = BA_AMBIENT + BA_DIFFUSE * lambert;
        float glowLight = BA_EMISSION + (1.0 - BA_EMISSION) * lambert;
        vec3 base = clamp(v_base, 0.0, 1.0);
        vec3 shaded = base * mix(glowLight, light, clamp(isLit, 0.0, 1.0));
        float along = clamp(abs(v_t), 0.0, 1.0);
        float direction = 2.0 * step(0.0, v_t) - 1.0;
        float shimmer = 0.5 + 0.5 * sin(BA_SHIMMER_FREQUENCY * along + BA_SHIMMER_SPEED * u_time);
        vec3 ribbon = mix(BA_RIBBON, BA_HIGHLIGHT, BA_SHIMMER_WEIGHT * shimmer + BA_SHEEN_WEIGHT * fresnel);
        float pulses = clamp(u_pulses, 0.0, float(BA_MAX_PULSES));
        float bead = 0.0;
        for (int i = 0; i < BA_MAX_PULSES; i++) {
            float on = 1.0 - step(pulses, float(i));
            float head = fract(direction * BA_PULSE_SPEED * u_time + float(i) / max(pulses, 1.0));
            float gap = abs(along - head);
            gap = min(gap, 1.0 - gap);
            bead = max(bead, on * (1.0 - smoothstep(0.0, BA_PULSE_WIDTH, gap)));
        }
        ribbon = mix(ribbon, BA_HIGHLIGHT, bead);
        vec3 rgb = mix(shaded, ribbon * glowLight, isRibbon);
        float isAurora = clamp(isRibbon + isFirstLayer + isSecondLayer, 0.0, 1.0);
        rgb = mix(rgb, BA_HIGHLIGHT * glowLight, isAurora * clamp(u_won, 0.0, 1.0) * BA_WON_LIFT);
        rgb = clamp(rgb, 0.0, 1.0);
        float alpha = 1.0 - isFirstLayer * (1.0 - BA_FIRST_LAYER_ALPHA) - isSecondLayer * (1.0 - BA_SECOND_LAYER_ALPHA);
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

    /// The glow fragment shader. Uniforms: `u_glow`, `u_glowLimit`. Gain ``glowGain(gain:limit:)``, colour and alpha
    /// ``glowColour(colour:glow:gain:)``; premultiplied RGBA in 0 ... 1, drawn with additive blending.
    public static let glowFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_colour;
    in float v_glow;
    uniform float u_glow;
    uniform float u_glowLimit;
    out vec4 color;
    const vec3 BA_HIGHLIGHT = \(vec3Literal(ribbonHighlight));
    const float BA_GLOW_WEIGHT = \(fixed(glowWeight));
    const float BA_CORE = \(fixed(coreLift));
    const float BA_MAX_GAIN = \(fixed(maxGlowGain));
    void main() {
        float gain = min(clamp(u_glow, 0.0, BA_MAX_GAIN), clamp(u_glowLimit, 0.0, BA_MAX_GAIN));
        vec3 rgb = mix(v_colour, BA_HIGHLIGHT, clamp(BA_CORE * gain * v_glow, 0.0, 1.0));
        float alpha = clamp(BA_GLOW_WEIGHT * gain * v_glow, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glow` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: BackwardsAuroraTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The value the presenter passes as `u_pulses` at `tier`: its `pulses`, clamped to 0 ... ``maxPulses``.
    public static func pulses(for tier: BackwardsAuroraTier) -> Double {
        Double(min(max(tier.pulses, 0), maxPulses))
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 ... ``maxGlowGain`` (non-finite
    /// counts as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow for a vertex `colour`, glow factor `glow` and the applied `gain`, before premultiplying: the colour
    /// lifted toward the ribbon highlight by ``coreLift`` gain glow (rgb) and the alpha ``glowWeight`` gain glow, every
    /// component clamped to 0 ... 1.
    public static func glowColour(colour: SIMD3<Double>, glow: Double, gain: Double) -> SIMD4<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        let c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        let g: Double = unit(glow)
        let k: Double = gain.isFinite ? gain : 0
        let lift: Double = unit(coreLift * k * g)
        let lifted: SIMD3<Double> = c + (ribbonHighlight - c) * lift
        return SIMD4<Double>(unit(lifted.x), unit(lifted.y), unit(lifted.z), unit(glowWeight * k * g))
    }

    /// The fresnel term for n . v `normalDotView`: (1 - |n . v|) ^ ``fresnelPower``, |n . v| clamped to 0 ... 1
    /// (non-finite counts as facing the eye, 0).
    public static func fresnel(normalDotView: Double) -> Double {
        let facing: Double = normalDotView.isFinite ? min(abs(normalDotView), 1) : 1
        return pow(1 - facing, fresnelPower)
    }

    /// The shimmer 0 ... 1 of the ribbon at signed timeline coordinate `t` and `time` seconds:
    /// 0.5 + 0.5 sin(``shimmerFrequency`` |t| + ``shimmerSpeed`` time). At `time` 0 (Reduce Motion) it depends on the
    /// position alone.
    public static func shimmer(t: Double, time: Double) -> Double {
        let along: Double = t.isFinite ? min(abs(t), 1) : 0
        let s: Double = time.isFinite ? time : 0
        return 0.5 + 0.5 * sin(shimmerFrequency * along + shimmerSpeed * s)
    }

    /// The pulse bead intensity 0 ... 1 on the ribbon at signed timeline coordinate `t`, `time` seconds and `pulses`
    /// beads (clamped to 0 ... ``maxPulses``): bead i's head sits at fract(sign(t) ``pulseSpeed`` time + i /
    /// max(pulses, 1)) along |t|, so beads run left to right where t ≥ 0 and right to left where t < 0; the intensity
    /// is the largest 1 - smoothstep(0, ``pulseWidth``, wrapped distance to a head). 0 when `pulses` is 0 (level-2).
    public static func pulseIntensity(t: Double, time: Double, pulses: Double) -> Double {
        let along: Double = t.isFinite ? min(abs(t), 1) : 0
        let direction: Double = (t.isFinite && t < 0) ? -1 : 1
        let s: Double = time.isFinite ? time : 0
        let count: Double = pulses.isFinite ? min(max(pulses, 0), Double(maxPulses)) : 0
        var bead: Double = 0
        for i in 0..<maxPulses where Double(i) < count {
            let raw: Double = direction * pulseSpeed * s + Double(i) / max(count, 1)
            let head: Double = raw - raw.rounded(.down)
            var gap: Double = abs(along - head)
            gap = min(gap, 1 - gap)
            let x: Double = min(max(gap / pulseWidth, 0), 1)
            bead = max(bead, 1 - x * x * (3 - 2 * x))
        }
        return bead
    }
}
