// MushroomWeatherShaders — feature 493 (R02-G20-03) T-R02G2003-003 (FR-R02G2003-001, 002, 004, 007; clarifications
// Q1–Q4). The two GLSL ES 3.00 programs of Mushroom Weather held as source text (data: the core issues no GL call),
// with the names of every uniform they declare, their vertex attributes (the three `ShaderMeshRenderer` streams), the
// material codes shared with `MushroomWeatherSceneGeometry` (``MushroomWeatherMaterial``), the constants the sources
// are built from and the CPU references of what they compute. Presentation only: no rule is ever evaluated on these
// values, and nothing drawn is consulted by the rules.
//
// Forest program: the still midnight backdrop (a vertical gradient from midnight to midnight top), the moon (its
// brightness (4 + L) / 7 carried in the vertex) with its phase ticks (filled or hollow), the moss floor squares, the
// logs and stones, the fronds, the mist squares (shaded mist low … mist high by h/M, translucent), the site rings, the
// lathed stalks, the translucent umbrella caps (layered core and rim light from the normal plus an SDF field of
// moisture beads whose density follows h/M; out-of-band caps lit in the cap colour on a won level), the band rings
// (solid in band, dashed out), the lathed pods and their second ring once grown, the droplets rising from the pods and
// the spore motes on a fixed loop (both moved by `u_time` times `u_motion`, so Reduce Motion stops them), the vent
// frames and slats, the gauge tracks, band brackets and markers, the run bars, the lit and unlit actions bars, the mold
// patch, and the broken colour of anything a failure names (any material, keeping its shape).
//
// Vertex streams (the geometry states the same contract; the shared renderer binds only position, normal and uv):
// - `a_uv.x` = material code (``MushroomWeatherMaterial``, 0 … 30) + ``MushroomWeatherShaders/valueScale`` · value
//   (0 … 1; only for the valued materials below, otherwise 0) + ``MushroomWeatherShaders/brokenOffset`` (32) when the
//   element is drawn in the broken colour. Write it with ``MushroomWeatherShaders/encode(_:value:broken:)``.
//   Valued materials: cap and capOut — the moisture h/M of the colony's cell at the shown cycle (bead density); mist —
//   h/M of its cell (shade); moon — its brightness ``MushroomWeatherShaders/moonBrightness(moonlight:)``; droplet and
//   mote — their phase 0 … 1 on their path.
// - `a_uv.y`: backdrop — the height h (0 bottom … 1 top); strip (frond, vent frame, gauge track) — the across
//   coordinate d, -1 on one long side and +1 on the other; solid (log, stone, stalk, cap, capOut, pod) — 0 on a lathed
//   (shaded) solid, and on a flat level-2 solid (zero normal: a screen-facing disc fan) the radial coordinate, 0 at the
//   centre vertex and 1 on the outline; every quad material — 0.
// - `a_normal`: solid — the surface normal in world space (zero for a flat level-2 solid, which is then shaded flat);
//   strip and backdrop — zero; quad materials (moon, phase ticks, floor, mist, rings, droplet, mote, vent slat, band
//   bracket, marker, run bars, actions bars, mold patch) — (u, v, w): the quad-local coordinate (u, v), the shape
//   spanning -1 … +1 and the quad ``MushroomWeatherShaders/quadExtent`` on each axis, and w = 0 except: droplet — the
//   rise distance in world units (``MushroomWeatherShaders/dropletRise(scale:)``); mote — the loop radius in world
//   units (``MushroomWeatherShaders/moteLoopRadius``). A band bracket's u runs along the track (-1 at low, +1 at high)
//   and v across it (+1 at the bar). Positions are world positions (model = identity). Only the droplets and motes
//   move: a droplet's vertices rise along +z by life · rise from where the geometry put them (life = fract(phase +
//   time · rate), so with time 0 or Reduce Motion it stands at its phase); a mote's move by radius · (cos a - 1, sin a)
//   in x, y with a = 2π(phase + time · rate) (its loop's centre is radius to -x of where the geometry put it). Every
//   other vertex is drawn where the geometry put it, so the CPU reference points (never a droplet or mote) hold.
//
// Signed-distance shading: strips and flat solids use the soft outline 1 - smoothstep(1 - ``edgeFeather``, 1, |d|);
// quads use smoothstep(-``markFeather``, ``markFeather``, distance) of their shape: square max(|u|, |v|) ≤ 1 (floor,
// mist, vent slat, run bars, actions bars), unit disc (moon, filled tick, marker, droplet, mote), ring of half-width
// ``ringHalf`` inside the unit circle (hollow tick, site ring, solid band ring, pod ring), the ring cut into
// ``dashCount`` dashes (dashed band ring), the bracket (bar at v ≥ ``bracketBar`` and ends at |u| ≥ ``bracketEnd``
// inside the square) and the lobed mold disc. A solid is shaded in layers from mu = n · ``viewDirection`` (limb
// darkening, core lifted toward white, rim light toward the glow colour); a cap is translucent (alpha ``capAlpha`` at
// its core rising to 1 at the rim) with moisture beads on a lattice in (azimuth, polar angle) of its normal, a lattice
// cell holding a bead when its hash is at most the density mix(``beadMin``, ``beadMax``, h/M). The fragment shader
// selects every code exactly once, so each pixel has one coverage rule.
//
// Glow program: the glow shells around the caps and pods, drawn additively and last. The colour is carried in
// `a_normal` (zero: the cap or pod colour by kind), `a_uv.x` is 2 · kind + factor (``GlowKind``: 0 cap, 1 pod;
// factor 0 … 1 — 1 for a cap in band, ``capOutGlowFactor`` out of band, 1 for a pod; see ``glowFactor(inBand:)``) and
// `a_uv.y` the shell's radial coordinate r, 0 on its inner edge and 1 on its outer edge. A won level (`u_won` = 1)
// raises every cap shell's factor to 1, so every cap glows. The alpha is ``glowWeight`` times the gain, the factor and
// (1 - r)²; the inner part is lifted toward the glow colour by ``glowCore``; the gain is `u_glowGain` capped by
// `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing the presenter passes ``glowGainCap``.
//
// Plain uniforms in the default block (at most 16 vec4 slots per program; the forest program uses 7: u_mvp 4, u_time,
// u_motion and u_won 1 each; the glow program 7: u_mvp 4, u_glowGain, u_glowLimit and u_won 1 each), no texture
// samplers, no image assets, no `discard` and no loops at all (so every loop is bounded; the bead field reads one
// lattice cell). Output is premultiplied alpha. Palette constants are generated from `MushroomWeatherPalette` with six
// fixed decimals, so the shader colours equal the CPU's within 1e-6.
//
// Feature 494 (R02-G20-04) T-R02G2004-002 (FR-R02G2004-002, 005, 006; clarification Q3) appends two materials after
// code 28, keeping every earlier code, the value scale and the broken offset (32, still above every code): 29
// ``MushroomWeatherMaterial/ghostPod`` — the dragged pod's ghost at its target site (quad, disc at
// ``ghostAlpha`` opacity, pod colour) — and 30 ``MushroomWeatherMaterial/scrubber`` — the cycle scrubber's track and
// mark (strip, moon colour).

import Foundation

/// The material code a forest-program vertex carries in `a_uv.x` (FR-R02G2003-001, 002): one per kind of element the
/// geometry draws, 0 … 30 (29 and 30 added by feature 494). The geometry writes
/// ``MushroomWeatherShaders/encode(_:value:broken:)``; the forest vertex
/// shader selects ``paletteConstant``. The comment of each case names its coverage rule and what `a_uv.y` and
/// `a_normal` carry (see the file header).
public enum MushroomWeatherMaterial: Int, Sendable, CaseIterable, Hashable {
    /// The backdrop quad (opaque; `a_uv.y` height h 0 … 1), the still gradient from midnight to midnight top.
    case backdrop = 0
    /// The moon disc (quad, disc), moon colour times its brightness (the value, (4 + L) / 7).
    case moon = 1
    /// A filled moon phase tick (quad, disc), moon colour; L + 1 of the four are filled.
    case phaseTickLit = 2
    /// A hollow moon phase tick (quad, ring), moon colour.
    case phaseTickUnlit = 3
    /// A floor cell's square (quad, square), moss colour.
    case floor = 4
    /// A blocked cell's log (solid, normal-shaded), log colour.
    case log = 5
    /// A blocked cell's stone dome (solid, normal-shaded), log colour.
    case stone = 6
    /// A decorative frond segment (strip), frond colour; drawn at the two richer tiers only.
    case frond = 7
    /// A cell's mist square (quad, square, translucent), mist low mixed to mist high by the value h/M.
    case mist = 8
    /// A pod site's ring (quad, ring), site colour.
    case siteRing = 9
    /// A colony's lathed stalk (solid), stalk colour.
    case stalk = 10
    /// A colony's cap while in band (solid, translucent, moisture beads by the value h/M), cap colour.
    case cap = 11
    /// A colony's cap while out of band (as ``cap``), cap out colour; lit in the cap colour on a won level.
    case capOut = 12
    /// A colony's band ring while in band (quad, solid ring), band colour.
    case bandRingSolid = 13
    /// A colony's band ring while out of band (quad, dashed ring), band colour.
    case bandRingDashed = 14
    /// A lathed spore pod (solid), pod colour.
    case pod = 15
    /// A grown pod's second ring (quad, ring), pod colour.
    case podRing = 16
    /// A droplet rising from a pod (quad, disc fading over its life; value its phase, `a_normal.z` its rise), droplet
    /// colour; moved by time, stopped under Reduce Motion.
    case droplet = 17
    /// A spore mote on a fixed loop (quad, disc; value its phase, `a_normal.z` its loop radius), droplet colour; moved
    /// by time, stopped under Reduce Motion.
    case mote = 18
    /// A vent's frame (strip), vent colour.
    case ventFrame = 19
    /// A vent slat, tilted open or flat shut by the geometry (quad, square), vent colour.
    case ventSlat = 20
    /// A colony gauge's track (strip), vent colour.
    case gaugeTrack = 21
    /// A gauge's band bracket over low … high (quad, bracket), band colour.
    case bandBracket = 22
    /// A gauge's humidity marker (quad, disc), marker colour.
    case marker = 23
    /// A lit segment of a colony's run bar, a cycle of its final run (quad, square), band colour.
    case runLit = 24
    /// An unlit segment of a run bar (quad, square), actions unlit colour.
    case runUnlit = 25
    /// A lit actions bar, an action left (quad, square), actions lit colour.
    case barLit = 26
    /// An unlit actions bar, an action spent (quad, square), actions unlit colour.
    case barUnlit = 27
    /// The mold patch on the moldy cell (quad, lobed disc), broken colour.
    case moldPatch = 28
    /// The dragged pod's ghost at its target site (quad, disc at ``MushroomWeatherShaders/ghostAlpha`` opacity), pod
    /// colour (feature 494, a preview only).
    case ghostPod = 29
    /// The cycle scrubber's track and mark (strip), moon colour (feature 494).
    case scrubber = 30

    /// The plain code (no value, not broken), as `Float` for the uv stream.
    public var code: Float { Float(rawValue) }

    /// The GLSL palette constant the forest vertex shader selects for this material.
    public var paletteConstant: String {
        switch self {
        case .backdrop: return "MW_MIDNIGHT"
        case .moon, .phaseTickLit, .phaseTickUnlit: return "MW_MOON"
        case .floor: return "MW_MOSS"
        case .log, .stone: return "MW_LOG"
        case .frond: return "MW_FROND"
        case .mist: return "MW_MIST_LOW"
        case .siteRing: return "MW_SITE"
        case .stalk: return "MW_STALK"
        case .cap: return "MW_CAP"
        case .capOut: return "MW_CAP_OUT"
        case .bandRingSolid, .bandRingDashed, .bandBracket, .runLit: return "MW_BAND"
        case .pod, .podRing, .ghostPod: return "MW_POD"
        case .droplet, .mote: return "MW_DROPLET"
        case .ventFrame, .ventSlat, .gaugeTrack: return "MW_VENT"
        case .marker: return "MW_MARKER"
        case .runUnlit, .barUnlit: return "MW_ACTIONS_UNLIT"
        case .barLit: return "MW_ACTIONS_LIT"
        case .moldPatch: return "MW_BROKEN"
        case .scrubber: return "MW_MOON"
        }
    }

    /// The palette colour of ``paletteConstant`` (the base colour before shading, value and won light).
    public var baseColour: SIMD3<Double> {
        for entry in MushroomWeatherShaders.paletteConstants where entry.name == paletteConstant {
            return entry.colour
        }
        return MushroomWeatherPalette.midnight
    }

    /// Whether the material carries a value in the fraction of `a_uv.x` (cap, capOut, mist, moon, droplet, mote).
    public var isValued: Bool {
        switch self {
        case .cap, .capOut, .mist, .moon, .droplet, .mote: return true
        default: return false
        }
    }
}

/// The GLSL ES 3.00 sources of Mushroom Weather's forest and glow programs, their uniform and attribute names, the
/// constants they are built from and the CPU references of what they compute (FR-R02G2003-001, 002, 004, 007).
public enum MushroomWeatherShaders {
    /// A glow-program vertex kind, encoded with the glow factor into `a_uv.x` as 2 · kind + factor.
    public enum GlowKind: Int, Sendable, CaseIterable, Hashable {
        /// A glow shell around a cap (zero colour: the cap colour); a won level raises its factor to 1.
        case cap = 0
        /// A glow shell around a pod (zero colour: the pod colour).
        case pod = 1

        /// The `a_uv.x` value of a vertex of this kind with glow factor `factor` (clamped to 0 … 1; non-finite counts
        /// as 0).
        public func code(factor: Double) -> Double {
            Double(2 * rawValue) + MushroomWeatherShaders.unit(factor)
        }

        /// The (kind, factor) the glow vertex shader decodes from `a_uv.x`: kind ⌊x / 2⌋ clamped to 0 … 1, factor
        /// x - 2 · kind clamped to 0 … 1 (x clamped to 0 … 3; non-finite counts as 0).
        public static func decode(_ x: Double) -> (kind: GlowKind, factor: Double) {
            let v: Double = x.isFinite ? min(max(x, 0), 3) : 0
            let k: Int = min(max(Int((v * 0.5).rounded(.down)), 0), 1)
            let factor: Double = min(max(v - Double(2 * k), 0), 1)
            return (kind: GlowKind(rawValue: k) ?? .cap, factor: factor)
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

    /// Every material as (Swift name, code, GLSL palette constant the forest vertex shader selects), codes 0 … 30.
    public static var materials: [(name: String, code: Float, constant: String)] {
        var result: [(name: String, code: Float, constant: String)] = []
        for material in MushroomWeatherMaterial.allCases {
            result.append((name: "\(material)", code: material.code, constant: material.paletteConstant))
        }
        return result
    }

    // MARK: Uniform names

    /// `mat4`: projection x view x model (both programs, vertex stage; model = identity, positions in world space).
    public static let mvpUniform: String = "u_mvp"
    /// `float`: the presentation time in seconds (forest vertex stage; moves the droplets and motes), as
    /// ``shaderTime(_:)`` wraps it.
    public static let timeUniform: String = "u_time"
    /// `float`: 1 normally, 0 under Reduce Motion (forest vertex stage; multiplies the time, so the droplets and motes
    /// stop at their phases); see ``motion(reduceMotion:)``.
    public static let motionUniform: String = "u_motion"
    /// `float`: the won level's light, 0 … 1 (forest vertex stage: lights every out-of-band cap in the cap colour;
    /// glow fragment stage: raises every cap shell's factor to 1); 0 on a level not won.
    public static let wonUniform: String = "u_won"
    /// `float`: the glow gain (glow fragment stage); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform: String = "u_glowGain"
    /// `float`: the glow limit (glow fragment stage): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform: String = "u_glowLimit"

    /// Every uniform the forest program declares, each once, in order of declaration (vertex stage first).
    public static let forestUniforms: [String] = [mvpUniform, timeUniform, motionUniform, wonUniform]

    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, wonUniform]

    /// The uniform lists per program name (`forest`, `glow`).
    public static let uniformNames: [String: [String]] = ["forest": forestUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), generated from
    /// `MushroomWeatherPalette` in its declaration order (21 entries): `MW_` and the colour's name in upper snake
    /// case (midnightTop: `MW_MIDNIGHT_TOP`).
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = {
        var result: [(name: String, colour: SIMD3<Double>)] = []
        for entry in MushroomWeatherPalette.all {
            result.append((name: constantName(entry.name), colour: entry.colour))
        }
        return result
    }()

    /// The GLSL constant name of palette colour `name`: `MW_` plus `name` in upper snake case.
    public static func constantName(_ name: String) -> String {
        var result: String = "MW_"
        for c in name {
            if c.isUppercase { result.append("_") }
            result.append(contentsOf: c.uppercased())
        }
        return result
    }

    /// The highest material code (the scrubber, feature 494).
    public static let maxMaterial: Int = MushroomWeatherMaterial.scrubber.rawValue
    /// What `a_uv.x` adds for an element drawn in the broken colour (above every code, so the shape is kept).
    public static let brokenOffset: Double = 32
    /// How much of `a_uv.x` above its code is the value: x = code + valueScale · value. Below 0.5, so the code still
    /// rounds to the material.
    public static let valueScale: Double = 0.4

    /// The unit direction from the scene toward the authored eye (eye (0, -1.6, 3.0) looking at (0, -0.2, 0)), the
    /// view direction the solids are shaded against.
    public static let viewDirection: SIMD3<Double> = {
        let d: SIMD3<Double> = SIMD3<Double>(0, -1.6, 3.0) - SIMD3<Double>(0, -0.2, 0)
        return d / (d * d).sum().squareRoot()
    }()

    /// The width of the soft outline as a share of the across (or radial) coordinate.
    public static let edgeFeather: Double = 0.25
    /// The soft edge of a quad shape in quad-local units: coverage smoothstep(-feather, feather, distance).
    public static let markFeather: Double = 0.06
    /// The half-width of a ring in quad-local units (the ring spans 1 - 2 · half … 1).
    public static let ringHalf: Double = 0.16
    /// The quad-local extent the geometry's quads span on each axis (-extent … +extent), room for the feather and the
    /// mold patch's lobes.
    public static let quadExtent: Double = 1.25
    /// The dashes around a dashed band ring.
    public static let dashCount: Double = 12
    /// The share of each dash period that is drawn.
    public static let dashDuty: Double = 0.55
    /// The soft edge of a dash in units of its period.
    public static let dashFeather: Double = 0.04
    /// The v above which a band bracket draws its bar.
    public static let bracketBar: Double = 0.4
    /// The |u| above which a band bracket draws its end ticks.
    public static let bracketEnd: Double = 0.8
    /// The lobes of the mold patch.
    public static let moldLobes: Double = 5
    /// How far the mold patch's lobes reach in and out of the unit circle.
    public static let moldWobble: Double = 0.12

    /// The share of a solid's colour at its very limb (limb darkening).
    public static let limbShade: Double = 0.55
    /// The mu below which a solid's limb darkens (smoothstep(0, limbEdge, mu)).
    public static let limbEdge: Double = 0.55
    /// The mu where a solid's core begins to lift toward white.
    public static let coreStart: Double = 0.85
    /// How far a solid's core (mu = 1) is lifted toward white.
    public static let coreLift: Double = 0.25
    /// The power of the rim light's rise toward grazing angles, (1 - mu)^power.
    public static let rimPower: Double = 3
    /// How far the rim light lifts a solid's limb toward the glow colour at mu = 0.
    public static let rimLift: Double = 0.35
    /// A lathed cap's opacity at its core (mu = 1), rising to 1 with the rim light (translucent cap).
    public static let capAlpha: Double = 0.82

    /// The bead lattice's cells around a cap (in azimuth).
    public static let beadColumns: Double = 14
    /// The bead lattice's cells per radian of polar angle.
    public static let beadRows: Double = 5
    /// The share of lattice cells holding a bead on a dry cap (h/M = 0).
    public static let beadMin: Double = 0.08
    /// The share of lattice cells holding a bead on a cap at the mold bound (h/M = 1).
    public static let beadMax: Double = 0.7
    /// A bead's radius in lattice units (the cell spans -0.5 … 0.5).
    public static let beadRadius: Double = 0.22
    /// The soft edge of a bead in lattice units.
    public static let beadFeather: Double = 0.08
    /// How far a bead lifts the cap toward white.
    public static let beadLift: Double = 0.55

    /// The mist squares' opacity.
    public static let mistAlpha: Double = 0.62
    /// The ghost pod's opacity (feature 494).
    public static let ghostAlpha: Double = 0.45
    /// The droplets' cycles per second along their rise.
    public static let dropletRate: Double = 0.5
    /// The share of a droplet's life over which it fades in.
    public static let dropletFadeIn: Double = 0.15
    /// A droplet's rise in units of the cell scale s (``dropletRise(scale:)``).
    public static let dropletRiseShare: Double = 0.6
    /// The motes' loops per second.
    public static let moteRate: Double = 0.05
    /// The motes' loop radius in world units (written in `a_normal.z`).
    public static let moteLoopRadius: Double = 0.08
    /// The period the presenter wraps the time into (whole cycles of both the droplets and the motes), seconds.
    public static let timeWrap: Double = 600

    /// The glow alpha weight, times the glow gain, the glow factor and the fade.
    public static let glowWeight: Double = 0.5
    /// How far a glow shell's inner part is lifted toward the glow colour, times the fade.
    public static let glowCore: Double = 0.5
    /// The glow factor of an out-of-band cap's shell (1 in band; a won level raises it to 1).
    public static let capOutGlowFactor: Double = 0.3
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
    static func decimals(_ x: Double) -> String { String(format: "%.6f", x) }

    /// `v` as a GLSL `vec3(...)` literal with six fixed decimals.
    static func vec3Literal(_ v: SIMD3<Double>) -> String {
        "vec3(\(decimals(v.x)), \(decimals(v.y)), \(decimals(v.z)))"
    }

    /// The `const vec3` lines of the palette colours named (camel-case palette names), generated from
    /// ``paletteConstants`` in palette order; every colour when `names` is nil.
    static func paletteBlock(_ names: [String]?) -> String {
        var lines: [String] = []
        for entry in MushroomWeatherPalette.all where names == nil || names?.contains(entry.name) == true {
            lines.append("const vec3 \(constantName(entry.name)) = \(vec3Literal(entry.colour));")
        }
        return lines.joined(separator: "\n")
    }

    /// The forest vertex shader. Uniforms: `u_mvp`, `u_time`, `u_motion`, `u_won`. Decodes the material, the broken
    /// mark and the value from `a_uv.x` (``decode(_:)``), moves the droplets and motes by the time times the motion
    /// (``dropletLife(phase:time:motion:)``, ``moteOffset(phase:radius:time:motion:)``), selects the base colour
    /// (``baseColour(of:value:broken:won:)``) and passes the normal or quad-local coordinate, the material, the local
    /// coordinate and the value (a droplet's life).
    public static let forestVertex: String = """
    #version 300 es
    precision highp float;
    layout(location = 0) in vec3 a_position;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    uniform mat4 u_mvp;
    uniform float u_time;
    uniform float u_motion;
    uniform float u_won;
    out vec3 v_base;
    out vec3 v_aux;
    out float v_material;
    out float v_local;
    out float v_value;
    \(paletteBlock(nil))
    const float MW_MAX_MATERIAL = \(decimals(Double(maxMaterial)));
    const float MW_BROKEN_OFFSET = \(decimals(brokenOffset));
    const float MW_VALUE_SCALE = \(decimals(valueScale));
    const float MW_DROPLET_RATE = \(decimals(dropletRate));
    const float MW_MOTE_RATE = \(decimals(moteRate));
    const float MW_TAU = 6.283185;
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float coded = clamp(floor(a_uv.x + 0.5), 0.0, MW_BROKEN_OFFSET + MW_MAX_MATERIAL);
        float marked = step(MW_BROKEN_OFFSET - 0.5, coded);
        float m = clamp(coded - MW_BROKEN_OFFSET * marked, 0.0, MW_MAX_MATERIAL);
        float value = clamp((a_uv.x - coded) / MW_VALUE_SCALE, 0.0, 1.0);
        float won = clamp(u_won, 0.0, 1.0);
        float clock = max(u_time, 0.0) * clamp(u_motion, 0.0, 1.0);
        float isDroplet = isCode(m, 17.0);
        float isMote = isCode(m, 18.0);
        float life = fract(value + clock * MW_DROPLET_RATE);
        float angle = MW_TAU * (value + clock * MW_MOTE_RATE);
        vec3 p = a_position;
        p.z = p.z + isDroplet * life * a_normal.z;
        p.xy = p.xy + isMote * a_normal.z * vec2(cos(angle) - 1.0, sin(angle));
        vec3 base = MW_MIDNIGHT;
        base = mix(base, MW_MOON, isCode(m, 1.0));
        base = mix(base, MW_MOON, isCode(m, 2.0));
        base = mix(base, MW_MOON, isCode(m, 3.0));
        base = mix(base, MW_MOSS, isCode(m, 4.0));
        base = mix(base, MW_LOG, isCode(m, 5.0));
        base = mix(base, MW_LOG, isCode(m, 6.0));
        base = mix(base, MW_FROND, isCode(m, 7.0));
        base = mix(base, MW_MIST_LOW, isCode(m, 8.0));
        base = mix(base, MW_SITE, isCode(m, 9.0));
        base = mix(base, MW_STALK, isCode(m, 10.0));
        base = mix(base, MW_CAP, isCode(m, 11.0));
        base = mix(base, MW_CAP_OUT, isCode(m, 12.0));
        base = mix(base, MW_BAND, isCode(m, 13.0));
        base = mix(base, MW_BAND, isCode(m, 14.0));
        base = mix(base, MW_POD, isCode(m, 15.0));
        base = mix(base, MW_POD, isCode(m, 16.0));
        base = mix(base, MW_DROPLET, isCode(m, 17.0));
        base = mix(base, MW_DROPLET, isCode(m, 18.0));
        base = mix(base, MW_VENT, isCode(m, 19.0));
        base = mix(base, MW_VENT, isCode(m, 20.0));
        base = mix(base, MW_VENT, isCode(m, 21.0));
        base = mix(base, MW_BAND, isCode(m, 22.0));
        base = mix(base, MW_MARKER, isCode(m, 23.0));
        base = mix(base, MW_BAND, isCode(m, 24.0));
        base = mix(base, MW_ACTIONS_UNLIT, isCode(m, 25.0));
        base = mix(base, MW_ACTIONS_LIT, isCode(m, 26.0));
        base = mix(base, MW_ACTIONS_UNLIT, isCode(m, 27.0));
        base = mix(base, MW_BROKEN, isCode(m, 28.0));
        base = mix(base, MW_POD, isCode(m, 29.0));
        base = mix(base, MW_MOON, isCode(m, 30.0));
        base = mix(base, MW_MIST_HIGH, isCode(m, 8.0) * value);
        base = mix(base, MW_CAP, isCode(m, 12.0) * won);
        base = base * mix(1.0, value, isCode(m, 1.0));
        base = mix(base, MW_BROKEN, marked);
        v_base = base;
        v_aux = a_normal;
        v_material = m;
        v_local = clamp(a_uv.y, -1.0, 1.0);
        v_value = mix(value, life, isDroplet);
        gl_Position = u_mvp * vec4(p, 1.0);
    }
    """

    /// The forest fragment shader (no uniforms). The still backdrop gradient (``backdropColour(height:)``), the
    /// layered solids (``solidShade(_:mu:)``, ``solidShade(_:normal:)``), the translucent caps with moisture beads
    /// (``capOpacity(mu:)``, ``beadCoverage(normal:moisture:)``), the soft outline of strips and flat solids
    /// (``edgeCoverage(local:)``) and the signed-distance quad shapes (``quadCoverage(_:u:v:)``). Every material code
    /// selects exactly one coverage rule. Premultiplied.
    public static let forestFragment: String = """
    #version 300 es
    precision highp float;
    in vec3 v_base;
    in vec3 v_aux;
    in float v_material;
    in float v_local;
    in float v_value;
    out vec4 color;
    \(paletteBlock(["midnight", "midnightTop", "glow"]))
    const vec3 MW_VIEW_DIR = \(vec3Literal(viewDirection));
    const float MW_TAU = 6.283185;
    const float MW_EDGE_FEATHER = \(decimals(edgeFeather));
    const float MW_MARK_FEATHER = \(decimals(markFeather));
    const float MW_RING_HALF = \(decimals(ringHalf));
    const float MW_DASH_COUNT = \(decimals(dashCount));
    const float MW_DASH_DUTY = \(decimals(dashDuty));
    const float MW_DASH_FEATHER = \(decimals(dashFeather));
    const float MW_BRACKET_BAR = \(decimals(bracketBar));
    const float MW_BRACKET_END = \(decimals(bracketEnd));
    const float MW_MOLD_LOBES = \(decimals(moldLobes));
    const float MW_MOLD_WOBBLE = \(decimals(moldWobble));
    const float MW_LIMB_SHADE = \(decimals(limbShade));
    const float MW_LIMB_EDGE = \(decimals(limbEdge));
    const float MW_CORE_START = \(decimals(coreStart));
    const float MW_CORE_LIFT = \(decimals(coreLift));
    const float MW_RIM_POWER = \(decimals(rimPower));
    const float MW_RIM_LIFT = \(decimals(rimLift));
    const float MW_CAP_ALPHA = \(decimals(capAlpha));
    const float MW_BEAD_COLUMNS = \(decimals(beadColumns));
    const float MW_BEAD_ROWS = \(decimals(beadRows));
    const float MW_BEAD_MIN = \(decimals(beadMin));
    const float MW_BEAD_MAX = \(decimals(beadMax));
    const float MW_BEAD_RADIUS = \(decimals(beadRadius));
    const float MW_BEAD_FEATHER = \(decimals(beadFeather));
    const float MW_BEAD_LIFT = \(decimals(beadLift));
    const float MW_MIST_ALPHA = \(decimals(mistAlpha));
    const float MW_DROPLET_FADE_IN = \(decimals(dropletFadeIn));
    const float MW_GHOST_ALPHA = \(decimals(ghostAlpha));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    float cover(float dist) {
        return smoothstep(-MW_MARK_FEATHER, MW_MARK_FEATHER, dist);
    }
    float beadHash(vec2 c) {
        return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
    }
    void main() {
        float m = floor(v_material + 0.5);
        float value = clamp(v_value, 0.0, 1.0);
        float d = clamp(abs(v_local), 0.0, 1.0);
        float edge = 1.0 - smoothstep(1.0 - MW_EDGE_FEATHER, 1.0, d);
        float sky = isCode(m, 0.0);
        float disc = isCode(m, 1.0) + isCode(m, 2.0) + isCode(m, 18.0) + isCode(m, 23.0);
        float ring = isCode(m, 3.0) + isCode(m, 9.0) + isCode(m, 13.0) + isCode(m, 16.0);
        float square = isCode(m, 4.0) + isCode(m, 20.0) + isCode(m, 24.0) + isCode(m, 25.0);
        square = square + isCode(m, 26.0) + isCode(m, 27.0);
        float solid = isCode(m, 5.0) + isCode(m, 6.0) + isCode(m, 10.0) + isCode(m, 15.0);
        float strip = isCode(m, 7.0) + isCode(m, 19.0) + isCode(m, 21.0) + isCode(m, 30.0);
        float isMist = isCode(m, 8.0);
        float isCap = isCode(m, 11.0) + isCode(m, 12.0);
        float dashed = isCode(m, 14.0);
        float isDroplet = isCode(m, 17.0);
        float isBracket = isCode(m, 22.0);
        float isMold = isCode(m, 28.0);
        float isGhost = isCode(m, 29.0);
        float h = clamp(v_local, 0.0, 1.0);
        vec3 backdrop = mix(MW_MIDNIGHT, MW_MIDNIGHT_TOP, h);
        float nl = length(v_aux);
        float shaded = step(0.0001, nl);
        vec3 n = v_aux / max(nl, 0.0001);
        float mu = clamp(dot(n, MW_VIEW_DIR), 0.0, 1.0);
        float rim = pow(1.0 - mu, MW_RIM_POWER);
        vec3 body = mix(v_base * MW_LIMB_SHADE, v_base, smoothstep(0.0, MW_LIMB_EDGE, mu));
        body = mix(body, vec3(1.0), MW_CORE_LIFT * smoothstep(MW_CORE_START, 1.0, mu));
        body = mix(body, MW_GLOW, MW_RIM_LIFT * rim);
        vec3 solidRgb = mix(v_base, body, shaded);
        float azimuth = atan(n.y, n.x + 0.00001) * MW_BEAD_COLUMNS / MW_TAU;
        vec2 q = vec2(azimuth, acos(clamp(n.z, -1.0, 1.0)) * MW_BEAD_ROWS);
        vec2 f = fract(q) - 0.5;
        float density = mix(MW_BEAD_MIN, MW_BEAD_MAX, value);
        float present = step(beadHash(floor(q)), density);
        float bead = (1.0 - smoothstep(MW_BEAD_RADIUS - MW_BEAD_FEATHER, MW_BEAD_RADIUS, length(f))) * present;
        vec3 capRgb = mix(solidRgb, vec3(1.0), MW_BEAD_LIFT * bead * shaded);
        float capAlpha = mix(1.0, mix(MW_CAP_ALPHA, 1.0, rim), shaded);
        vec2 p = v_aux.xy;
        float r = length(p);
        float ang = atan(p.y, p.x + 0.00001);
        float squareCover = cover(1.0 - max(abs(p.x), abs(p.y)));
        float discCover = cover(1.0 - r);
        float ringCover = cover(MW_RING_HALF - abs(r - (1.0 - MW_RING_HALF)));
        float t = fract(ang * MW_DASH_COUNT / MW_TAU);
        float dash = smoothstep(-MW_DASH_FEATHER, MW_DASH_FEATHER, MW_DASH_DUTY * 0.5 - abs(t - 0.5));
        float arm = max(cover(p.y - MW_BRACKET_BAR), cover(abs(p.x) - MW_BRACKET_END));
        float bracketCover = squareCover * arm;
        float moldCover = cover(1.0 - r - MW_MOLD_WOBBLE * sin(MW_MOLD_LOBES * ang));
        float fade = smoothstep(0.0, MW_DROPLET_FADE_IN, value) * (1.0 - value);
        vec3 rgb = mix(v_base, backdrop, sky);
        rgb = mix(rgb, solidRgb, solid);
        rgb = mix(rgb, capRgb, isCap);
        float coverage = sky;
        coverage = coverage + edge * (solid + strip) + edge * capAlpha * isCap;
        coverage = coverage + squareCover * square + squareCover * MW_MIST_ALPHA * isMist;
        coverage = coverage + discCover * disc + discCover * fade * isDroplet;
        coverage = coverage + ringCover * ring + ringCover * dash * dashed;
        coverage = coverage + bracketCover * isBracket + moldCover * isMold;
        coverage = coverage + discCover * MW_GHOST_ALPHA * isGhost;
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
    \(paletteBlock(["cap", "pod", "glow"]))
    const float MW_GLOW_WEIGHT = \(decimals(glowWeight));
    const float MW_GLOW_CORE = \(decimals(glowCore));
    const float MW_MAX_GAIN = \(decimals(maxGlowGain));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, MW_MAX_GAIN), clamp(u_glowLimit, 0.0, MW_MAX_GAIN));
        float kind = floor(v_kind + 0.5);
        float isCap = isCode(kind, 0.0);
        float isPod = isCode(kind, 1.0);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 fallback = mix(MW_CAP, MW_POD, isPod);
        vec3 rgb = mix(fallback, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        float factor = mix(clamp(v_factor, 0.0, 1.0), 1.0, won * isCap);
        float r = 1.0 - clamp(v_radius, 0.0, 1.0);
        float fade = r * r;
        rgb = mix(rgb, MW_GLOW, MW_GLOW_CORE * fade);
        float alpha = clamp(MW_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: Encoding (the geometry writes these)

    /// The `a_uv.x` a forest vertex of `material` writes: its code, plus ``valueScale`` times `value` (clamped to
    /// 0 … 1, non-finite counts as 0; only for a valued material, otherwise ignored), plus ``brokenOffset`` when
    /// `broken`.
    public static func encode(_ material: MushroomWeatherMaterial, value: Double = 0, broken: Bool = false) -> Double {
        let v: Double = material.isValued ? unit(value) : 0
        return Double(material.rawValue) + valueScale * v + (broken ? brokenOffset : 0)
    }

    /// What the forest vertex shader decodes from `a_uv.x` value `x`: the code rounded to the nearest integer and
    /// clamped to 0 … ``brokenOffset`` + ``maxMaterial``; broken when it is at least ``brokenOffset``; the material
    /// the code less the offset, clamped to 0 … ``maxMaterial``; the value (x - code) / ``valueScale`` clamped to
    /// 0 … 1. Non-finite counts as the backdrop, value 0, not broken.
    public static func decode(_ x: Double) -> (material: MushroomWeatherMaterial, value: Double, broken: Bool) {
        guard x.isFinite else { return (material: .backdrop, value: 0, broken: false) }
        let top: Double = brokenOffset + Double(maxMaterial)
        let coded: Double = min(max((x + 0.5).rounded(.down), 0), top)
        let broken: Bool = coded >= brokenOffset - 0.5
        let m: Double = min(max(coded - (broken ? brokenOffset : 0), 0), Double(maxMaterial))
        let material: MushroomWeatherMaterial = MushroomWeatherMaterial(rawValue: Int(m)) ?? .backdrop
        return (material: material, value: unit((x - coded) / valueScale), broken: broken)
    }

    /// The moon's brightness at moonlight level `moonlight` (clamped to 0 … 3): (4 + L) / 7, the moon's value.
    public static func moonBrightness(moonlight: Int) -> Double {
        Double(4 + min(max(moonlight, 0), 3)) / 7
    }

    /// The moisture value of a cap or mist square: h / M clamped to 0 … 1 (0 when M ≤ 0).
    public static func moisture(humidity: Int, moldBound: Int) -> Double {
        guard moldBound > 0 else { return 0 }
        return unit(Double(humidity) / Double(moldBound))
    }

    /// The rise a droplet writes in `a_normal.z` at cell scale `scale`: ``dropletRiseShare`` · scale (non-finite or
    /// negative scale counts as 0).
    public static func dropletRise(scale: Double) -> Double {
        scale.isFinite ? dropletRiseShare * max(scale, 0) : 0
    }

    /// The glow factor a cap shell writes: 1 in band, ``capOutGlowFactor`` out of band (a won level raises it to 1 in
    /// the shader).
    public static func glowFactor(inBand: Bool) -> Double {
        inBand ? 1 : capOutGlowFactor
    }

    // MARK: Uniform values (the presenter passes these)

    /// The time the presenter passes as `u_time`: `time` wrapped into 0 ..< ``timeWrap`` (whole cycles of the droplets
    /// and motes, so nothing jumps; non-finite or negative counts as 0), keeping float precision on long sessions.
    public static func shaderTime(_ time: Double) -> Double {
        guard time.isFinite, time > 0 else { return 0 }
        return time.truncatingRemainder(dividingBy: timeWrap)
    }

    /// The value the presenter passes as `u_motion`: 0 under Reduce Motion (the droplets and motes stop), else 1.
    public static func motion(reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : 1
    }

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: MushroomWeatherTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    // MARK: CPU references

    /// The base colour the forest vertex shader selects for `material` with `value` (clamped 0 … 1, non-finite 0),
    /// `broken` and won light `won` (clamped 0 … 1, non-finite 0): the broken colour when broken; else the material's
    /// palette colour, mist mixed toward mist high by the value, capOut mixed toward the cap colour by `won`, the moon
    /// times its value.
    public static func baseColour(of material: MushroomWeatherMaterial, value: Double, broken: Bool,
                                  won: Double) -> SIMD3<Double> {
        if broken { return MushroomWeatherPalette.broken }
        let base: SIMD3<Double> = material.baseColour
        switch material {
        case .mist: return base + (MushroomWeatherPalette.mistHigh - base) * unit(value)
        case .capOut: return base + (MushroomWeatherPalette.cap - base) * unit(won)
        case .moon: return base * unit(value)
        default: return base
        }
    }

    /// The still backdrop colour at height `height` (0 bottom … 1 top; clamped, non-finite counts as 0): the gradient
    /// from midnight to midnight top.
    public static func backdropColour(height: Double) -> SIMD3<Double> {
        let low: SIMD3<Double> = MushroomWeatherPalette.midnight
        return low + (MushroomWeatherPalette.midnightTop - low) * unit(height)
    }

    /// The soft-outline coverage of local (across or radial) coordinate `local`: 1 - smoothstep(1 - ``edgeFeather``,
    /// 1, |local|), |local| clamped to 0 … 1 (non-finite counts as the outline, 0 coverage).
    public static func edgeCoverage(local: Double) -> Double {
        guard local.isFinite else { return 0 }
        return 1 - smoothstep(1 - edgeFeather, 1, min(abs(local), 1))
    }

    /// The angle GLSL's atan(v, u + 0.00001) gives (radians).
    static func angle(u: Double, v: Double) -> Double { atan2(v, u + 0.00001) }

    /// The coverage of quad material `material` at quad-local (`u`, `v`): smoothstep(-``markFeather``,
    /// ``markFeather``, distance) of its shape (square, disc, ring, dashed ring, bracket, lobed mold disc); the mist
    /// times ``mistAlpha``; a droplet's disc without its life fade. 0 for a non-quad material or non-finite input.
    public static func quadCoverage(_ material: MushroomWeatherMaterial, u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return 0 }
        func cover(_ dist: Double) -> Double { smoothstep(-markFeather, markFeather, dist) }
        let r: Double = (u * u + v * v).squareRoot()
        let squareCover: Double = cover(1 - max(abs(u), abs(v)))
        let ringCover: Double = cover(ringHalf - abs(r - (1 - ringHalf)))
        switch material {
        case .floor, .ventSlat, .runLit, .runUnlit, .barLit, .barUnlit: return squareCover
        case .mist: return squareCover * mistAlpha
        case .moon, .phaseTickLit, .mote, .marker, .droplet: return cover(1 - r)
        case .phaseTickUnlit, .siteRing, .bandRingSolid, .podRing: return ringCover
        case .bandRingDashed: return ringCover * dashCoverage(u: u, v: v)
        case .bandBracket:
            return squareCover * max(cover(v - bracketBar), cover(abs(u) - bracketEnd))
        case .moldPatch: return cover(1 - r - moldWobble * sin(moldLobes * angle(u: u, v: v)))
        case .ghostPod: return cover(1 - r) * ghostAlpha
        default: return 0
        }
    }

    /// The dash coverage of a dashed band ring at quad-local (`u`, `v`): t = fract(angle · ``dashCount`` / 2π),
    /// smoothstep(-``dashFeather``, ``dashFeather``, ``dashDuty`` / 2 - |t - 0.5|).
    public static func dashCoverage(u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return 0 }
        let x: Double = angle(u: u, v: v) * dashCount / (2 * Double.pi)
        let t: Double = x - x.rounded(.down)
        return smoothstep(-dashFeather, dashFeather, dashDuty * 0.5 - abs(t - 0.5))
    }

    /// The layered colour of a lathed solid of `material` at mu = n · ``viewDirection`` (clamped to 0 … 1; non-finite
    /// counts as 1), base colour `base` (the material's palette colour when nil): the limb from base · ``limbShade`` to
    /// the base by smoothstep(0, ``limbEdge``, mu), the core lifted toward white by ``coreLift`` ·
    /// smoothstep(``coreStart``, 1, mu), then the rim light by ``rimLift`` · (1 - mu)^``rimPower`` toward the glow
    /// colour.
    public static func solidShade(_ material: MushroomWeatherMaterial, mu: Double,
                                  base: SIMD3<Double>? = nil) -> SIMD3<Double> {
        let m: Double = mu.isFinite ? min(max(mu, 0), 1) : 1
        let colour: SIMD3<Double> = base ?? material.baseColour
        let shade: SIMD3<Double> = colour * limbShade
        var c: SIMD3<Double> = shade + (colour - shade) * smoothstep(0, limbEdge, m)
        c += (SIMD3<Double>(1, 1, 1) - c) * (coreLift * smoothstep(coreStart, 1, m))
        c += (MushroomWeatherPalette.glow - c) * (rimLift * pow(1 - m, rimPower))
        return c
    }

    /// The colour of a solid with normal `normal` (any length): ``solidShade(_:mu:base:)`` of the normalised normal ·
    /// ``viewDirection``; a zero or non-finite normal (a flat level-2 solid) is shaded flat, the base colour.
    public static func solidShade(_ material: MushroomWeatherMaterial, normal: SIMD3<Double>) -> SIMD3<Double> {
        guard let n = normalised(normal) else { return material.baseColour }
        return solidShade(material, mu: (n * viewDirection).sum())
    }

    /// A lathed cap's opacity at mu (clamped 0 … 1; non-finite counts as 1): mix(``capAlpha``, 1, (1 - mu)^rimPower).
    public static func capOpacity(mu: Double) -> Double {
        let m: Double = mu.isFinite ? min(max(mu, 0), 1) : 1
        let rim: Double = pow(1 - m, rimPower)
        return capAlpha + (1 - capAlpha) * rim
    }

    /// The share of bead lattice cells that hold a bead at moisture `moisture` (h/M; clamped, non-finite 0):
    /// mix(``beadMin``, ``beadMax``, moisture).
    public static func beadDensity(moisture: Double) -> Double {
        beadMin + (beadMax - beadMin) * unit(moisture)
    }

    /// The bead lattice hash of cell (`x`, `y`): fract(sin(dot(c, (12.9898, 78.233))) · 43758.5453), as the fragment
    /// shader computes it (the GPU's float result may differ near a threshold; a reference, not a pixel oracle).
    public static func beadHash(x: Double, y: Double) -> Double {
        let s: Double = sin(x * 12.9898 + y * 78.233) * 43758.5453
        return s - s.rounded(.down)
    }

    /// The bead lattice coordinate of unit normal `normal`: (atan(n.y, n.x + 0.00001) · ``beadColumns`` / 2π,
    /// acos(n.z) · ``beadRows``).
    public static func beadLattice(normal n: SIMD3<Double>) -> SIMD2<Double> {
        let azimuth: Double = atan2(n.y, n.x + 0.00001) * beadColumns / (2 * Double.pi)
        return SIMD2<Double>(azimuth, acos(min(max(n.z, -1), 1)) * beadRows)
    }

    /// The bead coverage of a lathed cap at normal `normal` (any length) and moisture `moisture`: on the lattice cell
    /// holding the normal, 1 - smoothstep(``beadRadius`` - ``beadFeather``, ``beadRadius``, distance to the cell
    /// centre) when the cell's hash is at most ``beadDensity(moisture:)``, else 0; 0 for a zero or non-finite normal
    /// (flat caps have no beads).
    public static func beadCoverage(normal: SIMD3<Double>, moisture: Double) -> Double {
        guard let n = normalised(normal) else { return 0 }
        let q: SIMD2<Double> = beadLattice(normal: n)
        let cell: SIMD2<Double> = SIMD2<Double>(q.x.rounded(.down), q.y.rounded(.down))
        guard beadHash(x: cell.x, y: cell.y) <= beadDensity(moisture: moisture) else { return 0 }
        let f: SIMD2<Double> = q - cell - SIMD2<Double>(0.5, 0.5)
        return 1 - smoothstep(beadRadius - beadFeather, beadRadius, (f * f).sum().squareRoot())
    }

    /// A droplet's life (0 … 1 along its rise) at phase `phase` (clamped 0 … 1, non-finite 0), shader time `time`
    /// and motion `motion` (clamped 0 … 1, non-finite 0): fract(phase + max(time, 0) · motion · ``dropletRate``);
    /// with motion 0 it stays at its phase.
    public static func dropletLife(phase: Double, time: Double, motion: Double) -> Double {
        let clock: Double = (time.isFinite ? max(time, 0) : 0) * unit(motion)
        let x: Double = unit(phase) + clock * dropletRate
        return x - x.rounded(.down)
    }

    /// A droplet's opacity factor at life `life`: smoothstep(0, ``dropletFadeIn``, life) · (1 - life).
    public static func dropletFade(life: Double) -> Double {
        let l: Double = unit(life)
        return smoothstep(0, dropletFadeIn, l) * (1 - l)
    }

    /// A mote's offset from where the geometry put it, at phase `phase`, loop radius `radius`, shader time `time` and
    /// motion `motion`: radius · (cos a - 1, sin a) with a = 2π(phase + max(time, 0) · motion · ``moteRate``)
    /// (non-finite inputs count as 0). Zero at time 0 when the phase is 0, and wherever the motion is 0 the mote stays
    /// at its phase's point.
    public static func moteOffset(phase: Double, radius: Double, time: Double, motion: Double) -> SIMD2<Double> {
        let clock: Double = (time.isFinite ? max(time, 0) : 0) * unit(motion)
        let a: Double = 2 * Double.pi * (unit(phase) + clock * moteRate)
        let r: Double = radius.isFinite ? radius : 0
        return SIMD2<Double>(r * (cos(a) - 1), r * sin(a))
    }

    /// The glow gain the glow shader applies: `gain` and `limit` each clamped to 0 … ``maxGlowGain`` (non-finite counts
    /// as 0), the smaller of the two.
    public static func glowGain(gain: Double, limit: Double) -> Double {
        func clamped(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), maxGlowGain) : 0 }
        return min(clamped(gain), clamped(limit))
    }

    /// The glow of a vertex with `colour` (zero counts as the cap or pod colour by `kind`), glow factor `factor`,
    /// radial coordinate `radius`, the applied `gain` and won light `won`, before premultiplying: the colour lifted
    /// toward the glow colour by ``glowCore`` · (1 - radius)², with alpha ``glowWeight`` · gain · factor ·
    /// (1 - radius)², a cap shell's factor raised to 1 by `won`; every component clamped to 0 … 1.
    public static func glowColour(colour: SIMD3<Double>, kind: GlowKind, factor: Double, radius: Double, gain: Double,
                                  won: Double) -> SIMD4<Double> {
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 {
            switch kind {
            case .cap: c = MushroomWeatherPalette.cap
            case .pod: c = MushroomWeatherPalette.pod
            }
        }
        var f: Double = unit(factor)
        if kind == .cap { f += (1 - f) * unit(won) }
        let r: Double = 1 - unit(radius)
        let fade: Double = r * r
        c += (MushroomWeatherPalette.glow - c) * (glowCore * fade)
        let k: Double = gain.isFinite ? gain : 0
        return SIMD4<Double>(unit(c.x), unit(c.y), unit(c.z), unit(glowWeight * k * f * fade))
    }

    /// `v` normalised, nil when zero (length below 0.0001) or non-finite.
    static func normalised(_ v: SIMD3<Double>) -> SIMD3<Double>? {
        guard v.x.isFinite, v.y.isFinite, v.z.isFinite else { return nil }
        let length: Double = (v * v).sum().squareRoot()
        guard length >= 0.0001 else { return nil }
        return v / length
    }

    /// `x` clamped to 0 … 1 (non-finite counts as 0).
    static func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
