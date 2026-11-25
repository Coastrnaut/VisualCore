// ApsidesWorkshopShaders — feature 473 (R02-G18-03) T-R02G1803-003 (FR-R02G1803-001, 002, 004; clarifications
// Q1–Q4). The two GLSL ES 3.00 programs of Apsides Workshop held as source text (data: the core issues no GL call),
// with the names of every uniform they declare, their vertex attributes (the three `ShaderMeshRenderer` streams), the
// material codes shared with `ApsidesWorkshopSceneGeometry` (``ApsidesWorkshopMaterial``), the constants the sources
// are built from and the CPU references of what they compute. Presentation only: no rule is ever evaluated on these
// values, and nothing drawn is consulted by the rules.
//
// Compass program: the midnight backdrop (a vertical gradient from midnight to midnight top with sparse hashed specks,
// under 5 % of its pixels), the swept-area wedges (wedge or target-wedge tint), the compass spokes, rim and notches,
// the sector brackets, the ghost and orbit ribbons (soft edge; the orbit loop with an emissive core, brightened on a
// won level), the periapsis diamond and apoapsis square, the planets, the star and the orbiter (layered core, limb
// darkening and rim light from the sphere normal; the orbiter glacial with a deep rose rim), the planets' hatched
// hazard rings, the gauge tracks, band brackets and marks (filled when met, hollow when not; every mark lit filled on a
// won level), the lit and unlit actions bars and the broken colour of what a failure names.
//
// Vertex streams (the geometry states the same contract): `a_uv.x` is the material code (``ApsidesWorkshopMaterial``,
// 0 … 21), `a_uv.y` the primary local coordinate and `a_normal` the sphere normal (spheres) or a secondary local
// coordinate. Per material: on the backdrop `a_uv.y` is the height h (0 at the bottom, 1 at the top) and `a_normal.x`
// the horizontal coordinate s (-1 on the left edge, +1 on the right); on a wedge `a_uv.y` and `a_normal` are 0 (a flat
// fill); on a strip (spoke, rim, notch, bracket, ghost, orbit, hazard, gauge track, gauge band, broken) `a_uv.y` is the
// across coordinate d, -1 on one long side and +1 on the other, and `a_normal.x` on a hazard ring the angle fraction
// 0 … 1 around the ring (seam duplicated with 1.0; `a_normal` zero on the other strips); on a sphere (planet, star,
// orbiter) `a_normal` is the sphere normal in world space and `a_uv.y` 0 (a level-2 flat disc: normal
// ``ApsidesWorkshopShaders/viewDirection``, `a_uv.y` the radial coordinate, 0 at the centre and 1 on the rim); on a
// mark quad (periapsis, apoapsis, met mark, unmet mark) `a_normal.xy` is the mark-local coordinate (u, v), the mark
// spanning -1 … +1 and the quad ``ApsidesWorkshopShaders/markQuadExtent``, `a_uv.y` 0; on a bar fan `a_uv.y` is 0 at
// the centre vertex and 1 on every outline vertex.
//
// Signed-distance shading: the soft outline coverage 1 - smoothstep(1 - ``edgeFeather``, 1, |d|) on every strip,
// sphere and bar; the ribbons use the wider ``ribbonFeather``; the backdrop is opaque. A diamond is |u| + |v| ≤ 1, a
// square max(|u|, |v|) ≤ 1, a filled mark the unit disc and a hollow mark a ring of half-width ``markRingHalf`` inside
// it, all feathered by ``markFeather``. A hazard ring is hatched: ``hazardHatches`` slanted stripes of duty
// ``hazardDuty`` over a floor ``hazardFloor``. A sphere is shaded in three layers from mu = n · ``viewDirection``: the
// limb from its colour times ``limbShade`` to its colour, the core lifted toward white, the rim light toward the glow
// colour (the orbiter's toward deep rose, stronger) at grazing angles.
//
// Glow program: the glow shells around the star, the orbit loop and the orbiter, drawn additively and last. The colour
// is carried in `a_normal` (a zero colour falls back by kind), `a_uv.x` is 2 · kind + factor (``GlowKind``: 0 star,
// 1 orbit loop, 2 orbiter; factor 0 … 1) and `a_uv.y` the shell's radial coordinate r, 0 on its inner edge and 1 on its
// outer edge. The alpha is ``glowWeight`` times the gain, the factor and (1 - r)²; a star shell's factor is also times
// the pulse `u_pulse` (``starPulse(time:reduceMotion:)``, exactly 1 with Reduce Motion) and an orbit shell's times
// ``orbitRest``, rising to 1 with `u_won`; the gain is `u_glowGain` capped by `u_glowLimit` (both clamped to
// ``maxGlowGain``); under Reduce Flashing the presenter passes ``glowGainCap`` as the limit, so no glow, the won
// brightening included, exceeds the cap.
//
// Plain uniforms in the default block (at most 16 vec4 slots per program; the compass program uses 5: u_mvp 4, u_won 1;
// the glow program 8: u_mvp 4, u_glowGain, u_glowLimit, u_won and u_pulse 1 each), no texture samplers, no image
// assets, no `discard` and no loops at all (so every loop is bounded). Output is premultiplied alpha. Palette constants
// are written with six fixed decimals from `ApsidesWorkshopPalette`, so the shader colours equal the CPU's within 1e-6.

import Foundation

/// The material code a compass-program vertex carries in `a_uv.x` (FR-R02G1803-001, 002): one per kind of element the
/// geometry draws, 0 … 21. The geometry writes ``code``; the compass vertex shader selects ``paletteConstant``.
public enum ApsidesWorkshopMaterial: Int, Sendable, CaseIterable, Hashable {
    /// The backdrop quad (opaque; `a_uv.y` height h 0 … 1, `a_normal.x` horizontal s -1 … +1).
    case backdrop = 0
    /// A swept-area wedge (flat fill, `a_uv.y` 0), wedge colour.
    case wedge = 1
    /// A wedge in a sector a sweep target names (flat fill), target-wedge colour.
    case targetWedge = 2
    /// A compass spoke (strip), compass colour.
    case spoke = 3
    /// The compass rim ring (strip), compass colour.
    case rim = 4
    /// A notch across the rim (strip), compass colour lifted toward glacial by ``ApsidesWorkshopShaders/notchLift``.
    case notch = 5
    /// A bracket arc over a target's sector (strip), deep rose.
    case bracket = 6
    /// The starting orbit's ghost ribbon (strip, soft edge), ghost colour.
    case ghost = 7
    /// The orbit loop ribbon (strip, soft edge, emissive core; brightened on a won level), glacial.
    case orbit = 8
    /// The periapsis diamond (mark quad; `a_normal.xy` mark-local u, v), deep rose.
    case periapsis = 9
    /// The apoapsis square (mark quad), deep rose.
    case apoapsis = 10
    /// An exclusion planet (sphere or level-2 flat disc), planet colour.
    case planet = 11
    /// A planet's hatched hazard ring (strip; `a_normal.x` angle fraction 0 … 1), hazard colour.
    case hazard = 12
    /// The star (sphere or flat disc), star colour.
    case star = 13
    /// The orbiter (sphere or flat disc), glacial with a deep rose rim light.
    case orbiter = 14
    /// A gauge track (strip), ghost colour.
    case gaugeTrack = 15
    /// A gauge's band bracket (strip), deep rose.
    case gaugeBand = 16
    /// A met target's gauge mark: a filled disc (mark quad), met colour.
    case markMet = 17
    /// An unmet target's gauge mark: a hollow ring (mark quad), unmet colour; filled in the met colour on a won level.
    case markUnmet = 18
    /// A lit actions bar, an action left (fan).
    case barLit = 19
    /// An unlit actions bar, an action spent (fan).
    case barUnlit = 20
    /// What a failure names: the contact, the failing target's bracket or gauge, the offending apsis (strip).
    case broken = 21

    /// The value the geometry writes into `a_uv.x`.
    public var code: Float { Float(rawValue) }

    /// The GLSL palette constant the compass vertex shader selects for this material.
    public var paletteConstant: String {
        switch self {
        case .backdrop: return "AW_MIDNIGHT"
        case .wedge: return "AW_WEDGE"
        case .targetWedge: return "AW_TARGET_WEDGE"
        case .spoke, .rim, .notch: return "AW_COMPASS"
        case .bracket, .periapsis, .apoapsis, .gaugeBand: return "AW_DEEP_ROSE"
        case .ghost, .gaugeTrack: return "AW_GHOST"
        case .orbit, .orbiter: return "AW_GLACIAL"
        case .planet: return "AW_PLANET"
        case .hazard: return "AW_HAZARD"
        case .star: return "AW_STAR"
        case .markMet: return "AW_MET"
        case .markUnmet: return "AW_UNMET"
        case .barLit: return "AW_ACTIONS_LIT"
        case .barUnlit: return "AW_ACTIONS_UNLIT"
        case .broken: return "AW_BROKEN"
        }
    }

    /// The palette colour of ``paletteConstant`` (the base colour before shading, on a level not won).
    public var baseColour: SIMD3<Double> {
        for entry in ApsidesWorkshopShaders.paletteConstants where entry.name == paletteConstant { return entry.colour }
        return ApsidesWorkshopPalette.midnight
    }

    /// The material of code `x` as the vertex shader decodes it: rounded to the nearest integer and clamped to 0 … 21
    /// (non-finite counts as the backdrop).
    public static func decode(_ x: Double) -> ApsidesWorkshopMaterial {
        guard x.isFinite else { return .backdrop }
        let maxCode: Double = Double(ApsidesWorkshopMaterial.broken.rawValue)
        let m: Int = Int(min(max((x + 0.5).rounded(.down), 0), maxCode))
        return ApsidesWorkshopMaterial(rawValue: m) ?? .backdrop
    }
}

/// The GLSL ES 3.00 sources of Apsides Workshop's compass and glow programs, their uniform and attribute names, the
/// constants they are built from and the CPU references of what they compute (FR-R02G1803-001, 002, 004).
public enum ApsidesWorkshopShaders {
    /// A glow-program vertex kind, encoded with the glow factor into `a_uv.x` as 2 · kind + factor.
    public enum GlowKind: Int, Sendable, CaseIterable, Hashable {
        /// A glow shell around the star (zero colour: the star colour); its factor is times the pulse.
        case star = 0
        /// A glow shell along the orbit loop (zero colour: the glow colour); its factor is times ``orbitRest``,
        /// rising to 1 with `u_won`.
        case orbit = 1
        /// A glow shell around the orbiter (zero colour: glacial).
        case orbiter = 2

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
            return (kind: GlowKind(rawValue: k) ?? .star, factor: factor)
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

    /// Every material as (Swift name, code, GLSL palette constant the compass vertex shader selects), codes 0 … 21.
    public static var materials: [(name: String, code: Float, constant: String)] {
        var result: [(name: String, code: Float, constant: String)] = []
        for material in ApsidesWorkshopMaterial.allCases {
            result.append((name: "\(material)", code: material.code, constant: material.paletteConstant))
        }
        return result
    }

    // MARK: Uniform names

    /// `mat4`: projection x view x model (both programs, vertex stage; model = identity, positions in world space).
    public static let mvpUniform: String = "u_mvp"
    /// `float`: the won level's light, 0 … 1 (compass vertex stage: brightens the orbit loop and lights every gauge
    /// mark filled in the met colour; glow fragment stage: raises the orbit shells' rest to 1); 0 on a level not won.
    public static let wonUniform: String = "u_won"
    /// `float`: the star pulse, 0.85 … 1 (glow fragment stage): ``starPulse(time:reduceMotion:)``.
    public static let pulseUniform: String = "u_pulse"
    /// `float`: the glow gain (glow fragment stage); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform: String = "u_glowGain"
    /// `float`: the glow limit (glow fragment stage): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform: String = "u_glowLimit"

    /// Every uniform the compass program declares, each once, in order of declaration (vertex stage first).
    public static let compassUniforms: [String] = [mvpUniform, wonUniform]

    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, wonUniform, pulseUniform]

    /// The uniform lists per program name (`compass`, `glow`).
    public static let uniformNames: [String: [String]] = ["compass": compassUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), one per palette colour.
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = [
        (name: "AW_MIDNIGHT", colour: ApsidesWorkshopPalette.midnight),
        (name: "AW_MIDNIGHT_TOP", colour: ApsidesWorkshopPalette.midnightTop),
        (name: "AW_SPECK", colour: ApsidesWorkshopPalette.speck),
        (name: "AW_WEDGE", colour: ApsidesWorkshopPalette.wedge),
        (name: "AW_TARGET_WEDGE", colour: ApsidesWorkshopPalette.targetWedge),
        (name: "AW_COMPASS", colour: ApsidesWorkshopPalette.compass),
        (name: "AW_GHOST", colour: ApsidesWorkshopPalette.ghost),
        (name: "AW_GLACIAL", colour: ApsidesWorkshopPalette.glacial),
        (name: "AW_DEEP_ROSE", colour: ApsidesWorkshopPalette.deepRose),
        (name: "AW_PLANET", colour: ApsidesWorkshopPalette.planet),
        (name: "AW_HAZARD", colour: ApsidesWorkshopPalette.hazard),
        (name: "AW_STAR", colour: ApsidesWorkshopPalette.star),
        (name: "AW_MET", colour: ApsidesWorkshopPalette.met),
        (name: "AW_UNMET", colour: ApsidesWorkshopPalette.unmet),
        (name: "AW_ACTIONS_LIT", colour: ApsidesWorkshopPalette.actionsLit),
        (name: "AW_ACTIONS_UNLIT", colour: ApsidesWorkshopPalette.actionsUnlit),
        (name: "AW_BROKEN", colour: ApsidesWorkshopPalette.broken),
        (name: "AW_GLOW", colour: ApsidesWorkshopPalette.glow),
    ]

    /// The unit direction from the scene toward the authored eye (eye (0, -0.3, 3.6) looking at (0, -0.3, 0)): +z, the
    /// view direction the sphere layers are shaded against; a level-2 flat disc writes it as its normal.
    public static let viewDirection: SIMD3<Double> = SIMD3<Double>(0, 0, 1)

    /// The width of the soft outline as a share of the across coordinate: coverage falls from 1 at |d| = 1 - feather
    /// to 0 at |d| = 1.
    public static let edgeFeather: Double = 0.25
    /// The wider soft edge of the ghost and orbit ribbons.
    public static let ribbonFeather: Double = 0.6

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

    /// The share of a sphere's colour at its very limb (limb darkening).
    public static let limbShade: Double = 0.55
    /// The mu below which a sphere's limb darkens (smoothstep(0, limbEdge, mu)).
    public static let limbEdge: Double = 0.55
    /// The mu where a sphere's core begins to lift toward white.
    public static let coreStart: Double = 0.85
    /// How far a sphere's core (mu = 1) is lifted toward white.
    public static let coreLift: Double = 0.25
    /// The power of the rim light's rise toward grazing angles, (1 - mu)^power.
    public static let rimPower: Double = 3
    /// How far the rim light lifts a planet's or the star's limb toward the glow colour at mu = 0.
    public static let rimLift: Double = 0.3
    /// How far the rim light lifts the orbiter's limb toward deep rose at mu = 0.
    public static let orbiterRimLift: Double = 0.7

    /// The alpha of a swept-area wedge.
    public static let wedgeAlpha: Double = 0.9
    /// How far a notch is lifted from the compass colour toward glacial (so it reads on the rim).
    public static let notchLift: Double = 0.45
    /// The alpha of the ghost ribbon.
    public static let ghostAlpha: Double = 0.7
    /// The alpha of the orbit ribbon on a level not won (1 on a won level).
    public static let orbitAlpha: Double = 0.9
    /// How far the orbit ribbon's centre line (d = 0) is lifted from glacial toward white (the emissive core).
    public static let orbitCore: Double = 0.6
    /// How far a won level lifts the whole orbit ribbon toward white, times `u_won`.
    public static let wonLift: Double = 0.5
    /// The hatches around a hazard ring.
    public static let hazardHatches: Double = 24
    /// The share of a hatch period that is drawn.
    public static let hazardDuty: Double = 0.5
    /// The slant of the hatches: the angle-fraction shift per unit of the across coordinate, in hatch periods.
    public static let hazardSlant: Double = 0.5
    /// The coverage between hatches (the ring stays faintly visible).
    public static let hazardFloor: Double = 0.35
    /// The soft edge of a mark in mark-local units: coverage smoothstep(-feather, feather, distance).
    public static let markFeather: Double = 0.06
    /// The half-width of a hollow mark's ring in mark-local units (the ring spans 1 - 2 · half … 1).
    public static let markRingHalf: Double = 0.18
    /// The mark-local extent the geometry's mark quad spans on each axis (-extent … +extent), room for the feather.
    public static let markQuadExtent: Double = 1.25

    /// The star pulse's period in seconds.
    public static let pulsePeriod: Double = 2.4
    /// The star pulse's lowest value (its highest is 1).
    public static let pulseLow: Double = 0.85

    /// The alpha weight of the glow, times the glow gain, the glow factor and the fade.
    public static let glowWeight: Double = 0.5
    /// The share of an orbit shell's factor shown at rest (rising to 1 with `u_won`).
    public static let orbitRest: Double = 0.6
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

    /// 1 / √2, the normalisation of the diamond's diagonal distance.
    static let invSqrt2: Double = 1 / 2.0.squareRoot()

    /// The compass vertex shader. Uniforms: `u_mvp`, `u_won`. Selects the material colour from `a_uv.x` (an unmet mark
    /// mixed toward the met colour by `u_won`); passes the secondary coordinate or normal (`a_normal`), the material
    /// code, the local coordinate and the won light.
    public static let compassVertex: String = """
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
    const vec3 AW_MIDNIGHT = \(vec3Literal(ApsidesWorkshopPalette.midnight));
    const vec3 AW_WEDGE = \(vec3Literal(ApsidesWorkshopPalette.wedge));
    const vec3 AW_TARGET_WEDGE = \(vec3Literal(ApsidesWorkshopPalette.targetWedge));
    const vec3 AW_COMPASS = \(vec3Literal(ApsidesWorkshopPalette.compass));
    const vec3 AW_DEEP_ROSE = \(vec3Literal(ApsidesWorkshopPalette.deepRose));
    const vec3 AW_GHOST = \(vec3Literal(ApsidesWorkshopPalette.ghost));
    const vec3 AW_GLACIAL = \(vec3Literal(ApsidesWorkshopPalette.glacial));
    const vec3 AW_PLANET = \(vec3Literal(ApsidesWorkshopPalette.planet));
    const vec3 AW_HAZARD = \(vec3Literal(ApsidesWorkshopPalette.hazard));
    const vec3 AW_STAR = \(vec3Literal(ApsidesWorkshopPalette.star));
    const vec3 AW_MET = \(vec3Literal(ApsidesWorkshopPalette.met));
    const vec3 AW_UNMET = \(vec3Literal(ApsidesWorkshopPalette.unmet));
    const vec3 AW_ACTIONS_LIT = \(vec3Literal(ApsidesWorkshopPalette.actionsLit));
    const vec3 AW_ACTIONS_UNLIT = \(vec3Literal(ApsidesWorkshopPalette.actionsUnlit));
    const vec3 AW_BROKEN = \(vec3Literal(ApsidesWorkshopPalette.broken));
    const float AW_MAX_MATERIAL = \(fixed(Double(ApsidesWorkshopMaterial.broken.rawValue)));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float m = clamp(floor(a_uv.x + 0.5), 0.0, AW_MAX_MATERIAL);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 base = AW_MIDNIGHT;
        base = mix(base, AW_WEDGE, isCode(m, 1.0));
        base = mix(base, AW_TARGET_WEDGE, isCode(m, 2.0));
        base = mix(base, AW_COMPASS, isCode(m, 3.0));
        base = mix(base, AW_COMPASS, isCode(m, 4.0));
        base = mix(base, AW_COMPASS, isCode(m, 5.0));
        base = mix(base, AW_DEEP_ROSE, isCode(m, 6.0));
        base = mix(base, AW_GHOST, isCode(m, 7.0));
        base = mix(base, AW_GLACIAL, isCode(m, 8.0));
        base = mix(base, AW_DEEP_ROSE, isCode(m, 9.0));
        base = mix(base, AW_DEEP_ROSE, isCode(m, 10.0));
        base = mix(base, AW_PLANET, isCode(m, 11.0));
        base = mix(base, AW_HAZARD, isCode(m, 12.0));
        base = mix(base, AW_STAR, isCode(m, 13.0));
        base = mix(base, AW_GLACIAL, isCode(m, 14.0));
        base = mix(base, AW_GHOST, isCode(m, 15.0));
        base = mix(base, AW_DEEP_ROSE, isCode(m, 16.0));
        base = mix(base, AW_MET, isCode(m, 17.0));
        base = mix(base, AW_UNMET, isCode(m, 18.0));
        base = mix(base, AW_MET, isCode(m, 18.0) * won);
        base = mix(base, AW_ACTIONS_LIT, isCode(m, 19.0));
        base = mix(base, AW_ACTIONS_UNLIT, isCode(m, 20.0));
        base = mix(base, AW_BROKEN, isCode(m, 21.0));
        v_base = base;
        v_aux = a_normal;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0);
        v_won = won;
        gl_Position = u_mvp * vec4(a_position, 1.0);
    }
    """

    /// The compass fragment shader (no uniforms). The backdrop gradient and specks
    /// (``backdropColour(height:horizontal:)``), signed-distance coverage from the local coordinates
    /// (``edgeCoverage(local:)``, ``ribbonCoverage(across:)``, ``hazardCoverage(across:along:)``,
    /// ``markCoverage(_:u:v:won:)``), the layered spheres (``sphereShade(_:mu:)``) and the orbit ribbon's emissive core
    /// brightened by the won light (``orbitColour(across:won:)``, ``orbitCoverage(across:won:)``). Premultiplied.
    public static let compassFragment: String = """
    #version 300 es
    precision highp float;
    in vec3 v_base;
    in vec3 v_aux;
    in float v_material;
    in float v_local;
    in float v_won;
    out vec4 color;
    const vec3 AW_MIDNIGHT = \(vec3Literal(ApsidesWorkshopPalette.midnight));
    const vec3 AW_MIDNIGHT_TOP = \(vec3Literal(ApsidesWorkshopPalette.midnightTop));
    const vec3 AW_SPECK = \(vec3Literal(ApsidesWorkshopPalette.speck));
    const vec3 AW_GLACIAL = \(vec3Literal(ApsidesWorkshopPalette.glacial));
    const vec3 AW_DEEP_ROSE = \(vec3Literal(ApsidesWorkshopPalette.deepRose));
    const vec3 AW_GLOW = \(vec3Literal(ApsidesWorkshopPalette.glow));
    const vec3 AW_VIEW_DIR = \(vec3Literal(viewDirection));
    const float AW_EDGE_FEATHER = \(fixed(edgeFeather));
    const float AW_RIBBON_FEATHER = \(fixed(ribbonFeather));
    const float AW_CELLS_ACROSS = \(fixed(cellsAcross));
    const float AW_CELLS_UP = \(fixed(cellsUp));
    const float AW_SPECK_DENSITY = \(fixed(speckDensity));
    const float AW_SPECK_RADIUS = \(fixed(speckRadius));
    const float AW_SPECK_JITTER = \(fixed(speckJitter));
    const float AW_SPECK_DIM = \(fixed(speckDim));
    const float AW_LIMB_SHADE = \(fixed(limbShade));
    const float AW_LIMB_EDGE = \(fixed(limbEdge));
    const float AW_CORE_START = \(fixed(coreStart));
    const float AW_CORE_LIFT = \(fixed(coreLift));
    const float AW_RIM_POWER = \(fixed(rimPower));
    const float AW_RIM_LIFT = \(fixed(rimLift));
    const float AW_ORBITER_RIM_LIFT = \(fixed(orbiterRimLift));
    const float AW_WEDGE_ALPHA = \(fixed(wedgeAlpha));
    const float AW_NOTCH_LIFT = \(fixed(notchLift));
    const float AW_GHOST_ALPHA = \(fixed(ghostAlpha));
    const float AW_ORBIT_ALPHA = \(fixed(orbitAlpha));
    const float AW_ORBIT_CORE = \(fixed(orbitCore));
    const float AW_WON_LIFT = \(fixed(wonLift));
    const float AW_HAZARD_HATCHES = \(fixed(hazardHatches));
    const float AW_HAZARD_DUTY = \(fixed(hazardDuty));
    const float AW_HAZARD_SLANT = \(fixed(hazardSlant));
    const float AW_HAZARD_FLOOR = \(fixed(hazardFloor));
    const float AW_MARK_FEATHER = \(fixed(markFeather));
    const float AW_RING_HALF = \(fixed(markRingHalf));
    const float AW_INV_SQRT2 = \(fixed(invSqrt2));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    float hash(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }
    float markCover(float dist) {
        return smoothstep(-AW_MARK_FEATHER, AW_MARK_FEATHER, dist);
    }
    void main() {
        float m = floor(v_material + 0.5);
        float d = clamp(abs(v_local), 0.0, 1.0);
        float edge = 1.0 - smoothstep(1.0 - AW_EDGE_FEATHER, 1.0, d);
        float ribbon = 1.0 - smoothstep(1.0 - AW_RIBBON_FEATHER, 1.0, d);
        float won = clamp(v_won, 0.0, 1.0);
        float sky = isCode(m, 0.0);
        float h = clamp(v_local, 0.0, 1.0);
        float s = clamp(v_aux.x, -1.0, 1.0);
        vec2 cellPos = vec2((s + 1.0) * 0.5 * AW_CELLS_ACROSS, h * AW_CELLS_UP);
        vec2 cell = floor(cellPos);
        float pick = hash(cell);
        float jitter = hash(cell + vec2(17.0, 59.0));
        vec2 f = fract(cellPos) - 0.5 - (vec2(jitter, fract(jitter * 7.0)) - 0.5) * AW_SPECK_JITTER;
        float speck = step(1.0 - AW_SPECK_DENSITY, pick);
        speck = speck * (1.0 - smoothstep(AW_SPECK_RADIUS * 0.5, AW_SPECK_RADIUS, length(f)));
        vec3 gradient = mix(AW_MIDNIGHT, AW_MIDNIGHT_TOP, h);
        vec3 backdrop = mix(gradient, AW_SPECK, speck * mix(AW_SPECK_DIM, 1.0, fract(pick * 13.0)));
        float isWedge = isCode(m, 1.0) + isCode(m, 2.0);
        float isOrbiter = isCode(m, 14.0);
        float isSphere = isCode(m, 11.0) + isCode(m, 13.0) + isOrbiter;
        float nl = length(v_aux);
        float facing = clamp(dot(v_aux / max(nl, 0.0001), AW_VIEW_DIR), 0.0, 1.0);
        float mu = mix(1.0, facing, step(0.0001, nl));
        vec3 body = mix(v_base * AW_LIMB_SHADE, v_base, smoothstep(0.0, AW_LIMB_EDGE, mu));
        body = mix(body, vec3(1.0), AW_CORE_LIFT * smoothstep(AW_CORE_START, 1.0, mu));
        vec3 rimColour = mix(AW_GLOW, AW_DEEP_ROSE, isOrbiter);
        float rimLift = mix(AW_RIM_LIFT, AW_ORBITER_RIM_LIFT, isOrbiter);
        body = mix(body, rimColour, rimLift * pow(1.0 - mu, AW_RIM_POWER));
        vec3 orbit = mix(AW_GLACIAL, vec3(1.0), clamp(AW_ORBIT_CORE * (1.0 - d) + AW_WON_LIFT * won, 0.0, 1.0));
        float orbitCover = ribbon * mix(AW_ORBIT_ALPHA, 1.0, won);
        float t = clamp(v_aux.x, 0.0, 1.0);
        float hatch = 1.0 - step(AW_HAZARD_DUTY, fract(t * AW_HAZARD_HATCHES + v_local * AW_HAZARD_SLANT));
        vec2 p = v_aux.xy;
        float r = length(p);
        float diamond = markCover((1.0 - abs(p.x) - abs(p.y)) * AW_INV_SQRT2);
        float squareMark = markCover(1.0 - max(abs(p.x), abs(p.y)));
        float filled = markCover(1.0 - r);
        float hollow = markCover(AW_RING_HALF - abs(r - (1.0 - AW_RING_HALF)));
        float unmetMark = mix(hollow, filled, won);
        vec3 rgb = mix(v_base, backdrop, sky);
        rgb = mix(rgb, mix(v_base, AW_GLACIAL, AW_NOTCH_LIFT), isCode(m, 5.0));
        rgb = mix(rgb, orbit, isCode(m, 8.0));
        rgb = mix(rgb, body, isSphere);
        float coverage = edge;
        coverage = coverage * mix(1.0, AW_WEDGE_ALPHA, isWedge);
        coverage = mix(coverage, ribbon * AW_GHOST_ALPHA, isCode(m, 7.0));
        coverage = mix(coverage, orbitCover, isCode(m, 8.0));
        coverage = coverage * mix(1.0, mix(AW_HAZARD_FLOOR, 1.0, hatch), isCode(m, 12.0));
        coverage = mix(coverage, diamond, isCode(m, 9.0));
        coverage = mix(coverage, squareMark, isCode(m, 10.0));
        coverage = mix(coverage, filled, isCode(m, 17.0));
        coverage = mix(coverage, unmetMark, isCode(m, 18.0));
        coverage = mix(coverage, 1.0, sky);
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
        float x = clamp(a_uv.x, 0.0, 5.0);
        float kind = clamp(floor(x * 0.5), 0.0, 2.0);
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
    uniform float u_pulse;
    out vec4 color;
    const vec3 AW_STAR = \(vec3Literal(ApsidesWorkshopPalette.star));
    const vec3 AW_GLOW = \(vec3Literal(ApsidesWorkshopPalette.glow));
    const vec3 AW_GLACIAL = \(vec3Literal(ApsidesWorkshopPalette.glacial));
    const float AW_GLOW_WEIGHT = \(fixed(glowWeight));
    const float AW_ORBIT_REST = \(fixed(orbitRest));
    const float AW_MAX_GAIN = \(fixed(maxGlowGain));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, AW_MAX_GAIN), clamp(u_glowLimit, 0.0, AW_MAX_GAIN));
        float kind = floor(v_kind + 0.5);
        float isStar = isCode(kind, 0.0);
        float isOrbit = isCode(kind, 1.0);
        float isOrbiter = isCode(kind, 2.0);
        float won = clamp(u_won, 0.0, 1.0);
        float pulse = clamp(u_pulse, 0.0, 1.0);
        vec3 fallback = mix(mix(AW_STAR, AW_GLOW, isOrbit), AW_GLACIAL, isOrbiter);
        vec3 rgb = mix(fallback, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        float rest = mix(1.0, pulse, isStar) * mix(1.0, mix(AW_ORBIT_REST, 1.0, won), isOrbit);
        float factor = clamp(v_factor, 0.0, 1.0) * rest;
        float r = 1.0 - clamp(v_radius, 0.0, 1.0);
        float fade = r * r;
        float alpha = clamp(AW_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: CPU references

    /// The star pulse the presenter passes as `u_pulse`: exactly 1 with Reduce Motion or for a non-finite time;
    /// otherwise ``pulseLow`` + (1 - ``pulseLow``) · (1 + cos(2π · time / ``pulsePeriod``)) / 2, a gentle oscillation
    /// in ``pulseLow`` … 1 with period ``pulsePeriod`` (1 at time 0), finite for any finite time.
    public static func starPulse(time: Double, reduceMotion: Bool) -> Double {
        guard !reduceMotion, time.isFinite else { return 1 }
        let phase: Double = time.truncatingRemainder(dividingBy: pulsePeriod) / pulsePeriod
        let wave: Double = 0.5 * (1 + cos(2 * Double.pi * phase))
        let value: Double = pulseLow + (1 - pulseLow) * wave
        guard value.isFinite else { return 1 }
        return min(max(value, pulseLow), 1)
    }

    /// The base colour the compass vertex shader selects for `material` with won light `won` (clamped to 0 … 1;
    /// non-finite counts as 0): the material's palette colour, an unmet mark's mixed toward the met colour by `won`.
    public static func baseColour(of material: ApsidesWorkshopMaterial, won: Double) -> SIMD3<Double> {
        let base: SIMD3<Double> = material.baseColour
        guard material == .markUnmet else { return base }
        return base + (ApsidesWorkshopPalette.met - base) * unit(won)
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

    /// The orbit ribbon's colour at across coordinate `across` with won light `won`: glacial lifted toward white by
    /// ``orbitCore`` · (1 - |d|) + ``wonLift`` · won (the sum clamped to 0 … 1; non-finite `across` counts as the
    /// outline).
    public static func orbitColour(across: Double, won: Double) -> SIMD3<Double> {
        let d: Double = across.isFinite ? min(abs(across), 1) : 1
        let lift: Double = min(max(orbitCore * (1 - d) + wonLift * unit(won), 0), 1)
        let glacial: SIMD3<Double> = ApsidesWorkshopPalette.glacial
        return glacial + (SIMD3<Double>(1, 1, 1) - glacial) * lift
    }

    /// The orbit ribbon's coverage: ``ribbonCoverage(across:)`` times ``orbitAlpha`` raised to 1 by the won light.
    public static func orbitCoverage(across: Double, won: Double) -> Double {
        let w: Double = unit(won)
        return ribbonCoverage(across: across) * (orbitAlpha + (1 - orbitAlpha) * w)
    }

    /// The hatch at angle fraction `along` (clamped to 0 … 1) and across coordinate `across` (clamped to -1 … 1) of a
    /// hazard ring: 1 where fract(along · ``hazardHatches`` + across · ``hazardSlant``) < ``hazardDuty``, else 0.
    public static func hazardHatch(across: Double, along: Double) -> Double {
        let t: Double = along.isFinite ? min(max(along, 0), 1) : 0
        let d: Double = across.isFinite ? min(max(across, -1), 1) : 0
        return fract(t * hazardHatches + d * hazardSlant) < hazardDuty ? 1 : 0
    }

    /// A hazard ring's coverage: ``edgeCoverage(local:)`` times ``hazardFloor`` between hatches and 1 on a hatch.
    public static func hazardCoverage(across: Double, along: Double) -> Double {
        let hatch: Double = hazardHatch(across: across, along: along)
        return edgeCoverage(local: across) * (hazardFloor + (1 - hazardFloor) * hatch)
    }

    /// The signed distance of mark-local point (`u`, `v`) to the diamond |u| + |v| ≤ 1, positive inside (non-finite
    /// coordinates count as far outside, -1).
    public static func diamondDistance(u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return -1 }
        return (1 - abs(u) - abs(v)) * invSqrt2
    }

    /// The signed distance of (`u`, `v`) to the square max(|u|, |v|) ≤ 1, positive inside (non-finite: -1).
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

    /// A mark's coverage at (`u`, `v`): smoothstep(-``markFeather``, ``markFeather``, distance) with the distance of
    /// `material`'s shape (periapsis: diamond, apoapsis: square, met mark: disc, unmet mark: ring mixed toward the disc
    /// by `won`); 0 for a material that is not a mark.
    public static func markCoverage(_ material: ApsidesWorkshopMaterial, u: Double, v: Double, won: Double) -> Double {
        func cover(_ distance: Double) -> Double { smoothstep(-markFeather, markFeather, distance) }
        switch material {
        case .periapsis: return cover(diamondDistance(u: u, v: v))
        case .apoapsis: return cover(squareDistance(u: u, v: v))
        case .markMet: return cover(discDistance(u: u, v: v))
        case .markUnmet:
            let hollow: Double = cover(ringDistance(u: u, v: v))
            let filled: Double = cover(discDistance(u: u, v: v))
            return hollow + (filled - hollow) * unit(won)
        default: return 0
        }
    }

    /// The layered colour of a sphere of `material` (planet, star or orbiter; any other material is shaded with its
    /// base colour the same way) at mu = n · ``viewDirection`` (clamped to 0 … 1; non-finite counts as 1, a flat
    /// disc): the limb from base · ``limbShade`` to the base by smoothstep(0, ``limbEdge``, mu), the core lifted toward
    /// white by ``coreLift`` · smoothstep(``coreStart``, 1, mu), then the rim light by lift · (1 - mu)^``rimPower``
    /// toward the glow colour (lift ``rimLift``) or, on the orbiter, toward deep rose (lift ``orbiterRimLift``).
    public static func sphereShade(_ material: ApsidesWorkshopMaterial, mu: Double) -> SIMD3<Double> {
        let m: Double = mu.isFinite ? min(max(mu, 0), 1) : 1
        let base: SIMD3<Double> = material.baseColour
        let shade: SIMD3<Double> = base * limbShade
        var c: SIMD3<Double> = shade + (base - shade) * smoothstep(0, limbEdge, m)
        c += (SIMD3<Double>(1, 1, 1) - c) * (coreLift * smoothstep(coreStart, 1, m))
        let orbiter: Bool = material == .orbiter
        let rim: SIMD3<Double> = orbiter ? ApsidesWorkshopPalette.deepRose : ApsidesWorkshopPalette.glow
        let lift: Double = orbiter ? orbiterRimLift : rimLift
        c += (rim - c) * (lift * pow(1 - m, rimPower))
        return c
    }

    /// The layered colour of a sphere with normal `normal` (any length; a zero or non-finite normal counts as facing
    /// the eye, mu = 1): ``sphereShade(_:mu:)`` of the normalised normal · ``viewDirection``.
    public static func sphereShade(_ material: ApsidesWorkshopMaterial, normal: SIMD3<Double>) -> SIMD3<Double> {
        let finite: Bool = normal.x.isFinite && normal.y.isFinite && normal.z.isFinite
        let length: Double = finite ? (normal * normal).sum().squareRoot() : 0
        guard length >= 0.0001 else { return sphereShade(material, mu: 1) }
        return sphereShade(material, mu: ((normal / length) * viewDirection).sum())
    }

    /// The hash of a speck cell (`x`, `y`), 0 ..< 1, as the compass fragment shader computes it (in Float).
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
    /// from midnight to midnight top, lifted toward the speck colour by the speck coverage times its brightness
    /// ``speckDim`` … 1 (``speckCoverage(height:horizontal:)``).
    public static func backdropColour(height: Double, horizontal: Double) -> SIMD3<Double> {
        let h: Double = height.isFinite ? min(max(height, 0), 1) : 0
        let low: SIMD3<Double> = ApsidesWorkshopPalette.midnight
        let gradient: SIMD3<Double> = low + (ApsidesWorkshopPalette.midnightTop - low) * h
        let speck: Double = speckCoverage(height: height, horizontal: horizontal)
        guard speck > 0 else { return gradient }
        let cell: (x: Double, y: Double, px: Double, py: Double) = speckCell(height: height, horizontal: horizontal)
        let brightness: Double = speckDim + (1 - speckDim) * fract(hash(cell.x, cell.y) * 13)
        return gradient + (ApsidesWorkshopPalette.speck - gradient) * (speck * brightness)
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
    public static func glowGain(for tier: ApsidesWorkshopTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 … ``maxGlowGain`` (non-finite counts
    /// as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow of a vertex with `colour` (zero counts as the star, glow or glacial colour by `kind`), glow factor
    /// `factor`, radial coordinate `radius`, the applied `gain`, won light `won` and pulse `pulse`, before
    /// premultiplying: the colour, with alpha ``glowWeight`` · gain · factor · (1 - radius)², the factor of a star
    /// shell also times the pulse and of an orbit shell times ``orbitRest`` rising to 1 with `won`; every component
    /// clamped to 0 … 1.
    public static func glowColour(colour: SIMD3<Double>, kind: GlowKind, factor: Double, radius: Double, gain: Double,
                                  won: Double, pulse: Double) -> SIMD4<Double> {
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 {
            switch kind {
            case .star: c = ApsidesWorkshopPalette.star
            case .orbit: c = ApsidesWorkshopPalette.glow
            case .orbiter: c = ApsidesWorkshopPalette.glacial
            }
        }
        var f: Double = unit(factor)
        switch kind {
        case .star: f *= unit(pulse)
        case .orbit: f *= orbitRest + (1 - orbitRest) * unit(won)
        case .orbiter: break
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
