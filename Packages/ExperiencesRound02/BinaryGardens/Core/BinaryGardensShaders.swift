// BinaryGardensShaders — feature 503 (R02-G21-03) T-R02G2103-003 (FR-R02G2103-001, 002, 003, 004, 007, 010;
// SC-R02G2103-003; clarifications Q1–Q4, Q6; research R5–R8). The two GLSL ES 3.00 programs of Binary Gardens held as
// source text (data: the core issues no GL call), with the names of every uniform they declare, their vertex
// attributes (the three `ShaderMeshRenderer` streams), the material codes shared with `BinaryGardensSceneGeometry`
// (``BinaryGardensMaterial``), the constants the sources are built from and the CPU twins of what they compute.
// Presentation only: no rule is ever evaluated on these values, and nothing drawn is consulted by the rules.
//
// System program: the still space backdrop (a vertical gradient from space to space top) with a procedural starfield
// of hashed points covering at most 2 % of its area; the tilt dial's pips (filled or ring); the star rings' dashes
// (idle, solid in a star's colour, or alternating both colours dash by dash on a shared ring) and the world orbits;
// the trail dots fading with age; the garden worlds (cube-sphere solids) lit by both stars in their own colours by
// max(0, n · l_i) times a response of each star's kernel share, with a brightened sunrise band along each star's
// terminator over an ambient floor of 0.35 of the surface colour, and shader-only seasonal banding by the world's band
// at the shown tick from the latitude φ = asin(n.z) with feathered edges — frost caps (lethal low |φ| ≥ 30°, dim
// |φ| ≥ 60°), procedural flowers (comfortable), a scorched belt (bright |φ| ≤ 15°, lethal high |φ| ≤ 40°); a won level
// makes every world bloom (`u_won`); the world pips; the star discs with their white-hot core of half the radius; the
// corona rays (their reach pulsing by `u_time` times `u_motion`, so Reduce Motion stills them); the luminosity pips;
// the gauge plates, tick cells (crossed lethal, hollow dim or bright, solid comfortable), guide lines, window brackets
// (solid, or dashed when short of the required window), required tick, tick marker, bloom track, bracket and marker;
// the actions bars; the pollen motes on a fixed loop (moved by time times motion); the broken rings; and the broken
// colour of anything a failure names (any material, keeping its shape).
//
// Vertex streams (the geometry states the same contract; the shared renderer binds only position, normal and uv):
// - `a_uv.x` = material code (``BinaryGardensMaterial``, 0 … 41) + ``BinaryGardensShaders/valueScale`` · value
//   (0 … 1; only for the valued materials below, otherwise 0) + ``BinaryGardensShaders/brokenOffset`` (64) when the
//   element is drawn in the broken colour. Write it with ``BinaryGardensShaders/encode(_:value:broken:)``.
//   Valued materials: the five world materials — star 1's share of the world's flux at the shown tick over 64 000;
//   trail — its freshness 1 − age / (trail ticks + 1); the five cell materials — the cell's height share
//   min(1, F / λ_hi); corona and mote — their phase 0 … 1.
// - `a_uv.y`: backdrop — the height h (0 bottom … 1 top); world — star 2's share over 64 000; every other material 0.
// - `a_normal`: world — the unit sphere normal; backdrop — (x, y, 0), the point's offsets in world units from the
//   backdrop centre along its right and up axes (the starfield's lattice coordinate); every flat (pips, dashes, orbit
//   segments, trail dots, star discs, rays, cells, plates, guides, brackets, ticks, markers, tracks, bars, motes,
//   broken rings) — (u, v, w): the quad-local coordinate (u, v), the shape spanning −1 … +1 and the quad
//   ``BinaryGardensShaders/quadExtent`` on each axis, and the shape parameter w = 0 except: ringShared — the dash's
//   parity (0 star 1's colour, 1 star 2's); corona — the star (0 or 1, its colour); mote — its loop radius in world
//   units (``BinaryGardensShaders/moteLoopRadius``). A corona ray's v runs from its root (−1) to its tip (+1), a
//   bracket's v from its bar (−1) to its open side (+1). Positions are world positions (model = identity). Only the
//   motes move: a mote's vertices move by radius · (cos a − 1, sin a) in x, y with a = 2π(phase + time · rate); the
//   corona rays keep their vertices and only their drawn reach pulses. Every other vertex is drawn where the geometry
//   put it, so the CPU reference points (never a mote) hold.
//
// Signed-distance shading: quads use smoothstep(−``markFeather``, ``markFeather``, distance) of their shape: square
// max(|u|, |v|) ≤ 1 (dashes, orbit segments, comfortable cells, guides, required tick, bloom track, bars), the band
// |v| ≤ 1 along the whole quad (the gauge plate, whose quad spans u = ±1 exactly), unit disc (filled pips, trail dots,
// world pips, tick and bloom markers, motes, star discs), ring of half-width
// ``ringHalf`` inside the unit circle (unlit pips, broken rings), the hollow square of width ``outlineWidth`` (dim and
// bright cells), the hollow square crossed by both diagonals of width ``crossWidth`` (lethal cells), the bracket (bar
// at v ≤ −``bracketBar`` and ends at |u| ≥ ``bracketEnd``; the dashed bracket cut into ``dashCount`` dashes along u)
// and the tapered ray. A world is shaded as stated above (``worldShade(normal:band:shareOne:shareTwo:toStarOne:
// toStarTwo:won:)``). The fragment shader selects every code exactly once, so each pixel has one coverage rule.
//
// Glow program: the glow shells around the stars and the worlds, drawn additively and last. The colour is carried in
// `a_normal` (zero: the world colour), `a_uv.x` is 2 · kind + factor (``GlowKind``: 0 star, 1 world; factor 0 … 1 —
// 1 for a star and a blooming world, 0 for a world that is not comfortable at the shown tick; see
// ``glowFactor(blooming:)``) and `a_uv.y` the shell's radial coordinate r, 0 on its inner edge and 1 on its outer edge.
// A won level (`u_won` = 1) raises every world shell's factor to 1, so every world glows. The alpha is ``glowWeight``
// times the gain, the factor and (1 − r)²; the inner part is lifted toward the glow colour by ``glowCore``; the gain is
// `u_glowGain` capped by `u_glowLimit` (both clamped to ``maxGlowGain``); under Reduce Flashing the presenter passes
// ``glowGainCap``.
//
// Plain uniforms in the default block (at most 16 vec4 slots per program; the system program uses 9: u_mvp 4, u_time,
// u_motion, u_won, u_star1 and u_star2 1 each; the glow program 7: u_mvp 4, u_glowGain, u_glowLimit and u_won 1 each),
// no texture samplers, no image assets, no `discard` and no loops at all (so every loop is bounded; the starfield and
// the flowers read one lattice cell of a fixed hash, never a random source). Output is premultiplied alpha. Palette
// constants are generated from `BinaryGardensPalette` with six fixed decimals, so the shader colours equal the CPU's
// within 1e-6.
//
// The kernel's shares are 0 … 64 000 milliflux, but a catalog world's comfortable flux is tens to hundreds of
// milliflux (well under 1 % of 64 000), so a light linear in share / 64 000 would leave every lit side black; the
// shaders therefore light each side by ``lightResponse(share:)``, a logarithmic response of the carried share that
// reaches 1 at ``lightReference`` milliflux (still monotonic in the kernel's share).
//
// Feature 504 (R02-G21-04) T-R02G2104-002 (FR-R02G2104-002, 008, 015; research R5, R6) appends four materials after
// code 37, keeping every earlier code, the value scale and the broken offset (64, still above 41 + 0.4): 38
// ``BinaryGardensMaterial/ghostStar`` — a preview's ghost star (quad, a ring cut into ``ghostDashes`` dashes around
// its circle by a new angular dash rule; the star's colour chosen by `a_normal.z` = star as for ringShared and corona;
// the broken colour when the change is refused); 39 ``BinaryGardensMaterial/ghostCell`` — a committed gauge cell's
// outline strip behind a preview (quad, square; a valued material whose value, the committed band's index / 4, selects
// BG_LETHAL_LOW … BG_LETHAL_HIGH in the vertex shader); 40 ``BinaryGardensMaterial/inspectRing`` — the inspected
// world's ring (quad, ring, marker colour); 41 ``BinaryGardensMaterial/inspectBracket`` — the inspected row's bracket
// strips (quad, square, marker colour).

import Foundation

/// The material code a system-program vertex carries in `a_uv.x` (FR-R02G2103-001, 002): one per kind of element the
/// geometry draws, contiguous from 0 to 41 (38 … 41 added by feature 504). The geometry writes
/// ``BinaryGardensShaders/encode(_:value:broken:)``; the system vertex shader selects ``paletteConstant``. The comment
/// of each case names its coverage rule.
public enum BinaryGardensMaterial: Int, Sendable, CaseIterable, Hashable {
    /// The backdrop quad (opaque; `a_uv.y` height h 0 … 1; `a_normal.xy` its plane offsets): the still gradient from
    /// space to space top with the hashed starfield.
    case backdrop = 0
    /// The tilt dial's pip of the current tilt (quad, disc), tilt lit colour.
    case tiltPipLit = 1
    /// Another tilt pip (quad, ring), tilt unlit colour.
    case tiltPipUnlit = 2
    /// A dash of a star ring no star stands on (quad, square), ring idle colour.
    case ringIdle = 3
    /// A segment of the ring star 1 stands on (quad, square), star 1's colour.
    case ringStarOne = 4
    /// A segment of the ring star 2 stands on (quad, square), star 2's colour.
    case ringStarTwo = 5
    /// A segment of a ring both stars stand on (quad, square; `a_normal.z` its parity), alternating star 1's and
    /// star 2's colours dash by dash.
    case ringShared = 6
    /// A segment of a world's orbit (quad, square), orbit colour.
    case orbit = 7
    /// A trail dot (quad, disc fading by its value, the freshness), starfield colour; at the richer tiers only.
    case trail = 8
    /// A world whose band at the shown tick is lethal low (solid, sphere shading): frost caps |φ| ≥ 30°.
    case worldLethalLow = 9
    /// A dim world (solid): frost caps |φ| ≥ 60°.
    case worldDim = 10
    /// A comfortable world (solid): procedural flowers over the mint surface.
    case worldComfortable = 11
    /// A bright world (solid): a scorched belt |φ| ≤ 15°.
    case worldBright = 12
    /// A lethally bright world (solid): a scorched belt |φ| ≤ 40°.
    case worldLethalHigh = 13
    /// One of a world's j + 1 pips (quad, disc), world colour.
    case worldPip = 14
    /// Star 1's disc (quad, disc with a white-hot core of half the radius), star 1's colour.
    case starOne = 15
    /// Star 2's disc (quad, disc with a white-hot core), star 2's colour.
    case starTwo = 16
    /// A corona ray (quad, tapered ray whose reach pulses; value its phase, `a_normal.z` its star), the star's colour;
    /// at the richer tiers only.
    case corona = 17
    /// A luminosity pip up to the star's current level (quad, disc), core colour.
    case luminosityPipLit = 18
    /// A luminosity pip above the star's current level (quad, ring), tilt unlit colour.
    case luminosityPipUnlit = 19
    /// A gauge row's plate (quad, a band across v whose coverage ignores u: its quad spans exactly its length,
    /// u = ±1, so the long plate's margin stays inside the fitted box), gauge plate colour.
    case gaugePlate = 20
    /// A lethal-low tick cell (quad, crossed square; value its height share), lethal low colour.
    case cellLethalLow = 21
    /// A dim tick cell (quad, hollow square; value its height share), dim colour.
    case cellDim = 22
    /// A comfortable tick cell (quad, solid square; value its height share), comfortable colour.
    case cellComfortable = 23
    /// A bright tick cell (quad, hollow square; value its height share), bright colour.
    case cellBright = 24
    /// A lethal-high tick cell (quad, crossed square; value its height share), lethal high colour.
    case cellLethalHigh = 25
    /// A guide line at the height of c_lo or c_hi (quad, square), window colour.
    case guide = 26
    /// The longest comfortable window's bracket when it reaches the required window (quad, bracket), window colour.
    case windowBracket = 27
    /// The window's bracket when it is shorter than the required window (quad, dashed bracket), window colour.
    case windowBracketShort = 28
    /// The tick at the required window W (quad, square), marker colour.
    case requiredTick = 29
    /// The marker above the shown tick's column (quad, disc), marker colour.
    case tickMarker = 30
    /// The bloom meter's track (quad, square), tilt unlit colour.
    case bloomTrack = 31
    /// The bloom band's bracket over B_lo … B_hi (quad, bracket), window colour.
    case bloomBracket = 32
    /// The bloom meter's marker at min(I, 2 · B_hi) (quad, disc), marker colour.
    case bloomMarker = 33
    /// A lit actions bar, an action left (quad, square), actions lit colour.
    case actionsLit = 34
    /// An unlit actions bar, an action spent (quad, square), actions unlit colour.
    case actionsUnlit = 35
    /// A pollen mote on a fixed loop around a comfortable world (quad, disc; value its phase, `a_normal.z` its loop
    /// radius), pollen colour; moved by time, stopped under Reduce Motion; at the richer tiers only.
    case mote = 36
    /// The broken ring around a world a frozen or scorched failure names (quad, ring), broken colour.
    case brokenRing = 37
    /// A preview's ghost star (quad, ring cut into ``BinaryGardensShaders/ghostDashes`` dashes around its circle;
    /// `a_normal.z` its star), the star's colour, the broken colour when the change is refused (feature 504).
    case ghostStar = 38
    /// A committed gauge cell's outline strip behind a preview (quad, square; value its committed band's index / 4),
    /// that band's cell colour (feature 504).
    case ghostCell = 39
    /// The ring around the inspected world (quad, ring), marker colour (feature 504).
    case inspectRing = 40
    /// A bracket strip beside the inspected world's gauge row (quad, square), marker colour (feature 504).
    case inspectBracket = 41

    /// The plain code (no value, not broken), as `Float` for the uv stream.
    public var code: Float { Float(rawValue) }

    /// The GLSL palette constant the system vertex shader selects for this material.
    public var paletteConstant: String {
        switch self {
        case .backdrop: return "BG_SPACE"
        case .tiltPipLit: return "BG_TILT_LIT"
        case .tiltPipUnlit, .luminosityPipUnlit, .bloomTrack: return "BG_TILT_UNLIT"
        case .ringIdle: return "BG_RING_IDLE"
        case .ringStarOne, .starOne: return "BG_STAR_ONE"
        case .ringStarTwo, .starTwo: return "BG_STAR_TWO"
        case .ringShared, .corona, .ghostStar: return "BG_STAR_ONE"
        case .orbit: return "BG_ORBIT"
        case .trail: return "BG_STARFIELD"
        case .worldLethalLow, .worldDim, .worldComfortable, .worldBright, .worldLethalHigh, .worldPip:
            return "BG_WORLD"
        case .luminosityPipLit: return "BG_CORE"
        case .gaugePlate: return "BG_GAUGE_PLATE"
        case .cellLethalLow, .ghostCell: return "BG_LETHAL_LOW"
        case .cellDim: return "BG_DIM"
        case .cellComfortable: return "BG_COMFORTABLE"
        case .cellBright: return "BG_BRIGHT"
        case .cellLethalHigh: return "BG_LETHAL_HIGH"
        case .guide, .windowBracket, .windowBracketShort, .bloomBracket: return "BG_WINDOW"
        case .requiredTick, .tickMarker, .bloomMarker, .inspectRing, .inspectBracket: return "BG_MARKER"
        case .actionsLit: return "BG_ACTIONS_LIT"
        case .actionsUnlit: return "BG_ACTIONS_UNLIT"
        case .mote: return "BG_POLLEN"
        case .brokenRing: return "BG_BROKEN"
        }
    }

    /// The palette colour of ``paletteConstant`` (the base colour before shading, value and won light).
    public var baseColour: SIMD3<Double> {
        for entry in BinaryGardensShaders.paletteConstants where entry.name == paletteConstant {
            return entry.colour
        }
        return BinaryGardensPalette.space
    }

    /// Whether the material carries a value in the fraction of `a_uv.x` (the worlds, the trail, the cells, the
    /// corona, the mote and the ghost cell).
    public var isValued: Bool {
        switch self {
        case .worldLethalLow, .worldDim, .worldComfortable, .worldBright, .worldLethalHigh, .trail, .cellLethalLow,
             .cellDim, .cellComfortable, .cellBright, .cellLethalHigh, .corona, .mote, .ghostCell:
            return true
        default:
            return false
        }
    }

    /// Whether the material is a world (sphere-shaded solid).
    public var isWorld: Bool { (9...13).contains(rawValue) }

    /// The world material of `band`.
    public static func world(_ band: BinaryGardensBand) -> BinaryGardensMaterial {
        switch band {
        case .lethalLow: .worldLethalLow
        case .dim: .worldDim
        case .comfortable: .worldComfortable
        case .bright: .worldBright
        case .lethalHigh: .worldLethalHigh
        }
    }

    /// The cell material of `band`.
    public static func cell(_ band: BinaryGardensBand) -> BinaryGardensMaterial {
        switch band {
        case .lethalLow: .cellLethalLow
        case .dim: .cellDim
        case .comfortable: .cellComfortable
        case .bright: .cellBright
        case .lethalHigh: .cellLethalHigh
        }
    }

    /// The band of a world material (nil for any other material).
    public var band: BinaryGardensBand? {
        switch self {
        case .worldLethalLow: .lethalLow
        case .worldDim: .dim
        case .worldComfortable: .comfortable
        case .worldBright: .bright
        case .worldLethalHigh: .lethalHigh
        default: nil
        }
    }
}

/// The GLSL ES 3.00 sources of Binary Gardens' system and glow programs, their uniform and attribute names, the
/// constants they are built from and the CPU twins of what they compute (FR-R02G2103-001, 002, 004, 007).
public enum BinaryGardensShaders {
    /// A glow-program vertex kind, encoded with the glow factor into `a_uv.x` as 2 · kind + factor.
    public enum GlowKind: Int, Sendable, CaseIterable, Hashable {
        /// A glow shell around a star (its colour in `a_normal`).
        case star = 0
        /// A glow shell around a world (zero colour: the world colour); a won level raises its factor to 1.
        case world = 1

        /// The `a_uv.x` value of a vertex of this kind with glow factor `factor` (clamped to 0 … 1; non-finite counts
        /// as 0).
        public func code(factor: Double) -> Double {
            Double(2 * rawValue) + BinaryGardensShaders.unit(factor)
        }

        /// The (kind, factor) the glow vertex shader decodes from `a_uv.x`: kind ⌊x / 2⌋ clamped to 0 … 1, factor
        /// x − 2 · kind clamped to 0 … 1 (x clamped to 0 … 3; non-finite counts as 0).
        public static func decode(_ x: Double) -> (kind: GlowKind, factor: Double) {
            let v: Double = x.isFinite ? min(max(x, 0), 3) : 0
            let k: Int = min(max(Int((v * 0.5).rounded(.down)), 0), 1)
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

    /// Every material as (Swift name, code, GLSL palette constant the system vertex shader selects), codes 0 … 41.
    public static var materials: [(name: String, code: Float, constant: String)] {
        var result: [(name: String, code: Float, constant: String)] = []
        for material in BinaryGardensMaterial.allCases {
            result.append((name: "\(material)", code: material.code, constant: material.paletteConstant))
        }
        return result
    }

    // MARK: Uniform names

    /// `mat4`: projection × view × model (both programs, vertex stage; model = identity, positions in world space).
    public static let mvpUniform: String = "u_mvp"
    /// `float`: the presentation time in seconds (system vertex stage; moves the motes and pulses the coronas), as
    /// ``shaderTime(_:)`` wraps it.
    public static let timeUniform: String = "u_time"
    /// `float`: 1 normally, 0 under Reduce Motion (system vertex stage; multiplies the time, so the motes and the
    /// coronas stop); see ``motion(reduceMotion:)``.
    public static let motionUniform: String = "u_motion"
    /// `float`: the won level's light, 0 … 1 (system vertex stage: every world blooms; glow fragment stage: raises
    /// every world shell's factor to 1); 0 on a level not won.
    public static let wonUniform: String = "u_won"
    /// `vec3`: star 1's centre at the shown tick in world units (system fragment stage; lights the worlds), as
    /// `BinaryGardensSceneGeometry.starCentre(0, snapshot)` gives it.
    public static let starOneUniform: String = "u_star1"
    /// `vec3`: star 2's centre at the shown tick in world units (system fragment stage).
    public static let starTwoUniform: String = "u_star2"
    /// `float`: the glow gain (glow fragment stage); see ``glowGain(for:)`` and ``glowGain(gain:limit:)``.
    public static let glowGainUniform: String = "u_glowGain"
    /// `float`: the glow limit (glow fragment stage): ``glowLimit(reduceFlashing:)``.
    public static let glowLimitUniform: String = "u_glowLimit"

    /// Every uniform the system program declares, each once, in order of declaration (vertex stage first).
    public static let systemUniforms: [String] = [mvpUniform, timeUniform, motionUniform, wonUniform, starOneUniform,
                                                  starTwoUniform]

    /// Every uniform the glow program declares, each once, in order of declaration (vertex stage first).
    public static let glowUniforms: [String] = [mvpUniform, glowGainUniform, glowLimitUniform, wonUniform]

    /// The uniform lists per program name (`system`, `glow`).
    public static let uniformNames: [String: [String]] = ["system": systemUniforms, "glow": glowUniforms]

    /// The most vec4 uniform slots one program may use (the plan's shader limit).
    public static let maxUniformVec4s: Int = 16

    // MARK: Constants

    /// The palette colours as written into the sources, as (GLSL constant name, colour), generated from
    /// `BinaryGardensPalette` in its declaration order (27 entries): `BG_` and the colour's name in upper snake case
    /// (spaceTop: `BG_SPACE_TOP`).
    public static let paletteConstants: [(name: String, colour: SIMD3<Double>)] = {
        var result: [(name: String, colour: SIMD3<Double>)] = []
        for entry in BinaryGardensPalette.all {
            result.append((name: constantName(entry.name), colour: entry.colour))
        }
        return result
    }()

    /// The GLSL constant name of palette colour `name`: `BG_` plus `name` in upper snake case.
    public static func constantName(_ name: String) -> String {
        var result: String = "BG_"
        for c in name {
            if c.isUppercase { result.append("_") }
            result.append(contentsOf: c.uppercased())
        }
        return result
    }

    /// The highest material code (the inspection bracket, feature 504).
    public static let maxMaterial: Int = BinaryGardensMaterial.inspectBracket.rawValue
    /// What `a_uv.x` adds for an element drawn in the broken colour (64: above every code 0 … 41 and its value, so the
    /// shape is kept).
    public static let brokenOffset: Double = 64
    /// How much of `a_uv.x` above its code is the value: x = code + valueScale · value. Below 0.5, so the code still
    /// rounds to the material.
    public static let valueScale: Double = 0.4
    /// The ambient floor: the share of a world's surface colour its night side keeps.
    public static let ambientFloor: Double = 0.35
    /// The milliflux at which a star's light response reaches 1 (``lightResponse(share:)``).
    public static let lightReference: Double = 1024
    /// The largest share in milliflux (the kernel's per-star maximum): the carried value is share / 64 000.
    public static let shareScale: Double = 64_000
    /// The half-width of a sunrise band in n · l (the band lies where |n · l_i| is below it).
    public static let sunriseWidth: Double = 0.18
    /// How much a sunrise band lifts the surface, times the star's response.
    public static let sunriseLift: Double = 0.55
    /// How far a sunrise band's tint is mixed from the star's colour toward the core colour.
    public static let sunriseCore: Double = 0.35
    /// The frost caps' edge of a lethally dim world, in degrees of latitude (|φ| ≥ 30°).
    public static let lethalCapLatitude: Double = 30
    /// The frost caps' edge of a dim world (|φ| ≥ 60°).
    public static let dimCapLatitude: Double = 60
    /// The scorched belt's edge of a bright world (|φ| ≤ 15°).
    public static let brightBeltLatitude: Double = 15
    /// The scorched belt's edge of a lethally bright world (|φ| ≤ 40°).
    public static let lethalBeltLatitude: Double = 40
    /// The feather of the caps' and belts' edges, in degrees.
    public static let bandFeather: Double = 4
    /// The flower lattice's cells around a world (in azimuth).
    public static let flowerColumns: Double = 16
    /// The flower lattice's cells per radian of polar angle.
    public static let flowerRows: Double = 5
    /// The share of flower lattice cells holding a flower.
    public static let flowerDensity: Double = 0.55
    /// A flower's radius in lattice units (the cell spans −0.5 … 0.5).
    public static let flowerRadius: Double = 0.3
    /// The soft edge of a flower in lattice units.
    public static let flowerFeather: Double = 0.08
    /// The petals of a flower (its outline r · (0.75 + 0.25 · cos(petals · θ))).
    public static let flowerPetals: Double = 5
    /// The starfield lattice's cells per world unit of the backdrop plane.
    public static let starDensity: Double = 14
    /// The share of starfield cells holding a star.
    public static let starPresence: Double = 0.3
    /// A star point's radius in lattice units.
    public static let starRadius: Double = 0.1
    /// The soft edge of a star point in lattice units.
    public static let starFeather: Double = 0.04
    /// How far a star point may sit from its cell centre, as a share of the cell.
    public static let starJitter: Double = 0.6
    /// How far a star point lifts the backdrop toward the starfield colour.
    public static let starStrength: Double = 0.85
    /// The soft edge of a quad shape in quad-local units: coverage smoothstep(−feather, feather, distance).
    public static let markFeather: Double = 0.06
    /// The half-width of a ring in quad-local units (the ring spans 1 − 2 · half … 1).
    public static let ringHalf: Double = 0.18
    /// The width of a hollow cell's outline in quad-local units.
    public static let outlineWidth: Double = 0.24
    /// The half-width of a crossed cell's diagonals in quad-local units.
    public static let crossWidth: Double = 0.16
    /// The quad-local extent the geometry's quads span on each axis (−extent … +extent), room for the feather.
    public static let quadExtent: Double = 1.25
    /// The v below which a bracket draws its bar (from −1).
    public static let bracketBar: Double = 0.4
    /// The |u| above which a bracket draws its end ticks.
    public static let bracketEnd: Double = 0.85
    /// The dashes along a dashed bracket.
    public static let dashCount: Double = 8
    /// The share of each dash period that is drawn.
    public static let dashDuty: Double = 0.55
    /// The soft edge of a dash in units of its period.
    public static let dashFeather: Double = 0.04
    /// The dashes around a ghost star's ring (feature 504; each drawn over ``dashDuty`` of its period).
    public static let ghostDashes: Double = 12
    /// The share of a star disc's radius that is its white-hot core.
    public static let coreShare: Double = 0.5
    /// A corona ray's shortest reach as a share of its quad (its reach pulses between this and 1).
    public static let coronaMin: Double = 0.55
    /// How much a corona ray narrows from root to tip.
    public static let coronaTaper: Double = 0.75
    /// The corona rays' pulses per second.
    public static let coronaRate: Double = 0.25
    /// The motes' loops per second.
    public static let moteRate: Double = 0.08
    /// The motes' loop radius in world units (written in `a_normal.z`).
    public static let moteLoopRadius: Double = 0.11
    /// The period the presenter wraps the time into (whole cycles of the coronas and the motes), seconds.
    public static let timeWrap: Double = 600

    /// The glow alpha weight, times the glow gain, the glow factor and the fade.
    public static let glowWeight: Double = 0.5
    /// How far a glow shell's inner part is lifted toward the glow colour, times the fade.
    public static let glowCore: Double = 0.5
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
        for entry in BinaryGardensPalette.all where names == nil || names?.contains(entry.name) == true {
            lines.append("const vec3 \(constantName(entry.name)) = \(vec3Literal(entry.colour));")
        }
        return lines.joined(separator: "\n")
    }

    /// The `base = mix(base, <constant>, isCode(m, <code>));` lines of every material but the backdrop, in code order.
    static func selectionBlock() -> String {
        var lines: [String] = []
        for material in BinaryGardensMaterial.allCases where material != .backdrop {
            let code: String = decimals(Double(material.rawValue))
            lines.append("base = mix(base, \(material.paletteConstant), isCode(m, \(code)));")
        }
        return lines.joined(separator: "\n")
    }

    /// The palette colours the system fragment shader declares (the backdrop, the stars, the core and the worlds).
    static let fragmentColours: [String] = ["space", "spaceTop", "starfield", "starOne", "starTwo", "core", "world",
                                            "frost", "scorch", "flower"]

    /// The system vertex shader. Uniforms: `u_mvp`, `u_time`, `u_motion`, `u_won`. Decodes the material, the broken
    /// mark and the value from `a_uv.x` (``decode(_:)``), moves the motes by the time times the motion
    /// (``moteOffset(phase:radius:time:motion:)``), pulses the corona rays (``coronaPulse(phase:time:motion:)``),
    /// selects the base colour (``baseColour(of:value:broken:won:shape:)``) and passes the normal or quad-local
    /// coordinate, the world position, the material, the local coordinate, the value (a ray's pulse) and the bloom.
    public static let systemVertex: String = """
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
    out vec3 v_pos;
    out float v_material;
    out float v_local;
    out float v_value;
    out float v_bloom;
    \(paletteBlock(nil))
    const float BG_MAX_MATERIAL = \(decimals(Double(maxMaterial)));
    const float BG_BROKEN_OFFSET = \(decimals(brokenOffset));
    const float BG_VALUE_SCALE = \(decimals(valueScale));
    const float BG_CORONA_RATE = \(decimals(coronaRate));
    const float BG_MOTE_RATE = \(decimals(moteRate));
    const float BG_TAU = 6.283185;
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float coded = clamp(floor(a_uv.x + 0.5), 0.0, BG_BROKEN_OFFSET + BG_MAX_MATERIAL);
        float marked = step(BG_BROKEN_OFFSET - 0.5, coded);
        float m = clamp(coded - BG_BROKEN_OFFSET * marked, 0.0, BG_MAX_MATERIAL);
        float value = clamp((a_uv.x - coded) / BG_VALUE_SCALE, 0.0, 1.0);
        float won = clamp(u_won, 0.0, 1.0);
        float clock = max(u_time, 0.0) * clamp(u_motion, 0.0, 1.0);
        float isCorona = isCode(m, 17.0);
        float isMote = isCode(m, 36.0);
        float isWorld = step(8.5, m) * step(m, 13.5);
        float pulse = 0.5 + 0.5 * sin(BG_TAU * (value + clock * BG_CORONA_RATE));
        float angle = BG_TAU * (value + clock * BG_MOTE_RATE);
        vec3 p = a_position;
        p.xy = p.xy + isMote * a_normal.z * vec2(cos(angle) - 1.0, sin(angle));
        vec3 base = BG_SPACE;
        \(selectionBlock())
        float second = step(0.5, a_normal.z);
        base = mix(base, BG_STAR_TWO, (isCode(m, 6.0) + isCorona + isCode(m, 38.0)) * second);
        float isGhostCell = isCode(m, 39.0);
        float ghostBand = floor(value * 4.0 + 0.5);
        base = mix(base, BG_DIM, isGhostCell * isCode(ghostBand, 1.0));
        base = mix(base, BG_COMFORTABLE, isGhostCell * isCode(ghostBand, 2.0));
        base = mix(base, BG_BRIGHT, isGhostCell * isCode(ghostBand, 3.0));
        base = mix(base, BG_LETHAL_HIGH, isGhostCell * isCode(ghostBand, 4.0));
        base = mix(base, BG_BROKEN, marked);
        v_base = base;
        v_aux = a_normal;
        v_pos = p;
        v_material = m;
        v_local = a_uv.y;
        v_value = mix(value, pulse, isCorona);
        v_bloom = won * isWorld;
        gl_Position = u_mvp * vec4(p, 1.0);
    }
    """

    /// The system fragment shader. Uniforms: `u_star1`, `u_star2`. The still backdrop gradient with the hashed
    /// starfield (``backdropColour(height:)``, ``starfieldCoverage(u:v:)``), the worlds lit by both stars with sunrise
    /// bands, the ambient floor, the seasonal banding and the flowers (``worldShade(normal:band:shareOne:shareTwo:
    /// toStarOne:toStarTwo:won:)``), the star discs with their cores (``starDiscColour(_:radius:)``) and the
    /// signed-distance quad shapes (``quadCoverage(_:u:v:value:)``). Every material code selects exactly one coverage
    /// rule. Premultiplied.
    public static let systemFragment: String = """
    #version 300 es
    precision highp float;
    in vec3 v_base;
    in vec3 v_aux;
    in vec3 v_pos;
    in float v_material;
    in float v_local;
    in float v_value;
    in float v_bloom;
    uniform vec3 u_star1;
    uniform vec3 u_star2;
    out vec4 color;
    \(paletteBlock(fragmentColours))
    const float BG_TAU = 6.283185;
    const float BG_DEGREES = 57.295780;
    const float BG_AMBIENT = \(decimals(ambientFloor));
    const float BG_SHARE_SCALE = \(decimals(shareScale));
    const float BG_LIGHT_REFERENCE = \(decimals(lightReference));
    const float BG_SUNRISE_WIDTH = \(decimals(sunriseWidth));
    const float BG_SUNRISE_LIFT = \(decimals(sunriseLift));
    const float BG_SUNRISE_CORE = \(decimals(sunriseCore));
    const float BG_LETHAL_CAP = \(decimals(lethalCapLatitude));
    const float BG_DIM_CAP = \(decimals(dimCapLatitude));
    const float BG_BRIGHT_BELT = \(decimals(brightBeltLatitude));
    const float BG_LETHAL_BELT = \(decimals(lethalBeltLatitude));
    const float BG_BAND_FEATHER = \(decimals(bandFeather));
    const float BG_FLOWER_COLUMNS = \(decimals(flowerColumns));
    const float BG_FLOWER_ROWS = \(decimals(flowerRows));
    const float BG_FLOWER_DENSITY = \(decimals(flowerDensity));
    const float BG_FLOWER_RADIUS = \(decimals(flowerRadius));
    const float BG_FLOWER_FEATHER = \(decimals(flowerFeather));
    const float BG_FLOWER_PETALS = \(decimals(flowerPetals));
    const float BG_STAR_DENSITY = \(decimals(starDensity));
    const float BG_STAR_PRESENCE = \(decimals(starPresence));
    const float BG_STAR_RADIUS = \(decimals(starRadius));
    const float BG_STAR_FEATHER = \(decimals(starFeather));
    const float BG_STAR_JITTER = \(decimals(starJitter));
    const float BG_STAR_STRENGTH = \(decimals(starStrength));
    const float BG_MARK_FEATHER = \(decimals(markFeather));
    const float BG_RING_HALF = \(decimals(ringHalf));
    const float BG_OUTLINE = \(decimals(outlineWidth));
    const float BG_CROSS = \(decimals(crossWidth));
    const float BG_BRACKET_BAR = \(decimals(bracketBar));
    const float BG_BRACKET_END = \(decimals(bracketEnd));
    const float BG_DASH_COUNT = \(decimals(dashCount));
    const float BG_DASH_DUTY = \(decimals(dashDuty));
    const float BG_DASH_FEATHER = \(decimals(dashFeather));
    const float BG_GHOST_DASHES = \(decimals(ghostDashes));
    const float BG_CORE_SHARE = \(decimals(coreShare));
    const float BG_CORONA_MIN = \(decimals(coronaMin));
    const float BG_CORONA_TAPER = \(decimals(coronaTaper));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    float cover(float dist) {
        return smoothstep(-BG_MARK_FEATHER, BG_MARK_FEATHER, dist);
    }
    float hash(vec2 c) {
        return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
    }
    float response(float share) {
        float s = max(share, 0.0) * BG_SHARE_SCALE;
        return clamp(log2(1.0 + s) / log2(1.0 + BG_LIGHT_REFERENCE), 0.0, 1.0);
    }
    void main() {
        float m = floor(v_material + 0.5);
        float value = clamp(v_value, 0.0, 1.0);
        float sky = isCode(m, 0.0);
        float disc = isCode(m, 1.0) + isCode(m, 14.0) + isCode(m, 18.0) + isCode(m, 30.0);
        disc = disc + isCode(m, 33.0) + isCode(m, 36.0);
        float ring = isCode(m, 2.0) + isCode(m, 19.0) + isCode(m, 37.0) + isCode(m, 40.0);
        float square = isCode(m, 3.0) + isCode(m, 4.0) + isCode(m, 5.0) + isCode(m, 6.0) + isCode(m, 7.0);
        square = square + isCode(m, 23.0) + isCode(m, 26.0) + isCode(m, 29.0);
        float plate = isCode(m, 20.0);
        square = square + isCode(m, 31.0) + isCode(m, 34.0) + isCode(m, 35.0);
        square = square + isCode(m, 39.0) + isCode(m, 41.0);
        float ghost = isCode(m, 38.0);
        float isTrail = isCode(m, 8.0);
        float isWorld = step(8.5, m) * step(m, 13.5);
        float isStar = isCode(m, 15.0) + isCode(m, 16.0);
        float isCorona = isCode(m, 17.0);
        float hollow = isCode(m, 22.0) + isCode(m, 24.0);
        float crossed = isCode(m, 21.0) + isCode(m, 25.0);
        float bracket = isCode(m, 27.0) + isCode(m, 32.0);
        float dashedBracket = isCode(m, 28.0);
        float h = clamp(v_local, 0.0, 1.0);
        vec2 q = floor(v_aux.xy * BG_STAR_DENSITY);
        vec2 f = fract(v_aux.xy * BG_STAR_DENSITY) - 0.5;
        vec2 jitter = (vec2(hash(q + 17.0), hash(q + 31.0)) - 0.5) * BG_STAR_JITTER;
        float present = step(hash(q), BG_STAR_PRESENCE);
        float spark = 1.0 - smoothstep(BG_STAR_RADIUS - BG_STAR_FEATHER, BG_STAR_RADIUS, length(f - jitter));
        vec3 backdrop = mix(mix(BG_SPACE, BG_SPACE_TOP, h), BG_STARFIELD, BG_STAR_STRENGTH * spark * present);
        vec3 n = normalize(v_aux + vec3(0.0, 0.0, 0.000001));
        float lat = abs(asin(clamp(n.z, -1.0, 1.0))) * BG_DEGREES;
        float band = m - 9.0;
        float bloom = clamp(v_bloom, 0.0, 1.0);
        float fe = BG_BAND_FEATHER;
        float caps = isCode(band, 0.0) * smoothstep(BG_LETHAL_CAP - fe, BG_LETHAL_CAP + fe, lat);
        caps = caps + isCode(band, 1.0) * smoothstep(BG_DIM_CAP - fe, BG_DIM_CAP + fe, lat);
        float belt = isCode(band, 3.0) * (1.0 - smoothstep(BG_BRIGHT_BELT - fe, BG_BRIGHT_BELT + fe, lat));
        belt = belt + isCode(band, 4.0) * (1.0 - smoothstep(BG_LETHAL_BELT - fe, BG_LETHAL_BELT + fe, lat));
        float azimuth = atan(n.y, n.x + 0.00001) * BG_FLOWER_COLUMNS / BG_TAU;
        vec2 lattice = vec2(azimuth, acos(clamp(n.z, -1.0, 1.0)) * BG_FLOWER_ROWS);
        vec2 cell = fract(lattice) - 0.5;
        float petal = BG_FLOWER_RADIUS * (0.75 + 0.25 * cos(BG_FLOWER_PETALS * atan(cell.y, cell.x + 0.00001)));
        float blossom = 1.0 - smoothstep(petal - BG_FLOWER_FEATHER, petal, length(cell));
        float flowers = blossom * step(hash(floor(lattice)), BG_FLOWER_DENSITY);
        flowers = flowers * max(isCode(band, 2.0), bloom);
        vec3 surface = BG_WORLD;
        surface = mix(surface, BG_FROST, caps * (1.0 - bloom));
        surface = mix(surface, BG_SCORCH, belt * (1.0 - bloom));
        surface = mix(surface, BG_FLOWER, flowers);
        vec3 l1 = normalize(u_star1 - v_pos + vec3(0.0, 0.0, 0.000001));
        vec3 l2 = normalize(u_star2 - v_pos + vec3(0.0, 0.0, 0.000001));
        float d1 = dot(n, l1);
        float d2 = dot(n, l2);
        float r1 = response(value);
        float r2 = response(v_local);
        vec3 lit = surface * BG_AMBIENT;
        vec3 sun = BG_STAR_ONE * r1 * max(d1, 0.0) + BG_STAR_TWO * r2 * max(d2, 0.0);
        lit = lit + surface * (1.0 - BG_AMBIENT) * sun;
        float dawn1 = r1 * (1.0 - smoothstep(0.0, BG_SUNRISE_WIDTH, abs(d1))) * BG_SUNRISE_LIFT;
        float dawn2 = r2 * (1.0 - smoothstep(0.0, BG_SUNRISE_WIDTH, abs(d2))) * BG_SUNRISE_LIFT;
        lit = lit + dawn1 * mix(BG_STAR_ONE, BG_CORE, BG_SUNRISE_CORE);
        lit = lit + dawn2 * mix(BG_STAR_TWO, BG_CORE, BG_SUNRISE_CORE);
        vec2 p = v_aux.xy;
        float r = length(p);
        float squareCover = cover(1.0 - max(abs(p.x), abs(p.y)));
        float discCover = cover(1.0 - r);
        float ringCover = cover(BG_RING_HALF - abs(r - (1.0 - BG_RING_HALF)));
        float inner = 1.0 - BG_OUTLINE;
        float outline = squareCover * (1.0 - cover(inner - max(abs(p.x), abs(p.y))));
        float diagonal = max(cover(BG_CROSS - abs(p.x - p.y)), cover(BG_CROSS - abs(p.x + p.y)));
        float crossCover = max(outline, squareCover * diagonal);
        float arm = max(cover(-BG_BRACKET_BAR - p.y), cover(abs(p.x) - BG_BRACKET_END));
        float bracketCover = squareCover * arm;
        float t = fract((p.x + 1.0) * 0.5 * BG_DASH_COUNT);
        float dash = smoothstep(-BG_DASH_FEATHER, BG_DASH_FEATHER, BG_DASH_DUTY * 0.5 - abs(t - 0.5));
        float turn = fract(atan(p.y, p.x + 0.00001) / BG_TAU * BG_GHOST_DASHES);
        float arc = smoothstep(-BG_DASH_FEATHER, BG_DASH_FEATHER, BG_DASH_DUTY * 0.5 - abs(turn - 0.5));
        float reach = -1.0 + 2.0 * mix(BG_CORONA_MIN, 1.0, value);
        float width = 1.0 - BG_CORONA_TAPER * (clamp(p.y, -1.0, 1.0) + 1.0) * 0.5;
        float rayCover = cover(width - abs(p.x)) * cover(reach - p.y) * cover(p.y + 1.0);
        vec3 starRgb = mix(v_base, BG_CORE, 1.0 - smoothstep(BG_CORE_SHARE - 0.05, BG_CORE_SHARE + 0.05, r));
        vec3 rgb = mix(v_base, backdrop, sky);
        rgb = mix(rgb, lit, isWorld);
        rgb = mix(rgb, starRgb, isStar);
        float coverage = sky + isWorld;
        coverage = coverage + discCover * disc + discCover * value * isTrail + discCover * isStar;
        coverage = coverage + ringCover * ring + squareCover * square + cover(1.0 - abs(p.y)) * plate;
        coverage = coverage + outline * hollow + crossCover * crossed;
        coverage = coverage + bracketCover * bracket + bracketCover * dash * dashedBracket;
        coverage = coverage + rayCover * isCorona;
        coverage = coverage + ringCover * arc * ghost;
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
    \(paletteBlock(["world", "glow"]))
    const float BG_GLOW_WEIGHT = \(decimals(glowWeight));
    const float BG_GLOW_CORE = \(decimals(glowCore));
    const float BG_MAX_GAIN = \(decimals(maxGlowGain));
    float isCode(float m, float code) {
        return 1.0 - step(0.5, abs(m - code));
    }
    void main() {
        float gain = min(clamp(u_glowGain, 0.0, BG_MAX_GAIN), clamp(u_glowLimit, 0.0, BG_MAX_GAIN));
        float kind = floor(v_kind + 0.5);
        float isWorld = isCode(kind, 1.0);
        float won = clamp(u_won, 0.0, 1.0);
        vec3 rgb = mix(BG_WORLD, v_colour, step(0.0001, v_colour.r + v_colour.g + v_colour.b));
        float factor = mix(clamp(v_factor, 0.0, 1.0), 1.0, won * isWorld);
        float r = 1.0 - clamp(v_radius, 0.0, 1.0);
        float fade = r * r;
        rgb = mix(rgb, BG_GLOW, BG_GLOW_CORE * fade);
        float alpha = clamp(BG_GLOW_WEIGHT * gain * factor * fade, 0.0, 1.0);
        rgb = clamp(rgb, 0.0, 1.0);
        color = vec4(rgb * alpha, alpha);
    }
    """

    // MARK: Encoding (the geometry writes these)

    /// The `a_uv.x` a system vertex of `material` writes: its code, plus ``valueScale`` times `value` (clamped to
    /// 0 … 1, non-finite counts as 0; only for a valued material, otherwise ignored), plus ``brokenOffset`` when
    /// `broken`.
    public static func encode(_ material: BinaryGardensMaterial, value: Double = 0, broken: Bool = false) -> Double {
        let v: Double = material.isValued ? unit(value) : 0
        return Double(material.rawValue) + valueScale * v + (broken ? brokenOffset : 0)
    }

    /// What the system vertex shader decodes from `a_uv.x` value `x`: the code rounded to the nearest integer and
    /// clamped to 0 … ``brokenOffset`` + ``maxMaterial``; broken when it is at least ``brokenOffset``; the material
    /// the code less the offset, clamped to 0 … ``maxMaterial``; the value (x − code) / ``valueScale`` clamped to
    /// 0 … 1. Non-finite counts as the backdrop, value 0, not broken.
    public static func decode(_ x: Double) -> (material: BinaryGardensMaterial, value: Double, broken: Bool) {
        guard x.isFinite else { return (material: .backdrop, value: 0, broken: false) }
        let top: Double = brokenOffset + Double(maxMaterial)
        let coded: Double = min(max((x + 0.5).rounded(.down), 0), top)
        let broken: Bool = coded >= brokenOffset - 0.5
        let m: Double = min(max(coded - (broken ? brokenOffset : 0), 0), Double(maxMaterial))
        let material: BinaryGardensMaterial = BinaryGardensMaterial(rawValue: Int(m)) ?? .backdrop
        return (material: material, value: unit((x - coded) / valueScale), broken: broken)
    }

    /// The value a world vertex carries for a star's share `share` (milliflux): share / 64 000, clamped to 0 … 1.
    public static func shareValue(_ share: Int) -> Double { unit(Double(share) / shareScale) }

    /// The height share of a cell of flux `flux` on a world with lethal high bound `lethalHigh`: min(1, F / λ_hi)
    /// (F below 0 as 0, λ_hi at least 1).
    public static func heightShare(flux: Int, lethalHigh: Int) -> Double {
        min(1, Double(max(flux, 0)) / Double(max(lethalHigh, 1)))
    }

    /// The glow factor a world shell writes: 1 for a blooming world (comfortable at the shown tick), 0 otherwise (a
    /// won level raises it to 1 in the shader).
    public static func glowFactor(blooming: Bool) -> Double { blooming ? 1 : 0 }

    // MARK: Uniform values (the presenter passes these)

    /// The time the presenter passes as `u_time`: `time` wrapped into 0 ..< ``timeWrap`` (whole cycles of the coronas
    /// and motes, so nothing jumps; non-finite or negative counts as 0), keeping float precision on long sessions.
    public static func shaderTime(_ time: Double) -> Double {
        guard time.isFinite, time > 0 else { return 0 }
        return time.truncatingRemainder(dividingBy: timeWrap)
    }

    /// The value the presenter passes as `u_motion`: 0 under Reduce Motion (the coronas and motes stop), else 1.
    public static func motion(reduceMotion: Bool) -> Double { reduceMotion ? 0 : 1 }

    /// The glow limit the presenter passes as `u_glowLimit`: ``standardGlowLimit``, or ``glowGainCap`` under Reduce
    /// Flashing.
    public static func glowLimit(reduceFlashing: Bool) -> Double {
        reduceFlashing ? glowGainCap : standardGlowLimit
    }

    /// The glow gain the presenter passes as `u_glowGain` at `tier`: ``glowGainBase`` + ``glowGainPerShell`` times its
    /// glow shells, capped at ``maxGlowGain``, or 0 without glow shells (level-2). Level-0 (1.5) > level-1 (1.0) > 0.
    public static func glowGain(for tier: BinaryGardensTier) -> Double {
        guard tier.glowShells > 0 else { return 0 }
        return min(glowGainBase + glowGainPerShell * Double(tier.glowShells), maxGlowGain)
    }

    // MARK: CPU twins

    /// The base colour the system vertex shader selects for `material` with `value`, `broken`, won light `won` and
    /// shape parameter `shape` (`a_normal.z`): the broken colour when broken; star 2's colour for a ring-shared dash,
    /// a corona ray or a ghost star whose shape parameter is at least 0.5; a ghost cell's committed band colour
    /// (``ghostCellColour(value:)``); else the material's palette colour. (The won light
    /// changes no base colour; it makes the worlds bloom in the fragment stage.)
    public static func baseColour(of material: BinaryGardensMaterial, value: Double, broken: Bool, won: Double,
                                  shape: Double = 0) -> SIMD3<Double> {
        if broken { return BinaryGardensPalette.broken }
        if (material == .ringShared || material == .corona || material == .ghostStar) && shape >= 0.5 {
            return BinaryGardensPalette.starTwo
        }
        if material == .ghostCell { return ghostCellColour(value: value) }
        return material.baseColour
    }

    /// The colour of a ghost cell of value `value` (feature 504): the cell colour of band index round(4 · value)
    /// (clamped; lethal low, dim, comfortable, bright, lethal high), as the vertex shader selects it.
    public static func ghostCellColour(value: Double) -> SIMD3<Double> {
        let index: Int = Int((unit(value) * 4).rounded(.toNearestOrAwayFromZero))
        let bands: [BinaryGardensBand] = BinaryGardensBand.allCases
        return BinaryGardensMaterial.cell(bands[min(max(index, 0), bands.count - 1)]).baseColour
    }

    /// The still backdrop gradient at height `height` (0 bottom … 1 top; clamped, non-finite counts as 0): from space
    /// to space top.
    public static func backdropColour(height: Double) -> SIMD3<Double> {
        let low: SIMD3<Double> = BinaryGardensPalette.space
        return low + (BinaryGardensPalette.spaceTop - low) * unit(height)
    }

    /// The fixed hash of lattice cell (`x`, `y`): fract(sin(dot(c, (12.9898, 78.233))) · 43758.5453), as the
    /// fragment shader computes it (the GPU's float result may differ near a threshold; a reference, not a pixel
    /// oracle).
    public static func hash(x: Double, y: Double) -> Double {
        let s: Double = sin(x * 12.9898 + y * 78.233) * 43758.5453
        return s - s.rounded(.down)
    }

    /// The starfield coverage 0 … 1 at backdrop plane offsets (`u`, `v`) in world units: on the lattice cell of
    /// (u, v) · ``starDensity``, a point of radius ``starRadius`` jittered by up to ``starJitter`` / 2 of the cell when
    /// the cell's hash is at most ``starPresence``, else 0. Its mean over the plane is under 2 % (non-finite input 0).
    public static func starfieldCoverage(u: Double, v: Double) -> Double {
        guard u.isFinite, v.isFinite else { return 0 }
        let qx: Double = (u * starDensity).rounded(.down)
        let qy: Double = (v * starDensity).rounded(.down)
        guard hash(x: qx, y: qy) <= starPresence else { return 0 }
        let fx: Double = u * starDensity - qx - 0.5
        let fy: Double = v * starDensity - qy - 0.5
        let jx: Double = (hash(x: qx + 17, y: qy + 17) - 0.5) * starJitter
        let jy: Double = (hash(x: qx + 31, y: qy + 31) - 0.5) * starJitter
        let d: Double = ((fx - jx) * (fx - jx) + (fy - jy) * (fy - jy)).squareRoot()
        return 1 - smoothstep(starRadius - starFeather, starRadius, d)
    }

    /// The backdrop colour at height `height` and plane offsets (`u`, `v`): the gradient lifted toward the starfield
    /// colour by ``starStrength`` times the starfield coverage.
    public static func backdropColour(height: Double, u: Double, v: Double) -> SIMD3<Double> {
        let base: SIMD3<Double> = backdropColour(height: height)
        return base + (BinaryGardensPalette.starfield - base) * (starStrength * starfieldCoverage(u: u, v: v))
    }

    /// A star's light response to its share `share` (the carried value, share / 64 000; clamped, non-finite 0):
    /// min(1, log2(1 + 64 000 · share) / log2(1 + ``lightReference``)); 0 for no share, monotonic, 1 from
    /// ``lightReference`` milliflux on.
    public static func lightResponse(share: Double) -> Double {
        let s: Double = unit(share) * shareScale
        return min(max(log2(1 + s) / log2(1 + lightReference), 0), 1)
    }

    /// The coverage 0 … 1 of a band's caps or belt at latitude `latitude` (degrees, sign ignored; non-finite counts
    /// as 0): lethal low smoothstep(30 − f, 30 + f, |φ|), dim the same at 60°, bright 1 − smoothstep(15 − f, 15 + f,
    /// |φ|), lethal high the same at 40°, comfortable 0 (it flowers instead); f = ``bandFeather``.
    public static func bandCoverage(latitude: Double, band: BinaryGardensBand) -> Double {
        let lat: Double = latitude.isFinite ? abs(latitude) : 0
        let f: Double = bandFeather
        switch band {
        case .lethalLow: return smoothstep(lethalCapLatitude - f, lethalCapLatitude + f, lat)
        case .dim: return smoothstep(dimCapLatitude - f, dimCapLatitude + f, lat)
        case .comfortable: return 0
        case .bright: return 1 - smoothstep(brightBeltLatitude - f, brightBeltLatitude + f, lat)
        case .lethalHigh: return 1 - smoothstep(lethalBeltLatitude - f, lethalBeltLatitude + f, lat)
        }
    }

    /// The latitude φ = asin(n.z) in degrees of normal `normal` (any length; 0 for a zero or non-finite normal).
    public static func latitude(_ normal: SIMD3<Double>) -> Double {
        guard let n = normalised(normal) else { return 0 }
        return asin(min(max(n.z, -1), 1)) * 180 / Double.pi
    }

    /// The flower coverage 0 … 1 at normal `normal` (any length): on the lattice cell (atan(n.y, n.x + 0.00001) ·
    /// ``flowerColumns`` / 2π, acos(n.z) · ``flowerRows``) holding the normal, a five-petal blossom of radius
    /// ``flowerRadius`` · (0.75 + 0.25 · cos(5θ)) when the cell's hash is at most ``flowerDensity``, else 0 (a fixed
    /// hash; 0 for a zero or non-finite normal).
    public static func flowerCoverage(normal: SIMD3<Double>) -> Double {
        guard let n = normalised(normal) else { return 0 }
        let ax: Double = atan2(n.y, n.x + 0.00001) * flowerColumns / (2 * Double.pi)
        let ay: Double = acos(min(max(n.z, -1), 1)) * flowerRows
        let cx: Double = ax.rounded(.down)
        let cy: Double = ay.rounded(.down)
        guard hash(x: cx, y: cy) <= flowerDensity else { return 0 }
        let fx: Double = ax - cx - 0.5
        let fy: Double = ay - cy - 0.5
        let petal: Double = flowerRadius * (0.75 + 0.25 * cos(flowerPetals * atan2(fy, fx + 0.00001)))
        return 1 - smoothstep(petal - flowerFeather, petal, (fx * fx + fy * fy).squareRoot())
    }

    /// The surface colour of a world of `band` at normal `normal` before lighting: mint, mixed to frost by its caps,
    /// to scorch by its belt (neither when `won` is 1) and to the flower colour by its flowers (comfortable, or a won
    /// level).
    public static func worldSurface(normal: SIMD3<Double>, band: BinaryGardensBand, won: Double = 0) -> SIMD3<Double> {
        let bloom: Double = unit(won)
        let lat: Double = latitude(normal)
        var c: SIMD3<Double> = BinaryGardensPalette.world
        let cover: Double = bandCoverage(latitude: lat, band: band) * (1 - bloom)
        if band == .lethalLow || band == .dim { c += (BinaryGardensPalette.frost - c) * cover }
        if band == .bright || band == .lethalHigh { c += (BinaryGardensPalette.scorch - c) * cover }
        let flowers: Double = flowerCoverage(normal: normal) * max(band == .comfortable ? 1 : 0, bloom)
        c += (BinaryGardensPalette.flower - c) * flowers
        return c
    }

    /// The lit colour of a world of `band` at normal `normal` (any length) lit by star 1 (share value `shareOne`,
    /// direction `toStarOne`) and star 2 (`shareTwo`, `toStarTwo`): the surface (``worldSurface(normal:band:won:)``)
    /// times the ambient floor ``ambientFloor``, plus the surface times (1 − floor) times each star's colour by
    /// max(0, n · l_i) times its ``lightResponse(share:)``, plus each star's sunrise band (its response times
    /// ``sunriseLift`` where |n · l_i| < ``sunriseWidth``, tinted from its colour toward the core); clamped to 0 … 1.
    /// A zero normal or direction gives the ambient floor only.
    public static func worldShade(normal: SIMD3<Double>, band: BinaryGardensBand, shareOne: Double, shareTwo: Double,
                                  toStarOne: SIMD3<Double>, toStarTwo: SIMD3<Double>,
                                  won: Double = 0) -> SIMD3<Double> {
        let surface: SIMD3<Double> = worldSurface(normal: normal, band: band, won: won)
        var c: SIMD3<Double> = surface * ambientFloor
        guard let n = normalised(normal) else { return clamped(c) }
        let lights: [(share: Double, direction: SIMD3<Double>, colour: SIMD3<Double>)] = [
            (share: shareOne, direction: toStarOne, colour: BinaryGardensPalette.starOne),
            (share: shareTwo, direction: toStarTwo, colour: BinaryGardensPalette.starTwo),
        ]
        for light in lights {
            guard let l = normalised(light.direction) else { continue }
            let response: Double = lightResponse(share: light.share)
            let d: Double = (n * l).sum()
            c += surface * (1 - ambientFloor) * light.colour * (response * max(d, 0))
            let dawn: Double = response * (1 - smoothstep(0, sunriseWidth, abs(d))) * sunriseLift
            let tint: SIMD3<Double> = light.colour + (BinaryGardensPalette.core - light.colour) * sunriseCore
            c += tint * dawn
        }
        return clamped(c)
    }

    /// A star disc's colour at radial coordinate `radius` (0 centre … 1 rim) for star `star` (0 or 1): the white-hot
    /// core colour inside ``coreShare`` (feathered by 0.05), the star's colour outside.
    public static func starDiscColour(_ star: Int, radius: Double) -> SIMD3<Double> {
        let colour: SIMD3<Double> = star == 0 ? BinaryGardensPalette.starOne : BinaryGardensPalette.starTwo
        let r: Double = radius.isFinite ? abs(radius) : 1
        let coreMix: Double = 1 - smoothstep(coreShare - 0.05, coreShare + 0.05, r)
        return colour + (BinaryGardensPalette.core - colour) * coreMix
    }

    /// The angle GLSL's atan(v, u + 0.00001) gives (radians).
    static func angle(u: Double, v: Double) -> Double { atan2(v, u + 0.00001) }

    /// The coverage of quad material `material` at quad-local (`u`, `v`) with value `value` (the trail's freshness or
    /// the corona's pulse): smoothstep(−``markFeather``, ``markFeather``, distance) of its shape (disc, ring, square,
    /// plate band, hollow, crossed, bracket, dashed bracket, tapered ray, the ghost star's dashed ring); a trail's disc
    /// times its freshness. 0 for a world, the backdrop or non-finite input.
    public static func quadCoverage(_ material: BinaryGardensMaterial, u: Double, v: Double,
                                    value: Double = 1) -> Double {
        guard u.isFinite, v.isFinite else { return 0 }
        func cover(_ dist: Double) -> Double { smoothstep(-markFeather, markFeather, dist) }
        let r: Double = (u * u + v * v).squareRoot()
        let box: Double = max(abs(u), abs(v))
        let squareCover: Double = cover(1 - box)
        let outline: Double = squareCover * (1 - cover(1 - outlineWidth - box))
        switch material {
        case .tiltPipLit, .worldPip, .luminosityPipLit, .tickMarker, .bloomMarker, .mote, .starOne, .starTwo:
            return cover(1 - r)
        case .trail:
            return cover(1 - r) * unit(value)
        case .tiltPipUnlit, .luminosityPipUnlit, .brokenRing, .inspectRing:
            return cover(ringHalf - abs(r - (1 - ringHalf)))
        case .ghostStar:
            let x: Double = angle(u: u, v: v) / (2 * Double.pi) * ghostDashes
            let turn: Double = x - x.rounded(.down)
            let arc: Double = smoothstep(-dashFeather, dashFeather, dashDuty * 0.5 - abs(turn - 0.5))
            return cover(ringHalf - abs(r - (1 - ringHalf))) * arc
        case .ringIdle, .ringStarOne, .ringStarTwo, .ringShared, .orbit, .cellComfortable, .guide, .requiredTick,
             .bloomTrack, .actionsLit, .actionsUnlit, .ghostCell, .inspectBracket:
            return squareCover
        case .gaugePlate:
            return cover(1 - abs(v))
        case .cellDim, .cellBright:
            return outline
        case .cellLethalLow, .cellLethalHigh:
            let diagonal: Double = max(cover(crossWidth - abs(u - v)), cover(crossWidth - abs(u + v)))
            return max(outline, squareCover * diagonal)
        case .windowBracket, .bloomBracket:
            return squareCover * max(cover(-bracketBar - v), cover(abs(u) - bracketEnd))
        case .windowBracketShort:
            let x: Double = (u + 1) * 0.5 * dashCount
            let t: Double = x - x.rounded(.down)
            let dash: Double = smoothstep(-dashFeather, dashFeather, dashDuty * 0.5 - abs(t - 0.5))
            return squareCover * max(cover(-bracketBar - v), cover(abs(u) - bracketEnd)) * dash
        case .corona:
            let reach: Double = -1 + 2 * (coronaMin + (1 - coronaMin) * unit(value))
            let width: Double = 1 - coronaTaper * (min(max(v, -1), 1) + 1) * 0.5
            return cover(width - abs(u)) * cover(reach - v) * cover(v + 1)
        default:
            return 0
        }
    }

    /// A corona ray's pulse 0 … 1 at phase `phase` (clamped 0 … 1), shader time `time` and motion `motion` (clamped
    /// 0 … 1; non-finite inputs count as 0): 0.5 + 0.5 · sin(2π(phase + max(time, 0) · motion · ``coronaRate``)); with
    /// motion 0 it stays at its phase's value.
    public static func coronaPulse(phase: Double, time: Double, motion: Double) -> Double {
        let clock: Double = (time.isFinite ? max(time, 0) : 0) * unit(motion)
        return 0.5 + 0.5 * sin(2 * Double.pi * (unit(phase) + clock * coronaRate))
    }

    /// A mote's offset from where the geometry put it, at phase `phase`, loop radius `radius`, shader time `time` and
    /// motion `motion`: radius · (cos a − 1, sin a) with a = 2π(phase + max(time, 0) · motion · ``moteRate``)
    /// (non-finite inputs count as 0). Zero at time 0 when the phase is 0; with motion 0 the mote stays at its phase's
    /// point.
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

    /// The glow of a vertex with `colour` (zero counts as the world colour), glow factor `factor`, radial coordinate
    /// `radius`, the applied `gain` and won light `won`, before premultiplying: the colour lifted toward the glow
    /// colour by ``glowCore`` · (1 − radius)², with alpha ``glowWeight`` · gain · factor · (1 − radius)², a world
    /// shell's factor raised to 1 by `won`; every component clamped to 0 … 1.
    public static func glowColour(colour: SIMD3<Double>, kind: GlowKind, factor: Double, radius: Double, gain: Double,
                                  won: Double) -> SIMD4<Double> {
        var c: SIMD3<Double> = SIMD3<Double>(unit(colour.x), unit(colour.y), unit(colour.z))
        if c.x + c.y + c.z < 0.0001 { c = BinaryGardensPalette.world }
        var f: Double = unit(factor)
        if kind == .world { f += (1 - f) * unit(won) }
        let r: Double = 1 - unit(radius)
        let fade: Double = r * r
        c += (BinaryGardensPalette.glow - c) * (glowCore * fade)
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

    /// `c` with every component clamped to 0 … 1.
    static func clamped(_ c: SIMD3<Double>) -> SIMD3<Double> { SIMD3<Double>(unit(c.x), unit(c.y), unit(c.z)) }

    /// `x` clamped to 0 … 1 (non-finite counts as 0).
    static func unit(_ x: Double) -> Double { x.isFinite ? min(max(x, 0), 1) : 0 }

    /// GLSL's smoothstep(`edge0`, `edge1`, `x`).
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t: Double = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
