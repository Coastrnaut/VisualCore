// NocturneGardenShaders — feature 383 (R02-G09-03) T-R02G0903-003 (FR-R02G0903-002, FR-R02G0903-004, FR-R02G0903-006;
// clarifications Q1–Q4 on the scene, the tiers, the palette and Reduce Motion and Reduce Flashing). The two GLSL ES
// 3.00 programs of Nocturne Garden held as source text (data: the core issues no GL call), with the names of every
// uniform they declare, their vertex attributes, the material codes shared with `NocturneGardenSceneGeometry`, the
// constants the sources are built from and the CPU references of what they compute.
//
// Garden program: the midnight ground, the pearlescent mist bed, the deep black shadow with its feathered edge, the
// gold target rim, the coral forbidden hatch, the leak cross, the dark botanical bodies (heads, stems, leaves) with
// their coral-gold rims, the lantern and the spent and unspent bars of the move gauge. Mesh layout (data model, "Mesh
// streams"): `a_normal` is the surface normal, `a_uv.x` the material code (see `GardenMaterial`: 0 ground, 1 mist,
// 2 shadow, 3 target rim, 4 forbidden hatch, 5 leak cross, 6 bloom body, 7 leaf or stem, 8 lantern, 9 spent bar,
// 10 unspent bar, 11 head rim), `a_uv.y` the vertex shade 0 ... 1 (a brightness factor, 1 for full colour), except on
// the shadow, where it is the shadow cover: 1 inside the shadow, falling to 0 across the feather band at the shadow's
// edge (the geometry builds the band of the tier's `feather` width; at `feather` 0 there is no band, so every shadow
// vertex has cover 1 and the edges are hard). Lighting is an ambient term plus Lambert from `u_lightDir`; the signal
// materials (target rim, hatch, leak cross, lantern, spent bar, head rim) are mostly emissive (``emission``), so their
// colour cues hold under any light.
// Mist: the mist colour, a pearlescent sheen toward the mist highlight at grazing angles (`u_eye` gives the view
// direction) and up to ``maxMistLayers`` (3) drifting layers, bands of highlight tinted slightly toward gold sliding
// across the bed with `u_time` (the only time source); only the first `u_mistLayers` layers (the tier's `mistLayers`,
// clamped to 0 ... 3) count; the loop is bounded by the constant 3. Shadow: the lit mist mixed toward the lit shadow
// colour by smoothstep of the cover, opaque, so the feathered edge needs no blending. Forbidden hatch: a diagonal
// hatch computed from the world position (lines of coral along x + y, gaps a coral-tinted mist), so the cue is a
// pattern as well as a colour. Bloom body and leaf or stem: the dark body colour with a fresnel rim of the glow colour
// (strong on heads, faint on stems and leaves). Bodies, stems, leaves and head rims sway in the vertex shader by
// ``sway(position:time:)``, at most ``swayAmplitude`` model units along x, also driven by `u_time` alone. Reduce
// Motion needs nothing here: the scene passes `u_time` = 0, so the mist and the blooms stand still.
//
// Glow program: the glow shells over the blooms' heads and the lantern, drawn additively. The colour is carried in
// `a_normal` (the mesh builder writes a `NocturneGardenPalette` colour there, `glow` for heads, `lantern` for the
// lantern), `a_uv.x` is the glow weight 0 ... 1 and `a_uv.y` is 0. The glow is the colour lifted toward the lantern by
// ``coreLift`` times the glow weight and the glow gain, with alpha ``glowWeight`` times the same; the glow gain is
// `u_glow` capped by `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing the presenter passes
// ``glowGainCap`` as the limit. The glow program has no time input: it never pulses.
//
// Attributes follow VisualCoreRendering's `ShaderMeshRenderer`: `a_position` (location 0), `a_normal` (location 1)
// from `Mesh.interleavedPositionNormal()` and `a_uv` (location 2) from `Mesh.uvs`. Every source starts with
// `#version 300 es` (VisualCoreShaderSource's `ShaderLibrary.versionLine`) and states one float precision. Plain
// uniforms (at most 16 vec4 slots per program; the garden program uses 8, the glow program 6), no texture samplers,
// no image assets, no `discard` and one loop, bounded by a constant. Output is premultiplied alpha. Palette constants
// are written with six fixed decimals from `NocturneGardenPalette`, so the shader colours equal the CPU's within 1/255.

import Foundation

/// The GLSL ES 3.00 sources of Nocturne Garden's garden and glow programs, their uniform and attribute names, the
/// material codes, the constants they are built from and the CPU references of what they compute (FR-R02G0903-002).
public enum NocturneGardenShaders {
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
    /// `float`: presentation time in seconds, the only time source of the mist drift and the bloom sway (garden, both
    /// stages); the scene passes 0 under Reduce Motion, so mist and blooms stand still.
    public static let timeUniform = "u_time"
    /// `vec3`: the direction toward the light in model units (garden; normalised by the shader).
    public static let lightDirectionUniform = "u_lightDir"
    /// `vec3`: the camera position in model units (garden), for the view direction of the sheen and the rims.
    public static let eyeUniform = "u_eye"
    /// `float`: the tier's `mistLayers`, clamped by the shader to 0 ... ``maxMistLayers`` (garden); see
    /// ``mistLayers(for:)``.
    public static let mistLayersUniform = "u_mistLayers"
    /// `float`: the glow gain (glow); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowUniform = "u_glow"
    /// `float`: the glow limit (glow): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the garden program declares, each once, in order of first declaration (vertex stage first;
    /// `u_time` is declared in both stages).
    public static let gardenUniforms: [String] = [mvpUniform, timeUniform, lightDirectionUniform, eyeUniform,
                                                  mistLayersUniform]

    /// Every uniform the glow program declares, exactly as declared (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowUniform, glowLimitUniform]

    /// The uniform lists per program name (`garden`, `glow`).
    public static let uniformNames: [String: [String]] = ["garden": gardenUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Material codes

    /// The material code of the midnight ground plane (`a_uv.x` = 0).
    public static let groundMaterial: Double = GardenMaterial.ground.code
    /// The material code of a pearlescent mist cell of the bed, with the drifting layers (`a_uv.x` = 1).
    public static let mistMaterial: Double = GardenMaterial.mist.code
    /// The material code of a shadow quad or feather band; its `a_uv.y` is the shadow cover, 1 inside the shadow and 0
    /// at the feather band's outer edge (`a_uv.x` = 2).
    public static let shadowMaterial: Double = GardenMaterial.shadow.code
    /// The material code of the gold rim strip along the target's boundary edges (`a_uv.x` = 3).
    public static let targetRimMaterial: Double = GardenMaterial.targetRim.code
    /// The material code of a forbidden cell: a coral diagonal hatch over coral-tinted mist, computed from the world
    /// position (`a_uv.x` = 4).
    public static let forbiddenHatchMaterial: Double = GardenMaterial.forbiddenHatch.code
    /// The material code of the cross on a leaking cell after a leak failure (`a_uv.x` = 5).
    public static let leakCrossMaterial: Double = GardenMaterial.leakCross.code
    /// The material code of a bloom's extruded head body: dark, with a fresnel coral-gold rim; sways (`a_uv.x` = 6).
    public static let bloomBodyMaterial: Double = GardenMaterial.bloomBody.code
    /// The material code of a stem segment or a leaf: dark body, faint rim; sways (`a_uv.x` = 7).
    public static let leafStemMaterial: Double = GardenMaterial.leafStem.code
    /// The material code of the lantern (the sun), emissive (`a_uv.x` = 8).
    public static let lanternMaterial: Double = GardenMaterial.lantern.code
    /// The material code of a spent bar of the move gauge, coral (`a_uv.x` = 9).
    public static let spentBarMaterial: Double = GardenMaterial.spentBar.code
    /// The material code of an unspent bar of the move gauge (`a_uv.x` = 10).
    public static let unspentBarMaterial: Double = GardenMaterial.unspentBar.code
    /// The material code of the glowing rim strip around a bloom's head outline, emissive glow colour; sways
    /// (`a_uv.x` = 11).
    public static let headRimMaterial: Double = GardenMaterial.headRim.code

    // MARK: Constants

    /// The midnight ground, as written into the sources (`NocturneGardenPalette.ground`).
    public static let ground: SIMD3<Double> = NocturneGardenPalette.ground
    /// The pearlescent mist, as written into the sources (`NocturneGardenPalette.mist`).
    public static let mist: SIMD3<Double> = NocturneGardenPalette.mist
    /// The mist highlight of the sheen and the drifting layers (`NocturneGardenPalette.mistHighlight`).
    public static let mistHighlight: SIMD3<Double> = NocturneGardenPalette.mistHighlight
    /// The deep black shadow, as written into the sources (`NocturneGardenPalette.shadow`).
    public static let shadow: SIMD3<Double> = NocturneGardenPalette.shadow
    /// The parchment-gold target rim, as written into the sources (`NocturneGardenPalette.gold`).
    public static let gold: SIMD3<Double> = NocturneGardenPalette.gold
    /// The lantern-coral forbidden hatch, as written into the sources (`NocturneGardenPalette.coral`).
    public static let coral: SIMD3<Double> = NocturneGardenPalette.coral
    /// The leak cross, as written into the sources (`NocturneGardenPalette.leak`).
    public static let leak: SIMD3<Double> = NocturneGardenPalette.leak
    /// The dark botanical body, as written into the sources (`NocturneGardenPalette.body`).
    public static let body: SIMD3<Double> = NocturneGardenPalette.body
    /// The coral-gold glow of the rims, as written into the sources (`NocturneGardenPalette.glow`).
    public static let glow: SIMD3<Double> = NocturneGardenPalette.glow
    /// The lantern, as written into the sources (`NocturneGardenPalette.lantern`).
    public static let lantern: SIMD3<Double> = NocturneGardenPalette.lantern
    /// A spent bar of the move gauge, as written into the sources (`NocturneGardenPalette.spent`).
    public static let spent: SIMD3<Double> = NocturneGardenPalette.spent
    /// An unspent bar of the move gauge, as written into the sources (`NocturneGardenPalette.unspent`).
    public static let unspent: SIMD3<Double> = NocturneGardenPalette.unspent

    /// The garden program's ambient term.
    public static let ambient: Double = 0.6
    /// The garden program's Lambert weight (ambient + diffuse = 1).
    public static let diffuse: Double = 0.4
    /// The share of a signal material's colour that is emission, independent of the light (the rest is Lambert).
    public static let emission: Double = 0.85
    /// The exponent of the fresnel term (1 - |n . v|) ^ power.
    public static let fresnelPower: Double = 3
    /// How far the fresnel term mixes the mist toward the mist highlight (the pearlescent sheen).
    public static let pearlWeight: Double = 0.35
    /// The weight of the glow-coloured fresnel rim on a bloom's head body.
    public static let bodyRimWeight: Double = 0.9
    /// The weight of the glow-coloured fresnel rim on a stem or a leaf.
    public static let stemRimWeight: Double = 0.25
    /// The most drifting mist layers (the richest tier's `mistLayers`; the loop bound).
    public static let maxMistLayers: Int = 3
    /// How far one drifting layer mixes the mist toward its tint, times its band value 0 ... 1.
    public static let mistLayerWeight: Double = 0.18
    /// The spatial frequency of the mist bands in radians per model unit.
    public static let mistFrequency: Double = 5
    /// The drift rate of mist layer 0 in radians per second; layer i drifts at (i + 1) times it.
    public static let mistSpeed: Double = 0.35
    /// How far layer i's tint moves from the mist highlight toward gold, times i (pearlescent hue shift).
    public static let mistTintStep: Double = 0.15
    /// The hatch periods per model unit, measured along x + y (diagonal lines).
    public static let hatchFrequency: Double = 14
    /// The share of a hatch period that is a coral line (the rest is the gap).
    public static let hatchWidth: Double = 0.4
    /// How far a hatch gap mixes the mist toward coral, so a forbidden cell is warm everywhere.
    public static let hatchGapTint: Double = 0.6
    /// The largest sway offset along x, in model units.
    public static let swayAmplitude: Double = 0.008
    /// The sway rate in radians per second.
    public static let swaySpeed: Double = 1.1
    /// The sway phase per model unit of x (neighbouring blooms sway out of step).
    public static let swayPhase: Double = 1.3
    /// The height (model y) above which a vertex sways by the full amplitude; below it the sway falls linearly to 0
    /// at y = 0, so the feet stay planted.
    public static let swayHeight: Double = 0.5

    /// The alpha weight of the glow, times the glow gain and the glow weight of the vertex.
    public static let glowWeight: Double = 0.5
    /// How far the glow lifts a colour toward the lantern, times the glow gain and the glow weight.
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

    /// A garden material code, written into `a_uv.x` of a garden-program vertex (shared with the geometry).
    public enum GardenMaterial: Int, Sendable, CaseIterable, Hashable {
        /// The midnight ground plane (lit).
        case ground = 0
        /// A mist cell of the bed: pearlescent sheen and drifting layers (lit).
        case mist = 1
        /// A shadow quad or feather band; `a_uv.y` is the cover (1 shadow ... 0 mist).
        case shadow = 2
        /// The gold rim strip along the target's boundary edges (emissive).
        case targetRim = 3
        /// A forbidden cell: coral diagonal hatch over coral-tinted mist (emissive).
        case forbiddenHatch = 4
        /// The cross on a leaking cell (emissive).
        case leakCross = 5
        /// A bloom's head body: dark with a strong fresnel rim (lit; sways).
        case bloomBody = 6
        /// A stem segment or a leaf: dark with a faint fresnel rim (lit; sways).
        case leafStem = 7
        /// The lantern (emissive).
        case lantern = 8
        /// A spent bar of the move gauge (emissive).
        case spentBar = 9
        /// An unspent bar of the move gauge (lit).
        case unspentBar = 10
        /// The glowing rim strip around a bloom's head outline (emissive; sways).
        case headRim = 11

        /// The `a_uv.x` value of the material.
        public var code: Double { Double(rawValue) }

        /// The material's colour as the garden vertex shader selects it (before shade, light and patterns).
        public var colour: SIMD3<Double> {
            switch self {
            case .ground: NocturneGardenShaders.ground
            case .mist: NocturneGardenShaders.mist
            case .shadow: NocturneGardenShaders.shadow
            case .targetRim: NocturneGardenShaders.gold
            case .forbiddenHatch: NocturneGardenShaders.coral
            case .leakCross: NocturneGardenShaders.leak
            case .bloomBody: NocturneGardenShaders.body
            case .leafStem: NocturneGardenShaders.body
            case .lantern: NocturneGardenShaders.lantern
            case .spentBar: NocturneGardenShaders.spent
            case .unspentBar: NocturneGardenShaders.unspent
            case .headRim: NocturneGardenShaders.glow
            }
        }

        /// Whether the material is mostly emissive (``NocturneGardenShaders/emission``) rather than lit.
        public var isEmissive: Bool {
            switch self {
            case .targetRim, .forbiddenHatch, .leakCross, .lantern, .spentBar, .headRim: true
            default: false
            }
        }

        /// Whether the material sways with `u_time` (``NocturneGardenShaders/sway(position:time:)``).
        public var sways: Bool {
            switch self {
            case .bloomBody, .leafStem, .headRim: true
            default: false
            }
        }
    }

    // MARK: Sources

    /// `x` with six fixed decimals, as the sources write every constant.
    static func fixed(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String { "vec3(\(fixed(v.x)), \(fixed(v.y)), \(fixed(v.z)))" }

    /// The garden vertex shader. Uniforms: `u_mvp`, `u_time`. Selects the material colour from `a_uv.x`, scales it by
    /// the shade `a_uv.y` (not on the shadow, whose `a_uv.y` is the cover), sways bodies, stems, leaves and head rims
    /// (``sway(position:time:)``) and passes the normal, the model position, the material code and `a_uv.y`.
    public static let gardenVertex = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_time;
    out vec3 v_normal;
    out vec3 v_base;
    out vec3 v_position;
    out float v_material;
    out float v_shade;
    const vec3 NG_GROUND = \(vec3Literal(ground));
    const vec3 NG_MIST = \(vec3Literal(mist));
    const vec3 NG_SHADOW = \(vec3Literal(shadow));
    const vec3 NG_GOLD = \(vec3Literal(gold));
    const vec3 NG_CORAL = \(vec3Literal(coral));
    const vec3 NG_LEAK = \(vec3Literal(leak));
    const vec3 NG_BODY = \(vec3Literal(body));
    const vec3 NG_LANTERN = \(vec3Literal(lantern));
    const vec3 NG_SPENT = \(vec3Literal(spent));
    const vec3 NG_UNSPENT = \(vec3Literal(unspent));
    const vec3 NG_GLOW = \(vec3Literal(glow));
    const float NG_SWAY_AMPLITUDE = \(fixed(swayAmplitude));
    const float NG_SWAY_SPEED = \(fixed(swaySpeed));
    const float NG_SWAY_PHASE = \(fixed(swayPhase));
    const float NG_SWAY_HEIGHT = \(fixed(swayHeight));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, 11.0);
        float isShadow = isCode(m, 2.0);
        vec3 base = mix(NG_GROUND, NG_MIST, isCode(m, 1.0));
        base = mix(base, NG_SHADOW, isShadow);
        base = mix(base, NG_GOLD, isCode(m, 3.0));
        base = mix(base, NG_CORAL, isCode(m, 4.0));
        base = mix(base, NG_LEAK, isCode(m, 5.0));
        base = mix(base, NG_BODY, isCode(m, 6.0));
        base = mix(base, NG_BODY, isCode(m, 7.0));
        base = mix(base, NG_LANTERN, isCode(m, 8.0));
        base = mix(base, NG_SPENT, isCode(m, 9.0));
        base = mix(base, NG_UNSPENT, isCode(m, 10.0));
        base = mix(base, NG_GLOW, isCode(m, 11.0));
        float shade = clamp(a_uv.y, 0.0, 1.0);
        float sways = isCode(m, 6.0) + isCode(m, 7.0) + isCode(m, 11.0);
        float rise = clamp(a_position.y / NG_SWAY_HEIGHT, 0.0, 1.0);
        float swing = NG_SWAY_AMPLITUDE * rise * sin(NG_SWAY_SPEED * u_time + NG_SWAY_PHASE * a_position.x);
        vec3 position = a_position + vec3(sways * swing, 0.0, 0.0);
        v_base = base * mix(shade, 1.0, isShadow);
        v_normal = a_normal;
        v_position = position;
        v_material = m;
        v_shade = shade;
        gl_Position = u_mvp * vec4(position, 1.0);
    }
    """

    /// The garden fragment shader. Uniforms: `u_lightDir`, `u_eye`, `u_time`, `u_mistLayers`. Ambient ``ambient`` plus
    /// Lambert ``diffuse`` (``gardenShade(base:normalDotLight:)``), or mostly ``emission`` for the signal materials
    /// (``emissiveShade(base:normalDotLight:)``); the mist adds the pearlescent sheen (``fresnel(normalDotView:)``) and
    /// the first `u_mistLayers` of ``maxMistLayers`` drifting layers (``mistBand(layer:time:position:)``); the shadow
    /// mixes the lit mist toward the lit shadow by ``shadowCover(shade:)``; a forbidden cell is hatched
    /// (``hatch(position:)``); bodies, stems and leaves carry the glow-coloured fresnel rim. Opaque, premultiplied.
    public static let gardenFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_normal;
    in vec3 v_base;
    in vec3 v_position;
    in float v_material;
    in float v_shade;
    uniform vec3 u_lightDir;
    uniform vec3 u_eye;
    uniform float u_time;
    uniform float u_mistLayers;
    out vec4 color;
    const vec3 NG_MIST = \(vec3Literal(mist));
    const vec3 NG_MIST_HIGHLIGHT = \(vec3Literal(mistHighlight));
    const vec3 NG_GOLD = \(vec3Literal(gold));
    const vec3 NG_CORAL = \(vec3Literal(coral));
    const vec3 NG_GLOW = \(vec3Literal(glow));
    const int NG_MAX_LAYERS = \(maxMistLayers);
    const float NG_AMBIENT = \(fixed(ambient));
    const float NG_DIFFUSE = \(fixed(diffuse));
    const float NG_EMISSION = \(fixed(emission));
    const float NG_FRESNEL_POWER = \(fixed(fresnelPower));
    const float NG_PEARL_WEIGHT = \(fixed(pearlWeight));
    const float NG_BODY_RIM = \(fixed(bodyRimWeight));
    const float NG_STEM_RIM = \(fixed(stemRimWeight));
    const float NG_MIST_WEIGHT = \(fixed(mistLayerWeight));
    const float NG_MIST_FREQUENCY = \(fixed(mistFrequency));
    const float NG_MIST_SPEED = \(fixed(mistSpeed));
    const float NG_MIST_TINT_STEP = \(fixed(mistTintStep));
    const float NG_HATCH_FREQUENCY = \(fixed(hatchFrequency));
    const float NG_HATCH_WIDTH = \(fixed(hatchWidth));
    const float NG_HATCH_GAP_TINT = \(fixed(hatchGapTint));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = floor(v_material + 0.5);
        float isMist = isCode(m, 1.0);
        float isShadow = isCode(m, 2.0);
        float isHatch = isCode(m, 4.0);
        float isBody = isCode(m, 6.0);
        float isStem = isCode(m, 7.0);
        float emissive = isCode(m, 3.0) + isHatch + isCode(m, 5.0) + isCode(m, 8.0) + isCode(m, 9.0) + isCode(m, 11.0);
        vec3 n = v_normal / max(length(v_normal), 0.0001);
        vec3 l = u_lightDir / max(length(u_lightDir), 0.0001);
        vec3 e = u_eye - v_position;
        vec3 v = e / max(length(e), 0.0001);
        float lambert = max(dot(n, l), 0.0);
        float facing = clamp(abs(dot(n, v)), 0.0, 1.0);
        float fresnel = pow(1.0 - facing, NG_FRESNEL_POWER);
        float light = NG_AMBIENT + NG_DIFFUSE * lambert;
        float glowLight = NG_EMISSION + (1.0 - NG_EMISSION) * lambert;
        vec3 base = clamp(v_base, 0.0, 1.0);
        vec3 lit = base * mix(light, glowLight, clamp(emissive, 0.0, 1.0));
        float layers = clamp(u_mistLayers, 0.0, float(NG_MAX_LAYERS));
        vec3 pearl = mix(NG_MIST, NG_MIST_HIGHLIGHT, NG_PEARL_WEIGHT * fresnel);
        for (int i = 0; i < NG_MAX_LAYERS; i++) {
            float on = 1.0 - step(layers, float(i));
            float k = float(i);
            vec2 axis = vec2(cos(2.094395 * k + 0.5), sin(2.094395 * k + 0.5));
            float phase = NG_MIST_FREQUENCY * dot(v_position.xy, axis) + 2.094395 * k;
            float band = 0.5 + 0.5 * sin(phase + NG_MIST_SPEED * (k + 1.0) * u_time);
            vec3 tint = mix(NG_MIST_HIGHLIGHT, NG_GOLD, NG_MIST_TINT_STEP * k);
            pearl = mix(pearl, tint, on * NG_MIST_WEIGHT * band);
        }
        vec3 mistLit = pearl * light;
        vec3 mistColour = mistLit * clamp(v_shade, 0.0, 1.0);
        float cover = smoothstep(0.0, 1.0, clamp(v_shade, 0.0, 1.0));
        vec3 shadowColour = mix(mistLit, lit, cover);
        float stripe = fract((v_position.x + v_position.y) * NG_HATCH_FREQUENCY);
        float line = 1.0 - step(NG_HATCH_WIDTH, stripe);
        vec3 gap = mix(NG_MIST, NG_CORAL, NG_HATCH_GAP_TINT) * glowLight * clamp(v_shade, 0.0, 1.0);
        vec3 hatchColour = mix(gap, lit, line);
        vec3 bodyColour = lit + NG_GLOW * (NG_BODY_RIM * fresnel * isBody + NG_STEM_RIM * fresnel * isStem);
        vec3 rgb = mix(lit, mistColour, isMist);
        rgb = mix(rgb, shadowColour, isShadow);
        rgb = mix(rgb, hatchColour, isHatch);
        rgb = mix(rgb, bodyColour, clamp(isBody + isStem, 0.0, 1.0));
        rgb = clamp(rgb, 0.0, 1.0);
        float alpha = 1.0;
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`) and the glow weight (`a_uv.x`).
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
    const vec3 NG_LANTERN = \(vec3Literal(lantern));
    const float NG_GLOW_WEIGHT = \(fixed(glowWeight));
    const float NG_CORE = \(fixed(coreLift));
    const float NG_MAX_GAIN = \(fixed(maxGlowGain));
    void main() {
        float gain = min(clamp(u_glow, 0.0, NG_MAX_GAIN), clamp(u_glowLimit, 0.0, NG_MAX_GAIN));
        vec3 rgb = mix(v_colour, NG_LANTERN, clamp(NG_CORE * gain * v_glow, 0.0, 1.0));
        float alpha = clamp(NG_GLOW_WEIGHT * gain * v_glow, 0.0, 1.0);
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
    public static func glowGain(for tier: NocturneGardenTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The value the presenter passes as `u_mistLayers` at `tier`: its `mistLayers`, clamped to 0 ...
    /// ``maxMistLayers``.
    public static func mistLayers(for tier: NocturneGardenTier) -> Double {
        Double(min(max(tier.mistLayers, 0), maxMistLayers))
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 ... ``maxGlowGain`` (non-finite
    /// counts as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow for a vertex `colour`, glow weight `glow` and the applied `gain`, before premultiplying: the colour
    /// lifted toward the lantern by ``coreLift`` gain glow (rgb) and the alpha ``glowWeight`` gain glow, every
    /// component clamped to 0 ... 1.
    public static func glowColour(colour: SIMD3<Double>, glow: Double, gain: Double) -> SIMD4<Double> {
        func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }
        let c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        let g: Double = unit(glow)
        let k: Double = gain.isFinite ? gain : 0
        let lift: Double = unit(coreLift * k * g)
        let lifted: SIMD3<Double> = c + (lantern - c) * lift
        return SIMD4<Double>(unit(lifted.x), unit(lifted.y), unit(lifted.z), unit(glowWeight * k * g))
    }

    /// The lit colour of a lit material colour `base` (after shade) and n . l `normalDotLight`: base x (``ambient`` +
    /// ``diffuse`` max(n . l, 0)), every component in 0 ... 1.
    public static func gardenShade(base: SIMD3<Double>, normalDotLight: Double) -> SIMD3<Double> {
        shade(base: base, weight: ambient + diffuse * max(normalDotLight.isFinite ? normalDotLight : 0, 0))
    }

    /// The colour of an emissive material colour `base` (after shade) and n . l `normalDotLight`: base x
    /// (``emission`` + (1 - ``emission``) max(n . l, 0)), every component in 0 ... 1.
    public static func emissiveShade(base: SIMD3<Double>, normalDotLight: Double) -> SIMD3<Double> {
        shade(base: base, weight: emission + (1 - emission) * max(normalDotLight.isFinite ? normalDotLight : 0, 0))
    }

    /// `base` clamped to 0 ... 1, times `weight`, clamped to 0 ... 1.
    static func shade(base: SIMD3<Double>, weight: Double) -> SIMD3<Double> {
        func unit(_ x: Double) -> Double { min(max(x, 0), 1) }
        let b: SIMD3<Double> = SIMD3<Double>(unit(base.x), unit(base.y), unit(base.z))
        let lit: SIMD3<Double> = b * weight
        return SIMD3<Double>(unit(lit.x), unit(lit.y), unit(lit.z))
    }

    /// The fresnel term for n . v `normalDotView`: (1 - |n . v|) ^ ``fresnelPower``, |n . v| clamped to 0 ... 1
    /// (non-finite counts as facing the eye, 0).
    public static func fresnel(normalDotView: Double) -> Double {
        let facing: Double = normalDotView.isFinite ? min(abs(normalDotView), 1) : 1
        return pow(1 - facing, fresnelPower)
    }

    /// The band value 0 ... 1 of mist layer `layer` (0 ... ``maxMistLayers`` - 1) at `time` seconds and model
    /// `position`: 0.5 + 0.5 sin(``mistFrequency`` (p.xy . axis) + layer 2 pi / 3 + ``mistSpeed`` (layer + 1) time),
    /// axis = (cos(layer 2 pi / 3 + 0.5), sin(layer 2 pi / 3 + 0.5)). At `time` 0 (Reduce Motion) it depends on the
    /// position alone.
    public static func mistBand(layer: Int, time: Double, position: SIMD3<Double>) -> Double {
        let t: Double = time.isFinite ? time : 0
        let k: Double = Double(layer)
        let axis: SIMD2<Double> = SIMD2<Double>(cos(2.094395 * k + 0.5), sin(2.094395 * k + 0.5))
        let phase: Double = mistFrequency * (position.x * axis.x + position.y * axis.y) + 2.094395 * k
        return 0.5 + 0.5 * sin(phase + mistSpeed * (k + 1) * t)
    }

    /// The shadow cover 0 ... 1 of shade `shade` (`a_uv.y` of a shadow vertex): smoothstep(0, 1, shade).
    public static func shadowCover(shade: Double) -> Double {
        let x: Double = shade.isFinite ? min(max(shade, 0), 1) : 0
        return x * x * (3 - 2 * x)
    }

    /// Whether the forbidden hatch is a coral line (1) or a gap (0) at model `position`: the fractional part of
    /// (x + y) ``hatchFrequency`` below ``hatchWidth``.
    public static func hatch(position: SIMD3<Double>) -> Double {
        let s: Double = (position.x + position.y) * hatchFrequency
        guard s.isFinite else { return 0 }
        let f: Double = s - s.rounded(.down)
        return f < hatchWidth ? 1 : 0
    }

    /// The colour of a hatch gap before light: the mist mixed toward coral by ``hatchGapTint``.
    public static var hatchGap: SIMD3<Double> { mist + (coral - mist) * hatchGapTint }

    /// The x offset of a swaying vertex (bloom body, leaf or stem, head rim) at model `position` and `time` seconds:
    /// ``swayAmplitude`` clamp(y / ``swayHeight``, 0, 1) sin(``swaySpeed`` time + ``swayPhase`` x). Its magnitude is at
    /// most ``swayAmplitude``; at `time` 0 (Reduce Motion) it depends on the position alone.
    public static func sway(position: SIMD3<Double>, time: Double) -> Double {
        let t: Double = time.isFinite ? time : 0
        let rise: Double = position.y.isFinite ? min(max(position.y / swayHeight, 0), 1) : 0
        let x: Double = position.x.isFinite ? position.x : 0
        return swayAmplitude * rise * sin(swaySpeed * t + swayPhase * x)
    }
}
