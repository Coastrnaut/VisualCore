// MicroscopicAuroraShaders — feature 483 (R02-G19-03) T-R02G1903-003 (FR-R02G1903-001, 002, 004; clarifications
// Q1–Q4). The two GLSL ES 3.00 programs of Microscopic Aurora held as source text (data: the core issues no GL call),
// with the names of every uniform they declare, their vertex attributes (the three `ShaderMeshRenderer` streams), the
// material codes shared with `MicroscopicAuroraSceneGeometry` (``MicroscopicAuroraMaterial``), the constants the
// sources are built from and the CPU references of what they compute. Presentation only: no rule is ever evaluated on
// these values, and nothing drawn is consulted by the rules.
//
// Dish program: the still water backdrop (a vertical gradient from abyss to abyss top, no specks), the dish field, the
// fronds, the rim, the stencil outlines (lit in the lit colour on a won level), the lit and stray cells, the site
// rings, the well spirals and their arrowheads, the ribbons (soft edge, an emissive core and an opacity both fading to
// the tail; brightened on a won level), the swimmer capsules and their heliotrope tail tips (layered core, limb
// darkening and rim light from the capsule normal on the richer tiers; flat on level-2), the gauge tracks, the
// requirement ticks, the marks (filled when met, hollow when not), the lit and unlit actions bars and the broken
// colour of what a failure names.
//
// Nothing moves by time: there is no star pulse and no time uniform in this game (unlike the model program of feature
// 473); the shown tick is chosen by the adapter and baked into the geometry, so Reduce Motion needs no shader input.
//
// Vertex streams (the geometry states the same contract): `a_uv.x` is the material code (``MicroscopicAuroraMaterial``,
// 0 … 19) — on a ribbon plus ``MicroscopicAuroraShaders/alongScale`` times the along coordinate (0 at the tail, 1 at
// the head; ``MicroscopicAuroraShaders/ribbonCode(along:)``), so the tail fade travels in uv — `a_uv.y` the primary
// local coordinate and `a_normal` the capsule normal or a secondary local coordinate. Per material: on the backdrop
// `a_uv.y` is the height h (0 at the bottom, 1 at the top), `a_normal` zero; on a flat fill (field, arrowhead)
// `a_uv.y` and `a_normal` are 0; on a strip (frond, rim, stencil, site, well spiral, ribbon, gauge track, requirement
// tick, broken) `a_uv.y` is the across coordinate d, -1 on one long side and +1 on the other, `a_normal` zero; on a
// capsule (swimmer, tail tip) `a_normal` is the surface normal in world space and `a_uv.y` 0 (a level-2 flat capsule:
// `a_normal` zero, so it is shaded flat, and `a_uv.y` the across coordinate, 0 on the axis and ±1 on the outline); on
// a cell or mark quad (lit cell, stray cell, met mark, unmet mark) `a_normal.xy` is the quad-local coordinate (u, v),
// the shape spanning -1 … +1 and the quad ``MicroscopicAuroraShaders/markQuadExtent``, `a_uv.y` 0; on a bar fan
// `a_uv.y` is 0 at the centre vertex and 1 on every outline vertex.
//
// Signed-distance shading: the soft outline coverage 1 - smoothstep(1 - ``edgeFeather``, 1, |d|) on every strip,
// capsule and bar; the ribbons use the wider ``ribbonFeather``; the backdrop and flat fills are opaque. A cell is the
// square max(|u|, |v|) ≤ 1, a filled mark the unit disc and a hollow mark a ring of half-width ``markRingHalf`` inside
// it, all feathered by ``markFeather``. A capsule is shaded in three layers from mu = n · ``viewDirection``: the limb
// from its colour times ``limbShade`` to its colour, the core lifted toward white, the rim light toward the glow
// colour at grazing angles. The fragment shader selects every code exactly once, so each pixel has one coverage rule.
//
// Glow program: the glow shells around the swimmers and along the ribbons, drawn additively and last. The colour is
// carried in `a_normal` (a zero colour falls back by kind), `a_uv.x` is 2 · kind + factor (``GlowKind``: 0 swimmer,
// 1 ribbon; factor 0 … 1) and `a_uv.y` the shell's radial coordinate r, 0 on its inner edge and 1 on its outer edge.
// The alpha is ``glowWeight`` times the gain, the factor and (1 - r)²; a ribbon shell's factor is times
// ``ribbonRest``, rising to 1 with `u_won`; the gain is `u_glowGain` capped by `u_glowLimit` (both clamped to
// ``maxGlowGain``); under Reduce Flashing the presenter passes ``glowGainCap`` as the limit, so no glow, the won
// brightening included, exceeds the cap.
//
// Plain uniforms in the default block (at most 16 vec4 slots per program; the dish program uses 5: u_mvp 4, u_won 1;
// the glow program 7: u_mvp 4, u_glowGain, u_glowLimit and u_won 1 each), no texture samplers, no image assets, no
// `discard` and no loops at all (so every loop is bounded). Output is premultiplied alpha. Palette constants are
// written with six fixed decimals from `MicroscopicAuroraPalette`, so the shader colours equal the CPU's within 1e-6.

import Foundation

/// The material code a dish-program vertex carries in `a_uv.x` (FR-R02G1903-001, 002): one per kind of element the
/// geometry draws, 0 … 19. The geometry writes ``code`` (a ribbon writes
/// ``MicroscopicAuroraShaders/ribbonCode(along:)``); the dish vertex shader selects ``paletteConstant``.
public enum MicroscopicAuroraMaterial: Int, Sendable, CaseIterable, Hashable {
    /// The water backdrop quad (opaque; `a_uv.y` height h 0 … 1), the still gradient from abyss to abyss top.
    case backdrop = 0
    /// The dish field disc (flat fill), field colour.
    case field = 1
    /// A decorative frond segment (strip), frond colour; drawn at the two richer tiers only.
    case frond = 2
    /// The enclosure's rim ring (strip), rim colour.
    case rim = 3
    /// A stencil cell's outline (strip), stencil colour; lit in the lit colour on a won level.
    case stencil = 4
    /// A lit stencil cell (cell quad; `a_normal.xy` quad-local u, v), lit colour.
    case litCell = 5
    /// A lit cell outside the stencil (cell quad), stray colour.
    case strayCell = 6
    /// A well site's ring (strip), site colour.
    case siteRing = 7
    /// A well's spiral (strip), well colour.
    case wellSpiral = 8
    /// A well's arrowhead in the turning sense (flat fill), well colour.
    case wellArrow = 9
    /// A swimmer's ribbon trail (strip, soft edge, emissive core; `a_uv.x` carries the along coordinate), ribbon
    /// colour; brightened on a won level.
    case ribbon = 10
    /// A swimmer's capsule (layered from the normal, or flat with a zero normal), swimmer colour.
    case swimmer = 11
    /// A swimmer's tail tip (shaded as a capsule), heliotrope (the site colour).
    case swimmerTail = 12
    /// A gauge track (strip), stencil colour.
    case gaugeTrack = 13
    /// A gauge's requirement tick (strip), well colour.
    case requirementTick = 14
    /// A met gauge's mark: a filled disc (mark quad), met colour.
    case markMet = 15
    /// An unmet gauge's mark: a hollow ring (mark quad), unmet colour.
    case markUnmet = 16
    /// A lit actions bar, an action left (fan).
    case barLit = 17
    /// An unlit actions bar, an action spent (fan).
    case barUnlit = 18
    /// What a failure names: the escaping swimmer or its rim mark, a swimmer outside the largest group, an unlit
    /// stencil outline, the named cell (strip or capsule geometry in the broken colour).
    case broken = 19

    /// The value the geometry writes into `a_uv.x` (a ribbon adds its along coordinate; see
    /// ``MicroscopicAuroraShaders/ribbonCode(along:)``).
    public var code: Float { Float(rawValue) }

    /// The GLSL palette constant the dish vertex shader selects for this material.
    public var paletteConstant: String {
        switch self {
        case .backdrop: return "MA_ABYSS"
        case .field: return "MA_FIELD"
        case .frond: return "MA_FROND"
        case .rim: return "MA_RIM"
        case .stencil, .gaugeTrack: return "MA_STENCIL"
        case .litCell: return "MA_LIT"
        case .strayCell: return "MA_STRAY"
        case .siteRing, .swimmerTail: return "MA_SITE"
        case .wellSpiral, .wellArrow, .requirementTick: return "MA_WELL"
        case .ribbon: return "MA_RIBBON"
        case .swimmer: return "MA_SWIMMER"
        case .markMet: return "MA_MET"
        case .markUnmet: return "MA_UNMET"
        case .barLit: return "MA_ACTIONS_LIT"
        case .barUnlit: return "MA_ACTIONS_UNLIT"
        case .broken: return "MA_BROKEN"
        }
    }

    /// The palette colour of ``paletteConstant`` (the base colour before shading, on a level not won).
    public var baseColour: SIMD3<Double> {
        for entry in MicroscopicAuroraShaders.paletteConstants where entry.name == paletteConstant {
            return entry.colour
        }
        return MicroscopicAuroraPalette.abyss
    }

    /// The material of code `x` as the vertex shader decodes it: rounded to the nearest integer and clamped to 0 … 19
    /// (non-finite counts as the backdrop). A ribbon code with its along share (at most ``alongScale`` above 10)
    /// decodes to the ribbon.
    public static func decode(_ x: Double) -> MicroscopicAuroraMaterial {
        guard x.isFinite else { return .backdrop }
        let maxCode: Double = Double(MicroscopicAuroraMaterial.broken.rawValue)
        let m: Int = Int(min(max((x + 0.5).rounded(.down), 0), maxCode))
        return MicroscopicAuroraMaterial(rawValue: m) ?? .backdrop
    }
}

/// The GLSL ES 3.00 sources of Microscopic Aurora's dish and glow programs, their uniform and attribute names, the
/// constants they are built from and the CPU references of what they compute (FR-R02G1903-001, 002, 004).
public enum MicroscopicAuroraShaders {
    /// A glow-program vertex kind, encoded with the glow factor into `a_uv.x` as 2 · kind + factor.
    public enum GlowKind: Int, Sendable, CaseIterable, Hashable {
        /// A glow shell around a swimmer (zero colour: the glow colour).
        case swimmer = 0
        /// A glow shell along a ribbon (zero colour: the ribbon colour); its factor is times ``ribbonRest``, rising
        /// to 1 with `u_won`.
        case ribbon = 1

        /// The `a_uv.x` value of a vertex of this kind with glow factor `factor` (clamped to 0 … 1; non-finite counts
        /// as 0).
        public func code(factor: Double) -> Double {
            let f: Double = factor.isFinite ? min(max(factor, 0), 1) : 0
            return Double(2 * rawValue) + f
        }

        /// The (kind, factor) the glow vertex shader decodes from `a_uv.x`: kind ⌊x / 2⌋ clamped to 0 … 1, factor
        /// x - 2 · kind clamped to 0 … 1 (x clamped to 0 … 3; non-finite counts as 0).
        public static func decode(_ x: Double) -> (kind: GlowKind, factor: Double) {
            let v: Double = x.isFinite ? min(max(x, 0), 3) : 0
            let k: Int = min(max(Int((v * 0.5).rounded(.down)), 0), 1)
            let factor: Double = min(max(v - Double(2 * k), 0), 1)
            return (kind: GlowKind(rawValue: k) ?? .swimmer, factor: factor)
        }
    }

    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine: String = "#version 300 es"

    /// The vertex attributes both programs read, as (name, location): `a_position` (vec3, 0), `a_normal` (vec3, 1)
    /// and `a_uv` (vec2, 2), as `ShaderMeshRenderer` binds them.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]

    /// Every material as (Swift name, code, GLSL palette constant the dish vertex shader selects), codes 0 … 19.
    public static var materials: [(name: String, code: Float, constant: String)] {
        var result: [(name: String, code: Float, constant: String)] = []
        for material in MicroscopicAuroraMaterial.allCases {
            result.append((name: "\(material)", code: material.code, constant: material.paletteConstant))
        }
        return result
    }

    // MARK: Uniform names

    /// `mat4`: projection x view x model (both programs, vertex stage; model = identity, positions in world space).
    public static let mvpUniform: String = "u_mvp"
    /// `float`: the won level's light, 0 … 1 (dish vertex stage: lights every stencil outline in the lit colour; dish
    /// fragment stage, through the vertex output: brightens the ribbons; glow fragment stage: raises the ribbon
    /// shells' rest to 1); 0 on a level not won.
    public static let wonUniform: String = "u_won"
    /// `float`: the glow gain (glow fragment stage); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform: String = "u_glowGain"
    /// `float`: the glow limit (glow fragment stage): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform: String = "u_glowLimit"

    /// Every uniform the dish program declares, each once, in order of declaration (vertex stage first).
    public static let dishUniforms: [String] = [mvpUniform, wonUniform]

    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, wonUniform]

    /// The uniform lists per program name (`dish`, `glow`).
    public static let uniformNames: [String: [String]] = ["dish": dishUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), one per palette colour.
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = [
        (name: "MA_ABYSS", colour: MicroscopicAuroraPalette.abyss),
        (name: "MA_ABYSS_TOP", colour: MicroscopicAuroraPalette.abyssTop),
        (name: "MA_FIELD", colour: MicroscopicAuroraPalette.field),
        (name: "MA_FROND", colour: MicroscopicAuroraPalette.frond),
        (name: "MA_RIM", colour: MicroscopicAuroraPalette.rim),
        (name: "MA_STENCIL", colour: MicroscopicAuroraPalette.stencil),
        (name: "MA_LIT", colour: MicroscopicAuroraPalette.lit),
        (name: "MA_STRAY", colour: MicroscopicAuroraPalette.stray),
        (name: "MA_SITE", colour: MicroscopicAuroraPalette.site),
        (name: "MA_WELL", colour: MicroscopicAuroraPalette.well),
        (name: "MA_RIBBON", colour: MicroscopicAuroraPalette.ribbon),
        (name: "MA_SWIMMER", colour: MicroscopicAuroraPalette.swimmer),
        (name: "MA_MET", colour: MicroscopicAuroraPalette.met),
        (name: "MA_UNMET", colour: MicroscopicAuroraPalette.unmet),
        (name: "MA_ACTIONS_LIT", colour: MicroscopicAuroraPalette.actionsLit),
        (name: "MA_ACTIONS_UNLIT", colour: MicroscopicAuroraPalette.actionsUnlit),
        (name: "MA_BROKEN", colour: MicroscopicAuroraPalette.broken),
        (name: "MA_GLOW", colour: MicroscopicAuroraPalette.glow),
    ]

    /// The unit direction from the scene toward the authored eye (eye (0, -0.15, 3.4) looking at (0, -0.15, 0)): +z,
    /// the view direction the capsule layers are shaded against.
    public static let viewDirection: SIMD3<Double> = SIMD3<Double>(0, 0, 1)

    /// How much of a ribbon's `a_uv.x` above its code is the along coordinate: x = 10 + alongScale · along. Below 0.5,
    /// so the code still rounds to the ribbon.
    public static let alongScale: Double = 0.4

    /// The width of the soft outline as a share of the across coordinate: coverage falls from 1 at |d| = 1 - feather
    /// to 0 at |d| = 1.
    public static let edgeFeather: Double = 0.25
    /// The wider soft edge of the ribbons.
    public static let ribbonFeather: Double = 0.6

    /// The share of a capsule's colour at its very limb (limb darkening).
    public static let limbShade: Double = 0.55
    /// The mu below which a capsule's limb darkens (smoothstep(0, limbEdge, mu)).
    public static let limbEdge: Double = 0.55
    /// The mu where a capsule's core begins to lift toward white.
    public static let coreStart: Double = 0.85
    /// How far a capsule's core (mu = 1) is lifted toward white.
    public static let coreLift: Double = 0.25
    /// The power of the rim light's rise toward grazing angles, (1 - mu)^power.
    public static let rimPower: Double = 3
    /// How far the rim light lifts a capsule's limb toward the glow colour at mu = 0.
    public static let rimLift: Double = 0.35

    /// The opacity of a ribbon's head on a level not won (1 on a won level); it fades to 0 at the tail.
    public static let ribbonAlpha: Double = 0.85
    /// How far a ribbon's centre line (d = 0) at its head is lifted from the ribbon colour toward white (the emissive
    /// core; times the along coordinate, so it fades to the tail).
    public static let ribbonCore: Double = 0.6
    /// How far a won level lifts the whole ribbon toward white, times `u_won`.
    public static let wonLift: Double = 0.5
    /// The soft edge of a cell or mark in quad-local units: coverage smoothstep(-feather, feather, distance).
    public static let markFeather: Double = 0.06
    /// The half-width of a hollow mark's ring in quad-local units (the ring spans 1 - 2 · half … 1).
    public static let markRingHalf: Double = 0.18
    /// The quad-local extent the geometry's cell and mark quads span on each axis (-extent … +extent), room for the
    /// feather (a lit cell inset by 10 % fills -1 … +1 of a quad spanning the whole cell).
    public static let markQuadExtent: Double = 1.25

    /// The alpha weight of the glow, times the glow gain, the glow factor and the fade.
    public static let glowWeight: Double = 0.5
    /// The share of a ribbon shell's factor shown at rest (rising to 1 with `u_won`).
    public static let ribbonRest: Double = 0.6
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

    /// The dish vertex shader. Uniforms: `u_mvp`, `u_won`. Selects the material colour from `a_uv.x` (a stencil
    /// outline mixed toward the lit colour by `u_won`), decodes a ribbon's along coordinate, and passes the secondary
    /// coordinate or normal (`a_normal`), the material code, the local coordinate and the won light.
    public static let dishVertex: String = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_won;
    out vec3 v_base;
    out vec3 v_aux;
    out float v_material;
    out float v_local;
    out float v_along;
    out float v_won;
    const vec3 MA_ABYSS = \(vec3Literal(MicroscopicAuroraPalette.abyss));
    const vec3 MA_FIELD = \(vec3Literal(MicroscopicAuroraPalette.field));
    const vec3 MA_FROND = \(vec3Literal(MicroscopicAuroraPalette.frond));
    const vec3 MA_RIM = \(vec3Literal(MicroscopicAuroraPalette.rim));
    const vec3 MA_STENCIL = \(vec3Literal(MicroscopicAuroraPalette.stencil));
    const vec3 MA_LIT = \(vec3Literal(MicroscopicAuroraPalette.lit));
    const vec3 MA_STRAY = \(vec3Literal(MicroscopicAuroraPalette.stray));
    const vec3 MA_SITE = \(vec3Literal(MicroscopicAuroraPalette.site));
    const vec3 MA_WELL = \(vec3Literal(MicroscopicAuroraPalette.well));
    const vec3 MA_RIBBON = \(vec3Literal(MicroscopicAuroraPalette.ribbon));
    const vec3 MA_SWIMMER = \(vec3Literal(MicroscopicAuroraPalette.swimmer));
    const vec3 MA_MET = \(vec3Literal(MicroscopicAuroraPalette.met));
    const vec3 MA_UNMET = \(vec3Literal(MicroscopicAuroraPalette.unmet));
    const vec3 MA_ACTIONS_LIT = \(vec3Literal(MicroscopicAuroraPalette.actionsLit));
    const vec3 MA_ACTIONS_UNLIT = \(vec3Literal(MicroscopicAuroraPalette.actionsUnlit));
    const vec3 MA_BROKEN = \(vec3Literal(MicroscopicAuroraPalette.broken));
    const float MA_MAX_MATERIAL = \(fixed(Double(MicroscopicAuroraMaterial.broken.rawValue)));
    const float MA_ALONG_SCALE = \(fixed(alongScale));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, MA_MAX_MATERIAL);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 base = MA_ABYSS;
        base = mix(base, MA_FIELD, isCode(m, 1.0));
        base = mix(base, MA_FROND, isCode(m, 2.0));
        base = mix(base, MA_RIM, isCode(m, 3.0));
        base = mix(base, MA_STENCIL, isCode(m, 4.0));
        base = mix(base, MA_LIT, isCode(m, 5.0));
        base = mix(base, MA_STRAY, isCode(m, 6.0));
        base = mix(base, MA_SITE, isCode(m, 7.0));
        base = mix(base, MA_WELL, isCode(m, 8.0));
        base = mix(base, MA_WELL, isCode(m, 9.0));
        base = mix(base, MA_RIBBON, isCode(m, 10.0));
        base = mix(base, MA_SWIMMER, isCode(m, 11.0));
        base = mix(base, MA_SITE, isCode(m, 12.0));
        base = mix(base, MA_STENCIL, isCode(m, 13.0));
        base = mix(base, MA_WELL, isCode(m, 14.0));
        base = mix(base, MA_MET, isCode(m, 15.0));
        base = mix(base, MA_UNMET, isCode(m, 16.0));
        base = mix(base, MA_ACTIONS_LIT, isCode(m, 17.0));
        base = mix(base, MA_ACTIONS_UNLIT, isCode(m, 18.0));
        base = mix(base, MA_BROKEN, isCode(m, 19.0));
        base = mix(base, MA_LIT, isCode(m, 4.0) * won);
        v_base = base;
        v_aux = a_normal;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0);
        v_along = clamp((a_uv.x - m) / MA_ALONG_SCALE, 0.0, 1.0);
        v_won = won;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The dish fragment shader (no uniforms). The still backdrop gradient (``backdropColour(height:)``), the
    /// signed-distance coverage from the local coordinates (``edgeCoverage(local:)``, ``markCoverage(_:u:v:)``), the
    /// layered or flat capsules (``capsuleShade(_:mu:)``, ``capsuleShade(_:normal:)``) and the ribbons' emissive core
    /// fading to the tail and brightened by the won light (``ribbonColour(across:along:won:)``,
    /// ``ribbonOpacity(across:along:won:)``). Every material code selects exactly one coverage rule. Premultiplied.
    public static let dishFragment: String = """
    #version 300 es
    precision highp float;
    in vec3 v_base;
    in vec3 v_aux;
    in float v_material;
    in float v_local;
    in float v_along;
    in float v_won;
    out vec4 color;
    const vec3 MA_ABYSS = \(vec3Literal(MicroscopicAuroraPalette.abyss));
    const vec3 MA_ABYSS_TOP = \(vec3Literal(MicroscopicAuroraPalette.abyssTop));
    const vec3 MA_GLOW = \(vec3Literal(MicroscopicAuroraPalette.glow));
    const vec3 MA_VIEW_DIR = \(vec3Literal(viewDirection));
    const float MA_EDGE_FEATHER = \(fixed(edgeFeather));
    const float MA_RIBBON_FEATHER = \(fixed(ribbonFeather));
    const float MA_LIMB_SHADE = \(fixed(limbShade));
    const float MA_LIMB_EDGE = \(fixed(limbEdge));
    const float MA_CORE_START = \(fixed(coreStart));
    const float MA_CORE_LIFT = \(fixed(coreLift));
    const float MA_RIM_POWER = \(fixed(rimPower));
    const float MA_RIM_LIFT = \(fixed(rimLift));
    const float MA_RIBBON_ALPHA = \(fixed(ribbonAlpha));
    const float MA_RIBBON_CORE = \(fixed(ribbonCore));
    const float MA_WON_LIFT = \(fixed(wonLift));
    const float MA_MARK_FEATHER = \(fixed(markFeather));
    const float MA_RING_HALF = \(fixed(markRingHalf));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    float markCover(float dist) {
        return smoothstep(-MA_MARK_FEATHER, MA_MARK_FEATHER, dist);
    }
    void main() {
        float m = floor(v_material + 0.5);
        float d = clamp(abs(v_local), 0.0, 1.0);
        float edge = 1.0 - smoothstep(1.0 - MA_EDGE_FEATHER, 1.0, d);
        float ribbon = 1.0 - smoothstep(1.0 - MA_RIBBON_FEATHER, 1.0, d);
        float won = clamp(v_won, 0.0, 1.0);
        float along = clamp(v_along, 0.0, 1.0);
        float sky = isCode(m, 0.0);
        float flatFill = isCode(m, 1.0) + isCode(m, 9.0);
        float strip = isCode(m, 2.0) + isCode(m, 3.0) + isCode(m, 4.0) + isCode(m, 7.0) + isCode(m, 8.0);
        strip = strip + isCode(m, 13.0) + isCode(m, 14.0) + isCode(m, 19.0);
        float cellQuad = isCode(m, 5.0) + isCode(m, 6.0);
        float isRibbon = isCode(m, 10.0);
        float isCapsule = isCode(m, 11.0) + isCode(m, 12.0);
        float isMet = isCode(m, 15.0);
        float isUnmet = isCode(m, 16.0);
        float fan = isCode(m, 17.0) + isCode(m, 18.0);
        float h = clamp(v_local, 0.0, 1.0);
        vec3 backdrop = mix(MA_ABYSS, MA_ABYSS_TOP, h);
        float nl = length(v_aux);
        float shaded = step(0.0001, nl);
        float mu = clamp(dot(v_aux / max(nl, 0.0001), MA_VIEW_DIR), 0.0, 1.0);
        vec3 body = mix(v_base * MA_LIMB_SHADE, v_base, smoothstep(0.0, MA_LIMB_EDGE, mu));
        body = mix(body, vec3(1.0), MA_CORE_LIFT * smoothstep(MA_CORE_START, 1.0, mu));
        body = mix(body, MA_GLOW, MA_RIM_LIFT * pow(1.0 - mu, MA_RIM_POWER));
        vec3 capsule = mix(v_base, body, shaded);
        float lift = clamp(MA_RIBBON_CORE * (1.0 - d) * along + MA_WON_LIFT * won, 0.0, 1.0);
        vec3 ribbonRgb = mix(v_base, vec3(1.0), lift);
        float ribbonCover = ribbon * along * mix(MA_RIBBON_ALPHA, 1.0, won);
        vec2 p = v_aux.xy;
        float r = length(p);
        float cell = markCover(1.0 - max(abs(p.x), abs(p.y)));
        float filled = markCover(1.0 - r);
        float hollow = markCover(MA_RING_HALF - abs(r - (1.0 - MA_RING_HALF)));
        vec3 rgb = mix(v_base, backdrop, sky);
        rgb = mix(rgb, ribbonRgb, isRibbon);
        rgb = mix(rgb, capsule, isCapsule);
        float coverage = sky + flatFill;
        coverage = coverage + edge * (strip + fan + isCapsule);
        coverage = coverage + cell * cellQuad;
        coverage = coverage + ribbonCover * isRibbon;
        coverage = coverage + filled * isMet + hollow * isUnmet;
        float alpha = clamp(coverage, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    /// The glow vertex shader. Uniform: `u_mvp`. Passes the colour (`a_normal`), the kind and glow factor decoded from
    /// `a_uv.x` (``GlowKind/decode(_:)``) and the shell's radial coordinate (`a_uv.y`).
    public static let glowVertex: String = """
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
        float x = clamp(a_uv.x, 0.0, 3.0);
        float kind = clamp(floor(x * 0.5), 0.0, 1.0);
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
    public static let glowFragment: String = """
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
    const vec3 MA_GLOW = \(vec3Literal(MicroscopicAuroraPalette.glow));
    const vec3 MA_RIBBON = \(vec3Literal(MicroscopicAuroraPalette.ribbon));
    const float MA_GLOW_WEIGHT = \(fixed(glowWeight));
    const float MA_RIBBON_REST = \(fixed(ribbonRest));
    const float MA_MAX_GAIN = \(fixed(maxGlowGain));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, MA_MAX_GAIN), clamp(u_glowLimit, 0.0, MA_MAX_GAIN));
        float kind = floor(v_kind + 0.5);
        float isRibbon = isCode(kind, 1.0);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 fallback = mix(MA_GLOW, MA_RIBBON, isRibbon);
        vec3 rgb = mix(fallback, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        float rest = mix(1.0, mix(MA_RIBBON_REST, 1.0, won), isRibbon);
        float factor = clamp(v_factor, 0.0, 1.0) * rest;
        float r = 1.0 - clamp(v_radius, 0.0, 1.0);
        float fade = r * r;
        float alpha = clamp(MA_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The `a_uv.x` a ribbon vertex writes at along coordinate `along` (0 at the tail, 1 at the head; clamped, and
    /// non-finite counts as 0): the ribbon code plus ``alongScale`` · along.
    public static func ribbonCode(along: Double) -> Double {
        Double(MicroscopicAuroraMaterial.ribbon.rawValue) + alongScale * unit(along)
    }

    /// The along coordinate the dish vertex shader decodes from `a_uv.x` value `code`: (code - rounded code) /
    /// ``alongScale`` clamped to 0 … 1 (non-finite counts as 0).
    public static func ribbonAlong(code: Double) -> Double {
        guard code.isFinite else { return 0 }
        let maxCode: Double = Double(MicroscopicAuroraMaterial.broken.rawValue)
        let m: Double = min(max((code + 0.5).rounded(.down), 0), maxCode)
        return unit((code - m) / alongScale)
    }

    /// The base colour the dish vertex shader selects for `material` with won light `won` (clamped to 0 … 1;
    /// non-finite counts as 0): the material's palette colour, a stencil outline's mixed toward the lit colour by
    /// `won`.
    public static func baseColour(of material: MicroscopicAuroraMaterial, won: Double) -> SIMD3<Double> {
        let base: SIMD3<Double> = material.baseColour
        guard material == .stencil else { return base }
        return base + (MicroscopicAuroraPalette.lit - base) * unit(won)
    }

    /// The still backdrop colour at height `height` (0 bottom … 1 top; clamped, non-finite counts as 0): the gradient
    /// from abyss to abyss top.
    public static func backdropColour(height: Double) -> SIMD3<Double> {
        let low: SIMD3<Double> = MicroscopicAuroraPalette.abyss
        return low + (MicroscopicAuroraPalette.abyssTop - low) * unit(height)
    }

    /// The soft-outline coverage of local coordinate `local`: 1 - smoothstep(1 - ``edgeFeather``, 1, |local|), |local|
    /// clamped to 0 … 1 (non-finite counts as the outline, 0 coverage).
    public static func edgeCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(1 - edgeFeather, 1, min(abs(local), 1))
    }

    /// A ribbon's soft-edge coverage at across coordinate `across`: 1 - smoothstep(1 - ``ribbonFeather``, 1, |across|)
    /// (non-finite counts as the outline, 0).
    public static func ribbonCoverage(across: Double) -> Double {
        guard across.isFinite else { return 0 }
        return 1 - smoothstep(1 - ribbonFeather, 1, min(abs(across), 1))
    }

    /// A ribbon's colour at across coordinate `across` and along coordinate `along` (0 tail … 1 head) with won light
    /// `won`: the ribbon colour lifted toward white by ``ribbonCore`` · (1 - |d|) · along + ``wonLift`` · won (the sum
    /// clamped to 0 … 1; non-finite `across` counts as the outline, non-finite `along` and `won` as 0).
    public static func ribbonColour(across: Double, along: Double, won: Double) -> SIMD3<Double> {
        let d: Double = across.isFinite ? min(abs(across), 1) : 1
        let lift: Double = min(max(ribbonCore * (1 - d) * unit(along) + wonLift * unit(won), 0), 1)
        let colour: SIMD3<Double> = MicroscopicAuroraPalette.ribbon
        return colour + (SIMD3<Double>(1, 1, 1) - colour) * lift
    }

    /// A ribbon's opacity: ``ribbonCoverage(across:)`` times the along coordinate (fading to 0 at the tail) times
    /// ``ribbonAlpha`` raised to 1 by the won light.
    public static func ribbonOpacity(across: Double, along: Double, won: Double) -> Double {
        let w: Double = unit(won)
        return ribbonCoverage(across: across) * unit(along) * (ribbonAlpha + (1 - ribbonAlpha) * w)
    }

    /// The signed distance of quad-local point (`u`, `v`) to the square max(|u|, |v|) ≤ 1 (a cell), positive inside
    /// (non-finite coordinates count as far outside, -1).
    public static func squareDistance(u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return -1 }
        return 1 - max(abs(u), abs(v))
    }

    /// The signed distance of (`u`, `v`) to the unit disc (a filled mark), positive inside (non-finite: -1).
    public static func discDistance(u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return -1 }
        return 1 - (u * u + v * v).squareRoot()
    }

    /// The signed distance of (`u`, `v`) to the hollow mark's ring of half-width ``markRingHalf`` centred on radius
    /// 1 - ``markRingHalf``, positive inside (non-finite: -1).
    public static func ringDistance(u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return -1 }
        let r: Double = (u * u + v * v).squareRoot()
        return markRingHalf - abs(r - (1 - markRingHalf))
    }

    /// A cell's or mark's coverage at (`u`, `v`): smoothstep(-``markFeather``, ``markFeather``, distance) with the
    /// distance of `material`'s shape (lit and stray cells: square, met mark: disc, unmet mark: ring); 0 for a material
    /// that is neither.
    public static func markCoverage(_ material: MicroscopicAuroraMaterial, u: Double, v: Double) -> Double {
        func cover(_ distance: Double) -> Double { smoothstep(-markFeather, markFeather, distance) }
        switch material {
        case .litCell, .strayCell: return cover(squareDistance(u: u, v: v))
        case .markMet: return cover(discDistance(u: u, v: v))
        case .markUnmet: return cover(ringDistance(u: u, v: v))
        default: return 0
        }
    }

    /// The layered colour of a capsule of `material` (swimmer or tail tip; any other material is shaded with its base
    /// colour the same way) at mu = n · ``viewDirection`` (clamped to 0 … 1; non-finite counts as 1): the limb from
    /// base · ``limbShade`` to the base by smoothstep(0, ``limbEdge``, mu), the core lifted toward white by
    /// ``coreLift`` · smoothstep(``coreStart``, 1, mu), then the rim light by ``rimLift`` · (1 - mu)^``rimPower``
    /// toward the glow colour.
    public static func capsuleShade(_ material: MicroscopicAuroraMaterial, mu: Double) -> SIMD3<Double> {
        let m: Double = mu.isFinite ? min(max(mu, 0), 1) : 1
        let base: SIMD3<Double> = material.baseColour
        let shade: SIMD3<Double> = base * limbShade
        var c: SIMD3<Double> = shade + (base - shade) * smoothstep(0, limbEdge, m)
        c += (SIMD3<Double>(1, 1, 1) - c) * (coreLift * smoothstep(coreStart, 1, m))
        c += (MicroscopicAuroraPalette.glow - c) * (rimLift * pow(1 - m, rimPower))
        return c
    }

    /// The colour of a capsule with normal `normal` (any length): ``capsuleShade(_:mu:)`` of the normalised normal ·
    /// ``viewDirection``; a zero or non-finite normal (a level-2 flat capsule) is shaded flat, the base colour.
    public static func capsuleShade(_ material: MicroscopicAuroraMaterial, normal: SIMD3<Double>) -> SIMD3<Double> {
        let finite: Bool = normal.x.isFinite && normal.y.isFinite && normal.z.isFinite
        let length: Double = finite ? (normal * normal).sum().squareRoot() : 0
        guard length >= 0.0001 else { return material.baseColour }
        return capsuleShade(material, mu: ((normal / length) * viewDirection).sum())
    }

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: MicroscopicAuroraTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 … ``maxGlowGain`` (non-finite counts
    /// as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow of a vertex with `colour` (zero counts as the glow or ribbon colour by `kind`), glow factor `factor`,
    /// radial coordinate `radius`, the applied `gain` and won light `won`, before premultiplying: the colour, with
    /// alpha ``glowWeight`` · gain · factor · (1 - radius)², the factor of a ribbon shell also times ``ribbonRest``
    /// rising to 1 with `won`; every component clamped to 0 … 1.
    public static func glowColour(colour: SIMD3<Double>, kind: GlowKind, factor: Double, radius: Double, gain: Double,
                                  won: Double) -> SIMD4<Double> {
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 {
            switch kind {
            case .swimmer: c = MicroscopicAuroraPalette.glow
            case .ribbon: c = MicroscopicAuroraPalette.ribbon
            }
        }
        var f: Double = unit(factor)
        if kind == .ribbon { f *= ribbonRest + (1 - ribbonRest) * unit(won) }
        let r: Double = 1 - unit(radius)
        let k: Double = gain.isFinite ? gain : 0
        return SIMD4<Double>(c.x, c.y, c.z, unit(glowWeight * k * f * r * r))
    }

    /// `x` clamped to 0 … 1 (non-finite counts as 0).
    static func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
