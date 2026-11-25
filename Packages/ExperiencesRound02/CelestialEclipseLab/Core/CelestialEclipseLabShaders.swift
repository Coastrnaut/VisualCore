// CelestialEclipseLabShaders — feature 463 (R02-G17-03) T-R02G1703-003 (FR-R02G1703-001, 002, 004; clarifications
// Q1–Q4). The two GLSL ES 3.00 programs of Celestial Eclipse Lab held as source text (data: the core issues no GL
// call), with the names of every uniform they declare, their vertex attributes (the three `ShaderMeshRenderer`
// streams), the material codes shared with `CelestialEclipseLabSceneGeometry`, the constants the sources are built from
// and the CPU references of what they compute. Presentation only: no rule is ever evaluated on these values, and
// nothing drawn is consulted by the rules.
//
// Sky program: the ink backdrop (a vertical gradient from ink to ink top with sparse hashed specks, under 5 % of its
// pixels), the orbital rings, their notches and the square frames of fixed bodies, the bodies (layered core, limb
// darkening and rim light from the sphere normal), the eclipse shadows (the lens where a nearer disc covers a farther
// one, drawn as geometry in the crescent shadow with a thin ember rim), the corona halos (thin emissive rings times the
// pulse `u_pulse`, flared on a won level when matched), the chosen body's dashed ring, the timeline strip, the window
// brackets, the predicted-event marks (filled diamonds, crosses, faint diamonds), the playhead, the actions bars and
// the broken colour of a failure.
//
// Vertex streams (the geometry states the same contract): `a_uv.x` is the material code (the `material…` constants, 0 …
// 16), `a_uv.y` the primary local coordinate and `a_normal` the sphere normal (bodies) or a secondary local coordinate.
// Per material: on the backdrop `a_uv.y` is the height h (0 at the bottom, 1 at the top) and `a_normal.x` the
// horizontal coordinate s (-1 on the left edge, +1 on the right); on a strip (ring, notch, frame, halo, chosen ring,
// timeline strip, bracket, playhead, broken) `a_uv.y` is the across coordinate d, -1 on one long side and +1 on the
// other, with `a_normal.x` the angle fraction 0 … 1 around the chosen ring (seam duplicated with 1.0) or, on a halo, 1
// for a matched eclipse's halo and 0 otherwise (`a_normal` zero elsewhere); on a body `a_normal` is the sphere normal
// in world space and `a_uv.y` 0 (a level-2 flat disc: normal ``viewDirection``, `a_uv.y` the radial coordinate, 0 at
// the centre and 1 on the rim); on a mark quad (diamond, cross, faint) `a_normal.xy` is the mark-local coordinate (u,
// v), the mark spanning -1 … +1 and the quad ``markQuadExtent``, `a_uv.y` 0; on a bar fan `a_uv.y` is 0 at the centre
// vertex and 1 on every outline vertex; on a shadow lens fan `a_uv.y` is 0 at the centroid and 1 on the outline and
// `a_normal` is zero.
//
// Crescents (clarification Q1, lead decision): the geometry draws, for every eclipse under way at the shown tick, the
// exact intersection of the front and back discs (a total eclipse: the back disc; an annular one: the front disc) as a
// fan of material ``materialShadow``, painted right after the back body and before the front body. It is shaded in the
// crescent shadow at alpha ``shadowAlpha`` with an ember rim toward its outline (``shadowColour(radial:)``), so the
// crescent seen is the overlap judged. Bodies themselves are shaded by the layered model only.
//
// Signed-distance shading: the soft outline coverage 1 - smoothstep(1 - ``edgeFeather``, 1, |d|)
// (``edgeCoverage(local:)``) on every strip, body and bar; the backdrop is opaque; a shadow lens keeps a crisp outline
// (1 - smoothstep(``shadowEdge``, 1, radial)). The chosen ring has ``chosenDashes`` dashes
// (``chosenDashCoverage(angle:)``); a diamond is |u| + |v| ≤ 1 (``diamondDistance(u:v:)``), a cross two diagonal arms
// of half-width ``crossArm`` inside the unit square (``crossDistance(u:v:)``), both feathered by ``markFeather``. A
// body is shaded in three layers from mu = n · ``viewDirection`` (``bodyShade(mu:)``): the limb from the disc shade to
// the disc, the core lifted toward white, the rim light toward the corona glow at grazing angles. A halo is corona gold
// lifted toward the corona glow at its centre line (``haloColour(across:won:matched:)``) with alpha times the pulse
// (``haloAlpha(across:pulse:won:matched:)``); a won level (`u_won`) flares matched halos.
//
// Glow program: the glow shells around the halos, the chosen ring and the lit marks, drawn additively and last. The
// colour is carried in `a_normal` (a zero colour falls back by kind), `a_uv.x` is 2 · kind + factor (``GlowKind``: 0
// halo, 1 matched halo, 2 chosen ring, 3 lit mark; factor 0 … 1) and `a_uv.y` the shell's radial coordinate r, 0 on its
// inner edge and 1 on its outer edge. The alpha is ``glowWeight`` times the gain, the factor and (1 - r)²; a halo
// shell's factor is also times the pulse and ``haloRest``, a matched halo's rising to 1 with `u_won`; the gain is
// `u_glowGain` capped by `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing the presenter passes
// ``glowGainCap`` as the limit, so no glow, the won flare included, exceeds the cap.
//
// Plain uniforms in the default block (at most 16 vec4 slots per program; the sky program uses 6: u_mvp 4, u_won and
// u_pulse 1 each; the glow program 8: u_mvp 4, u_glowGain, u_glowLimit, u_won and u_pulse 1 each), no texture samplers,
// no image assets, no `discard` and no loops. Output is premultiplied alpha. Palette constants are written with six
// fixed decimals from `CelestialEclipseLabPalette`, so the shader colours equal the CPU's within 1e-6.

import Foundation

/// The GLSL ES 3.00 sources of Celestial Eclipse Lab's sky and glow programs, their uniform and attribute names, the
/// material codes, the constants they are built from and the CPU references of what they compute (FR-R02G1703-001,
/// 002, 004).
public enum CelestialEclipseLabShaders {
    // MARK: Material codes (written into `a_uv.x` of a sky vertex)

    /// The backdrop quad (opaque; `a_uv.y` height h 0 … 1, `a_normal.x` horizontal s -1 … +1).
    public static let materialBackdrop: Float = 0
    /// An orbital ring ribbon, orbit blue (strip).
    public static let materialRing: Float = 1
    /// A notch across an orbital ring at the body's position, or a bracket's index notch (strip; orbit blue lifted
    /// toward the window colour by ``notchLift``).
    public static let materialNotch: Float = 2
    /// A side of the square frame of a fixed body (strip).
    public static let materialFrame: Float = 3
    /// A body sphere (normal = sphere normal, `a_uv.y` 0) or a level-2 flat disc (normal ``viewDirection``, `a_uv.y`
    /// radial).
    public static let materialBody: Float = 4
    /// A corona halo ring at the front body's rim (strip; `a_normal.x` 1 for a matched eclipse's halo, else 0).
    public static let materialHalo: Float = 5
    /// The chosen body's dashed ring (strip ring; `a_normal.x` angle fraction 0 … 1).
    public static let materialChosen: Float = 6
    /// The timeline strip (strip).
    public static let materialStrip: Float = 7
    /// A target window's bracket (strip).
    public static let materialBracket: Float = 8
    /// A matched predicted event: a filled corona-gold diamond (mark quad; `a_normal.xy` mark-local u, v).
    public static let materialDiamond: Float = 9
    /// The failing predicted event: an ember cross (mark quad; `a_normal.xy` mark-local u, v).
    public static let materialCross: Float = 10
    /// A predicted event after the last match: a faint diamond (mark quad; `a_normal.xy` mark-local u, v).
    public static let materialFaint: Float = 11
    /// The playhead at the shown tick (strip).
    public static let materialPlayhead: Float = 12
    /// A lit actions bar, an action left (fan).
    public static let materialBar: Float = 13
    /// An unlit actions bar, an action spent (fan).
    public static let materialBarUnlit: Float = 14
    /// What a failure names: the failing event's marker, the outlines of its two bodies, the next target's bracket
    /// (strip).
    public static let materialBroken: Float = 15
    /// An eclipse's shadow lens: the intersection of the front and back discs (a fan; `a_uv.y` 0 at the centroid and 1
    /// on the outline, `a_normal` zero), the crescent shadow with an ember rim, painted between the two bodies.
    public static let materialShadow: Float = 16

    /// Every material as (Swift name, code, GLSL palette constant the sky vertex shader selects for it), in code
    /// order 0 … 16.
    public static let materials: [(name: String, code: Float, constant: String)] = [
        (name: "materialBackdrop", code: materialBackdrop, constant: "CE_INK"),
        (name: "materialRing", code: materialRing, constant: "CE_ORBIT"),
        (name: "materialNotch", code: materialNotch, constant: "CE_ORBIT"),
        (name: "materialFrame", code: materialFrame, constant: "CE_FIXED_FRAME"),
        (name: "materialBody", code: materialBody, constant: "CE_DISC"),
        (name: "materialHalo", code: materialHalo, constant: "CE_CORONA"),
        (name: "materialChosen", code: materialChosen, constant: "CE_CHOSEN"),
        (name: "materialStrip", code: materialStrip, constant: "CE_ORBIT"),
        (name: "materialBracket", code: materialBracket, constant: "CE_WINDOW"),
        (name: "materialDiamond", code: materialDiamond, constant: "CE_MATCHED"),
        (name: "materialCross", code: materialCross, constant: "CE_UNWANTED"),
        (name: "materialFaint", code: materialFaint, constant: "CE_FAINT_EVENT"),
        (name: "materialPlayhead", code: materialPlayhead, constant: "CE_PLAYHEAD"),
        (name: "materialBar", code: materialBar, constant: "CE_ACTIONS_LIT"),
        (name: "materialBarUnlit", code: materialBarUnlit, constant: "CE_ACTIONS_UNLIT"),
        (name: "materialBroken", code: materialBroken, constant: "CE_BROKEN"),
        (name: "materialShadow", code: materialShadow, constant: "CE_SHADOW"),
    ]

    /// A glow-program vertex kind, encoded with the glow factor into `a_uv.x` as 2 · kind + factor.
    public enum GlowKind: Int, Sendable, CaseIterable, Hashable {
        /// A glow shell around a halo (zero colour: the corona glow); its factor is times the pulse and ``haloRest``.
        case halo = 0
        /// A glow shell around a matched eclipse's halo: as ``halo``, its rest rising to 1 with `u_won`.
        case matchedHalo = 1
        /// A glow shell around the chosen ring (zero colour: the chosen colour).
        case chosen = 2
        /// A glow shell around a lit mark or bar (zero colour: the glow colour).
        case mark = 3

        /// The `a_uv.x` value of a vertex of this kind with glow factor `factor` (clamped to 0 … 1; non-finite counts
        /// as 0).
        public func code(factor: Double) -> Double {
            let f: Double = factor.isFinite ? min(max(factor, 0), 1) : 0
            return Double(2 * rawValue) + f
        }

        /// The (kind, factor) the glow vertex shader decodes from `a_uv.x`: kind ⌊x / 2⌋ clamped to 0 … 3, factor
        /// x - 2 · kind clamped to 0 … 1 (x clamped to 0 … 7; non-finite counts as 0).
        public static func decode(_ x: Double) -> (kind: GlowKind, factor: Double) {
            let v: Double = x.isFinite ? min(max(x, 0), 7) : 0
            let k: Int = min(max(Int((v * 0.5).rounded(.down)), 0), 3)
            let factor: Double = min(max(v - Double(2 * k), 0), 1)
            return (kind: GlowKind(rawValue: k) ?? .halo, factor: factor)
        }
    }

    /// The version line every source starts with (equal to VisualCoreShaderSource's `ShaderLibrary.versionLine`).
    public static let versionLine = "#version 300 es"

    /// The vertex attributes both programs read, as (name, location): `a_position` (vec3, 0), `a_normal` (vec3, 1)
    /// and `a_uv` (vec2, 2), as `ShaderMeshRenderer` binds them.
    public static let attributes: [(name: String, location: Int)] = [
        (name: "a_position", location: 0),
        (name: "a_normal", location: 1),
        (name: "a_uv", location: 2),
    ]


    /// Every sky-program attribute as (name, location): the same three streams as ``attributes``.
    public static let skyAttributes: [(name: String, location: Int)] = attributes

    // MARK: Uniform names

    /// `mat4`: projection x view x model (both programs, vertex stage; model = identity, positions in world space).
    public static let mvpUniform = "u_mvp"
    /// `float`: the won level's light, 0 … 1 (sky vertex stage: lights the window brackets matched gold, as the
    /// fallback colours do (feature 463 T-R02G1703-014), and flares the matched halos; glow fragment stage: raises the
    /// matched halo shells' rest to 1); 0 on a level not won.
    public static let wonUniform = "u_won"
    /// `float`: the halo pulse, 0.85 … 1 (sky and glow fragment stages): ``haloPulse(time:reduceMotion:)``.
    public static let pulseUniform = "u_pulse"
    /// `float`: the glow gain (glow fragment stage); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform = "u_glowGain"
    /// `float`: the glow limit (glow fragment stage): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform = "u_glowLimit"

    /// Every uniform the sky program declares, each once, in order of declaration (vertex stage first).
    public static let skyUniforms: [String] = [mvpUniform, wonUniform, pulseUniform]

    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, wonUniform, pulseUniform]

    /// The uniform lists per program name (`sky`, `glow`).
    public static let uniformNames: [String: [String]] = ["sky": skyUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), one per palette colour.
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = [
        (name: "CE_INK", colour: CelestialEclipseLabPalette.ink),
        (name: "CE_INK_TOP", colour: CelestialEclipseLabPalette.inkTop),
        (name: "CE_SPECK", colour: CelestialEclipseLabPalette.speck),
        (name: "CE_DISC", colour: CelestialEclipseLabPalette.disc),
        (name: "CE_DISC_SHADE", colour: CelestialEclipseLabPalette.discShade),
        (name: "CE_ORBIT", colour: CelestialEclipseLabPalette.orbit),
        (name: "CE_FIXED_FRAME", colour: CelestialEclipseLabPalette.fixedFrame),
        (name: "CE_CHOSEN", colour: CelestialEclipseLabPalette.chosen),
        (name: "CE_CORONA", colour: CelestialEclipseLabPalette.corona),
        (name: "CE_CORONA_GLOW", colour: CelestialEclipseLabPalette.coronaGlow),
        (name: "CE_SHADOW", colour: CelestialEclipseLabPalette.crescentShadow),
        (name: "CE_EMBER", colour: CelestialEclipseLabPalette.ember),
        (name: "CE_WINDOW", colour: CelestialEclipseLabPalette.window),
        (name: "CE_MATCHED", colour: CelestialEclipseLabPalette.matched),
        (name: "CE_UNWANTED", colour: CelestialEclipseLabPalette.unwanted),
        (name: "CE_FAINT_EVENT", colour: CelestialEclipseLabPalette.faintEvent),
        (name: "CE_PLAYHEAD", colour: CelestialEclipseLabPalette.playhead),
        (name: "CE_ACTIONS_LIT", colour: CelestialEclipseLabPalette.actionsLit),
        (name: "CE_ACTIONS_UNLIT", colour: CelestialEclipseLabPalette.actionsUnlit),
        (name: "CE_BROKEN", colour: CelestialEclipseLabPalette.broken),
        (name: "CE_GLOW", colour: CelestialEclipseLabPalette.glow),
    ]

    /// The unit direction from the scene toward the authored eye (eye (0.3, 0.2, 3.4) looking at (0, -0.25, 0)), the
    /// view direction the body layers are shaded against; a level-2 flat disc writes it as its normal.
    public static let viewDirection: SIMD3<Double> = {
        let raw: SIMD3<Double> = SIMD3<Double>(0.3, 0.45, 3.4)
        let length: Double = (raw * raw).sum().squareRoot()
        return raw / length
    }()

    /// The width of the soft outline as a share of the across coordinate: coverage falls from 1 at |d| = 1 - feather
    /// to 0 at |d| = 1.
    public static let edgeFeather: Double = 0.25

    /// The speck cells across the backdrop (s -1 … +1).
    public static let cellsAcross: Double = 360
    /// The speck cells from the bottom (h = 0) to the top (h = 1) of the backdrop.
    public static let cellsUp: Double = 160
    /// The share of cells holding a speck.
    public static let speckDensity: Double = 0.06
    /// A speck's radius in cell units: full inside half of it, fading to 0 at it.
    public static let speckRadius: Double = 0.22
    /// How far a speck's centre is jittered inside its cell, in cell units (±half of it).
    public static let speckJitter: Double = 0.5
    /// The dimmest speck's share of the speck colour (the brightest has 1).
    public static let speckDim: Double = 0.45

    /// The mu below which a body's limb darkens from the disc colour toward the disc shade
    /// (smoothstep(0, limbEdge, mu)).
    public static let limbEdge: Double = 0.55
    /// The mu where a body's core begins to lift toward white.
    public static let coreStart: Double = 0.85
    /// How far a body's core (mu = 1) is lifted toward white.
    public static let coreLift: Double = 0.25
    /// The power of the rim light's rise toward grazing angles, (1 - mu)^power.
    public static let rimPower: Double = 3
    /// How far the rim light lifts a body's limb toward the corona glow at mu = 0.
    public static let rimLift: Double = 0.3


    /// The alpha of a shadow lens (its colour the crescent shadow).
    public static let shadowAlpha: Double = 0.92
    /// The radial coordinate where a shadow lens's ember rim begins (it is full at the outline, radial 1).
    public static let shadowRimStart: Double = 0.85
    /// How far the rim of a shadow lens is tinted toward ember at its outline.
    public static let emberRim: Double = 0.5
    /// The radial coordinate where a shadow lens's crisp outline begins to fade (to 0 at radial 1).
    public static let shadowEdge: Double = 0.97

    /// How far a notch is lifted from the orbit colour toward the window colour (so it reads on its ring).
    public static let notchLift: Double = 0.45
    /// The alpha of an orbital ring ribbon.
    public static let ringAlpha: Double = 0.85
    /// The dashes around the chosen body's ring.
    public static let chosenDashes: Double = 16
    /// The share of a chosen-ring dash period that is drawn, from its start.
    public static let chosenDuty: Double = 0.6
    /// How far a halo's centre line (d = 0) is lifted from corona gold toward the corona glow.
    public static let haloCore: Double = 0.6
    /// How far a won level flares a matched halo: its colour toward the corona glow and its alpha from the pulse
    /// toward 1, times `u_won`.
    public static let flareLift: Double = 0.6
    /// The soft edge of a mark in mark-local units: coverage smoothstep(-feather, feather, distance).
    public static let markFeather: Double = 0.06
    /// The half-width of a cross's diagonal arms in mark-local units.
    public static let crossArm: Double = 0.22
    /// The mark-local extent the geometry's mark quad spans on each axis (-extent … +extent), room for the feather.
    public static let markQuadExtent: Double = 1.25

    /// The halo pulse's period in seconds.
    public static let pulsePeriod: Double = 2.4
    /// The halo pulse's lowest value (its highest is 1).
    public static let pulseLow: Double = 0.85

    /// The alpha weight of the glow, times the glow gain, the glow factor and the fade.
    public static let glowWeight: Double = 0.5
    /// The share of a halo shell's factor shown at rest (a matched halo's rises to 1 with `u_won`).
    public static let haloRest: Double = 0.6
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

    /// 1 / √2, the normalisation of the marks' diagonal distances.
    static let invSqrt2: Double = 1 / 2.0.squareRoot()

    /// The sky vertex shader. Uniforms: `u_mvp`, `u_won`. Selects the material colour from `a_uv.x`; passes the
    /// secondary coordinate or normal (`a_normal`), the world x and y, the material code, the local coordinate, the
    /// won light.
    public static let skyVertex = """
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
    out float v_won;
    const vec3 CE_INK = \(vec3Literal(CelestialEclipseLabPalette.ink));
    const vec3 CE_ORBIT = \(vec3Literal(CelestialEclipseLabPalette.orbit));
    const vec3 CE_FIXED_FRAME = \(vec3Literal(CelestialEclipseLabPalette.fixedFrame));
    const vec3 CE_DISC = \(vec3Literal(CelestialEclipseLabPalette.disc));
    const vec3 CE_CORONA = \(vec3Literal(CelestialEclipseLabPalette.corona));
    const vec3 CE_CHOSEN = \(vec3Literal(CelestialEclipseLabPalette.chosen));
    const vec3 CE_WINDOW = \(vec3Literal(CelestialEclipseLabPalette.window));
    const vec3 CE_MATCHED = \(vec3Literal(CelestialEclipseLabPalette.matched));
    const vec3 CE_UNWANTED = \(vec3Literal(CelestialEclipseLabPalette.unwanted));
    const vec3 CE_FAINT_EVENT = \(vec3Literal(CelestialEclipseLabPalette.faintEvent));
    const vec3 CE_PLAYHEAD = \(vec3Literal(CelestialEclipseLabPalette.playhead));
    const vec3 CE_ACTIONS_LIT = \(vec3Literal(CelestialEclipseLabPalette.actionsLit));
    const vec3 CE_ACTIONS_UNLIT = \(vec3Literal(CelestialEclipseLabPalette.actionsUnlit));
    const vec3 CE_BROKEN = \(vec3Literal(CelestialEclipseLabPalette.broken));
    const vec3 CE_SHADOW = \(vec3Literal(CelestialEclipseLabPalette.crescentShadow));
    const float CE_MAX_MATERIAL = \(fixed(Double(materialShadow)));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, CE_MAX_MATERIAL);
        vec3 base = CE_INK;
        base = mix(base, CE_ORBIT, isCode(m, 1.0));
        base = mix(base, CE_ORBIT, isCode(m, 2.0));
        base = mix(base, CE_FIXED_FRAME, isCode(m, 3.0));
        base = mix(base, CE_DISC, isCode(m, 4.0));
        base = mix(base, CE_CORONA, isCode(m, 5.0));
        base = mix(base, CE_CHOSEN, isCode(m, 6.0));
        base = mix(base, CE_ORBIT, isCode(m, 7.0));
        base = mix(base, CE_WINDOW, isCode(m, 8.0));
        base = mix(base, CE_MATCHED, isCode(m, 8.0) * clamp(u_won, 0.0, 1.0));
        base = mix(base, CE_MATCHED, isCode(m, 9.0));
        base = mix(base, CE_UNWANTED, isCode(m, 10.0));
        base = mix(base, CE_FAINT_EVENT, isCode(m, 11.0));
        base = mix(base, CE_PLAYHEAD, isCode(m, 12.0));
        base = mix(base, CE_ACTIONS_LIT, isCode(m, 13.0));
        base = mix(base, CE_ACTIONS_UNLIT, isCode(m, 14.0));
        base = mix(base, CE_BROKEN, isCode(m, 15.0));
        base = mix(base, CE_SHADOW, isCode(m, 16.0));
        v_base = base;
        v_aux = a_normal;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0);
        v_won = clamp(u_won, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The sky fragment shader. Uniform: `u_pulse`. The backdrop gradient and specks
    /// (``backdropColour(height:horizontal:)``), signed-distance coverage from the local coordinates
    /// (``edgeCoverage(local:)``, ``chosenDashCoverage(angle:)``, ``diamondCoverage(u:v:)``, ``crossCoverage(u:v:)``),
    /// the layered bodies (``bodyShade(mu:)``), the shadow lenses (``shadowColour(radial:)``) and the pulsed, flared
    /// halos (``haloColour(across:won:matched:)``, ``haloAlpha(across:pulse:won:matched:)``). Premultiplied.
    public static let skyFragment = """
    #version 300 es
    precision highp float;
    in vec3 v_base;
    in vec3 v_aux;
    in float v_material;
    in float v_local;
    in float v_won;
    uniform float u_pulse;
    out vec4 color;
    const vec3 CE_INK = \(vec3Literal(CelestialEclipseLabPalette.ink));
    const vec3 CE_INK_TOP = \(vec3Literal(CelestialEclipseLabPalette.inkTop));
    const vec3 CE_SPECK = \(vec3Literal(CelestialEclipseLabPalette.speck));
    const vec3 CE_DISC = \(vec3Literal(CelestialEclipseLabPalette.disc));
    const vec3 CE_DISC_SHADE = \(vec3Literal(CelestialEclipseLabPalette.discShade));
    const vec3 CE_CORONA = \(vec3Literal(CelestialEclipseLabPalette.corona));
    const vec3 CE_CORONA_GLOW = \(vec3Literal(CelestialEclipseLabPalette.coronaGlow));
    const vec3 CE_SHADOW = \(vec3Literal(CelestialEclipseLabPalette.crescentShadow));
    const vec3 CE_EMBER = \(vec3Literal(CelestialEclipseLabPalette.ember));
    const vec3 CE_WINDOW = \(vec3Literal(CelestialEclipseLabPalette.window));
    const vec3 CE_VIEW_DIR = \(vec3Literal(viewDirection));
    const float CE_EDGE_FEATHER = \(fixed(edgeFeather));
    const float CE_CELLS_ACROSS = \(fixed(cellsAcross));
    const float CE_CELLS_UP = \(fixed(cellsUp));
    const float CE_SPECK_DENSITY = \(fixed(speckDensity));
    const float CE_SPECK_RADIUS = \(fixed(speckRadius));
    const float CE_SPECK_JITTER = \(fixed(speckJitter));
    const float CE_SPECK_DIM = \(fixed(speckDim));
    const float CE_LIMB_EDGE = \(fixed(limbEdge));
    const float CE_CORE_START = \(fixed(coreStart));
    const float CE_CORE_LIFT = \(fixed(coreLift));
    const float CE_RIM_POWER = \(fixed(rimPower));
    const float CE_RIM_LIFT = \(fixed(rimLift));
    const float CE_SHADOW_ALPHA = \(fixed(shadowAlpha));
    const float CE_SHADOW_RIM_START = \(fixed(shadowRimStart));
    const float CE_EMBER_RIM = \(fixed(emberRim));
    const float CE_SHADOW_EDGE = \(fixed(shadowEdge));
    const float CE_NOTCH_LIFT = \(fixed(notchLift));
    const float CE_RING_ALPHA = \(fixed(ringAlpha));
    const float CE_CHOSEN_DASHES = \(fixed(chosenDashes));
    const float CE_CHOSEN_DUTY = \(fixed(chosenDuty));
    const float CE_HALO_CORE = \(fixed(haloCore));
    const float CE_FLARE_LIFT = \(fixed(flareLift));
    const float CE_MARK_FEATHER = \(fixed(markFeather));
    const float CE_CROSS_ARM = \(fixed(crossArm));
    const float CE_INV_SQRT2 = \(fixed(invSqrt2));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    float hash(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }
    float diamondDistance(vec2 p) {
        return (1.0 - abs(p.x) - abs(p.y)) * CE_INV_SQRT2;
    }
    float crossDistance(vec2 p) {
        float arms = CE_CROSS_ARM - min(abs(p.x - p.y), abs(p.x + p.y)) * CE_INV_SQRT2;
        return min(arms, 1.0 - max(abs(p.x), abs(p.y)));
    }
    void main() {
        float m = floor(v_material + 0.5);
        float d = clamp(abs(v_local), 0.0, 1.0);
        float edge = 1.0 - smoothstep(1.0 - CE_EDGE_FEATHER, 1.0, d);
        float won = clamp(v_won, 0.0, 1.0);
        float pulse = clamp(u_pulse, 0.0, 1.0);
        float sky = isCode(m, 0.0);
        float h = clamp(v_local, 0.0, 1.0);
        float s = clamp(v_aux.x, -1.0, 1.0);
        vec2 cellPos = vec2((s + 1.0) * 0.5 * CE_CELLS_ACROSS, h * CE_CELLS_UP);
        vec2 cell = floor(cellPos);
        float pick = hash(cell);
        float jitter = hash(cell + vec2(17.0, 59.0));
        vec2 f = fract(cellPos) - 0.5 - (vec2(jitter, fract(jitter * 7.0)) - 0.5) * CE_SPECK_JITTER;
        float speck = step(1.0 - CE_SPECK_DENSITY, pick);
        speck = speck * (1.0 - smoothstep(CE_SPECK_RADIUS * 0.5, CE_SPECK_RADIUS, length(f)));
        vec3 gradient = mix(CE_INK, CE_INK_TOP, h);
        vec3 backdrop = mix(gradient, CE_SPECK, speck * mix(CE_SPECK_DIM, 1.0, fract(pick * 13.0)));
        float nl = length(v_aux);
        float facing = clamp(dot(v_aux / max(nl, 0.0001), CE_VIEW_DIR), 0.0, 1.0);
        float mu = mix(1.0, facing, step(0.0001, nl));
        vec3 disc = mix(CE_DISC_SHADE, CE_DISC, smoothstep(0.0, CE_LIMB_EDGE, mu));
        disc = mix(disc, vec3(1.0), CE_CORE_LIFT * smoothstep(CE_CORE_START, 1.0, mu));
        disc = mix(disc, CE_CORONA_GLOW, CE_RIM_LIFT * pow(1.0 - mu, CE_RIM_POWER));
        float t = clamp(v_aux.x, 0.0, 1.0);
        float chosenDash = 1.0 - step(CE_CHOSEN_DUTY, fract(t * CE_CHOSEN_DASHES));
        float matchedHalo = step(0.5, v_aux.x);
        float flare = CE_FLARE_LIFT * won * matchedHalo;
        vec3 halo = mix(CE_CORONA, CE_CORONA_GLOW, clamp(CE_HALO_CORE * (1.0 - d) + flare, 0.0, 1.0));
        float diamond = smoothstep(-CE_MARK_FEATHER, CE_MARK_FEATHER, diamondDistance(v_aux.xy));
        float crossMark = smoothstep(-CE_MARK_FEATHER, CE_MARK_FEATHER, crossDistance(v_aux.xy));
        float isDiamond = isCode(m, 9.0) + isCode(m, 11.0);
        float isShadow = isCode(m, 16.0);
        float rim = smoothstep(CE_SHADOW_RIM_START, 1.0, d);
        vec3 lens = mix(CE_SHADOW, CE_EMBER, CE_EMBER_RIM * rim);
        float lensCover = CE_SHADOW_ALPHA * (1.0 - smoothstep(CE_SHADOW_EDGE, 1.0, d));
        vec3 rgb = mix(v_base, backdrop, sky);
        rgb = mix(rgb, mix(v_base, CE_WINDOW, CE_NOTCH_LIFT), isCode(m, 2.0));
        rgb = mix(rgb, disc, isCode(m, 4.0));
        rgb = mix(rgb, halo, isCode(m, 5.0));
        rgb = mix(rgb, lens, isShadow);
        float coverage = edge;
        coverage = coverage * mix(1.0, CE_RING_ALPHA, isCode(m, 1.0));
        coverage = coverage * mix(1.0, chosenDash, isCode(m, 6.0));
        coverage = coverage * mix(1.0, mix(pulse, 1.0, flare), isCode(m, 5.0));
        coverage = mix(coverage, diamond, isDiamond);
        coverage = mix(coverage, crossMark, isCode(m, 10.0));
        coverage = mix(coverage, lensCover, isShadow);
        coverage = mix(coverage, 1.0, sky);
        float alpha = clamp(coverage, 0.0, 1.0);
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
        float x = clamp(a_uv.x, 0.0, 7.0);
        float kind = clamp(floor(x * 0.5), 0.0, 3.0);
        v_colour = clamp(a_normal, 0.0, 1.0);
        v_kind = kind;
        v_factor = clamp(x - 2.0 * kind, 0.0, 1.0);
        v_radius = clamp(a_uv.y, 0.0, 1.0);
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The glow fragment shader. Uniforms: `u_glowGain`, `u_glowLimit`, `u_won`, `u_pulse`. Gain
    /// ``glowGain(gain:limit:)``, colour and alpha ``glowColour(colour:kind:factor:radius:gain:won:pulse:)``;
    /// premultiplied RGBA in 0 … 1, drawn with additive blending.
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
    uniform float u_pulse;
    out vec4 color;
    const vec3 CE_CORONA_GLOW = \(vec3Literal(CelestialEclipseLabPalette.coronaGlow));
    const vec3 CE_CHOSEN = \(vec3Literal(CelestialEclipseLabPalette.chosen));
    const vec3 CE_GLOW = \(vec3Literal(CelestialEclipseLabPalette.glow));
    const float CE_GLOW_WEIGHT = \(fixed(glowWeight));
    const float CE_HALO_REST = \(fixed(haloRest));
    const float CE_MAX_GAIN = \(fixed(maxGlowGain));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, CE_MAX_GAIN), clamp(u_glowLimit, 0.0, CE_MAX_GAIN));
        float kind = floor(v_kind + 0.5);
        float isHalo = isCode(kind, 0.0) + isCode(kind, 1.0);
        float isMatched = isCode(kind, 1.0);
        float isChosen = isCode(kind, 2.0);
        float isMark = isCode(kind, 3.0);
        float won = clamp(u_won, 0.0, 1.0);
        float pulse = clamp(u_pulse, 0.0, 1.0);
        vec3 fallback = mix(mix(CE_CORONA_GLOW, CE_CHOSEN, isChosen), CE_GLOW, isMark);
        vec3 rgb = mix(fallback, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        float rest = pulse * mix(CE_HALO_REST, 1.0, won * isMatched);
        float factor = clamp(v_factor, 0.0, 1.0) * mix(1.0, rest, isHalo);
        float r = 1.0 - clamp(v_radius, 0.0, 1.0);
        float fade = r * r;
        float alpha = clamp(CE_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The halo pulse the presenter passes as `u_pulse`: 1 with Reduce Motion or for a non-finite time; otherwise
    /// ``pulseLow`` + (1 - ``pulseLow``) · (1 + cos(2π · time / ``pulsePeriod``)) / 2, a gentle oscillation in
    /// ``pulseLow`` … 1 with period ``pulsePeriod`` (1 at time 0), finite for any finite time.
    public static func haloPulse(time: Double, reduceMotion: Bool) -> Double {
        guard !reduceMotion, time.isFinite else { return 1 }
        let phase: Double = time.truncatingRemainder(dividingBy: pulsePeriod) / pulsePeriod
        let wave: Double = 0.5 * (1 + cos(2 * Double.pi * phase))
        let value: Double = pulseLow + (1 - pulseLow) * wave
        guard value.isFinite else { return 1 }
        return min(max(value, pulseLow), 1)
    }

    /// The soft-outline coverage of local coordinate `local`: 1 - smoothstep(1 - ``edgeFeather``, 1, |local|), |local|
    /// clamped to 0 … 1 (non-finite counts as the outline, 0 coverage).
    public static func edgeCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(1 - edgeFeather, 1, min(abs(local), 1))
    }

    /// The dash at angle fraction `angle` (clamped to 0 … 1) around the chosen ring: 1 where fract(angle ·
    /// ``chosenDashes``) < ``chosenDuty``, else 0.
    public static func chosenDashCoverage(angle: Double) -> Double {
        let a: Double = angle.isFinite ? min(max(angle, 0), 1) : 0
        return fract(a * chosenDashes) < chosenDuty ? 1 : 0
    }

    /// The signed distance of mark-local point (`u`, `v`) to the diamond |u| + |v| ≤ 1, positive inside (non-finite
    /// coordinates count as far outside, -1).
    public static func diamondDistance(u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return -1 }
        return (1 - abs(u) - abs(v)) * invSqrt2
    }

    /// The signed distance of mark-local point (`u`, `v`) to the cross (two diagonal arms of half-width ``crossArm``
    /// inside the square |u|, |v| ≤ 1), positive inside (non-finite coordinates count as far outside, -1).
    public static func crossDistance(u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return -1 }
        let arms: Double = crossArm - min(abs(u - v), abs(u + v)) * invSqrt2
        return min(arms, 1 - max(abs(u), abs(v)))
    }

    /// A diamond's coverage at (`u`, `v`): smoothstep(-``markFeather``, ``markFeather``, ``diamondDistance(u:v:)``).
    public static func diamondCoverage(u: Double, v: Double) -> Double {
        smoothstep(-markFeather, markFeather, diamondDistance(u: u, v: v))
    }

    /// A cross's coverage at (`u`, `v`): smoothstep(-``markFeather``, ``markFeather``, ``crossDistance(u:v:)``).
    public static func crossCoverage(u: Double, v: Double) -> Double {
        smoothstep(-markFeather, markFeather, crossDistance(u: u, v: v))
    }

    /// The layered colour of a body at mu = n · ``viewDirection`` (clamped to 0 … 1; non-finite counts as 1, a flat
    /// disc): the limb from the disc shade to the disc by smoothstep(0, ``limbEdge``, mu), the core lifted toward white
    /// by ``coreLift`` · smoothstep(``coreStart``, 1, mu), then the rim light toward the corona glow by ``rimLift`` ·
    /// (1 - mu)^``rimPower``.
    public static func bodyShade(mu: Double) -> SIMD3<Double> {
        let m: Double = mu.isFinite ? min(max(mu, 0), 1) : 1
        let shade: SIMD3<Double> = CelestialEclipseLabPalette.discShade
        let disc: SIMD3<Double> = CelestialEclipseLabPalette.disc
        var c: SIMD3<Double> = shade + (disc - shade) * smoothstep(0, limbEdge, m)
        c += (SIMD3<Double>(1, 1, 1) - c) * (coreLift * smoothstep(coreStart, 1, m))
        c += (CelestialEclipseLabPalette.coronaGlow - c) * (rimLift * pow(1 - m, rimPower))
        return c
    }

    /// The layered colour of a body with sphere normal `normal` (any length; a zero or non-finite normal counts as
    /// facing the eye, mu = 1): ``bodyShade(mu:)`` of the normalised normal · ``viewDirection``.
    public static func bodyShade(normal: SIMD3<Double>) -> SIMD3<Double> {
        let finite: Bool = normal.x.isFinite && normal.y.isFinite && normal.z.isFinite
        let length: Double = finite ? (normal * normal).sum().squareRoot() : 0
        guard length >= 0.0001 else { return bodyShade(mu: 1) }
        return bodyShade(mu: ((normal / length) * viewDirection).sum())
    }

    /// A shadow lens's colour and alpha (not premultiplied) at radial coordinate `radial` (|radial| clamped to 0 … 1;
    /// non-finite counts as the outline): the crescent shadow tinted toward ember by ``emberRim`` ·
    /// smoothstep(``shadowRimStart``, 1, radial), with alpha ``shadowAlpha`` · (1 - smoothstep(``shadowEdge``, 1,
    /// radial)).
    public static func shadowColour(radial: Double) -> SIMD4<Double> {
        let d: Double = radial.isFinite ? min(abs(radial), 1) : 1
        let shadow: SIMD3<Double> = CelestialEclipseLabPalette.crescentShadow
        let rgb: SIMD3<Double> = shadow + (CelestialEclipseLabPalette.ember - shadow) * (emberRim * smoothstep(
            shadowRimStart, 1, d))
        return SIMD4<Double>(rgb.x, rgb.y, rgb.z, shadowAlpha * (1 - smoothstep(shadowEdge, 1, d)))
    }

    /// A halo's colour at across coordinate `across` (|d| clamped to 0 … 1; non-finite counts as the outline), won
    /// light `won` and matched flag: corona gold lifted toward the corona glow by ``haloCore`` · (1 - |d|) plus, for a
    /// matched halo, ``flareLift`` · won (the sum clamped to 0 … 1).
    public static func haloColour(across: Double, won: Double, matched: Bool) -> SIMD3<Double> {
        let d: Double = across.isFinite ? min(abs(across), 1) : 1
        let flare: Double = matched ? flareLift * unit(won) : 0
        let lift: Double = min(max(haloCore * (1 - d) + flare, 0), 1)
        let corona: SIMD3<Double> = CelestialEclipseLabPalette.corona
        return corona + (CelestialEclipseLabPalette.coronaGlow - corona) * lift
    }

    /// A halo's alpha at across coordinate `across`: ``edgeCoverage(local:)`` times the pulse (clamped to 0 … 1),
    /// raised toward 1 by ``flareLift`` · won for a matched halo.
    public static func haloAlpha(across: Double, pulse: Double, won: Double, matched: Bool) -> Double {
        let flare: Double = matched ? flareLift * unit(won) : 0
        let p: Double = unit(pulse)
        return unit(edgeCoverage(local: across) * (p + (1 - p) * flare))
    }

    /// The hash of a speck cell (`x`, `y`), 0 ..< 1, as the sky fragment shader computes it (in Float).
    public static func hash(_ x: Double, _ y: Double) -> Double {
        func fr(_ v: Float) -> Float { v - v.rounded(.down) }
        var p: SIMD3<Float> = SIMD3<Float>(fr(Float(x) * 0.1031), fr(Float(y) * 0.1031), fr(Float(x) * 0.1031))
        let yzx: SIMD3<Float> = SIMD3<Float>(p.y, p.z, p.x) + SIMD3<Float>(33.33, 33.33, 33.33)
        let dot: Float = (p * yzx).sum()
        p += SIMD3<Float>(dot, dot, dot)
        return Double(fr((p.x + p.y) * p.z))
    }

    /// The speck coverage (0 … 1) of the backdrop at height `height` (0 … 1) and horizontal coordinate `horizontal`
    /// (-1 … 1): the speck of its cell on the grid of ``cellsAcross`` × ``cellsUp`` cells, when the cell's hash is at
    /// least 1 - ``speckDensity``, fading from ``speckRadius`` / 2 to ``speckRadius`` around its jittered centre.
    /// Non-finite inputs count as 0.
    public static func speckCoverage(height: Double, horizontal: Double) -> Double {
        let cell: (x: Double, y: Double, px: Double, py: Double) = speckCell(height: height, horizontal: horizontal)
        let pick: Double = hash(cell.x, cell.y)
        guard pick >= 1 - speckDensity else { return 0 }
        let jitter: Double = hash(cell.x + 17, cell.y + 59)
        let fx: Double = fract(cell.px) - 0.5 - (jitter - 0.5) * speckJitter
        let fy: Double = fract(cell.py) - 0.5 - (fract(jitter * 7) - 0.5) * speckJitter
        let r: Double = (fx * fx + fy * fy).squareRoot()
        return 1 - smoothstep(speckRadius * 0.5, speckRadius, r)
    }

    /// The backdrop colour at height `height` (0 bottom … 1 top) and horizontal coordinate `horizontal`: the gradient
    /// from ink to ink top, lifted toward the speck colour by the speck coverage times its brightness ``speckDim`` … 1
    /// (``speckCoverage(height:horizontal:)``).
    public static func backdropColour(height: Double, horizontal: Double) -> SIMD3<Double> {
        let h: Double = height.isFinite ? min(max(height, 0), 1) : 0
        let ink: SIMD3<Double> = CelestialEclipseLabPalette.ink
        let gradient: SIMD3<Double> = ink + (CelestialEclipseLabPalette.inkTop - ink) * h
        let speck: Double = speckCoverage(height: height, horizontal: horizontal)
        guard speck > 0 else { return gradient }
        let cell: (x: Double, y: Double, px: Double, py: Double) = speckCell(height: height, horizontal: horizontal)
        let brightness: Double = speckDim + (1 - speckDim) * fract(hash(cell.x, cell.y) * 13)
        return gradient + (CelestialEclipseLabPalette.speck - gradient) * (speck * brightness)
    }

    /// The speck cell and cell-space position of (`height`, `horizontal`), both clamped (non-finite counts as 0).
    static func speckCell(height: Double, horizontal: Double) -> (x: Double, y: Double, px: Double, py: Double) {
        let h: Double = height.isFinite ? min(max(height, 0), 1) : 0
        let s: Double = horizontal.isFinite ? min(max(horizontal, -1), 1) : 0
        let px: Double = (s + 1) * 0.5 * cellsAcross
        let py: Double = h * cellsUp
        return (x: px.rounded(.down), y: py.rounded(.down), px: px, py: py)
    }

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: CelestialEclipseLabTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 … ``maxGlowGain`` (non-finite counts
    /// as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow of a vertex with `colour` (zero counts as the corona glow, chosen or glow colour by `kind`), glow
    /// factor `factor`, radial coordinate `radius`, the applied `gain`, won light `won` and pulse `pulse`, before
    /// premultiplying: the colour, with alpha ``glowWeight`` · gain · factor · (1 - radius)², the factor of a halo
    /// shell also times pulse · ``haloRest`` (a matched halo's rest rising to 1 with `won`); every component clamped
    /// to 0 … 1.
    public static func glowColour(colour: SIMD3<Double>, kind: GlowKind, factor: Double, radius: Double, gain: Double,
                                  won: Double, pulse: Double) -> SIMD4<Double> {
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 {
            switch kind {
            case .halo, .matchedHalo: c = CelestialEclipseLabPalette.coronaGlow
            case .chosen: c = CelestialEclipseLabPalette.chosen
            case .mark: c = CelestialEclipseLabPalette.glow
            }
        }
        var f: Double = unit(factor)
        if kind == .halo || kind == .matchedHalo {
            let w: Double = kind == .matchedHalo ? unit(won) : 0
            f *= unit(pulse) * (haloRest + (1 - haloRest) * w)
        }
        let r: Double = 1 - unit(radius)
        let k: Double = gain.isFinite ? gain : 0
        return SIMD4<Double>(c.x, c.y, c.z, unit(glowWeight * k * f * r * r))
    }

    /// `x` clamped to 0 … 1 (non-finite counts as 0).
    static func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }

    /// GLSL's fract(`x`).
    static func fract(_ x: Double) -> Double { x - x.rounded(.down) }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
